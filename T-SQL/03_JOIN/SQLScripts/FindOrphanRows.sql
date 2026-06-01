/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "FindOrphanRows.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "03_JOIN"
purpose: >
  Findet verwaiste Kinddatensaetze auf einer kleinen Demobasis und
  kontrastiert die Muster LEFT JOIN ... IS NULL und NOT EXISTS fuer
  dieselbe Orphan-Suche.
parameters:
  - name: "@MinOrderDate"
    sql_type: "DATE"
    direction: "IN"
    required: false
    description: "Optionales Untergrenzen-Datum fuer die betrachteten Bestellungen"
  - name: "@MinimumOrderAmount"
    sql_type: "DECIMAL(10,2)"
    direction: "IN"
    required: false
    description: "Optionaler Mindestbetrag fuer die betrachteten Bestellungen"
  - name: "@IncludePatternComparison"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zusaetzliches Vergleichs-Resultset fuer beide Join-Muster ausgeben"
result_sets:
  - name: "OrphanRowsLeftJoin"
    description: "Verwaiste Bestellungen ueber LEFT JOIN ... IS NULL"
  - name: "OrphanRowsNotExists"
    description: "Verwaiste Bestellungen ueber NOT EXISTS"
  - name: "OrphanSummary"
    description: "Zusammenfassung der verwaisten und gueltigen Bestellungen je Vertriebskanal"
  - name: "PatternComparison"
    description: "Optionaler Abgleich, ob LEFT JOIN und NOT EXISTS dieselben Orphans liefern"
dependencies:
  - "tempdb"
  - "temp tables"
  - "LEFT JOIN"
  - "NOT EXISTS"
  - "FULL OUTER JOIN"
safety:
  level: "read-only-tempdb"
  writes_data: false
documentation:
  markdown_file: "T-SQL/03_JOIN/SQLScripts/FindOrphanRows.md"
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
    description: "Erstversion fuer die didaktische Orphan-Row-Suche mit LEFT JOIN und NOT EXISTS"
notes:
  - "Die Trainingsdaten bleiben auf temp-Objekte beschraenkt und modellieren keine produktiven Tabellen."
  - "Als verwaist gilt hier eine Bestellung mit CustomerID ohne passenden Stammdatensatz in #Customers."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @MinOrderDate DATE = '2026-04-01';
DECLARE @MinimumOrderAmount DECIMAL(10,2) = 0.00;
DECLARE @IncludePatternComparison BIT = 1;

IF @IncludePatternComparison NOT IN (0, 1)
BEGIN
    THROW 50000, '@IncludePatternComparison muss 0 oder 1 sein.', 1;
END;

IF @MinimumOrderAmount < 0
BEGIN
    THROW 50000, '@MinimumOrderAmount darf nicht negativ sein.', 1;
END;

DROP TABLE IF EXISTS #Customers;
DROP TABLE IF EXISTS #Orders;
DROP TABLE IF EXISTS #ScopedOrders;
DROP TABLE IF EXISTS #OrphansLeftJoin;
DROP TABLE IF EXISTS #OrphansNotExists;
DROP TABLE IF EXISTS #OrphanSummary;

CREATE TABLE #Customers
(
    CustomerID INT NOT NULL PRIMARY KEY,
    CustomerName NVARCHAR(100) NOT NULL,
    RegionCode NVARCHAR(20) NOT NULL,
    CustomerStatus NVARCHAR(20) NOT NULL
);

CREATE TABLE #Orders
(
    OrderID INT NOT NULL PRIMARY KEY,
    CustomerID INT NULL,
    SalesChannel NVARCHAR(20) NOT NULL,
    OrderAmount DECIMAL(10,2) NOT NULL,
    OrderDate DATE NOT NULL
);

INSERT INTO #Customers (CustomerID, CustomerName, RegionCode, CustomerStatus)
VALUES
    (1, N'Alpenrad GmbH', N'DE-SOUTH', N'active'),
    (2, N'Baltic Bikes', N'DE-NORTH', N'active'),
    (3, N'City Couriers', N'AT-EAST', N'active'),
    (4, N'Delta Retail', N'AT-WEST', N'inactive'),
    (5, N'Elbe Stores', N'DE-NORTH', N'active');

INSERT INTO #Orders (OrderID, CustomerID, SalesChannel, OrderAmount, OrderDate)
VALUES
    (1001, 1, N'web', 120.00, '2026-04-01'),
    (1002, 2, N'partner', 210.00, '2026-04-01'),
    (1003, 8, N'web', 95.00, '2026-04-02'),
    (1004, NULL, N'manual', 75.00, '2026-04-02'),
    (1005, 3, N'partner', 60.00, '2026-04-03'),
    (1006, 9, N'web', 160.00, '2026-04-04'),
    (1007, 4, N'store', 180.00, '2026-04-04'),
    (1008, 12, N'manual', 130.00, '2026-04-05');

SELECT
    o.OrderID,
    o.CustomerID,
    o.SalesChannel,
    o.OrderAmount,
    o.OrderDate
INTO #ScopedOrders
FROM #Orders AS o
WHERE (@MinOrderDate IS NULL OR o.OrderDate >= @MinOrderDate)
  AND o.OrderAmount >= @MinimumOrderAmount;

SELECT
    so.OrderID,
    so.CustomerID,
    so.SalesChannel,
    so.OrderAmount,
    so.OrderDate,
    'LEFT JOIN IS NULL' AS DetectionPattern,
    CASE
        WHEN so.CustomerID IS NULL THEN 'CustomerID is NULL'
        ELSE 'CustomerID has no matching customer master'
    END AS OrphanReason
INTO #OrphansLeftJoin
FROM #ScopedOrders AS so
LEFT JOIN #Customers AS c
    ON c.CustomerID = so.CustomerID
WHERE c.CustomerID IS NULL;

SELECT
    so.OrderID,
    so.CustomerID,
    so.SalesChannel,
    so.OrderAmount,
    so.OrderDate,
    'NOT EXISTS' AS DetectionPattern,
    CASE
        WHEN so.CustomerID IS NULL THEN 'CustomerID is NULL'
        ELSE 'CustomerID has no matching customer master'
    END AS OrphanReason
INTO #OrphansNotExists
FROM #ScopedOrders AS so
WHERE NOT EXISTS
(
    SELECT 1
    FROM #Customers AS c
    WHERE c.CustomerID = so.CustomerID
);

SELECT
    so.SalesChannel,
    COUNT(*) AS ScopedOrderCount,
    SUM(CASE WHEN EXISTS
        (
            SELECT 1
            FROM #Customers AS c
            WHERE c.CustomerID = so.CustomerID
        )
        THEN 0 ELSE 1 END) AS OrphanCount,
    SUM(CASE WHEN EXISTS
        (
            SELECT 1
            FROM #Customers AS c
            WHERE c.CustomerID = so.CustomerID
        )
        THEN 1 ELSE 0 END) AS MatchedCount
INTO #OrphanSummary
FROM #ScopedOrders AS so
GROUP BY
    so.SalesChannel;

SELECT
    olj.OrderID,
    olj.CustomerID,
    olj.SalesChannel,
    olj.OrderAmount,
    olj.OrderDate,
    olj.OrphanReason,
    olj.DetectionPattern
FROM #OrphansLeftJoin AS olj
ORDER BY
    olj.OrderDate,
    olj.OrderID;

SELECT
    oneg.OrderID,
    oneg.CustomerID,
    oneg.SalesChannel,
    oneg.OrderAmount,
    oneg.OrderDate,
    oneg.OrphanReason,
    oneg.DetectionPattern
FROM #OrphansNotExists AS oneg
ORDER BY
    oneg.OrderDate,
    oneg.OrderID;

SELECT
    os.SalesChannel,
    os.ScopedOrderCount,
    os.OrphanCount,
    os.MatchedCount,
    CAST(os.OrphanCount * 1.0 / NULLIF(os.ScopedOrderCount, 0) AS DECIMAL(5,2)) AS OrphanRate
FROM #OrphanSummary AS os
ORDER BY
    os.OrphanCount DESC,
    os.SalesChannel;

IF @IncludePatternComparison = 1
BEGIN
    SELECT
        COALESCE(olj.OrderID, oneg.OrderID) AS OrderID,
        CASE
            WHEN olj.OrderID IS NOT NULL AND oneg.OrderID IS NOT NULL THEN 'both patterns'
            WHEN olj.OrderID IS NOT NULL THEN 'LEFT JOIN only'
            ELSE 'NOT EXISTS only'
        END AS PresenceStatus
    FROM #OrphansLeftJoin AS olj
    FULL OUTER JOIN #OrphansNotExists AS oneg
        ON oneg.OrderID = olj.OrderID
    ORDER BY
        COALESCE(olj.OrderID, oneg.OrderID);
END;
