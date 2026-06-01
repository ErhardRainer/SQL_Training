/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "HavingThresholdPatterns.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "10_GroupBy_Aggregate"

purpose: >
  Demonstriert typische HAVING-Muster fuer Mindestumsatz,
  Mindestanzahl von Bestellungen und gruppenbezogene Ausreisserfilter
  auf Basis einer kompakten Demo-Sales-Tabelle.

parameters:
  - name: "@MinRevenue"
    sql_type: "DECIMAL(12,2)"
    direction: "IN"
    required: true
    description: "Mindestumsatz, den eine Gruppe in einem HAVING-SUM-Filter erreichen muss"
  - name: "@MinOrderCount"
    sql_type: "INT"
    direction: "IN"
    required: true
    description: "Mindestanzahl an Orders pro Gruppe fuer COUNT-basierte HAVING-Filter"
  - name: "@OutlierOrderAmount"
    sql_type: "DECIMAL(12,2)"
    direction: "IN"
    required: true
    description: "Grenzwert fuer Gruppen, die mindestens eine auffaellig hohe Einzelorder enthalten"
  - name: "@IncludeSourceData"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 gibt die Demo-Quelldaten vor den Aggregationen aus"

result_sets:
  - name: "SourceData"
    description: "Optionale Vorschau auf die Demo-Orders je Region und Kanal"
  - name: "GroupAggregateBaseline"
    description: "Basiskennzahlen aller Gruppen vor jeder HAVING-Filterung"
  - name: "HavingPatternResults"
    description: "Ergebnis der drei typischen HAVING-Muster plus einer kombinierten Variante"
  - name: "HavingPatternGuide"
    description: "Kurze Einordnung, welcher HAVING-Typ welche fachliche Frage beantwortet"

dependencies:
  - "tempdb"
  - "GROUP BY"
  - "HAVING"
  - "SUM()"
  - "COUNT()"
  - "AVG()"
  - "MAX()"
  - "UNION ALL"
  - "DROP TABLE IF EXISTS"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/10_GroupBy_Aggregate/SQLScripts/HavingThresholdPatterns.md"
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
    description: "Erstversion fuer typische HAVING-Schwellenmuster in Gruppenauswertungen"

notes:
  - "Die Erstversion nutzt lokale Temp-Tabellen statt produktiver Faktentabellen."
  - "Die HAVING-Beispiele kontrastieren Umsatz-, Mengen- und Ausreisser-Schwellen auf derselben Gruppierung."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @MinRevenue DECIMAL(12,2) = 3000.00;
DECLARE @MinOrderCount INT = 3;
DECLARE @OutlierOrderAmount DECIMAL(12,2) = 1800.00;
DECLARE @IncludeSourceData BIT = 1;

IF @MinRevenue IS NULL OR @MinRevenue <= 0
BEGIN
    THROW 50040, '@MinRevenue muss groesser als 0 sein.', 1;
END;

IF @MinOrderCount IS NULL OR @MinOrderCount <= 0
BEGIN
    THROW 50041, '@MinOrderCount muss groesser als 0 sein.', 1;
END;

IF @OutlierOrderAmount IS NULL OR @OutlierOrderAmount <= 0
BEGIN
    THROW 50042, '@OutlierOrderAmount muss groesser als 0 sein.', 1;
END;

IF @IncludeSourceData NOT IN (0, 1)
BEGIN
    THROW 50043, '@IncludeSourceData muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #SalesOrders;
DROP TABLE IF EXISTS #GroupAggregate;
DROP TABLE IF EXISTS #HavingPatternResult;

CREATE TABLE #SalesOrders
(
    OrderID INT NOT NULL,
    SalesRegion VARCHAR(20) NOT NULL,
    SalesChannel VARCHAR(20) NOT NULL,
    AccountName VARCHAR(40) NOT NULL,
    OrderDate DATE NOT NULL,
    OrderAmount DECIMAL(12,2) NOT NULL
);

CREATE TABLE #HavingPatternResult
(
    PatternName VARCHAR(40) NOT NULL,
    SalesRegion VARCHAR(20) NOT NULL,
    SalesChannel VARCHAR(20) NOT NULL,
    OrderCount INT NOT NULL,
    TotalRevenue DECIMAL(12,2) NOT NULL,
    AverageOrderAmount DECIMAL(12,2) NOT NULL,
    MaxOrderAmount DECIMAL(12,2) NOT NULL,
    ThresholdNote VARCHAR(200) NOT NULL
);

INSERT INTO #SalesOrders
(
    OrderID,
    SalesRegion,
    SalesChannel,
    AccountName,
    OrderDate,
    OrderAmount
)
VALUES
    (4001, 'North', 'Online', 'Aster Retail', '2026-03-02',  720.00),
    (4002, 'North', 'Online', 'Aster Retail', '2026-03-08', 1180.00),
    (4003, 'North', 'Online', 'Blue Harbor',  '2026-03-14', 1640.00),
    (4004, 'North', 'Retail', 'City Health',  '2026-03-05',  680.00),
    (4005, 'North', 'Retail', 'City Health',  '2026-03-19',  910.00),
    (4006, 'South', 'Online', 'Delta Works',  '2026-03-01',  540.00),
    (4007, 'South', 'Online', 'Delta Works',  '2026-03-12',  690.00),
    (4008, 'South', 'Online', 'Eon Energy',   '2026-03-27', 2050.00),
    (4009, 'South', 'Retail', 'Eon Energy',   '2026-03-04',  430.00),
    (4010, 'South', 'Retail', 'Futura Labs',  '2026-03-11',  510.00),
    (4011, 'South', 'Retail', 'Futura Labs',  '2026-03-22',  560.00),
    (4012, 'West',  'Online', 'Green Foods',  '2026-03-03',  980.00),
    (4013, 'West',  'Online', 'Green Foods',  '2026-03-16', 1020.00),
    (4014, 'West',  'Online', 'Harbor Care',  '2026-03-28', 1110.00),
    (4015, 'West',  'Retail', 'Harbor Care',  '2026-03-09',  350.00),
    (4016, 'West',  'Retail', 'Iota Systems', '2026-03-18',  370.00),
    (4017, 'East',  'Online', 'Juno Trade',   '2026-03-07', 1450.00),
    (4018, 'East',  'Online', 'Juno Trade',   '2026-03-20', 1520.00),
    (4019, 'East',  'Retail', 'Kappa Med',    '2026-03-10',  610.00),
    (4020, 'East',  'Retail', 'Kappa Med',    '2026-03-24',  640.00);

IF @IncludeSourceData = 1
BEGIN
    SELECT
        so.OrderID,
        so.SalesRegion,
        so.SalesChannel,
        so.AccountName,
        so.OrderDate,
        so.OrderAmount
    FROM #SalesOrders AS so
    ORDER BY
        so.SalesRegion,
        so.SalesChannel,
        so.OrderDate,
        so.OrderID;
END;

SELECT
    so.SalesRegion,
    so.SalesChannel,
    COUNT(*) AS OrderCount,
    SUM(so.OrderAmount) AS TotalRevenue,
    CAST(AVG(so.OrderAmount) AS DECIMAL(12,2)) AS AverageOrderAmount,
    MAX(so.OrderAmount) AS MaxOrderAmount
INTO #GroupAggregate
FROM #SalesOrders AS so
GROUP BY
    so.SalesRegion,
    so.SalesChannel;

SELECT
    ga.SalesRegion,
    ga.SalesChannel,
    ga.OrderCount,
    ga.TotalRevenue,
    ga.AverageOrderAmount,
    ga.MaxOrderAmount
FROM #GroupAggregate AS ga
ORDER BY
    ga.TotalRevenue DESC,
    ga.SalesRegion,
    ga.SalesChannel;

INSERT INTO #HavingPatternResult
(
    PatternName,
    SalesRegion,
    SalesChannel,
    OrderCount,
    TotalRevenue,
    AverageOrderAmount,
    MaxOrderAmount,
    ThresholdNote
)
SELECT
    'minimum_revenue' AS PatternName,
    so.SalesRegion,
    so.SalesChannel,
    COUNT(*) AS OrderCount,
    SUM(so.OrderAmount) AS TotalRevenue,
    CAST(AVG(so.OrderAmount) AS DECIMAL(12,2)) AS AverageOrderAmount,
    MAX(so.OrderAmount) AS MaxOrderAmount,
    CONCAT('SUM(OrderAmount) >= ', CONVERT(VARCHAR(30), CAST(@MinRevenue AS DECIMAL(12,2)))) AS ThresholdNote
FROM #SalesOrders AS so
GROUP BY
    so.SalesRegion,
    so.SalesChannel
HAVING
    SUM(so.OrderAmount) >= @MinRevenue;

INSERT INTO #HavingPatternResult
(
    PatternName,
    SalesRegion,
    SalesChannel,
    OrderCount,
    TotalRevenue,
    AverageOrderAmount,
    MaxOrderAmount,
    ThresholdNote
)
SELECT
    'minimum_order_count' AS PatternName,
    so.SalesRegion,
    so.SalesChannel,
    COUNT(*) AS OrderCount,
    SUM(so.OrderAmount) AS TotalRevenue,
    CAST(AVG(so.OrderAmount) AS DECIMAL(12,2)) AS AverageOrderAmount,
    MAX(so.OrderAmount) AS MaxOrderAmount,
    CONCAT('COUNT(*) >= ', CONVERT(VARCHAR(20), @MinOrderCount)) AS ThresholdNote
FROM #SalesOrders AS so
GROUP BY
    so.SalesRegion,
    so.SalesChannel
HAVING
    COUNT(*) >= @MinOrderCount;

INSERT INTO #HavingPatternResult
(
    PatternName,
    SalesRegion,
    SalesChannel,
    OrderCount,
    TotalRevenue,
    AverageOrderAmount,
    MaxOrderAmount,
    ThresholdNote
)
SELECT
    'outlier_order_filter' AS PatternName,
    so.SalesRegion,
    so.SalesChannel,
    COUNT(*) AS OrderCount,
    SUM(so.OrderAmount) AS TotalRevenue,
    CAST(AVG(so.OrderAmount) AS DECIMAL(12,2)) AS AverageOrderAmount,
    MAX(so.OrderAmount) AS MaxOrderAmount,
    CONCAT('MAX(OrderAmount) >= ', CONVERT(VARCHAR(30), CAST(@OutlierOrderAmount AS DECIMAL(12,2)))) AS ThresholdNote
FROM #SalesOrders AS so
GROUP BY
    so.SalesRegion,
    so.SalesChannel
HAVING
    MAX(so.OrderAmount) >= @OutlierOrderAmount;

INSERT INTO #HavingPatternResult
(
    PatternName,
    SalesRegion,
    SalesChannel,
    OrderCount,
    TotalRevenue,
    AverageOrderAmount,
    MaxOrderAmount,
    ThresholdNote
)
SELECT
    'combined_thresholds' AS PatternName,
    so.SalesRegion,
    so.SalesChannel,
    COUNT(*) AS OrderCount,
    SUM(so.OrderAmount) AS TotalRevenue,
    CAST(AVG(so.OrderAmount) AS DECIMAL(12,2)) AS AverageOrderAmount,
    MAX(so.OrderAmount) AS MaxOrderAmount,
    CONCAT(
        'SUM >= ', CONVERT(VARCHAR(30), CAST(@MinRevenue AS DECIMAL(12,2))),
        '; COUNT >= ', CONVERT(VARCHAR(20), @MinOrderCount),
        '; MAX >= ', CONVERT(VARCHAR(30), CAST(@OutlierOrderAmount AS DECIMAL(12,2)))
    ) AS ThresholdNote
FROM #SalesOrders AS so
GROUP BY
    so.SalesRegion,
    so.SalesChannel
HAVING
    SUM(so.OrderAmount) >= @MinRevenue
    AND COUNT(*) >= @MinOrderCount
    AND MAX(so.OrderAmount) >= @OutlierOrderAmount;

SELECT
    hpr.PatternName,
    hpr.SalesRegion,
    hpr.SalesChannel,
    hpr.OrderCount,
    hpr.TotalRevenue,
    hpr.AverageOrderAmount,
    hpr.MaxOrderAmount,
    hpr.ThresholdNote
FROM #HavingPatternResult AS hpr
ORDER BY
    hpr.PatternName,
    hpr.TotalRevenue DESC,
    hpr.SalesRegion,
    hpr.SalesChannel;

SELECT
    'minimum_revenue' AS PatternName,
    'Hebt Gruppen hervor, deren Gesamtumsatz einen Zielwert erreicht oder uebertrifft.' AS UseCase,
    'SUM(OrderAmount) >= @MinRevenue' AS HavingPredicate
UNION ALL
SELECT
    'minimum_order_count' AS PatternName,
    'Filtert Gruppen mit ausreichend vielen Einzelvorgaengen fuer belastbare Auswertungen.' AS UseCase,
    'COUNT(*) >= @MinOrderCount' AS HavingPredicate
UNION ALL
SELECT
    'outlier_order_filter' AS PatternName,
    'Markiert Gruppen, in denen mindestens eine aussergewoehnlich hohe Einzelorder vorkommt.' AS UseCase,
    'MAX(OrderAmount) >= @OutlierOrderAmount' AS HavingPredicate
UNION ALL
SELECT
    'combined_thresholds' AS PatternName,
    'Kombiniert Mindestumsatz, Mindestanzahl und Ausreisserkriterium fuer engere Review-Listen.' AS UseCase,
    'SUM(...) AND COUNT(*) AND MAX(...)' AS HavingPredicate;
