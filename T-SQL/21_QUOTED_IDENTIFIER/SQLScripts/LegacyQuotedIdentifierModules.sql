/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "LegacyQuotedIdentifierModules.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "21_QUOTED_IDENTIFIER"

purpose: >
  Findet aeltere SQL-Module mit auffaelligen QUOTED_IDENTIFIER-Einstellungen
  und priorisiert Kandidaten fuer Review oder Neuerstellung. Das Skript nutzt
  Katalogsichten, bewertet Alter und Session-Capture des Moduls und erzeugt
  ein Remediation-Template fuer die weitere Bearbeitung.

parameters:
  - name: "@LegacyCutoffDate"
    sql_type: "DATE"
    direction: "IN"
    required: false
    description: "Module mit create_date oder modify_date vor diesem Datum gelten als legacy-nah"
  - name: "@OnlyFlaggedModules"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = nur Module mit mindestens einem Review-Flag ausgeben"
  - name: "@IncludeEncryptedModules"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = verschluesselte Module trotz eingeschraenkter Einsicht einbeziehen"

result_sets:
  - name: "LegacyQuotedIdentifierModules"
    description: "Detailsicht auf Module mit Alter, QUOTED_IDENTIFIER-Capture und Review-Hinweisen"
  - name: "RiskSummary"
    description: "Verdichtete Uebersicht ueber Anzahl und Schwere der gefundenen Legacy-Kandidaten"
  - name: "RemediationTemplate"
    description: "Beispielhafte Review- und Recreate-Schritte fuer betroffene Module"

dependencies:
  - "sys.sql_modules"
  - "sys.objects"
  - "sys.schemas"
  - "OBJECTPROPERTYEX"
  - "SET QUOTED_IDENTIFIER"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/21_QUOTED_IDENTIFIER/SQLScripts/LegacyQuotedIdentifierModules.md"
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
    description: "Erstversion des Legacy-Audits fuer Module mit QUOTED_IDENTIFIER-Fokus"

notes:
  - "Legacy wird didaktisch ueber einen frei waehlbaren Stichtag modelliert."
  - "Das Skript fuehrt keine ALTER- oder CREATE-Befehle aus und erzeugt nur Review-Hinweise."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @LegacyCutoffDate DATE = '2016-01-01';
DECLARE @OnlyFlaggedModules BIT = 1;
DECLARE @IncludeEncryptedModules BIT = 1;

IF @LegacyCutoffDate IS NULL
BEGIN
    THROW 50000, '@LegacyCutoffDate darf nicht NULL sein.', 1;
END;

IF @OnlyFlaggedModules NOT IN (0, 1)
BEGIN
    THROW 50001, '@OnlyFlaggedModules muss 0 oder 1 sein.', 1;
END;

IF @IncludeEncryptedModules NOT IN (0, 1)
BEGIN
    THROW 50002, '@IncludeEncryptedModules muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #ModuleInventory;
DROP TABLE IF EXISTS #LegacyAssessment;
DROP TABLE IF EXISTS #RiskSummary;
DROP TABLE IF EXISTS #RemediationTemplate;

CREATE TABLE #ModuleInventory
(
    object_id               INT            NOT NULL,
    schema_name             SYSNAME        NOT NULL,
    module_name             SYSNAME        NOT NULL,
    module_type             NVARCHAR(60)   NOT NULL,
    create_date             DATETIME       NOT NULL,
    modify_date             DATETIME       NOT NULL,
    uses_quoted_identifier  BIT            NOT NULL,
    uses_ansi_nulls         BIT            NOT NULL,
    is_schema_bound         BIT            NOT NULL,
    is_encrypted            BIT            NOT NULL,
    definition_preview      NVARCHAR(200)  NULL
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
  AND (@IncludeEncryptedModules = 1 OR sm.is_encrypted = 0);

CREATE TABLE #LegacyAssessment
(
    object_id                INT            NOT NULL,
    module_qualified_name    NVARCHAR(517)  NOT NULL,
    module_type              NVARCHAR(60)   NOT NULL,
    create_date              DATETIME       NOT NULL,
    modify_date              DATETIME       NOT NULL,
    uses_quoted_identifier   VARCHAR(3)     NOT NULL,
    uses_ansi_nulls          VARCHAR(3)     NOT NULL,
    is_schema_bound          VARCHAR(3)     NOT NULL,
    is_encrypted             VARCHAR(3)     NOT NULL,
    legacy_reason            VARCHAR(120)   NOT NULL,
    review_status            VARCHAR(14)    NOT NULL,
    risk_level               VARCHAR(10)    NOT NULL,
    recommended_action       VARCHAR(260)   NOT NULL,
    definition_preview       NVARCHAR(200)  NULL
);

INSERT INTO #LegacyAssessment
(
    object_id,
    module_qualified_name,
    module_type,
    create_date,
    modify_date,
    uses_quoted_identifier,
    uses_ansi_nulls,
    is_schema_bound,
    is_encrypted,
    legacy_reason,
    review_status,
    risk_level,
    recommended_action,
    definition_preview
)
SELECT
    mi.object_id,
    QUOTENAME(mi.schema_name) + N'.' + QUOTENAME(mi.module_name) AS module_qualified_name,
    mi.module_type,
    mi.create_date,
    mi.modify_date,
    CASE mi.uses_quoted_identifier
        WHEN 1 THEN 'ON'
        ELSE 'OFF'
    END AS uses_quoted_identifier,
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
    CASE
        WHEN mi.uses_quoted_identifier = 0 AND mi.modify_date < @LegacyCutoffDate THEN 'Legacy capture and QUOTED_IDENTIFIER OFF'
        WHEN mi.uses_quoted_identifier = 0 THEN 'QUOTED_IDENTIFIER OFF'
        WHEN mi.modify_date < @LegacyCutoffDate THEN 'Module changed before legacy cutoff'
        WHEN mi.create_date < @LegacyCutoffDate THEN 'Module created before legacy cutoff'
        ELSE 'No legacy trigger'
    END AS legacy_reason,
    CASE
        WHEN mi.uses_quoted_identifier = 0 OR mi.modify_date < @LegacyCutoffDate OR mi.create_date < @LegacyCutoffDate THEN 'ReviewNeeded'
        ELSE 'Aligned'
    END AS review_status,
    CASE
        WHEN mi.uses_quoted_identifier = 0 AND mi.is_encrypted = 1 THEN 'High'
        WHEN mi.uses_quoted_identifier = 0 THEN 'High'
        WHEN mi.modify_date < @LegacyCutoffDate THEN 'Medium'
        WHEN mi.create_date < @LegacyCutoffDate THEN 'Low'
        ELSE 'Info'
    END AS risk_level,
    CASE
        WHEN mi.uses_quoted_identifier = 0 AND mi.is_encrypted = 1 THEN 'Quelle sichern, Moduldefinition aus Deployment-Source beschaffen und mit SET QUOTED_IDENTIFIER ON neu erstellen.'
        WHEN mi.uses_quoted_identifier = 0 THEN 'Definition pruefen und das Modul in einer Session mit SET QUOTED_IDENTIFIER ON neu deployen.'
        WHEN mi.modify_date < @LegacyCutoffDate THEN 'Aenderungshistorie pruefen und Session-Capture bei der naechsten Revision dokumentieren.'
        WHEN mi.create_date < @LegacyCutoffDate THEN 'Legacy-Modul in die naechste Review-Welle fuer Session-Settings aufnehmen.'
        ELSE 'Keine Aktion erforderlich.'
    END AS recommended_action,
    mi.definition_preview
FROM #ModuleInventory AS mi;

SELECT
    la.module_qualified_name,
    la.module_type,
    la.create_date,
    la.modify_date,
    la.uses_quoted_identifier,
    la.uses_ansi_nulls,
    la.is_schema_bound,
    la.is_encrypted,
    la.legacy_reason,
    la.review_status,
    la.risk_level,
    la.recommended_action,
    la.definition_preview
FROM #LegacyAssessment AS la
WHERE @OnlyFlaggedModules = 0
   OR la.review_status = 'ReviewNeeded'
ORDER BY
    CASE la.risk_level
        WHEN 'High' THEN 1
        WHEN 'Medium' THEN 2
        WHEN 'Low' THEN 3
        ELSE 4
    END,
    la.modify_date,
    la.module_qualified_name;

CREATE TABLE #RiskSummary
(
    risk_level          VARCHAR(10)  NOT NULL,
    module_count        INT          NOT NULL,
    quoted_off_count    INT          NOT NULL,
    encrypted_count     INT          NOT NULL,
    oldest_modify_date  DATETIME     NULL,
    summary_note        VARCHAR(260) NOT NULL
);

INSERT INTO #RiskSummary
(
    risk_level,
    module_count,
    quoted_off_count,
    encrypted_count,
    oldest_modify_date,
    summary_note
)
SELECT
    la.risk_level,
    COUNT(*) AS module_count,
    SUM(CASE WHEN la.uses_quoted_identifier = 'OFF' THEN 1 ELSE 0 END) AS quoted_off_count,
    SUM(CASE WHEN la.is_encrypted = 'Yes' THEN 1 ELSE 0 END) AS encrypted_count,
    MIN(la.modify_date) AS oldest_modify_date,
    CASE la.risk_level
        WHEN 'High' THEN 'Diese Module sollten vor weiterer DDL oder Refaktorierung zuerst reviewt werden.'
        WHEN 'Medium' THEN 'Diese Module sind aelter und sollten beim naechsten Wartungsfenster ueberprueft werden.'
        WHEN 'Low' THEN 'Diese Module sind legacy-nah, aber ohne direktes QUOTED_IDENTIFIER-Fehlsetting.'
        ELSE 'Keine akuten Legacy-Hinweise.'
    END AS summary_note
FROM #LegacyAssessment AS la
WHERE @OnlyFlaggedModules = 0
   OR la.review_status = 'ReviewNeeded'
GROUP BY
    la.risk_level;

SELECT
    rs.risk_level,
    rs.module_count,
    rs.quoted_off_count,
    rs.encrypted_count,
    rs.oldest_modify_date,
    rs.summary_note
FROM #RiskSummary AS rs
ORDER BY
    CASE rs.risk_level
        WHEN 'High' THEN 1
        WHEN 'Medium' THEN 2
        WHEN 'Low' THEN 3
        ELSE 4
    END;

CREATE TABLE #RemediationTemplate
(
    template_name     VARCHAR(60)    NOT NULL,
    template_sql      NVARCHAR(MAX)  NOT NULL,
    usage_hint        VARCHAR(260)   NOT NULL
);

INSERT INTO #RemediationTemplate
(
    template_name,
    template_sql,
    usage_hint
)
VALUES
(
    'QuotedIdentifierModuleReviewTemplate',
    N'-- Review-Vorlage fuer ein gefundenes Legacy-Modul' + CHAR(13) + CHAR(10)
    + N'SET ANSI_NULLS ON;' + CHAR(13) + CHAR(10)
    + N'SET QUOTED_IDENTIFIER ON;' + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10)
    + N'-- 1. Vorhandene Definition aus Quellverwaltung oder OBJECT_DEFINITION sichern' + CHAR(13) + CHAR(10)
    + N'-- 2. CREATE OR ALTER des Moduls in einer Session mit den gewuenschten SET-Optionen ausfuehren' + CHAR(13) + CHAR(10)
    + N'-- 3. Danach dieses Audit erneut starten und uses_quoted_identifier pruefen',
    'Als Checkliste fuer Review oder Neuerstellung gefundener Module verwenden.'
);

SELECT
    rt.template_name,
    rt.template_sql,
    rt.usage_hint
FROM #RemediationTemplate AS rt;
