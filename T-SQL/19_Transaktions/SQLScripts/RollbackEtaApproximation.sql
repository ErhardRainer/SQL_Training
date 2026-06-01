/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "RollbackEtaApproximation.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "19_Transaktions"

purpose: >
  Versucht fuer laufende Rollbacks eine grobe ETA abzuschaetzen, indem
  DMV-Fortschrittswerte, beobachtete Laufzeit, Wait-Signale und eine
  konservative Fallback-Heuristik in einer lesbaren Diagnose kombiniert werden.

parameters:
  - name: "@MinimumPercentComplete"
    sql_type: "DECIMAL(5,2)"
    direction: "IN"
    required: false
    description: "Filtert auf Rollbacks ab diesem gemeldeten Prozentfortschritt"
  - name: "@MinimumRollbackAgeMinutes"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Filtert auf Rollbacks, die mindestens so lange laufen"
  - name: "@IncludeGuidance"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zusaetzlich einen Leitfaden fuer die Einordnung der ETA ausgeben"

result_sets:
  - name: "RollbackEtaSamples"
    description: "Zeigt laufende Rollbacks mit gemeldeter und heuristisch abgeleiteter ETA"
  - name: "RollbackEtaPrioritySummary"
    description: "Verdichtet Rollbacks nach Zuverlaessigkeit der ETA und operativer Prioritaet"
  - name: "EtaGuidance"
    description: "Ordnet typische ETA-Situationen passenden Review-Hinweisen zu"

dependencies:
  - "sys.dm_exec_requests"
  - "sys.dm_exec_sessions"
  - "sys.dm_exec_connections"
  - "sys.dm_exec_sql_text"
  - "sys.dm_tran_session_transactions"
  - "sys.dm_tran_active_transactions"
  - "sys.dm_tran_database_transactions"
  - "sys.databases"
  - "SYSUTCDATETIME"
  - "DATEDIFF"
  - "DATEADD"
  - "CASE"
  - "tempdb temporary tables"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/19_Transaktions/SQLScripts/RollbackEtaApproximation.md"
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
    description: "Erstversion fuer konservative ETA-Abschaetzungen bei laufenden Rollbacks"

notes:
  - "Die ETA bleibt eine Diagnose-Naeherung; percent_complete und estimated_completion_time koennen fehlen oder springen."
  - "Das Skript fuehrt keine KILL-, ROLLBACK- oder Recovery-Aktionen aus und dient nur der Beobachtung."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

-- 1. Parameter vorbereiten
DECLARE @MinimumPercentComplete DECIMAL(5,2) = 0.00;
DECLARE @MinimumRollbackAgeMinutes INT = 0;
DECLARE @IncludeGuidance BIT = 1;

IF @MinimumPercentComplete < 0 OR @MinimumPercentComplete > 100
BEGIN
    THROW 50000, '@MinimumPercentComplete muss zwischen 0 und 100 liegen.', 1;
END;

IF @MinimumRollbackAgeMinutes < 0
BEGIN
    THROW 50001, '@MinimumRollbackAgeMinutes darf nicht negativ sein.', 1;
END;

IF @IncludeGuidance NOT IN (0, 1)
BEGIN
    THROW 50002, '@IncludeGuidance muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #RollbackEtaSamples;
DROP TABLE IF EXISTS #RollbackEtaPrioritySummary;
DROP TABLE IF EXISTS #EtaGuidance;

-- 2. Beobachtungsbasis aufbauen
CREATE TABLE #RollbackEtaSamples
(
    SampleCapturedAtUtc                 DATETIME2(0)    NOT NULL,
    SessionId                           SMALLINT        NULL,
    DatabaseName                        SYSNAME         NULL,
    TransactionId                       BIGINT          NULL,
    TransactionName                     NVARCHAR(64)    NULL,
    RequestStatus                       NVARCHAR(30)    NULL,
    RequestCommand                      NVARCHAR(32)    NULL,
    TransactionState                    NVARCHAR(40)    NOT NULL,
    RollbackAgeMinutes                  INT             NULL,
    PercentComplete                     DECIMAL(6,2)    NULL,
    DmvEstimatedCompletionMs            BIGINT          NULL,
    DmvEstimatedCompletionMinutes       DECIMAL(18,2)   NULL,
    HeuristicRemainingMinutes           DECIMAL(18,2)   NULL,
    ApproxEtaUtc                        DATETIME2(0)    NULL,
    EtaSource                           VARCHAR(40)     NOT NULL,
    EtaConfidence                       VARCHAR(16)     NOT NULL,
    BlockingSessionId                   SMALLINT        NULL,
    WaitType                            NVARCHAR(120)   NULL,
    WaitTimeMs                          INT             NULL,
    OpenTransactionCount                INT             NULL,
    DatabaseLogUsedMB                   DECIMAL(18,2)   NULL,
    DatabaseLogReservedMB               DECIMAL(18,2)   NULL,
    LoginName                           NVARCHAR(128)   NULL,
    HostName                            NVARCHAR(128)   NULL,
    ProgramName                         NVARCHAR(128)   NULL,
    ClientNetAddress                    VARCHAR(48)     NULL,
    StatementSnippet                    NVARCHAR(4000)  NULL,
    ReviewSignal                        VARCHAR(20)     NOT NULL,
    ReviewHint                          VARCHAR(260)    NOT NULL
);

INSERT INTO #RollbackEtaSamples
(
    SampleCapturedAtUtc,
    SessionId,
    DatabaseName,
    TransactionId,
    TransactionName,
    RequestStatus,
    RequestCommand,
    TransactionState,
    RollbackAgeMinutes,
    PercentComplete,
    DmvEstimatedCompletionMs,
    DmvEstimatedCompletionMinutes,
    HeuristicRemainingMinutes,
    ApproxEtaUtc,
    EtaSource,
    EtaConfidence,
    BlockingSessionId,
    WaitType,
    WaitTimeMs,
    OpenTransactionCount,
    DatabaseLogUsedMB,
    DatabaseLogReservedMB,
    LoginName,
    HostName,
    ProgramName,
    ClientNetAddress,
    StatementSnippet,
    ReviewSignal,
    ReviewHint
)
SELECT
    base.SampleCapturedAtUtc,
    base.SessionId,
    base.DatabaseName,
    base.TransactionId,
    base.TransactionName,
    base.RequestStatus,
    base.RequestCommand,
    base.TransactionState,
    base.RollbackAgeMinutes,
    base.PercentComplete,
    base.DmvEstimatedCompletionMs,
    base.DmvEstimatedCompletionMinutes,
    base.HeuristicRemainingMinutes,
    CASE
        WHEN base.DmvEstimatedCompletionMs IS NOT NULL
            THEN DATEADD(MILLISECOND, base.DmvEstimatedCompletionMs, base.SampleCapturedAtUtc)
        WHEN base.HeuristicRemainingMinutes IS NOT NULL
            THEN DATEADD(MINUTE, CEILING(base.HeuristicRemainingMinutes), base.SampleCapturedAtUtc)
        ELSE NULL
    END AS ApproxEtaUtc,
    CASE
        WHEN base.DmvEstimatedCompletionMs IS NOT NULL THEN 'dmv-estimated_completion_time'
        WHEN base.HeuristicRemainingMinutes IS NOT NULL THEN 'elapsed-progress-heuristic'
        ELSE 'insufficient-signal'
    END AS EtaSource,
    CASE
        WHEN base.DmvEstimatedCompletionMs IS NOT NULL AND base.PercentComplete >= 10 THEN 'medium'
        WHEN base.DmvEstimatedCompletionMs IS NOT NULL THEN 'low'
        WHEN base.HeuristicRemainingMinutes IS NOT NULL AND base.PercentComplete >= 25 THEN 'low'
        ELSE 'very-low'
    END AS EtaConfidence,
    base.BlockingSessionId,
    base.WaitType,
    base.WaitTimeMs,
    base.OpenTransactionCount,
    base.DatabaseLogUsedMB,
    base.DatabaseLogReservedMB,
    base.LoginName,
    base.HostName,
    base.ProgramName,
    base.ClientNetAddress,
    base.StatementSnippet,
    CASE
        WHEN base.DmvEstimatedCompletionMs IS NULL AND base.HeuristicRemainingMinutes IS NULL THEN 'observe'
        WHEN base.BlockingSessionId IS NOT NULL THEN 'blocked'
        WHEN base.DatabaseLogUsedMB >= 1024 THEN 'log-pressure'
        WHEN base.HeuristicRemainingMinutes >= 60 THEN 'slow'
        ELSE 'monitor'
    END AS ReviewSignal,
    CASE
        WHEN base.DmvEstimatedCompletionMs IS NULL AND base.HeuristicRemainingMinutes IS NULL
            THEN 'Mehrere Samples nehmen; ohne Fortschritt oder ETA-Signal ist nur eine Beobachtung moeglich.'
        WHEN base.BlockingSessionId IS NOT NULL
            THEN 'Blocking parallel pruefen; eine ETA allein erklaert die Wartezeit nicht.'
        WHEN base.DatabaseLogUsedMB >= 1024
            THEN 'Logvolumen eng beobachten und Verlaufssamples sichern, bevor weitere Massnahmen diskutiert werden.'
        WHEN base.HeuristicRemainingMinutes >= 60
            THEN 'ETA als grobe Projektion behandeln und im Verlauf nachmessen, nicht als Fixdatum kommunizieren.'
        ELSE 'ETA als Orientierung verwenden und mit weiteren Samples verifizieren.'
    END AS ReviewHint
FROM
(
    SELECT
        SYSUTCDATETIME() AS SampleCapturedAtUtc,
        r.session_id AS SessionId,
        DB_NAME(COALESCE(r.database_id, dt.database_id, s.database_id)) AS DatabaseName,
        at.transaction_id AS TransactionId,
        at.name AS TransactionName,
        r.status AS RequestStatus,
        r.command AS RequestCommand,
        CASE at.transaction_state
            WHEN 0 THEN 'not initialized'
            WHEN 1 THEN 'initialized'
            WHEN 2 THEN 'active'
            WHEN 3 THEN 'ended read-only'
            WHEN 4 THEN 'commit started'
            WHEN 5 THEN 'prepared'
            WHEN 6 THEN 'committed'
            WHEN 7 THEN 'rolling back'
            WHEN 8 THEN 'rolled back'
            ELSE 'unknown'
        END AS TransactionState,
        CASE
            WHEN at.transaction_begin_time IS NULL THEN NULL
            ELSE DATEDIFF(MINUTE, at.transaction_begin_time, SYSUTCDATETIME())
        END AS RollbackAgeMinutes,
        CONVERT(DECIMAL(6,2), r.percent_complete) AS PercentComplete,
        r.estimated_completion_time AS DmvEstimatedCompletionMs,
        CASE
            WHEN r.estimated_completion_time IS NULL THEN NULL
            ELSE CAST(r.estimated_completion_time / 60000.0 AS DECIMAL(18,2))
        END AS DmvEstimatedCompletionMinutes,
        CASE
            WHEN r.percent_complete IS NULL OR r.percent_complete <= 0 THEN NULL
            WHEN at.transaction_begin_time IS NULL THEN NULL
            ELSE CAST(
                (
                    DATEDIFF(SECOND, at.transaction_begin_time, SYSUTCDATETIME())
                    * (100.0 - r.percent_complete)
                    / NULLIF(r.percent_complete, 0)
                ) / 60.0
                AS DECIMAL(18,2)
            )
        END AS HeuristicRemainingMinutes,
        r.blocking_session_id AS BlockingSessionId,
        r.wait_type AS WaitType,
        r.wait_time AS WaitTimeMs,
        s.open_transaction_count AS OpenTransactionCount,
        CAST(dt.database_transaction_log_bytes_used / 1048576.0 AS DECIMAL(18,2)) AS DatabaseLogUsedMB,
        CAST(dt.database_transaction_log_bytes_reserved / 1048576.0 AS DECIMAL(18,2)) AS DatabaseLogReservedMB,
        s.login_name AS LoginName,
        s.host_name AS HostName,
        s.program_name AS ProgramName,
        c.client_net_address AS ClientNetAddress,
        SUBSTRING(REPLACE(REPLACE(st.text, CHAR(13), ' '), CHAR(10), ' '), 1, 4000) AS StatementSnippet
    FROM sys.dm_exec_requests AS r
    LEFT JOIN sys.dm_exec_sessions AS s
        ON s.session_id = r.session_id
    LEFT JOIN sys.dm_exec_connections AS c
        ON c.session_id = r.session_id
    LEFT JOIN sys.dm_tran_session_transactions AS stx
        ON stx.session_id = r.session_id
    LEFT JOIN sys.dm_tran_active_transactions AS at
        ON at.transaction_id = stx.transaction_id
    LEFT JOIN sys.dm_tran_database_transactions AS dt
        ON dt.transaction_id = at.transaction_id
    OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) AS st
    WHERE
        (
            r.command LIKE 'KILLED/ROLLBACK%'
            OR r.command = 'ROLLBACK'
            OR (at.transaction_state = 7)
        )
        AND (r.percent_complete IS NULL OR r.percent_complete >= @MinimumPercentComplete)
        AND (
            at.transaction_begin_time IS NULL
            OR DATEDIFF(MINUTE, at.transaction_begin_time, SYSUTCDATETIME()) >= @MinimumRollbackAgeMinutes
        )
) AS base;

-- 3. Verdichtung nach ETA-Signal und Prioritaet
SELECT
    COALESCE(DatabaseName, '(unknown)') AS DatabaseName,
    EtaSource,
    EtaConfidence,
    COUNT(*) AS RollbackCount,
    MIN(ApproxEtaUtc) AS EarliestApproxEtaUtc,
    MAX(ApproxEtaUtc) AS LatestApproxEtaUtc,
    AVG(COALESCE(DmvEstimatedCompletionMinutes, HeuristicRemainingMinutes)) AS AvgRemainingMinutes,
    MAX(DatabaseLogUsedMB) AS MaxDatabaseLogUsedMB,
    SUM(CASE WHEN ReviewSignal IN ('blocked', 'log-pressure', 'slow') THEN 1 ELSE 0 END) AS ElevatedReviewSignals
INTO #RollbackEtaPrioritySummary
FROM #RollbackEtaSamples
GROUP BY
    COALESCE(DatabaseName, '(unknown)'),
    EtaSource,
    EtaConfidence;

-- 4. Leitfaden fuer die Einordnung befuellen
CREATE TABLE #EtaGuidance
(
    Situation VARCHAR(60) NOT NULL,
    Meaning VARCHAR(220) NOT NULL,
    RecommendedReview VARCHAR(260) NOT NULL
);

INSERT INTO #EtaGuidance (Situation, Meaning, RecommendedReview)
VALUES
    (
        'dmv eta available',
        'SQL Server liefert eine eigene estimated_completion_time, die aber im Verlauf springen kann.',
        'Mehrere Samples vergleichen und die ETA nicht als exakten Abschlusszeitpunkt kommunizieren.'
    ),
    (
        'heuristic only',
        'Die ETA stammt nur aus Laufzeit und percent_complete und ist daher deutlich unsicherer.',
        'Heuristik nur als grobe Richtung verwenden und weitere Beobachtungspunkte sammeln.'
    ),
    (
        'no eta signal',
        'Weder DMV-ETA noch Fortschrittsprojektion ist belastbar verfuegbar.',
        'Waits, Blocking und Logdruck beobachten; ohne weitere Samples keine feste Restdauer zusagen.'
    ),
    (
        'blocking visible',
        'Parallel sichtbares Blocking kann die wahrgenommene Dauer vergroessern oder Folgeprobleme ausloesen.',
        'Betroffene Session-Kette und Blockierungsfolgen getrennt von der ETA analysieren.'
    ),
    (
        'log pressure',
        'Hohes reserviertes oder genutztes Logvolumen deutet auf laengeres Aufraeumen und Monitoringbedarf hin.',
        'Lognutzung im Verlauf messen und keine voreiligen manuelle Gegenmassnahmen ohne Review ausloesen.'
    );

-- 5. Ausgaben
SELECT
    SampleCapturedAtUtc,
    SessionId,
    DatabaseName,
    TransactionId,
    TransactionName,
    RequestStatus,
    RequestCommand,
    TransactionState,
    RollbackAgeMinutes,
    PercentComplete,
    DmvEstimatedCompletionMinutes,
    HeuristicRemainingMinutes,
    ApproxEtaUtc,
    EtaSource,
    EtaConfidence,
    BlockingSessionId,
    WaitType,
    WaitTimeMs,
    OpenTransactionCount,
    DatabaseLogUsedMB,
    DatabaseLogReservedMB,
    LoginName,
    HostName,
    ProgramName,
    ClientNetAddress,
    StatementSnippet,
    ReviewSignal,
    ReviewHint
FROM #RollbackEtaSamples
ORDER BY
    COALESCE(ApproxEtaUtc, '9999-12-31'),
    COALESCE(DmvEstimatedCompletionMinutes, HeuristicRemainingMinutes, 999999.0),
    DatabaseName,
    SessionId;

SELECT
    DatabaseName,
    EtaSource,
    EtaConfidence,
    RollbackCount,
    EarliestApproxEtaUtc,
    LatestApproxEtaUtc,
    CAST(AvgRemainingMinutes AS DECIMAL(18,2)) AS AvgRemainingMinutes,
    MaxDatabaseLogUsedMB,
    ElevatedReviewSignals
FROM #RollbackEtaPrioritySummary
ORDER BY
    CASE EtaConfidence
        WHEN 'medium' THEN 1
        WHEN 'low' THEN 2
        ELSE 3
    END,
    AvgRemainingMinutes DESC,
    DatabaseName;

IF @IncludeGuidance = 1
BEGIN
    SELECT
        Situation,
        Meaning,
        RecommendedReview
    FROM #EtaGuidance
    ORDER BY Situation;
END;
