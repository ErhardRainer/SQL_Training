/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "DeleteImpactPreviewByKey.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "06_Delete"

purpose: >
  Zeigt fuer einen ausgewaehlten Geschaeftsschluessel, welche Eltern- und
  Kindzeilen von einem Delete fachlich oder technisch betroffen waeren, ohne
  die Demo-Daten tatsaechlich zu loeschen.

parameters:
  - name: "@CustomerID"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Demo-Kundenschluessel, fuer den die Delete-Auswirkungen betrachtet werden"
  - name: "@IncludeInactiveChildren"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 zeigt auch inaktive oder bereits archivierte Kindzeilen, 0 blendet sie aus"
  - name: "@PreviewMode"
    sql_type: "VARCHAR(20)"
    direction: "IN"
    required: false
    description: "Steuert, ob nur die Zusammenfassung oder auch Detailzeilen ausgegeben werden"

result_sets:
  - name: "DeleteKeyPreview"
    description: "Zeigt die Elternzeile samt Bewertungsstatus fuer den ausgewaehlten Schluessel"
  - name: "DeleteImpactSummary"
    description: "Verdichtet betroffene Kindtabellen, Loeschstrategie und Zeilenanzahl"
  - name: "DeleteImpactDetail"
    description: "Listet die konkreten Demo-Zeilen, die vom Delete betroffen oder zu pruefen waeren"
  - name: "ExecutionGuide"
    description: "Fasst Modus, Safety und didaktische Hinweise zur Delete-Vorschau zusammen"

dependencies:
  - "tempdb temporary tables"
  - "CTE"
  - "UNION ALL"
  - "GROUP BY"
  - "CASE"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/06_Delete/SQLScripts/DeleteImpactPreviewByKey.md"
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
    description: "Erstversion fuer eine didaktische Delete-Impact-Vorschau nach Schluessel"

notes:
  - "Alle Daten liegen nur in temporaeren Demo-Tabellen."
  - "Das Skript fuehrt kein DELETE aus und dient nur als sichere Vorschau."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @CustomerID INT = 102;
DECLARE @IncludeInactiveChildren BIT = 1;
DECLARE @PreviewMode VARCHAR(20) = 'detail';

IF @CustomerID IS NULL OR @CustomerID < 1
BEGIN
    THROW 50650, '@CustomerID muss groesser als 0 sein.', 1;
END;

IF @IncludeInactiveChildren NOT IN (0, 1)
BEGIN
    THROW 50651, '@IncludeInactiveChildren muss 0 oder 1 sein.', 1;
END;

IF @PreviewMode NOT IN ('summary', 'detail')
BEGIN
    THROW 50652, '@PreviewMode muss summary oder detail sein.', 1;
END;

DROP TABLE IF EXISTS #Customer;
DROP TABLE IF EXISTS #SalesOrder;
DROP TABLE IF EXISTS #OrderLine;
DROP TABLE IF EXISTS #Invoice;
DROP TABLE IF EXISTS #SupportTicket;

CREATE TABLE #Customer
(
    CustomerID INT NOT NULL PRIMARY KEY,
    CustomerName NVARCHAR(100) NOT NULL,
    RegionCode CHAR(2) NOT NULL,
    CustomerStatus VARCHAR(20) NOT NULL,
    CreditState VARCHAR(20) NOT NULL
);

CREATE TABLE #SalesOrder
(
    SalesOrderID INT NOT NULL PRIMARY KEY,
    CustomerID INT NOT NULL,
    OrderDate DATE NOT NULL,
    OrderStatus VARCHAR(20) NOT NULL,
    NetAmount DECIMAL(12,2) NOT NULL
);

CREATE TABLE #OrderLine
(
    OrderLineID INT NOT NULL PRIMARY KEY,
    SalesOrderID INT NOT NULL,
    ProductCode VARCHAR(30) NOT NULL,
    FulfillmentState VARCHAR(20) NOT NULL,
    LineAmount DECIMAL(12,2) NOT NULL
);

CREATE TABLE #Invoice
(
    InvoiceID INT NOT NULL PRIMARY KEY,
    CustomerID INT NOT NULL,
    SalesOrderID INT NULL,
    InvoiceStatus VARCHAR(20) NOT NULL,
    OpenAmount DECIMAL(12,2) NOT NULL
);

CREATE TABLE #SupportTicket
(
    TicketID INT NOT NULL PRIMARY KEY,
    CustomerID INT NOT NULL,
    TicketStatus VARCHAR(20) NOT NULL,
    Severity VARCHAR(20) NOT NULL,
    NeedsManualReview BIT NOT NULL
);

INSERT INTO #Customer
(
    CustomerID,
    CustomerName,
    RegionCode,
    CustomerStatus,
    CreditState
)
VALUES
    (101, N'Alpen Bikes GmbH', 'DE', 'active', 'ok'),
    (102, N'Nordwind Retail AG', 'CH', 'inactive', 'hold'),
    (103, N'Urban Coffee Labs', 'AT', 'active', 'ok'),
    (104, N'Delta Service Group', 'DE', 'inactive', 'ok');

INSERT INTO #SalesOrder
(
    SalesOrderID,
    CustomerID,
    OrderDate,
    OrderStatus,
    NetAmount
)
VALUES
    (5001, 101, '2026-01-05', 'closed', 480.00),
    (5002, 102, '2025-11-21', 'closed', 720.00),
    (5003, 102, '2025-12-02', 'archived', 140.00),
    (5004, 102, '2026-01-17', 'cancelled', 0.00),
    (5005, 103, '2026-02-09', 'active', 360.00),
    (5006, 104, '2025-10-10', 'closed', 910.00);

INSERT INTO #OrderLine
(
    OrderLineID,
    SalesOrderID,
    ProductCode,
    FulfillmentState,
    LineAmount
)
VALUES
    (7001, 5001, 'BK-100', 'shipped', 280.00),
    (7002, 5001, 'SV-200', 'shipped', 200.00),
    (7003, 5002, 'NW-410', 'shipped', 420.00),
    (7004, 5002, 'NW-420', 'shipped', 300.00),
    (7005, 5003, 'NW-430', 'archived', 140.00),
    (7006, 5004, 'NW-999', 'cancelled', 0.00),
    (7007, 5005, 'UC-110', 'reserved', 360.00),
    (7008, 5006, 'DS-210', 'shipped', 910.00);

INSERT INTO #Invoice
(
    InvoiceID,
    CustomerID,
    SalesOrderID,
    InvoiceStatus,
    OpenAmount
)
VALUES
    (8101, 101, 5001, 'paid', 0.00),
    (8102, 102, 5002, 'paid', 0.00),
    (8103, 102, 5003, 'archived', 0.00),
    (8104, 102, NULL, 'open', 95.00),
    (8105, 103, 5005, 'open', 360.00),
    (8106, 104, 5006, 'paid', 0.00);

INSERT INTO #SupportTicket
(
    TicketID,
    CustomerID,
    TicketStatus,
    Severity,
    NeedsManualReview
)
VALUES
    (9001, 101, 'closed', 'low', 0),
    (9002, 102, 'resolved', 'medium', 0),
    (9003, 102, 'open', 'high', 1),
    (9004, 102, 'waiting-customer', 'medium', 1),
    (9005, 103, 'open', 'low', 0),
    (9006, 104, 'closed', 'low', 0);

IF NOT EXISTS
(
    SELECT 1
    FROM #Customer AS c
    WHERE c.CustomerID = @CustomerID
)
BEGIN
    THROW 50653, 'Die angegebene @CustomerID ist in den Demo-Daten nicht vorhanden.', 1;
END;

;WITH DeleteKeyPreview AS
(
    SELECT
        c.CustomerID,
        c.CustomerName,
        c.RegionCode,
        c.CustomerStatus,
        c.CreditState,
        CASE
            WHEN c.CustomerStatus = 'inactive' AND c.CreditState <> 'hold' THEN 'delete-ready'
            WHEN c.CustomerStatus = 'inactive' AND c.CreditState = 'hold' THEN 'manual-review'
            ELSE 'active-customer'
        END AS DeleteReadiness
    FROM #Customer AS c
    WHERE c.CustomerID = @CustomerID
),
OrderCandidates AS
(
    SELECT
        so.SalesOrderID,
        so.CustomerID,
        so.OrderDate,
        so.OrderStatus,
        so.NetAmount
    FROM #SalesOrder AS so
    WHERE so.CustomerID = @CustomerID
      AND (
            @IncludeInactiveChildren = 1
            OR so.OrderStatus NOT IN ('archived', 'cancelled')
          )
),
InvoiceCandidates AS
(
    SELECT
        i.InvoiceID,
        i.CustomerID,
        i.SalesOrderID,
        i.InvoiceStatus,
        i.OpenAmount
    FROM #Invoice AS i
    WHERE i.CustomerID = @CustomerID
      AND (
            @IncludeInactiveChildren = 1
            OR i.InvoiceStatus NOT IN ('archived', 'paid')
          )
),
TicketCandidates AS
(
    SELECT
        st.TicketID,
        st.CustomerID,
        st.TicketStatus,
        st.Severity,
        st.NeedsManualReview
    FROM #SupportTicket AS st
    WHERE st.CustomerID = @CustomerID
      AND (
            @IncludeInactiveChildren = 1
            OR st.TicketStatus NOT IN ('closed', 'resolved')
          )
),
LineCandidates AS
(
    SELECT
        ol.OrderLineID,
        oc.SalesOrderID,
        ol.ProductCode,
        ol.FulfillmentState,
        ol.LineAmount
    FROM OrderCandidates AS oc
    INNER JOIN #OrderLine AS ol
        ON ol.SalesOrderID = oc.SalesOrderID
    WHERE @IncludeInactiveChildren = 1
       OR ol.FulfillmentState NOT IN ('archived', 'cancelled')
),
DeleteImpactSummary AS
(
    SELECT
        'Customer' AS EntityName,
        'root-row' AS ImpactRole,
        'manual-check-before-delete' AS RecommendedAction,
        COUNT(*) AS ImpactedRows,
        CAST(0.00 AS DECIMAL(12,2)) AS FinancialExposure
    FROM DeleteKeyPreview

    UNION ALL

    SELECT
        'SalesOrder',
        'direct-child',
        CASE
            WHEN SUM(CASE WHEN oc.OrderStatus = 'active' THEN 1 ELSE 0 END) > 0 THEN 'block-active-orders'
            ELSE 'cascade-or-archive'
        END,
        COUNT(*),
        SUM(oc.NetAmount)
    FROM OrderCandidates AS oc

    UNION ALL

    SELECT
        'OrderLine',
        'indirect-child',
        CASE
            WHEN SUM(CASE WHEN lc.FulfillmentState IN ('reserved', 'picking') THEN 1 ELSE 0 END) > 0 THEN 'review-fulfillment'
            ELSE 'delete-with-parent-order'
        END,
        COUNT(*),
        SUM(lc.LineAmount)
    FROM LineCandidates AS lc

    UNION ALL

    SELECT
        'Invoice',
        'financial-child',
        CASE
            WHEN SUM(CASE WHEN ic.OpenAmount > 0 THEN 1 ELSE 0 END) > 0 THEN 'block-open-balance'
            ELSE 'retain-or-archive'
        END,
        COUNT(*),
        SUM(ic.OpenAmount)
    FROM InvoiceCandidates AS ic

    UNION ALL

    SELECT
        'SupportTicket',
        'manual-follow-up',
        CASE
            WHEN SUM(CASE WHEN tc.NeedsManualReview = 1 THEN 1 ELSE 0 END) > 0 THEN 'manual-ticket-review'
            ELSE 'close-with-customer'
        END,
        COUNT(*),
        CAST(0.00 AS DECIMAL(12,2))
    FROM TicketCandidates AS tc
),
DeleteImpactDetail AS
(
    SELECT
        'SalesOrder' AS EntityName,
        CAST(oc.SalesOrderID AS VARCHAR(30)) AS EntityKey,
        oc.OrderStatus AS StateValue,
        CAST(oc.NetAmount AS DECIMAL(12,2)) AS FinancialValue,
        'Delete des Kunden wuerde diese Bestellung fachlich mitbetreffen.' AS ImpactNote
    FROM OrderCandidates AS oc

    UNION ALL

    SELECT
        'OrderLine',
        CAST(lc.OrderLineID AS VARCHAR(30)),
        lc.FulfillmentState,
        CAST(lc.LineAmount AS DECIMAL(12,2)),
        'Position haengt an einer betroffenen Bestellung.' AS ImpactNote
    FROM LineCandidates AS lc

    UNION ALL

    SELECT
        'Invoice',
        CAST(ic.InvoiceID AS VARCHAR(30)),
        ic.InvoiceStatus,
        CAST(ic.OpenAmount AS DECIMAL(12,2)),
        CASE
            WHEN ic.OpenAmount > 0 THEN 'Offener Betrag blockiert ein einfaches Delete.'
            ELSE 'Beleg ist bereits ausgeglichen oder archiviert.'
        END
    FROM InvoiceCandidates AS ic

    UNION ALL

    SELECT
        'SupportTicket',
        CAST(tc.TicketID AS VARCHAR(30)),
        tc.TicketStatus,
        CAST(0.00 AS DECIMAL(12,2)),
        CASE
            WHEN tc.NeedsManualReview = 1 THEN 'Ticket verlangt manuelle Abstimmung vor dem Delete.'
            ELSE 'Ticket kann nur als Kontextinformation betrachtet werden.'
        END
    FROM TicketCandidates AS tc
)
SELECT
    dkp.CustomerID,
    dkp.CustomerName,
    dkp.RegionCode,
    dkp.CustomerStatus,
    dkp.CreditState,
    dkp.DeleteReadiness
FROM DeleteKeyPreview AS dkp;

SELECT
    dis.EntityName,
    dis.ImpactRole,
    dis.RecommendedAction,
    dis.ImpactedRows,
    dis.FinancialExposure
FROM DeleteImpactSummary AS dis
ORDER BY
    CASE dis.EntityName
        WHEN 'Customer' THEN 1
        WHEN 'SalesOrder' THEN 2
        WHEN 'OrderLine' THEN 3
        WHEN 'Invoice' THEN 4
        WHEN 'SupportTicket' THEN 5
        ELSE 9
    END;

IF @PreviewMode = 'detail'
BEGIN
    SELECT
        did.EntityName,
        did.EntityKey,
        did.StateValue,
        did.FinancialValue,
        did.ImpactNote
    FROM DeleteImpactDetail AS did
    ORDER BY
        did.EntityName,
        did.EntityKey;
END;

SELECT
    @CustomerID AS CustomerID,
    @IncludeInactiveChildren AS IncludeInactiveChildren,
    @PreviewMode AS PreviewMode,
    'Das Skript erstellt nur tempdb-Demodaten und fuehrt kein DELETE aus.' AS SafetyNote,
    CASE
        WHEN EXISTS
        (
            SELECT 1
            FROM #Invoice AS i
            WHERE i.CustomerID = @CustomerID
              AND i.OpenAmount > 0
        ) THEN 'Offene Rechnungen sprechen gegen ein direktes Delete.'
        WHEN EXISTS
        (
            SELECT 1
            FROM #SupportTicket AS st
            WHERE st.CustomerID = @CustomerID
              AND st.NeedsManualReview = 1
        ) THEN 'Support-Tickets verlangen manuelle Abstimmung vor einer Loeschung.'
        ELSE 'Die Vorschau zeigt keine offenen Salden, ersetzt aber kein fachliches Freigabeverfahren.'
    END AS DeleteRecommendation;
