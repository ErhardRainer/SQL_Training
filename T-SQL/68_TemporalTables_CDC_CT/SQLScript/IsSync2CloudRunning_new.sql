DECLARE @DBName SYSNAME = N'BI_DWH';
DECLARE @StaleMinutes INT = 15;
DECLARE @SQL NVARCHAR(MAX);

------------------------------------------------------------
-- 1) Grundstatus der Datenbank
------------------------------------------------------------
SELECT
    d.name AS DatabaseName,
    d.state_desc,
    d.recovery_model_desc,
    d.log_reuse_wait_desc,
    d.is_change_feed_enabled,
    d.is_data_lake_replication_enabled
FROM sys.databases AS d
WHERE d.name = @DBName;

------------------------------------------------------------
-- 2) Change Feed / Fabric Mirroring Settings
------------------------------------------------------------
SET @SQL = N'
USE ' + QUOTENAME(@DBName) + N';

BEGIN TRY
    EXEC sys.sp_help_change_feed_settings;
END TRY
BEGIN CATCH
    SELECT
        ''sp_help_change_feed_settings'' AS CheckName,
        ERROR_NUMBER() AS ErrorNumber,
        ERROR_MESSAGE() AS ErrorMessage;
END CATCH;
';
EXEC (@SQL);

------------------------------------------------------------
-- 3) Letzte und aktuelle Log-Scan-Session
------------------------------------------------------------
SET @SQL = N'
USE ' + QUOTENAME(@DBName) + N';

BEGIN TRY
    ;WITH LastSessions AS
    (
        SELECT TOP (5)
            session_id,
            start_time,
            end_time,
            duration,
            batch_processing_phase,
            error_count,
            batch_start_lsn,
            currently_processed_lsn,
            batch_end_lsn,
            tran_count,
            command_count,
            currently_processed_commit_lsn,
            currently_processed_commit_time,
            latency,
            empty_scan_count,
            failed_sessions_count
        FROM sys.dm_change_feed_log_scan_sessions
        WHERE session_id > 0
        ORDER BY session_id DESC
    )
    SELECT
        session_id,
        start_time,
        end_time,
        CASE
            WHEN end_time IS NULL THEN ''ACTIVE''
            WHEN currently_processed_commit_time IS NULL THEN ''NO_COMMIT_PROCESSED''
            WHEN currently_processed_commit_time >= DATEADD(MINUTE, -' + CAST(@StaleMinutes AS NVARCHAR(10)) + N', GETDATE()) THEN ''RUNNING_RECENTLY''
            ELSE ''STALE''
        END AS SyncHealth,
        duration,
        batch_processing_phase,
        error_count,
        tran_count,
        command_count,
        currently_processed_commit_lsn,
        currently_processed_commit_time,
        latency,
        empty_scan_count,
        failed_sessions_count,
        batch_start_lsn,
        currently_processed_lsn,
        batch_end_lsn
    FROM LastSessions
    ORDER BY session_id DESC;
END TRY
BEGIN CATCH
    SELECT
        ''sys.dm_change_feed_log_scan_sessions'' AS CheckName,
        ERROR_NUMBER() AS ErrorNumber,
        ERROR_MESSAGE() AS ErrorMessage;
END CATCH;
';
EXEC (@SQL);

------------------------------------------------------------
-- 4) Aktuelle Fehler
------------------------------------------------------------
SET @SQL = N'
USE ' + QUOTENAME(@DBName) + N';

BEGIN TRY
    SELECT TOP (20)
        entry_time,
        session_id,
        source_task,
        table_id,
        error_number,
        error_severity,
        error_state,
        error_message,
        tran_begin_lsn,
        tran_commit_lsn,
        sequence_value,
        command_id
    FROM sys.dm_change_feed_errors
    ORDER BY entry_time DESC;
END TRY
BEGIN CATCH
    SELECT
        ''sys.dm_change_feed_errors'' AS CheckName,
        ERROR_NUMBER() AS ErrorNumber,
        ERROR_MESSAGE() AS ErrorMessage;
END CATCH;
';
EXEC (@SQL);

------------------------------------------------------------
-- 5) Tabellenstatus im Mirroring
------------------------------------------------------------
SET @SQL = N'
USE ' + QUOTENAME(@DBName) + N';

BEGIN TRY
    EXEC sys.sp_help_change_feed;
END TRY
BEGIN CATCH
    SELECT
        ''sys.sp_help_change_feed'' AS CheckName,
        ERROR_NUMBER() AS ErrorNumber,
        ERROR_MESSAGE() AS ErrorMessage;
END CATCH;
';
EXEC (@SQL);