SET NOCOUNT ON;

/*
Purpose:
    Show since when a SPID is most likely in rollback.

Important:
    SQL Server does not expose a documented exact "rollback_start_time"
    column for KILLED/ROLLBACK. This script therefore shows:

    1) The best live approximation from sys.dm_exec_requests
    2) The first observed rollback timestamp from ##KillStatusHistory,
       if the monitoring script was already running

    Interpretation:
    - rollback_observed_since is the best value if ##KillStatusHistory exists.
    - Otherwise request_start_time / derived_request_start_time is only a
      best-effort approximation, not a guaranteed exact rollback start.
*/

DECLARE @Spid INT = 109;
DECLARE @FirstObservedRollback DATETIME2(0) = NULL;
DECLARE @LastObservedRollback DATETIME2(0) = NULL;
DECLARE @ObservedSamples INT = 0;

IF @Spid IS NULL OR @Spid <= 0
BEGIN
    THROW 50000, 'Please set @Spid to a valid session_id.', 1;
END;

IF OBJECT_ID('tempdb..##KillStatusHistory') IS NOT NULL
BEGIN
    SELECT
        @FirstObservedRollback = MIN(ks.sample_time),
        @LastObservedRollback = MAX(ks.sample_time),
        @ObservedSamples = COUNT(*)
    FROM tempdb..##KillStatusHistory AS ks
    WHERE ks.target_session_id = @Spid
      AND ks.request_found = 1
      AND ks.command IN (N'KILLED/ROLLBACK', N'ROLLBACK');
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.dm_exec_sessions AS s
    WHERE s.session_id = @Spid
)
BEGIN
    SELECT
        @Spid AS target_session_id,
        N'The session no longer exists.' AS info_message,
        @FirstObservedRollback AS rollback_observed_since,
        @LastObservedRollback AS rollback_last_seen_at,
        @ObservedSamples AS observed_rollback_samples;

    RETURN;
END;

SELECT
    s.session_id,
    s.status AS session_status,
    r.status AS request_status,
    r.command,
    s.login_time,
    s.last_request_start_time,
    r.start_time AS request_start_time,
    DATEADD(MILLISECOND, -r.total_elapsed_time, SYSDATETIME()) AS derived_request_start_time,
    @FirstObservedRollback AS rollback_observed_since,
    @LastObservedRollback AS rollback_last_seen_at,
    @ObservedSamples AS observed_rollback_samples,
    CASE
        WHEN @FirstObservedRollback IS NOT NULL
            THEN @FirstObservedRollback
        ELSE r.start_time
    END AS best_known_rollback_since,
    CASE
        WHEN @FirstObservedRollback IS NOT NULL
            THEN DATEDIFF(SECOND, @FirstObservedRollback, SYSDATETIME())
        WHEN r.start_time IS NOT NULL
            THEN DATEDIFF(SECOND, r.start_time, SYSDATETIME())
        ELSE NULL
    END AS seconds_since_best_known_rollback_since,
    r.percent_complete,
    r.estimated_completion_time / 1000.0 AS estimated_completion_time_sec,
    r.wait_type,
    r.last_wait_type,
    r.wait_time AS current_wait_time_ms,
    r.blocking_session_id,
    DB_NAME(r.database_id) AS database_name,
    s.host_name,
    s.program_name,
    s.login_name,
    CASE
        WHEN @FirstObservedRollback IS NOT NULL
            THEN N'Based on the first sample recorded in ##KillStatusHistory.'
        WHEN r.command IN (N'KILLED/ROLLBACK', N'ROLLBACK')
            THEN N'Approximation only. SQL Server exposes request start time, not a documented exact rollback start timestamp.'
        ELSE N'The session is currently not visible as KILLED/ROLLBACK in sys.dm_exec_requests.'
    END AS interpretation
FROM sys.dm_exec_sessions AS s
LEFT JOIN sys.dm_exec_requests AS r
    ON r.session_id = s.session_id
WHERE s.session_id = @Spid;

IF OBJECT_ID('tempdb..##KillStatusHistory') IS NOT NULL
BEGIN
    SELECT
        ks.run_id,
        ks.sample_no,
        ks.sample_time,
        ks.target_session_id,
        ks.command,
        ks.request_status,
        ks.percent_complete,
        ks.estimated_completion_time_sec,
        ks.wait_type,
        ks.wait_time_ms,
        ks.blocking_session_id,
        ks.kill_status_text
    FROM tempdb..##KillStatusHistory AS ks
    WHERE ks.target_session_id = @Spid
      AND ks.command IN (N'KILLED/ROLLBACK', N'ROLLBACK')
    ORDER BY ks.sample_time;
END;
