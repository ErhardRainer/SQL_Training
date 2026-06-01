/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "LongTranHostProgramAudit.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "19_Transaktions"

purpose: >
  Auditiert aktuell lang laufende Transaktionen ueber Host und Programm,
  damit auffaellige Clients, offene Transaktionen, Waits und Blocking-Muster
  strukturiert gesichtet werden koennen.

parameters:
  - name: "@MinimumAgeMinutes"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Beruecksichtigt nur Transaktionen ab dieser Mindestdauer in Minuten"
  - name: "@MinimumOpenTransactionCount"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Filtert auf Sessions mit mindestens so vielen offenen Transaktionen"
  - name: "@IncludeGuide"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zusaetzlich einen kompakten Review-Guide ausgeben"

result_sets:
  - name: "LongTranAudit"
    description: "Zeigt lange Transaktionen mit Session-, Host-, Programm-, Wait- und Blocking-Kontext"
  - name: "HostProgramSummary"
    description: "Verdichtet lange Transaktionen pro Host und Programm"
  - name: "ReviewGuide"
    description: "Leitet naechste Diagnose- und Review-Schritte aus dem Audit ab"

dependencies:
  - "sys.dm_tran_active_transactions"
  - "sys.dm_tran_session_transactions"
  - "sys.dm_exec_sessions"
  - "sys.dm_exec_requests"
  - "sys.dm_exec_sql_text"
  - "SYSDATETIME"
  - "DATEDIFF"
  - "tempdb temporary tables"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/19_Transaktions/SQLScripts/LongTranHostProgramAudit.md"
  sync_blocks:
    - "SUMMARY_TABLE"
    - "PARAMETERS_TABLE"
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
    date: "2026-04-22"
    user: "ER"
    description: "Erstversion des Host- und Programm-Audits fuer lang laufende Transaktionen"

notes:
  - "Das Skript liest nur aktuelle DMV-Daten und fuehrt keine KILL-, COMMIT- oder ROLLBACK-Aktionen aus."
  - "Fuer produktive Nutzung werden ueblicherweise VIEW SERVER STATE oder vergleichbare Leserechte benoetigt."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

-- 1. Parameter vorbereiten
DECLARE @MinimumAgeMinutes INT = 10;
DECLARE @MinimumOpenTransactionCount INT = 1;
DECLARE @IncludeGuide BIT = 1;

IF @MinimumAgeMinutes < 0
BEGIN
    THROW 50000, '@MinimumAgeMinutes darf nicht negativ sein.', 1;
END;

IF @MinimumOpenTransactionCount < 0
BEGIN
    THROW 50001, '@MinimumOpenTransactionCount darf nicht negativ sein.', 1;
END;

IF @IncludeGuide NOT IN (0, 1)
BEGIN
    THROW 50002, '@IncludeGuide muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #LongTranAudit;
DROP TABLE IF EXISTS #HostProgramSummary;
DROP TABLE IF EXISTS #ReviewGuide;

-- 2. Lange Transaktionen mit Session-, Host- und Programmkontext sammeln
CREATE TABLE #LongTranAudit
(
    SessionID                   SMALLINT        NOT NULL,
    TransactionID               BIGINT          NOT NULL,
    DatabaseName                SYSNAME         NULL,
    HostName                    NVARCHAR(128)   NULL,
    ProgramName                 NVARCHAR(128)   NULL,
    LoginName                   NVARCHAR(128)   NULL,
    SessionStatus               NVARCHAR(30)    NULL,
    RequestStatus               NVARCHAR(30)    NULL,
    TransactionName             NVARCHAR(64)    NULL,
    TransactionState            NVARCHAR(40)    NOT NULL,
    TransactionType             NVARCHAR(40)    NOT NULL,
    TransactionBeginTime        DATETIME        NOT NULL,
    AgeMinutes                  INT             NOT NULL,
    OpenTransactionCount        INT             NOT NULL,
    BlockingSessionID           SMALLINT        NULL,
    WaitType                    NVARCHAR(120)   NULL,
    WaitTimeMs                  INT             NULL,
    WaitResource                NVARCHAR(256)   NULL,
    CommandText                 NVARCHAR(32)    NULL,
    StatementSnippet            NVARCHAR(4000)  NULL,
    AuditComment                NVARCHAR(220)   NOT NULL
);

INSERT INTO #LongTranAudit
(
    SessionID,
    TransactionID,
    DatabaseName,
    HostName,
    ProgramName,
    LoginName,
    SessionStatus,
    RequestStatus,
    TransactionName,
    TransactionState,
    TransactionType,
    TransactionBeginTime,
    AgeMinutes,
    OpenTransactionCount,
    BlockingSessionID,
    WaitType,
    WaitTimeMs,
    WaitResource,
    CommandText,
    StatementSnippet,
    AuditComment
)
SELECT
    s.session_id AS SessionID,
    at.transaction_id AS TransactionID,
    DB_NAME(COALESCE(r.database_id, s.database_id)) AS DatabaseName,
    COALESCE(NULLIF(s.host_name, N''), N'(unknown host)') AS HostName,
    COALESCE(NULLIF(s.program_name, N''), N'(unknown program)') AS ProgramName,
    s.login_name AS LoginName,
    s.status AS SessionStatus,
    r.status AS RequestStatus,
    at.name AS TransactionName,
    CASE at.transaction_state
        WHEN 0 THEN N'not initialized'
        WHEN 1 THEN N'initialized'
        WHEN 2 THEN N'active'
        WHEN 3 THEN N'ended read-only'
        WHEN 4 THEN N'commit started'
        WHEN 5 THEN N'prepared'
        WHEN 6 THEN N'committed'
        WHEN 7 THEN N'rolling back'
        WHEN 8 THEN N'rolled back'
        ELSE N'unknown'
    END AS TransactionState,
    CASE at.transaction_type
        WHEN 1 THEN N'read/write'
        WHEN 2 THEN N'read-only'
        WHEN 3 THEN N'system'
        WHEN 4 THEN N'distributed'
        ELSE N'unknown'
    END AS TransactionType,
    at.transaction_begin_time AS TransactionBeginTime,
    DATEDIFF(MINUTE, at.transaction_begin_time, SYSDATETIME()) AS AgeMinutes,
    COALESCE(tx.open_transaction_count, 0) AS OpenTransactionCount,
    NULLIF(r.blocking_session_id, 0) AS BlockingSessionID,
    r.wait_type AS WaitType,
    r.wait_time AS WaitTimeMs,
    r.wait_resource AS WaitResource,
    r.command AS CommandText,
    CASE
        WHEN r.sql_handle IS NULL OR txt.text IS NULL THEN NULL
        ELSE LTRIM(RTRIM(
            SUBSTRING(
                txt.text,
                (r.statement_start_offset / 2) + 1,
                CASE
                    WHEN r.statement_end_offset IS NULL OR r.statement_end_offset < 0
                        THEN LEN(CONVERT(NVARCHAR(MAX), txt.text))
                    ELSE ((r.statement_end_offset - r.statement_start_offset) / 2) + 1
                END
            )
        ))
    END AS StatementSnippet,
    CASE
        WHEN NULLIF(r.blocking_session_id, 0) IS NOT NULL
            THEN N'Transaktion wartet bereits auf einen Blocker; Host und Programm sollten gegen den Root-Blocker abgeglichen werden.'
        WHEN s.status = N'sleeping' AND COALESCE(tx.open_transaction_count, 0) > 0
            THEN N'Sleeping Session mit offener Transaktion; typische Kandidatin fuer vergessene COMMIT- oder ROLLBACK-Grenzen.'
        WHEN DATEDIFF(MINUTE, at.transaction_begin_time, SYSDATETIME()) >= 60
            THEN N'Sehr lange Laufzeit; Host und Programm verdienen eine priorisierte Review auf Batch-Groesse und Commit-Frequenz.'
        WHEN COALESCE(tx.open_transaction_count, 0) > 1
            THEN N'Mehrere offene Transaktionen auf derselben Session; Ownership und Error-Handling sollten geprueft werden.'
        ELSE N'Lange Transaktion ohne akuten Blocking-Hinweis; als Baseline fuer Host- oder Programm-Audits geeignet.'
    END AS AuditComment
FROM sys.dm_tran_session_transactions AS tst
INNER JOIN sys.dm_tran_active_transactions AS at
    ON at.transaction_id = tst.transaction_id
INNER JOIN sys.dm_exec_sessions AS s
    ON s.session_id = tst.session_id
LEFT JOIN sys.dm_exec_requests AS r
    ON r.session_id = s.session_id
LEFT JOIN
(
    SELECT
        session_id,
        COUNT_BIG(*) AS open_transaction_count
    FROM sys.dm_tran_session_transactions
    GROUP BY
        session_id
) AS tx
    ON tx.session_id = s.session_id
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) AS txt
WHERE s.is_user_process = 1
  AND s.session_id <> @@SPID
  AND at.transaction_begin_time IS NOT NULL
  AND DATEDIFF(MINUTE, at.transaction_begin_time, SYSDATETIME()) >= @MinimumAgeMinutes
  AND COALESCE(tx.open_transaction_count, 0) >= @MinimumOpenTransactionCount;

-- 3. Verdichtung nach Host und Programm vorbereiten
CREATE TABLE #HostProgramSummary
(
    HostName                    NVARCHAR(128)   NOT NULL,
    ProgramName                 NVARCHAR(128)   NOT NULL,
    SessionsInScope             INT             NOT NULL,
    DistinctLogins              INT             NOT NULL,
    DistinctDatabases           INT             NOT NULL,
    LongestAgeMinutes           INT             NOT NULL,
    MaxOpenTransactionCount     INT             NOT NULL,
    BlockedSessions             INT             NOT NULL,
    SleepingSessions            INT             NOT NULL,
    DominantWaitType            NVARCHAR(120)   NULL,
    SummaryComment              NVARCHAR(220)   NOT NULL
);

INSERT INTO #HostProgramSummary
(
    HostName,
    ProgramName,
    SessionsInScope,
    DistinctLogins,
    DistinctDatabases,
    LongestAgeMinutes,
    MaxOpenTransactionCount,
    BlockedSessions,
    SleepingSessions,
    DominantWaitType,
    SummaryComment
)
SELECT
    lta.HostName,
    lta.ProgramName,
    COUNT(*) AS SessionsInScope,
    COUNT(DISTINCT ISNULL(lta.LoginName, N'')) AS DistinctLogins,
    COUNT(DISTINCT ISNULL(lta.DatabaseName, N'')) AS DistinctDatabases,
    MAX(lta.AgeMinutes) AS LongestAgeMinutes,
    MAX(lta.OpenTransactionCount) AS MaxOpenTransactionCount,
    SUM(CASE WHEN lta.BlockingSessionID IS NOT NULL THEN 1 ELSE 0 END) AS BlockedSessions,
    SUM(CASE WHEN lta.SessionStatus = N'sleeping' THEN 1 ELSE 0 END) AS SleepingSessions,
    MAX(CASE WHEN lta.WaitTimeMs = wt.MaxWaitTimeMs THEN lta.WaitType END) AS DominantWaitType,
    CASE
        WHEN MAX(lta.AgeMinutes) >= 60 AND SUM(CASE WHEN lta.BlockingSessionID IS NOT NULL THEN 1 ELSE 0 END) > 0
            THEN N'Host oder Programm erzeugt sehr lange und bereits blockierte Transaktionen; Review mit Anwendungsteam priorisieren.'
        WHEN SUM(CASE WHEN lta.SessionStatus = N'sleeping' THEN 1 ELSE 0 END) > 0
            THEN N'Host oder Programm haelt offene Transaktionen in sleeping Sessions; Transaktionsgrenzen und Connection-Handling pruefen.'
        WHEN MAX(lta.OpenTransactionCount) > 1
            THEN N'Host oder Programm zeigt mehrere offene Transaktionen pro Session; Retry- und Fehlerpfade sollten geprueft werden.'
        ELSE N'Host oder Programm ist im Scope, aber aktuell ohne klaren Eskalationshinweis; fuer Baseline und Verlauf geeignet.'
    END AS SummaryComment
FROM #LongTranAudit AS lta
INNER JOIN
(
    SELECT
        HostName,
        ProgramName,
        MAX(ISNULL(WaitTimeMs, -1)) AS MaxWaitTimeMs
    FROM #LongTranAudit
    GROUP BY
        HostName,
        ProgramName
) AS wt
    ON wt.HostName = lta.HostName
   AND wt.ProgramName = lta.ProgramName
GROUP BY
    lta.HostName,
    lta.ProgramName;

-- 4. Review-Guide aus dem Audit ableiten
CREATE TABLE #ReviewGuide
(
    StepNo                      TINYINT         NOT NULL,
    FocusArea                   VARCHAR(80)     NOT NULL,
    TriggerDescription          VARCHAR(220)    NOT NULL,
    RecommendedNextStep         VARCHAR(220)    NOT NULL,
    WhyItHelps                  VARCHAR(220)    NOT NULL
);

INSERT INTO #ReviewGuide
(
    StepNo,
    FocusArea,
    TriggerDescription,
    RecommendedNextStep,
    WhyItHelps
)
SELECT
    1,
    'Host-program hotspot',
    'Mindestens ein Host-Programm-Paar haelt Transaktionen laenger als 60 Minuten.',
    'Mit dem betroffenen Anwendungsteam Batch-Groesse, Commit-Frequenz und Timeout-Verhalten abstimmen.',
    'Die Verdichtung pro Host und Programm zeigt schneller, welche Clients wiederholt lange Transaktionen offen halten.'
WHERE EXISTS
(
    SELECT 1
    FROM #HostProgramSummary AS hps
    WHERE hps.LongestAgeMinutes >= 60
);

INSERT INTO #ReviewGuide
(
    StepNo,
    FocusArea,
    TriggerDescription,
    RecommendedNextStep,
    WhyItHelps
)
SELECT
    2,
    'Sleeping transaction owners',
    'Mindestens eine sleeping Session hat weiterhin offene Transaktionen.',
    'Connection-Pooling, explizite COMMIT-Pfade und Fehlerbehandlung der betreffenden Anwendung pruefen.',
    'Sleeping Sessions mit offenen Transaktionen bleiben im Betrieb leicht unbemerkt und verursachen dennoch Sperren.'
WHERE EXISTS
(
    SELECT 1
    FROM #LongTranAudit AS lta
    WHERE lta.SessionStatus = N'sleeping'
      AND lta.OpenTransactionCount > 0
);

INSERT INTO #ReviewGuide
(
    StepNo,
    FocusArea,
    TriggerDescription,
    RecommendedNextStep,
    WhyItHelps
)
SELECT
    3,
    'Blocking context',
    'Mindestens eine lange Transaktion wartet bereits auf einen Blocker.',
    'Root-Blocker, WaitResource und StatementSnippet gemeinsam analysieren statt nur die wartende Session zu betrachten.',
    'So wird das Host- und Programm-Audit direkt mit dem eigentlichen Blocking-Ausloeser verbunden.'
WHERE EXISTS
(
    SELECT 1
    FROM #LongTranAudit AS lta
    WHERE lta.BlockingSessionID IS NOT NULL
);

INSERT INTO #ReviewGuide
(
    StepNo,
    FocusArea,
    TriggerDescription,
    RecommendedNextStep,
    WhyItHelps
)
SELECT
    4,
    'No current findings',
    'Aktuell liegen keine langen Benutzertransaktionen im definierten Scope vor.',
    'Parameter senken oder das Audit waehrend der naechsten Stoerung erneut ausfuehren.',
    'Das Skript eignet sich dann als Baseline, auch wenn im Moment keine akuten Faelle sichtbar sind.'
WHERE NOT EXISTS
(
    SELECT 1
    FROM #LongTranAudit
);

-- 5. Ergebnisse ausgeben
SELECT
    lta.SessionID,
    lta.TransactionID,
    lta.DatabaseName,
    lta.HostName,
    lta.ProgramName,
    lta.LoginName,
    lta.SessionStatus,
    lta.RequestStatus,
    lta.TransactionName,
    lta.TransactionState,
    lta.TransactionType,
    lta.TransactionBeginTime,
    lta.AgeMinutes,
    lta.OpenTransactionCount,
    lta.BlockingSessionID,
    lta.WaitType,
    lta.WaitTimeMs,
    lta.WaitResource,
    lta.CommandText,
    lta.StatementSnippet,
    lta.AuditComment
FROM #LongTranAudit AS lta
ORDER BY
    lta.AgeMinutes DESC,
    lta.OpenTransactionCount DESC,
    lta.HostName,
    lta.ProgramName,
    lta.SessionID;

SELECT
    hps.HostName,
    hps.ProgramName,
    hps.SessionsInScope,
    hps.DistinctLogins,
    hps.DistinctDatabases,
    hps.LongestAgeMinutes,
    hps.MaxOpenTransactionCount,
    hps.BlockedSessions,
    hps.SleepingSessions,
    hps.DominantWaitType,
    hps.SummaryComment
FROM #HostProgramSummary AS hps
ORDER BY
    hps.LongestAgeMinutes DESC,
    hps.BlockedSessions DESC,
    hps.MaxOpenTransactionCount DESC,
    hps.HostName,
    hps.ProgramName;

IF @IncludeGuide = 1
BEGIN
    SELECT
        rg.StepNo,
        rg.FocusArea,
        rg.TriggerDescription,
        rg.RecommendedNextStep,
        rg.WhyItHelps
    FROM #ReviewGuide AS rg
    ORDER BY
        rg.StepNo;
END;
