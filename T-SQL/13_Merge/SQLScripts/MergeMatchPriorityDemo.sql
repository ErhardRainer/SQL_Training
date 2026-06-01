/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "MergeMatchPriorityDemo.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "13_Merge"

purpose: >
  Demonstriert, wie eine vorgelagerte Match-Priorisierung und zusaetzliche
  WHEN MATCHED-Bedingungen das Verhalten eines MERGE steuern.

parameters: []

result_sets:
  - name: "MergeMatchCandidates"
    description: "Zeigt alle ermittelten Match-Kandidaten mit Prioritaet und Ambiguitaetsprofil"
  - name: "MergeMatchResolution"
    description: "Leitet pro Source-Zeile den finalen Merge-Pfad als ExactMatch, FallbackMatch, InsertCandidate oder Review ab"
  - name: "MergeMatchActionSummary"
    description: "Zaehlt MERGE-Aktionen und stellt sie der Match-Prioritaet gegenueber"
  - name: "MergeMatchAudit"
    description: "Dokumentiert pro betroffener Zeile Aktion, Match-Grund und Vorher-Nachher-Werte"
  - name: "MergeMatchTargetAfter"
    description: "Zeigt den Zielbestand nach dem MERGE mitsamt Review-Status"

dependencies:
  - "MERGE"
  - "CTE"
  - "ROW_NUMBER"
  - "OUTPUT $action"
  - "temporary tables"

safety:
  level: "demo-write-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/13_Merge/SQLScripts/MergeMatchPriorityDemo.md"
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
    date: "2026-04-18"
    user: "ER"
    description: "Erstversion eines didaktischen MERGE-Labors fuer Match-Priorisierung und Zusatzbedingungen"

notes:
  - "Die Erstversion arbeitet ausschliesslich mit temporaeren Demo-Tabellen."
  - "Exakte CustomerCode-Treffer erhalten eine hoehere Prioritaet als Legacy-Fallback-Treffer."
  - "Fallback-Matches mit manual-review oder ohne Freigabe werden nur dokumentiert."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DROP TABLE IF EXISTS #MergeTarget;
DROP TABLE IF EXISTS #MergeSource;
DROP TABLE IF EXISTS #MatchCandidates;
DROP TABLE IF EXISTS #ResolvedSource;
DROP TABLE IF EXISTS #MergeAudit;

CREATE TABLE #MergeTarget
(
    AccountId           INT           NOT NULL PRIMARY KEY,
    CustomerCode        VARCHAR(10)   NOT NULL,
    LegacyCustomerCode  VARCHAR(10)   NULL,
    SalesChannel        VARCHAR(20)   NOT NULL,
    SegmentLabel        VARCHAR(20)   NOT NULL,
    CreditLimit         DECIMAL(10,2) NOT NULL,
    ReviewState         VARCHAR(20)   NOT NULL
);

CREATE TABLE #MergeSource
(
    SourceRowId          INT           NOT NULL PRIMARY KEY,
    CustomerCode         VARCHAR(10)   NULL,
    LegacyCustomerCode   VARCHAR(10)   NULL,
    SalesChannel         VARCHAR(20)   NOT NULL,
    ProposedSegmentLabel VARCHAR(20)   NOT NULL,
    ProposedCreditLimit  DECIMAL(10,2) NOT NULL,
    AllowFallbackUpdate  BIT           NOT NULL,
    SourceComment        VARCHAR(100)  NOT NULL
);

CREATE TABLE #MatchCandidates
(
    SourceRowId               INT         NOT NULL,
    SourceCustomerCode        VARCHAR(10) NULL,
    SourceLegacyCustomerCode  VARCHAR(10) NULL,
    SalesChannel              VARCHAR(20) NOT NULL,
    TargetAccountId           INT         NOT NULL,
    TargetCustomerCode        VARCHAR(10) NOT NULL,
    TargetLegacyCustomerCode  VARCHAR(10) NULL,
    MatchPriority             INT         NOT NULL,
    MatchReason               VARCHAR(40) NOT NULL
);

CREATE TABLE #ResolvedSource
(
    SourceRowId             INT           NOT NULL PRIMARY KEY,
    TargetAccountId         INT           NULL,
    MergeDecision           VARCHAR(20)   NOT NULL,
    MatchPriority           INT           NULL,
    MatchReason             VARCHAR(40)   NOT NULL,
    MergeCustomerCode       VARCHAR(10)   NOT NULL,
    MergeLegacyCustomerCode VARCHAR(10)   NULL,
    SalesChannel            VARCHAR(20)   NOT NULL,
    ProposedSegmentLabel    VARCHAR(20)   NOT NULL,
    ProposedCreditLimit     DECIMAL(10,2) NOT NULL,
    AllowFallbackUpdate     BIT           NOT NULL,
    SourceComment           VARCHAR(100)  NOT NULL
);

CREATE TABLE #MergeAudit
(
    AuditId         INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    MergeAction     VARCHAR(10)       NOT NULL,
    SourceRowId     INT               NOT NULL,
    MergeDecision   VARCHAR(20)       NOT NULL,
    MatchPriority   INT               NULL,
    MatchReason     VARCHAR(40)       NOT NULL,
    AccountId       INT               NULL,
    CustomerCode    VARCHAR(10)       NOT NULL,
    OldSegmentLabel VARCHAR(20)       NULL,
    NewSegmentLabel VARCHAR(20)       NULL,
    OldCreditLimit  DECIMAL(10,2)     NULL,
    NewCreditLimit  DECIMAL(10,2)     NULL,
    OldReviewState  VARCHAR(20)       NULL,
    NewReviewState  VARCHAR(20)       NULL
);

INSERT INTO #MergeTarget
(AccountId, CustomerCode, LegacyCustomerCode, SalesChannel, SegmentLabel, CreditLimit, ReviewState)
VALUES
    (1, 'C100', 'L100', 'direct',  'standard', 1200.00, 'approved'),
    (2, 'C200', 'L200', 'partner', 'standard',  900.00, 'approved'),
    (3, 'C300', 'L300', 'direct',  'priority', 2100.00, 'manual-review'),
    (4, 'C400', 'L401', 'partner', 'legacy',    650.00, 'approved'),
    (5, 'C500', 'L500', 'partner', 'standard', 1100.00, 'approved');

INSERT INTO #MergeSource
(SourceRowId, CustomerCode, LegacyCustomerCode, SalesChannel, ProposedSegmentLabel, ProposedCreditLimit, AllowFallbackUpdate, SourceComment)
VALUES
    (101, 'C100', NULL,   'direct',  'priority', 1400.00, 1, 'Exact code should update immediately.'),
    (102, NULL,   'L200', 'partner', 'priority', 1250.00, 1, 'Legacy fallback may update because review state is approved.'),
    (103, NULL,   'L300', 'direct',  'priority', 2500.00, 1, 'Fallback candidate exists but manual-review blocks the update.'),
    (104, NULL,   'L401', 'partner', 'standard',  700.00, 0, 'Fallback candidate exists but source explicitly disables fallback update.'),
    (105, 'C900', NULL,   'direct',  'new',       500.00, 1, 'No match should produce an insert candidate.'),
    (106, 'C500', 'L401', 'partner', 'priority', 1600.00, 1, 'Exact and fallback both exist; exact code should win by priority.');

INSERT INTO #MatchCandidates
(SourceRowId, SourceCustomerCode, SourceLegacyCustomerCode, SalesChannel, TargetAccountId, TargetCustomerCode, TargetLegacyCustomerCode, MatchPriority, MatchReason)
SELECT src.SourceRowId, src.CustomerCode, src.LegacyCustomerCode, src.SalesChannel, tgt.AccountId, tgt.CustomerCode, tgt.LegacyCustomerCode, 1, 'ExactCustomerCode'
FROM #MergeSource AS src
INNER JOIN #MergeTarget AS tgt
    ON tgt.CustomerCode = src.CustomerCode
UNION ALL
SELECT src.SourceRowId, src.CustomerCode, src.LegacyCustomerCode, src.SalesChannel, tgt.AccountId, tgt.CustomerCode, tgt.LegacyCustomerCode, 2, 'LegacyCodeSameChannel'
FROM #MergeSource AS src
INNER JOIN #MergeTarget AS tgt
    ON tgt.LegacyCustomerCode = src.LegacyCustomerCode
   AND tgt.SalesChannel = src.SalesChannel;

;WITH RankedCandidates AS
(
    SELECT
        mc.SourceRowId,
        mc.TargetAccountId,
        mc.MatchPriority,
        mc.MatchReason,
        COUNT(*) OVER (PARTITION BY mc.SourceRowId, mc.MatchPriority) AS PriorityCandidateCount,
        ROW_NUMBER() OVER (PARTITION BY mc.SourceRowId ORDER BY mc.MatchPriority, mc.TargetAccountId) AS MatchRank
    FROM #MatchCandidates AS mc
)
INSERT INTO #ResolvedSource
(SourceRowId, TargetAccountId, MergeDecision, MatchPriority, MatchReason, MergeCustomerCode, MergeLegacyCustomerCode, SalesChannel, ProposedSegmentLabel, ProposedCreditLimit, AllowFallbackUpdate, SourceComment)
SELECT
    src.SourceRowId,
    CASE WHEN rc.MatchRank = 1 AND rc.PriorityCandidateCount = 1 THEN rc.TargetAccountId ELSE NULL END,
    CASE
        WHEN rc.MatchRank = 1 AND rc.PriorityCandidateCount = 1 AND rc.MatchPriority = 1 THEN 'ExactMatch'
        WHEN rc.MatchRank = 1 AND rc.PriorityCandidateCount = 1 AND rc.MatchPriority = 2 THEN 'FallbackMatch'
        WHEN rc.MatchRank IS NULL THEN 'InsertCandidate'
        ELSE 'Review'
    END,
    CASE WHEN rc.MatchRank = 1 AND rc.PriorityCandidateCount = 1 THEN rc.MatchPriority ELSE NULL END,
    CASE
        WHEN rc.MatchRank = 1 AND rc.PriorityCandidateCount = 1 THEN rc.MatchReason
        WHEN rc.MatchRank IS NULL THEN 'NoMatch'
        ELSE 'AmbiguousMatch'
    END,
    COALESCE(src.CustomerCode, CONCAT('NEW-', src.LegacyCustomerCode)),
    src.LegacyCustomerCode,
    src.SalesChannel,
    src.ProposedSegmentLabel,
    src.ProposedCreditLimit,
    src.AllowFallbackUpdate,
    src.SourceComment
FROM #MergeSource AS src
LEFT JOIN RankedCandidates AS rc
    ON rc.SourceRowId = src.SourceRowId
   AND rc.MatchRank = 1;

SELECT
    mc.SourceRowId,
    mc.SourceCustomerCode,
    mc.SourceLegacyCustomerCode,
    mc.SalesChannel,
    mc.TargetAccountId,
    mc.TargetCustomerCode,
    mc.TargetLegacyCustomerCode,
    mc.MatchPriority,
    mc.MatchReason,
    COUNT(*) OVER (PARTITION BY mc.SourceRowId, mc.MatchPriority) AS PriorityCandidateCount
FROM #MatchCandidates AS mc
ORDER BY mc.SourceRowId, mc.MatchPriority, mc.TargetAccountId;

SELECT
    rs.SourceRowId,
    rs.MergeDecision,
    rs.MatchPriority,
    rs.MatchReason,
    rs.TargetAccountId,
    rs.MergeCustomerCode,
    rs.MergeLegacyCustomerCode,
    rs.SalesChannel,
    rs.ProposedSegmentLabel,
    rs.ProposedCreditLimit,
    rs.AllowFallbackUpdate,
    rs.SourceComment
FROM #ResolvedSource AS rs
ORDER BY rs.SourceRowId;

MERGE INTO #MergeTarget WITH (HOLDLOCK) AS tgt
USING #ResolvedSource AS src
    ON tgt.AccountId = src.TargetAccountId
WHEN MATCHED
 AND src.MergeDecision = 'ExactMatch'
 AND (tgt.SegmentLabel <> src.ProposedSegmentLabel OR tgt.CreditLimit <> src.ProposedCreditLimit)
    THEN UPDATE SET
        tgt.SegmentLabel = src.ProposedSegmentLabel,
        tgt.CreditLimit = src.ProposedCreditLimit,
        tgt.ReviewState = 'approved'
WHEN MATCHED
 AND src.MergeDecision = 'FallbackMatch'
 AND src.AllowFallbackUpdate = 1
 AND tgt.ReviewState <> 'manual-review'
 AND (tgt.SegmentLabel <> src.ProposedSegmentLabel OR tgt.CreditLimit <> src.ProposedCreditLimit)
    THEN UPDATE SET
        tgt.SegmentLabel = src.ProposedSegmentLabel,
        tgt.CreditLimit = src.ProposedCreditLimit,
        tgt.ReviewState = 'fallback-approved'
WHEN NOT MATCHED BY TARGET
 AND src.MergeDecision = 'InsertCandidate'
    THEN INSERT
    (
        AccountId,
        CustomerCode,
        LegacyCustomerCode,
        SalesChannel,
        SegmentLabel,
        CreditLimit,
        ReviewState
    )
    VALUES
    (
        (SELECT ISNULL(MAX(mt.AccountId), 0) + src.SourceRowId FROM #MergeTarget AS mt),
        src.MergeCustomerCode,
        src.MergeLegacyCustomerCode,
        src.SalesChannel,
        src.ProposedSegmentLabel,
        src.ProposedCreditLimit,
        'new'
    )
OUTPUT
    $action,
    src.SourceRowId,
    src.MergeDecision,
    src.MatchPriority,
    src.MatchReason,
    inserted.AccountId,
    COALESCE(inserted.CustomerCode, deleted.CustomerCode),
    deleted.SegmentLabel,
    inserted.SegmentLabel,
    deleted.CreditLimit,
    inserted.CreditLimit,
    deleted.ReviewState,
    inserted.ReviewState
INTO #MergeAudit
(MergeAction, SourceRowId, MergeDecision, MatchPriority, MatchReason, AccountId, CustomerCode, OldSegmentLabel, NewSegmentLabel, OldCreditLimit, NewCreditLimit, OldReviewState, NewReviewState);

SELECT
    ISNULL(a.MergeAction, 'NO_ACTION') AS MergeAction,
    ISNULL(CAST(a.MatchPriority AS VARCHAR(10)), '-') AS MatchPriority,
    COUNT(*) AS SourceRows
FROM #ResolvedSource AS rs
LEFT JOIN #MergeAudit AS a
    ON a.SourceRowId = rs.SourceRowId
GROUP BY ISNULL(a.MergeAction, 'NO_ACTION'), ISNULL(CAST(a.MatchPriority AS VARCHAR(10)), '-')
ORDER BY CASE ISNULL(a.MergeAction, 'NO_ACTION') WHEN 'UPDATE' THEN 1 WHEN 'INSERT' THEN 2 ELSE 3 END, ISNULL(CAST(a.MatchPriority AS VARCHAR(10)), '-');

SELECT
    rs.SourceRowId,
    rs.MergeDecision,
    rs.MatchPriority,
    rs.MatchReason,
    ISNULL(a.MergeAction, 'NO_ACTION') AS MergeAction,
    COALESCE(a.AccountId, rs.TargetAccountId) AS AccountId,
    COALESCE(a.CustomerCode, rs.MergeCustomerCode) AS CustomerCode,
    a.OldSegmentLabel,
    a.NewSegmentLabel,
    a.OldCreditLimit,
    a.NewCreditLimit,
    a.OldReviewState,
    a.NewReviewState,
    CASE
        WHEN a.MergeAction = 'UPDATE' AND rs.MergeDecision = 'ExactMatch' THEN 'Exakter Match hat den Datensatz direkt aktualisiert.'
        WHEN a.MergeAction = 'UPDATE' AND rs.MergeDecision = 'FallbackMatch' THEN 'Fallback-Match war erlaubt und hat den Datensatz angepasst.'
        WHEN a.MergeAction = 'INSERT' THEN 'Kein Match vorhanden; Quelle wurde als neue Zielzeile aufgenommen.'
        WHEN rs.MergeDecision = 'FallbackMatch' AND rs.AllowFallbackUpdate = 0 THEN 'Fallback-Kandidat blieb ohne Aktion, weil die Quelle keine Fallback-Aktualisierung erlaubt.'
        WHEN rs.MergeDecision = 'FallbackMatch' THEN 'Fallback-Kandidat blieb ohne Aktion, weil Zusatzbedingungen den Update-Pfad blockieren.'
        WHEN rs.MergeDecision = 'Review' THEN 'Mehrdeutiger Kandidat wurde nur fuer Review markiert.'
        ELSE 'Keine Aenderung erforderlich.'
    END AS DecisionExplanation
FROM #ResolvedSource AS rs
LEFT JOIN #MergeAudit AS a
    ON a.SourceRowId = rs.SourceRowId
ORDER BY rs.SourceRowId;

SELECT
    tgt.AccountId,
    tgt.CustomerCode,
    tgt.LegacyCustomerCode,
    tgt.SalesChannel,
    tgt.SegmentLabel,
    tgt.CreditLimit,
    tgt.ReviewState
FROM #MergeTarget AS tgt
ORDER BY tgt.AccountId;
