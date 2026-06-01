/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "ViewDependencyTree.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "22_Views_Schemata"

purpose: >
  Baut einen lesbaren Abhaengigkeitsbaum fuer Views in der aktuellen
  Datenbank. Das Skript startet bei ausgewaehlten Root-Views, verfolgt
  weitere View-Referenzen rekursiv und zeigt Tabellen, Synonyme,
  externe Ziele sowie nicht aufgeloeste Referenzen als Blattknoten.

parameters:
  - name: "@RootViewLike"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Optionales LIKE-Muster fuer die Auswahl der Root-Views"
  - name: "@MaxDepth"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Maximale Tiefe fuer die rekursive Baumdarstellung"
  - name: "@IncludeSummary"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zusaetzliches Summary-Resultset pro Root-View ausgeben"

result_sets:
  - name: "ViewDependencyTree"
    description: "Baumansicht mit Tiefe, Einrueckung, Knotentyp und Zyklusmarker"
  - name: "ViewDependencyEdges"
    description: "Direkte Parent-Child-Kanten fuer die Root-Views"
  - name: "ViewDependencySummary"
    description: "Optionale Zusammenfassung pro Root-View mit Tiefen- und Risikokennzahlen"

dependencies:
  - "sys.views"
  - "sys.schemas"
  - "sys.sql_expression_dependencies"
  - "sys.objects"
  - "sys.synonyms"
  - "Recursive CTE"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/22_Views_Schemata/SQLScripts/ViewDependencyTree.md"
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
    description: "Erstversion des lesbaren View-Abhaengigkeitbaums"

notes:
  - "Das Skript nutzt ausschliesslich Metadaten der aktuellen Datenbank."
  - "Rekursion folgt nur weiteren Views; andere Objekttypen bleiben als Blattknoten sichtbar."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @RootViewLike SYSNAME = NULL;
DECLARE @MaxDepth INT = 5;
DECLARE @IncludeSummary BIT = 1;

IF @MaxDepth IS NULL OR @MaxDepth < 1 OR @MaxDepth > 12
BEGIN
    THROW 50070, '@MaxDepth muss zwischen 1 und 12 liegen.', 1;
END;

IF @IncludeSummary NOT IN (0, 1)
BEGIN
    THROW 50071, '@IncludeSummary muss 0 oder 1 sein.', 1;
END;

IF @RootViewLike IS NOT NULL AND LTRIM(RTRIM(@RootViewLike)) = ''
BEGIN
    SET @RootViewLike = NULL;
END;

DROP TABLE IF EXISTS #RootViews;
DROP TABLE IF EXISTS #DependencyEdges;
DROP TABLE IF EXISTS #DependencyTree;
DROP TABLE IF EXISTS #DependencySummary;

CREATE TABLE #RootViews
(
    root_view_id       INT             NOT NULL,
    schema_name        SYSNAME         NOT NULL,
    view_name          SYSNAME         NOT NULL,
    full_view_name     NVARCHAR(517)   NOT NULL
);

INSERT INTO #RootViews
(
    root_view_id,
    schema_name,
    view_name,
    full_view_name
)
SELECT
    v.object_id,
    s.name AS schema_name,
    v.name AS view_name,
    QUOTENAME(s.name) + N'.' + QUOTENAME(v.name) AS full_view_name
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
    parent_object_id           INT             NOT NULL,
    parent_object_name         NVARCHAR(517)   NOT NULL,
    child_object_id            INT             NULL,
    child_object_name          NVARCHAR(900)   NOT NULL,
    child_type_desc            NVARCHAR(60)    NOT NULL,
    dependency_scope           NVARCHAR(100)   NOT NULL,
    dependency_status          NVARCHAR(20)    NOT NULL,
    traversal_allowed          BIT             NOT NULL,
    dependency_note            NVARCHAR(260)   NOT NULL
);

INSERT INTO #DependencyEdges
(
    root_view_id,
    root_view_name,
    parent_object_id,
    parent_object_name,
    child_object_id,
    child_object_name,
    child_type_desc,
    dependency_scope,
    dependency_status,
    traversal_allowed,
    dependency_note
)
SELECT
    rv.root_view_id,
    rv.full_view_name,
    sed.referencing_id AS parent_object_id,
    QUOTENAME(OBJECT_SCHEMA_NAME(sed.referencing_id))
        + N'.'
        + QUOTENAME(OBJECT_NAME(sed.referencing_id)) AS parent_object_name,
    sed.referenced_id AS child_object_id,
    COALESCE(
        CASE
            WHEN sed.referenced_id IS NOT NULL THEN
                QUOTENAME(OBJECT_SCHEMA_NAME(sed.referenced_id))
                + N'.'
                + QUOTENAME(OBJECT_NAME(sed.referenced_id))
        END,
        CASE
            WHEN sed.referenced_server_name IS NOT NULL THEN
                QUOTENAME(sed.referenced_server_name)
                + N'.'
                + QUOTENAME(sed.referenced_database_name)
                + COALESCE(N'.' + QUOTENAME(sed.referenced_schema_name), N'')
                + COALESCE(N'.' + QUOTENAME(sed.referenced_entity_name), N'')
            WHEN sed.referenced_database_name IS NOT NULL THEN
                QUOTENAME(sed.referenced_database_name)
                + COALESCE(N'.' + QUOTENAME(sed.referenced_schema_name), N'')
                + COALESCE(N'.' + QUOTENAME(sed.referenced_entity_name), N'')
            WHEN sed.referenced_schema_name IS NOT NULL AND sed.referenced_entity_name IS NOT NULL THEN
                QUOTENAME(sed.referenced_schema_name) + N'.' + QUOTENAME(sed.referenced_entity_name)
            WHEN sed.referenced_entity_name IS NOT NULL THEN
                QUOTENAME(sed.referenced_entity_name)
            ELSE
                N'(unresolved reference)'
        END
    ) AS child_object_name,
    CASE
        WHEN sed.referenced_id IS NULL AND sed.referenced_server_name IS NOT NULL THEN 'EXTERNAL_REFERENCE'
        WHEN sed.referenced_id IS NULL AND sed.referenced_database_name IS NOT NULL THEN 'CROSS_DATABASE_REFERENCE'
        WHEN sed.referenced_id IS NULL AND sed.referenced_entity_name IS NOT NULL THEN 'UNRESOLVED'
        WHEN so.type_desc IS NOT NULL THEN so.type_desc
        WHEN syn.object_id IS NOT NULL THEN 'SYNONYM'
        ELSE 'UNKNOWN'
    END AS child_type_desc,
    CASE
        WHEN sed.referenced_server_name IS NOT NULL THEN 'cross-server'
        WHEN sed.referenced_database_name IS NOT NULL THEN 'cross-database'
        WHEN sed.referenced_schema_name IS NOT NULL THEN 'same-database'
        ELSE 'implicit-or-unresolved'
    END AS dependency_scope,
    CASE
        WHEN sed.referenced_id IS NULL THEN 'unresolved'
        WHEN so.type = 'V' THEN 'nested-view'
        ELSE 'leaf'
    END AS dependency_status,
    CONVERT(
        BIT,
        CASE
            WHEN so.type = 'V' THEN 1
            ELSE 0
        END
    ) AS traversal_allowed,
    CASE
        WHEN sed.referenced_id IS NULL AND sed.referenced_server_name IS NOT NULL THEN 'Externer Zielknoten bleibt als Blatt im Baum sichtbar.'
        WHEN sed.referenced_id IS NULL AND sed.referenced_database_name IS NOT NULL THEN 'Cross-Database-Referenz bleibt als Blatt sichtbar.'
        WHEN sed.referenced_id IS NULL THEN 'Referenz ist in den Metadaten nicht vollstaendig aufloesbar.'
        WHEN so.type = 'V' THEN 'Weitere View kann rekursiv in den Baum aufgenommen werden.'
        WHEN so.type = 'U' THEN 'Tabelle bildet einen Blattknoten im Baum.'
        WHEN syn.object_id IS NOT NULL THEN 'Synonym wird als Blattknoten und Kopplungspunkt markiert.'
        ELSE 'Objekt bleibt als technischer Blattknoten sichtbar.'
    END AS dependency_note
FROM #RootViews AS rv
INNER JOIN sys.sql_expression_dependencies AS sed
    ON sed.referencing_id = rv.root_view_id
LEFT JOIN sys.objects AS so
    ON so.object_id = sed.referenced_id
LEFT JOIN sys.synonyms AS syn
    ON syn.object_id = sed.referenced_id;

CREATE TABLE #DependencyTree
(
    root_view_name        NVARCHAR(517)   NOT NULL,
    depth_level           INT             NOT NULL,
    parent_object_name    NVARCHAR(517)   NOT NULL,
    node_object_name      NVARCHAR(900)   NOT NULL,
    node_type_desc        NVARCHAR(60)    NOT NULL,
    dependency_scope      NVARCHAR(100)   NOT NULL,
    dependency_status     NVARCHAR(20)    NOT NULL,
    node_path             NVARCHAR(MAX)   NOT NULL,
    tree_label            NVARCHAR(1200)  NOT NULL,
    cycle_detected        BIT             NOT NULL
);

WITH RecursiveTree AS
(
    SELECT
        de.root_view_id,
        de.root_view_name,
        1 AS depth_level,
        de.parent_object_id,
        de.parent_object_name,
        de.child_object_id,
        de.child_object_name,
        de.child_type_desc,
        de.dependency_scope,
        de.dependency_status,
        CAST(de.root_view_name + N' -> ' + de.child_object_name AS NVARCHAR(MAX)) AS node_path,
        CAST(
            REPLICATE(N'  ', 1)
            + CASE WHEN de.traversal_allowed = 1 THEN N'+- ' ELSE N'*  ' END
            + de.child_object_name
            + N' [' + de.child_type_desc + N']'
            AS NVARCHAR(1200)
        ) AS tree_label,
        CAST(
            N'|' + CAST(de.parent_object_id AS NVARCHAR(20)) + N'|'
            + ISNULL(CAST(de.child_object_id AS NVARCHAR(20)) + N'|', N'UNRESOLVED|')
            AS NVARCHAR(MAX)
        ) AS visited_object_ids,
        CAST(0 AS BIT) AS cycle_detected
    FROM #DependencyEdges AS de

    UNION ALL

    SELECT
        rt.root_view_id,
        rt.root_view_name,
        rt.depth_level + 1,
        de.parent_object_id,
        de.parent_object_name,
        de.child_object_id,
        de.child_object_name,
        de.child_type_desc,
        de.dependency_scope,
        de.dependency_status,
        CAST(rt.node_path + N' -> ' + de.child_object_name AS NVARCHAR(MAX)) AS node_path,
        CAST(
            REPLICATE(N'  ', rt.depth_level + 1)
            + CASE
                WHEN de.child_object_id IS NOT NULL
                 AND rt.visited_object_ids LIKE N'%|' + CAST(de.child_object_id AS NVARCHAR(20)) + N'|%'
                    THEN N'!  '
                WHEN de.traversal_allowed = 1 THEN N'+- '
                ELSE N'*  '
              END
            + de.child_object_name
            + N' [' + de.child_type_desc + N']'
            AS NVARCHAR(1200)
        ) AS tree_label,
        CAST(
            rt.visited_object_ids
            + ISNULL(CAST(de.child_object_id AS NVARCHAR(20)) + N'|', N'UNRESOLVED|')
            AS NVARCHAR(MAX)
        ) AS visited_object_ids,
        CAST(
            CASE
                WHEN de.child_object_id IS NOT NULL
                 AND rt.visited_object_ids LIKE N'%|' + CAST(de.child_object_id AS NVARCHAR(20)) + N'|%'
                    THEN 1
                ELSE 0
            END AS BIT
        ) AS cycle_detected
    FROM RecursiveTree AS rt
    INNER JOIN #DependencyEdges AS de
        ON de.parent_object_id = rt.child_object_id
       AND de.root_view_id = rt.root_view_id
    WHERE rt.child_object_id IS NOT NULL
      AND rt.depth_level < @MaxDepth
      AND rt.cycle_detected = 0
      AND EXISTS
      (
          SELECT 1
          FROM sys.views AS v
          WHERE v.object_id = rt.child_object_id
      )
)
INSERT INTO #DependencyTree
(
    root_view_name,
    depth_level,
    parent_object_name,
    node_object_name,
    node_type_desc,
    dependency_scope,
    dependency_status,
    node_path,
    tree_label,
    cycle_detected
)
SELECT
    rt.root_view_name,
    rt.depth_level,
    rt.parent_object_name,
    rt.child_object_name,
    rt.child_type_desc,
    rt.dependency_scope,
    rt.dependency_status,
    rt.node_path,
    rt.tree_label,
    rt.cycle_detected
FROM RecursiveTree AS rt;

CREATE TABLE #DependencySummary
(
    root_view_name             NVARCHAR(517)   NOT NULL,
    direct_child_count         INT             NOT NULL,
    total_tree_nodes           INT             NOT NULL,
    max_depth_found            INT             NOT NULL,
    nested_view_count          INT             NOT NULL,
    leaf_node_count            INT             NOT NULL,
    unresolved_node_count      INT             NOT NULL,
    cycle_count                INT             NOT NULL,
    primary_recommendation     NVARCHAR(260)   NOT NULL
);

INSERT INTO #DependencySummary
(
    root_view_name,
    direct_child_count,
    total_tree_nodes,
    max_depth_found,
    nested_view_count,
    leaf_node_count,
    unresolved_node_count,
    cycle_count,
    primary_recommendation
)
SELECT
    rv.full_view_name,
    ISNULL(direct_stats.direct_child_count, 0) AS direct_child_count,
    ISNULL(tree_stats.total_tree_nodes, 0) AS total_tree_nodes,
    ISNULL(tree_stats.max_depth_found, 0) AS max_depth_found,
    ISNULL(tree_stats.nested_view_count, 0) AS nested_view_count,
    ISNULL(tree_stats.leaf_node_count, 0) AS leaf_node_count,
    ISNULL(tree_stats.unresolved_node_count, 0) AS unresolved_node_count,
    ISNULL(tree_stats.cycle_count, 0) AS cycle_count,
    CASE
        WHEN ISNULL(tree_stats.cycle_count, 0) > 0 THEN 'Zyklische View-Ketten gegen Definition und Deploy-Reihenfolge pruefen.'
        WHEN ISNULL(tree_stats.unresolved_node_count, 0) > 0 THEN 'Nicht aufgeloeste oder externe Knoten manuell gegen Zielobjekte verifizieren.'
        WHEN ISNULL(tree_stats.max_depth_found, 0) >= 4 THEN 'Tiefe Baumstruktur fuer Lesbarkeit, Performance und Aenderungsfolgen dokumentieren.'
        ELSE 'Baum ist ueberschaubar; bei Schemaaenderungen erneut analysieren.'
    END AS primary_recommendation
FROM #RootViews AS rv
OUTER APPLY
(
    SELECT COUNT(*) AS direct_child_count
    FROM #DependencyEdges AS de
    WHERE de.root_view_id = rv.root_view_id
) AS direct_stats
OUTER APPLY
(
    SELECT
        COUNT(*) AS total_tree_nodes,
        MAX(dt.depth_level) AS max_depth_found,
        SUM(CASE WHEN dt.node_type_desc = 'VIEW' THEN 1 ELSE 0 END) AS nested_view_count,
        SUM(CASE WHEN dt.node_type_desc <> 'VIEW' THEN 1 ELSE 0 END) AS leaf_node_count,
        SUM(CASE WHEN dt.dependency_status = 'unresolved' THEN 1 ELSE 0 END) AS unresolved_node_count,
        SUM(CASE WHEN dt.cycle_detected = 1 THEN 1 ELSE 0 END) AS cycle_count
    FROM #DependencyTree AS dt
    WHERE dt.root_view_name = rv.full_view_name
) AS tree_stats;

SELECT
    dt.root_view_name,
    dt.depth_level,
    dt.parent_object_name,
    dt.node_object_name,
    dt.node_type_desc,
    dt.dependency_scope,
    dt.dependency_status,
    dt.cycle_detected,
    dt.tree_label,
    dt.node_path
FROM #DependencyTree AS dt
ORDER BY
    dt.root_view_name,
    dt.node_path;

SELECT
    de.root_view_name,
    de.parent_object_name,
    de.child_object_name,
    de.child_type_desc,
    de.dependency_scope,
    de.dependency_status,
    de.traversal_allowed,
    de.dependency_note
FROM #DependencyEdges AS de
ORDER BY
    de.root_view_name,
    de.parent_object_name,
    de.child_object_name;

IF @IncludeSummary = 1
BEGIN
    SELECT
        ds.root_view_name,
        ds.direct_child_count,
        ds.total_tree_nodes,
        ds.max_depth_found,
        ds.nested_view_count,
        ds.leaf_node_count,
        ds.unresolved_node_count,
        ds.cycle_count,
        ds.primary_recommendation
    FROM #DependencySummary AS ds
    ORDER BY
        ds.unresolved_node_count DESC,
        ds.max_depth_found DESC,
        ds.root_view_name;
END;
