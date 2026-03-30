DECLARE @SchemaName SYSNAME = 'sap';
DECLARE @TableName  SYSNAME = 'JournalEntry_CO_CBC';

;WITH IndexBase AS
(
    SELECT
        i.object_id,
        i.index_id,
        SchemaName           = CAST(s.name AS NVARCHAR(128)) COLLATE DATABASE_DEFAULT,
        TableName            = CAST(t.name AS NVARCHAR(128)) COLLATE DATABASE_DEFAULT,
        IndexName            = CAST(i.name AS NVARCHAR(128)) COLLATE DATABASE_DEFAULT,
        IndexTypeDesc        = CAST(i.type_desc AS NVARCHAR(128)) COLLATE DATABASE_DEFAULT,
        i.type,
        i.is_unique,
        i.is_primary_key,
        i.is_unique_constraint,
        i.is_disabled,
        i.has_filter,
        FilterDefinition     = CAST(i.filter_definition AS NVARCHAR(MAX)) COLLATE DATABASE_DEFAULT,
        i.fill_factor,
        i.is_padded,
        i.ignore_dup_key,
        i.allow_row_locks,
        i.allow_page_locks,
        DataSpaceName        = CAST(ds.name AS NVARCHAR(128)) COLLATE DATABASE_DEFAULT,
        IsPartitionScheme    = CASE WHEN ps.data_space_id IS NULL THEN 0 ELSE 1 END
    FROM sys.indexes i
    INNER JOIN sys.tables t
        ON t.object_id = i.object_id
    INNER JOIN sys.schemas s
        ON s.schema_id = t.schema_id
    LEFT JOIN sys.data_spaces ds
        ON ds.data_space_id = i.data_space_id
    LEFT JOIN sys.partition_schemes ps
        ON ps.data_space_id = i.data_space_id
    WHERE s.name = @SchemaName
      AND t.name = @TableName
      AND i.index_id > 0
      AND i.is_hypothetical = 0
      AND i.type IN (1, 2)   -- 1 = CLUSTERED, 2 = NONCLUSTERED
),
KeyCols AS
(
    SELECT
        ic.object_id,
        ic.index_id,
        KeyColumns =
            STRING_AGG(
                CAST(QUOTENAME(c.name) AS NVARCHAR(MAX)) COLLATE DATABASE_DEFAULT
                + CASE
                      WHEN ic.is_descending_key = 1 THEN N' DESC'
                      ELSE N' ASC'
                  END,
                N', '
            ) WITHIN GROUP (ORDER BY ic.key_ordinal)
    FROM sys.index_columns ic
    INNER JOIN sys.columns c
        ON c.object_id = ic.object_id
       AND c.column_id = ic.column_id
    INNER JOIN IndexBase ib
        ON ib.object_id = ic.object_id
       AND ib.index_id = ic.index_id
    WHERE ic.key_ordinal > 0
      AND ic.is_included_column = 0
    GROUP BY
        ic.object_id,
        ic.index_id
),
IncludeCols AS
(
    SELECT
        ic.object_id,
        ic.index_id,
        IncludeColumns =
            STRING_AGG(
                CAST(QUOTENAME(c.name) AS NVARCHAR(MAX)) COLLATE DATABASE_DEFAULT,
                N', '
            ) WITHIN GROUP (ORDER BY ic.index_column_id)
    FROM sys.index_columns ic
    INNER JOIN sys.columns c
        ON c.object_id = ic.object_id
       AND c.column_id = ic.column_id
    INNER JOIN IndexBase ib
        ON ib.object_id = ic.object_id
       AND ib.index_id = ic.index_id
    WHERE ic.is_included_column = 1
    GROUP BY
        ic.object_id,
        ic.index_id
),
PartitionCols AS
(
    SELECT
        ic.object_id,
        ic.index_id,
        PartitionColumns =
            STRING_AGG(
                CAST(QUOTENAME(c.name) AS NVARCHAR(MAX)) COLLATE DATABASE_DEFAULT,
                N', '
            ) WITHIN GROUP (ORDER BY ic.partition_ordinal)
    FROM sys.index_columns ic
    INNER JOIN sys.columns c
        ON c.object_id = ic.object_id
       AND c.column_id = ic.column_id
    INNER JOIN IndexBase ib
        ON ib.object_id = ic.object_id
       AND ib.index_id = ic.index_id
    WHERE ic.partition_ordinal > 0
    GROUP BY
        ic.object_id,
        ic.index_id
)
SELECT
    ib.SchemaName,
    ib.TableName,
    ib.IndexName,
    ib.IndexTypeDesc,
    ib.is_unique,
    ib.is_primary_key,
    ib.is_unique_constraint,
    ib.is_disabled,
    kc.KeyColumns,
    ic.IncludeColumns,
    pc.PartitionColumns,
    IndexDefinition =
        (
            N'CREATE '
            + CASE WHEN ib.is_unique = 1 THEN N'UNIQUE ' ELSE N'' END
            + ib.IndexTypeDesc
            + N' INDEX ' + QUOTENAME(ib.IndexName)
            + N' ON ' + QUOTENAME(ib.SchemaName) + N'.' + QUOTENAME(ib.TableName)
            + N' (' + kc.KeyColumns + N')'
            + CASE
                  WHEN ic.IncludeColumns IS NOT NULL
                  THEN N' INCLUDE (' + ic.IncludeColumns + N')'
                  ELSE N''
              END
            + CASE
                  WHEN ib.has_filter = 1
                  THEN N' WHERE ' + ib.FilterDefinition
                  ELSE N''
              END
            + N' WITH ('
            + N'PAD_INDEX = '      + CASE WHEN ib.is_padded = 1      THEN N'ON'  ELSE N'OFF' END
            + N', FILLFACTOR = '   + CAST(ib.fill_factor AS NVARCHAR(10))
            + N', IGNORE_DUP_KEY = '+ CASE WHEN ib.ignore_dup_key = 1 THEN N'ON'  ELSE N'OFF' END
            + N', ALLOW_ROW_LOCKS = ' + CASE WHEN ib.allow_row_locks = 1 THEN N'ON' ELSE N'OFF' END
            + N', ALLOW_PAGE_LOCKS = ' + CASE WHEN ib.allow_page_locks = 1 THEN N'ON' ELSE N'OFF' END
            + N')'
            + CASE
                  WHEN ib.DataSpaceName IS NOT NULL AND ib.IsPartitionScheme = 1 AND pc.PartitionColumns IS NOT NULL
                  THEN N' ON ' + QUOTENAME(ib.DataSpaceName) + N' (' + pc.PartitionColumns + N')'
                  WHEN ib.DataSpaceName IS NOT NULL
                  THEN N' ON ' + QUOTENAME(ib.DataSpaceName)
                  ELSE N''
              END
        ) COLLATE DATABASE_DEFAULT
FROM IndexBase ib
LEFT JOIN KeyCols kc
    ON kc.object_id = ib.object_id
   AND kc.index_id = ib.index_id
LEFT JOIN IncludeCols ic
    ON ic.object_id = ib.object_id
   AND ic.index_id = ib.index_id
LEFT JOIN PartitionCols pc
    ON pc.object_id = ib.object_id
   AND pc.index_id = ib.index_id
ORDER BY
    ib.index_id;