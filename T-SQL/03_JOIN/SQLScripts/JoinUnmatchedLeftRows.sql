/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "JoinUnmatchedLeftRows.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "03_JOIN"
purpose: >
  Zeigt gezielt die linksseitig nicht gematchten Zeilen einer LEFT-JOIN-Beziehung
  auf einer kleinen tempdb-Demobasis und kontrastiert sie mit einer kompakten
  Match-Zusammenfassung.
parameters:
  - name: "@RegionFilter"
    sql_type: "NVARCHAR(20)"
    direction: "IN"
    required: false
    description: "Optionaler Filter auf die Region der linken Kundenseite"
  - name: "@MinOrderDate"
    sql_type: "DATE"
    direction: "IN"
    required: false
    description: "Untergrenze fuer Bestellungen auf der rechten Seite"
  - name: "@ShowMatchedComparison"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zusaetzlich die gematchten Zeilen der linken Seite ausgeben"
result_sets:
  - name: "LeftSourcePreview"
    description: "Vorschau der linken Kundenseite"
  - name: "UnmatchedLeftRows"
    description: "Linksseitige Zeilen ohne Match auf der rechten Bestellseite"
  - name: "MatchCoverageSummary"
    description: "Verdichtet gematchte und nicht gematchte Zeilen pro Region"
  - name: "MatchedLeftRows"
    description: "Optionale Vergleichsausgabe fuer linksseitige Zeilen mit mindestens einem Match"
dependencies:
  - "tempdb"
  - "temp tables"
  - "LEFT JOIN"
  - "IS NULL"
  - "GROUP BY"
  - "MIN"
  - "MAX"
safety:
  level: "read-only-tempdb"
  writes_data: false
documentation:
  markdown_file: "T-SQL/03_JOIN/SQLScripts/JoinUnmatchedLeftRows.md"
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
    description: "Erstversion fuer die didaktische Sicht auf linksseitig nicht gematchte Zeilen"
notes:
  - "Das Skript nutzt nur temp-Objekte und setzt keine produktiven Tabellen voraus."
  - "Nicht gematcht bedeutet hier: kein Bestelltreffer ab dem gefilterten Mindestdatum."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @RegionFilter NVARCHAR(20) = NULL;
DECLARE @MinOrderDate DATE = '2026-04-01';
DECLARE @ShowMatchedComparison BIT = 1;

IF @ShowMatchedComparison NOT IN (0, 1)
BEGIN
    THROW 50000, '@ShowMatchedComparison muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #Customers;
DROP TABLE IF EXISTS #Orders;
DROP TABLE IF EXISTS #ScopedCustomers;
DROP TABLE IF EXISTS #ScopedOrders;
DROP TABLE IF EXISTS #UnmatchedLeftRows;
DROP TABLE IF EXISTS #CustomerMatchStatus;
DROP TABLE IF EXISTS #MatchCoverageSummary;

CREATE TABLE #Customers
(
    CustomerID INT NOT NULL PRIMARY KEY,
    CustomerName NVARCHAR(100) NOT NULL,
    RegionCode NVARCHAR(20) NOT NULL,
    AccountManager NVARCHAR(50) NOT NULL,
    CustomerTier NVARCHAR(20) NOT NULL
);

CREATE TABLE #Orders
(
    OrderID INT NOT NULL PRIMARY KEY,
    CustomerID INT NOT NULL,
    OrderDate DATE NOT NULL,
    OrderAmount DECIMAL(10,2) NOT NULL,
    SalesChannel NVARCHAR(20) NOT NULL
);

INSERT INTO #Customers (CustomerID, CustomerName, RegionCode, AccountManager, CustomerTier)
VALUES
    (1, N'Alpenrad GmbH', N'DE-SOUTH', N'Anika', N'Gold'),
    (2, N'Baltic Bikes', N'DE-NORTH', N'Bora', N'Silver'),
    (3, N'City Couriers', N'AT-EAST', N'Cem', N'Gold'),
    (4, N'Delta Retail', N'AT-WEST', N'Dina', N'Bronze'),
    (5, N'Elbe Stores', N'DE-NORTH', N'Emir', N'Silver'),
    (6, N'Fjord Sports', N'CH-ZURICH', N'Fina', N'Gold');

INSERT INTO #Orders (OrderID, CustomerID, OrderDate, OrderAmount, SalesChannel)
VALUES
    (101, 1, '2026-04-01', 180.00, N'web'),
    (102, 1, '2026-04-05', 240.00, N'partner'),
    (103, 2, '2026-04-03', 110.00, N'store'),
    (104, 3, '2026-03-28', 95.00, N'web'),
    (105, 5, '2026-04-06', 140.00, N'partner'),
    (106, 5, '2026-04-09', 160.00, N'web');

SELECT
    c.CustomerID,
    c.CustomerName,
    c.RegionCode,
    c.AccountManager,
    c.CustomerTier
INTO #ScopedCustomers
FROM #Customers AS c
WHERE @RegionFilter IS NULL
   OR c.RegionCode = @RegionFilter;

SELECT
    o.OrderID,
    o.CustomerID,
    o.OrderDate,
    o.OrderAmount,
    o.SalesChannel
INTO #ScopedOrders
FROM #Orders AS o
WHERE @MinOrderDate IS NULL
   OR o.OrderDate >= @MinOrderDate;

SELECT
    sc.CustomerID,
    sc.CustomerName,
    sc.RegionCode,
    sc.AccountManager,
    sc.CustomerTier,
    'LEFT JOIN produced no row on the right side' AS JoinInterpretation
INTO #UnmatchedLeftRows
FROM #ScopedCustomers AS sc
LEFT JOIN #ScopedOrders AS so
    ON so.CustomerID = sc.CustomerID
WHERE so.OrderID IS NULL;

SELECT
    sc.CustomerID,
    sc.CustomerName,
    sc.RegionCode,
    CASE WHEN COUNT(so.OrderID) = 0 THEN 0 ELSE 1 END AS HasMatch,
    COUNT(so.OrderID) AS MatchingOrderCount,
    MIN(so.OrderDate) AS EarliestMatchedOrderDate,
    MAX(so.OrderDate) AS LatestMatchedOrderDate
INTO #CustomerMatchStatus
FROM #ScopedCustomers AS sc
LEFT JOIN #ScopedOrders AS so
    ON so.CustomerID = sc.CustomerID
GROUP BY
    sc.CustomerID,
    sc.CustomerName,
    sc.RegionCode;

SELECT
    cms.RegionCode,
    COUNT(*) AS LeftRowCount,
    SUM(CASE WHEN cms.HasMatch = 0 THEN 1 ELSE 0 END) AS UnmatchedLeftCount,
    SUM(CASE WHEN cms.HasMatch = 1 THEN 1 ELSE 0 END) AS MatchedLeftCount,
    MIN(cms.EarliestMatchedOrderDate) AS EarliestMatchedOrderDate,
    MAX(cms.LatestMatchedOrderDate) AS LatestMatchedOrderDate
INTO #MatchCoverageSummary
FROM #CustomerMatchStatus AS cms
GROUP BY
    cms.RegionCode;

SELECT
    sc.CustomerID,
    sc.CustomerName,
    sc.RegionCode,
    sc.AccountManager,
    sc.CustomerTier
FROM #ScopedCustomers AS sc
ORDER BY
    sc.RegionCode,
    sc.CustomerID;

SELECT
    ulr.CustomerID,
    ulr.CustomerName,
    ulr.RegionCode,
    ulr.AccountManager,
    ulr.CustomerTier,
    ulr.JoinInterpretation
FROM #UnmatchedLeftRows AS ulr
ORDER BY
    ulr.RegionCode,
    ulr.CustomerID;

SELECT
    mcs.RegionCode,
    mcs.LeftRowCount,
    mcs.UnmatchedLeftCount,
    mcs.MatchedLeftCount,
    mcs.EarliestMatchedOrderDate,
    mcs.LatestMatchedOrderDate
FROM #MatchCoverageSummary AS mcs
ORDER BY
    mcs.UnmatchedLeftCount DESC,
    mcs.RegionCode;

IF @ShowMatchedComparison = 1
BEGIN
    SELECT
        sc.CustomerID,
        sc.CustomerName,
        sc.RegionCode,
        COUNT(*) AS MatchingOrderCount,
        MIN(so.OrderDate) AS FirstMatchedOrderDate,
        MAX(so.OrderDate) AS LastMatchedOrderDate
    FROM #ScopedCustomers AS sc
    INNER JOIN #ScopedOrders AS so
        ON so.CustomerID = sc.CustomerID
    GROUP BY
        sc.CustomerID,
        sc.CustomerName,
        sc.RegionCode
    ORDER BY
        sc.RegionCode,
        sc.CustomerID;
END;
