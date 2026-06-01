/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "FunctionWeekNumberExamples.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "05_Funktionen"

purpose: >
  Vergleicht Wochenlogik in T-SQL fuer ISO-Wochen, DATEFIRST-basierte
  Kalenderwochen mit Sonntag oder Montag als Wochenstart und erklaert
  typische Jahreswechsel-Effekte an reproduzierbaren Demo-Daten.

parameters:
  - name: "@CalendarMode"
    sql_type: "VARCHAR(20)"
    direction: "IN"
    required: false
    description: "Filtert all, iso, us-sunday oder us-monday fuer die sichtbare Lehrperspektive"
  - name: "@AnchorDate"
    sql_type: "DATE"
    direction: "IN"
    required: false
    description: "Legt den Referenztag fest, um den herum eine Boundary-Vorschau erzeugt wird"
  - name: "@PreviewDays"
    sql_type: "TINYINT"
    direction: "IN"
    required: false
    description: "Steuert die Anzahl der Tage vor und nach dem Referenztag in der Vorschau"

result_sets:
  - name: "WeekNumberExamples"
    description: "Zeigt pro Beispieldatum ISO-, Sonntag- und Montag-Wochendefinitionen im direkten Vergleich"
  - name: "WeekDefinitionSummary"
    description: "Verdichtet die Unterschiede nach Perspektive und markiert Jahreswechsel-Effekte"
  - name: "BoundaryPreview"
    description: "Erzeugt rund um den Referenztag eine kleine Tagesachse mit Wochenstarts und Wechselmarken"

dependencies:
  - "tempdb temporary tables"
  - "DATEADD"
  - "DATEDIFF"
  - "DATEPART"
  - "DATENAME"
  - "SET DATEFIRST"
  - "ROW_NUMBER"
  - "CASE"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/05_Funktionen/SQLScripts/FunctionWeekNumberExamples.md"
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
    description: "Erstversion fuer didaktische Beispiele zu Wochenlogik und Kalenderdefinitionen"

notes:
  - "Das Skript arbeitet mit tempdb-Demo-Daten und stellt Kalenderdefinitionen bewusst nebeneinander."
  - "DATEFIRST wird fuer die Lehrvergleiche kurz umgestellt und am Ende wiederhergestellt."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @CalendarMode VARCHAR(20) = 'all';
DECLARE @AnchorDate DATE = '2026-01-01';
DECLARE @PreviewDays TINYINT = 6;
DECLARE @OriginalDateFirst INT = @@DATEFIRST;

IF @CalendarMode NOT IN ('all', 'iso', 'us-sunday', 'us-monday')
BEGIN
    THROW 50820, '@CalendarMode muss all, iso, us-sunday oder us-monday sein.', 1;
END;

IF @PreviewDays NOT BETWEEN 3 AND 14
BEGIN
    THROW 50821, '@PreviewDays muss zwischen 3 und 14 liegen.', 1;
END;

DROP TABLE IF EXISTS #WeekSampleDates;
DROP TABLE IF EXISTS #WeekComparisons;

CREATE TABLE #WeekSampleDates
(
    SampleId INT NOT NULL PRIMARY KEY,
    SampleGroup VARCHAR(20) NOT NULL,
    SampleLabel VARCHAR(80) NOT NULL,
    SampleDate DATE NOT NULL
);

CREATE TABLE #WeekComparisons
(
    SampleId INT NOT NULL PRIMARY KEY,
    SampleGroup VARCHAR(20) NOT NULL,
    SampleLabel VARCHAR(80) NOT NULL,
    SampleDate DATE NOT NULL,
    WeekdayName VARCHAR(30) NOT NULL,
    CalendarYear INT NOT NULL,
    IsoWeekYear INT NOT NULL,
    IsoWeekNumber INT NOT NULL,
    IsoWeekStartDate DATE NOT NULL,
    SundayWeekNumber INT NOT NULL,
    SundayWeekStartDate DATE NOT NULL,
    MondayWeekNumber INT NOT NULL,
    MondayWeekStartDate DATE NOT NULL
);

INSERT INTO #WeekSampleDates
(
    SampleId,
    SampleGroup,
    SampleLabel,
    SampleDate
)
VALUES
    (1, 'year-boundary', 'Last Monday of previous year', '2025-12-29'),
    (2, 'year-boundary', 'New Years Eve', '2025-12-31'),
    (3, 'year-boundary', 'New Years Day', '2026-01-01'),
    (4, 'year-boundary', 'First Sunday of new year', '2026-01-04'),
    (5, 'year-boundary', 'First Monday of new year', '2026-01-05'),
    (6, 'mid-year', 'Mid-year Wednesday', '2026-06-17'),
    (7, 'mid-year', 'Month boundary Monday', '2026-08-31'),
    (8, 'mid-year', 'Month boundary Tuesday', '2026-09-01');

;WITH PreviewOffsets AS
(
    SELECT TOP ((@PreviewDays * 2) + 1)
        ROW_NUMBER() OVER (ORDER BY (SELECT 1)) - (@PreviewDays + 1) AS DayOffset
    FROM sys.all_objects
)
INSERT INTO #WeekSampleDates
(
    SampleId,
    SampleGroup,
    SampleLabel,
    SampleDate
)
SELECT
    100 + ROW_NUMBER() OVER (ORDER BY po.DayOffset) AS SampleId,
    'anchor-preview' AS SampleGroup,
    CONCAT(
        'Anchor ',
        CASE
            WHEN po.DayOffset = 0 THEN 'day'
            WHEN po.DayOffset > 0 THEN CONCAT('+', po.DayOffset)
            ELSE CAST(po.DayOffset AS VARCHAR(5))
        END
    ) AS SampleLabel,
    DATEADD(DAY, po.DayOffset, @AnchorDate) AS SampleDate
FROM PreviewOffsets AS po;

INSERT INTO #WeekComparisons
(
    SampleId,
    SampleGroup,
    SampleLabel,
    SampleDate,
    WeekdayName,
    CalendarYear,
    IsoWeekYear,
    IsoWeekNumber,
    IsoWeekStartDate,
    SundayWeekNumber,
    SundayWeekStartDate,
    MondayWeekNumber,
    MondayWeekStartDate
)
SELECT
    wsd.SampleId,
    wsd.SampleGroup,
    wsd.SampleLabel,
    wsd.SampleDate,
    DATENAME(WEEKDAY, wsd.SampleDate) AS WeekdayName,
    YEAR(wsd.SampleDate) AS CalendarYear,
    YEAR(
        DATEADD(
            DAY,
            3 - ((DATEDIFF(DAY, '19000101', wsd.SampleDate) % 7 + 7) % 7),
            wsd.SampleDate
        )
    ) AS IsoWeekYear,
    DATEPART(ISO_WEEK, wsd.SampleDate) AS IsoWeekNumber,
    DATEADD(
        DAY,
        -((DATEDIFF(DAY, '19000101', wsd.SampleDate) % 7 + 7) % 7),
        wsd.SampleDate
    ) AS IsoWeekStartDate,
    0,
    DATEADD(
        DAY,
        -((DATEDIFF(DAY, '19000107', wsd.SampleDate) % 7 + 7) % 7),
        wsd.SampleDate
    ) AS SundayWeekStartDate,
    0,
    DATEADD(
        DAY,
        -((DATEDIFF(DAY, '19000101', wsd.SampleDate) % 7 + 7) % 7),
        wsd.SampleDate
    ) AS MondayWeekStartDate
FROM #WeekSampleDates AS wsd;

SET DATEFIRST 7;

UPDATE wc
SET wc.SundayWeekNumber = DATEPART(WEEK, wc.SampleDate)
FROM #WeekComparisons AS wc;

SET DATEFIRST 1;

UPDATE wc
SET wc.MondayWeekNumber = DATEPART(WEEK, wc.SampleDate)
FROM #WeekComparisons AS wc;

SET DATEFIRST @OriginalDateFirst;

;WITH WeekNumberExamples AS
(
    SELECT
        wc.SampleId,
        wc.SampleGroup,
        wc.SampleLabel,
        wc.SampleDate,
        wc.WeekdayName,
        wc.CalendarYear,
        wc.IsoWeekYear,
        wc.IsoWeekNumber,
        wc.IsoWeekStartDate,
        wc.SundayWeekNumber,
        wc.SundayWeekStartDate,
        wc.MondayWeekNumber,
        wc.MondayWeekStartDate,
        CASE
            WHEN wc.CalendarYear <> wc.IsoWeekYear THEN 'iso-week-year-shift'
            WHEN wc.SundayWeekNumber <> wc.MondayWeekNumber THEN 'datefirst-difference'
            ELSE 'same-week-number'
        END AS TeachingFlag,
        CASE
            WHEN wc.CalendarYear <> wc.IsoWeekYear THEN 'ISO-Woche gehoert bereits zum Nachbarjahr.'
            WHEN wc.SundayWeekNumber <> wc.MondayWeekNumber THEN 'DATEFIRST aendert die Wochenzaehlung fuer dieses Datum.'
            ELSE 'Alle Lehrperspektiven liefern hier dieselbe Kalenderwoche.'
        END AS TeachingNote
    FROM #WeekComparisons AS wc
)
SELECT
    wne.SampleGroup,
    wne.SampleLabel,
    wne.SampleDate,
    wne.WeekdayName,
    wne.CalendarYear,
    wne.IsoWeekYear,
    wne.IsoWeekNumber,
    wne.IsoWeekStartDate,
    wne.SundayWeekNumber,
    wne.SundayWeekStartDate,
    wne.MondayWeekNumber,
    wne.MondayWeekStartDate,
    CASE
        WHEN @CalendarMode = 'iso' THEN CONCAT('ISO ', wne.IsoWeekYear, '-W', RIGHT(CONCAT('0', wne.IsoWeekNumber), 2))
        WHEN @CalendarMode = 'us-sunday' THEN CONCAT('Sunday-start week ', wne.SundayWeekNumber)
        WHEN @CalendarMode = 'us-monday' THEN CONCAT('Monday-start week ', wne.MondayWeekNumber)
        ELSE CONCAT(
            'ISO ',
            wne.IsoWeekYear,
            '-W',
            RIGHT(CONCAT('0', wne.IsoWeekNumber), 2),
            ' | Sun ',
            wne.SundayWeekNumber,
            ' | Mon ',
            wne.MondayWeekNumber
        )
    END AS FocusedWeekLabel,
    wne.TeachingFlag,
    wne.TeachingNote
FROM WeekNumberExamples AS wne
ORDER BY
    CASE wne.SampleGroup
        WHEN 'year-boundary' THEN 1
        WHEN 'mid-year' THEN 2
        ELSE 3
    END,
    wne.SampleDate,
    wne.SampleId;

SELECT
    'iso' AS CalendarPerspective,
    COUNT(*) AS ExampleCount,
    MIN(wc.IsoWeekNumber) AS MinimumWeekNumber,
    MAX(wc.IsoWeekNumber) AS MaximumWeekNumber,
    SUM(CASE WHEN wc.CalendarYear <> wc.IsoWeekYear THEN 1 ELSE 0 END) AS YearBoundaryShiftCount,
    MIN(wc.IsoWeekStartDate) AS EarliestWeekStart,
    MAX(wc.IsoWeekStartDate) AS LatestWeekStart
FROM #WeekComparisons AS wc
WHERE @CalendarMode IN ('all', 'iso')

UNION ALL

SELECT
    'us-sunday' AS CalendarPerspective,
    COUNT(*) AS ExampleCount,
    MIN(wc.SundayWeekNumber) AS MinimumWeekNumber,
    MAX(wc.SundayWeekNumber) AS MaximumWeekNumber,
    SUM(CASE WHEN wc.SundayWeekNumber <> wc.MondayWeekNumber THEN 1 ELSE 0 END) AS YearBoundaryShiftCount,
    MIN(wc.SundayWeekStartDate) AS EarliestWeekStart,
    MAX(wc.SundayWeekStartDate) AS LatestWeekStart
FROM #WeekComparisons AS wc
WHERE @CalendarMode IN ('all', 'us-sunday')

UNION ALL

SELECT
    'us-monday' AS CalendarPerspective,
    COUNT(*) AS ExampleCount,
    MIN(wc.MondayWeekNumber) AS MinimumWeekNumber,
    MAX(wc.MondayWeekNumber) AS MaximumWeekNumber,
    SUM(CASE WHEN wc.SundayWeekNumber <> wc.MondayWeekNumber THEN 1 ELSE 0 END) AS YearBoundaryShiftCount,
    MIN(wc.MondayWeekStartDate) AS EarliestWeekStart,
    MAX(wc.MondayWeekStartDate) AS LatestWeekStart
FROM #WeekComparisons AS wc
WHERE @CalendarMode IN ('all', 'us-monday')
ORDER BY
    CalendarPerspective;

;WITH BoundaryPreview AS
(
    SELECT
        ROW_NUMBER() OVER (ORDER BY wc.SampleDate, wc.SampleId) AS PreviewOrder,
        wc.SampleLabel,
        wc.SampleDate,
        wc.WeekdayName,
        wc.IsoWeekNumber,
        wc.IsoWeekYear,
        wc.SundayWeekNumber,
        wc.MondayWeekNumber,
        wc.IsoWeekStartDate,
        wc.SundayWeekStartDate,
        wc.MondayWeekStartDate
    FROM #WeekComparisons AS wc
    WHERE wc.SampleGroup = 'anchor-preview'
)
SELECT
    bp.PreviewOrder,
    bp.SampleLabel,
    bp.SampleDate,
    bp.WeekdayName,
    bp.IsoWeekYear,
    bp.IsoWeekNumber,
    bp.SundayWeekNumber,
    bp.MondayWeekNumber,
    bp.IsoWeekStartDate,
    bp.SundayWeekStartDate,
    bp.MondayWeekStartDate,
    CASE
        WHEN bp.SampleDate = @AnchorDate THEN 'anchor-date'
        WHEN YEAR(bp.SampleDate) <> YEAR(@AnchorDate) THEN 'cross-year-preview'
        WHEN bp.IsoWeekStartDate <> bp.MondayWeekStartDate THEN 'unexpected-difference'
        ELSE 'same-year-preview'
    END AS PreviewFlag
FROM BoundaryPreview AS bp
ORDER BY
    bp.PreviewOrder;
