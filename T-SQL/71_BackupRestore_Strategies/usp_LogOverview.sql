USE BIMonitoring
GO

/* =======================================================================
   Stored Procedure: [log].[usp_LogOverview]
   Writes results to persistent tables with SnapshotDate (no #temp tables)
   ======================================================================= */

-- Ensure schema exists
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'log')
    EXEC('CREATE SCHEMA [log] AUTHORIZATION [dbo]');
GO

-- Create target tables if they don't exist yet
IF OBJECT_ID(N'log.LogSpace', 'U') IS NULL
BEGIN
    CREATE TABLE log.LogSpace
    (
        SnapshotDate          datetime2(0)  NOT NULL,
        DatabaseName          sysname       NOT NULL,
        LogSizeMB             decimal(18,2) NOT NULL,
        LogSpaceUsedPct       decimal(5,2)  NOT NULL,
        [Status]              int           NULL,
        CONSTRAINT PK_LogSpace PRIMARY KEY CLUSTERED
        (
            SnapshotDate, DatabaseName
        )
    );
END

IF OBJECT_ID(N'log.LogDetails', 'U') IS NULL
BEGIN
    CREATE TABLE log.LogDetails
    (
        SnapshotDate                        datetime2(0)  NOT NULL,
        [Database Name]                     sysname       NOT NULL,
        [Log Size (MB)]                     decimal(18,2) NOT NULL,
        [Log Size (GB)]                     decimal(18,3) NOT NULL,
        [Log Space Used (%)]                decimal(5,2)  NOT NULL,
        [Status]                            int           NULL,
        [Recovery Model]                    nvarchar(60)  NULL,
        [Log Reuse Wait]                    nvarchar(128) NULL,
        [Used (MB)]                         decimal(18,2) NOT NULL,
        [Used (GB)]                         decimal(18,3) NOT NULL,
        [Has Full Backup]                   bit           NOT NULL,
        [Has Log Backup]                    bit           NOT NULL,
        [Age of Log Backup (min)]           int           NULL,
        [Last Full Backup At]               datetime      NULL,
        [Last Log Backup At]                datetime      NULL,
        [Recommendation]                    varchar(12)   NOT NULL,
        [Projected Size After Shrink (MB)]  decimal(18,2) NULL,
        [Projected Size After Shrink (GB)]  decimal(18,3) NULL,
        CONSTRAINT PK_LogDetails PRIMARY KEY CLUSTERED
        (
            SnapshotDate, [Database Name]
        )
    );
END

IF OBJECT_ID(N'log.LogFiles', 'U') IS NULL
BEGIN
    CREATE TABLE log.LogFiles
    (
        SnapshotDate            datetime2(0)  NOT NULL,
        [Database Name]         sysname       NOT NULL,
        [File ID]               int           NOT NULL,
        [Logical Name]          sysname       NOT NULL,
        [Physical Name]         nvarchar(260) NOT NULL,
        [Current Size (MB)]     decimal(18,2) NOT NULL,
        [Current Size (GB)]     decimal(18,3) NOT NULL,
        [Growth Type]           varchar(10)   NOT NULL,   -- 'MB' or 'PERCENT'
        [Growth (MB)]           decimal(18,2) NULL,
        [Growth (%)]            int           NULL,
        [Max Size (MB)]         decimal(18,2) NULL,
        [Max Size (GB)]         decimal(18,3) NULL,
        [Max Size Desc]         varchar(20)   NOT NULL,   -- 'UNLIMITED' or numeric text
        [Remaining to Max (MB)] decimal(18,2) NULL,
        [Remaining to Max (GB)] decimal(18,3) NULL,
        CONSTRAINT PK_LogFiles PRIMARY KEY CLUSTERED
        (
            SnapshotDate, [Database Name], [File ID]
        )
    );
END
GO

-- Drop and recreate the procedure
IF OBJECT_ID(N'[log].[usp_LogOverview]', 'P') IS NOT NULL
    DROP PROCEDURE [log].[usp_LogOverview];
GO

CREATE PROCEDURE [log].[usp_LogOverview]
      @DbNameFilter           sysname = NULL      -- e.g. N'BI_RAW' (NULL = all DBs)
    , @MaxLogBackupAgeMinutes int     = 120       -- "freshness" policy for last log backup
    , @ResultFillPct          int     = 90        -- target fill % after shrink
    , @MinTargetMB            int     = 256       -- minimum target size (MB) after shrink
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SnapshotDate datetime2(0) = SYSDATETIME();

    PRINT CONCAT('Taking log snapshot @ ', CONVERT(varchar(19), @SnapshotDate, 120));

    /* -------------------------------------------------------------
       1) Read current log usage via DBCC SQLPERF(LOGSPACE)
          -> insert into TABLE VARIABLE (no #temp)
       ------------------------------------------------------------- */
    DECLARE @LogSpace TABLE
    (
        DatabaseName     sysname,
        LogSizeMB        float,
        LogSpaceUsedPct  float,
        [Status]         int
    );

    INSERT INTO @LogSpace
    EXEC('DBCC SQLPERF(LOGSPACE)');

    /* Optionally filter early for performance */
    IF @DbNameFilter IS NOT NULL
        DELETE FROM @LogSpace WHERE DatabaseName <> @DbNameFilter;

    /* Persist into log.LogSpace with snapshot timestamp */
    INSERT INTO log.LogSpace (SnapshotDate, DatabaseName, LogSizeMB, LogSpaceUsedPct, [Status])
    SELECT
        @SnapshotDate,
        ls.DatabaseName,
        CAST(ls.LogSizeMB AS decimal(18,2)),
        CAST(ls.LogSpaceUsedPct AS decimal(5,2)),
        ls.[Status]
    FROM @LogSpace ls;

    /* -------------------------------------------------------------
       2) Build details using CTEs over @LogSpace + msdb + sys.databases
       ------------------------------------------------------------- */
    ;WITH BackupAgg AS
    (
        SELECT
            bs.database_name,
            LastFullBackup = MAX(CASE WHEN bs.[type] = 'D' THEN bs.backup_finish_date END),
            LastLogBackup  = MAX(CASE WHEN bs.[type] = 'L' THEN bs.backup_finish_date END)
        FROM msdb.dbo.backupset bs
        GROUP BY bs.database_name
    ),
    Detail AS
    (
        SELECT
            ls.DatabaseName                                        AS [Database Name],
            CAST(ls.LogSizeMB AS decimal(18,2))                    AS [Log Size (MB)],
            CAST(ls.LogSizeMB/1024.0 AS decimal(18,3))             AS [Log Size (GB)],
            CAST(ls.LogSpaceUsedPct AS decimal(5,2))               AS [Log Space Used (%)],
            ls.[Status]                                            AS [Status],
            sd.recovery_model_desc                                 AS [Recovery Model],
            sd.log_reuse_wait_desc                                 AS [Log Reuse Wait],
            -- used space (theoretical)
            UsedMB = CAST(ls.LogSizeMB * (ls.LogSpaceUsedPct/100.0) AS decimal(18,2)),
            UsedGB = CAST(ls.LogSizeMB * (ls.LogSpaceUsedPct/100.0) / 1024.0 AS decimal(18,3)),
            HasFullBackup = CASE WHEN ba.LastFullBackup IS NOT NULL THEN 1 ELSE 0 END,
            HasLogBackup  = CASE WHEN ba.LastLogBackup  IS NOT NULL THEN 1 ELSE 0 END,
            AgeOfLogBackupMin = CAST(CASE
                                       WHEN ba.LastLogBackup IS NULL THEN NULL
                                       ELSE DATEDIFF(MINUTE, ba.LastLogBackup, GETDATE())
                                     END AS int),
            LastFullBackupAt = ba.LastFullBackup,
            LastLogBackupAt  = ba.LastLogBackup,
            Recommendation =
                CASE
                    WHEN sd.recovery_model_desc = 'SIMPLE' THEN
                        CASE WHEN ls.LogSpaceUsedPct < 20.0 THEN 'shrink' ELSE 'don''t shrink' END
                    WHEN sd.recovery_model_desc IN ('FULL','BULK_LOGGED') THEN
                        CASE
                            WHEN ba.LastFullBackup IS NULL
                                 OR ba.LastLogBackup IS NULL
                                 OR DATEDIFF(MINUTE, ba.LastLogBackup, GETDATE()) > @MaxLogBackupAgeMinutes
                                 OR sd.log_reuse_wait_desc IN ('LOG_BACKUP','ACTIVE_TRANSACTION',
                                                               'ACTIVE_BACKUP_OR_RESTORE','REPLICATION',
                                                               'AVAILABILITY_REPLICA')
                            THEN 'don''t shrink'
                            WHEN ls.LogSpaceUsedPct < 20.0 THEN 'shrink'
                            ELSE 'don''t shrink'
                        END
                    ELSE 'don''t shrink'
                END,
            ProjectedSizeMB =
                CAST(CASE
                         WHEN
                         (
                             (sd.recovery_model_desc = 'SIMPLE' AND ls.LogSpaceUsedPct < 20.0)
                          OR (sd.recovery_model_desc IN ('FULL','BULK_LOGGED')
                              AND ba.LastFullBackup IS NOT NULL
                              AND ba.LastLogBackup  IS NOT NULL
                              AND DATEDIFF(MINUTE, ba.LastLogBackup, GETDATE()) <= @MaxLogBackupAgeMinutes
                              AND sd.log_reuse_wait_desc NOT IN ('LOG_BACKUP','ACTIVE_TRANSACTION',
                                                                 'ACTIVE_BACKUP_OR_RESTORE','REPLICATION',
                                                                 'AVAILABILITY_REPLICA')
                              AND ls.LogSpaceUsedPct < 20.0)
                         )
                         THEN
                            CASE
                                WHEN CEILING( (ls.LogSizeMB * (ls.LogSpaceUsedPct/100.0)) / (@ResultFillPct/100.0) ) < @MinTargetMB
                                     THEN @MinTargetMB
                                ELSE CEILING( (ls.LogSizeMB * (ls.LogSpaceUsedPct/100.0)) / (@ResultFillPct/100.0) )
                            END
                         ELSE NULL
                     END AS decimal(18,2)),
            ProjectedSizeGB =
                CAST(CASE
                         WHEN
                         (
                             (sd.recovery_model_desc = 'SIMPLE' AND ls.LogSpaceUsedPct < 20.0)
                          OR (sd.recovery_model_desc IN ('FULL','BULK_LOGGED')
                              AND ba.LastFullBackup IS NOT NULL
                              AND ba.LastLogBackup  IS NOT NULL
                              AND DATEDIFF(MINUTE, ba.LastLogBackup, GETDATE()) <= @MaxLogBackupAgeMinutes
                              AND sd.log_reuse_wait_desc NOT IN ('LOG_BACKUP','ACTIVE_TRANSACTION',
                                                                 'ACTIVE_BACKUP_OR_RESTORE','REPLICATION',
                                                                 'AVAILABILITY_REPLICA')
                              AND ls.LogSpaceUsedPct < 20.0)
                         )
                         THEN
                            CASE
                                WHEN CEILING( (ls.LogSizeMB * (ls.LogSpaceUsedPct/100.0)) / (@ResultFillPct/100.0) ) < @MinTargetMB
                                     THEN @MinTargetMB / 1024.0
                                ELSE CEILING( (ls.LogSizeMB * (ls.LogSpaceUsedPct/100.0)) / (@ResultFillPct/100.0) ) / 1024.0
                            END
                         ELSE NULL
                     END AS decimal(18,3))
        FROM @LogSpace ls
        JOIN sys.databases sd
          ON sd.name = ls.DatabaseName
        LEFT JOIN BackupAgg ba
          ON ba.database_name = ls.DatabaseName
    )
    INSERT INTO log.LogDetails
    (
        SnapshotDate, [Database Name], [Log Size (MB)], [Log Size (GB)], [Log Space Used (%)], [Status],
        [Recovery Model], [Log Reuse Wait], [Used (MB)], [Used (GB)],
        [Has Full Backup], [Has Log Backup], [Age of Log Backup (min)],
        [Last Full Backup At], [Last Log Backup At], [Recommendation],
        [Projected Size After Shrink (MB)], [Projected Size After Shrink (GB)]
    )
    SELECT
        @SnapshotDate,
        d.[Database Name],
        d.[Log Size (MB)],
        d.[Log Size (GB)],
        d.[Log Space Used (%)],
        d.[Status],
        d.[Recovery Model],
        d.[Log Reuse Wait],
        d.UsedMB,
        d.UsedGB,
        d.HasFullBackup,
        d.HasLogBackup,
        d.AgeOfLogBackupMin,
        d.LastFullBackupAt,
        d.LastLogBackupAt,
        d.Recommendation,
        d.ProjectedSizeMB,
        d.ProjectedSizeGB
    FROM Detail d
    WHERE (@DbNameFilter IS NULL OR d.[Database Name] = @DbNameFilter);

    /* -------------------------------------------------------------
       3) Per-log file growth/max settings -> log.LogFiles
       ------------------------------------------------------------- */
    INSERT INTO log.LogFiles
    (
        SnapshotDate, [Database Name], [File ID], [Logical Name], [Physical Name],
        [Current Size (MB)], [Current Size (GB)],
        [Growth Type], [Growth (MB)], [Growth (%)],
        [Max Size (MB)], [Max Size (GB)], [Max Size Desc],
        [Remaining to Max (MB)], [Remaining to Max (GB)]
    )
    SELECT
        @SnapshotDate,
        d.name                                        AS [Database Name],
        mf.file_id                                    AS [File ID],
        mf.name                                       AS [Logical Name],
        mf.physical_name                              AS [Physical Name],
        CAST(mf.size * 8.0 / 1024.0 AS decimal(18,2))                AS [Current Size (MB)],
        CAST(mf.size * 8.0 / 1024.0 / 1024.0 AS decimal(18,3))       AS [Current Size (GB)],
        CASE WHEN mf.is_percent_growth = 1 THEN 'PERCENT' ELSE 'MB' END AS [Growth Type],
        CAST(CASE WHEN mf.is_percent_growth = 1 THEN NULL
                  ELSE mf.growth * 8.0 / 1024.0 END AS decimal(18,2))   AS [Growth (MB)],
        CASE WHEN mf.is_percent_growth = 1 THEN mf.growth ELSE NULL END  AS [Growth (%)],
        CAST(CASE WHEN mf.max_size = -1 THEN NULL
                  ELSE mf.max_size * 8.0 / 1024.0 END AS decimal(18,2)) AS [Max Size (MB)],
        CAST(CASE WHEN mf.max_size = -1 THEN NULL
                  ELSE mf.max_size * 8.0 / 1024.0 / 1024.0 END AS decimal(18,3)) AS [Max Size (GB)],
        CASE WHEN mf.max_size = -1 THEN 'UNLIMITED'
             ELSE CONVERT(varchar(20), CAST(mf.max_size * 8.0 / 1024.0 AS decimal(18,2)))
        END AS [Max Size Desc],
        CAST(CASE WHEN mf.max_size = -1 THEN NULL
                  ELSE (mf.max_size - mf.size) * 8.0 / 1024.0 END AS decimal(18,2)) AS [Remaining to Max (MB)],
        CAST(CASE WHEN mf.max_size = -1 THEN NULL
                  ELSE (mf.max_size - mf.size) * 8.0 / 1024.0 / 1024.0 END AS decimal(18,3)) AS [Remaining to Max (GB)]
    FROM sys.master_files mf
    JOIN sys.databases d
      ON d.database_id = mf.database_id
    WHERE mf.type_desc = 'LOG'
      AND (@DbNameFilter IS NULL OR d.name = @DbNameFilter);

    /* (Optional) quick preview of what was just inserted (comment out if not desired) */
    -- SELECT * FROM log.LogSpace  WHERE SnapshotDate = @SnapshotDate ORDER BY DatabaseName;
    -- SELECT * FROM log.LogDetails WHERE SnapshotDate = @SnapshotDate ORDER BY [Database Name];
    -- SELECT * FROM log.LogFiles   WHERE SnapshotDate = @SnapshotDate ORDER BY [Database Name], [File ID];
END
GO
