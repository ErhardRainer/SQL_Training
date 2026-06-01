/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "DeleteArchiveBeforeRemove.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "06_Delete"

purpose: >
  Demonstriert ein sicheres Muster, bei dem Loeschkandidaten vor dem endgueltigen
  Entfernen atomar in eine Archivtabelle geschrieben werden, damit Fachkontext,
  Loeschgrund und Wiederherstellungsbasis erhalten bleiben.

parameters:
  - name: "@DeleteBeforeDate"
    sql_type: "DATE"
    direction: "IN"
    required: false
    description: "Bestellungen mit RequestedShipDate vor diesem Datum gelten als Loeschkandidaten"
  - name: "@ArchiveReason"
    sql_type: "NVARCHAR(120)"
    direction: "IN"
    required: false
    description: "Dokumentiert den fachlichen Grund fuer Archivierung und Delete"
  - name: "@PreviewOnly"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 zeigt nur Kandidaten und Plan, 0 archiviert und loescht in der Demo"
  - name: "@IncludeClosedOnly"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 beschraenkt die Loeschung auf abgeschlossene oder stornierte Bestellungen"

result_sets:
  - name: "DeleteCandidates"
    description: "Zeigt die Demo-Bestellungen und markiert, welche Zeilen fuer Archivierung und Delete vorgesehen sind"
  - name: "ArchiveResult"
    description: "Listet die archivierten und geloeschten Zeilen mit Archivmetadaten auf"
  - name: "RemainingOrders"
    description: "Zeigt den verbleibenden Bestand nach der optionalen Delete-Ausfuehrung"
  - name: "ExecutionGuide"
    description: "Fasst Modus, Kandidatenzahl und Sicherheitsgedanken des Musters zusammen"

dependencies:
  - "tempdb temporary tables"
  - "explicit transactions"
  - "TRY...CATCH"
  - "DELETE"
  - "OUTPUT"
  - "SYSUTCDATETIME"

safety:
  level: "destructive-demo-tempdb"
  writes_data: true

documentation:
  markdown_file: "T-SQL/06_Delete/SQLScripts/DeleteArchiveBeforeRemove.md"
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
    description: "Erstversion fuer atomisches Archivieren vor dem DELETE in tempdb"

notes:
  - "Die Demo arbeitet nur mit temporaeren Tabellen in tempdb."
  - "Archivierung und Loeschung laufen ueber DELETE ... OUTPUT in einer gemeinsamen Transaktion."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @DeleteBeforeDate DATE = '2026-02-01';
DECLARE @ArchiveReason NVARCHAR(120) = N'Retention-Fenster abgeschlossen';
DECLARE @PreviewOnly BIT = 1;
DECLARE @IncludeClosedOnly BIT = 1;

IF @DeleteBeforeDate IS NULL
BEGIN
    THROW 50650, '@DeleteBeforeDate darf nicht NULL sein.', 1;
END;

IF NULLIF(LTRIM(RTRIM(@ArchiveReason)), N'') IS NULL
BEGIN
    THROW 50651, '@ArchiveReason darf nicht leer sein.', 1;
END;

IF @PreviewOnly NOT IN (0, 1)
BEGIN
    THROW 50652, '@PreviewOnly muss 0 oder 1 sein.', 1;
END;

IF @IncludeClosedOnly NOT IN (0, 1)
BEGIN
    THROW 50653, '@IncludeClosedOnly muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #OrderDeleteArchive;
DROP TABLE IF EXISTS #SalesOrder;

CREATE TABLE #SalesOrder
(
    OrderID INT NOT NULL PRIMARY KEY,
    CustomerCode VARCHAR(12) NOT NULL,
    OrderStatus VARCHAR(20) NOT NULL,
    RequestedShipDate DATE NOT NULL,
    NetAmount DECIMAL(12,2) NOT NULL,
    LastTouchedAt DATETIME2(0) NOT NULL
);

CREATE TABLE #OrderDeleteArchive
(
    ArchiveID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    ArchivedAtUtc DATETIME2(0) NOT NULL,
    ArchiveReason NVARCHAR(120) NOT NULL,
    ArchivedBy SYSNAME NOT NULL,
    OrderID INT NOT NULL,
    CustomerCode VARCHAR(12) NOT NULL,
    OrderStatus VARCHAR(20) NOT NULL,
    RequestedShipDate DATE NOT NULL,
    NetAmount DECIMAL(12,2) NOT NULL,
    LastTouchedAt DATETIME2(0) NOT NULL
);

INSERT INTO #SalesOrder
(
    OrderID,
    CustomerCode,
    OrderStatus,
    RequestedShipDate,
    NetAmount,
    LastTouchedAt
)
VALUES
    (4101, 'C-100', 'closed', '2025-12-14', 240.00, '2025-12-15T09:10:00'),
    (4102, 'C-100', 'cancelled', '2025-12-20', 80.00, '2025-12-20T13:45:00'),
    (4103, 'C-205', 'closed', '2026-01-09', 515.50, '2026-01-10T08:20:00'),
    (4104, 'C-205', 'open', '2026-01-12', 310.00, '2026-01-12T15:05:00'),
    (4105, 'C-330', 'closed', '2026-01-18', 124.90, '2026-01-19T07:40:00'),
    (4106, 'C-330', 'staged', '2026-01-22', 900.00, '2026-01-22T17:10:00'),
    (4107, 'C-411', 'cancelled', '2026-01-28', 60.00, '2026-01-28T11:55:00'),
    (4108, 'C-411', 'closed', '2026-02-03', 440.00, '2026-02-03T14:30:00');

SELECT
    so.OrderID,
    so.CustomerCode,
    so.OrderStatus,
    so.RequestedShipDate,
    so.NetAmount,
    so.LastTouchedAt,
    CASE
        WHEN so.RequestedShipDate < @DeleteBeforeDate
         AND (
                @IncludeClosedOnly = 0
                OR so.OrderStatus IN ('closed', 'cancelled')
             )
            THEN 1
        ELSE 0
    END AS IsDeleteCandidate
FROM #SalesOrder AS so
ORDER BY
    so.RequestedShipDate,
    so.OrderID;

IF @PreviewOnly = 0
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE so
            OUTPUT
                SYSUTCDATETIME(),
                @ArchiveReason,
                SUSER_SNAME(),
                deleted.OrderID,
                deleted.CustomerCode,
                deleted.OrderStatus,
                deleted.RequestedShipDate,
                deleted.NetAmount,
                deleted.LastTouchedAt
            INTO #OrderDeleteArchive
            (
                ArchivedAtUtc,
                ArchiveReason,
                ArchivedBy,
                OrderID,
                CustomerCode,
                OrderStatus,
                RequestedShipDate,
                NetAmount,
                LastTouchedAt
            )
        FROM #SalesOrder AS so
        WHERE so.RequestedShipDate < @DeleteBeforeDate
          AND (
                @IncludeClosedOnly = 0
                OR so.OrderStatus IN ('closed', 'cancelled')
              );

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
        BEGIN
            ROLLBACK TRANSACTION;
        END;

        THROW;
    END CATCH;
END;

SELECT
    oda.ArchiveID,
    oda.ArchivedAtUtc,
    oda.ArchiveReason,
    oda.ArchivedBy,
    oda.OrderID,
    oda.CustomerCode,
    oda.OrderStatus,
    oda.RequestedShipDate,
    oda.NetAmount
FROM #OrderDeleteArchive AS oda
ORDER BY
    oda.ArchiveID;

SELECT
    so.OrderID,
    so.CustomerCode,
    so.OrderStatus,
    so.RequestedShipDate,
    so.NetAmount,
    so.LastTouchedAt
FROM #SalesOrder AS so
ORDER BY
    so.RequestedShipDate,
    so.OrderID;

SELECT
    @DeleteBeforeDate AS DeleteBeforeDate,
    @ArchiveReason AS ArchiveReason,
    @PreviewOnly AS PreviewOnly,
    @IncludeClosedOnly AS IncludeClosedOnly,
    (
        SELECT COUNT(*)
        FROM #SalesOrder AS so
        WHERE so.RequestedShipDate < @DeleteBeforeDate
          AND (
                @IncludeClosedOnly = 0
                OR so.OrderStatus IN ('closed', 'cancelled')
              )
    ) AS RemainingDeleteCandidates,
    (
        SELECT COUNT(*)
        FROM #OrderDeleteArchive AS oda
    ) AS ArchivedRows,
    CASE
        WHEN @PreviewOnly = 1 THEN 'PreviewOnly zeigt nur Kandidaten; Archiv und Zielbestand bleiben unveraendert.'
        ELSE 'Archivierung und DELETE wurden atomar in tempdb ausgefuehrt.'
    END AS ExecutionModeNote,
    'Fuer produktive Tabellen muessen Archivziel, Aufbewahrungsfrist, Restore-Pfad und Monitoring vorab festgelegt sein.' AS SafetyNote;
