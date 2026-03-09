DECLARE @SchemaName SYSNAME = 'dbo';
DECLARE @TableName  SYSNAME = 'FIBU_Accounting_SAP';
DECLARE @IndexName  SYSNAME = 'IX_FIBU_Accounting_SAP_Customer';

DECLARE @MinGoodReadWriteRatio       DECIMAL(18,2) = 10.00;
DECLARE @MinAcceptableReadWriteRatio DECIMAL(18,2) = 1.00;

DECLARE @ObjectID INT;

SELECT
    @ObjectID = T.object_id
FROM sys.tables AS T
INNER JOIN sys.schemas AS S
    ON S.schema_id = T.schema_id
WHERE S.name = @SchemaName
  AND T.name = @TableName;

IF @ObjectID IS NULL
BEGIN
    THROW 50000, 'Tabelle nicht gefunden.', 1;
END;

;WITH SpaceAgg AS
(
    SELECT
        PS.object_id,
        PS.index_id,
        SUM(PS.row_count) AS ApproxRowCount,
        CAST(SUM(PS.used_page_count) * 8.0 / 1024.0 AS DECIMAL(18,2)) AS UsedMB,
        CAST(SUM(PS.reserved_page_count) * 8.0 / 1024.0 AS DECIMAL(18,2)) AS ReservedMB
    FROM sys.dm_db_partition_stats AS PS
    WHERE PS.object_id = @ObjectID
    GROUP BY
        PS.object_id,
        PS.index_id
)
SELECT
    DB_NAME() AS DatabaseName,
    SCH.name  AS SchemaName,
    OBJ.name  AS TableName,
    I.name    AS IndexName,
    I.index_id,
    I.type_desc,
    I.is_unique,
    I.is_primary_key,
    I.is_unique_constraint,
    I.is_disabled,

    SA.ApproxRowCount,
    SA.UsedMB,
    SA.ReservedMB,

    ISNULL(IUS.user_seeks,   0) AS user_seeks,
    ISNULL(IUS.user_scans,   0) AS user_scans,
    ISNULL(IUS.user_lookups, 0) AS user_lookups,
    ISNULL(IUS.user_updates, 0) AS user_updates,

    LU.LastUserRead,
    IUS.last_user_update,
    OSI.sqlserver_start_time AS SqlServerStartTime,
    DATEDIFF(DAY, OSI.sqlserver_start_time, SYSDATETIME()) AS DaysSinceSqlStart,

    M.TotalReads,
    M.TotalWrites,
    R.ReadWriteRatio,

    CASE
        WHEN IUS.index_id IS NULL
            THEN 'Keine Nutzungsdaten seit letztem SQL-Server-Start'
        WHEN M.TotalReads = 0 AND M.TotalWrites = 0
            THEN 'Keine Nutzung seit letztem SQL-Server-Start'
        WHEN M.TotalReads = 0 AND M.TotalWrites > 0
            THEN 'Kritisch: nur Wartung, keine Leseverwendung'
        WHEN M.TotalReads > 0 AND M.TotalWrites = 0
            THEN 'Sehr gut: Leseverwendung ohne DML-Wartung'
        WHEN R.ReadWriteRatio >= @MinGoodReadWriteRatio
             AND ISNULL(IUS.user_seeks, 0) > 0
             AND ISNULL(IUS.user_scans, 0) = 0
             AND ISNULL(IUS.user_lookups, 0) = 0
            THEN 'Gut: selektiv genutzt, sehr gutes Reads/Writes-Verhältnis'
        WHEN R.ReadWriteRatio >= @MinGoodReadWriteRatio
            THEN 'Gut: Reads deutlich höher als Writes'
        WHEN R.ReadWriteRatio >= @MinAcceptableReadWriteRatio
            THEN 'Mittel: Reads und Writes in ähnlicher Größenordnung'
        ELSE 'Kritisch: Writes höher als Reads'
    END AS Assessment,

    CASE
        WHEN IUS.index_id IS NULL
            THEN 'Nur auf Basis der DMV nicht löschen; Zeitraum seit letztem SQL-Server-Start prüfen'
        WHEN M.TotalReads = 0 AND M.TotalWrites > 0
            THEN 'Drop-Kandidat fachlich und per Ausführungsplänen prüfen'
        WHEN R.ReadWriteRatio < @MinAcceptableReadWriteRatio
            THEN 'Nur behalten, wenn fachlich oder für kritische Abfragen notwendig'
        WHEN R.ReadWriteRatio < @MinGoodReadWriteRatio
            THEN 'Behalten, aber Nutzen gegen Schreibkosten abwägen'
        ELSE 'Eher behalten'
    END AS Recommendation
FROM sys.indexes AS I
INNER JOIN sys.objects AS OBJ
    ON OBJ.object_id = I.object_id
INNER JOIN sys.schemas AS SCH
    ON SCH.schema_id = OBJ.schema_id
LEFT JOIN sys.dm_db_index_usage_stats AS IUS
    ON IUS.database_id = DB_ID()
   AND IUS.object_id   = I.object_id
   AND IUS.index_id    = I.index_id
LEFT JOIN SpaceAgg AS SA
    ON SA.object_id = I.object_id
   AND SA.index_id  = I.index_id
CROSS JOIN sys.dm_os_sys_info AS OSI
OUTER APPLY
(
    SELECT
        LastUserRead =
        (
            SELECT MAX(V.dt)
            FROM (VALUES
                    (IUS.last_user_seek),
                    (IUS.last_user_scan),
                    (IUS.last_user_lookup)
                 ) AS V(dt)
        )
) AS LU
OUTER APPLY
(
    SELECT
        TotalReads  = ISNULL(IUS.user_seeks, 0) + ISNULL(IUS.user_scans, 0) + ISNULL(IUS.user_lookups, 0),
        TotalWrites = ISNULL(IUS.user_updates, 0)
) AS M
OUTER APPLY
(
    SELECT
        ReadWriteRatio =
            CAST
            (
                CASE
                    WHEN M.TotalWrites = 0 AND M.TotalReads > 0 THEN 999999.00
                    WHEN M.TotalWrites = 0 AND M.TotalReads = 0 THEN 0.00
                    ELSE 1.0 * M.TotalReads / NULLIF(M.TotalWrites, 0)
                END
                AS DECIMAL(18,2)
            )
) AS R
WHERE I.object_id = @ObjectID
  AND I.name = @IndexName;