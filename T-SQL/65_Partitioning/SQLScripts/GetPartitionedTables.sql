-- Welche Tabellen haben eine Partition und wieviele?
DECLARE @DatabaseName SYSNAME = NULL;   -- z.B. N'BI_RAW'; NULL = aktuelle DB
DECLARE @SchemaName   SYSNAME = NULL;   -- z.B. N'sap';    NULL = alle Schemas

DECLARE @EffectiveDatabaseName SYSNAME = ISNULL(@DatabaseName, DB_NAME());
DECLARE @SQL NVARCHAR(MAX);

SET @SQL = N'
SELECT
    N''' + REPLACE(@EffectiveDatabaseName, '''', '''''') + N''' AS DatabaseName,
    s.name  AS SchemaName,
    t.name  AS TableName,
    i.type_desc AS BaseStorageType,
    i.name  AS BaseIndexName,
    c.name  AS PartitionColumn,
    ps.name AS PartitionSchemeName,
    pf.name AS PartitionFunctionName,
    COUNT(DISTINCT p.partition_number) AS PartitionCount,
    SUM(p.rows) AS TotalRows
FROM ' + QUOTENAME(@EffectiveDatabaseName) + N'.sys.tables t
INNER JOIN ' + QUOTENAME(@EffectiveDatabaseName) + N'.sys.schemas s
    ON s.schema_id = t.schema_id
INNER JOIN ' + QUOTENAME(@EffectiveDatabaseName) + N'.sys.indexes i
    ON i.object_id = t.object_id
   AND i.index_id IN (0, 1)   -- Heap oder Basisspeicher-Index
INNER JOIN ' + QUOTENAME(@EffectiveDatabaseName) + N'.sys.data_spaces ds
    ON ds.data_space_id = i.data_space_id
INNER JOIN ' + QUOTENAME(@EffectiveDatabaseName) + N'.sys.partition_schemes ps
    ON ps.data_space_id = ds.data_space_id
INNER JOIN ' + QUOTENAME(@EffectiveDatabaseName) + N'.sys.partition_functions pf
    ON pf.function_id = ps.function_id
INNER JOIN ' + QUOTENAME(@EffectiveDatabaseName) + N'.sys.partitions p
    ON p.object_id = i.object_id
   AND p.index_id  = i.index_id
LEFT JOIN ' + QUOTENAME(@EffectiveDatabaseName) + N'.sys.index_columns ic
    ON ic.object_id = i.object_id
   AND ic.index_id  = i.index_id
   AND ic.partition_ordinal = 1
LEFT JOIN ' + QUOTENAME(@EffectiveDatabaseName) + N'.sys.columns c
    ON c.object_id = ic.object_id
   AND c.column_id = ic.column_id
WHERE
    t.is_ms_shipped = 0
    AND (@SchemaName IS NULL OR s.name = @SchemaName)
GROUP BY
    s.name,
    t.name,
    i.type_desc,
    i.name,
    c.name,
    ps.name,
    pf.name
ORDER BY
    s.name,
    t.name;';

EXEC sys.sp_executesql
    @stmt   = @SQL,
    @params = N'@SchemaName SYSNAME',
    @SchemaName = @SchemaName;