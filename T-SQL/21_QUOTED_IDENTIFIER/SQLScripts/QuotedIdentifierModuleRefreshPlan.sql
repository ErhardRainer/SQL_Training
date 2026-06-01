/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "QuotedIdentifierModuleRefreshPlan.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "21_QUOTED_IDENTIFIER"

purpose: >
  Plant das kontrollierte Neu-Erstellen betroffener SQL-Module mit Fokus auf
  persistierte Session-Settings. Das Skript inventarisiert Module aus
  sys.sql_modules, priorisiert sie fuer Refresh-Wellen und erzeugt eine
  nachvollziehbare Arbeitsgrundlage mit Header-Baseline, Review-Hinweisen und
  Batch-Skeletten.

parameters:
  - name: "@SchemaName"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Optionaler Filter auf ein einzelnes Schema"
  - name: "@OnlyActionable"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = nur Module mit echtem Refresh- oder Review-Bedarf ausgeben"
  - name: "@ExpectedAnsiNulls"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "Zielwert fuer SET ANSI_NULLS im geplanten Refresh-Batch"
  - name: "@ExpectedQuotedIdentifier"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "Zielwert fuer SET QUOTED_IDENTIFIER im geplanten Refresh-Batch"
  - name: "@MaxModulesPerWave"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Maximale Modulanzahl je geplanter Refresh-Welle"
  - name: "@IncludeEncryptedModules"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = verschluesselte Module als externe Beschaffungsfaelle im Plan behalten"

result_sets:
  - name: "ModuleRefreshPlan"
    description: "Priorisierte Modulliste mit Refresh-Welle, Aktion und Review-Batch-Skelett"
  - name: "RefreshWaveSummary"
    description: "Verdichtung nach Refresh-Welle, Aktionstyp und Modulanzahl"
  - name: "RefreshExecutionChecklist"
    description: "Kontrollierte Schrittfolge fuer Analyse, Definition, Test und Deployment"

dependencies:
  - "sys.sql_modules"
  - "sys.objects"
  - "sys.schemas"
  - "OBJECTPROPERTYEX"
  - "sp_helptext"
  - "SET ANSI_NULLS"
  - "SET QUOTED_IDENTIFIER"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/21_QUOTED_IDENTIFIER/SQLScripts/QuotedIdentifierModuleRefreshPlan.md"
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
    description: "Erstversion des Refresh-Plans fuer betroffene Module mit QUOTED_IDENTIFIER-Bezug"

notes:
  - "Das Skript fuehrt keine Neuerstellung aus, sondern plant und priorisiert kontrollierte Refresh-Schritte."
  - "Fuer verschluesselte Module werden externe Definitionsquellen vorausgesetzt und nicht erraten."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @SchemaName SYSNAME = NULL;
DECLARE @OnlyActionable BIT = 1;
DECLARE @ExpectedAnsiNulls BIT = 1;
DECLARE @ExpectedQuotedIdentifier BIT = 1;
DECLARE @MaxModulesPerWave INT = 5;
DECLARE @IncludeEncryptedModules BIT = 1;

IF @OnlyActionable NOT IN (0, 1)
BEGIN
    THROW 50000, '@OnlyActionable muss 0 oder 1 sein.', 1;
END;

IF @ExpectedAnsiNulls NOT IN (0, 1)
BEGIN
    THROW 50001, '@ExpectedAnsiNulls muss 0 oder 1 sein.', 1;
END;

IF @ExpectedQuotedIdentifier NOT IN (0, 1)
BEGIN
    THROW 50002, '@ExpectedQuotedIdentifier muss 0 oder 1 sein.', 1;
END;

IF @IncludeEncryptedModules NOT IN (0, 1)
BEGIN
    THROW 50003, '@IncludeEncryptedModules muss 0 oder 1 sein.', 1;
END;

IF @MaxModulesPerWave IS NULL OR @MaxModulesPerWave < 1
BEGIN
    THROW 50004, '@MaxModulesPerWave muss mindestens 1 sein.', 1;
END;

DROP TABLE IF EXISTS #ModuleInventory;
DROP TABLE IF EXISTS #ModuleRefreshPlan;
DROP TABLE IF EXISTS #RefreshWaveSummary;
DROP TABLE IF EXISTS #RefreshExecutionChecklist;

CREATE TABLE #ModuleInventory
(
    object_id                    INT            NOT NULL,
    schema_name                  SYSNAME        NOT NULL,
    module_name                  SYSNAME        NOT NULL,
    module_qualified_name        NVARCHAR(517)  NOT NULL,
    module_type                  NVARCHAR(60)   NOT NULL,
    create_date                  DATETIME       NOT NULL,
    modify_date                  DATETIME       NOT NULL,
    uses_ansi_nulls              BIT            NOT NULL,
    uses_quoted_identifier       BIT            NOT NULL,
    is_schema_bound              BIT            NOT NULL,
    is_encrypted                 BIT            NOT NULL,
    definition_text              NVARCHAR(MAX)  NULL
);

INSERT INTO #ModuleInventory
(
    object_id,
    schema_name,
    module_name,
    module_qualified_name,
    module_type,
    create_date,
    modify_date,
    uses_ansi_nulls,
    uses_quoted_identifier,
    is_schema_bound,
    is_encrypted,
    definition_text
)
SELECT
    o.object_id,
    s.name AS schema_name,
    o.name AS module_name,
    QUOTENAME(s.name) + N'.' + QUOTENAME(o.name) AS module_qualified_name,
    o.type_desc AS module_type,
    o.create_date,
    o.modify_date,
    sm.uses_ansi_nulls,
    sm.uses_quoted_identifier,
    CONVERT(BIT, OBJECTPROPERTYEX(o.object_id, 'IsSchemaBound')) AS is_schema_bound,
    sm.is_encrypted,
    sm.definition AS definition_text
FROM sys.sql_modules AS sm
INNER JOIN sys.objects AS o
    ON sm.object_id = o.object_id
INNER JOIN sys.schemas AS s
    ON s.schema_id = o.schema_id
WHERE o.type IN ('P', 'V', 'FN', 'IF', 'TF', 'TR')
  AND (@SchemaName IS NULL OR s.name = @SchemaName)
  AND (@IncludeEncryptedModules = 1 OR sm.is_encrypted = 0);

CREATE TABLE #ModuleRefreshPlan
(
    refresh_wave                 INT            NOT NULL,
    refresh_priority             INT            NOT NULL,
    module_qualified_name        NVARCHAR(517)  NOT NULL,
    module_type                  NVARCHAR(60)   NOT NULL,
    current_setting_pair         VARCHAR(32)    NOT NULL,
    target_setting_pair          VARCHAR(32)    NOT NULL,
    refresh_action               VARCHAR(32)    NOT NULL,
    refresh_reason               NVARCHAR(260)  NOT NULL,
    dependency_note              NVARCHAR(260)  NOT NULL,
    planned_header_block         NVARCHAR(200)  NOT NULL,
    review_command               NVARCHAR(260)  NOT NULL,
    batch_skeleton               NVARCHAR(MAX)  NOT NULL,
    create_date                  DATETIME       NOT NULL,
    modify_date                  DATETIME       NOT NULL
);

;WITH ModuleScoring AS
(
    SELECT
        mi.object_id,
        mi.schema_name,
        mi.module_name,
        mi.module_qualified_name,
        mi.module_type,
        mi.create_date,
        mi.modify_date,
        mi.uses_ansi_nulls,
        mi.uses_quoted_identifier,
        mi.is_schema_bound,
        mi.is_encrypted,
        mi.definition_text,
        CASE
            WHEN mi.uses_ansi_nulls = 1 AND mi.uses_quoted_identifier = 1 THEN 'ANSI_ON__QI_ON'
            WHEN mi.uses_ansi_nulls = 1 AND mi.uses_quoted_identifier = 0 THEN 'ANSI_ON__QI_OFF'
            WHEN mi.uses_ansi_nulls = 0 AND mi.uses_quoted_identifier = 1 THEN 'ANSI_OFF__QI_ON'
            ELSE 'ANSI_OFF__QI_OFF'
        END AS current_setting_pair,
        CASE
            WHEN @ExpectedAnsiNulls = 1 AND @ExpectedQuotedIdentifier = 1 THEN 'ANSI_ON__QI_ON'
            WHEN @ExpectedAnsiNulls = 1 AND @ExpectedQuotedIdentifier = 0 THEN 'ANSI_ON__QI_OFF'
            WHEN @ExpectedAnsiNulls = 0 AND @ExpectedQuotedIdentifier = 1 THEN 'ANSI_OFF__QI_ON'
            ELSE 'ANSI_OFF__QI_OFF'
        END AS target_setting_pair,
        CASE
            WHEN mi.is_encrypted = 1 THEN 'ExternalDefinition'
            WHEN mi.definition_text IS NULL OR LEN(mi.definition_text) = 0 THEN 'ManualDefinitionReview'
            WHEN mi.uses_quoted_identifier <> @ExpectedQuotedIdentifier
              OR mi.uses_ansi_nulls <> @ExpectedAnsiNulls THEN 'RecreateWithModernHeader'
            ELSE 'BaselineConfirmed'
        END AS refresh_action,
        CASE
            WHEN mi.is_encrypted = 1 THEN 1
            WHEN mi.uses_quoted_identifier = 0 AND mi.is_schema_bound = 1 THEN 1
            WHEN mi.uses_quoted_identifier = 0 AND mi.module_type IN ('VIEW', 'SQL_TRIGGER') THEN 1
            WHEN mi.uses_quoted_identifier = 0 THEN 2
            WHEN mi.uses_ansi_nulls = 0 THEN 3
            ELSE 4
        END AS refresh_priority,
        CASE
            WHEN mi.is_encrypted = 1
                THEN N'Verschluesseltes Modul: Definition zuerst aus Quellverwaltung oder Deployment-Artefakten beschaffen.'
            WHEN mi.definition_text IS NULL OR LEN(mi.definition_text) = 0
                THEN N'Im Katalog ist keine Definition verfuegbar; Refresh erst nach manueller Beschaffung planen.'
            WHEN mi.uses_quoted_identifier <> @ExpectedQuotedIdentifier
             AND mi.uses_ansi_nulls <> @ExpectedAnsiNulls
                THEN N'Beide persistierten Session-Settings weichen von der Ziel-Baseline ab und sollten gemeinsam bereinigt werden.'
            WHEN mi.uses_quoted_identifier <> @ExpectedQuotedIdentifier
                THEN N'QUOTED_IDENTIFIER weicht von der Ziel-Baseline ab und ist fuer Recreate-Batches das prioritaere Review-Signal.'
            WHEN mi.uses_ansi_nulls <> @ExpectedAnsiNulls
                THEN N'ANSI_NULLS weicht von der Ziel-Baseline ab und sollte vor dem Refresh explizit harmonisiert werden.'
            ELSE N'Modul entspricht bereits der Ziel-Baseline und bleibt als Referenzfall im Plan.'
        END AS refresh_reason,
        CASE
            WHEN mi.is_schema_bound = 1
                THEN N'Schema-bound Modul: abhaengige Objekte und Deployment-Reihenfolge vor dem Refresh pruefen.'
            WHEN mi.module_type = 'VIEW'
                THEN N'View: abhaengige Reports, Berechtigungen und moegliche Indexe vor dem Recreate beruecksichtigen.'
            WHEN mi.module_type = 'SQL_TRIGGER'
                THEN N'Trigger: Zielobjekt, Seiteneffekte und Testdaten vor dem Refresh separat pruefen.'
            WHEN mi.module_type LIKE '%FUNCTION%'
                THEN N'Funktion: Signatur und aufrufende Objekte fuer den geplanten Refresh mit betrachten.'
            ELSE N'Prozedur oder tabellarisches Modul: Header-Baseline, Tests und Rollback-Notiz vor dem Refresh festhalten.'
        END AS dependency_note,
        N'SET ANSI_NULLS ' + CASE @ExpectedAnsiNulls WHEN 1 THEN N'ON' ELSE N'OFF' END + N';'
        + CHAR(13) + CHAR(10)
        + N'SET QUOTED_IDENTIFIER ' + CASE @ExpectedQuotedIdentifier WHEN 1 THEN N'ON' ELSE N'OFF' END + N';' AS planned_header_block,
        CASE
            WHEN mi.is_encrypted = 1
                THEN N'-- Modul ist verschluesselt; Definition aus externer Quelle beschaffen.'
            ELSE N'EXEC sys.sp_helptext N''' + mi.module_qualified_name + N''';'
        END AS review_command
    FROM #ModuleInventory AS mi
),
ModuleWaves AS
(
    SELECT
        ms.*,
        ((ROW_NUMBER() OVER
        (
            ORDER BY
                ms.refresh_priority,
                ms.modify_date,
                ms.module_qualified_name
        ) - 1) / @MaxModulesPerWave) + 1 AS refresh_wave
    FROM ModuleScoring AS ms
)
INSERT INTO #ModuleRefreshPlan
(
    refresh_wave,
    refresh_priority,
    module_qualified_name,
    module_type,
    current_setting_pair,
    target_setting_pair,
    refresh_action,
    refresh_reason,
    dependency_note,
    planned_header_block,
    review_command,
    batch_skeleton,
    create_date,
    modify_date
)
SELECT
    mw.refresh_wave,
    mw.refresh_priority,
    mw.module_qualified_name,
    mw.module_type,
    mw.current_setting_pair,
    mw.target_setting_pair,
    mw.refresh_action,
    mw.refresh_reason,
    mw.dependency_note,
    mw.planned_header_block,
    mw.review_command,
    CASE
        WHEN mw.refresh_action IN ('ExternalDefinition', 'ManualDefinitionReview')
            THEN N'-- Plan fuer ' + mw.module_qualified_name + CHAR(13) + CHAR(10)
                + N'-- ' + mw.refresh_reason + CHAR(13) + CHAR(10)
                + mw.planned_header_block + CHAR(13) + CHAR(10)
                + N'-- Definition hier einfuegen oder aus der Freigabequelle uebernehmen.' + CHAR(13) + CHAR(10)
                + N'-- Danach CREATE, ALTER oder CREATE OR ALTER bewusst anpassen.' + CHAR(13) + CHAR(10)
                + N'GO'
        ELSE N'-- Plan fuer ' + mw.module_qualified_name + CHAR(13) + CHAR(10)
            + N'-- ' + mw.refresh_reason + CHAR(13) + CHAR(10)
            + N'-- ' + mw.dependency_note + CHAR(13) + CHAR(10)
            + mw.planned_header_block + CHAR(13) + CHAR(10)
            + N'-- Definition via sp_helptext pruefen und fuer den geplanten Refresh in einen separaten Batch uebernehmen.' + CHAR(13) + CHAR(10)
            + N'GO'
    END AS batch_skeleton,
    mw.create_date,
    mw.modify_date
FROM ModuleWaves AS mw;

SELECT
    mrp.refresh_wave,
    mrp.refresh_priority,
    mrp.module_qualified_name,
    mrp.module_type,
    mrp.current_setting_pair,
    mrp.target_setting_pair,
    mrp.refresh_action,
    mrp.refresh_reason,
    mrp.dependency_note,
    mrp.planned_header_block,
    mrp.review_command,
    mrp.batch_skeleton,
    mrp.create_date,
    mrp.modify_date
FROM #ModuleRefreshPlan AS mrp
WHERE @OnlyActionable = 0
   OR mrp.refresh_action <> 'BaselineConfirmed'
ORDER BY
    mrp.refresh_wave,
    mrp.refresh_priority,
    mrp.modify_date,
    mrp.module_qualified_name;

CREATE TABLE #RefreshWaveSummary
(
    refresh_wave                 INT            NOT NULL,
    refresh_action               VARCHAR(32)    NOT NULL,
    module_count                 INT            NOT NULL,
    highest_priority_in_wave     INT            NOT NULL,
    summary_note                 NVARCHAR(260)  NOT NULL
);

INSERT INTO #RefreshWaveSummary
(
    refresh_wave,
    refresh_action,
    module_count,
    highest_priority_in_wave,
    summary_note
)
SELECT
    mrp.refresh_wave,
    mrp.refresh_action,
    COUNT(*) AS module_count,
    MIN(mrp.refresh_priority) AS highest_priority_in_wave,
    CASE
        WHEN mrp.refresh_action = 'ExternalDefinition'
            THEN N'Welle enthaelt verschluesselte Module; externe Definitionen zuerst beschaffen.'
        WHEN mrp.refresh_action = 'ManualDefinitionReview'
            THEN N'Welle enthaelt Module mit fehlender Definition und benoetigt manuelle Vorarbeit.'
        WHEN mrp.refresh_action = 'RecreateWithModernHeader'
            THEN N'Welle enthaelt aktiv zu harmonisierende Module mit geplantem Refresh-Header.'
        ELSE N'Welle enthaelt bereits ausgerichtete Referenzfaelle ohne unmittelbaren Refresh-Bedarf.'
    END AS summary_note
FROM #ModuleRefreshPlan AS mrp
WHERE @OnlyActionable = 0
   OR mrp.refresh_action <> 'BaselineConfirmed'
GROUP BY
    mrp.refresh_wave,
    mrp.refresh_action;

SELECT
    rws.refresh_wave,
    rws.refresh_action,
    rws.module_count,
    rws.highest_priority_in_wave,
    rws.summary_note
FROM #RefreshWaveSummary AS rws
ORDER BY
    rws.refresh_wave,
    rws.highest_priority_in_wave,
    rws.refresh_action;

CREATE TABLE #RefreshExecutionChecklist
(
    step_number                  INT            NOT NULL,
    phase_name                   VARCHAR(40)    NOT NULL,
    recommended_action           NVARCHAR(260)  NOT NULL,
    why_it_matters               NVARCHAR(260)  NOT NULL
);

INSERT INTO #RefreshExecutionChecklist
(
    step_number,
    phase_name,
    recommended_action,
    why_it_matters
)
VALUES
    (1, 'Inventory', N'Detailplan pro Welle sichten und prioritaere Module mit QUOTED_IDENTIFIER OFF zuerst markieren.', N'Die Reihenfolge reduziert Risiko bei Recreates fuer sensible Module und haelt den Scope klein.'),
    (2, 'Definition', N'Fuer verschluesselte oder fehlende Definitionen zunaechst die Freigabequelle oder Quellverwaltung beschaffen.', N'Ohne belastbare Definition ist kein kontrolliertes Neu-Erstellen moeglich.'),
    (3, 'Header', N'Vor jedem Refresh-Batch explizit SET ANSI_NULLS und SET QUOTED_IDENTIFIER auf die Ziel-Baseline setzen.', N'Diese Session-Optionen werden beim Kompilieren persistiert und muessen bewusst harmonisiert werden.'),
    (4, 'Validation', N'Abhaengigkeiten, Berechtigungen und fachliche Tests je Modul vor dem eigentlichen Recreate festhalten.', N'Ein kontrollierter Refresh braucht Test- und Rollback-Kontext statt nur einen neuen Header.'),
    (5, 'Deployment', N'Refresh nur wellenweise und mit getrennten Batches pro Modul oder klaren GO-Grenzen ausfuehren.', N'Das verhindert vermischte Session-Kontexte und erleichtert ein geordnetes Rollback.');

SELECT
    rec.step_number,
    rec.phase_name,
    rec.recommended_action,
    rec.why_it_matters
FROM #RefreshExecutionChecklist AS rec
ORDER BY
    rec.step_number;
