/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "ListTransactionLogs.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "19_Transaktions"

purpose: >
  Listet alle Transaction-Log-Dateien aller Datenbanken mit Groesse, Belegung,
  freiem Speicher, log_reuse_wait_desc und einer einfachen Statusklassifikation
  (OK / BEOBACHTEN / HOCH / KRITISCH) auf Basis des prozentualen Log-Verbrauchs.

parameters: []

result_sets:
  - name: "LogSpaceOverview"
    description: "Alle Datenbanken mit Log-Groesse, Belegung, freiem Speicher und Statusklasse"

dependencies:
  - "DBCC SQLPERF(LOGSPACE)"
  - "sys.databases"
  - "tempdb temporary tables"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/19_Transaktions/SQLScripts/ListTransactionLogs.md"
  sync_blocks:
    - "SUMMARY_TABLE"
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
    date: "2026-04-21"
    user: "ER"
    description: "Erstversion"

notes:
  - "DBCC SQLPERF(LOGSPACE) liefert DB-weit aggregierte Werte, keine Einzeldatei-Aufloesung"
  - "Statusklassen basieren auf fixen Schwellen; diese koennen je Umgebung abweichen"
---
END:SQL-HEADER v1
*/

IF OBJECT_ID('tempdb..#LogSpace') IS NOT NULL
    DROP TABLE #LogSpace;

CREATE TABLE #LogSpace
(
    [Database Name]      SYSNAME,
    [Log Size (MB)]      DECIMAL(18,2),
    [Log Space Used (%)] DECIMAL(18,2),
    [Status]             INT
);

INSERT INTO #LogSpace
EXEC ('DBCC SQLPERF(LOGSPACE)');

SELECT
    ls.[Database Name] AS DatabaseName,
    d.state_desc AS DatabaseState,
    d.recovery_model_desc AS RecoveryModel,
    CAST(ls.[Log Size (MB)] AS DECIMAL(18,2)) AS LogSizeMB,
    CAST(ls.[Log Space Used (%)] AS DECIMAL(18,2)) AS LogUsedPct,
    CAST(ls.[Log Size (MB)] * ls.[Log Space Used (%)] / 100.0 AS DECIMAL(18,2)) AS LogUsedMB,
    CAST(ls.[Log Size (MB)] * (100.0 - ls.[Log Space Used (%)]) / 100.0 AS DECIMAL(18,2)) AS LogFreeMB,
    d.log_reuse_wait_desc,
    CASE
        WHEN ls.[Log Space Used (%)] >= 95 THEN 'KRITISCH'
        WHEN ls.[Log Space Used (%)] >= 85 THEN 'HOCH'
        WHEN ls.[Log Space Used (%)] >= 70 THEN 'BEOBACHTEN'
        ELSE 'OK'
    END AS LogStatus
FROM #LogSpace AS ls
LEFT JOIN sys.databases AS d
    ON d.name = ls.[Database Name]
ORDER BY
    ls.[Log Space Used (%)] DESC,
    ls.[Log Size (MB)] DESC;