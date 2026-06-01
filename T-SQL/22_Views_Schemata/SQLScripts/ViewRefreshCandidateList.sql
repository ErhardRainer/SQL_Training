/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "ViewRefreshCandidateList.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "22_Views_Schemata"

purpose: >
  Listet Views, deren Metadaten nach Aenderungen an Abhaengigkeiten
  oder Definitionen voraussichtlich mit einem Refresh abgeglichen
  werden sollten. Das Skript bewertet nur lesend typische Refresh-
  Signale und erzeugt optionale Review-Kommandos.

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
    description: "1 = nur Views mit mindestens einem Refresh-Signal ausgeben"
  - name: "@IncludeRefreshCommands"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zusaetzliches Resultset mit empfohlenen Refresh-Kommandos ausgeben"

result_sets:
  - name: "ViewRefreshCandidates"
    description: "Detailsicht je View mit Refresh-Signalen und empfohlener Aktion"
  - name: "ViewRefreshSummary"
    description: "Verdichtete Sicht pro View mit Anzahl und Staerke der Refresh-Signale"
  - name: "RefreshCommands"
    description: "Optionale Kommandoliste fuer manuelle Refresh-Pruefungen"

dependencies:
  - "sys.views"
  - "sys.schemas"
  - "sys.sql_modules"
  - "sys.sql_expression_dependencies"
  - "sys.objects"
  - "sys.columns"
  - "sp_refreshview"
  - "sp_refreshsqlmodule"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/22_Views_Schemata/SQLScripts/ViewRefreshCandidateList.md"
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
    description: "Erstversion der Refresh-Kandidatenliste fuer Views"

notes:
  - "Das Skript arbeitet rein lesend und nutzt nur Metadaten der aktuellen Datenbank."
  - "Die Kandidatenliste ist eine Review-Hilfe und fuehrt selbst keinen Refresh aus."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @SchemaNameLike SYSNAME = NULL;
DECLARE @OnlyCandidates BIT = 1;
DECLARE @IncludeRefreshCommands BIT = 1;

IF @OnlyCandidates NOT IN (0, 1)
BEGIN
    THROW 50040, '@OnlyCandidates muss 0 oder 1 sein.', 1;
END;

IF @IncludeRefreshCommands NOT IN (0, 1)
BEGIN
    THROW 50041, '@IncludeRefreshCommands muss 0 oder 1 sein.', 1;
END;

IF @SchemaNameLike IS NOT NULL AND LTRIM(RTRIM(@SchemaNameLike)) = ''
BEGIN
    SET @SchemaNameLike = NULL;
END;

DROP TABLE IF EXISTS #ViewInventory;
DROP TABLE IF EXISTS #DependencyFacts;
DROP TABLE IF EXISTS #RefreshCandidates;
DROP TABLE IF EXISTS #RefreshCommands;

CREATE TABLE #ViewInventory
(
    view_object_id       INT             NOT NULL,
    schema_name          SYSNAME         NOT NULL,
    view_name            SYSNAME         NOT NULL,
    full_view_name       NVARCHAR(517)   NOT NULL,
    view_modify_date     DATETIME        NOT NULL,
    uses_schemabinding   BIT             NOT NULL,
    has_select_star      BIT             NOT NULL,
    definition_text      NVARCHAR(MAX)   NOT NULL
);

INSERT INTO #ViewInventory
(
    view_object_id,
    schema_name,
    view_name,
    full_view_name,
    view_modify_date,
    uses_schemabinding,
    has_select_star,
    definition_text
)
SELECT
    v.object_id,
    s.name AS schema_name,
    v.name AS view_name,
    QUOTENAME(s.name) + N'.' + QUOTENAME(v.name) AS full_view_name,
    v.modify_date,
    CONVERT(BIT, OBJECTPROPERTY(v.object_id, 'IsSchemaBound')) AS uses_schemabinding,
    CASE
        WHEN sm.definition LIKE '%SELECT *%' OR sm.definition LIKE '%SELECT%*%'
            THEN 1
        ELSE 0
    END AS has_select_star,
    sm.definition
FROM sys.views AS v
INNER JOIN sys.schemas AS s
    ON s.schema_id = v.schema_id
INNER JOIN sys.sql_modules AS sm
    ON sm.object_id = v.object_id
WHERE @SchemaNameLike IS NULL
   OR s.name LIKE @SchemaNameLike;

CREATE TABLE #DependencyFacts
(
    view_object_id               INT             NOT NULL,
    full_view_name               NVARCHAR(517)   NOT NULL,
    dependency_scope             NVARCHAR(100)   NOT NULL,
    referenced_entity            NVARCHAR(776)   NULL,
    referenced_column            SYSNAME         NULL,
    referenced_modify_date       DATETIME        NULL,
    is_unresolved_reference      BIT             NOT NULL,
    is_missing_column            BIT             NOT NULL,
    is_external_reference        BIT             NOT NULL,
    is_caller_dependent          BIT             NOT NULL,
    base_changed_after_view      BIT             NOT NULL
);

INSERT INTO #DependencyFacts
(
    view_object_id,
    full_view_name,
    dependency_scope,
    referenced_entity,
    referenced_column,
    referenced_modify_date,
    is_unresolved_reference,
    is_missing_column,
    is_external_reference,
    is_caller_dependent,
    base_changed_after_view
)
SELECT
    vi.view_object_id,
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
    ro.modify_date,
    CONVERT(BIT, CASE WHEN sed.referenced_id IS NULL THEN 1 ELSE 0 END) AS is_unresolved_reference,
    CONVERT(BIT, CASE WHEN sed.referenced_minor_id > 0 AND c.column_id IS NULL THEN 1 ELSE 0 END) AS is_missing_column,
    CONVERT(BIT, CASE WHEN sed.referenced_database_name IS NOT NULL OR sed.referenced_server_name IS NOT NULL THEN 1 ELSE 0 END) AS is_external_reference,
    CONVERT(BIT, ISNULL(sed.is_caller_dependent, 0)) AS is_caller_dependent,
    CONVERT(
        BIT,
        CASE
            WHEN ro.modify_date IS NOT NULL AND ro.modify_date > vi.view_modify_date THEN 1
            ELSE 0
        END
    ) AS base_changed_after_view
FROM #ViewInventory AS vi
LEFT JOIN sys.sql_expression_dependencies AS sed
    ON sed.referencing_id = vi.view_object_id
LEFT JOIN sys.objects AS ro
    ON ro.object_id = sed.referenced_id
LEFT JOIN sys.columns AS c
    ON c.object_id = sed.referenced_id
   AND c.column_id = sed.referenced_minor_id;

CREATE TABLE #RefreshCandidates
(
    full_view_name                 NVARCHAR(517)   NOT NULL,
    schema_name                    SYSNAME         NOT NULL,
    view_name                      SYSNAME         NOT NULL,
    view_modify_date               DATETIME        NOT NULL,
    refresh_command_type           NVARCHAR(40)    NOT NULL,
    recommended_refresh_command    NVARCHAR(700)   NOT NULL,
    refresh_signal_count           INT             NOT NULL,
    highest_signal                 VARCHAR(10)     NOT NULL,
    has_unresolved_reference       BIT             NOT NULL,
    has_missing_column             BIT             NOT NULL,
    has_external_reference         BIT             NOT NULL,
    has_caller_dependent_reference BIT             NOT NULL,
    has_base_changed_after_view    BIT             NOT NULL,
    has_select_star_without_binding BIT            NOT NULL,
    recommended_action             NVARCHAR(260)   NOT NULL
);

CREATE TABLE #RefreshCommands
(
    full_view_name                 NVARCHAR(517)   NOT NULL,
    refresh_command_type           NVARCHAR(40)    NOT NULL,
    recommended_refresh_command    NVARCHAR(700)   NOT NULL,
    refresh_reason                 NVARCHAR(260)   NOT NULL
);

INSERT INTO #RefreshCandidates
(
    full_view_name,
    schema_name,
    view_name,
    view_modify_date,
    refresh_command_type,
    recommended_refresh_command,
    refresh_signal_count,
    highest_signal,
    has_unresolved_reference,
    has_missing_column,
    has_external_reference,
    has_caller_dependent_reference,
    has_base_changed_after_view,
    has_select_star_without_binding,
    recommended_action
)
SELECT
    vi.full_view_name,
    vi.schema_name,
    vi.view_name,
    vi.view_modify_date,
    CASE
        WHEN vi.uses_schemabinding = 1 THEN 'sp_refreshsqlmodule'
        ELSE 'sp_refreshview'
    END AS refresh_command_type,
    CASE
        WHEN vi.uses_schemabinding = 1 THEN
            N'EXEC sys.sp_refreshsqlmodule N'''
            + REPLACE(vi.full_view_name, '''', '''''')
            + N''';'
        ELSE
            N'EXEC sys.sp_refreshview N'''
            + REPLACE(vi.full_view_name, '''', '''''')
            + N''';'
    END AS recommended_refresh_command,
    SUM(
        CASE WHEN df.is_unresolved_reference = 1 THEN 1 ELSE 0 END
        + CASE WHEN df.is_missing_column = 1 THEN 1 ELSE 0 END
        + CASE WHEN df.is_external_reference = 1 THEN 1 ELSE 0 END
        + CASE WHEN df.is_caller_dependent = 1 THEN 1 ELSE 0 END
        + CASE WHEN df.base_changed_after_view = 1 THEN 1 ELSE 0 END
    ) + CASE WHEN vi.has_select_star = 1 AND vi.uses_schemabinding = 0 THEN 1 ELSE 0 END AS refresh_signal_count,
    CASE
        WHEN MAX(CASE WHEN df.is_unresolved_reference = 1 OR df.is_missing_column = 1 THEN 1 ELSE 0 END) = 1 THEN 'High'
        WHEN MAX(CASE WHEN df.base_changed_after_view = 1 OR df.is_external_reference = 1 OR df.is_caller_dependent = 1 THEN 1 ELSE 0 END) = 1
             OR (vi.has_select_star = 1 AND vi.uses_schemabinding = 0) THEN 'Medium'
        ELSE 'Info'
    END AS highest_signal,
    MAX(df.is_unresolved_reference) AS has_unresolved_reference,
    MAX(df.is_missing_column) AS has_missing_column,
    MAX(df.is_external_reference) AS has_external_reference,
    MAX(df.is_caller_dependent) AS has_caller_dependent_reference,
    MAX(df.base_changed_after_view) AS has_base_changed_after_view,
    CONVERT(BIT, CASE WHEN vi.has_select_star = 1 AND vi.uses_schemabinding = 0 THEN 1 ELSE 0 END) AS has_select_star_without_binding,
    CASE
        WHEN MAX(CASE WHEN df.is_unresolved_reference = 1 OR df.is_missing_column = 1 THEN 1 ELSE 0 END) = 1 THEN
            N'View-Definition und referenzierte Objekte vor einem Refresh manuell pruefen.'
        WHEN MAX(CASE WHEN df.base_changed_after_view = 1 THEN 1 ELSE 0 END) = 1 THEN
            N'Refresh nach Metadatenaenderung einplanen und Resultset der View erneut testen.'
        WHEN MAX(CASE WHEN df.is_external_reference = 1 OR df.is_caller_dependent = 1 THEN 1 ELSE 0 END) = 1 THEN
            N'Refresh im Zielkontext testen, weil Abhaengigkeiten nicht vollstaendig lokal aufloesbar sind.'
        WHEN vi.has_select_star = 1 AND vi.uses_schemabinding = 0 THEN
            N'View wegen SELECT Stern ohne SCHEMABINDING nach Schemaaenderungen bevorzugt refreshen.'
        ELSE
            N'Keine starken Refresh-Signale; View nur bei gezieltem Review aufnehmen.'
    END AS recommended_action
FROM #ViewInventory AS vi
LEFT JOIN #DependencyFacts AS df
    ON df.view_object_id = vi.view_object_id
GROUP BY
    vi.full_view_name,
    vi.schema_name,
    vi.view_name,
    vi.view_modify_date,
    vi.uses_schemabinding,
    vi.has_select_star;

IF @OnlyCandidates = 1
BEGIN
    SELECT
        rc.full_view_name AS ViewName,
        rc.view_modify_date AS ViewModifyDate,
        rc.refresh_command_type AS RefreshCommandType,
        rc.refresh_signal_count AS RefreshSignalCount,
        rc.highest_signal AS HighestSignal,
        rc.has_unresolved_reference AS HasUnresolvedReference,
        rc.has_missing_column AS HasMissingColumn,
        rc.has_external_reference AS HasExternalReference,
        rc.has_caller_dependent_reference AS HasCallerDependentReference,
        rc.has_base_changed_after_view AS HasBaseChangedAfterView,
        rc.has_select_star_without_binding AS HasSelectStarWithoutBinding,
        rc.recommended_action AS RecommendedAction,
        rc.recommended_refresh_command AS RecommendedRefreshCommand
    FROM #RefreshCandidates AS rc
    WHERE rc.refresh_signal_count > 0
    ORDER BY
        CASE rc.highest_signal
            WHEN 'High' THEN 1
            WHEN 'Medium' THEN 2
            ELSE 3
        END,
        rc.refresh_signal_count DESC,
        rc.full_view_name;
END;
ELSE
BEGIN
    SELECT
        rc.full_view_name AS ViewName,
        rc.view_modify_date AS ViewModifyDate,
        rc.refresh_command_type AS RefreshCommandType,
        rc.refresh_signal_count AS RefreshSignalCount,
        rc.highest_signal AS HighestSignal,
        rc.has_unresolved_reference AS HasUnresolvedReference,
        rc.has_missing_column AS HasMissingColumn,
        rc.has_external_reference AS HasExternalReference,
        rc.has_caller_dependent_reference AS HasCallerDependentReference,
        rc.has_base_changed_after_view AS HasBaseChangedAfterView,
        rc.has_select_star_without_binding AS HasSelectStarWithoutBinding,
        rc.recommended_action AS RecommendedAction,
        rc.recommended_refresh_command AS RecommendedRefreshCommand
    FROM #RefreshCandidates AS rc
    ORDER BY
        CASE rc.highest_signal
            WHEN 'High' THEN 1
            WHEN 'Medium' THEN 2
            ELSE 3
        END,
        rc.refresh_signal_count DESC,
        rc.full_view_name;
END;

SELECT
    rc.highest_signal AS HighestSignal,
    COUNT(*) AS ViewCount,
    SUM(CASE WHEN rc.refresh_signal_count > 0 THEN 1 ELSE 0 END) AS CandidateCount,
    SUM(CASE WHEN rc.has_base_changed_after_view = 1 THEN 1 ELSE 0 END) AS ViewsWithBaseChange,
    SUM(CASE WHEN rc.has_select_star_without_binding = 1 THEN 1 ELSE 0 END) AS ViewsWithSelectStarRisk,
    SUM(CASE WHEN rc.has_unresolved_reference = 1 OR rc.has_missing_column = 1 THEN 1 ELSE 0 END) AS ViewsWithBrokenMetadataSignals
FROM #RefreshCandidates AS rc
WHERE @OnlyCandidates = 0
   OR rc.refresh_signal_count > 0
GROUP BY rc.highest_signal
ORDER BY
    CASE rc.highest_signal
        WHEN 'High' THEN 1
        WHEN 'Medium' THEN 2
        ELSE 3
    END;

IF @IncludeRefreshCommands = 1
BEGIN
    INSERT INTO #RefreshCommands
    (
        full_view_name,
        refresh_command_type,
        recommended_refresh_command,
        refresh_reason
    )
    SELECT
        rc.full_view_name,
        rc.refresh_command_type,
        rc.recommended_refresh_command,
        CASE
            WHEN rc.highest_signal = 'High' THEN N'Hohe Prioritaet wegen aufgeloester oder fehlender Metadaten.'
            WHEN rc.has_base_changed_after_view = 1 THEN N'Basisobjekt wurde nach der View geaendert.'
            WHEN rc.has_select_star_without_binding = 1 THEN N'SELECT Stern ohne SCHEMABINDING reagiert empfindlich auf Schemaaenderungen.'
            WHEN rc.has_external_reference = 1 OR rc.has_caller_dependent_reference = 1 THEN N'Kontextabhaengige oder externe Referenz vor Refresh pruefen.'
            ELSE N'Allgemeiner Review-Kandidat.'
        END AS refresh_reason
    FROM #RefreshCandidates AS rc
    WHERE (@OnlyCandidates = 0 OR rc.refresh_signal_count > 0)
      AND rc.refresh_signal_count > 0;

    SELECT
        full_view_name AS ViewName,
        refresh_command_type AS RefreshCommandType,
        refresh_reason AS RefreshReason,
        recommended_refresh_command AS RecommendedRefreshCommand
    FROM #RefreshCommands
    ORDER BY ViewName;
END;
