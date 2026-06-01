/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "DateBucketGenerator.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "05_Funktionen"

purpose: >
  Erzeugt aus einer kleinen Demo-Zeitreihe stabile Tages-, Wochen- und
  Monats-Buckets, damit Verdichtungen und Reporting-Intervalle in T-SQL
  nachvollziehbar vorbereitet werden koennen.

parameters:
  - name: "@BucketLevel"
    sql_type: "VARCHAR(10)"
    direction: "IN"
    required: false
    description: "Waehlt day, week, month oder all fuer die sichtbaren Buckets"
  - name: "@WeekStart"
    sql_type: "VARCHAR(10)"
    direction: "IN"
    required: false
    description: "Legt Monday oder Sunday als Wochenstart fuer das Wochen-Bucketing fest"
  - name: "@IncludeEmptyBuckets"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 zeigt auch Buckets ohne Messwert, 0 blendet leere Buckets aus"

result_sets:
  - name: "BucketRows"
    description: "Zeigt je Bucket die Start- und Endgrenzen sowie aggregierte Demo-Messwerte"
  - name: "BucketSummary"
    description: "Verdichtet die Bucket-Erzeugung nach Granularitaet und sichtbaren Perioden"
  - name: "BucketGuide"
    description: "Erklaert die aktive Parameterkombination und den didaktischen Einsatzzweck"

dependencies:
  - "tempdb temporary tables"
  - "CTE"
  - "DATEADD"
  - "DATEDIFF"
  - "DATEPART"
  - "ROW_NUMBER"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/05_Funktionen/SQLScripts/DateBucketGenerator.md"
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
    description: "Erstversion fuer didaktische Tages-, Wochen- und Monats-Buckets"

notes:
  - "Das Skript arbeitet ausschliesslich mit einer temporaeren Demo-Zeitreihe."
  - "Wochen-Buckets werden explizit ueber den Parameter WeekStart statt ueber DATEFIRST erklaert."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @BucketLevel VARCHAR(10) = 'all';
DECLARE @WeekStart VARCHAR(10) = 'monday';
DECLARE @IncludeEmptyBuckets BIT = 1;

IF @BucketLevel NOT IN ('day', 'week', 'month', 'all')
BEGIN
    THROW 50610, '@BucketLevel muss day, week, month oder all sein.', 1;
END;

IF @WeekStart NOT IN ('monday', 'sunday')
BEGIN
    THROW 50611, '@WeekStart muss monday oder sunday sein.', 1;
END;

IF @IncludeEmptyBuckets NOT IN (0, 1)
BEGIN
    THROW 50612, '@IncludeEmptyBuckets muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #DailySignals;

CREATE TABLE #DailySignals
(
    SignalDate DATE NOT NULL PRIMARY KEY,
    RegionCode CHAR(2) NOT NULL,
    OrderCount INT NOT NULL,
    NetAmount DECIMAL(12, 2) NOT NULL
);

INSERT INTO #DailySignals
(
    SignalDate,
    RegionCode,
    OrderCount,
    NetAmount
)
VALUES
    ('2026-01-27', 'DE', 7, 1420.00),
    ('2026-01-28', 'DE', 9, 1880.00),
    ('2026-01-30', 'AT', 6, 1210.00),
    ('2026-02-02', 'DE', 8, 1775.00),
    ('2026-02-03', 'CH', 5, 980.00),
    ('2026-02-05', 'AT', 11, 2310.00),
    ('2026-02-09', 'DE', 10, 2140.00),
    ('2026-02-12', 'CH', 4, 870.00),
    ('2026-02-18', 'DE', 13, 2695.00),
    ('2026-02-23', 'AT', 8, 1650.00),
    ('2026-03-02', 'DE', 12, 2510.00),
    ('2026-03-08', 'CH', 7, 1490.00),
    ('2026-03-12', 'AT', 9, 1975.00),
    ('2026-03-17', 'DE', 14, 2980.00),
    ('2026-03-24', 'CH', 6, 1335.00),
    ('2026-03-29', 'AT', 5, 1105.00);

DECLARE @MinDate DATE = (SELECT MIN(ds.SignalDate) FROM #DailySignals AS ds);
DECLARE @MaxDate DATE = (SELECT MAX(ds.SignalDate) FROM #DailySignals AS ds);

;WITH NumberSeries AS
(
    SELECT TOP (DATEDIFF(DAY, @MinDate, @MaxDate) + 1)
        ROW_NUMBER() OVER (ORDER BY (SELECT 1)) - 1 AS DayOffset
    FROM sys.all_objects
),
DateSpan AS
(
    SELECT
        DATEADD(DAY, ns.DayOffset, @MinDate) AS CalendarDate
    FROM NumberSeries AS ns
),
BaseCalendar AS
(
    SELECT
        ds.CalendarDate,
        DATEADD(DAY, 1 - DAY(ds.CalendarDate), ds.CalendarDate) AS MonthStartDate,
        DATEADD(
            DAY,
            CASE
                WHEN @WeekStart = 'monday' THEN -((DATEDIFF(DAY, '19000101', ds.CalendarDate) + 700000) % 7)
                ELSE -((DATEDIFF(DAY, '19000107', ds.CalendarDate) + 700000) % 7)
            END,
            ds.CalendarDate
        ) AS WeekStartDate
    FROM DateSpan AS ds
),
ExpandedBuckets AS
(
    SELECT
        CAST('day' AS VARCHAR(10)) AS BucketLevel,
        bc.CalendarDate AS BucketStartDate,
        bc.CalendarDate AS BucketLabelDate
    FROM BaseCalendar AS bc

    UNION ALL

    SELECT DISTINCT
        CAST('week' AS VARCHAR(10)) AS BucketLevel,
        bc.WeekStartDate AS BucketStartDate,
        bc.WeekStartDate AS BucketLabelDate
    FROM BaseCalendar AS bc

    UNION ALL

    SELECT DISTINCT
        CAST('month' AS VARCHAR(10)) AS BucketLevel,
        bc.MonthStartDate AS BucketStartDate,
        bc.MonthStartDate AS BucketLabelDate
    FROM BaseCalendar AS bc
),
AggregatedBuckets AS
(
    SELECT
        eb.BucketLevel,
        eb.BucketStartDate,
        CASE eb.BucketLevel
            WHEN 'day' THEN DATEADD(DAY, 1, eb.BucketStartDate)
            WHEN 'week' THEN DATEADD(DAY, 7, eb.BucketStartDate)
            ELSE DATEADD(MONTH, 1, eb.BucketStartDate)
        END AS BucketEndExclusive,
        COUNT(ds.SignalDate) AS MeasurementDays,
        SUM(ISNULL(ds.OrderCount, 0)) AS TotalOrders,
        SUM(ISNULL(ds.NetAmount, 0.00)) AS TotalNetAmount,
        MIN(ds.SignalDate) AS FirstSignalDate,
        MAX(ds.SignalDate) AS LastSignalDate,
        COUNT(DISTINCT ds.RegionCode) AS ActiveRegions
    FROM ExpandedBuckets AS eb
    LEFT JOIN #DailySignals AS ds
        ON ds.SignalDate >= eb.BucketStartDate
       AND ds.SignalDate < CASE eb.BucketLevel
                               WHEN 'day' THEN DATEADD(DAY, 1, eb.BucketStartDate)
                               WHEN 'week' THEN DATEADD(DAY, 7, eb.BucketStartDate)
                               ELSE DATEADD(MONTH, 1, eb.BucketStartDate)
                           END
    GROUP BY
        eb.BucketLevel,
        eb.BucketStartDate
),
VisibleBuckets AS
(
    SELECT
        ab.BucketLevel,
        ab.BucketStartDate,
        DATEADD(DAY, -1, ab.BucketEndExclusive) AS BucketEndDate,
        ab.MeasurementDays,
        ab.TotalOrders,
        ab.TotalNetAmount,
        ab.FirstSignalDate,
        ab.LastSignalDate,
        ab.ActiveRegions,
        CASE ab.BucketLevel
            WHEN 'day' THEN CONVERT(VARCHAR(10), ab.BucketStartDate, 23)
            WHEN 'week' THEN CONCAT('week-of-', CONVERT(VARCHAR(10), ab.BucketStartDate, 23))
            ELSE CONCAT(
                DATENAME(YEAR, ab.BucketStartDate),
                '-',
                RIGHT(CONCAT('0', DATEPART(MONTH, ab.BucketStartDate)), 2)
            )
        END AS BucketLabel,
        ROW_NUMBER() OVER (
            PARTITION BY ab.BucketLevel
            ORDER BY ab.BucketStartDate
        ) AS BucketSequence
    FROM AggregatedBuckets AS ab
    WHERE (@BucketLevel = 'all' OR ab.BucketLevel = @BucketLevel)
      AND (@IncludeEmptyBuckets = 1 OR ab.MeasurementDays > 0)
)
SELECT
    vb.BucketLevel,
    vb.BucketSequence,
    vb.BucketLabel,
    vb.BucketStartDate,
    vb.BucketEndDate,
    vb.MeasurementDays,
    vb.TotalOrders,
    vb.TotalNetAmount,
    vb.ActiveRegions,
    vb.FirstSignalDate,
    vb.LastSignalDate,
    CASE
        WHEN vb.MeasurementDays = 0 THEN 'empty-bucket'
        WHEN vb.BucketLevel = 'day' THEN 'day-grain'
        WHEN vb.BucketLevel = 'week' THEN 'weekly-rollup'
        ELSE 'monthly-rollup'
    END AS TeachingBucketType
FROM VisibleBuckets AS vb
ORDER BY
    CASE vb.BucketLevel
        WHEN 'day' THEN 1
        WHEN 'week' THEN 2
        ELSE 3
    END,
    vb.BucketStartDate;

SELECT
    vb.BucketLevel,
    COUNT(*) AS VisibleBucketCount,
    SUM(CASE WHEN vb.MeasurementDays = 0 THEN 1 ELSE 0 END) AS EmptyBucketCount,
    SUM(vb.MeasurementDays) AS CoveredMeasurementDays,
    SUM(vb.TotalOrders) AS CoveredOrders,
    SUM(vb.TotalNetAmount) AS CoveredNetAmount,
    MIN(vb.BucketStartDate) AS FirstVisibleBucket,
    MAX(vb.BucketEndDate) AS LastVisibleBucket
FROM VisibleBuckets AS vb
GROUP BY
    vb.BucketLevel
ORDER BY
    CASE vb.BucketLevel
        WHEN 'day' THEN 1
        WHEN 'week' THEN 2
        ELSE 3
    END;

SELECT
    @BucketLevel AS RequestedBucketLevel,
    @WeekStart AS RequestedWeekStart,
    @IncludeEmptyBuckets AS IncludeEmptyBuckets,
    @MinDate AS SourceMinDate,
    @MaxDate AS SourceMaxDate,
    CASE
        WHEN @BucketLevel = 'day' THEN 'Zeigt die feinste Granularitaet fuer taegliche Linien oder Debugging.'
        WHEN @BucketLevel = 'week' THEN 'Gruppiert die Demo-Zeitreihe in stabile Wochen-Buckets fuer Rollups.'
        WHEN @BucketLevel = 'month' THEN 'Verdichtet den Zeitraum auf Monatsanfang und Monatsende.'
        ELSE 'Vergleicht Tages-, Wochen- und Monats-Buckets auf derselben Demo-Zeitreihe.'
    END AS TeachingFocus,
    CASE
        WHEN @WeekStart = 'monday' THEN 'Wochenstart folgt einem ISO-nahen Montag-Muster.'
        ELSE 'Wochenstart ist auf Sonntag verschoben, um alternative Reports zu demonstrieren.'
    END AS WeekStartNote;
