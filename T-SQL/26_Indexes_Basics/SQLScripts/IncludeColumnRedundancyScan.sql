/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "IncludeColumnRedundancyScan.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "26_Indexes_Basics"

purpose: >
  Scannt Nichtclustered-Indizes auf explizite Include-Spalten, die bereits
  implizit ueber den Clusterschluessel in den Blattseiten vorhanden sind.

parameters:
  - name: "@SchemaName"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Optionaler Filter auf ein Schema"
  - name: "@TableName"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Optionaler Filter auf einen Tabellennamen"
  - name: "@OnlyRedundant"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = nur redundante Include-Spalten zeigen, 0 = alle Include-Spalten mit Klassifikation zeigen"

result_sets:
  - name: "IncludedColumnReview"
    description: "Detailansicht je Include-Spalte mit Einstufung auf Redundanz gegen den Clusterschluessel"
  - name: "IndexRedundancySummary"
    description: "Verdichtung je Index mit Anzahl gepruefter und redundant wirkender Include-Spalten"

dependencies:
  - "sys.tables"
  - "sys.schemas"
  - "sys.indexes"
  - "sys.index_columns"
  - "sys.columns"
  - "CTE"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/26_Indexes_Basics/SQLScripts/IncludeColumnRedundancyScan.md"
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
    date: "2026-04-17"
    user: "ER"
    description: "Erstversion fuer den Scan redundanter Include-Spalten"

notes:
  - "Das Skript bewertet Redundanz konservativ nur gegen Clusterschluessel-Spalten derselben Tabelle"
  - "Die Ausgabe ist fuer Review und Unterricht gedacht und ersetzt keine Workload-Validierung vor Indexaenderungen"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @SchemaName SYSNAME = NULL;
DECLARE @TableName SYSNAME = NULL;
DECLARE @OnlyRedundant BIT = 1;

IF @OnlyRedundant NOT IN (0, 1)
BEGIN
    THROW 50000, '@OnlyRedundant muss 0 oder 1 sein.', 1;
END;

;WITH TargetIndexes AS
(
    SELECT
        s.name AS SchemaName,
        t.name AS TableName,
        t.object_id,
        i.index_id,
        i.name AS IndexName,
        i.type_desc,
        i.fill_factor,
        i.has_filter,
        i.filter_definition
    FROM sys.tables AS t
    INNER JOIN sys.schemas AS s
        ON s.schema_id = t.schema_id
    INNER JOIN sys.indexes AS i
        ON i.object_id = t.object_id
    WHERE t.is_ms_shipped = 0
      AND i.type = 2
      AND i.is_hypothetical = 0
      AND i.is_disabled = 0
      AND (@SchemaName IS NULL OR s.name = @SchemaName)
      AND (@TableName IS NULL OR t.name = @TableName)
),
IncludedColumns AS
(
    SELECT
        ti.SchemaName,
        ti.TableName,
        ti.object_id,
        ti.index_id,
        ti.IndexName,
        ti.type_desc,
        ti.fill_factor,
        ti.has_filter,
        ti.filter_definition,
        ic.index_column_id AS IncludedColumnOrder,
        c.column_id,
        c.name AS IncludedColumnName
    FROM TargetIndexes AS ti
    INNER JOIN sys.index_columns AS ic
        ON ic.object_id = ti.object_id
       AND ic.index_id = ti.index_id
    INNER JOIN sys.columns AS c
        ON c.object_id = ic.object_id
       AND c.column_id = ic.column_id
    WHERE ic.is_included_column = 1
),
ClusteredKeyColumns AS
(
    SELECT
        ci.object_id,
        ci.name AS ClusteredIndexName,
        ic.column_id,
        ic.key_ordinal,
        c.name AS ClusteredKeyColumnName
    FROM sys.indexes AS ci
    INNER JOIN sys.index_columns AS ic
        ON ic.object_id = ci.object_id
       AND ic.index_id = ci.index_id
    INNER JOIN sys.columns AS c
        ON c.object_id = ic.object_id
       AND c.column_id = ic.column_id
    WHERE ci.type = 1
      AND ic.is_included_column = 0
      AND ic.key_ordinal > 0
),
ClassifiedIncludeColumns AS
(
    SELECT
        DB_NAME() AS DatabaseName,
        ic.SchemaName,
        ic.TableName,
        ic.IndexName,
        ic.type_desc AS IndexType,
        ic.IncludedColumnOrder,
        ic.IncludedColumnName,
        ck.ClusteredIndexName,
        ck.ClusteredKeyColumnName,
        ck.key_ordinal AS ClusteredKeyOrdinal,
        ic.fill_factor,
        ic.has_filter,
        ic.filter_definition,
        CAST(CASE WHEN ck.column_id IS NOT NULL THEN 1 ELSE 0 END AS BIT) AS IsRedundant,
        CASE
            WHEN ck.column_id IS NOT NULL THEN 'Included column is already carried in every nonclustered leaf row via the clustered key.'
            ELSE 'No direct redundancy against the clustered key detected.'
        END AS RedundancyReason,
        CASE
            WHEN ck.column_id IS NOT NULL THEN 'Review INCLUDE list and validate whether the explicit column can be removed.'
            ELSE 'Keep under review; no clustered-key overlap found.'
        END AS SuggestedAction
    FROM IncludedColumns AS ic
    LEFT JOIN ClusteredKeyColumns AS ck
        ON ck.object_id = ic.object_id
       AND ck.column_id = ic.column_id
)
SELECT
    cic.DatabaseName,
    cic.SchemaName,
    cic.TableName,
    cic.IndexName,
    cic.IndexType,
    cic.IncludedColumnOrder,
    cic.IncludedColumnName,
    cic.ClusteredIndexName,
    cic.ClusteredKeyColumnName,
    cic.ClusteredKeyOrdinal,
    cic.fill_factor AS FillFactor,
    CAST(cic.has_filter AS BIT) AS HasFilter,
    cic.filter_definition AS FilterDefinition,
    cic.IsRedundant,
    cic.RedundancyReason,
    cic.SuggestedAction
FROM ClassifiedIncludeColumns AS cic
WHERE @OnlyRedundant = 0
   OR cic.IsRedundant = 1
ORDER BY
    cic.IsRedundant DESC,
    cic.SchemaName,
    cic.TableName,
    cic.IndexName,
    cic.IncludedColumnOrder;

SELECT
    cic.DatabaseName,
    cic.SchemaName,
    cic.TableName,
    cic.IndexName,
    cic.IndexType,
    COUNT(*) AS IncludedColumnCount,
    SUM(CASE WHEN cic.IsRedundant = 1 THEN 1 ELSE 0 END) AS RedundantIncludedColumnCount,
    CAST(100.0 * SUM(CASE WHEN cic.IsRedundant = 1 THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0) AS DECIMAL(6,2)) AS RedundantSharePercent,
    MAX(cic.ClusteredIndexName) AS ClusteredIndexName,
    MAX(CASE WHEN cic.has_filter = 1 THEN 'Filtered index' ELSE 'Unfiltered index' END) AS FilterClassification
FROM ClassifiedIncludeColumns AS cic
GROUP BY
    cic.DatabaseName,
    cic.SchemaName,
    cic.TableName,
    cic.IndexName,
    cic.IndexType
HAVING @OnlyRedundant = 0
    OR SUM(CASE WHEN cic.IsRedundant = 1 THEN 1 ELSE 0 END) > 0
ORDER BY
    RedundantIncludedColumnCount DESC,
    IncludedColumnCount DESC,
    cic.SchemaName,
    cic.TableName,
    cic.IndexName;
