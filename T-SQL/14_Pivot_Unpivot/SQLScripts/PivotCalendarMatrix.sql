/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "PivotCalendarMatrix.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "14_Pivot_Unpivot"

purpose: >
  Baut eine didaktische Kalender-Matrix per PIVOT auf. Das Skript nutzt
  Demo-Arbeitsdaten, leitet daraus je nach Parameter Monats- oder
  ISO-Wochen-Buckets ab und verdichtet die geplanten Stunden zu einer
  dynamischen Matrix pro Team und Aktivitaet.

parameters:
  - name: "@CalendarMode"
    sql_type: "varchar(10)"
    direction: "IN"
    required: false
    description: "Steuert die Kalendersicht mit den Werten Month oder Week."
  - name: "@StartDate"
    sql_type: "date"
    direction: "IN"
    required: false
    description: "Untergrenze fuer die Demo-Daten, die in die Kalender-Matrix eingehen."
  - name: "@ExecutePivot"
    sql_type: "bit"
    direction: "IN"
    required: false
    description: "Fuehrt die generierte Pivot-Anweisung aus, wenn der Wert 1 ist."

result_sets:
  - name: "CalendarSourcePreview"
    description: "Zeigt die Demo-Arbeitsdaten innerhalb des gewaehlten Datumsfensters."
  - name: "CalendarBucketPreview"
    description: "Listet die abgeleiteten Monats- oder Wochen-Buckets inklusive Sortierreihenfolge."
  - name: "DynamicPivotStatementPreview"
    description: "Zeigt die generierte Pivot-Anweisung fuer die Kalender-Matrix."
  - name: "CalendarMatrix"
    description: "Gibt die Kalender-Matrix mit Stunden pro Team, Aktivitaet und Kalender-Bucket aus."

dependencies:
  - "DATEPART"
  - "DATENAME"
  - "STRING_AGG"
  - "QUOTENAME"
  - "sp_executesql"
  - "temporary tables"
  - "THROW"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/14_Pivot_Unpivot/SQLScripts/PivotCalendarMatrix.md"
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
    description: "Erstversion einer Kalender-Matrix fuer Monats- und ISO-Wochen-Pivots."

notes:
  - "Die Erstversion arbeitet ausschliesslich mit temporaeren Demo-Tabellen."
  - "Die Kalender-Spalten werden dynamisch aus dem gefilterten Demo-Zeitraum erzeugt."
  - "ISO-Wochen werden ueber YEAR(TaskDate) und DATEPART(ISO_WEEK, TaskDate) beschriftet."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @CalendarMode VARCHAR(10) = 'Month';
DECLARE @StartDate DATE = '2026-01-01';
DECLARE @ExecutePivot BIT = 1;

DROP TABLE IF EXISTS #WorklogSource;
DROP TABLE IF EXISTS #CalendarBucketStage;
DROP TABLE IF EXISTS #ApprovedCalendarBuckets;

CREATE TABLE #WorklogSource
(
    TeamName        VARCHAR(20)     NOT NULL,
    ActivityName    VARCHAR(30)     NOT NULL,
    TaskDate        DATE            NOT NULL,
    PlannedHours    DECIMAL(10,2)   NOT NULL
);

INSERT INTO #WorklogSource
(
    TeamName,
    ActivityName,
    TaskDate,
    PlannedHours
)
VALUES
    ('Team Alpha', 'Analysis',      '2026-01-05', 6.00),
    ('Team Alpha', 'Development',   '2026-01-12', 10.00),
    ('Team Alpha', 'Development',   '2026-02-03', 14.00),
    ('Team Alpha', 'Testing',       '2026-02-10', 8.00),
    ('Team Alpha', 'Deployment',    '2026-03-02', 4.00),
    ('Team Alpha', 'Support',       '2026-03-18', 3.50),
    ('Team Beta',  'Analysis',      '2026-01-08', 5.00),
    ('Team Beta',  'Development',   '2026-01-21', 12.50),
    ('Team Beta',  'Development',   '2026-02-17', 11.00),
    ('Team Beta',  'Testing',       '2026-02-24', 9.50),
    ('Team Beta',  'Deployment',    '2026-03-12', 6.00),
    ('Team Beta',  'Support',       '2026-03-26', 2.50),
    ('Team Gamma', 'Analysis',      '2026-01-15', 7.00),
    ('Team Gamma', 'Development',   '2026-02-05', 13.00),
    ('Team Gamma', 'Testing',       '2026-02-19', 10.00),
    ('Team Gamma', 'Testing',       '2026-03-05', 6.50),
    ('Team Gamma', 'Deployment',    '2026-03-23', 5.50),
    ('Team Gamma', 'Support',       '2026-04-02', 4.00);

IF @CalendarMode IS NULL OR UPPER(@CalendarMode) NOT IN ('MONTH', 'WEEK')
BEGIN
    THROW 50071, 'PivotCalendarMatrix requires @CalendarMode = Month or Week.', 1;
END;

IF @StartDate IS NULL
BEGIN
    THROW 50072, 'PivotCalendarMatrix requires a non-null @StartDate value.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM #WorklogSource AS src
    WHERE src.TaskDate >= @StartDate
)
BEGIN
    THROW 50073, 'PivotCalendarMatrix found no demo worklog rows for the selected @StartDate.', 1;
END;

SELECT
    CASE
        WHEN UPPER(@CalendarMode) = 'MONTH'
            THEN CONCAT(LEFT(DATENAME(MONTH, src.TaskDate), 3), '-', DATEPART(YEAR, src.TaskDate))
        ELSE CONCAT(DATEPART(YEAR, src.TaskDate), '-W', RIGHT('00' + CAST(DATEPART(ISO_WEEK, src.TaskDate) AS VARCHAR(2)), 2))
    END AS BucketLabel,
    CASE
        WHEN UPPER(@CalendarMode) = 'MONTH'
            THEN DATEPART(YEAR, src.TaskDate) * 100 + DATEPART(MONTH, src.TaskDate)
        ELSE DATEPART(YEAR, src.TaskDate) * 100 + DATEPART(ISO_WEEK, src.TaskDate)
    END AS BucketSortKey
INTO #CalendarBucketStage
FROM #WorklogSource AS src
WHERE src.TaskDate >= @StartDate
GROUP BY
    CASE
        WHEN UPPER(@CalendarMode) = 'MONTH'
            THEN CONCAT(LEFT(DATENAME(MONTH, src.TaskDate), 3), '-', DATEPART(YEAR, src.TaskDate))
        ELSE CONCAT(DATEPART(YEAR, src.TaskDate), '-W', RIGHT('00' + CAST(DATEPART(ISO_WEEK, src.TaskDate) AS VARCHAR(2)), 2))
    END,
    CASE
        WHEN UPPER(@CalendarMode) = 'MONTH'
            THEN DATEPART(YEAR, src.TaskDate) * 100 + DATEPART(MONTH, src.TaskDate)
        ELSE DATEPART(YEAR, src.TaskDate) * 100 + DATEPART(ISO_WEEK, src.TaskDate)
    END;

SELECT
    cbs.BucketLabel,
    cbs.BucketSortKey,
    QUOTENAME(cbs.BucketLabel) AS SafeColumnName
INTO #ApprovedCalendarBuckets
FROM #CalendarBucketStage AS cbs;

IF NOT EXISTS
(
    SELECT 1
    FROM #ApprovedCalendarBuckets
)
BEGIN
    THROW 50074, 'PivotCalendarMatrix could not derive any calendar buckets from the source set.', 1;
END;

DECLARE @PivotColumnList NVARCHAR(MAX);
DECLARE @PivotSelectList NVARCHAR(MAX);
DECLARE @TotalExpression NVARCHAR(MAX);
DECLARE @DynamicSql NVARCHAR(MAX);

SELECT
    @PivotColumnList = STRING_AGG(acb.SafeColumnName, ', ')
        WITHIN GROUP (ORDER BY acb.BucketSortKey),
    @PivotSelectList = STRING_AGG
    (
        'COALESCE(p.' + acb.SafeColumnName + ', 0.00) AS ' + acb.SafeColumnName,
        ', '
    ) WITHIN GROUP (ORDER BY acb.BucketSortKey),
    @TotalExpression = STRING_AGG
    (
        'COALESCE(p.' + acb.SafeColumnName + ', 0.00)',
        ' + '
    ) WITHIN GROUP (ORDER BY acb.BucketSortKey)
FROM #ApprovedCalendarBuckets AS acb;

IF @PivotColumnList IS NULL OR @PivotSelectList IS NULL OR @TotalExpression IS NULL
BEGIN
    THROW 50075, 'PivotCalendarMatrix could not assemble the dynamic calendar projection.', 1;
END;

SET @DynamicSql = N'
WITH calendarized_source AS
(
    SELECT
        src.TeamName,
        src.ActivityName,
        CASE
            WHEN UPPER(@RuntimeCalendarMode) = ''MONTH''
                THEN CONCAT(LEFT(DATENAME(MONTH, src.TaskDate), 3), ''-'', DATEPART(YEAR, src.TaskDate))
            ELSE CONCAT(DATEPART(YEAR, src.TaskDate), ''-W'', RIGHT(''00'' + CAST(DATEPART(ISO_WEEK, src.TaskDate) AS VARCHAR(2)), 2))
        END AS BucketLabel,
        src.PlannedHours
    FROM #WorklogSource AS src
    WHERE src.TaskDate >= @RuntimeStartDate
)
SELECT
    p.TeamName,
    p.ActivityName,
    ' + @PivotSelectList + N',
    CAST(' + @TotalExpression + N' AS DECIMAL(10,2)) AS TotalPlannedHours
FROM calendarized_source AS src
PIVOT
(
    SUM(src.PlannedHours)
    FOR src.BucketLabel IN (' + @PivotColumnList + N')
) AS p
ORDER BY
    p.TeamName,
    p.ActivityName;';

SELECT
    src.TeamName,
    src.ActivityName,
    src.TaskDate,
    src.PlannedHours
FROM #WorklogSource AS src
WHERE src.TaskDate >= @StartDate
ORDER BY
    src.TaskDate,
    src.TeamName,
    src.ActivityName;

SELECT
    acb.BucketSortKey,
    acb.BucketLabel,
    acb.SafeColumnName,
    @CalendarMode AS CalendarMode
FROM #ApprovedCalendarBuckets AS acb
ORDER BY
    acb.BucketSortKey;

SELECT
    @DynamicSql AS DynamicPivotSql;

IF @ExecutePivot = 1
BEGIN
    EXEC sys.sp_executesql
        @stmt = @DynamicSql,
        @params = N'@RuntimeCalendarMode VARCHAR(10), @RuntimeStartDate DATE',
        @RuntimeCalendarMode = @CalendarMode,
        @RuntimeStartDate = @StartDate;
END;
ELSE
BEGIN
    SELECT
        CAST('Execution skipped because @ExecutePivot = 0.' AS NVARCHAR(100)) AS ExecutionStatus,
        @CalendarMode AS CalendarMode,
        @StartDate AS StartDate;
END;
