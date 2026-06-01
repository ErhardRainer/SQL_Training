/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "SelectTopPercentDemo.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "02_Select"

purpose: >
  Demonstriert an einem kleinen Demo-Datensatz, wie TOP (PERCENT) die
  Rueckgabemenge aus einer Prozentangabe ableitet, warum kleine Prozentwerte
  auf ganze Zeilen aufgerundet werden und weshalb die ORDER BY-Richtung die
  ausgewaehlten Zeilen bestimmt.

parameters:
  - name: "@TopPercent"
    sql_type: "DECIMAL(5,2)"
    direction: "IN"
    required: false
    description: "Prozentanteil der Zeilen, die ueber TOP (PERCENT) ausgewaehlt werden sollen"
  - name: "@RegionFilter"
    sql_type: "NVARCHAR(20)"
    direction: "IN"
    required: false
    description: "Optionaler Filter auf eine Region des Demo-Datensatzes"
  - name: "@IncludeAscendingComparison"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zusaetzlich eine Gegenprobe mit aufsteigender Sortierung ausgeben"
  - name: "@ShowPercentCatalog"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = ein zusaetzliches Resultset mit Merkregeln zu TOP (PERCENT) anzeigen"

result_sets:
  - name: "PercentCatalog"
    description: "Optionale Uebersicht der zentralen Beobachtungen zu TOP (PERCENT)"
  - name: "PercentSelectionPreview"
    description: "Zeigt fuer jede Zeile Rang, erwartete Zielgroesse und Auswahlmarker fuer die verglichenen TOP-PERCENT-Szenarien"
  - name: "PercentSelectionSummary"
    description: "Verdichtet Rueckgabemenge, Grenzwerte und ausgewaehlte IDs pro Szenario"

dependencies:
  - "Table variable"
  - "CTE"
  - "TOP PERCENT"
  - "ROW_NUMBER"
  - "COUNT OVER"
  - "CEILING"
  - "CASE"
  - "STRING_AGG"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/02_Select/SQLScripts/SelectTopPercentDemo.md"
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
    date: "2026-04-19"
    user: "ER"
    description: "Erstversion des Labs zu TOP (PERCENT) und seiner abgeleiteten Zeilenzahl"

notes:
  - "Das Lab nutzt nur eingebettete Demo-Daten und keine produktiven Tabellen."
  - "Die erwartete Zielgroesse wird didaktisch ueber CEILING(total_rows * percent / 100.0) erklaert."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @TopPercent DECIMAL(5,2) = 25.00;
DECLARE @RegionFilter NVARCHAR(20) = NULL;
DECLARE @IncludeAscendingComparison BIT = 1;
DECLARE @ShowPercentCatalog BIT = 1;

DECLARE @DemoOrders TABLE
(
    OrderID INT NOT NULL,
    CustomerName NVARCHAR(60) NOT NULL,
    RegionCode NVARCHAR(20) NOT NULL,
    OrderDate DATE NOT NULL,
    Quantity INT NOT NULL,
    UnitPrice DECIMAL(10,2) NOT NULL,
    DiscountRate DECIMAL(5,2) NOT NULL,
    MarginPercent DECIMAL(5,2) NOT NULL
);

SET @RegionFilter = NULLIF(LTRIM(RTRIM(@RegionFilter)), N'');

IF @TopPercent <= 0 OR @TopPercent > 100
BEGIN
    THROW 50000, '@TopPercent muss groesser als 0 und kleiner oder gleich 100 sein.', 1;
END;

IF @IncludeAscendingComparison NOT IN (0, 1)
BEGIN
    THROW 50001, '@IncludeAscendingComparison muss 0 oder 1 sein.', 1;
END;

IF @ShowPercentCatalog NOT IN (0, 1)
BEGIN
    THROW 50002, '@ShowPercentCatalog muss 0 oder 1 sein.', 1;
END;

INSERT INTO @DemoOrders
(
    OrderID,
    CustomerName,
    RegionCode,
    OrderDate,
    Quantity,
    UnitPrice,
    DiscountRate,
    MarginPercent
)
VALUES
    (5201, 'Alpenmarkt GmbH',   'DE-NORTH',   CAST('2026-04-03' AS DATE), 12, CAST( 44.00 AS DECIMAL(10,2)), CAST(0.02 AS DECIMAL(5,2)), CAST(0.29 AS DECIMAL(5,2))),
    (5202, 'Bergblick AG',      'AT-WEST',    CAST('2026-04-04' AS DATE),  5, CAST(180.00 AS DECIMAL(10,2)), CAST(0.00 AS DECIMAL(5,2)), CAST(0.22 AS DECIMAL(5,2))),
    (5203, 'City Clinic',       'CH-CENTRAL', CAST('2026-04-05' AS DATE),  2, CAST(640.00 AS DECIMAL(10,2)), CAST(0.03 AS DECIMAL(5,2)), CAST(0.34 AS DECIMAL(5,2))),
    (5204, 'Delta Stores',      'DE-SOUTH',   CAST('2026-04-06' AS DATE), 20, CAST( 18.50 AS DECIMAL(10,2)), CAST(0.08 AS DECIMAL(5,2)), CAST(0.18 AS DECIMAL(5,2))),
    (5205, 'Eiger Systems',     'DE-NORTH',   CAST('2026-04-07' AS DATE),  1, CAST(990.00 AS DECIMAL(10,2)), CAST(0.10 AS DECIMAL(5,2)), CAST(0.41 AS DECIMAL(5,2))),
    (5206, 'Fjord Retail',      'AT-WEST',    CAST('2026-04-08' AS DATE),  8, CAST( 74.00 AS DECIMAL(10,2)), CAST(0.04 AS DECIMAL(5,2)), CAST(0.24 AS DECIMAL(5,2))),
    (5207, 'Green Labs',        'CH-CENTRAL', CAST('2026-04-09' AS DATE), 15, CAST( 49.00 AS DECIMAL(10,2)), CAST(0.05 AS DECIMAL(5,2)), CAST(0.27 AS DECIMAL(5,2))),
    (5208, 'Hanseatik Retail',  'DE-NORTH',   CAST('2026-04-10' AS DATE),  6, CAST( 96.00 AS DECIMAL(10,2)), CAST(0.06 AS DECIMAL(5,2)), CAST(0.21 AS DECIMAL(5,2)));

IF @ShowPercentCatalog = 1
BEGIN
    SELECT
        notes.RuleName,
        notes.ExampleObservation,
        notes.TeachingIntent
    FROM
    (
        VALUES
            ('Percent to rows', '8 Zeilen bei 25 Prozent ergeben 2 Rueckgabezeilen.', 'TOP (PERCENT) arbeitet intern auf einer Zeilenzahl, nicht auf Bruchteilen einer Zeile.'),
            ('Rounding up', '5 Zeilen bei 10 Prozent fuehren didaktisch zu 1 Rueckgabezeile.', 'Kleine Prozentwerte koennen trotzdem mindestens eine Zeile liefern, wenn die Grundmenge nicht leer ist.'),
            ('ORDER BY matters', 'DESC waehlt hohe Werte, ASC waehlt niedrige Werte.', 'Der Prozentanteil sagt nichts ueber die fachliche Bedeutung der Auswahl ohne Sortierlogik aus.')
    ) AS notes
    (
        RuleName,
        ExampleObservation,
        TeachingIntent
    )
    ORDER BY
        notes.RuleName;
END;

;WITH FilteredOrders AS
(
    SELECT
        d.OrderID,
        d.CustomerName,
        d.RegionCode,
        d.OrderDate,
        d.Quantity,
        d.UnitPrice,
        d.DiscountRate,
        d.MarginPercent,
        CAST(d.Quantity * d.UnitPrice AS DECIMAL(12,2)) AS GrossAmount,
        CAST((d.Quantity * d.UnitPrice) * (1 - d.DiscountRate) AS DECIMAL(12,2)) AS NetAmount
    FROM @DemoOrders AS d
    WHERE @RegionFilter IS NULL
       OR d.RegionCode = @RegionFilter
),
PreparedRows AS
(
    SELECT
        f.OrderID,
        f.CustomerName,
        f.RegionCode,
        f.OrderDate,
        f.Quantity,
        f.UnitPrice,
        f.DiscountRate,
        f.MarginPercent,
        f.GrossAmount,
        f.NetAmount,
        COUNT(*) OVER () AS TotalRows,
        ROW_NUMBER() OVER
        (
            ORDER BY
                f.NetAmount DESC,
                f.OrderDate DESC,
                f.OrderID DESC
        ) AS DescendingRowNumber,
        ROW_NUMBER() OVER
        (
            ORDER BY
                f.NetAmount ASC,
                f.OrderDate ASC,
                f.OrderID ASC
        ) AS AscendingRowNumber
    FROM FilteredOrders AS f
),
PreviewRows AS
(
    SELECT
        p.OrderID,
        p.CustomerName,
        p.RegionCode,
        p.OrderDate,
        p.Quantity,
        p.UnitPrice,
        p.DiscountRate,
        p.MarginPercent,
        p.GrossAmount,
        p.NetAmount,
        p.TotalRows,
        CAST(CEILING(p.TotalRows * @TopPercent / 100.0) AS INT) AS ExpectedSelectedRows,
        p.DescendingRowNumber,
        p.AscendingRowNumber,
        CASE
            WHEN p.DescendingRowNumber <= CEILING(p.TotalRows * @TopPercent / 100.0) THEN 'selected'
            ELSE 'not_selected'
        END AS DescendingSelectionFlag,
        CASE
            WHEN p.AscendingRowNumber <= CEILING(p.TotalRows * @TopPercent / 100.0) THEN 'selected'
            ELSE 'not_selected'
        END AS AscendingSelectionFlag
    FROM PreparedRows AS p
),
ComparisonRows AS
(
    SELECT
        'top_percent_desc' AS ScenarioKey,
        'TOP (@TopPercent) PERCENT ORDER BY NetAmount DESC, OrderDate DESC, OrderID DESC' AS OrderByPattern,
        s.OrderID,
        s.CustomerName,
        s.RegionCode,
        s.OrderDate,
        s.NetAmount,
        s.TotalRows,
        s.DescendingRowNumber AS ScenarioRowNumber
    FROM
    (
        SELECT TOP (@TopPercent) PERCENT
            p.OrderID,
            p.CustomerName,
            p.RegionCode,
            p.OrderDate,
            p.NetAmount,
            p.TotalRows,
            p.DescendingRowNumber
        FROM PreparedRows AS p
        ORDER BY
            p.NetAmount DESC,
            p.OrderDate DESC,
            p.OrderID DESC
    ) AS s

    UNION ALL

    SELECT
        'top_percent_asc' AS ScenarioKey,
        'TOP (@TopPercent) PERCENT ORDER BY NetAmount ASC, OrderDate ASC, OrderID ASC' AS OrderByPattern,
        s.OrderID,
        s.CustomerName,
        s.RegionCode,
        s.OrderDate,
        s.NetAmount,
        s.TotalRows,
        s.AscendingRowNumber AS ScenarioRowNumber
    FROM
    (
        SELECT TOP (@TopPercent) PERCENT
            p.OrderID,
            p.CustomerName,
            p.RegionCode,
            p.OrderDate,
            p.NetAmount,
            p.TotalRows,
            p.AscendingRowNumber
        FROM PreparedRows AS p
        WHERE @IncludeAscendingComparison = 1
        ORDER BY
            p.NetAmount ASC,
            p.OrderDate ASC,
            p.OrderID ASC
    ) AS s
),
ScenarioSummary AS
(
    SELECT
        c.ScenarioKey,
        MIN(c.OrderByPattern) AS OrderByPattern,
        MIN(c.TotalRows) AS TotalRows,
        CAST(CEILING(MIN(c.TotalRows) * @TopPercent / 100.0) AS INT) AS ExpectedSelectedRows,
        COUNT(*) AS ReturnedRows,
        MIN(c.NetAmount) AS LowestReturnedNetAmount,
        MAX(c.NetAmount) AS HighestReturnedNetAmount,
        STRING_AGG(CAST(c.OrderID AS varchar(20)), ', ') WITHIN GROUP (ORDER BY c.ScenarioRowNumber ASC) AS SelectedOrderIDs
    FROM ComparisonRows AS c
    GROUP BY
        c.ScenarioKey
)
SELECT
    @TopPercent AS AppliedTopPercent,
    @RegionFilter AS AppliedRegionFilter,
    @IncludeAscendingComparison AS AppliedAscendingComparison,
    pr.OrderID,
    pr.CustomerName,
    pr.RegionCode,
    pr.OrderDate,
    pr.Quantity,
    pr.UnitPrice,
    pr.DiscountRate,
    pr.MarginPercent,
    pr.GrossAmount,
    pr.NetAmount,
    pr.TotalRows,
    pr.ExpectedSelectedRows,
    pr.DescendingRowNumber,
    pr.AscendingRowNumber,
    pr.DescendingSelectionFlag,
    pr.AscendingSelectionFlag
FROM PreviewRows AS pr
ORDER BY
    pr.DescendingRowNumber;

SELECT
    ss.ScenarioKey,
    ss.OrderByPattern,
    ss.TotalRows,
    ss.ExpectedSelectedRows,
    ss.ReturnedRows,
    ss.LowestReturnedNetAmount,
    ss.HighestReturnedNetAmount,
    ss.SelectedOrderIDs
FROM ScenarioSummary AS ss
ORDER BY
    ss.ScenarioKey;
