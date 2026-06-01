/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "GroupingIdDecodeLab.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "18_Cube_Rollup"

purpose: >
  Zerlegt GROUPING_ID()-Werte einer CUBE-Auswertung in einzelne Bits,
  Bitgewichte und lesbare Komponenten, damit Subtotal-Ebenen ohne mentale
  Bitrechnung nachvollzogen und mit den zugrunde liegenden Dimensionen
  abgeglichen werden koennen.

parameters:
  - name: "@ShowSourcePreview"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = die Demo-Fakttabelle vor der CUBE-Auswertung anzeigen"
  - name: "@FilterGroupingId"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "-1 = alle GROUPING_ID()-Werte, sonst nur die angeforderte Bitmaske"
  - name: "@ShowOnlyAggregatedRows"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = nur Subtotal- und Grand-Total-Zeilen im Labor anzeigen"

result_sets:
  - name: "SourceFactPreview"
    description: "Optionale Vorschau auf die Demo-Fakttabelle fuer Region, Produktlinie, Segment und Quartal"
  - name: "GroupingIdDecodeLab"
    description: "CUBE-Ergebnis mit GROUPING_ID(), Einzelbits, Bitgewichten und lesbaren Level-Bausteinen"
  - name: "GroupingIdLegend"
    description: "Legende zu Bitpositionen, Gewichten und der fachlichen Lesart von 0 versus 1"

dependencies:
  - "tempdb temporary tables"
  - "GROUP BY CUBE"
  - "GROUPING"
  - "GROUPING_ID"
  - "CASE"
  - "CONCAT"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/18_Cube_Rollup/SQLScripts/GroupingIdDecodeLab.md"
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
    description: "Erstversion des Labors zur schrittweisen Dekodierung von GROUPING_ID()-Werten"

notes:
  - "Die Demo verwendet nur temporaere Objekte und bleibt rein didaktisch"
  - "Die Bitgewichte werden explizit ausgewiesen, damit die Summe zur GROUPING_ID() direkt pruefbar bleibt"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @ShowSourcePreview BIT = 1;
DECLARE @FilterGroupingId INT = -1;
DECLARE @ShowOnlyAggregatedRows BIT = 0;

IF @ShowSourcePreview NOT IN (0, 1)
BEGIN
    THROW 50070, '@ShowSourcePreview muss 0 oder 1 sein.', 1;
END;

IF @ShowOnlyAggregatedRows NOT IN (0, 1)
BEGIN
    THROW 50071, '@ShowOnlyAggregatedRows muss 0 oder 1 sein.', 1;
END;

IF @FilterGroupingId < -1 OR @FilterGroupingId > 15
BEGIN
    THROW 50072, '@FilterGroupingId muss zwischen -1 und 15 liegen.', 1;
END;

DROP TABLE IF EXISTS #SalesFact;
DROP TABLE IF EXISTS #GroupingLab;
DROP TABLE IF EXISTS #GroupingLegend;

CREATE TABLE #SalesFact
(
    RegionCode      VARCHAR(20)   NOT NULL,
    ProductLine     VARCHAR(30)   NOT NULL,
    CustomerTier    VARCHAR(20)   NOT NULL,
    FiscalQuarter   VARCHAR(10)   NOT NULL,
    RevenueAmount   DECIMAL(12,2) NOT NULL
);

INSERT INTO #SalesFact
(
    RegionCode,
    ProductLine,
    CustomerTier,
    FiscalQuarter,
    RevenueAmount
)
VALUES
    ('North',   'Hardware', 'Enterprise', '2026-Q1', 15400.00),
    ('North',   'Hardware', 'SMB',        '2026-Q2', 10250.00),
    ('North',   'Services', 'Enterprise', '2026-Q2', 11880.00),
    ('South',   'Hardware', 'Enterprise', '2026-Q1', 13340.00),
    ('South',   'Services', 'SMB',        '2026-Q2',  9240.00),
    ('South',   'Training', 'Public',     '2026-Q3',  6890.00),
    ('West',    'Hardware', 'SMB',        '2026-Q1',  9780.00),
    ('West',    'Services', 'Enterprise', '2026-Q3', 12760.00),
    ('Central', 'Hardware', 'Public',     '2026-Q2',  8450.00),
    ('Central', 'Services', 'Public',     '2026-Q3',  9030.00),
    ('Central', 'Services', 'SMB',        '2026-Q4',  9475.00),
    ('Central', 'Training', 'Enterprise', '2026-Q4',  7120.00);

IF @ShowSourcePreview = 1
BEGIN
    SELECT
        sf.RegionCode,
        sf.ProductLine,
        sf.CustomerTier,
        sf.FiscalQuarter,
        sf.RevenueAmount
    FROM #SalesFact AS sf
    ORDER BY
        sf.RegionCode,
        sf.ProductLine,
        sf.CustomerTier,
        sf.FiscalQuarter;
END;

CREATE TABLE #GroupingLab
(
    RegionCode                 VARCHAR(20)   NULL,
    ProductLine                VARCHAR(30)   NULL,
    CustomerTier               VARCHAR(20)   NULL,
    FiscalQuarter              VARCHAR(10)   NULL,
    RevenueAmount              DECIMAL(12,2) NOT NULL,
    GroupingId                 INT           NOT NULL,
    GroupingIdBinary           VARCHAR(4)    NOT NULL,
    AggregatedDimensions       TINYINT       NOT NULL,
    RegionBit                  BIT           NOT NULL,
    ProductLineBit             BIT           NOT NULL,
    CustomerTierBit            BIT           NOT NULL,
    FiscalQuarterBit           BIT           NOT NULL,
    RegionBitWeight            TINYINT       NOT NULL,
    ProductLineBitWeight       TINYINT       NOT NULL,
    CustomerTierBitWeight      TINYINT       NOT NULL,
    FiscalQuarterBitWeight     TINYINT       NOT NULL,
    CalculatedGroupingId       INT           NOT NULL,
    DecodeStatus               VARCHAR(30)   NOT NULL,
    DimensionScope             VARCHAR(160)  NOT NULL,
    AggregationLevelLabel      VARCHAR(80)   NOT NULL
);

INSERT INTO #GroupingLab
(
    RegionCode,
    ProductLine,
    CustomerTier,
    FiscalQuarter,
    RevenueAmount,
    GroupingId,
    GroupingIdBinary,
    AggregatedDimensions,
    RegionBit,
    ProductLineBit,
    CustomerTierBit,
    FiscalQuarterBit,
    RegionBitWeight,
    ProductLineBitWeight,
    CustomerTierBitWeight,
    FiscalQuarterBitWeight,
    CalculatedGroupingId,
    DecodeStatus,
    DimensionScope,
    AggregationLevelLabel
)
SELECT
    sf.RegionCode,
    sf.ProductLine,
    sf.CustomerTier,
    sf.FiscalQuarter,
    SUM(sf.RevenueAmount) AS RevenueAmount,
    GROUPING_ID
    (
        sf.RegionCode,
        sf.ProductLine,
        sf.CustomerTier,
        sf.FiscalQuarter
    ) AS GroupingId,
    CONCAT(
        GROUPING(sf.RegionCode),
        GROUPING(sf.ProductLine),
        GROUPING(sf.CustomerTier),
        GROUPING(sf.FiscalQuarter)
    ) AS GroupingIdBinary,
    GROUPING(sf.RegionCode)
    + GROUPING(sf.ProductLine)
    + GROUPING(sf.CustomerTier)
    + GROUPING(sf.FiscalQuarter) AS AggregatedDimensions,
    GROUPING(sf.RegionCode) AS RegionBit,
    GROUPING(sf.ProductLine) AS ProductLineBit,
    GROUPING(sf.CustomerTier) AS CustomerTierBit,
    GROUPING(sf.FiscalQuarter) AS FiscalQuarterBit,
    GROUPING(sf.RegionCode) * 8 AS RegionBitWeight,
    GROUPING(sf.ProductLine) * 4 AS ProductLineBitWeight,
    GROUPING(sf.CustomerTier) * 2 AS CustomerTierBitWeight,
    GROUPING(sf.FiscalQuarter) * 1 AS FiscalQuarterBitWeight,
    GROUPING(sf.RegionCode) * 8
    + GROUPING(sf.ProductLine) * 4
    + GROUPING(sf.CustomerTier) * 2
    + GROUPING(sf.FiscalQuarter) * 1 AS CalculatedGroupingId,
    CASE
        WHEN GROUPING_ID
        (
            sf.RegionCode,
            sf.ProductLine,
            sf.CustomerTier,
            sf.FiscalQuarter
        ) = GROUPING(sf.RegionCode) * 8
          + GROUPING(sf.ProductLine) * 4
          + GROUPING(sf.CustomerTier) * 2
          + GROUPING(sf.FiscalQuarter) * 1 THEN 'decode_matches_gid'
        ELSE 'check_decode_formula'
    END AS DecodeStatus,
    CONCAT(
        CASE WHEN GROUPING(sf.RegionCode) = 0 THEN CONCAT('Region ', sf.RegionCode) ELSE 'alle Regionen' END,
        ' | ',
        CASE WHEN GROUPING(sf.ProductLine) = 0 THEN CONCAT('Produktlinie ', sf.ProductLine) ELSE 'alle Produktlinien' END,
        ' | ',
        CASE WHEN GROUPING(sf.CustomerTier) = 0 THEN CONCAT('Segment ', sf.CustomerTier) ELSE 'alle Segmente' END,
        ' | ',
        CASE WHEN GROUPING(sf.FiscalQuarter) = 0 THEN CONCAT('Quartal ', sf.FiscalQuarter) ELSE 'alle Quartale' END
    ) AS DimensionScope,
    CASE
        WHEN GROUPING(sf.RegionCode)
           + GROUPING(sf.ProductLine)
           + GROUPING(sf.CustomerTier)
           + GROUPING(sf.FiscalQuarter) = 0 THEN 'detail_row'
        WHEN GROUPING(sf.RegionCode)
           + GROUPING(sf.ProductLine)
           + GROUPING(sf.CustomerTier)
           + GROUPING(sf.FiscalQuarter) = 4 THEN 'grand_total'
        ELSE CONCAT(
            'subtotal mit ',
            4 - (
                GROUPING(sf.RegionCode)
                + GROUPING(sf.ProductLine)
                + GROUPING(sf.CustomerTier)
                + GROUPING(sf.FiscalQuarter)
            ),
            ' Detaildimensionen'
        )
    END AS AggregationLevelLabel
FROM #SalesFact AS sf
GROUP BY CUBE
(
    sf.RegionCode,
    sf.ProductLine,
    sf.CustomerTier,
    sf.FiscalQuarter
);

SELECT
    gl.RegionCode,
    gl.ProductLine,
    gl.CustomerTier,
    gl.FiscalQuarter,
    gl.RevenueAmount,
    gl.GroupingId,
    gl.GroupingIdBinary,
    gl.AggregatedDimensions,
    gl.RegionBit,
    gl.ProductLineBit,
    gl.CustomerTierBit,
    gl.FiscalQuarterBit,
    gl.RegionBitWeight,
    gl.ProductLineBitWeight,
    gl.CustomerTierBitWeight,
    gl.FiscalQuarterBitWeight,
    gl.CalculatedGroupingId,
    gl.DecodeStatus,
    gl.DimensionScope,
    gl.AggregationLevelLabel
FROM #GroupingLab AS gl
WHERE (@ShowOnlyAggregatedRows = 0 OR gl.AggregatedDimensions > 0)
  AND (@FilterGroupingId = -1 OR gl.GroupingId = @FilterGroupingId)
ORDER BY
    gl.GroupingId ASC,
    gl.AggregatedDimensions DESC,
    gl.RegionCode,
    gl.ProductLine,
    gl.CustomerTier,
    gl.FiscalQuarter;

CREATE TABLE #GroupingLegend
(
    BitPosition       TINYINT       NOT NULL,
    DimensionName     VARCHAR(30)   NOT NULL,
    Weight            TINYINT       NOT NULL,
    ValueZeroMeans    VARCHAR(120)  NOT NULL,
    ValueOneMeans     VARCHAR(120)  NOT NULL
);

INSERT INTO #GroupingLegend
(
    BitPosition,
    DimensionName,
    Weight,
    ValueZeroMeans,
    ValueOneMeans
)
VALUES
    (3, 'RegionCode', 8, 'Region bleibt in der Gruppierung erhalten', 'Region wurde zur ALL-Ebene aggregiert'),
    (2, 'ProductLine', 4, 'Produktlinie bleibt in der Gruppierung erhalten', 'Produktlinie wurde zur ALL-Ebene aggregiert'),
    (1, 'CustomerTier', 2, 'Kundensegment bleibt in der Gruppierung erhalten', 'Kundensegment wurde zur ALL-Ebene aggregiert'),
    (0, 'FiscalQuarter', 1, 'Quartal bleibt in der Gruppierung erhalten', 'Quartal wurde zur ALL-Ebene aggregiert');

SELECT
    gl.BitPosition,
    gl.DimensionName,
    gl.Weight,
    gl.ValueZeroMeans,
    gl.ValueOneMeans
FROM #GroupingLegend AS gl
ORDER BY
    gl.BitPosition DESC;
