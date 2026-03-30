/* Index fragmentation report + recommendation (Refresh/Rebuild)
   - Refresh = REORGANIZE (optional: UPDATE STATISTICS)
   - Rebuild = REBUILD
*/
DECLARE @MinPageCount INT   = 1000;  -- ignore tiny indexes
DECLARE @RefreshFrag  FLOAT = 5.0;   -- >= 5%  => Refresh
DECLARE @RebuildFrag  FLOAT = 30.0;  -- >= 30% => Rebuild

;WITH ips AS
(
    SELECT
        object_id,
        index_id,
        avg_fragmentation_in_percent,
        page_count
    FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'SAMPLED')
    WHERE index_id > 0
),
agg AS
(
    SELECT
        object_id,
        index_id,
        page_count = SUM(page_count),
        avg_fragmentation_in_percent =
            CASE WHEN SUM(page_count) = 0 THEN 0
                 ELSE SUM(avg_fragmentation_in_percent * page_count) / SUM(page_count)
            END
    FROM ips
    GROUP BY object_id, index_id
)
SELECT
    DatabaseName = DB_NAME(),
    SchemaName   = s.name,
    TableName    = o.name,
    IndexName    = i.name,
    i.type_desc,
    a.page_count,
    avg_fragmentation_in_percent = CAST(a.avg_fragmentation_in_percent AS DECIMAL(6,2)),
    Recommendation =
        CASE
            WHEN a.page_count IS NULL THEN 'N/A'
            WHEN a.page_count < @MinPageCount THEN 'Skip (small)'
            WHEN a.avg_fragmentation_in_percent >= @RebuildFrag THEN 'Rebuild'
            WHEN a.avg_fragmentation_in_percent >= @RefreshFrag THEN 'Refresh'
            ELSE 'OK'
        END,
    MaintenanceCommand =
        CASE
            WHEN a.page_count IS NULL THEN NULL
            WHEN a.page_count < @MinPageCount THEN NULL
            WHEN a.avg_fragmentation_in_percent >= @RebuildFrag THEN
                'ALTER INDEX ' + QUOTENAME(i.name) + ' ON ' + QUOTENAME(s.name) + '.' + QUOTENAME(o.name) + ' REBUILD;'
            WHEN a.avg_fragmentation_in_percent >= @RefreshFrag THEN
                'ALTER INDEX ' + QUOTENAME(i.name) + ' ON ' + QUOTENAME(s.name) + '.' + QUOTENAME(o.name) + ' REORGANIZE;'
                + ' -- optional: UPDATE STATISTICS ' + QUOTENAME(s.name) + '.' + QUOTENAME(o.name) + ' ' + QUOTENAME(i.name) + ';'
            ELSE NULL
        END
FROM sys.indexes i
JOIN sys.objects o
    ON o.object_id = i.object_id
JOIN sys.schemas s
    ON s.schema_id = o.schema_id
LEFT JOIN agg a
    ON a.object_id = i.object_id
   AND a.index_id  = i.index_id
WHERE
    o.type = 'U'          -- user tables
    AND i.index_id > 0    -- exclude HEAP
    AND i.is_disabled = 0
ORDER BY
    CASE
        WHEN a.page_count < @MinPageCount THEN 3
        WHEN a.avg_fragmentation_in_percent >= @RebuildFrag THEN 1
        WHEN a.avg_fragmentation_in_percent >= @RefreshFrag THEN 2
        ELSE 4
    END,
    a.avg_fragmentation_in_percent DESC,
    a.page_count DESC,
    s.name, o.name, i.name;