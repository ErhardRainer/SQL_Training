DECLARE @SchemaName SYSNAME = 'dbo';
DECLARE @TableName  SYSNAME = 'FIBU_Accounting_SAP';
DECLARE @IndexName  SYSNAME = 'IX_FIBU_Accounting_SAP_Customer';

SELECT
    DB_NAME() AS DatabaseName,
    sch.name AS SchemaName,
    obj.name AS TableName,
    i.name   AS IndexName,
    i.index_id,
    i.type_desc,

    ISNULL(ius.user_seeks,   0) AS user_seeks,
    ISNULL(ius.user_scans,   0) AS user_scans,
    ISNULL(ius.user_lookups, 0) AS user_lookups,
    ISNULL(ius.user_updates, 0) AS user_updates,

    ius.last_user_seek,
    ius.last_user_scan,
    ius.last_user_lookup,
    ius.last_user_update,

    ca.LastUserRead,
    ca.LastUserAnyUse,

    ISNULL(ius.user_seeks, 0)
      + ISNULL(ius.user_scans, 0)
      + ISNULL(ius.user_lookups, 0) AS TotalUserReads,

    ISNULL(ius.user_seeks, 0)
      + ISNULL(ius.user_scans, 0)
      + ISNULL(ius.user_lookups, 0)
      + ISNULL(ius.user_updates, 0) AS TotalUserOps,

    osi.sqlserver_start_time AS SqlServerStartTime
FROM sys.indexes AS i
INNER JOIN sys.objects AS obj
    ON obj.object_id = i.object_id
INNER JOIN sys.schemas AS sch
    ON sch.schema_id = obj.schema_id
LEFT JOIN sys.dm_db_index_usage_stats AS ius
    ON ius.database_id = DB_ID()
   AND ius.object_id   = i.object_id
   AND ius.index_id    = i.index_id
CROSS JOIN sys.dm_os_sys_info AS osi
CROSS APPLY
(
    SELECT
        LastUserRead =
        (
            SELECT MAX(v.dt)
            FROM (VALUES
                    (ius.last_user_seek),
                    (ius.last_user_scan),
                    (ius.last_user_lookup)
                 ) AS v(dt)
        ),
        LastUserAnyUse =
        (
            SELECT MAX(v.dt)
            FROM (VALUES
                    (ius.last_user_seek),
                    (ius.last_user_scan),
                    (ius.last_user_lookup),
                    (ius.last_user_update)
                 ) AS v(dt)
        )
) AS ca
WHERE sch.name = @SchemaName
  AND obj.name = @TableName
  AND i.name   = @IndexName;