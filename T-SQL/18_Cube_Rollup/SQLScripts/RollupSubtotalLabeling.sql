/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "RollupSubtotalLabeling.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "18_Cube_Rollup"

purpose: >
  Beschriftet Detail-, Subtotal- und Grand-Total-Zeilen in einem
  ROLLUP-Ergebnis mit lesbaren Texten, damit aggregierte Ebenen nicht nur
  ueber rohe NULL-Werte erkannt werden muessen.

parameters:
  - name: "@ShowSourcePreview"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = die Demo-Fakttabelle vor der Aggregation ausgeben"
  - name: "@UseCompactLabels"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = kompakte Scope-Labels statt ausfuehrlicher Beschriftungen verwenden"
  - name: "@GrandTotalLabel"
    sql_type: "VARCHAR(80)"
    direction: "IN"
    required: false
    description: "Beschriftung fuer die voll aggregierte Grand-Total-Zeile"

result_sets:
  - name: "SourceFactPreview"
    description: "Optionale Vorschau auf die Demo-Umsatzdaten"
  - name: "RawRollupPreview"
    description: "Technisches ROLLUP-Ergebnis mit GROUPING-Informationen"
  - name: "LabeledRollupResult"
    description: "ROLLUP-Ausgabe mit sprechenden Labels fuer Detail, Subtotal und Grand Total"
  - name: "LabelingGuidance"
    description: "Kurze Hinweise fuer die Uebernahme der Label-Logik in Reports"

dependencies:
  - "tempdb temporary tables"
  - "GROUP BY ROLLUP"
  - "GROUPING"
  - "GROUPING_ID"
  - "CASE"
  - "CONCAT"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/18_Cube_Rollup/SQLScripts/RollupSubtotalLabeling.md"
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
    description: "Erstversion fuer sprechende Beschriftungen in ROLLUP-Ergebnissen"

notes:
  - "Das Skript arbeitet ausschliesslich mit Demo-Daten in temporaeren Tabellen"
  - "Die Label-Logik ist bewusst generisch gehalten und kann spaeter an Fachbegriffe angepasst werden"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @ShowSourcePreview BIT = 1;
DECLARE @UseCompactLabels BIT = 0;
DECLARE @GrandTotalLabel VARCHAR(80) = 'Gesamtergebnis ueber alle Regionen, Produktgruppen und Kanaele';

IF @ShowSourcePreview NOT IN (0, 1)
BEGIN
    THROW 50070, '@ShowSourcePreview muss 0 oder 1 sein.', 1;
END;

IF @UseCompactLabels NOT IN (0, 1)
BEGIN
    THROW 50071, '@UseCompactLabels muss 0 oder 1 sein.', 1;
END;

IF NULLIF(LTRIM(RTRIM(@GrandTotalLabel)), '') IS NULL
BEGIN
    THROW 50072, '@GrandTotalLabel darf nicht leer sein.', 1;
END;

DROP TABLE IF EXISTS #SalesFact;
DROP TABLE IF EXISTS #RawRollupPreview;
DROP TABLE IF EXISTS #LabeledRollupResult;
DROP TABLE IF EXISTS #LabelingGuidance;

CREATE TABLE #SalesFact
(
    RegionCode      VARCHAR(20)   NOT NULL,
    ProductGroup    VARCHAR(30)   NOT NULL,
    SalesChannel    VARCHAR(20)   NOT NULL,
    RevenueAmount   DECIMAL(18,2) NOT NULL
);

INSERT INTO #SalesFact
(
    RegionCode,
    ProductGroup,
    SalesChannel,
    RevenueAmount
)
VALUES
    ('North',   'Hardware', 'Online', 11200.00),
    ('North',   'Hardware', 'Store',   9700.00),
    ('North',   'Services', 'Online',  8300.00),
    ('North',   'Training', 'Partner', 4200.00),
    ('South',   'Hardware', 'Store',  10400.00),
    ('South',   'Services', 'Partner', 7600.00),
    ('South',   'Training', 'Online',  5100.00),
    ('West',    'Hardware', 'Partner', 8900.00),
    ('West',    'Services', 'Online',  7900.00),
    ('West',    'Training', 'Store',   4600.00),
    ('Central', 'Hardware', 'Store',   6800.00),
    ('Central', 'Services', 'Partner', 6100.00);

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

CREATE TABLE #RawRollupPreview
(
    RegionCode             VARCHAR(20)   NULL,
    ProductGroup           VARCHAR(30)   NULL,
    SalesChannel           VARCHAR(20)   NULL,
    RevenueAmount          DECIMAL(18,2) NOT NULL,
    GroupingId             INT           NOT NULL,
    AggregatedDimensions   TINYINT       NOT NULL,
    LevelKind              VARCHAR(20)   NOT NULL
);

INSERT INTO #RawRollupPreview
(
    RegionCode,
    ProductGroup,
    SalesChannel,
    RevenueAmount,
    GroupingId,
    AggregatedDimensions,
    LevelKind
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
    END AS LevelKind
FROM #SalesFact AS sf
GROUP BY ROLLUP
(
    sf.RegionCode,
    sf.ProductGroup,
    sf.SalesChannel
);

SELECT
    rrp.RegionCode,
    rrp.ProductGroup,
    rrp.SalesChannel,
    rrp.RevenueAmount,
    rrp.GroupingId,
    rrp.AggregatedDimensions,
    rrp.LevelKind
FROM #RawRollupPreview AS rrp
ORDER BY
    rrp.AggregatedDimensions DESC,
    rrp.GroupingId ASC,
    rrp.RegionCode,
    rrp.ProductGroup,
    rrp.SalesChannel;

CREATE TABLE #LabeledRollupResult
(
    RegionCode             VARCHAR(20)   NULL,
    ProductGroup           VARCHAR(30)   NULL,
    SalesChannel           VARCHAR(20)   NULL,
    RevenueAmount          DECIMAL(18,2) NOT NULL,
    GroupingId             INT           NOT NULL,
    AggregatedDimensions   TINYINT       NOT NULL,
    LevelKind              VARCHAR(20)   NOT NULL,
    ScopeLabel             VARCHAR(220)  NOT NULL,
    DisplayRegion          VARCHAR(40)   NOT NULL,
    DisplayProductGroup    VARCHAR(50)   NOT NULL,
    DisplaySalesChannel    VARCHAR(40)   NOT NULL,
    ReportingHint          VARCHAR(220)  NOT NULL
);

INSERT INTO #LabeledRollupResult
(
    RegionCode,
    ProductGroup,
    SalesChannel,
    RevenueAmount,
    GroupingId,
    AggregatedDimensions,
    LevelKind,
    ScopeLabel,
    DisplayRegion,
    DisplayProductGroup,
    DisplaySalesChannel,
    ReportingHint
)
SELECT
    rrp.RegionCode,
    rrp.ProductGroup,
    rrp.SalesChannel,
    rrp.RevenueAmount,
    rrp.GroupingId,
    rrp.AggregatedDimensions,
    rrp.LevelKind,
    CASE
        WHEN rrp.LevelKind = 'grand_total' THEN @GrandTotalLabel
        WHEN @UseCompactLabels = 1 THEN CONCAT(
            CASE WHEN rrp.RegionCode IS NULL THEN 'Alle Regionen' ELSE rrp.RegionCode END,
            ' | ',
            CASE WHEN rrp.ProductGroup IS NULL THEN 'Alle Produktgruppen' ELSE rrp.ProductGroup END,
            ' | ',
            CASE WHEN rrp.SalesChannel IS NULL THEN 'Alle Kanaele' ELSE rrp.SalesChannel END
        )
        WHEN rrp.LevelKind = 'detail' THEN CONCAT(
            'Detailzeile fuer Region ',
            rrp.RegionCode,
            ', Produktgruppe ',
            rrp.ProductGroup,
            ' und Kanal ',
            rrp.SalesChannel
        )
        ELSE CONCAT(
            'Subtotal fuer ',
            CASE WHEN rrp.RegionCode IS NULL THEN 'alle Regionen' ELSE CONCAT('Region ', rrp.RegionCode) END,
            ', ',
            CASE WHEN rrp.ProductGroup IS NULL THEN 'alle Produktgruppen' ELSE CONCAT('Produktgruppe ', rrp.ProductGroup) END,
            ' und ',
            CASE WHEN rrp.SalesChannel IS NULL THEN 'alle Kanaele' ELSE CONCAT('Kanal ', rrp.SalesChannel) END
        )
    END AS ScopeLabel,
    CASE
        WHEN rrp.RegionCode IS NULL THEN '(alle Regionen)'
        ELSE rrp.RegionCode
    END AS DisplayRegion,
    CASE
        WHEN rrp.ProductGroup IS NULL THEN '(alle Produktgruppen)'
        ELSE rrp.ProductGroup
    END AS DisplayProductGroup,
    CASE
        WHEN rrp.SalesChannel IS NULL THEN '(alle Kanaele)'
        ELSE rrp.SalesChannel
    END AS DisplaySalesChannel,
    CASE
        WHEN rrp.LevelKind = 'detail' THEN 'Leaf-Zeilen koennen direkt in einer Detailtabelle oder Drilldown-Ansicht gezeigt werden.'
        WHEN rrp.LevelKind = 'grand_total' THEN 'Grand Totals sollten sprachlich explizit benannt statt nur ueber NULL-Werte erkannt werden.'
        ELSE 'Subtotal-Zeilen profitieren von Sammelbezeichnungen fuer aggregierte Dimensionen und sichtbaren Restdimensionen.'
    END AS ReportingHint
FROM #RawRollupPreview AS rrp;

SELECT
    lrr.RegionCode,
    lrr.ProductGroup,
    lrr.SalesChannel,
    lrr.RevenueAmount,
    lrr.GroupingId,
    lrr.AggregatedDimensions,
    lrr.LevelKind,
    lrr.ScopeLabel,
    lrr.DisplayRegion,
    lrr.DisplayProductGroup,
    lrr.DisplaySalesChannel,
    lrr.ReportingHint
FROM #LabeledRollupResult AS lrr
ORDER BY
    lrr.AggregatedDimensions DESC,
    lrr.GroupingId ASC,
    lrr.RegionCode,
    lrr.ProductGroup,
    lrr.SalesChannel;

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
    (1, 'Grand Total', 'Nutze einen expliziten Text fuer die voll aggregierte Zeile, damit sie in Reports sofort erkennbar ist.'),
    (2, 'Subtotals', 'Ersetze aggregierte NULL-Dimensionen durch Sammelbezeichnungen wie alle Regionen oder alle Kanaele.'),
    (3, 'Compact labels', 'Fuer enge Tabellen oder Matrix-Header kann eine kompakte Pipe-Notation leichter lesbar sein.'),
    (4, 'Field-level captions', 'Zusatzspalten wie DisplayRegion oder DisplayProductGroup helfen bei Exporten ohne nachgelagerte CASE-Logik.');

SELECT
    lg.StepNumber,
    lg.FocusArea,
    lg.Recommendation
FROM #LabelingGuidance AS lg
ORDER BY
    lg.StepNumber;
