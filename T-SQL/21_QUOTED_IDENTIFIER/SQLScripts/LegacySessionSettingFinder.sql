/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "LegacySessionSettingFinder.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "21_QUOTED_IDENTIFIER"

purpose: >
  Findet SQL-Module, die noch mit problematischen Session-Settings wie
  QUOTED_IDENTIFIER OFF oder ANSI_NULLS OFF gespeichert wurden. Das Skript
  eignet sich als Bestandsaufnahme fuer Altmodule und liefert eine
  Review-Hilfe fuer die spaetere technische Bereinigung.

parameters:
  - name: "@SchemaName"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Optionaler Schemaname fuer die Eingrenzung auf ein bestimmtes Schema"
  - name: "@OnlyProblematic"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = nur Module mit problematischen Settings anzeigen; 0 = komplettes Inventar"
  - name: "@IncludeMsShipped"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = systemnahe Objekte einbeziehen; 0 = nur eigene Module betrachten"

result_sets:
  - name: "SettingSummary"
    description: "Aggregierte Uebersicht zu Session-Settings und Problemfaellen"
  - name: "LegacyModuleInventory"
    description: "Inventar betroffener oder optional aller Module mit Bewertung und Review-Hinweisen"
  - name: "ReviewCommands"
    description: "Kompakte Befehle und Header-Vorlagen fuer die manuelle Nachbereitung"

dependencies:
  - "sys.objects"
  - "sys.schemas"
  - "sys.sql_modules"
  - "sp_helptext"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/21_QUOTED_IDENTIFIER/SQLScripts/LegacySessionSettingFinder.md"
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
    description: "Erstversion des Diagnose-Skripts fuer Legacy-Session-Settings"

notes:
  - "Das Skript aendert keine Module, sondern markiert nur Review-Kandidaten."
  - "Problematisch bedeutet hier vor allem QUOTED_IDENTIFIER OFF oder ANSI_NULLS OFF."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @SchemaName SYSNAME = NULL;
DECLARE @OnlyProblematic BIT = 1;
DECLARE @IncludeMsShipped BIT = 0;

IF @OnlyProblematic NOT IN (0, 1)
BEGIN
    THROW 50000, '@OnlyProblematic muss 0 oder 1 sein.', 1;
END;

IF @IncludeMsShipped NOT IN (0, 1)
BEGIN
    THROW 50001, '@IncludeMsShipped muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #ModuleInventory;

CREATE TABLE #ModuleInventory
(
    SchemaName                  SYSNAME         NOT NULL,
    ObjectName                  SYSNAME         NOT NULL,
    ObjectType                  CHAR(2)         NOT NULL,
    ObjectTypeDescription       NVARCHAR(60)    NOT NULL,
    IsMsShipped                 BIT             NOT NULL,
    UsesQuotedIdentifier        BIT             NULL,
    UsesAnsiNulls               BIT             NULL,
    UsesDatabaseCollation       BIT             NULL,
    CreateDate                  DATETIME        NOT NULL,
    ModifyDate                  DATETIME        NOT NULL,
    DefinitionPreview           NVARCHAR(400)   NULL,
    SettingRiskLevel            VARCHAR(16)     NOT NULL,
    RiskReason                  NVARCHAR(220)   NOT NULL,
    SuggestedReviewCommand      NVARCHAR(400)   NOT NULL,
    SuggestedHeaderTemplate     NVARCHAR(400)   NOT NULL
);

WITH ModuleSource AS
(
    SELECT
        s.name AS SchemaName,
        o.name AS ObjectName,
        o.type AS ObjectType,
        o.type_desc AS ObjectTypeDescription,
        CAST(o.is_ms_shipped AS BIT) AS IsMsShipped,
        CAST(sm.uses_quoted_identifier AS BIT) AS UsesQuotedIdentifier,
        CAST(sm.uses_ansi_nulls AS BIT) AS UsesAnsiNulls,
        CAST(sm.uses_database_collation AS BIT) AS UsesDatabaseCollation,
        o.create_date AS CreateDate,
        o.modify_date AS ModifyDate,
        REPLACE(REPLACE(LEFT(LTRIM(RTRIM(sm.definition)), 400), CHAR(13), ' '), CHAR(10), ' ') AS DefinitionPreview
    FROM sys.objects AS o
    INNER JOIN sys.schemas AS s
        ON s.schema_id = o.schema_id
    INNER JOIN sys.sql_modules AS sm
        ON sm.object_id = o.object_id
    WHERE o.type IN ('P', 'V', 'FN', 'IF', 'TF', 'TR')
      AND (@SchemaName IS NULL OR s.name = @SchemaName)
      AND (@IncludeMsShipped = 1 OR o.is_ms_shipped = 0)
)
INSERT INTO #ModuleInventory
(
    SchemaName,
    ObjectName,
    ObjectType,
    ObjectTypeDescription,
    IsMsShipped,
    UsesQuotedIdentifier,
    UsesAnsiNulls,
    UsesDatabaseCollation,
    CreateDate,
    ModifyDate,
    DefinitionPreview,
    SettingRiskLevel,
    RiskReason,
    SuggestedReviewCommand,
    SuggestedHeaderTemplate
)
SELECT
    ms.SchemaName,
    ms.ObjectName,
    ms.ObjectType,
    ms.ObjectTypeDescription,
    ms.IsMsShipped,
    ms.UsesQuotedIdentifier,
    ms.UsesAnsiNulls,
    ms.UsesDatabaseCollation,
    ms.CreateDate,
    ms.ModifyDate,
    ms.DefinitionPreview,
    CASE
        WHEN ms.UsesQuotedIdentifier = 0 AND ms.UsesAnsiNulls = 0 THEN 'high'
        WHEN ms.UsesQuotedIdentifier = 0 OR ms.UsesAnsiNulls = 0 THEN 'medium'
        ELSE 'review'
    END AS SettingRiskLevel,
    CASE
        WHEN ms.UsesQuotedIdentifier = 0 AND ms.UsesAnsiNulls = 0 THEN 'QUOTED_IDENTIFIER OFF und ANSI_NULLS OFF gespeichert'
        WHEN ms.UsesQuotedIdentifier = 0 THEN 'QUOTED_IDENTIFIER OFF gespeichert'
        WHEN ms.UsesAnsiNulls = 0 THEN 'ANSI_NULLS OFF gespeichert'
        ELSE 'Keine der hier geprueften Legacy-Einstellungen erkannt'
    END AS RiskReason,
    'EXEC sys.sp_helptext N'''
        + QUOTENAME(ms.SchemaName) + '.'
        + QUOTENAME(ms.ObjectName) + ''';' AS SuggestedReviewCommand,
    'SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON; -- danach ALTER fuer '
        + QUOTENAME(ms.SchemaName) + '.'
        + QUOTENAME(ms.ObjectName) AS SuggestedHeaderTemplate
FROM ModuleSource AS ms;

SELECT
    COUNT(*) AS ModulesInScope,
    SUM(CASE WHEN mi.UsesQuotedIdentifier = 0 THEN 1 ELSE 0 END) AS ModulesWithQuotedIdentifierOff,
    SUM(CASE WHEN mi.UsesAnsiNulls = 0 THEN 1 ELSE 0 END) AS ModulesWithAnsiNullsOff,
    SUM(CASE WHEN mi.UsesQuotedIdentifier = 0 OR mi.UsesAnsiNulls = 0 THEN 1 ELSE 0 END) AS ProblematicModules,
    SUM(CASE WHEN mi.UsesQuotedIdentifier = 1 AND mi.UsesAnsiNulls = 1 THEN 1 ELSE 0 END) AS ModulesAlreadyAligned
FROM #ModuleInventory AS mi;

SELECT
    mi.SchemaName,
    mi.ObjectName,
    mi.ObjectType,
    mi.ObjectTypeDescription,
    mi.UsesQuotedIdentifier,
    mi.UsesAnsiNulls,
    mi.UsesDatabaseCollation,
    mi.CreateDate,
    mi.ModifyDate,
    mi.SettingRiskLevel,
    mi.RiskReason,
    mi.DefinitionPreview,
    mi.SuggestedReviewCommand,
    mi.SuggestedHeaderTemplate
FROM #ModuleInventory AS mi
WHERE @OnlyProblematic = 0
   OR mi.UsesQuotedIdentifier = 0
   OR mi.UsesAnsiNulls = 0
ORDER BY
    CASE mi.SettingRiskLevel
        WHEN 'high' THEN 1
        WHEN 'medium' THEN 2
        ELSE 3
    END,
    mi.ModifyDate ASC,
    mi.SchemaName ASC,
    mi.ObjectName ASC;

SELECT
    mi.SchemaName,
    mi.ObjectName,
    mi.SettingRiskLevel,
    mi.RiskReason,
    mi.SuggestedReviewCommand,
    mi.SuggestedHeaderTemplate
FROM #ModuleInventory AS mi
WHERE mi.UsesQuotedIdentifier = 0
   OR mi.UsesAnsiNulls = 0
ORDER BY
    mi.SchemaName,
    mi.ObjectName;
