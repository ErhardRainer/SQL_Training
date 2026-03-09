/*
---
title: "Index Usage Analysis for a Specific Column"
description: |
  This script examines all indexes on a given table to identify where a
  designated column is used. It checks for the column in key and include
  columns, in filter predicates, and through computed columns that depend on
  the target column. The output includes detailed index metadata and a
  generated CREATE INDEX statement skeleton for each affected index.
parameters:
  SchemaName: "Schema of the table (default 'dbo')"
  TableName: "Name of the table to inspect"
  ColumnName: "Column to search for in index definitions"
---
*/

DECLARE @SchemaName SYSNAME = 'dbo';
DECLARE @TableName  SYSNAME = 'FIBU_Accounting_SAP';
DECLARE @ColumnName SYSNAME = 'Customer';

DECLARE @ObjectID INT;

SELECT
    @ObjectID = T.object_id
FROM sys.tables AS T
INNER JOIN sys.schemas AS S
    ON T.schema_id = S.schema_id
WHERE S.name = @SchemaName
  AND T.name = @TableName;

IF @ObjectID IS NULL
BEGIN
    THROW 50000, 'Tabelle nicht gefunden.', 1;
END;

;WITH DirectRef AS
(
    SELECT
        IC.object_id,
        IC.index_id,
        MAX(CASE WHEN C.name = @ColumnName AND IC.is_included_column = 0 THEN 1 ELSE 0 END) AS CustomerInKey,
        MAX(CASE WHEN C.name = @ColumnName AND IC.is_included_column = 1 THEN 1 ELSE 0 END) AS CustomerInInclude
    FROM sys.index_columns AS IC
    INNER JOIN sys.columns AS C
        ON C.object_id = IC.object_id
       AND C.column_id = IC.column_id
    WHERE IC.object_id = @ObjectID
    GROUP BY
        IC.object_id,
        IC.index_id
),
ComputedColsDependingOnTarget AS
(
    SELECT
        CC.object_id,
        CC.column_id,
        C.name AS ComputedColumnName
    FROM sys.computed_columns AS CC
    INNER JOIN sys.columns AS C
        ON C.object_id = CC.object_id
       AND C.column_id = CC.column_id
    WHERE CC.object_id = @ObjectID
      AND EXISTS
      (
          SELECT 1
          FROM sys.sql_expression_dependencies AS D
          INNER JOIN sys.columns AS RC
              ON RC.object_id = D.referenced_id
             AND RC.column_id = D.referenced_minor_id
          WHERE D.referencing_id = CC.object_id
            AND D.referencing_minor_id = CC.column_id
            AND D.referenced_id = CC.object_id
            AND RC.name = @ColumnName
      )
),
ComputedIndexRef AS
(
    SELECT
        IC.object_id,
        IC.index_id,
        STUFF(
        (
            SELECT
                ', ' + QUOTENAME(CD2.ComputedColumnName) COLLATE DATABASE_DEFAULT
            FROM sys.index_columns AS IC2
            INNER JOIN ComputedColsDependingOnTarget AS CD2
                ON CD2.object_id = IC2.object_id
               AND CD2.column_id = IC2.column_id
            WHERE IC2.object_id = IC.object_id
              AND IC2.index_id = IC.index_id
            ORDER BY IC2.index_column_id
            FOR XML PATH(''), TYPE
        ).value('.', 'nvarchar(max)'), 1, 2, '') COLLATE DATABASE_DEFAULT AS IndexedComputedColumnsDependingOnCustomer
    FROM sys.index_columns AS IC
    WHERE IC.object_id = @ObjectID
    GROUP BY
        IC.object_id,
        IC.index_id
)
SELECT
    SC.name AS SchemaName,
    O.name  AS TableName,
    I.name  AS IndexName,
    I.type_desc AS IndexType,
    I.is_unique,
    I.is_primary_key,
    I.is_unique_constraint,
    I.is_disabled,
    I.has_filter,
    I.filter_definition,
    DS.name AS DataSpaceName,
    DS.type_desc AS DataSpaceType,
    ISNULL(DR.CustomerInKey, 0) AS CustomerInKey,
    ISNULL(DR.CustomerInInclude, 0) AS CustomerInInclude,
    CASE
        WHEN I.has_filter = 1
         AND I.filter_definition IS NOT NULL
         AND (
                I.filter_definition COLLATE DATABASE_DEFAULT LIKE '%[[]' + @ColumnName + '[]]%'
             OR I.filter_definition COLLATE DATABASE_DEFAULT LIKE '%' + @ColumnName + '%'
             )
        THEN 1
        ELSE 0
    END AS CustomerInFilter,
    CASE
        WHEN CIR.IndexedComputedColumnsDependingOnCustomer IS NOT NULL
             AND LEN(CIR.IndexedComputedColumnsDependingOnCustomer) > 0
        THEN 1
        ELSE 0
    END AS CustomerViaIndexedComputedColumn,
    KC.KeyColumns,
    INC.IncludeColumns,
    PC.PartitionColumns,
    CIR.IndexedComputedColumnsDependingOnCustomer,
    CASE
        WHEN ISNULL(DR.CustomerInKey, 0) = 1
          OR ISNULL(DR.CustomerInInclude, 0) = 1
          OR (
                I.has_filter = 1
            AND I.filter_definition IS NOT NULL
            AND (
                   I.filter_definition COLLATE DATABASE_DEFAULT LIKE '%[[]' + @ColumnName + '[]]%'
                OR I.filter_definition COLLATE DATABASE_DEFAULT LIKE '%' + @ColumnName + '%'
                )
             )
          OR (
                CIR.IndexedComputedColumnsDependingOnCustomer IS NOT NULL
            AND LEN(CIR.IndexedComputedColumnsDependingOnCustomer) > 0
             )
        THEN
            (
                STUFF(
                      CASE WHEN ISNULL(DR.CustomerInKey, 0) = 1 THEN ',KEY' ELSE '' END
                    + CASE WHEN ISNULL(DR.CustomerInInclude, 0) = 1 THEN ',INCLUDE' ELSE '' END
                    + CASE WHEN I.has_filter = 1
                             AND I.filter_definition IS NOT NULL
                             AND (
                                    I.filter_definition COLLATE DATABASE_DEFAULT LIKE '%[[]' + @ColumnName + '[]]%'
                                 OR I.filter_definition COLLATE DATABASE_DEFAULT LIKE '%' + @ColumnName + '%'
                                 )
                           THEN ',FILTER' ELSE '' END
                    + CASE WHEN CIR.IndexedComputedColumnsDependingOnCustomer IS NOT NULL
                             AND LEN(CIR.IndexedComputedColumnsDependingOnCustomer) > 0
                           THEN ',COMPUTED' ELSE '' END
                , 1, 1, '')
            ) COLLATE DATABASE_DEFAULT
        ELSE NULL
    END AS AffectedReason,

    CASE
        WHEN I.type NOT IN (1, 2)
        THEN ('-- CREATE INDEX nicht automatisch generiert: Indextyp ' + I.type_desc + ' bitte separat prüfen.') COLLATE DATABASE_DEFAULT
        ELSE
            (
                'CREATE '
                + CASE WHEN I.is_unique = 1 THEN 'UNIQUE ' ELSE '' END
                + CASE I.type
                    WHEN 1 THEN 'CLUSTERED '
                    WHEN 2 THEN 'NONCLUSTERED '
                    ELSE ''
                  END
                + 'INDEX ' + QUOTENAME(I.name) COLLATE DATABASE_DEFAULT
                + ' ON ' + QUOTENAME(SC.name) COLLATE DATABASE_DEFAULT
                + '.' + QUOTENAME(O.name) COLLATE DATABASE_DEFAULT
                + ' (' + ISNULL(KC.KeyColumns, '') COLLATE DATABASE_DEFAULT + ')'
                + CASE
                    WHEN INC.IncludeColumns IS NOT NULL AND LEN(INC.IncludeColumns) > 0
                    THEN ' INCLUDE (' + INC.IncludeColumns COLLATE DATABASE_DEFAULT + ')'
                    ELSE ''
                  END
                + CASE
                    WHEN I.has_filter = 1 AND I.filter_definition IS NOT NULL
                    THEN ' WHERE ' + I.filter_definition COLLATE DATABASE_DEFAULT
                    ELSE ''
                  END
                + ' WITH ('
                + 'PAD_INDEX = ' + CASE WHEN I.is_padded = 1 THEN 'ON' ELSE 'OFF' END
                + ', STATISTICS_NORECOMPUTE = ' + CASE WHEN ST.no_recompute = 1 THEN 'ON' ELSE 'OFF' END
                + ', SORT_IN_TEMPDB = OFF'
                + ', IGNORE_DUP_KEY = ' + CASE WHEN I.ignore_dup_key = 1 THEN 'ON' ELSE 'OFF' END
                + ', DROP_EXISTING = OFF'
                + ', ONLINE = OFF'
                + ', ALLOW_ROW_LOCKS = ' + CASE WHEN I.allow_row_locks = 1 THEN 'ON' ELSE 'OFF' END
                + ', ALLOW_PAGE_LOCKS = ' + CASE WHEN I.allow_page_locks = 1 THEN 'ON' ELSE 'OFF' END
                + CASE
                    WHEN I.fill_factor > 0
                    THEN ', FILLFACTOR = ' + CAST(I.fill_factor AS VARCHAR(3))
                    ELSE ''
                  END
                + CASE
                    WHEN I.optimize_for_sequential_key = 1
                    THEN ', OPTIMIZE_FOR_SEQUENTIAL_KEY = ON'
                    ELSE ', OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF'
                  END
                + CASE
                    WHEN DC.UniformDataCompressionDesc IS NOT NULL
                    THEN ', DATA_COMPRESSION = ' + DC.UniformDataCompressionDesc COLLATE DATABASE_DEFAULT
                    ELSE ''
                  END
                + ')'
                + ' ON '
                + CASE
                    WHEN DS.type = 'PS'
                    THEN QUOTENAME(DS.name) COLLATE DATABASE_DEFAULT
                         + ' (' + ISNULL(PC.PartitionColumns, '') COLLATE DATABASE_DEFAULT + ')'
                    ELSE QUOTENAME(DS.name) COLLATE DATABASE_DEFAULT
                  END
            ) COLLATE DATABASE_DEFAULT
    END AS CreateIndexStatement

FROM sys.indexes AS I
INNER JOIN sys.objects AS O
    ON O.object_id = I.object_id
INNER JOIN sys.schemas AS SC
    ON SC.schema_id = O.schema_id
LEFT JOIN sys.data_spaces AS DS
    ON DS.data_space_id = I.data_space_id
LEFT JOIN sys.stats AS ST
    ON ST.object_id = I.object_id
   AND ST.stats_id = I.index_id
LEFT JOIN DirectRef AS DR
    ON DR.object_id = I.object_id
   AND DR.index_id = I.index_id
LEFT JOIN ComputedIndexRef AS CIR
    ON CIR.object_id = I.object_id
   AND CIR.index_id = I.index_id

OUTER APPLY
(
    SELECT
        STUFF
        (
            (
                SELECT
                    ', ' + (QUOTENAME(C.name) + CASE WHEN IC.is_descending_key = 1 THEN ' DESC' ELSE ' ASC' END) COLLATE DATABASE_DEFAULT
                FROM sys.index_columns AS IC
                INNER JOIN sys.columns AS C
                    ON C.object_id = IC.object_id
                   AND C.column_id = IC.column_id
                WHERE IC.object_id = I.object_id
                  AND IC.index_id = I.index_id
                  AND IC.is_included_column = 0
                  AND IC.key_ordinal > 0
                ORDER BY IC.key_ordinal
                FOR XML PATH(''), TYPE
            ).value('.', 'nvarchar(max)')
        , 1, 2, '') COLLATE DATABASE_DEFAULT AS KeyColumns
) AS KC

OUTER APPLY
(
    SELECT
        STUFF
        (
            (
                SELECT
                    ', ' + QUOTENAME(C.name) COLLATE DATABASE_DEFAULT
                FROM sys.index_columns AS IC
                INNER JOIN sys.columns AS C
                    ON C.object_id = IC.object_id
                   AND C.column_id = IC.column_id
                WHERE IC.object_id = I.object_id
                  AND IC.index_id = I.index_id
                  AND IC.is_included_column = 1
                ORDER BY IC.index_column_id
                FOR XML PATH(''), TYPE
            ).value('.', 'nvarchar(max)')
        , 1, 2, '') COLLATE DATABASE_DEFAULT AS IncludeColumns
) AS INC

OUTER APPLY
(
    SELECT
        STUFF
        (
            (
                SELECT
                    ', ' + QUOTENAME(C.name) COLLATE DATABASE_DEFAULT
                FROM sys.index_columns AS IC
                INNER JOIN sys.columns AS C
                    ON C.object_id = IC.object_id
                   AND C.column_id = IC.column_id
                WHERE IC.object_id = I.object_id
                  AND IC.index_id = I.index_id
                  AND IC.partition_ordinal > 0
                ORDER BY IC.partition_ordinal
                FOR XML PATH(''), TYPE
            ).value('.', 'nvarchar(max)')
        , 1, 2, '') COLLATE DATABASE_DEFAULT AS PartitionColumns
) AS PC

OUTER APPLY
(
    SELECT
        CASE
            WHEN COUNT(DISTINCT P.data_compression_desc) = 1
             AND MAX(P.data_compression_desc) <> 'NONE'
            THEN MAX(P.data_compression_desc) COLLATE DATABASE_DEFAULT
            ELSE NULL
        END AS UniformDataCompressionDesc
    FROM sys.partitions AS P
    WHERE P.object_id = I.object_id
      AND P.index_id = I.index_id
) AS DC

WHERE I.object_id = @ObjectID
  AND I.index_id > 0
  AND
  (
       ISNULL(DR.CustomerInKey, 0) = 1
    OR ISNULL(DR.CustomerInInclude, 0) = 1
    OR (
           I.has_filter = 1
       AND I.filter_definition IS NOT NULL
       AND (
              I.filter_definition COLLATE DATABASE_DEFAULT LIKE '%[[]' + @ColumnName + '[]]%'
           OR I.filter_definition COLLATE DATABASE_DEFAULT LIKE '%' + @ColumnName + '%'
           )
       )
    OR (
           CIR.IndexedComputedColumnsDependingOnCustomer IS NOT NULL
       AND LEN(CIR.IndexedComputedColumnsDependingOnCustomer) > 0
       )
  )
ORDER BY
    I.index_id,
    I.name;