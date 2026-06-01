/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "ViewColumnLineageReport.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "22_Views_Schemata"

purpose: >
  Erstellt einen didaktisch nutzbaren Bericht zur Spaltenherkunft in Views.
  Das Skript kombiniert View-Spalten, bekannte Objektabhaengigkeiten und
  Namensheuristiken, um moegliche Quellspalten je Ausgabespalte sichtbar zu
  machen und unsichere Faelle fuer manuelle Analyse zu markieren.

parameters:
  - name: "@SchemaNameLike"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Optionales LIKE-Muster fuer View-Schemata"
  - name: "@OnlyResolvable"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = nur Spalten mit mindestens einem gefundenen Lineage-Kandidaten ausgeben"
  - name: "@IncludeSummary"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zusaetzliches Summary-Resultset pro View ausgeben"

result_sets:
  - name: "ViewColumnInventory"
    description: "Inventar der View-Spalten mit Metadaten zu Datentyp und Nullbarkeit"
  - name: "ViewColumnLineage"
    description: "Moegliche Herkunft je View-Spalte inklusive Heuristik und Vertrauensniveau"
  - name: "ViewLineageSummary"
    description: "Optionale Zusammenfassung pro View mit Abdeckungsgrad und Review-Bedarf"

dependencies:
  - "sys.views"
  - "sys.schemas"
  - "sys.columns"
  - "sys.types"
  - "sys.sql_expression_dependencies"
  - "sys.objects"
  - "ROW_NUMBER()"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/22_Views_Schemata/SQLScripts/ViewColumnLineageReport.md"
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
    description: "Erstversion des Berichts zur Spaltenherkunft in Views"

notes:
  - "Die Zuordnung arbeitet bewusst heuristisch und ersetzt keine vollstaendige Parser- oder Optimizer-Sicht."
  - "Nicht aufgeloeste oder mehrdeutige Faelle werden fuer manuelles Review markiert."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @SchemaNameLike SYSNAME = NULL;
DECLARE @OnlyResolvable BIT = 0;
DECLARE @IncludeSummary BIT = 1;

IF @OnlyResolvable NOT IN (0, 1)
BEGIN
    THROW 50040, '@OnlyResolvable muss 0 oder 1 sein.', 1;
END;

IF @IncludeSummary NOT IN (0, 1)
BEGIN
    THROW 50041, '@IncludeSummary muss 0 oder 1 sein.', 1;
END;

IF @SchemaNameLike IS NOT NULL AND LTRIM(RTRIM(@SchemaNameLike)) = ''
BEGIN
    SET @SchemaNameLike = NULL;
END;

DROP TABLE IF EXISTS #ViewInventory;
DROP TABLE IF EXISTS #ViewColumns;
DROP TABLE IF EXISTS #DependencyObjects;
DROP TABLE IF EXISTS #DependencyColumns;
DROP TABLE IF EXISTS #ColumnLineageCandidates;
DROP TABLE IF EXISTS #ViewLineageSummary;

CREATE TABLE #ViewInventory
(
    view_object_id       INT             NOT NULL,
    schema_name          SYSNAME         NOT NULL,
    view_name            SYSNAME         NOT NULL,
    full_view_name       NVARCHAR(517)   NOT NULL,
    uses_schemabinding   BIT             NOT NULL,
    dependency_count     INT             NOT NULL
);

INSERT INTO #ViewInventory
(
    view_object_id,
    schema_name,
    view_name,
    full_view_name,
    uses_schemabinding,
    dependency_count
)
SELECT
    v.object_id,
    s.name AS schema_name,
    v.name AS view_name,
    QUOTENAME(s.name) + N'.' + QUOTENAME(v.name) AS full_view_name,
    CONVERT(BIT, OBJECTPROPERTY(v.object_id, 'IsSchemaBound')) AS uses_schemabinding,
    COUNT(DISTINCT sed.referenced_id) AS dependency_count
FROM sys.views AS v
INNER JOIN sys.schemas AS s
    ON s.schema_id = v.schema_id
LEFT JOIN sys.sql_expression_dependencies AS sed
    ON sed.referencing_id = v.object_id
WHERE @SchemaNameLike IS NULL
   OR s.name LIKE @SchemaNameLike
GROUP BY
    v.object_id,
    s.name,
    v.name;

CREATE TABLE #ViewColumns
(
    view_object_id           INT             NOT NULL,
    full_view_name           NVARCHAR(517)   NOT NULL,
    column_id                INT             NOT NULL,
    column_name              SYSNAME         NOT NULL,
    data_type_name           SYSNAME         NOT NULL,
    max_length               SMALLINT        NOT NULL,
    precision_value          TINYINT         NOT NULL,
    scale_value              TINYINT         NOT NULL,
    is_nullable              BIT             NOT NULL
);

INSERT INTO #ViewColumns
(
    view_object_id,
    full_view_name,
    column_id,
    column_name,
    data_type_name,
    max_length,
    precision_value,
    scale_value,
    is_nullable
)
SELECT
    vi.view_object_id,
    vi.full_view_name,
    c.column_id,
    c.name AS column_name,
    t.name AS data_type_name,
    c.max_length,
    c.precision,
    c.scale,
    c.is_nullable
FROM #ViewInventory AS vi
INNER JOIN sys.columns AS c
    ON c.object_id = vi.view_object_id
INNER JOIN sys.types AS t
    ON t.user_type_id = c.user_type_id;

CREATE TABLE #DependencyObjects
(
    view_object_id               INT             NOT NULL,
    full_view_name               NVARCHAR(517)   NOT NULL,
    referenced_id                INT             NULL,
    referenced_entity            NVARCHAR(776)   NOT NULL,
    dependency_scope             NVARCHAR(100)   NOT NULL,
    referenced_minor_id          INT             NOT NULL,
    referenced_column_name       SYSNAME         NULL
);

INSERT INTO #DependencyObjects
(
    view_object_id,
    full_view_name,
    referenced_id,
    referenced_entity,
    dependency_scope,
    referenced_minor_id,
    referenced_column_name
)
SELECT
    vi.view_object_id,
    vi.full_view_name,
    sed.referenced_id,
    COALESCE(
        CASE
            WHEN sed.referenced_id IS NOT NULL THEN
                QUOTENAME(OBJECT_SCHEMA_NAME(sed.referenced_id))
                + N'.'
                + QUOTENAME(OBJECT_NAME(sed.referenced_id))
        END,
        CASE
            WHEN sed.referenced_schema_name IS NOT NULL AND sed.referenced_entity_name IS NOT NULL THEN
                QUOTENAME(sed.referenced_schema_name) + N'.' + QUOTENAME(sed.referenced_entity_name)
            WHEN sed.referenced_entity_name IS NOT NULL THEN
                QUOTENAME(sed.referenced_entity_name)
            ELSE
                N'(unresolved reference)'
        END
    ) AS referenced_entity,
    CASE
        WHEN sed.referenced_server_name IS NOT NULL THEN 'cross-server'
        WHEN sed.referenced_database_name IS NOT NULL THEN 'cross-database'
        WHEN sed.referenced_schema_name IS NOT NULL THEN 'same-database'
        ELSE 'implicit-or-unresolved'
    END AS dependency_scope,
    ISNULL(sed.referenced_minor_id, 0) AS referenced_minor_id,
    rc.name AS referenced_column_name
FROM #ViewInventory AS vi
LEFT JOIN sys.sql_expression_dependencies AS sed
    ON sed.referencing_id = vi.view_object_id
LEFT JOIN sys.columns AS rc
    ON rc.object_id = sed.referenced_id
   AND rc.column_id = sed.referenced_minor_id
WHERE sed.referencing_id IS NOT NULL;

CREATE TABLE #DependencyColumns
(
    view_object_id           INT             NOT NULL,
    full_view_name           NVARCHAR(517)   NOT NULL,
    referenced_entity        NVARCHAR(776)   NOT NULL,
    dependency_scope         NVARCHAR(100)   NOT NULL,
    source_column_name       SYSNAME         NOT NULL,
    source_data_type         SYSNAME         NOT NULL
);

INSERT INTO #DependencyColumns
(
    view_object_id,
    full_view_name,
    referenced_entity,
    dependency_scope,
    source_column_name,
    source_data_type
)
SELECT DISTINCT
    vi.view_object_id,
    vi.full_view_name,
    QUOTENAME(OBJECT_SCHEMA_NAME(o.object_id)) + N'.' + QUOTENAME(o.name) AS referenced_entity,
    'same-database' AS dependency_scope,
    c.name AS source_column_name,
    t.name AS source_data_type
FROM #ViewInventory AS vi
INNER JOIN #DependencyObjects AS do
    ON do.view_object_id = vi.view_object_id
   AND do.referenced_id IS NOT NULL
INNER JOIN sys.objects AS o
    ON o.object_id = do.referenced_id
INNER JOIN sys.columns AS c
    ON c.object_id = o.object_id
INNER JOIN sys.types AS t
    ON t.user_type_id = c.user_type_id;

CREATE TABLE #ColumnLineageCandidates
(
    full_view_name            NVARCHAR(517)   NOT NULL,
    view_column_id            INT             NOT NULL,
    view_column_name          SYSNAME         NOT NULL,
    candidate_rank            INT             NOT NULL,
    lineage_status            VARCHAR(20)     NOT NULL,
    confidence_level          VARCHAR(10)     NOT NULL,
    lineage_method            VARCHAR(40)     NOT NULL,
    referenced_entity         NVARCHAR(776)   NULL,
    source_column_name        SYSNAME         NULL,
    dependency_scope          NVARCHAR(100)   NULL,
    candidate_count           INT             NOT NULL,
    review_note               NVARCHAR(260)   NOT NULL
);

WITH ExactColumnDependencies AS
(
    SELECT
        vc.full_view_name,
        vc.column_id,
        vc.column_name,
        do.referenced_entity,
        do.referenced_column_name AS source_column_name,
        do.dependency_scope,
        COUNT(*) OVER (PARTITION BY vc.full_view_name, vc.column_id) AS candidate_count
    FROM #ViewColumns AS vc
    INNER JOIN #DependencyObjects AS do
        ON do.view_object_id = vc.view_object_id
       AND do.referenced_minor_id > 0
       AND do.referenced_column_name = vc.column_name
)
INSERT INTO #ColumnLineageCandidates
(
    full_view_name,
    view_column_id,
    view_column_name,
    candidate_rank,
    lineage_status,
    confidence_level,
    lineage_method,
    referenced_entity,
    source_column_name,
    dependency_scope,
    candidate_count,
    review_note
)
SELECT
    ecd.full_view_name,
    ecd.column_id,
    ecd.column_name,
    ROW_NUMBER() OVER (PARTITION BY ecd.full_view_name, ecd.column_id ORDER BY ecd.referenced_entity, ecd.source_column_name),
    CASE
        WHEN ecd.candidate_count = 1 THEN 'resolved'
        ELSE 'ambiguous'
    END AS lineage_status,
    CASE
        WHEN ecd.candidate_count = 1 THEN 'High'
        ELSE 'Medium'
    END AS confidence_level,
    'dependency-column-match' AS lineage_method,
    ecd.referenced_entity,
    ecd.source_column_name,
    ecd.dependency_scope,
    ecd.candidate_count,
    CASE
        WHEN ecd.candidate_count = 1 THEN 'Direkte Spaltenreferenz aus den Metadaten ableitbar.'
        ELSE 'Mehrere direkte Spaltenkandidaten mit gleichem Namen gefunden; View-Ausdruck manuell pruefen.'
    END AS review_note
FROM ExactColumnDependencies AS ecd;

WITH HeuristicNameMatches AS
(
    SELECT
        vc.full_view_name,
        vc.column_id,
        vc.column_name,
        dc.referenced_entity,
        dc.source_column_name,
        dc.dependency_scope,
        COUNT(*) OVER (PARTITION BY vc.full_view_name, vc.column_id) AS candidate_count
    FROM #ViewColumns AS vc
    INNER JOIN #DependencyColumns AS dc
        ON dc.view_object_id = vc.view_object_id
       AND dc.source_column_name = vc.column_name
)
INSERT INTO #ColumnLineageCandidates
(
    full_view_name,
    view_column_id,
    view_column_name,
    candidate_rank,
    lineage_status,
    confidence_level,
    lineage_method,
    referenced_entity,
    source_column_name,
    dependency_scope,
    candidate_count,
    review_note
)
SELECT
    hnm.full_view_name,
    hnm.column_id,
    hnm.column_name,
    ROW_NUMBER() OVER (PARTITION BY hnm.full_view_name, hnm.column_id ORDER BY hnm.referenced_entity, hnm.source_column_name),
    CASE
        WHEN hnm.candidate_count = 1 THEN 'resolved'
        ELSE 'ambiguous'
    END AS lineage_status,
    CASE
        WHEN hnm.candidate_count = 1 THEN 'Medium'
        ELSE 'Low'
    END AS confidence_level,
    'name-match-across-dependencies' AS lineage_method,
    hnm.referenced_entity,
    hnm.source_column_name,
    hnm.dependency_scope,
    hnm.candidate_count,
    CASE
        WHEN hnm.candidate_count = 1 THEN 'Namensheuristik liefert genau eine passende Quellspalte.'
        ELSE 'Mehrere gleichnamige Quellspalten in abhaengigen Objekten gefunden; manuelles Review empfohlen.'
    END AS review_note
FROM HeuristicNameMatches AS hnm
WHERE NOT EXISTS
(
    SELECT 1
    FROM #ColumnLineageCandidates AS clc
    WHERE clc.full_view_name = hnm.full_view_name
      AND clc.view_column_id = hnm.column_id
);

WITH SingleDependencyFallback AS
(
    SELECT
        vc.full_view_name,
        vc.column_id,
        vc.column_name,
        MIN(dc.referenced_entity) AS referenced_entity,
        MIN(dc.dependency_scope) AS dependency_scope
    FROM #ViewColumns AS vc
    INNER JOIN #DependencyColumns AS dc
        ON dc.view_object_id = vc.view_object_id
    GROUP BY
        vc.full_view_name,
        vc.column_id,
        vc.column_name
    HAVING COUNT(DISTINCT dc.referenced_entity) = 1
)
INSERT INTO #ColumnLineageCandidates
(
    full_view_name,
    view_column_id,
    view_column_name,
    candidate_rank,
    lineage_status,
    confidence_level,
    lineage_method,
    referenced_entity,
    source_column_name,
    dependency_scope,
    candidate_count,
    review_note
)
SELECT
    sdf.full_view_name,
    sdf.column_id,
    sdf.column_name,
    1 AS candidate_rank,
    'review' AS lineage_status,
    'Low' AS confidence_level,
    'single-dependency-fallback' AS lineage_method,
    sdf.referenced_entity,
    NULL AS source_column_name,
    sdf.dependency_scope,
    0 AS candidate_count,
    'Nur ein abhaengiges Objekt bekannt, aber keine belastbare Spaltenzuordnung gefunden.'
FROM SingleDependencyFallback AS sdf
WHERE NOT EXISTS
(
    SELECT 1
    FROM #ColumnLineageCandidates AS clc
    WHERE clc.full_view_name = sdf.full_view_name
      AND clc.view_column_id = sdf.column_id
);

CREATE TABLE #ViewLineageSummary
(
    full_view_name                 NVARCHAR(517)   NOT NULL,
    total_columns                  INT             NOT NULL,
    resolved_columns               INT             NOT NULL,
    ambiguous_columns              INT             NOT NULL,
    review_columns                 INT             NOT NULL,
    unresolved_columns             INT             NOT NULL,
    lineage_coverage_pct           DECIMAL(5, 2)   NOT NULL,
    primary_recommendation         NVARCHAR(260)   NOT NULL
);

INSERT INTO #ViewLineageSummary
(
    full_view_name,
    total_columns,
    resolved_columns,
    ambiguous_columns,
    review_columns,
    unresolved_columns,
    lineage_coverage_pct,
    primary_recommendation
)
SELECT
    vc.full_view_name,
    COUNT(*) AS total_columns,
    SUM(CASE WHEN topc.lineage_status = 'resolved' THEN 1 ELSE 0 END) AS resolved_columns,
    SUM(CASE WHEN topc.lineage_status = 'ambiguous' THEN 1 ELSE 0 END) AS ambiguous_columns,
    SUM(CASE WHEN topc.lineage_status = 'review' THEN 1 ELSE 0 END) AS review_columns,
    SUM(CASE WHEN topc.lineage_status IS NULL THEN 1 ELSE 0 END) AS unresolved_columns,
    CONVERT(DECIMAL(5, 2),
        100.0 * SUM(CASE WHEN topc.lineage_status = 'resolved' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0)
    ) AS lineage_coverage_pct,
    CASE
        WHEN SUM(CASE WHEN topc.lineage_status IS NULL THEN 1 ELSE 0 END) > 0 THEN 'Nicht zuordenbare Spalten gegen View-Definition und Aliasverwendung pruefen.'
        WHEN SUM(CASE WHEN topc.lineage_status IN ('ambiguous', 'review') THEN 1 ELSE 0 END) > 0 THEN 'Mehrdeutige Zuordnungen mit der echten SELECT-Liste der View verifizieren.'
        ELSE 'Lineage weitgehend ableitbar; bei Schemaaenderungen erneut pruefen.'
    END AS primary_recommendation
FROM #ViewColumns AS vc
LEFT JOIN
(
    SELECT
        clc.full_view_name,
        clc.view_column_id,
        clc.lineage_status
    FROM #ColumnLineageCandidates AS clc
    WHERE clc.candidate_rank = 1
) AS topc
    ON topc.full_view_name = vc.full_view_name
   AND topc.view_column_id = vc.column_id
GROUP BY
    vc.full_view_name;

SELECT
    vc.full_view_name,
    vc.column_id,
    vc.column_name,
    vc.data_type_name,
    vc.max_length,
    vc.precision_value,
    vc.scale_value,
    vc.is_nullable
FROM #ViewColumns AS vc
ORDER BY
    vc.full_view_name,
    vc.column_id;

SELECT
    vc.full_view_name,
    vc.column_id,
    vc.column_name,
    COALESCE(clc.lineage_status, 'unresolved') AS lineage_status,
    COALESCE(clc.confidence_level, 'Low') AS confidence_level,
    clc.lineage_method,
    clc.referenced_entity,
    clc.source_column_name,
    clc.dependency_scope,
    clc.candidate_count,
    COALESCE(clc.review_note, 'Keine belastbare Lineage aus Metadaten und Namensheuristik ableitbar.') AS review_note
FROM #ViewColumns AS vc
LEFT JOIN #ColumnLineageCandidates AS clc
    ON clc.full_view_name = vc.full_view_name
   AND clc.view_column_id = vc.column_id
WHERE @OnlyResolvable = 0
   OR clc.view_column_id IS NOT NULL
ORDER BY
    vc.full_view_name,
    vc.column_id,
    clc.candidate_rank;

IF @IncludeSummary = 1
BEGIN
    SELECT
        vls.full_view_name,
        vls.total_columns,
        vls.resolved_columns,
        vls.ambiguous_columns,
        vls.review_columns,
        vls.unresolved_columns,
        vls.lineage_coverage_pct,
        vls.primary_recommendation
    FROM #ViewLineageSummary AS vls
    WHERE @OnlyResolvable = 0
       OR vls.resolved_columns > 0
    ORDER BY
        vls.lineage_coverage_pct DESC,
        vls.unresolved_columns ASC,
        vls.full_view_name;
END;
