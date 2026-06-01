/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "JoinSurvivorRowPreview.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "03_JOIN"
purpose: >
  Zeigt anhand eines mehrstufigen Demo-Joins, welche Bestellzeilen nach
  Status-, Rechnungs-, Versand- und Rueckgabepruefungen als echte
  Survivor Rows uebrig bleiben und an welcher Stufe andere Zeilen
  herausfallen.
parameters:
  - name: "@RegionFilter"
    sql_type: "NVARCHAR(20)"
    direction: "IN"
    required: false
    description: "Optionaler Filter auf eine Vertriebsregion"
  - name: "@MinimumInvoiceCoverage"
    sql_type: "DECIMAL(5,2)"
    direction: "IN"
    required: false
    description: "Untergrenze fuer die akzeptierte Rechnungsabdeckung je Bestellzeile"
  - name: "@IncludeExcludedRows"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zusaetzliches Resultset mit ausgeschlossenen Zeilen und Ausschlussgrund ausgeben"
result_sets:
  - name: "SurvivorRowPreview"
    description: "Zeigt nur die Bestellzeilen, die alle Join- und Filterstufen ueberstehen"
  - name: "JoinStepSummary"
    description: "Verdichtet, wie viele Zeilen nach jeder Pruefstufe verbleiben"
  - name: "ExcludedRowPreview"
    description: "Optionaler Blick auf ausgeschlossene Zeilen inklusive dominanter Ausschlussursache"
dependencies:
  - "tempdb"
  - "temp tables"
  - "CTE"
  - "INNER JOIN"
  - "LEFT JOIN"
  - "CASE"
  - "ROW_NUMBER"
safety:
  level: "read-only-tempdb"
  writes_data: false
documentation:
  markdown_file: "T-SQL/03_JOIN/SQLScripts/JoinSurvivorRowPreview.md"
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
    description: "Erstversion fuer die Vorschau auf Survivor Rows nach einem komplexen Join"
notes:
  - "Das Skript nutzt ausschliesslich temp-Objekte und didaktische Bestell-, Rechnungs- und Versanddaten."
  - "Survivor Rows sind hier Zeilen, die Status-, Rechnungs-, Versand- und Rueckgabepruefungen gemeinsam bestehen."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @RegionFilter NVARCHAR(20) = NULL;
DECLARE @MinimumInvoiceCoverage DECIMAL(5,2) = 95.00;
DECLARE @IncludeExcludedRows BIT = 1;

IF @MinimumInvoiceCoverage < 0 OR @MinimumInvoiceCoverage > 100
BEGIN
    THROW 50000, '@MinimumInvoiceCoverage muss zwischen 0 und 100 liegen.', 1;
END;

IF @IncludeExcludedRows NOT IN (0, 1)
BEGIN
    THROW 50000, '@IncludeExcludedRows muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #Customers;
DROP TABLE IF EXISTS #Orders;
DROP TABLE IF EXISTS #OrderLines;
DROP TABLE IF EXISTS #InvoiceCoverage;
DROP TABLE IF EXISTS #ShipmentMatches;
DROP TABLE IF EXISTS #ReturnFlags;
DROP TABLE IF EXISTS #BaseOrderLines;

CREATE TABLE #Customers
(
    CustomerID INT NOT NULL PRIMARY KEY,
    CustomerName NVARCHAR(100) NOT NULL,
    RegionCode NVARCHAR(20) NOT NULL,
    SegmentCode NVARCHAR(20) NOT NULL
);

CREATE TABLE #Orders
(
    OrderID INT NOT NULL PRIMARY KEY,
    CustomerID INT NOT NULL,
    OrderDate DATE NOT NULL,
    OrderStatus NVARCHAR(20) NOT NULL,
    SalesChannel NVARCHAR(30) NOT NULL
);

CREATE TABLE #OrderLines
(
    OrderID INT NOT NULL,
    LineNo INT NOT NULL,
    ProductFamily NVARCHAR(30) NOT NULL,
    Quantity INT NOT NULL,
    NetAmount DECIMAL(10,2) NOT NULL,
    CONSTRAINT PK_OrderLines PRIMARY KEY (OrderID, LineNo)
);

CREATE TABLE #InvoiceCoverage
(
    OrderID INT NOT NULL,
    LineNo INT NOT NULL,
    InvoiceStatus NVARCHAR(20) NOT NULL,
    CoveragePercent DECIMAL(5,2) NOT NULL,
    InvoiceDocumentNo NVARCHAR(30) NOT NULL,
    CONSTRAINT PK_InvoiceCoverage PRIMARY KEY (OrderID, LineNo)
);

CREATE TABLE #ShipmentMatches
(
    ShipmentMatchID INT NOT NULL PRIMARY KEY,
    OrderID INT NOT NULL,
    LineNo INT NOT NULL,
    ShipmentRole NVARCHAR(20) NOT NULL,
    TrackingStatus NVARCHAR(20) NOT NULL,
    HubCode NVARCHAR(20) NOT NULL
);

CREATE TABLE #ReturnFlags
(
    OrderID INT NOT NULL,
    LineNo INT NOT NULL,
    ReturnState NVARCHAR(20) NOT NULL,
    ResolutionNote NVARCHAR(100) NOT NULL,
    CONSTRAINT PK_ReturnFlags PRIMARY KEY (OrderID, LineNo)
);

INSERT INTO #Customers (CustomerID, CustomerName, RegionCode, SegmentCode)
VALUES
    (1, N'Aster Bikes', N'NORTH', N'B2B'),
    (2, N'Blue Harbor Retail', N'NORTH', N'Retail'),
    (3, N'Cedar Labs', N'SOUTH', N'Education'),
    (4, N'Delta Outfitters', N'WEST', N'Retail');

INSERT INTO #Orders (OrderID, CustomerID, OrderDate, OrderStatus, SalesChannel)
VALUES
    (1101, 1, '2026-04-01', N'Released', N'Portal'),
    (1102, 1, '2026-04-02', N'Released', N'Portal'),
    (1103, 2, '2026-04-02', N'Picking', N'SalesDesk'),
    (1104, 3, '2026-04-03', N'Released', N'Marketplace'),
    (1105, 4, '2026-04-03', N'Cancelled', N'Marketplace');

INSERT INTO #OrderLines (OrderID, LineNo, ProductFamily, Quantity, NetAmount)
VALUES
    (1101, 1, N'Bike', 2, 400.00),
    (1101, 2, N'Accessory', 1, 25.00),
    (1102, 1, N'Accessory', 4, 40.00),
    (1102, 2, N'Service', 1, 90.00),
    (1103, 1, N'Bike', 1, 650.00),
    (1103, 2, N'Accessory', 2, 36.00),
    (1104, 1, N'Bike', 1, 510.00),
    (1104, 2, N'Service', 1, 120.00),
    (1105, 1, N'Accessory', 3, 54.00);

INSERT INTO #InvoiceCoverage (OrderID, LineNo, InvoiceStatus, CoveragePercent, InvoiceDocumentNo)
VALUES
    (1101, 1, N'posted', 100.00, N'INV-1101-1'),
    (1101, 2, N'posted', 100.00, N'INV-1101-2'),
    (1102, 1, N'posted', 97.50, N'INV-1102-1'),
    (1102, 2, N'draft', 70.00, N'INV-1102-2'),
    (1103, 1, N'posted', 100.00, N'INV-1103-1'),
    (1103, 2, N'posted', 100.00, N'INV-1103-2'),
    (1104, 1, N'posted', 100.00, N'INV-1104-1'),
    (1104, 2, N'posted', 100.00, N'INV-1104-2'),
    (1105, 1, N'void', 0.00, N'INV-1105-1');

INSERT INTO #ShipmentMatches (ShipmentMatchID, OrderID, LineNo, ShipmentRole, TrackingStatus, HubCode)
VALUES
    (1, 1101, 1, N'primary', N'in-transit', N'HUB-N1'),
    (2, 1101, 1, N'audit', N'scanned', N'HUB-N1'),
    (3, 1101, 2, N'primary', N'delivered', N'HUB-N1'),
    (4, 1102, 1, N'primary', N'manifested', N'HUB-N2'),
    (5, 1102, 2, N'primary', N'pending', N'HUB-N2'),
    (6, 1103, 1, N'backup', N'in-transit', N'HUB-N3'),
    (7, 1103, 2, N'primary', N'in-transit', N'HUB-N3'),
    (8, 1104, 1, N'primary', N'delivered', N'HUB-S1'),
    (9, 1104, 2, N'primary', N'manifested', N'HUB-S1');

INSERT INTO #ReturnFlags (OrderID, LineNo, ReturnState, ResolutionNote)
VALUES
    (1101, 1, N'none', N'Keine Rueckgabe erfasst'),
    (1101, 2, N'none', N'Keine Rueckgabe erfasst'),
    (1102, 1, N'none', N'Keine Rueckgabe erfasst'),
    (1102, 2, N'none', N'Keine Rueckgabe erfasst'),
    (1103, 1, N'none', N'Keine Rueckgabe erfasst'),
    (1103, 2, N'pending', N'Retourenanfrage noch offen'),
    (1104, 1, N'closed', N'Retourenfall abgeschlossen'),
    (1104, 2, N'none', N'Keine Rueckgabe erfasst'),
    (1105, 1, N'none', N'Keine Rueckgabe erfasst');

SELECT
    c.RegionCode,
    c.SegmentCode,
    c.CustomerName,
    o.OrderID,
    o.OrderDate,
    o.OrderStatus,
    o.SalesChannel,
    ol.LineNo,
    ol.ProductFamily,
    ol.Quantity,
    ol.NetAmount
INTO #BaseOrderLines
FROM #OrderLines AS ol
INNER JOIN #Orders AS o
    ON o.OrderID = ol.OrderID
INNER JOIN #Customers AS c
    ON c.CustomerID = o.CustomerID
WHERE @RegionFilter IS NULL
   OR c.RegionCode = @RegionFilter;

;WITH PrimaryShipment AS
(
    SELECT
        sm.OrderID,
        sm.LineNo,
        sm.TrackingStatus,
        sm.HubCode,
        ROW_NUMBER() OVER
        (
            PARTITION BY sm.OrderID, sm.LineNo
            ORDER BY
                CASE sm.TrackingStatus
                    WHEN N'delivered' THEN 1
                    WHEN N'in-transit' THEN 2
                    WHEN N'manifested' THEN 3
                    ELSE 4
                END,
                sm.ShipmentMatchID
        ) AS ShipmentRank
    FROM #ShipmentMatches AS sm
    WHERE sm.ShipmentRole = N'primary'
),
ComplexJoinPreview AS
(
    SELECT
        bol.RegionCode,
        bol.SegmentCode,
        bol.CustomerName,
        bol.OrderID,
        bol.OrderDate,
        bol.OrderStatus,
        bol.SalesChannel,
        bol.LineNo,
        bol.ProductFamily,
        bol.Quantity,
        bol.NetAmount,
        ic.InvoiceStatus,
        ic.CoveragePercent,
        ic.InvoiceDocumentNo,
        ps.TrackingStatus,
        ps.HubCode,
        rf.ReturnState,
        rf.ResolutionNote,
        CASE
            WHEN bol.OrderStatus IN (N'Released', N'Shipped') THEN 1
            ELSE 0
        END AS PassOrderStatus,
        CASE
            WHEN ic.InvoiceStatus = N'posted'
             AND ic.CoveragePercent >= @MinimumInvoiceCoverage THEN 1
            ELSE 0
        END AS PassInvoiceCoverage,
        CASE
            WHEN ps.TrackingStatus IN (N'manifested', N'in-transit', N'delivered') THEN 1
            ELSE 0
        END AS PassShipment,
        CASE
            WHEN rf.ReturnState IN (N'none', N'closed') THEN 1
            ELSE 0
        END AS PassReturnState
    FROM #BaseOrderLines AS bol
    INNER JOIN #InvoiceCoverage AS ic
        ON ic.OrderID = bol.OrderID
       AND ic.LineNo = bol.LineNo
    LEFT JOIN PrimaryShipment AS ps
        ON ps.OrderID = bol.OrderID
       AND ps.LineNo = bol.LineNo
       AND ps.ShipmentRank = 1
    LEFT JOIN #ReturnFlags AS rf
        ON rf.OrderID = bol.OrderID
       AND rf.LineNo = bol.LineNo
),
SurvivorEvaluation AS
(
    SELECT
        cjp.RegionCode,
        cjp.SegmentCode,
        cjp.CustomerName,
        cjp.OrderID,
        cjp.OrderDate,
        cjp.OrderStatus,
        cjp.SalesChannel,
        cjp.LineNo,
        cjp.ProductFamily,
        cjp.Quantity,
        cjp.NetAmount,
        cjp.InvoiceStatus,
        cjp.CoveragePercent,
        cjp.InvoiceDocumentNo,
        cjp.TrackingStatus,
        cjp.HubCode,
        cjp.ReturnState,
        cjp.ResolutionNote,
        cjp.PassOrderStatus,
        cjp.PassInvoiceCoverage,
        cjp.PassShipment,
        cjp.PassReturnState,
        CASE
            WHEN cjp.PassOrderStatus = 1
             AND cjp.PassInvoiceCoverage = 1
             AND cjp.PassShipment = 1
             AND cjp.PassReturnState = 1 THEN 1
            ELSE 0
        END AS IsSurvivor,
        CASE
            WHEN cjp.PassOrderStatus = 0 THEN N'order-status-filter'
            WHEN cjp.PassInvoiceCoverage = 0 THEN N'invoice-coverage-filter'
            WHEN cjp.PassShipment = 0 THEN N'shipment-filter'
            WHEN cjp.PassReturnState = 0 THEN N'return-filter'
            ELSE N'survivor'
        END AS PrimaryOutcome,
        CONCAT(
            CASE WHEN cjp.PassOrderStatus = 1 THEN N'order-ok; ' ELSE N'order-stop; ' END,
            CASE WHEN cjp.PassInvoiceCoverage = 1 THEN N'invoice-ok; ' ELSE N'invoice-stop; ' END,
            CASE WHEN cjp.PassShipment = 1 THEN N'shipment-ok; ' ELSE N'shipment-stop; ' END,
            CASE WHEN cjp.PassReturnState = 1 THEN N'return-ok' ELSE N'return-stop' END
        ) AS EvaluationPath
    FROM ComplexJoinPreview AS cjp
)
,JoinStepSummary AS
(
    SELECT
        N'base-order-lines' AS StepName,
        COUNT(*) AS RowCount
    FROM #BaseOrderLines AS bol

    UNION ALL

    SELECT
        N'after-order-status' AS StepName,
        COUNT(*) AS RowCount
    FROM SurvivorEvaluation AS se
    WHERE se.PassOrderStatus = 1

    UNION ALL

    SELECT
        N'after-invoice-coverage' AS StepName,
        COUNT(*) AS RowCount
    FROM SurvivorEvaluation AS se
    WHERE se.PassOrderStatus = 1
      AND se.PassInvoiceCoverage = 1

    UNION ALL

    SELECT
        N'after-primary-shipment' AS StepName,
        COUNT(*) AS RowCount
    FROM SurvivorEvaluation AS se
    WHERE se.PassOrderStatus = 1
      AND se.PassInvoiceCoverage = 1
      AND se.PassShipment = 1

    UNION ALL

    SELECT
        N'after-return-check' AS StepName,
        COUNT(*) AS RowCount
    FROM SurvivorEvaluation AS se
    WHERE se.IsSurvivor = 1
)
SELECT
    se.RegionCode,
    se.SegmentCode,
    se.CustomerName,
    se.SalesChannel,
    se.OrderID,
    se.OrderDate,
    se.LineNo,
    se.ProductFamily,
    se.Quantity,
    se.NetAmount,
    se.InvoiceDocumentNo,
    se.InvoiceStatus,
    se.CoveragePercent,
    se.TrackingStatus,
    se.HubCode,
    se.ReturnState,
    se.PrimaryOutcome,
    se.EvaluationPath
FROM SurvivorEvaluation AS se
WHERE se.IsSurvivor = 1
ORDER BY
    se.RegionCode,
    se.CustomerName,
    se.OrderID,
    se.LineNo;

SELECT
    jss.StepName,
    jss.RowCount,
    LAG(jss.RowCount) OVER
    (
        ORDER BY
            CASE jss.StepName
                WHEN N'base-order-lines' THEN 1
                WHEN N'after-order-status' THEN 2
                WHEN N'after-invoice-coverage' THEN 3
                WHEN N'after-primary-shipment' THEN 4
                ELSE 5
            END
    ) AS PreviousStepRowCount,
    COALESCE
    (
        LAG(jss.RowCount) OVER
        (
            ORDER BY
                CASE jss.StepName
                    WHEN N'base-order-lines' THEN 1
                    WHEN N'after-order-status' THEN 2
                    WHEN N'after-invoice-coverage' THEN 3
                    WHEN N'after-primary-shipment' THEN 4
                    ELSE 5
                END
        ) - jss.RowCount,
        0
    ) AS RowsRemovedAtStep
FROM JoinStepSummary AS jss
ORDER BY
    CASE jss.StepName
        WHEN N'base-order-lines' THEN 1
        WHEN N'after-order-status' THEN 2
        WHEN N'after-invoice-coverage' THEN 3
        WHEN N'after-primary-shipment' THEN 4
        ELSE 5
    END;

IF @IncludeExcludedRows = 1
BEGIN
    SELECT
        se.RegionCode,
        se.SegmentCode,
        se.CustomerName,
        se.SalesChannel,
        se.OrderID,
        se.OrderDate,
        se.LineNo,
        se.ProductFamily,
        se.NetAmount,
        se.OrderStatus,
        se.InvoiceStatus,
        se.CoveragePercent,
        se.TrackingStatus,
        se.ReturnState,
        se.PrimaryOutcome,
        se.EvaluationPath,
        ROW_NUMBER() OVER
        (
            PARTITION BY se.PrimaryOutcome
            ORDER BY se.NetAmount DESC, se.OrderID, se.LineNo
        ) AS OutcomeRank
    FROM SurvivorEvaluation AS se
    WHERE se.IsSurvivor = 0
    ORDER BY
        se.PrimaryOutcome,
        se.NetAmount DESC,
        se.OrderID,
        se.LineNo;
END;
