/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "BrokenViewReferenceFinder.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "22_Views_Schemata"

purpose: >
  Findet Views mit potenziell gebrochenen Objekt- oder Spaltenreferenzen.
  Das Skript wertet Metadaten aus sys.views, sys.sql_modules und
  sys.sql_expression_dependencies aus, markiert Warnsignale fuer
  nicht aufloesbare Abhaengigkeiten und erzeugt ein optionales
  Refresh-Template fuer betroffene Views.

parameters:
  - name: "@SchemaNameLike"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Optionales LIKE-Muster fuer die View-Schemata"
  - name: "@OnlyPotentialBreaks"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = nur Views mit Warnsignal oder Risiko ausgeben"
  - name: "@IncludeRefreshCommands"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zusaetzliches Resultset mit sp_refreshview-Kommandos ausgeben"

result_sets:
  - name: "ViewReferenceAudit"
    description: "Detailpruefung je View und referenziertem Objekt oder Spaltenhinweis"
  - name: "ViewRiskSummary"
    description: "Verdichtete Risikoeinstufung pro View mit Anzahl der Warnsignale"
  - name: "RefreshCommands"
    description: "Optionale sp_refreshview-Kommandos fuer Views mit Auffaelligkeiten"

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
  markdown_file: "T-SQL/22_Views_Schemata/SQLScripts/BrokenViewReferenceFinder.md"
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
    description: "Erstversion des View-Referenz-Audits"

notes:
  - "Das Skript bleibt rein lesend und nutzt nur Metadaten aus der aktuellen Datenbank."
  - "Nicht aufloesbare Referenzen werden als potenzielles Risiko markiert und nicht als harter Beweis fuer einen Defekt."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @SchemaNameLike SYSNAME = NULL;
DECLARE @OnlyPotentialBreaks BIT = 0;
DECLARE @IncludeRefreshCommands BIT = 1;

IF @OnlyPotentialBreaks NOT IN (0, 1)
BEGIN
    THROW 50010, '@OnlyPotentialBreaks muss 0 oder 1 sein.', 1;
END;

IF @IncludeRefreshCommands NOT IN (0, 1)
BEGIN
    THROW 50011, '@IncludeRefreshCommands muss 0 oder 1 sein.', 1;
END;

IF @SchemaNameLike IS NOT NULL AND LTRIM(RTRIM(@SchemaNameLike)) = ''
BEGIN
    SET @SchemaNameLike = NULL;
END;

DROP TABLE IF EXISTS #ViewInventory;
DROP TABLE IF EXISTS #DependencyAudit;
DROP TABLE IF EXISTS #ViewRiskSummary;
DROP TABLE IF EXISTS #RefreshCommands;

CREATE TABLE #ViewInventory
(
    view_object_id       INT             NOT NULL,
    schema_name          SYSNAME         NOT NULL,
    view_name            SYSNAME         NOT NULL,
    full_view_name       NVARCHAR(517)   NOT NULL,
    uses_schemabinding   BIT             NOT NULL,
    definition_text      NVARCHAR(MAX)   NOT NULL,
    has_select_star      BIT             NOT NULL
);

INSERT INTO #ViewInventory
(
    view_object_id,
    schema_name,
    view_name,
    full_view_name,
    uses_schemabinding,
    definition_text,
    has_select_star
)
SELECT
    v.object_id,
    s.name AS schema_name,
    v.name AS view_name,
    QUOTENAME(s.name) + N'.' + QUOTENAME(v.name) AS full_view_name,
    CONVERT(BIT, OBJECTPROPERTY(v.object_id, 'IsSchemaBound')),
    sm.definition,
    CASE
        WHEN sm.definition LIKE '%SELECT *%' OR sm.definition LIKE '%SELECT%*%'
            THEN 1
        ELSE 0
    END AS has_select_star
FROM sys.views AS v
INNER JOIN sys.schemas AS s
    ON s.schema_id = v.schema_id
INNER JOIN sys.sql_modules AS sm
    ON sm.object_id = v.object_id
WHERE @SchemaNameLike IS NULL
   OR s.name LIKE @SchemaNameLike;

CREATE TABLE #DependencyAudit
(
    full_view_name               NVARCHAR(517)   NOT NULL,
    schema_name                  SYSNAME         NOT NULL,
    view_name                    SYSNAME         NOT NULL,
    dependency_scope             NVARCHAR(100)   NOT NULL,
    referenced_entity            NVARCHAR(776)   NULL,
    referenced_column            SYSNAME         NULL,
    reference_kind               NVARCHAR(60)    NOT NULL,
    is_schema_bound_reference    BIT             NOT NULL,
    is_caller_dependent          BIT             NOT NULL,
    risk_level                   VARCHAR(10)     NOT NULL,
    finding                      NVARCHAR(260)   NOT NULL,
    recommended_action           NVARCHAR(260)   NOT NULL
);

INSERT INTO #DependencyAudit
(
    full_view_name,
    schema_name,
    view_name,
    dependency_scope,
    referenced_entity,
    referenced_column,
    reference_kind,
    is_schema_bound_reference,
    is_caller_dependent,
    risk_level,
    finding,
    recommended_action
)
SELECT
    vi.full_view_name,
    vi.schema_name,
    vi.view_name,
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
    sed.referenced_class_desc,
    ISNULL(sed.is_schema_bound_reference, 0),
    ISNULL(sed.is_caller_dependent, 0),
    CASE
        WHEN sed.referenced_id IS NULL THEN 'High'
        WHEN sed.referenced_minor_id > 0 AND c.column_id IS NULL THEN 'High'
        WHEN sed.referenced_database_name IS NOT NULL OR sed.referenced_server_name IS NOT NULL THEN 'Medium'
        WHEN vi.has_select_star = 1 AND vi.uses_schemabinding = 0 THEN 'Medium'
        ELSE 'Info'
    END AS risk_level,
    CASE
        WHEN sed.referenced_id IS NULL THEN 'Referenz konnte ueber die Metadaten nicht aufgeloest werden.'
        WHEN sed.referenced_minor_id > 0 AND c.column_id IS NULL THEN 'Spaltenreferenz ist nicht mehr in den Metadaten vorhanden.'
        WHEN sed.referenced_database_name IS NOT NULL OR sed.referenced_server_name IS NOT NULL THEN 'Externe Referenz erhoeht Drift- und Deploy-Risiko.'
        WHEN vi.has_select_star = 1 AND vi.uses_schemabinding = 0 THEN 'SELECT * ohne SCHEMABINDING kann versteckte Schemaaenderungen maskieren.'
        ELSE 'Referenz ist aufloesbar und aktuell sichtbar.'
    END AS finding,
    CASE
        WHEN sed.referenced_id IS NULL THEN 'View-Definition pruefen und Referenzen mit sp_refreshview oder ALTER VIEW neu validieren.'
        WHEN sed.referenced_minor_id > 0 AND c.column_id IS NULL THEN 'Betroffene Spalte oder View-Definition gegen aktuelle Basistabellen abgleichen.'
        WHEN sed.referenced_database_name IS NOT NULL OR sed.referenced_server_name IS NOT NULL THEN 'Cross-Database- oder Cross-Server-Abhaengigkeit in Runbooks und Berechtigungen absichern.'
        WHEN vi.has_select_star = 1 AND vi.uses_schemabinding = 0 THEN 'Explizite Spaltenliste statt SELECT * verwenden und bei Bedarf SCHEMABINDING pruefen.'
        ELSE 'Keine Sofortmassnahme erforderlich.'
    END AS recommended_action
FROM #ViewInventory AS vi
LEFT JOIN sys.sql_expression_dependencies AS sed
    ON sed.referencing_id = vi.view_object_id
LEFT JOIN sys.columns AS c
    ON c.object_id = sed.referenced_id
   AND c.column_id = sed.referenced_minor_id;
WHERE sed.referencing_id IS NOT NULL;

INSERT INTO #DependencyAudit
(
    full_view_name,
    schema_name,
    view_name,
    dependency_scope,
    referenced_entity,
    referenced_column,
    reference_kind,
    is_schema_bound_reference,
    is_caller_dependent,
    risk_level,
    finding,
    recommended_action
)
SELECT
    vi.full_view_name,
    vi.schema_name,
    vi.view_name,
    'definition-scan',
    vi.full_view_name,
    NULL,
    'VIEW_METADATA',
    0,
    0,
    CASE
        WHEN vi.has_select_star = 1 AND vi.uses_schemabinding = 0 THEN 'Medium'
        ELSE 'Info'
    END,
    CASE
        WHEN vi.has_select_star = 1 AND vi.uses_schemabinding = 0 THEN 'View verwendet SELECT * ohne SCHEMABINDING.'
        ELSE 'Keine zusaetzlichen Definition-Warnsignale erkannt.'
    END,
    CASE
        WHEN vi.has_select_star = 1 AND vi.uses_schemabinding = 0 THEN 'Explizite Spaltenliste und optional SCHEMABINDING fuer robustere View-Vertraege einplanen.'
        ELSE 'Keine Sofortmassnahme erforderlich.'
    END
FROM #ViewInventory AS vi;

INSERT INTO #DependencyAudit
(
    full_view_name,
    schema_name,
    view_name,
    dependency_scope,
    referenced_entity,
    referenced_column,
    reference_kind,
    is_schema_bound_reference,
    is_caller_dependent,
    risk_level,
    finding,
    recommended_action
)
SELECT
    vi.full_view_name,
    vi.schema_name,
    vi.view_name,
    'metadata-gap',
    vi.full_view_name,
    NULL,
    'VIEW_METADATA',
    0,
    0,
    'Info',
    'Keine Abhaengigkeiten in sys.sql_expression_dependencies gefunden.',
    'Bei komplexen oder dynamischen Quellen die View-Definition manuell gegen Basistabellen pruefen.'
FROM #ViewInventory AS vi
WHERE NOT EXISTS
(
    SELECT 1
    FROM sys.sql_expression_dependencies AS sed
    WHERE sed.referencing_id = vi.view_object_id
);

CREATE TABLE #ViewRiskSummary
(
    full_view_name              NVARCHAR(517)   NOT NULL,
    uses_schemabinding          BIT             NOT NULL,
    dependency_count            INT             NOT NULL,
    high_risk_findings          INT             NOT NULL,
    medium_risk_findings        INT             NOT NULL,
    unresolved_reference_count  INT             NOT NULL,
    risk_status                 VARCHAR(12)     NOT NULL,
    primary_recommendation      NVARCHAR(260)   NOT NULL
);

INSERT INTO #ViewRiskSummary
(
    full_view_name,
    uses_schemabinding,
    dependency_count,
    high_risk_findings,
    medium_risk_findings,
    unresolved_reference_count,
    risk_status,
    primary_recommendation
)
SELECT
    vi.full_view_name,
    vi.uses_schemabinding,
    COUNT(*) AS dependency_count,
    SUM(CASE WHEN da.risk_level = 'High' THEN 1 ELSE 0 END) AS high_risk_findings,
    SUM(CASE WHEN da.risk_level = 'Medium' THEN 1 ELSE 0 END) AS medium_risk_findings,
    SUM(CASE WHEN da.finding LIKE 'Referenz konnte ueber die Metadaten nicht aufgeloest werden.%' THEN 1 ELSE 0 END) AS unresolved_reference_count,
    CASE
        WHEN SUM(CASE WHEN da.risk_level = 'High' THEN 1 ELSE 0 END) > 0 THEN 'High'
        WHEN SUM(CASE WHEN da.risk_level = 'Medium' THEN 1 ELSE 0 END) > 0 THEN 'Medium'
        ELSE 'Aligned'
    END AS risk_status,
    CASE
        WHEN SUM(CASE WHEN da.risk_level = 'High' THEN 1 ELSE 0 END) > 0 THEN 'View-Definition gegen aktuelle Objekte und Spalten pruefen.'
        WHEN SUM(CASE WHEN da.risk_level = 'Medium' THEN 1 ELSE 0 END) > 0 THEN 'Drift-Risiken dokumentieren und View-Refresh im Wartungsprozess vorsehen.'
        ELSE 'Nur bei Schemaaenderungen erneut pruefen.'
    END AS primary_recommendation
FROM #ViewInventory AS vi
INNER JOIN #DependencyAudit AS da
    ON da.full_view_name = vi.full_view_name
GROUP BY
    vi.full_view_name,
    vi.uses_schemabinding;

SELECT
    da.full_view_name,
    da.dependency_scope,
    da.referenced_entity,
    da.referenced_column,
    da.reference_kind,
    da.is_schema_bound_reference,
    da.is_caller_dependent,
    da.risk_level,
    da.finding,
    da.recommended_action
FROM #DependencyAudit AS da
WHERE @OnlyPotentialBreaks = 0
   OR da.risk_level IN ('High', 'Medium')
ORDER BY
    da.full_view_name,
    CASE da.risk_level
        WHEN 'High' THEN 1
        WHEN 'Medium' THEN 2
        ELSE 3
    END,
    da.dependency_scope,
    da.referenced_entity;

SELECT
    vrs.full_view_name,
    vrs.uses_schemabinding,
    vrs.dependency_count,
    vrs.high_risk_findings,
    vrs.medium_risk_findings,
    vrs.unresolved_reference_count,
    vrs.risk_status,
    vrs.primary_recommendation
FROM #ViewRiskSummary AS vrs
WHERE @OnlyPotentialBreaks = 0
   OR vrs.risk_status IN ('High', 'Medium')
ORDER BY
    CASE vrs.risk_status
        WHEN 'High' THEN 1
        WHEN 'Medium' THEN 2
        ELSE 3
    END,
    vrs.unresolved_reference_count DESC,
    vrs.full_view_name;

CREATE TABLE #RefreshCommands
(
    full_view_name      NVARCHAR(517)   NOT NULL,
    refresh_command     NVARCHAR(700)   NOT NULL,
    execution_hint      NVARCHAR(260)   NOT NULL
);

INSERT INTO #RefreshCommands
(
    full_view_name,
    refresh_command,
    execution_hint
)
SELECT
    vrs.full_view_name,
    N'EXEC sys.sp_refreshview @viewname = N'''
        + REPLACE(vrs.full_view_name, N'''', N'''''')
        + N''';' AS refresh_command,
    N'Nach Pruefung der Basisobjekte in einer kontrollierten Session ausfuehren.'
FROM #ViewRiskSummary AS vrs
WHERE vrs.risk_status IN ('High', 'Medium');

IF @IncludeRefreshCommands = 1
BEGIN
    SELECT
        rc.full_view_name,
        rc.refresh_command,
        rc.execution_hint
    FROM #RefreshCommands AS rc
    ORDER BY rc.full_view_name;
END;
