/* ----------------------------------------------------------------------
   Kontext-Check: Verbindung, DB, Login/Host/Client und Serverzeit
   Zweck: Verifiziert, gegen welchen Server/DB/Benutzer/Client du arbeitest.
---------------------------------------------------------------------- */
SELECT
    @@SERVERNAME                  AS server_name,
    DB_NAME()                     AS current_database,
    SUSER_SNAME()                 AS login_name,
    HOST_NAME()                   AS host_name,
    PROGRAM_NAME()                AS program_name,
    SYSDATETIMEOFFSET()           AS server_time;


/* ----------------------------------------------------------------------
   (1) Parameter: Zielprozedur und Suchmuster
   - @ProcName: Name der gesuchten Stored Procedure.
   - @LikeText: Freitext-Suchmuster für SQL-Text (heuristisch).
   - @MyLogin/@MyHost/@MyProg: Umgebung des aktuellen Clients (optional nützlich).
   - @SSMSFilter: Filter auf SSMS-Clients (anpassbar für ADS o. ä.).
---------------------------------------------------------------------- */
DECLARE @ProcName SYSNAME      = N'dbo.usp_Lookup_LW_Order_LW';
DECLARE @LikeText NVARCHAR(200)= N'%usp_Lookup_LW_Order_LW%';

DECLARE @MyLogin SYSNAME       = SUSER_SNAME();
DECLARE @MyHost  NVARCHAR(128) = HOST_NAME();
DECLARE @MyProg  NVARCHAR(128) = PROGRAM_NAME();

DECLARE @SSMSFilter NVARCHAR(200) = N'%Microsoft SQL Server Management Studio%';


/* ----------------------------------------------------------------------
   (2) Ziel-Session (SPID) ermitteln:
   - Sammelt passende aktive Requests in @m (ohne die eigene Session).
   - Filter über SQL-Text (@LikeText) oder EXEC-Aufruf der Prozedur.
   - Stellt sicher, dass genau 1 Treffer existiert -> sonst THROW.
   Ergebnis: @target_spid enthält die eindeutige Ziel-Session.
---------------------------------------------------------------------- */
DECLARE @target_spid INT;

DECLARE @m TABLE
(
    session_id   INT PRIMARY KEY,
    start_time   DATETIME2,
    login_name   SYSNAME,
    host_name    NVARCHAR(128),
    program_name NVARCHAR(128)
);

INSERT INTO @m (session_id, start_time, login_name, host_name, program_name)
SELECT
    r.session_id,
    r.start_time,
    s.login_name,
    s.host_name,
    s.program_name
FROM sys.dm_exec_requests AS r
JOIN sys.dm_exec_sessions AS s ON s.session_id = r.session_id
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) AS t
WHERE s.is_user_process = 1
  AND r.session_id <> @@SPID
  AND (t.text LIKE @LikeText OR t.text LIKE N'%EXEC%'+@ProcName+'%');

-- 0 Treffer -> eindeutige Fehlermeldung
IF NOT EXISTS (SELECT 1 FROM @m)
    THROW 51000, 'No matching session found. Refine your filter (LIKE/@ProcName).', 1;

-- >1 Treffer -> eindeutige Fehlermeldung (oder hier Policy für TOP(1) wählen)
IF (SELECT COUNT(*) FROM @m) > 1
    THROW 51001, 'Multiple matching sessions found. Narrow your filter (login/host/program/proc).', 1;

-- genau 1 Treffer -> SPID übernehmen
SELECT @target_spid = session_id FROM @m;

-- Optional: Sichtprüfung der gefundenen Session-Metadaten
SELECT * FROM @m;

PRINT(@target_spid);


/* ----------------------------------------------------------------------
   Detailblick auf die Ziel-Session (Request-Ebene):
   - Status/Command/Startzeit
   - Wartegründe (wait_type/last_wait_type/wait_time)
   - Blocker (blocking_session_id)
   - DB-Name und aktueller SQL-Text
   Zweck: Erste, schnelle Ursachenanalyse (Locks, Memory-Grant, I/O, etc.).
---------------------------------------------------------------------- */
SELECT
    r.session_id, r.status, r.command, r.start_time,
    r.wait_type, r.last_wait_type, r.wait_time, r.blocking_session_id,
    DB_NAME(r.database_id) AS database_name,
    t.text AS sql_text
FROM sys.dm_exec_requests r
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE r.session_id = @target_spid;


/* ----------------------------------------------------------------------
   (2a) "Meine Requests" (hier: auf die Ziel-Session eingeschränkt):
   - Zeigt Laufzeit, Fortschritt (percent_complete, falls vorhanden),
     Blocker, DB und SQL-Text.
   Hinweis: percent_complete ist nur bei bestimmten Operationen > 0.
---------------------------------------------------------------------- */
SELECT
    r.session_id,
    s.login_name, s.host_name, s.program_name,
    r.status, r.command, r.start_time,
    r.percent_complete, r.total_elapsed_time/1000.0 AS elapsed_s,
    r.blocking_session_id,
    DB_NAME(r.database_id) AS database_name,
    t.text                 AS sql_text
FROM sys.dm_exec_requests AS r
JOIN sys.dm_exec_sessions AS s
  ON s.session_id = r.session_id
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) AS t
WHERE r.session_id = @target_spid
ORDER BY r.start_time ASC;


/* ----------------------------------------------------------------------
   (3) Läuft noch meine Stored Procedure?
   - Hier kein heuristisches Muster mehr, sondern direkter Filter auf @target_spid.
   - Liefert Status, Command, Startzeit, Umgebung und SQL-Text.
   Zweck: Bestätigung, dass die ermittelte SPID wirklich "deine" Ausführung ist.
---------------------------------------------------------------------- */
SELECT
    r.session_id, r.status, r.command, r.start_time,
    s.login_name, s.host_name, s.program_name,
    DB_NAME(r.database_id) AS database_name,
    t.text                 AS sql_text
FROM sys.dm_exec_requests AS r
JOIN sys.dm_exec_sessions AS s ON s.session_id = r.session_id
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) AS t
WHERE s.is_user_process = 1
  AND r.session_id = @target_spid
ORDER BY r.start_time ASC;


/* ----------------------------------------------------------------------
   Status/Waits/Blocker & SQL-Text der Ziel-SPID:
   - Kompakte Ansicht für Troubleshooting (Warten, Blocker, DB, SQL).
---------------------------------------------------------------------- */
SELECT r.session_id, r.status, r.command, r.start_time,
       r.wait_type, r.last_wait_type, r.wait_time, r.blocking_session_id,
       DB_NAME(r.database_id) AS db_name,
       t.text
FROM sys.dm_exec_requests r
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE r.session_id = @target_spid;


/* ----------------------------------------------------------------------
   Blocker-Hierarchie:
   - Zeigt an, welche Sessions andere blockieren (Kette).
   - Hier als Gesamtüberblick für alle mit Blocking; Fokus auf @target_spid
     folgt in der nächsten Abfrage "wer blockiert wen?".
---------------------------------------------------------------------- */
;WITH c AS (
  SELECT session_id, blocking_session_id
  FROM sys.dm_exec_requests WHERE blocking_session_id <> 0
)
SELECT DISTINCT r.session_id AS victim, r.blocking_session_id AS blocker,
       vt.text AS victim_sql, bt.text AS blocker_sql
FROM sys.dm_exec_requests r
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) vt
OUTER APPLY sys.dm_exec_sql_text((SELECT r2.sql_handle FROM sys.dm_exec_requests r2 WHERE r2.session_id=r.blocking_session_id)) bt
WHERE r.blocking_session_id <> 0;


/* ----------------------------------------------------------------------
   Memory-Grant-Warteschlange (global):
   - Zeigt Sessions mit angeforderten/gewährten Speichermengen für Abfragen.
   - Hohe wait_time_ms + granted_memory_kb = 0 deuten auf Engpässe hin.
---------------------------------------------------------------------- */
SELECT session_id, requested_memory_kb, granted_memory_kb,
       required_memory_kb, max_used_memory_kb, wait_time_ms
FROM sys.dm_exec_query_memory_grants
WHERE session_id = @target_spid
ORDER BY wait_time_ms DESC;


/* ----------------------------------------------------------------------
   Wer blockiert wen? (inkl. Kette) – auf die Ziel-Session fokussiert:
   - Baut eine Kette von Blockings auf und filtert dann @target_spid.
   - Erkennt schnell, ob die Ziel-Session Opfer in einer Blocker-Kette ist.
---------------------------------------------------------------------- */
;WITH blockers AS (
    SELECT
        r.session_id,
        r.blocking_session_id,
        CAST(CONCAT(r.session_id, N'') AS NVARCHAR(4000)) AS chain
    FROM sys.dm_exec_requests AS r
    WHERE r.blocking_session_id <> 0
    UNION ALL
    SELECT
        r.session_id,
        r.blocking_session_id,
        CAST(b.chain + N' -> ' + CAST(r.session_id AS NVARCHAR(10)) AS NVARCHAR(4000)) AS chain
    FROM sys.dm_exec_requests AS r
    JOIN blockers b ON r.blocking_session_id = b.session_id
    WHERE r.blocking_session_id <> 0
)
SELECT DISTINCT
    s.session_id,
    s.login_name, s.host_name, s.program_name,
    r.status, r.command, r.start_time,
    r.blocking_session_id,
    b.chain
FROM sys.dm_exec_sessions s
LEFT JOIN sys.dm_exec_requests r ON s.session_id = r.session_id
LEFT JOIN blockers b ON s.session_id = b.session_id
WHERE s.is_user_process = 1
  AND s.session_id = @target_spid
ORDER BY s.session_id;


/* ----------------------------------------------------------------------
   Ausführungsplan (aktuell) der Ziel-Session:
   - Liefert Plan XML (query_plan) + SQL-Text; hilfreich zur Plananalyse.
   - Hinweis: Nicht jeder Request liefert einen Plan (z. B. kurze/laufende).
---------------------------------------------------------------------- */
SELECT TOP (20)
    r.session_id, r.status, r.command, r.start_time,
    DB_NAME(r.database_id) AS database_name,
    t.text                  AS sql_text,
    qp.query_plan
FROM sys.dm_exec_requests AS r
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) AS t
OUTER APPLY sys.dm_exec_query_plan(r.plan_handle) AS qp
WHERE r.session_id = @target_spid
ORDER BY r.start_time ASC;


/* ----------------------------------------------------------------------
   Aktive Transaktionen der Ziel-Session:
   - Verknüpft Session -> SessionTransactions -> ActiveTransactions -> DB/Log.
   - Zeigt Typ/Status/Begin-Zeitpunkt und Log-Verbrauch pro DB.
   Zweck: Prüfen, ob lange/umfangreiche Transaktionen die Ursache sind.
---------------------------------------------------------------------- */
SELECT
    s.session_id,
    at.transaction_id,
    at.name,
    at.transaction_begin_time,
    at.transaction_type,   -- 1=Read/Write, 2=Read-only, 3=System, 4=Distributed
    at.transaction_state,  -- 0..8 (2=Active, 6=Committed, 7=Rolled back, ...)
    dt.database_id,
    DB_NAME(dt.database_id) AS database_name,
    dt.database_transaction_log_bytes_used/1024.0/1024.0 AS log_used_MB
FROM sys.dm_exec_sessions                AS s
JOIN sys.dm_tran_session_transactions    AS st ON st.session_id   = s.session_id
JOIN sys.dm_tran_active_transactions     AS at ON at.transaction_id = st.transaction_id
LEFT JOIN sys.dm_tran_database_transactions AS dt ON dt.transaction_id = at.transaction_id
WHERE s.is_user_process = 1
  AND s.session_id = @target_spid
ORDER BY at.transaction_begin_time;
