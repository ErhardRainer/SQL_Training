SET NOCOUNT ON;

/*
Purpose:
    Identify the transactions that currently keep the transaction log from being reused
    when sys.databases.log_reuse_wait_desc = 'ACTIVE_TRANSACTION'.

Usage:
    1) Leave @DatabaseName = NULL to inspect every ONLINE database that currently shows
       log_reuse_wait_desc = 'ACTIVE_TRANSACTION'.
    2) Set @DatabaseName to inspect one specific database.
    3) Set @OnlyDatabasesWithActiveTransactionWait = 0 if you want to inspect active
       transactions even when the database currently shows another reuse wait.

Permissions:
    VIEW SERVER STATE is required for the DMVs used below.

Result sets:
    1) Database summary
    2) Most likely blocker per database (oldest_rank = 1)
    3) Full transaction detail list
*/

DECLARE @DatabaseName SYSNAME = NULL;
DECLARE @OnlyDatabasesWithActiveTransactionWait BIT = 1;
DECLARE @IncludeSystemTransactions BIT = 1;

IF @DatabaseName IS NOT NULL
   AND DB_ID(@DatabaseName) IS NULL
BEGIN
    THROW 50000, 'The specified database does not exist.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.databases AS d
    WHERE d.state_desc = N'ONLINE'
      AND (@DatabaseName IS NULL OR d.name = @DatabaseName)
      AND
      (
          @OnlyDatabasesWithActiveTransactionWait = 0
          OR d.log_reuse_wait_desc = N'ACTIVE_TRANSACTION'
      )
)
BEGIN
    SELECT
        @DatabaseName AS requested_database_name,
        N'No ONLINE database matched the current filter.' AS info_message,
        N'Set @OnlyDatabasesWithActiveTransactionWait = 0 to inspect all active transactions.' AS hint_message;

    RETURN;
END;

IF OBJECT_ID('tempdb..#ActiveTransactions') IS NOT NULL
    DROP TABLE #ActiveTransactions;

CREATE TABLE #ActiveTransactions
(
    database_id                    INT             NOT NULL,
    database_name                  SYSNAME         NOT NULL,
    recovery_model_desc            NVARCHAR(60)    NULL,
    log_reuse_wait_desc            NVARCHAR(120)   NULL,
    transaction_id                 BIGINT          NOT NULL,
    transaction_name               NVARCHAR(128)   NULL,
    transaction_type_desc          NVARCHAR(30)    NOT NULL,
    transaction_state_desc         NVARCHAR(40)    NOT NULL,
    database_transaction_state_desc NVARCHAR(40)   NOT NULL,
    transaction_begin_time         DATETIME        NULL,
    database_transaction_begin_time DATETIME       NULL,
    transaction_age_minutes        INT             NULL,
    session_id                     SMALLINT        NULL,
    is_user_transaction            BIT             NULL,
    is_local                       BIT             NULL,
    enlist_count                   INT             NULL,
    session_status                 NVARCHAR(30)    NULL,
    request_status                 NVARCHAR(30)    NULL,
    login_name                     NVARCHAR(128)   NULL,
    host_name                      NVARCHAR(128)   NULL,
    program_name                   NVARCHAR(128)   NULL,
    client_interface_name          NVARCHAR(128)   NULL,
    isolation_level_desc           NVARCHAR(40)    NULL,
    session_open_transaction_count INT             NULL,
    command                        NVARCHAR(32)    NULL,
    request_start_time             DATETIME        NULL,
    wait_type                      NVARCHAR(60)    NULL,
    wait_time_ms                   INT             NULL,
    wait_resource                  NVARCHAR(256)   NULL,
    blocking_session_id            SMALLINT        NULL,
    cpu_time_ms                    INT             NULL,
    total_elapsed_time_ms          INT             NULL,
    reads                          BIGINT          NULL,
    writes                         BIGINT          NULL,
    logical_reads                  BIGINT          NULL,
    log_record_count               BIGINT          NULL,
    log_mb_used                    DECIMAL(18,2)   NULL,
    log_mb_reserved                DECIMAL(18,2)   NULL,
    sql_text_excerpt               NVARCHAR(MAX)   NULL,
    oldest_rank                    INT             NOT NULL
);

;WITH CandidateDatabases AS
(
    SELECT
        d.database_id,
        d.name AS database_name,
        d.recovery_model_desc,
        d.log_reuse_wait_desc
    FROM sys.databases AS d
    WHERE d.state_desc = N'ONLINE'
      AND (@DatabaseName IS NULL OR d.name = @DatabaseName)
      AND
      (
          @OnlyDatabasesWithActiveTransactionWait = 0
          OR d.log_reuse_wait_desc = N'ACTIVE_TRANSACTION'
      )
),
TransactionBase AS
(
    SELECT
        d.database_id,
        d.database_name,
        d.recovery_model_desc,
        d.log_reuse_wait_desc,
        at.transaction_id,
        at.name AS transaction_name,
        at.transaction_type,
        at.transaction_state,
        at.transaction_begin_time,
        dt.database_transaction_begin_time,
        dt.database_transaction_state,
        dt.database_transaction_log_record_count,
        dt.database_transaction_log_bytes_used,
        dt.database_transaction_log_bytes_reserved,
        st.session_id,
        st.is_user_transaction,
        st.is_local,
        st.enlist_count,
        s.status AS session_status,
        s.login_name,
        s.host_name,
        s.program_name,
        s.client_interface_name,
        s.transaction_isolation_level,
        s.open_transaction_count AS session_open_transaction_count,
        req.request_id,
        req.status AS request_status,
        req.command,
        req.start_time AS request_start_time,
        req.statement_start_offset,
        req.statement_end_offset,
        req.wait_type,
        req.wait_time,
        req.wait_resource,
        req.blocking_session_id,
        req.cpu_time,
        req.total_elapsed_time,
        req.reads,
        req.writes,
        req.logical_reads,
        sql_text.[text] AS sql_text_full
    FROM CandidateDatabases AS d
    INNER JOIN sys.dm_tran_database_transactions AS dt
        ON dt.database_id = d.database_id
    INNER JOIN sys.dm_tran_active_transactions AS at
        ON at.transaction_id = dt.transaction_id
    LEFT JOIN sys.dm_tran_session_transactions AS st
        ON st.transaction_id = at.transaction_id
    LEFT JOIN sys.dm_exec_sessions AS s
        ON s.session_id = st.session_id
    OUTER APPLY
    (
        SELECT TOP (1)
            r.request_id,
            r.status,
            r.command,
            r.start_time,
            r.statement_start_offset,
            r.statement_end_offset,
            r.wait_type,
            r.wait_time,
            r.wait_resource,
            r.blocking_session_id,
            r.cpu_time,
            r.total_elapsed_time,
            r.reads,
            r.writes,
            r.logical_reads,
            r.sql_handle,
            r.database_id
        FROM sys.dm_exec_requests AS r
        WHERE r.session_id = st.session_id
        ORDER BY
            CASE WHEN r.database_id = d.database_id THEN 0 ELSE 1 END,
            r.start_time DESC
    ) AS req
    LEFT JOIN sys.dm_exec_connections AS c
        ON c.session_id = st.session_id
    OUTER APPLY sys.dm_exec_sql_text(COALESCE(req.sql_handle, c.most_recent_sql_handle)) AS sql_text
    WHERE at.transaction_state NOT IN (3, 6, 8)
      AND (@IncludeSystemTransactions = 1 OR at.transaction_type <> 3)
)
INSERT INTO #ActiveTransactions
(
    database_id,
    database_name,
    recovery_model_desc,
    log_reuse_wait_desc,
    transaction_id,
    transaction_name,
    transaction_type_desc,
    transaction_state_desc,
    database_transaction_state_desc,
    transaction_begin_time,
    database_transaction_begin_time,
    transaction_age_minutes,
    session_id,
    is_user_transaction,
    is_local,
    enlist_count,
    session_status,
    request_status,
    login_name,
    host_name,
    program_name,
    client_interface_name,
    isolation_level_desc,
    session_open_transaction_count,
    command,
    request_start_time,
    wait_type,
    wait_time_ms,
    wait_resource,
    blocking_session_id,
    cpu_time_ms,
    total_elapsed_time_ms,
    reads,
    writes,
    logical_reads,
    log_record_count,
    log_mb_used,
    log_mb_reserved,
    sql_text_excerpt,
    oldest_rank
)
SELECT
    tb.database_id,
    tb.database_name,
    tb.recovery_model_desc,
    tb.log_reuse_wait_desc,
    tb.transaction_id,
    COALESCE(NULLIF(tb.transaction_name, N''), N'(unnamed)') AS transaction_name,
    CASE tb.transaction_type
        WHEN 1 THEN N'Read/write'
        WHEN 2 THEN N'Read-only'
        WHEN 3 THEN N'System'
        WHEN 4 THEN N'Distributed'
        ELSE N'Unknown'
    END AS transaction_type_desc,
    CASE tb.transaction_state
        WHEN 0 THEN N'Not initialized'
        WHEN 1 THEN N'Initialized'
        WHEN 2 THEN N'Active'
        WHEN 3 THEN N'Ended'
        WHEN 4 THEN N'Commit started'
        WHEN 5 THEN N'Prepared'
        WHEN 6 THEN N'Committed'
        WHEN 7 THEN N'Rolling back'
        WHEN 8 THEN N'Rolled back'
        ELSE N'Unknown'
    END AS transaction_state_desc,
    CASE tb.database_transaction_state
        WHEN 1 THEN N'Not initialized'
        WHEN 3 THEN N'No log records generated'
        WHEN 4 THEN N'Log records generated'
        WHEN 5 THEN N'Prepared'
        WHEN 10 THEN N'Committed'
        WHEN 11 THEN N'Rolled back'
        WHEN 12 THEN N'Commit in progress'
        ELSE N'Unknown'
    END AS database_transaction_state_desc,
    tb.transaction_begin_time,
    tb.database_transaction_begin_time,
    DATEDIFF
    (
        MINUTE,
        COALESCE(tb.database_transaction_begin_time, tb.transaction_begin_time),
        SYSDATETIME()
    ) AS transaction_age_minutes,
    tb.session_id,
    tb.is_user_transaction,
    tb.is_local,
    tb.enlist_count,
    tb.session_status,
    tb.request_status,
    tb.login_name,
    tb.host_name,
    tb.program_name,
    tb.client_interface_name,
    CASE tb.transaction_isolation_level
        WHEN 0 THEN N'Unspecified'
        WHEN 1 THEN N'ReadUncommitted'
        WHEN 2 THEN N'ReadCommitted'
        WHEN 3 THEN N'RepeatableRead'
        WHEN 4 THEN N'Serializable'
        WHEN 5 THEN N'Snapshot'
        ELSE N'Unknown'
    END AS isolation_level_desc,
    tb.session_open_transaction_count,
    tb.command,
    tb.request_start_time,
    tb.wait_type,
    tb.wait_time,
    tb.wait_resource,
    tb.blocking_session_id,
    tb.cpu_time,
    tb.total_elapsed_time,
    tb.reads,
    tb.writes,
    tb.logical_reads,
    tb.database_transaction_log_record_count,
    CAST(tb.database_transaction_log_bytes_used / 1048576.0 AS DECIMAL(18,2)) AS log_mb_used,
    CAST(tb.database_transaction_log_bytes_reserved / 1048576.0 AS DECIMAL(18,2)) AS log_mb_reserved,
    LEFT
    (
        REPLACE
        (
            REPLACE
            (
                CASE
                    WHEN tb.sql_text_full IS NULL THEN NULL
                    WHEN tb.request_id IS NOT NULL THEN
                        SUBSTRING
                        (
                            tb.sql_text_full,
                            (tb.statement_start_offset / 2) + 1,
                            CASE
                                WHEN tb.statement_end_offset = -1
                                  OR tb.statement_end_offset < tb.statement_start_offset
                                    THEN (DATALENGTH(tb.sql_text_full) - tb.statement_start_offset) / 2 + 1
                                ELSE (tb.statement_end_offset - tb.statement_start_offset) / 2 + 1
                            END
                        )
                    ELSE tb.sql_text_full
                END,
                CHAR(13),
                N' '
            ),
            CHAR(10),
            N' '
        ),
        4000
    ) AS sql_text_excerpt,
    ROW_NUMBER() OVER
    (
        PARTITION BY tb.database_id
        ORDER BY
            COALESCE(tb.database_transaction_begin_time, tb.transaction_begin_time),
            tb.transaction_id
    ) AS oldest_rank
FROM TransactionBase AS tb;

IF NOT EXISTS (SELECT 1 FROM #ActiveTransactions)
BEGIN
    SELECT
        @DatabaseName AS requested_database_name,
        N'No active transactions were found in the selected scope.' AS info_message,
        N'If the reuse wait just changed, run the script again and also verify other wait reasons such as LOG_BACKUP or REPLICATION.' AS hint_message;

    RETURN;
END;

SELECT
    atx.database_name,
    atx.recovery_model_desc,
    atx.log_reuse_wait_desc,
    COUNT(DISTINCT atx.transaction_id) AS active_transaction_count,
    COUNT(DISTINCT atx.session_id) AS involved_session_count,
    MIN(COALESCE(atx.database_transaction_begin_time, atx.transaction_begin_time)) AS oldest_transaction_begin_time,
    MAX(atx.transaction_age_minutes) AS oldest_transaction_age_minutes,
    CAST(SUM(ISNULL(atx.log_mb_used, 0.00)) AS DECIMAL(18,2)) AS total_log_mb_used,
    CAST(SUM(ISNULL(atx.log_mb_reserved, 0.00)) AS DECIMAL(18,2)) AS total_log_mb_reserved
FROM #ActiveTransactions AS atx
GROUP BY
    atx.database_name,
    atx.recovery_model_desc,
    atx.log_reuse_wait_desc
ORDER BY
    MAX(atx.transaction_age_minutes) DESC,
    SUM(ISNULL(atx.log_mb_used, 0.00)) DESC,
    atx.database_name;

SELECT
    atx.database_name,
    atx.recovery_model_desc,
    atx.log_reuse_wait_desc,
    atx.transaction_id,
    atx.transaction_name,
    atx.transaction_type_desc,
    atx.transaction_state_desc,
    atx.database_transaction_state_desc,
    atx.transaction_begin_time,
    atx.database_transaction_begin_time,
    atx.transaction_age_minutes,
    atx.session_id,
    atx.is_user_transaction,
    atx.is_local,
    atx.enlist_count,
    atx.session_status,
    atx.request_status,
    atx.login_name,
    atx.host_name,
    atx.program_name,
    atx.client_interface_name,
    atx.isolation_level_desc,
    atx.session_open_transaction_count,
    atx.command,
    atx.request_start_time,
    atx.wait_type,
    atx.wait_time_ms,
    atx.wait_resource,
    atx.blocking_session_id,
    atx.log_record_count,
    atx.log_mb_used,
    atx.log_mb_reserved,
    atx.sql_text_excerpt
FROM #ActiveTransactions AS atx
WHERE atx.oldest_rank = 1
ORDER BY
    atx.transaction_age_minutes DESC,
    atx.log_mb_used DESC,
    atx.database_name;

SELECT
    atx.database_name,
    atx.recovery_model_desc,
    atx.log_reuse_wait_desc,
    atx.oldest_rank,
    atx.transaction_id,
    atx.transaction_name,
    atx.transaction_type_desc,
    atx.transaction_state_desc,
    atx.database_transaction_state_desc,
    atx.transaction_begin_time,
    atx.database_transaction_begin_time,
    atx.transaction_age_minutes,
    atx.session_id,
    atx.is_user_transaction,
    atx.is_local,
    atx.enlist_count,
    atx.session_status,
    atx.request_status,
    atx.login_name,
    atx.host_name,
    atx.program_name,
    atx.client_interface_name,
    atx.isolation_level_desc,
    atx.session_open_transaction_count,
    atx.command,
    atx.request_start_time,
    atx.wait_type,
    atx.wait_time_ms,
    atx.wait_resource,
    atx.blocking_session_id,
    atx.cpu_time_ms,
    atx.total_elapsed_time_ms,
    atx.reads,
    atx.writes,
    atx.logical_reads,
    atx.log_record_count,
    atx.log_mb_used,
    atx.log_mb_reserved,
    atx.sql_text_excerpt
FROM #ActiveTransactions AS atx
ORDER BY
    atx.database_name,
    atx.oldest_rank,
    atx.transaction_age_minutes DESC,
    atx.log_mb_used DESC,
    atx.transaction_id;
