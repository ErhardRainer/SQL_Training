/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "ListLogUsageOfAllDB.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "19_Transaktions"

purpose: >
  Listet alle Log-Dateien aller Online-Datenbanken mit aktueller Groesse,
  DB-weitem Verbrauch, VLF-basierter theoretischer Mindestgroesse und
  maximal moeglichem Shrink-Potenzial. Generiert ausserdem fertige
  DBCC SHRINKFILE- und DBCC SHRINKDATABASE-Befehle zur direkten Verwendung.

parameters: []

result_sets:
  - name: "LogFileOverview"
    description: "Alle Log-Dateien mit Groesse, Belegung, Shrink-Potenzial und generierten Shrink-Befehlen"

dependencies:
  - "DBCC SQLPERF(LOGSPACE)"
  - "sys.databases"
  - "sys.master_files"
  - "sys.dm_db_log_info"
  - "tempdb temporary tables"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/19_Transaktions/SQLScripts/ListLogUsageOfAllDB.md"
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
  - "theoretic_min_size_mb basiert auf dem Ende des letzten aktiven VLF und ist eine untere Schranke, kein garantierter Shrink-Zielwert"
  - "Die generierten Shrink-Befehle sind nur ein Ausgangspunkt; vor der Ausfuehrung Reuse-Wait und aktive Transaktionen pruefen"
  - "sys.dm_db_log_info erfordert mindestens SQL Server 2016"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

IF OBJECT_ID('tempdb..#LogSpace') IS NOT NULL
    DROP TABLE #LogSpace;

CREATE TABLE #LogSpace
(
    [Database Name]   sysname,
    [Log Size (MB)]   decimal(18,2),
    [Log Space Used (%)] decimal(9,2),
    [Status]          int
);

INSERT INTO #LogSpace
EXEC ('DBCC SQLPERF(LOGSPACE)');

;WITH LogFiles AS
(
    SELECT
        d.database_id,
        d.name AS database_name,
        d.recovery_model_desc,
        d.log_reuse_wait_desc,
        mf.file_id,
        mf.name AS logical_log_name,
        mf.physical_name,
        mf.size / 128.0 AS current_size_mb
    FROM sys.databases d
    INNER JOIN sys.master_files mf
        ON mf.database_id = d.database_id
       AND mf.type_desc = 'LOG'
    WHERE d.state_desc = 'ONLINE'
),
ActiveVlfEnd AS
(
    SELECT
        d.database_id,
        li.file_id,
        MAX(
            CASE
                WHEN li.vlf_active = 1
                THEN (CAST(li.vlf_begin_offset AS decimal(20,2)) / 1048576.0) + li.vlf_size_mb
            END
        ) AS theoretic_min_size_mb
    FROM sys.databases d
    CROSS APPLY sys.dm_db_log_info(d.database_id) li
    WHERE d.state_desc = 'ONLINE'
    GROUP BY d.database_id, li.file_id
)
SELECT
    lf.database_name,
    lf.recovery_model_desc,
    lf.log_reuse_wait_desc,
    lf.logical_log_name,
    lf.physical_name,
    CAST(lf.current_size_mb AS decimal(18,2)) AS current_size_mb,
    ls.[Log Space Used (%)] AS log_used_pct_db_wide,
    CAST(ls.[Log Size (MB)] * ls.[Log Space Used (%)] / 100.0 AS decimal(18,2)) AS used_log_mb_db_wide,
    CAST(COALESCE(av.theoretic_min_size_mb, lf.current_size_mb) AS decimal(18,2)) AS theoretic_min_size_mb,
    CAST(
        CASE
            WHEN lf.current_size_mb > COALESCE(av.theoretic_min_size_mb, lf.current_size_mb)
            THEN lf.current_size_mb - COALESCE(av.theoretic_min_size_mb, lf.current_size_mb)
            ELSE 0
        END
        AS decimal(18,2)
    ) AS max_shrink_mb,
    'USE ' + QUOTENAME(lf.database_name) +
    '; DBCC SHRINKFILE (N''' + REPLACE(lf.logical_log_name, '''', '''''') + ''', ' +
    CAST(CEILING(COALESCE(av.theoretic_min_size_mb, lf.current_size_mb)) AS varchar(20)) +
    ');' AS shrink_command,
    'USE ' + QUOTENAME(lf.database_name) +
    '; DBCC SHRINKDATABASE (N''' + REPLACE(lf.database_name, '''', '''''') + ''');' AS shrink_database_command
FROM LogFiles lf
LEFT JOIN #LogSpace ls
    ON ls.[Database Name] = lf.database_name
LEFT JOIN ActiveVlfEnd av
    ON av.database_id = lf.database_id
   AND av.file_id = lf.file_id
ORDER BY max_shrink_mb DESC, lf.database_name, lf.logical_log_name;

DROP TABLE #LogSpace;
