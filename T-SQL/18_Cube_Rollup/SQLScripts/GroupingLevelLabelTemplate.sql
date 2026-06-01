/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "GroupingLevelLabelTemplate.sql"
script_version: "1.0"
script_type: "template"
chapter: "18_Cube_Rollup"

purpose: >
  Liefert eine didaktische Vorlage fuer sprechende Aggregationslabels in
  CUBE- oder ROLLUP-Ausgaben, indem GROUPING()-Flags in fachlich lesbare
  Ebenentexte, Detailbezeichnungen und Grand-Total-Labels ueberfuehrt werden.

parameters:
  - name: "@ShowSourcePreview"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = die Demo-Fakttabelle vor der Aggregation anzeigen"
  - name: "@UseCompactLabels"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = kuerzere Ebenenlabels statt ausfuehrlicher Beschriftungen verwenden"
  - name: "@GrandTotalLabel"
    sql_type: "VARCHAR(60)"
    direction: "IN"
    required: false
    description: "Beschriftung fuer die Zeile, in der alle Dimensionen aggregiert sind"

result_sets:
  - name: "SourceDataPreview"
    description: "Optionale Vorschau auf die Demo-Fakten fuer Region, Produktgruppe und Kanal"
  - name: "GroupingLevelLabelMatrix"
    description: "Vorlage mit Aggregationsgrad, GROUPING-Flags und sprechenden Labels je Zeile"
  - name: "LabelingGuidance"
    description: "Kurze Hinweise fuer die Uebertragung der Label-Logik in reale Reports"

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
  markdown_file: "T-SQL/18_Cube_Rollup/SQLScripts/GroupingLevelLabelTemplate.md"
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
    description: "Erstversion der Label-Vorlage fuer Aggregationslevel in CUBE-Ausgaben"

notes:
  - "Die Vorlage verwendet Demo-Daten in temporaeren Tabellen und setzt keine produktiven Fakt- oder Dimensionstabellen voraus"
  - "Die Label-Logik ist bewusst generisch gehalten, damit sie spaeter an Fachbegriffe, Sprachen oder UI-Konventionen angepasst werden kann"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @ShowSourcePreview BIT = 1;
DECLARE @UseCompactLabels BIT = 0;
DECLARE @GrandTotalLabel VARCHAR(60) = 'Gesamtergebnis ueber alle Dimensionen';

IF @ShowSourcePreview NOT IN (0, 1)
BEGIN
    THROW 50060, '@ShowSourcePreview muss 0 oder 1 sein.', 1;
END;

IF @UseCompactLabels NOT IN (0, 1)
BEGIN
    THROW 50061, '@UseCompactLabels muss 0 oder 1 sein.', 1;
END;

IF NULLIF(LTRIM(RTRIM(@GrandTotalLabel)), '') IS NULL
BEGIN
    THROW 50062, '@GrandTotalLabel darf nicht leer sein.', 1;
END;

DROP TABLE IF EXISTS #SalesFact;
DROP TABLE IF EXISTS #GroupingLevelLabelMatrix;
DROP TABLE IF EXISTS #LabelingGuidance;

CREATE TABLE #SalesFact
(
    RegionCode      VARCHAR(20)   NOT NULL,
    ProductGroup    VARCHAR(30)   NOT NULL,
    SalesChannel    VARCHAR(20)   NOT NULL,
    RevenueAmount   DECIMAL(12,2) NOT NULL
);

INSERT INTO #SalesFact
(
    RegionCode,
    ProductGroup,
    SalesChannel,
    RevenueAmount
)
VALUES
    ('North',   'Hardware', 'Online',  12800.00),
    ('North',   'Hardware', 'Store',   11350.00),
    ('North',   'Services', 'Online',   9250.00),
    ('South',   'Hardware', 'Store',   14100.00),
    ('South',   'Services', 'Partner',  8400.00),
    ('South',   'Training', 'Online',   6200.00),
    ('West',    'Hardware', 'Partner',  9900.00),
    ('West',    'Services', 'Online',   8750.00),
    ('Central', 'Hardware', 'Store',    9650.00),
    ('Central', 'Training', 'Partner',  7100.00);

IF @ShowSourcePreview = 1
BEGIN
    SELECT
        sf.RegionCode,
        sf.ProductGroup,
        sf.SalesChannel,
        sf.RevenueAmount
    FROM #SalesFact AS sf
    ORDER BY
        sf.RegionCode,
        sf.ProductGroup,
        sf.SalesChannel;
END;

CREATE TABLE #GroupingLevelLabelMatrix
(
    RegionCode                VARCHAR(20)   NULL,
    ProductGroup              VARCHAR(30)   NULL,
    SalesChannel              VARCHAR(20)   NULL,
    RevenueAmount             DECIMAL(12,2) NOT NULL,
    GroupingId                INT           NOT NULL,
    AggregatedDimensions      TINYINT       NOT NULL,
    LevelKind                 VARCHAR(20)   NOT NULL,
    LevelLabel                VARCHAR(220)  NOT NULL,
    RegionLabel               VARCHAR(60)   NOT NULL,
    ProductGroupLabel         VARCHAR(70)   NOT NULL,
    SalesChannelLabel         VARCHAR(60)   NOT NULL,
    LabelTemplateHint         VARCHAR(220)  NOT NULL
);

INSERT INTO #GroupingLevelLabelMatrix
(
    RegionCode,
    ProductGroup,
    SalesChannel,
    RevenueAmount,
    GroupingId,
    AggregatedDimensions,
    LevelKind,
    LevelLabel,
    RegionLabel,
    ProductGroupLabel,
    SalesChannelLabel,
    LabelTemplateHint
)
SELECT
    sf.RegionCode,
    sf.ProductGroup,
    sf.SalesChannel,
    SUM(sf.RevenueAmount) AS RevenueAmount,
    GROUPING_ID
    (
        sf.RegionCode,
        sf.ProductGroup,
        sf.SalesChannel
    ) AS GroupingId,
    GROUPING(sf.RegionCode)
    + GROUPING(sf.ProductGroup)
    + GROUPING(sf.SalesChannel) AS AggregatedDimensions,
    CASE
        WHEN GROUPING(sf.RegionCode)
           + GROUPING(sf.ProductGroup)
           + GROUPING(sf.SalesChannel) = 0 THEN 'detail'
        WHEN GROUPING(sf.RegionCode)
           + GROUPING(sf.ProductGroup)
           + GROUPING(sf.SalesChannel) = 3 THEN 'grand_total'
        ELSE 'subtotal'
    END AS LevelKind,
    CASE
        WHEN GROUPING(sf.RegionCode)
           + GROUPING(sf.ProductGroup)
           + GROUPING(sf.SalesChannel) = 3 THEN @GrandTotalLabel
        WHEN @UseCompactLabels = 1 THEN CONCAT(
            'Level ',
            GROUPING(sf.RegionCode)
            + GROUPING(sf.ProductGroup)
            + GROUPING(sf.SalesChannel),
            ': ',
            CASE WHEN GROUPING(sf.RegionCode) = 0 THEN sf.RegionCode ELSE 'alle Regionen' END,
            ' | ',
            CASE WHEN GROUPING(sf.ProductGroup) = 0 THEN sf.ProductGroup ELSE 'alle Produktgruppen' END,
            ' | ',
            CASE WHEN GROUPING(sf.SalesChannel) = 0 THEN sf.SalesChannel ELSE 'alle Kanaele' END
        )
        WHEN GROUPING(sf.RegionCode)
           + GROUPING(sf.ProductGroup)
           + GROUPING(sf.SalesChannel) = 0 THEN CONCAT(
            'Detailzeile fuer Region ',
            sf.RegionCode,
            ', Produktgruppe ',
            sf.ProductGroup,
            ' und Kanal ',
            sf.SalesChannel
        )
        ELSE CONCAT(
            'Subtotal fuer ',
            CASE WHEN GROUPING(sf.RegionCode) = 0 THEN CONCAT('Region ', sf.RegionCode) ELSE 'alle Regionen' END,
            ', ',
            CASE WHEN GROUPING(sf.ProductGroup) = 0 THEN CONCAT('Produktgruppe ', sf.ProductGroup) ELSE 'alle Produktgruppen' END,
            ' und ',
            CASE WHEN GROUPING(sf.SalesChannel) = 0 THEN CONCAT('Kanal ', sf.SalesChannel) ELSE 'alle Kanaele' END
        )
    END AS LevelLabel,
    CASE
        WHEN GROUPING(sf.RegionCode) = 1 THEN '(alle Regionen)'
        ELSE sf.RegionCode
    END AS RegionLabel,
    CASE
        WHEN GROUPING(sf.ProductGroup) = 1 THEN '(alle Produktgruppen)'
        ELSE sf.ProductGroup
    END AS ProductGroupLabel,
    CASE
        WHEN GROUPING(sf.SalesChannel) = 1 THEN '(alle Kanaele)'
        ELSE sf.SalesChannel
    END AS SalesChannelLabel,
    CASE
        WHEN GROUPING(sf.RegionCode)
           + GROUPING(sf.ProductGroup)
           + GROUPING(sf.SalesChannel) = 0 THEN 'Detailbeschriftung kann direkt aus den sichtbaren Dimensionswerten erzeugt werden.'
        WHEN GROUPING(sf.RegionCode)
           + GROUPING(sf.ProductGroup)
           + GROUPING(sf.SalesChannel) = 3 THEN 'Grand Total sollte sprachlich explizit benannt und nicht als NULL-Zeile gezeigt werden.'
        ELSE 'Bei Subtotals sollten aggregierte Dimensionen durch Sammelbezeichnungen ersetzt und verbleibende Detailwerte sichtbar bleiben.'
    END AS LabelTemplateHint
FROM #SalesFact AS sf
GROUP BY CUBE
(
    sf.RegionCode,
    sf.ProductGroup,
    sf.SalesChannel
);

SELECT
    gllm.RegionCode,
    gllm.ProductGroup,
    gllm.SalesChannel,
    gllm.RevenueAmount,
    gllm.GroupingId,
    gllm.AggregatedDimensions,
    gllm.LevelKind,
    gllm.LevelLabel,
    gllm.RegionLabel,
    gllm.ProductGroupLabel,
    gllm.SalesChannelLabel,
    gllm.LabelTemplateHint
FROM #GroupingLevelLabelMatrix AS gllm
ORDER BY
    gllm.AggregatedDimensions DESC,
    gllm.GroupingId ASC,
    gllm.RegionCode,
    gllm.ProductGroup,
    gllm.SalesChannel;

CREATE TABLE #LabelingGuidance
(
    StepNumber        INT           NOT NULL,
    FocusArea         VARCHAR(80)   NOT NULL,
    Recommendation    VARCHAR(260)  NOT NULL
);

INSERT INTO #LabelingGuidance
(
    StepNumber,
    FocusArea,
    Recommendation
)
VALUES
    (1, 'Grand totals', 'Vergib fuer die Vollaggregation einen expliziten Report-Text wie Gesamtergebnis statt rohe NULL-Werte anzuzeigen.'),
    (2, 'Subtotals', 'Kombiniere sichtbare Detaildimensionen mit Sammelbezeichnungen fuer aggregierte Ebenen, damit der fachliche Kontext erhalten bleibt.'),
    (3, 'Compact mode', 'Kurze Labels eignen sich fuer Pivot-Header oder Visualisierungen, waehrend ausfuehrliche Beschriftungen besser fuer Tabellen und Schulungsbeispiele passen.'),
    (4, 'Localization', 'Ersetze die generischen Texte spaeter durch Fachbegriffe, Sprachvarianten oder UI-konforme Beschriftungen, ohne die GROUPING-Logik zu aendern.');

SELECT
    lg.StepNumber,
    lg.FocusArea,
    lg.Recommendation
FROM #LabelingGuidance AS lg
ORDER BY
    lg.StepNumber;
