/* All indexes in the current database (incl. columns, includes, filters, uniqueness, PK/UQ) */
;WITH idx AS
(
    SELECT
        s.name  AS SchemaName,
        t.name  AS TableName,
        i.name  AS IndexName,
        i.type_desc,
        i.is_primary_key,
        i.is_unique,
        i.is_unique_constraint,
        i.is_disabled,
        i.has_filter,
        i.filter_definition,
        i.fill_factor,
        i.data_space_id,
        ds.name AS DataSpaceName
    FROM sys.tables t
    INNER JOIN sys.schemas s
        ON s.schema_id = t.schema_id
    INNER JOIN sys.indexes i
        ON i.object_id = t.object_id
    LEFT JOIN sys.data_spaces ds
        ON ds.data_space_id = i.data_space_id
    WHERE i.index_id >= 0  -- includes HEAP (0) + all indexes
)
SELECT
    idx.SchemaName,
    idx.TableName,
    idx.IndexName,
    idx.type_desc,
    idx.is_primary_key,
    idx.is_unique,
    idx.is_unique_constraint,
    idx.is_disabled,
    idx.fill_factor,
    idx.DataSpaceName,
    idx.has_filter,
    idx.filter_definition,
    KeyColumns =
        STUFF((
            SELECT
                ', ' + QUOTENAME(c.name) +
                CASE WHEN ic.is_descending_key = 1 THEN ' DESC' ELSE ' ASC' END
            FROM sys.index_columns ic
            INNER JOIN sys.columns c
                ON c.object_id = ic.object_id
               AND c.column_id = ic.column_id
            WHERE ic.object_id = OBJECT_ID(QUOTENAME(idx.SchemaName) + '.' + QUOTENAME(idx.TableName))
              AND ic.index_id  = (SELECT i2.index_id
                                 FROM sys.indexes i2
                                 WHERE i2.object_id = OBJECT_ID(QUOTENAME(idx.SchemaName) + '.' + QUOTENAME(idx.TableName))
                                   AND ISNULL(i2.name,'') = ISNULL(idx.IndexName,'')
                                )
              AND ic.is_included_column = 0
              AND ic.key_ordinal > 0
            ORDER BY ic.key_ordinal
            FOR XML PATH(''), TYPE
        ).value('.','nvarchar(max)'), 1, 2, ''),
    IncludedColumns =
        STUFF((
            SELECT ', ' + QUOTENAME(c.name)
            FROM sys.index_columns ic
            INNER JOIN sys.columns c
                ON c.object_id = ic.object_id
               AND c.column_id = ic.column_id
            WHERE ic.object_id = OBJECT_ID(QUOTENAME(idx.SchemaName) + '.' + QUOTENAME(idx.TableName))
              AND ic.index_id  = (SELECT i2.index_id
                                 FROM sys.indexes i2
                                 WHERE i2.object_id = OBJECT_ID(QUOTENAME(idx.SchemaName) + '.' + QUOTENAME(idx.TableName))
                                   AND ISNULL(i2.name,'') = ISNULL(idx.IndexName,'')
                                )
              AND ic.is_included_column = 1
            ORDER BY c.column_id
            FOR XML PATH(''), TYPE
        ).value('.','nvarchar(max)'), 1, 2, '')
FROM idx
ORDER BY
    idx.SchemaName,
    idx.TableName,
    CASE WHEN idx.IndexName IS NULL THEN 0 ELSE 1 END,
    idx.IndexName;