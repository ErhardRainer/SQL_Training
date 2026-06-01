/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "ViewDefinitionSearchIndex.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "22_Views_Schemata"

purpose: >
  Erstellt einen didaktischen Suchindex ueber View-Definitionen in der aktuellen
  Datenbank. Das Skript zerlegt Definitionstexte aus sys.sql_modules in
  normalisierte Suchbegriffe, verdichtet haeufige Token pro View und markiert
  typische SQL-Muster fuer Analyse-, Review- und Refactoring-Zwecke.

parameters:
  - name: "@SchemaNameLike"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Optionales LIKE-Muster fuer View-Schemata"
  - name: "@SearchTermLike"
    sql_type: "NVARCHAR(200)"
    direction: "IN"
    required: false
    description: "Optionales LIKE-Muster fuer normalisierte Suchbegriffe"
  - name: "@MinimumTokenLength"
    sql_type: "TINYINT"
    direction: "IN"
    required: false
    description: "Minimale Laenge eines Suchbegriffs zwischen 2 und 30 Zeichen"
  - name: "@IncludeDefinitionPreview"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zusaetzliches Resultset mit gekuerzten Definitionen passender Views ausgeben"

result_sets:
  - name: "ViewDefinitionSearchIndex"
    description: "Detailsicht je View und Suchbegriff mit Haeufigkeit, Positionsrang und Musterhinweis"
  - name: "ViewDefinitionTokenSummary"
    description: "Verdichtete Token- und Musterstatistik pro View"
  - name: "DefinitionPreview"
    description: "Optionale Vorschau auf normalisierte Definitionen der betroffenen Views"

dependencies:
  - "sys.views"
  - "sys.schemas"
  - "sys.sql_modules"
  - "STRING_SPLIT"
  - "ROW_NUMBER()"
  - "COUNT(DISTINCT)"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/22_Views_Schemata/SQLScripts/ViewDefinitionSearchIndex.md"
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
    date: "2026-04-22"
    user: "ER"
    description: "Erstversion des Suchindex fuer View-Definitionen"

notes:
  - "Die Tokenisierung ist bewusst heuristisch und ersetzt keinen vollstaendigen SQL-Parser."
  - "Das Skript liest nur Metadaten der aktuellen Datenbank und fuehrt keine Aenderungen aus."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @SchemaNameLike SYSNAME = NULL;
DECLARE @SearchTermLike NVARCHAR(200) = NULL;
DECLARE @MinimumTokenLength TINYINT = 3;
DECLARE @IncludeDefinitionPreview BIT = 1;

IF @MinimumTokenLength NOT BETWEEN 2 AND 30
BEGIN
    THROW 50050, '@MinimumTokenLength muss zwischen 2 und 30 liegen.', 1;
END;

IF @IncludeDefinitionPreview NOT IN (0, 1)
BEGIN
    THROW 50051, '@IncludeDefinitionPreview muss 0 oder 1 sein.', 1;
END;

IF @SchemaNameLike IS NOT NULL AND LTRIM(RTRIM(@SchemaNameLike)) = ''
BEGIN
    SET @SchemaNameLike = NULL;
END;

IF @SearchTermLike IS NOT NULL AND LTRIM(RTRIM(@SearchTermLike)) = ''
BEGIN
    SET @SearchTermLike = NULL;
END;

DROP TABLE IF EXISTS #ViewInventory;
DROP TABLE IF EXISTS #DefinitionTokens;
DROP TABLE IF EXISTS #SearchIndex;
DROP TABLE IF EXISTS #ViewTokenSummary;

CREATE TABLE #ViewInventory
(
    view_object_id           INT             NOT NULL,
    schema_name              SYSNAME         NOT NULL,
    view_name                SYSNAME         NOT NULL,
    full_view_name           NVARCHAR(517)   NOT NULL,
    uses_schemabinding       BIT             NOT NULL,
    definition_text          NVARCHAR(MAX)   NOT NULL,
    normalized_definition    NVARCHAR(MAX)   NOT NULL
);

INSERT INTO #ViewInventory
(
    view_object_id,
    schema_name,
    view_name,
    full_view_name,
    uses_schemabinding,
    definition_text,
    normalized_definition
)
SELECT
    v.object_id,
    s.name AS schema_name,
    v.name AS view_name,
    QUOTENAME(s.name) + N'.' + QUOTENAME(v.name) AS full_view_name,
    CONVERT(BIT, OBJECTPROPERTY(v.object_id, 'IsSchemaBound')) AS uses_schemabinding,
    sm.definition AS definition_text,
    LOWER(
        REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
        REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
            sm.definition,
            CHAR(13), N' '),
            CHAR(10), N' '),
            CHAR(9), N' '),
            N'(', N' '),
            N')', N' '),
            N',', N' '),
            N';', N' '),
            N'.', N' '),
            N'=', N' '),
            N'+', N' '),
            N'-', N' '),
            N'*', N' '),
            N'/', N' '),
            N'[', N' '),
            N']', N' '),
            N'"', N' '),
            N'''', N' '),
            N':', N' '),
            N'>', N' '),
            N'<', N' ')
    ) AS normalized_definition
FROM sys.views AS v
INNER JOIN sys.schemas AS s
    ON s.schema_id = v.schema_id
INNER JOIN sys.sql_modules AS sm
    ON sm.object_id = v.object_id
WHERE @SchemaNameLike IS NULL
   OR s.name LIKE @SchemaNameLike;

CREATE TABLE #DefinitionTokens
(
    view_object_id        INT             NOT NULL,
    full_view_name        NVARCHAR(517)   NOT NULL,
    token                 NVARCHAR(200)   NOT NULL
);

INSERT INTO #DefinitionTokens
(
    view_object_id,
    full_view_name,
    token
)
SELECT
    vi.view_object_id,
    vi.full_view_name,
    LTRIM(RTRIM(ss.value)) AS token
FROM #ViewInventory AS vi
CROSS APPLY STRING_SPLIT(vi.normalized_definition, N' ') AS ss
WHERE LEN(LTRIM(RTRIM(ss.value))) >= @MinimumTokenLength
  AND LTRIM(RTRIM(ss.value)) NOT LIKE N'%[^a-z0-9_#]%'
  AND (
        @SearchTermLike IS NULL
        OR LTRIM(RTRIM(ss.value)) LIKE LOWER(@SearchTermLike)
      );

CREATE TABLE #SearchIndex
(
    full_view_name           NVARCHAR(517)   NOT NULL,
    schema_name              SYSNAME         NOT NULL,
    view_name                SYSNAME         NOT NULL,
    search_term              NVARCHAR(200)   NOT NULL,
    token_occurrence_count   INT             NOT NULL,
    term_rank_in_view        INT             NOT NULL,
    pattern_hint             NVARCHAR(120)   NOT NULL,
    uses_schemabinding       BIT             NOT NULL,
    review_focus             NVARCHAR(220)   NOT NULL
);

WITH TokenFrequency AS
(
    SELECT
        vi.full_view_name,
        vi.schema_name,
        vi.view_name,
        dt.token AS search_term,
        COUNT(*) AS token_occurrence_count,
        vi.uses_schemabinding,
        vi.definition_text
    FROM #ViewInventory AS vi
    INNER JOIN #DefinitionTokens AS dt
        ON dt.view_object_id = vi.view_object_id
    GROUP BY
        vi.full_view_name,
        vi.schema_name,
        vi.view_name,
        dt.token,
        vi.uses_schemabinding,
        vi.definition_text
)
INSERT INTO #SearchIndex
(
    full_view_name,
    schema_name,
    view_name,
    search_term,
    token_occurrence_count,
    term_rank_in_view,
    pattern_hint,
    uses_schemabinding,
    review_focus
)
SELECT
    tf.full_view_name,
    tf.schema_name,
    tf.view_name,
    tf.search_term,
    tf.token_occurrence_count,
    ROW_NUMBER() OVER
    (
        PARTITION BY tf.full_view_name
        ORDER BY tf.token_occurrence_count DESC, tf.search_term ASC
    ) AS term_rank_in_view,
    CASE
        WHEN tf.search_term IN (N'join', N'left', N'right', N'inner', N'outer') THEN N'Join-Muster'
        WHEN tf.search_term IN (N'partition', N'over', N'row_number', N'dense_rank') THEN N'Window-Muster'
        WHEN tf.search_term IN (N'case', N'coalesce', N'isnull') THEN N'Ausdruckslogik'
        WHEN tf.search_term IN (N'openquery', N'openrowset', N'opendatasource') THEN N'Externe Quelle'
        WHEN tf.search_term IN (N'nolock', N'readuncommitted') THEN N'Isolation-Hinweis'
        WHEN tf.search_term IN (N'union', N'intersect', N'except') THEN N'Set-Operation'
        WHEN tf.search_term IN (N'group', N'having', N'aggregate', N'count', N'sum', N'avg') THEN N'Aggregation'
        ELSE N'Allgemeines SQL-Muster'
    END AS pattern_hint,
    tf.uses_schemabinding,
    CASE
        WHEN tf.search_term IN (N'openquery', N'openrowset', N'opendatasource') THEN N'Externe Datenquelle und Berechtigungen separat pruefen.'
        WHEN tf.search_term IN (N'nolock', N'readuncommitted') THEN N'Isolationseffekt und fachliche Konsistenz pruefen.'
        WHEN tf.search_term = N'select' AND tf.definition_text LIKE '%SELECT *%' THEN N'SELECT Stern gezielt auf Drift-Risiken pruefen.'
        WHEN tf.search_term IN (N'join', N'left', N'right', N'inner', N'outer') THEN N'Join-Pfade und Kardinalitaet in der View dokumentieren.'
        WHEN tf.search_term IN (N'partition', N'over', N'row_number', N'dense_rank') THEN N'Fensterdefinition und Sortierung fuer stabile Ergebnisse pruefen.'
        WHEN tf.search_term IN (N'group', N'having', N'count', N'sum', N'avg') THEN N'Aggregationsebene und Gruppierung fachlich absichern.'
        ELSE N'Token als Suchanker fuer Code-Review oder Refactoring verwenden.'
    END AS review_focus
FROM TokenFrequency AS tf;

CREATE TABLE #ViewTokenSummary
(
    full_view_name                 NVARCHAR(517)   NOT NULL,
    distinct_token_count           INT             NOT NULL,
    indexed_token_count            INT             NOT NULL,
    top_search_terms               NVARCHAR(4000)  NOT NULL,
    contains_select_star           BIT             NOT NULL,
    contains_external_access_hint  BIT             NOT NULL,
    uses_schemabinding             BIT             NOT NULL,
    review_priority                VARCHAR(10)     NOT NULL
);

INSERT INTO #ViewTokenSummary
(
    full_view_name,
    distinct_token_count,
    indexed_token_count,
    top_search_terms,
    contains_select_star,
    contains_external_access_hint,
    uses_schemabinding,
    review_priority
)
SELECT
    vi.full_view_name,
    token_stats.distinct_token_count,
    token_stats.indexed_token_count,
    COALESCE(top_terms.top_search_terms, N'(keine Treffer)') AS top_search_terms,
    CASE
        WHEN vi.definition_text LIKE '%SELECT *%' OR vi.definition_text LIKE '%SELECT%*%' THEN 1
        ELSE 0
    END AS contains_select_star,
    CASE
        WHEN vi.definition_text LIKE '%OPENQUERY(%'
          OR vi.definition_text LIKE '%OPENROWSET(%'
          OR vi.definition_text LIKE '%OPENDATASOURCE(%'
            THEN 1
        ELSE 0
    END AS contains_external_access_hint,
    vi.uses_schemabinding,
    CASE
        WHEN (vi.definition_text LIKE '%SELECT *%' OR vi.definition_text LIKE '%SELECT%*%')
             AND vi.uses_schemabinding = 0
            THEN 'High'
        WHEN vi.definition_text LIKE '%OPENQUERY(%'
          OR vi.definition_text LIKE '%OPENROWSET(%'
          OR vi.definition_text LIKE '%OPENDATASOURCE(%'
            THEN 'High'
        WHEN vi.definition_text LIKE '%NOLOCK%'
          OR vi.definition_text LIKE '%READUNCOMMITTED%'
            THEN 'Medium'
        ELSE 'Info'
    END AS review_priority
FROM #ViewInventory AS vi
INNER JOIN
(
    SELECT
        dt.view_object_id,
        COUNT(DISTINCT dt.token) AS distinct_token_count,
        COUNT(*) AS indexed_token_count
    FROM #DefinitionTokens AS dt
    GROUP BY
        dt.view_object_id
) AS token_stats
    ON token_stats.view_object_id = vi.view_object_id
OUTER APPLY
(
    SELECT STRING_AGG(CONCAT(top_si.search_term, N' x', top_si.token_occurrence_count), N', ') AS top_search_terms
    FROM
    (
        SELECT TOP (5)
            si.search_term,
            si.token_occurrence_count
        FROM #SearchIndex AS si
        WHERE si.full_view_name = vi.full_view_name
        ORDER BY
            si.term_rank_in_view,
            si.search_term
    ) AS top_si
) AS top_terms;

SELECT
    si.full_view_name,
    si.schema_name,
    si.view_name,
    si.search_term,
    si.token_occurrence_count,
    si.term_rank_in_view,
    si.pattern_hint,
    si.uses_schemabinding,
    si.review_focus
FROM #SearchIndex AS si
ORDER BY
    si.full_view_name,
    si.term_rank_in_view,
    si.search_term;

SELECT
    vts.full_view_name,
    vts.distinct_token_count,
    vts.indexed_token_count,
    vts.top_search_terms,
    vts.contains_select_star,
    vts.contains_external_access_hint,
    vts.uses_schemabinding,
    vts.review_priority
FROM #ViewTokenSummary AS vts
ORDER BY
    CASE vts.review_priority
        WHEN 'High' THEN 1
        WHEN 'Medium' THEN 2
        ELSE 3
    END,
    vts.full_view_name;

IF @IncludeDefinitionPreview = 1
BEGIN
    SELECT
        vi.full_view_name,
        LEN(vi.definition_text) AS definition_length,
        LEFT(REPLACE(REPLACE(vi.definition_text, CHAR(13), N' '), CHAR(10), N' '), 600) AS definition_preview
    FROM #ViewInventory AS vi
    WHERE EXISTS
    (
        SELECT 1
        FROM #SearchIndex AS si
        WHERE si.full_view_name = vi.full_view_name
    )
    ORDER BY
        vi.full_view_name;
END;
