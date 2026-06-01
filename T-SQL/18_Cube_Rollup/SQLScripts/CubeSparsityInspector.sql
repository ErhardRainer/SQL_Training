/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "CubeSparsityInspector.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "18_Cube_Rollup"

purpose: >
  Zeigt an einer sparsamen Demo-Fakttabelle, wie wenige belegte
  Detailkombinationen trotzdem ein deutlich groesseres CUBE-Ergebnis mit
  vielen Subtotal-Zeilen ausloesen koennen.

parameters:
  - name: "@ShowCubeSample"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = eine kleine Auswahl der erzeugten CUBE-Zeilen anzeigen"
  - name: "@MinimumExpansionFactor"
    sql_type: "DECIMAL(9,2)"
    direction: "IN"
    required: false
    description: "Mindestfaktor fuer die Alert-Ausgabe bezogen auf kumulierte CUBE-Zeilen versus Faktdatensaetze"

result_sets:
  - name: "SourceSparsityProfile"
    description: "Dimensionsprofil der Demo-Fakttabelle inklusive dichter Detailobergrenze"
  - name: "CubeExpansionByDepth"
    description: "Vergleicht reale CUBE-Zeilen, dichte Obergrenze und kumulative Expansion je Aggregationstiefe"
  - name: "ExpansionAlerts"
    description: "Markiert Aggregationstiefen, ab denen die kumulierte CUBE-Groesse den Schwellwert ueberschreitet"
  - name: "CubeSample"
    description: "Optionale Stichprobe einzelner CUBE-Zeilen mit lesbaren Ebenenlabels"

dependencies:
  - "tempdb temporary tables"
  - "GROUP BY CUBE"
  - "GROUPING"
  - "GROUPING_ID"
  - "recursive CTE"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/18_Cube_Rollup/SQLScripts/CubeSparsityInspector.md"
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
    description: "Erstversion des didaktischen Inspectors fuer CUBE-Sparsity und Expansion"

notes:
  - "Die Faktendaten sind absichtlich sparsam besetzt und repraesentieren keine produktive Vollbelegung aller Detailkombinationen"
  - "Die Auswertung fokussiert auf den Kontrast zwischen belegten Faktdatensaetzen, dichter Obergrenze und zusaetzlichen CUBE-Subtotal-Zeilen"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @ShowCubeSample BIT = 1;
DECLARE @MinimumExpansionFactor DECIMAL(9,2) = 1.50;

IF @ShowCubeSample NOT IN (0, 1)
BEGIN
    THROW 50030, '@ShowCubeSample muss 0 oder 1 sein.', 1;
END;

IF @MinimumExpansionFactor <= 0
BEGIN
    THROW 50031, '@MinimumExpansionFactor muss groesser als 0 sein.', 1;
END;

DROP TABLE IF EXISTS #SparseSalesFact;
DROP TABLE IF EXISTS #DimensionProfile;
DROP TABLE IF EXISTS #CubeResult;

CREATE TABLE #SparseSalesFact
(
    RegionCode      VARCHAR(20)   NOT NULL,
    ProductGroup    VARCHAR(30)   NOT NULL,
    SalesChannel    VARCHAR(20)   NOT NULL,
    FiscalQuarter   VARCHAR(10)   NOT NULL,
    RevenueAmount   DECIMAL(12,2) NOT NULL
);

INSERT INTO #SparseSalesFact
(
    RegionCode,
    ProductGroup,
    SalesChannel,
    FiscalQuarter,
    RevenueAmount
)
VALUES
    ('North',   'Hardware', 'Store',   '2026-Q1', 12600.00),
    ('North',   'Hardware', 'Online',  '2026-Q2',  9400.00),
    ('North',   'Services', 'Partner', '2026-Q3', 11800.00),
    ('South',   'Hardware', 'Store',   '2026-Q1', 13750.00),
    ('South',   'Training', 'Partner', '2026-Q4',  7350.00),
    ('West',    'Services', 'Online',  '2026-Q2', 10100.00),
    ('West',    'Services', 'Store',   '2026-Q3',  9800.00),
    ('West',    'Training', 'Partner', '2026-Q4',  6900.00),
    ('Central', 'Hardware', 'Partner', '2026-Q4',  8700.00),
    ('Central', 'Services', 'Store',   '2026-Q2', 11250.00),
    ('Central', 'Training', 'Online',  '2026-Q4',  6400.00),
    ('South',   'Services', 'Online',  '2026-Q2', 12100.00);

CREATE TABLE #DimensionProfile
(
    DimensionOrder   INT          NOT NULL,
    DimensionName    VARCHAR(40)  NOT NULL,
    DistinctMembers  INT          NOT NULL
);

INSERT INTO #DimensionProfile
(
    DimensionOrder,
    DimensionName,
    DistinctMembers
)
SELECT 1, 'RegionCode', COUNT(DISTINCT RegionCode) FROM #SparseSalesFact
UNION ALL
SELECT 2, 'ProductGroup', COUNT(DISTINCT ProductGroup) FROM #SparseSalesFact
UNION ALL
SELECT 3, 'SalesChannel', COUNT(DISTINCT SalesChannel) FROM #SparseSalesFact
UNION ALL
SELECT 4, 'FiscalQuarter', COUNT(DISTINCT FiscalQuarter) FROM #SparseSalesFact;

;WITH DenseSummary AS
(
    SELECT
        CAST(EXP(SUM(LOG(CONVERT(FLOAT, dp.DistinctMembers)))) AS BIGINT) AS DenseDetailUpperBound
    FROM #DimensionProfile AS dp
)
SELECT
    dp.DimensionOrder,
    dp.DimensionName,
    dp.DistinctMembers,
    (SELECT COUNT(*) FROM #SparseSalesFact) AS FactRows,
    ds.DenseDetailUpperBound,
    CAST(
        (SELECT COUNT(*) FROM #SparseSalesFact) * 1.0
        / NULLIF(ds.DenseDetailUpperBound, 0) AS DECIMAL(9,4)
    ) AS OccupancyRatio
FROM #DimensionProfile AS dp
CROSS JOIN DenseSummary AS ds
ORDER BY
    dp.DimensionOrder;

CREATE TABLE #CubeResult
(
    RegionCode            VARCHAR(20)   NULL,
    ProductGroup          VARCHAR(30)   NULL,
    SalesChannel          VARCHAR(20)   NULL,
    FiscalQuarter         VARCHAR(10)   NULL,
    RevenueAmount         DECIMAL(12,2) NOT NULL,
    GroupingId            INT           NOT NULL,
    AggregatedDimensions  TINYINT       NOT NULL
);

INSERT INTO #CubeResult
(
    RegionCode,
    ProductGroup,
    SalesChannel,
    FiscalQuarter,
    RevenueAmount,
    GroupingId,
    AggregatedDimensions
)
SELECT
    sf.RegionCode,
    sf.ProductGroup,
    sf.SalesChannel,
    sf.FiscalQuarter,
    SUM(sf.RevenueAmount) AS RevenueAmount,
    GROUPING_ID
    (
        sf.RegionCode,
        sf.ProductGroup,
        sf.SalesChannel,
        sf.FiscalQuarter
    ) AS GroupingId,
    GROUPING(sf.RegionCode)
    + GROUPING(sf.ProductGroup)
    + GROUPING(sf.SalesChannel)
    + GROUPING(sf.FiscalQuarter) AS AggregatedDimensions
FROM #SparseSalesFact AS sf
GROUP BY CUBE
(
    sf.RegionCode,
    sf.ProductGroup,
    sf.SalesChannel,
    sf.FiscalQuarter
);

;WITH DimensionBits AS
(
    SELECT 1 AS DimensionOrder, 'RegionCode' AS DimensionName, CAST(8 AS INT) AS GroupingBit
    UNION ALL
    SELECT 2, 'ProductGroup', 4
    UNION ALL
    SELECT 3, 'SalesChannel', 2
    UNION ALL
    SELECT 4, 'FiscalQuarter', 1
),
GroupingLevels AS
(
    SELECT 0 AS GroupingId
    UNION ALL
    SELECT gl.GroupingId + 1
    FROM GroupingLevels AS gl
    WHERE gl.GroupingId < 15
),
TheoreticalLevels AS
(
    SELECT
        gl.GroupingId,
        SUM(CASE WHEN (gl.GroupingId & db.GroupingBit) = db.GroupingBit THEN 1 ELSE 0 END) AS AggregatedDimensions,
        4 - SUM(CASE WHEN (gl.GroupingId & db.GroupingBit) = db.GroupingBit THEN 1 ELSE 0 END) AS DetailDimensions,
        CAST(
            EXP(
                SUM(
                    CASE
                        WHEN (gl.GroupingId & db.GroupingBit) = db.GroupingBit THEN 0.0
                        ELSE LOG(CONVERT(FLOAT, dp.DistinctMembers))
                    END
                )
            ) AS BIGINT
        ) AS TheoreticalDenseRows
    FROM GroupingLevels AS gl
    INNER JOIN DimensionBits AS db
        ON 1 = 1
    INNER JOIN #DimensionProfile AS dp
        ON dp.DimensionOrder = db.DimensionOrder
    GROUP BY
        gl.GroupingId
),
ActualLevels AS
(
    SELECT
        cr.GroupingId,
        cr.AggregatedDimensions,
        COUNT(*) AS ActualCubeRows
    FROM #CubeResult AS cr
    GROUP BY
        cr.GroupingId,
        cr.AggregatedDimensions
),
DepthSummary AS
(
    SELECT
        tl.AggregatedDimensions,
        tl.DetailDimensions,
        COUNT(*) AS GroupingLevelsAtDepth,
        SUM(tl.TheoreticalDenseRows) AS DenseRowsAtDepth,
        SUM(ISNULL(al.ActualCubeRows, 0)) AS ActualCubeRowsAtDepth
    FROM TheoreticalLevels AS tl
    LEFT JOIN ActualLevels AS al
        ON al.GroupingId = tl.GroupingId
    GROUP BY
        tl.AggregatedDimensions,
        tl.DetailDimensions
)
SELECT
    ds.AggregatedDimensions,
    ds.DetailDimensions,
    ds.GroupingLevelsAtDepth,
    ds.DenseRowsAtDepth,
    ds.ActualCubeRowsAtDepth,
    CAST(ds.ActualCubeRowsAtDepth * 1.0 / NULLIF(ds.DenseRowsAtDepth, 0) AS DECIMAL(9,4)) AS DensityRatioAtDepth,
    SUM(ds.ActualCubeRowsAtDepth) OVER
    (
        ORDER BY ds.AggregatedDimensions
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS CumulativeCubeRows,
    CAST(
        SUM(ds.ActualCubeRowsAtDepth) OVER
        (
            ORDER BY ds.AggregatedDimensions
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) * 1.0
        / NULLIF((SELECT COUNT(*) FROM #SparseSalesFact), 0) AS DECIMAL(9,4)
    ) AS CumulativeExpansionVsFactRows,
    CASE
        WHEN ds.AggregatedDimensions = 0 THEN 'detail_rows'
        WHEN ds.AggregatedDimensions = 4 THEN 'grand_total_layer'
        ELSE 'subtotal_layer'
    END AS LevelRole,
    CASE
        WHEN ds.AggregatedDimensions = 0 THEN 'Nur die belegten Detailkombinationen aus den Faktdaten.'
        WHEN ds.AggregatedDimensions = 1 THEN 'Erste Subtotal-Schicht; wenige Faktzeilen erzeugen bereits viele zusaetzliche Gruppen.'
        WHEN ds.AggregatedDimensions IN (2, 3) THEN 'Weitere Verdichtung; Sparsity bleibt sichtbar, aber die CUBE-Gesamtmenge waechst weiter.'
        ELSE 'Grand Total schliesst den CUBE mit einer weiteren Zeile ab.'
    END AS Interpretation
FROM DepthSummary AS ds
ORDER BY
    ds.AggregatedDimensions;

;WITH DimensionBits AS
(
    SELECT 1 AS DimensionOrder, CAST(8 AS INT) AS GroupingBit
    UNION ALL
    SELECT 2, 4
    UNION ALL
    SELECT 3, 2
    UNION ALL
    SELECT 4, 1
),
GroupingLevels AS
(
    SELECT 0 AS GroupingId
    UNION ALL
    SELECT gl.GroupingId + 1
    FROM GroupingLevels AS gl
    WHERE gl.GroupingId < 15
),
TheoreticalLevels AS
(
    SELECT
        gl.GroupingId,
        SUM(CASE WHEN (gl.GroupingId & db.GroupingBit) = db.GroupingBit THEN 1 ELSE 0 END) AS AggregatedDimensions,
        CAST(
            EXP(
                SUM(
                    CASE
                        WHEN (gl.GroupingId & db.GroupingBit) = db.GroupingBit THEN 0.0
                        ELSE LOG(CONVERT(FLOAT, dp.DistinctMembers))
                    END
                )
            ) AS BIGINT
        ) AS TheoreticalDenseRows
    FROM GroupingLevels AS gl
    INNER JOIN DimensionBits AS db
        ON 1 = 1
    INNER JOIN #DimensionProfile AS dp
        ON dp.DimensionOrder = db.DimensionOrder
    GROUP BY
        gl.GroupingId
),
ActualLevels AS
(
    SELECT
        cr.GroupingId,
        cr.AggregatedDimensions,
        COUNT(*) AS ActualCubeRows
    FROM #CubeResult AS cr
    GROUP BY
        cr.GroupingId,
        cr.AggregatedDimensions
),
DepthSummary AS
(
    SELECT
        tl.AggregatedDimensions,
        SUM(tl.TheoreticalDenseRows) AS DenseRowsAtDepth,
        SUM(ISNULL(al.ActualCubeRows, 0)) AS ActualCubeRowsAtDepth
    FROM TheoreticalLevels AS tl
    LEFT JOIN ActualLevels AS al
        ON al.GroupingId = tl.GroupingId
    GROUP BY
        tl.AggregatedDimensions
),
ExpansionProgress AS
(
    SELECT
        ds.AggregatedDimensions,
        ds.DenseRowsAtDepth,
        ds.ActualCubeRowsAtDepth,
        SUM(ds.ActualCubeRowsAtDepth) OVER
        (
            ORDER BY ds.AggregatedDimensions
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS CumulativeCubeRows
    FROM DepthSummary AS ds
)
SELECT
    ep.AggregatedDimensions,
    ep.ActualCubeRowsAtDepth,
    ep.DenseRowsAtDepth,
    ep.CumulativeCubeRows,
    (SELECT COUNT(*) FROM #SparseSalesFact) AS FactRows,
    CAST(ep.CumulativeCubeRows * 1.0 / NULLIF((SELECT COUNT(*) FROM #SparseSalesFact), 0) AS DECIMAL(9,4)) AS CumulativeExpansionVsFactRows,
    CAST((SELECT COUNT(*) FROM #CubeResult) * 1.0 / NULLIF((SELECT COUNT(*) FROM #SparseSalesFact), 0) AS DECIMAL(9,4)) AS FinalCubeExpansionFactor,
    CASE
        WHEN ep.AggregatedDimensions = 0 THEN 'Detailzeilen allein'
        WHEN ep.AggregatedDimensions = 1 THEN 'Nach der ersten Subtotal-Schicht'
        WHEN ep.AggregatedDimensions IN (2, 3) THEN 'Mit weiteren Subtotals'
        ELSE 'Mit Grand Total'
    END AS AlertStage
FROM ExpansionProgress AS ep
WHERE CAST(ep.CumulativeCubeRows * 1.0 / NULLIF((SELECT COUNT(*) FROM #SparseSalesFact), 0) AS DECIMAL(9,4)) >= @MinimumExpansionFactor
ORDER BY
    ep.AggregatedDimensions;

IF @ShowCubeSample = 1
BEGIN
    SELECT TOP (24)
        CASE WHEN cr.RegionCode IS NULL THEN '(all regions)' ELSE cr.RegionCode END AS RegionCode,
        CASE WHEN cr.ProductGroup IS NULL THEN '(all product groups)' ELSE cr.ProductGroup END AS ProductGroup,
        CASE WHEN cr.SalesChannel IS NULL THEN '(all channels)' ELSE cr.SalesChannel END AS SalesChannel,
        CASE WHEN cr.FiscalQuarter IS NULL THEN '(all quarters)' ELSE cr.FiscalQuarter END AS FiscalQuarter,
        cr.RevenueAmount,
        cr.GroupingId,
        cr.AggregatedDimensions,
        CASE
            WHEN cr.AggregatedDimensions = 0 THEN 'detail'
            WHEN cr.AggregatedDimensions = 4 THEN 'grand_total'
            ELSE 'subtotal'
        END AS LevelRole
    FROM #CubeResult AS cr
    ORDER BY
        cr.AggregatedDimensions DESC,
        cr.GroupingId ASC,
        cr.RevenueAmount DESC;
END;
