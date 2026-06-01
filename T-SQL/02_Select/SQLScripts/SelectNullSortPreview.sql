/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "SelectNullSortPreview.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "02_Select"

purpose: >
  Zeigt an einem kleinen Demo-Datensatz, wie SQL Server NULL-Werte bei
  aufsteigender und absteigender Sortierung einordnet und wie sich diese
  Einordnung mit expliziten CASE-Ausdruecken steuern laesst.

parameters:
  - name: "@ShowSourceData"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = den Demo-Datensatz vor den Sortiervergleichen zusaetzlich ausgeben"
  - name: "@IncludeExplicitAlternatives"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zusaetzlich Sortiervarianten mit expliziter NULL-Steuerung anzeigen"
  - name: "@ShowTeachingSummary"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = eine kompakte Zusammenfassung der beobachteten NULL-Platzierung ausgeben"

result_sets:
  - name: "SourceDataPreview"
    description: "Optionale Vorschau des Demo-Datensatzes mit NULL- und Nicht-NULL-Werten"
  - name: "NullSortPreview"
    description: "Vergleicht Standard-Sortierung und explizite NULL-Platzierung fuer dieselbe Spalte"
  - name: "TeachingSummary"
    description: "Verdichtet die beobachtete NULL-Position und die didaktische Aussage je Sortierszenario"

dependencies:
  - "CTE"
  - "VALUES constructor"
  - "ROW_NUMBER"
  - "CASE"
  - "UNION ALL"
  - "COUNT OVER"
  - "MIN"
  - "MAX"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/02_Select/SQLScripts/SelectNullSortPreview.md"
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
    description: "Erstversion des Labs zur NULL-Sortierung in SQL Server"

notes:
  - "Das Skript arbeitet ausschliesslich mit eingebetteten Demo-Daten"
  - "Explizite NULL-Steuerung wird ueber CASE im ORDER BY emuliert, da T-SQL kein NULLS FIRST oder NULLS LAST kennt"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @ShowSourceData BIT = 1;
DECLARE @IncludeExplicitAlternatives BIT = 1;
DECLARE @ShowTeachingSummary BIT = 1;

IF @ShowSourceData NOT IN (0, 1)
BEGIN
    THROW 50000, '@ShowSourceData muss 0 oder 1 sein.', 1;
END;

IF @IncludeExplicitAlternatives NOT IN (0, 1)
BEGIN
    THROW 50001, '@IncludeExplicitAlternatives muss 0 oder 1 sein.', 1;
END;

IF @ShowTeachingSummary NOT IN (0, 1)
BEGIN
    THROW 50002, '@ShowTeachingSummary muss 0 oder 1 sein.', 1;
END;

;WITH DemoBacklog AS
(
    SELECT
        sample.TaskID,
        sample.WorkItem,
        sample.TeamCode,
        sample.PriorityScore,
        sample.ReviewDate
    FROM
    (
        VALUES
            (7101, 'Backlog groomen',         'OPS',  CAST(90 AS INT),  CAST('2026-04-20' AS DATE)),
            (7102, 'Fachfrage klaeren',       'BI',   NULL,             CAST('2026-04-22' AS DATE)),
            (7103, 'Import testen',           'APP',  CAST(75 AS INT),  NULL),
            (7104, 'Schnittstelle pruefen',   'OPS',  CAST(60 AS INT),  CAST('2026-04-18' AS DATE)),
            (7105, 'Altdaten sichten',        'DWH',  NULL,             NULL),
            (7106, 'Freigabe vorbereiten',    'APP',  CAST(85 AS INT),  CAST('2026-04-19' AS DATE))
    ) AS sample
    (
        TaskID,
        WorkItem,
        TeamCode,
        PriorityScore,
        ReviewDate
    )
),
PreparedBacklog AS
(
    SELECT
        d.TaskID,
        d.WorkItem,
        d.TeamCode,
        d.PriorityScore,
        d.ReviewDate,
        CASE
            WHEN d.PriorityScore IS NULL THEN 'priority_missing'
            WHEN d.PriorityScore >= 85 THEN 'high_priority'
            WHEN d.PriorityScore >= 70 THEN 'medium_priority'
            ELSE 'follow_up'
        END AS PriorityBand,
        CASE
            WHEN d.ReviewDate IS NULL THEN 'review_open'
            ELSE 'review_planned'
        END AS ReviewStatus
    FROM DemoBacklog AS d
),
SortPreview AS
(
    SELECT
        'score_asc_default' AS ScenarioKey,
        'PriorityScore ASC' AS OrderByClause,
        'default_engine_order' AS ScenarioType,
        'NULL wird in SQL Server bei ASC wie der kleinste Wert behandelt und erscheint zuerst.' AS TeachingNote,
        ROW_NUMBER() OVER (ORDER BY p.PriorityScore ASC, p.TaskID ASC) AS SortPosition,
        p.TaskID,
        p.WorkItem,
        p.TeamCode,
        p.PriorityScore,
        p.ReviewDate,
        p.PriorityBand,
        p.ReviewStatus
    FROM PreparedBacklog AS p

    UNION ALL

    SELECT
        'score_desc_default' AS ScenarioKey,
        'PriorityScore DESC' AS OrderByClause,
        'default_engine_order' AS ScenarioType,
        'NULL landet bei DESC am Ende, weil groessere Nicht-NULL-Werte zuerst sortiert werden.' AS TeachingNote,
        ROW_NUMBER() OVER (ORDER BY p.PriorityScore DESC, p.TaskID ASC) AS SortPosition,
        p.TaskID,
        p.WorkItem,
        p.TeamCode,
        p.PriorityScore,
        p.ReviewDate,
        p.PriorityBand,
        p.ReviewStatus
    FROM PreparedBacklog AS p

    UNION ALL

    SELECT
        'score_asc_nulls_last' AS ScenarioKey,
        'CASE WHEN PriorityScore IS NULL THEN 1 ELSE 0 END, PriorityScore ASC' AS OrderByClause,
        'explicit_null_policy' AS ScenarioType,
        'Ein vorgeschaltetes CASE verschiebt NULL-Werte bei ASC bewusst an das Ende.' AS TeachingNote,
        ROW_NUMBER() OVER
        (
            ORDER BY
                CASE WHEN p.PriorityScore IS NULL THEN 1 ELSE 0 END ASC,
                p.PriorityScore ASC,
                p.TaskID ASC
        ) AS SortPosition,
        p.TaskID,
        p.WorkItem,
        p.TeamCode,
        p.PriorityScore,
        p.ReviewDate,
        p.PriorityBand,
        p.ReviewStatus
    FROM PreparedBacklog AS p
    WHERE @IncludeExplicitAlternatives = 1

    UNION ALL

    SELECT
        'score_desc_nulls_first' AS ScenarioKey,
        'CASE WHEN PriorityScore IS NULL THEN 0 ELSE 1 END, PriorityScore DESC' AS OrderByClause,
        'explicit_null_policy' AS ScenarioType,
        'Ein vorgeschaltetes CASE zieht NULL-Werte bei DESC gezielt an den Anfang.' AS TeachingNote,
        ROW_NUMBER() OVER
        (
            ORDER BY
                CASE WHEN p.PriorityScore IS NULL THEN 0 ELSE 1 END ASC,
                p.PriorityScore DESC,
                p.TaskID ASC
        ) AS SortPosition,
        p.TaskID,
        p.WorkItem,
        p.TeamCode,
        p.PriorityScore,
        p.ReviewDate,
        p.PriorityBand,
        p.ReviewStatus
    FROM PreparedBacklog AS p
    WHERE @IncludeExplicitAlternatives = 1
),
TeachingSummary AS
(
    SELECT
        sp.ScenarioKey,
        MIN(sp.OrderByClause) AS OrderByClause,
        MIN(sp.ScenarioType) AS ScenarioType,
        MIN(sp.TeachingNote) AS TeachingNote,
        MIN(CASE WHEN sp.PriorityScore IS NULL THEN sp.SortPosition END) AS FirstNullPosition,
        MAX(CASE WHEN sp.PriorityScore IS NULL THEN sp.SortPosition END) AS LastNullPosition,
        SUM(CASE WHEN sp.PriorityScore IS NULL THEN 1 ELSE 0 END) AS NullRowCount,
        COUNT(*) AS TotalRowCount,
        CASE
            WHEN MIN(CASE WHEN sp.PriorityScore IS NULL THEN sp.SortPosition END) = 1 THEN 'nulls_first'
            WHEN MAX(CASE WHEN sp.PriorityScore IS NULL THEN sp.SortPosition END) = COUNT(*) THEN 'nulls_last'
            ELSE 'nulls_between_values'
        END AS ObservedNullPlacement
    FROM SortPreview AS sp
    GROUP BY
        sp.ScenarioKey
)
SELECT
    p.TaskID,
    p.WorkItem,
    p.TeamCode,
    p.PriorityScore,
    p.ReviewDate,
    p.PriorityBand,
    p.ReviewStatus
FROM PreparedBacklog AS p
WHERE @ShowSourceData = 1
ORDER BY
    p.TaskID;

SELECT
    sp.ScenarioKey,
    sp.OrderByClause,
    sp.ScenarioType,
    sp.SortPosition,
    sp.TaskID,
    sp.WorkItem,
    sp.TeamCode,
    sp.PriorityScore,
    sp.ReviewDate,
    sp.PriorityBand,
    sp.ReviewStatus,
    CASE
        WHEN sp.PriorityScore IS NULL THEN 'NULL row'
        ELSE 'value row'
    END AS NullMarker,
    sp.TeachingNote
FROM SortPreview AS sp
ORDER BY
    sp.ScenarioKey,
    sp.SortPosition;

SELECT
    ts.ScenarioKey,
    ts.OrderByClause,
    ts.ScenarioType,
    ts.ObservedNullPlacement,
    ts.FirstNullPosition,
    ts.LastNullPosition,
    ts.NullRowCount,
    ts.TotalRowCount,
    ts.TeachingNote
FROM TeachingSummary AS ts
WHERE @ShowTeachingSummary = 1
ORDER BY
    ts.ScenarioKey;
