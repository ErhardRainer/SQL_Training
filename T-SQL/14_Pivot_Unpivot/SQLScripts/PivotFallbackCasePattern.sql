/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "PivotFallbackCasePattern.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "14_Pivot_Unpivot"

purpose: >
  Demonstriert ein CASE-basiertes Fallback-Muster fuer Crosstab-Ausgaben,
  wenn ein klassisches PIVOT nicht passend ist. Das Skript zeigt an einer
  Demo-Quelle, wie mehrere Zielspalten mit unterschiedlichen Filter- und
  Aggregationsregeln in einer stabilen Ergebnismatrix zusammengefuehrt
  werden koennen.

parameters:
  - name: "@ReportYear"
    sql_type: "int"
    direction: "IN"
    required: false
    description: "Filtert die Demo-Quelle auf ein Berichtsjahr fuer die Ausgabematrix."
  - name: "@IncludeForecastRows"
    sql_type: "bit"
    direction: "IN"
    required: false
    description: "Beruecksichtigt Forecast-Zeilen in Vorschau und Matrix, wenn der Wert 1 ist."

result_sets:
  - name: "CaseSourcePreview"
    description: "Zeigt die gefilterte Demo-Quelle fuer das CASE-basierte Crosstab-Muster."
  - name: "CasePatternMapping"
    description: "Dokumentiert die Zielspalten samt Filterregel und Aggregatfamilie."
  - name: "PivotLimitationReview"
    description: "Macht sichtbar, warum die kombinierte Ausgabe fuer ein reines PIVOT unguenstig ist."
  - name: "CaseFallbackMatrix"
    description: "Gibt die finale Matrix mit CASE-basierten Aggregationen je Region zurueck."

dependencies:
  - "CASE expressions"
  - "CTEs"
  - "temporary tables"
  - "THROW"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/14_Pivot_Unpivot/SQLScripts/PivotFallbackCasePattern.md"
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
    description: "Erstversion eines CASE-basierten Fallback-Musters fuer gemischte Crosstab-Regeln."

notes:
  - "Die Erstversion arbeitet ausschliesslich mit temporaeren Demo-Tabellen."
  - "Die Zielmatrix kombiniert bewusst SUM-, COUNT- und MAX-Regeln in einer Ausgabe."
  - "Das Skript zeigt, wann conditional aggregation lesbarer ist als ein reines PIVOT."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @ReportYear INT = 2026;
DECLARE @IncludeForecastRows BIT = 1;

DROP TABLE IF EXISTS #CaseSource;
DROP TABLE IF EXISTS #CasePatternMap;

CREATE TABLE #CaseSource
(
    ReportYear      INT             NOT NULL,
    RegionCode      VARCHAR(20)     NOT NULL,
    ChannelName     VARCHAR(20)     NOT NULL,
    ScenarioName    VARCHAR(20)     NOT NULL,
    RevenueAmount   DECIMAL(12,2)   NOT NULL,
    TicketCount     INT             NOT NULL,
    ReviewDate      DATE            NULL,
    IsEscalated     BIT             NOT NULL
);

CREATE TABLE #CasePatternMap
(
    OutputColumnName    SYSNAME         NOT NULL PRIMARY KEY,
    AggregateFamily     VARCHAR(20)     NOT NULL,
    FilterRule          NVARCHAR(200)   NOT NULL,
    WhyNotPlainPivot    NVARCHAR(200)   NOT NULL
);

INSERT INTO #CaseSource
(
    ReportYear,
    RegionCode,
    ChannelName,
    ScenarioName,
    RevenueAmount,
    TicketCount,
    ReviewDate,
    IsEscalated
)
VALUES
    (2025, 'Central', 'Retail',    'Actual',   10800.00, 3, '2025-01-09', 0),
    (2025, 'Central', 'Wholesale', 'Actual',   12150.00, 2, '2025-01-17', 1),
    (2025, 'North',   'Retail',    'Forecast', 13220.00, 1, '2025-02-02', 0),
    (2026, 'Central', 'Retail',    'Actual',   12440.00, 4, '2026-01-08', 0),
    (2026, 'Central', 'Wholesale', 'Actual',   13750.00, 2, '2026-01-19', 1),
    (2026, 'Central', 'Retail',    'Forecast', 14180.00, 1, '2026-02-14', 0),
    (2026, 'North',   'Retail',    'Actual',   14925.00, 5, '2026-01-11', 1),
    (2026, 'North',   'Wholesale', 'Forecast', 15680.00, 2, '2026-02-18', 1),
    (2026, 'North',   'Wholesale', 'Actual',   15110.00, 3, '2026-03-05', 0),
    (2026, 'South',   'Retail',    'Actual',   11420.00, 2, '2026-01-12', 0),
    (2026, 'South',   'Retail',    'Forecast', 11865.00, 1, '2026-02-07', 0),
    (2026, 'South',   'Wholesale', 'Actual',   12240.00, 4, '2026-03-03', 1),
    (2026, 'West',    'Retail',    'Actual',   10310.00, 1, '2026-01-21', 0),
    (2026, 'West',    'Wholesale', 'Forecast', 10990.00, 2, '2026-03-09', 1),
    (2026, 'West',    'Wholesale', 'Actual',   10760.00, 1, '2026-03-18', 0);

INSERT INTO #CasePatternMap
(
    OutputColumnName,
    AggregateFamily,
    FilterRule,
    WhyNotPlainPivot
)
VALUES
    ('ActualRevenue', 'SUM',   N'ScenarioName = Actual', N'Nur eine Teilmenge der Zeilen fliesst in die Kennzahl ein.'),
    ('ForecastRevenue', 'SUM', N'ScenarioName = Forecast', N'Forecast soll optional ein- oder ausgeblendet werden.'),
    ('WholesaleRevenue', 'SUM', N'ChannelName = Wholesale', N'Die Pivot-Achse folgt dem Kanal und nicht der Szenario-Spalte.'),
    ('EscalatedTickets', 'SUM', N'IsEscalated = 1', N'Dieselbe Quellmenge liefert eine zweite fachliche Aggregation.'),
    ('LatestEscalationReview', 'MAX', N'IsEscalated = 1 auf ReviewDate', N'Die Matrix mischt Datums-Maximum und Summen in einer Zeile.'),
    ('DistinctScenarios', 'COUNT', N'Distinct ScenarioName je Region', N'Ein reines PIVOT erzwingt typischerweise ein gemeinsames Aggregat.');

IF @ReportYear IS NULL
BEGIN
    THROW 50041, 'PivotFallbackCasePattern requires a non-null @ReportYear value.', 1;
END;

IF @IncludeForecastRows NOT IN (0, 1)
BEGIN
    THROW 50042, 'PivotFallbackCasePattern expects @IncludeForecastRows as 0 or 1.', 1;
END;

IF EXISTS
(
    SELECT
        map.OutputColumnName
    FROM #CasePatternMap AS map
    GROUP BY
        map.OutputColumnName
    HAVING COUNT(*) > 1
)
BEGIN
    THROW 50043, 'PivotFallbackCasePattern detected duplicate output column names in the CASE map.', 1;
END;

;WITH FilteredSource AS
(
    SELECT
        src.ReportYear,
        src.RegionCode,
        src.ChannelName,
        src.ScenarioName,
        src.RevenueAmount,
        src.TicketCount,
        src.ReviewDate,
        src.IsEscalated
    FROM #CaseSource AS src
    WHERE src.ReportYear = @ReportYear
      AND (@IncludeForecastRows = 1 OR src.ScenarioName <> 'Forecast')
)
SELECT
    src.ReportYear,
    src.RegionCode,
    src.ChannelName,
    src.ScenarioName,
    src.RevenueAmount,
    src.TicketCount,
    src.ReviewDate,
    src.IsEscalated
FROM FilteredSource AS src
ORDER BY
    src.RegionCode,
    src.ChannelName,
    CASE src.ScenarioName
        WHEN 'Actual' THEN 1
        WHEN 'Forecast' THEN 2
        ELSE 99
    END,
    src.ReviewDate;

SELECT
    map.OutputColumnName,
    map.AggregateFamily,
    map.FilterRule,
    map.WhyNotPlainPivot
FROM #CasePatternMap AS map
ORDER BY
    CASE map.OutputColumnName
        WHEN 'ActualRevenue' THEN 1
        WHEN 'ForecastRevenue' THEN 2
        WHEN 'WholesaleRevenue' THEN 3
        WHEN 'EscalatedTickets' THEN 4
        WHEN 'LatestEscalationReview' THEN 5
        WHEN 'DistinctScenarios' THEN 6
        ELSE 99
    END;

;WITH FilteredSource AS
(
    SELECT
        src.ReportYear,
        src.RegionCode,
        src.ChannelName,
        src.ScenarioName,
        src.RevenueAmount,
        src.TicketCount,
        src.ReviewDate,
        src.IsEscalated
    FROM #CaseSource AS src
    WHERE src.ReportYear = @ReportYear
      AND (@IncludeForecastRows = 1 OR src.ScenarioName <> 'Forecast')
),
AggregateFamilies AS
(
    SELECT DISTINCT
        map.AggregateFamily
    FROM #CasePatternMap AS map
),
RegionCounts AS
(
    SELECT
        src.RegionCode,
        COUNT(*) AS SourceRowCount,
        COUNT(DISTINCT src.ScenarioName) AS ScenarioCount
    FROM FilteredSource AS src
    GROUP BY
        src.RegionCode
)
SELECT
    rc.RegionCode,
    rc.SourceRowCount,
    rc.ScenarioCount,
    (SELECT COUNT(*) FROM AggregateFamilies) AS AggregateFamilyCount,
    CAST
    (
        CASE
            WHEN (SELECT COUNT(*) FROM AggregateFamilies) > 1
                THEN 'CASE fallback is preferable because the output mixes SUM, COUNT and MAX.'
            ELSE 'A single-aggregate pivot would still be plausible.'
        END
        AS NVARCHAR(120)
    ) AS ReviewConclusion
FROM RegionCounts AS rc
ORDER BY
    rc.RegionCode;

;WITH FilteredSource AS
(
    SELECT
        src.ReportYear,
        src.RegionCode,
        src.ChannelName,
        src.ScenarioName,
        src.RevenueAmount,
        src.TicketCount,
        src.ReviewDate,
        src.IsEscalated
    FROM #CaseSource AS src
    WHERE src.ReportYear = @ReportYear
      AND (@IncludeForecastRows = 1 OR src.ScenarioName <> 'Forecast')
)
SELECT
    src.ReportYear,
    src.RegionCode,
    SUM(CASE WHEN src.ScenarioName = 'Actual' THEN src.RevenueAmount ELSE 0.00 END) AS ActualRevenue,
    SUM(CASE WHEN src.ScenarioName = 'Forecast' THEN src.RevenueAmount ELSE 0.00 END) AS ForecastRevenue,
    SUM(CASE WHEN src.ChannelName = 'Wholesale' THEN src.RevenueAmount ELSE 0.00 END) AS WholesaleRevenue,
    SUM(CASE WHEN src.IsEscalated = 1 THEN src.TicketCount ELSE 0 END) AS EscalatedTickets,
    MAX(CASE WHEN src.IsEscalated = 1 THEN src.ReviewDate END) AS LatestEscalationReview,
    COUNT(DISTINCT src.ScenarioName) AS DistinctScenarios
FROM FilteredSource AS src
GROUP BY
    src.ReportYear,
    src.RegionCode
ORDER BY
    src.ReportYear,
    src.RegionCode;
