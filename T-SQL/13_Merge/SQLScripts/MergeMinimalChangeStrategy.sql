/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "MergeMinimalChangeStrategy.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "13_Merge"

purpose: >
  Demonstriert eine MERGE-Strategie mit minimalen Aenderungen. Das Skript
  filtert unveraenderte Business Keys vor dem MERGE aus, staged nur echte
  Delta-Zeilen und aktualisiert dadurch nur die Spalten, die fuer das
  didaktische Szenario wirklich angepasst werden muessen.

parameters: []

result_sets:
  - name: "MergeMinimalChangeSummary"
    description: "Verdichtet unveraenderte, zu aktualisierende und einzufuegende Business Keys vor dem MERGE"
  - name: "MergeMinimalChangeCandidates"
    description: "Zeigt pro Business Key den Delta-Status und die betroffenen Spalten"
  - name: "MergeMinimalChangeAudit"
    description: "Protokolliert die tatsaechlich ausgefuehrten MERGE-Aktionen aus dem Delta-Stage"
  - name: "MergeMinimalChangeTargetAfter"
    description: "Zeigt den finalen Zielbestand nach dem minimalen MERGE"

dependencies:
  - "MERGE"
  - "OUTPUT $action"
  - "FULL OUTER JOIN"
  - "STRING_AGG"
  - "temporary tables"
  - "THROW"

safety:
  level: "demo-write-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/13_Merge/SQLScripts/MergeMinimalChangeStrategy.md"
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
    description: "Erstversion eines didaktischen Minimal-Change-MERGE-Musters"

notes:
  - "Die Erstversion nutzt ausschliesslich temporaere Demo-Tabellen."
  - "Nur Zeilen mit echten Aenderungen oder neue Business Keys gelangen in das MERGE-Stage."
  - "Ein DELETE-Zweig ist bewusst nicht enthalten, damit der Fokus auf minimalen INSERT- und UPDATE-Operationen liegt."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DROP TABLE IF EXISTS #MergeTarget;
DROP TABLE IF EXISTS #MergeSource;
DROP TABLE IF EXISTS #MergeDeltaStage;
DROP TABLE IF EXISTS #MergeAudit;

CREATE TABLE #MergeTarget
(
    CustomerCode      VARCHAR(10)   NOT NULL PRIMARY KEY,
    CustomerName      VARCHAR(100)  NOT NULL,
    CreditLimit       DECIMAL(10,2) NOT NULL,
    SegmentLabel      VARCHAR(20)   NOT NULL,
    BillingCycle      VARCHAR(12)   NOT NULL,
    LastReviewedDate  DATE          NOT NULL
);

CREATE TABLE #MergeSource
(
    CustomerCode      VARCHAR(10)   NOT NULL,
    CustomerName      VARCHAR(100)  NOT NULL,
    CreditLimit       DECIMAL(10,2) NOT NULL,
    SegmentLabel      VARCHAR(20)   NOT NULL,
    BillingCycle      VARCHAR(12)   NOT NULL,
    LastReviewedDate  DATE          NOT NULL
);

CREATE TABLE #MergeDeltaStage
(
    CustomerCode      VARCHAR(10)   NOT NULL PRIMARY KEY,
    DeltaAction       VARCHAR(12)   NOT NULL,
    ChangedColumns    VARCHAR(200)  NOT NULL,
    CustomerName      VARCHAR(100)  NOT NULL,
    CreditLimit       DECIMAL(10,2) NOT NULL,
    SegmentLabel      VARCHAR(20)   NOT NULL,
    BillingCycle      VARCHAR(12)   NOT NULL,
    LastReviewedDate  DATE          NOT NULL
);

CREATE TABLE #MergeAudit
(
    AuditId              INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    MergeAction          VARCHAR(10)       NOT NULL,
    DeltaAction          VARCHAR(12)       NOT NULL,
    CustomerCode         VARCHAR(10)       NOT NULL,
    ChangedColumns       VARCHAR(200)      NOT NULL,
    OldCustomerName      VARCHAR(100)      NULL,
    NewCustomerName      VARCHAR(100)      NULL,
    OldCreditLimit       DECIMAL(10,2)     NULL,
    NewCreditLimit       DECIMAL(10,2)     NULL,
    OldSegmentLabel      VARCHAR(20)       NULL,
    NewSegmentLabel      VARCHAR(20)       NULL,
    OldBillingCycle      VARCHAR(12)       NULL,
    NewBillingCycle      VARCHAR(12)       NULL,
    OldLastReviewedDate  DATE              NULL,
    NewLastReviewedDate  DATE              NULL
);

INSERT INTO #MergeTarget
(
    CustomerCode,
    CustomerName,
    CreditLimit,
    SegmentLabel,
    BillingCycle,
    LastReviewedDate
)
VALUES
    ('C001', 'Alpine Retail',     1200.00, 'standard', 'monthly',   '2026-04-01'),
    ('C002', 'Baltic Foods',       900.00, 'standard', 'monthly',   '2026-03-15'),
    ('C003', 'City Logistics',    1500.00, 'priority', 'quarterly', '2026-03-30'),
    ('C004', 'Delta Services',     650.00, 'legacy',   'monthly',   '2026-02-28');

INSERT INTO #MergeSource
(
    CustomerCode,
    CustomerName,
    CreditLimit,
    SegmentLabel,
    BillingCycle,
    LastReviewedDate
)
VALUES
    ('C001', 'Alpine Retail',      1200.00, 'standard', 'monthly',   '2026-04-01'),
    ('C002', 'Baltic Foods GmbH',  1350.00, 'priority', 'monthly',   '2026-04-18'),
    ('C003', 'City Logistics',     1500.00, 'priority', 'quarterly', '2026-03-30'),
    ('C005', 'Elm Tech',            800.00, 'new',      'monthly',   '2026-04-18');

IF EXISTS
(
    SELECT
        s.CustomerCode
    FROM #MergeSource AS s
    GROUP BY
        s.CustomerCode
    HAVING COUNT(*) > 1
)
BEGIN
    THROW 50041, 'MergeMinimalChangeStrategy detected duplicate CustomerCode values in #MergeSource.', 1;
END;

IF EXISTS
(
    SELECT
        t.CustomerCode
    FROM #MergeTarget AS t
    GROUP BY
        t.CustomerCode
    HAVING COUNT(*) > 1
)
BEGIN
    THROW 50042, 'MergeMinimalChangeStrategy detected duplicate CustomerCode values in #MergeTarget.', 1;
END;

;WITH Baseline AS
(
    SELECT
        COALESCE(src.CustomerCode, tgt.CustomerCode) AS CustomerCode,
        tgt.CustomerName AS TargetCustomerName,
        src.CustomerName AS SourceCustomerName,
        tgt.CreditLimit AS TargetCreditLimit,
        src.CreditLimit AS SourceCreditLimit,
        tgt.SegmentLabel AS TargetSegmentLabel,
        src.SegmentLabel AS SourceSegmentLabel,
        tgt.BillingCycle AS TargetBillingCycle,
        src.BillingCycle AS SourceBillingCycle,
        tgt.LastReviewedDate AS TargetLastReviewedDate,
        src.LastReviewedDate AS SourceLastReviewedDate,
        CASE
            WHEN tgt.CustomerCode IS NULL THEN 'InsertNeeded'
            WHEN src.CustomerCode IS NULL THEN 'TargetOnly'
            ELSE 'Matched'
        END AS MatchStatus
    FROM #MergeSource AS src
    FULL OUTER JOIN #MergeTarget AS tgt
        ON tgt.CustomerCode = src.CustomerCode
),
DeltaColumns AS
(
    SELECT
        b.CustomerCode,
        b.MatchStatus,
        v.ColumnName
    FROM Baseline AS b
    CROSS APPLY
    (
        VALUES
            ('CustomerName', CONVERT(VARCHAR(200), b.SourceCustomerName), CONVERT(VARCHAR(200), b.TargetCustomerName)),
            ('CreditLimit', CONVERT(VARCHAR(200), b.SourceCreditLimit), CONVERT(VARCHAR(200), b.TargetCreditLimit)),
            ('SegmentLabel', CONVERT(VARCHAR(200), b.SourceSegmentLabel), CONVERT(VARCHAR(200), b.TargetSegmentLabel)),
            ('BillingCycle', CONVERT(VARCHAR(200), b.SourceBillingCycle), CONVERT(VARCHAR(200), b.TargetBillingCycle)),
            ('LastReviewedDate', CONVERT(VARCHAR(200), b.SourceLastReviewedDate, 23), CONVERT(VARCHAR(200), b.TargetLastReviewedDate, 23))
    ) AS v(ColumnName, SourceValue, TargetValue)
    WHERE
        b.MatchStatus = 'InsertNeeded'
        OR
        (
            b.MatchStatus = 'Matched'
            AND ISNULL(v.SourceValue, '<NULL>') <> ISNULL(v.TargetValue, '<NULL>')
        )
),
CandidateStatus AS
(
    SELECT
        b.CustomerCode,
        CASE
            WHEN b.MatchStatus = 'TargetOnly' THEN 'TargetOnly'
            WHEN b.MatchStatus = 'InsertNeeded' THEN 'InsertNeeded'
            WHEN COUNT(dc.ColumnName) = 0 THEN 'NoChange'
            ELSE 'UpdateNeeded'
        END AS DeltaAction,
        COALESCE
        (
            STRING_AGG(dc.ColumnName, ', ') WITHIN GROUP (ORDER BY dc.ColumnName),
            'None'
        ) AS ChangedColumns,
        b.SourceCustomerName,
        b.SourceCreditLimit,
        b.SourceSegmentLabel,
        b.SourceBillingCycle,
        b.SourceLastReviewedDate
    FROM Baseline AS b
    LEFT JOIN DeltaColumns AS dc
        ON dc.CustomerCode = b.CustomerCode
    GROUP BY
        b.CustomerCode,
        b.MatchStatus,
        b.SourceCustomerName,
        b.SourceCreditLimit,
        b.SourceSegmentLabel,
        b.SourceBillingCycle,
        b.SourceLastReviewedDate
)
INSERT INTO #MergeDeltaStage
(
    CustomerCode,
    DeltaAction,
    ChangedColumns,
    CustomerName,
    CreditLimit,
    SegmentLabel,
    BillingCycle,
    LastReviewedDate
)
SELECT
    cs.CustomerCode,
    cs.DeltaAction,
    cs.ChangedColumns,
    cs.SourceCustomerName,
    cs.SourceCreditLimit,
    cs.SourceSegmentLabel,
    cs.SourceBillingCycle,
    cs.SourceLastReviewedDate
FROM CandidateStatus AS cs
WHERE cs.DeltaAction IN ('InsertNeeded', 'UpdateNeeded');

SELECT
    cs.DeltaAction,
    COUNT(*) AS BusinessKeyCount,
    STRING_AGG(cs.CustomerCode, ', ') WITHIN GROUP (ORDER BY cs.CustomerCode) AS CustomerCodes
FROM CandidateStatus AS cs
GROUP BY
    cs.DeltaAction
ORDER BY
    CASE cs.DeltaAction
        WHEN 'NoChange' THEN 1
        WHEN 'UpdateNeeded' THEN 2
        WHEN 'InsertNeeded' THEN 3
        WHEN 'TargetOnly' THEN 4
        ELSE 5
    END;

SELECT
    cs.CustomerCode,
    cs.DeltaAction,
    cs.ChangedColumns,
    CASE
        WHEN cs.DeltaAction = 'NoChange' THEN 'Business Key wird vor dem MERGE bewusst uebersprungen.'
        WHEN cs.DeltaAction = 'UpdateNeeded' THEN 'Nur echte Delta-Spalten gelangen in das Update-Stage.'
        WHEN cs.DeltaAction = 'InsertNeeded' THEN 'Neuer Business Key wird als INSERT in das Stage uebernommen.'
        ELSE 'Zielzeile ohne Quelltreffer bleibt ausserhalb dieses Minimal-Change-Musters.'
    END AS DeltaInterpretation
FROM CandidateStatus AS cs
ORDER BY
    CASE cs.DeltaAction
        WHEN 'NoChange' THEN 1
        WHEN 'UpdateNeeded' THEN 2
        WHEN 'InsertNeeded' THEN 3
        WHEN 'TargetOnly' THEN 4
        ELSE 5
    END,
    cs.CustomerCode;

MERGE INTO #MergeTarget WITH (HOLDLOCK) AS tgt
USING #MergeDeltaStage AS src
    ON tgt.CustomerCode = src.CustomerCode
WHEN MATCHED
 AND src.DeltaAction = 'UpdateNeeded'
    THEN
        UPDATE SET
            tgt.CustomerName = src.CustomerName,
            tgt.CreditLimit = src.CreditLimit,
            tgt.SegmentLabel = src.SegmentLabel,
            tgt.BillingCycle = src.BillingCycle,
            tgt.LastReviewedDate = src.LastReviewedDate
WHEN NOT MATCHED BY TARGET
 AND src.DeltaAction = 'InsertNeeded'
    THEN
        INSERT
        (
            CustomerCode,
            CustomerName,
            CreditLimit,
            SegmentLabel,
            BillingCycle,
            LastReviewedDate
        )
        VALUES
        (
            src.CustomerCode,
            src.CustomerName,
            src.CreditLimit,
            src.SegmentLabel,
            src.BillingCycle,
            src.LastReviewedDate
        )
OUTPUT
    $action,
    src.DeltaAction,
    COALESCE(inserted.CustomerCode, deleted.CustomerCode),
    src.ChangedColumns,
    deleted.CustomerName,
    inserted.CustomerName,
    deleted.CreditLimit,
    inserted.CreditLimit,
    deleted.SegmentLabel,
    inserted.SegmentLabel,
    deleted.BillingCycle,
    inserted.BillingCycle,
    deleted.LastReviewedDate,
    inserted.LastReviewedDate
INTO #MergeAudit
(
    MergeAction,
    DeltaAction,
    CustomerCode,
    ChangedColumns,
    OldCustomerName,
    NewCustomerName,
    OldCreditLimit,
    NewCreditLimit,
    OldSegmentLabel,
    NewSegmentLabel,
    OldBillingCycle,
    NewBillingCycle,
    OldLastReviewedDate,
    NewLastReviewedDate
);

SELECT
    a.AuditId,
    a.MergeAction,
    a.DeltaAction,
    a.CustomerCode,
    a.ChangedColumns,
    a.OldCustomerName,
    a.NewCustomerName,
    a.OldCreditLimit,
    a.NewCreditLimit,
    a.OldSegmentLabel,
    a.NewSegmentLabel,
    a.OldBillingCycle,
    a.NewBillingCycle,
    a.OldLastReviewedDate,
    a.NewLastReviewedDate,
    CASE
        WHEN a.MergeAction = 'UPDATE' THEN 'Nur echte Delta-Zeilen wurden aktualisiert.'
        WHEN a.MergeAction = 'INSERT' THEN 'Neuer Business Key wurde aus dem Delta-Stage eingefuegt.'
        ELSE 'Keine unerwartete Aktion vorgesehen.'
    END AS AuditInterpretation
FROM #MergeAudit AS a
ORDER BY
    a.AuditId;

SELECT
    tgt.CustomerCode,
    tgt.CustomerName,
    tgt.CreditLimit,
    tgt.SegmentLabel,
    tgt.BillingCycle,
    tgt.LastReviewedDate
FROM #MergeTarget AS tgt
ORDER BY
    tgt.CustomerCode;
