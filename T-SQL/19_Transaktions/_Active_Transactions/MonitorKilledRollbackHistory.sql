SET NOCOUNT ON;

/*
Purpose:
    Build a short history for a SPID in KILLED/ROLLBACK by sampling:
    1) sys.dm_exec_requests
    2) sys.dm_os_waiting_tasks
    3) a synthesized "KILL ... WITH STATUSONLY" status row

Important:
    The textual output of "KILL <spid> WITH STATUSONLY" is written as a message,
    not as a result set. Because of that, pure T-SQL cannot directly INSERT that
    message into a table. This script therefore stores an equivalent status text
    based on DMV data in ##KillStatusHistory. Optionally, it can also emit the
    real KILL STATUSONLY message to the Messages tab on every loop.

Permissions:
    VIEW SERVER STATE is required for the DMV queries.
*/

DECLARE @Spid INT = 109;
DECLARE @Delay VARCHAR(8) = '00:00:02';
DECLARE @MaxSamples INT = 900; -- 900 * 2 seconds = 30 minutes
DECLARE @EmitKillStatusOnlyToMessages BIT = 1;
DECLARE @StopWhenSessionDisappears BIT = 1;
DECLARE @ResetGlobalTempTables BIT = 0;

DECLARE @RunId UNIQUEIDENTIFIER = NEWID();
DECLARE @SampleNo INT = 0;
DECLARE @Sql NVARCHAR(200);
DECLARE @Message NVARCHAR(4000);
DECLARE @DelayTime TIME(0);

IF @Spid IS NULL OR @Spid <= 0
BEGIN
    THROW 50000, 'Please set @Spid to a valid session_id.', 1;
END;

IF @Delay NOT LIKE '[0-2][0-9]:[0-5][0-9]:[0-5][0-9]'
BEGIN
    THROW 50001, 'Please use @Delay in hh:mm:ss format.', 1;
END;

SET @DelayTime = CONVERT(TIME(0), @Delay);

IF @ResetGlobalTempTables = 1
BEGIN
    IF OBJECT_ID('tempdb..##KillRollbackRequestHistory') IS NOT NULL
        DROP TABLE ##KillRollbackRequestHistory;

    IF OBJECT_ID('tempdb..##KillRollbackWaitHistory') IS NOT NULL
        DROP TABLE ##KillRollbackWaitHistory;

    IF OBJECT_ID('tempdb..##KillStatusHistory') IS NOT NULL
        DROP TABLE ##KillStatusHistory;
END;

IF OBJECT_ID('tempdb..##KillRollbackRequestHistory') IS NULL
BEGIN
    CREATE TABLE ##KillRollbackRequestHistory
    (
        run_id                         UNIQUEIDENTIFIER NOT NULL,
        sample_no                      INT NOT NULL,
        sample_time                    DATETIME2(0) NOT NULL,
        target_session_id              INT NOT NULL,
        session_exists                 BIT NOT NULL,
        request_found                  BIT NOT NULL,
        session_status                 NVARCHAR(30) NULL,
        request_status                 NVARCHAR(30) NULL,
        command                        NVARCHAR(32) NULL,
        percent_complete               DECIMAL(9,2) NULL,
        estimated_completion_time_ms   BIGINT NULL,
        estimated_completion_time_sec  DECIMAL(18,2) NULL,
        database_id                    SMALLINT NULL,
        database_name                  SYSNAME NULL,
        wait_type                      NVARCHAR(60) NULL,
        last_wait_type                 NVARCHAR(60) NULL,
        wait_time_ms                   INT NULL,
        blocking_session_id            SMALLINT NULL,
        open_transaction_count         INT NULL,
        cpu_time_ms                    INT NULL,
        total_elapsed_time_ms          INT NULL,
        reads                          BIGINT NULL,
        writes                         BIGINT NULL,
        logical_reads                  BIGINT NULL,
        row_count                      BIGINT NULL,
        granted_query_memory           INT NULL,
        host_name                      NVARCHAR(128) NULL,
        program_name                   NVARCHAR(128) NULL,
        login_name                     NVARCHAR(128) NULL,
        sql_text_excerpt               NVARCHAR(MAX) NULL
    );
END;

IF OBJECT_ID('tempdb..##KillRollbackWaitHistory') IS NULL
BEGIN
    CREATE TABLE ##KillRollbackWaitHistory
    (
        run_id                         UNIQUEIDENTIFIER NOT NULL,
        sample_no                      INT NOT NULL,
        sample_time                    DATETIME2(0) NOT NULL,
        target_session_id              INT NOT NULL,
        session_exists                 BIT NOT NULL,
        wait_row_found                 BIT NOT NULL,
        waiting_task_address           VARBINARY(8) NULL,
        exec_context_id                INT NULL,
        wait_duration_ms               BIGINT NULL,
        wait_type                      NVARCHAR(60) NULL,
        resource_address               VARBINARY(8) NULL,
        blocking_task_address          VARBINARY(8) NULL,
        blocking_session_id            SMALLINT NULL,
        resource_description           NVARCHAR(3072) NULL
    );
END;

IF OBJECT_ID('tempdb..##KillStatusHistory') IS NULL
BEGIN
    CREATE TABLE ##KillStatusHistory
    (
        run_id                         UNIQUEIDENTIFIER NOT NULL,
        sample_no                      INT NOT NULL,
        sample_time                    DATETIME2(0) NOT NULL,
        target_session_id              INT NOT NULL,
        session_exists                 BIT NOT NULL,
        request_found                  BIT NOT NULL,
        command                        NVARCHAR(32) NULL,
        request_status                 NVARCHAR(30) NULL,
        percent_complete               DECIMAL(9,2) NULL,
        estimated_completion_time_ms   BIGINT NULL,
        estimated_completion_time_sec  DECIMAL(18,2) NULL,
        estimated_completion_time_min  DECIMAL(18,2) NULL,
        wait_type                      NVARCHAR(60) NULL,
        wait_time_ms                   INT NULL,
        blocking_session_id            SMALLINT NULL,
        kill_status_text               NVARCHAR(4000) NULL,
        kill_statusonly_message_note   NVARCHAR(4000) NULL
    );
END;

WHILE @MaxSamples IS NULL OR @SampleNo < @MaxSamples
BEGIN
    DECLARE @SampleTime DATETIME2(0) = SYSDATETIME();
    DECLARE @SessionExists BIT =
        CASE
            WHEN EXISTS (SELECT 1 FROM sys.dm_exec_sessions WHERE session_id = @Spid) THEN 1
            ELSE 0
        END;

    SET @SampleNo += 1;

    INSERT INTO ##KillRollbackRequestHistory
    (
        run_id,
        sample_no,
        sample_time,
        target_session_id,
        session_exists,
        request_found,
        session_status,
        request_status,
        command,
        percent_complete,
        estimated_completion_time_ms,
        estimated_completion_time_sec,
        database_id,
        database_name,
        wait_type,
        last_wait_type,
        wait_time_ms,
        blocking_session_id,
        open_transaction_count,
        cpu_time_ms,
        total_elapsed_time_ms,
        reads,
        writes,
        logical_reads,
        row_count,
        granted_query_memory,
        host_name,
        program_name,
        login_name,
        sql_text_excerpt
    )
    SELECT
        @RunId,
        @SampleNo,
        @SampleTime,
        @Spid,
        @SessionExists,
        CASE WHEN r.session_id IS NULL THEN 0 ELSE 1 END,
        s.status,
        r.status,
        r.command,
        CAST(r.percent_complete AS DECIMAL(9,2)),
        r.estimated_completion_time,
        CAST(r.estimated_completion_time / 1000.0 AS DECIMAL(18,2)),
        r.database_id,
        DB_NAME(r.database_id),
        r.wait_type,
        r.last_wait_type,
        r.wait_time,
        r.blocking_session_id,
        s.open_transaction_count,
        r.cpu_time,
        r.total_elapsed_time,
        r.reads,
        r.writes,
        r.logical_reads,
        r.row_count,
        r.granted_query_memory,
        s.host_name,
        s.program_name,
        s.login_name,
        LEFT(REPLACE(REPLACE(t.[text], CHAR(13), N' '), CHAR(10), N' '), 4000)
    FROM (VALUES (1)) AS anchor(dummy)
    LEFT JOIN sys.dm_exec_sessions AS s
        ON s.session_id = @Spid
    LEFT JOIN sys.dm_exec_requests AS r
        ON r.session_id = @Spid
    OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) AS t;

    INSERT INTO ##KillRollbackWaitHistory
    (
        run_id,
        sample_no,
        sample_time,
        target_session_id,
        session_exists,
        wait_row_found,
        waiting_task_address,
        exec_context_id,
        wait_duration_ms,
        wait_type,
        resource_address,
        blocking_task_address,
        blocking_session_id,
        resource_description
    )
    SELECT
        @RunId,
        @SampleNo,
        @SampleTime,
        @Spid,
        @SessionExists,
        1,
        wt.waiting_task_address,
        wt.exec_context_id,
        wt.wait_duration_ms,
        wt.wait_type,
        wt.resource_address,
        wt.blocking_task_address,
        wt.blocking_session_id,
        wt.resource_description
    FROM sys.dm_os_waiting_tasks AS wt
    WHERE wt.session_id = @Spid;

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO ##KillRollbackWaitHistory
        (
            run_id,
            sample_no,
            sample_time,
            target_session_id,
            session_exists,
            wait_row_found
        )
        VALUES
        (
            @RunId,
            @SampleNo,
            @SampleTime,
            @Spid,
            @SessionExists,
            0
        );
    END;

    INSERT INTO ##KillStatusHistory
    (
        run_id,
        sample_no,
        sample_time,
        target_session_id,
        session_exists,
        request_found,
        command,
        request_status,
        percent_complete,
        estimated_completion_time_ms,
        estimated_completion_time_sec,
        estimated_completion_time_min,
        wait_type,
        wait_time_ms,
        blocking_session_id,
        kill_status_text,
        kill_statusonly_message_note
    )
    SELECT
        @RunId,
        @SampleNo,
        @SampleTime,
        @Spid,
        @SessionExists,
        CASE WHEN r.session_id IS NULL THEN 0 ELSE 1 END,
        r.command,
        r.status,
        CAST(r.percent_complete AS DECIMAL(9,2)),
        r.estimated_completion_time,
        CAST(r.estimated_completion_time / 1000.0 AS DECIMAL(18,2)),
        CAST(r.estimated_completion_time / 60000.0 AS DECIMAL(18,2)),
        r.wait_type,
        r.wait_time,
        r.blocking_session_id,
        CASE
            WHEN r.session_id IS NULL AND @SessionExists = 0 THEN
                CONCAT(N'SPID ', @Spid, N' is no longer present in sys.dm_exec_sessions.')
            WHEN r.session_id IS NULL THEN
                CONCAT(N'SPID ', @Spid, N' still exists, but there is currently no active row in sys.dm_exec_requests.')
            WHEN r.command IN (N'KILLED/ROLLBACK', N'ROLLBACK') THEN
                CONCAT
                (
                    N'SPID ', @Spid,
                    N': transaction rollback in progress. Estimated rollback completion: ',
                    COALESCE(CONVERT(NVARCHAR(30), CAST(r.percent_complete AS DECIMAL(9,2))), N'0.00'),
                    N'%. Estimated time remaining: ',
                    COALESCE(CONVERT(NVARCHAR(30), CAST(r.estimated_completion_time / 1000.0 AS DECIMAL(18,2))), N'0.00'),
                    N' seconds.'
                )
            ELSE
                CONCAT
                (
                    N'SPID ', @Spid,
                    N': current command = ',
                    COALESCE(r.command, N'(null)'),
                    N', request status = ',
                    COALESCE(r.status, N'(null)'),
                    N'.'
                )
        END,
        N'Exact KILL WITH STATUSONLY output is emitted to the Messages tab only when @EmitKillStatusOnlyToMessages = 1.'
    FROM (VALUES (1)) AS anchor(dummy)
    LEFT JOIN sys.dm_exec_requests AS r
        ON r.session_id = @Spid;

    IF @EmitKillStatusOnlyToMessages = 1 AND @SessionExists = 1
    BEGIN
        BEGIN TRY
            SET @Sql = N'KILL ' + CONVERT(NVARCHAR(20), @Spid) + N' WITH STATUSONLY;';
            EXEC sys.sp_executesql @Sql;
        END TRY
        BEGIN CATCH
            SET @Message =
                CONCAT
                (
                    N'KILL STATUSONLY failed for SPID ',
                    @Spid,
                    N': ',
                    ERROR_MESSAGE()
                );

            RAISERROR('%s', 10, 1, @Message) WITH NOWAIT;
        END CATCH;
    END;

    IF @StopWhenSessionDisappears = 1 AND @SessionExists = 0
    BEGIN
        BREAK;
    END;

    WAITFOR DELAY @DelayTime;
END;

SELECT
    @RunId AS run_id,
    @Spid AS monitored_spid,
    @SampleNo AS collected_samples,
    @Delay AS sample_delay,
    N'Use the run_id to filter the three global temp tables.' AS info_message;

SELECT
    ks.run_id,
    ks.sample_no,
    ks.sample_time,
    ks.target_session_id,
    ks.session_exists,
    ks.request_found,
    ks.command,
    ks.request_status,
    ks.percent_complete,
    ks.estimated_completion_time_sec,
    ks.wait_type,
    ks.wait_time_ms,
    ks.blocking_session_id,
    ks.kill_status_text
FROM ##KillStatusHistory AS ks
WHERE ks.run_id = @RunId
ORDER BY ks.sample_no;
