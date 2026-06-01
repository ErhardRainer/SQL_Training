/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "RollupRunningSubtotalDemo.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "18_Cube_Rollup"

purpose: >
  Demonstriert, wie ein ROLLUP-Ergebnis in eine praesentationstaugliche
  Reihenfolge gebracht und dort mit laufenden Zwischensummen je Region,
  Produktgruppe und ueber den gesamten Ausgabestrom angereichert werden kann.

parameters:
  - name: "@ShowSourceData"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = Demo-Buchungen vor der Aggregation ausgeben"
  - name: "@IncludeLeafRows"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = Leaf-Zeilen im Running-Subtotal-Resultset behalten"
  - name: "@HighlightAmountFrom"
    sql_type: "DECIMAL(18,2)"
    direction: "IN"
    required: false
    description: "Schwellwert fuer auffaellige kumulierte Zwischenstaende"

result_sets:
  - name: "SourceDataPreview"
    description: "Demo-Umsatzbuchungen vor dem ROLLUP"
  - name: "RollupBasePreview"
    description: "Unmittelbares ROLLUP-Ergebnis mit Level-Labels und Scope-Text"
  - name: "RunningSubtotalDemo"
    description: "Praesentationsreife Reihenfolge mit laufenden Zwischensummen je Ebene"
  - name: "RunningSubtotalHighlights"
    description: "Auffaellige Running-Subtotal-Staende fuer Unterricht und Review"
  - name: "ModelingHints"
    description: "Hinweise zur Interpretation der laufenden Zwischensummen"

dependencies:
  - "tempdb temporary tables"
  - "GROUP BY ROLLUP"
  - "GROUPING_ID"
  - "window functions"
  - "CASE"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/18_Cube_Rollup/SQLScripts/RollupRunningSubtotalDemo.md"
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
    description: "Erstversion fuer laufende Zwischensummen in einem didaktischen ROLLUP-Bericht"

notes:
  - "Die Demo-Daten bleiben lokal in Temp-Tabellen und modellieren Monatsbuchungen mit bewusst wiederholten Leaf-Kombinationen"
  - "Die Running-Subtotal-Felder folgen der sichtbaren Berichtssortierung und nicht einer separaten Zeitreihe"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @ShowSourceData BIT = 1;
DECLARE @IncludeLeafRows BIT = 1;
DECLARE @HighlightAmountFrom DECIMAL(18,2) = 25000.00;

IF @ShowSourceData NOT IN (0, 1)
    THROW 50070, '@ShowSourceData muss 0 oder 1 sein.', 1;

IF @IncludeLeafRows NOT IN (0, 1)
    THROW 50071, '@IncludeLeafRows muss 0 oder 1 sein.', 1;

IF @HighlightAmountFrom < 0
    THROW 50072, '@HighlightAmountFrom darf nicht negativ sein.', 1;

DROP TABLE IF EXISTS #SalesFact;
DROP TABLE IF EXISTS #RollupBase;
DROP TABLE IF EXISTS #PresentationRows;
DROP TABLE IF EXISTS #RunningSubtotalHighlights;
DROP TABLE IF EXISTS #ModelingHints;

CREATE TABLE #SalesFact
(
    SalesRegion     VARCHAR(20)   NOT NULL,
    ProductGroup    VARCHAR(30)   NOT NULL,
    SalesMonth      CHAR(7)       NOT NULL,
    BookingAmount   DECIMAL(18,2) NOT NULL
);

INSERT INTO #SalesFact
(
    SalesRegion,
    ProductGroup,
    SalesMonth,
    BookingAmount
)
VALUES
    ('North',   'Hardware', '2026-01',  8200.00),
    ('North',   'Hardware', '2026-01',  1300.00),
    ('North',   'Hardware', '2026-02',  9100.00),
    ('North',   'Services', '2026-02',  7600.00),
    ('North',   'Services', '2026-03',  5400.00),
    ('South',   'Hardware', '2026-01',  6800.00),
    ('South',   'Hardware', '2026-02',  7200.00),
    ('South',   'Services', '2026-02',  6100.00),
    ('South',   'Services', '2026-03',  6600.00),
    ('West',    'Hardware', '2026-01',  5900.00),
    ('West',    'Hardware', '2026-03',  6400.00),
    ('West',    'Services', '2026-02',  8100.00),
    ('West',    'Training', '2026-03',  4700.00),
    ('Central', 'Hardware', '2026-02',  5300.00),
    ('Central', 'Services', '2026-01',  4900.00),
    ('Central', 'Training', '2026-03',  3500.00);

IF @ShowSourceData = 1
BEGIN
    SELECT
        sf.SalesRegion,
        sf.ProductGroup,
        sf.SalesMonth,
        sf.BookingAmount
    FROM #SalesFact AS sf
    ORDER BY
        sf.SalesRegion,
        sf.ProductGroup,
        sf.SalesMonth,
        sf.BookingAmount DESC;
END;

CREATE TABLE #RollupBase
(
    SalesRegion           VARCHAR(20)   NULL,
    ProductGroup          VARCHAR(30)   NULL,
    SalesMonth            CHAR(7)       NULL,
    AggregatedAmount      DECIMAL(18,2) NOT NULL,
    GroupingId            INT           NOT NULL,
    AggregatedDimensions  TINYINT       NOT NULL,
    LevelLabel            VARCHAR(40)   NOT NULL,
    ScopeLabel            VARCHAR(160)  NOT NULL
);

INSERT INTO #RollupBase
(
    SalesRegion,
    ProductGroup,
    SalesMonth,
    AggregatedAmount,
    GroupingId,
    AggregatedDimensions,
    LevelLabel,
    ScopeLabel
)
SELECT
    sf.SalesRegion,
    sf.ProductGroup,
    sf.SalesMonth,
    SUM(sf.BookingAmount) AS AggregatedAmount,
    GROUPING_ID(sf.SalesRegion, sf.ProductGroup, sf.SalesMonth) AS GroupingId,
    GROUPING(sf.SalesRegion)
    + GROUPING(sf.ProductGroup)
    + GROUPING(sf.SalesMonth) AS AggregatedDimensions,
    CASE
        WHEN GROUPING(sf.SalesRegion)
           + GROUPING(sf.ProductGroup)
           + GROUPING(sf.SalesMonth) = 0 THEN 'leaf'
        WHEN GROUPING(sf.SalesRegion)
           + GROUPING(sf.ProductGroup)
           + GROUPING(sf.SalesMonth) = 3 THEN 'grand_total'
        ELSE 'subtotal'
    END AS LevelLabel,
    CONCAT(
        CASE WHEN GROUPING(sf.SalesRegion) = 1 THEN '(all regions)' ELSE sf.SalesRegion END,
        ' | ',
        CASE WHEN GROUPING(sf.ProductGroup) = 1 THEN '(all product groups)' ELSE sf.ProductGroup END,
        ' | ',
        CASE WHEN GROUPING(sf.SalesMonth) = 1 THEN '(all months)' ELSE sf.SalesMonth END
    ) AS ScopeLabel
FROM #SalesFact AS sf
GROUP BY ROLLUP (sf.SalesRegion, sf.ProductGroup, sf.SalesMonth);

SELECT
    rb.SalesRegion,
    rb.ProductGroup,
    rb.SalesMonth,
    rb.AggregatedAmount,
    rb.GroupingId,
    rb.AggregatedDimensions,
    rb.LevelLabel,
    rb.ScopeLabel
FROM #RollupBase AS rb
ORDER BY
    rb.AggregatedDimensions DESC,
    rb.GroupingId ASC,
    rb.SalesRegion,
    rb.ProductGroup,
    rb.SalesMonth;

CREATE TABLE #PresentationRows
(
    DisplayOrder                       INT           NOT NULL,
    SalesRegion                        VARCHAR(20)   NULL,
    ProductGroup                       VARCHAR(30)   NULL,
    SalesMonth                         CHAR(7)       NULL,
    GroupingId                         INT           NOT NULL,
    AggregatedDimensions               TINYINT       NOT NULL,
    LevelLabel                         VARCHAR(40)   NOT NULL,
    ScopeLabel                         VARCHAR(160)  NOT NULL,
    AggregatedAmount                   DECIMAL(18,2) NOT NULL,
    RunningContribution                DECIMAL(18,2) NOT NULL,
    RunningAmountWithinRegion          DECIMAL(18,2) NOT NULL,
    RunningAmountWithinProductInRegion DECIMAL(18,2) NOT NULL,
    RunningAmountAcrossReport          DECIMAL(18,2) NOT NULL,
    ResetScope                         VARCHAR(80)   NOT NULL,
    InterpretationNote                 VARCHAR(240)  NOT NULL
);

WITH OrderedRollup AS
(
    SELECT
        rb.SalesRegion,
        rb.ProductGroup,
        rb.SalesMonth,
        rb.GroupingId,
        rb.AggregatedDimensions,
        rb.LevelLabel,
        rb.ScopeLabel,
        rb.AggregatedAmount,
        CASE
            WHEN rb.SalesRegion IS NULL THEN 999
            ELSE DENSE_RANK() OVER (ORDER BY rb.SalesRegion)
        END AS RegionOrder,
        CASE
            WHEN rb.SalesRegion IS NULL OR rb.ProductGroup IS NULL THEN 999
            ELSE DENSE_RANK() OVER (PARTITION BY rb.SalesRegion ORDER BY rb.ProductGroup)
        END AS ProductOrder,
        CASE
            WHEN rb.SalesMonth IS NULL THEN 99
            ELSE DENSE_RANK() OVER (PARTITION BY rb.SalesRegion, rb.ProductGroup ORDER BY rb.SalesMonth)
        END AS MonthOrder,
        CASE
            WHEN rb.GroupingId = 0 THEN 1
            WHEN rb.GroupingId = 1 THEN 2
            WHEN rb.GroupingId = 3 THEN 3
            ELSE 4
        END AS LevelOrder
    FROM #RollupBase AS rb
)
INSERT INTO #PresentationRows
(
    DisplayOrder,
    SalesRegion,
    ProductGroup,
    SalesMonth,
    GroupingId,
    AggregatedDimensions,
    LevelLabel,
    ScopeLabel,
    AggregatedAmount,
    RunningContribution,
    RunningAmountWithinRegion,
    RunningAmountWithinProductInRegion,
    RunningAmountAcrossReport,
    ResetScope,
    InterpretationNote
)
SELECT
    ROW_NUMBER() OVER
    (
        ORDER BY
            oru.RegionOrder,
            oru.ProductOrder,
            oru.MonthOrder,
            oru.LevelOrder,
            oru.ScopeLabel
    ) AS DisplayOrder,
    oru.SalesRegion,
    oru.ProductGroup,
    oru.SalesMonth,
    oru.GroupingId,
    oru.AggregatedDimensions,
    oru.LevelLabel,
    oru.ScopeLabel,
    oru.AggregatedAmount,
    CASE
        WHEN oru.GroupingId = 0 THEN oru.AggregatedAmount
        ELSE 0.00
    END AS RunningContribution,
    SUM(CASE WHEN oru.GroupingId = 0 THEN oru.AggregatedAmount ELSE 0.00 END) OVER
    (
        PARTITION BY COALESCE(oru.SalesRegion, '(all regions)')
        ORDER BY
            oru.ProductOrder,
            oru.MonthOrder,
            oru.LevelOrder,
            oru.ScopeLabel
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS RunningAmountWithinRegion,
    SUM(CASE WHEN oru.GroupingId = 0 THEN oru.AggregatedAmount ELSE 0.00 END) OVER
    (
        PARTITION BY
            COALESCE(oru.SalesRegion, '(all regions)'),
            COALESCE(oru.ProductGroup, '(all product groups)')
        ORDER BY
            oru.MonthOrder,
            oru.LevelOrder,
            oru.ScopeLabel
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS RunningAmountWithinProductInRegion,
    SUM(CASE WHEN oru.GroupingId = 0 THEN oru.AggregatedAmount ELSE 0.00 END) OVER
    (
        ORDER BY
            oru.RegionOrder,
            oru.ProductOrder,
            oru.MonthOrder,
            oru.LevelOrder,
            oru.ScopeLabel
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS RunningAmountAcrossReport,
    CASE
        WHEN oru.GroupingId = 0 THEN 'continues month-level stream'
        WHEN oru.GroupingId = 1 THEN 'product subtotal closes one product block'
        WHEN oru.GroupingId = 3 THEN 'region subtotal closes one region block'
        ELSE 'grand total closes the entire report'
    END AS ResetScope,
    CASE
        WHEN oru.GroupingId = 0 THEN 'Leaf-Zeile: laufende Summen wachsen innerhalb derselben Region und Produktgruppe.'
        WHEN oru.GroupingId = 1 THEN 'Produkt-Subtotal: hier wird sichtbar, welcher Zwischenstand nach dem letzten Monat einer Produktgruppe erreicht ist.'
        WHEN oru.GroupingId = 3 THEN 'Regions-Subtotal: die kumulierte Regionensumme ist bis zum Ende dieses Blocks komplett.'
        ELSE 'Grand Total: letzter Stand ueber die gesamte praesentierte Reihenfolge.'
    END AS InterpretationNote
FROM OrderedRollup AS oru;

SELECT
    pr.DisplayOrder,
    pr.SalesRegion,
    pr.ProductGroup,
    pr.SalesMonth,
    pr.GroupingId,
    pr.AggregatedDimensions,
    pr.LevelLabel,
    pr.ScopeLabel,
    pr.AggregatedAmount,
    pr.RunningAmountWithinRegion,
    pr.RunningAmountWithinProductInRegion,
    pr.RunningAmountAcrossReport,
    pr.ResetScope,
    pr.InterpretationNote
FROM #PresentationRows AS pr
WHERE @IncludeLeafRows = 1
   OR pr.LevelLabel <> 'leaf'
ORDER BY
    pr.DisplayOrder;

CREATE TABLE #RunningSubtotalHighlights
(
    DisplayOrder               INT           NOT NULL,
    ScopeLabel                 VARCHAR(160)  NOT NULL,
    LevelLabel                 VARCHAR(40)   NOT NULL,
    AggregatedAmount           DECIMAL(18,2) NOT NULL,
    RunningAmountWithinRegion  DECIMAL(18,2) NOT NULL,
    RunningAmountAcrossReport  DECIMAL(18,2) NOT NULL,
    ReviewHint                 VARCHAR(220)  NOT NULL
);

INSERT INTO #RunningSubtotalHighlights
(
    DisplayOrder,
    ScopeLabel,
    LevelLabel,
    AggregatedAmount,
    RunningAmountWithinRegion,
    RunningAmountAcrossReport,
    ReviewHint
)
SELECT
    pr.DisplayOrder,
    pr.ScopeLabel,
    pr.LevelLabel,
    pr.AggregatedAmount,
    pr.RunningAmountWithinRegion,
    pr.RunningAmountAcrossReport,
    CASE
        WHEN pr.LevelLabel = 'grand_total' THEN 'Grand Total bildet den letzten kumulierten Stand des ganzen Berichts.'
        WHEN pr.LevelLabel = 'subtotal' AND pr.GroupingId = 3 THEN 'Regions-Subtotal erreicht oder ueberschreitet den Highlight-Schwellwert.'
        WHEN pr.LevelLabel = 'subtotal' THEN 'Produkt-Subtotal erreicht oder ueberschreitet den Highlight-Schwellwert.'
        ELSE 'Leaf-Zeile erreicht oder ueberschreitet den Highlight-Schwellwert im laufenden Bericht.'
    END AS ReviewHint
FROM #PresentationRows AS pr
WHERE pr.RunningAmountAcrossReport >= @HighlightAmountFrom
   OR pr.LevelLabel = 'grand_total';

SELECT
    rsh.DisplayOrder,
    rsh.ScopeLabel,
    rsh.LevelLabel,
    rsh.AggregatedAmount,
    rsh.RunningAmountWithinRegion,
    rsh.RunningAmountAcrossReport,
    rsh.ReviewHint
FROM #RunningSubtotalHighlights AS rsh
ORDER BY
    rsh.DisplayOrder;

CREATE TABLE #ModelingHints
(
    StepNumber     INT           NOT NULL,
    FocusArea      VARCHAR(80)   NOT NULL,
    GuidanceText   VARCHAR(240)  NOT NULL
);

INSERT INTO #ModelingHints
(
    StepNumber,
    FocusArea,
    GuidanceText
)
VALUES
    (1, 'Presentation order', 'Running subtotals sind nur interpretierbar, wenn die Sortierung des ROLLUP-Outputs stabil und fachlich gewollt ist.'),
    (2, 'Reset logic', 'Ein Produkt-Subtotal beendet einen Produktblock, ein Regions-Subtotal beendet den gesamten Regionsblock.'),
    (3, 'Window functions', 'SUM() OVER (...) eignet sich, um aus demselben ROLLUP-Ergebnis mehrere kumulierte Sichten parallel abzuleiten.'),
    (4, 'Reporting design', 'Wenn nur wenige Subtotal-Zeilen benoetigt werden, koennen spaeter gezielte GROUPING SETS statt vollem ROLLUP sinnvoll sein.');

SELECT
    mh.StepNumber,
    mh.FocusArea,
    mh.GuidanceText
FROM #ModelingHints AS mh
ORDER BY
    mh.StepNumber;
