/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "SuspectOrRecoveryPendingDatabaseRootCauseCheck.sql"
script_version: "2.5"
script_type: "diagnostic"
chapter: "71_BackupRestore_Strategies"
purpose: >
  Unterstuetzt die Ursachenanalyse, wenn eine oder mehrere Datenbanken einen
  kritischen Status zeigen. Ohne Angabe eines Datenbanknamens ermittelt das
  Skript selbststaendig alle Datenbanken, deren state_desc in @TargetStates
  enthalten ist (Default: SUSPECT, RECOVERY_PENDING, EMERGENCY; wahlweise
  z.B. nur SUSPECT oder nur RECOVERY_PENDING), und durchlaeuft fuer jede
  davon Dateizugriff/-existenz, freien Speicherplatz auf den zugehoerigen
  Laufwerken, bekannte Suspect Pages (moegliche Korruption) sowie die
  juengsten Errorlog-Eintraege, um typische Ursachen (fehlendes/beschaedigtes
  Log, voller Datentraeger, Seitenkorruption, Zugriffsproblem) sichtbar zu
  machen.

parameters:
  - name: "@TargetDatabaseName"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Name einer einzelnen zu untersuchenden Datenbank; NULL (Default) untersucht automatisch alle Datenbanken mit Status gemaess @TargetStates"
  - name: "@TargetStates"
    sql_type: "NVARCHAR(400)"
    direction: "IN"
    required: false
    description: "Kommagetrennte Liste der zu beruecksichtigenden state_desc-Werte (z.B. 'SUSPECT,RECOVERY_PENDING'); wird nur beachtet, wenn @TargetDatabaseName NULL ist. NULL/leer (Default) = 'SUSPECT,RECOVERY_PENDING,EMERGENCY'"
  - name: "@ErrorLogEntriesToScan"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Anzahl der juengsten Errorlog-Eintraege je Datenbank, die nach dem Datenbanknamen durchsucht werden (Default 200)"

result_sets:
  - name: "AffectedDatabases"
    description: "Alle Datenbanken, die in diesem Lauf untersucht wurden, mit Status, Recovery Model und Zugriffsmodus"
  - name: "DatabaseFileCheck"
    description: "Je untersuchter Datenbank und Datenbankdatei: Pfad, existiert die Datei (per sys.dm_os_file_exists), Dateityp und Groesse laut Metadaten"
  - name: "VolumeFreeSpaceCheck"
    description: "Freier Speicherplatz je Laufwerk, auf dem Datenbankdateien der untersuchten Datenbanken liegen (sys.dm_os_volume_stats)"
  - name: "SuspectPagesCheck"
    description: "Eintraege aus msdb.dbo.suspect_pages fuer die untersuchten Datenbanken als Hinweis auf Seitenkorruption"
  - name: "ErrorLogFindings"
    description: "Juengste Errorlog-Eintraege je Datenbank, die den Datenbanknamen erwaehnen (z.B. Recovery-, IO- oder Startup-Meldungen)"
  - name: "RootCauseSummary"
    description: "Verdichtete Einschaetzung moeglicher Ursachen je Datenbank basierend auf den vorherigen Pruefungen"

dependencies:
  - "sys.databases"
  - "sys.master_files"
  - "sys.dm_os_volume_stats"
  - "msdb.dbo.suspect_pages"
  - "sys.dm_os_file_exists"
  - "sp_readerrorlog"
  - "STRING_SPLIT"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/71_BackupRestore_Strategies/SQLScripts/SuspectOrRecoveryPendingDatabaseRootCauseCheck.md"
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
    description: "Erstversion der Root-Cause-Analyse fuer SUSPECT/RECOVERY_PENDING Datenbanken (ein Datenbankname als Pflichtparameter)"
  - version: "1.1"
    date: "2026-08-13"
    user: "ER"
    description: "Zusaetzlicher RootCauseSummary-Hinweis, wenn sys.dm_os_volume_stats keine Zeile liefert (Datei aktuell nicht geoeffnet)"
  - version: "2.0"
    date: "2026-08-13"
    user: "ER"
    description: "@TargetDatabaseName ist jetzt optional; ohne Angabe ermittelt das Skript automatisch alle Datenbanken mit Status SUSPECT, RECOVERY_PENDING oder EMERGENCY und durchlaeuft die Diagnose je Datenbank per WHILE-Schleife"
  - version: "2.1"
    date: "2026-08-13"
    user: "ER"
    description: "GO nach dem Vorbereitungsblock ergaenzt, um 'Invalid column name' durch verfruehte Deferred-Name-Resolution im grossen Batch zu vermeiden; Parameter werden dafuer ueber eine #ScriptParams-Tabelle batch-uebergreifend gehalten"
  - version: "2.2"
    date: "2026-08-13"
    user: "ER"
    description: "Neuer Parameter @TargetStates erlaubt die gezielte Auswahl der zu beruecksichtigenden state_desc-Werte (z.B. nur SUSPECT oder nur RECOVERY_PENDING) statt der fest verdrahteten Kombination aus SUSPECT/RECOVERY_PENDING/EMERGENCY"
  - version: "2.3"
    date: "2026-08-13"
    user: "ER"
    description: "COLLATE DATABASE_DEFAULT beim Vergleich von sys.databases.state_desc gegen #TargetStates ergaenzt, um einen Collation-Konflikt (Msg 468) zwischen Server-/DB-Collation und der tempdb-Collation zu vermeiden"
  - version: "2.4"
    date: "2026-08-13"
    user: "ER"
    description: "NextStep fuer den Volume-Freiraum-Hinweis (Check 4) enthaelt jetzt den konkreten PowerShell-Befehl (Get-Volume -DriveLetter) und den passenden CMD-Befehl (fsutil volume diskfree) mit dem tatsaechlichen Laufwerksbuchstaben der betroffenen Datei"
  - version: "2.5"
    date: "2026-08-13"
    user: "ER"
    description: "NextStep fuer Seitenkorruption (Check 3) listet jetzt explizit die drei konkreten Optionen auf: (1) vollstaendiger DB-Restore aus Backup-Kette, (2) Page Restore nur der betroffenen Seiten aus Backup, (3) DBCC CHECKDB WITH REPAIR_ALLOW_DATA_LOSS als letzte, datenverlustbehaftete Notloesung ohne Backup; NextStep-Spalte auf VARCHAR(600) vergroessert"

notes:
  - "Reines Leseskript; es fuehrt keine Reparatur (kein SET EMERGENCY, kein CHECKDB REPAIR) durch."
  - "sys.dm_os_file_exists und sp_readerrorlog erfordern sysadmin- bzw. ausreichende Serverrechte."
  - "sys.dm_os_volume_stats liefert nur Werte fuer Dateien, die SQL Server aktuell oeffnen kann; bei komplett fehlendem Volume oder einer nicht geoeffneten Datei (z.B. bei SUSPECT) kann die Abfrage leer bleiben - RootCauseSummary weist in diesem Fall explizit darauf hin."
  - "Der Auto-Discovery-Modus (@TargetDatabaseName IS NULL) durchlaeuft die betroffenen Datenbanken sequenziell per WHILE-Schleife, da sp_readerrorlog und die Dateipruefungen je Datenbank ausgefuehrt werden muessen."
  - "Das Skript enthaelt bewusst ein GO zwischen Vorbereitung und Cursor-Block; lokale Variablen (@TargetDatabaseName, @ErrorLogEntriesToScan) werden deshalb vor dem GO ausschliesslich gelesen bzw. in #ScriptParams gesichert, da sie nach GO nicht mehr existieren."
  - "Der Vergleich von sys.databases.state_desc gegen die Werte aus #TargetStates verwendet bewusst COLLATE DATABASE_DEFAULT auf beiden Seiten, da #temp-Tabellen die tempdb-Collation erben, die von der Server-/Datenbank-Collation abweichen kann (Msg 468 'Cannot resolve the collation conflict')."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

-- 1. Parameter vorbereiten
DECLARE @TargetDatabaseName SYSNAME = NULL;
DECLARE @TargetStates NVARCHAR(400) = NULL;
DECLARE @ErrorLogEntriesToScan INT = 200;

IF @TargetDatabaseName IS NOT NULL AND LTRIM(RTRIM(@TargetDatabaseName)) = N''
BEGIN
    THROW 50000, '@TargetDatabaseName darf, wenn angegeben, nicht leer sein.', 1;
END;

IF @ErrorLogEntriesToScan IS NULL OR @ErrorLogEntriesToScan <= 0
BEGIN
    THROW 50001, '@ErrorLogEntriesToScan muss ein positiver Wert sein.', 1;
END;

IF @TargetDatabaseName IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = @TargetDatabaseName)
BEGIN
    THROW 50002, 'Die angegebene Datenbank wurde nicht in sys.databases gefunden.', 1;
END;

-- @TargetStates: NULL/leer bedeutet das Standard-Set; wird nur beachtet, wenn @TargetDatabaseName NULL ist.
IF @TargetDatabaseName IS NULL AND (@TargetStates IS NULL OR LTRIM(RTRIM(@TargetStates)) = N'')
BEGIN
    SET @TargetStates = N'SUSPECT,RECOVERY_PENDING,EMERGENCY';
END;

IF @TargetDatabaseName IS NULL AND EXISTS (
    SELECT 1
    FROM STRING_SPLIT(@TargetStates, N',') AS s
    WHERE UPPER(LTRIM(RTRIM(s.value))) NOT IN (N'SUSPECT', N'RECOVERY_PENDING', N'EMERGENCY', N'RESTORING', N'RECOVERING', N'OFFLINE', N'COPYING', N'ONLINE')
)
BEGIN
    THROW 50003, '@TargetStates enthaelt einen unbekannten state_desc-Wert. Gueltig sind z.B. SUSPECT, RECOVERY_PENDING, EMERGENCY, RESTORING, RECOVERING, OFFLINE, COPYING, ONLINE.', 1;
END;

DROP TABLE IF EXISTS #ScriptParams;
DROP TABLE IF EXISTS #TargetStates;
DROP TABLE IF EXISTS #AffectedDatabases;
DROP TABLE IF EXISTS #FileCheck;
DROP TABLE IF EXISTS #VolumeCheck;
DROP TABLE IF EXISTS #SuspectPagesCheck;
DROP TABLE IF EXISTS #ErrorLogFindings;
DROP TABLE IF EXISTS #RootCauseSummary;

-- Parameter batch-uebergreifend verfuegbar halten (noetig wegen GO vor dem Cursor-Block).
CREATE TABLE #ScriptParams
(
    ErrorLogEntriesToScan INT NOT NULL
);
INSERT INTO #ScriptParams (ErrorLogEntriesToScan) VALUES (@ErrorLogEntriesToScan);

CREATE TABLE #TargetStates
(
    StateDesc NVARCHAR(60) NOT NULL
);

IF @TargetDatabaseName IS NULL
BEGIN
    INSERT INTO #TargetStates (StateDesc)
    SELECT DISTINCT UPPER(LTRIM(RTRIM(s.value)))
    FROM STRING_SPLIT(@TargetStates, N',') AS s
    WHERE LTRIM(RTRIM(s.value)) <> N'';
END;

-- 2. Zu untersuchende Datenbanken ermitteln:
--    ohne @TargetDatabaseName automatisch alle mit Status gemaess @TargetStates,
--    sonst nur die explizit angegebene Datenbank (unabhaengig von ihrem Status).
CREATE TABLE #AffectedDatabases
(
    DatabaseId       INT           NOT NULL,
    DatabaseName     SYSNAME       NOT NULL,
    StateDesc        NVARCHAR(60)  NOT NULL,
    RecoveryModel    NVARCHAR(60)  NULL,
    UserAccessDesc   NVARCHAR(60)  NULL
);

INSERT INTO #AffectedDatabases (DatabaseId, DatabaseName, StateDesc, RecoveryModel, UserAccessDesc)
SELECT
    d.database_id,
    d.name,
    d.state_desc,
    d.recovery_model_desc,
    d.user_access_desc
FROM sys.databases AS d
WHERE (@TargetDatabaseName IS NULL AND d.state_desc COLLATE DATABASE_DEFAULT IN (SELECT ts.StateDesc COLLATE DATABASE_DEFAULT FROM #TargetStates AS ts))
   OR (@TargetDatabaseName IS NOT NULL AND d.name = @TargetDatabaseName);

-- 3. Ergebnistabellen fuer alle untersuchten Datenbanken vorbereiten
CREATE TABLE #FileCheck
(
    DatabaseName    SYSNAME       NOT NULL,
    FileId          INT           NOT NULL,
    LogicalName     SYSNAME       NOT NULL,
    PhysicalName    NVARCHAR(260) NOT NULL,
    FileTypeDesc    NVARCHAR(60)  NOT NULL,
    SizeMB          DECIMAL(18,2) NOT NULL,
    FileExists      BIT           NULL,
    IsDirectory     BIT           NULL,
    ParentDirExists BIT           NULL
);

CREATE TABLE #VolumeCheck
(
    DatabaseName         SYSNAME       NOT NULL,
    LogicalName          SYSNAME       NOT NULL,
    VolumeMountPoint     NVARCHAR(260) NULL,
    TotalSizeGB          DECIMAL(18,2) NULL,
    AvailableFreeSpaceGB DECIMAL(18,2) NULL
);

CREATE TABLE #SuspectPagesCheck
(
    DatabaseName         SYSNAME       NOT NULL,
    file_id              INT           NOT NULL,
    page_id              BIGINT        NOT NULL,
    EventTypeDescription VARCHAR(60)   NOT NULL,
    error_count          INT           NOT NULL,
    last_update_date     DATETIME      NOT NULL
);

CREATE TABLE #ErrorLogFindings
(
    DatabaseName SYSNAME       NOT NULL,
    LogDate      DATETIME      NULL,
    ProcessInfo  NVARCHAR(50)  NULL,
    LogText      NVARCHAR(MAX) NULL
);

DROP TABLE IF EXISTS #ErrorLogFindingsRaw;
CREATE TABLE #ErrorLogFindingsRaw
(
    LogDate     DATETIME      NULL,
    ProcessInfo NVARCHAR(50)  NULL,
    LogText     NVARCHAR(MAX) NULL
);

CREATE TABLE #RootCauseSummary
(
    DatabaseName SYSNAME       NOT NULL,
    CheckOrder   INT           NOT NULL,
    CheckName    VARCHAR(60)   NOT NULL,
    Finding      VARCHAR(400)  NOT NULL,
    Severity     VARCHAR(10)   NOT NULL,
    NextStep     VARCHAR(600)  NOT NULL
);
GO

-- 4. Je betroffener Datenbank die Diagnose durchlaufen
DECLARE @CurrentDatabaseId INT;
DECLARE @CurrentDatabaseName SYSNAME;

DECLARE DatabaseCursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT DatabaseId, DatabaseName FROM #AffectedDatabases ORDER BY DatabaseName;

OPEN DatabaseCursor;
FETCH NEXT FROM DatabaseCursor INTO @CurrentDatabaseId, @CurrentDatabaseName;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- 4a. Datenbankdateien pruefen: existiert die Datei physisch noch?
    INSERT INTO #FileCheck (DatabaseName, FileId, LogicalName, PhysicalName, FileTypeDesc, SizeMB, FileExists, IsDirectory, ParentDirExists)
    SELECT
        @CurrentDatabaseName,
        mf.file_id,
        mf.name,
        mf.physical_name,
        mf.type_desc,
        CAST(mf.size * 8.0 / 1024 AS DECIMAL(18,2)),
        fe.file_exists,
        fe.file_is_a_directory,
        fe.parent_directory_exists
    FROM sys.master_files AS mf
    CROSS APPLY sys.dm_os_file_exists(mf.physical_name) AS fe
    WHERE mf.database_id = @CurrentDatabaseId;

    -- 4b. Freien Speicherplatz je betroffenem Laufwerk pruefen (typische Ursache: voller Datentraeger)
    INSERT INTO #VolumeCheck (DatabaseName, LogicalName, VolumeMountPoint, TotalSizeGB, AvailableFreeSpaceGB)
    SELECT
        @CurrentDatabaseName,
        mf.name,
        vs.volume_mount_point,
        CAST(vs.total_bytes / 1024.0 / 1024 / 1024 AS DECIMAL(18,2)),
        CAST(vs.available_bytes / 1024.0 / 1024 / 1024 AS DECIMAL(18,2))
    FROM sys.master_files AS mf
    CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.file_id) AS vs
    WHERE mf.database_id = @CurrentDatabaseId;

    -- 4c. Bekannte Suspect Pages (Hinweis auf Seitenkorruption statt reinem Zugriffsproblem)
    INSERT INTO #SuspectPagesCheck (DatabaseName, file_id, page_id, EventTypeDescription, error_count, last_update_date)
    SELECT
        @CurrentDatabaseName,
        sp.file_id,
        sp.page_id,
        CASE sp.event_type
            WHEN 1 THEN '823/824: Bad checksum oder Torn Page'
            WHEN 2 THEN '823: Bad Page ID'
            WHEN 3 THEN 'Nicht behebbarer Hardware-I/O-Fehler'
            WHEN 4 THEN 'Page wurde per DBCC/Restore als korrekt bestaetigt'
            WHEN 5 THEN 'Deallociert per Repair'
            WHEN 7 THEN 'Ueber Restore-Vorgang repariert'
            ELSE 'Sonstiges'
        END,
        sp.error_count,
        sp.last_update_date
    FROM msdb.dbo.suspect_pages AS sp
    WHERE sp.database_id = @CurrentDatabaseId;

    -- 4d. Errorlog nach Eintraegen zur aktuellen Datenbank durchsuchen
    TRUNCATE TABLE #ErrorLogFindingsRaw;

    INSERT INTO #ErrorLogFindingsRaw (LogDate, ProcessInfo, LogText)
    EXEC sp_readerrorlog 0, 1, @CurrentDatabaseName;

    INSERT INTO #ErrorLogFindings (DatabaseName, LogDate, ProcessInfo, LogText)
    SELECT @CurrentDatabaseName, LogDate, ProcessInfo, LogText
    FROM #ErrorLogFindingsRaw;

    FETCH NEXT FROM DatabaseCursor INTO @CurrentDatabaseId, @CurrentDatabaseName;
END;

CLOSE DatabaseCursor;
DEALLOCATE DatabaseCursor;

DROP TABLE IF EXISTS #ErrorLogFindingsRaw;

-- 5. Ursachen-Zusammenfassung je Datenbank ableiten
INSERT INTO #RootCauseSummary (DatabaseName, CheckOrder, CheckName, Finding, Severity, NextStep)
SELECT
    fc.DatabaseName,
    1,
    'Fehlende/nicht erreichbare Datei',
    CONCAT('Datei fehlt oder ist nicht erreichbar: ', fc.PhysicalName, ' (', fc.FileTypeDesc, ')'),
    'high',
    'Datei am gemeldeten Pfad wiederherstellen, Laufwerksbuchstabe/Freigabe pruefen oder Datenbank aus Backup restoren.'
FROM #FileCheck AS fc
WHERE fc.FileExists = 0 OR fc.ParentDirExists = 0;

INSERT INTO #RootCauseSummary (DatabaseName, CheckOrder, CheckName, Finding, Severity, NextStep)
SELECT
    vc.DatabaseName,
    2,
    'Speicherplatz auf Datentraeger',
    CONCAT('Nur noch ', vc.AvailableFreeSpaceGB, ' GB frei auf dem Volume von ', vc.LogicalName, ' (', vc.VolumeMountPoint, ').'),
    CASE WHEN vc.AvailableFreeSpaceGB < 1 THEN 'high' ELSE 'medium' END,
    'Speicherplatz freigeben (alte Backups/Logs verschieben) oder Datei auf ein Laufwerk mit mehr Platz verlegen, dann Recovery/Restore erneut versuchen.'
FROM #VolumeCheck AS vc
WHERE vc.AvailableFreeSpaceGB IS NOT NULL AND vc.AvailableFreeSpaceGB < 5;

INSERT INTO #RootCauseSummary (DatabaseName, CheckOrder, CheckName, Finding, Severity, NextStep)
SELECT
    sp.DatabaseName,
    3,
    'Seitenkorruption (Suspect Pages)',
    CONCAT('msdb.dbo.suspect_pages enthaelt ', COUNT(*), ' Eintrag/Eintraege fuer diese Datenbank.'),
    'high',
    'DBCC CHECKDB ausfuehren, dann je nach Backup-Lage: (1) Vollstaendiger Restore der kompletten DB aus Full-/Diff-/Log-Backup-Kette - sicherste Option, aber laengste Downtime. (2) Page Restore nur der betroffenen Seiten aus Backup (RESTORE DATABASE ... PAGE = ...) - schneller, setzt Full-Backup + luecklose Log-Kette (FULL/BULK_LOGGED Recovery Model) voraus. (3) Ohne brauchbares Backup: DBCC CHECKDB ... WITH REPAIR_ALLOW_DATA_LOSS als letzte Notloesung - entfernt die betroffenen Seiten/Zeilen, bedeutet echten Datenverlust und ist keine Wiederherstellung.'
FROM #SuspectPagesCheck AS sp
GROUP BY sp.DatabaseName
HAVING COUNT(*) > 0;

INSERT INTO #RootCauseSummary (DatabaseName, CheckOrder, CheckName, Finding, Severity, NextStep)
SELECT
    fc.DatabaseName,
    4,
    'Volume-Freiraum nicht ermittelbar',
    CONCAT('sys.dm_os_volume_stats lieferte keine Zeile fuer Datei ', fc.PhysicalName, ' (', fc.FileTypeDesc, '); die Datenbankdatei ist aktuell vermutlich nicht geoeffnet.'),
    'low',
    CONCAT(
        'Freien Speicherplatz auf dem Laufwerk manuell pruefen, da die DMV nur fuer aktuell geoeffnete Dateien Werte liefert. PowerShell: Get-Volume -DriveLetter ''',
        LEFT(fc.PhysicalName, 1),
        '''  |  Alternativ CMD: fsutil volume diskfree ',
        LEFT(fc.PhysicalName, 2)
    )
FROM #FileCheck AS fc
WHERE fc.FileExists = 1
  AND NOT EXISTS (
        SELECT 1 FROM #VolumeCheck AS vc
        WHERE vc.DatabaseName = fc.DatabaseName AND vc.LogicalName = fc.LogicalName
      );

INSERT INTO #RootCauseSummary (DatabaseName, CheckOrder, CheckName, Finding, Severity, NextStep)
SELECT
    ad.DatabaseName,
    5,
    'Fehlende Voraussetzung nicht erkannt',
    'Kein fehlender Dateizugriff, kein knapper Speicherplatz und keine Suspect Pages gefunden.',
    'medium',
    'Errorlog-Eintraege (ErrorLogFindings) im Detail lesen: oft liegt die Ursache in Berechtigungen des Dienstkontos, einem beschaedigten Log-VLF oder einem I/O-Fehler, der nur im Log-Text sichtbar wird.'
FROM #AffectedDatabases AS ad
WHERE NOT EXISTS (SELECT 1 FROM #FileCheck WHERE DatabaseName = ad.DatabaseName AND (FileExists = 0 OR ParentDirExists = 0))
  AND NOT EXISTS (SELECT 1 FROM #VolumeCheck WHERE DatabaseName = ad.DatabaseName AND AvailableFreeSpaceGB IS NOT NULL AND AvailableFreeSpaceGB < 5)
  AND NOT EXISTS (SELECT 1 FROM #SuspectPagesCheck WHERE DatabaseName = ad.DatabaseName);

-- 6. Ergebnisse ausgeben
SELECT
    ad.DatabaseName,
    ad.DatabaseId,
    ad.StateDesc,
    ad.RecoveryModel,
    ad.UserAccessDesc,
    DATABASEPROPERTYEX(ad.DatabaseName, 'IsSuspect')       AS IsSuspectFlag,
    DATABASEPROPERTYEX(ad.DatabaseName, 'IsInRecovery')    AS IsInRecoveryFlag,
    DATABASEPROPERTYEX(ad.DatabaseName, 'IsEmergencyMode') AS IsEmergencyModeFlag
FROM #AffectedDatabases AS ad
ORDER BY
    ad.DatabaseName;

SELECT
    fc.DatabaseName,
    fc.FileId,
    fc.LogicalName,
    fc.PhysicalName,
    fc.FileTypeDesc,
    fc.SizeMB,
    fc.FileExists,
    fc.IsDirectory,
    fc.ParentDirExists
FROM #FileCheck AS fc
ORDER BY
    fc.DatabaseName,
    fc.FileId;

SELECT
    vc.DatabaseName,
    vc.LogicalName,
    vc.VolumeMountPoint,
    vc.TotalSizeGB,
    vc.AvailableFreeSpaceGB
FROM #VolumeCheck AS vc
ORDER BY
    vc.DatabaseName,
    vc.LogicalName;

SELECT
    sp.DatabaseName,
    sp.file_id,
    sp.page_id,
    sp.EventTypeDescription,
    sp.error_count,
    sp.last_update_date
FROM #SuspectPagesCheck AS sp
ORDER BY
    sp.DatabaseName,
    sp.last_update_date DESC;

SELECT
    elf.DatabaseName,
    elf.LogDate,
    elf.ProcessInfo,
    elf.LogText
FROM (
    SELECT
        e.*,
        ROW_NUMBER() OVER (PARTITION BY e.DatabaseName ORDER BY e.LogDate DESC) AS RowNum
    FROM #ErrorLogFindings AS e
) AS elf
WHERE elf.RowNum <= (SELECT ErrorLogEntriesToScan FROM #ScriptParams)
ORDER BY
    elf.DatabaseName,
    elf.LogDate DESC;

SELECT
    rcs.DatabaseName,
    rcs.CheckOrder,
    rcs.CheckName,
    rcs.Finding,
    rcs.Severity,
    rcs.NextStep
FROM #RootCauseSummary AS rcs
ORDER BY
    rcs.DatabaseName,
    rcs.CheckOrder;
