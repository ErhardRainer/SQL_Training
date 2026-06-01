/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "IncludedColumnWidthAudit.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "26_Indexes_Basics"
purpose: >
  Bewertet breite Include-Spalten in Nichtclustered-Indizes und schaetzt
  ihre Wirkung auf Leaf-Breite und Seitendichte.
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
  - name: "@WarnIncludedBytes"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Schwellwert fuer die geschaetzte Include-Gesamtbreite"
  - name: "@WarnLeafBytes"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Schwellwert fuer die geschaetzte Leaf-Zeilenbreite"
  - name: "@ShowOnlyFlagged"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = nur markierte Faelle, 0 = alle Faelle"
result_sets:
  - name: "IndexWidthSummary"
    description: "Summary je Nichtclustered-Index"
  - name: "IncludedColumnWidthDetail"
    description: "Detailansicht je Include-Spalte"
dependencies:
  - "sys.tables"
  - "sys.schemas"
  - "sys.indexes"
  - "sys.index_columns"
  - "sys.columns"
  - "sys.types"
  - "CTE"
safety:
  level: "read-only"
  writes_data: false
documentation:
  markdown_file: "T-SQL/26_Indexes_Basics/SQLScripts/IncludedColumnWidthAudit.md"
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
    description: "Erstversion fuer das Audit breiter Include-Spalten"
notes:
  - "Breiten sind Metadatenheuristiken und keine physische Seitenausmessung"
  - "Clustered-Key oder Heap-RID werden als Locator zur Leaf-Breite addiert"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @SchemaName SYSNAME = NULL;
DECLARE @TableName SYSNAME = NULL;
DECLARE @WarnIncludedBytes INT = 256;
DECLARE @WarnLeafBytes INT = 512;
DECLARE @ShowOnlyFlagged BIT = 1;

IF @WarnIncludedBytes < 0 THROW 50000, '@WarnIncludedBytes darf nicht negativ sein.', 1;
IF @WarnLeafBytes < 1 THROW 50000, '@WarnLeafBytes muss groesser oder gleich 1 sein.', 1;
IF @ShowOnlyFlagged NOT IN (0, 1) THROW 50000, '@ShowOnlyFlagged muss 0 oder 1 sein.', 1;

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
ColumnBytes AS
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
        ic.index_column_id,
        ic.key_ordinal,
        ic.is_included_column,
        c.name AS ColumnName,
        CASE
            WHEN c.max_length = -1 THEN CONCAT(bt.name, '(max)')
            WHEN bt.name IN ('nchar', 'nvarchar') THEN CONCAT(bt.name, '(', c.max_length / 2, ')')
            WHEN bt.name IN ('char', 'varchar', 'binary', 'varbinary') THEN CONCAT(bt.name, '(', c.max_length, ')')
            WHEN bt.name IN ('decimal', 'numeric') THEN CONCAT(bt.name, '(', c.precision, ',', c.scale, ')')
            WHEN bt.name IN ('datetime2', 'datetimeoffset', 'time') THEN CONCAT(bt.name, '(', c.scale, ')')
            ELSE bt.name
        END AS DataTypeDisplay,
        CASE
            WHEN c.max_length = -1 THEN NULL
            WHEN bt.name IN ('xml', 'text', 'ntext', 'image', 'sql_variant') THEN NULL
            ELSE c.max_length
        END AS EstimatedBytes,
        CASE
            WHEN c.max_length = -1 THEN 'max-or-row-overflow'
            WHEN bt.name IN ('xml', 'text', 'ntext', 'image', 'sql_variant') THEN 'lob-or-variable'
            WHEN bt.name IN ('varchar', 'nvarchar', 'varbinary') THEN 'variable'
            ELSE 'fixed'
        END AS WidthCategory
    FROM TargetIndexes AS ti
    INNER JOIN sys.index_columns AS ic
        ON ic.object_id = ti.object_id
       AND ic.index_id = ti.index_id
    INNER JOIN sys.columns AS c
        ON c.object_id = ic.object_id
       AND c.column_id = ic.column_id
    INNER JOIN sys.types AS bt
        ON bt.user_type_id = c.system_type_id
       AND bt.user_type_id = bt.system_type_id
),
LocatorBytes AS
(
    SELECT
        t.object_id,
        MAX(ci.name) AS ClusteredIndexName,
        CAST(CASE WHEN MAX(ci.index_id) IS NULL THEN 1 ELSE 0 END AS BIT) AS UsesHeapRidLocator,
        CASE
            WHEN MAX(ci.index_id) IS NULL THEN 8
            ELSE SUM(CASE WHEN c.max_length = -1 OR bt.name IN ('xml', 'text', 'ntext', 'image', 'sql_variant') THEN 0 ELSE c.max_length END)
        END AS EstimatedLocatorBytes
    FROM sys.tables AS t
    LEFT JOIN sys.indexes AS ci
        ON ci.object_id = t.object_id
       AND ci.type = 1
       AND ci.is_hypothetical = 0
       AND ci.is_disabled = 0
    LEFT JOIN sys.index_columns AS ic
        ON ic.object_id = ci.object_id
       AND ic.index_id = ci.index_id
       AND ic.is_included_column = 0
       AND ic.key_ordinal > 0
    LEFT JOIN sys.columns AS c
        ON c.object_id = ic.object_id
       AND c.column_id = ic.column_id
    LEFT JOIN sys.types AS bt
        ON bt.user_type_id = c.system_type_id
       AND bt.user_type_id = bt.system_type_id
    WHERE t.is_ms_shipped = 0
    GROUP BY
        t.object_id
),
IndexSummary AS
(
    SELECT
        DB_NAME() AS DatabaseName,
        cb.SchemaName,
        cb.TableName,
        cb.object_id,
        cb.index_id,
        cb.IndexName,
        cb.type_desc AS IndexType,
        cb.fill_factor,
        cb.has_filter,
        cb.filter_definition,
        lb.ClusteredIndexName,
        lb.UsesHeapRidLocator,
        lb.EstimatedLocatorBytes,
        SUM(CASE WHEN cb.is_included_column = 0 AND cb.key_ordinal > 0 THEN ISNULL(cb.EstimatedBytes, 0) ELSE 0 END) AS EstimatedKeyBytes,
        SUM(CASE WHEN cb.is_included_column = 1 THEN ISNULL(cb.EstimatedBytes, 0) ELSE 0 END) AS EstimatedIncludedBytes,
        SUM(CASE WHEN cb.is_included_column = 1 THEN 1 ELSE 0 END) AS IncludedColumnCount,
        SUM(CASE WHEN cb.is_included_column = 0 AND cb.key_ordinal > 0 THEN 1 ELSE 0 END) AS KeyColumnCount,
        SUM(CASE WHEN cb.is_included_column = 1 AND cb.WidthCategory = 'variable' THEN 1 ELSE 0 END) AS VariableIncludedColumnCount,
        SUM(CASE WHEN cb.is_included_column = 1 AND cb.WidthCategory IN ('max-or-row-overflow', 'lob-or-variable') THEN 1 ELSE 0 END) AS LargeValueIncludedColumnCount
    FROM ColumnBytes AS cb
    INNER JOIN LocatorBytes AS lb
        ON lb.object_id = cb.object_id
    GROUP BY
        cb.SchemaName,
        cb.TableName,
        cb.object_id,
        cb.index_id,
        cb.IndexName,
        cb.type_desc,
        cb.fill_factor,
        cb.has_filter,
        cb.filter_definition,
        lb.ClusteredIndexName,
        lb.UsesHeapRidLocator,
        lb.EstimatedLocatorBytes
),
Classified AS
(
    SELECT
        s.*,
        s.EstimatedKeyBytes + s.EstimatedIncludedBytes + s.EstimatedLocatorBytes AS EstimatedLeafRowBytes,
        CAST(CASE WHEN s.EstimatedKeyBytes + s.EstimatedIncludedBytes + s.EstimatedLocatorBytes > 0
            THEN 8096.0 / (s.EstimatedKeyBytes + s.EstimatedIncludedBytes + s.EstimatedLocatorBytes)
            ELSE NULL END AS DECIMAL(10,2)) AS EstimatedRowsPerPage,
        CAST(CASE
            WHEN s.LargeValueIncludedColumnCount > 0 THEN 1
            WHEN s.EstimatedKeyBytes + s.EstimatedIncludedBytes + s.EstimatedLocatorBytes >= @WarnLeafBytes THEN 1
            WHEN s.EstimatedIncludedBytes >= @WarnIncludedBytes THEN 1
            ELSE 0
        END AS BIT) AS IsWidthFlagged,
        CASE
            WHEN s.LargeValueIncludedColumnCount > 0 THEN 'review-large-value'
            WHEN s.EstimatedKeyBytes + s.EstimatedIncludedBytes + s.EstimatedLocatorBytes >= @WarnLeafBytes THEN 'review-wide-leaf'
            WHEN s.EstimatedIncludedBytes >= @WarnIncludedBytes THEN 'review-wide-include'
            WHEN s.EstimatedIncludedBytes <= 64 THEN 'compact'
            ELSE 'moderate'
        END AS WidthClass
    FROM IndexSummary AS s
)
SELECT
    c.DatabaseName,
    c.SchemaName,
    c.TableName,
    c.IndexName,
    c.IndexType,
    c.KeyColumnCount,
    c.IncludedColumnCount,
    c.ClusteredIndexName,
    c.UsesHeapRidLocator,
    c.EstimatedKeyBytes,
    c.EstimatedIncludedBytes,
    c.EstimatedLocatorBytes,
    c.EstimatedLeafRowBytes,
    c.EstimatedRowsPerPage,
    c.VariableIncludedColumnCount,
    c.LargeValueIncludedColumnCount,
    c.fill_factor AS FillFactor,
    CAST(c.has_filter AS BIT) AS HasFilter,
    c.filter_definition AS FilterDefinition,
    c.WidthClass,
    c.IsWidthFlagged,
    CASE
        WHEN c.LargeValueIncludedColumnCount > 0 THEN 'Contains MAX or LOB-like include columns.'
        WHEN c.EstimatedLeafRowBytes >= @WarnLeafBytes THEN 'Estimated leaf row width exceeds the configured threshold.'
        WHEN c.EstimatedIncludedBytes >= @WarnIncludedBytes THEN 'Estimated include width exceeds the configured threshold.'
        ELSE 'Below the configured width thresholds.'
    END AS WidthFinding,
    CASE
        WHEN c.LargeValueIncludedColumnCount > 0 THEN 'Validate large-value include columns before keeping them for coverage.'
        WHEN c.EstimatedLeafRowBytes >= @WarnLeafBytes THEN 'Review covering strategy because the leaf row becomes broad.'
        WHEN c.EstimatedIncludedBytes >= @WarnIncludedBytes THEN 'Prune low-value include columns or split coverage.'
        ELSE 'Keep as baseline and compare with workload and plans.'
    END AS SuggestedAction
FROM Classified AS c
WHERE @ShowOnlyFlagged = 0
   OR c.IsWidthFlagged = 1
ORDER BY
    c.IsWidthFlagged DESC,
    c.EstimatedLeafRowBytes DESC,
    c.EstimatedIncludedBytes DESC,
    c.SchemaName,
    c.TableName,
    c.IndexName;

SELECT
    c.DatabaseName,
    c.SchemaName,
    c.TableName,
    c.IndexName,
    c.IndexType,
    cb.index_column_id AS IncludedColumnOrder,
    cb.ColumnName AS IncludedColumnName,
    cb.DataTypeDisplay,
    cb.WidthCategory,
    cb.EstimatedBytes AS EstimatedMaxBytes,
    CAST(CASE WHEN cb.EstimatedBytes IS NOT NULL AND c.EstimatedIncludedBytes > 0
        THEN 100.0 * cb.EstimatedBytes / c.EstimatedIncludedBytes
        ELSE NULL END AS DECIMAL(6,2)) AS IncludedWidthSharePercent,
    c.EstimatedIncludedBytes,
    c.EstimatedLeafRowBytes,
    c.EstimatedRowsPerPage,
    c.WidthClass,
    c.IsWidthFlagged,
    CASE
        WHEN cb.WidthCategory IN ('max-or-row-overflow', 'lob-or-variable') THEN 'Column requires separate review because width is not bounded in-page.'
        WHEN c.EstimatedLeafRowBytes >= @WarnLeafBytes THEN 'Column contributes to a broad leaf row footprint.'
        WHEN c.EstimatedIncludedBytes >= @WarnIncludedBytes THEN 'Column contributes to a wide include list.'
        ELSE 'Column remains visible for baseline comparison.'
    END AS ColumnFinding
FROM Classified AS c
INNER JOIN ColumnBytes AS cb
    ON cb.object_id = c.object_id
   AND cb.index_id = c.index_id
WHERE cb.is_included_column = 1
  AND (@ShowOnlyFlagged = 0 OR c.IsWidthFlagged = 1)
ORDER BY
    c.IsWidthFlagged DESC,
    cb.EstimatedBytes DESC,
    c.SchemaName,
    c.TableName,
    c.IndexName,
    cb.index_column_id;
