/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "MergeDuplicateSourceCheck.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "13_Merge"

purpose: >
  Prueft eine didaktische MERGE-Quellmenge vor dem eigentlichen MERGE auf
  doppelte Business Keys, mehrdeutige Zieltreffer und daraus abgeleitete
  Blocker oder Warnungen fuer den Preflight.

parameters: []

result_sets:
  - name: "MergePreflightSummary"
    description: "Verdichtet die Zahl erkannter Blocker, Warnungen und unauffaelliger Business Keys"
  - name: "MergeSourceDuplicates"
    description: "Zeigt doppelte Business Keys in der Quellmenge mitsamt Zeilenkontext"
  - name: "MergeMatchMultiplicity"
    description: "Bewertet pro Business Key die Zahl der Quell- und Zieltreffer vor dem MERGE"
  - name: "MergePreflightAssessment"
    description: "Leitet pro Business Key eine Preflight-Empfehlung fuer MERGE, Bereinigung oder Review ab"

dependencies:
  - "temporary tables"
  - "CTE"
  - "ROW_NUMBER"
  - "STRING_AGG"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/13_Merge/SQLScripts/MergeDuplicateSourceCheck.md"
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
    description: "Erstversion eines didaktischen Preflight-Checks fuer MERGE-Quellmengen"

notes:
  - "Die Erstversion arbeitet mit temporaeren Demo-Tabellen statt mit produktiven Staging- oder Zieltabellen."
  - "Mehrfachtreffer werden sowohl fuer doppelte Quellschluessel als auch fuer nicht eindeutige Zielschluessel bewertet."
  - "Das Skript fuehrt bewusst kein MERGE aus, sondern liefert eine diagnostische Vorpruefung."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DROP TABLE IF EXISTS #MergeTarget;
DROP TABLE IF EXISTS #MergeSource;

CREATE TABLE #MergeTarget
(
    TargetRowId     INT          NOT NULL PRIMARY KEY,
    CustomerCode    VARCHAR(10)  NOT NULL,
    CustomerName    VARCHAR(100) NOT NULL,
    SegmentLabel    VARCHAR(20)  NOT NULL,
    IsCurrentRow    BIT          NOT NULL
);

CREATE TABLE #MergeSource
(
    SourceRowId        INT          NOT NULL PRIMARY KEY,
    CustomerCode       VARCHAR(10)  NOT NULL,
    CustomerName       VARCHAR(100) NOT NULL,
    ProposedSegment    VARCHAR(20)  NOT NULL,
    SourceBatchLabel   VARCHAR(20)  NOT NULL
);

INSERT INTO #MergeTarget
(
    TargetRowId,
    CustomerCode,
    CustomerName,
    SegmentLabel,
    IsCurrentRow
)
VALUES
    (1, 'C001', 'Alpine Retail',   'standard', 1),
    (2, 'C002', 'Baltic Foods',    'standard', 1),
    (3, 'C003', 'City Logistics',  'priority', 1),
    (4, 'C004', 'Delta Services',  'legacy',   1),
    (5, 'C004', 'Delta Services',  'legacy',   0),
    (6, 'C006', 'Elm Analytics',   'new',      1);

INSERT INTO #MergeSource
(
    SourceRowId,
    CustomerCode,
    CustomerName,
    ProposedSegment,
    SourceBatchLabel
)
VALUES
    (101, 'C001', 'Alpine Retail',      'standard', 'Batch-A'),
    (102, 'C002', 'Baltic Foods GmbH',  'priority', 'Batch-A'),
    (103, 'C002', 'Baltic Foods GmbH',  'priority', 'Batch-B'),
    (104, 'C004', 'Delta Services',     'legacy',   'Batch-A'),
    (105, 'C005', 'Future Mobility',    'new',      'Batch-A'),
    (106, 'C007', 'Granite Medical',    'priority', 'Batch-C');

;WITH SourceKeyProfile AS
(
    SELECT
        s.CustomerCode,
        COUNT(*) AS SourceRowCount,
        STRING_AGG(CAST(s.SourceRowId AS VARCHAR(20)), ', ') WITHIN GROUP (ORDER BY s.SourceRowId) AS SourceRowIds,
        STRING_AGG(s.SourceBatchLabel, ', ') WITHIN GROUP (ORDER BY s.SourceRowId) AS SourceBatches
    FROM #MergeSource AS s
    GROUP BY
        s.CustomerCode
),
TargetKeyProfile AS
(
    SELECT
        t.CustomerCode,
        COUNT(*) AS TargetRowCount,
        STRING_AGG(CAST(t.TargetRowId AS VARCHAR(20)), ', ') WITHIN GROUP (ORDER BY t.TargetRowId) AS TargetRowIds
    FROM #MergeTarget AS t
    GROUP BY
        t.CustomerCode
),
MatchProfile AS
(
    SELECT
        COALESCE(src.CustomerCode, tgt.CustomerCode) AS CustomerCode,
        ISNULL(src.SourceRowCount, 0) AS SourceRowCount,
        ISNULL(src.SourceRowIds, '-') AS SourceRowIds,
        ISNULL(src.SourceBatches, '-') AS SourceBatches,
        ISNULL(tgt.TargetRowCount, 0) AS TargetRowCount,
        ISNULL(tgt.TargetRowIds, '-') AS TargetRowIds
    FROM SourceKeyProfile AS src
    FULL OUTER JOIN TargetKeyProfile AS tgt
        ON tgt.CustomerCode = src.CustomerCode
),
PreflightAssessment AS
(
    SELECT
        mp.CustomerCode,
        mp.SourceRowCount,
        mp.SourceRowIds,
        mp.SourceBatches,
        mp.TargetRowCount,
        mp.TargetRowIds,
        mp.SourceRowCount * mp.TargetRowCount AS PotentialMatchPairs,
        CASE
            WHEN mp.SourceRowCount > 1 THEN 'Block'
            WHEN mp.TargetRowCount > 1 THEN 'Block'
            WHEN mp.SourceRowCount = 0 THEN 'Info'
            WHEN mp.TargetRowCount = 0 THEN 'Warn'
            ELSE 'Proceed'
        END AS PreflightDecision,
        CASE
            WHEN mp.SourceRowCount > 1 AND mp.TargetRowCount > 1 THEN 'Mehrere Quell- und Zielzeilen teilen denselben Business Key.'
            WHEN mp.SourceRowCount > 1 THEN 'Mehrere Quellzeilen wuerden auf dieselbe Zielzeile oder denselben Business Key zeigen.'
            WHEN mp.TargetRowCount > 1 THEN 'Mehrere Zielzeilen wuerden denselben Business Key fuer ein einzelnes Source-Match anbieten.'
            WHEN mp.TargetRowCount = 0 THEN 'Kein Zieltreffer vorhanden; ein MERGE wuerde voraussichtlich INSERT ausfuehren.'
            WHEN mp.SourceRowCount = 0 THEN 'Business Key existiert nur im Zielbestand und ist fuer den aktuellen Source-Batch unauffaellig.'
            ELSE 'Genau ein Source- und ein Zieltreffer; der Business Key ist fuer ein MERGE eindeutig.'
        END AS DecisionReason
    FROM MatchProfile AS mp
)
SELECT
    pa.PreflightDecision,
    COUNT(*) AS BusinessKeyCount,
    SUM(CASE WHEN pa.SourceRowCount > 1 THEN 1 ELSE 0 END) AS KeysWithSourceDuplicates,
    SUM(CASE WHEN pa.TargetRowCount > 1 THEN 1 ELSE 0 END) AS KeysWithTargetDuplicates,
    SUM(CASE WHEN pa.TargetRowCount = 0 AND pa.SourceRowCount > 0 THEN 1 ELSE 0 END) AS KeysLikelyToInsert
FROM PreflightAssessment AS pa
GROUP BY
    pa.PreflightDecision
ORDER BY
    CASE pa.PreflightDecision
        WHEN 'Block' THEN 1
        WHEN 'Warn' THEN 2
        WHEN 'Proceed' THEN 3
        ELSE 4
    END;

;WITH DuplicateSourceKeys AS
(
    SELECT
        s.CustomerCode
    FROM #MergeSource AS s
    GROUP BY
        s.CustomerCode
    HAVING COUNT(*) > 1
),
DuplicateSourceRows AS
(
    SELECT
        s.SourceRowId,
        s.CustomerCode,
        s.CustomerName,
        s.ProposedSegment,
        s.SourceBatchLabel,
        ROW_NUMBER() OVER (PARTITION BY s.CustomerCode ORDER BY s.SourceRowId) AS DuplicateOrdinal
    FROM #MergeSource AS s
    INNER JOIN DuplicateSourceKeys AS dsk
        ON dsk.CustomerCode = s.CustomerCode
)
SELECT
    dsr.CustomerCode,
    dsr.DuplicateOrdinal,
    dsr.SourceRowId,
    dsr.CustomerName,
    dsr.ProposedSegment,
    dsr.SourceBatchLabel
FROM DuplicateSourceRows AS dsr
ORDER BY
    dsr.CustomerCode,
    dsr.DuplicateOrdinal;

SELECT
    pa.CustomerCode,
    pa.SourceRowCount,
    pa.TargetRowCount,
    pa.PotentialMatchPairs,
    pa.SourceRowIds,
    pa.TargetRowIds,
    CASE
        WHEN pa.SourceRowCount > 1 AND pa.TargetRowCount > 1 THEN 'SourceDuplicates + TargetDuplicates'
        WHEN pa.SourceRowCount > 1 THEN 'SourceDuplicates'
        WHEN pa.TargetRowCount > 1 THEN 'TargetDuplicates'
        WHEN pa.TargetRowCount = 0 AND pa.SourceRowCount > 0 THEN 'InsertOnly'
        WHEN pa.SourceRowCount = 0 THEN 'TargetOnly'
        ELSE 'SingleMatch'
    END AS MatchPattern
FROM PreflightAssessment AS pa
ORDER BY
    CASE
        WHEN pa.SourceRowCount > 1 OR pa.TargetRowCount > 1 THEN 1
        WHEN pa.TargetRowCount = 0 AND pa.SourceRowCount > 0 THEN 2
        WHEN pa.SourceRowCount = 0 THEN 4
        ELSE 3
    END,
    pa.CustomerCode;

SELECT
    pa.CustomerCode,
    pa.PreflightDecision,
    pa.DecisionReason,
    CASE
        WHEN pa.PreflightDecision = 'Block' THEN 'Source oder Target vor dem MERGE auf genau einen Business Key pro Zeile bereinigen.'
        WHEN pa.PreflightDecision = 'Warn' THEN 'INSERT-Pfad pruefen und entscheiden, ob der neue Business Key gewuenscht ist.'
        WHEN pa.PreflightDecision = 'Proceed' THEN 'MERGE kann fuer diesen Business Key mit eindeutiger Match-Beziehung vorbereitet werden.'
        ELSE 'Nur fuer Vollstaendigkeits-Review dokumentieren.'
    END AS RecommendedAction,
    pa.SourceRowIds,
    pa.SourceBatches,
    pa.TargetRowIds
FROM PreflightAssessment AS pa
ORDER BY
    CASE pa.PreflightDecision
        WHEN 'Block' THEN 1
        WHEN 'Warn' THEN 2
        WHEN 'Proceed' THEN 3
        ELSE 4
    END,
    pa.CustomerCode;
