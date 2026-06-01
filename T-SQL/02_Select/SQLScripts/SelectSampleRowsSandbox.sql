/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "SelectSampleRowsSandbox.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "02_Select"

purpose: >
  Bietet eine sichere Sandbox fuer Stichproben und erste Datenexploration mit
  SELECT auf einem didaktischen Auftragsdatensatz.

parameters:
  - name: "@SampleSize"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Anzahl der Zeilen fuer die Stichprobe"
  - name: "@SampleMode"
    sql_type: "NVARCHAR(20)"
    direction: "IN"
    required: false
    description: "Stichprobenmodus latest, high_value oder every_nth"
  - name: "@EveryNthRow"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Intervall fuer den Modus every_nth"
  - name: "@RegionFilter"
    sql_type: "NVARCHAR(20)"
    direction: "IN"
    required: false
    description: "Optionaler Filter auf eine Region"
  - name: "@ShowSamplingNotes"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zusaetzliche Einordnung der Stichprobenmodi anzeigen"

result_sets:
  - name: "SamplingNotes"
    description: "Optionale Einordnung der verfuegbaren Stichprobenmodi"
  - name: "SampleRows"
    description: "Gezogene Stichprobe mit Basiskennzahlen und Explorationsspalten"
  - name: "SampleSummary"
    description: "Verdichtung der gezogenen Stichprobe nach Region und Status"

dependencies:
  - "CTE"
  - "VALUES constructor"
  - "ROW_NUMBER"
  - "CASE"
  - "DATEADD"
  - "DATEDIFF"
  - "TOP"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/02_Select/SQLScripts/SelectSampleRowsSandbox.md"
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
    description: "Erstversion der Sandbox fuer Stichproben und erste Datenexploration mit SELECT"

notes:
  - "Die Sandbox arbeitet ausschliesslich mit eingebetteten Demo-Daten"
  - "Die Stichprobe ist didaktisch nachvollziehbar und verwendet bewusst keine nicht deterministische Zufallslogik"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @SampleSize INT = 3;
DECLARE @SampleMode NVARCHAR(20) = N'latest';
DECLARE @EveryNthRow INT = 2;
DECLARE @RegionFilter NVARCHAR(20) = NULL;
DECLARE @ShowSamplingNotes BIT = 1;

SET @SampleMode = LOWER(LTRIM(RTRIM(@SampleMode)));
SET @RegionFilter = NULLIF(LTRIM(RTRIM(@RegionFilter)), N'');

IF @SampleSize < 1
BEGIN
    THROW 50000, '@SampleSize muss groesser oder gleich 1 sein.', 1;
END;

IF @SampleMode NOT IN (N'latest', N'high_value', N'every_nth')
BEGIN
    THROW 50001, '@SampleMode muss latest, high_value oder every_nth sein.', 1;
END;

IF @EveryNthRow < 1
BEGIN
    THROW 50002, '@EveryNthRow muss groesser oder gleich 1 sein.', 1;
END;

IF @ShowSamplingNotes NOT IN (0, 1)
BEGIN
    THROW 50003, '@ShowSamplingNotes muss 0 oder 1 sein.', 1;
END;

IF @ShowSamplingNotes = 1
BEGIN
    SELECT
        notes.SampleMode,
        notes.SelectionIdea,
        notes.TeachingIntent
    FROM
    (
        VALUES
            ('latest', 'Neueste OrderDate-Werte zuerst', 'Zeigt TOP, ORDER BY und eine zeitlich orientierte Sicht auf neue Daten.'),
            ('high_value', 'Hoechster NetAmount zuerst', 'Zeigt eine fachliche Priorisierung nach Umsatz oder Volumen.'),
            ('every_nth', 'Jede n-te Zeile der stabil sortierten Grundmenge', 'Zeigt eine einfache, deterministische Stichprobe fuer Exploration und Kontrolle.')
    ) AS notes
    (
        SampleMode,
        SelectionIdea,
        TeachingIntent
    )
    ORDER BY
        notes.SampleMode;
END;

;WITH DemoOrders AS
(
    SELECT
        sample.OrderID,
        sample.CustomerName,
        sample.RegionCode,
        sample.OrderDate,
        sample.Quantity,
        sample.UnitPrice,
        sample.DiscountRate,
        sample.StatusCode,
        sample.OwnerName
    FROM
    (
        VALUES
            (4101, 'Alpenmarkt GmbH', 'DE-NORTH', CAST('2026-04-07' AS DATE), 12, CAST(29.90 AS DECIMAL(10,2)), CAST(0.05 AS DECIMAL(5,2)), 'A', 'Nora'),
            (4102, 'Bergwerk AG', 'AT-WEST', CAST('2026-04-08' AS DATE), 4, CAST(180.00 AS DECIMAL(10,2)), CAST(0.00 AS DECIMAL(5,2)), 'P', 'Ivo'),
            (4103, 'City Clinic', 'CH-CENTRAL', CAST('2026-04-09' AS DATE), 2, CAST(520.00 AS DECIMAL(10,2)), CAST(0.02 AS DECIMAL(5,2)), 'A', 'Mina'),
            (4104, 'Delta Stores', 'DE-SOUTH', CAST('2026-04-10' AS DATE), 30, CAST(15.50 AS DECIMAL(10,2)), CAST(0.08 AS DECIMAL(5,2)), 'D', 'Tariq'),
            (4105, 'Eiger Systems', 'DE-NORTH', CAST('2026-04-11' AS DATE), 1, CAST(1290.00 AS DECIMAL(10,2)), CAST(0.10 AS DECIMAL(5,2)), 'A', 'Nora'),
            (4106, 'Fjord Retail', 'AT-WEST', CAST('2026-04-12' AS DATE), 8, CAST(74.00 AS DECIMAL(10,2)), CAST(0.03 AS DECIMAL(5,2)), 'P', 'Ivo'),
            (4107, 'Green Labs', 'CH-CENTRAL', CAST('2026-04-13' AS DATE), 15, CAST(48.00 AS DECIMAL(10,2)), CAST(0.04 AS DECIMAL(5,2)), 'A', 'Mina'),
            (4108, 'Hanseatik Retail', 'DE-NORTH', CAST('2026-04-14' AS DATE), 6, CAST(96.00 AS DECIMAL(10,2)), CAST(0.06 AS DECIMAL(5,2)), 'P', 'Nora')
    ) AS sample
    (
        OrderID,
        CustomerName,
        RegionCode,
        OrderDate,
        Quantity,
        UnitPrice,
        DiscountRate,
        StatusCode,
        OwnerName
    )
),
PreparedRows AS
(
    SELECT
        d.OrderID,
        d.CustomerName,
        d.RegionCode,
        d.OrderDate,
        d.Quantity,
        d.UnitPrice,
        d.DiscountRate,
        d.StatusCode,
        d.OwnerName,
        CAST(d.Quantity * d.UnitPrice AS DECIMAL(12,2)) AS GrossAmount,
        CAST((d.Quantity * d.UnitPrice) * (1 - d.DiscountRate) AS DECIMAL(12,2)) AS NetAmount,
        DATEADD(DAY, 7, d.OrderDate) AS ExpectedFollowUpDate,
        DATEDIFF(DAY, d.OrderDate, DATEADD(DAY, 7, d.OrderDate)) AS ReviewHorizonDays,
        CASE d.StatusCode
            WHEN 'A' THEN 'active'
            WHEN 'P' THEN 'planned'
            ELSE 'draft'
        END AS StatusLabel
    FROM DemoOrders AS d
    WHERE @RegionFilter IS NULL
       OR d.RegionCode = @RegionFilter
),
OrderedRows AS
(
    SELECT
        p.*,
        ROW_NUMBER() OVER
        (
            ORDER BY
                p.OrderDate DESC,
                p.OrderID DESC
        ) AS LatestOrderRowNumber,
        ROW_NUMBER() OVER
        (
            ORDER BY
                p.NetAmount DESC,
                p.OrderDate DESC,
                p.OrderID DESC
        ) AS HighValueRowNumber,
        ROW_NUMBER() OVER
        (
            ORDER BY
                p.RegionCode,
                p.OrderDate,
                p.OrderID
        ) AS ExplorationRowNumber
    FROM PreparedRows AS p
),
SampleRows AS
(
    SELECT TOP (@SampleSize)
        o.OrderID,
        o.CustomerName,
        o.RegionCode,
        o.OrderDate,
        o.Quantity,
        o.UnitPrice,
        o.DiscountRate,
        o.GrossAmount,
        o.NetAmount,
        o.StatusCode,
        o.StatusLabel,
        o.OwnerName,
        o.ExpectedFollowUpDate,
        o.ReviewHorizonDays,
        o.LatestOrderRowNumber,
        o.HighValueRowNumber,
        o.ExplorationRowNumber,
        CASE @SampleMode
            WHEN N'latest' THEN 'Latest order date'
            WHEN N'high_value' THEN 'Highest net amount'
            ELSE 'Every nth exploration row'
        END AS SelectionReason
    FROM OrderedRows AS o
    WHERE (
            @SampleMode = N'latest'
            AND o.LatestOrderRowNumber <= @SampleSize
          )
       OR (
            @SampleMode = N'high_value'
            AND o.HighValueRowNumber <= @SampleSize
          )
       OR (
            @SampleMode = N'every_nth'
            AND o.ExplorationRowNumber % @EveryNthRow = 0
          )
    ORDER BY
        CASE @SampleMode
            WHEN N'latest' THEN o.LatestOrderRowNumber
            WHEN N'high_value' THEN o.HighValueRowNumber
            ELSE o.ExplorationRowNumber
        END,
        o.OrderID
)
SELECT
    @SampleMode AS AppliedSampleMode,
    @SampleSize AS AppliedSampleSize,
    @EveryNthRow AS AppliedEveryNthRow,
    s.OrderID,
    s.CustomerName,
    s.RegionCode,
    s.OrderDate,
    s.Quantity,
    s.UnitPrice,
    s.DiscountRate,
    s.GrossAmount,
    s.NetAmount,
    s.StatusCode,
    s.StatusLabel,
    s.OwnerName,
    s.ExpectedFollowUpDate,
    s.ReviewHorizonDays,
    s.SelectionReason,
    s.LatestOrderRowNumber,
    s.HighValueRowNumber,
    s.ExplorationRowNumber
FROM SampleRows AS s
ORDER BY
    CASE @SampleMode
        WHEN N'latest' THEN s.LatestOrderRowNumber
        WHEN N'high_value' THEN s.HighValueRowNumber
        ELSE s.ExplorationRowNumber
    END,
    s.OrderID;

SELECT
    s.RegionCode,
    s.StatusLabel,
    COUNT(*) AS SampleRowCount,
    CAST(SUM(s.NetAmount) AS DECIMAL(12,2)) AS NetAmountTotal,
    CAST(AVG(s.NetAmount) AS DECIMAL(12,2)) AS NetAmountAverage,
    MIN(s.OrderDate) AS OldestOrderDate,
    MAX(s.OrderDate) AS NewestOrderDate
FROM SampleRows AS s
GROUP BY
    s.RegionCode,
    s.StatusLabel
ORDER BY
    s.RegionCode,
    s.StatusLabel;
