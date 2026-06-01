/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "FunctionSchemaBindingReadiness.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "24_UserDefinedFunctions"

purpose: >
  Bewertet User-Defined Functions mit einem nachvollziehbaren
  Readiness-Score fuer die Vorbereitung auf SCHEMABINDING und
  priorisiert konkrete Nacharbeiten fuer ein manuelles Review.

parameters:
  - name: "@SchemaFilter"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Optionales Schema zur Eingrenzung der analysierten Funktionen"
  - name: "@MinimumReadinessScore"
    sql_type: "TINYINT"
    direction: "IN"
    required: false
    description: "Optionaler Mindestscore zwischen 0 und 100 fuer die Detailausgabe"
  - name: "@IncludeDefinitionSnippet"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = gekuerzten Definitionsausschnitt im Detailresultset anzeigen"

result_sets:
  - name: "FunctionSchemaBindingReadiness"
    description: "Detailansicht je Funktion mit Readiness-Score, Status und empfohlenen Nacharbeiten"
  - name: "ReadinessSummary"
    description: "Aggregierte Anzahl der Funktionen je Readiness-Status"

dependencies:
  - "sys.objects"
  - "sys.schemas"
  - "sys.sql_modules"
  - "sys.sql_expression_dependencies"
  - "OBJECTPROPERTYEX"
  - "UPPER"
  - "LIKE"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/24_UserDefinedFunctions/SQLScripts/FunctionSchemaBindingReadiness.md"
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
    description: "Erstversion des Diagnose-Skripts fuer SCHEMABINDING-Readiness bei Funktionen"

notes:
  - "Der Readiness-Score ist eine konservative Heuristik und ersetzt kein manuelles Review"
  - "Blocker und Nacharbeiten werden aus Metadaten, Abhaengigkeiten und Definitionsmustern abgeleitet"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @SchemaFilter SYSNAME = NULL;
DECLARE @MinimumReadinessScore TINYINT = 0;
DECLARE @IncludeDefinitionSnippet BIT = 1;

IF @MinimumReadinessScore NOT BETWEEN 0 AND 100
BEGIN
    THROW 50000, '@MinimumReadinessScore muss zwischen 0 und 100 liegen.', 1;
END;

IF @IncludeDefinitionSnippet NOT IN (0, 1)
BEGIN
    THROW 50001, '@IncludeDefinitionSnippet muss 0 oder 1 sein.', 1;
END;

;WITH FunctionCatalog AS
(
    SELECT
        o.object_id,
        s.name AS schema_name,
        o.name AS function_name,
        o.type AS function_type,
        o.type_desc AS function_type_desc,
        o.create_date,
        o.modify_date,
        sm.definition,
        sm.is_schema_bound,
        sm.uses_ansi_nulls,
        sm.uses_quoted_identifier,
        CAST(OBJECTPROPERTYEX(o.object_id, 'IsDeterministic') AS BIT) AS is_deterministic,
        CAST(OBJECTPROPERTYEX(o.object_id, 'IsPrecise') AS BIT) AS is_precise
    FROM sys.objects AS o
    INNER JOIN sys.schemas AS s
        ON s.schema_id = o.schema_id
    LEFT JOIN sys.sql_modules AS sm
        ON sm.object_id = o.object_id
    WHERE o.type IN ('FN', 'IF', 'TF', 'FS', 'FT')
      AND (@SchemaFilter IS NULL OR s.name = @SchemaFilter)
),
DependencyScan AS
(
    SELECT
        fc.object_id,
        COUNT(sed.referenced_id) AS dependency_count,
        CAST(MAX(CASE WHEN sed.referenced_server_name IS NOT NULL THEN 1 ELSE 0 END) AS BIT) AS has_cross_server_reference,
        CAST(MAX(CASE WHEN sed.referenced_database_name IS NOT NULL THEN 1 ELSE 0 END) AS BIT) AS has_cross_database_reference,
        CAST(MAX(CASE WHEN sed.is_caller_dependent = 1 THEN 1 ELSE 0 END) AS BIT) AS has_caller_dependent_reference,
        CAST(MAX(CASE WHEN sed.referenced_id IS NULL
                           AND sed.referenced_entity_name IS NOT NULL
                           AND sed.referenced_server_name IS NULL
                           AND sed.referenced_database_name IS NULL
                      THEN 1 ELSE 0 END) AS BIT) AS has_unresolved_local_reference,
        CAST(MAX(CASE WHEN sed.referenced_class_desc = 'OBJECT_OR_COLUMN' THEN 1 ELSE 0 END) AS BIT) AS has_object_reference
    FROM FunctionCatalog AS fc
    LEFT JOIN sys.sql_expression_dependencies AS sed
        ON sed.referencing_id = fc.object_id
    GROUP BY
        fc.object_id
),
DefinitionSignals AS
(
    SELECT
        fc.object_id,
        CAST(CASE WHEN fc.definition IS NOT NULL AND UPPER(fc.definition) LIKE '%SELECT *%' THEN 1 ELSE 0 END AS BIT) AS uses_select_star,
        CAST(CASE WHEN fc.definition IS NOT NULL AND (UPPER(fc.definition) LIKE '%GETDATE(%'
                                                      OR UPPER(fc.definition) LIKE '%SYSDATETIME(%'
                                                      OR UPPER(fc.definition) LIKE '%SYSUTCDATETIME(%'
                                                      OR UPPER(fc.definition) LIKE '%CURRENT_TIMESTAMP%'
                                                      OR UPPER(fc.definition) LIKE '%NEWID(%'
                                                      OR UPPER(fc.definition) LIKE '%RAND(%')
                  THEN 1 ELSE 0 END AS BIT) AS uses_nondeterministic_function,
        CAST(CASE WHEN fc.definition IS NOT NULL AND (UPPER(fc.definition) LIKE '%OPENQUERY(%'
                                                      OR UPPER(fc.definition) LIKE '%OPENROWSET(%'
                                                      OR UPPER(fc.definition) LIKE '%OPENDATASOURCE(%')
                  THEN 1 ELSE 0 END AS BIT) AS uses_external_access,
        CAST(CASE WHEN fc.definition IS NOT NULL AND (UPPER(fc.definition) LIKE '%EXEC %'
                                                      OR UPPER(fc.definition) LIKE '%SP_EXECUTESQL%')
                  THEN 1 ELSE 0 END AS BIT) AS uses_dynamic_execution,
        CAST(CASE WHEN fc.definition IS NOT NULL AND (UPPER(fc.definition) LIKE '%#%'
                                                      OR UPPER(fc.definition) LIKE '%TEMPDB%')
                  THEN 1 ELSE 0 END AS BIT) AS mentions_temp_objects
    FROM FunctionCatalog AS fc
),
Assessment AS
(
    SELECT
        fc.schema_name,
        fc.function_name,
        fc.function_type,
        fc.function_type_desc,
        fc.is_schema_bound,
        fc.uses_ansi_nulls,
        fc.uses_quoted_identifier,
        fc.is_deterministic,
        fc.is_precise,
        ds.dependency_count,
        ds.has_cross_server_reference,
        ds.has_cross_database_reference,
        ds.has_caller_dependent_reference,
        ds.has_unresolved_local_reference,
        ds.has_object_reference,
        def.uses_select_star,
        def.uses_nondeterministic_function,
        def.uses_external_access,
        def.uses_dynamic_execution,
        def.mentions_temp_objects,
        CASE
            WHEN fc.is_schema_bound = 1 THEN 100
            ELSE
                100
                - CASE WHEN fc.uses_ansi_nulls = 1 THEN 0 ELSE 15 END
                - CASE WHEN fc.uses_quoted_identifier = 1 THEN 0 ELSE 15 END
                - CASE WHEN ds.has_object_reference = 1 THEN 0 ELSE 10 END
                - CASE WHEN ds.has_cross_server_reference = 1 THEN 35 ELSE 0 END
                - CASE WHEN ds.has_cross_database_reference = 1 THEN 30 ELSE 0 END
                - CASE WHEN ds.has_caller_dependent_reference = 1 THEN 20 ELSE 0 END
                - CASE WHEN ds.has_unresolved_local_reference = 1 THEN 20 ELSE 0 END
                - CASE WHEN def.uses_select_star = 1 THEN 15 ELSE 0 END
                - CASE WHEN def.uses_nondeterministic_function = 1 THEN 25 ELSE 0 END
                - CASE WHEN def.uses_external_access = 1 THEN 35 ELSE 0 END
                - CASE WHEN def.uses_dynamic_execution = 1 THEN 35 ELSE 0 END
                - CASE WHEN def.mentions_temp_objects = 1 THEN 20 ELSE 0 END
                + CASE WHEN fc.is_deterministic = 1 THEN 10 ELSE 0 END
                + CASE WHEN fc.is_precise = 1 THEN 5 ELSE 0 END
        END AS raw_readiness_score,
        CASE
            WHEN fc.is_schema_bound = 1
                THEN 'already_schema_bound'
            WHEN fc.function_type IN ('FS', 'FT')
                THEN 'manual_review_required'
            WHEN ds.has_cross_server_reference = 1
              OR ds.has_cross_database_reference = 1
              OR def.uses_external_access = 1
              OR def.uses_dynamic_execution = 1
                THEN 'not_ready'
            WHEN ds.has_caller_dependent_reference = 1
              OR ds.has_unresolved_local_reference = 1
              OR def.mentions_temp_objects = 1
              OR def.uses_select_star = 1
              OR def.uses_nondeterministic_function = 1
                THEN 'needs_preparation'
            ELSE 'review_ready'
        END AS readiness_status,
        CASE
            WHEN fc.is_schema_bound = 1
                THEN 'Bereits schema-gebunden; pruefe nur noch Consumer- und Deployment-Folgen.'
            WHEN fc.function_type IN ('FS', 'FT')
                THEN 'CLR- oder externe Funktionen separat pruefen; SCHEMABINDING haengt hier nicht nur von T-SQL-Metadaten ab.'
            WHEN ds.has_cross_server_reference = 1 OR ds.has_cross_database_reference = 1
                THEN 'Referenzen ueber Server- oder Datenbankgrenzen zuerst in lokale, eindeutig aufloesbare Objekte ueberfuehren.'
            WHEN def.uses_external_access = 1 OR def.uses_dynamic_execution = 1
                THEN 'Externe Zugriffe oder dynamische Ausfuehrung entfernen, bevor SCHEMABINDING realistisch ist.'
            WHEN ds.has_caller_dependent_reference = 1 OR ds.has_unresolved_local_reference = 1
                THEN 'Objektnamen explizit qualifizieren und aufloesbare lokale Referenzen herstellen.'
            WHEN def.mentions_temp_objects = 1
                THEN 'Tempdb- oder Temp-Objekte durch stabile Objektbezuege ersetzen.'
            WHEN def.uses_select_star = 1
                THEN 'Wildcard-Projektionen in explizite Spaltenlisten ueberfuehren.'
            WHEN def.uses_nondeterministic_function = 1
                THEN 'Nicht deterministische Built-ins entfernen oder isolieren.'
            WHEN fc.uses_ansi_nulls = 0 OR fc.uses_quoted_identifier = 0
                THEN 'Moduloptionen fuer ANSI_NULLS und QUOTED_IDENTIFIER mit einer Neu-Erstellung der Funktion bereinigen.'
            ELSE 'Modul wirkt fuer ein konservatives SCHEMABINDING-Review vorbereitet.'
        END AS next_action,
        LTRIM(RTRIM(CONCAT(
            CASE WHEN fc.uses_ansi_nulls = 1 THEN 'ANSI_NULLS aktiv. ' ELSE 'ANSI_NULLS fehlt. ' END,
            CASE WHEN fc.uses_quoted_identifier = 1 THEN 'QUOTED_IDENTIFIER aktiv. ' ELSE 'QUOTED_IDENTIFIER fehlt. ' END,
            CASE WHEN ds.has_object_reference = 1 THEN 'Objektreferenz erkannt. ' ELSE 'Keine aufloesbare Objektreferenz erkannt. ' END,
            CASE WHEN ds.has_cross_server_reference = 1 THEN 'Cross-Server-Referenz erkannt. ' ELSE '' END,
            CASE WHEN ds.has_cross_database_reference = 1 THEN 'Cross-Database-Referenz erkannt. ' ELSE '' END,
            CASE WHEN ds.has_caller_dependent_reference = 1 THEN 'Caller-dependent Referenz erkannt. ' ELSE '' END,
            CASE WHEN ds.has_unresolved_local_reference = 1 THEN 'Nicht aufgeloeste lokale Referenz erkannt. ' ELSE '' END,
            CASE WHEN def.uses_select_star = 1 THEN 'SELECT * erkannt. ' ELSE '' END,
            CASE WHEN def.uses_nondeterministic_function = 1 THEN 'Nicht deterministische Built-ins erkannt. ' ELSE '' END,
            CASE WHEN def.uses_external_access = 1 THEN 'Externe Zugriffe erkannt. ' ELSE '' END,
            CASE WHEN def.uses_dynamic_execution = 1 THEN 'Dynamische Ausfuehrung erkannt. ' ELSE '' END,
            CASE WHEN def.mentions_temp_objects = 1 THEN 'Tempdb- oder Temp-Objekte erkannt. ' ELSE '' END
        ))) AS readiness_notes,
        CASE
            WHEN @IncludeDefinitionSnippet = 1 AND fc.definition IS NOT NULL
                THEN LEFT(REPLACE(REPLACE(fc.definition, CHAR(13), ' '), CHAR(10), ' '), 220)
            ELSE NULL
        END AS definition_snippet,
        fc.create_date,
        fc.modify_date
    FROM FunctionCatalog AS fc
    INNER JOIN DependencyScan AS ds
        ON ds.object_id = fc.object_id
    INNER JOIN DefinitionSignals AS def
        ON def.object_id = fc.object_id
),
NormalizedAssessment AS
(
    SELECT
        a.schema_name,
        a.function_name,
        a.function_type,
        a.function_type_desc,
        a.is_schema_bound,
        a.uses_ansi_nulls,
        a.uses_quoted_identifier,
        a.is_deterministic,
        a.is_precise,
        a.dependency_count,
        a.has_object_reference,
        a.has_cross_server_reference,
        a.has_cross_database_reference,
        a.has_caller_dependent_reference,
        a.has_unresolved_local_reference,
        a.uses_select_star,
        a.uses_nondeterministic_function,
        a.uses_external_access,
        a.uses_dynamic_execution,
        a.mentions_temp_objects,
        CASE
            WHEN a.raw_readiness_score < 0 THEN 0
            WHEN a.raw_readiness_score > 100 THEN 100
            ELSE a.raw_readiness_score
        END AS readiness_score,
        a.readiness_status,
        a.next_action,
        a.readiness_notes,
        a.definition_snippet,
        a.create_date,
        a.modify_date
    FROM Assessment AS a
)
SELECT
    na.schema_name,
    na.function_name,
    na.function_type,
    na.function_type_desc,
    na.readiness_score,
    na.readiness_status,
    na.next_action,
    na.is_schema_bound,
    na.uses_ansi_nulls,
    na.uses_quoted_identifier,
    na.is_deterministic,
    na.is_precise,
    na.dependency_count,
    na.has_object_reference,
    na.has_cross_server_reference,
    na.has_cross_database_reference,
    na.has_caller_dependent_reference,
    na.has_unresolved_local_reference,
    na.uses_select_star,
    na.uses_nondeterministic_function,
    na.uses_external_access,
    na.uses_dynamic_execution,
    na.mentions_temp_objects,
    na.readiness_notes,
    na.definition_snippet,
    na.create_date,
    na.modify_date
FROM NormalizedAssessment AS na
WHERE na.readiness_score >= @MinimumReadinessScore
ORDER BY
    CASE na.readiness_status
        WHEN 'review_ready' THEN 1
        WHEN 'needs_preparation' THEN 2
        WHEN 'already_schema_bound' THEN 3
        ELSE 4
    END,
    na.readiness_score DESC,
    na.schema_name,
    na.function_name;

SELECT
    na.readiness_status,
    COUNT(*) AS function_count,
    AVG(CAST(na.readiness_score AS DECIMAL(5,2))) AS average_readiness_score,
    SUM(CASE WHEN na.uses_nondeterministic_function = 1 THEN 1 ELSE 0 END) AS nondeterministic_signal_count,
    SUM(CASE WHEN na.has_cross_database_reference = 1 OR na.has_cross_server_reference = 1 THEN 1 ELSE 0 END) AS cross_boundary_reference_count
FROM NormalizedAssessment AS na
GROUP BY
    na.readiness_status
ORDER BY
    CASE na.readiness_status
        WHEN 'review_ready' THEN 1
        WHEN 'needs_preparation' THEN 2
        WHEN 'already_schema_bound' THEN 3
        ELSE 4
    END;
