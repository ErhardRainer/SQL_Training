/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "FunctionRefactorCandidateList.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "24_UserDefinedFunctions"

purpose: >
  Listet User-Defined Functions auf, die anhand von Metadaten,
  Abhaengigkeiten und Definitionsmustern als moegliche
  Refactoring-Kandidaten priorisiert werden koennen.

parameters:
  - name: "@FunctionSchema"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Optionales Schema zur Eingrenzung der untersuchten Funktionen"
  - name: "@MinimumRefactorScore"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Untergrenze fuer die Ausgabe im Kandidaten-Resultset"
  - name: "@OnlyCandidates"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = nur Funktionen mit Einstufung review oder priority ausgeben"

result_sets:
  - name: "FunctionRefactorCandidates"
    description: "Priorisierte Detailsicht je Funktion mit Refactoring-Signalen, Score und Empfehlung"
  - name: "FunctionRefactorSummary"
    description: "Zusammenfassung je Refactoring-Einstufung mit Signal- und Funktionsanzahl"

dependencies:
  - "sys.objects"
  - "sys.schemas"
  - "sys.sql_modules"
  - "sys.sql_expression_dependencies"
  - "OBJECTPROPERTYEX"
  - "STRING_AGG"
  - "UPPER"
  - "LIKE"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/24_UserDefinedFunctions/SQLScripts/FunctionRefactorCandidateList.md"
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
    description: "Erstversion des Diagnose-Skripts fuer Refactoring-Kandidaten bei Funktionen"

notes:
  - "Die Priorisierung ist eine didaktische Heuristik fuer Review und Backlog-Bildung, keine automatische Umbauentscheidung."
  - "Score und Empfehlung kombinieren Funktionsart, Metadaten, Dependencies und einfache Definitionsmuster."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @FunctionSchema SYSNAME = NULL;
DECLARE @MinimumRefactorScore INT = 3;
DECLARE @OnlyCandidates BIT = 0;

IF @MinimumRefactorScore IS NULL OR @MinimumRefactorScore < 0
BEGIN
    THROW 50000, '@MinimumRefactorScore muss groesser oder gleich 0 sein.', 1;
END;

IF @OnlyCandidates NOT IN (0, 1)
BEGIN
    THROW 50001, '@OnlyCandidates muss 0 oder 1 sein.', 1;
END;

;WITH FunctionCatalog AS
(
    SELECT
        o.object_id AS function_id,
        s.name AS function_schema_name,
        o.name AS function_name,
        o.type AS function_type,
        o.type_desc AS function_type_desc,
        o.create_date,
        o.modify_date,
        sm.definition,
        CAST(OBJECTPROPERTYEX(o.object_id, 'IsDeterministic') AS BIT) AS is_deterministic,
        CAST(OBJECTPROPERTYEX(o.object_id, 'IsPrecise') AS BIT) AS is_precise,
        CAST(OBJECTPROPERTYEX(o.object_id, 'IsSchemaBound') AS BIT) AS is_schema_bound
    FROM sys.objects AS o
    INNER JOIN sys.schemas AS s
        ON s.schema_id = o.schema_id
    LEFT JOIN sys.sql_modules AS sm
        ON sm.object_id = o.object_id
    WHERE o.type IN ('FN', 'IF', 'TF', 'FS', 'FT')
      AND (@FunctionSchema IS NULL OR s.name = @FunctionSchema)
),
DependencySignals AS
(
    SELECT
        fc.function_id,
        COUNT(sed.referencing_id) AS dependency_rows,
        SUM(CASE WHEN ro.type IN ('U', 'V', 'SN') THEN 1 ELSE 0 END) AS data_object_refs,
        SUM(CASE WHEN ro.type IN ('FN', 'IF', 'TF', 'FS', 'FT') THEN 1 ELSE 0 END) AS function_refs,
        SUM(CASE WHEN sed.referenced_database_name IS NOT NULL THEN 1 ELSE 0 END) AS cross_database_refs,
        SUM(CASE WHEN sed.referenced_server_name IS NOT NULL THEN 1 ELSE 0 END) AS cross_server_refs,
        SUM(CASE WHEN sed.referenced_id IS NULL
                  AND sed.referenced_entity_name IS NOT NULL THEN 1 ELSE 0 END) AS unresolved_refs,
        SUM(CASE WHEN sed.is_ambiguous = 1 THEN 1 ELSE 0 END) AS ambiguous_refs,
        SUM(CASE WHEN sed.is_schema_bound_reference = 1 THEN 1 ELSE 0 END) AS schema_bound_refs,
        STRING_AGG(
            COALESCE(
                rs.name + N'.' + ro.name,
                sed.referenced_schema_name + N'.' + sed.referenced_entity_name,
                sed.referenced_entity_name,
                N'(unresolved)'
            ),
            N', '
        ) WITHIN GROUP
        (
            ORDER BY COALESCE(
                rs.name + N'.' + ro.name,
                sed.referenced_schema_name + N'.' + sed.referenced_entity_name,
                sed.referenced_entity_name,
                N'(unresolved)'
            )
        ) AS dependency_sample
    FROM FunctionCatalog AS fc
    LEFT JOIN sys.sql_expression_dependencies AS sed
        ON sed.referencing_id = fc.function_id
    LEFT JOIN sys.objects AS ro
        ON ro.object_id = sed.referenced_id
    LEFT JOIN sys.schemas AS rs
        ON rs.schema_id = ro.schema_id
    GROUP BY
        fc.function_id
),
DefinitionSignals AS
(
    SELECT
        fc.function_id,
        CAST(CASE WHEN fc.definition IS NOT NULL AND UPPER(fc.definition) LIKE '%CURSOR%'
                    THEN 1 ELSE 0 END AS BIT) AS mentions_cursor,
        CAST(CASE WHEN fc.definition IS NOT NULL AND UPPER(fc.definition) LIKE '%WHILE %'
                    THEN 1 ELSE 0 END AS BIT) AS mentions_while_loop,
        CAST(CASE WHEN fc.definition IS NOT NULL AND UPPER(fc.definition) LIKE '%JOIN%'
                    THEN 1 ELSE 0 END AS BIT) AS mentions_join,
        CAST(CASE WHEN fc.definition IS NOT NULL
                    AND (
                        UPPER(fc.definition) LIKE '%GETDATE(%'
                        OR UPPER(fc.definition) LIKE '%SYSDATETIME(%'
                        OR UPPER(fc.definition) LIKE '%NEWID(%'
                        OR UPPER(fc.definition) LIKE '%RAND(%'
                    )
                  THEN 1 ELSE 0 END AS BIT) AS mentions_nondeterministic_builtin,
        CAST(CASE WHEN fc.definition IS NOT NULL
                    AND (
                        UPPER(fc.definition) LIKE '%CROSS APPLY%'
                        OR UPPER(fc.definition) LIKE '%OUTER APPLY%'
                    )
                  THEN 1 ELSE 0 END AS BIT) AS mentions_apply,
        CAST(CASE WHEN fc.definition IS NOT NULL
                    AND LEN(REPLACE(REPLACE(fc.definition, CHAR(13), ''), CHAR(10), '')) > 1200
                  THEN 1 ELSE 0 END AS BIT) AS long_definition_flag
    FROM FunctionCatalog AS fc
),
Audit AS
(
    SELECT
        fc.function_schema_name,
        fc.function_name,
        fc.function_type,
        fc.function_type_desc,
        fc.create_date,
        fc.modify_date,
        fc.is_deterministic,
        fc.is_precise,
        fc.is_schema_bound,
        COALESCE(ds.dependency_rows, 0) AS dependency_rows,
        COALESCE(ds.data_object_refs, 0) AS data_object_refs,
        COALESCE(ds.function_refs, 0) AS function_refs,
        COALESCE(ds.cross_database_refs, 0) AS cross_database_refs,
        COALESCE(ds.cross_server_refs, 0) AS cross_server_refs,
        COALESCE(ds.unresolved_refs, 0) AS unresolved_refs,
        COALESCE(ds.ambiguous_refs, 0) AS ambiguous_refs,
        COALESCE(ds.schema_bound_refs, 0) AS schema_bound_refs,
        COALESCE(ds.dependency_sample, '(none)') AS dependency_sample,
        def.mentions_cursor,
        def.mentions_while_loop,
        def.mentions_join,
        def.mentions_nondeterministic_builtin,
        def.mentions_apply,
        def.long_definition_flag,
        CASE
            WHEN fc.function_type = 'FN' THEN 3
            WHEN fc.function_type IN ('FS', 'FT') THEN 2
            ELSE 1
        END
        + CASE WHEN fc.is_schema_bound = 0 THEN 2 ELSE 0 END
        + CASE WHEN fc.is_deterministic = 0 THEN 2 ELSE 0 END
        + CASE WHEN fc.is_precise = 0 THEN 1 ELSE 0 END
        + CASE WHEN COALESCE(ds.data_object_refs, 0) >= 2 THEN 2
               WHEN COALESCE(ds.data_object_refs, 0) = 1 THEN 1
               ELSE 0 END
        + CASE WHEN COALESCE(ds.function_refs, 0) >= 2 THEN 2
               WHEN COALESCE(ds.function_refs, 0) = 1 THEN 1
               ELSE 0 END
        + CASE WHEN COALESCE(ds.cross_database_refs, 0) > 0 THEN 2 ELSE 0 END
        + CASE WHEN COALESCE(ds.cross_server_refs, 0) > 0 THEN 3 ELSE 0 END
        + CASE WHEN COALESCE(ds.unresolved_refs, 0) > 0 THEN 2 ELSE 0 END
        + CASE WHEN COALESCE(ds.ambiguous_refs, 0) > 0 THEN 1 ELSE 0 END
        + CASE WHEN def.mentions_cursor = 1 THEN 2 ELSE 0 END
        + CASE WHEN def.mentions_while_loop = 1 THEN 2 ELSE 0 END
        + CASE WHEN def.mentions_join = 1 THEN 1 ELSE 0 END
        + CASE WHEN def.mentions_apply = 1 THEN 1 ELSE 0 END
        + CASE WHEN def.mentions_nondeterministic_builtin = 1 THEN 2 ELSE 0 END
        + CASE WHEN def.long_definition_flag = 1 THEN 1 ELSE 0 END AS refactor_score
    FROM FunctionCatalog AS fc
    LEFT JOIN DependencySignals AS ds
        ON ds.function_id = fc.function_id
    INNER JOIN DefinitionSignals AS def
        ON def.function_id = fc.function_id
),
RankedCandidates AS
(
    SELECT
        a.function_schema_name,
        a.function_name,
        a.function_type,
        a.function_type_desc,
        a.create_date,
        a.modify_date,
        a.is_deterministic,
        a.is_precise,
        a.is_schema_bound,
        a.dependency_rows,
        a.data_object_refs,
        a.function_refs,
        a.cross_database_refs,
        a.cross_server_refs,
        a.unresolved_refs,
        a.ambiguous_refs,
        a.schema_bound_refs,
        a.mentions_cursor,
        a.mentions_while_loop,
        a.mentions_join,
        a.mentions_apply,
        a.mentions_nondeterministic_builtin,
        a.long_definition_flag,
        a.dependency_sample,
        a.refactor_score,
        CASE
            WHEN a.refactor_score >= 10 THEN 'priority'
            WHEN a.refactor_score >= 6 THEN 'review'
            ELSE 'baseline'
        END AS refactor_band,
        CONCAT(
            CASE WHEN a.function_type = 'FN' THEN 'Scalar function. ' ELSE '' END,
            CASE WHEN a.is_schema_bound = 0 THEN 'No SCHEMABINDING. ' ELSE '' END,
            CASE WHEN a.is_deterministic = 0 THEN 'Marked as non-deterministic. ' ELSE '' END,
            CASE WHEN a.is_precise = 0 THEN 'Marked as imprecise. ' ELSE '' END,
            CASE WHEN a.data_object_refs > 0 THEN 'References data objects. ' ELSE '' END,
            CASE WHEN a.function_refs > 0 THEN 'Calls other functions. ' ELSE '' END,
            CASE WHEN a.cross_database_refs > 0 THEN 'Cross-database reference. ' ELSE '' END,
            CASE WHEN a.cross_server_refs > 0 THEN 'Cross-server reference. ' ELSE '' END,
            CASE WHEN a.unresolved_refs > 0 THEN 'Contains unresolved dependencies. ' ELSE '' END,
            CASE WHEN a.ambiguous_refs > 0 THEN 'Contains ambiguous dependencies. ' ELSE '' END,
            CASE WHEN a.mentions_cursor = 1 THEN 'Definition mentions CURSOR. ' ELSE '' END,
            CASE WHEN a.mentions_while_loop = 1 THEN 'Definition mentions WHILE. ' ELSE '' END,
            CASE WHEN a.mentions_apply = 1 THEN 'Definition mentions APPLY. ' ELSE '' END,
            CASE WHEN a.mentions_nondeterministic_builtin = 1 THEN 'Definition mentions non-deterministic built-ins. ' ELSE '' END,
            CASE WHEN a.long_definition_flag = 1 THEN 'Definition length exceeds heuristic threshold. ' ELSE '' END
        ) AS recommendation_notes
    FROM Audit AS a
)
SELECT
    rc.function_schema_name AS FunctionSchema,
    rc.function_name AS FunctionName,
    rc.function_type AS FunctionType,
    rc.function_type_desc AS FunctionTypeDescription,
    rc.refactor_score AS RefactorScore,
    rc.refactor_band AS RefactorBand,
    rc.is_schema_bound AS IsSchemaBound,
    rc.is_deterministic AS IsDeterministic,
    rc.is_precise AS IsPrecise,
    rc.dependency_rows AS DependencyRows,
    rc.data_object_refs AS DataObjectRefs,
    rc.function_refs AS FunctionRefs,
    rc.cross_database_refs AS CrossDatabaseRefs,
    rc.cross_server_refs AS CrossServerRefs,
    rc.unresolved_refs AS UnresolvedRefs,
    rc.ambiguous_refs AS AmbiguousRefs,
    rc.schema_bound_refs AS SchemaBoundRefs,
    rc.mentions_cursor AS MentionsCursor,
    rc.mentions_while_loop AS MentionsWhileLoop,
    rc.mentions_join AS MentionsJoin,
    rc.mentions_apply AS MentionsApply,
    rc.mentions_nondeterministic_builtin AS MentionsNondeterministicBuiltin,
    rc.long_definition_flag AS LongDefinitionFlag,
    NULLIF(rc.recommendation_notes, '') AS RecommendationNotes,
    rc.dependency_sample AS DependencySample,
    rc.create_date AS CreateDate,
    rc.modify_date AS ModifyDate
FROM RankedCandidates AS rc
WHERE rc.refactor_score >= @MinimumRefactorScore
  AND (
        @OnlyCandidates = 0
        OR rc.refactor_band IN ('review', 'priority')
      )
ORDER BY
    rc.refactor_score DESC,
    rc.data_object_refs DESC,
    rc.function_refs DESC,
    rc.function_schema_name,
    rc.function_name;

SELECT
    rc.refactor_band AS RefactorBand,
    COUNT(*) AS FunctionCount,
    AVG(CAST(rc.refactor_score AS DECIMAL(10, 2))) AS AverageRefactorScore,
    MAX(rc.refactor_score) AS MaxRefactorScore,
    SUM(CASE WHEN rc.function_type = 'FN' THEN 1 ELSE 0 END) AS ScalarFunctionCount,
    SUM(CASE WHEN rc.is_schema_bound = 0 THEN 1 ELSE 0 END) AS NoSchemaBindingCount,
    SUM(CASE WHEN rc.data_object_refs > 0 THEN 1 ELSE 0 END) AS DataAccessCount,
    SUM(CASE WHEN rc.unresolved_refs > 0 THEN 1 ELSE 0 END) AS UnresolvedDependencyCount
FROM RankedCandidates AS rc
WHERE rc.refactor_score >= @MinimumRefactorScore
  AND (
        @OnlyCandidates = 0
        OR rc.refactor_band IN ('review', 'priority')
      )
GROUP BY
    rc.refactor_band
ORDER BY
    CASE rc.refactor_band
        WHEN 'priority' THEN 1
        WHEN 'review' THEN 2
        ELSE 3
    END;
