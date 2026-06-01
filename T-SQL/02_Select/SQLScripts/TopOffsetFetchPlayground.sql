/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "TopOffsetFetchPlayground.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "02_Select"

purpose: >
  Vergleicht an einer gemeinsamen Sortierbasis die Auswahl per TOP, kumulativem
  TOP und OFFSET/FETCH, damit sichtbar wird, welche Variante nur die ersten n
  Zeilen liefert und welche Variante eine echte Zielseite adressiert.

parameters:
  - name: "@PageSize"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Anzahl der Zeilen pro Seite im Playground"
  - name: "@PageNumber"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Zielseite fuer den Vergleich von kumulativem TOP und OFFSET/FETCH"
  - name: "@RegionFilter"
    sql_type: "NVARCHAR(20)"
    direction: "IN"
    required: false
    description: "Optionaler Filter auf eine Region der Demo-Daten"
  - name: "@ShowOrderingPreview"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = die vollstaendige Sortierbasis mit Zeilennummern und Seiteneinteilung ausgeben"

result_sets:
  - name: "OrderingPreview"
    description: "Optionale Gesamtansicht der sortierten Demo-Daten mit Zeilennummer und abgeleiteter Seite"
  - name: "SelectionComparison"
    description: "Stellt TOP, kumulatives TOP und OFFSET/FETCH mit derselben ORDER-BY-Logik nebeneinander"
  - name: "TeachingSummary"
    description: "Verdichtet Zielseite, Rueckgabemengen und erklaert die Unterschiede der Selektionsvarianten"

dependencies:
  - "Table variable"
  - "CTE"
  - "TOP"
  - "OFFSET FETCH"
  - "ROW_NUMBER"
  - "COUNT OVER"
  - "CASE"
  - "STRING_AGG"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/02_Select/SQLScripts/TopOffsetFetchPlayground.md"
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
    description: "Erstversion des Playgrounds fuer TOP, kumulatives TOP und OFFSET/FETCH"

notes:
  - "Das Lab verwendet nur eingebettete Demo-Daten und keine produktiven Tabellen."
  - "Die Sortierung ist absichtlich eindeutig ueber LastContactDate, PriorityWeight und OpportunityID definiert."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @PageSize INT = 3;
DECLARE @PageNumber INT = 2;
DECLARE @RegionFilter NVARCHAR(20) = NULL;
DECLARE @ShowOrderingPreview BIT = 1;

DECLARE @OffsetRows INT = (@PageNumber - 1) * @PageSize;
DECLARE @TargetTopRows INT = @PageNumber * @PageSize;

DECLARE @OpportunityPipeline TABLE
(
    OpportunityID INT NOT NULL,
    CustomerName NVARCHAR(60) NOT NULL,
    RegionCode NVARCHAR(20) NOT NULL,
    PriorityCode NCHAR(1) NOT NULL,
    LastContactDate DATE NOT NULL,
    ExpectedRevenue DECIMAL(12,2) NOT NULL,
    StageName NVARCHAR(30) NOT NULL
);

SET @RegionFilter = NULLIF(LTRIM(RTRIM(@RegionFilter)), N'');

IF @PageSize IS NULL OR @PageSize < 1
BEGIN
    THROW 50000, '@PageSize muss mindestens 1 sein.', 1;
END;

IF @PageNumber IS NULL OR @PageNumber < 1
BEGIN
    THROW 50001, '@PageNumber muss mindestens 1 sein.', 1;
END;

IF @ShowOrderingPreview NOT IN (0, 1)
BEGIN
    THROW 50002, '@ShowOrderingPreview muss 0 oder 1 sein.', 1;
END;

INSERT INTO @OpportunityPipeline
(
    OpportunityID,
    CustomerName,
    RegionCode,
    PriorityCode,
    LastContactDate,
    ExpectedRevenue,
    StageName
)
VALUES
    (7101, 'Alpenmarkt GmbH',  'DE-NORTH',   'A', CAST('2026-04-18' AS DATE), CAST(185000.00 AS DECIMAL(12,2)), 'Proposal'),
    (7102, 'Bergblick AG',     'AT-WEST',    'B', CAST('2026-04-18' AS DATE), CAST(132000.00 AS DECIMAL(12,2)), 'Negotiation'),
    (7103, 'City Clinic',      'CH-CENTRAL', 'A', CAST('2026-04-17' AS DATE), CAST(164000.00 AS DECIMAL(12,2)), 'Proposal'),
    (7104, 'Delta Stores',     'DE-SOUTH',   'C', CAST('2026-04-17' AS DATE), CAST( 92000.00 AS DECIMAL(12,2)), 'Qualification'),
    (7105, 'Eiger Systems',    'DE-NORTH',   'B', CAST('2026-04-16' AS DATE), CAST(141000.00 AS DECIMAL(12,2)), 'Negotiation'),
    (7106, 'Fjord Retail',     'AT-WEST',    'A', CAST('2026-04-15' AS DATE), CAST(176000.00 AS DECIMAL(12,2)), 'Proposal'),
    (7107, 'Green Labs',       'CH-CENTRAL', 'B', CAST('2026-04-15' AS DATE), CAST(118000.00 AS DECIMAL(12,2)), 'Discovery'),
    (7108, 'Hanseatik Care',   'DE-NORTH',   'C', CAST('2026-04-14' AS DATE), CAST( 86000.00 AS DECIMAL(12,2)), 'Qualification'),
    (7109, 'Insel Energie',    'DE-SOUTH',   'A', CAST('2026-04-13' AS DATE), CAST(193000.00 AS DECIMAL(12,2)), 'Closing'),
    (7110, 'Jura Mobility',    'CH-CENTRAL', 'B', CAST('2026-04-12' AS DATE), CAST(109000.00 AS DECIMAL(12,2)), 'Discovery');

;WITH FilteredPipeline AS
(
    SELECT
        p.OpportunityID,
        p.CustomerName,
        p.RegionCode,
        p.PriorityCode,
        p.LastContactDate,
        p.ExpectedRevenue,
        p.StageName,
        CASE p.PriorityCode
            WHEN 'A' THEN 3
            WHEN 'B' THEN 2
            ELSE 1
        END AS PriorityWeight
    FROM @OpportunityPipeline AS p
    WHERE @RegionFilter IS NULL
       OR p.RegionCode = @RegionFilter
),
PreparedRows AS
(
    SELECT
        f.OpportunityID,
        f.CustomerName,
        f.RegionCode,
        f.PriorityCode,
        f.PriorityWeight,
        f.LastContactDate,
        f.ExpectedRevenue,
        f.StageName,
        COUNT(*) OVER () AS TotalRows,
        ROW_NUMBER() OVER
        (
            ORDER BY
                f.LastContactDate DESC,
                f.PriorityWeight DESC,
                f.OpportunityID DESC
        ) AS SortRowNumber
    FROM FilteredPipeline AS f
),
OrderingPreview AS
(
    SELECT
        p.OpportunityID,
        p.CustomerName,
        p.RegionCode,
        p.PriorityCode,
        p.PriorityWeight,
        p.LastContactDate,
        p.ExpectedRevenue,
        p.StageName,
        p.TotalRows,
        p.SortRowNumber,
        ((p.SortRowNumber - 1) / @PageSize) + 1 AS CalculatedPageNumber,
        CASE
            WHEN p.SortRowNumber <= @PageSize THEN 'top_page_size'
            WHEN p.SortRowNumber <= @TargetTopRows THEN 'top_cumulative_range'
            ELSE 'outside_target_top'
        END AS TopCoverageRole,
        CASE
            WHEN ((p.SortRowNumber - 1) / @PageSize) + 1 = @PageNumber THEN 'target_offset_page'
            ELSE 'outside_offset_page'
        END AS OffsetCoverageRole
    FROM PreparedRows AS p
)
SELECT
    o.OpportunityID,
    o.CustomerName,
    o.RegionCode,
    o.PriorityCode,
    o.PriorityWeight,
    o.LastContactDate,
    o.ExpectedRevenue,
    o.StageName,
    o.TotalRows,
    o.SortRowNumber,
    o.CalculatedPageNumber,
    o.TopCoverageRole,
    o.OffsetCoverageRole
FROM OrderingPreview AS o
WHERE @ShowOrderingPreview = 1
ORDER BY
    o.SortRowNumber;

;WITH FilteredPipeline AS
(
    SELECT
        p.OpportunityID,
        p.CustomerName,
        p.RegionCode,
        p.PriorityCode,
        p.LastContactDate,
        p.ExpectedRevenue,
        p.StageName,
        CASE p.PriorityCode
            WHEN 'A' THEN 3
            WHEN 'B' THEN 2
            ELSE 1
        END AS PriorityWeight
    FROM @OpportunityPipeline AS p
    WHERE @RegionFilter IS NULL
       OR p.RegionCode = @RegionFilter
),
PreparedRows AS
(
    SELECT
        f.OpportunityID,
        f.CustomerName,
        f.RegionCode,
        f.PriorityCode,
        f.PriorityWeight,
        f.LastContactDate,
        f.ExpectedRevenue,
        f.StageName,
        COUNT(*) OVER () AS TotalRows,
        ROW_NUMBER() OVER
        (
            ORDER BY
                f.LastContactDate DESC,
                f.PriorityWeight DESC,
                f.OpportunityID DESC
        ) AS SortRowNumber
    FROM FilteredPipeline AS f
),
ComparisonRows AS
(
    SELECT
        'top_page_size' AS ScenarioKey,
        'TOP (@PageSize)' AS SelectionPattern,
        1 AS LogicalPageNumber,
        s.OpportunityID,
        s.CustomerName,
        s.RegionCode,
        s.PriorityCode,
        s.LastContactDate,
        s.ExpectedRevenue,
        s.StageName,
        s.TotalRows,
        s.SortRowNumber
    FROM
    (
        SELECT TOP (@PageSize)
            p.OpportunityID,
            p.CustomerName,
            p.RegionCode,
            p.PriorityCode,
            p.LastContactDate,
            p.ExpectedRevenue,
            p.StageName,
            p.TotalRows,
            p.SortRowNumber
        FROM PreparedRows AS p
        ORDER BY
            p.LastContactDate DESC,
            p.PriorityWeight DESC,
            p.OpportunityID DESC
    ) AS s

    UNION ALL

    SELECT
        'top_cumulative' AS ScenarioKey,
        'TOP (@PageNumber * @PageSize)' AS SelectionPattern,
        @PageNumber AS LogicalPageNumber,
        s.OpportunityID,
        s.CustomerName,
        s.RegionCode,
        s.PriorityCode,
        s.LastContactDate,
        s.ExpectedRevenue,
        s.StageName,
        s.TotalRows,
        s.SortRowNumber
    FROM
    (
        SELECT TOP (@TargetTopRows)
            p.OpportunityID,
            p.CustomerName,
            p.RegionCode,
            p.PriorityCode,
            p.LastContactDate,
            p.ExpectedRevenue,
            p.StageName,
            p.TotalRows,
            p.SortRowNumber
        FROM PreparedRows AS p
        ORDER BY
            p.LastContactDate DESC,
            p.PriorityWeight DESC,
            p.OpportunityID DESC
    ) AS s

    UNION ALL

    SELECT
        'offset_fetch_page' AS ScenarioKey,
        'OFFSET (@PageNumber - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY' AS SelectionPattern,
        @PageNumber AS LogicalPageNumber,
        s.OpportunityID,
        s.CustomerName,
        s.RegionCode,
        s.PriorityCode,
        s.LastContactDate,
        s.ExpectedRevenue,
        s.StageName,
        s.TotalRows,
        s.SortRowNumber
    FROM
    (
        SELECT
            p.OpportunityID,
            p.CustomerName,
            p.RegionCode,
            p.PriorityCode,
            p.LastContactDate,
            p.ExpectedRevenue,
            p.StageName,
            p.TotalRows,
            p.SortRowNumber
        FROM PreparedRows AS p
        ORDER BY
            p.LastContactDate DESC,
            p.PriorityWeight DESC,
            p.OpportunityID DESC
        OFFSET @OffsetRows ROWS FETCH NEXT @PageSize ROWS ONLY
    ) AS s
)
SELECT
    c.ScenarioKey,
    c.SelectionPattern,
    c.LogicalPageNumber,
    c.SortRowNumber,
    c.OpportunityID,
    c.CustomerName,
    c.RegionCode,
    c.PriorityCode,
    c.LastContactDate,
    c.ExpectedRevenue,
    c.StageName,
    c.TotalRows,
    CASE
        WHEN c.ScenarioKey = 'top_page_size' AND @PageNumber > 1 THEN 'liefert weiter nur die erste Seite'
        WHEN c.ScenarioKey = 'top_cumulative' THEN 'enthaelt alle Zeilen bis zum Ende der Zielseite'
        ELSE 'liefert genau die Zielseite'
    END AS TeachingNote
FROM ComparisonRows AS c
ORDER BY
    c.ScenarioKey,
    c.SortRowNumber;

;WITH FilteredPipeline AS
(
    SELECT
        p.OpportunityID,
        p.CustomerName,
        p.RegionCode,
        p.PriorityCode,
        p.LastContactDate,
        p.ExpectedRevenue,
        p.StageName,
        CASE p.PriorityCode
            WHEN 'A' THEN 3
            WHEN 'B' THEN 2
            ELSE 1
        END AS PriorityWeight
    FROM @OpportunityPipeline AS p
    WHERE @RegionFilter IS NULL
       OR p.RegionCode = @RegionFilter
),
PreparedRows AS
(
    SELECT
        f.OpportunityID,
        ROW_NUMBER() OVER
        (
            ORDER BY
                f.LastContactDate DESC,
                f.PriorityWeight DESC,
                f.OpportunityID DESC
        ) AS SortRowNumber
    FROM FilteredPipeline AS f
),
ComparisonRows AS
(
    SELECT
        'top_page_size' AS ScenarioKey,
        p.OpportunityID,
        p.SortRowNumber
    FROM PreparedRows AS p
    WHERE p.SortRowNumber <= @PageSize

    UNION ALL

    SELECT
        'top_cumulative' AS ScenarioKey,
        p.OpportunityID,
        p.SortRowNumber
    FROM PreparedRows AS p
    WHERE p.SortRowNumber <= @TargetTopRows

    UNION ALL

    SELECT
        'offset_fetch_page' AS ScenarioKey,
        p.OpportunityID,
        p.SortRowNumber
    FROM PreparedRows AS p
    WHERE ((p.SortRowNumber - 1) / @PageSize) + 1 = @PageNumber
)
SELECT
    c.ScenarioKey,
    COUNT(*) AS SelectedRows,
    MIN(c.SortRowNumber) AS FirstSortRowNumber,
    MAX(c.SortRowNumber) AS LastSortRowNumber,
    STRING_AGG(CAST(c.OpportunityID AS NVARCHAR(20)), ', ') WITHIN GROUP (ORDER BY c.SortRowNumber) AS OpportunityIDs,
    CASE
        WHEN c.ScenarioKey = 'top_page_size' THEN 'TOP mit PageSize bleibt auf der ersten Seite und ignoriert spaetere Seiten.'
        WHEN c.ScenarioKey = 'top_cumulative' THEN 'Kumulatives TOP deckt die Zielseite mit ab, liefert aber auch alle vorherigen Seiten.'
        ELSE 'OFFSET/FETCH liefert nur die Zielseite der gemeinsamen Sortierbasis.'
    END AS TeachingTakeaway
FROM ComparisonRows AS c
GROUP BY
    c.ScenarioKey
ORDER BY
    c.ScenarioKey;
