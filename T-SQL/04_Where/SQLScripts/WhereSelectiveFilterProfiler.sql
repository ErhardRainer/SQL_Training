/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "WhereSelectiveFilterProfiler.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "04_Where"

purpose: >
  Profiliert typische WHERE-Filter auf einer Demo-Auftragsmenge nach
  Trefferquote, Kundenbreite, Umsatzanteil und didaktischer
  Selektivitaetsbewertung, damit Suchbedingungen vor einer tieferen
  Performance-Analyse vergleichbar werden.

parameters:
  - name: "@TargetRegionCode"
    sql_type: "CHAR(2)"
    direction: "IN"
    required: false
    description: "Optionaler Regionenwert fuer einen Equality-Filter auf DE, AT oder CH"
  - name: "@MinNetAmount"
    sql_type: "DECIMAL(10,2)"
    direction: "IN"
    required: false
    description: "Optionaler Schwellwert fuer einen Bereichsfilter auf NetAmount"
  - name: "@CustomerNamePrefix"
    sql_type: "NVARCHAR(20)"
    direction: "IN"
    required: false
    description: "Optionales Namenspraefix fuer einen LIKE-Prefix-Filter"
  - name: "@TargetMonth"
    sql_type: "TINYINT"
    direction: "IN"
    required: false
    description: "Optionaler Monatswert von 1 bis 12 fuer einen Datumsbereich"
  - name: "@PriorityOnly"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 aktiviert einen BIT-Filter auf priorisierte Auftraege, 0 laesst ihn neutral"

result_sets:
  - name: "FilterCatalog"
    description: "Listet die profilierten Filtermuster mit aktivem Vergleichswert und Einsatzidee"
  - name: "FilterProfile"
    description: "Zeigt pro Filter Trefferzahlen, Anteile und didaktische Selektivitaetsbaender"
  - name: "CompositeFilterPreview"
    description: "Zeigt, wie sich eine Kombination selektiver Einzelbedingungen weiter verengt"

dependencies:
  - "tempdb temporary tables"
  - "CASE"
  - "DATEFROMPARTS"
  - "EOMONTH"
  - "LIKE"
  - "UNION ALL"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/04_Where/SQLScripts/WhereSelectiveFilterProfiler.md"
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
    description: "Erstversion fuer ein didaktisches Profiling typischer WHERE-Filter"

notes:
  - "Das Skript arbeitet ausschliesslich mit tempdb-nahen Demo-Daten."
  - "Das Profiling bewertet Trefferquoten didaktisch und ersetzt keine echte Laufzeit- oder Plananalyse."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @TargetRegionCode CHAR(2) = 'DE';
DECLARE @MinNetAmount DECIMAL(10, 2) = 300.00;
DECLARE @CustomerNamePrefix NVARCHAR(20) = N'K';
DECLARE @TargetMonth TINYINT = 5;
DECLARE @PriorityOnly BIT = 1;

IF @TargetRegionCode IS NOT NULL AND @TargetRegionCode NOT IN ('DE', 'AT', 'CH')
BEGIN
    THROW 50490, '@TargetRegionCode muss NULL, DE, AT oder CH sein.', 1;
END;

IF @MinNetAmount IS NOT NULL AND @MinNetAmount < 0
BEGIN
    THROW 50491, '@MinNetAmount darf nicht negativ sein.', 1;
END;

IF @CustomerNamePrefix IS NOT NULL AND LEN(LTRIM(RTRIM(@CustomerNamePrefix))) = 0
BEGIN
    THROW 50492, '@CustomerNamePrefix darf nicht nur aus Leerzeichen bestehen.', 1;
END;

IF @TargetMonth IS NOT NULL AND (@TargetMonth < 1 OR @TargetMonth > 12)
BEGIN
    THROW 50493, '@TargetMonth muss NULL oder zwischen 1 und 12 sein.', 1;
END;

IF @PriorityOnly NOT IN (0, 1)
BEGIN
    THROW 50494, '@PriorityOnly muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #SalesOrders;
DROP TABLE IF EXISTS #FilterCatalog;
DROP TABLE IF EXISTS #FilterProfile;

CREATE TABLE #SalesOrders
(
    OrderID INT NOT NULL PRIMARY KEY,
    CustomerName NVARCHAR(80) NOT NULL,
    RegionCode CHAR(2) NOT NULL,
    CustomerSegment VARCHAR(20) NOT NULL,
    OrderStatus VARCHAR(20) NOT NULL,
    IsPriority BIT NOT NULL,
    OrderDate DATE NOT NULL,
    NetAmount DECIMAL(10, 2) NOT NULL
);

CREATE TABLE #FilterCatalog
(
    FilterName VARCHAR(50) NOT NULL PRIMARY KEY,
    FilterShape VARCHAR(20) NOT NULL,
    ComparedColumn VARCHAR(40) NOT NULL,
    ActiveValue NVARCHAR(80) NOT NULL,
    TeachingGoal NVARCHAR(220) NOT NULL
);

CREATE TABLE #FilterProfile
(
    FilterName VARCHAR(50) NOT NULL PRIMARY KEY,
    FilterShape VARCHAR(20) NOT NULL,
    ComparedColumn VARCHAR(40) NOT NULL,
    ActiveValue NVARCHAR(80) NOT NULL,
    MatchingRows INT NOT NULL,
    MatchingCustomers INT NOT NULL,
    MatchingAmount DECIMAL(12, 2) NOT NULL,
    TotalRows INT NOT NULL,
    TotalAmount DECIMAL(12, 2) NOT NULL,
    RowSelectivityPct DECIMAL(5, 2) NOT NULL,
    AmountCoveragePct DECIMAL(5, 2) NOT NULL,
    SelectivityBand VARCHAR(20) NOT NULL,
    RecommendedUse NVARCHAR(220) NOT NULL
);

INSERT INTO #SalesOrders
(
    OrderID,
    CustomerName,
    RegionCode,
    CustomerSegment,
    OrderStatus,
    IsPriority,
    OrderDate,
    NetAmount
)
VALUES
    (4201, N'Alpenmarkt GmbH', 'DE', 'SMB', 'Open', 0, '2026-01-08', 95.00),
    (4202, N'Alpenmarkt GmbH', 'DE', 'SMB', 'Closed', 0, '2026-02-12', 145.00),
    (4203, N'Bergblick AG', 'AT', 'MidMarket', 'Open', 1, '2026-02-18', 210.00),
    (4204, N'Bergblick AG', 'AT', 'MidMarket', 'Closed', 0, '2026-03-03', 260.00),
    (4205, N'City Office KG', 'DE', 'MidMarket', 'Open', 1, '2026-03-07', 180.00),
    (4206, N'Delta Handel SA', 'CH', 'Enterprise', 'Open', 1, '2026-03-14', 520.00),
    (4207, N'Delta Handel SA', 'CH', 'Enterprise', 'Pending', 1, '2026-03-21', 480.00),
    (4208, N'Elbe Service GmbH', 'DE', 'Enterprise', 'Closed', 1, '2026-03-28', 610.00),
    (4209, N'Foxtrot Stores AG', 'AT', 'SMB', 'Open', 0, '2026-04-02', 85.00),
    (4210, N'Gipfel Technik AG', 'CH', 'Enterprise', 'Closed', 1, '2026-04-09', 730.00),
    (4211, N'Hafenbedarf GmbH', 'DE', 'MidMarket', 'Pending', 0, '2026-04-16', 305.00),
    (4212, N'Inselwaren eG', 'AT', 'SMB', 'Open', 0, '2026-04-19', 130.00),
    (4213, N'Jura Logistik AG', 'CH', 'Enterprise', 'Open', 1, '2026-05-04', 460.00),
    (4214, N'Kontor Nord GmbH', 'DE', 'Enterprise', 'Pending', 1, '2026-05-11', 390.00),
    (4215, N'Komet Retail GmbH', 'DE', 'SMB', 'Open', 0, '2026-05-15', 155.00),
    (4216, N'Luna Transport AG', 'CH', 'MidMarket', 'Closed', 0, '2026-05-20', 275.00);

INSERT INTO #FilterCatalog
(
    FilterName,
    FilterShape,
    ComparedColumn,
    ActiveValue,
    TeachingGoal
)
VALUES
    (
        'RegionEquals',
        'equality',
        'RegionCode',
        COALESCE(@TargetRegionCode, 'ALL'),
        N'Exakte Gleichheitsfilter auf Basisattributen sind oft die erste Referenz fuer Selektivitaetsdiskussionen.'
    ),
    (
        'NetAmountAtLeast',
        'range',
        'NetAmount',
        COALESCE(CONVERT(NVARCHAR(80), @MinNetAmount), 'ALL'),
        N'Bereichsfilter zeigen, wie stark ein numerischer Schwellenwert die verbleibende Menge reduziert.'
    ),
    (
        'CustomerNamePrefix',
        'prefix-like',
        'CustomerName',
        COALESCE(@CustomerNamePrefix + N'%', N'ALL'),
        N'Prefix-Suchen illustrieren ein typisches Suchmaskenpraedikat mit LIKE.'
    ),
    (
        'MonthWindow',
        'date-range',
        'OrderDate',
        COALESCE(CONVERT(NVARCHAR(80), @TargetMonth), 'ALL'),
        N'Der Monatsfilter wird als Datumsbereich profiliert, damit die Spalte selbst unveraendert bleibt.'
    ),
    (
        'PriorityOnly',
        'boolean',
        'IsPriority',
        CASE WHEN @PriorityOnly = 1 THEN '1' ELSE 'ALL' END,
        N'BIT-Filter sind leicht formulierbar, aber nicht immer wirklich eng.'
    );

INSERT INTO #FilterProfile
(
    FilterName,
    FilterShape,
    ComparedColumn,
    ActiveValue,
    MatchingRows,
    MatchingCustomers,
    MatchingAmount,
    TotalRows,
    TotalAmount,
    RowSelectivityPct,
    AmountCoveragePct,
    SelectivityBand,
    RecommendedUse
)
SELECT
    fc.FilterName,
    fc.FilterShape,
    fc.ComparedColumn,
    fc.ActiveValue,
    scan.MatchingRows,
    scan.MatchingCustomers,
    scan.MatchingAmount,
    totals.TotalRows,
    totals.TotalAmount,
    CAST((100.0 * scan.MatchingRows) / NULLIF(totals.TotalRows, 0) AS DECIMAL(5, 2)) AS RowSelectivityPct,
    CAST((100.0 * scan.MatchingAmount) / NULLIF(totals.TotalAmount, 0) AS DECIMAL(5, 2)) AS AmountCoveragePct,
    CASE
        WHEN (100.0 * scan.MatchingRows) / NULLIF(totals.TotalRows, 0) <= 20 THEN 'highly-selective'
        WHEN (100.0 * scan.MatchingRows) / NULLIF(totals.TotalRows, 0) <= 50 THEN 'medium-selective'
        ELSE 'low-selective'
    END AS SelectivityBand,
    CASE
        WHEN (100.0 * scan.MatchingRows) / NULLIF(totals.TotalRows, 0) <= 20 THEN N'Geeignet als enger Vorfilter oder fuer gezielte Suchpfade.'
        WHEN (100.0 * scan.MatchingRows) / NULLIF(totals.TotalRows, 0) <= 50 THEN N'Solider Filter, der oft mit weiteren Kriterien kombiniert wird.'
        ELSE N'Allein eher breit; sinnvoller als Zusatzfilter oder fuer explorative Sichten.'
    END AS RecommendedUse
FROM #FilterCatalog AS fc
CROSS JOIN
(
    SELECT
        COUNT(*) AS TotalRows,
        CAST(SUM(so.NetAmount) AS DECIMAL(12, 2)) AS TotalAmount
    FROM #SalesOrders AS so
) AS totals
INNER JOIN
(
    SELECT
        'RegionEquals' AS FilterName,
        COUNT(*) AS MatchingRows,
        COUNT(DISTINCT so.CustomerName) AS MatchingCustomers,
        CAST(SUM(so.NetAmount) AS DECIMAL(12, 2)) AS MatchingAmount
    FROM #SalesOrders AS so
    WHERE @TargetRegionCode IS NULL OR so.RegionCode = @TargetRegionCode

    UNION ALL

    SELECT
        'NetAmountAtLeast',
        COUNT(*),
        COUNT(DISTINCT so.CustomerName),
        CAST(SUM(so.NetAmount) AS DECIMAL(12, 2))
    FROM #SalesOrders AS so
    WHERE @MinNetAmount IS NULL OR so.NetAmount >= @MinNetAmount

    UNION ALL

    SELECT
        'CustomerNamePrefix',
        COUNT(*),
        COUNT(DISTINCT so.CustomerName),
        CAST(SUM(so.NetAmount) AS DECIMAL(12, 2))
    FROM #SalesOrders AS so
    WHERE @CustomerNamePrefix IS NULL
       OR so.CustomerName LIKE @CustomerNamePrefix + N'%'

    UNION ALL

    SELECT
        'MonthWindow',
        COUNT(*),
        COUNT(DISTINCT so.CustomerName),
        CAST(SUM(so.NetAmount) AS DECIMAL(12, 2))
    FROM #SalesOrders AS so
    WHERE @TargetMonth IS NULL
       OR (
            so.OrderDate >= DATEFROMPARTS(YEAR(so.OrderDate), @TargetMonth, 1)
            AND so.OrderDate < DATEADD(DAY, 1, EOMONTH(DATEFROMPARTS(YEAR(so.OrderDate), @TargetMonth, 1)))
          )

    UNION ALL

    SELECT
        'PriorityOnly',
        COUNT(*),
        COUNT(DISTINCT so.CustomerName),
        CAST(SUM(so.NetAmount) AS DECIMAL(12, 2))
    FROM #SalesOrders AS so
    WHERE @PriorityOnly = 0 OR so.IsPriority = 1
) AS scan
    ON scan.FilterName = fc.FilterName;

SELECT
    fc.FilterName,
    fc.FilterShape,
    fc.ComparedColumn,
    fc.ActiveValue,
    fc.TeachingGoal
FROM #FilterCatalog AS fc
ORDER BY
    CASE fc.FilterShape
        WHEN 'equality' THEN 1
        WHEN 'range' THEN 2
        WHEN 'prefix-like' THEN 3
        WHEN 'date-range' THEN 4
        ELSE 5
    END,
    fc.FilterName;

SELECT
    fp.FilterName,
    fp.FilterShape,
    fp.ComparedColumn,
    fp.ActiveValue,
    fp.MatchingRows,
    fp.MatchingCustomers,
    fp.MatchingAmount,
    fp.TotalRows,
    fp.TotalAmount,
    fp.RowSelectivityPct,
    fp.AmountCoveragePct,
    fp.SelectivityBand,
    fp.RecommendedUse
FROM #FilterProfile AS fp
ORDER BY
    fp.RowSelectivityPct ASC,
    fp.AmountCoveragePct ASC,
    fp.FilterName;

;WITH CompositeFilterPreview AS
(
    SELECT
        'Region + Amount + Priority' AS ScenarioName,
        COUNT(*) AS MatchingRows,
        COUNT(DISTINCT so.CustomerName) AS MatchingCustomers,
        CAST(SUM(so.NetAmount) AS DECIMAL(12, 2)) AS MatchingAmount
    FROM #SalesOrders AS so
    WHERE (@TargetRegionCode IS NULL OR so.RegionCode = @TargetRegionCode)
      AND (@MinNetAmount IS NULL OR so.NetAmount >= @MinNetAmount)
      AND (@PriorityOnly = 0 OR so.IsPriority = 1)

    UNION ALL

    SELECT
        'Prefix + Month + Priority',
        COUNT(*),
        COUNT(DISTINCT so.CustomerName),
        CAST(SUM(so.NetAmount) AS DECIMAL(12, 2))
    FROM #SalesOrders AS so
    WHERE (@CustomerNamePrefix IS NULL OR so.CustomerName LIKE @CustomerNamePrefix + N'%')
      AND (
            @TargetMonth IS NULL
            OR (
                so.OrderDate >= DATEFROMPARTS(YEAR(so.OrderDate), @TargetMonth, 1)
                AND so.OrderDate < DATEADD(DAY, 1, EOMONTH(DATEFROMPARTS(YEAR(so.OrderDate), @TargetMonth, 1)))
               )
          )
      AND (@PriorityOnly = 0 OR so.IsPriority = 1)
)
SELECT
    cfp.ScenarioName,
    cfp.MatchingRows,
    cfp.MatchingCustomers,
    cfp.MatchingAmount,
    CAST((100.0 * cfp.MatchingRows) / NULLIF(totals.TotalRows, 0) AS DECIMAL(5, 2)) AS RowSelectivityPct,
    CAST((100.0 * cfp.MatchingAmount) / NULLIF(totals.TotalAmount, 0) AS DECIMAL(5, 2)) AS AmountCoveragePct,
    CASE
        WHEN cfp.MatchingRows = 0 THEN 'Keine Treffer; Kombination ist fuer die Demo-Menge zu eng.'
        WHEN cfp.MatchingRows <= 2 THEN 'Sehr enger Kombinationsfilter mit klarer Vorfilter-Wirkung.'
        ELSE 'Kombinationsfilter reduziert die Menge merklich weiter.'
    END AS CombinationReading
FROM CompositeFilterPreview AS cfp
CROSS JOIN
(
    SELECT
        COUNT(*) AS TotalRows,
        CAST(SUM(so.NetAmount) AS DECIMAL(12, 2)) AS TotalAmount
    FROM #SalesOrders AS so
) AS totals
ORDER BY
    cfp.ScenarioName;
