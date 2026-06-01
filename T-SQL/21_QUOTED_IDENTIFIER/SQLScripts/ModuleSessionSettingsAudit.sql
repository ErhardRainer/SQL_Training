/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "ModuleSessionSettingsAudit.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "21_QUOTED_IDENTIFIER"

purpose: >
  Audit fuer gespeicherte Session-Settings je SQL-Modul. Das Skript liest
  Modulmetadaten aus sys.sql_modules, zeigt die persistierten Capture-Werte
  fuer ANSI_NULLS und QUOTED_IDENTIFIER, klassifiziert typische
  Compile-Kontexte und liefert eine kompakte Nacharbeitsgrundlage je Schema.

parameters:
  - name: "@SchemaName"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Optionaler Schemaname fuer die Eingrenzung des Audits"
  - name: "@OnlySettingMismatches"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = nur Module mit OFF- oder Mischkonstellationen im Detailreport ausgeben"
  - name: "@IncludeEncryptedModules"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = verschluesselte Module im Audit behalten"

result_sets:
  - name: "ModuleSessionSettingsAudit"
    description: "Detailsicht je Modul mit persistierten Session-Settings und Audit-Hinweisen"
  - name: "SchemaSessionSettingsSummary"
    description: "Verdichtete Sicht auf Setting-Paare und Audit-Risiko je Schema"
  - name: "SessionSettingsRemediationGuide"
    description: "Kompakte Header-Baseline und Review-Kommandos fuer Nacharbeiten"

dependencies:
  - "sys.sql_modules"
  - "sys.objects"
  - "sys.schemas"
  - "OBJECTPROPERTYEX"
  - "SET ANSI_NULLS"
  - "SET QUOTED_IDENTIFIER"
  - "sp_helptext"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/21_QUOTED_IDENTIFIER/SQLScripts/ModuleSessionSettingsAudit.md"
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
    description: "Erstversion des Audits fuer persistierte Modul-Session-Settings"

notes:
  - "SQL Server persistiert fuer sys.sql_modules vor allem ANSI_NULLS und QUOTED_IDENTIFIER als Modul-Capture-Werte."
  - "Das Skript fuehrt keine Neuerstellung von Modulen aus und bleibt rein lesend."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @SchemaName SYSNAME = NULL;
DECLARE @OnlySettingMismatches BIT = 0;
DECLARE @IncludeEncryptedModules BIT = 1;

IF @OnlySettingMismatches NOT IN (0, 1)
BEGIN
    THROW 50000, '@OnlySettingMismatches muss 0 oder 1 sein.', 1;
END;

IF @IncludeEncryptedModules NOT IN (0, 1)
BEGIN
    THROW 50001, '@IncludeEncryptedModules muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #ModuleSessionInventory;
DROP TABLE IF EXISTS #ModuleSessionSettingsAudit;
DROP TABLE IF EXISTS #SchemaSessionSettingsSummary;
DROP TABLE IF EXISTS #SessionSettingsRemediationGuide;

CREATE TABLE #ModuleSessionInventory
(
    object_id                    INT            NOT NULL,
    schema_name                  SYSNAME        NOT NULL,
    module_name                  SYSNAME        NOT NULL,
    module_type                  NVARCHAR(60)   NOT NULL,
    create_date                  DATETIME       NOT NULL,
    modify_date                  DATETIME       NOT NULL,
    uses_ansi_nulls              BIT            NOT NULL,
    uses_quoted_identifier       BIT            NOT NULL,
    is_schema_bound              BIT            NOT NULL,
    is_encrypted                 BIT            NOT NULL,
    definition_preview           NVARCHAR(200)  NULL
);

INSERT INTO #ModuleSessionInventory
(
    object_id,
    schema_name,
    module_name,
    module_type,
    create_date,
    modify_date,
    uses_ansi_nulls,
    uses_quoted_identifier,
    is_schema_bound,
    is_encrypted,
    definition_preview
)
SELECT
    o.object_id,
    s.name AS schema_name,
    o.name AS module_name,
    o.type_desc AS module_type,
    o.create_date,
    o.modify_date,
    sm.uses_ansi_nulls,
    sm.uses_quoted_identifier,
    CONVERT(BIT, OBJECTPROPERTYEX(o.object_id, 'IsSchemaBound')) AS is_schema_bound,
    sm.is_encrypted,
    CASE
        WHEN sm.is_encrypted = 1 THEN NULL
        ELSE LEFT(REPLACE(REPLACE(sm.definition, CHAR(13), ' '), CHAR(10), ' '), 200)
    END AS definition_preview
FROM sys.sql_modules AS sm
INNER JOIN sys.objects AS o
    ON sm.object_id = o.object_id
INNER JOIN sys.schemas AS s
    ON o.schema_id = s.schema_id
WHERE o.type IN ('P', 'V', 'FN', 'IF', 'TF', 'TR')
  AND (@SchemaName IS NULL OR s.name = @SchemaName)
  AND (@IncludeEncryptedModules = 1 OR sm.is_encrypted = 0);

CREATE TABLE #ModuleSessionSettingsAudit
(
    schema_name                  SYSNAME        NOT NULL,
    module_qualified_name        NVARCHAR(517)  NOT NULL,
    module_type                  NVARCHAR(60)   NOT NULL,
    create_date                  DATETIME       NOT NULL,
    modify_date                  DATETIME       NOT NULL,
    ansi_nulls_setting           VARCHAR(3)     NOT NULL,
    quoted_identifier_setting    VARCHAR(3)     NOT NULL,
    setting_pair                 VARCHAR(32)    NOT NULL,
    compile_context              VARCHAR(18)    NOT NULL,
    audit_risk                   VARCHAR(12)    NOT NULL,
    audit_note                   NVARCHAR(260)  NOT NULL,
    is_schema_bound              VARCHAR(3)     NOT NULL,
    is_encrypted                 VARCHAR(3)     NOT NULL,
    recommended_header_block     NVARCHAR(260)  NOT NULL,
    review_command               NVARCHAR(260)  NOT NULL,
    definition_preview           NVARCHAR(200)  NULL
);

INSERT INTO #ModuleSessionSettingsAudit
(
    schema_name,
    module_qualified_name,
    module_type,
    create_date,
    modify_date,
    ansi_nulls_setting,
    quoted_identifier_setting,
    setting_pair,
    compile_context,
    audit_risk,
    audit_note,
    is_schema_bound,
    is_encrypted,
    recommended_header_block,
    review_command,
    definition_preview
)
SELECT
    msi.schema_name,
    QUOTENAME(msi.schema_name) + N'.' + QUOTENAME(msi.module_name) AS module_qualified_name,
    msi.module_type,
    msi.create_date,
    msi.modify_date,
    CASE msi.uses_ansi_nulls
        WHEN 1 THEN 'ON'
        ELSE 'OFF'
    END AS ansi_nulls_setting,
    CASE msi.uses_quoted_identifier
        WHEN 1 THEN 'ON'
        ELSE 'OFF'
    END AS quoted_identifier_setting,
    CASE
        WHEN msi.uses_ansi_nulls = 1 AND msi.uses_quoted_identifier = 1 THEN 'ANSI_ON__QI_ON'
        WHEN msi.uses_ansi_nulls = 1 AND msi.uses_quoted_identifier = 0 THEN 'ANSI_ON__QI_OFF'
        WHEN msi.uses_ansi_nulls = 0 AND msi.uses_quoted_identifier = 1 THEN 'ANSI_OFF__QI_ON'
        ELSE 'ANSI_OFF__QI_OFF'
    END AS setting_pair,
    CASE
        WHEN msi.uses_ansi_nulls = 1 AND msi.uses_quoted_identifier = 1 THEN 'ModernBaseline'
        WHEN msi.uses_ansi_nulls = 0 AND msi.uses_quoted_identifier = 0 THEN 'LegacyBatch'
        ELSE 'MixedCapture'
    END AS compile_context,
    CASE
        WHEN msi.uses_quoted_identifier = 0 THEN 'High'
        WHEN msi.uses_ansi_nulls = 0 THEN 'Medium'
        ELSE 'Info'
    END AS audit_risk,
    CASE
        WHEN msi.uses_quoted_identifier = 0 AND msi.uses_ansi_nulls = 0
            THEN 'Modul wurde vermutlich aus einem Legacy-Batch mit ANSI_NULLS OFF und QUOTED_IDENTIFIER OFF erstellt.'
        WHEN msi.uses_quoted_identifier = 0
            THEN 'QUOTED_IDENTIFIER OFF ist fuer viele moderne Objekttypen und Deployments ein Review-Signal.'
        WHEN msi.uses_ansi_nulls = 0
            THEN 'ANSI_NULLS OFF weist auf aeltere Capture-Kontexte hin und sollte vor einem Re-Deploy geprueft werden.'
        WHEN msi.is_encrypted = 1
            THEN 'Verschluesseltes Modul ist laut Capture-Werten modern ausgerichtet, die Definition bleibt aber verdeckt.'
        WHEN msi.is_schema_bound = 1
            THEN 'Schema-gebundenes Modul ist modern ausgerichtet und bleibt fuer Kontextpruefungen sichtbar.'
        ELSE 'Persistierte Session-Settings entsprechen einer modernen Baseline mit ANSI_NULLS ON und QUOTED_IDENTIFIER ON.'
    END AS audit_note,
    CASE msi.is_schema_bound
        WHEN 1 THEN 'Yes'
        ELSE 'No'
    END AS is_schema_bound,
    CASE msi.is_encrypted
        WHEN 1 THEN 'Yes'
        ELSE 'No'
    END AS is_encrypted,
    N'SET ANSI_NULLS ON;'
    + CHAR(13) + CHAR(10)
    + N'SET QUOTED_IDENTIFIER ON;' AS recommended_header_block,
    CASE
        WHEN msi.is_encrypted = 1
            THEN N'-- Modul ist verschluesselt; Definition nur ueber Deployment-Quelle oder Quellverwaltung pruefen.'
        ELSE N'EXEC sys.sp_helptext N'''
            + QUOTENAME(msi.schema_name) + N'.' + QUOTENAME(msi.module_name)
            + N''';'
    END AS review_command,
    msi.definition_preview
FROM #ModuleSessionInventory AS msi;

SELECT
    mssa.module_qualified_name,
    mssa.module_type,
    mssa.create_date,
    mssa.modify_date,
    mssa.ansi_nulls_setting,
    mssa.quoted_identifier_setting,
    mssa.setting_pair,
    mssa.compile_context,
    mssa.audit_risk,
    mssa.audit_note,
    mssa.is_schema_bound,
    mssa.is_encrypted,
    mssa.recommended_header_block,
    mssa.review_command,
    mssa.definition_preview
FROM #ModuleSessionSettingsAudit AS mssa
WHERE @OnlySettingMismatches = 0
   OR mssa.audit_risk <> 'Info'
ORDER BY
    CASE mssa.audit_risk
        WHEN 'High' THEN 1
        WHEN 'Medium' THEN 2
        ELSE 3
    END,
    mssa.modify_date,
    mssa.module_qualified_name;

CREATE TABLE #SchemaSessionSettingsSummary
(
    schema_name                  SYSNAME       NOT NULL,
    module_count                 INT           NOT NULL,
    modern_baseline_count        INT           NOT NULL,
    legacy_batch_count           INT           NOT NULL,
    mixed_capture_count          INT           NOT NULL,
    off_quoted_identifier_count  INT           NOT NULL,
    off_ansi_nulls_count         INT           NOT NULL,
    schema_audit_status          VARCHAR(20)   NOT NULL,
    summary_note                 NVARCHAR(260) NOT NULL
);

INSERT INTO #SchemaSessionSettingsSummary
(
    schema_name,
    module_count,
    modern_baseline_count,
    legacy_batch_count,
    mixed_capture_count,
    off_quoted_identifier_count,
    off_ansi_nulls_count,
    schema_audit_status,
    summary_note
)
SELECT
    mssa.schema_name,
    COUNT(*) AS module_count,
    SUM(CASE WHEN mssa.compile_context = 'ModernBaseline' THEN 1 ELSE 0 END) AS modern_baseline_count,
    SUM(CASE WHEN mssa.compile_context = 'LegacyBatch' THEN 1 ELSE 0 END) AS legacy_batch_count,
    SUM(CASE WHEN mssa.compile_context = 'MixedCapture' THEN 1 ELSE 0 END) AS mixed_capture_count,
    SUM(CASE WHEN mssa.quoted_identifier_setting = 'OFF' THEN 1 ELSE 0 END) AS off_quoted_identifier_count,
    SUM(CASE WHEN mssa.ansi_nulls_setting = 'OFF' THEN 1 ELSE 0 END) AS off_ansi_nulls_count,
    CASE
        WHEN SUM(CASE WHEN mssa.compile_context = 'LegacyBatch' THEN 1 ELSE 0 END) > 0 THEN 'LegacyRisk'
        WHEN SUM(CASE WHEN mssa.compile_context = 'MixedCapture' THEN 1 ELSE 0 END) > 0 THEN 'Mixed'
        ELSE 'Aligned'
    END AS schema_audit_status,
    CASE
        WHEN SUM(CASE WHEN mssa.compile_context = 'LegacyBatch' THEN 1 ELSE 0 END) > 0
            THEN 'Schema enthaelt Module mit Legacy-Batch-Capture und sollte vor strukturellen Aenderungen priorisiert geprueft werden.'
        WHEN SUM(CASE WHEN mssa.compile_context = 'MixedCapture' THEN 1 ELSE 0 END) > 0
            THEN 'Schema mischt moderne und gemischte Capture-Kontexte; eine einheitliche Header-Baseline ist sinnvoll.'
        ELSE 'Schema arbeitet mit einer modernen Modul-Baseline fuer ANSI_NULLS und QUOTED_IDENTIFIER.'
    END AS summary_note
FROM #ModuleSessionSettingsAudit AS mssa
GROUP BY
    mssa.schema_name;

SELECT
    ssss.schema_name,
    ssss.module_count,
    ssss.modern_baseline_count,
    ssss.legacy_batch_count,
    ssss.mixed_capture_count,
    ssss.off_quoted_identifier_count,
    ssss.off_ansi_nulls_count,
    ssss.schema_audit_status,
    ssss.summary_note
FROM #SchemaSessionSettingsSummary AS ssss
ORDER BY
    CASE ssss.schema_audit_status
        WHEN 'LegacyRisk' THEN 1
        WHEN 'Mixed' THEN 2
        ELSE 3
    END,
    ssss.module_count DESC,
    ssss.schema_name;

CREATE TABLE #SessionSettingsRemediationGuide
(
    guide_name                   VARCHAR(80)    NOT NULL,
    baseline_header              NVARCHAR(260)  NOT NULL,
    modules_in_scope             INT            NOT NULL,
    modules_requiring_review     INT            NOT NULL,
    review_batch_example         NVARCHAR(MAX)  NOT NULL,
    usage_hint                   NVARCHAR(260)  NOT NULL
);

INSERT INTO #SessionSettingsRemediationGuide
(
    guide_name,
    baseline_header,
    modules_in_scope,
    modules_requiring_review,
    review_batch_example,
    usage_hint
)
SELECT
    'SessionSettingsRemediationGuide',
    N'SET ANSI_NULLS ON;'
    + CHAR(13) + CHAR(10)
    + N'SET QUOTED_IDENTIFIER ON;' AS baseline_header,
    COUNT(*) AS modules_in_scope,
    COALESCE(SUM(CASE WHEN mssa.audit_risk <> 'Info' THEN 1 ELSE 0 END), 0) AS modules_requiring_review,
    COALESCE(
        STRING_AGG(
            CAST(CASE WHEN mssa.audit_risk <> 'Info' THEN mssa.review_command END AS NVARCHAR(MAX)),
            CHAR(13) + CHAR(10)
        ) WITHIN GROUP (ORDER BY mssa.module_qualified_name),
        N'-- Keine Module mit auditrelevanten Session-Settings gefunden.'
    ) AS review_batch_example,
    N'Vor CREATE OR ALTER den gespeicherten Header pruefen und Module nur bewusst neu kompilieren.'
FROM #ModuleSessionSettingsAudit AS mssa;

SELECT
    ssrg.guide_name,
    ssrg.baseline_header,
    ssrg.modules_in_scope,
    ssrg.modules_requiring_review,
    ssrg.review_batch_example,
    ssrg.usage_hint
FROM #SessionSettingsRemediationGuide AS ssrg;
