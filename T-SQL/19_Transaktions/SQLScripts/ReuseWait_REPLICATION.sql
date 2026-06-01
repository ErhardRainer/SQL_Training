/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "ReuseWait_REPLICATION.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "19_Transaktions"

purpose: >
  Zeigt alle Datenbanken, bei denen log_reuse_wait_desc den Wert REPLICATION
  hat. Replikation haelt Log-Eintraege solange fest, bis der Log-Reader-Agent
  sie verarbeitet hat. Das Skript listet betroffene DBs mit Log-Groesse,
  Belegung und Hinweisen zum weiteren Vorgehen.

parameters: []

result_sets:
  - name: "ReplicationLogWait"
    description: "Datenbanken mit log_reuse_wait_desc = REPLICATION samt Log-Groesse und Handlungshinweis"

dependencies:
  - "sys.databases"
  - "sys.dm_db_log_stats"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/19_Transaktions/SQLScripts/ReuseWait_REPLICATION.md"
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
    description: "Erstversion; Platzhalter-Datei mit Inhalt und Header versehen"

notes:
  - "REPLICATION als Reuse-Wait-Grund tritt auf, wenn der Log-Reader-Agent rueckstaendig oder gestoppt ist"
  - "Loesung: Log-Reader-Agent-Status pruefen (sp_helpsubscription, Replikationsmonitor) und ggf. neu starten"
  - "sys.dm_db_log_stats erfordert mindestens SQL Server 2016 SP2 / 2017"
---
END:SQL-HEADER v1
*/

SELECT
    d.name                              AS DatabaseName,
    d.recovery_model_desc               AS RecoveryModel,
    d.log_reuse_wait_desc               AS LogReuseWaitDesc,
    ls.total_log_size_mb                AS LogSizeMB,
    ls.active_log_size_mb               AS ActiveLogMB,
    CAST(
        CASE
            WHEN ls.total_log_size_mb > 0
                THEN (ls.active_log_size_mb * 100.0) / ls.total_log_size_mb
            ELSE 0
        END
        AS DECIMAL(10,2)
    )                                   AS LogUsedPct,
    ls.log_truncation_holdup_reason     AS TruncationHoldupReason,
    N'Log-Reader-Agent pruefen: ist der Agent aktiv und verarbeitet Transaktionen? '
    + N'Ggf. sp_helpsubscription / Replikationsmonitor verwenden.'
                                        AS Handlungshinweis
FROM sys.databases AS d
CROSS APPLY sys.dm_db_log_stats(d.database_id) AS ls
WHERE d.log_reuse_wait_desc = N'REPLICATION'
  AND d.state_desc = N'ONLINE'
ORDER BY
    ls.active_log_size_mb DESC,
    d.name;
