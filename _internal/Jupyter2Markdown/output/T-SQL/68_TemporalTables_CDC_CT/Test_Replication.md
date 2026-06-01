# Test_Replication

**Quelle:** `T-SQL\68_TemporalTables_CDC_CT\Test_Replication.ipynb`  
**Generiert:** 2026-04-18 21:13:31  
**Markdown-Zellen:** 3  
**SQL-Zellen:** 3  

---

Change Data Capture (CDC)

- **`cdc.<DB>_capture:`** Liest fortlaufend den **Transaktionslog** <span style="color: var(--vscode-foreground);">der angegebenen Datenbank (hier z. B. </span> `BI_STAGE`<span style="color: var(--vscode-foreground);">) und schreibt erkannte </span> **INSERT/UPDATE/DELETE** <span style="color: var(--vscode-foreground);">in die CDC-Änderungstabellen (</span>`cdc.<capture_instance>_CT`<span style="color: var(--vscode-foreground);">) inkl. LSN-Zeit-Mapping. Läuft i. d. R. kontinuierlich.</span>→ Wenn der Capture-Job lange steht, kann sich das **Log aufblähen** <span style="color: var(--vscode-foreground);">(Log-Truncation wartet dann häufig mit </span> `log_reuse_wait_desc = REPLICATION`<span style="color: var(--vscode-foreground);">).</span>
- **`cdc.<DB>_cleanup:`** Räumt alte CDC-Zeilen auf, gemäß **Retention** <span style="color: var(--vscode-foreground);">(Minuten) und </span> **Batch-Schwelle**<span style="color: var(--vscode-foreground);">. So bleiben die CDC-Tabellen schlank.&nbsp;</span> 

Diese Jobs entstehen, wenn du `sys.sp_cdc_enable_db` (DB-weit) und anschließend `sys.sp_cdc_enable_table` (je Tabelle) aufrufst. Der Capture-Job ruft intern die System-SPs für den Log-Scan auf (z. B. `sys.sp_MScdc_capture_job`/`sys.sp_cdc_scan`), der Cleanup-Job `sys.sp_MScdc_cleanup_job`.





```sql
EXEC sys.sp_cdc_help_jobs @job_type = N'capture';  -- zeigt Status/Last Run
```

```sql
DECLARE @db sysname = N'BI_STAGE';

-- 1) CDC auf DB-Ebene aktiv?
SELECT name AS database_name, is_cdc_enabled
FROM sys.databases
WHERE name = @db;

-- 2) CDC-Tabellen (pro DB)
EXEC (N'EXEC ' + QUOTENAME(@db) + N'.sys.sp_cdc_help_change_data_capture;');

-- 3) Jobs vorhanden?
SELECT j.name, j.enabled
FROM msdb.dbo.sysjobs j
WHERE j.name IN (N'cdc.' + @db + N'_capture', N'cdc.' + @db + N'_cleanup');

-- 4) Laufen die Jobs?
;WITH a AS (
  SELECT sja.job_id, sja.start_execution_date, sja.stop_execution_date,
         ROW_NUMBER() OVER (PARTITION BY sja.job_id ORDER BY sja.start_execution_date DESC) rn
  FROM msdb.dbo.sysjobactivity sja
)
SELECT j.name,
       CASE WHEN a.start_execution_date IS NOT NULL AND a.stop_execution_date IS NULL
            THEN 'Running' ELSE 'Not running' END AS Status,
       a.start_execution_date, a.stop_execution_date
FROM msdb.dbo.sysjobs j
LEFT JOIN a ON a.job_id = j.job_id AND a.rn = 1
WHERE j.name LIKE N'cdc.' + @db + N'_%';

-- 5) Letzte Log-Scan-Sessions der DB
SELECT TOP (10)
       d.name AS database_name, s.start_time, s.end_time, s.scan_phase,
       s.error_number, s.error_severity, s.error_message
FROM sys.dm_cdc_log_scan_sessions s
JOIN sys.databases d ON d.database_id = s.database_id
WHERE d.name = @db
ORDER BY s.start_time DESC;

```

aktuelle/letzte Log-Scan-Sessiond der DB


```sql
SELECT TOP (10) s.start_time, s.end_time, s.scan_phase, s.error_number, s.error_message
FROM sys.dm_cdc_log_scan_sessions s
JOIN sys.databases d ON d.database_id = s.database_id
WHERE d.name = N'BI_STAGE'
ORDER BY s.start_time DESC;
```
