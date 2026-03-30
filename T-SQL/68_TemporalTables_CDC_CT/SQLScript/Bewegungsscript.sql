USE [BI_DWH];
GO

SELECT TOP (2)
    session_id,
    start_time,
    end_time,
    scan_phase,
    error_count,
    current_lsn,
    tran_count,
    command_count,
    last_commit_cdc_time
FROM sys.dm_cdc_log_scan_sessions
WHERE session_id > 0
ORDER BY session_id DESC;