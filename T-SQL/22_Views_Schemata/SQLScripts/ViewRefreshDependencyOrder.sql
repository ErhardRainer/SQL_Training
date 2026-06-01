/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "ViewRefreshDependencyOrder.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "22_Views_Schemata"

purpose: >
  Ermittelt eine didaktisch nutzbare Reihenfolge fuer View-Refreshes nach
  Aenderungen an abhaengigen Objekten. Das Skript wertet View-zu-View-
  Abhaengigkeiten aus, priorisiert tiefer liegende Basis-Views vor darauf
  aufbauenden Views und markiert Zyklen oder unaufgeloeste Referenzen als
  Review-Hinweise.

parameters:
  - name: "@SchemaNameLike"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Optionales LIKE-Muster fuer das Schema der betrachteten Views"
  - name: "@RootViewLike"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Optionales LIKE-Muster fuer einzelne Views oder vollqualifizierte View-Namen"
  - name: "@IncludeCommands"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zusaetzliches Resultset mit empfohlenen Refresh-Kommandos ausgeben"

result_sets:
  - name: "ViewRefreshOrder"
    description: "Empfohlene Refresh-Reihenfolge mit Level, Risiken und Kommandotyp"
  - name: "ViewRefreshDependencies"
    description: "Direkte View-zu-View-Kanten und sonstige Referenzhinweise"
  - name: "ViewRefreshSummary"
    description: "Zusammenfassung ueber sichere Kandidaten, Zyklen und Blocker"
  - name: "RefreshCommands"
    description: "Optionale Kommandoliste fuer die manuelle Ausfuehrung"

dependencies:
  - "sys.views"
  - "sys.schemas"
  - "sys.sql_expression_dependencies"
  - "sys.objects"
  - "sys.sql_modules"
  - "sp_refreshview"
  - "sp_refreshsqlmodule"
  - "Recursive CTE"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/22_Views_Schemata/SQLScripts/ViewRefreshDependencyOrder.md"
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
    description: "Erstversion der diagnostischen Refresh-Reihenfolge fuer Views"

notes:
  - "Das Skript fuehrt keinen Refresh aus, sondern berechnet nur eine belastbare Reihenfolge."
  - "Cross-Database- oder unaufgeloeste Referenzen werden als Review-Hinweis markiert."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @SchemaNameLike SYSNAME = NULL;
DECLARE @RootViewLike SYSNAME = NULL;
DECLARE @IncludeCommands BIT = 1;

IF @IncludeCommands NOT IN (0, 1)
BEGIN
    THROW 50080, '@IncludeCommands muss 0 oder 1 sein.', 1;
END;

IF @SchemaNameLike IS NOT NULL AND LTRIM(RTRIM(@SchemaNameLike)) = ''
BEGIN
    SET @SchemaNameLike = NULL;
END;

IF @RootViewLike IS NOT NULL AND LTRIM(RTRIM(@RootViewLike)) = ''
BEGIN
    SET @RootViewLike = NULL;
END;

DROP TABLE IF EXISTS #ViewInventory;
DROP TABLE IF EXISTS #DependencyEdges;
DROP TABLE IF EXISTS #RefreshLevels;
DROP TABLE IF EXISTS #CycleRoots;
DROP TABLE IF EXISTS #RefreshPlan;
DROP TABLE IF EXISTS #RefreshSummary;
DROP TABLE IF EXISTS #RefreshCommands;

CREATE TABLE #ViewInventory
(
    view_object_id         INT             NOT NULL,
    schema_name            SYSNAME         NOT NULL,
    view_name              SYSNAME         NOT NULL,
    full_view_name         NVARCHAR(517)   NOT NULL,
    uses_schemabinding     BIT             NOT NULL,
    refresh_command_type   NVARCHAR(40)    NOT NULL,
    refresh_command        NVARCHAR(700)   NOT NULL
);

INSERT INTO #ViewInventory
(
    view_object_id,
    schema_name,
    view_name,
    full_view_name,
    uses_schemabinding,
    refresh_command_type,
    refresh_command
)
SELECT
    v.object_id,
    s.name AS schema_name,
    v.name AS view_name,
    QUOTENAME(s.name) + N'.' + QUOTENAME(v.name) AS full_view_name,
    CONVERT(BIT, OBJECTPROPERTY(v.object_id, 'IsSchemaBound')) AS uses_schemabinding,
    CASE
        WHEN OBJECTPROPERTY(v.object_id, 'IsSchemaBound') = 1 THEN 'sp_refreshsqlmodule'
        ELSE 'sp_refreshview'
    END AS refresh_command_type,
    CASE
        WHEN OBJECTPROPERTY(v.object_id, 'IsSchemaBound') = 1 THEN
            N'EXEC sys.sp_refreshsqlmodule N'''
            + REPLACE(QUOTENAME(s.name) + N'.' + QUOTENAME(v.name), '''', '''''')
            + N''';'
        ELSE
            N'EXEC sys.sp_refreshview N'''
            + REPLACE(QUOTENAME(s.name) + N'.' + QUOTENAME(v.name), '''', '''''')
            + N''';'
    END AS refresh_command
FROM sys.views AS v
INNER JOIN sys.schemas AS s
    ON s.schema_id = v.schema_id
WHERE (@SchemaNameLike IS NULL OR s.name LIKE @SchemaNameLike)
  AND (
        @RootViewLike IS NULL
        OR v.name LIKE @RootViewLike
        OR (QUOTENAME(s.name) + N'.' + QUOTENAME(v.name)) LIKE @RootViewLike
      );

CREATE TABLE #DependencyEdges
(
    referencing_view_id       INT             NOT NULL,
    referencing_view_name     NVARCHAR(517)   NOT NULL,
    referenced_view_id        INT             NULL,
    referenced_view_name      NVARCHAR(776)   NOT NULL,
    dependency_kind           NVARCHAR(40)    NOT NULL,
    dependency_scope          NVARCHAR(100)   NOT NULL,
    refresh_blocker           BIT             NOT NULL,
    blocker_reason            NVARCHAR(260)   NOT NULL
);

INSERT INTO #DependencyEdges
(
    referencing_view_id,
    referencing_view_name,
    referenced_view_id,
    referenced_view_name,
    dependency_kind,
    dependency_scope,
    refresh_blocker,
    blocker_reason
)
SELECT
    vi.view_object_id AS referencing_view_id,
    vi.full_view_name AS referencing_view_name,
    rv.view_object_id AS referenced_view_id,
    COALESCE(
        rv.full_view_name,
        CASE
            WHEN sed.referenced_schema_name IS NOT NULL AND sed.referenced_entity_name IS NOT NULL THEN
                QUOTENAME(sed.referenced_schema_name) + N'.' + QUOTENAME(sed.referenced_entity_name)
            WHEN sed.referenced_entity_name IS NOT NULL THEN
                QUOTENAME(sed.referenced_entity_name)
            ELSE
                N'(unresolved reference)'
        END
    ) AS referenced_view_name,
    CASE
        WHEN rv.view_object_id IS NOT NULL THEN 'view'
        WHEN sed.referenced_id IS NULL AND sed.referenced_entity_name IS NOT NULL THEN 'unresolved'
        ELSE 'other-object'
    END AS dependency_kind,
    CASE
        WHEN sed.referenced_server_name IS NOT NULL THEN 'cross-server'
        WHEN sed.referenced_database_name IS NOT NULL THEN 'cross-database'
        WHEN sed.referenced_schema_name IS NOT NULL THEN 'same-database'
        ELSE 'implicit-or-unresolved'
    END AS dependency_scope,
    CONVERT(
        BIT,
        CASE
            WHEN sed.referenced_database_name IS NOT NULL OR sed.referenced_server_name IS NOT NULL THEN 1
            WHEN sed.referenced_id IS NULL AND sed.referenced_entity_name IS NOT NULL THEN 1
            ELSE 0
        END
    ) AS refresh_blocker,
    CASE
        WHEN sed.referenced_server_name IS NOT NULL THEN 'Externe Server-Referenz vor lokalem Refresh gesondert pruefen.'
        WHEN sed.referenced_database_name IS NOT NULL THEN 'Cross-Database-Referenz vor Refresh im Zielkontext pruefen.'
        WHEN sed.referenced_id IS NULL AND sed.referenced_entity_name IS NOT NULL THEN 'Referenz ist in den Metadaten nicht vollstaendig aufloesbar.'
        WHEN rv.view_object_id IS NOT NULL THEN 'Abhaengige View muss vor der referenzierenden View betrachtet werden.'
        ELSE 'Kein weiterer View-Refresh-Schritt aus dieser Kante ableitbar.'
    END AS blocker_reason
FROM #ViewInventory AS vi
LEFT JOIN sys.sql_expression_dependencies AS sed
    ON sed.referencing_id = vi.view_object_id
LEFT JOIN #ViewInventory AS rv
    ON rv.view_object_id = sed.referenced_id;
WHERE sed.referencing_id IS NOT NULL;

CREATE TABLE #RefreshLevels
(
    root_view_id             INT             NOT NULL,
    referenced_view_id       INT             NULL,
    depth_to_base            INT             NOT NULL,
    cycle_detected           BIT             NOT NULL
);

WITH RecursiveLevels AS
(
    SELECT
        de.referencing_view_id AS root_view_id,
        de.referenced_view_id,
        1 AS depth_to_base,
        CAST(
            N'|' + CAST(de.referencing_view_id AS NVARCHAR(20)) + N'|'
            + ISNULL(CAST(de.referenced_view_id AS NVARCHAR(20)) + N'|', N'NULL|')
            AS NVARCHAR(MAX)
        ) AS visited_path,
        CAST(0 AS BIT) AS cycle_detected
    FROM #DependencyEdges AS de
    WHERE de.dependency_kind = 'view'

    UNION ALL

    SELECT
        rl.root_view_id,
        de.referenced_view_id,
        rl.depth_to_base + 1,
        CAST(
            rl.visited_path
            + ISNULL(CAST(de.referenced_view_id AS NVARCHAR(20)) + N'|', N'NULL|')
            AS NVARCHAR(MAX)
        ) AS visited_path,
        CAST(
            CASE
                WHEN de.referenced_view_id IS NOT NULL
                 AND rl.visited_path LIKE N'%|' + CAST(de.referenced_view_id AS NVARCHAR(20)) + N'|%'
                    THEN 1
                ELSE 0
            END AS BIT
        ) AS cycle_detected
    FROM RecursiveLevels AS rl
    INNER JOIN #DependencyEdges AS de
        ON de.referencing_view_id = rl.referenced_view_id
       AND de.dependency_kind = 'view'
    WHERE rl.referenced_view_id IS NOT NULL
      AND rl.cycle_detected = 0
)
INSERT INTO #RefreshLevels
(
    root_view_id,
    referenced_view_id,
    depth_to_base,
    cycle_detected
)
SELECT
    rl.root_view_id,
    rl.referenced_view_id,
    rl.depth_to_base,
    rl.cycle_detected
FROM RecursiveLevels AS rl;

CREATE TABLE #CycleRoots
(
    view_object_id INT NOT NULL PRIMARY KEY
);

INSERT INTO #CycleRoots
(
    view_object_id
)
SELECT DISTINCT
    rl.root_view_id
FROM #RefreshLevels AS rl
WHERE rl.cycle_detected = 1;

CREATE TABLE #RefreshPlan
(
    refresh_level                INT             NOT NULL,
    full_view_name               NVARCHAR(517)   NOT NULL,
    schema_name                  SYSNAME         NOT NULL,
    view_name                    SYSNAME         NOT NULL,
    refresh_command_type         NVARCHAR(40)    NOT NULL,
    recommended_refresh_command  NVARCHAR(700)   NOT NULL,
    nested_view_count            INT             NOT NULL,
    max_dependency_depth         INT             NOT NULL,
    has_cycle                    BIT             NOT NULL,
    has_refresh_blocker          BIT             NOT NULL,
    readiness                    NVARCHAR(20)    NOT NULL,
    recommendation               NVARCHAR(260)   NOT NULL
);

INSERT INTO #RefreshPlan
(
    refresh_level,
    full_view_name,
    schema_name,
    view_name,
    refresh_command_type,
    recommended_refresh_command,
    nested_view_count,
    max_dependency_depth,
    has_cycle,
    has_refresh_blocker,
    readiness,
    recommendation
)
SELECT
    CASE
        WHEN stats.max_dependency_depth IS NULL THEN 1
        ELSE stats.max_dependency_depth + 1
    END AS refresh_level,
    vi.full_view_name,
    vi.schema_name,
    vi.view_name,
    vi.refresh_command_type,
    vi.refresh_command,
    ISNULL(stats.nested_view_count, 0) AS nested_view_count,
    ISNULL(stats.max_dependency_depth, 0) AS max_dependency_depth,
    CONVERT(BIT, CASE WHEN cr.view_object_id IS NULL THEN 0 ELSE 1 END) AS has_cycle,
    ISNULL(edge_stats.has_refresh_blocker, 0) AS has_refresh_blocker,
    CASE
        WHEN cr.view_object_id IS NOT NULL THEN 'review'
        WHEN ISNULL(edge_stats.has_refresh_blocker, 0) = 1 THEN 'review'
        ELSE 'ready'
    END AS readiness,
    CASE
        WHEN cr.view_object_id IS NOT NULL THEN 'Zyklische View-Abhaengigkeit vor automatisierter Refresh-Reihenfolge manuell aufloesen.'
        WHEN ISNULL(edge_stats.has_refresh_blocker, 0) = 1 THEN 'Refresh-Reihenfolge lokal nutzbar, aber Blocker-Referenzen zuerst manuell pruefen.'
        WHEN ISNULL(stats.max_dependency_depth, 0) = 0 THEN 'Leaf-View ohne weitere View-Abhaengigkeit frueh refreshen.'
        ELSE 'Abhaengige Basis-Views zuerst refreshen, dann diese View in der berechneten Stufe.'
    END AS recommendation
FROM #ViewInventory AS vi
OUTER APPLY
(
    SELECT
        MAX(rl.depth_to_base) AS max_dependency_depth,
        COUNT(DISTINCT rl.referenced_view_id) AS nested_view_count
    FROM #RefreshLevels AS rl
    WHERE rl.root_view_id = vi.view_object_id
      AND rl.cycle_detected = 0
) AS stats
OUTER APPLY
(
    SELECT
        MAX(CASE WHEN de.refresh_blocker = 1 THEN 1 ELSE 0 END) AS has_refresh_blocker
    FROM #DependencyEdges AS de
    WHERE de.referencing_view_id = vi.view_object_id
) AS edge_stats
LEFT JOIN #CycleRoots AS cr
    ON cr.view_object_id = vi.view_object_id;

CREATE TABLE #RefreshSummary
(
    summary_bucket           NVARCHAR(40)    NOT NULL,
    view_count               INT             NOT NULL,
    min_refresh_level        INT             NULL,
    max_refresh_level        INT             NULL,
    summary_note             NVARCHAR(260)   NOT NULL
);

INSERT INTO #RefreshSummary
(
    summary_bucket,
    view_count,
    min_refresh_level,
    max_refresh_level,
    summary_note
)
SELECT
    rp.readiness AS summary_bucket,
    COUNT(*) AS view_count,
    MIN(rp.refresh_level) AS min_refresh_level,
    MAX(rp.refresh_level) AS max_refresh_level,
    CASE
        WHEN rp.readiness = 'ready' THEN 'Views koennen in aufsteigender Refresh-Stufe abgearbeitet werden.'
        ELSE 'Views benoetigen vor dem Refresh eine manuelle Pruefung wegen Zyklen oder Blocker-Referenzen.'
    END AS summary_note
FROM #RefreshPlan AS rp
GROUP BY rp.readiness;

CREATE TABLE #RefreshCommands
(
    refresh_level                INT             NOT NULL,
    full_view_name               NVARCHAR(517)   NOT NULL,
    refresh_command_type         NVARCHAR(40)    NOT NULL,
    recommended_refresh_command  NVARCHAR(700)   NOT NULL,
    command_note                 NVARCHAR(260)   NOT NULL
);

INSERT INTO #RefreshCommands
(
    refresh_level,
    full_view_name,
    refresh_command_type,
    recommended_refresh_command,
    command_note
)
SELECT
    rp.refresh_level,
    rp.full_view_name,
    rp.refresh_command_type,
    rp.recommended_refresh_command,
    rp.recommendation
FROM #RefreshPlan AS rp;

SELECT
    rp.refresh_level AS RefreshLevel,
    rp.full_view_name AS ViewName,
    rp.refresh_command_type AS RefreshCommandType,
    rp.nested_view_count AS NestedViewCount,
    rp.max_dependency_depth AS MaxDependencyDepth,
    rp.has_cycle AS HasCycle,
    rp.has_refresh_blocker AS HasRefreshBlocker,
    rp.readiness AS Readiness,
    rp.recommendation AS Recommendation,
    rp.recommended_refresh_command AS RecommendedRefreshCommand
FROM #RefreshPlan AS rp
ORDER BY
    rp.refresh_level,
    rp.has_refresh_blocker,
    rp.full_view_name;

SELECT
    de.referencing_view_name AS ReferencingView,
    de.referenced_view_name AS ReferencedObject,
    de.dependency_kind AS DependencyKind,
    de.dependency_scope AS DependencyScope,
    de.refresh_blocker AS RefreshBlocker,
    de.blocker_reason AS BlockerReason
FROM #DependencyEdges AS de
ORDER BY
    de.referencing_view_name,
    CASE de.dependency_kind
        WHEN 'view' THEN 1
        WHEN 'unresolved' THEN 2
        ELSE 3
    END,
    de.referenced_view_name;

SELECT
    rs.summary_bucket AS SummaryBucket,
    rs.view_count AS ViewCount,
    rs.min_refresh_level AS MinRefreshLevel,
    rs.max_refresh_level AS MaxRefreshLevel,
    rs.summary_note AS SummaryNote
FROM #RefreshSummary AS rs
ORDER BY
    CASE rs.summary_bucket
        WHEN 'ready' THEN 1
        ELSE 2
    END;

IF @IncludeCommands = 1
BEGIN
    SELECT
        rc.refresh_level AS RefreshLevel,
        rc.full_view_name AS ViewName,
        rc.refresh_command_type AS RefreshCommandType,
        rc.command_note AS CommandNote,
        rc.recommended_refresh_command AS RecommendedRefreshCommand
    FROM #RefreshCommands AS rc
    ORDER BY
        rc.refresh_level,
        rc.full_view_name;
END;
