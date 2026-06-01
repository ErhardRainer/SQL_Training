/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "InListParameterizationDemo.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "04_Where"

purpose: >
  Demonstriert fuer WHERE-IN-Filter zwei didaktische Parameterisierungs-
  muster: eine kleine stabile IN-Liste per VALUES-Konstruktor und eine
  groessere Liste per CSV-Aufbereitung mit STRING_SPLIT und bereinigter
  Join-Menge.

parameters:
  - name: "@IncludeLargeList"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 fuehrt zusaetzlich das Muster fuer die groessere IN-Liste aus"
  - name: "@LargeCustomerCsv"
    sql_type: "NVARCHAR(MAX)"
    direction: "IN"
    required: false
    description: "CSV-Liste fuer das groessere Listenmuster mit CustomerIDs"
  - name: "@MinOrderAmount"
    sql_type: "DECIMAL(10,2)"
    direction: "IN"
    required: false
    description: "Untergrenze fuer die Demo-Bestellsumme im Ergebnis"

result_sets:
  - name: "SmallListMatches"
    description: "Zeigt Treffer fuer eine kleine stabile IN-Liste auf Basis eines VALUES-Konstruktors"
  - name: "LargeListMatches"
    description: "Zeigt Treffer fuer eine groessere bereinigte Listenmenge aus STRING_SPLIT"
  - name: "StrategyComparison"
    description: "Vergleicht beide Muster didaktisch nach Eingabegroesse und Pflegeaufwand"

dependencies:
  - "tempdb temporary tables"
  - "STRING_SPLIT"
  - "TRY_CONVERT"
  - "ROW_NUMBER"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/04_Where/SQLScripts/InListParameterizationDemo.md"
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
    description: "Erstversion fuer ein didaktisches Lab zu kleinen und groesseren IN-Listen"

notes:
  - "Das Skript arbeitet ausschliesslich mit tempdb-Objekten und Demo-Daten."
  - "Groessere Listen werden als bereinigte Join-Menge statt als lange Literal-IN-Liste umgesetzt."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @IncludeLargeList BIT = 1;
DECLARE @LargeCustomerCsv NVARCHAR(MAX) = N'102, 104, 105, 105, 999, abc, 110, 112';
DECLARE @MinOrderAmount DECIMAL(10, 2) = 100.00;

IF @IncludeLargeList NOT IN (0, 1)
BEGIN
    THROW 50410, '@IncludeLargeList muss 0 oder 1 sein.', 1;
END;

IF @LargeCustomerCsv IS NULL OR LTRIM(RTRIM(@LargeCustomerCsv)) = N''
BEGIN
    THROW 50411, '@LargeCustomerCsv darf nicht leer sein.', 1;
END;

IF @MinOrderAmount < 0
BEGIN
    THROW 50412, '@MinOrderAmount darf nicht negativ sein.', 1;
END;

DROP TABLE IF EXISTS #Orders;
DROP TABLE IF EXISTS #LargeListTokens;

CREATE TABLE #Orders
(
    OrderID INT NOT NULL PRIMARY KEY,
    CustomerID INT NOT NULL,
    CustomerName NVARCHAR(80) NOT NULL,
    RegionCode CHAR(2) NOT NULL,
    OrderAmount DECIMAL(10, 2) NOT NULL,
    OrderDate DATE NOT NULL
);

CREATE TABLE #LargeListTokens
(
    TokenOrdinal INT NOT NULL,
    RawToken NVARCHAR(50) NOT NULL,
    ParsedCustomerID INT NULL
);

INSERT INTO #Orders
(
    OrderID,
    CustomerID,
    CustomerName,
    RegionCode,
    OrderAmount,
    OrderDate
)
VALUES
    (1001, 101, N'Alpenmarkt GmbH', 'DE', 95.00, '2026-01-14'),
    (1002, 102, N'Berg & Tal AG', 'AT', 180.00, '2026-01-18'),
    (1003, 103, N'City Bikes GmbH', 'DE', 140.00, '2026-01-22'),
    (1004, 104, N'Delta Retail SA', 'CH', 210.00, '2026-01-30'),
    (1005, 105, N'Elbe Office KG', 'DE', 125.00, '2026-02-02'),
    (1006, 106, N'Foxtrot Fashion GmbH', 'AT', 320.00, '2026-02-04'),
    (1007, 107, N'Gamma Gastro AG', 'CH', 88.00, '2026-02-10'),
    (1008, 108, N'Hafenmarkt GmbH', 'DE', 260.00, '2026-02-14'),
    (1009, 109, N'Inselhandel eG', 'AT', 115.00, '2026-02-20'),
    (1010, 110, N'Jura Technik AG', 'CH', 470.00, '2026-02-25'),
    (1011, 111, N'Kuestenbedarf GmbH', 'DE', 102.00, '2026-03-01'),
    (1012, 112, N'Luna Logistics AG', 'AT', 540.00, '2026-03-05');

INSERT INTO #LargeListTokens
(
    TokenOrdinal,
    RawToken,
    ParsedCustomerID
)
SELECT
    ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS TokenOrdinal,
    LTRIM(RTRIM(split_item.value)) AS RawToken,
    TRY_CONVERT(INT, LTRIM(RTRIM(split_item.value))) AS ParsedCustomerID
FROM STRING_SPLIT(@LargeCustomerCsv, N',') AS split_item;

;WITH SmallList AS
(
    SELECT list_item.CustomerID
    FROM
    (
        VALUES (102), (105), (110)
    ) AS list_item(CustomerID)
),
SmallListMatches AS
(
    SELECT
        o.OrderID,
        o.CustomerID,
        o.CustomerName,
        o.RegionCode,
        o.OrderAmount,
        o.OrderDate,
        'inline-values' AS PatternUsed
    FROM #Orders AS o
    INNER JOIN SmallList AS sl
        ON sl.CustomerID = o.CustomerID
    WHERE o.OrderAmount >= @MinOrderAmount
)
SELECT
    slm.OrderID,
    slm.CustomerID,
    slm.CustomerName,
    slm.RegionCode,
    slm.OrderAmount,
    slm.OrderDate,
    slm.PatternUsed
FROM SmallListMatches AS slm
ORDER BY
    slm.CustomerID,
    slm.OrderDate;

;WITH ValidLargeList AS
(
    SELECT DISTINCT
        llt.ParsedCustomerID AS CustomerID
    FROM #LargeListTokens AS llt
    WHERE llt.ParsedCustomerID IS NOT NULL
),
LargeListMatches AS
(
    SELECT
        o.OrderID,
        o.CustomerID,
        o.CustomerName,
        o.RegionCode,
        o.OrderAmount,
        o.OrderDate,
        'split-join' AS PatternUsed
    FROM #Orders AS o
    INNER JOIN ValidLargeList AS vll
        ON vll.CustomerID = o.CustomerID
    WHERE @IncludeLargeList = 1
      AND o.OrderAmount >= @MinOrderAmount
)
SELECT
    llm.OrderID,
    llm.CustomerID,
    llm.CustomerName,
    llm.RegionCode,
    llm.OrderAmount,
    llm.OrderDate,
    llm.PatternUsed
FROM LargeListMatches AS llm
ORDER BY
    llm.CustomerID,
    llm.OrderDate;

;WITH TokenQuality AS
(
    SELECT
        COUNT(*) AS RawTokenCount,
        SUM(CASE WHEN ParsedCustomerID IS NOT NULL THEN 1 ELSE 0 END) AS ValidTokenCount,
        SUM(CASE WHEN ParsedCustomerID IS NULL THEN 1 ELSE 0 END) AS InvalidTokenCount,
        COUNT(DISTINCT ParsedCustomerID) AS DistinctValidCustomerCount
    FROM #LargeListTokens
),
StrategyComparison AS
(
    SELECT
        'small-inline-values' AS StrategyName,
        'bis etwa 3-10 stabile Werte' AS TypicalScale,
        'VALUES-Konstruktor oder kurze IN-Liste im Statement' AS RecommendedPattern,
        'Einfach lesbar, wenig Parsing, ideal fuer konstante Demo- oder UI-Filter' AS TeachingNote
    UNION ALL
    SELECT
        'large-split-join',
        'groessere oder variierende Listen',
        'CSV aufbereiten, validieren, deduplizieren und per Join filtern',
        'Bessere Pflege und Validierung als sehr lange Literal-IN-Listen'
)
SELECT
    sc.StrategyName,
    sc.TypicalScale,
    sc.RecommendedPattern,
    sc.TeachingNote,
    tq.RawTokenCount,
    tq.ValidTokenCount,
    tq.InvalidTokenCount,
    tq.DistinctValidCustomerCount,
    CASE
        WHEN sc.StrategyName = 'small-inline-values' THEN 'konstante kleine Liste'
        ELSE 'externe oder wechselnde Liste'
    END AS BestFitInputShape
FROM StrategyComparison AS sc
CROSS JOIN TokenQuality AS tq
ORDER BY
    CASE sc.StrategyName
        WHEN 'small-inline-values' THEN 1
        ELSE 2
    END;
