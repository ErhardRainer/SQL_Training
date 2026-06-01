/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "MergeConflictWindowReview.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "13_Merge"

purpose: >
  Analysiert didaktisch moegliche Konfliktfenster zwischen parallelen
  MERGE-Laeufen. Das Skript simuliert Session- und Schluesselbereiche,
  erkennt zeitliche Ueberschneidungen pro Business Key und bewertet das
  daraus entstehende Konfliktrisiko fuer Review-Gespraeche.

parameters: []

result_sets:
  - name: "MergeConflictWindowSummary"
    description: "Verdichtet pro Business Key die Zahl paralleler Konfliktfenster und das hoechste Risiko"
  - name: "MergeConflictWindowPairs"
    description: "Zeigt ueberlappende Session-Paare mit Konfliktdauer, Phase und Risikoeinstufung"
  - name: "MergeConflictWindowMitigations"
    description: "Leitet didaktische Gegenmassnahmen je Konfliktmuster ab"

dependencies:
  - "temporary tables"
  - "CTE"
  - "self join"
  - "DATEDIFF"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/13_Merge/SQLScripts/MergeConflictWindowReview.md"
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
    description: "Erstversion eines didaktischen Konfliktfenster-Reviews fuer parallele MERGE-Laeufe"

notes:
  - "Die Erstversion arbeitet mit simulierten Session-Zeitfenstern statt mit produktiven Sperrprotokollen."
  - "Das Konfliktrisiko wird pro Business Key und zeitlicher Ueberschneidung heuristisch bewertet."
  - "Die Resultsets dienen der Review-Vorbereitung fuer HOLDLOCK-, Batch- oder Schluesselsegmentierungs-Strategien."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DROP TABLE IF EXISTS #MergeSessions;
DROP TABLE IF EXISTS #MergeWindows;

CREATE TABLE #MergeSessions
(
    SessionRunId      INT          NOT NULL PRIMARY KEY,
    SessionLabel      VARCHAR(20)  NOT NULL,
    BatchLabel        VARCHAR(20)  NOT NULL,
    StartedAt         DATETIME2(0) NOT NULL,
    FinishedAt        DATETIME2(0) NOT NULL,
    IsolationPattern  VARCHAR(30)  NOT NULL,
    UsesHoldlock      BIT          NOT NULL
);

CREATE TABLE #MergeWindows
(
    SessionRunId      INT          NOT NULL,
    CustomerCode      VARCHAR(10)  NOT NULL,
    OperationPhase    VARCHAR(30)  NOT NULL,
    WindowStart       DATETIME2(0) NOT NULL,
    WindowEnd         DATETIME2(0) NOT NULL,
    IntendedAction    VARCHAR(12)  NOT NULL,
    ExpectedChange    VARCHAR(80)  NOT NULL,
    CONSTRAINT PK_MergeWindows PRIMARY KEY (SessionRunId, CustomerCode, OperationPhase)
);

INSERT INTO #MergeSessions
(
    SessionRunId,
    SessionLabel,
    BatchLabel,
    StartedAt,
    FinishedAt,
    IsolationPattern,
    UsesHoldlock
)
VALUES
    (101, 'Session-A', 'Batch-Alpha', '2026-04-18T09:00:00', '2026-04-18T09:00:14', 'Read committed', 0),
    (102, 'Session-B', 'Batch-Beta',  '2026-04-18T09:00:04', '2026-04-18T09:00:16', 'Read committed', 0),
    (103, 'Session-C', 'Batch-Gamma', '2026-04-18T09:00:20', '2026-04-18T09:00:32', 'Serializable',   1);

INSERT INTO #MergeWindows
(
    SessionRunId,
    CustomerCode,
    OperationPhase,
    WindowStart,
    WindowEnd,
    IntendedAction,
    ExpectedChange
)
VALUES
    (101, 'C002', 'MatchScan',    '2026-04-18T09:00:01', '2026-04-18T09:00:05', 'UPDATE', 'CreditLimit 900 -> 1350'),
    (101, 'C002', 'WritePhase',   '2026-04-18T09:00:05', '2026-04-18T09:00:08', 'UPDATE', 'SegmentLabel standard -> priority'),
    (101, 'C004', 'DeleteReview', '2026-04-18T09:00:08', '2026-04-18T09:00:11', 'DELETE', 'Customer missing in source batch'),
    (102, 'C002', 'MatchScan',    '2026-04-18T09:00:04', '2026-04-18T09:00:07', 'UPDATE', 'CreditLimit 900 -> 1400'),
    (102, 'C002', 'WritePhase',   '2026-04-18T09:00:07', '2026-04-18T09:00:10', 'UPDATE', 'SegmentLabel standard -> priority'),
    (102, 'C004', 'InsertReplay', '2026-04-18T09:00:09', '2026-04-18T09:00:12', 'INSERT', 'Late arriving source row recreates customer'),
    (103, 'C002', 'WritePhase',   '2026-04-18T09:00:24', '2026-04-18T09:00:27', 'UPDATE', 'Retry after serialized source snapshot'),
    (103, 'C006', 'InsertPhase',  '2026-04-18T09:00:27', '2026-04-18T09:00:30', 'INSERT', 'New customer from isolated retry batch');

IF EXISTS
(
    SELECT
        w.SessionRunId,
        w.CustomerCode,
        w.OperationPhase
    FROM #MergeWindows AS w
    GROUP BY
        w.SessionRunId,
        w.CustomerCode,
        w.OperationPhase
    HAVING COUNT(*) > 1
)
BEGIN
    THROW 50021, 'MergeConflictWindowReview detected duplicate session-key-phase windows.', 1;
END;

IF EXISTS
(
    SELECT
        w.SessionRunId,
        w.CustomerCode,
        w.OperationPhase
    FROM #MergeWindows AS w
    WHERE w.WindowEnd <= w.WindowStart
)
BEGIN
    THROW 50022, 'MergeConflictWindowReview detected an invalid window with non-positive duration.', 1;
END;

;WITH WindowPairs AS
(
    SELECT
        leftWin.CustomerCode,
        leftSession.SessionRunId AS LeftSessionRunId,
        leftSession.SessionLabel AS LeftSessionLabel,
        leftSession.BatchLabel AS LeftBatchLabel,
        leftSession.IsolationPattern AS LeftIsolationPattern,
        leftSession.UsesHoldlock AS LeftUsesHoldlock,
        leftWin.OperationPhase AS LeftPhase,
        leftWin.IntendedAction AS LeftAction,
        leftWin.ExpectedChange AS LeftExpectedChange,
        rightSession.SessionRunId AS RightSessionRunId,
        rightSession.SessionLabel AS RightSessionLabel,
        rightSession.BatchLabel AS RightBatchLabel,
        rightSession.IsolationPattern AS RightIsolationPattern,
        rightSession.UsesHoldlock AS RightUsesHoldlock,
        rightWin.OperationPhase AS RightPhase,
        rightWin.IntendedAction AS RightAction,
        rightWin.ExpectedChange AS RightExpectedChange,
        CASE
            WHEN leftWin.WindowStart > rightWin.WindowStart THEN leftWin.WindowStart
            ELSE rightWin.WindowStart
        END AS OverlapStart,
        CASE
            WHEN leftWin.WindowEnd < rightWin.WindowEnd THEN leftWin.WindowEnd
            ELSE rightWin.WindowEnd
        END AS OverlapEnd
    FROM #MergeWindows AS leftWin
    INNER JOIN #MergeWindows AS rightWin
        ON rightWin.CustomerCode = leftWin.CustomerCode
       AND rightWin.SessionRunId > leftWin.SessionRunId
       AND rightWin.WindowStart < leftWin.WindowEnd
       AND rightWin.WindowEnd > leftWin.WindowStart
    INNER JOIN #MergeSessions AS leftSession
        ON leftSession.SessionRunId = leftWin.SessionRunId
    INNER JOIN #MergeSessions AS rightSession
        ON rightSession.SessionRunId = rightWin.SessionRunId
),
ConflictPairs AS
(
    SELECT
        wp.CustomerCode,
        wp.LeftSessionRunId,
        wp.LeftSessionLabel,
        wp.LeftBatchLabel,
        wp.LeftIsolationPattern,
        wp.LeftUsesHoldlock,
        wp.LeftPhase,
        wp.LeftAction,
        wp.LeftExpectedChange,
        wp.RightSessionRunId,
        wp.RightSessionLabel,
        wp.RightBatchLabel,
        wp.RightIsolationPattern,
        wp.RightUsesHoldlock,
        wp.RightPhase,
        wp.RightAction,
        wp.RightExpectedChange,
        wp.OverlapStart,
        wp.OverlapEnd,
        DATEDIFF(SECOND, wp.OverlapStart, wp.OverlapEnd) AS OverlapSeconds,
        CASE
            WHEN wp.LeftAction <> wp.RightAction THEN 'CompetingActions'
            WHEN wp.LeftPhase = 'WritePhase' AND wp.RightPhase = 'WritePhase' THEN 'ParallelWrite'
            WHEN wp.LeftPhase = 'MatchScan' OR wp.RightPhase = 'MatchScan' THEN 'ReadWriteRace'
            ELSE 'SharedKeyOverlap'
        END AS ConflictPattern,
        CASE
            WHEN wp.LeftUsesHoldlock = 0 AND wp.RightUsesHoldlock = 0 AND wp.LeftAction <> wp.RightAction THEN 'High'
            WHEN wp.LeftUsesHoldlock = 0 AND wp.RightUsesHoldlock = 0 THEN 'Medium'
            WHEN wp.LeftPhase = 'WritePhase' AND wp.RightPhase = 'WritePhase' THEN 'Medium'
            ELSE 'Low'
        END AS RiskLevel
    FROM WindowPairs AS wp
    WHERE wp.OverlapEnd > wp.OverlapStart
),
ConflictSummary AS
(
    SELECT
        cp.CustomerCode,
        COUNT(*) AS ConflictWindowCount,
        SUM(cp.OverlapSeconds) AS TotalOverlapSeconds,
        MAX
        (
            CASE cp.RiskLevel
                WHEN 'High' THEN 3
                WHEN 'Medium' THEN 2
                ELSE 1
            END
        ) AS MaxRiskRank,
        STRING_AGG
        (
            CONCAT(cp.LeftSessionLabel, ' vs ', cp.RightSessionLabel, ' (', cp.ConflictPattern, ')'),
            '; '
        ) WITHIN GROUP (ORDER BY cp.LeftSessionRunId, cp.RightSessionRunId, cp.OverlapStart) AS ConflictWindows
    FROM ConflictPairs AS cp
    GROUP BY
        cp.CustomerCode
)
SELECT
    cs.CustomerCode,
    cs.ConflictWindowCount,
    cs.TotalOverlapSeconds,
    CASE cs.MaxRiskRank
        WHEN 3 THEN 'High'
        WHEN 2 THEN 'Medium'
        ELSE 'Low'
    END AS HighestRiskLevel,
    cs.ConflictWindows
FROM ConflictSummary AS cs
ORDER BY
    CASE cs.MaxRiskRank
        WHEN 3 THEN 1
        WHEN 2 THEN 2
        ELSE 3
    END,
    cs.CustomerCode;

SELECT
    cp.CustomerCode,
    cp.LeftSessionLabel,
    cp.LeftBatchLabel,
    cp.LeftIsolationPattern,
    cp.LeftPhase,
    cp.LeftAction,
    cp.RightSessionLabel,
    cp.RightBatchLabel,
    cp.RightIsolationPattern,
    cp.RightPhase,
    cp.RightAction,
    cp.OverlapStart,
    cp.OverlapEnd,
    cp.OverlapSeconds,
    cp.ConflictPattern,
    cp.RiskLevel,
    CASE
        WHEN cp.ConflictPattern = 'CompetingActions' THEN 'Parallel laufende MERGE-Sessions verfolgen fuer denselben Business Key unterschiedliche Zielaktionen.'
        WHEN cp.ConflictPattern = 'ParallelWrite' THEN 'Beide Sessions schreiben parallel an derselben Zielzeile.'
        WHEN cp.ConflictPattern = 'ReadWriteRace' THEN 'Eine Session liest noch, waehrend die andere bereits in die Zielzeile schreibt.'
        ELSE 'Mehrere Sessions ueberlappen auf demselben Schluessel und sollten gemeinsam reviewed werden.'
    END AS ReviewInterpretation,
    cp.LeftExpectedChange,
    cp.RightExpectedChange
FROM ConflictPairs AS cp
ORDER BY
    cp.CustomerCode,
    cp.OverlapStart,
    cp.LeftSessionRunId,
    cp.RightSessionRunId;

SELECT DISTINCT
    cp.CustomerCode,
    cp.ConflictPattern,
    cp.RiskLevel,
    CASE
        WHEN cp.RiskLevel = 'High' THEN 'HOLDLOCK oder serialisierte Batch-Segmentierung fuer diesen Business Key pruefen.'
        WHEN cp.ConflictPattern = 'ReadWriteRace' THEN 'Quellmengen vor dem MERGE materialisieren oder Snapshot/serialisierte Isolation bewerten.'
        WHEN cp.ConflictPattern = 'ParallelWrite' THEN 'Batch-Grenzen so schneiden, dass derselbe Schluessel nicht parallel verarbeitet wird.'
        ELSE 'Konfliktfenster dokumentieren und Reihenfolge der Session-Runs explizit testen.'
    END AS SuggestedMitigation
FROM ConflictPairs AS cp
ORDER BY
    CASE cp.RiskLevel
        WHEN 'High' THEN 1
        WHEN 'Medium' THEN 2
        ELSE 3
    END,
    cp.CustomerCode,
    cp.ConflictPattern;
