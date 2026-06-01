/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "ListAllCriticalTransactionLogs.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "19_Transaktions"

purpose: >
  Listet nur jene Datenbanken, bei denen der Transaction-Log-Verbrauch bei
  mindestens 85 % liegt. Dient als schneller Ueberblick ueber kritische
  Log-Fuellstaende quer ueber alle Datenbanken.

parameters: []

result_sets:
  - name: "CriticalLogs"
    description: "Datenbanken mit Log-Belegung >= 85 % sortiert nach Belegung absteigend"

dependencies:
  - "DBCC SQLPERF(LOGSPACE)"
  - "sys.databases"
  - "tempdb temporary tables"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/19_Transaktions/SQLScripts/ListAllCriticalTransactionLogs.md"
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
  - "Schwelle von 85 % ist hart kodiert; bei Bedarf in einen Parameter auslagern"
  - "DBCC SQLPERF liefert nur DB-weite Aggregatwerte, keine Datei-Einzelansicht"
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
    d.recovery_model_desc AS RecoveryModel,
    CAST(ls.[Log Size (MB)] AS DECIMAL(18,2)) AS LogSizeMB,
    CAST(ls.[Log Space Used (%)] AS DECIMAL(18,2)) AS LogUsedPct,
    d.log_reuse_wait_desc
FROM #LogSpace AS ls
INNER JOIN sys.databases AS d
    ON d.name = ls.[Database Name]
WHERE ls.[Log Space Used (%)] >= 85
ORDER BY ls.[Log Space Used (%)] DESC;