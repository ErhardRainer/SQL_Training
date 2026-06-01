/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "RecoveryModelSimpleFullWhy_AllDB.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "19_Transaktions"

purpose: >
  Zeigt fuer eine einzelne Datenbank detaillierte Log-Statistiken aus
  sys.dm_db_log_stats: Log-Groesse, Belegung, log_reuse_wait_desc,
  log_truncation_holdup_reason sowie Zeit und Groesse seit dem letzten
  Log-Backup. Dient zur Ursachenanalyse bei Log-Wachstum oder hohen
  Reuse-Wait-Zeiten.

parameters:
  - name: "@DBName"
    sql_type: "SYSNAME"
    direction: "IN"
    required: true
    description: "Name der zu analysierenden Datenbank"

result_sets:
  - name: "LogStats"
    description: "Log-Statistiken der angegebenen Datenbank aus sys.dm_db_log_stats"

dependencies:
  - "sys.databases"
  - "sys.dm_db_log_stats"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/19_Transaktions/SQLScripts/RecoveryModelSimpleFullWhy_AllDB.md"
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
    date: "2026-04-21"
    user: "ER"
    description: "Erstversion"

notes:
  - "sys.dm_db_log_stats erfordert mindestens SQL Server 2016 SP2 / 2017"
  - "log_truncation_holdup_reason ist aussagekraeftiger als log_reuse_wait_desc bei neueren Versionen"
---
END:SQL-HEADER v1
*/

DECLARE @DBName SYSNAME = N'BI_DWH';

SELECT
    d.name AS DatabaseName,
    d.state_desc,
    d.recovery_model_desc,
    ls.total_log_size_mb,
    ls.active_log_size_mb,
    CAST(
        CASE
            WHEN ls.total_log_size_mb > 0
                THEN (ls.active_log_size_mb * 100.0) / ls.total_log_size_mb
            ELSE 0
        END
        AS DECIMAL(10,2)
    ) AS LogUsedPct,
    d.log_reuse_wait_desc,
    ls.log_truncation_holdup_reason,
    ls.log_since_last_log_backup_mb,
    ls.log_backup_time
FROM sys.databases AS d
CROSS APPLY sys.dm_db_log_stats(d.database_id) AS ls
WHERE d.name = @DBName;