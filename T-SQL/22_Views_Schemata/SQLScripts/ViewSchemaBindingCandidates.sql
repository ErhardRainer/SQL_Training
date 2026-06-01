/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "ViewSchemaBindingCandidates.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "22_Views_Schemata"

purpose: >
  Markiert Views, die anhand lesbarer Metadaten als Kandidaten fuer
  SCHEMABINDING in Frage kommen koennten. Das Skript bewertet
  typische Ausschlussgruende und erzeugt optional ein Review-
  Template fuer CREATE OR ALTER VIEW WITH SCHEMABINDING.

parameters:
  - name: "@SchemaNameLike"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Optionales LIKE-Muster fuer View-Schemata"
  - name: "@OnlyCandidates"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = nur plausible Kandidaten ausgeben"
  - name: "@IncludeAlterTemplate"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zusaetzliches Resultset mit Review-Templates ausgeben"

result_sets:
  - name: "SchemaBindingCandidateAudit"
    description: "Detailsicht je View mit Ausschlussgruenden, Eignung und Review-Hinweisen"
  - name: "SchemaBindingSummary"
    description: "Verdichtete Sicht nach Eignungsstatus und wichtigsten Ausschlussgruenden"
  - name: "SchemaBindingTemplates"
    description: "Optionale Review-Templates fuer CREATE OR ALTER VIEW WITH SCHEMABINDING"

dependencies:
  - "sys.views"
  - "sys.schemas"
  - "sys.sql_modules"
  - "sys.sql_expression_dependencies"
  - "sys.objects"
  - "sys.columns"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/22_Views_Schemata/SQLScripts/ViewSchemaBindingCandidates.md"
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
    description: "Erstversion des SCHEMABINDING-Kandidaten-Audits fuer Views"

notes:
  - "Das Skript bewertet nur Metadaten der aktuellen Datenbank und nimmt keine Aenderung an Views vor."
  - "Die Kandidatenliste ist eine Review-Hilfe; einzelne Views koennen trotz positiver Heuristik manuelle Anpassungen benoetigen."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @SchemaNameLike SYSNAME = NULL;
DECLARE @OnlyCandidates BIT = 1;
DECLARE @IncludeAlterTemplate BIT = 1;

IF @OnlyCandidates NOT IN (0, 1)
BEGIN
    THROW 50050, '@OnlyCandidates muss 0 oder 1 sein.', 1;
END;

IF @IncludeAlterTemplate NOT IN (0, 1)
BEGIN
    THROW 50051, '@IncludeAlterTemplate muss 0 oder 1 sein.', 1;
END;

IF @SchemaNameLike IS NOT NULL AND LTRIM(RTRIM(@SchemaNameLike)) = ''
BEGIN
    SET @SchemaNameLike = NULL;
END;

DROP TABLE IF EXISTS #ViewInventory;
DROP TABLE IF EXISTS #DependencyFacts;
DROP TABLE IF EXISTS #CandidateAudit;
DROP TABLE IF EXISTS #SchemaBindingTemplates;

CREATE TABLE #ViewInventory
(
    view_object_id         INT             NOT NULL,
    schema_name            SYSNAME         NOT NULL,
    view_name              SYSNAME         NOT NULL,
    full_view_name         NVARCHAR(517)   NOT NULL,
    uses_schemabinding     BIT             NOT NULL,
    definition_text        NVARCHAR(MAX)   NOT NULL,
    normalized_definition  NVARCHAR(MAX)   NOT NULL,
    has_select_star        BIT             NOT NULL,
    has_union_keyword      BIT             NOT NULL,
    has_top_keyword        BIT             NOT NULL,
    view_modify_date       DATETIME        NOT NULL
);

INSERT INTO #ViewInventory
(
    view_object_id,
    schema_name,
    view_name,
    full_view_name,
    uses_schemabinding,
    definition_text,
    normalized_definition,
    has_select_star,
    has_union_keyword,
    has_top_keyword,
    view_modify_date
)
SELECT
    v.object_id,
    s.name AS schema_name,
    v.name AS view_name,
    QUOTENAME(s.name) + N'.' + QUOTENAME(v.name) AS full_view_name,
    CONVERT(BIT, OBJECTPROPERTY(v.object_id, 'IsSchemaBound')) AS uses_schemabinding,
    sm.definition,
    UPPER(REPLACE(REPLACE(REPLACE(sm.definition, CHAR(13), N' '), CHAR(10), N' '), CHAR(9), N' ')) AS normalized_definition,
    CASE
        WHEN sm.definition LIKE '%SELECT *%' OR sm.definition LIKE '%SELECT%*%'
            THEN 1
        ELSE 0
    END AS has_select_star,
    CASE
        WHEN UPPER(sm.definition) LIKE '% UNION %' OR UPPER(sm.definition) LIKE '%UNION ALL%'
            THEN 1
        ELSE 0
    END AS has_union_keyword,
    CASE
        WHEN UPPER(sm.definition) LIKE '% TOP %'
            THEN 1
        ELSE 0
    END AS has_top_keyword,
    v.modify_date
FROM sys.views AS v
INNER JOIN sys.schemas AS s
    ON s.schema_id = v.schema_id
INNER JOIN sys.sql_modules AS sm
    ON sm.object_id = v.object_id
WHERE @SchemaNameLike IS NULL
   OR s.name LIKE @SchemaNameLike;

CREATE TABLE #DependencyFacts
(
    view_object_id              INT             NOT NULL,
    total_dependency_rows       INT             NOT NULL,
    same_database_references    INT             NOT NULL,
    unresolved_references       INT             NOT NULL,
    external_references         INT             NOT NULL,
    caller_dependent_references INT             NOT NULL,
    missing_schema_prefixes     INT             NOT NULL,
    system_object_references    INT             NOT NULL,
    base_object_count           INT             NOT NULL
);

INSERT INTO #DependencyFacts
(
    view_object_id,
    total_dependency_rows,
    same_database_references,
    unresolved_references,
    external_references,
    caller_dependent_references,
    missing_schema_prefixes,
    system_object_references,
    base_object_count
)
SELECT
    vi.view_object_id,
    COUNT(sed.referencing_id) AS total_dependency_rows,
    SUM(
        CASE
            WHEN sed.referenced_id IS NOT NULL
                 AND sed.referenced_database_name IS NULL
                 AND sed.referenced_server_name IS NULL
                THEN 1
            ELSE 0
        END
    ) AS same_database_references,
    SUM(CASE WHEN sed.referenced_id IS NULL THEN 1 ELSE 0 END) AS unresolved_references,
    SUM(
        CASE
            WHEN sed.referenced_database_name IS NOT NULL OR sed.referenced_server_name IS NOT NULL
                THEN 1
            ELSE 0
        END
    ) AS external_references,
    SUM(CASE WHEN ISNULL(sed.is_caller_dependent, 0) = 1 THEN 1 ELSE 0 END) AS caller_dependent_references,
    SUM(
        CASE
            WHEN sed.referenced_id IS NOT NULL
                 AND sed.referenced_database_name IS NULL
                 AND sed.referenced_server_name IS NULL
                 AND sed.referenced_schema_name IS NULL
                THEN 1
            ELSE 0
        END
    ) AS missing_schema_prefixes,
    SUM(CASE WHEN o.is_ms_shipped = 1 THEN 1 ELSE 0 END) AS system_object_references,
    COUNT(DISTINCT sed.referenced_id) AS base_object_count
FROM #ViewInventory AS vi
LEFT JOIN sys.sql_expression_dependencies AS sed
    ON sed.referencing_id = vi.view_object_id
LEFT JOIN sys.objects AS o
    ON o.object_id = sed.referenced_id
GROUP BY
    vi.view_object_id;

CREATE TABLE #CandidateAudit
(
    full_view_name                 NVARCHAR(517)   NOT NULL,
    uses_schemabinding             BIT             NOT NULL,
    view_modify_date               DATETIME        NOT NULL,
    total_dependency_rows          INT             NOT NULL,
    base_object_count              INT             NOT NULL,
    has_select_star                BIT             NOT NULL,
    has_union_keyword              BIT             NOT NULL,
    has_top_keyword                BIT             NOT NULL,
    unresolved_references          INT             NOT NULL,
    external_references            INT             NOT NULL,
    caller_dependent_references    INT             NOT NULL,
    missing_schema_prefixes        INT             NOT NULL,
    system_object_references       INT             NOT NULL,
    candidate_status               VARCHAR(24)     NOT NULL,
    review_priority                VARCHAR(12)     NOT NULL,
    candidate_reason               NVARCHAR(260)   NOT NULL,
    recommended_action             NVARCHAR(320)   NOT NULL,
    review_template                NVARCHAR(MAX)   NULL
);

INSERT INTO #CandidateAudit
(
    full_view_name,
    uses_schemabinding,
    view_modify_date,
    total_dependency_rows,
    base_object_count,
    has_select_star,
    has_union_keyword,
    has_top_keyword,
    unresolved_references,
    external_references,
    caller_dependent_references,
    missing_schema_prefixes,
    system_object_references,
    candidate_status,
    review_priority,
    candidate_reason,
    recommended_action,
    review_template
)
SELECT
    vi.full_view_name,
    vi.uses_schemabinding,
    vi.view_modify_date,
    df.total_dependency_rows,
    df.base_object_count,
    vi.has_select_star,
    vi.has_union_keyword,
    vi.has_top_keyword,
    df.unresolved_references,
    df.external_references,
    df.caller_dependent_references,
    df.missing_schema_prefixes,
    df.system_object_references,
    CASE
        WHEN vi.uses_schemabinding = 1 THEN 'already-bound'
        WHEN df.total_dependency_rows = 0 THEN 'review-needed'
        WHEN vi.has_select_star = 1 THEN 'not-ready'
        WHEN df.unresolved_references > 0 THEN 'not-ready'
        WHEN df.external_references > 0 THEN 'not-ready'
        WHEN df.caller_dependent_references > 0 THEN 'not-ready'
        WHEN df.missing_schema_prefixes > 0 THEN 'review-needed'
        WHEN df.system_object_references > 0 THEN 'review-needed'
        ELSE 'candidate'
    END AS candidate_status,
    CASE
        WHEN vi.uses_schemabinding = 1 THEN 'Info'
        WHEN vi.has_select_star = 1 OR df.unresolved_references > 0 OR df.external_references > 0 THEN 'High'
        WHEN df.caller_dependent_references > 0 OR df.missing_schema_prefixes > 0 THEN 'Medium'
        ELSE 'Low'
    END AS review_priority,
    CASE
        WHEN vi.uses_schemabinding = 1 THEN 'View ist bereits mit SCHEMABINDING erstellt.'
        WHEN df.total_dependency_rows = 0 THEN 'Keine aufloesbaren Abhaengigkeiten in den Metadaten gefunden.'
        WHEN vi.has_select_star = 1 THEN 'SELECT * ist fuer SCHEMABINDING ungeeignet und muss explizit ersetzt werden.'
        WHEN df.unresolved_references > 0 THEN 'Mindestens eine Referenz ist ueber Metadaten nicht aufloesbar.'
        WHEN df.external_references > 0 THEN 'Cross-Database- oder Cross-Server-Referenzen blockieren SCHEMABINDING in Views.'
        WHEN df.caller_dependent_references > 0 THEN 'Caller-dependent Referenzen brauchen vor SCHEMABINDING eine stabile Aufloesung.'
        WHEN df.missing_schema_prefixes > 0 THEN 'Mindestens eine Referenz wirkt nicht explizit schemaqualifiziert.'
        WHEN df.system_object_references > 0 THEN 'Systemobjekte oder Spezialobjekte sollten manuell gegen die Regeln geprueft werden.'
        ELSE 'Lesbare Metadaten zeigen keine offensichtlichen Ausschlussgruende fuer SCHEMABINDING.'
    END AS candidate_reason,
    CASE
        WHEN vi.uses_schemabinding = 1 THEN 'Keine Aktion erforderlich; View dient als Referenz fuer bereits gebundene Definitionen.'
        WHEN vi.has_select_star = 1 THEN 'Explizite Spaltenliste einbauen und Basistabellen mit zweiteiligen Namen referenzieren.'
        WHEN df.unresolved_references > 0 THEN 'View-Definition und Basiskontext manuell pruefen, bis alle Referenzen stabil aufloesbar sind.'
        WHEN df.external_references > 0 THEN 'Externe Referenzen entfernen oder Architektur ohne SCHEMABINDING beibehalten.'
        WHEN df.caller_dependent_references > 0 THEN 'Objektnamen eindeutig qualifizieren und im Zielschema fest verankern.'
        WHEN df.missing_schema_prefixes > 0 THEN 'Alle Objektbezeichner mit explizitem Schema versehen und danach erneut validieren.'
        WHEN df.system_object_references > 0 THEN 'Regeln fuer die verwendeten Systemobjekte pruefen und danach manuell testen.'
        WHEN df.total_dependency_rows = 0 THEN 'Definition gegen den echten SQL-Text pruefen; Metadaten alleine reichen hier nicht fuer eine Freigabe.'
        ELSE 'CREATE OR ALTER VIEW ... WITH SCHEMABINDING als Review-Template pruefen und anschliessend Tests fuer Resultset und Berechtigungen ausfuehren.'
    END AS recommended_action,
    CASE
        WHEN vi.uses_schemabinding = 0
             AND df.total_dependency_rows > 0
             AND vi.has_select_star = 0
             AND df.unresolved_references = 0
             AND df.external_references = 0
             AND df.caller_dependent_references = 0
            THEN N'-- Review template: pruefe alle SCHEMABINDING-Regeln, ersetze CREATE VIEW durch CREATE OR ALTER VIEW'
                 + CHAR(13) + CHAR(10)
                 + N'-- und fuege WITH SCHEMABINDING unmittelbar vor AS der finalen Definition ein.'
                 + CHAR(13) + CHAR(10)
                 + N'-- Originaldefinition zur manuellen Ueberarbeitung:'
                 + CHAR(13) + CHAR(10)
                 + vi.definition_text
        ELSE NULL
    END AS review_template
FROM #ViewInventory AS vi
INNER JOIN #DependencyFacts AS df
    ON df.view_object_id = vi.view_object_id;

SELECT
    ca.full_view_name AS ViewName,
    ca.candidate_status AS CandidateStatus,
    ca.review_priority AS ReviewPriority,
    ca.uses_schemabinding AS UsesSchemaBinding,
    ca.base_object_count AS BaseObjectCount,
    ca.total_dependency_rows AS DependencyRows,
    ca.has_select_star AS HasSelectStar,
    ca.has_union_keyword AS HasUnionKeyword,
    ca.has_top_keyword AS HasTopKeyword,
    ca.unresolved_references AS UnresolvedReferences,
    ca.external_references AS ExternalReferences,
    ca.caller_dependent_references AS CallerDependentReferences,
    ca.missing_schema_prefixes AS MissingSchemaPrefixes,
    ca.system_object_references AS SystemObjectReferences,
    ca.candidate_reason AS CandidateReason,
    ca.recommended_action AS RecommendedAction
FROM #CandidateAudit AS ca
WHERE @OnlyCandidates = 0
   OR ca.candidate_status = 'candidate'
ORDER BY
    CASE ca.candidate_status
        WHEN 'candidate' THEN 1
        WHEN 'review-needed' THEN 2
        WHEN 'already-bound' THEN 3
        ELSE 4
    END,
    CASE ca.review_priority
        WHEN 'High' THEN 1
        WHEN 'Medium' THEN 2
        WHEN 'Low' THEN 3
        ELSE 4
    END,
    ca.full_view_name;

SELECT
    ca.candidate_status AS CandidateStatus,
    COUNT(*) AS ViewCount,
    SUM(CASE WHEN ca.has_select_star = 1 THEN 1 ELSE 0 END) AS ViewsWithSelectStar,
    SUM(CASE WHEN ca.unresolved_references > 0 THEN 1 ELSE 0 END) AS ViewsWithUnresolvedReferences,
    SUM(CASE WHEN ca.external_references > 0 THEN 1 ELSE 0 END) AS ViewsWithExternalReferences,
    SUM(CASE WHEN ca.missing_schema_prefixes > 0 THEN 1 ELSE 0 END) AS ViewsWithMissingSchemaPrefixes
FROM #CandidateAudit AS ca
WHERE @OnlyCandidates = 0
   OR ca.candidate_status = 'candidate'
GROUP BY ca.candidate_status
ORDER BY
    CASE ca.candidate_status
        WHEN 'candidate' THEN 1
        WHEN 'review-needed' THEN 2
        WHEN 'already-bound' THEN 3
        ELSE 4
    END;

IF @IncludeAlterTemplate = 1
BEGIN
    CREATE TABLE #SchemaBindingTemplates
    (
        full_view_name        NVARCHAR(517)   NOT NULL,
        candidate_status      VARCHAR(24)     NOT NULL,
        template_note         NVARCHAR(260)   NOT NULL,
        review_template       NVARCHAR(MAX)   NOT NULL
    );

    INSERT INTO #SchemaBindingTemplates
    (
        full_view_name,
        candidate_status,
        template_note,
        review_template
    )
    SELECT
        ca.full_view_name,
        ca.candidate_status,
        CASE
            WHEN ca.candidate_status = 'candidate' THEN 'Template vor Deployment gegen alle SCHEMABINDING-Regeln und Resultsets pruefen.'
            ELSE 'Kein Template verfuegbar.'
        END AS template_note,
        ca.review_template
    FROM #CandidateAudit AS ca
    WHERE ca.review_template IS NOT NULL
      AND (@OnlyCandidates = 0 OR ca.candidate_status = 'candidate');

    SELECT
        full_view_name AS ViewName,
        candidate_status AS CandidateStatus,
        template_note AS TemplateNote,
        review_template AS ReviewTemplate
    FROM #SchemaBindingTemplates
    ORDER BY ViewName;
END;
