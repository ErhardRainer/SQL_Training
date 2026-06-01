/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "FunctionDeterminismAudit.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "24_UserDefinedFunctions"

purpose: >
  Prueft User-Defined Functions auf Metadaten- und Definitionshinweise
  zu Determinismus, Praezision, Schema Binding und potenziell
  seiteneffektbehafteten oder kontextabhaengigen Ausdruecken.

parameters:
  - name: "@SchemaFilter"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Optionales Schema zur Eingrenzung der Analyse"
  - name: "@OnlyFlagged"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = nur Funktionen mit Warnhinweisen ausgeben"
  - name: "@IncludeDefinitionSnippet"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = gekuerzten Definitionsausschnitt im Detailresultset anzeigen"

result_sets:
  - name: "FunctionDeterminismAudit"
    description: "Detailaudit pro Funktion mit Metadaten, Hinweisen und Risikobewertung"
  - name: "FindingSummary"
    description: "Aggregierte Anzahl der Funktionen je Bewertungs- und Warnkategorie"

dependencies:
  - "sys.objects"
  - "sys.schemas"
  - "sys.sql_modules"
  - "OBJECTPROPERTYEX"
  - "UPPER"
  - "LIKE"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/24_UserDefinedFunctions/SQLScripts/FunctionDeterminismAudit.md"
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
    date: "2026-04-17"
    user: "ER"
    description: "Erstversion des Diagnose-Skripts fuer Determinismus-Hinweise bei Funktionen"

notes:
  - "Die Bewertung kombiniert SQL-Server-Metadaten mit heuristischen Textmustern in sys.sql_modules.definition"
  - "Seiteneffekte werden als Warnhinweise fuer kontextabhaengige oder nicht deterministische Ausdruecke modelliert"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @SchemaFilter SYSNAME = NULL;
DECLARE @OnlyFlagged BIT = 0;
DECLARE @IncludeDefinitionSnippet BIT = 1;

IF @OnlyFlagged NOT IN (0, 1)
BEGIN
    THROW 50000, '@OnlyFlagged muss 0 oder 1 sein.', 1;
END;

IF @IncludeDefinitionSnippet NOT IN (0, 1)
BEGIN
    THROW 50001, '@IncludeDefinitionSnippet muss 0 oder 1 sein.', 1;
END;

;WITH FunctionBase AS
(
    SELECT
        o.object_id,
        s.name AS schema_name,
        o.name AS function_name,
        o.type,
        o.type_desc,
        sm.definition,
        CAST(OBJECTPROPERTYEX(o.object_id, 'IsDeterministic') AS BIT) AS is_deterministic,
        CAST(OBJECTPROPERTYEX(o.object_id, 'IsPrecise') AS BIT) AS is_precise,
        CAST(OBJECTPROPERTYEX(o.object_id, 'IsSchemaBound') AS BIT) AS is_schema_bound,
        CAST(OBJECTPROPERTYEX(o.object_id, 'ExecIsNullCall') AS BIT) AS null_on_null_input,
        o.create_date,
        o.modify_date
    FROM sys.objects AS o
    INNER JOIN sys.schemas AS s
        ON s.schema_id = o.schema_id
    LEFT JOIN sys.sql_modules AS sm
        ON sm.object_id = o.object_id
    WHERE o.type IN ('FN', 'IF', 'TF', 'FS', 'FT')
      AND (@SchemaFilter IS NULL OR s.name = @SchemaFilter)
),
DefinitionSignals AS
(
    SELECT
        fb.object_id,
        fb.schema_name,
        fb.function_name,
        fb.type,
        fb.type_desc,
        fb.definition,
        fb.is_deterministic,
        fb.is_precise,
        fb.is_schema_bound,
        fb.null_on_null_input,
        fb.create_date,
        fb.modify_date,
        CASE
            WHEN fb.definition IS NULL THEN NULL
            ELSE UPPER(fb.definition)
        END AS definition_upper
    FROM FunctionBase AS fb
),
FlagScan AS
(
    SELECT
        ds.object_id,
        ds.schema_name,
        ds.function_name,
        ds.type,
        ds.type_desc,
        ds.definition,
        ds.is_deterministic,
        ds.is_precise,
        ds.is_schema_bound,
        ds.null_on_null_input,
        ds.create_date,
        ds.modify_date,
        CAST(CASE WHEN ds.definition_upper LIKE '%GETDATE(%'
                    OR ds.definition_upper LIKE '%SYSDATETIME(%'
                    OR ds.definition_upper LIKE '%SYSUTCDATETIME(%'
                    OR ds.definition_upper LIKE '%CURRENT_TIMESTAMP%'
                  THEN 1 ELSE 0 END AS BIT) AS uses_time_function,
        CAST(CASE WHEN ds.definition_upper LIKE '%NEWID(%'
                    OR ds.definition_upper LIKE '%NEWSEQUENTIALID(%'
                    OR ds.definition_upper LIKE '%RAND(%'
                    OR ds.definition_upper LIKE '%CRYPT_GEN_RANDOM(%'
                  THEN 1 ELSE 0 END AS BIT) AS uses_random_function,
        CAST(CASE WHEN ds.definition_upper LIKE '%NEXT VALUE FOR%'
                  THEN 1 ELSE 0 END AS BIT) AS uses_sequence,
        CAST(CASE WHEN ds.definition_upper LIKE '%@@%'
                    OR ds.definition_upper LIKE '%SESSION_CONTEXT(%'
                    OR ds.definition_upper LIKE '%CONTEXT_INFO(%'
                  THEN 1 ELSE 0 END AS BIT) AS uses_session_state,
        CAST(CASE WHEN ds.definition_upper LIKE '%OPENROWSET(%'
                    OR ds.definition_upper LIKE '%OPENQUERY(%'
                    OR ds.definition_upper LIKE '%OPENDATASOURCE(%'
                  THEN 1 ELSE 0 END AS BIT) AS uses_external_access,
        CAST(CASE WHEN ds.definition_upper LIKE '%INSERT %'
                    OR ds.definition_upper LIKE '%UPDATE %'
                    OR ds.definition_upper LIKE '%DELETE %'
                    OR ds.definition_upper LIKE '%MERGE %'
                  THEN 1 ELSE 0 END AS BIT) AS mentions_data_change_tokens,
        CAST(CASE WHEN ds.definition_upper LIKE '%EXEC %'
                    OR ds.definition_upper LIKE '%SP_EXECUTESQL%'
                  THEN 1 ELSE 0 END AS BIT) AS mentions_execute_tokens,
        CAST(CASE WHEN ds.definition_upper LIKE '%TRY%'
                    OR ds.definition_upper LIKE '%CATCH%'
                    OR ds.definition_upper LIKE '%RAISERROR%'
                    OR ds.definition_upper LIKE '%THROW %'
                  THEN 1 ELSE 0 END AS BIT) AS mentions_error_handling_tokens
    FROM DefinitionSignals AS ds
),
Audit AS
(
    SELECT
        fs.schema_name,
        fs.function_name,
        fs.type,
        fs.type_desc,
        fs.is_deterministic,
        fs.is_precise,
        fs.is_schema_bound,
        fs.null_on_null_input,
        fs.create_date,
        fs.modify_date,
        fs.uses_time_function,
        fs.uses_random_function,
        fs.uses_sequence,
        fs.uses_session_state,
        fs.uses_external_access,
        fs.mentions_data_change_tokens,
        fs.mentions_execute_tokens,
        fs.mentions_error_handling_tokens,
        CASE
            WHEN fs.is_deterministic = 1
             AND fs.is_precise = 1
             AND fs.is_schema_bound = 1
             AND fs.uses_time_function = 0
             AND fs.uses_random_function = 0
             AND fs.uses_sequence = 0
             AND fs.uses_session_state = 0
             AND fs.uses_external_access = 0
                THEN 'low'
            WHEN fs.is_deterministic = 0
              OR fs.uses_time_function = 1
              OR fs.uses_random_function = 1
              OR fs.uses_sequence = 1
              OR fs.uses_session_state = 1
              OR fs.uses_external_access = 1
                THEN 'high'
            ELSE 'medium'
        END AS risk_level,
        CASE
            WHEN fs.is_deterministic = 1
             AND fs.is_schema_bound = 1
             AND fs.uses_time_function = 0
             AND fs.uses_random_function = 0
             AND fs.uses_sequence = 0
             AND fs.uses_session_state = 0
             AND fs.uses_external_access = 0
                THEN 'looks_stable'
            WHEN fs.is_deterministic = 0
             AND (fs.uses_time_function = 1 OR fs.uses_random_function = 1 OR fs.uses_sequence = 1 OR fs.uses_session_state = 1)
                THEN 'nondeterministic_signal'
            WHEN fs.mentions_data_change_tokens = 1
              OR fs.mentions_execute_tokens = 1
              OR fs.mentions_error_handling_tokens = 1
                THEN 'review_restrictions'
            ELSE 'review_metadata'
        END AS audit_status,
        CONCAT(
            CASE WHEN fs.is_schema_bound = 0 THEN 'No SCHEMABINDING. ' ELSE '' END,
            CASE WHEN fs.is_deterministic = 0 THEN 'Metadata marks function as non-deterministic. ' ELSE '' END,
            CASE WHEN fs.is_precise = 0 THEN 'Metadata marks function as imprecise. ' ELSE '' END,
            CASE WHEN fs.uses_time_function = 1 THEN 'Definition references time-dependent built-ins. ' ELSE '' END,
            CASE WHEN fs.uses_random_function = 1 THEN 'Definition references random or GUID built-ins. ' ELSE '' END,
            CASE WHEN fs.uses_sequence = 1 THEN 'Definition references NEXT VALUE FOR. ' ELSE '' END,
            CASE WHEN fs.uses_session_state = 1 THEN 'Definition references session or context state. ' ELSE '' END,
            CASE WHEN fs.uses_external_access = 1 THEN 'Definition references external rowset access. ' ELSE '' END,
            CASE WHEN fs.mentions_data_change_tokens = 1 THEN 'Definition contains DML-like tokens that deserve a manual check. ' ELSE '' END,
            CASE WHEN fs.mentions_execute_tokens = 1 THEN 'Definition contains EXEC-like tokens that deserve a manual check. ' ELSE '' END,
            CASE WHEN fs.mentions_error_handling_tokens = 1 THEN 'Definition contains TRY/CATCH or error tokens that deserve a manual check. ' ELSE '' END
        ) AS review_notes,
        CASE
            WHEN @IncludeDefinitionSnippet = 1 AND fs.definition IS NOT NULL
                THEN LEFT(REPLACE(REPLACE(fs.definition, CHAR(13), ' '), CHAR(10), ' '), 220)
            ELSE NULL
        END AS definition_snippet
    FROM FlagScan AS fs
)
SELECT
    a.schema_name AS SchemaName,
    a.function_name AS FunctionName,
    a.type AS ObjectType,
    a.type_desc AS ObjectTypeDescription,
    a.is_deterministic AS IsDeterministic,
    a.is_precise AS IsPrecise,
    a.is_schema_bound AS IsSchemaBound,
    a.null_on_null_input AS NullOnNullInput,
    a.uses_time_function AS UsesTimeFunction,
    a.uses_random_function AS UsesRandomOrGuidFunction,
    a.uses_sequence AS UsesSequence,
    a.uses_session_state AS UsesSessionState,
    a.uses_external_access AS UsesExternalAccess,
    a.mentions_data_change_tokens AS MentionsDataChangeTokens,
    a.mentions_execute_tokens AS MentionsExecuteTokens,
    a.mentions_error_handling_tokens AS MentionsErrorHandlingTokens,
    a.risk_level AS RiskLevel,
    a.audit_status AS AuditStatus,
    NULLIF(a.review_notes, '') AS ReviewNotes,
    a.definition_snippet AS DefinitionSnippet,
    a.create_date AS CreateDate,
    a.modify_date AS ModifyDate
FROM Audit AS a
WHERE @OnlyFlagged = 0
   OR a.audit_status <> 'looks_stable'
ORDER BY
    CASE a.risk_level
        WHEN 'high' THEN 1
        WHEN 'medium' THEN 2
        ELSE 3
    END,
    a.schema_name,
    a.function_name;

SELECT
    a.risk_level AS RiskLevel,
    a.audit_status AS AuditStatus,
    COUNT(*) AS FunctionCount,
    SUM(CASE WHEN a.is_deterministic = 1 THEN 1 ELSE 0 END) AS DeterministicCount,
    SUM(CASE WHEN a.is_schema_bound = 1 THEN 1 ELSE 0 END) AS SchemaBoundCount,
    SUM(CASE WHEN a.uses_time_function = 1 THEN 1 ELSE 0 END) AS TimeFunctionCount,
    SUM(CASE WHEN a.uses_random_function = 1 THEN 1 ELSE 0 END) AS RandomFunctionCount,
    SUM(CASE WHEN a.uses_session_state = 1 THEN 1 ELSE 0 END) AS SessionStateCount
FROM Audit AS a
GROUP BY
    a.risk_level,
    a.audit_status
ORDER BY
    CASE a.risk_level
        WHEN 'high' THEN 1
        WHEN 'medium' THEN 2
        ELSE 3
    END,
    a.audit_status;
