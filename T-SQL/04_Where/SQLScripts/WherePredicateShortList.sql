/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "WherePredicateShortList.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "04_Where"

purpose: >
  Liefert eine kompakte Sammlung kurzer und gut lesbarer WHERE-
  Praedikatmuster, damit Equality-, Range-, IN-, LIKE-, NULL- und
  Datumsfilter auf derselben Demo-Menge direkt verglichen werden koennen.

parameters:
  - name: "@RegionCode"
    sql_type: "CHAR(2)"
    direction: "IN"
    required: false
    description: "Optionaler Equality-Filter fuer DE, AT oder CH"
  - name: "@MinNetAmount"
    sql_type: "DECIMAL(10,2)"
    direction: "IN"
    required: false
    description: "Optionaler Range-Filter fuer Mindestumsatz"
  - name: "@NameStartsWith"
    sql_type: "NVARCHAR(20)"
    direction: "IN"
    required: false
    description: "Optionales Praefix fuer LIKE-Praedikate"
  - name: "@StatusCsv"
    sql_type: "VARCHAR(100)"
    direction: "IN"
    required: false
    description: "Kommagetrennte Statusliste fuer ein IN-Muster"
  - name: "@RequireUnassigned"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 zeigt nur Zeilen ohne AccountManager"
  - name: "@OrderMonth"
    sql_type: "TINYINT"
    direction: "IN"
    required: false
    description: "Optionaler Monatsfilter fuer eine halb-offene Datumsrange"

result_sets:
  - name: "PredicateShortList"
    description: "Uebersicht der kompakten Praedikatmuster mit aktivem Vergleichswert"
  - name: "PredicateMatches"
    description: "Trefferliste je Praedikat mit kurzer Lesart und deterministischer Sortierung"
  - name: "PredicateSummary"
    description: "Verdichtet Trefferzahl, Umsatz und Kundensignatur pro Muster"

dependencies:
  - "tempdb temporary tables"
  - "STRING_SPLIT"
  - "DATEFROMPARTS"
  - "EOMONTH"
  - "ROW_NUMBER"
  - "STRING_AGG"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/04_Where/SQLScripts/WherePredicateShortList.md"
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
    description: "Erstversion fuer eine kompakte Sammlung lesbarer WHERE-Praedikatmuster"

notes:
  - "Das Skript nutzt ausschliesslich Demo-Daten in tempdb-nahen Temp-Tabellen."
  - "Alle Muster sind bewusst kurz gehalten und sollen Lesbarkeit vor Vollstaendigkeit zeigen."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @RegionCode CHAR(2) = 'DE';
DECLARE @MinNetAmount DECIMAL(10, 2) = 150.00;
DECLARE @NameStartsWith NVARCHAR(20) = N'A';
DECLARE @StatusCsv VARCHAR(100) = 'Open,Pending';
DECLARE @RequireUnassigned BIT = 1;
DECLARE @OrderMonth TINYINT = 3;

IF @RegionCode IS NOT NULL AND @RegionCode NOT IN ('DE', 'AT', 'CH')
BEGIN
    THROW 50440, '@RegionCode muss NULL, DE, AT oder CH sein.', 1;
END;

IF @MinNetAmount IS NOT NULL AND @MinNetAmount < 0
BEGIN
    THROW 50441, '@MinNetAmount darf nicht negativ sein.', 1;
END;

IF @NameStartsWith IS NOT NULL AND LEN(@NameStartsWith) = 0
BEGIN
    THROW 50442, '@NameStartsWith darf nicht leer sein.', 1;
END;

IF @RequireUnassigned NOT IN (0, 1)
BEGIN
    THROW 50443, '@RequireUnassigned muss 0 oder 1 sein.', 1;
END;

IF @OrderMonth IS NOT NULL AND (@OrderMonth < 1 OR @OrderMonth > 12)
BEGIN
    THROW 50444, '@OrderMonth muss NULL oder zwischen 1 und 12 sein.', 1;
END;

DROP TABLE IF EXISTS #Orders;
DROP TABLE IF EXISTS #StatusFilter;
DROP TABLE IF EXISTS #PredicateCatalog;
DROP TABLE IF EXISTS #PredicateMatches;

CREATE TABLE #Orders
(
    OrderID INT NOT NULL PRIMARY KEY,
    CustomerName NVARCHAR(80) NOT NULL,
    RegionCode CHAR(2) NOT NULL,
    OrderStatus VARCHAR(20) NOT NULL,
    AccountManager NVARCHAR(80) NULL,
    OrderDate DATE NOT NULL,
    NetAmount DECIMAL(10, 2) NOT NULL
);

CREATE TABLE #StatusFilter
(
    StatusValue VARCHAR(20) NOT NULL PRIMARY KEY
);

CREATE TABLE #PredicateCatalog
(
    PredicateName VARCHAR(40) NOT NULL PRIMARY KEY,
    PredicateShape VARCHAR(20) NOT NULL,
    SamplePredicate NVARCHAR(160) NOT NULL,
    ActiveValue NVARCHAR(80) NOT NULL,
    TeachingNote NVARCHAR(220) NOT NULL
);

CREATE TABLE #PredicateMatches
(
    PredicateName VARCHAR(40) NOT NULL,
    PredicateShape VARCHAR(20) NOT NULL,
    MatchRank INT NOT NULL,
    OrderID INT NOT NULL,
    CustomerName NVARCHAR(80) NOT NULL,
    RegionCode CHAR(2) NOT NULL,
    OrderStatus VARCHAR(20) NOT NULL,
    AccountManager NVARCHAR(80) NULL,
    OrderDate DATE NOT NULL,
    NetAmount DECIMAL(10, 2) NOT NULL,
    ReadingHint NVARCHAR(160) NOT NULL
);

INSERT INTO #Orders
(
    OrderID,
    CustomerName,
    RegionCode,
    OrderStatus,
    AccountManager,
    OrderDate,
    NetAmount
)
VALUES
    (3101, N'Alpenmarkt GmbH', 'DE', 'Open', NULL, '2026-03-02', 180.00),
    (3102, N'Bergblick AG', 'AT', 'Closed', N'Lea Sommer', '2026-03-05', 95.00),
    (3103, N'City Office KG', 'DE', 'Pending', N'Mark Weber', '2026-03-09', 260.00),
    (3104, N'Delta Handel SA', 'CH', 'Open', NULL, '2026-03-12', 140.00),
    (3105, N'Elbe Service GmbH', 'DE', 'Closed', N'Sarah Klein', '2026-04-01', 430.00),
    (3106, N'Foxtrot Stores AG', 'AT', 'Pending', NULL, '2026-04-06', 110.00),
    (3107, N'Gipfel Technik AG', 'CH', 'Open', N'Lea Sommer', '2026-04-11', 520.00),
    (3108, N'Hafenbedarf GmbH', 'DE', 'Open', N'Mark Weber', '2026-05-03', 305.00),
    (3109, N'Inselwaren eG', 'AT', 'Closed', NULL, '2026-05-09', 75.00),
    (3110, N'Jura Logistik AG', 'CH', 'Pending', N'Sarah Klein', '2026-05-15', 610.00);

IF NULLIF(LTRIM(RTRIM(ISNULL(@StatusCsv, ''))), '') IS NOT NULL
BEGIN
    INSERT INTO #StatusFilter (StatusValue)
    SELECT DISTINCT
        LTRIM(RTRIM(value))
    FROM STRING_SPLIT(@StatusCsv, ',')
    WHERE LTRIM(RTRIM(value)) <> '';
END;

INSERT INTO #PredicateCatalog
(
    PredicateName,
    PredicateShape,
    SamplePredicate,
    ActiveValue,
    TeachingNote
)
VALUES
    (
        'RegionEquals',
        'equality',
        N'RegionCode = @RegionCode',
        COALESCE(@RegionCode, 'ALL'),
        N'Gleichheitsfilter sind das kuerzeste und meist klarste Basismuster.'
    ),
    (
        'AmountAtLeast',
        'range',
        N'NetAmount >= @MinNetAmount',
        COALESCE(CONVERT(NVARCHAR(80), @MinNetAmount), 'ALL'),
        N'Ein Range-Filter zeigt ein direkt lesbares Vergleichsmuster ohne verschachtelte Logik.'
    ),
    (
        'NameStartsWith',
        'like-prefix',
        N'CustomerName LIKE @NameStartsWith + N''%''',
        COALESCE(@NameStartsWith, N'ALL'),
        N'Praefixsuche eignet sich gut fuer lesbare LIKE-Beispiele mit begrenztem Muster.'
    ),
    (
        'StatusInList',
        'in-list',
        N'OrderStatus IN (SELECT StatusValue FROM #StatusFilter)',
        COALESCE(@StatusCsv, 'ALL'),
        N'IN-Muster bleiben kurz, wenn die Werteliste vorher sauber vorbereitet wird.'
    ),
    (
        'UnassignedOnly',
        'null-check',
        N'AccountManager IS NULL',
        CASE WHEN @RequireUnassigned = 1 THEN 'only-null' ELSE 'skip' END,
        N'NULL-Pruefungen sind oft lesbarer als Ersatzwerte oder CASE-Konstrukte.'
    ),
    (
        'OrderMonthRange',
        'date-range',
        N'OrderDate >= Monatsanfang AND OrderDate < naechster Monatsanfang',
        COALESCE(CONVERT(NVARCHAR(80), @OrderMonth), 'ALL'),
        N'Halb-offene Datumsranges sind ein gut lesbares Standardmuster fuer Monatsfilter.'
    );

INSERT INTO #PredicateMatches
(
    PredicateName,
    PredicateShape,
    MatchRank,
    OrderID,
    CustomerName,
    RegionCode,
    OrderStatus,
    AccountManager,
    OrderDate,
    NetAmount,
    ReadingHint
)
SELECT
    matches.PredicateName,
    matches.PredicateShape,
    ROW_NUMBER() OVER (PARTITION BY matches.PredicateName ORDER BY matches.OrderID) AS MatchRank,
    matches.OrderID,
    matches.CustomerName,
    matches.RegionCode,
    matches.OrderStatus,
    matches.AccountManager,
    matches.OrderDate,
    matches.NetAmount,
    matches.ReadingHint
FROM
(
    SELECT
        'RegionEquals' AS PredicateName,
        'equality' AS PredicateShape,
        o.OrderID,
        o.CustomerName,
        o.RegionCode,
        o.OrderStatus,
        o.AccountManager,
        o.OrderDate,
        o.NetAmount,
        N'Exakter Regionsvergleich' AS ReadingHint
    FROM #Orders AS o
    WHERE @RegionCode IS NULL OR o.RegionCode = @RegionCode

    UNION ALL

    SELECT
        'AmountAtLeast',
        'range',
        o.OrderID,
        o.CustomerName,
        o.RegionCode,
        o.OrderStatus,
        o.AccountManager,
        o.OrderDate,
        o.NetAmount,
        N'Untergrenze fuer Netto-Umsatz'
    FROM #Orders AS o
    WHERE @MinNetAmount IS NULL OR o.NetAmount >= @MinNetAmount

    UNION ALL

    SELECT
        'NameStartsWith',
        'like-prefix',
        o.OrderID,
        o.CustomerName,
        o.RegionCode,
        o.OrderStatus,
        o.AccountManager,
        o.OrderDate,
        o.NetAmount,
        N'Praefixsuche ueber Kundennamen'
    FROM #Orders AS o
    WHERE @NameStartsWith IS NULL OR o.CustomerName LIKE @NameStartsWith + N'%'

    UNION ALL

    SELECT
        'StatusInList',
        'in-list',
        o.OrderID,
        o.CustomerName,
        o.RegionCode,
        o.OrderStatus,
        o.AccountManager,
        o.OrderDate,
        o.NetAmount,
        N'Statusabgleich ueber vorbereitete Liste'
    FROM #Orders AS o
    WHERE NOT EXISTS (SELECT 1 FROM #StatusFilter)
       OR o.OrderStatus IN (SELECT sf.StatusValue FROM #StatusFilter AS sf)

    UNION ALL

    SELECT
        'UnassignedOnly',
        'null-check',
        o.OrderID,
        o.CustomerName,
        o.RegionCode,
        o.OrderStatus,
        o.AccountManager,
        o.OrderDate,
        o.NetAmount,
        N'Nur Zeilen ohne AccountManager'
    FROM #Orders AS o
    WHERE @RequireUnassigned = 0 OR o.AccountManager IS NULL

    UNION ALL

    SELECT
        'OrderMonthRange',
        'date-range',
        o.OrderID,
        o.CustomerName,
        o.RegionCode,
        o.OrderStatus,
        o.AccountManager,
        o.OrderDate,
        o.NetAmount,
        N'Halb-offener Monatsfilter auf OrderDate'
    FROM #Orders AS o
    WHERE @OrderMonth IS NULL
       OR (
            o.OrderDate >= DATEFROMPARTS(YEAR(o.OrderDate), @OrderMonth, 1)
            AND o.OrderDate < DATEADD(DAY, 1, EOMONTH(DATEFROMPARTS(YEAR(o.OrderDate), @OrderMonth, 1)))
          )
) AS matches;

SELECT
    pc.PredicateName,
    pc.PredicateShape,
    pc.SamplePredicate,
    pc.ActiveValue,
    pc.TeachingNote
FROM #PredicateCatalog AS pc
ORDER BY
    CASE pc.PredicateShape
        WHEN 'equality' THEN 1
        WHEN 'range' THEN 2
        WHEN 'like-prefix' THEN 3
        WHEN 'in-list' THEN 4
        WHEN 'null-check' THEN 5
        ELSE 6
    END,
    pc.PredicateName;

SELECT
    pm.PredicateName,
    pm.PredicateShape,
    pm.MatchRank,
    pm.OrderID,
    pm.CustomerName,
    pm.RegionCode,
    pm.OrderStatus,
    pm.AccountManager,
    pm.OrderDate,
    pm.NetAmount,
    pm.ReadingHint
FROM #PredicateMatches AS pm
ORDER BY
    pm.PredicateName,
    pm.MatchRank;

SELECT
    pm.PredicateName,
    pm.PredicateShape,
    COUNT(*) AS MatchCount,
    CAST(SUM(pm.NetAmount) AS DECIMAL(12, 2)) AS NetAmountTotal,
    STRING_AGG(CONVERT(VARCHAR(12), pm.OrderID), ',') WITHIN GROUP (ORDER BY pm.OrderID) AS OrderIDSignature,
    MIN(pm.OrderDate) AS FirstOrderDate,
    MAX(pm.OrderDate) AS LastOrderDate
FROM #PredicateMatches AS pm
GROUP BY
    pm.PredicateName,
    pm.PredicateShape
ORDER BY
    CASE pm.PredicateShape
        WHEN 'equality' THEN 1
        WHEN 'range' THEN 2
        WHEN 'like-prefix' THEN 3
        WHEN 'in-list' THEN 4
        WHEN 'null-check' THEN 5
        ELSE 6
    END,
    pm.PredicateName;
