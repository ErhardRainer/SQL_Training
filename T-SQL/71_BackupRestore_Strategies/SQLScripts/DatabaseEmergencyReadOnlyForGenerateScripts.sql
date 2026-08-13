/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "DatabaseEmergencyReadOnlyForGenerateScripts.sql"
script_version: "1.0"
script_type: "remediation"
chapter: "71_BackupRestore_Strategies"
purpose: >
  Versetzt eine SUSPECT-Datenbank NUR in EMERGENCY + READ_ONLY (kein REPAIR,
  kein SINGLE_USER WITH ROLLBACK IMMEDIATE, keine eigene Schema-Extraktion),
  um sie ueberhaupt wieder lesbar zu machen. Im Unterschied zu
  SuspectDatabaseScriptSchemaOnly.sql liest dieses Skript die Systemkataloge
  NICHT selbst objektweise aus, sondern gibt am Ende lediglich eine Anleitung
  aus, wie das Schema anschliessend komfortabel per SSMS "Generate Scripts"
  (Tasks -> Generate Scripts...) oder einem der programmatischen Wege
  (SMO/PowerShell, dbatools Export-DbaScript, mssql-scripter) extrahiert
  werden kann - siehe SSMS_GenerateScripts_Anleitung.md.

parameters:
  - name: "@TargetDatabaseName"
    sql_type: "SYSNAME"
    direction: "IN"
    required: true
    description: "Name der SUSPECT-Datenbank, die fuer eine anschliessende Schema-Extraktion per Generate Scripts lesbar gemacht werden soll, z.B. 'BI_DQ'"
  - name: "@ConfirmEmergencyReadOnly"
    sql_type: "BIT"
    direction: "IN"
    required: true
    description: "Muss explizit auf 1 gesetzt werden, um die Datenbank in EMERGENCY + READ_ONLY zu versetzen; bei 0 (Default) wird nur der aktuelle Status angezeigt und nichts geaendert"

result_sets:
  - name: "PreCheckStatus"
    description: "Status der Zieldatenbank aus sys.databases vor jeder Aenderung"
  - name: "PostChangeStatus"
    description: "Status der Zieldatenbank nach dem Wechsel nach EMERGENCY + READ_ONLY (nur wenn @ConfirmEmergencyReadOnly = 1)"

dependencies:
  - "sys.databases"
  - "ALTER DATABASE"

safety:
  level: "destructive-limited"
  writes_data: false

documentation:
  markdown_file: "T-SQL/71_BackupRestore_Strategies/SQLScripts/DatabaseEmergencyReadOnlyForGenerateScripts.md"
  sync_blocks:
    - "SUMMARY_TABLE"
    - "PARAMETERS_TABLE"
    - "DEPENDENCIES_LIST"
    - "VERSION_HISTORY_TABLE"
    - "SQL_CODE"
  mermaid:
    mode: "ai-agent-from-sql"
    source: "script-body"

main_responsible:
  name: "Erhard Rainer"
  initials: "ER"

version_history:
  - version: "1.0"
    date: "2026-08-13"
    user: "ER"
    description: "Erstversion: schlanke Variante von SuspectDatabaseScriptSchemaOnly.sql ohne eigene T-SQL-Schema-Extraktion - versetzt die Datenbank nur nach EMERGENCY + READ_ONLY und verweist anschliessend auf SSMS Generate Scripts bzw. die programmatischen Alternativen (SMO/PowerShell, dbatools, mssql-scripter) aus SSMS_GenerateScripts_Anleitung.md."

notes:
  - "Dieses Skript aendert die Datenbankeigenschaften (EMERGENCY, READ_ONLY), fuehrt aber KEIN DBCC CHECKDB REPAIR_ALLOW_DATA_LOSS und KEINE eigene Objekt-Extraktion durch - es ist NICHT identisch mit SuspectDatabaseRepairWithoutBackup.sql oder SuspectDatabaseScriptSchemaOnly.sql."
  - "Ob SSMS Generate Scripts (bzw. SMO/dbatools/mssql-scripter) im EMERGENCY-Modus tatsaechlich erfolgreich durchlaeuft, haengt davon ab, ob die benoetigten Metadaten-Seiten selbst beschaedigt sind. SMO fragt Objekte i.d.R. pauschal je Objekttyp ab (nicht objektweise mit TRY/CATCH wie SuspectDatabaseScriptSchemaOnly.sql) und kann daher beim ersten beschaedigten Objekt komplett abbrechen, statt nur dieses eine Objekt auszulassen."
  - "Bricht Generate Scripts/SMO wegen beschaedigter Metadaten ab, ist SuspectDatabaseScriptSchemaOnly.sql (objektweise TRY/CATCH-Extraktion direkt ueber Systemkataloge) der robustere Fallback."
  - "Siehe SSMS_GenerateScripts_Anleitung.md Abschnitt 3.1 fuer die Einschraenkungen des Wizards bei nicht vollstaendig lesbaren Datenbanken, und Abschnitt 7 fuer die programmatischen Alternativen (SMO/PowerShell, dbatools Export-DbaScript, mssql-scripter, sqlpackage)."
  - "Solange @ConfirmEmergencyReadOnly = 0 ist, aendert das Skript nichts an der Datenbank."
  - "Nach Abschluss sollte die Datenbank NICHT dauerhaft im EMERGENCY-Modus verbleiben; sie kann nach erfolgreicher Schema-Extraktion verworfen und aus dem generierten Skript neu aufgebaut werden (DROP DATABASE + CREATE DATABASE + generiertes Skript)."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

-- 1. Parameter vorbereiten
DECLARE @TargetDatabaseName SYSNAME = N'BI_DQ';
DECLARE @ConfirmEmergencyReadOnly BIT = 0;

IF @TargetDatabaseName IS NULL OR LTRIM(RTRIM(@TargetDatabaseName)) = N''
BEGIN
    THROW 50000, '@TargetDatabaseName darf nicht leer sein.', 1;
END;

IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = @TargetDatabaseName)
BEGIN
    THROW 50001, 'Die angegebene Datenbank wurde nicht in sys.databases gefunden.', 1;
END;

IF @ConfirmEmergencyReadOnly IS NULL OR @ConfirmEmergencyReadOnly NOT IN (0, 1)
BEGIN
    THROW 50002, '@ConfirmEmergencyReadOnly muss 0 oder 1 sein.', 1;
END;

-- 2. Vorab-Status anzeigen (rein lesend)
SELECT
    d.name                    AS DatabaseName,
    d.database_id             AS DatabaseId,
    d.state_desc              AS StateDesc,
    d.recovery_model_desc     AS RecoveryModel,
    d.user_access_desc        AS UserAccessDesc,
    d.is_read_only            AS IsReadOnly,
    @ConfirmEmergencyReadOnly AS ConfirmEmergencyReadOnlyFlag
FROM sys.databases AS d
WHERE d.name = @TargetDatabaseName;

IF @ConfirmEmergencyReadOnly <> 1
BEGIN
    PRINT N'@ConfirmEmergencyReadOnly = 0: Es wurde nichts an der Datenbank geaendert. Zum Wechsel nach EMERGENCY + READ_ONLY @ConfirmEmergencyReadOnly auf 1 setzen.';
    RETURN;
END;

-- 3. Datenbank NUR in EMERGENCY + READ_ONLY versetzen (kein REPAIR, kein SINGLE_USER WITH ROLLBACK IMMEDIATE)
DECLARE @Sql NVARCHAR(MAX);

PRINT N'Versetze ' + QUOTENAME(@TargetDatabaseName) + N' in EMERGENCY + READ_ONLY, um die Datenbank fuer Generate Scripts lesbar zu machen (keine Reparatur, keine Datenaenderung).';

SET @Sql = N'ALTER DATABASE ' + QUOTENAME(@TargetDatabaseName) + N' SET EMERGENCY;';
EXEC sp_executesql @Sql;

BEGIN TRY
    SET @Sql = N'ALTER DATABASE ' + QUOTENAME(@TargetDatabaseName) + N' SET READ_ONLY;';
    EXEC sp_executesql @Sql;
END TRY
BEGIN CATCH
    PRINT N'Hinweis: SET READ_ONLY schlug fehl (' + ERROR_MESSAGE() + N'). Fahre trotzdem im EMERGENCY-Modus fort.';
END CATCH;

-- 4. Ergebnis pruefen
SELECT
    d.name                AS DatabaseName,
    d.database_id         AS DatabaseId,
    d.state_desc          AS StateDesc,
    d.recovery_model_desc AS RecoveryModel,
    d.user_access_desc    AS UserAccessDesc,
    d.is_read_only        AS IsReadOnly
FROM sys.databases AS d
WHERE d.name = @TargetDatabaseName;

-- 5. Naechster Schritt: Schema-Extraktion NICHT hier im Skript, sondern ueber
--    SSMS Generate Scripts bzw. eine der programmatischen Alternativen ausfuehren.
PRINT N'--------------------------------------------------------------------------------';
PRINT N'Datenbank ' + QUOTENAME(@TargetDatabaseName) + N' steht jetzt (falls erfolgreich) in EMERGENCY + READ_ONLY.';
PRINT N'Naechster Schritt: Schema jetzt per SSMS "Generate Scripts" sichern.';
PRINT N'  1. Im Objekt-Explorer Rechtsklick auf ' + QUOTENAME(@TargetDatabaseName) + N' -> Tasks -> Generate Scripts...';
PRINT N'  2. "Script entire database and all database objects" waehlen.';
PRINT N'  3. Unter "Set Scripting Options" -> Advanced ggf. Indexes, Triggers, Permissions,';
PRINT N'     Extended Properties und Users mit aktivieren (im SMO-Default oft ausgeschaltet).';
PRINT N'  4. Ergebnis als EINE zusammenhaengende .sql-Datei speichern (nicht "One file per object"),';
PRINT N'     um die Objektreihenfolge zu erhalten - siehe SSMS_GenerateScripts_Anleitung.md Abschnitt 6.4.';
PRINT N'';
PRINT N'Alternativ programmatisch ohne GUI (z.B. fuer Automatisierung): SMO/PowerShell,';
PRINT N'dbatools Export-DbaScript oder mssql-scripter - siehe SSMS_GenerateScripts_Anleitung.md Abschnitt 7.';
PRINT N'';
PRINT N'Falls Generate Scripts/SMO wegen beschaedigter Metadaten abbricht: SuspectDatabaseScriptSchemaOnly.sql';
PRINT N'als Fallback verwenden (liest Systemkataloge objektweise mit TRY/CATCH aus, bricht bei';
PRINT N'einem beschaedigten Objekt nicht komplett ab).';
PRINT N'--------------------------------------------------------------------------------';
