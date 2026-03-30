DECLARE @SchemaName SYSNAME = 'sap';
DECLARE @TableName  SYSNAME = 'JournalEntry_CO_CBC';
DECLARE @IndexName  SYSNAME = 'IX_JournalEntry_CO_CBC_ID';

;WITH IndexBase AS
(
    SELECT
        i.object_id,
        i.index_id,
        SchemaName = CAST(s.name AS NVARCHAR(128)) COLLATE DATABASE_DEFAULT,
        TableName = CAST(t.name AS NVARCHAR(128)) COLLATE DATABASE_DEFAULT,
        IndexName = CAST(i.name AS NVARCHAR(128)) COLLATE DATABASE_DEFAULT,
        i.is_unique,
        i.type_desc,
        i.has_filter,
        filter_definition = CAST(i.filter_definition AS NVARCHAR(MAX)) COLLATE DATABASE_DEFAULT,
        DataSpaceName = CAST(ds.name AS NVARCHAR(128)) COLLATE DATABASE_DEFAULT
    FROM sys.indexes i
    INNER JOIN sys.tables t
        ON t.object_id = i.object_id
    INNER JOIN sys.schemas s
        ON s.schema_id = t.schema_id
    LEFT JOIN sys.data_spaces ds
        ON ds.data_space_id = i.data_space_id
    WHERE s.name = @SchemaName
      AND t.name = @TableName
      AND i.name = @IndexName
),
KeyCols AS
(
    SELECT
        ic.object_id,
        ic.index_id,
        KeyColumns =
            STRING_AGG(
                (
                    CAST(QUOTENAME(c.name) AS NVARCHAR(MAX)) COLLATE DATABASE_DEFAULT
                    + CASE WHEN ic.is_descending_key = 1
                           THEN N' DESC'
                           ELSE N' ASC'
                      END COLLATE DATABASE_DEFAULT
                ),
                N', '
            ) WITHIN GROUP (ORDER BY ic.key_ordinal)
    FROM sys.index_columns ic
    INNER JOIN sys.columns c
        ON c.object_id = ic.object_id
       AND c.column_id = ic.column_id
    INNER JOIN IndexBase ib
        ON ib.object_id = ic.object_id
       AND ib.index_id = ic.index_id
    WHERE ic.is_included_column = 0
      AND ic.key_ordinal > 0
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
)
SELECT
    ib.SchemaName,
    ib.TableName,
    ib.IndexName,
    ib.type_desc,
    ib.is_unique,
    ib.has_filter,
    ib.filter_definition,
    kc.KeyColumns,
    ic.IncludeColumns,
    RecreatedIndexDefinition =
        (
            N'CREATE '
            + CASE WHEN ib.is_unique = 1 THEN N'UNIQUE ' ELSE N'' END
            + CAST(ib.type_desc AS NVARCHAR(128)) COLLATE DATABASE_DEFAULT
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
                  THEN N' WHERE ' + ib.filter_definition
                  ELSE N''
              END
            + CASE
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
   AND ic.index_id = ib.index_id;