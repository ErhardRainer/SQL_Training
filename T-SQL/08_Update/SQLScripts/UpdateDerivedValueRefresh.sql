/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "UpdateDerivedValueRefresh.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "08_Update"

purpose: >
  Demonstriert in tempdb, wie abgeleitete Kopfwerte nach Aenderungen an
  Detaildaten kontrolliert neu berechnet und per UPDATE nur bei echtem
  Delta zurueck in die Zieltabelle geschrieben werden.

parameters:
  - name: "@ApplyUpdate"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = abgeleitete Werte in der Kopfzeile aktualisieren, 0 = nur Vorschau"
  - name: "@OnlyChangedRows"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = nur Kopfzeilen mit Delta schreiben, 0 = alle Refresh-Kandidaten schreiben"
  - name: "@ResetDemoData"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = Demo-Daten vor dem Lauf neu aufbauen"
  - name: "@DropDemoObjects"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = Demo-Objekte am Ende wieder aus tempdb entfernen"

result_sets:
  - name: "RefreshPreview"
    description: "Vergleich zwischen gespeicherten und neu berechneten Kopfwerten je Auftrag"
  - name: "AppliedRefresh"
    description: "Per OUTPUT protokollierte Refreshes der Kopfzeilen"
  - name: "FinalHeaderState"
    description: "Endzustand der Kopfzeilen nach Preview oder Refresh"
  - name: "RefreshSummary"
    description: "Zusammenfassung zu Kandidaten, Deltas und ausgefuehrten Updates"

dependencies:
  - "tempdb"
  - "sys.schemas"
  - "SYSUTCDATETIME()"
  - "CTE"
  - "GROUP BY"
  - "UPDATE ... FROM"
  - "OUTPUT"
  - "CASE"

safety:
  level: "demo-write-tempdb"
  writes_data: true

documentation:
  markdown_file: "T-SQL/08_Update/SQLScripts/UpdateDerivedValueRefresh.md"
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
    description: "Erstversion eines didaktischen Refresh-Skripts fuer abgeleitete Kopfwerte nach Detailaenderungen"

notes:
  - "Die Erstversion verwendet ausschliesslich Demo-Objekte in tempdb"
  - "Abgeleitete Werte werden aus Detailzeilen neu aggregiert und nur bei Delta zurueckgeschrieben"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @ApplyUpdate BIT = 1;
DECLARE @OnlyChangedRows BIT = 1;
DECLARE @ResetDemoData BIT = 1;
DECLARE @DropDemoObjects BIT = 1;
DECLARE @RunStamp DATETIME2(0) = SYSUTCDATETIME();

IF @ApplyUpdate NOT IN (0, 1)
BEGIN
    THROW 50000, '@ApplyUpdate muss 0 oder 1 sein.', 1;
END;

IF @OnlyChangedRows NOT IN (0, 1)
BEGIN
    THROW 50001, '@OnlyChangedRows muss 0 oder 1 sein.', 1;
END;

IF @ResetDemoData NOT IN (0, 1)
BEGIN
    THROW 50002, '@ResetDemoData muss 0 oder 1 sein.', 1;
END;

IF @DropDemoObjects NOT IN (0, 1)
BEGIN
    THROW 50003, '@DropDemoObjects muss 0 oder 1 sein.', 1;
END;

USE tempdb;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.schemas
    WHERE name = N'demo'
)
BEGIN
    EXEC(N'CREATE SCHEMA demo AUTHORIZATION dbo;');
END;

IF OBJECT_ID(N'demo.UpdateDerivedValueHeader', N'U') IS NULL
BEGIN
    CREATE TABLE demo.UpdateDerivedValueHeader
    (
        OrderID                  INT             NOT NULL PRIMARY KEY,
        CustomerCode             NVARCHAR(20)    NOT NULL,
        StoredOpenLineCount      INT             NOT NULL,
        StoredBackorderLineCount INT             NOT NULL,
        StoredTotalAmount        DECIMAL(12,2)   NOT NULL,
        StoredFulfillmentState   NVARCHAR(20)    NOT NULL,
        LastSourceChangeAt       DATETIME2(0)    NOT NULL,
        LastDerivedRefreshAt     DATETIME2(0)    NULL
    );
END;

IF OBJECT_ID(N'demo.UpdateDerivedValueLine', N'U') IS NULL
BEGIN
    CREATE TABLE demo.UpdateDerivedValueLine
    (
        OrderID              INT             NOT NULL,
        LineID               INT             NOT NULL,
        LineStatus           NVARCHAR(20)    NOT NULL,
        Quantity             INT             NOT NULL,
        UnitPrice            DECIMAL(12,2)   NOT NULL,
        LastChangedAt        DATETIME2(0)    NOT NULL,
        CONSTRAINT PK_UpdateDerivedValueLine PRIMARY KEY (OrderID, LineID)
    );
END;

IF @ResetDemoData = 1
BEGIN
    TRUNCATE TABLE demo.UpdateDerivedValueLine;
    TRUNCATE TABLE demo.UpdateDerivedValueHeader;

    INSERT INTO demo.UpdateDerivedValueHeader
    (
        OrderID,
        CustomerCode,
        StoredOpenLineCount,
        StoredBackorderLineCount,
        StoredTotalAmount,
        StoredFulfillmentState,
        LastSourceChangeAt,
        LastDerivedRefreshAt
    )
    VALUES
        (401, N'CUST-ALPHA', 2, 0, 275.00, N'open', DATEADD(HOUR, -8, @RunStamp), DATEADD(DAY, -1, @RunStamp)),
        (402, N'CUST-BRAVO', 1, 0, 160.00, N'open', DATEADD(HOUR, -5, @RunStamp), DATEADD(DAY, -1, @RunStamp)),
        (403, N'CUST-CHARLIE', 1, 1, 210.00, N'backorder', DATEADD(HOUR, -3, @RunStamp), DATEADD(DAY, -2, @RunStamp)),
        (404, N'CUST-DELTA', 0, 0, 90.00, N'fulfilled', DATEADD(HOUR, -2, @RunStamp), DATEADD(DAY, -2, @RunStamp));

    INSERT INTO demo.UpdateDerivedValueLine
    (
        OrderID,
        LineID,
        LineStatus,
        Quantity,
        UnitPrice,
        LastChangedAt
    )
    VALUES
        (401, 1, N'open', 2, 50.00, DATEADD(HOUR, -7, @RunStamp)),
        (401, 2, N'fulfilled', 1, 175.00, DATEADD(HOUR, -6, @RunStamp)),
        (402, 1, N'fulfilled', 2, 80.00, DATEADD(HOUR, -4, @RunStamp)),
        (403, 1, N'backorder', 3, 40.00, DATEADD(HOUR, -3, @RunStamp)),
        (403, 2, N'open', 1, 90.00, DATEADD(HOUR, -3, @RunStamp)),
        (404, 1, N'fulfilled', 1, 90.00, DATEADD(HOUR, -2, @RunStamp));
END;

DROP TABLE IF EXISTS #RefreshPreview;
CREATE TABLE #RefreshPreview
(
    OrderID                   INT             NOT NULL PRIMARY KEY,
    CustomerCode              NVARCHAR(20)    NOT NULL,
    StoredOpenLineCount       INT             NOT NULL,
    DerivedOpenLineCount      INT             NOT NULL,
    StoredBackorderLineCount  INT             NOT NULL,
    DerivedBackorderLineCount INT             NOT NULL,
    StoredTotalAmount         DECIMAL(12,2)   NOT NULL,
    DerivedTotalAmount        DECIMAL(12,2)   NOT NULL,
    StoredFulfillmentState    NVARCHAR(20)    NOT NULL,
    DerivedFulfillmentState   NVARCHAR(20)    NOT NULL,
    LastSourceChangeAt        DATETIME2(0)    NOT NULL,
    NeedsRefresh              BIT             NOT NULL,
    RefreshReason             NVARCHAR(200)   NOT NULL
);

DROP TABLE IF EXISTS #AppliedRefresh;
CREATE TABLE #AppliedRefresh
(
    OrderID                INT             NOT NULL,
    CustomerCode           NVARCHAR(20)    NOT NULL,
    PreviousOpenLineCount  INT             NOT NULL,
    NewOpenLineCount       INT             NOT NULL,
    PreviousBackorderCount INT             NOT NULL,
    NewBackorderCount      INT             NOT NULL,
    PreviousTotalAmount    DECIMAL(12,2)   NOT NULL,
    NewTotalAmount         DECIMAL(12,2)   NOT NULL,
    PreviousState          NVARCHAR(20)    NOT NULL,
    NewState               NVARCHAR(20)    NOT NULL,
    RefreshedAtUtc         DATETIME2(0)    NOT NULL
);

;WITH LineAggregate AS
(
    SELECT
        line.OrderID,
        SUM(CASE WHEN line.LineStatus IN (N'open', N'backorder') THEN 1 ELSE 0 END) AS DerivedOpenLineCount,
        SUM(CASE WHEN line.LineStatus = N'backorder' THEN 1 ELSE 0 END) AS DerivedBackorderLineCount,
        CAST(SUM(CAST(line.Quantity * line.UnitPrice AS DECIMAL(12,2))) AS DECIMAL(12,2)) AS DerivedTotalAmount,
        MAX(line.LastChangedAt) AS DerivedLastSourceChangeAt,
        CASE
            WHEN SUM(CASE WHEN line.LineStatus = N'backorder' THEN 1 ELSE 0 END) > 0 THEN N'backorder'
            WHEN SUM(CASE WHEN line.LineStatus = N'open' THEN 1 ELSE 0 END) > 0 THEN N'open'
            ELSE N'fulfilled'
        END AS DerivedFulfillmentState
    FROM demo.UpdateDerivedValueLine AS line
    GROUP BY
        line.OrderID
)
INSERT INTO #RefreshPreview
(
    OrderID,
    CustomerCode,
    StoredOpenLineCount,
    DerivedOpenLineCount,
    StoredBackorderLineCount,
    DerivedBackorderLineCount,
    StoredTotalAmount,
    DerivedTotalAmount,
    StoredFulfillmentState,
    DerivedFulfillmentState,
    LastSourceChangeAt,
    NeedsRefresh,
    RefreshReason
)
SELECT
    hdr.OrderID,
    hdr.CustomerCode,
    hdr.StoredOpenLineCount,
    agg.DerivedOpenLineCount,
    hdr.StoredBackorderLineCount,
    agg.DerivedBackorderLineCount,
    hdr.StoredTotalAmount,
    agg.DerivedTotalAmount,
    hdr.StoredFulfillmentState,
    agg.DerivedFulfillmentState,
    agg.DerivedLastSourceChangeAt,
    CASE
        WHEN hdr.StoredOpenLineCount <> agg.DerivedOpenLineCount
          OR hdr.StoredBackorderLineCount <> agg.DerivedBackorderLineCount
          OR hdr.StoredTotalAmount <> agg.DerivedTotalAmount
          OR hdr.StoredFulfillmentState <> agg.DerivedFulfillmentState
          OR hdr.LastSourceChangeAt <> agg.DerivedLastSourceChangeAt
        THEN 1
        ELSE 0
    END AS NeedsRefresh,
    CASE
        WHEN hdr.StoredOpenLineCount <> agg.DerivedOpenLineCount
          AND hdr.StoredBackorderLineCount <> agg.DerivedBackorderLineCount
          AND hdr.StoredTotalAmount <> agg.DerivedTotalAmount
          AND hdr.StoredFulfillmentState <> agg.DerivedFulfillmentState
        THEN N'offene Linien, Backorders, Summe und Status muessen aktualisiert werden'
        WHEN hdr.StoredOpenLineCount <> agg.DerivedOpenLineCount
          AND hdr.StoredBackorderLineCount <> agg.DerivedBackorderLineCount
        THEN N'Aggregierte Linienanzahlen sind veraltet'
        WHEN hdr.StoredTotalAmount <> agg.DerivedTotalAmount
          AND hdr.StoredFulfillmentState <> agg.DerivedFulfillmentState
        THEN N'Betrag und abgeleiteter Gesamtstatus sind veraltet'
        WHEN hdr.StoredTotalAmount <> agg.DerivedTotalAmount
        THEN N'Gesamtbetrag ist veraltet'
        WHEN hdr.StoredFulfillmentState <> agg.DerivedFulfillmentState
        THEN N'Abgeleiteter Gesamtstatus ist veraltet'
        WHEN hdr.LastSourceChangeAt <> agg.DerivedLastSourceChangeAt
        THEN N'Nur der Refresh-Zeitbezug zur Quellaenderung ist veraltet'
        ELSE N'Kein Delta zwischen gespeicherten und abgeleiteten Werten'
    END AS RefreshReason
FROM demo.UpdateDerivedValueHeader AS hdr
INNER JOIN LineAggregate AS agg
    ON agg.OrderID = hdr.OrderID;

IF @ApplyUpdate = 1
BEGIN
    UPDATE hdr
    SET
        hdr.StoredOpenLineCount = prv.DerivedOpenLineCount,
        hdr.StoredBackorderLineCount = prv.DerivedBackorderLineCount,
        hdr.StoredTotalAmount = prv.DerivedTotalAmount,
        hdr.StoredFulfillmentState = prv.DerivedFulfillmentState,
        hdr.LastSourceChangeAt = prv.LastSourceChangeAt,
        hdr.LastDerivedRefreshAt = @RunStamp
    OUTPUT
        inserted.OrderID,
        inserted.CustomerCode,
        deleted.StoredOpenLineCount,
        inserted.StoredOpenLineCount,
        deleted.StoredBackorderLineCount,
        inserted.StoredBackorderLineCount,
        deleted.StoredTotalAmount,
        inserted.StoredTotalAmount,
        deleted.StoredFulfillmentState,
        inserted.StoredFulfillmentState,
        @RunStamp
    INTO #AppliedRefresh
    (
        OrderID,
        CustomerCode,
        PreviousOpenLineCount,
        NewOpenLineCount,
        PreviousBackorderCount,
        NewBackorderCount,
        PreviousTotalAmount,
        NewTotalAmount,
        PreviousState,
        NewState,
        RefreshedAtUtc
    )
    FROM demo.UpdateDerivedValueHeader AS hdr
    INNER JOIN #RefreshPreview AS prv
        ON prv.OrderID = hdr.OrderID
    WHERE @OnlyChangedRows = 0
       OR prv.NeedsRefresh = 1;
END;

SELECT
    OrderID,
    CustomerCode,
    StoredOpenLineCount,
    DerivedOpenLineCount,
    StoredBackorderLineCount,
    DerivedBackorderLineCount,
    StoredTotalAmount,
    DerivedTotalAmount,
    StoredFulfillmentState,
    DerivedFulfillmentState,
    LastSourceChangeAt,
    NeedsRefresh,
    RefreshReason
FROM #RefreshPreview
ORDER BY OrderID;

SELECT
    OrderID,
    CustomerCode,
    PreviousOpenLineCount,
    NewOpenLineCount,
    PreviousBackorderCount,
    NewBackorderCount,
    PreviousTotalAmount,
    NewTotalAmount,
    PreviousState,
    NewState,
    RefreshedAtUtc
FROM #AppliedRefresh
ORDER BY OrderID;

SELECT
    OrderID,
    CustomerCode,
    StoredOpenLineCount,
    StoredBackorderLineCount,
    StoredTotalAmount,
    StoredFulfillmentState,
    LastSourceChangeAt,
    LastDerivedRefreshAt
FROM demo.UpdateDerivedValueHeader
ORDER BY OrderID;

SELECT
    COUNT(*) AS RefreshCandidates,
    SUM(CASE WHEN NeedsRefresh = 1 THEN 1 ELSE 0 END) AS RowsWithDelta,
    SUM(CASE WHEN NeedsRefresh = 0 THEN 1 ELSE 0 END) AS RowsAlreadyCurrent,
    COUNT(apl.OrderID) AS RowsWritten,
    CASE
        WHEN @ApplyUpdate = 1 AND @OnlyChangedRows = 1
        THEN N'Nur Kopfzeilen mit Delta wurden aktualisiert.'
        WHEN @ApplyUpdate = 1 AND @OnlyChangedRows = 0
        THEN N'Alle Kandidaten wurden zur Demonstration neu geschrieben.'
        ELSE N'Preview-Lauf ohne Schreibvorgang.'
    END AS ExecutionMode
FROM #RefreshPreview AS prv
LEFT JOIN #AppliedRefresh AS apl
    ON apl.OrderID = prv.OrderID;

IF @DropDemoObjects = 1
BEGIN
    DROP TABLE IF EXISTS demo.UpdateDerivedValueLine;
    DROP TABLE IF EXISTS demo.UpdateDerivedValueHeader;
END;
