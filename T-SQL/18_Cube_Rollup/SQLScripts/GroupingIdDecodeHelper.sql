/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "GroupingIdDecodeHelper.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "18_Cube_Rollup"

purpose: >
  Macht GROUPING_ID()-Werte fuer Subtotal-Zeilen leichter lesbar, indem
  die Bitmaske pro Dimension aufgeschluesselt, als Binarmuster dargestellt
  und mit sprechenden Ebenenlabels fuer eine kleine Demo-Aggregation versehen wird.

parameters:
  - name: "@UseCube"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = GROUP BY CUBE, 0 = GROUP BY ROLLUP fuer die Demo-Auswertung verwenden"
  - name: "@ShowOnlyAggregatedRows"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = nur Subtotal- und Grand-Total-Zeilen im Ergebnis anzeigen"
  - name: "@ShowBinaryMask"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = die ausgeschriebene Binardarstellung der GROUPING_ID-Maske anzeigen"

result_sets:
  - name: "SourceFactPreview"
    description: "Optionale Demo-Fakttabelle fuer Region, Produktlinie und Quartal"
  - name: "GroupingIdDecodedRows"
    description: "Aggregierte Zeilen mit GROUPING_ID, Bitdekodierung und Ebenenlabel"
  - name: "GroupingIdReference"
    description: "Merkhilfe zur Zuordnung der Bits auf die vier Demo-Dimensionen"

dependencies:
  - "tempdb temporary tables"
  - "GROUP BY CUBE"
  - "GROUP BY ROLLUP"
  - "GROUPING"
  - "GROUPING_ID"
  - "CASE"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/18_Cube_Rollup/SQLScripts/GroupingIdDecodeHelper.md"
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
    description: "Erstversion des Helpers zur lesbaren Dekodierung von GROUPING_ID()-Werten"

notes:
  - "Die Demo bleibt rein didaktisch und schreibt nur in temporaere Objekte"
  - "Die Bitpositionen werden explizit ausgewiesen, damit Subtotal-Zeilen ohne mentale Bitrechnung lesbar bleiben"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @UseCube BIT = 1;
DECLARE @ShowOnlyAggregatedRows BIT = 0;
DECLARE @ShowBinaryMask BIT = 1;

IF @UseCube NOT IN (0, 1)
BEGIN
    THROW 50060, '@UseCube muss 0 oder 1 sein.', 1;
END;

IF @ShowOnlyAggregatedRows NOT IN (0, 1)
BEGIN
    THROW 50061, '@ShowOnlyAggregatedRows muss 0 oder 1 sein.', 1;
END;

IF @ShowBinaryMask NOT IN (0, 1)
BEGIN
    THROW 50062, '@ShowBinaryMask muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #SalesFact;
DROP TABLE IF EXISTS #GroupingResult;
DROP TABLE IF EXISTS #BitReference;

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
    ('North',   'Hardware', 'Enterprise', '2026-Q1', 12800.00),
    ('North',   'Hardware', 'SMB',        '2026-Q2',  9650.00),
    ('North',   'Services', 'Enterprise', '2026-Q2', 10450.00),
    ('South',   'Hardware', 'Enterprise', '2026-Q1', 11750.00),
    ('South',   'Services', 'SMB',        '2026-Q2',  8450.00),
    ('West',    'Hardware', 'SMB',        '2026-Q1',  9325.00),
    ('West',    'Services', 'Enterprise', '2026-Q3', 12100.00),
    ('Central', 'Hardware', 'Public',     '2026-Q2',  7880.00),
    ('Central', 'Services', 'Public',     '2026-Q3',  8340.00),
    ('Central', 'Services', 'SMB',        '2026-Q4',  9025.00);

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

CREATE TABLE #GroupingResult
(
    RegionCode                VARCHAR(20)   NULL,
    ProductLine               VARCHAR(30)   NULL,
    CustomerTier              VARCHAR(20)   NULL,
    FiscalQuarter             VARCHAR(10)   NULL,
    RevenueAmount             DECIMAL(12,2) NOT NULL,
    GroupingId                INT           NOT NULL,
    GroupingIdBinary          VARCHAR(4)    NOT NULL,
    AggregatedDimensions      TINYINT       NOT NULL,
    RegionBit                 BIT           NOT NULL,
    ProductLineBit            BIT           NOT NULL,
    CustomerTierBit           BIT           NOT NULL,
    FiscalQuarterBit          BIT           NOT NULL,
    RegionLabel               VARCHAR(30)   NOT NULL,
    ProductLineLabel          VARCHAR(40)   NOT NULL,
    CustomerTierLabel         VARCHAR(30)   NOT NULL,
    FiscalQuarterLabel        VARCHAR(20)   NOT NULL,
    AggregationLevelLabel     VARCHAR(80)   NOT NULL,
    DecodeCaption             VARCHAR(220)  NOT NULL
);

IF @UseCube = 1
BEGIN
    INSERT INTO #GroupingResult
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
        RegionLabel,
        ProductLineLabel,
        CustomerTierLabel,
        FiscalQuarterLabel,
        AggregationLevelLabel,
        DecodeCaption
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
        CASE WHEN GROUPING(sf.RegionCode) = 1 THEN '(alle Regionen)' ELSE sf.RegionCode END AS RegionLabel,
        CASE WHEN GROUPING(sf.ProductLine) = 1 THEN '(alle Produktlinien)' ELSE sf.ProductLine END AS ProductLineLabel,
        CASE WHEN GROUPING(sf.CustomerTier) = 1 THEN '(alle Segmente)' ELSE sf.CustomerTier END AS CustomerTierLabel,
        CASE WHEN GROUPING(sf.FiscalQuarter) = 1 THEN '(alle Quartale)' ELSE sf.FiscalQuarter END AS FiscalQuarterLabel,
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
                'subtotal fuer ',
                STUFF(
                    CONCAT(
                        CASE WHEN GROUPING(sf.RegionCode) = 0 THEN ', Region' ELSE '' END,
                        CASE WHEN GROUPING(sf.ProductLine) = 0 THEN ', Produktlinie' ELSE '' END,
                        CASE WHEN GROUPING(sf.CustomerTier) = 0 THEN ', Kundensegment' ELSE '' END,
                        CASE WHEN GROUPING(sf.FiscalQuarter) = 0 THEN ', Quartal' ELSE '' END
                    ),
                    1,
                    2,
                    ''
                )
            )
        END AS AggregationLevelLabel,
        CONCAT(
            'gid=',
            GROUPING_ID
            (
                sf.RegionCode,
                sf.ProductLine,
                sf.CustomerTier,
                sf.FiscalQuarter
            ),
            ' | bits=',
            GROUPING(sf.RegionCode),
            GROUPING(sf.ProductLine),
            GROUPING(sf.CustomerTier),
            GROUPING(sf.FiscalQuarter),
            ' | subtotal fuer ',
            CASE WHEN GROUPING(sf.RegionCode) = 0 THEN 'Region ' ELSE '' END,
            CASE WHEN GROUPING(sf.ProductLine) = 0 THEN 'Produktlinie ' ELSE '' END,
            CASE WHEN GROUPING(sf.CustomerTier) = 0 THEN 'Kundensegment ' ELSE '' END,
            CASE WHEN GROUPING(sf.FiscalQuarter) = 0 THEN 'Quartal' ELSE '' END
        ) AS DecodeCaption
    FROM #SalesFact AS sf
    GROUP BY CUBE
    (
        sf.RegionCode,
        sf.ProductLine,
        sf.CustomerTier,
        sf.FiscalQuarter
    );
END;
ELSE
BEGIN
    INSERT INTO #GroupingResult
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
        RegionLabel,
        ProductLineLabel,
        CustomerTierLabel,
        FiscalQuarterLabel,
        AggregationLevelLabel,
        DecodeCaption
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
        CASE WHEN GROUPING(sf.RegionCode) = 1 THEN '(alle Regionen)' ELSE sf.RegionCode END AS RegionLabel,
        CASE WHEN GROUPING(sf.ProductLine) = 1 THEN '(alle Produktlinien)' ELSE sf.ProductLine END AS ProductLineLabel,
        CASE WHEN GROUPING(sf.CustomerTier) = 1 THEN '(alle Segmente)' ELSE sf.CustomerTier END AS CustomerTierLabel,
        CASE WHEN GROUPING(sf.FiscalQuarter) = 1 THEN '(alle Quartale)' ELSE sf.FiscalQuarter END AS FiscalQuarterLabel,
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
                'rollup subtotal bis ',
                STUFF(
                    CONCAT(
                        CASE WHEN GROUPING(sf.RegionCode) = 0 THEN ', Region' ELSE '' END,
                        CASE WHEN GROUPING(sf.ProductLine) = 0 THEN ', Produktlinie' ELSE '' END,
                        CASE WHEN GROUPING(sf.CustomerTier) = 0 THEN ', Kundensegment' ELSE '' END,
                        CASE WHEN GROUPING(sf.FiscalQuarter) = 0 THEN ', Quartal' ELSE '' END
                    ),
                    1,
                    2,
                    ''
                )
            )
        END AS AggregationLevelLabel,
        CONCAT(
            'gid=',
            GROUPING_ID
            (
                sf.RegionCode,
                sf.ProductLine,
                sf.CustomerTier,
                sf.FiscalQuarter
            ),
            ' | bits=',
            GROUPING(sf.RegionCode),
            GROUPING(sf.ProductLine),
            GROUPING(sf.CustomerTier),
            GROUPING(sf.FiscalQuarter),
            ' | rollup helper'
        ) AS DecodeCaption
    FROM #SalesFact AS sf
    GROUP BY ROLLUP
    (
        sf.RegionCode,
        sf.ProductLine,
        sf.CustomerTier,
        sf.FiscalQuarter
    );
END;

SELECT
    gr.RegionCode,
    gr.ProductLine,
    gr.CustomerTier,
    gr.FiscalQuarter,
    gr.RevenueAmount,
    gr.GroupingId,
    CASE
        WHEN @ShowBinaryMask = 1 THEN gr.GroupingIdBinary
        ELSE NULL
    END AS GroupingIdBinary,
    gr.AggregatedDimensions,
    gr.RegionBit,
    gr.ProductLineBit,
    gr.CustomerTierBit,
    gr.FiscalQuarterBit,
    gr.RegionLabel,
    gr.ProductLineLabel,
    gr.CustomerTierLabel,
    gr.FiscalQuarterLabel,
    gr.AggregationLevelLabel,
    gr.DecodeCaption
FROM #GroupingResult AS gr
WHERE @ShowOnlyAggregatedRows = 0
   OR gr.AggregatedDimensions > 0
ORDER BY
    gr.AggregatedDimensions DESC,
    gr.GroupingId ASC,
    gr.RegionCode,
    gr.ProductLine,
    gr.CustomerTier,
    gr.FiscalQuarter;

CREATE TABLE #BitReference
(
    BitPosition       TINYINT       NOT NULL,
    DimensionName     VARCHAR(30)   NOT NULL,
    MeaningWhenOne    VARCHAR(120)  NOT NULL,
    MeaningWhenZero   VARCHAR(120)  NOT NULL
);

INSERT INTO #BitReference
(
    BitPosition,
    DimensionName,
    MeaningWhenOne,
    MeaningWhenZero
)
VALUES
    (3, 'RegionCode', 'Region wurde aggregiert', 'Region bleibt in der Gruppierung erhalten'),
    (2, 'ProductLine', 'Produktlinie wurde aggregiert', 'Produktlinie bleibt in der Gruppierung erhalten'),
    (1, 'CustomerTier', 'Kundensegment wurde aggregiert', 'Kundensegment bleibt in der Gruppierung erhalten'),
    (0, 'FiscalQuarter', 'Quartal wurde aggregiert', 'Quartal bleibt in der Gruppierung erhalten');

SELECT
    br.BitPosition,
    br.DimensionName,
    br.MeaningWhenOne,
    br.MeaningWhenZero
FROM #BitReference AS br
ORDER BY
    br.BitPosition DESC;
