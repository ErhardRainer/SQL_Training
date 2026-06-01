/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "SetDifferenceAudit.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "09_Set_Operations"

purpose: >
  Vergleicht zwei Snapshot-Mengen mit EXCEPT und INTERSECT, um neue,
  fehlende und unveraenderte Elemente fuer eine Delta-Analyse sichtbar zu
  machen.

parameters:
  - name: "@BaselineSnapshotLabel"
    sql_type: "NVARCHAR(30)"
    direction: "IN"
    required: false
    description: "Bezeichner der Baseline-Menge"
  - name: "@CandidateSnapshotLabel"
    sql_type: "NVARCHAR(30)"
    direction: "IN"
    required: false
    description: "Bezeichner der Vergleichsmenge"
  - name: "@IncludeIntersectionDetails"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = gibt die Schnittmenge beider Snapshots als zusaetzliches Resultset aus"

result_sets:
  - name: "AuditSummary"
    description: "Verdichtet die Mengenanzahl sowie Additions-, Wegfall- und Ueberschneidungswerte"
  - name: "OnlyInCandidate"
    description: "Elemente, die nur in der Vergleichsmenge vorhanden sind"
  - name: "OnlyInBaseline"
    description: "Elemente, die nur in der Baseline-Menge vorhanden sind"
  - name: "InBothSnapshots"
    description: "Optionale Schnittmenge beider Snapshots"

dependencies:
  - "tempdb"
  - "EXCEPT"
  - "INTERSECT"
  - "CONCAT()"
  - "COUNT(*)"
  - "DROP TABLE IF EXISTS"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/09_Set_Operations/SQLScripts/SetDifferenceAudit.md"
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
    description: "Erstversion fuer Delta-Audits mit EXCEPT und INTERSECT"

notes:
  - "Die Erstversion arbeitet mit Demo-Snapshots in einer lokalen Temp-Tabelle"
  - "Verglichen wird bewusst eine distincte Fachprojektion aus Order, Kunde, Status und Lager"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @BaselineSnapshotLabel NVARCHAR(30) = N'baseline';
DECLARE @CandidateSnapshotLabel NVARCHAR(30) = N'candidate';
DECLARE @IncludeIntersectionDetails BIT = 1;

IF NULLIF(LTRIM(RTRIM(@BaselineSnapshotLabel)), N'') IS NULL
BEGIN
    THROW 50000, '@BaselineSnapshotLabel darf nicht leer sein.', 1;
END;

IF NULLIF(LTRIM(RTRIM(@CandidateSnapshotLabel)), N'') IS NULL
BEGIN
    THROW 50001, '@CandidateSnapshotLabel darf nicht leer sein.', 1;
END;

IF @BaselineSnapshotLabel = @CandidateSnapshotLabel
BEGIN
    THROW 50002, 'Baseline- und Candidate-Label muessen unterschiedlich sein.', 1;
END;

IF @IncludeIntersectionDetails NOT IN (0, 1)
BEGIN
    THROW 50003, '@IncludeIntersectionDetails muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #OrderSnapshots;

CREATE TABLE #OrderSnapshots
(
    SnapshotLabel       NVARCHAR(30)    NOT NULL,
    OrderID             INT             NOT NULL,
    CustomerCode        INT             NOT NULL,
    FulfillmentStatus   NVARCHAR(20)    NOT NULL,
    WarehouseCode       NVARCHAR(10)    NOT NULL
);

INSERT INTO #OrderSnapshots
(
    SnapshotLabel,
    OrderID,
    CustomerCode,
    FulfillmentStatus,
    WarehouseCode
)
VALUES
    (@BaselineSnapshotLabel, 101, 1001, N'packed',     N'BER-01'),
    (@BaselineSnapshotLabel, 102, 1002, N'queued',     N'HAM-01'),
    (@BaselineSnapshotLabel, 103, 1003, N'in-transit', N'MUC-02'),
    (@BaselineSnapshotLabel, 104, 1004, N'queued',     N'BER-01'),
    (@BaselineSnapshotLabel, 105, 1005, N'packed',     N'FRA-03'),
    (@CandidateSnapshotLabel, 101, 1001, N'packed',     N'BER-01'),
    (@CandidateSnapshotLabel, 103, 1003, N'in-transit', N'MUC-02'),
    (@CandidateSnapshotLabel, 104, 1004, N'packed',     N'BER-01'),
    (@CandidateSnapshotLabel, 105, 1005, N'packed',     N'FRA-03'),
    (@CandidateSnapshotLabel, 106, 1006, N'queued',     N'LEJ-01');

;WITH BaselineSet AS
(
    SELECT DISTINCT
        snapshot.OrderID,
        snapshot.CustomerCode,
        snapshot.FulfillmentStatus,
        snapshot.WarehouseCode
    FROM #OrderSnapshots AS snapshot
    WHERE snapshot.SnapshotLabel = @BaselineSnapshotLabel
),
CandidateSet AS
(
    SELECT DISTINCT
        snapshot.OrderID,
        snapshot.CustomerCode,
        snapshot.FulfillmentStatus,
        snapshot.WarehouseCode
    FROM #OrderSnapshots AS snapshot
    WHERE snapshot.SnapshotLabel = @CandidateSnapshotLabel
),
OnlyInCandidate AS
(
    SELECT
        candidate.OrderID,
        candidate.CustomerCode,
        candidate.FulfillmentStatus,
        candidate.WarehouseCode
    FROM CandidateSet AS candidate

    EXCEPT

    SELECT
        baseline.OrderID,
        baseline.CustomerCode,
        baseline.FulfillmentStatus,
        baseline.WarehouseCode
    FROM BaselineSet AS baseline
),
OnlyInBaseline AS
(
    SELECT
        baseline.OrderID,
        baseline.CustomerCode,
        baseline.FulfillmentStatus,
        baseline.WarehouseCode
    FROM BaselineSet AS baseline

    EXCEPT

    SELECT
        candidate.OrderID,
        candidate.CustomerCode,
        candidate.FulfillmentStatus,
        candidate.WarehouseCode
    FROM CandidateSet AS candidate
),
InBothSnapshots AS
(
    SELECT
        baseline.OrderID,
        baseline.CustomerCode,
        baseline.FulfillmentStatus,
        baseline.WarehouseCode
    FROM BaselineSet AS baseline

    INTERSECT

    SELECT
        candidate.OrderID,
        candidate.CustomerCode,
        candidate.FulfillmentStatus,
        candidate.WarehouseCode
    FROM CandidateSet AS candidate
)
SELECT
    @BaselineSnapshotLabel AS baseline_snapshot,
    @CandidateSnapshotLabel AS candidate_snapshot,
    (SELECT COUNT(*) FROM BaselineSet) AS baseline_rows,
    (SELECT COUNT(*) FROM CandidateSet) AS candidate_rows,
    (SELECT COUNT(*) FROM OnlyInCandidate) AS rows_only_in_candidate,
    (SELECT COUNT(*) FROM OnlyInBaseline) AS rows_only_in_baseline,
    (SELECT COUNT(*) FROM InBothSnapshots) AS rows_in_both,
    CASE
        WHEN EXISTS (SELECT 1 FROM OnlyInCandidate) AND EXISTS (SELECT 1 FROM OnlyInBaseline)
            THEN N'bidirectional-drift'
        WHEN EXISTS (SELECT 1 FROM OnlyInCandidate)
            THEN N'candidate-additions-only'
        WHEN EXISTS (SELECT 1 FROM OnlyInBaseline)
            THEN N'candidate-missing-rows'
        ELSE N'snapshots-match'
    END AS audit_outcome,
    CASE
        WHEN EXISTS (SELECT 1 FROM OnlyInCandidate) AND EXISTS (SELECT 1 FROM OnlyInBaseline)
            THEN N'Neue und fehlende Elemente gemeinsam pruefen, bevor der Snapshot freigegeben wird.'
        WHEN EXISTS (SELECT 1 FROM OnlyInCandidate)
            THEN N'Candidate enthaelt Zusatzzeilen; pruefen, ob diese fachlich erwartet sind.'
        WHEN EXISTS (SELECT 1 FROM OnlyInBaseline)
            THEN N'Candidate verliert Baseline-Zeilen; Quelle oder Filterbedingungen pruefen.'
        ELSE N'Beide Snapshots sind fuer die gewaehlte Projektion identisch.'
    END AS recommended_next_step
;

SELECT
    candidate.OrderID,
    candidate.CustomerCode,
    candidate.FulfillmentStatus,
    candidate.WarehouseCode,
    N'only-in-candidate' AS change_type
FROM OnlyInCandidate AS candidate
ORDER BY
    candidate.OrderID,
    candidate.CustomerCode;

SELECT
    baseline.OrderID,
    baseline.CustomerCode,
    baseline.FulfillmentStatus,
    baseline.WarehouseCode,
    N'only-in-baseline' AS change_type
FROM OnlyInBaseline AS baseline
ORDER BY
    baseline.OrderID,
    baseline.CustomerCode;

IF @IncludeIntersectionDetails = 1
BEGIN
    SELECT
        shared.OrderID,
        shared.CustomerCode,
        shared.FulfillmentStatus,
        shared.WarehouseCode,
        N'in-both-snapshots' AS change_type
    FROM InBothSnapshots AS shared
    ORDER BY
        shared.OrderID,
        shared.CustomerCode;
END;
