/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "GroupingIdExplainer.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "18_Cube_Rollup"

purpose: >
  Erklaert GROUPING() und GROUPING_ID() anhand kompakter CUBE- und
  ROLLUP-Beispiele, damit sichtbare NULL-Werte, aggregierte ALL-Ebenen
  und die zugehoerige Bitmaske in einem kleinen Demo-Report lesbar werden.

parameters:
  - name: "@ShowSourcePreview"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = die Demo-Fakttabelle vor der Aggregation anzeigen"
  - name: "@AggregationMode"
    sql_type: "VARCHAR(10)"
    direction: "IN"
    required: false
    description: "CUBE oder ROLLUP als Aggregationsmodus fuer das Erklaerungsbeispiel"
  - name: "@ShowOnlyAggregatedRows"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = nur Zeilen mit mindestens einer aggregierten Dimension anzeigen"
  - name: "@FilterGroupingId"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "-1 = alle Zeilen, sonst nur den gewaehlten GROUPING_ID()-Wert 0 bis 7 zeigen"

result_sets:
  - name: "SourceFactPreview"
    description: "Optionale Vorschau auf die Demo-Fakttabelle fuer Region, Produktlinie und Quartal"
  - name: "GroupingExplainer"
    description: "Aggregierte Zeilen mit GROUPING()-Flags, GROUPING_ID(), Bitmustern und Klartext-Erklaerung"
  - name: "GroupingReference"
    description: "Legende zu Bitpositionen, Gewichten und der Lesart von GROUPING versus GROUPING_ID"

dependencies:
  - "tempdb temporary tables"
  - "GROUP BY CUBE"
  - "GROUP BY ROLLUP"
  - "GROUPING"
  - "GROUPING_ID"
  - "CASE"
  - "STUFF"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/18_Cube_Rollup/SQLScripts/GroupingIdExplainer.md"
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
    description: "Erstversion der kompakten Erklaerung fuer GROUPING() und GROUPING_ID()"

notes:
  - "Die Demo verwendet nur temporaere Objekte und bleibt rein didaktisch"
  - "Die Bitgewichte fuer GROUPING_ID(RegionCode, ProductLine, FiscalQuarter) sind 4, 2 und 1"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @ShowSourcePreview BIT = 1;
DECLARE @AggregationMode VARCHAR(10) = 'CUBE';
DECLARE @ShowOnlyAggregatedRows BIT = 0;
DECLARE @FilterGroupingId INT = -1;

IF @ShowSourcePreview NOT IN (0, 1)
BEGIN
    THROW 50080, '@ShowSourcePreview muss 0 oder 1 sein.', 1;
END;

IF UPPER(@AggregationMode) NOT IN ('CUBE', 'ROLLUP')
BEGIN
    THROW 50081, '@AggregationMode muss CUBE oder ROLLUP sein.', 1;
END;

IF @ShowOnlyAggregatedRows NOT IN (0, 1)
BEGIN
    THROW 50082, '@ShowOnlyAggregatedRows muss 0 oder 1 sein.', 1;
END;

IF @FilterGroupingId < -1 OR @FilterGroupingId > 7
BEGIN
    THROW 50083, '@FilterGroupingId muss zwischen -1 und 7 liegen.', 1;
END;

DROP TABLE IF EXISTS #SalesFact;
DROP TABLE IF EXISTS #GroupingExplainer;
DROP TABLE IF EXISTS #GroupingReference;

CREATE TABLE #SalesFact
(
    RegionCode      VARCHAR(20)   NOT NULL,
    ProductLine     VARCHAR(30)   NOT NULL,
    FiscalQuarter   VARCHAR(10)   NOT NULL,
    RevenueAmount   DECIMAL(12,2) NOT NULL
);

INSERT INTO #SalesFact
(
    RegionCode,
    ProductLine,
    FiscalQuarter,
    RevenueAmount
)
VALUES
    ('North',   'Hardware', '2026-Q1', 12600.00),
    ('North',   'Services', '2026-Q2',  9850.00),
    ('South',   'Hardware', '2026-Q1', 11720.00),
    ('South',   'Services', '2026-Q2',  9340.00),
    ('West',    'Hardware', '2026-Q2', 10310.00),
    ('West',    'Services', '2026-Q3',  8825.00),
    ('Central', 'Hardware', '2026-Q3',  7910.00),
    ('Central', 'Services', '2026-Q4',  8455.00);

IF @ShowSourcePreview = 1
BEGIN
    SELECT
        sf.RegionCode,
        sf.ProductLine,
        sf.FiscalQuarter,
        sf.RevenueAmount
    FROM #SalesFact AS sf
    ORDER BY
        sf.RegionCode,
        sf.ProductLine,
        sf.FiscalQuarter;
END;

CREATE TABLE #GroupingExplainer
(
    AggregationMode         VARCHAR(10)   NOT NULL,
    RegionCode              VARCHAR(20)   NULL,
    ProductLine             VARCHAR(30)   NULL,
    FiscalQuarter           VARCHAR(10)   NULL,
    RevenueAmount           DECIMAL(12,2) NOT NULL,
    GroupingId              INT           NOT NULL,
    GroupingBits            VARCHAR(3)    NOT NULL,
    AggregatedDimensions    TINYINT       NOT NULL,
    RegionGroupingFlag      BIT           NOT NULL,
    ProductLineGroupingFlag BIT           NOT NULL,
    QuarterGroupingFlag     BIT           NOT NULL,
    RegionLabel             VARCHAR(30)   NOT NULL,
    ProductLineLabel        VARCHAR(40)   NOT NULL,
    QuarterLabel            VARCHAR(20)   NOT NULL,
    GroupingMeaning         VARCHAR(220)  NOT NULL,
    GroupingIdMeaning       VARCHAR(220)  NOT NULL,
    LevelLabel              VARCHAR(60)   NOT NULL
);

IF UPPER(@AggregationMode) = 'CUBE'
BEGIN
    INSERT INTO #GroupingExplainer
    (
        AggregationMode,
        RegionCode,
        ProductLine,
        FiscalQuarter,
        RevenueAmount,
        GroupingId,
        GroupingBits,
        AggregatedDimensions,
        RegionGroupingFlag,
        ProductLineGroupingFlag,
        QuarterGroupingFlag,
        RegionLabel,
        ProductLineLabel,
        QuarterLabel,
        GroupingMeaning,
        GroupingIdMeaning,
        LevelLabel
    )
    SELECT
        'CUBE' AS AggregationMode,
        sf.RegionCode,
        sf.ProductLine,
        sf.FiscalQuarter,
        SUM(sf.RevenueAmount) AS RevenueAmount,
        GROUPING_ID
        (
            sf.RegionCode,
            sf.ProductLine,
            sf.FiscalQuarter
        ) AS GroupingId,
        CONCAT(
            GROUPING(sf.RegionCode),
            GROUPING(sf.ProductLine),
            GROUPING(sf.FiscalQuarter)
        ) AS GroupingBits,
        GROUPING(sf.RegionCode)
        + GROUPING(sf.ProductLine)
        + GROUPING(sf.FiscalQuarter) AS AggregatedDimensions,
        GROUPING(sf.RegionCode) AS RegionGroupingFlag,
        GROUPING(sf.ProductLine) AS ProductLineGroupingFlag,
        GROUPING(sf.FiscalQuarter) AS QuarterGroupingFlag,
        CASE WHEN GROUPING(sf.RegionCode) = 1 THEN '(alle Regionen)' ELSE sf.RegionCode END AS RegionLabel,
        CASE WHEN GROUPING(sf.ProductLine) = 1 THEN '(alle Produktlinien)' ELSE sf.ProductLine END AS ProductLineLabel,
        CASE WHEN GROUPING(sf.FiscalQuarter) = 1 THEN '(alle Quartale)' ELSE sf.FiscalQuarter END AS QuarterLabel,
        CONCAT(
            'GROUPING sagt: ',
            STUFF(
                CONCAT(
                    CASE WHEN GROUPING(sf.RegionCode) = 1 THEN ', Region aggregiert' ELSE ', Region im Detail' END,
                    CASE WHEN GROUPING(sf.ProductLine) = 1 THEN ', Produktlinie aggregiert' ELSE ', Produktlinie im Detail' END,
                    CASE WHEN GROUPING(sf.FiscalQuarter) = 1 THEN ', Quartal aggregiert' ELSE ', Quartal im Detail' END
                ),
                1,
                2,
                ''
            )
        ) AS GroupingMeaning,
        CONCAT(
            'GROUPING_ID ',
            GROUPING_ID
            (
                sf.RegionCode,
                sf.ProductLine,
                sf.FiscalQuarter
            ),
            ' = ',
            GROUPING(sf.RegionCode) * 4,
            ' + ',
            GROUPING(sf.ProductLine) * 2,
            ' + ',
            GROUPING(sf.FiscalQuarter) * 1,
            ' aus Bits ',
            GROUPING(sf.RegionCode),
            GROUPING(sf.ProductLine),
            GROUPING(sf.FiscalQuarter)
        ) AS GroupingIdMeaning,
        CASE
            WHEN GROUPING(sf.RegionCode)
               + GROUPING(sf.ProductLine)
               + GROUPING(sf.FiscalQuarter) = 0 THEN 'detail_row'
            WHEN GROUPING(sf.RegionCode)
               + GROUPING(sf.ProductLine)
               + GROUPING(sf.FiscalQuarter) = 3 THEN 'grand_total'
            ELSE 'subtotal_row'
        END AS LevelLabel
    FROM #SalesFact AS sf
    GROUP BY CUBE
    (
        sf.RegionCode,
        sf.ProductLine,
        sf.FiscalQuarter
    );
END;
ELSE
BEGIN
    INSERT INTO #GroupingExplainer
    (
        AggregationMode,
        RegionCode,
        ProductLine,
        FiscalQuarter,
        RevenueAmount,
        GroupingId,
        GroupingBits,
        AggregatedDimensions,
        RegionGroupingFlag,
        ProductLineGroupingFlag,
        QuarterGroupingFlag,
        RegionLabel,
        ProductLineLabel,
        QuarterLabel,
        GroupingMeaning,
        GroupingIdMeaning,
        LevelLabel
    )
    SELECT
        'ROLLUP' AS AggregationMode,
        sf.RegionCode,
        sf.ProductLine,
        sf.FiscalQuarter,
        SUM(sf.RevenueAmount) AS RevenueAmount,
        GROUPING_ID
        (
            sf.RegionCode,
            sf.ProductLine,
            sf.FiscalQuarter
        ) AS GroupingId,
        CONCAT(
            GROUPING(sf.RegionCode),
            GROUPING(sf.ProductLine),
            GROUPING(sf.FiscalQuarter)
        ) AS GroupingBits,
        GROUPING(sf.RegionCode)
        + GROUPING(sf.ProductLine)
        + GROUPING(sf.FiscalQuarter) AS AggregatedDimensions,
        GROUPING(sf.RegionCode) AS RegionGroupingFlag,
        GROUPING(sf.ProductLine) AS ProductLineGroupingFlag,
        GROUPING(sf.FiscalQuarter) AS QuarterGroupingFlag,
        CASE WHEN GROUPING(sf.RegionCode) = 1 THEN '(alle Regionen)' ELSE sf.RegionCode END AS RegionLabel,
        CASE WHEN GROUPING(sf.ProductLine) = 1 THEN '(alle Produktlinien)' ELSE sf.ProductLine END AS ProductLineLabel,
        CASE WHEN GROUPING(sf.FiscalQuarter) = 1 THEN '(alle Quartale)' ELSE sf.FiscalQuarter END AS QuarterLabel,
        CONCAT(
            'ROLLUP erzeugt nur Prefix-Subtotals: ',
            STUFF(
                CONCAT(
                    CASE WHEN GROUPING(sf.RegionCode) = 1 THEN ', Region aggregiert' ELSE ', Region im Detail' END,
                    CASE WHEN GROUPING(sf.ProductLine) = 1 THEN ', Produktlinie aggregiert' ELSE ', Produktlinie im Detail' END,
                    CASE WHEN GROUPING(sf.FiscalQuarter) = 1 THEN ', Quartal aggregiert' ELSE ', Quartal im Detail' END
                ),
                1,
                2,
                ''
            )
        ) AS GroupingMeaning,
        CONCAT(
            'GROUPING_ID ',
            GROUPING_ID
            (
                sf.RegionCode,
                sf.ProductLine,
                sf.FiscalQuarter
            ),
            ' = ',
            GROUPING(sf.RegionCode) * 4,
            ' + ',
            GROUPING(sf.ProductLine) * 2,
            ' + ',
            GROUPING(sf.FiscalQuarter) * 1,
            ' aus Bits ',
            GROUPING(sf.RegionCode),
            GROUPING(sf.ProductLine),
            GROUPING(sf.FiscalQuarter)
        ) AS GroupingIdMeaning,
        CASE
            WHEN GROUPING(sf.RegionCode)
               + GROUPING(sf.ProductLine)
               + GROUPING(sf.FiscalQuarter) = 0 THEN 'detail_row'
            WHEN GROUPING(sf.RegionCode)
               + GROUPING(sf.ProductLine)
               + GROUPING(sf.FiscalQuarter) = 3 THEN 'grand_total'
            ELSE 'rollup_subtotal'
        END AS LevelLabel
    FROM #SalesFact AS sf
    GROUP BY ROLLUP
    (
        sf.RegionCode,
        sf.ProductLine,
        sf.FiscalQuarter
    );
END;

SELECT
    ge.AggregationMode,
    ge.RegionCode,
    ge.ProductLine,
    ge.FiscalQuarter,
    ge.RevenueAmount,
    ge.GroupingId,
    ge.GroupingBits,
    ge.AggregatedDimensions,
    ge.RegionGroupingFlag,
    ge.ProductLineGroupingFlag,
    ge.QuarterGroupingFlag,
    ge.RegionLabel,
    ge.ProductLineLabel,
    ge.QuarterLabel,
    ge.GroupingMeaning,
    ge.GroupingIdMeaning,
    ge.LevelLabel
FROM #GroupingExplainer AS ge
WHERE (@ShowOnlyAggregatedRows = 0 OR ge.AggregatedDimensions > 0)
  AND (@FilterGroupingId = -1 OR ge.GroupingId = @FilterGroupingId)
ORDER BY
    ge.GroupingId ASC,
    ge.RegionCode,
    ge.ProductLine,
    ge.FiscalQuarter;

CREATE TABLE #GroupingReference
(
    BitPosition         TINYINT       NOT NULL,
    DimensionName       VARCHAR(30)   NOT NULL,
    Weight              TINYINT       NOT NULL,
    GroupingZeroMeans   VARCHAR(120)  NOT NULL,
    GroupingOneMeans    VARCHAR(120)  NOT NULL
);

INSERT INTO #GroupingReference
(
    BitPosition,
    DimensionName,
    Weight,
    GroupingZeroMeans,
    GroupingOneMeans
)
VALUES
    (2, 'RegionCode', 4, 'Region bleibt in der Gruppierung erhalten', 'Region wurde zur ALL-Ebene aggregiert'),
    (1, 'ProductLine', 2, 'Produktlinie bleibt in der Gruppierung erhalten', 'Produktlinie wurde zur ALL-Ebene aggregiert'),
    (0, 'FiscalQuarter', 1, 'Quartal bleibt in der Gruppierung erhalten', 'Quartal wurde zur ALL-Ebene aggregiert');

SELECT
    gr.BitPosition,
    gr.DimensionName,
    gr.Weight,
    gr.GroupingZeroMeans,
    gr.GroupingOneMeans
FROM #GroupingReference AS gr
ORDER BY
    gr.BitPosition DESC;
