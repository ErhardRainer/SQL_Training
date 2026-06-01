/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "PivotQuarterMatrixTemplate.sql"
script_version: "1.0"
script_type: "template"
chapter: "14_Pivot_Unpivot"

purpose: >
  Liefert eine didaktische Vorlage fuer Quartalsmatrizen mit PIVOT. Das
  Skript kombiniert Demo-Daten, eine stabile Quartals-Whitelist, eine
  verdichtete Quartalsaggregation und dynamisches SQL, damit pro Portfolio
  und Kennzahlengruppe eine nachvollziehbare Quarter-Matrix entsteht.

parameters:
  - name: "@ReportYear"
    sql_type: "int"
    direction: "IN"
    required: false
    description: "Filtert die Demo-Quelle auf ein Berichtsjahr fuer die Quartalsmatrix."
  - name: "@IncludeQuarterTotal"
    sql_type: "bit"
    direction: "IN"
    required: false
    description: "Erweitert die Matrix um eine berechnete TotalQuarterAmount-Spalte, wenn der Wert 1 ist."
  - name: "@ExecutePivot"
    sql_type: "bit"
    direction: "IN"
    required: false
    description: "Fuehrt die generierte Pivot-Anweisung aus, wenn der Wert 1 ist."

result_sets:
  - name: "TemplateSourcePreview"
    description: "Zeigt die Demo-Quelle fuer das gewaehlte Berichtsjahr vor der Quartalsverdichtung."
  - name: "QuarterBucketPreview"
    description: "Listet die freigegebenen Quartals-Spalten inklusive Sortierung und sicherem Alias."
  - name: "QuarterAggregationPreview"
    description: "Zeigt die auf Quartale verdichtete Quellmenge pro Portfolio und Kennzahlengruppe."
  - name: "DynamicPivotStatementPreview"
    description: "Zeigt die generierte Pivot-Anweisung fuer die Quartalsmatrix."
  - name: "QuarterMatrix"
    description: "Gibt die fertige Quartalsmatrix mit Q1 bis Q4 und optionaler Gesamtsumme aus."

dependencies:
  - "DATEPART"
  - "STRING_AGG"
  - "QUOTENAME"
  - "sp_executesql"
  - "temporary tables"
  - "THROW"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/14_Pivot_Unpivot/SQLScripts/PivotQuarterMatrixTemplate.md"
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
    description: "Erstversion einer didaktischen Quartalsmatrix-Vorlage mit stabilem Quarter-Axis-Template."

notes:
  - "Die Erstversion arbeitet ausschliesslich mit temporaeren Demo-Tabellen."
  - "Die Quartalsachse bleibt ueber eine freigegebene Whitelist stabil bei Q1 bis Q4."
  - "Nicht belegte Quartale werden ueber die Zeilen- und Quartalsachse als 0.00 sichtbar gemacht."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @ReportYear INT = 2026;
DECLARE @IncludeQuarterTotal BIT = 1;
DECLARE @ExecutePivot BIT = 1;

DROP TABLE IF EXISTS #QuarterMatrixSource;
DROP TABLE IF EXISTS #QuarterWhitelist;
DROP TABLE IF EXISTS #ApprovedQuarterBuckets;
DROP TABLE IF EXISTS #QuarterAggregationPreview;

CREATE TABLE #QuarterMatrixSource
(
    SnapshotDate        DATE            NOT NULL,
    PortfolioName       VARCHAR(30)     NOT NULL,
    MeasureGroup        VARCHAR(30)     NOT NULL,
    PlannedAmount       DECIMAL(12,2)   NOT NULL
);

CREATE TABLE #QuarterWhitelist
(
    QuarterLabel        CHAR(2)         NOT NULL PRIMARY KEY,
    QuarterNumber       TINYINT         NOT NULL,
    IsApproved          BIT             NOT NULL
);

INSERT INTO #QuarterMatrixSource
(
    SnapshotDate,
    PortfolioName,
    MeasureGroup,
    PlannedAmount
)
VALUES
    ('2025-01-15', 'Modernization', 'Revenue', 11800.00),
    ('2025-03-22', 'Modernization', 'Revenue', 12450.00),
    ('2025-04-09', 'Modernization', 'Cost',     6400.00),
    ('2025-07-11', 'Operations',    'Revenue',  9800.00),
    ('2025-10-03', 'Operations',    'Cost',     5200.00),
    ('2026-01-14', 'Modernization', 'Revenue', 13200.00),
    ('2026-02-27', 'Modernization', 'Revenue', 12880.00),
    ('2026-03-18', 'Modernization', 'Cost',     7100.00),
    ('2026-04-07', 'Modernization', 'Cost',     7350.00),
    ('2026-04-26', 'Operations',    'Revenue', 10120.00),
    ('2026-05-15', 'Operations',    'Revenue', 10440.00),
    ('2026-06-30', 'Operations',    'Cost',     5820.00),
    ('2026-07-19', 'Retention',     'Revenue',  8640.00),
    ('2026-08-08', 'Retention',     'Cost',     4310.00),
    ('2026-09-21', 'Retention',     'Cost',     4460.00),
    ('2026-10-13', 'Modernization', 'Revenue', 13990.00),
    ('2026-11-02', 'Operations',    'Cost',     6030.00),
    ('2026-12-18', 'Retention',     'Revenue',  9125.00);

INSERT INTO #QuarterWhitelist
(
    QuarterLabel,
    QuarterNumber,
    IsApproved
)
VALUES
    ('Q1', 1, 1),
    ('Q2', 2, 1),
    ('Q3', 3, 1),
    ('Q4', 4, 1);

IF @ReportYear IS NULL
BEGIN
    THROW 50081, 'PivotQuarterMatrixTemplate requires a non-null @ReportYear value.', 1;
END;

IF @IncludeQuarterTotal NOT IN (0, 1)
BEGIN
    THROW 50082, 'PivotQuarterMatrixTemplate expects @IncludeQuarterTotal as 0 or 1.', 1;
END;

IF @ExecutePivot NOT IN (0, 1)
BEGIN
    THROW 50083, 'PivotQuarterMatrixTemplate expects @ExecutePivot as 0 or 1.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM #QuarterMatrixSource AS src
    WHERE DATEPART(YEAR, src.SnapshotDate) = @ReportYear
)
BEGIN
    THROW 50084, 'PivotQuarterMatrixTemplate found no source rows for the selected @ReportYear.', 1;
END;

SELECT
    qw.QuarterLabel,
    qw.QuarterNumber,
    QUOTENAME(qw.QuarterLabel) AS SafeQuarterColumn
INTO #ApprovedQuarterBuckets
FROM #QuarterWhitelist AS qw
WHERE qw.IsApproved = 1;

IF NOT EXISTS
(
    SELECT 1
    FROM #ApprovedQuarterBuckets AS aqb
)
BEGIN
    THROW 50085, 'PivotQuarterMatrixTemplate found no approved quarter buckets.', 1;
END;

SELECT
    src.PortfolioName,
    src.MeasureGroup,
    CONCAT('Q', DATEPART(QUARTER, src.SnapshotDate)) AS QuarterLabel,
    SUM(src.PlannedAmount) AS QuarterAmount
INTO #QuarterAggregationPreview
FROM #QuarterMatrixSource AS src
WHERE DATEPART(YEAR, src.SnapshotDate) = @ReportYear
GROUP BY
    src.PortfolioName,
    src.MeasureGroup,
    CONCAT('Q', DATEPART(QUARTER, src.SnapshotDate));

DECLARE @PivotColumnList NVARCHAR(MAX);
DECLARE @PivotSelectList NVARCHAR(MAX);
DECLARE @QuarterTotalExpression NVARCHAR(MAX);
DECLARE @QuarterTotalProjection NVARCHAR(MAX);
DECLARE @DynamicSql NVARCHAR(MAX);

SELECT
    @PivotColumnList = STRING_AGG(aqb.SafeQuarterColumn, ', ')
        WITHIN GROUP (ORDER BY aqb.QuarterNumber),
    @PivotSelectList = STRING_AGG
    (
        'COALESCE(p.' + aqb.SafeQuarterColumn + ', 0.00) AS ' + aqb.SafeQuarterColumn,
        ', '
    ) WITHIN GROUP (ORDER BY aqb.QuarterNumber),
    @QuarterTotalExpression = STRING_AGG
    (
        'COALESCE(p.' + aqb.SafeQuarterColumn + ', 0.00)',
        ' + '
    ) WITHIN GROUP (ORDER BY aqb.QuarterNumber)
FROM #ApprovedQuarterBuckets AS aqb;

IF @PivotColumnList IS NULL OR @PivotSelectList IS NULL OR @QuarterTotalExpression IS NULL
BEGIN
    THROW 50086, 'PivotQuarterMatrixTemplate could not assemble the dynamic quarter projection.', 1;
END;

SET @QuarterTotalProjection =
    CASE
        WHEN @IncludeQuarterTotal = 1
            THEN ', CAST(' + @QuarterTotalExpression + ' AS DECIMAL(12,2)) AS TotalQuarterAmount'
        ELSE ''
    END;

SET @DynamicSql = N'
WITH row_axis AS
(
    SELECT DISTINCT
        src.PortfolioName,
        src.MeasureGroup
    FROM #QuarterMatrixSource AS src
    WHERE DATEPART(YEAR, src.SnapshotDate) = @RuntimeReportYear
),
aggregated_source AS
(
    SELECT
        src.PortfolioName,
        src.MeasureGroup,
        CONCAT(''Q'', DATEPART(QUARTER, src.SnapshotDate)) AS QuarterLabel,
        SUM(src.PlannedAmount) AS QuarterAmount
    FROM #QuarterMatrixSource AS src
    WHERE DATEPART(YEAR, src.SnapshotDate) = @RuntimeReportYear
    GROUP BY
        src.PortfolioName,
        src.MeasureGroup,
        CONCAT(''Q'', DATEPART(QUARTER, src.SnapshotDate))
),
densified_source AS
(
    SELECT
        ra.PortfolioName,
        ra.MeasureGroup,
        aqb.QuarterLabel,
        COALESCE(ags.QuarterAmount, 0.00) AS QuarterAmount
    FROM row_axis AS ra
    CROSS JOIN #ApprovedQuarterBuckets AS aqb
    LEFT JOIN aggregated_source AS ags
        ON ags.PortfolioName = ra.PortfolioName
       AND ags.MeasureGroup = ra.MeasureGroup
       AND ags.QuarterLabel = aqb.QuarterLabel
)
SELECT
    p.PortfolioName,
    p.MeasureGroup,
    ' + @PivotSelectList + @QuarterTotalProjection + N'
FROM densified_source AS src
PIVOT
(
    SUM(src.QuarterAmount)
    FOR src.QuarterLabel IN (' + @PivotColumnList + N')
) AS p
ORDER BY
    p.PortfolioName,
    p.MeasureGroup;';

SELECT
    src.SnapshotDate,
    src.PortfolioName,
    src.MeasureGroup,
    src.PlannedAmount
FROM #QuarterMatrixSource AS src
WHERE DATEPART(YEAR, src.SnapshotDate) = @ReportYear
ORDER BY
    src.SnapshotDate,
    src.PortfolioName,
    src.MeasureGroup;

SELECT
    aqb.QuarterNumber,
    aqb.QuarterLabel,
    aqb.SafeQuarterColumn,
    @IncludeQuarterTotal AS IncludeQuarterTotal
FROM #ApprovedQuarterBuckets AS aqb
ORDER BY
    aqb.QuarterNumber;

SELECT
    qap.PortfolioName,
    qap.MeasureGroup,
    qap.QuarterLabel,
    qap.QuarterAmount
FROM #QuarterAggregationPreview AS qap
ORDER BY
    qap.PortfolioName,
    qap.MeasureGroup,
    qap.QuarterLabel;

SELECT
    @DynamicSql AS DynamicPivotSql;

IF @ExecutePivot = 1
BEGIN
    EXEC sys.sp_executesql
        @stmt = @DynamicSql,
        @params = N'@RuntimeReportYear INT',
        @RuntimeReportYear = @ReportYear;
END;
ELSE
BEGIN
    SELECT
        CAST('Execution skipped because @ExecutePivot = 0.' AS NVARCHAR(100)) AS ExecutionStatus,
        @ReportYear AS ReportYear,
        @IncludeQuarterTotal AS IncludeQuarterTotal;
END;
