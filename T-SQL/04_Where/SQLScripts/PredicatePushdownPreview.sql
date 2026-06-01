/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "PredicatePushdownPreview.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "04_Where"

purpose: >
  Macht sichtbar, welche Filter bereits auf Basiszeilen greifen und
  welche Bedingungen erst nach einer Aggregation wirksam werden, damit
  der Unterschied zwischen fruehem WHERE-Filter und spaeterem HAVING-
  Schritt didaktisch nachvollziehbar bleibt.

parameters:
  - name: "@RegionCode"
    sql_type: "CHAR(2)"
    direction: "IN"
    required: false
    description: "Optionaler frueher Regionsfilter fuer DE, AT oder CH"
  - name: "@MinOrderDate"
    sql_type: "DATE"
    direction: "IN"
    required: false
    description: "Optionaler frueher Filter auf das Bestelldatum"
  - name: "@MinOrderAmount"
    sql_type: "DECIMAL(10,2)"
    direction: "IN"
    required: false
    description: "Optionaler frueher Filter auf den einzelnen Auftragswert"
  - name: "@MinCustomerRevenue"
    sql_type: "DECIMAL(10,2)"
    direction: "IN"
    required: false
    description: "Optionaler spaeter Filter auf aggregierten Umsatz je Kunde"

result_sets:
  - name: "FilterPreview"
    description: "Listet alle aktiven Filter und ordnet sie als frueh oder spaet ein"
  - name: "CandidateFlow"
    description: "Zeigt pro Auftrag, an welcher Stufe er aus dem Datenfluss faellt oder bestehen bleibt"
  - name: "StageSummary"
    description: "Verdichtet Zeilen- und Kundenmengen vor und nach fruehen sowie spaeten Filtern"

dependencies:
  - "tempdb temporary tables"
  - "CASE"
  - "GROUP BY"
  - "HAVING"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/04_Where/SQLScripts/PredicatePushdownPreview.md"
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
    date: "2026-04-17"
    user: "ER"
    description: "Erstversion fuer ein didaktisches Lab zu fruehen und spaeten Filterstufen"

notes:
  - "Das Skript arbeitet ausschliesslich mit tempdb-Objekten und einer kleinen Demo-Bestellmenge."
  - "Predicate Pushdown wird didaktisch ueber fruehe Zeilenfilter versus spaete HAVING-Filter veranschaulicht, nicht ueber echte Ausfuehrungsplaene."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @RegionCode CHAR(2) = 'DE';
DECLARE @MinOrderDate DATE = '2026-02-01';
DECLARE @MinOrderAmount DECIMAL(10, 2) = 100.00;
DECLARE @MinCustomerRevenue DECIMAL(10, 2) = 350.00;

IF @RegionCode IS NOT NULL AND @RegionCode NOT IN ('DE', 'AT', 'CH')
BEGIN
    THROW 50470, '@RegionCode muss NULL, DE, AT oder CH sein.', 1;
END;

IF @MinOrderAmount IS NOT NULL AND @MinOrderAmount < 0
BEGIN
    THROW 50471, '@MinOrderAmount darf nicht negativ sein.', 1;
END;

IF @MinCustomerRevenue IS NOT NULL AND @MinCustomerRevenue < 0
BEGIN
    THROW 50472, '@MinCustomerRevenue darf nicht negativ sein.', 1;
END;

DROP TABLE IF EXISTS #SalesOrders;
DROP TABLE IF EXISTS #FilterPreview;
DROP TABLE IF EXISTS #EarlyEvaluation;
DROP TABLE IF EXISTS #EarlyFiltered;
DROP TABLE IF EXISTS #CustomerRevenue;
DROP TABLE IF EXISTS #LateQualifiedCustomers;
DROP TABLE IF EXISTS #CandidateFlow;

CREATE TABLE #SalesOrders
(
    OrderID INT NOT NULL PRIMARY KEY,
    CustomerName NVARCHAR(80) NOT NULL,
    RegionCode CHAR(2) NOT NULL,
    OrderDate DATE NOT NULL,
    OrderAmount DECIMAL(10, 2) NOT NULL,
    ProductGroup VARCHAR(20) NOT NULL
);

CREATE TABLE #FilterPreview
(
    FilterName VARCHAR(30) NOT NULL,
    FilterExpression NVARCHAR(200) NOT NULL,
    StageName VARCHAR(20) NOT NULL,
    PushdownClass VARCHAR(20) NOT NULL,
    ActiveValue NVARCHAR(80) NULL,
    TeachingNote NVARCHAR(200) NOT NULL
);

CREATE TABLE #EarlyEvaluation
(
    OrderID INT NOT NULL PRIMARY KEY,
    CustomerName NVARCHAR(80) NOT NULL,
    RegionCode CHAR(2) NOT NULL,
    OrderDate DATE NOT NULL,
    OrderAmount DECIMAL(10, 2) NOT NULL,
    ProductGroup VARCHAR(20) NOT NULL,
    PassRegionFilter BIT NOT NULL,
    PassDateFilter BIT NOT NULL,
    PassAmountFilter BIT NOT NULL
);

CREATE TABLE #EarlyFiltered
(
    OrderID INT NOT NULL PRIMARY KEY,
    CustomerName NVARCHAR(80) NOT NULL,
    RegionCode CHAR(2) NOT NULL,
    OrderDate DATE NOT NULL,
    OrderAmount DECIMAL(10, 2) NOT NULL,
    ProductGroup VARCHAR(20) NOT NULL
);

CREATE TABLE #CustomerRevenue
(
    CustomerName NVARCHAR(80) NOT NULL PRIMARY KEY,
    CustomerRevenue DECIMAL(10, 2) NOT NULL,
    SurvivingOrderCount INT NOT NULL
);

CREATE TABLE #LateQualifiedCustomers
(
    CustomerName NVARCHAR(80) NOT NULL PRIMARY KEY,
    CustomerRevenue DECIMAL(10, 2) NOT NULL,
    SurvivingOrderCount INT NOT NULL
);

CREATE TABLE #CandidateFlow
(
    OrderID INT NOT NULL PRIMARY KEY,
    CustomerName NVARCHAR(80) NOT NULL,
    RegionCode CHAR(2) NOT NULL,
    OrderDate DATE NOT NULL,
    OrderAmount DECIMAL(10, 2) NOT NULL,
    ProductGroup VARCHAR(20) NOT NULL,
    PassRegionFilter BIT NOT NULL,
    PassDateFilter BIT NOT NULL,
    PassAmountFilter BIT NOT NULL,
    EarlyStageState VARCHAR(30) NOT NULL,
    LateStageState VARCHAR(30) NOT NULL,
    CustomerRevenue DECIMAL(10, 2) NULL,
    SurvivingOrderCount INT NULL,
    FlowOutcome VARCHAR(40) NOT NULL
);

INSERT INTO #SalesOrders
(
    OrderID,
    CustomerName,
    RegionCode,
    OrderDate,
    OrderAmount,
    ProductGroup
)
VALUES
    (3001, N'Alpenmarkt GmbH', 'DE', '2026-01-12', 80.00, 'Starter'),
    (3002, N'Alpenmarkt GmbH', 'DE', '2026-02-14', 140.00, 'Plus'),
    (3003, N'Alpenmarkt GmbH', 'DE', '2026-03-08', 160.00, 'Plus'),
    (3004, N'Bergblick AG', 'AT', '2026-02-03', 220.00, 'Enterprise'),
    (3005, N'Bergblick AG', 'AT', '2026-03-01', 90.00, 'Starter'),
    (3006, N'City Office KG', 'DE', '2026-02-09', 110.00, 'Starter'),
    (3007, N'City Office KG', 'DE', '2026-02-27', 70.00, 'Starter'),
    (3008, N'Delta Handel SA', 'CH', '2026-02-18', 310.00, 'Enterprise'),
    (3009, N'Elbe Service GmbH', 'DE', '2026-03-05', 205.00, 'Enterprise'),
    (3010, N'Elbe Service GmbH', 'DE', '2026-03-17', 175.00, 'Plus');

INSERT INTO #FilterPreview
(
    FilterName,
    FilterExpression,
    StageName,
    PushdownClass,
    ActiveValue,
    TeachingNote
)
VALUES
    (
        'RegionCode',
        N'RegionCode = @RegionCode',
        'base-row',
        'early',
        CAST(@RegionCode AS NVARCHAR(80)),
        N'Filtert direkt auf einer Spalte der Basiszeile und kann vor der Aggregation greifen.'
    ),
    (
        'MinOrderDate',
        N'OrderDate >= @MinOrderDate',
        'base-row',
        'early',
        CONVERT(NVARCHAR(80), @MinOrderDate, 23),
        N'Filtert einzelne Auftraege frueh ueber das Bestelldatum.'
    ),
    (
        'MinOrderAmount',
        N'OrderAmount >= @MinOrderAmount',
        'base-row',
        'early',
        CAST(@MinOrderAmount AS NVARCHAR(80)),
        N'Entfernt zu kleine Einzelauftraege bereits vor spaeteren Berechnungen.'
    ),
    (
        'MinCustomerRevenue',
        N'SUM(OrderAmount) >= @MinCustomerRevenue',
        'post-aggregate',
        'late',
        CAST(@MinCustomerRevenue AS NVARCHAR(80)),
        N'Ist erst nach GROUP BY sichtbar und kann deshalb nicht auf die einzelne Basiszeile gepusht werden.'
    );

INSERT INTO #EarlyEvaluation
(
    OrderID,
    CustomerName,
    RegionCode,
    OrderDate,
    OrderAmount,
    ProductGroup,
    PassRegionFilter,
    PassDateFilter,
    PassAmountFilter
)
SELECT
    so.OrderID,
    so.CustomerName,
    so.RegionCode,
    so.OrderDate,
    so.OrderAmount,
    so.ProductGroup,
    CASE WHEN @RegionCode IS NULL OR so.RegionCode = @RegionCode THEN 1 ELSE 0 END,
    CASE WHEN @MinOrderDate IS NULL OR so.OrderDate >= @MinOrderDate THEN 1 ELSE 0 END,
    CASE WHEN @MinOrderAmount IS NULL OR so.OrderAmount >= @MinOrderAmount THEN 1 ELSE 0 END
FROM #SalesOrders AS so;

INSERT INTO #EarlyFiltered
(
    OrderID,
    CustomerName,
    RegionCode,
    OrderDate,
    OrderAmount,
    ProductGroup
)
SELECT
    ee.OrderID,
    ee.CustomerName,
    ee.RegionCode,
    ee.OrderDate,
    ee.OrderAmount,
    ee.ProductGroup
FROM #EarlyEvaluation AS ee
WHERE ee.PassRegionFilter = 1
  AND ee.PassDateFilter = 1
  AND ee.PassAmountFilter = 1;

INSERT INTO #CustomerRevenue
(
    CustomerName,
    CustomerRevenue,
    SurvivingOrderCount
)
SELECT
    ef.CustomerName,
    SUM(ef.OrderAmount) AS CustomerRevenue,
    COUNT(*) AS SurvivingOrderCount
FROM #EarlyFiltered AS ef
GROUP BY
    ef.CustomerName;

INSERT INTO #LateQualifiedCustomers
(
    CustomerName,
    CustomerRevenue,
    SurvivingOrderCount
)
SELECT
    ef.CustomerName,
    SUM(ef.OrderAmount) AS CustomerRevenue,
    COUNT(*) AS SurvivingOrderCount
FROM #EarlyFiltered AS ef
GROUP BY
    ef.CustomerName
HAVING @MinCustomerRevenue IS NULL
    OR SUM(ef.OrderAmount) >= @MinCustomerRevenue;

INSERT INTO #CandidateFlow
(
    OrderID,
    CustomerName,
    RegionCode,
    OrderDate,
    OrderAmount,
    ProductGroup,
    PassRegionFilter,
    PassDateFilter,
    PassAmountFilter,
    EarlyStageState,
    LateStageState,
    CustomerRevenue,
    SurvivingOrderCount,
    FlowOutcome
)
SELECT
    ee.OrderID,
    ee.CustomerName,
    ee.RegionCode,
    ee.OrderDate,
    ee.OrderAmount,
    ee.ProductGroup,
    ee.PassRegionFilter,
    ee.PassDateFilter,
    ee.PassAmountFilter,
    CASE
        WHEN ee.PassRegionFilter = 1
         AND ee.PassDateFilter = 1
         AND ee.PassAmountFilter = 1
            THEN 'early-stage-passed'
        ELSE 'early-stage-removed'
    END AS EarlyStageState,
    CASE
        WHEN ee.PassRegionFilter = 1
         AND ee.PassDateFilter = 1
         AND ee.PassAmountFilter = 1
         AND lqc.CustomerName IS NOT NULL
            THEN 'late-stage-passed'
        WHEN ee.PassRegionFilter = 1
         AND ee.PassDateFilter = 1
         AND ee.PassAmountFilter = 1
            THEN 'late-stage-removed'
        ELSE 'not-reached'
    END AS LateStageState,
    cr.CustomerRevenue,
    cr.SurvivingOrderCount,
    CASE
        WHEN ee.PassRegionFilter = 0 THEN 'removed-by-region'
        WHEN ee.PassDateFilter = 0 THEN 'removed-by-date'
        WHEN ee.PassAmountFilter = 0 THEN 'removed-by-order-amount'
        WHEN lqc.CustomerName IS NULL THEN 'removed-by-customer-revenue'
        ELSE 'survives-all-filters'
    END AS FlowOutcome
FROM #EarlyEvaluation AS ee
LEFT JOIN #CustomerRevenue AS cr
    ON cr.CustomerName = ee.CustomerName
LEFT JOIN #LateQualifiedCustomers AS lqc
    ON lqc.CustomerName = ee.CustomerName;

SELECT
    fp.FilterName,
    fp.FilterExpression,
    fp.StageName,
    fp.PushdownClass,
    fp.ActiveValue,
    fp.TeachingNote
FROM #FilterPreview AS fp
ORDER BY
    CASE fp.PushdownClass WHEN 'early' THEN 1 ELSE 2 END,
    fp.FilterName;

SELECT
    cf.OrderID,
    cf.CustomerName,
    cf.RegionCode,
    cf.OrderDate,
    cf.OrderAmount,
    cf.ProductGroup,
    cf.PassRegionFilter,
    cf.PassDateFilter,
    cf.PassAmountFilter,
    cf.EarlyStageState,
    cf.LateStageState,
    cf.CustomerRevenue,
    cf.SurvivingOrderCount,
    cf.FlowOutcome
FROM #CandidateFlow AS cf
ORDER BY
    cf.OrderID;

SELECT
    summary.StageName,
    summary.RowCount,
    summary.CustomerCount,
    summary.Explanation
FROM
(
    SELECT
        'base-input' AS StageName,
        COUNT(*) AS RowCount,
        COUNT(DISTINCT bo.CustomerName) AS CustomerCount,
        'Alle Basiszeilen vor jedem Filter.' AS Explanation
    FROM #SalesOrders AS bo

    UNION ALL

    SELECT
        'after-early-filters' AS StageName,
        COUNT(*) AS RowCount,
        COUNT(DISTINCT ef.CustomerName) AS CustomerCount,
        'Nur Zeilen, die direkt auf Basiswerten gefiltert werden konnten.' AS Explanation
    FROM #EarlyFiltered AS ef

    UNION ALL

    SELECT
        'after-late-filter' AS StageName,
        COUNT(*) AS RowCount,
        COUNT(DISTINCT ef.CustomerName) AS CustomerCount,
        'Nur Zeilen von Kunden, deren aggregierter Umsatz den spaeten Filter besteht.' AS Explanation
    FROM #EarlyFiltered AS ef
    INNER JOIN #LateQualifiedCustomers AS lqc
        ON lqc.CustomerName = ef.CustomerName
) AS summary
ORDER BY
    CASE summary.StageName
        WHEN 'base-input' THEN 1
        WHEN 'after-early-filters' THEN 2
        ELSE 3
    END;
