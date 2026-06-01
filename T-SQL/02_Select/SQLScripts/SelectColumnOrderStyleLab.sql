/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "SelectColumnOrderStyleLab.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "02_Select"

purpose: >
  Demonstriert an einem kleinen Datensatz, wie eine konsistente
  Spaltenreihenfolge SELECT-Listen lesbarer macht und wie sich eine
  fachlich gruppierte Reihenfolge von einer ungeordneten Liste
  unterscheidet.

parameters:
  - name: "@ShowSourceData"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = den Ausgangsdatensatz zusaetzlich anzeigen"
  - name: "@ShowUnorderedExample"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = auch eine bewusst unruhige Spaltenliste ausgeben"
  - name: "@OnlyAttentionRows"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = nur Zeilen mit hohem Diskussionswert zur Spaltenordnung zeigen"

result_sets:
  - name: "SourceDataPreview"
    description: "Optionale Vorschau des didaktischen Demo-Datensatzes"
  - name: "UnorderedLayoutPreview"
    description: "Zeigt eine bewusst unruhige SELECT-Liste als Negativbeispiel"
  - name: "GroupedLayoutPreview"
    description: "Zeigt dieselben Daten in einer konsistent gruppierten SELECT-Liste"
  - name: "ColumnOrderChecklistSummary"
    description: "Verdichtet die Zeilen nach den verwendeten Ordnungsprinzipien"

dependencies:
  - "CTE"
  - "VALUES constructor"
  - "CASE"
  - "ROW_NUMBER"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/02_Select/SQLScripts/SelectColumnOrderStyleLab.md"
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
    description: "Erstversion des Labs fuer konsistente Spaltenreihenfolgen"

notes:
  - "Das Skript nutzt nur Demo-Daten und bleibt bewusst bei einem lesenden Lehrbeispiel"
  - "Die geordnete SELECT-Liste gruppiert Identitaet, Kontext, Zeit, Mengen und Kennzahlen"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @ShowSourceData BIT = 1;
DECLARE @ShowUnorderedExample BIT = 1;
DECLARE @OnlyAttentionRows BIT = 0;

IF @ShowSourceData NOT IN (0, 1)
BEGIN
    THROW 50000, '@ShowSourceData muss 0 oder 1 sein.', 1;
END;

IF @ShowUnorderedExample NOT IN (0, 1)
BEGIN
    THROW 50001, '@ShowUnorderedExample muss 0 oder 1 sein.', 1;
END;

IF @OnlyAttentionRows NOT IN (0, 1)
BEGIN
    THROW 50002, '@OnlyAttentionRows muss 0 oder 1 sein.', 1;
END;

;WITH SalesInbox AS
(
    SELECT
        sample.RequestID,
        sample.TeamName,
        sample.CustomerName,
        sample.RegionCode,
        sample.PriorityCode,
        sample.RequestDate,
        sample.DueDate,
        sample.Quantity,
        sample.UnitPrice,
        sample.DiscountRate,
        sample.OwnerName,
        sample.StatusCode
    FROM
    (
        VALUES
            (2001, 'Inside Sales', 'Alpine Retail', 'DE-NORTH', 'A', CAST('2026-04-07' AS DATE), CAST('2026-04-17' AS DATE), 12, CAST(39.50 AS DECIMAL(10,2)), CAST(0.05 AS DECIMAL(5,2)), 'Anika', 'Open'),
            (2002, 'Field Sales', 'Bergmann AG', 'AT-WEST', 'B', CAST('2026-04-08' AS DATE), CAST('2026-04-21' AS DATE), 4, CAST(210.00 AS DECIMAL(10,2)), CAST(0.12 AS DECIMAL(5,2)), 'Bora', 'Review'),
            (2003, 'Partner Desk', 'City Health', 'CH-CENTRAL', 'A', CAST('2026-04-09' AS DATE), CAST('2026-04-16' AS DATE), 2, CAST(650.00 AS DECIMAL(10,2)), CAST(0.03 AS DECIMAL(5,2)), 'Cem', 'Open'),
            (2004, 'Inside Sales', 'Delta Schools', 'DE-SOUTH', 'C', CAST('2026-04-10' AS DATE), CAST('2026-04-28' AS DATE), 20, CAST(18.00 AS DECIMAL(10,2)), CAST(0.00 AS DECIMAL(5,2)), 'Dina', 'Draft'),
            (2005, 'Key Accounts', 'Eiger Systems', 'DE-NORTH', 'A', CAST('2026-04-11' AS DATE), CAST('2026-04-18' AS DATE), 1, CAST(1200.00 AS DECIMAL(10,2)), CAST(0.10 AS DECIMAL(5,2)), 'Emir', 'Review'),
            (2006, 'Partner Desk', 'Fjord Clinic', 'AT-WEST', 'B', CAST('2026-04-12' AS DATE), CAST('2026-04-24' AS DATE), 9, CAST(84.00 AS DECIMAL(10,2)), CAST(0.07 AS DECIMAL(5,2)), 'Fina', 'Open')
    ) AS sample
    (
        RequestID,
        TeamName,
        CustomerName,
        RegionCode,
        PriorityCode,
        RequestDate,
        DueDate,
        Quantity,
        UnitPrice,
        DiscountRate,
        OwnerName,
        StatusCode
    )
),
PreparedData AS
(
    SELECT
        s.RequestID,
        s.TeamName,
        s.CustomerName,
        s.RegionCode,
        s.PriorityCode,
        s.RequestDate,
        s.DueDate,
        s.Quantity,
        s.UnitPrice,
        s.DiscountRate,
        s.OwnerName,
        s.StatusCode,
        CAST(s.Quantity * s.UnitPrice AS DECIMAL(12,2)) AS GrossAmount,
        CAST((s.Quantity * s.UnitPrice) * (1 - s.DiscountRate) AS DECIMAL(12,2)) AS NetAmount,
        DATEDIFF(DAY, s.RequestDate, s.DueDate) AS LeadTimeDays,
        CASE s.PriorityCode
            WHEN 'A' THEN 'Critical'
            WHEN 'B' THEN 'Planned'
            ELSE 'Routine'
        END AS PriorityLabel,
        CASE
            WHEN s.Quantity * s.UnitPrice >= 1000 THEN 'Large'
            WHEN s.Quantity * s.UnitPrice >= 300 THEN 'Medium'
            ELSE 'Small'
        END AS DealBand
    FROM SalesInbox AS s
),
AnnotatedRows AS
(
    SELECT
        p.*,
        CAST(CASE
            WHEN p.PriorityCode = 'A' THEN 1
            WHEN p.LeadTimeDays <= 8 THEN 1
            WHEN p.NetAmount >= 1000 THEN 1
            ELSE 0
        END AS BIT) AS NeedsAttention,
        CASE
            WHEN p.PriorityCode = 'A' THEN 'identity -> context -> timeline -> quantity -> amount'
            WHEN p.NetAmount >= 1000 THEN 'identity -> amount -> owner follow-up'
            ELSE 'identity -> context -> timeline -> status'
        END AS SuggestedOrderPattern,
        ROW_NUMBER() OVER
        (
            ORDER BY
                CASE p.PriorityCode WHEN 'A' THEN 1 WHEN 'B' THEN 2 ELSE 3 END,
                p.DueDate,
                p.RequestID
        ) AS ReviewSequence
    FROM PreparedData AS p
)
SELECT
    s.RequestID,
    s.TeamName,
    s.CustomerName,
    s.RegionCode,
    s.PriorityCode,
    s.RequestDate,
    s.DueDate,
    s.Quantity,
    s.UnitPrice,
    s.DiscountRate,
    s.OwnerName,
    s.StatusCode
FROM SalesInbox AS s
WHERE @ShowSourceData = 1
ORDER BY
    s.RequestID;

SELECT
    'unordered-example' AS LayoutName,
    'Zeigt absichtlich eine unruhige Mischung aus Kennzahlen, Status und Stammdaten.' AS LayoutComment,
    a.NetAmount,
    a.PriorityLabel,
    a.CustomerName,
    a.RequestID,
    a.OwnerName,
    a.RequestDate,
    a.TeamName,
    a.Quantity,
    a.DealBand,
    a.DueDate,
    a.StatusCode,
    a.LeadTimeDays,
    a.RegionCode,
    a.DiscountRate,
    a.UnitPrice,
    a.GrossAmount,
    a.NeedsAttention,
    a.SuggestedOrderPattern,
    a.ReviewSequence
FROM AnnotatedRows AS a
WHERE @ShowUnorderedExample = 1
  AND (@OnlyAttentionRows = 0 OR a.NeedsAttention = 1)
ORDER BY
    a.ReviewSequence;

SELECT
    'grouped-style' AS LayoutName,
    'Ordnet Identitaet, Kontext, Zeit, Mengen und Betraege in einem stabilen Lesefluss.' AS LayoutComment,
    a.RequestID,
    a.CustomerName,
    a.TeamName,
    a.RegionCode,
    a.PriorityLabel,
    a.StatusCode,
    a.RequestDate,
    a.DueDate,
    a.LeadTimeDays,
    a.Quantity,
    a.UnitPrice,
    a.DiscountRate,
    a.GrossAmount,
    a.NetAmount,
    a.OwnerName,
    a.DealBand,
    a.NeedsAttention,
    a.SuggestedOrderPattern,
    a.ReviewSequence
FROM AnnotatedRows AS a
WHERE @OnlyAttentionRows = 0 OR a.NeedsAttention = 1
ORDER BY
    a.ReviewSequence;

SELECT
    summary.LayoutName,
    summary.OrderingPrinciple,
    COUNT(*) AS MatchingRows
FROM
(
    SELECT
        'grouped-style' AS LayoutName,
        'identity-first' AS OrderingPrinciple
    FROM AnnotatedRows

    UNION ALL

    SELECT
        'grouped-style' AS LayoutName,
        'context-next' AS OrderingPrinciple
    FROM AnnotatedRows

    UNION ALL

    SELECT
        'grouped-style' AS LayoutName,
        'timeline-before-amounts' AS OrderingPrinciple
    FROM AnnotatedRows

    UNION ALL

    SELECT
        CASE WHEN @ShowUnorderedExample = 1 THEN 'unordered-example' ELSE 'grouped-style' END AS LayoutName,
        CASE
            WHEN NeedsAttention = 1 THEN 'attention-rows-visible'
            ELSE 'baseline-rows-visible'
        END AS OrderingPrinciple
    FROM AnnotatedRows
    WHERE @OnlyAttentionRows = 0 OR NeedsAttention = 1
) AS summary
GROUP BY
    summary.LayoutName,
    summary.OrderingPrinciple
ORDER BY
    summary.LayoutName,
    summary.OrderingPrinciple;
