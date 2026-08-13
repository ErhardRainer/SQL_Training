/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "DatabaseStatusOverview.sql"
script_version: "1.0"
script_type: "query"
chapter: "71_BackupRestore_Strategies"
purpose: >
  Gibt den aktuellen Status (state_desc) aller Datenbanken der Instanz aus,
  inklusive Recovery Model, Zugriffsmodus und einer Klartext-Einordnung
  kritischer Zustaende wie RECOVERING, RECOVERY_PENDING oder SUSPECT.

parameters: []

result_sets:
  - name: "DatabaseStatus"
    description: "Status, Recovery Model und Einordnung je Datenbank aus sys.databases"

dependencies:
  - "sys.databases"
  - "CASE"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/71_BackupRestore_Strategies/SQLScripts/DatabaseStatusOverview.md"
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
    description: "Erstversion der Datenbank-Statusuebersicht mit Klartext-Einordnung"

notes:
  - "Reines Leseskript ohne Seiteneffekte; eignet sich auch als Basis fuer ein Monitoring/Alerting nach einem Neustart."
  - "state_desc SUSPECT und RECOVERY_PENDING erfordern manuelles Eingreifen eines DBA."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

SELECT
    d.name                      AS DatabaseName,
    d.database_id               AS DatabaseId,
    d.state_desc                AS StateDesc,
    d.recovery_model_desc       AS RecoveryModel,
    d.user_access_desc          AS UserAccess,
    d.is_read_only              AS IsReadOnly,
    CASE d.state_desc
        WHEN 'ONLINE'          THEN 'OK - Datenbank ist normal verfuegbar.'
        WHEN 'RESTORING'       THEN 'Info - Restore laeuft, Datenbank noch nicht online.'
        WHEN 'RECOVERING'      THEN 'Info - Crash-Recovery laeuft (Analysis/Redo/Undo), i.d.R. temporaer.'
        WHEN 'RECOVERY_PENDING' THEN 'Achtung - Recovery kann nicht starten (z.B. Log fehlt/beschaedigt oder Ressourcenproblem); DBA muss Ursache beheben.'
        WHEN 'SUSPECT'         THEN 'Kritisch - Recovery fehlgeschlagen, Datenbank moeglicherweise inkonsistent; manueller Eingriff/Restore noetig.'
        WHEN 'EMERGENCY'       THEN 'Achtung - Datenbank manuell in den EMERGENCY-Modus versetzt (nur lesend, meist zur Reparatur).'
        WHEN 'OFFLINE'         THEN 'Info - Datenbank ist bewusst offline gesetzt.'
        WHEN 'COPYING'         THEN 'Info - Datenbank wird gerade kopiert (z.B. Azure SQL).'
        ELSE 'Unbekannter Status - bitte state_desc pruefen.'
    END                          AS StatusExplanation
FROM sys.databases AS d
ORDER BY
    CASE d.state_desc
        WHEN 'SUSPECT'          THEN 0
        WHEN 'RECOVERY_PENDING' THEN 1
        WHEN 'EMERGENCY'        THEN 2
        WHEN 'RECOVERING'       THEN 3
        WHEN 'RESTORING'        THEN 4
        WHEN 'OFFLINE'          THEN 5
        ELSE 6
    END,
    d.name;
