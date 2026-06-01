/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "SelectOutputFormattingExamples.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "02_Select"

purpose: >
  Zeigt mehrere Anzeigeformate direkt in der SELECT-Liste, darunter
  Datumsdarstellungen, einfache Betragsformate, Prozentlabels und kompakte
  Statusbanner auf einem didaktischen Demo-Datensatz.

parameters:
  - name: "@AsOfDate"
    sql_type: "DATE"
    direction: "IN"
    required: false
    description: "Stichtag fuer reproduzierbare Datums- und Restlaufzeitspalten"
  - name: "@CurrencyPrefix"
    sql_type: "NVARCHAR(10)"
    direction: "IN"
    required: false
    description: "Praefix fuer einfache Betragsanzeigen in der finalen Projektion"
  - name: "@IncludeBacklogRows"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = auch Demo-Zeilen mit Status Backlog in die Hauptausgabe aufnehmen"
  - name: "@ShowFormatCatalog"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zusaetzliches Resultset mit den verwendeten Formatmustern anzeigen"

result_sets:
  - name: "FormatCatalog"
    description: "Optionaler Ueberblick ueber die im Skript verwendeten Anzeigeformate"
  - name: "FormattedSelectOutput"
    description: "Hauptausgabe mit mehreren Anzeigeformaten direkt in der SELECT-Liste"

dependencies:
  - "CTE"
  - "VALUES constructor"
  - "CASE"
  - "CAST"
  - "CONCAT"
  - "CONVERT"
  - "RIGHT"
  - "REPLICATE"
  - "STR"
  - "UPPER"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/02_Select/SQLScripts/SelectOutputFormattingExamples.md"
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
    description: "Erstversion des Labs fuer Anzeigeformate direkt in der SELECT-Liste"

notes:
  - "Die Umsetzung arbeitet ausschliesslich mit eingebetteten Demo-Daten"
  - "Die Anzeigeformate bleiben bewusst transparent und verzichten auf komplexe Lokalisierungslogik"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @AsOfDate DATE = '2026-04-19';
DECLARE @CurrencyPrefix NVARCHAR(10) = N'EUR ';
DECLARE @IncludeBacklogRows BIT = 0;
DECLARE @ShowFormatCatalog BIT = 1;

IF @AsOfDate IS NULL
BEGIN
    THROW 50000, '@AsOfDate darf nicht NULL sein.', 1;
END;

IF @CurrencyPrefix IS NULL OR LTRIM(RTRIM(@CurrencyPrefix)) = N''
BEGIN
    THROW 50001, '@CurrencyPrefix darf nicht leer sein.', 1;
END;

IF @IncludeBacklogRows NOT IN (0, 1)
BEGIN
    THROW 50002, '@IncludeBacklogRows muss 0 oder 1 sein.', 1;
END;

IF @ShowFormatCatalog NOT IN (0, 1)
BEGIN
    THROW 50003, '@ShowFormatCatalog muss 0 oder 1 sein.', 1;
END;

IF @ShowFormatCatalog = 1
BEGIN
    SELECT
        catalog.FormatPattern,
        catalog.ExampleExpression,
        catalog.TeachingIntent
    FROM
    (
        VALUES
            ('ISO date', 'CONVERT(char(10), ShipDate, 23)', 'Technisch stabiles Datumsformat fuer Vergleiche und Export'),
            ('DACH date', 'CONVERT(char(10), ShipDate, 104)', 'Menschenlesbares Datumsformat fuer Berichte'),
            ('Currency label', 'CONCAT(@CurrencyPrefix, LTRIM(STR(NetAmount, 12, 2)))', 'Einfache Anzeige eines Betrags ohne FORMAT-Abhaengigkeit'),
            ('Percent label', 'CONCAT(CAST(CAST(DiscountRate * 100.0 AS DECIMAL(5,1)) AS varchar(10)), '' %'')', 'Rabattquote als Text fuer die Berichtssicht'),
            ('Status banner', 'CONCAT(UPPER(ChannelCode), '' / '', StatusLabel)', 'Verdichtet Kanal und Status in einer kompakten Spalte')
    ) AS catalog
    (
        FormatPattern,
        ExampleExpression,
        TeachingIntent
    )
    ORDER BY
        catalog.FormatPattern;
END;

;WITH DemoOrders AS
(
    SELECT
        sample.OrderID,
        sample.CustomerName,
        sample.ChannelCode,
        sample.OrderDate,
        sample.ShipDate,
        sample.Quantity,
        sample.UnitPrice,
        sample.DiscountRate,
        sample.StatusCode
    FROM
    (
        VALUES
            (6201, 'Alpenmarkt GmbH', 'web',   CAST('2026-04-10' AS DATE), CAST('2026-04-18' AS DATE), 12, CAST( 39.90 AS DECIMAL(10,2)), CAST(0.05 AS DECIMAL(5,2)), 'A'),
            (6202, 'Bergblick AG',    'store', CAST('2026-04-11' AS DATE), CAST('2026-04-21' AS DATE),  5, CAST(125.00 AS DECIMAL(10,2)), CAST(0.00 AS DECIMAL(5,2)), 'P'),
            (6203, 'City Clinic',     'b2b',   CAST('2026-04-13' AS DATE), CAST('2026-04-22' AS DATE),  2, CAST(540.00 AS DECIMAL(10,2)), CAST(0.03 AS DECIMAL(5,2)), 'A'),
            (6204, 'Delta Stores',    'store', CAST('2026-04-14' AS DATE), CAST('2026-04-26' AS DATE), 20, CAST( 18.50 AS DECIMAL(10,2)), CAST(0.08 AS DECIMAL(5,2)), 'B'),
            (6205, 'Eiger Systems',   'web',   CAST('2026-04-15' AS DATE), CAST('2026-04-20' AS DATE),  1, CAST(980.00 AS DECIMAL(10,2)), CAST(0.10 AS DECIMAL(5,2)), 'A')
    ) AS sample
    (
        OrderID,
        CustomerName,
        ChannelCode,
        OrderDate,
        ShipDate,
        Quantity,
        UnitPrice,
        DiscountRate,
        StatusCode
    )
),
PreparedOrders AS
(
    SELECT
        d.OrderID,
        d.CustomerName,
        d.ChannelCode,
        d.OrderDate,
        d.ShipDate,
        d.Quantity,
        d.UnitPrice,
        d.DiscountRate,
        d.StatusCode,
        CAST(d.Quantity * d.UnitPrice AS DECIMAL(12,2)) AS GrossAmount,
        CAST((d.Quantity * d.UnitPrice) * (1 - d.DiscountRate) AS DECIMAL(12,2)) AS NetAmount,
        DATEDIFF(DAY, @AsOfDate, d.ShipDate) AS DaysUntilShip,
        CASE d.StatusCode
            WHEN 'A' THEN 'active'
            WHEN 'P' THEN 'planned'
            ELSE 'backlog'
        END AS StatusLabel,
        CASE
            WHEN d.Quantity >= 10 THEN 'bulk'
            WHEN d.Quantity >= 3 THEN 'standard'
            ELSE 'small'
        END AS QuantityBand
    FROM DemoOrders AS d
    WHERE @IncludeBacklogRows = 1
       OR d.StatusCode <> 'B'
)
SELECT
    'formatting-lab' AS ProjectionTag,
    p.OrderID,
    p.CustomerName,
    p.ChannelCode,
    p.OrderDate,
    p.ShipDate,
    CONVERT(char(10), p.ShipDate, 23) AS ShipDateIso,
    CONVERT(char(10), p.ShipDate, 104) AS ShipDateDach,
    p.Quantity,
    RIGHT(CONCAT('000', CAST(p.Quantity AS varchar(3))), 3) AS QuantityPadded,
    CONCAT(REPLICATE('*', CASE WHEN p.Quantity >= 10 THEN 3 WHEN p.Quantity >= 3 THEN 2 ELSE 1 END), ' ', p.QuantityBand) AS QuantityBadge,
    p.UnitPrice,
    p.GrossAmount,
    p.NetAmount,
    CONCAT(@CurrencyPrefix, LTRIM(STR(p.NetAmount, 12, 2))) AS NetAmountDisplay,
    CONCAT(CAST(CAST(p.DiscountRate * 100.0 AS DECIMAL(5,1)) AS varchar(10)), ' %') AS DiscountPercentLabel,
    CONCAT(UPPER(p.ChannelCode), ' / ', p.StatusLabel) AS ChannelStatusBanner,
    CONCAT('ship-', CASE WHEN p.DaysUntilShip < 0 THEN 'overdue' WHEN p.DaysUntilShip <= 2 THEN 'soon' ELSE 'later' END) AS ShipWindowLabel,
    CONCAT('days ', CASE WHEN p.DaysUntilShip >= 0 THEN '+' ELSE '' END, CAST(p.DaysUntilShip AS varchar(11))) AS ShipDeltaLabel
FROM PreparedOrders AS p
ORDER BY
    p.StatusLabel,
    p.NetAmount DESC,
    p.OrderID;
