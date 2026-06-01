/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "ViewDependencyGraph.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "22_Views_Schemata"

purpose: >
  Erstellt einen didaktisch nutzbaren Abhaengigkeitsgraphen fuer Views in der
  aktuellen Datenbank. Das Skript verbindet Ausgangs-Views mit direkt und
  transitiv referenzierten Views, Tabellen und weiteren Objekten und markiert
  dabei nicht aufgeloeste Referenzen separat.

parameters:
  - name: "@RootViewLike"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Optionales LIKE-Muster fuer den Startpunkt der View-Auswahl"
  - name: "@MaxDepth"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Maximale Rekursionstiefe fuer transitive Abhaengigkeitspfade"
  - name: "@IncludeSummary"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zusaetzliches Summary-Resultset pro Root-View ausgeben"

result_sets:
  - name: "DependencyEdges"
    description: "Direkte Kanten zwischen Root-View, referenziertem Objekt und Aufloesungsstatus"
  - name: "DependencyPaths"
    description: "Transitive Pfade mit Tiefe, Knotentyp und Zyklusmarker"
  - name: "DependencySummary"
    description: "Optionale Verdichtung pro Root-View mit Tiefen- und Risikoindikatoren"

dependencies:
  - "sys.views"
  - "sys.schemas"
  - "sys.sql_expression_dependencies"
  - "sys.objects"
  - "sys.synonyms"
  - "sys.tables"
  - "Recursive CTE"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/22_Views_Schemata/SQLScripts/ViewDependencyGraph.md"
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
    description: "Erstversion des View-Abhaengigkeitsgraphen"

notes:
  - "Die Analyse bleibt auf Metadaten der aktuellen Datenbank beschraenkt."
  - "Nicht aufgeloeste oder externe Referenzen bleiben als Knoten im Graph sichtbar."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @RootViewLike SYSNAME = NULL;
DECLARE @MaxDepth INT = 4;
DECLARE @IncludeSummary BIT = 1;

IF @MaxDepth IS NULL OR @MaxDepth < 1 OR @MaxDepth > 10
BEGIN
    THROW 50060, '@MaxDepth muss zwischen 1 und 10 liegen.', 1;
END;

IF @IncludeSummary NOT IN (0, 1)
BEGIN
    THROW 50061, '@IncludeSummary muss 0 oder 1 sein.', 1;
END;

IF @RootViewLike IS NOT NULL AND LTRIM(RTRIM(@RootViewLike)) = ''
BEGIN
    SET @RootViewLike = NULL;
END;

DROP TABLE IF EXISTS #RootViews;
DROP TABLE IF EXISTS #DependencyEdges;
DROP TABLE IF EXISTS #DependencyPaths;
DROP TABLE IF EXISTS #DependencySummary;

CREATE TABLE #RootViews
(
    root_view_id         INT             NOT NULL,
    schema_name          SYSNAME         NOT NULL,
    view_name            SYSNAME         NOT NULL,
    full_view_name       NVARCHAR(517)   NOT NULL,
    uses_schemabinding   BIT             NOT NULL
);

INSERT INTO #RootViews
(
    root_view_id,
    schema_name,
    view_name,
    full_view_name,
    uses_schemabinding
)
SELECT
    v.object_id,
    s.name AS schema_name,
    v.name AS view_name,
    QUOTENAME(s.name) + N'.' + QUOTENAME(v.name) AS full_view_name,
    CONVERT(BIT, OBJECTPROPERTY(v.object_id, 'IsSchemaBound')) AS uses_schemabinding
FROM sys.views AS v
INNER JOIN sys.schemas AS s
    ON s.schema_id = v.schema_id
WHERE @RootViewLike IS NULL
   OR v.name LIKE @RootViewLike
   OR (QUOTENAME(s.name) + N'.' + QUOTENAME(v.name)) LIKE @RootViewLike;

CREATE TABLE #DependencyEdges
(
    root_view_id               INT             NOT NULL,
    root_view_name             NVARCHAR(517)   NOT NULL,
    referencing_object_id      INT             NOT NULL,
    referencing_object_name    NVARCHAR(517)   NOT NULL,
    referenced_object_id       INT             NULL,
    referenced_object_name     NVARCHAR(776)   NOT NULL,
    referenced_type_desc       NVARCHAR(60)    NOT NULL,
    dependency_scope           NVARCHAR(100)   NOT NULL,
    dependency_status          NVARCHAR(20)    NOT NULL,
    dependency_hint            NVARCHAR(260)   NOT NULL
);

INSERT INTO #DependencyEdges
(
    root_view_id,
    root_view_name,
    referencing_object_id,
    referencing_object_name,
    referenced_object_id,
    referenced_object_name,
    referenced_type_desc,
    dependency_scope,
    dependency_status,
    dependency_hint
)
SELECT
    rv.root_view_id,
    rv.full_view_name,
    sed.referencing_id,
    QUOTENAME(OBJECT_SCHEMA_NAME(sed.referencing_id)) + N'.' + QUOTENAME(OBJECT_NAME(sed.referencing_id)) AS referencing_object_name,
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
    ) AS referenced_object_name,
    CASE
        WHEN sed.referenced_id IS NULL AND sed.referenced_entity_name IS NOT NULL THEN 'UNRESOLVED'
        WHEN so.type_desc IS NOT NULL THEN so.type_desc
        WHEN syn.object_id IS NOT NULL THEN 'SYNONYM'
        ELSE 'UNKNOWN'
    END AS referenced_type_desc,
    CASE
        WHEN sed.referenced_server_name IS NOT NULL THEN 'cross-server'
        WHEN sed.referenced_database_name IS NOT NULL THEN 'cross-database'
        WHEN sed.referenced_schema_name IS NOT NULL THEN 'same-database'
        ELSE 'implicit-or-unresolved'
    END AS dependency_scope,
    CASE
        WHEN sed.referenced_id IS NULL THEN 'unresolved'
        WHEN so.type = 'V' THEN 'view'
        ELSE 'resolved'
    END AS dependency_status,
    CASE
        WHEN sed.referenced_id IS NULL THEN 'Referenz ist in den Metadaten nicht vollstaendig aufloesbar.'
        WHEN so.type = 'V' THEN 'Referenz fuehrt zu einer weiteren View und kann transitiv verfolgt werden.'
        WHEN so.type = 'U' THEN 'Referenz endet in einer Tabelle und markiert einen Blattknoten.'
        WHEN syn.object_id IS NOT NULL THEN 'Referenz zeigt auf ein Synonym; Zielsystem getrennt pruefen.'
        ELSE 'Referenz endet in einem anderen Objekt der aktuellen Datenbank.'
    END AS dependency_hint
FROM #RootViews AS rv
INNER JOIN sys.sql_expression_dependencies AS sed
    ON sed.referencing_id = rv.root_view_id
LEFT JOIN sys.objects AS so
    ON so.object_id = sed.referenced_id
LEFT JOIN sys.synonyms AS syn
    ON syn.object_id = sed.referenced_id;

CREATE TABLE #DependencyPaths
(
    root_view_name             NVARCHAR(517)   NOT NULL,
    depth_level                INT             NOT NULL,
    from_object_name           NVARCHAR(776)   NOT NULL,
    to_object_name             NVARCHAR(776)   NOT NULL,
    to_type_desc               NVARCHAR(60)    NOT NULL,
    dependency_scope           NVARCHAR(100)   NOT NULL,
    dependency_status          NVARCHAR(20)    NOT NULL,
    path_text                  NVARCHAR(MAX)   NOT NULL,
    cycle_detected             BIT             NOT NULL
);

WITH RecursivePaths AS
(
    SELECT
        de.root_view_id,
        de.root_view_name,
        1 AS depth_level,
        de.referencing_object_id AS current_object_id,
        de.referencing_object_name AS from_object_name,
        de.referenced_object_id AS next_object_id,
        de.referenced_object_name AS to_object_name,
        de.referenced_type_desc AS to_type_desc,
        de.dependency_scope,
        de.dependency_status,
        CAST(de.referencing_object_name + N' -> ' + de.referenced_object_name AS NVARCHAR(MAX)) AS path_text,
        CAST(
            N'|' + CAST(de.referencing_object_id AS NVARCHAR(20)) + N'|'
            + ISNULL(CAST(de.referenced_object_id AS NVARCHAR(20)) + N'|', N'UNRESOLVED|')
            AS NVARCHAR(MAX)
        ) AS visited_object_ids,
        CAST(0 AS BIT) AS cycle_detected
    FROM #DependencyEdges AS de

    UNION ALL

    SELECT
        rp.root_view_id,
        rp.root_view_name,
        rp.depth_level + 1,
        rp.next_object_id AS current_object_id,
        QUOTENAME(OBJECT_SCHEMA_NAME(rp.next_object_id)) + N'.' + QUOTENAME(OBJECT_NAME(rp.next_object_id)) AS from_object_name,
        sed.referenced_id AS next_object_id,
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
        ) AS to_object_name,
        CASE
            WHEN sed.referenced_id IS NULL AND sed.referenced_entity_name IS NOT NULL THEN 'UNRESOLVED'
            WHEN so.type_desc IS NOT NULL THEN so.type_desc
            WHEN syn.object_id IS NOT NULL THEN 'SYNONYM'
            ELSE 'UNKNOWN'
        END AS to_type_desc,
        CASE
            WHEN sed.referenced_server_name IS NOT NULL THEN 'cross-server'
            WHEN sed.referenced_database_name IS NOT NULL THEN 'cross-database'
            WHEN sed.referenced_schema_name IS NOT NULL THEN 'same-database'
            ELSE 'implicit-or-unresolved'
        END AS dependency_scope,
        CASE
            WHEN sed.referenced_id IS NULL THEN 'unresolved'
            WHEN so.type = 'V' THEN 'view'
            ELSE 'resolved'
        END AS dependency_status,
        CAST(rp.path_text + N' -> ' + COALESCE(
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
        ) AS NVARCHAR(MAX)) AS path_text,
        CAST(
            rp.visited_object_ids
            + ISNULL(CAST(sed.referenced_id AS NVARCHAR(20)) + N'|', N'UNRESOLVED|')
            AS NVARCHAR(MAX)
        ) AS visited_object_ids,
        CAST(
            CASE
                WHEN sed.referenced_id IS NOT NULL
                 AND rp.visited_object_ids LIKE N'%|' + CAST(sed.referenced_id AS NVARCHAR(20)) + N'|%'
                    THEN 1
                ELSE 0
            END AS BIT
        ) AS cycle_detected
    FROM RecursivePaths AS rp
    INNER JOIN sys.sql_expression_dependencies AS sed
        ON sed.referencing_id = rp.next_object_id
    LEFT JOIN sys.objects AS so
        ON so.object_id = sed.referenced_id
    LEFT JOIN sys.synonyms AS syn
        ON syn.object_id = sed.referenced_id
    WHERE rp.next_object_id IS NOT NULL
      AND rp.depth_level < @MaxDepth
      AND rp.cycle_detected = 0
      AND EXISTS
      (
          SELECT 1
          FROM sys.views AS v
          WHERE v.object_id = rp.next_object_id
      )
)
INSERT INTO #DependencyPaths
(
    root_view_name,
    depth_level,
    from_object_name,
    to_object_name,
    to_type_desc,
    dependency_scope,
    dependency_status,
    path_text,
    cycle_detected
)
SELECT
    rp.root_view_name,
    rp.depth_level,
    rp.from_object_name,
    rp.to_object_name,
    rp.to_type_desc,
    rp.dependency_scope,
    rp.dependency_status,
    rp.path_text,
    rp.cycle_detected
FROM RecursivePaths AS rp;

CREATE TABLE #DependencySummary
(
    root_view_name             NVARCHAR(517)   NOT NULL,
    direct_dependency_count    INT             NOT NULL,
    transitive_edge_count      INT             NOT NULL,
    max_depth_found            INT             NOT NULL,
    nested_view_count          INT             NOT NULL,
    table_leaf_count           INT             NOT NULL,
    unresolved_count           INT             NOT NULL,
    cycle_count                INT             NOT NULL,
    primary_recommendation     NVARCHAR(260)   NOT NULL
);

INSERT INTO #DependencySummary
(
    root_view_name,
    direct_dependency_count,
    transitive_edge_count,
    max_depth_found,
    nested_view_count,
    table_leaf_count,
    unresolved_count,
    cycle_count,
    primary_recommendation
)
SELECT
    rv.full_view_name,
    ISNULL(de_stats.direct_dependency_count, 0) AS direct_dependency_count,
    ISNULL(dp_stats.transitive_edge_count, 0) AS transitive_edge_count,
    ISNULL(dp_stats.max_depth_found, 0) AS max_depth_found,
    ISNULL(dp_stats.nested_view_count, 0) AS nested_view_count,
    ISNULL(dp_stats.table_leaf_count, 0) AS table_leaf_count,
    ISNULL(dp_stats.unresolved_count, 0) AS unresolved_count,
    ISNULL(dp_stats.cycle_count, 0) AS cycle_count,
    CASE
        WHEN ISNULL(dp_stats.cycle_count, 0) > 0 THEN 'Zyklische View-Ketten gegen Definition und Deploy-Reihenfolge pruefen.'
        WHEN ISNULL(dp_stats.unresolved_count, 0) > 0 THEN 'Nicht aufgeloeste Referenzen manuell gegen Definition und Zielobjekte verifizieren.'
        WHEN ISNULL(dp_stats.nested_view_count, 0) >= 3 THEN 'Tiefe View-Ketten fuer Lesbarkeit, Performance und Refresh-Reihenfolge dokumentieren.'
        ELSE 'Graph ist fuer diese Root-View ueberschaubar; bei Schemaaenderungen erneut pruefen.'
    END AS primary_recommendation
FROM #RootViews AS rv
OUTER APPLY
(
    SELECT COUNT(*) AS direct_dependency_count
    FROM #DependencyEdges AS de
    WHERE de.root_view_id = rv.root_view_id
) AS de_stats
OUTER APPLY
(
    SELECT
        COUNT(*) AS transitive_edge_count,
        MAX(dp.depth_level) AS max_depth_found,
        SUM(CASE WHEN dp.to_type_desc = 'VIEW' THEN 1 ELSE 0 END) AS nested_view_count,
        SUM(CASE WHEN dp.to_type_desc = 'USER_TABLE' THEN 1 ELSE 0 END) AS table_leaf_count,
        SUM(CASE WHEN dp.dependency_status = 'unresolved' THEN 1 ELSE 0 END) AS unresolved_count,
        SUM(CASE WHEN dp.cycle_detected = 1 THEN 1 ELSE 0 END) AS cycle_count
    FROM #DependencyPaths AS dp
    WHERE dp.root_view_name = rv.full_view_name
) AS dp_stats;

SELECT
    de.root_view_name,
    de.referencing_object_name,
    de.referenced_object_name,
    de.referenced_type_desc,
    de.dependency_scope,
    de.dependency_status,
    de.dependency_hint
FROM #DependencyEdges AS de
ORDER BY
    de.root_view_name,
    de.referencing_object_name,
    de.referenced_object_name;

SELECT
    dp.root_view_name,
    dp.depth_level,
    dp.from_object_name,
    dp.to_object_name,
    dp.to_type_desc,
    dp.dependency_scope,
    dp.dependency_status,
    dp.cycle_detected,
    dp.path_text
FROM #DependencyPaths AS dp
ORDER BY
    dp.root_view_name,
    dp.depth_level,
    dp.from_object_name,
    dp.to_object_name;

IF @IncludeSummary = 1
BEGIN
    SELECT
        ds.root_view_name,
        ds.direct_dependency_count,
        ds.transitive_edge_count,
        ds.max_depth_found,
        ds.nested_view_count,
        ds.table_leaf_count,
        ds.unresolved_count,
        ds.cycle_count,
        ds.primary_recommendation
    FROM #DependencySummary AS ds
    ORDER BY
        ds.unresolved_count DESC,
        ds.max_depth_found DESC,
        ds.root_view_name;
END;
