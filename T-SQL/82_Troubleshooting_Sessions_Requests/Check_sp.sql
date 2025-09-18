/* ----------------------------------------------------------------------
Dieses Script dient dazu für eine bestimmte Stored Procedure zu ermitteln,
durch was sie geblockt wird, wor die SP gerade hängt usw.
---------------------------------------------------------------------- */
DECLARE @server_name SYSNAME      = @@SERVERNAME;
DECLARE @current_database SYSNAME = DB_NAME();
DECLARE @now DATETIMEOFFSET(7)    = SYSDATETIMEOFFSET();

/* ----------------------------------------------------------------------
   (1) Parameter: Zielprozedur & Suchmuster (global)
   - @TimeWindowMin: optionales Zeitfenster in Minuten (NULL = kein Limit)
   - @ExcludeSelf:   eigene Such-Session ausblenden
   - @MaxSessions:   max. Anzahl an Kandidaten (Schutz gegen „Full Table“)
---------------------------------------------------------------------- */
DECLARE @ProcName       SYSNAME        = N'dbo.usp_Lookup_LW_Order_LW';
DECLARE @LikeText       NVARCHAR(200)  = N'%usp_Lookup_LW_Order_LW%';
DECLARE @TimeWindowMin  INT            = 240;       -- z. B. 4h, oder NULL
DECLARE @ExcludeSelf    BIT            = 1;         -- eigenen Tab ausblenden
DECLARE @MaxSessions    INT            = 20;        -- Sicherheitslimit

/* ----------------------------------------------------------------------
   (2) Kandidaten (SPIDs) sammeln – mehrere zulassen
   - Trefferkriterien: SQL-Text enthält Muster oder EXEC <ProcName>
   - Optional: Zeitfenster & Self-Exclude
   - Begrenzung via TOP (@MaxSessions) nach Startzeit (älteste zuerst)
---------------------------------------------------------------------- */
DECLARE @m TABLE
(
    session_id   INT PRIMARY KEY,
    start_time   DATETIME2,
    login_name   SYSNAME,
    host_name    NVARCHAR(128),
    program_name NVARCHAR(128)
);

INSERT INTO @m (session_id, start_time, login_name, host_name, program_name)
SELECT TOP (@MaxSessions)
    r.session_id,
    r.start_time,
    s.login_name,
    s.host_name,
    s.program_name
FROM sys.dm_exec_requests AS r
JOIN sys.dm_exec_sessions AS s ON s.session_id = r.session_id
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) AS t
WHERE s.is_user_process = 1
  AND ( @ExcludeSelf = 0 OR r.session_id <> @@SPID )
  AND (
        t.text LIKE @LikeText
     OR t.text LIKE N'%EXEC%'+@ProcName+'%'     -- RPC/EXEC-Aufrufe
  )
  AND ( @TimeWindowMin IS NULL OR r.start_time >= DATEADD(MINUTE, -@TimeWindowMin, SYSDATETIME()) )
ORDER BY r.start_time ASC;

IF NOT EXISTS (SELECT 1 FROM @m)
    THROW 51000, 'No matching sessions found. Refine the text filter or widen the time window.', 1;

/* Optionaler Blick auf die Kandidaten */
-- SELECT * FROM @m ORDER BY start_time;

/* ----------------------------------------------------------------------
   (3) SUMMARY 1: Request/Session/Waits/Plan/Memory je Kandidat
   - Enthält: server_name, current_database, found_procedure, session_id,
     start_time, login/host/program, status/command, waits, blocker,
     sql_text, elapsed_s, percent_complete, Memory-Grant (TOP 1),
     query_plan.
---------------------------------------------------------------------- */
SELECT
    -- Kontext
    @server_name                     AS server_name,
    @current_database                AS current_database,
    @ProcName                        AS found_procedure,

    -- Session/Request
    r.session_id,
    r.start_time,
    s.login_name,
    s.host_name,
    s.program_name,
    r.status,
    r.command,

    -- Waits/Blocking
    r.wait_type,
    r.last_wait_type,
    r.wait_time,
    r.blocking_session_id,

    -- SQL + Laufzeit
    t.text                           AS sql_text,
    r.total_elapsed_time/1000.0      AS elapsed_s,
    r.percent_complete,

    -- Memory-Grant (falls vorhanden)
    mg.requested_memory_kb,
    mg.granted_memory_kb,
    mg.max_used_memory_kb,

    -- Plan
    qp.query_plan
FROM @m AS m
JOIN sys.dm_exec_requests AS r
  ON r.session_id = m.session_id
JOIN sys.dm_exec_sessions AS s
  ON s.session_id = r.session_id
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle)     AS t
OUTER APPLY sys.dm_exec_query_plan(r.plan_handle)  AS qp
OUTER APPLY (
    SELECT TOP (1)
           requested_memory_kb,
           granted_memory_kb,
           max_used_memory_kb
    FROM sys.dm_exec_query_memory_grants AS g
    WHERE g.session_id = r.session_id
    ORDER BY g.grant_time DESC
) AS mg
ORDER BY r.start_time ASC;

/* ----------------------------------------------------------------------
   (4) SUMMARY 2: Transaktionen zu allen Kandidaten
   - Verknüpft jede Session aus @m -> SessionTransactions -> ActiveTransactions
     -> DatabaseTransactions (Log-Verbrauch).
---------------------------------------------------------------------- */
SELECT
    s.session_id,
    at.transaction_id,
    at.name,
    at.transaction_begin_time,
    at.transaction_type,    -- 1=Read/Write, 2=Read-only, 3=System, 4=Distributed
    at.transaction_state,   -- 0..8 (2=Active, 6=Committed, 7=Rolled back, ...)
    dt.database_id,
    DB_NAME(dt.database_id) AS database_name,
    dt.database_transaction_log_bytes_used/1024.0/1024.0 AS log_used_MB
FROM @m AS m
JOIN sys.dm_exec_sessions                  AS s  ON s.session_id = m.session_id
JOIN sys.dm_tran_session_transactions      AS st ON st.session_id = s.session_id
JOIN sys.dm_tran_active_transactions       AS at ON at.transaction_id = st.transaction_id
LEFT JOIN sys.dm_tran_database_transactions AS dt ON dt.transaction_id = at.transaction_id
ORDER BY s.session_id, at.transaction_begin_time;
