/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "FunctionDataAccessHeatmap.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "24_UserDefinedFunctions"

purpose: >
  Erstellt eine Heatmap fuer Datenzugriffe aus User-Defined Functions,
  indem lokale Dependencies, referenzierte Objektarten und heuristische
  Definition-Signale zu gewichteten Zugriffskategorien verdichtet werden.

parameters:
  - name: "@FunctionSchema"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Optionales Schema zur Eingrenzung der untersuchten Funktionen"
  - name: "@OnlyHotspots"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = nur Funktionen und Kategorien mit auffaelligen Zugriffssignalen ausgeben"
  - name: "@MinimumHeatScore"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Untergrenze fuer Heatmap-Zeilen im Summary-Resultset"

result_sets:
  - name: "FunctionDataAccessDetail"
    description: "Detailansicht je Funktion mit Zugriffssignalen, Referenzarten und Hotspot-Einstufung"
  - name: "FunctionDataAccessHeatmap"
    description: "Gewichtete Heatmap je Funktionsschema und Zugriffskategorie"
  - name: "FunctionDataAccessSchemaSummary"
    description: "Verdichtete Hotspot-Sicht je Funktionsschema"

dependencies:
  - "sys.objects"
  - "sys.schemas"
  - "sys.sql_modules"
  - "sys.sql_expression_dependencies"
  - "STRING_AGG"
  - "UPPER"
  - "LIKE"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/24_UserDefinedFunctions/SQLScripts/FunctionDataAccessHeatmap.md"
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
    description: "Erstversion des Diagnose-Skripts fuer eine Heatmap von Datenzugriffen aus Funktionen"

notes:
  - "Die Heatmap kombiniert aufgeloeste Katalog-Dependencies mit Textmustern in sys.sql_modules.definition"
  - "Gewichte sind didaktische Heuristiken fuer Review-Priorisierung und keine vollstaendige semantische Analyse"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @FunctionSchema SYSNAME = NULL;
DECLARE @OnlyHotspots BIT = 0;
DECLARE @MinimumHeatScore INT = 1;

IF @OnlyHotspots NOT IN (0, 1)
BEGIN
    THROW 50000, '@OnlyHotspots muss 0 oder 1 sein.', 1;
END;

IF @MinimumHeatScore IS NULL OR @MinimumHeatScore < 1
BEGIN
    THROW 50001, '@MinimumHeatScore muss groesser oder gleich 1 sein.', 1;
END;

;WITH FunctionCatalog AS
(
    SELECT
        o.object_id AS function_id,
        s.name AS function_schema_name,
        o.name AS function_name,
        o.type AS function_type,
        o.type_desc AS function_type_desc,
        sm.definition,
        o.create_date,
        o.modify_date
    FROM sys.objects AS o
    INNER JOIN sys.schemas AS s
        ON s.schema_id = o.schema_id
    LEFT JOIN sys.sql_modules AS sm
        ON sm.object_id = o.object_id
    WHERE o.type IN ('FN', 'IF', 'TF', 'FS', 'FT')
      AND (@FunctionSchema IS NULL OR s.name = @FunctionSchema)
),
DependencyBase AS
(
    SELECT
        fc.function_id,
        fc.function_schema_name,
        fc.function_name,
        fc.function_type,
        fc.function_type_desc,
        fc.definition,
        fc.create_date,
        fc.modify_date,
        sed.referenced_id,
        sed.referenced_schema_name,
        sed.referenced_entity_name,
        sed.referenced_database_name,
        sed.referenced_server_name,
        sed.is_ambiguous,
        sed.is_schema_bound_reference
    FROM FunctionCatalog AS fc
    LEFT JOIN sys.sql_expression_dependencies AS sed
        ON sed.referencing_id = fc.function_id
),
DependencyResolved AS
(
    SELECT
        db.function_id,
        db.function_schema_name,
        db.function_name,
        db.function_type,
        db.function_type_desc,
        db.definition,
        db.create_date,
        db.modify_date,
        db.referenced_schema_name,
        db.referenced_entity_name,
        db.referenced_database_name,
        db.referenced_server_name,
        db.is_ambiguous,
        db.is_schema_bound_reference,
        ro.object_id AS referenced_object_id,
        ro.type AS referenced_object_type,
        ro.type_desc AS referenced_object_type_desc,
        rs.name AS referenced_object_schema_name
    FROM DependencyBase AS db
    LEFT JOIN sys.objects AS ro
        ON ro.object_id = db.referenced_id
    LEFT JOIN sys.schemas AS rs
        ON rs.schema_id = ro.schema_id
),
AccessSignals AS
(
    SELECT
        dr.function_id,
        dr.function_schema_name,
        dr.function_name,
        dr.function_type,
        dr.function_type_desc,
        dr.definition,
        dr.create_date,
        dr.modify_date,
        COUNT_BIG(*) AS dependency_rows,
        SUM(CASE WHEN dr.referenced_object_type = 'U' THEN 1 ELSE 0 END) AS user_table_refs,
        SUM(CASE WHEN dr.referenced_object_type = 'V' THEN 1 ELSE 0 END) AS view_refs,
        SUM(CASE WHEN dr.referenced_object_type IN ('FN', 'IF', 'TF', 'FS', 'FT') THEN 1 ELSE 0 END) AS function_refs,
        SUM(CASE WHEN dr.referenced_object_type = 'SN' THEN 1 ELSE 0 END) AS synonym_refs,
        SUM(CASE WHEN dr.referenced_database_name IS NOT NULL THEN 1 ELSE 0 END) AS cross_database_refs,
        SUM(CASE WHEN dr.referenced_server_name IS NOT NULL THEN 1 ELSE 0 END) AS cross_server_refs,
        SUM(CASE WHEN dr.referenced_object_id IS NULL
                  AND dr.referenced_entity_name IS NOT NULL THEN 1 ELSE 0 END) AS unresolved_refs,
        SUM(CASE WHEN dr.is_ambiguous = 1 THEN 1 ELSE 0 END) AS ambiguous_refs,
        SUM(CASE WHEN dr.is_schema_bound_reference = 1 THEN 1 ELSE 0 END) AS schema_bound_refs,
        STRING_AGG(
            COALESCE(
                dr.referenced_object_schema_name,
                dr.referenced_schema_name,
                N'(unresolved)'
            ),
            N', '
        ) WITHIN GROUP
        (
            ORDER BY COALESCE(
                dr.referenced_object_schema_name,
                dr.referenced_schema_name,
                N'(unresolved)'
            )
        ) AS referenced_schema_list
    FROM DependencyResolved AS dr
    GROUP BY
        dr.function_id,
        dr.function_schema_name,
        dr.function_name,
        dr.function_type,
        dr.function_type_desc,
        dr.definition,
        dr.create_date,
        dr.modify_date
),
DefinitionHeuristics AS
(
    SELECT
        fc.function_id,
        CAST(CASE WHEN fc.definition IS NOT NULL AND UPPER(fc.definition) LIKE '% FROM %'
                    THEN 1 ELSE 0 END AS BIT) AS mentions_from_clause,
        CAST(CASE WHEN fc.definition IS NOT NULL AND UPPER(fc.definition) LIKE '% JOIN %'
                    THEN 1 ELSE 0 END AS BIT) AS mentions_join_clause,
        CAST(CASE WHEN fc.definition IS NOT NULL AND UPPER(fc.definition) LIKE '%APPLY%'
                    THEN 1 ELSE 0 END AS BIT) AS mentions_apply_clause,
        CAST(CASE WHEN fc.definition IS NOT NULL
                    AND (
                        UPPER(fc.definition) LIKE '%OPENQUERY(%'
                        OR UPPER(fc.definition) LIKE '%OPENROWSET(%'
                        OR UPPER(fc.definition) LIKE '%OPENDATASOURCE(%'
                    )
                  THEN 1 ELSE 0 END AS BIT) AS mentions_external_access,
        CAST(CASE WHEN fc.definition IS NOT NULL
                    AND (
                        UPPER(fc.definition) LIKE '%SYS.%'
                        OR UPPER(fc.definition) LIKE '%INFORMATION_SCHEMA.%'
                    )
                  THEN 1 ELSE 0 END AS BIT) AS mentions_metadata_access
    FROM FunctionCatalog AS fc
),
FunctionAudit AS
(
    SELECT
        a.function_schema_name,
        a.function_name,
        a.function_type,
        a.function_type_desc,
        a.create_date,
        a.modify_date,
        a.dependency_rows,
        a.user_table_refs,
        a.view_refs,
        a.function_refs,
        a.synonym_refs,
        a.cross_database_refs,
        a.cross_server_refs,
        a.unresolved_refs,
        a.ambiguous_refs,
        a.schema_bound_refs,
        dh.mentions_from_clause,
        dh.mentions_join_clause,
        dh.mentions_apply_clause,
        dh.mentions_external_access,
        dh.mentions_metadata_access,
        COALESCE(a.referenced_schema_list, '(none)') AS referenced_schema_list,
        (a.user_table_refs * 4)
        + (a.view_refs * 3)
        + (a.function_refs * 2)
        + (a.synonym_refs * 3)
        + (a.cross_database_refs * 5)
        + (a.cross_server_refs * 6)
        + (a.unresolved_refs * 3)
        + (a.ambiguous_refs * 2)
        + (CASE WHEN dh.mentions_join_clause = 1 THEN 2 ELSE 0 END)
        + (CASE WHEN dh.mentions_apply_clause = 1 THEN 2 ELSE 0 END)
        + (CASE WHEN dh.mentions_external_access = 1 THEN 4 ELSE 0 END)
        + (CASE WHEN dh.mentions_metadata_access = 1 THEN 1 ELSE 0 END) AS total_heat_score,
        CASE
            WHEN (a.cross_server_refs > 0 OR a.cross_database_refs > 0 OR dh.mentions_external_access = 1)
                THEN 'hotspot'
            WHEN (a.user_table_refs + a.view_refs + a.unresolved_refs) >= 3
                THEN 'review'
            ELSE 'baseline'
        END AS hotspot_level
    FROM AccessSignals AS a
    INNER JOIN DefinitionHeuristics AS dh
        ON dh.function_id = a.function_id
),
HeatmapRows AS
(
    SELECT
        fa.function_schema_name,
        fa.function_name,
        fa.hotspot_level,
        v.access_category,
        v.signal_count,
        v.heat_weight
    FROM FunctionAudit AS fa
    CROSS APPLY
    (
        VALUES
            ('user_table', fa.user_table_refs, fa.user_table_refs * 4),
            ('view', fa.view_refs, fa.view_refs * 3),
            ('function', fa.function_refs, fa.function_refs * 2),
            ('synonym', fa.synonym_refs, fa.synonym_refs * 3),
            ('cross_database', fa.cross_database_refs, fa.cross_database_refs * 5),
            ('cross_server', fa.cross_server_refs, fa.cross_server_refs * 6),
            ('unresolved_reference', fa.unresolved_refs, fa.unresolved_refs * 3),
            ('ambiguous_reference', fa.ambiguous_refs, fa.ambiguous_refs * 2),
            ('join_pattern', CASE WHEN fa.mentions_join_clause = 1 THEN 1 ELSE 0 END, CASE WHEN fa.mentions_join_clause = 1 THEN 2 ELSE 0 END),
            ('apply_pattern', CASE WHEN fa.mentions_apply_clause = 1 THEN 1 ELSE 0 END, CASE WHEN fa.mentions_apply_clause = 1 THEN 2 ELSE 0 END),
            ('external_pattern', CASE WHEN fa.mentions_external_access = 1 THEN 1 ELSE 0 END, CASE WHEN fa.mentions_external_access = 1 THEN 4 ELSE 0 END),
            ('metadata_pattern', CASE WHEN fa.mentions_metadata_access = 1 THEN 1 ELSE 0 END, CASE WHEN fa.mentions_metadata_access = 1 THEN 1 ELSE 0 END)
    ) AS v(access_category, signal_count, heat_weight)
    WHERE v.signal_count > 0
)
SELECT
    fa.function_schema_name AS FunctionSchema,
    fa.function_name AS FunctionName,
    fa.function_type AS FunctionType,
    fa.function_type_desc AS FunctionTypeDescription,
    fa.user_table_refs AS UserTableRefs,
    fa.view_refs AS ViewRefs,
    fa.function_refs AS FunctionRefs,
    fa.synonym_refs AS SynonymRefs,
    fa.cross_database_refs AS CrossDatabaseRefs,
    fa.cross_server_refs AS CrossServerRefs,
    fa.unresolved_refs AS UnresolvedRefs,
    fa.ambiguous_refs AS AmbiguousRefs,
    fa.schema_bound_refs AS SchemaBoundRefs,
    fa.mentions_from_clause AS MentionsFromClause,
    fa.mentions_join_clause AS MentionsJoinClause,
    fa.mentions_apply_clause AS MentionsApplyClause,
    fa.mentions_external_access AS MentionsExternalAccess,
    fa.mentions_metadata_access AS MentionsMetadataAccess,
    fa.total_heat_score AS TotalHeatScore,
    fa.hotspot_level AS HotspotLevel,
    fa.referenced_schema_list AS ReferencedSchemas,
    fa.create_date AS CreateDate,
    fa.modify_date AS ModifyDate
FROM FunctionAudit AS fa
WHERE @OnlyHotspots = 0
   OR fa.hotspot_level <> 'baseline'
ORDER BY
    fa.total_heat_score DESC,
    fa.function_schema_name,
    fa.function_name;

SELECT
    hr.function_schema_name AS FunctionSchema,
    hr.access_category AS AccessCategory,
    COUNT(*) AS FunctionsWithSignal,
    SUM(hr.signal_count) AS SignalCount,
    SUM(hr.heat_weight) AS HeatScore,
    SUM(CASE WHEN hr.hotspot_level = 'hotspot' THEN 1 ELSE 0 END) AS HotspotFunctions,
    SUM(CASE WHEN hr.hotspot_level = 'review' THEN 1 ELSE 0 END) AS ReviewFunctions
FROM HeatmapRows AS hr
GROUP BY
    hr.function_schema_name,
    hr.access_category
HAVING SUM(hr.heat_weight) >= @MinimumHeatScore
ORDER BY
    HeatScore DESC,
    hr.function_schema_name,
    hr.access_category;

SELECT
    fa.function_schema_name AS FunctionSchema,
    COUNT(*) AS FunctionCount,
    SUM(fa.total_heat_score) AS SchemaHeatScore,
    SUM(CASE WHEN fa.hotspot_level = 'hotspot' THEN 1 ELSE 0 END) AS HotspotCount,
    SUM(CASE WHEN fa.hotspot_level = 'review' THEN 1 ELSE 0 END) AS ReviewCount,
    SUM(CASE WHEN fa.hotspot_level = 'baseline' THEN 1 ELSE 0 END) AS BaselineCount,
    SUM(fa.user_table_refs + fa.view_refs) AS LocalDataObjectRefs,
    SUM(fa.cross_database_refs + fa.cross_server_refs) AS ExternalRefs,
    SUM(fa.unresolved_refs) AS UnresolvedRefs
FROM FunctionAudit AS fa
WHERE @OnlyHotspots = 0
   OR fa.hotspot_level <> 'baseline'
GROUP BY
    fa.function_schema_name
ORDER BY
    SchemaHeatScore DESC,
    fa.function_schema_name;
