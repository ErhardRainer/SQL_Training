/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "DistinctVsGroupByDemo.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "02_Select"

purpose: >
  Vergleicht DISTINCT und GROUP BY auf einem kleinen Demo-Datensatz hinsichtlich
  Ergebnisform, Duplikatentfernung und typischer Plancharakteristik ohne
  produktive Tabellen vorauszusetzen.

parameters:
  - name: "@IncludeDetailedRows"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = Rohdaten und beide Vergleichsresultsets zusaetzlich ausgeben"
  - name: "@IncludeCategoryBreakdown"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = erweiterte GROUP BY-Auswertung je Region und Kategorie zeigen"
  - name: "@OnlyDuplicateGroups"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = Fokus auf Kombinationen mit mehrfach vorkommenden Zeilen"

result_sets:
  - name: "SourceDataPreview"
    description: "Optionale Vorschau des eingebetteten Demo-Datensatzes"
  - name: "DistinctProjection"
    description: "Eindeutige Region-Kategorie-Kombinationen per DISTINCT"
  - name: "GroupByProjection"
    description: "Dieselben Kombinationen per GROUP BY inklusive Duplikatzaehler"
  - name: "ComparisonSummary"
    description: "Verdichtet Ergebnisform und typische Planhinweise fuer beide Varianten"
  - name: "CategoryBreakdown"
    description: "Optionale erweiterte GROUP BY-Auswertung mit Kennzahlen je Region und Kategorie"

dependencies:
  - "CTE"
  - "VALUES constructor"
  - "DISTINCT"
  - "GROUP BY"
  - "COUNT"
  - "SUM"
  - "CASE"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/02_Select/SQLScripts/DistinctVsGroupByDemo.md"
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
    description: "Erstversion des Labs zum Vergleich von DISTINCT und GROUP BY"

notes:
  - "Das Skript verwendet nur Demo-Daten im CTE und bleibt vollstaendig read-only."
  - "Planhinweise werden didaktisch aus der Abfrageform abgeleitet und nicht aus einem konkreten Ausfuehrungsplan exportiert."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @IncludeDetailedRows BIT = 1;
DECLARE @IncludeCategoryBreakdown BIT = 1;
DECLARE @OnlyDuplicateGroups BIT = 0;

IF @IncludeDetailedRows NOT IN (0, 1)
BEGIN
    THROW 50000, '@IncludeDetailedRows muss 0 oder 1 sein.', 1;
END;

IF @IncludeCategoryBreakdown NOT IN (0, 1)
BEGIN
    THROW 50001, '@IncludeCategoryBreakdown muss 0 oder 1 sein.', 1;
END;

IF @OnlyDuplicateGroups NOT IN (0, 1)
BEGIN
    THROW 50002, '@OnlyDuplicateGroups muss 0 oder 1 sein.', 1;
END;

;WITH SalesSample AS
(
    SELECT
        sample.OrderID,
        sample.RegionCode,
        sample.ProductCategory,
        sample.SalesChannel,
        sample.CustomerTier,
        sample.UnitsSold,
        sample.NetAmount
    FROM
    (
        VALUES
            (101, 'DE-NORTH', 'Hardware', 'Direct', 'Gold', 4, CAST(480.00 AS DECIMAL(10,2))),
            (102, 'DE-NORTH', 'Hardware', 'Direct', 'Gold', 2, CAST(240.00 AS DECIMAL(10,2))),
            (103, 'DE-NORTH', 'Service',  'Partner', 'Silver', 1, CAST(160.00 AS DECIMAL(10,2))),
            (104, 'DE-SOUTH', 'Hardware', 'Direct', 'Silver', 3, CAST(330.00 AS DECIMAL(10,2))),
            (105, 'DE-SOUTH', 'Hardware', 'Partner', 'Silver', 3, CAST(315.00 AS DECIMAL(10,2))),
            (106, 'DE-SOUTH', 'Service',  'Partner', 'Bronze', 2, CAST(190.00 AS DECIMAL(10,2))),
            (107, 'AT-WEST',  'Hardware', 'Direct', 'Gold', 5, CAST(550.00 AS DECIMAL(10,2))),
            (108, 'AT-WEST',  'Hardware', 'Direct', 'Gold', 1, CAST(110.00 AS DECIMAL(10,2))),
            (109, 'AT-WEST',  'Training', 'Partner', 'Bronze', 6, CAST(420.00 AS DECIMAL(10,2))),
            (110, 'CH-CENTRAL', 'Service', 'Direct', 'Gold', 2, CAST(280.00 AS DECIMAL(10,2))),
            (111, 'CH-CENTRAL', 'Service', 'Direct', 'Gold', 2, CAST(280.00 AS DECIMAL(10,2))),
            (112, 'CH-CENTRAL', 'Training', 'Partner', 'Silver', 4, CAST(360.00 AS DECIMAL(10,2)))
    ) AS sample
    (
        OrderID,
        RegionCode,
        ProductCategory,
        SalesChannel,
        CustomerTier,
        UnitsSold,
        NetAmount
    )
),
BaseRows AS
(
    SELECT
        s.OrderID,
        s.RegionCode,
        s.ProductCategory,
        s.SalesChannel,
        s.CustomerTier,
        s.UnitsSold,
        s.NetAmount,
        CASE
            WHEN s.NetAmount >= 400 THEN 'high'
            WHEN s.NetAmount >= 250 THEN 'medium'
            ELSE 'entry'
        END AS RevenueBand
    FROM SalesSample AS s
),
DistinctProjection AS
(
    SELECT DISTINCT
        b.RegionCode,
        b.ProductCategory
    FROM BaseRows AS b
),
GroupedProjection AS
(
    SELECT
        b.RegionCode,
        b.ProductCategory,
        COUNT(*) AS DuplicateRowCount,
        SUM(b.UnitsSold) AS TotalUnitsSold,
        CAST(SUM(b.NetAmount) AS DECIMAL(12,2)) AS TotalNetAmount
    FROM BaseRows AS b
    GROUP BY
        b.RegionCode,
        b.ProductCategory
),
ComparisonSummary AS
(
    SELECT
        'DISTINCT' AS PatternName,
        COUNT(*) AS ResultRowCount,
        SUM(CASE WHEN gp.DuplicateRowCount > 1 THEN 1 ELSE 0 END) AS GroupsBackedByDuplicates,
        'Nur die projizierten Spalten sind im Resultset sichtbar.' AS ResultShape,
        'Typisch Stream Aggregate oder Hash Match Aggregate zur Duplikatentfernung.' AS LikelyPlanNote
    FROM DistinctProjection AS dp
    INNER JOIN GroupedProjection AS gp
        ON gp.RegionCode = dp.RegionCode
       AND gp.ProductCategory = dp.ProductCategory

    UNION ALL

    SELECT
        'GROUP BY' AS PatternName,
        COUNT(*) AS ResultRowCount,
        SUM(CASE WHEN gp.DuplicateRowCount > 1 THEN 1 ELSE 0 END) AS GroupsBackedByDuplicates,
        'Aggregationen und Gruppenschluessel koennen im selben Schritt ausgegeben werden.' AS ResultShape,
        'Aehnliche Operatoren wie bei DISTINCT, aber meist mit expliziten Aggregatberechnungen.' AS LikelyPlanNote
    FROM GroupedProjection AS gp
)
SELECT
    b.OrderID,
    b.RegionCode,
    b.ProductCategory,
    b.SalesChannel,
    b.CustomerTier,
    b.UnitsSold,
    b.NetAmount,
    b.RevenueBand
FROM BaseRows AS b
WHERE @IncludeDetailedRows = 1
ORDER BY
    b.RegionCode,
    b.ProductCategory,
    b.OrderID;

SELECT
    dp.RegionCode,
    dp.ProductCategory
FROM DistinctProjection AS dp
INNER JOIN GroupedProjection AS gp
    ON gp.RegionCode = dp.RegionCode
   AND gp.ProductCategory = dp.ProductCategory
WHERE @IncludeDetailedRows = 1
  AND (@OnlyDuplicateGroups = 0 OR gp.DuplicateRowCount > 1)
ORDER BY
    dp.RegionCode,
    dp.ProductCategory;

SELECT
    gp.RegionCode,
    gp.ProductCategory,
    gp.DuplicateRowCount,
    gp.TotalUnitsSold,
    gp.TotalNetAmount
FROM GroupedProjection AS gp
WHERE @IncludeDetailedRows = 1
  AND (@OnlyDuplicateGroups = 0 OR gp.DuplicateRowCount > 1)
ORDER BY
    gp.RegionCode,
    gp.ProductCategory;

SELECT
    cs.PatternName,
    cs.ResultRowCount,
    cs.GroupsBackedByDuplicates,
    cs.ResultShape,
    cs.LikelyPlanNote
FROM ComparisonSummary AS cs
ORDER BY
    cs.PatternName;

SELECT
    b.RegionCode,
    b.ProductCategory,
    COUNT(*) AS OrderCount,
    SUM(CASE WHEN b.SalesChannel = 'Direct' THEN 1 ELSE 0 END) AS DirectOrderCount,
    SUM(CASE WHEN b.RevenueBand = 'high' THEN 1 ELSE 0 END) AS HighRevenueRows,
    CAST(SUM(b.NetAmount) AS DECIMAL(12,2)) AS TotalNetAmount
FROM BaseRows AS b
WHERE @IncludeCategoryBreakdown = 1
  AND (@OnlyDuplicateGroups = 0
       OR EXISTS
       (
           SELECT 1
           FROM GroupedProjection AS gp
           WHERE gp.RegionCode = b.RegionCode
             AND gp.ProductCategory = b.ProductCategory
             AND gp.DuplicateRowCount > 1
       ))
GROUP BY
    b.RegionCode,
    b.ProductCategory
ORDER BY
    b.RegionCode,
    b.ProductCategory;
