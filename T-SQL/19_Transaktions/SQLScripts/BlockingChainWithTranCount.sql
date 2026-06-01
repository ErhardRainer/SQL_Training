/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "BlockingChainWithTranCount.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "19_Transaktions"

purpose: >
  Stellt aktuelle Blocking-Ketten zusammen und kombiniert wartende sowie
  blockierende Sessions mit ihrer Anzahl offener Transaktionen,
  Request-Details und kompakten Diagnosehinweisen. Das Skript hilft dabei,
  akute Blockaden, schlafende Blocker und tiefe Ketten strukturiert zu
  sichten.

parameters:
  - name: "@IncludeSleepingBlockers"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = auch Blocker ohne aktiven Request in die Kettensicht aufnehmen"
  - name: "@MinOpenTransactionCount"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Filtert die Kettensicht auf Sessions mit mindestens so vielen offenen Transaktionen"

result_sets:
  - name: "BlockingChain"
    description: "Zeigt Blocking-Kanten mit Level, Session-Kontext und Transaktionsanzahl"
  - name: "BlockingSummary"
    description: "Verdichtet die aktuelle Blocking-Lage pro Blocker-Session"
  - name: "AlertGuide"
    description: "Leitet naechste Diagnose- oder Review-Schritte aus der Blocking-Lage ab"

dependencies:
  - "sys.dm_exec_sessions"
  - "sys.dm_exec_requests"
  - "sys.dm_tran_session_transactions"
  - "sys.dm_exec_sql_text"
  - "recursive CTE"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/19_Transaktions/SQLScripts/BlockingChainWithTranCount.md"
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
    date: "2026-04-19"
    user: "ER"
    description: "Erstversion der Blocking-Ketten-Diagnose mit Transaktionsanzahl"

notes:
  - "Das Skript liest nur DMVs der aktuellen Instanz und fuehrt keine kill-, commit- oder rollback-Aktionen aus."
  - "Die Sicht setzt uebliche Leserechte auf die verwendeten DMVs voraus."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

-- 1. Parameter vorbereiten
DECLARE @IncludeSleepingBlockers BIT = 1;
DECLARE @MinOpenTransactionCount INT = 0;

IF @IncludeSleepingBlockers NOT IN (0, 1)
BEGIN
    THROW 50000, '@IncludeSleepingBlockers muss 0 oder 1 sein.', 1;
END;

IF @MinOpenTransactionCount < 0
BEGIN
    THROW 50001, '@MinOpenTransactionCount darf nicht negativ sein.', 1;
END;

DROP TABLE IF EXISTS #SessionSnapshot;
DROP TABLE IF EXISTS #BlockingEdges;
DROP TABLE IF EXISTS #BlockingChain;
DROP TABLE IF EXISTS #BlockingSummary;
DROP TABLE IF EXISTS #AlertGuide;

-- 2. Session-, Request- und Transaktionskontext vorbereiten
CREATE TABLE #SessionSnapshot
(
    SessionID                 SMALLINT       NOT NULL PRIMARY KEY,
    IsUserProcess             BIT            NOT NULL,
    SessionStatus             NVARCHAR(30)   NULL,
    LoginName                 NVARCHAR(128)  NULL,
    HostName                  NVARCHAR(128)  NULL,
    ProgramName               NVARCHAR(128)  NULL,
    DatabaseName              SYSNAME        NULL,
    RequestStatus             NVARCHAR(30)   NULL,
    CommandText               NVARCHAR(32)   NULL,
    WaitType                  NVARCHAR(120)  NULL,
    WaitTimeMs                INT            NULL,
    WaitResource              NVARCHAR(256)  NULL,
    BlockingSessionID         SMALLINT       NULL,
    OpenTransactionCount      INT            NOT NULL,
    StatementSnippet          NVARCHAR(4000) NULL
);

INSERT INTO #SessionSnapshot
(
    SessionID,
    IsUserProcess,
    SessionStatus,
    LoginName,
    HostName,
    ProgramName,
    DatabaseName,
    RequestStatus,
    CommandText,
    WaitType,
    WaitTimeMs,
    WaitResource,
    BlockingSessionID,
    OpenTransactionCount,
    StatementSnippet
)
SELECT
    s.session_id,
    s.is_user_process,
    s.status,
    s.login_name,
    s.host_name,
    s.program_name,
    DB_NAME(COALESCE(r.database_id, s.database_id)),
    r.status,
    r.command,
    r.wait_type,
    r.wait_time,
    r.wait_resource,
    NULLIF(r.blocking_session_id, 0),
    COALESCE(tx.open_transaction_count, 0),
    CASE
        WHEN r.sql_handle IS NULL OR txt.text IS NULL THEN NULL
        ELSE
            LTRIM(RTRIM(
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
    END
FROM sys.dm_exec_sessions AS s
LEFT JOIN sys.dm_exec_requests AS r
    ON r.session_id = s.session_id
LEFT JOIN
(
    SELECT
        tst.session_id,
        COUNT_BIG(*) AS open_transaction_count
    FROM sys.dm_tran_session_transactions AS tst
    GROUP BY
        tst.session_id
) AS tx
    ON tx.session_id = s.session_id
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) AS txt
WHERE s.session_id <> @@SPID
  AND s.is_user_process = 1;

-- 3. Wartende Sessions und ihre Blocker extrahieren
CREATE TABLE #BlockingEdges
(
    BlockedSessionID          SMALLINT       NOT NULL,
    BlockingSessionID         SMALLINT       NOT NULL,
    WaitType                  NVARCHAR(120)  NULL,
    WaitTimeMs                INT            NULL,
    WaitResource              NVARCHAR(256)  NULL
);

INSERT INTO #BlockingEdges
(
    BlockedSessionID,
    BlockingSessionID,
    WaitType,
    WaitTimeMs,
    WaitResource
)
SELECT
    ss.SessionID,
    ss.BlockingSessionID,
    ss.WaitType,
    ss.WaitTimeMs,
    ss.WaitResource
FROM #SessionSnapshot AS ss
WHERE ss.BlockingSessionID IS NOT NULL
  AND ss.BlockingSessionID > 0;

-- 4. Rekursive Kettensicht aufbauen
CREATE TABLE #BlockingChain
(
    ChainRootSessionID        SMALLINT       NOT NULL,
    ChainLevel                INT            NOT NULL,
    BlockingSessionID         SMALLINT       NOT NULL,
    BlockedSessionID          SMALLINT       NOT NULL,
    BlockingSessionStatus     NVARCHAR(30)   NULL,
    BlockedSessionStatus      NVARCHAR(30)   NULL,
    BlockingDatabaseName      SYSNAME        NULL,
    BlockedDatabaseName       SYSNAME        NULL,
    BlockingOpenTranCount     INT            NOT NULL,
    BlockedOpenTranCount      INT            NOT NULL,
    WaitType                  NVARCHAR(120)  NULL,
    WaitTimeMs                INT            NULL,
    WaitResource              NVARCHAR(256)  NULL,
    BlockingCommand           NVARCHAR(32)   NULL,
    BlockedCommand            NVARCHAR(32)   NULL,
    BlockingLoginName         NVARCHAR(128)  NULL,
    BlockedLoginName          NVARCHAR(128)  NULL,
    BlockingHostName          NVARCHAR(128)  NULL,
    BlockedHostName           NVARCHAR(128)  NULL,
    BlockingProgramName       NVARCHAR(128)  NULL,
    BlockedProgramName        NVARCHAR(128)  NULL,
    BlockingStatementSnippet  NVARCHAR(4000) NULL,
    BlockedStatementSnippet   NVARCHAR(4000) NULL
);

;WITH roots AS
(
    SELECT DISTINCT
        be.BlockingSessionID AS ChainRootSessionID
    FROM #BlockingEdges AS be
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM #BlockingEdges AS parent_edge
        WHERE parent_edge.BlockedSessionID = be.BlockingSessionID
    )
),
chain_cte AS
(
    SELECT
        r.ChainRootSessionID,
        CAST(1 AS INT) AS ChainLevel,
        be.BlockingSessionID,
        be.BlockedSessionID,
        CAST(CONCAT('>', be.BlockingSessionID, '>', be.BlockedSessionID, '>') AS NVARCHAR(4000)) AS PathToken,
        be.WaitType,
        be.WaitTimeMs,
        be.WaitResource
    FROM roots AS r
    INNER JOIN #BlockingEdges AS be
        ON be.BlockingSessionID = r.ChainRootSessionID

    UNION ALL

    SELECT
        c.ChainRootSessionID,
        c.ChainLevel + 1,
        be.BlockingSessionID,
        be.BlockedSessionID,
        CAST(c.PathToken + CAST(be.BlockedSessionID AS NVARCHAR(20)) + '>' AS NVARCHAR(4000)),
        be.WaitType,
        be.WaitTimeMs,
        be.WaitResource
    FROM chain_cte AS c
    INNER JOIN #BlockingEdges AS be
        ON be.BlockingSessionID = c.BlockedSessionID
    WHERE c.PathToken NOT LIKE CONCAT('%>', be.BlockedSessionID, '>%')
)
INSERT INTO #BlockingChain
(
    ChainRootSessionID,
    ChainLevel,
    BlockingSessionID,
    BlockedSessionID,
    BlockingSessionStatus,
    BlockedSessionStatus,
    BlockingDatabaseName,
    BlockedDatabaseName,
    BlockingOpenTranCount,
    BlockedOpenTranCount,
    WaitType,
    WaitTimeMs,
    WaitResource,
    BlockingCommand,
    BlockedCommand,
    BlockingLoginName,
    BlockedLoginName,
    BlockingHostName,
    BlockedHostName,
    BlockingProgramName,
    BlockedProgramName,
    BlockingStatementSnippet,
    BlockedStatementSnippet
)
SELECT
    c.ChainRootSessionID,
    c.ChainLevel,
    c.BlockingSessionID,
    c.BlockedSessionID,
    blocker.SessionStatus,
    blocked.SessionStatus,
    blocker.DatabaseName,
    blocked.DatabaseName,
    blocker.OpenTransactionCount,
    blocked.OpenTransactionCount,
    c.WaitType,
    c.WaitTimeMs,
    c.WaitResource,
    blocker.CommandText,
    blocked.CommandText,
    blocker.LoginName,
    blocked.LoginName,
    blocker.HostName,
    blocked.HostName,
    blocker.ProgramName,
    blocked.ProgramName,
    blocker.StatementSnippet,
    blocked.StatementSnippet
FROM chain_cte AS c
INNER JOIN #SessionSnapshot AS blocker
    ON blocker.SessionID = c.BlockingSessionID
INNER JOIN #SessionSnapshot AS blocked
    ON blocked.SessionID = c.BlockedSessionID
WHERE (@IncludeSleepingBlockers = 1 OR blocker.RequestStatus IS NOT NULL)
  AND (blocker.OpenTransactionCount >= @MinOpenTransactionCount
       OR blocked.OpenTransactionCount >= @MinOpenTransactionCount)
OPTION (MAXRECURSION 32);

-- 5. Kompakte Zusammenfassung pro Blocker aufbauen
CREATE TABLE #BlockingSummary
(
    BlockingSessionID         SMALLINT       NOT NULL,
    ChainRootSessionID        SMALLINT       NOT NULL,
    SessionsBlocked           INT            NOT NULL,
    DeepestChainLevel         INT            NOT NULL,
    BlockingOpenTranCount     INT            NOT NULL,
    BlockingSessionStatus     NVARCHAR(30)   NULL,
    BlockingDatabaseName      SYSNAME        NULL,
    BlockingLoginName         NVARCHAR(128)  NULL,
    BlockingHostName          NVARCHAR(128)  NULL,
    BlockingProgramName       NVARCHAR(128)  NULL,
    LongestWaitMs             INT            NULL,
    MostCommonWaitType        NVARCHAR(120)  NULL,
    BlockingStatementSnippet  NVARCHAR(4000) NULL
);

INSERT INTO #BlockingSummary
(
    BlockingSessionID,
    ChainRootSessionID,
    SessionsBlocked,
    DeepestChainLevel,
    BlockingOpenTranCount,
    BlockingSessionStatus,
    BlockingDatabaseName,
    BlockingLoginName,
    BlockingHostName,
    BlockingProgramName,
    LongestWaitMs,
    MostCommonWaitType,
    BlockingStatementSnippet
)
SELECT
    bc.BlockingSessionID,
    MIN(bc.ChainRootSessionID) AS ChainRootSessionID,
    COUNT(*) AS SessionsBlocked,
    MAX(bc.ChainLevel) AS DeepestChainLevel,
    MAX(bc.BlockingOpenTranCount) AS BlockingOpenTranCount,
    MAX(bc.BlockingSessionStatus) AS BlockingSessionStatus,
    MAX(bc.BlockingDatabaseName) AS BlockingDatabaseName,
    MAX(bc.BlockingLoginName) AS BlockingLoginName,
    MAX(bc.BlockingHostName) AS BlockingHostName,
    MAX(bc.BlockingProgramName) AS BlockingProgramName,
    MAX(bc.WaitTimeMs) AS LongestWaitMs,
    MAX(CASE WHEN bc.WaitTimeMs = max_waits.MaxWaitTimeMs THEN bc.WaitType END) AS MostCommonWaitType,
    MAX(bc.BlockingStatementSnippet) AS BlockingStatementSnippet
FROM #BlockingChain AS bc
INNER JOIN
(
    SELECT
        BlockingSessionID,
        MAX(WaitTimeMs) AS MaxWaitTimeMs
    FROM #BlockingChain
    GROUP BY
        BlockingSessionID
) AS max_waits
    ON max_waits.BlockingSessionID = bc.BlockingSessionID
GROUP BY
    bc.BlockingSessionID;

-- 6. Alert-Guide aus Diagnosemustern ableiten
CREATE TABLE #AlertGuide
(
    PriorityOrder             TINYINT        NOT NULL,
    AlertType                 VARCHAR(50)    NOT NULL,
    TriggerDescription        VARCHAR(220)   NOT NULL,
    WhyItMatters              VARCHAR(220)   NOT NULL,
    RecommendedNextStep       VARCHAR(220)   NOT NULL
);

INSERT INTO #AlertGuide
(
    PriorityOrder,
    AlertType,
    TriggerDescription,
    WhyItMatters,
    RecommendedNextStep
)
SELECT
    1,
    'Sleeping blocker',
    'Mindestens ein Blocker ist sleeping oder hat keinen aktiven Request, blockiert aber weiterhin andere Sessions.',
    'Offene Transaktionen bleiben oft unbemerkt offen und halten Sperren laenger als erwartet.',
    'Zuletzt ausgefuehrte Aktion, Transaktionsgrenzen und Anwendungskontext des Blockers pruefen.'
WHERE EXISTS
(
    SELECT 1
    FROM #BlockingSummary AS bs
    WHERE bs.BlockingSessionStatus = 'sleeping'
);

INSERT INTO #AlertGuide
(
    PriorityOrder,
    AlertType,
    TriggerDescription,
    WhyItMatters,
    RecommendedNextStep
)
SELECT
    2,
    'Multiple open transactions',
    'Mindestens ein Blocker hat mehr als eine offene Transaktion.',
    'Mehrere offene Transaktionen vergroessern die Wahrscheinlichkeit fuer lang anhaltende Sperren und unklare Ownership.',
    'Transaktionszaehler mit Fachcode, Retry-Logik und expliziten COMMIT- oder ROLLBACK-Pfaden abgleichen.'
WHERE EXISTS
(
    SELECT 1
    FROM #BlockingSummary AS bs
    WHERE bs.BlockingOpenTranCount > 1
);

INSERT INTO #AlertGuide
(
    PriorityOrder,
    AlertType,
    TriggerDescription,
    WhyItMatters,
    RecommendedNextStep
)
SELECT
    3,
    'Deep blocking chain',
    'Eine Blocking-Kette hat mindestens drei Ebenen.',
    'Tiefe Ketten erschweren die Ursachenanalyse, weil Symptome und eigentliche Ursache zeitlich auseinanderfallen.',
    'Mit der Root-Session beginnen und dann die Kette entlang von ChainLevel und WaitResource nachvollziehen.'
WHERE EXISTS
(
    SELECT 1
    FROM #BlockingSummary AS bs
    WHERE bs.DeepestChainLevel >= 3
);

INSERT INTO #AlertGuide
(
    PriorityOrder,
    AlertType,
    TriggerDescription,
    WhyItMatters,
    RecommendedNextStep
)
SELECT
    4,
    'No current blocking',
    'Aktuell wurde keine Blocking-Kette gefunden.',
    'Die Umgebung ist momentan ruhig oder das Blocking ist bereits aufgeloest.',
    'Skript bei der naechsten Stoerung erneut ausfuehren oder um ein periodisches Monitoring ergaenzen.'
WHERE NOT EXISTS
(
    SELECT 1
    FROM #BlockingChain
);

-- 7. Ergebnisse ausgeben
SELECT
    bc.ChainRootSessionID,
    bc.ChainLevel,
    bc.BlockingSessionID,
    bc.BlockedSessionID,
    bc.BlockingSessionStatus,
    bc.BlockedSessionStatus,
    bc.BlockingDatabaseName,
    bc.BlockedDatabaseName,
    bc.BlockingOpenTranCount,
    bc.BlockedOpenTranCount,
    bc.WaitType,
    bc.WaitTimeMs,
    bc.WaitResource,
    bc.BlockingCommand,
    bc.BlockedCommand,
    bc.BlockingLoginName,
    bc.BlockedLoginName,
    bc.BlockingHostName,
    bc.BlockedHostName,
    bc.BlockingProgramName,
    bc.BlockedProgramName,
    bc.BlockingStatementSnippet,
    bc.BlockedStatementSnippet
FROM #BlockingChain AS bc
ORDER BY
    bc.ChainRootSessionID,
    bc.ChainLevel,
    bc.BlockingSessionID,
    bc.BlockedSessionID;

SELECT
    bs.BlockingSessionID,
    bs.ChainRootSessionID,
    bs.SessionsBlocked,
    bs.DeepestChainLevel,
    bs.BlockingOpenTranCount,
    bs.BlockingSessionStatus,
    bs.BlockingDatabaseName,
    bs.BlockingLoginName,
    bs.BlockingHostName,
    bs.BlockingProgramName,
    bs.LongestWaitMs,
    bs.MostCommonWaitType,
    bs.BlockingStatementSnippet
FROM #BlockingSummary AS bs
ORDER BY
    bs.SessionsBlocked DESC,
    bs.DeepestChainLevel DESC,
    bs.BlockingOpenTranCount DESC,
    bs.BlockingSessionID;

SELECT
    ag.PriorityOrder,
    ag.AlertType,
    ag.TriggerDescription,
    ag.WhyItMatters,
    ag.RecommendedNextStep
FROM #AlertGuide AS ag
ORDER BY
    ag.PriorityOrder;
