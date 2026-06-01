/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "WindowPreviousNextStatus.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "11_WindowFunctions"

purpose: >
  Vergleicht pro Ereignis den aktuellen Status mit dem vorherigen und
  naechsten Status. Das Skript zeigt, wie LAG() und LEAD() zusammen eine
  kompakte Sicht auf Statusfenster, Uebergaenge und Randfaelle liefern.

parameters:
  - name: "@ShowSourceData"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = Demo-Daten vor der Window-Auswertung anzeigen"
  - name: "@OnlyChangedRows"
    sql_type: "BIT"
    direction: "IN"
    required: true
    description: "1 = nur Zeilen mit erkennbarem Unterschied zu Vorher/Nachher anzeigen, 0 = komplette Sequenz zeigen"

result_sets:
  - name: "SourcePreview"
    description: "Optionale Vorschau der Demo-Ereignisse vor der Window-Auswertung"
  - name: "StatusSequenceWithNeighbors"
    description: "Komplette Statusfolge mit vorherigem, aktuellem und naechstem Status je Vorgang"
  - name: "TransitionFocus"
    description: "Fokussierte Sicht auf echte Wechsel und Randzeilen mit Einordnung des Uebergangs"
  - name: "BoundarySummary"
    description: "Zusammenfassung der Start-, End- und stabilen Statusfenster je Vorgang"

dependencies:
  - "tempdb temporary tables"
  - "LAG()"
  - "LEAD()"
  - "ROW_NUMBER()"
  - "SUM()"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/11_WindowFunctions/SQLScripts/WindowPreviousNextStatus.md"
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
    description: "Erstversion des Window-Functions-Labs zum Vergleich von vorherigem, aktuellem und naechstem Status"

notes:
  - "Die Demo verwendet absichtlich Statusfolgen mit stabilen und wechselnden Phasen"
  - "Ein Fokus-Ereignis liegt vor, wenn sich der aktuelle Status vom vorherigen oder naechsten Status unterscheidet"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @ShowSourceData BIT = 1;
DECLARE @OnlyChangedRows BIT = 1;

IF @ShowSourceData NOT IN (0, 1) OR @OnlyChangedRows NOT IN (0, 1)
BEGIN
    THROW 50000, 'Die Parameter muessen als BIT-Werte 0 oder 1 gesetzt sein.', 1;
END;

DROP TABLE IF EXISTS #OrderStatusHistory;
DROP TABLE IF EXISTS #StatusSequence;
DROP TABLE IF EXISTS #TransitionFocus;

CREATE TABLE #OrderStatusHistory
(
    OrderID         VARCHAR(20)  NOT NULL,
    StatusTime      DATETIME2(0) NOT NULL,
    StatusCode      VARCHAR(20)  NOT NULL,
    ResponsibleTeam VARCHAR(30)  NOT NULL,
    StatusNote      VARCHAR(100) NOT NULL
);

INSERT INTO #OrderStatusHistory
(
    OrderID,
    StatusTime,
    StatusCode,
    ResponsibleTeam,
    StatusNote
)
VALUES
    ('ORD-100', '2026-02-10T08:00:00', 'Open',       'Sales',      'Bestellung erfasst'),
    ('ORD-100', '2026-02-10T08:10:00', 'Open',       'Sales',      'Adresspruefung laeuft'),
    ('ORD-100', '2026-02-10T09:00:00', 'Approved',   'Backoffice', 'Freigabe erteilt'),
    ('ORD-100', '2026-02-10T11:15:00', 'Picking',    'Warehouse',  'Kommissionierung gestartet'),
    ('ORD-100', '2026-02-10T12:40:00', 'Shipped',    'Warehouse',  'Paket an Versand uebergeben'),
    ('ORD-200', '2026-02-11T07:45:00', 'Open',       'Sales',      'Bestellung erfasst'),
    ('ORD-200', '2026-02-11T08:30:00', 'Approved',   'Backoffice', 'Freigabe erteilt'),
    ('ORD-200', '2026-02-11T09:20:00', 'Approved',   'Backoffice', 'Freigabe bestaetigt'),
    ('ORD-200', '2026-02-11T10:15:00', 'OnHold',     'Backoffice', 'Rueckfrage zur Zahlungsart'),
    ('ORD-200', '2026-02-11T13:00:00', 'Approved',   'Backoffice', 'Rueckfrage geklaert'),
    ('ORD-200', '2026-02-11T16:25:00', 'Picking',    'Warehouse',  'Kommissionierung gestartet'),
    ('ORD-300', '2026-02-12T09:05:00', 'Open',       'Sales',      'Bestellung erfasst'),
    ('ORD-300', '2026-02-12T09:40:00', 'Cancelled',  'Sales',      'Kunde hat storniert');

IF @ShowSourceData = 1
BEGIN
    SELECT
        osh.OrderID,
        osh.StatusTime,
        osh.StatusCode,
        osh.ResponsibleTeam,
        osh.StatusNote
    FROM #OrderStatusHistory AS osh
    ORDER BY
        osh.OrderID,
        osh.StatusTime;
END;

-- 1. Vorherigen, aktuellen und naechsten Status je Order in einer Sequenz sichtbar machen.
SELECT
    osh.OrderID,
    ROW_NUMBER() OVER
    (
        PARTITION BY osh.OrderID
        ORDER BY osh.StatusTime
    ) AS StatusStepNumber,
    osh.StatusTime,
    osh.StatusCode AS CurrentStatusCode,
    LAG(osh.StatusCode) OVER
    (
        PARTITION BY osh.OrderID
        ORDER BY osh.StatusTime
    ) AS PreviousStatusCode,
    LEAD(osh.StatusCode) OVER
    (
        PARTITION BY osh.OrderID
        ORDER BY osh.StatusTime
    ) AS NextStatusCode,
    LAG(osh.StatusTime) OVER
    (
        PARTITION BY osh.OrderID
        ORDER BY osh.StatusTime
    ) AS PreviousStatusTime,
    LEAD(osh.StatusTime) OVER
    (
        PARTITION BY osh.OrderID
        ORDER BY osh.StatusTime
    ) AS NextStatusTime,
    osh.ResponsibleTeam,
    osh.StatusNote
INTO #StatusSequence
FROM #OrderStatusHistory AS osh;

SELECT
    ss.OrderID,
    ss.StatusStepNumber,
    ss.PreviousStatusCode,
    ss.CurrentStatusCode,
    ss.NextStatusCode,
    ss.PreviousStatusTime,
    ss.StatusTime AS CurrentStatusTime,
    ss.NextStatusTime,
    ss.ResponsibleTeam,
    ss.StatusNote,
    CASE
        WHEN ss.PreviousStatusCode IS NULL THEN 'first_row'
        WHEN ss.NextStatusCode IS NULL THEN 'last_row'
        WHEN ss.PreviousStatusCode = ss.CurrentStatusCode
         AND ss.NextStatusCode = ss.CurrentStatusCode THEN 'stable_middle'
        WHEN ss.PreviousStatusCode = ss.CurrentStatusCode THEN 'leaving_status'
        WHEN ss.NextStatusCode = ss.CurrentStatusCode THEN 'entering_stable_window'
        ELSE 'transition_peak'
    END AS SequenceRole
FROM #StatusSequence AS ss
WHERE @OnlyChangedRows = 0
   OR ss.PreviousStatusCode IS NULL
   OR ss.NextStatusCode IS NULL
   OR ss.PreviousStatusCode <> ss.CurrentStatusCode
   OR ss.NextStatusCode <> ss.CurrentStatusCode
ORDER BY
    ss.OrderID,
    ss.StatusStepNumber;

-- 2. Die fokussierte Uebergangssicht klassifiziert den Unterschied zu Vorher und Nachher.
SELECT
    ss.OrderID,
    ss.StatusStepNumber,
    ss.PreviousStatusCode,
    ss.CurrentStatusCode,
    ss.NextStatusCode,
    CASE
        WHEN ss.PreviousStatusCode IS NULL THEN 'start_of_sequence'
        WHEN ss.PreviousStatusCode = ss.CurrentStatusCode THEN 'same_as_previous'
        ELSE 'different_from_previous'
    END AS PreviousComparison,
    CASE
        WHEN ss.NextStatusCode IS NULL THEN 'end_of_sequence'
        WHEN ss.NextStatusCode = ss.CurrentStatusCode THEN 'same_as_next'
        ELSE 'different_from_next'
    END AS NextComparison,
    CASE
        WHEN ss.PreviousStatusCode IS NULL AND ss.NextStatusCode IS NULL THEN 'single_row_sequence'
        WHEN ss.PreviousStatusCode IS NULL THEN CONCAT('START -> ', ss.CurrentStatusCode)
        WHEN ss.NextStatusCode IS NULL THEN CONCAT(ss.CurrentStatusCode, ' -> END')
        WHEN ss.PreviousStatusCode = ss.CurrentStatusCode
         AND ss.NextStatusCode = ss.CurrentStatusCode THEN CONCAT(ss.CurrentStatusCode, ' stable')
        WHEN ss.PreviousStatusCode = ss.CurrentStatusCode THEN CONCAT(ss.CurrentStatusCode, ' -> ', ss.NextStatusCode)
        WHEN ss.NextStatusCode = ss.CurrentStatusCode THEN CONCAT(ss.PreviousStatusCode, ' -> ', ss.CurrentStatusCode)
        ELSE CONCAT(ss.PreviousStatusCode, ' -> ', ss.CurrentStatusCode, ' -> ', ss.NextStatusCode)
    END AS TransitionLabel,
    DATEDIFF(MINUTE, ss.PreviousStatusTime, ss.StatusTime) AS MinutesSincePreviousStatus,
    DATEDIFF(MINUTE, ss.StatusTime, ss.NextStatusTime) AS MinutesUntilNextStatus,
    ss.ResponsibleTeam,
    ss.StatusNote
INTO #TransitionFocus
FROM #StatusSequence AS ss;

SELECT
    tf.OrderID,
    tf.StatusStepNumber,
    tf.PreviousStatusCode,
    tf.CurrentStatusCode,
    tf.NextStatusCode,
    tf.PreviousComparison,
    tf.NextComparison,
    tf.TransitionLabel,
    tf.MinutesSincePreviousStatus,
    tf.MinutesUntilNextStatus,
    tf.ResponsibleTeam,
    tf.StatusNote
FROM #TransitionFocus AS tf
WHERE @OnlyChangedRows = 0
   OR tf.PreviousComparison = 'different_from_previous'
   OR tf.NextComparison = 'different_from_next'
   OR tf.PreviousComparison = 'start_of_sequence'
   OR tf.NextComparison = 'end_of_sequence'
ORDER BY
    tf.OrderID,
    tf.StatusStepNumber;

-- 3. Start-, End- und stabile Fenster je Order zusammenfassen.
SELECT
    ss.OrderID,
    SUM(CASE WHEN ss.PreviousStatusCode IS NULL THEN 1 ELSE 0 END) AS FirstRowCount,
    SUM(CASE WHEN ss.NextStatusCode IS NULL THEN 1 ELSE 0 END) AS LastRowCount,
    SUM
    (
        CASE
            WHEN ss.PreviousStatusCode = ss.CurrentStatusCode
             AND ss.NextStatusCode = ss.CurrentStatusCode THEN 1
            ELSE 0
        END
    ) AS StableMiddleCount,
    SUM(CASE WHEN ss.PreviousStatusCode <> ss.CurrentStatusCode THEN 1 ELSE 0 END) AS ChangesFromPrevious,
    SUM(CASE WHEN ss.NextStatusCode <> ss.CurrentStatusCode THEN 1 ELSE 0 END) AS ChangesToNext
FROM #StatusSequence AS ss
GROUP BY
    ss.OrderID
ORDER BY
    ss.OrderID;
