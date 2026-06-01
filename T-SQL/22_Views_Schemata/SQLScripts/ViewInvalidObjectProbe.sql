/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "ViewInvalidObjectProbe.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "22_Views_Schemata"

purpose: >
  Prueft Views auf ungueltige, nicht aufloesbare oder potenziell veraltete
  Objekt- und Spaltenreferenzen. Das Skript wertet die Metadaten aus
  sys.views, sys.sql_modules, sys.sql_expression_dependencies, sys.objects
  und sys.columns aus und verdichtet die Auffaelligkeiten je View.

parameters:
  - name: "@SchemaNameLike"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Optionales LIKE-Muster fuer das Schema der zu pruefenden Views"
  - name: "@ViewNameLike"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Optionales LIKE-Muster fuer die zu pruefenden View-Namen"
  - name: "@OnlyProblems"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = nur problematische Referenzen und Views ausgeben"
  - name: "@IncludeRefreshCommands"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zusaetzliches Resultset mit sp_refreshview-Kommandos ausgeben"

result_sets:
  - name: "ViewInvalidReferenceDetail"
    description: "Detailsicht auf ungueltige oder auffaellige View-Referenzen"
  - name: "ViewInvalidReferenceSummary"
    description: "Verdichtete Problemsicht pro View mit Prioritaet und Empfehlung"
  - name: "RefreshCommands"
    description: "Optionale sp_refreshview-Kommandos fuer Views mit Warnsignal"

dependencies:
  - "sys.views"
  - "sys.schemas"
  - "sys.sql_modules"
  - "sys.sql_expression_dependencies"
  - "sys.objects"
  - "sys.columns"
  - "sp_refreshview"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/22_Views_Schemata/SQLScripts/ViewInvalidObjectProbe.md"
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
    description: "Erstversion der Probe auf ungueltige View-Referenzen"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @SchemaNameLike SYSNAME = NULL;
DECLARE @ViewNameLike SYSNAME = NULL;
DECLARE @OnlyProblems BIT = 1;
DECLARE @IncludeRefreshCommands BIT = 1;

IF @OnlyProblems NOT IN (0, 1)
BEGIN
    THROW 50020, '@OnlyProblems muss 0 oder 1 sein.', 1;
END;

IF @IncludeRefreshCommands NOT IN (0, 1)
BEGIN
    THROW 50021, '@IncludeRefreshCommands muss 0 oder 1 sein.', 1;
END;

IF @SchemaNameLike IS NOT NULL AND LTRIM(RTRIM(@SchemaNameLike)) = ''
BEGIN
    SET @SchemaNameLike = NULL;
END;

IF @ViewNameLike IS NOT NULL AND LTRIM(RTRIM(@ViewNameLike)) = ''
BEGIN
    SET @ViewNameLike = NULL;
END;

DROP TABLE IF EXISTS #ViewInventory;
DROP TABLE IF EXISTS #ReferenceProbe;
DROP TABLE IF EXISTS #ViewSummary;
DROP TABLE IF EXISTS #RefreshCommands;

CREATE TABLE #ViewInventory
(
    view_object_id       INT            NOT NULL,
    schema_name          SYSNAME        NOT NULL,
    view_name            SYSNAME        NOT NULL,
    full_view_name       NVARCHAR(517)  NOT NULL,
    view_definition      NVARCHAR(MAX)  NOT NULL,
    uses_schemabinding   BIT            NOT NULL
);

INSERT INTO #ViewInventory
(
    view_object_id,
    schema_name,
    view_name,
    full_view_name,
    view_definition,
    uses_schemabinding
)
SELECT
    v.object_id,
    s.name AS schema_name,
    v.name AS view_name,
    QUOTENAME(s.name) + N'.' + QUOTENAME(v.name) AS full_view_name,
    sm.definition,
    CONVERT(BIT, OBJECTPROPERTY(v.object_id, 'IsSchemaBound'))
FROM sys.views AS v
INNER JOIN sys.schemas AS s
    ON s.schema_id = v.schema_id
INNER JOIN sys.sql_modules AS sm
    ON sm.object_id = v.object_id
WHERE (@SchemaNameLike IS NULL OR s.name LIKE @SchemaNameLike)
  AND (@ViewNameLike IS NULL OR v.name LIKE @ViewNameLike);

CREATE TABLE #ReferenceProbe
(
    full_view_name             NVARCHAR(517)  NOT NULL,
    dependency_scope           NVARCHAR(100)  NOT NULL,
    referenced_entity          NVARCHAR(776)  NULL,
    referenced_column          SYSNAME        NULL,
    reference_state            VARCHAR(30)    NOT NULL,
    severity                   VARCHAR(12)    NOT NULL,
    finding                    NVARCHAR(260)  NOT NULL,
    recommended_action         NVARCHAR(260)  NOT NULL
);

INSERT INTO #ReferenceProbe
(
    full_view_name,
    dependency_scope,
    referenced_entity,
    referenced_column,
    reference_state,
    severity,
    finding,
    recommended_action
)
SELECT
    vi.full_view_name,
    CASE
        WHEN sed.referenced_server_name IS NOT NULL THEN 'cross-server'
        WHEN sed.referenced_database_name IS NOT NULL THEN 'cross-database'
        WHEN sed.referenced_schema_name IS NOT NULL THEN 'same-database'
        ELSE 'implicit-or-unresolved'
    END AS dependency_scope,
    COALESCE(
        CASE
            WHEN sed.referenced_id IS NOT NULL THEN
                QUOTENAME(OBJECT_SCHEMA_NAME(sed.referenced_id))
                + N'.'
                + QUOTENAME(OBJECT_NAME(sed.referenced_id))
        END,
        CASE
            WHEN sed.referenced_schema_name IS NOT NULL AND sed.referenced_entity_name IS NOT NULL THEN
                QUOTENAME(sed.referenced_schema_name) + N'.' + QUOTENAME(sed.referenced_entity_name)
            WHEN sed.referenced_entity_name IS NOT NULL THEN
                QUOTENAME(sed.referenced_entity_name)
            ELSE
                N'(unresolved reference)'
        END
    ) AS referenced_entity,
    CASE
        WHEN sed.referenced_minor_id > 0 THEN COALESCE(c.name, N'(missing column)')
        ELSE NULL
    END AS referenced_column,
    CASE
        WHEN sed.referenced_database_name IS NOT NULL
             OR sed.referenced_server_name IS NOT NULL THEN 'ExternalReference'
        WHEN sed.referenced_id IS NULL
             AND sed.referenced_entity_name IS NOT NULL THEN 'MissingObject'
        WHEN sed.referenced_minor_id > 0
             AND sed.referenced_id IS NOT NULL
             AND c.column_id IS NULL THEN 'MissingColumn'
        WHEN sed.referenced_id IS NULL
             AND sed.referenced_entity_name IS NULL THEN 'UnresolvedName'
        ELSE 'Resolved'
    END AS reference_state,
    CASE
        WHEN sed.referenced_database_name IS NOT NULL
             OR sed.referenced_server_name IS NOT NULL THEN 'Warning'
        WHEN sed.referenced_id IS NULL
             AND sed.referenced_entity_name IS NOT NULL THEN 'Critical'
        WHEN sed.referenced_minor_id > 0
             AND sed.referenced_id IS NOT NULL
             AND c.column_id IS NULL THEN 'Critical'
        WHEN sed.referenced_id IS NULL
             AND sed.referenced_entity_name IS NULL THEN 'Warning'
        ELSE 'Info'
    END AS severity,
    CASE
        WHEN sed.referenced_database_name IS NOT NULL
             OR sed.referenced_server_name IS NOT NULL THEN 'Externe Referenz erhoeht das Risiko fuer defekte Views nach Deployments.'
        WHEN sed.referenced_id IS NULL
             AND sed.referenced_entity_name IS NOT NULL THEN 'Objektreferenz ist in den Metadaten nicht mehr aufloesbar.'
        WHEN sed.referenced_minor_id > 0
             AND sed.referenced_id IS NOT NULL
             AND c.column_id IS NULL THEN 'Spaltenreferenz ist in den aktuellen Metadaten nicht mehr vorhanden.'
        WHEN sed.referenced_id IS NULL
             AND sed.referenced_entity_name IS NULL THEN 'Referenz konnte nicht eindeutig gegen ein Objekt aufgeloest werden.'
        ELSE 'Referenz ist in den Metadaten aufloesbar.'
    END AS finding,
    CASE
        WHEN sed.referenced_database_name IS NOT NULL
             OR sed.referenced_server_name IS NOT NULL THEN 'Externe Abhaengigkeit dokumentieren und in Deployments explizit pruefen.'
        WHEN sed.referenced_id IS NULL
             AND sed.referenced_entity_name IS NOT NULL THEN 'Basisobjekt pruefen und View mit ALTER VIEW oder sp_refreshview neu validieren.'
        WHEN sed.referenced_minor_id > 0
             AND sed.referenced_id IS NOT NULL
             AND c.column_id IS NULL THEN 'Spaltenliste der View gegen die aktuelle Tabellenstruktur abgleichen.'
        WHEN sed.referenced_id IS NULL
             AND sed.referenced_entity_name IS NULL THEN 'View-Definition und indirekte Abhaengigkeiten manuell pruefen.'
        ELSE 'Keine Sofortmassnahme erforderlich.'
    END AS recommended_action
FROM #ViewInventory AS vi
LEFT JOIN sys.sql_expression_dependencies AS sed
    ON sed.referencing_id = vi.view_object_id
LEFT JOIN sys.columns AS c
    ON c.object_id = sed.referenced_id
   AND c.column_id = sed.referenced_minor_id
WHERE sed.referencing_id IS NOT NULL;

INSERT INTO #ReferenceProbe
(
    full_view_name,
    dependency_scope,
    referenced_entity,
    referenced_column,
    reference_state,
    severity,
    finding,
    recommended_action
)
SELECT
    vi.full_view_name,
    'metadata-gap',
    vi.full_view_name,
    NULL,
    'UnresolvedName',
    'Warning',
    'Fuer die View wurden keine aufloesbaren Zeilen in sys.sql_expression_dependencies gefunden.',
    'View-Definition manuell pruefen und bei Bedarf mit sp_refreshview aktualisieren.'
FROM #ViewInventory AS vi
WHERE NOT EXISTS
(
    SELECT 1
    FROM sys.sql_expression_dependencies AS sed
    WHERE sed.referencing_id = vi.view_object_id
);

CREATE TABLE #ViewSummary
(
    full_view_name              NVARCHAR(517)  NOT NULL,
    uses_schemabinding          BIT            NOT NULL,
    critical_findings           INT            NOT NULL,
    warning_findings            INT            NOT NULL,
    invalid_object_count        INT            NOT NULL,
    invalid_column_count        INT            NOT NULL,
    health_status               VARCHAR(12)    NOT NULL,
    primary_recommendation      NVARCHAR(260)  NOT NULL
);

INSERT INTO #ViewSummary
(
    full_view_name,
    uses_schemabinding,
    critical_findings,
    warning_findings,
    invalid_object_count,
    invalid_column_count,
    health_status,
    primary_recommendation
)
SELECT
    vi.full_view_name,
    vi.uses_schemabinding,
    SUM(CASE WHEN rp.severity = 'Critical' THEN 1 ELSE 0 END) AS critical_findings,
    SUM(CASE WHEN rp.severity = 'Warning' THEN 1 ELSE 0 END) AS warning_findings,
    SUM(CASE WHEN rp.reference_state = 'MissingObject' THEN 1 ELSE 0 END) AS invalid_object_count,
    SUM(CASE WHEN rp.reference_state = 'MissingColumn' THEN 1 ELSE 0 END) AS invalid_column_count,
    CASE
        WHEN SUM(CASE WHEN rp.severity = 'Critical' THEN 1 ELSE 0 END) > 0 THEN 'Critical'
        WHEN SUM(CASE WHEN rp.severity = 'Warning' THEN 1 ELSE 0 END) > 0 THEN 'Warning'
        ELSE 'Healthy'
    END AS health_status,
    CASE
        WHEN SUM(CASE WHEN rp.reference_state IN ('MissingObject', 'MissingColumn') THEN 1 ELSE 0 END) > 0 THEN
            'View-Definition mit aktuellen Basisobjekten vergleichen und anschliessend neu validieren.'
        WHEN SUM(CASE WHEN rp.severity = 'Warning' THEN 1 ELSE 0 END) > 0 THEN
            'Unklare oder externe Abhaengigkeiten im Wartungsprozess dokumentieren.'
        ELSE
            'Nur nach Schemaaenderungen erneut pruefen.'
    END AS primary_recommendation
FROM #ViewInventory AS vi
INNER JOIN #ReferenceProbe AS rp
    ON rp.full_view_name = vi.full_view_name
GROUP BY
    vi.full_view_name,
    vi.uses_schemabinding;

SELECT
    rp.full_view_name,
    rp.dependency_scope,
    rp.referenced_entity,
    rp.referenced_column,
    rp.reference_state,
    rp.severity,
    rp.finding,
    rp.recommended_action
FROM #ReferenceProbe AS rp
WHERE @OnlyProblems = 0
   OR rp.severity IN ('Critical', 'Warning')
ORDER BY
    rp.full_view_name,
    CASE rp.severity
        WHEN 'Critical' THEN 1
        WHEN 'Warning' THEN 2
        ELSE 3
    END,
    rp.reference_state,
    rp.referenced_entity;

SELECT
    vs.full_view_name,
    vs.uses_schemabinding,
    vs.critical_findings,
    vs.warning_findings,
    vs.invalid_object_count,
    vs.invalid_column_count,
    vs.health_status,
    vs.primary_recommendation
FROM #ViewSummary AS vs
WHERE @OnlyProblems = 0
   OR vs.health_status IN ('Critical', 'Warning')
ORDER BY
    CASE vs.health_status
        WHEN 'Critical' THEN 1
        WHEN 'Warning' THEN 2
        ELSE 3
    END,
    vs.invalid_object_count DESC,
    vs.invalid_column_count DESC,
    vs.full_view_name;

CREATE TABLE #RefreshCommands
(
    full_view_name      NVARCHAR(517)  NOT NULL,
    refresh_command     NVARCHAR(700)  NOT NULL,
    execution_hint      NVARCHAR(260)  NOT NULL
);

INSERT INTO #RefreshCommands
(
    full_view_name,
    refresh_command,
    execution_hint
)
SELECT
    vs.full_view_name,
    N'EXEC sys.sp_refreshview @viewname = N'''
        + REPLACE(vs.full_view_name, N'''', N'''''')
        + N''';' AS refresh_command,
    N'Nur nach Pruefung der Basisobjekte in einer kontrollierten Session ausfuehren.'
FROM #ViewSummary AS vs
WHERE vs.health_status IN ('Critical', 'Warning');

IF @IncludeRefreshCommands = 1
BEGIN
    SELECT
        rc.full_view_name,
        rc.refresh_command,
        rc.execution_hint
    FROM #RefreshCommands AS rc
    ORDER BY rc.full_view_name;
END;
