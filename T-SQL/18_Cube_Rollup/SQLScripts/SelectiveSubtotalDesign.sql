/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "SelectiveSubtotalDesign.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "18_Cube_Rollup"

purpose: >
  Hilft bei der gezielten Auswahl fachlich noetiger Subtotal-Ebenen, indem
  eine kleine Demo-Fakttabelle den Unterschied zwischen einer vollstaendigen
  CUBE-Expansion und einer bewusst kuratierten Menge an GROUPING SETS zeigt.

parameters:
  - name: "@ShowFullCubeReference"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = Referenz ueber alle CUBE-Ebenen ausgeben"
  - name: "@IncludeProductQuarter"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zusaetzliche Subtotals je Produktgruppe und Quartal in das Design aufnehmen"
  - name: "@IncludeGrandTotal"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = Grand Total als eigene Zeile in das selektive Design aufnehmen"

result_sets:
  - name: "SourceDataPreview"
    description: "Demo-Umsatzdaten fuer Region, Produktgruppe, Kanal und Quartal"
  - name: "FullCubeLevelReference"
    description: "Referenz auf alle durch CUBE erreichbaren Gruppierungsebenen mit realer Zeilenzahl"
  - name: "SelectiveDesignCoverage"
    description: "Vergleicht die ausgewaehlten Subtotal-Ebenen mit dem vollen CUBE-Raum"
  - name: "SelectiveSubtotalResult"
    description: "Die kuratierten Subtotals fuer die ausgewaehlten fachlichen Fragen"
  - name: "DesignGuidance"
    description: "Knappe Hinweise fuer die Auswahl produktiver GROUPING SETS"

dependencies:
  - "tempdb temporary tables"
  - "GROUP BY CUBE"
  - "GROUPING_ID"
  - "GROUPING SETS design pattern via explicit subtotal queries"
  - "UNION ALL style selective subtotal assembly"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/18_Cube_Rollup/SQLScripts/SelectiveSubtotalDesign.md"
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
    description: "Erstversion fuer die didaktische Auswahl gezielter Subtotal-Ebenen"

notes:
  - "Das Skript vergleicht ein kuratiertes GROUPING-SET-Design mit dem vollen CUBE derselben vier Dimensionen"
  - "Die Auswahllogik bleibt didaktisch und schreibt nicht in persistente Objekte"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @ShowFullCubeReference BIT = 1;
DECLARE @IncludeProductQuarter BIT = 1;
DECLARE @IncludeGrandTotal BIT = 1;

IF @ShowFullCubeReference NOT IN (0, 1)
BEGIN
    THROW 50030, '@ShowFullCubeReference muss 0 oder 1 sein.', 1;
END;

IF @IncludeProductQuarter NOT IN (0, 1)
BEGIN
    THROW 50031, '@IncludeProductQuarter muss 0 oder 1 sein.', 1;
END;

IF @IncludeGrandTotal NOT IN (0, 1)
BEGIN
    THROW 50032, '@IncludeGrandTotal muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #SalesFact;
DROP TABLE IF EXISTS #FullCubeReference;
DROP TABLE IF EXISTS #SelectiveDesign;
DROP TABLE IF EXISTS #SelectiveSubtotalResult;
DROP TABLE IF EXISTS #DesignGuidance;

CREATE TABLE #SalesFact
(
    RegionCode      VARCHAR(20)   NOT NULL,
    ProductGroup    VARCHAR(30)   NOT NULL,
    SalesChannel    VARCHAR(20)   NOT NULL,
    FiscalQuarter   VARCHAR(10)   NOT NULL,
    RevenueAmount   DECIMAL(12,2) NOT NULL
);

INSERT INTO #SalesFact
(
    RegionCode,
    ProductGroup,
    SalesChannel,
    FiscalQuarter,
    RevenueAmount
)
VALUES
    ('North',   'Hardware', 'Store',   '2026-Q1', 12800.00),
    ('North',   'Hardware', 'Online',  '2026-Q2',  9400.00),
    ('North',   'Services', 'Online',  '2026-Q2', 11600.00),
    ('North',   'Training', 'Partner', '2026-Q3',  7200.00),
    ('South',   'Hardware', 'Store',   '2026-Q1', 15100.00),
    ('South',   'Services', 'Partner', '2026-Q3', 12450.00),
    ('South',   'Training', 'Partner', '2026-Q4',  8300.00),
    ('West',    'Hardware', 'Online',  '2026-Q1', 13900.00),
    ('West',    'Services', 'Store',   '2026-Q3', 10150.00),
    ('West',    'Training', 'Online',  '2026-Q4',  6900.00),
    ('Central', 'Hardware', 'Partner', '2026-Q4',  9700.00),
    ('Central', 'Services', 'Store',   '2026-Q2', 10900.00),
    ('Central', 'Training', 'Online',  '2026-Q4',  6400.00);

SELECT
    sf.RegionCode,
    sf.ProductGroup,
    sf.SalesChannel,
    sf.FiscalQuarter,
    sf.RevenueAmount
FROM #SalesFact AS sf
ORDER BY
    sf.RegionCode,
    sf.ProductGroup,
    sf.SalesChannel,
    sf.FiscalQuarter;

CREATE TABLE #FullCubeReference
(
    GroupingId             INT           NOT NULL,
    ActiveDimensions       INT           NOT NULL,
    DetailDimensions       VARCHAR(160)  NOT NULL,
    AggregatedDimensions   VARCHAR(160)  NOT NULL,
    ActualRowsAtLevel      INT           NOT NULL,
    TotalRevenueAtLevel    DECIMAL(18,2) NOT NULL
);

;WITH CubeRaw AS
(
    SELECT
        GROUPING_ID
        (
            sf.RegionCode,
            sf.ProductGroup,
            sf.SalesChannel,
            sf.FiscalQuarter
        ) AS GroupingId,
        GROUPING(sf.RegionCode) AS RegionAggregated,
        GROUPING(sf.ProductGroup) AS ProductAggregated,
        GROUPING(sf.SalesChannel) AS ChannelAggregated,
        GROUPING(sf.FiscalQuarter) AS QuarterAggregated,
        SUM(sf.RevenueAmount) AS RevenueAmount
    FROM #SalesFact AS sf
    GROUP BY CUBE
    (
        sf.RegionCode,
        sf.ProductGroup,
        sf.SalesChannel,
        sf.FiscalQuarter
    )
)
INSERT INTO #FullCubeReference
(
    GroupingId,
    ActiveDimensions,
    DetailDimensions,
    AggregatedDimensions,
    ActualRowsAtLevel,
    TotalRevenueAtLevel
)
SELECT
    cr.GroupingId,
    4 - MAX(cr.RegionAggregated + cr.ProductAggregated + cr.ChannelAggregated + cr.QuarterAggregated) AS ActiveDimensions,
    CASE
        WHEN MAX(cr.RegionAggregated) = 0 AND MAX(cr.ProductAggregated) = 0 AND MAX(cr.ChannelAggregated) = 0 AND MAX(cr.QuarterAggregated) = 0 THEN 'RegionCode, ProductGroup, SalesChannel, FiscalQuarter'
        WHEN MAX(cr.RegionAggregated) = 0 AND MAX(cr.ProductAggregated) = 0 AND MAX(cr.ChannelAggregated) = 0 AND MAX(cr.QuarterAggregated) = 1 THEN 'RegionCode, ProductGroup, SalesChannel'
        WHEN MAX(cr.RegionAggregated) = 0 AND MAX(cr.ProductAggregated) = 0 AND MAX(cr.ChannelAggregated) = 1 AND MAX(cr.QuarterAggregated) = 0 THEN 'RegionCode, ProductGroup, FiscalQuarter'
        WHEN MAX(cr.RegionAggregated) = 0 AND MAX(cr.ProductAggregated) = 0 AND MAX(cr.ChannelAggregated) = 1 AND MAX(cr.QuarterAggregated) = 1 THEN 'RegionCode, ProductGroup'
        WHEN MAX(cr.RegionAggregated) = 0 AND MAX(cr.ProductAggregated) = 1 AND MAX(cr.ChannelAggregated) = 0 AND MAX(cr.QuarterAggregated) = 0 THEN 'RegionCode, SalesChannel, FiscalQuarter'
        WHEN MAX(cr.RegionAggregated) = 0 AND MAX(cr.ProductAggregated) = 1 AND MAX(cr.ChannelAggregated) = 0 AND MAX(cr.QuarterAggregated) = 1 THEN 'RegionCode, SalesChannel'
        WHEN MAX(cr.RegionAggregated) = 0 AND MAX(cr.ProductAggregated) = 1 AND MAX(cr.ChannelAggregated) = 1 AND MAX(cr.QuarterAggregated) = 0 THEN 'RegionCode, FiscalQuarter'
        WHEN MAX(cr.RegionAggregated) = 0 AND MAX(cr.ProductAggregated) = 1 AND MAX(cr.ChannelAggregated) = 1 AND MAX(cr.QuarterAggregated) = 1 THEN 'RegionCode'
        WHEN MAX(cr.RegionAggregated) = 1 AND MAX(cr.ProductAggregated) = 0 AND MAX(cr.ChannelAggregated) = 0 AND MAX(cr.QuarterAggregated) = 0 THEN 'ProductGroup, SalesChannel, FiscalQuarter'
        WHEN MAX(cr.RegionAggregated) = 1 AND MAX(cr.ProductAggregated) = 0 AND MAX(cr.ChannelAggregated) = 0 AND MAX(cr.QuarterAggregated) = 1 THEN 'ProductGroup, SalesChannel'
        WHEN MAX(cr.RegionAggregated) = 1 AND MAX(cr.ProductAggregated) = 0 AND MAX(cr.ChannelAggregated) = 1 AND MAX(cr.QuarterAggregated) = 0 THEN 'ProductGroup, FiscalQuarter'
        WHEN MAX(cr.RegionAggregated) = 1 AND MAX(cr.ProductAggregated) = 0 AND MAX(cr.ChannelAggregated) = 1 AND MAX(cr.QuarterAggregated) = 1 THEN 'ProductGroup'
        WHEN MAX(cr.RegionAggregated) = 1 AND MAX(cr.ProductAggregated) = 1 AND MAX(cr.ChannelAggregated) = 0 AND MAX(cr.QuarterAggregated) = 0 THEN 'SalesChannel, FiscalQuarter'
        WHEN MAX(cr.RegionAggregated) = 1 AND MAX(cr.ProductAggregated) = 1 AND MAX(cr.ChannelAggregated) = 0 AND MAX(cr.QuarterAggregated) = 1 THEN 'SalesChannel'
        WHEN MAX(cr.RegionAggregated) = 1 AND MAX(cr.ProductAggregated) = 1 AND MAX(cr.ChannelAggregated) = 1 AND MAX(cr.QuarterAggregated) = 0 THEN 'FiscalQuarter'
        ELSE '(grand total)'
    END AS DetailDimensions,
    CASE
        WHEN MAX(cr.RegionAggregated) = 0 AND MAX(cr.ProductAggregated) = 0 AND MAX(cr.ChannelAggregated) = 0 AND MAX(cr.QuarterAggregated) = 0 THEN '(none)'
        ELSE CONCAT(
            CASE WHEN MAX(cr.RegionAggregated) = 1 THEN 'RegionCode ' ELSE '' END,
            CASE WHEN MAX(cr.ProductAggregated) = 1 THEN 'ProductGroup ' ELSE '' END,
            CASE WHEN MAX(cr.ChannelAggregated) = 1 THEN 'SalesChannel ' ELSE '' END,
            CASE WHEN MAX(cr.QuarterAggregated) = 1 THEN 'FiscalQuarter' ELSE '' END
        )
    END AS AggregatedDimensions,
    COUNT(*) AS ActualRowsAtLevel,
    CAST(SUM(cr.RevenueAmount) AS DECIMAL(18,2)) AS TotalRevenueAtLevel
FROM CubeRaw AS cr
GROUP BY
    cr.GroupingId;

IF @ShowFullCubeReference = 1
BEGIN
    SELECT
        fcr.GroupingId,
        fcr.ActiveDimensions,
        fcr.DetailDimensions,
        fcr.AggregatedDimensions,
        fcr.ActualRowsAtLevel,
        fcr.TotalRevenueAtLevel
    FROM #FullCubeReference AS fcr
    ORDER BY
        fcr.ActiveDimensions DESC,
        fcr.GroupingId ASC;
END;

CREATE TABLE #SelectiveDesign
(
    DesignOrder            INT           NOT NULL,
    DesignLabel            VARCHAR(80)   NOT NULL,
    BusinessQuestion       VARCHAR(220)  NOT NULL,
    GroupingId             INT           NOT NULL,
    DetailDimensions       VARCHAR(160)  NOT NULL,
    IncludedInDesign       BIT           NOT NULL
);

INSERT INTO #SelectiveDesign
(
    DesignOrder,
    DesignLabel,
    BusinessQuestion,
    GroupingId,
    DetailDimensions,
    IncludedInDesign
)
VALUES
    (1, 'RegionProduct', 'Welche Produktgruppen tragen je Region den Umsatz?', 3, 'RegionCode, ProductGroup', 1),
    (2, 'RegionQuarter', 'Wie entwickelt sich der Umsatz je Region ueber die Quartale?', 6, 'RegionCode, FiscalQuarter', 1),
    (3, 'ChannelQuarter', 'Welche Verkaufskanaele liefern je Quartal welchen Beitrag?', 12, 'SalesChannel, FiscalQuarter', 1),
    (4, 'ProductQuarter', 'Welche Produktgruppen zeigen je Quartal den staerksten Beitrag?', 10, 'ProductGroup, FiscalQuarter', @IncludeProductQuarter),
    (5, 'GrandTotal', 'Wird eine Gesamtzeile ueber alle Dimensionen benoetigt?', 15, '(grand total)', @IncludeGrandTotal);

SELECT
    sd.DesignOrder,
    sd.DesignLabel,
    sd.BusinessQuestion,
    sd.DetailDimensions,
    sd.GroupingId,
    sd.IncludedInDesign,
    fcr.ActualRowsAtLevel,
    CASE
        WHEN sd.IncludedInDesign = 1 THEN 'selected'
        ELSE 'skipped'
    END AS DesignDecision
FROM #SelectiveDesign AS sd
LEFT JOIN #FullCubeReference AS fcr
    ON fcr.GroupingId = sd.GroupingId
ORDER BY
    sd.DesignOrder;

CREATE TABLE #SelectiveSubtotalResult
(
    DesignOrder          INT           NOT NULL,
    DesignLabel          VARCHAR(80)   NOT NULL,
    LevelCaption         VARCHAR(120)  NOT NULL,
    RegionCode           VARCHAR(20)   NULL,
    ProductGroup         VARCHAR(30)   NULL,
    SalesChannel         VARCHAR(20)   NULL,
    FiscalQuarter        VARCHAR(10)   NULL,
    RevenueAmount        DECIMAL(18,2) NOT NULL,
    DesignReason         VARCHAR(220)  NOT NULL
);

INSERT INTO #SelectiveSubtotalResult
(
    DesignOrder,
    DesignLabel,
    LevelCaption,
    RegionCode,
    ProductGroup,
    SalesChannel,
    FiscalQuarter,
    RevenueAmount,
    DesignReason
)
SELECT
    1,
    'RegionProduct',
    'Subtotal je Region und Produktgruppe',
    sf.RegionCode,
    sf.ProductGroup,
    NULL,
    NULL,
    SUM(sf.RevenueAmount),
    'Unterstuetzt Portfoliosteuerung je Region ohne unnoetige Kanal- und Quartalskombinationen.'
FROM #SalesFact AS sf
GROUP BY
    sf.RegionCode,
    sf.ProductGroup;

INSERT INTO #SelectiveSubtotalResult
(
    DesignOrder,
    DesignLabel,
    LevelCaption,
    RegionCode,
    ProductGroup,
    SalesChannel,
    FiscalQuarter,
    RevenueAmount,
    DesignReason
)
SELECT
    2,
    'RegionQuarter',
    'Subtotal je Region und Quartal',
    sf.RegionCode,
    NULL,
    NULL,
    sf.FiscalQuarter,
    SUM(sf.RevenueAmount),
    'Zeigt regionale Verlaufssignale ueber die Zeit ohne weitere Aufsplitterung.'
FROM #SalesFact AS sf
GROUP BY
    sf.RegionCode,
    sf.FiscalQuarter;

INSERT INTO #SelectiveSubtotalResult
(
    DesignOrder,
    DesignLabel,
    LevelCaption,
    RegionCode,
    ProductGroup,
    SalesChannel,
    FiscalQuarter,
    RevenueAmount,
    DesignReason
)
SELECT
    3,
    'ChannelQuarter',
    'Subtotal je Kanal und Quartal',
    NULL,
    NULL,
    sf.SalesChannel,
    sf.FiscalQuarter,
    SUM(sf.RevenueAmount),
    'Fokussiert auf Vertriebssteuerung pro Quartal statt auf alle moeglichen Mischdimensionen.'
FROM #SalesFact AS sf
GROUP BY
    sf.SalesChannel,
    sf.FiscalQuarter;

IF @IncludeProductQuarter = 1
BEGIN
    INSERT INTO #SelectiveSubtotalResult
    (
        DesignOrder,
        DesignLabel,
        LevelCaption,
        RegionCode,
        ProductGroup,
        SalesChannel,
        FiscalQuarter,
        RevenueAmount,
        DesignReason
    )
    SELECT
        4,
        'ProductQuarter',
        'Subtotal je Produktgruppe und Quartal',
        NULL,
        sf.ProductGroup,
        NULL,
        sf.FiscalQuarter,
        SUM(sf.RevenueAmount),
        'Optional fuer Sortimentssicht ueber Quartale; bleibt abschaltbar, wenn dieser Schnitt nicht benoetigt wird.'
    FROM #SalesFact AS sf
    GROUP BY
        sf.ProductGroup,
        sf.FiscalQuarter;
END;

IF @IncludeGrandTotal = 1
BEGIN
    INSERT INTO #SelectiveSubtotalResult
    (
        DesignOrder,
        DesignLabel,
        LevelCaption,
        RegionCode,
        ProductGroup,
        SalesChannel,
        FiscalQuarter,
        RevenueAmount,
        DesignReason
    )
    SELECT
        5,
        'GrandTotal',
        'Grand Total',
        NULL,
        NULL,
        NULL,
        NULL,
        SUM(sf.RevenueAmount),
        'Liefert eine kompakte Referenz fuer die Gesamtsumme aller Zeilen.'
    FROM #SalesFact AS sf;
END;

SELECT
    selected_levels.SelectedLevelCount,
    all_levels.TotalCubeLevels,
    all_levels.TotalCubeLevels - selected_levels.SelectedLevelCount AS SkippedLevels,
    selected_rows.SelectedRows,
    all_rows.TotalCubeRows,
    all_rows.TotalCubeRows - selected_rows.SelectedRows AS RowsAvoided,
    CAST(selected_rows.SelectedRows * 1.0 / NULLIF(all_rows.TotalCubeRows, 0) AS DECIMAL(9,4)) AS ShareOfCubeRowsUsed
FROM
(
    SELECT COUNT(*) AS SelectedLevelCount
    FROM #SelectiveDesign AS sd
    WHERE sd.IncludedInDesign = 1
) AS selected_levels
CROSS JOIN
(
    SELECT COUNT(*) AS TotalCubeLevels
    FROM #FullCubeReference AS fcr
) AS all_levels
CROSS JOIN
(
    SELECT COUNT(*) AS SelectedRows
    FROM #SelectiveSubtotalResult AS ssr
) AS selected_rows
CROSS JOIN
(
    SELECT SUM(fcr.ActualRowsAtLevel) AS TotalCubeRows
    FROM #FullCubeReference AS fcr
) AS all_rows;

SELECT
    ssr.DesignOrder,
    ssr.DesignLabel,
    ssr.LevelCaption,
    COALESCE(ssr.RegionCode, '(all)') AS RegionCode,
    COALESCE(ssr.ProductGroup, '(all)') AS ProductGroup,
    COALESCE(ssr.SalesChannel, '(all)') AS SalesChannel,
    COALESCE(ssr.FiscalQuarter, '(all)') AS FiscalQuarter,
    ssr.RevenueAmount,
    ssr.DesignReason
FROM #SelectiveSubtotalResult AS ssr
ORDER BY
    ssr.DesignOrder,
    ssr.RegionCode,
    ssr.ProductGroup,
    ssr.SalesChannel,
    ssr.FiscalQuarter;

CREATE TABLE #DesignGuidance
(
    StepNumber       INT           NOT NULL,
    GuidanceFocus    VARCHAR(80)   NOT NULL,
    Recommendation   VARCHAR(260)  NOT NULL
);

INSERT INTO #DesignGuidance
(
    StepNumber,
    GuidanceFocus,
    Recommendation
)
VALUES
    (1, 'Business questions', 'Leite jede Subtotal-Ebene aus einer konkreten fachlichen Frage ab statt aus technischer Vollstaendigkeit.'),
    (2, 'Row budget', 'Vergleiche die Zahl selektierter Ergebniszeilen mit dem Voll-CUBE, um unnoetige Aggregationskosten sichtbar zu machen.'),
    (3, 'Optionality', 'Halte selten benoetigte Ebenen per Parameter oder separatem Report abschaltbar.'),
    (4, 'Escalation path', 'Fuege weitere Grouping Sets erst hinzu, wenn ein neuer Reporting-Bedarf nicht durch bestehende Ebenen beantwortet wird.');

SELECT
    dg.StepNumber,
    dg.GuidanceFocus,
    dg.Recommendation
FROM #DesignGuidance AS dg
ORDER BY
    dg.StepNumber;
