/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "ModuleQuotedIdentifierReport.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "21_QUOTED_IDENTIFIER"

purpose: >
  Erstellt einen Report ueber QUOTED_IDENTIFIER je SQL-Modul. Das Skript
  liest Metadaten aus sys.sql_modules, zeigt Capture-Werte und
  Review-Prioritaeten pro Modul und verdichtet die Verteilung je Schema fuer
  eine gezielte Nachbearbeitung.

parameters:
  - name: "@ExpectedQuotedIdentifier"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "Erwarteter Capture-Wert fuer QUOTED_IDENTIFIER in der Zielumgebung"
  - name: "@SchemaName"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Optionaler Schemaname fuer die Eingrenzung des Reports"
  - name: "@OnlyMismatches"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = nur Module mit QUOTED_IDENTIFIER-Abweichung gegen die Erwartung ausgeben"
  - name: "@IncludeEncryptedModules"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = verschluesselte Module in die Report-Sicht einbeziehen"

result_sets:
  - name: "ModuleQuotedIdentifierReport"
    description: "Detailsicht auf Module mit QUOTED_IDENTIFIER-Capture, Review-Prioritaet und Folgehinweisen"
  - name: "SchemaQuotedIdentifierSummary"
    description: "Verdichtete Verteilung von QUOTED_IDENTIFIER je Schema"
  - name: "QuotedIdentifierGuidance"
    description: "Header-Baseline und Review-Kommandos fuer die manuelle Nacharbeit"

dependencies:
  - "sys.sql_modules"
  - "sys.objects"
  - "sys.schemas"
  - "OBJECTPROPERTYEX"
  - "SET QUOTED_IDENTIFIER"
  - "sp_helptext"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/21_QUOTED_IDENTIFIER/SQLScripts/ModuleQuotedIdentifierReport.md"
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
    description: "Erstversion des Modul-Reports fuer QUOTED_IDENTIFIER"

notes:
  - "Das Skript liest nur Katalogmetadaten und fuehrt keine Modul-Aenderungen aus."
  - "Die Zielbaseline ist standardmaessig QUOTED_IDENTIFIER ON."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @ExpectedQuotedIdentifier BIT = 1;
DECLARE @SchemaName SYSNAME = NULL;
DECLARE @OnlyMismatches BIT = 1;
DECLARE @IncludeEncryptedModules BIT = 1;

IF @ExpectedQuotedIdentifier NOT IN (0, 1)
BEGIN
    THROW 50000, '@ExpectedQuotedIdentifier muss 0 oder 1 sein.', 1;
END;

IF @OnlyMismatches NOT IN (0, 1)
BEGIN
    THROW 50001, '@OnlyMismatches muss 0 oder 1 sein.', 1;
END;

IF @IncludeEncryptedModules NOT IN (0, 1)
BEGIN
    THROW 50002, '@IncludeEncryptedModules muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #ModuleInventory;
DROP TABLE IF EXISTS #ModuleQuotedIdentifierReport;
DROP TABLE IF EXISTS #SchemaQuotedIdentifierSummary;
DROP TABLE IF EXISTS #QuotedIdentifierGuidance;

CREATE TABLE #ModuleInventory
(
    object_id                INT            NOT NULL,
    schema_name              SYSNAME        NOT NULL,
    module_name              SYSNAME        NOT NULL,
    module_type              NVARCHAR(60)   NOT NULL,
    create_date              DATETIME       NOT NULL,
    modify_date              DATETIME       NOT NULL,
    uses_quoted_identifier   BIT            NOT NULL,
    uses_ansi_nulls          BIT            NOT NULL,
    is_schema_bound          BIT            NOT NULL,
    is_encrypted             BIT            NOT NULL,
    definition_preview       NVARCHAR(200)  NULL
);

INSERT INTO #ModuleInventory
(
    object_id,
    schema_name,
    module_name,
    module_type,
    create_date,
    modify_date,
    uses_quoted_identifier,
    uses_ansi_nulls,
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
    sm.uses_quoted_identifier,
    sm.uses_ansi_nulls,
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

CREATE TABLE #ModuleQuotedIdentifierReport
(
    schema_name                  SYSNAME        NOT NULL,
    module_qualified_name        NVARCHAR(517)  NOT NULL,
    module_type                  NVARCHAR(60)   NOT NULL,
    create_date                  DATETIME       NOT NULL,
    modify_date                  DATETIME       NOT NULL,
    quoted_identifier_setting    VARCHAR(3)     NOT NULL,
    expected_setting             VARCHAR(3)     NOT NULL,
    setting_status               VARCHAR(20)    NOT NULL,
    review_priority              VARCHAR(10)    NOT NULL,
    review_reason                NVARCHAR(260)  NOT NULL,
    uses_ansi_nulls              VARCHAR(3)     NOT NULL,
    is_schema_bound              VARCHAR(3)     NOT NULL,
    is_encrypted                 VARCHAR(3)     NOT NULL,
    review_command               NVARCHAR(260)  NOT NULL,
    recommended_header           NVARCHAR(260)  NOT NULL,
    definition_preview           NVARCHAR(200)  NULL
);

INSERT INTO #ModuleQuotedIdentifierReport
(
    schema_name,
    module_qualified_name,
    module_type,
    create_date,
    modify_date,
    quoted_identifier_setting,
    expected_setting,
    setting_status,
    review_priority,
    review_reason,
    uses_ansi_nulls,
    is_schema_bound,
    is_encrypted,
    review_command,
    recommended_header,
    definition_preview
)
SELECT
    mi.schema_name,
    QUOTENAME(mi.schema_name) + N'.' + QUOTENAME(mi.module_name) AS module_qualified_name,
    mi.module_type,
    mi.create_date,
    mi.modify_date,
    CASE mi.uses_quoted_identifier
        WHEN 1 THEN 'ON'
        ELSE 'OFF'
    END AS quoted_identifier_setting,
    CASE @ExpectedQuotedIdentifier
        WHEN 1 THEN 'ON'
        ELSE 'OFF'
    END AS expected_setting,
    CASE
        WHEN mi.uses_quoted_identifier = @ExpectedQuotedIdentifier THEN 'Aligned'
        ELSE 'Mismatch'
    END AS setting_status,
    CASE
        WHEN mi.uses_quoted_identifier <> @ExpectedQuotedIdentifier THEN 'High'
        WHEN mi.is_schema_bound = 1 THEN 'Info'
        ELSE 'Review'
    END AS review_priority,
    CASE
        WHEN mi.uses_quoted_identifier <> @ExpectedQuotedIdentifier
            THEN 'QUOTED_IDENTIFIER weicht vom erwarteten Capture-Wert ab.'
        WHEN mi.is_encrypted = 1
            THEN 'Modul ist verschluesselt, wirkt laut Capture-Wert aber ausgerichtet.'
        WHEN mi.is_schema_bound = 1
            THEN 'Schema-gebundenes Modul ist ausgerichtet und bleibt fuer Folgepruefungen sichtbar.'
        ELSE 'QUOTED_IDENTIFIER entspricht dem erwarteten Capture-Wert.'
    END AS review_reason,
    CASE mi.uses_ansi_nulls
        WHEN 1 THEN 'ON'
        ELSE 'OFF'
    END AS uses_ansi_nulls,
    CASE mi.is_schema_bound
        WHEN 1 THEN 'Yes'
        ELSE 'No'
    END AS is_schema_bound,
    CASE mi.is_encrypted
        WHEN 1 THEN 'Yes'
        ELSE 'No'
    END AS is_encrypted,
    N'EXEC sys.sp_helptext N'''
    + QUOTENAME(mi.schema_name) + N'.' + QUOTENAME(mi.module_name)
    + N''';' AS review_command,
    CASE @ExpectedQuotedIdentifier
        WHEN 1 THEN N'SET QUOTED_IDENTIFIER ON;'
        ELSE N'SET QUOTED_IDENTIFIER OFF;'
    END AS recommended_header,
    mi.definition_preview
FROM #ModuleInventory AS mi;

SELECT
    mqir.module_qualified_name,
    mqir.module_type,
    mqir.create_date,
    mqir.modify_date,
    mqir.quoted_identifier_setting,
    mqir.expected_setting,
    mqir.setting_status,
    mqir.review_priority,
    mqir.review_reason,
    mqir.uses_ansi_nulls,
    mqir.is_schema_bound,
    mqir.is_encrypted,
    mqir.review_command,
    mqir.recommended_header,
    mqir.definition_preview
FROM #ModuleQuotedIdentifierReport AS mqir
WHERE @OnlyMismatches = 0
   OR mqir.setting_status <> 'Aligned'
ORDER BY
    CASE mqir.review_priority
        WHEN 'High' THEN 1
        WHEN 'Review' THEN 2
        ELSE 3
    END,
    mqir.modify_date,
    mqir.module_qualified_name;

CREATE TABLE #SchemaQuotedIdentifierSummary
(
    schema_name                  SYSNAME        NOT NULL,
    module_count                 INT            NOT NULL,
    quoted_identifier_on_count   INT            NOT NULL,
    quoted_identifier_off_count  INT            NOT NULL,
    mismatch_count               INT            NOT NULL,
    schema_status                VARCHAR(20)    NOT NULL,
    summary_note                 NVARCHAR(260)  NOT NULL
);

INSERT INTO #SchemaQuotedIdentifierSummary
(
    schema_name,
    module_count,
    quoted_identifier_on_count,
    quoted_identifier_off_count,
    mismatch_count,
    schema_status,
    summary_note
)
SELECT
    mqir.schema_name,
    COUNT(*) AS module_count,
    SUM(CASE WHEN mqir.quoted_identifier_setting = 'ON' THEN 1 ELSE 0 END) AS quoted_identifier_on_count,
    SUM(CASE WHEN mqir.quoted_identifier_setting = 'OFF' THEN 1 ELSE 0 END) AS quoted_identifier_off_count,
    SUM(CASE WHEN mqir.setting_status = 'Mismatch' THEN 1 ELSE 0 END) AS mismatch_count,
    CASE
        WHEN SUM(CASE WHEN mqir.setting_status = 'Mismatch' THEN 1 ELSE 0 END) = 0 THEN 'Aligned'
        WHEN SUM(CASE WHEN mqir.quoted_identifier_setting = 'ON' THEN 1 ELSE 0 END) > 0
         AND SUM(CASE WHEN mqir.quoted_identifier_setting = 'OFF' THEN 1 ELSE 0 END) > 0 THEN 'Mixed'
        ELSE 'UniformMismatch'
    END AS schema_status,
    CASE
        WHEN SUM(CASE WHEN mqir.setting_status = 'Mismatch' THEN 1 ELSE 0 END) = 0
            THEN 'Alle Module im Schema folgen dem erwarteten QUOTED_IDENTIFIER-Capture.'
        WHEN SUM(CASE WHEN mqir.quoted_identifier_setting = 'ON' THEN 1 ELSE 0 END) > 0
         AND SUM(CASE WHEN mqir.quoted_identifier_setting = 'OFF' THEN 1 ELSE 0 END) > 0
            THEN 'Schema mischt ON- und OFF-Captures und sollte priorisiert vereinheitlicht werden.'
        ELSE 'Schema ist intern einheitlich, weicht aber geschlossen von der Erwartung ab.'
    END AS summary_note
FROM #ModuleQuotedIdentifierReport AS mqir
GROUP BY
    mqir.schema_name;

SELECT
    sqis.schema_name,
    sqis.module_count,
    sqis.quoted_identifier_on_count,
    sqis.quoted_identifier_off_count,
    sqis.mismatch_count,
    sqis.schema_status,
    sqis.summary_note
FROM #SchemaQuotedIdentifierSummary AS sqis
ORDER BY
    CASE sqis.schema_status
        WHEN 'Mixed' THEN 1
        WHEN 'UniformMismatch' THEN 2
        ELSE 3
    END,
    sqis.module_count DESC,
    sqis.schema_name;

CREATE TABLE #QuotedIdentifierGuidance
(
    guidance_name             VARCHAR(80)    NOT NULL,
    expected_header           NVARCHAR(260)  NOT NULL,
    modules_in_scope          INT            NOT NULL,
    mismatching_modules       INT            NOT NULL,
    review_batch_example      NVARCHAR(MAX)  NOT NULL,
    usage_hint                NVARCHAR(260)  NOT NULL
);

INSERT INTO #QuotedIdentifierGuidance
(
    guidance_name,
    expected_header,
    modules_in_scope,
    mismatching_modules,
    review_batch_example,
    usage_hint
)
SELECT
    'QuotedIdentifierReviewGuidance',
    CASE @ExpectedQuotedIdentifier
        WHEN 1 THEN N'SET QUOTED_IDENTIFIER ON;'
        ELSE N'SET QUOTED_IDENTIFIER OFF;'
    END AS expected_header,
    COUNT(*) AS modules_in_scope,
    SUM(CASE WHEN mqir.setting_status = 'Mismatch' THEN 1 ELSE 0 END) AS mismatching_modules,
    COALESCE(
        STRING_AGG(
            CAST(CASE WHEN mqir.setting_status = 'Mismatch' THEN mqir.review_command END AS NVARCHAR(MAX)),
            CHAR(13) + CHAR(10)
        ) WITHIN GROUP (ORDER BY mqir.module_qualified_name),
        N'-- Keine QUOTED_IDENTIFIER-Abweichungen gegen die Erwartung gefunden.'
    ) AS review_batch_example,
    N'Review-Kommandos vor einem CREATE OR ALTER mit passendem QUOTED_IDENTIFIER-Header ausfuehren.'
FROM #ModuleQuotedIdentifierReport AS mqir;

SELECT
    qig.guidance_name,
    qig.expected_header,
    qig.modules_in_scope,
    qig.mismatching_modules,
    qig.review_batch_example,
    qig.usage_hint
FROM #QuotedIdentifierGuidance AS qig;
