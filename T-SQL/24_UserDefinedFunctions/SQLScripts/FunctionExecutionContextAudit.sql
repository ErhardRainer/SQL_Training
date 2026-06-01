/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "FunctionExecutionContextAudit.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "24_UserDefinedFunctions"

purpose: >
  Auditiert User-Defined Functions auf Ausfuehrungskontext,
  Eigentuemerschaft und explizite Objektberechtigungen, um
  Ownership-Chaining, EXECUTE AS und potenzielle Review-Faelle
  sichtbar zu machen.

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
  - name: "FunctionExecutionContextAudit"
    description: "Detailaudit pro Funktion mit Kontext-, Owner- und Berechtigungsindikatoren"
  - name: "AuditSummary"
    description: "Aggregierte Anzahl der Funktionen je Risiko- und Befundkategorie"

dependencies:
  - "sys.objects"
  - "sys.schemas"
  - "sys.sql_modules"
  - "sys.database_principals"
  - "sys.database_permissions"
  - "USER_NAME"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/24_UserDefinedFunctions/SQLScripts/FunctionExecutionContextAudit.md"
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
    description: "Erstversion des Diagnose-Skripts fuer Kontext-, Owner- und Berechtigungs-Audits bei Funktionen"

notes:
  - "Die Bewertung kombiniert Modulmetadaten, Objekt-Owner und explizite Objektberechtigungen"
  - "Nicht jede Funktion nutzt EXECUTE AS; fehlende Kontexte werden als CALLER bzw. implizites Ownership-Chaining interpretiert"
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
        o.principal_id AS object_owner_principal_id,
        USER_NAME(o.principal_id) AS object_owner_name,
        USER_NAME(s.principal_id) AS schema_owner_name,
        sm.execute_as_principal_id,
        CASE
            WHEN sm.execute_as_principal_id IS NULL THEN NULL
            WHEN sm.execute_as_principal_id = -2 THEN 'OWNER'
            ELSE USER_NAME(sm.execute_as_principal_id)
        END AS execute_as_principal_name,
        sm.definition,
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
PermissionRollup AS
(
    SELECT
        dp.major_id AS object_id,
        COUNT(*) AS permission_entry_count,
        SUM(CASE WHEN dp.state_desc IN ('GRANT', 'GRANT_WITH_GRANT_OPTION') THEN 1 ELSE 0 END) AS grant_count,
        SUM(CASE WHEN dp.state_desc = 'DENY' THEN 1 ELSE 0 END) AS deny_count,
        STRING_AGG(
            CONCAT(
                dp.state_desc,
                ' ',
                dp.permission_name,
                ' TO ',
                COALESCE(pr.name, CONCAT('principal_id=', CONVERT(VARCHAR(12), dp.grantee_principal_id)))
            ),
            '; '
        ) WITHIN GROUP
        (
            ORDER BY
                pr.name,
                dp.permission_name,
                dp.state_desc
        ) AS permission_summary
    FROM sys.database_permissions AS dp
    LEFT JOIN sys.database_principals AS pr
        ON pr.principal_id = dp.grantee_principal_id
    WHERE dp.class = 1
      AND dp.major_id > 0
    GROUP BY
        dp.major_id
),
Audit AS
(
    SELECT
        fb.schema_name,
        fb.function_name,
        fb.type,
        fb.type_desc,
        COALESCE(fb.object_owner_name, fb.schema_owner_name, 'dbo') AS effective_owner_name,
        fb.object_owner_name,
        fb.schema_owner_name,
        fb.execute_as_principal_id,
        CASE
            WHEN fb.execute_as_principal_id IS NULL THEN 'CALLER'
            WHEN fb.execute_as_principal_id = -2 THEN 'OWNER'
            ELSE COALESCE(fb.execute_as_principal_name, CONCAT('principal_id=', CONVERT(VARCHAR(12), fb.execute_as_principal_id)))
        END AS execution_context,
        ISNULL(pr.permission_entry_count, 0) AS permission_entry_count,
        ISNULL(pr.grant_count, 0) AS grant_count,
        ISNULL(pr.deny_count, 0) AS deny_count,
        pr.permission_summary,
        fb.create_date,
        fb.modify_date,
        CASE
            WHEN fb.execute_as_principal_id IS NOT NULL OR ISNULL(pr.deny_count, 0) > 0 THEN 'high'
            WHEN ISNULL(pr.grant_count, 0) > 0
              OR (fb.object_owner_name IS NOT NULL AND fb.object_owner_name <> fb.schema_owner_name)
                THEN 'medium'
            ELSE 'low'
        END AS risk_level,
        CASE
            WHEN fb.execute_as_principal_id = -2 THEN 'execute_as_owner'
            WHEN fb.execute_as_principal_id IS NOT NULL THEN 'explicit_execute_as'
            WHEN ISNULL(pr.deny_count, 0) > 0 THEN 'deny_present'
            WHEN ISNULL(pr.grant_count, 0) > 0 THEN 'explicit_grants'
            WHEN fb.object_owner_name IS NOT NULL AND fb.object_owner_name <> fb.schema_owner_name THEN 'owner_differs_from_schema'
            ELSE 'default_context'
        END AS audit_status,
        CONCAT(
            CASE
                WHEN fb.execute_as_principal_id IS NULL THEN 'Kein EXECUTE AS im Modul hinterlegt. '
                WHEN fb.execute_as_principal_id = -2 THEN 'Modul laeuft mit EXECUTE AS OWNER. '
                ELSE CONCAT(
                    'Modul laeuft mit EXECUTE AS ',
                    COALESCE(fb.execute_as_principal_name, CONCAT('principal_id=', CONVERT(VARCHAR(12), fb.execute_as_principal_id))),
                    '. '
                )
            END,
            CASE
                WHEN fb.object_owner_name IS NOT NULL AND fb.object_owner_name <> fb.schema_owner_name
                    THEN CONCAT('Objekt-Owner weicht vom Schema-Owner ', fb.schema_owner_name, ' ab. ')
                ELSE ''
            END,
            CASE
                WHEN ISNULL(pr.grant_count, 0) > 0
                    THEN CONCAT('Explizite Objekt-Grant-Eintraege: ', CONVERT(VARCHAR(12), pr.grant_count), '. ')
                ELSE ''
            END,
            CASE
                WHEN ISNULL(pr.deny_count, 0) > 0
                    THEN CONCAT('Explizite Objekt-Deny-Eintraege: ', CONVERT(VARCHAR(12), pr.deny_count), '. ')
                ELSE ''
            END
        ) AS review_notes,
        CASE
            WHEN @IncludeDefinitionSnippet = 1 AND fb.definition IS NOT NULL
                THEN LEFT(REPLACE(REPLACE(fb.definition, CHAR(13), ' '), CHAR(10), ' '), 220)
            ELSE NULL
        END AS definition_snippet
    FROM FunctionBase AS fb
    LEFT JOIN PermissionRollup AS pr
        ON pr.object_id = fb.object_id
)
SELECT
    a.schema_name AS SchemaName,
    a.function_name AS FunctionName,
    a.type AS ObjectType,
    a.type_desc AS ObjectTypeDescription,
    a.execution_context AS ExecutionContext,
    a.effective_owner_name AS EffectiveOwnerName,
    a.object_owner_name AS ObjectOwnerName,
    a.schema_owner_name AS SchemaOwnerName,
    a.permission_entry_count AS PermissionEntryCount,
    a.grant_count AS GrantCount,
    a.deny_count AS DenyCount,
    NULLIF(a.permission_summary, '') AS PermissionSummary,
    a.risk_level AS RiskLevel,
    a.audit_status AS AuditStatus,
    NULLIF(a.review_notes, '') AS ReviewNotes,
    a.definition_snippet AS DefinitionSnippet,
    a.create_date AS CreateDate,
    a.modify_date AS ModifyDate
FROM Audit AS a
WHERE @OnlyFlagged = 0
   OR a.audit_status <> 'default_context'
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
    SUM(CASE WHEN a.execution_context = 'CALLER' THEN 1 ELSE 0 END) AS CallerContextCount,
    SUM(CASE WHEN a.execution_context = 'OWNER' THEN 1 ELSE 0 END) AS OwnerContextCount,
    SUM(CASE WHEN a.execution_context NOT IN ('CALLER', 'OWNER') THEN 1 ELSE 0 END) AS ExplicitPrincipalContextCount,
    SUM(CASE WHEN a.grant_count > 0 THEN 1 ELSE 0 END) AS FunctionsWithGrantEntries,
    SUM(CASE WHEN a.deny_count > 0 THEN 1 ELSE 0 END) AS FunctionsWithDenyEntries
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
