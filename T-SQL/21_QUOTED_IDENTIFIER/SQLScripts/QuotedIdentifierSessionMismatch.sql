/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "QuotedIdentifierSessionMismatch.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "21_QUOTED_IDENTIFIER"

purpose: >
  Vergleicht die in SQL-Modulen gespeicherten Capture-Werte fuer
  ANSI_NULLS und QUOTED_IDENTIFIER mit den aktuellen Session-Einstellungen
  der laufenden Verbindung. Das Skript zeigt betroffene Module,
  verdichtet die Abweichungen pro Schema und liefert eine kleine
  Orientierung fuer Recreate- oder Review-Schritte.

parameters:
  - name: "@SchemaName"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Optionaler Schemaname fuer die Eingrenzung des Vergleichs"
  - name: "@ModuleNamePattern"
    sql_type: "NVARCHAR(128)"
    direction: "IN"
    required: false
    description: "Optionales LIKE-Muster fuer Modulnamen"
  - name: "@OnlyMismatches"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = nur Module mit Abweichung gegen die aktuelle Session ausgeben"
  - name: "@IncludeEncryptedModules"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = verschluesselte Module im Report behalten"

result_sets:
  - name: "QuotedIdentifierSessionMismatch"
    description: "Detailsicht je Modul mit Session- und Metadatenvergleich"
  - name: "SchemaMismatchSummary"
    description: "Verdichtete Sicht auf Abweichungen pro Schema"
  - name: "SessionAlignmentGuide"
    description: "Aktuelle Session-Baseline und Review-Hinweise fuer Nacharbeiten"

dependencies:
  - "sys.sql_modules"
  - "sys.objects"
  - "sys.schemas"
  - "OBJECTPROPERTYEX"
  - "SESSIONPROPERTY"
  - "SET ANSI_NULLS"
  - "SET QUOTED_IDENTIFIER"
  - "sp_helptext"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/21_QUOTED_IDENTIFIER/SQLScripts/QuotedIdentifierSessionMismatch.md"
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
    description: "Erstversion des Session-vs-Metadaten-Vergleichs fuer QUOTED_IDENTIFIER"

notes:
  - "Das Skript liest nur Katalogmetadaten und aktuelle Session-Eigenschaften."
  - "Die laufende Session dient als Vergleichsbasis und wird nicht automatisch umgestellt."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @SchemaName SYSNAME = NULL;
DECLARE @ModuleNamePattern NVARCHAR(128) = NULL;
DECLARE @OnlyMismatches BIT = 1;
DECLARE @IncludeEncryptedModules BIT = 1;

DECLARE @CurrentAnsiNulls BIT = CONVERT(BIT, SESSIONPROPERTY('ANSI_NULLS'));
DECLARE @CurrentQuotedIdentifier BIT = CONVERT(BIT, SESSIONPROPERTY('QUOTED_IDENTIFIER'));

IF @OnlyMismatches NOT IN (0, 1)
BEGIN
    THROW 50000, '@OnlyMismatches muss 0 oder 1 sein.', 1;
END;

IF @IncludeEncryptedModules NOT IN (0, 1)
BEGIN
    THROW 50001, '@IncludeEncryptedModules muss 0 oder 1 sein.', 1;
END;

IF @CurrentAnsiNulls IS NULL OR @CurrentQuotedIdentifier IS NULL
BEGIN
    THROW 50002, 'SESSIONPROPERTY fuer ANSI_NULLS oder QUOTED_IDENTIFIER liefert NULL.', 1;
END;

DROP TABLE IF EXISTS #ModuleSessionInventory;
DROP TABLE IF EXISTS #QuotedIdentifierSessionMismatch;
DROP TABLE IF EXISTS #SchemaMismatchSummary;
DROP TABLE IF EXISTS #SessionAlignmentGuide;

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
  AND (@ModuleNamePattern IS NULL OR o.name LIKE @ModuleNamePattern)
  AND (@IncludeEncryptedModules = 1 OR sm.is_encrypted = 0);

CREATE TABLE #QuotedIdentifierSessionMismatch
(
    schema_name                      SYSNAME        NOT NULL,
    module_qualified_name            NVARCHAR(517)  NOT NULL,
    module_type                      NVARCHAR(60)   NOT NULL,
    create_date                      DATETIME       NOT NULL,
    modify_date                      DATETIME       NOT NULL,
    current_ansi_nulls               VARCHAR(3)     NOT NULL,
    current_quoted_identifier        VARCHAR(3)     NOT NULL,
    module_ansi_nulls                VARCHAR(3)     NOT NULL,
    module_quoted_identifier         VARCHAR(3)     NOT NULL,
    session_pair                     VARCHAR(32)    NOT NULL,
    module_pair                      VARCHAR(32)    NOT NULL,
    mismatch_scope                   VARCHAR(24)    NOT NULL,
    review_priority                  VARCHAR(10)    NOT NULL,
    review_note                      NVARCHAR(260)  NOT NULL,
    recreate_header_baseline         NVARCHAR(260)  NOT NULL,
    review_command                   NVARCHAR(260)  NOT NULL,
    is_schema_bound                  VARCHAR(3)     NOT NULL,
    is_encrypted                     VARCHAR(3)     NOT NULL,
    definition_preview               NVARCHAR(200)  NULL
);

INSERT INTO #QuotedIdentifierSessionMismatch
(
    schema_name,
    module_qualified_name,
    module_type,
    create_date,
    modify_date,
    current_ansi_nulls,
    current_quoted_identifier,
    module_ansi_nulls,
    module_quoted_identifier,
    session_pair,
    module_pair,
    mismatch_scope,
    review_priority,
    review_note,
    recreate_header_baseline,
    review_command,
    is_schema_bound,
    is_encrypted,
    definition_preview
)
SELECT
    msi.schema_name,
    QUOTENAME(msi.schema_name) + N'.' + QUOTENAME(msi.module_name) AS module_qualified_name,
    msi.module_type,
    msi.create_date,
    msi.modify_date,
    CASE @CurrentAnsiNulls
        WHEN 1 THEN 'ON'
        ELSE 'OFF'
    END AS current_ansi_nulls,
    CASE @CurrentQuotedIdentifier
        WHEN 1 THEN 'ON'
        ELSE 'OFF'
    END AS current_quoted_identifier,
    CASE msi.uses_ansi_nulls
        WHEN 1 THEN 'ON'
        ELSE 'OFF'
    END AS module_ansi_nulls,
    CASE msi.uses_quoted_identifier
        WHEN 1 THEN 'ON'
        ELSE 'OFF'
    END AS module_quoted_identifier,
    CASE
        WHEN @CurrentAnsiNulls = 1 AND @CurrentQuotedIdentifier = 1 THEN 'ANSI_ON__QI_ON'
        WHEN @CurrentAnsiNulls = 1 AND @CurrentQuotedIdentifier = 0 THEN 'ANSI_ON__QI_OFF'
        WHEN @CurrentAnsiNulls = 0 AND @CurrentQuotedIdentifier = 1 THEN 'ANSI_OFF__QI_ON'
        ELSE 'ANSI_OFF__QI_OFF'
    END AS session_pair,
    CASE
        WHEN msi.uses_ansi_nulls = 1 AND msi.uses_quoted_identifier = 1 THEN 'ANSI_ON__QI_ON'
        WHEN msi.uses_ansi_nulls = 1 AND msi.uses_quoted_identifier = 0 THEN 'ANSI_ON__QI_OFF'
        WHEN msi.uses_ansi_nulls = 0 AND msi.uses_quoted_identifier = 1 THEN 'ANSI_OFF__QI_ON'
        ELSE 'ANSI_OFF__QI_OFF'
    END AS module_pair,
    CASE
        WHEN msi.uses_ansi_nulls = @CurrentAnsiNulls
         AND msi.uses_quoted_identifier = @CurrentQuotedIdentifier THEN 'Aligned'
        WHEN msi.uses_quoted_identifier <> @CurrentQuotedIdentifier
         AND msi.uses_ansi_nulls <> @CurrentAnsiNulls THEN 'BothMismatch'
        WHEN msi.uses_quoted_identifier <> @CurrentQuotedIdentifier THEN 'QuotedMismatch'
        ELSE 'AnsiMismatch'
    END AS mismatch_scope,
    CASE
        WHEN msi.uses_quoted_identifier <> @CurrentQuotedIdentifier THEN 'High'
        WHEN msi.uses_ansi_nulls <> @CurrentAnsiNulls THEN 'Medium'
        ELSE 'Info'
    END AS review_priority,
    CASE
        WHEN msi.uses_quoted_identifier <> @CurrentQuotedIdentifier
         AND msi.uses_ansi_nulls <> @CurrentAnsiNulls THEN 'Modul-Capture weicht bei ANSI_NULLS und QUOTED_IDENTIFIER von der laufenden Session ab.'
        WHEN msi.uses_quoted_identifier <> @CurrentQuotedIdentifier THEN 'Modul-Capture und laufende Session unterscheiden sich bei QUOTED_IDENTIFIER.'
        WHEN msi.uses_ansi_nulls <> @CurrentAnsiNulls THEN 'Modul-Capture und laufende Session unterscheiden sich bei ANSI_NULLS.'
        WHEN msi.is_encrypted = 1 THEN 'Capture-Werte sind ausgerichtet, die Definition des Moduls bleibt aber verdeckt.'
        WHEN msi.is_schema_bound = 1 THEN 'Capture-Werte sind ausgerichtet und das Modul ist schema-gebunden.'
        ELSE 'Aktuelle Session und gespeicherte Modul-Metadaten sind ausgerichtet.'
    END AS review_note,
    CASE @CurrentAnsiNulls
        WHEN 1 THEN 'SET ANSI_NULLS ON;'
        ELSE 'SET ANSI_NULLS OFF;'
    END
    + CHAR(13) + CHAR(10)
    + CASE @CurrentQuotedIdentifier
        WHEN 1 THEN 'SET QUOTED_IDENTIFIER ON;'
        ELSE 'SET QUOTED_IDENTIFIER OFF;'
      END AS recreate_header_baseline,
    CASE
        WHEN msi.is_encrypted = 1
            THEN N'-- Modul ist verschluesselt; Definition ueber Quellverwaltung oder Deployment-Skript pruefen.'
        ELSE N'EXEC sys.sp_helptext N'''
            + QUOTENAME(msi.schema_name) + N'.' + QUOTENAME(msi.module_name)
            + N''';'
    END AS review_command,
    CASE msi.is_schema_bound
        WHEN 1 THEN 'Yes'
        ELSE 'No'
    END AS is_schema_bound,
    CASE msi.is_encrypted
        WHEN 1 THEN 'Yes'
        ELSE 'No'
    END AS is_encrypted,
    msi.definition_preview
FROM #ModuleSessionInventory AS msi;

SELECT
    qism.module_qualified_name,
    qism.module_type,
    qism.create_date,
    qism.modify_date,
    qism.current_ansi_nulls,
    qism.current_quoted_identifier,
    qism.module_ansi_nulls,
    qism.module_quoted_identifier,
    qism.session_pair,
    qism.module_pair,
    qism.mismatch_scope,
    qism.review_priority,
    qism.review_note,
    qism.recreate_header_baseline,
    qism.review_command,
    qism.is_schema_bound,
    qism.is_encrypted,
    qism.definition_preview
FROM #QuotedIdentifierSessionMismatch AS qism
WHERE @OnlyMismatches = 0
   OR qism.mismatch_scope <> 'Aligned'
ORDER BY
    CASE qism.review_priority
        WHEN 'High' THEN 1
        WHEN 'Medium' THEN 2
        ELSE 3
    END,
    qism.modify_date,
    qism.module_qualified_name;

CREATE TABLE #SchemaMismatchSummary
(
    schema_name                      SYSNAME       NOT NULL,
    module_count                     INT           NOT NULL,
    aligned_modules                  INT           NOT NULL,
    quoted_mismatch_modules          INT           NOT NULL,
    ansi_mismatch_modules            INT           NOT NULL,
    both_mismatch_modules            INT           NOT NULL,
    schema_status                    VARCHAR(18)   NOT NULL,
    status_note                      NVARCHAR(260) NOT NULL
);

INSERT INTO #SchemaMismatchSummary
(
    schema_name,
    module_count,
    aligned_modules,
    quoted_mismatch_modules,
    ansi_mismatch_modules,
    both_mismatch_modules,
    schema_status,
    status_note
)
SELECT
    qism.schema_name,
    COUNT(*) AS module_count,
    SUM(CASE WHEN qism.mismatch_scope = 'Aligned' THEN 1 ELSE 0 END) AS aligned_modules,
    SUM(CASE WHEN qism.mismatch_scope = 'QuotedMismatch' THEN 1 ELSE 0 END) AS quoted_mismatch_modules,
    SUM(CASE WHEN qism.mismatch_scope = 'AnsiMismatch' THEN 1 ELSE 0 END) AS ansi_mismatch_modules,
    SUM(CASE WHEN qism.mismatch_scope = 'BothMismatch' THEN 1 ELSE 0 END) AS both_mismatch_modules,
    CASE
        WHEN SUM(CASE WHEN qism.mismatch_scope = 'QuotedMismatch' THEN 1 ELSE 0 END) > 0
          OR SUM(CASE WHEN qism.mismatch_scope = 'BothMismatch' THEN 1 ELSE 0 END) > 0 THEN 'QuotedRisk'
        WHEN SUM(CASE WHEN qism.mismatch_scope = 'AnsiMismatch' THEN 1 ELSE 0 END) > 0 THEN 'AnsiRisk'
        ELSE 'Aligned'
    END AS schema_status,
    CASE
        WHEN SUM(CASE WHEN qism.mismatch_scope = 'QuotedMismatch' THEN 1 ELSE 0 END) > 0
          OR SUM(CASE WHEN qism.mismatch_scope = 'BothMismatch' THEN 1 ELSE 0 END) > 0 THEN 'Schema enthaelt Module, deren QUOTED_IDENTIFIER-Capture nicht zur aktuellen Session passt.'
        WHEN SUM(CASE WHEN qism.mismatch_scope = 'AnsiMismatch' THEN 1 ELSE 0 END) > 0 THEN 'Schema enthaelt nur ANSI_NULLS-Abweichungen gegen die aktuelle Session.'
        ELSE 'Schema ist gegen die aktuelle Session fuer die relevanten Capture-Werte ausgerichtet.'
    END AS status_note
FROM #QuotedIdentifierSessionMismatch AS qism
GROUP BY
    qism.schema_name;

SELECT
    sms.schema_name,
    sms.module_count,
    sms.aligned_modules,
    sms.quoted_mismatch_modules,
    sms.ansi_mismatch_modules,
    sms.both_mismatch_modules,
    sms.schema_status,
    sms.status_note
FROM #SchemaMismatchSummary AS sms
ORDER BY
    CASE sms.schema_status
        WHEN 'QuotedRisk' THEN 1
        WHEN 'AnsiRisk' THEN 2
        ELSE 3
    END,
    sms.module_count DESC,
    sms.schema_name;

CREATE TABLE #SessionAlignmentGuide
(
    guide_name                       VARCHAR(80)    NOT NULL,
    current_session_header           NVARCHAR(260)  NOT NULL,
    modules_in_scope                 INT            NOT NULL,
    modules_requiring_review         INT            NOT NULL,
    review_batch_example             NVARCHAR(MAX)  NOT NULL,
    usage_hint                       NVARCHAR(260)  NOT NULL
);

INSERT INTO #SessionAlignmentGuide
(
    guide_name,
    current_session_header,
    modules_in_scope,
    modules_requiring_review,
    review_batch_example,
    usage_hint
)
SELECT
    'SessionAlignmentGuide',
    CASE @CurrentAnsiNulls
        WHEN 1 THEN 'SET ANSI_NULLS ON;'
        ELSE 'SET ANSI_NULLS OFF;'
    END
    + CHAR(13) + CHAR(10)
    + CASE @CurrentQuotedIdentifier
        WHEN 1 THEN 'SET QUOTED_IDENTIFIER ON;'
        ELSE 'SET QUOTED_IDENTIFIER OFF;'
      END AS current_session_header,
    COUNT(*) AS modules_in_scope,
    COALESCE(SUM(CASE WHEN qism.mismatch_scope <> 'Aligned' THEN 1 ELSE 0 END), 0) AS modules_requiring_review,
    COALESCE(
        STRING_AGG(
            CAST(CASE WHEN qism.mismatch_scope <> 'Aligned' THEN qism.review_command END AS NVARCHAR(MAX)),
            CHAR(13) + CHAR(10)
        ) WITHIN GROUP (ORDER BY qism.module_qualified_name),
        N'-- Keine Abweichungen zwischen aktueller Session und Modul-Metadaten gefunden.'
    ) AS review_batch_example,
    N'Vor CREATE OR ALTER die Session bewusst setzen und gespeicherte Modul-Header mit der Zielbaseline abstimmen.'
FROM #QuotedIdentifierSessionMismatch AS qism;

SELECT
    sag.guide_name,
    sag.current_session_header,
    sag.modules_in_scope,
    sag.modules_requiring_review,
    sag.review_batch_example,
    sag.usage_hint
FROM #SessionAlignmentGuide AS sag;
