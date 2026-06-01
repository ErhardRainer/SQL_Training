/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "JoinSelectivityEstimator.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "03_JOIN"
purpose: >
  Schaetzt die Selektivitaet typischer Join-Pfade ueber Rowcounts,
  Distinct-Werte und beobachtete Trefferraten auf einer kleinen Demobasis.
parameters:
  - name: "@OnlyRiskyPaths"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = nur Pfade mit Coverage- oder Fanout-Risiko anzeigen"
  - name: "@MinActualMatchesPerLeftRow"
    sql_type: "DECIMAL(10,2)"
    direction: "IN"
    required: false
    description: "Untergrenze fuer beobachtete Treffer pro linker Zeile"
  - name: "@IncludeSampleRows"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zusaetzliche Beispieldaten pro Join-Pfad ausgeben"
result_sets:
  - name: "JoinPathEstimate"
    description: "Kennzahlen je Join-Pfad mit Distinct-Keys, Coverage und Fanout"
  - name: "JoinSelectivitySignals"
    description: "Didaktische Review-Signale aus den Join-Kennzahlen"
  - name: "JoinSampleRows"
    description: "Optionale Beispieldaten fuer Lookup-Luecken und Mehrfachtreffer"
dependencies:
  - "tempdb"
  - "temp tables"
  - "CTE"
  - "LEFT JOIN"
  - "GROUP BY"
  - "COUNT DISTINCT"
  - "CASE"
safety:
  level: "read-only-tempdb"
  writes_data: false
documentation:
  markdown_file: "T-SQL/03_JOIN/SQLScripts/JoinSelectivityEstimator.md"
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
    description: "Erstversion fuer eine didaktische Schaetzung von Join-Selektivitaet"
notes:
  - "Die Demo kombiniert stabile Lookups, 1:n-Pfade und einen fanout-starken Prozesspfad."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @OnlyRiskyPaths BIT = 0;
DECLARE @MinActualMatchesPerLeftRow DECIMAL(10,2) = 0.00;
DECLARE @IncludeSampleRows BIT = 1;

IF @OnlyRiskyPaths NOT IN (0, 1) THROW 50000, '@OnlyRiskyPaths muss 0 oder 1 sein.', 1;
IF @MinActualMatchesPerLeftRow IS NULL OR @MinActualMatchesPerLeftRow < 0 THROW 50001, '@MinActualMatchesPerLeftRow muss 0 oder groesser sein.', 1;
IF @IncludeSampleRows NOT IN (0, 1) THROW 50002, '@IncludeSampleRows muss 0 oder 1 sein.', 1;

DROP TABLE IF EXISTS #Customers;
DROP TABLE IF EXISTS #Orders;
DROP TABLE IF EXISTS #OrderLines;
DROP TABLE IF EXISTS #Events;

CREATE TABLE #Customers (CustomerID INT PRIMARY KEY, CustomerName NVARCHAR(100), RegionCode NVARCHAR(20));
CREATE TABLE #Orders (OrderID INT PRIMARY KEY, CustomerID INT NOT NULL, SalesChannel NVARCHAR(30), OrderDate DATE);
CREATE TABLE #OrderLines (OrderID INT NOT NULL, LineNo INT NOT NULL, ProductFamily NVARCHAR(30), NetAmount DECIMAL(10,2), CONSTRAINT PK_OrderLines PRIMARY KEY (OrderID, LineNo));
CREATE TABLE #Events (EventID INT PRIMARY KEY, OrderID INT NOT NULL, LineNo INT NOT NULL, EventType NVARCHAR(30));

INSERT INTO #Customers VALUES
    (1, N'Aster Bikes', N'NORTH'), (2, N'Blue Harbor Retail', N'NORTH'), (3, N'Cedar Labs', N'SOUTH'), (4, N'Delta Outfitters', N'WEST');
INSERT INTO #Orders VALUES
    (1001, 1, N'Portal', '2026-04-01'), (1002, 1, N'Portal', '2026-04-02'), (1003, 2, N'SalesDesk', '2026-04-02'),
    (1004, 3, N'Marketplace', '2026-04-03'), (1005, 4, N'Marketplace', '2026-04-03'), (1006, 99, N'PartnerAPI', '2026-04-04');
INSERT INTO #OrderLines VALUES
    (1001, 1, N'Bike', 400.00), (1001, 2, N'Accessory', 25.00), (1002, 1, N'Accessory', 40.00),
    (1002, 2, N'Service', 90.00), (1003, 1, N'Bike', 650.00), (1004, 1, N'Bike', 510.00),
    (1004, 2, N'Service', 120.00), (1005, 1, N'Accessory', 54.00), (1006, 1, N'Service', 210.00);
INSERT INTO #Events VALUES
    (1, 1001, 1, N'picking'), (2, 1001, 1, N'packing'), (3, 1001, 1, N'label'),
    (4, 1001, 2, N'picking'), (5, 1002, 1, N'picking'), (6, 1002, 1, N'packing'),
    (7, 1002, 1, N'label'), (8, 1002, 1, N'handover'), (9, 1003, 1, N'picking'),
    (10, 1004, 1, N'picking'), (11, 1004, 1, N'packing'), (12, 1004, 1, N'label'),
    (13, 1004, 2, N'picking'), (14, 1005, 1, N'picking'), (15, 1005, 1, N'packing'),
    (16, 1005, 1, N'label'), (17, 1005, 1, N'carrier-scan');

;WITH PathCatalog AS
(
    SELECT 1 AS PathID, N'OrdersToCustomers' AS PathName, N'Orders' AS LeftEntity, N'Customers' AS RightEntity, N'CustomerID' AS JoinKeyLabel, N'n_to_1_lookup' AS JoinPattern, N'Lookup-Coverage und fehlende Stammdatentreffer pruefen.' AS TeachingQuestion
    UNION ALL SELECT 2, N'OrdersToOrderLines', N'Orders', N'OrderLines', N'OrderID', N'1_to_n_expansion', N'Wie stark expandiert eine Order in Positionen?'
    UNION ALL SELECT 3, N'OrderLinesToEvents', N'OrderLines', N'Events', N'OrderID + LineNo', N'1_to_n_process', N'Wie viele technische Ereignisse haengen an einer fachlichen Position?'
    UNION ALL SELECT 4, N'CustomersToOrders', N'Customers', N'Orders', N'CustomerID', N'1_to_n_account', N'Wie stark expandiert ein Kunde in Orders?'
),
Metrics AS
(
    SELECT
        1 AS PathID,
        (SELECT COUNT(*) FROM #Orders) AS LeftRowCount,
        (SELECT COUNT(*) FROM #Customers) AS RightRowCount,
        (SELECT COUNT(DISTINCT CustomerID) FROM #Orders) AS LeftDistinctKeys,
        (SELECT COUNT(DISTINCT CustomerID) FROM #Customers) AS RightDistinctKeys,
        (SELECT COUNT(DISTINCT o.CustomerID) FROM #Orders AS o INNER JOIN #Customers AS c ON c.CustomerID = o.CustomerID) AS SharedDistinctKeys,
        (SELECT COUNT(*) FROM #Orders AS o LEFT JOIN #Customers AS c ON c.CustomerID = o.CustomerID WHERE c.CustomerID IS NOT NULL) AS MatchingLeftRows,
        (SELECT COUNT(*) FROM #Orders AS o LEFT JOIN #Customers AS c ON c.CustomerID = o.CustomerID WHERE c.CustomerID IS NULL) AS LeftRowsWithoutMatch,
        (SELECT COUNT(*) FROM #Orders AS o LEFT JOIN #Customers AS c ON c.CustomerID = o.CustomerID) AS JoinedRowCount,
        1 AS MaxMatchesPerLeftRow
    UNION ALL
    SELECT
        2,
        (SELECT COUNT(*) FROM #Orders),
        (SELECT COUNT(*) FROM #OrderLines),
        (SELECT COUNT(DISTINCT OrderID) FROM #Orders),
        (SELECT COUNT(DISTINCT OrderID) FROM #OrderLines),
        (SELECT COUNT(DISTINCT o.OrderID) FROM #Orders AS o INNER JOIN #OrderLines AS ol ON ol.OrderID = o.OrderID),
        (SELECT COUNT(*) FROM (SELECT o.OrderID FROM #Orders AS o LEFT JOIN #OrderLines AS ol ON ol.OrderID = o.OrderID GROUP BY o.OrderID HAVING COUNT(ol.LineNo) > 0) AS x),
        (SELECT COUNT(*) FROM (SELECT o.OrderID FROM #Orders AS o LEFT JOIN #OrderLines AS ol ON ol.OrderID = o.OrderID GROUP BY o.OrderID HAVING COUNT(ol.LineNo) = 0) AS x),
        (SELECT COUNT(*) FROM #Orders AS o LEFT JOIN #OrderLines AS ol ON ol.OrderID = o.OrderID WHERE ol.LineNo IS NOT NULL),
        (SELECT MAX(MatchCount) FROM (SELECT COUNT(ol.LineNo) AS MatchCount FROM #Orders AS o LEFT JOIN #OrderLines AS ol ON ol.OrderID = o.OrderID GROUP BY o.OrderID) AS x)
    UNION ALL
    SELECT
        3,
        (SELECT COUNT(*) FROM #OrderLines),
        (SELECT COUNT(*) FROM #Events),
        (SELECT COUNT(*) FROM #OrderLines),
        (SELECT COUNT(DISTINCT CONCAT(CAST(OrderID AS VARCHAR(20)), ':', CAST(LineNo AS VARCHAR(20)))) FROM #Events),
        (SELECT COUNT(*) FROM #OrderLines AS ol INNER JOIN (SELECT DISTINCT OrderID, LineNo FROM #Events) AS e ON e.OrderID = ol.OrderID AND e.LineNo = ol.LineNo),
        (SELECT COUNT(*) FROM (SELECT ol.OrderID, ol.LineNo FROM #OrderLines AS ol LEFT JOIN #Events AS e ON e.OrderID = ol.OrderID AND e.LineNo = ol.LineNo GROUP BY ol.OrderID, ol.LineNo HAVING COUNT(e.EventID) > 0) AS x),
        (SELECT COUNT(*) FROM (SELECT ol.OrderID, ol.LineNo FROM #OrderLines AS ol LEFT JOIN #Events AS e ON e.OrderID = ol.OrderID AND e.LineNo = ol.LineNo GROUP BY ol.OrderID, ol.LineNo HAVING COUNT(e.EventID) = 0) AS x),
        (SELECT COUNT(*) FROM #OrderLines AS ol LEFT JOIN #Events AS e ON e.OrderID = ol.OrderID AND e.LineNo = ol.LineNo WHERE e.EventID IS NOT NULL),
        (SELECT MAX(MatchCount) FROM (SELECT COUNT(e.EventID) AS MatchCount FROM #OrderLines AS ol LEFT JOIN #Events AS e ON e.OrderID = ol.OrderID AND e.LineNo = ol.LineNo GROUP BY ol.OrderID, ol.LineNo) AS x)
    UNION ALL
    SELECT
        4,
        (SELECT COUNT(*) FROM #Customers),
        (SELECT COUNT(*) FROM #Orders),
        (SELECT COUNT(DISTINCT CustomerID) FROM #Customers),
        (SELECT COUNT(DISTINCT CustomerID) FROM #Orders),
        (SELECT COUNT(DISTINCT c.CustomerID) FROM #Customers AS c INNER JOIN #Orders AS o ON o.CustomerID = c.CustomerID),
        (SELECT COUNT(*) FROM (SELECT c.CustomerID FROM #Customers AS c LEFT JOIN #Orders AS o ON o.CustomerID = c.CustomerID GROUP BY c.CustomerID HAVING COUNT(o.OrderID) > 0) AS x),
        (SELECT COUNT(*) FROM (SELECT c.CustomerID FROM #Customers AS c LEFT JOIN #Orders AS o ON o.CustomerID = c.CustomerID GROUP BY c.CustomerID HAVING COUNT(o.OrderID) = 0) AS x),
        (SELECT COUNT(*) FROM #Customers AS c LEFT JOIN #Orders AS o ON o.CustomerID = c.CustomerID WHERE o.OrderID IS NOT NULL),
        (SELECT MAX(MatchCount) FROM (SELECT COUNT(o.OrderID) AS MatchCount FROM #Customers AS c LEFT JOIN #Orders AS o ON o.CustomerID = c.CustomerID GROUP BY c.CustomerID) AS x)
)
SELECT
    pc.PathName,
    pc.LeftEntity,
    pc.RightEntity,
    pc.JoinKeyLabel,
    pc.JoinPattern,
    m.LeftRowCount,
    m.RightRowCount,
    m.LeftDistinctKeys,
    m.RightDistinctKeys,
    m.SharedDistinctKeys,
    m.MatchingLeftRows,
    m.LeftRowsWithoutMatch,
    m.JoinedRowCount,
    CAST(m.RightRowCount AS DECIMAL(10,2)) / NULLIF(CAST(m.RightDistinctKeys AS DECIMAL(10,2)), 0) AS EstimatedMatchesPerLeftRow,
    CAST(m.JoinedRowCount AS DECIMAL(10,2)) / NULLIF(CAST(m.LeftRowCount AS DECIMAL(10,2)), 0) AS ActualMatchesPerLeftRow,
    CAST(100.0 * m.MatchingLeftRows AS DECIMAL(10,2)) / NULLIF(CAST(m.LeftRowCount AS DECIMAL(10,2)), 0) AS MatchCoveragePct,
    m.MaxMatchesPerLeftRow,
    CASE WHEN CAST(m.JoinedRowCount AS DECIMAL(10,2)) / NULLIF(CAST(m.LeftRowCount AS DECIMAL(10,2)), 0) >= 3 THEN N'high_fanout' WHEN m.LeftRowsWithoutMatch > 0 THEN N'partial_match' WHEN m.MaxMatchesPerLeftRow >= 2 THEN N'medium_fanout' ELSE N'stable_lookup' END AS SelectivityBand,
    CASE WHEN m.LeftRowsWithoutMatch > 0 AND m.MaxMatchesPerLeftRow >= 3 THEN N'coverage_and_fanout' WHEN m.LeftRowsWithoutMatch > 0 THEN N'coverage_gap' WHEN m.MaxMatchesPerLeftRow >= 3 THEN N'fanout_hotspot' WHEN m.MaxMatchesPerLeftRow = 2 THEN N'elevated_multiplicity' ELSE N'low_risk' END AS RiskSignal
INTO #PathEstimate
FROM PathCatalog AS pc
INNER JOIN Metrics AS m ON m.PathID = pc.PathID;

SELECT *
FROM #PathEstimate
WHERE ActualMatchesPerLeftRow >= @MinActualMatchesPerLeftRow
  AND (@OnlyRiskyPaths = 0 OR RiskSignal <> N'low_risk')
ORDER BY ActualMatchesPerLeftRow DESC, PathName;

SELECT
    pe.PathName,
    pe.SelectivityBand,
    pe.RiskSignal,
    CASE WHEN pe.RiskSignal = N'coverage_and_fanout' THEN N'Pfad kombiniert fehlende Treffer mit hoher Mehrfachheit.' WHEN pe.RiskSignal = N'coverage_gap' THEN N'Pfad hat linke Zeilen ohne Match.' WHEN pe.RiskSignal = N'fanout_hotspot' THEN N'Pfad expandiert stark und braucht vor Aggregationen besondere Vorsicht.' WHEN pe.RiskSignal = N'elevated_multiplicity' THEN N'Pfad ist kontrolliert, aber bereits kein reiner Lookup mehr.' ELSE N'Pfad wirkt in der Demo stabil.' END AS ReviewSignal,
    CASE WHEN pe.ActualMatchesPerLeftRow > pe.EstimatedMatchesPerLeftRow + 0.50 THEN N'Beobachtete Mehrfachheit liegt ueber der Distinct-Schaetzung.' WHEN pe.ActualMatchesPerLeftRow + 0.50 < pe.EstimatedMatchesPerLeftRow THEN N'Distinct-Schaetzung ist bewusst konservativ.' ELSE N'Schaetzung und Beobachtung liegen didaktisch nah beieinander.' END AS EstimationComment
FROM #PathEstimate AS pe
WHERE pe.ActualMatchesPerLeftRow >= @MinActualMatchesPerLeftRow
  AND (@OnlyRiskyPaths = 0 OR pe.RiskSignal <> N'low_risk')
ORDER BY pe.PathName;

IF @IncludeSampleRows = 1
BEGIN
    ;WITH Samples AS
    (
        SELECT N'OrdersToCustomers' AS PathName, CAST(o.OrderID AS NVARCHAR(30)) AS LeftRowRef, CAST(o.CustomerID AS NVARCHAR(30)) AS JoinKeyValue, ISNULL(c.CustomerName, N'<missing>') AS RightRowRef, CASE WHEN c.CustomerID IS NULL THEN N'left_without_match' ELSE N'lookup_match' END AS MatchSignal FROM #Orders AS o LEFT JOIN #Customers AS c ON c.CustomerID = o.CustomerID
        UNION ALL
        SELECT N'OrdersToOrderLines', CAST(o.OrderID AS NVARCHAR(30)), CAST(o.OrderID AS NVARCHAR(30)), ISNULL(CONCAT(CAST(ol.OrderID AS NVARCHAR(30)), N':', CAST(ol.LineNo AS NVARCHAR(30))), N'<missing>'), CASE WHEN ol.LineNo IS NULL THEN N'left_without_match' ELSE N'fanout_match' END FROM #Orders AS o LEFT JOIN #OrderLines AS ol ON ol.OrderID = o.OrderID
        UNION ALL
        SELECT N'OrderLinesToEvents', CONCAT(CAST(ol.OrderID AS NVARCHAR(30)), N':', CAST(ol.LineNo AS NVARCHAR(30))), CONCAT(CAST(ol.OrderID AS NVARCHAR(30)), N':', CAST(ol.LineNo AS NVARCHAR(30))), ISNULL(CAST(e.EventID AS NVARCHAR(30)), N'<missing>'), CASE WHEN e.EventID IS NULL THEN N'left_without_match' ELSE N'fanout_match' END FROM #OrderLines AS ol LEFT JOIN #Events AS e ON e.OrderID = ol.OrderID AND e.LineNo = ol.LineNo
        UNION ALL
        SELECT N'CustomersToOrders', CAST(c.CustomerID AS NVARCHAR(30)), CAST(c.CustomerID AS NVARCHAR(30)), ISNULL(CAST(o.OrderID AS NVARCHAR(30)), N'<missing>'), CASE WHEN o.OrderID IS NULL THEN N'left_without_match' ELSE N'fanout_match' END FROM #Customers AS c LEFT JOIN #Orders AS o ON o.CustomerID = c.CustomerID
    )
    SELECT s.*
    FROM Samples AS s
    WHERE EXISTS
    (
        SELECT 1
        FROM #PathEstimate AS pe
        WHERE pe.PathName = s.PathName
          AND pe.ActualMatchesPerLeftRow >= @MinActualMatchesPerLeftRow
          AND (@OnlyRiskyPaths = 0 OR pe.RiskSignal <> N'low_risk')
    )
    ORDER BY s.PathName, s.LeftRowRef, s.RightRowRef;
END;
