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