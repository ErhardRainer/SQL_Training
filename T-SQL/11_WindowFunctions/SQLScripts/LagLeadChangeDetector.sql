/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "LagLeadChangeDetector.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "11_WindowFunctions"

purpose: >
  Markiert Status- und Wertewechsel in einer geordneten Snapshot-Folge
  je Auftrag. Das Skript kombiniert LAG() und LEAD(), um vorherige und
  naechste Auspraegungen sichtbar zu machen, Aenderungstypen zu
  klassifizieren und den letzten bekannten Zustand kompakt auszuwerten.

parameters:
  - name: "@OnlyShowDetectedChanges"
    sql_type: "BIT"
    direction: "IN"
    required: true
    description: "1 = nur Initial-, Status- oder Wertewechsel zeigen, 0 = komplette Snapshot-Folge ausgeben"
  - name: "@AmountTolerance"
    sql_type: "DECIMAL(10,2)"
    direction: "IN"
    required: true
    description: "Betragsdifferenzen bis einschliesslich dieses Werts gelten als unveraendert"
  - name: "@ShowSourceData"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = Demo-Snapshots vor der Analyse zusaetzlich ausgeben"

result_sets:
  - name: "SourcePreview"
    description: "Optionale Vorschau auf die sortierten Demo-Snapshots"
  - name: "SnapshotWithNeighbors"
    description: "Zeigt je Snapshot den vorherigen und naechsten Status sowie den vorherigen und naechsten Betrag"
  - name: "DetectedChanges"
    description: "Klassifiziert Initial-, Status-, Werte- und kombinierte Wechsel"
  - name: "ChangeSummaryPerOrder"
    description: "Verdichtete Sicht je Auftrag mit Anzahl und Reihenfolge der erkannten Wechsel"
  - name: "CurrentSnapshotOutlook"
    description: "Letzter bekannter Snapshot je Auftrag mit Hinweis auf fehlenden Nachfolger"

dependencies:
  - "tempdb temporary tables"
  - "LAG()"
  - "LEAD()"
  - "ROW_NUMBER()"
  - "STRING_AGG()"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/11_WindowFunctions/SQLScripts/LagLeadChangeDetector.md"
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
    description: "Erstversion des didaktischen Labs zur Erkennung von Status- und Wertewechseln mit LAG und LEAD"

notes:
  - "Die Demo arbeitet mit Auftrags-Snapshots in Temp-Tabellen statt mit produktiven Tabellen"
  - "Ein Wertewechsel liegt nur vor, wenn sich NetAmount um mehr als @AmountTolerance aendert"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @OnlyShowDetectedChanges BIT = 1;
DECLARE @AmountTolerance         DECIMAL(10,2) = 5.00;
DECLARE @ShowSourceData          BIT = 1;

IF @OnlyShowDetectedChanges NOT IN (0, 1) OR @ShowSourceData NOT IN (0, 1)
BEGIN
    THROW 50000, 'Die BIT-Parameter muessen als 0 oder 1 gesetzt sein.', 1;
END;

IF @AmountTolerance IS NULL OR @AmountTolerance < 0
BEGIN
    THROW 50000, '@AmountTolerance muss groesser oder gleich 0 sein.', 1;
END;

DROP TABLE IF EXISTS #OrderSnapshots;
DROP TABLE IF EXISTS #SnapshotWithNeighbors;
DROP TABLE IF EXISTS #DetectedChanges;
DROP TABLE IF EXISTS #CurrentSnapshotOutlook;

CREATE TABLE #OrderSnapshots
(
    OrderID            VARCHAR(20)    NOT NULL,
    SnapshotTime       DATETIME2(0)   NOT NULL,
    ProcessStatus      VARCHAR(20)    NOT NULL,
    NetAmount          DECIMAL(10,2)  NOT NULL,
    PlannedShipDate    DATE           NOT NULL,
    UpdatedByRole      VARCHAR(30)    NOT NULL,
    SnapshotComment    VARCHAR(120)   NOT NULL
);

INSERT INTO #OrderSnapshots
(
    OrderID,
    SnapshotTime,
    ProcessStatus,
    NetAmount,
    PlannedShipDate,
    UpdatedByRole,
    SnapshotComment
)
VALUES
    ('ORD-100', '2026-03-10T08:00:00', 'Draft',      1200.00, '2026-03-14', 'Sales',     'Initiales Angebot angelegt'),
    ('ORD-100', '2026-03-10T09:15:00', 'Draft',      1200.00, '2026-03-14', 'Sales',     'Nur Kommentar ohne fachliche Aenderung'),
    ('ORD-100', '2026-03-10T10:30:00', 'Approved',   1200.00, '2026-03-14', 'Manager',   'Freigabe erteilt'),
    ('ORD-100', '2026-03-10T11:20:00', 'Approved',   1325.00, '2026-03-15', 'Sales',     'Mengenanpassung nach Rueckfrage'),
    ('ORD-100', '2026-03-10T15:40:00', 'Shipped',    1325.00, '2026-03-15', 'Logistics', 'Versand bestaetigt'),
    ('ORD-200', '2026-03-11T07:45:00', 'Draft',       450.00, '2026-03-16', 'Sales',     'Auftrag angelegt'),
    ('ORD-200', '2026-03-11T08:10:00', 'Draft',       454.00, '2026-03-16', 'Sales',     'Rundungsnahe Korrektur innerhalb Toleranz'),
    ('ORD-200', '2026-03-11T09:00:00', 'OnHold',      454.00, '2026-03-18', 'Finance',   'Bonitaetspruefung angehalten'),
    ('ORD-200', '2026-03-11T12:30:00', 'OnHold',      610.00, '2026-03-18', 'Sales',     'Zusatzposition aufgenommen'),
    ('ORD-200', '2026-03-11T16:10:00', 'Approved',    610.00, '2026-03-18', 'Finance',   'Freigabe nach Pruefung'),
    ('ORD-300', '2026-03-12T08:05:00', 'Draft',       980.00, '2026-03-20', 'Sales',     'Auftrag angelegt'),
    ('ORD-300', '2026-03-12T10:15:00', 'Approved',    980.00, '2026-03-20', 'Manager',   'Sofort freigegeben'),
    ('ORD-300', '2026-03-12T14:45:00', 'Approved',   1110.00, '2026-03-22', 'Sales',     'Preis und Termin aktualisiert'),
    ('ORD-300', '2026-03-12T18:00:00', 'Cancelled',  1110.00, '2026-03-22', 'Sales',     'Kunde storniert vor Versand');

IF @ShowSourceData = 1
BEGIN
    SELECT
        os.OrderID,
        os.SnapshotTime,
        os.ProcessStatus,
        os.NetAmount,
        os.PlannedShipDate,
        os.UpdatedByRole,
        os.SnapshotComment
    FROM #OrderSnapshots AS os
    ORDER BY
        os.OrderID,
        os.SnapshotTime;
END;

-- 1. Vorherige und naechste Auspraegungen je Auftrag sichtbar machen.
SELECT
    os.OrderID,
    os.SnapshotTime,
    os.ProcessStatus,
    os.NetAmount,
    os.PlannedShipDate,
    os.UpdatedByRole,
    os.SnapshotComment,
    ROW_NUMBER() OVER
    (
        PARTITION BY os.OrderID
        ORDER BY os.SnapshotTime
    ) AS SnapshotSequenceNumber,
    LAG(os.ProcessStatus) OVER
    (
        PARTITION BY os.OrderID
        ORDER BY os.SnapshotTime
    ) AS PreviousProcessStatus,
    LAG(os.NetAmount) OVER
    (
        PARTITION BY os.OrderID
        ORDER BY os.SnapshotTime
    ) AS PreviousNetAmount,
    LAG(os.PlannedShipDate) OVER
    (
        PARTITION BY os.OrderID
        ORDER BY os.SnapshotTime
    ) AS PreviousPlannedShipDate,
    LEAD(os.ProcessStatus) OVER
    (
        PARTITION BY os.OrderID
        ORDER BY os.SnapshotTime
    ) AS NextProcessStatus,
    LEAD(os.NetAmount) OVER
    (
        PARTITION BY os.OrderID
        ORDER BY os.SnapshotTime
    ) AS NextNetAmount,
    LEAD(os.SnapshotTime) OVER
    (
        PARTITION BY os.OrderID
        ORDER BY os.SnapshotTime
    ) AS NextSnapshotTime
INTO #SnapshotWithNeighbors
FROM #OrderSnapshots AS os;

SELECT
    swn.OrderID,
    swn.SnapshotSequenceNumber,
    swn.SnapshotTime,
    swn.ProcessStatus,
    swn.PreviousProcessStatus,
    swn.NextProcessStatus,
    swn.NetAmount,
    swn.PreviousNetAmount,
    swn.NextNetAmount,
    swn.PlannedShipDate,
    swn.PreviousPlannedShipDate,
    swn.NextSnapshotTime,
    swn.UpdatedByRole,
    swn.SnapshotComment
FROM #SnapshotWithNeighbors AS swn
WHERE @OnlyShowDetectedChanges = 0
   OR swn.PreviousProcessStatus IS NULL
   OR swn.PreviousProcessStatus <> swn.ProcessStatus
   OR ABS(swn.NetAmount - ISNULL(swn.PreviousNetAmount, swn.NetAmount)) > @AmountTolerance
   OR swn.PreviousPlannedShipDate <> swn.PlannedShipDate
ORDER BY
    swn.OrderID,
    swn.SnapshotSequenceNumber;

-- 2. Status-, Werte- und Terminwechsel klassifizieren.
SELECT
    swn.OrderID,
    swn.SnapshotSequenceNumber,
    swn.SnapshotTime,
    swn.ProcessStatus,
    swn.PreviousProcessStatus,
    swn.NextProcessStatus,
    swn.NetAmount,
    swn.PreviousNetAmount,
    swn.NextNetAmount,
    swn.PlannedShipDate,
    swn.PreviousPlannedShipDate,
    swn.NextSnapshotTime,
    swn.UpdatedByRole,
    swn.SnapshotComment,
    CAST(ABS(swn.NetAmount - ISNULL(swn.PreviousNetAmount, swn.NetAmount)) AS DECIMAL(10,2)) AS AmountDelta,
    CASE
        WHEN swn.PreviousProcessStatus IS NULL THEN 1
        WHEN swn.PreviousProcessStatus <> swn.ProcessStatus THEN 1
        ELSE 0
    END AS HasStatusChange,
    CASE
        WHEN swn.PreviousNetAmount IS NULL THEN 0
        WHEN ABS(swn.NetAmount - swn.PreviousNetAmount) > @AmountTolerance THEN 1
        ELSE 0
    END AS HasAmountChange,
    CASE
        WHEN swn.PreviousPlannedShipDate IS NULL THEN 0
        WHEN swn.PreviousPlannedShipDate <> swn.PlannedShipDate THEN 1
        ELSE 0
    END AS HasDateChange,
    CASE
        WHEN swn.PreviousProcessStatus IS NULL THEN 'initial_snapshot'
        WHEN swn.PreviousProcessStatus <> swn.ProcessStatus
             AND ABS(swn.NetAmount - ISNULL(swn.PreviousNetAmount, swn.NetAmount)) > @AmountTolerance
            THEN 'status_and_amount_changed'
        WHEN swn.PreviousProcessStatus <> swn.ProcessStatus
            THEN 'status_changed'
        WHEN ABS(swn.NetAmount - ISNULL(swn.PreviousNetAmount, swn.NetAmount)) > @AmountTolerance
             OR swn.PreviousPlannedShipDate <> swn.PlannedShipDate
            THEN 'value_changed'
        ELSE 'no_relevant_change'
    END AS ChangeCategory,
    CASE
        WHEN swn.PreviousProcessStatus IS NULL
            THEN CONCAT('START -> ', swn.ProcessStatus)
        WHEN swn.PreviousProcessStatus <> swn.ProcessStatus
             AND ABS(swn.NetAmount - ISNULL(swn.PreviousNetAmount, swn.NetAmount)) > @AmountTolerance
            THEN CONCAT(swn.PreviousProcessStatus, ' -> ', swn.ProcessStatus, ' | Amount ', CONVERT(VARCHAR(20), swn.PreviousNetAmount), ' -> ', CONVERT(VARCHAR(20), swn.NetAmount))
        WHEN swn.PreviousProcessStatus <> swn.ProcessStatus
            THEN CONCAT(swn.PreviousProcessStatus, ' -> ', swn.ProcessStatus)
        WHEN ABS(swn.NetAmount - ISNULL(swn.PreviousNetAmount, swn.NetAmount)) > @AmountTolerance
            THEN CONCAT('Amount ', CONVERT(VARCHAR(20), swn.PreviousNetAmount), ' -> ', CONVERT(VARCHAR(20), swn.NetAmount))
        WHEN swn.PreviousPlannedShipDate <> swn.PlannedShipDate
            THEN CONCAT('ShipDate ', CONVERT(VARCHAR(10), swn.PreviousPlannedShipDate, 23), ' -> ', CONVERT(VARCHAR(10), swn.PlannedShipDate, 23))
        ELSE 'stable_snapshot'
    END AS ChangeLabel,
    DATEDIFF
    (
        MINUTE,
        swn.SnapshotTime,
        swn.NextSnapshotTime
    ) AS MinutesUntilNextSnapshot
INTO #DetectedChanges
FROM #SnapshotWithNeighbors AS swn;

SELECT
    dc.OrderID,
    dc.SnapshotSequenceNumber,
    dc.SnapshotTime,
    dc.PreviousProcessStatus,
    dc.ProcessStatus,
    dc.NetAmount,
    dc.PreviousNetAmount,
    dc.AmountDelta,
    dc.PreviousPlannedShipDate,
    dc.PlannedShipDate,
    dc.ChangeCategory,
    dc.ChangeLabel,
    dc.MinutesUntilNextSnapshot,
    dc.UpdatedByRole,
    dc.SnapshotComment
FROM #DetectedChanges AS dc
WHERE dc.ChangeCategory <> 'no_relevant_change'
   OR @OnlyShowDetectedChanges = 0
ORDER BY
    dc.OrderID,
    dc.SnapshotSequenceNumber;

-- 3. Pro Auftrag die erkannte Wechselhistorie verdichten.
SELECT
    dc.OrderID,
    COUNT(CASE WHEN dc.ChangeCategory IN ('status_changed', 'status_and_amount_changed') THEN 1 END) AS StatusChangeCount,
    COUNT(CASE WHEN dc.ChangeCategory IN ('value_changed', 'status_and_amount_changed') THEN 1 END) AS ValueChangeCount,
    COUNT(CASE WHEN dc.ChangeCategory = 'initial_snapshot' THEN 1 END) AS InitialSnapshotCount,
    STRING_AGG(dc.ChangeLabel, ' | ')
        WITHIN GROUP (ORDER BY dc.SnapshotSequenceNumber) AS ChangeTimeline
FROM #DetectedChanges AS dc
WHERE dc.ChangeCategory <> 'no_relevant_change'
GROUP BY
    dc.OrderID
ORDER BY
    dc.OrderID;

-- 4. Letzten bekannten Snapshot je Auftrag und fehlenden Nachfolger markieren.
SELECT
    swn.OrderID,
    swn.SnapshotSequenceNumber,
    swn.SnapshotTime AS LastKnownSnapshotTime,
    swn.ProcessStatus AS CurrentProcessStatus,
    swn.NetAmount AS CurrentNetAmount,
    swn.PlannedShipDate AS CurrentPlannedShipDate,
    swn.NextProcessStatus,
    CASE
        WHEN swn.NextSnapshotTime IS NULL THEN 'current_tail'
        ELSE 'has_future_snapshot'
    END AS OutlookCategory,
    CASE
        WHEN swn.NextSnapshotTime IS NULL THEN 'Kein spaeterer Snapshot vorhanden'
        ELSE CONCAT('Naechster Status: ', swn.NextProcessStatus)
    END AS OutlookNote
INTO #CurrentSnapshotOutlook
FROM #SnapshotWithNeighbors AS swn
WHERE swn.NextSnapshotTime IS NULL;

SELECT
    cso.OrderID,
    cso.LastKnownSnapshotTime,
    cso.CurrentProcessStatus,
    cso.CurrentNetAmount,
    cso.CurrentPlannedShipDate,
    cso.OutlookCategory,
    cso.OutlookNote
FROM #CurrentSnapshotOutlook AS cso
ORDER BY
    cso.OrderID;
