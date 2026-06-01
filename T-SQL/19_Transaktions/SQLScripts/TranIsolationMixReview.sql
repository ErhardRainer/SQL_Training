/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "TranIsolationMixReview.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "19_Transaktions"

purpose: >
  Reviewt aktuelle Sessions auf gemischte Transaktions-Isolationsstufen
  innerhalb vergleichbarer Workload-Gruppen und verbindet die Session-Sicht
  mit Datenbank-, Wait- und Programm-Kontext.

parameters:
  - name: "@IncludeSystemSessions"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = System-Sessions mit aufnehmen, 0 = nur Benutzer-Sessions betrachten"
  - name: "@MinimumSessionCountForAlert"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Mindestanzahl Sessions pro Workload-Gruppe, bevor eine gemischte Isolationslage als Alert erscheint"
  - name: "@IncludeGuide"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zusaetzlich einen didaktischen Review-Guide ausgeben"

result_sets:
  - name: "SessionIsolationInventory"
    description: "Zeigt aktuelle Sessions mit Isolation, Datenbank, Wait- und Workload-Kontext"
  - name: "IsolationMixSummary"
    description: "Verdichtet Workload-Gruppen mit einer oder mehreren beobachteten Isolationsstufen"
  - name: "ReviewGuide"
    description: "Leitet naechste Review-Schritte fuer gemischte Isolationslagen ab"

dependencies:
  - "sys.dm_exec_sessions"
  - "sys.dm_exec_requests"
  - "sys.dm_exec_connections"
  - "sys.dm_exec_sql_text"
  - "sys.databases"
  - "DB_NAME"
  - "SYSUTCDATETIME"
  - "DATEDIFF"
  - "STRING_AGG"
  - "CASE"
  - "ORDER BY"
  - "tempdb temporary tables"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/19_Transaktions/SQLScripts/TranIsolationMixReview.md"
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
    description: "Erstversion des Diagnose-Skripts fuer gemischte Isolationsstufen in aktuellen Sessions"

notes:
  - "Das Skript liest nur aktuelle DMV-Daten und bewertet keine Anwendung als fehlerhaft."
  - "Gemischte Isolationsstufen koennen legitim sein; die Ausgabe dient als Review- und Abstimmungshilfe."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

-- 1. Parameter vorbereiten
DECLARE @IncludeSystemSessions BIT = 0;
DECLARE @MinimumSessionCountForAlert INT = 2;
DECLARE @IncludeGuide BIT = 1;

IF @IncludeSystemSessions NOT IN (0, 1)
BEGIN
    THROW 50000, '@IncludeSystemSessions muss 0 oder 1 sein.', 1;
END;

IF @MinimumSessionCountForAlert < 1
BEGIN
    THROW 50001, '@MinimumSessionCountForAlert muss mindestens 1 sein.', 1;
END;

IF @IncludeGuide NOT IN (0, 1)
BEGIN
    THROW 50002, '@IncludeGuide muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #SessionIsolationInventory;
DROP TABLE IF EXISTS #IsolationMixSummary;
DROP TABLE IF EXISTS #ReviewGuide;

-- 2. Aktuelle Sessions mit Isolations-, Request- und Workload-Kontext erfassen
CREATE TABLE #SessionIsolationInventory
(
    SessionId                    SMALLINT         NOT NULL,
    IsUserProcess                BIT              NOT NULL,
    SessionStatus                NVARCHAR(30)     NULL,
    RequestStatus                NVARCHAR(30)     NULL,
    DatabaseName                 SYSNAME          NULL,
    LoginName                    NVARCHAR(128)    NULL,
    HostName                     NVARCHAR(128)    NULL,
    ProgramName                  NVARCHAR(128)    NULL,
    ClientNetAddress             VARCHAR(48)      NULL,
    TransactionIsolationLevel    NVARCHAR(40)     NOT NULL,
    IsolationFamily              NVARCHAR(40)     NOT NULL,
    OpenTransactionCount         INT              NULL,
    RequestCommand               NVARCHAR(32)     NULL,
    WaitType                     NVARCHAR(120)    NULL,
    WaitTimeMs                   INT              NULL,
    StatementSnippet             NVARCHAR(4000)   NULL,
    LastRequestAgeMinutes        INT              NULL,
    WorkloadGroup                NVARCHAR(300)    NOT NULL,
    ReviewSignal                 VARCHAR(220)     NOT NULL
);

INSERT INTO #SessionIsolationInventory
(
    SessionId,
    IsUserProcess,
    SessionStatus,
    RequestStatus,
    DatabaseName,
    LoginName,
    HostName,
    ProgramName,
    ClientNetAddress,
    TransactionIsolationLevel,
    IsolationFamily,
    OpenTransactionCount,
    RequestCommand,
    WaitType,
    WaitTimeMs,
    StatementSnippet,
    LastRequestAgeMinutes,
    WorkloadGroup,
    ReviewSignal
)
SELECT
    s.session_id AS SessionId,
    CAST(COALESCE(s.is_user_process, 0) AS BIT) AS IsUserProcess,
    s.status AS SessionStatus,
    r.status AS RequestStatus,
    DB_NAME(COALESCE(r.database_id, s.database_id)) AS DatabaseName,
    s.login_name AS LoginName,
    s.host_name AS HostName,
    s.program_name AS ProgramName,
    c.client_net_address AS ClientNetAddress,
    CASE s.transaction_isolation_level
        WHEN 0 THEN N'unspecified'
        WHEN 1 THEN N'read uncommitted'
        WHEN 2 THEN N'read committed'
        WHEN 3 THEN N'repeatable read'
        WHEN 4 THEN N'serializable'
        WHEN 5 THEN N'snapshot'
        ELSE CONCAT(N'level(', s.transaction_isolation_level, N')')
    END AS TransactionIsolationLevel,
    CASE s.transaction_isolation_level
        WHEN 0 THEN N'unspecified'
        WHEN 1 THEN N'locking-read'
        WHEN 2 THEN N'locking-read'
        WHEN 3 THEN N'locking-read'
        WHEN 4 THEN N'locking-read'
        WHEN 5 THEN N'row-versioning'
        ELSE N'other'
    END AS IsolationFamily,
    s.open_transaction_count AS OpenTransactionCount,
    r.command AS RequestCommand,
    r.wait_type AS WaitType,
    r.wait_time AS WaitTimeMs,
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
        WHEN s.last_request_end_time IS NULL THEN NULL
        ELSE DATEDIFF(MINUTE, s.last_request_end_time, SYSUTCDATETIME())
    END AS LastRequestAgeMinutes,
    CONCAT(
        COALESCE(NULLIF(DB_NAME(COALESCE(r.database_id, s.database_id)), N''), N'<no-db>'),
        N' | ',
        COALESCE(NULLIF(s.program_name, N''), N'<no-program>'),
        N' | ',
        COALESCE(NULLIF(s.host_name, N''), N'<no-host>')
    ) AS WorkloadGroup,
    CASE
        WHEN s.transaction_isolation_level IN (4, 5) AND COALESCE(s.open_transaction_count, 0) > 0
            THEN 'Strenge oder versionierte Isolation mit offener Transaktion im Review behalten.'
        WHEN s.transaction_isolation_level = 1
            THEN 'READ UNCOMMITTED gesondert validieren, falls dieselbe Workload-Gruppe sonst strenger arbeitet.'
        WHEN s.status = N'sleeping' AND COALESCE(s.open_transaction_count, 0) > 0
            THEN 'Sleeping Session mit offener Transaktion separat auf Commit-Pfade pruefen.'
        ELSE 'Session dient als Vergleichspunkt fuer das Isolationsprofil der Gruppe.'
    END AS ReviewSignal
FROM sys.dm_exec_sessions AS s
LEFT JOIN sys.dm_exec_requests AS r
    ON r.session_id = s.session_id
LEFT JOIN sys.dm_exec_connections AS c
    ON c.session_id = s.session_id
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) AS txt
WHERE s.session_id <> @@SPID
  AND (@IncludeSystemSessions = 1 OR COALESCE(s.is_user_process, 0) = 1);

-- 3. Workload-Gruppen auf gemischte Isolationsstufen verdichten
CREATE TABLE #IsolationMixSummary
(
    WorkloadGroup                NVARCHAR(300)    NOT NULL,
    DatabaseName                 SYSNAME          NULL,
    ProgramName                  NVARCHAR(128)    NULL,
    HostName                     NVARCHAR(128)    NULL,
    SessionsInGroup              INT              NOT NULL,
    OpenTransactionSessions      INT              NOT NULL,
    DistinctIsolationLevels      INT              NOT NULL,
    IsolationLevelsObserved      NVARCHAR(400)    NOT NULL,
    HighestRiskSignal            VARCHAR(20)      NOT NULL,
    ReviewRecommendation         VARCHAR(220)     NOT NULL
);

WITH workload_base AS
(
    SELECT
        sii.WorkloadGroup,
        MAX(sii.DatabaseName) AS DatabaseName,
        MAX(sii.ProgramName) AS ProgramName,
        MAX(sii.HostName) AS HostName,
        COUNT(*) AS SessionsInGroup,
        SUM(CASE WHEN COALESCE(sii.OpenTransactionCount, 0) > 0 THEN 1 ELSE 0 END) AS OpenTransactionSessions,
        COUNT(DISTINCT sii.TransactionIsolationLevel) AS DistinctIsolationLevels
    FROM #SessionIsolationInventory AS sii
    GROUP BY
        sii.WorkloadGroup
)
INSERT INTO #IsolationMixSummary
(
    WorkloadGroup,
    DatabaseName,
    ProgramName,
    HostName,
    SessionsInGroup,
    OpenTransactionSessions,
    DistinctIsolationLevels,
    IsolationLevelsObserved,
    HighestRiskSignal,
    ReviewRecommendation
)
SELECT
    wb.WorkloadGroup,
    wb.DatabaseName,
    wb.ProgramName,
    wb.HostName,
    wb.SessionsInGroup,
    wb.OpenTransactionSessions,
    wb.DistinctIsolationLevels,
    level_list.IsolationLevelsObserved,
    CASE
        WHEN wb.DistinctIsolationLevels >= 3 THEN 'high'
        WHEN wb.DistinctIsolationLevels = 2 AND wb.OpenTransactionSessions > 0 THEN 'medium'
        WHEN wb.DistinctIsolationLevels = 2 THEN 'observe'
        ELSE 'baseline'
    END AS HighestRiskSignal,
    CASE
        WHEN wb.DistinctIsolationLevels >= 3
            THEN 'Mehrere Isolationsstufen im selben Workload-Muster gemeinsam mit Statements und Deployment-Historie abstimmen.'
        WHEN wb.DistinctIsolationLevels = 2 AND wb.OpenTransactionSessions > 0
            THEN 'Gemischte Isolation plus offene Transaktionen: Session-Zweck, Sperrbild und erwartete Konsistenz aktiv reviewen.'
        WHEN wb.DistinctIsolationLevels = 2
            THEN 'Abweichende Isolation dokumentieren und pruefen, ob sie bewusst fuer einzelne Pfade gesetzt wurde.'
        ELSE 'Aktuell konsistentes Isolationsprofil innerhalb der beobachteten Workload-Gruppe.'
    END AS ReviewRecommendation
FROM workload_base AS wb
CROSS APPLY
(
    SELECT STRING_AGG(level_value.TransactionIsolationLevel, N', ')
           WITHIN GROUP (ORDER BY level_value.SortWeight, level_value.TransactionIsolationLevel) AS IsolationLevelsObserved
    FROM
    (
        SELECT DISTINCT
            sii.TransactionIsolationLevel,
            CASE sii.TransactionIsolationLevel
                WHEN N'read uncommitted' THEN 1
                WHEN N'read committed' THEN 2
                WHEN N'repeatable read' THEN 3
                WHEN N'serializable' THEN 4
                WHEN N'snapshot' THEN 5
                ELSE 6
            END AS SortWeight
        FROM #SessionIsolationInventory AS sii
        WHERE sii.WorkloadGroup = wb.WorkloadGroup
    ) AS level_value
) AS level_list
WHERE wb.SessionsInGroup >= @MinimumSessionCountForAlert
   OR wb.DistinctIsolationLevels > 1;

-- 4. Review-Guide formulieren
CREATE TABLE #ReviewGuide
(
    GuideStep                    TINYINT          NOT NULL,
    FocusArea                    VARCHAR(80)      NOT NULL,
    TriggerDescription           VARCHAR(220)     NOT NULL,
    RecommendedNextStep          VARCHAR(220)     NOT NULL,
    WhyItHelps                   VARCHAR(220)     NOT NULL
);

INSERT INTO #ReviewGuide
(
    GuideStep,
    FocusArea,
    TriggerDescription,
    RecommendedNextStep,
    WhyItHelps
)
VALUES
    (
        1,
        'Workload grouping',
        'Unterschiedliche Isolation ist erst im gleichen Workload-Muster wirklich interessant.',
        'Gruppierung nach Datenbank, Programm und Host zunaechst gegen reale Deployments oder Batch-Fenster spiegeln.',
        'So werden legitime Unterschiede zwischen Job, Reporting und OLTP nicht vorschnell als Fehler gelesen.'
    ),
    (
        2,
        'Open transactions',
        'Gemischte Isolation mit offenen Transaktionen verdient hoehere Aufmerksamkeit.',
        'Offene Sessions mit StatementSnippet, WaitType und Owner-Kontext zuerst reviewen.',
        'Die Kombination zeigt, ob die Isolation nur konfiguriert oder bereits operativ wirksam ist.'
    ),
    (
        3,
        'Risk interpretation',
        'READ UNCOMMITTED, SERIALIZABLE und SNAPSHOT koennen bewusst, aber folgenreich eingesetzt werden.',
        'Abweichende Stufen mit Konsistenzbedarf, Sperrverhalten und Version-Store-Strategie abstimmen.',
        'Die Diskussion bleibt damit auf beobachtbare Technikfolgen statt auf Namensbewertungen fokussiert.'
    ),
    (
        4,
        'Operational follow-up',
        'Ein Mix ist nicht automatisch falsch, sollte aber nachvollziehbar sein.',
        'Runbook, Codepfade oder Session-Initialisierung pruefen und bewusste Ausnahmen dokumentieren.',
        'Das reduziert Drift zwischen Anwendungserwartung, Monitoring und DBA-Review.'
    );

-- 5. Resultsets ausgeben
SELECT
    sii.SessionId,
    sii.DatabaseName,
    sii.LoginName,
    sii.HostName,
    sii.ProgramName,
    sii.TransactionIsolationLevel,
    sii.IsolationFamily,
    sii.OpenTransactionCount,
    sii.SessionStatus,
    sii.RequestStatus,
    sii.RequestCommand,
    sii.WaitType,
    sii.WaitTimeMs,
    sii.LastRequestAgeMinutes,
    sii.WorkloadGroup,
    sii.ReviewSignal,
    sii.StatementSnippet
FROM #SessionIsolationInventory AS sii
ORDER BY
    sii.WorkloadGroup,
    CASE sii.TransactionIsolationLevel
        WHEN N'read uncommitted' THEN 1
        WHEN N'read committed' THEN 2
        WHEN N'repeatable read' THEN 3
        WHEN N'serializable' THEN 4
        WHEN N'snapshot' THEN 5
        ELSE 6
    END,
    sii.OpenTransactionCount DESC,
    sii.SessionId;

SELECT
    ims.WorkloadGroup,
    ims.DatabaseName,
    ims.ProgramName,
    ims.HostName,
    ims.SessionsInGroup,
    ims.OpenTransactionSessions,
    ims.DistinctIsolationLevels,
    ims.IsolationLevelsObserved,
    ims.HighestRiskSignal,
    ims.ReviewRecommendation
FROM #IsolationMixSummary AS ims
ORDER BY
    CASE ims.HighestRiskSignal
        WHEN 'high' THEN 1
        WHEN 'medium' THEN 2
        WHEN 'observe' THEN 3
        ELSE 4
    END,
    ims.DistinctIsolationLevels DESC,
    ims.SessionsInGroup DESC,
    ims.WorkloadGroup;

IF @IncludeGuide = 1
BEGIN
    SELECT
        rg.GuideStep,
        rg.FocusArea,
        rg.TriggerDescription,
        rg.RecommendedNextStep,
        rg.WhyItHelps
    FROM #ReviewGuide AS rg
    ORDER BY
        rg.GuideStep;
END;
