/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "Install_DatabaseSizeGrowthMonitor.sql"
script_version: "1.0"
script_type: "solution-install"
chapter: "72_SQLAgent_Jobs_Alerts"
purpose: >
  Installiert eine wiederverwendbare Monitoring-Loesung, die taeglich
  Datenbank-, Datei- und Tabellengroessen in einem zentralen Schema
  protokolliert und Wachstum zwischen zwei Snapshots auswertbar macht.

parameters:
  - name: "@CreateSqlAgentJob"
    description: "1 = SQL-Agent-Job fuer taegliche Snapshots anlegen/aktualisieren"
  - name: "@IncludeSystemDatabases"
    description: "1 = master/model/msdb/tempdb ebenfalls erfassen"
  - name: "@SnapshotRetentionDays"
    description: "Historie aelter als diese Anzahl Tage nach erfolgreichem Capture loeschen"

result_sets:
  - name: "CaptureSummary"
    description: "Wird von size_monitoring.CaptureDatabaseSizeSnapshot nach einem Lauf ausgegeben"

dependencies:
  - "SQL Server Agent"
  - "msdb.dbo.sp_add_job"
  - "sys.database_files"
  - "sys.dm_db_partition_stats"
  - "sys.dm_db_log_space_usage"

safety:
  level: "creates-monitoring-objects"
  writes_data: true

documentation:
  markdown_file: "T-SQL/72_SQLAgent_Jobs_Alerts/Solutions/DatabaseSizeGrowthMonitor/README.md"

main_responsible:
  name: "Erhard Rainer"
  initials: "ER"

version_history:
  - version: "1.0"
    date: "2026-05-11"
    user: "ER"
    description: "Erstversion der DatabaseSizeGrowthMonitor-Loesung"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

IF SCHEMA_ID(N'size_monitoring') IS NULL
BEGIN
    EXEC(N'CREATE SCHEMA size_monitoring AUTHORIZATION dbo;');
END;

IF OBJECT_ID(N'size_monitoring.SnapshotRun', N'U') IS NULL
BEGIN
    CREATE TABLE size_monitoring.SnapshotRun
    (
        SnapshotRunId BIGINT IDENTITY(1, 1) NOT NULL
            CONSTRAINT PK_size_monitoring_SnapshotRun PRIMARY KEY,
        SnapshotTimeUtc DATETIME2(0) NOT NULL
            CONSTRAINT DF_size_monitoring_SnapshotRun_SnapshotTimeUtc DEFAULT SYSUTCDATETIME(),
        ServerName SYSNAME NOT NULL,
        InstanceName SYSNAME NULL,
        CaptureDatabaseName SYSNAME NOT NULL,
        IncludeSystemDatabases BIT NOT NULL,
        SnapshotRetentionDays INT NULL,
        StartedAtUtc DATETIME2(0) NOT NULL,
        FinishedAtUtc DATETIME2(0) NULL,
        Status VARCHAR(30) NOT NULL
            CONSTRAINT DF_size_monitoring_SnapshotRun_Status DEFAULT ('running'),
        ErrorNumber INT NULL,
        ErrorMessage NVARCHAR(4000) NULL
    );
END;

IF OBJECT_ID(N'size_monitoring.DatabaseSizeSnapshot', N'U') IS NULL
BEGIN
    CREATE TABLE size_monitoring.DatabaseSizeSnapshot
    (
        SnapshotRunId BIGINT NOT NULL,
        DatabaseId INT NOT NULL,
        DatabaseName SYSNAME NOT NULL,
        StateDesc NVARCHAR(60) NOT NULL,
        RecoveryModelDesc NVARCHAR(60) NOT NULL,
        CompatibilityLevel TINYINT NOT NULL,
        DataFileCount INT NOT NULL,
        LogFileCount INT NOT NULL,
        DataSizeMB DECIMAL(19, 2) NOT NULL,
        LogSizeMB DECIMAL(19, 2) NOT NULL,
        TotalSizeMB DECIMAL(19, 2) NOT NULL,
        DataUsedMB DECIMAL(19, 2) NULL,
        DataFreeMB DECIMAL(19, 2) NULL,
        LogUsedMB DECIMAL(19, 2) NULL,
        LogUsedPct DECIMAL(9, 2) NULL,
        CONSTRAINT PK_size_monitoring_DatabaseSizeSnapshot
            PRIMARY KEY (SnapshotRunId, DatabaseId),
        CONSTRAINT FK_size_monitoring_DatabaseSizeSnapshot_SnapshotRun
            FOREIGN KEY (SnapshotRunId)
            REFERENCES size_monitoring.SnapshotRun (SnapshotRunId)
    );
END;

IF OBJECT_ID(N'size_monitoring.DatabaseFileSizeSnapshot', N'U') IS NULL
BEGIN
    CREATE TABLE size_monitoring.DatabaseFileSizeSnapshot
    (
        SnapshotRunId BIGINT NOT NULL,
        DatabaseId INT NOT NULL,
        DatabaseName SYSNAME NOT NULL,
        FileId INT NOT NULL,
        FileTypeDesc NVARCHAR(60) NOT NULL,
        LogicalFileName SYSNAME NOT NULL,
        PhysicalFileName NVARCHAR(260) NOT NULL,
        SizeMB DECIMAL(19, 2) NOT NULL,
        UsedMB DECIMAL(19, 2) NULL,
        FreeMB DECIMAL(19, 2) NULL,
        GrowthValue INT NOT NULL,
        GrowthUnit VARCHAR(10) NOT NULL,
        GrowthMB DECIMAL(19, 2) NULL,
        MaxSizeValue INT NOT NULL,
        MaxSizeMB DECIMAL(19, 2) NULL,
        CONSTRAINT PK_size_monitoring_DatabaseFileSizeSnapshot
            PRIMARY KEY (SnapshotRunId, DatabaseId, FileId),
        CONSTRAINT FK_size_monitoring_DatabaseFileSizeSnapshot_SnapshotRun
            FOREIGN KEY (SnapshotRunId)
            REFERENCES size_monitoring.SnapshotRun (SnapshotRunId)
    );
END;

IF OBJECT_ID(N'size_monitoring.TableSizeSnapshot', N'U') IS NULL
BEGIN
    CREATE TABLE size_monitoring.TableSizeSnapshot
    (
        SnapshotRunId BIGINT NOT NULL,
        DatabaseId INT NOT NULL,
        DatabaseName SYSNAME NOT NULL,
        ObjectId INT NOT NULL,
        SchemaName SYSNAME NOT NULL,
        TableName SYSNAME NOT NULL,
        TemporalTypeDesc NVARCHAR(60) NOT NULL,
        IsMemoryOptimized BIT NOT NULL,
        [RowCount] BIGINT NOT NULL,
        ReservedMB DECIMAL(19, 2) NOT NULL,
        UsedMB DECIMAL(19, 2) NOT NULL,
        DataMB DECIMAL(19, 2) NOT NULL,
        IndexMB DECIMAL(19, 2) NOT NULL,
        UnusedMB DECIMAL(19, 2) NOT NULL,
        TablePartitionCount INT NOT NULL,
        CONSTRAINT PK_size_monitoring_TableSizeSnapshot
            PRIMARY KEY (SnapshotRunId, DatabaseId, ObjectId),
        CONSTRAINT FK_size_monitoring_TableSizeSnapshot_SnapshotRun
            FOREIGN KEY (SnapshotRunId)
            REFERENCES size_monitoring.SnapshotRun (SnapshotRunId)
    );
END;

IF OBJECT_ID(N'size_monitoring.CaptureError', N'U') IS NULL
BEGIN
    CREATE TABLE size_monitoring.CaptureError
    (
        CaptureErrorId BIGINT IDENTITY(1, 1) NOT NULL
            CONSTRAINT PK_size_monitoring_CaptureError PRIMARY KEY,
        SnapshotRunId BIGINT NOT NULL,
        DatabaseId INT NULL,
        DatabaseName SYSNAME NULL,
        CapturePhase VARCHAR(50) NOT NULL,
        ErrorNumber INT NOT NULL,
        ErrorMessage NVARCHAR(4000) NOT NULL,
        CapturedAtUtc DATETIME2(0) NOT NULL
            CONSTRAINT DF_size_monitoring_CaptureError_CapturedAtUtc DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_size_monitoring_CaptureError_SnapshotRun
            FOREIGN KEY (SnapshotRunId)
            REFERENCES size_monitoring.SnapshotRun (SnapshotRunId)
    );
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'size_monitoring.SnapshotRun')
      AND name = N'IX_size_monitoring_SnapshotRun_SnapshotTimeUtc'
)
BEGIN
    CREATE INDEX IX_size_monitoring_SnapshotRun_SnapshotTimeUtc
    ON size_monitoring.SnapshotRun (SnapshotTimeUtc DESC)
    INCLUDE (Status, IncludeSystemDatabases);
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'size_monitoring.DatabaseSizeSnapshot')
      AND name = N'IX_size_monitoring_DatabaseSizeSnapshot_Database'
)
BEGIN
    CREATE INDEX IX_size_monitoring_DatabaseSizeSnapshot_Database
    ON size_monitoring.DatabaseSizeSnapshot (DatabaseName, SnapshotRunId)
    INCLUDE (TotalSizeMB, DataSizeMB, LogSizeMB, DataUsedMB, LogUsedMB);
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'size_monitoring.TableSizeSnapshot')
      AND name = N'IX_size_monitoring_TableSizeSnapshot_Table'
)
BEGIN
    CREATE INDEX IX_size_monitoring_TableSizeSnapshot_Table
    ON size_monitoring.TableSizeSnapshot (DatabaseName, SchemaName, TableName, SnapshotRunId)
    INCLUDE (ReservedMB, DataMB, IndexMB, [RowCount]);
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'size_monitoring.TableSizeSnapshot')
      AND name = N'IX_size_monitoring_TableSizeSnapshot_RunReserved'
)
BEGIN
    CREATE INDEX IX_size_monitoring_TableSizeSnapshot_RunReserved
    ON size_monitoring.TableSizeSnapshot (SnapshotRunId, ReservedMB DESC)
    INCLUDE (DatabaseName, SchemaName, TableName, [RowCount]);
END;
GO

CREATE OR ALTER PROCEDURE size_monitoring.CaptureDatabaseSizeSnapshot
    @IncludeSystemDatabases BIT = 0,
    @SnapshotRetentionDays INT = 400
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT OFF;

    DECLARE
        @SnapshotRunId BIGINT,
        @StartedAtUtc DATETIME2(0) = SYSUTCDATETIME(),
        @DatabaseId INT,
        @DatabaseName SYSNAME,
        @Sql NVARCHAR(MAX),
        @ErrorCount INT;

    CREATE TABLE #DatabaseFileSnapshot
    (
        DatabaseId INT NOT NULL,
        DatabaseName SYSNAME NOT NULL,
        FileId INT NOT NULL,
        FileTypeDesc NVARCHAR(60) NOT NULL,
        LogicalFileName SYSNAME NOT NULL,
        PhysicalFileName NVARCHAR(260) NOT NULL,
        SizeMB DECIMAL(19, 2) NOT NULL,
        UsedMB DECIMAL(19, 2) NULL,
        FreeMB DECIMAL(19, 2) NULL,
        GrowthValue INT NOT NULL,
        GrowthUnit VARCHAR(10) NOT NULL,
        GrowthMB DECIMAL(19, 2) NULL,
        MaxSizeValue INT NOT NULL,
        MaxSizeMB DECIMAL(19, 2) NULL
    );

    CREATE TABLE #DatabaseLogSpace
    (
        DatabaseId INT NOT NULL,
        DatabaseName SYSNAME NOT NULL,
        TotalLogSizeMB DECIMAL(19, 2) NULL,
        LogUsedMB DECIMAL(19, 2) NULL,
        LogUsedPct DECIMAL(9, 2) NULL
    );

    CREATE TABLE #TableSizeSnapshot
    (
        DatabaseId INT NOT NULL,
        DatabaseName SYSNAME NOT NULL,
        ObjectId INT NOT NULL,
        SchemaName SYSNAME NOT NULL,
        TableName SYSNAME NOT NULL,
        TemporalTypeDesc NVARCHAR(60) NOT NULL,
        IsMemoryOptimized BIT NOT NULL,
        [RowCount] BIGINT NOT NULL,
        ReservedMB DECIMAL(19, 2) NOT NULL,
        UsedMB DECIMAL(19, 2) NOT NULL,
        DataMB DECIMAL(19, 2) NOT NULL,
        IndexMB DECIMAL(19, 2) NOT NULL,
        UnusedMB DECIMAL(19, 2) NOT NULL,
        TablePartitionCount INT NOT NULL
    );

    CREATE TABLE #CaptureError
    (
        DatabaseId INT NULL,
        DatabaseName SYSNAME NULL,
        CapturePhase VARCHAR(50) NOT NULL,
        ErrorNumber INT NOT NULL,
        ErrorMessage NVARCHAR(4000) NOT NULL
    );

    BEGIN TRY
        INSERT size_monitoring.SnapshotRun
        (
            ServerName,
            InstanceName,
            CaptureDatabaseName,
            IncludeSystemDatabases,
            SnapshotRetentionDays,
            StartedAtUtc,
            Status
        )
        VALUES
        (
            CONVERT(SYSNAME, @@SERVERNAME),
            CONVERT(SYSNAME, SERVERPROPERTY(N'InstanceName')),
            DB_NAME(),
            @IncludeSystemDatabases,
            @SnapshotRetentionDays,
            @StartedAtUtc,
            'running'
        );

        SET @SnapshotRunId = SCOPE_IDENTITY();

        DECLARE DatabaseCursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT
                d.database_id,
                d.name
            FROM sys.databases AS d
            WHERE d.state_desc = N'ONLINE'
              AND d.source_database_id IS NULL
              AND HAS_DBACCESS(d.name) = 1
              AND (@IncludeSystemDatabases = 1 OR d.database_id > 4)
            ORDER BY d.database_id;

        OPEN DatabaseCursor;

        FETCH NEXT FROM DatabaseCursor INTO @DatabaseId, @DatabaseName;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @Sql = N'
USE ' + QUOTENAME(@DatabaseName) + N';

BEGIN TRY
    INSERT #DatabaseFileSnapshot
    (
        DatabaseId,
        DatabaseName,
        FileId,
        FileTypeDesc,
        LogicalFileName,
        PhysicalFileName,
        SizeMB,
        UsedMB,
        FreeMB,
        GrowthValue,
        GrowthUnit,
        GrowthMB,
        MaxSizeValue,
        MaxSizeMB
    )
    SELECT
        DB_ID() AS DatabaseId,
        DB_NAME() AS DatabaseName,
        df.file_id AS FileId,
        df.type_desc AS FileTypeDesc,
        df.name AS LogicalFileName,
        df.physical_name AS PhysicalFileName,
        CAST(df.size / 128.0 AS DECIMAL(19, 2)) AS SizeMB,
        CASE
            WHEN df.type_desc = N''ROWS''
                THEN CAST(FILEPROPERTY(df.name, N''SpaceUsed'') / 128.0 AS DECIMAL(19, 2))
            ELSE NULL
        END AS UsedMB,
        CASE
            WHEN df.type_desc = N''ROWS''
                THEN CAST((df.size - FILEPROPERTY(df.name, N''SpaceUsed'')) / 128.0 AS DECIMAL(19, 2))
            ELSE NULL
        END AS FreeMB,
        df.growth AS GrowthValue,
        CASE WHEN df.is_percent_growth = 1 THEN ''PERCENT'' ELSE ''MB'' END AS GrowthUnit,
        CASE
            WHEN df.is_percent_growth = 1 THEN NULL
            ELSE CAST(df.growth / 128.0 AS DECIMAL(19, 2))
        END AS GrowthMB,
        df.max_size AS MaxSizeValue,
        CASE
            WHEN df.max_size = -1 THEN NULL
            ELSE CAST(df.max_size / 128.0 AS DECIMAL(19, 2))
        END AS MaxSizeMB
    FROM sys.database_files AS df;
END TRY
BEGIN CATCH
    INSERT #CaptureError (DatabaseId, DatabaseName, CapturePhase, ErrorNumber, ErrorMessage)
    VALUES (DB_ID(), DB_NAME(), ''database-files'', ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH;

BEGIN TRY
    INSERT #DatabaseLogSpace
    (
        DatabaseId,
        DatabaseName,
        TotalLogSizeMB,
        LogUsedMB,
        LogUsedPct
    )
    SELECT
        DB_ID() AS DatabaseId,
        DB_NAME() AS DatabaseName,
        CAST(total_log_size_in_bytes / 1048576.0 AS DECIMAL(19, 2)) AS TotalLogSizeMB,
        CAST(used_log_space_in_bytes / 1048576.0 AS DECIMAL(19, 2)) AS LogUsedMB,
        CAST(used_log_space_in_percent AS DECIMAL(9, 2)) AS LogUsedPct
    FROM sys.dm_db_log_space_usage;
END TRY
BEGIN CATCH
    INSERT #CaptureError (DatabaseId, DatabaseName, CapturePhase, ErrorNumber, ErrorMessage)
    VALUES (DB_ID(), DB_NAME(), ''database-log-space'', ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH;

BEGIN TRY
    ;WITH TablePages AS
    (
        SELECT
            t.object_id AS ObjectId,
            s.name AS SchemaName,
            t.name AS TableName,
            t.temporal_type_desc AS TemporalTypeDesc,
            t.is_memory_optimized AS IsMemoryOptimized,
            SUM(CASE WHEN ps.index_id IN (0, 1) THEN ps.row_count ELSE 0 END) AS [RowCount],
            SUM(ps.reserved_page_count) AS ReservedPages,
            SUM(ps.used_page_count) AS UsedPages,
            SUM
            (
                CASE
                    WHEN ps.index_id IN (0, 1)
                        THEN ps.in_row_data_page_count
                           + ps.lob_used_page_count
                           + ps.row_overflow_used_page_count
                    ELSE 0
                END
            ) AS DataPages,
            COUNT(DISTINCT ps.partition_number) AS TablePartitionCount
        FROM sys.tables AS t
        INNER JOIN sys.schemas AS s
            ON s.schema_id = t.schema_id
        LEFT JOIN sys.dm_db_partition_stats AS ps
            ON ps.object_id = t.object_id
        WHERE t.is_ms_shipped = 0
        GROUP BY
            t.object_id,
            s.name,
            t.name,
            t.temporal_type_desc,
            t.is_memory_optimized
    )
    INSERT #TableSizeSnapshot
    (
        DatabaseId,
        DatabaseName,
        ObjectId,
        SchemaName,
        TableName,
        TemporalTypeDesc,
        IsMemoryOptimized,
        [RowCount],
        ReservedMB,
        UsedMB,
        DataMB,
        IndexMB,
        UnusedMB,
        TablePartitionCount
    )
    SELECT
        DB_ID() AS DatabaseId,
        DB_NAME() AS DatabaseName,
        ObjectId,
        SchemaName,
        TableName,
        TemporalTypeDesc,
        IsMemoryOptimized,
        COALESCE([RowCount], 0) AS [RowCount],
        CAST(COALESCE(ReservedPages, 0) / 128.0 AS DECIMAL(19, 2)) AS ReservedMB,
        CAST(COALESCE(UsedPages, 0) / 128.0 AS DECIMAL(19, 2)) AS UsedMB,
        CAST(COALESCE(DataPages, 0) / 128.0 AS DECIMAL(19, 2)) AS DataMB,
        CAST((COALESCE(UsedPages, 0) - COALESCE(DataPages, 0)) / 128.0 AS DECIMAL(19, 2)) AS IndexMB,
        CAST((COALESCE(ReservedPages, 0) - COALESCE(UsedPages, 0)) / 128.0 AS DECIMAL(19, 2)) AS UnusedMB,
        COALESCE(TablePartitionCount, 0) AS TablePartitionCount
    FROM TablePages;
END TRY
BEGIN CATCH
    INSERT #CaptureError (DatabaseId, DatabaseName, CapturePhase, ErrorNumber, ErrorMessage)
    VALUES (DB_ID(), DB_NAME(), ''table-sizes'', ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH;
';

            EXEC sys.sp_executesql @Sql;

            FETCH NEXT FROM DatabaseCursor INTO @DatabaseId, @DatabaseName;
        END;

        CLOSE DatabaseCursor;
        DEALLOCATE DatabaseCursor;

        INSERT size_monitoring.DatabaseFileSizeSnapshot
        (
            SnapshotRunId,
            DatabaseId,
            DatabaseName,
            FileId,
            FileTypeDesc,
            LogicalFileName,
            PhysicalFileName,
            SizeMB,
            UsedMB,
            FreeMB,
            GrowthValue,
            GrowthUnit,
            GrowthMB,
            MaxSizeValue,
            MaxSizeMB
        )
        SELECT
            @SnapshotRunId,
            DatabaseId,
            DatabaseName,
            FileId,
            FileTypeDesc,
            LogicalFileName,
            PhysicalFileName,
            SizeMB,
            UsedMB,
            FreeMB,
            GrowthValue,
            GrowthUnit,
            GrowthMB,
            MaxSizeValue,
            MaxSizeMB
        FROM #DatabaseFileSnapshot;

        INSERT size_monitoring.TableSizeSnapshot
        (
            SnapshotRunId,
            DatabaseId,
            DatabaseName,
            ObjectId,
            SchemaName,
            TableName,
            TemporalTypeDesc,
            IsMemoryOptimized,
            [RowCount],
            ReservedMB,
            UsedMB,
            DataMB,
            IndexMB,
            UnusedMB,
            TablePartitionCount
        )
        SELECT
            @SnapshotRunId,
            DatabaseId,
            DatabaseName,
            ObjectId,
            SchemaName,
            TableName,
            TemporalTypeDesc,
            IsMemoryOptimized,
            [RowCount],
            ReservedMB,
            UsedMB,
            DataMB,
            IndexMB,
            UnusedMB,
            TablePartitionCount
        FROM #TableSizeSnapshot;

        ;WITH FileAgg AS
        (
            SELECT
                DatabaseId,
                DatabaseName,
                SUM(CASE WHEN FileTypeDesc = N'ROWS' THEN 1 ELSE 0 END) AS DataFileCount,
                SUM(CASE WHEN FileTypeDesc = N'LOG' THEN 1 ELSE 0 END) AS LogFileCount,
                SUM(CASE WHEN FileTypeDesc = N'ROWS' THEN SizeMB ELSE 0 END) AS DataSizeMB,
                SUM(CASE WHEN FileTypeDesc = N'LOG' THEN SizeMB ELSE 0 END) AS LogSizeMB,
                SUM(SizeMB) AS TotalSizeMB,
                SUM(CASE WHEN FileTypeDesc = N'ROWS' THEN COALESCE(UsedMB, 0) ELSE 0 END) AS DataUsedMB,
                SUM(CASE WHEN FileTypeDesc = N'ROWS' THEN COALESCE(FreeMB, 0) ELSE 0 END) AS DataFreeMB
            FROM #DatabaseFileSnapshot
            GROUP BY
                DatabaseId,
                DatabaseName
        )
        INSERT size_monitoring.DatabaseSizeSnapshot
        (
            SnapshotRunId,
            DatabaseId,
            DatabaseName,
            StateDesc,
            RecoveryModelDesc,
            CompatibilityLevel,
            DataFileCount,
            LogFileCount,
            DataSizeMB,
            LogSizeMB,
            TotalSizeMB,
            DataUsedMB,
            DataFreeMB,
            LogUsedMB,
            LogUsedPct
        )
        SELECT
            @SnapshotRunId,
            d.database_id,
            d.name,
            d.state_desc,
            d.recovery_model_desc,
            d.compatibility_level,
            fa.DataFileCount,
            fa.LogFileCount,
            fa.DataSizeMB,
            fa.LogSizeMB,
            fa.TotalSizeMB,
            fa.DataUsedMB,
            fa.DataFreeMB,
            ls.LogUsedMB,
            ls.LogUsedPct
        FROM FileAgg AS fa
        INNER JOIN sys.databases AS d
            ON d.database_id = fa.DatabaseId
        LEFT JOIN #DatabaseLogSpace AS ls
            ON ls.DatabaseId = fa.DatabaseId;

        INSERT size_monitoring.CaptureError
        (
            SnapshotRunId,
            DatabaseId,
            DatabaseName,
            CapturePhase,
            ErrorNumber,
            ErrorMessage
        )
        SELECT
            @SnapshotRunId,
            DatabaseId,
            DatabaseName,
            CapturePhase,
            ErrorNumber,
            ErrorMessage
        FROM #CaptureError;

        SET @ErrorCount = (SELECT COUNT(*) FROM #CaptureError);

        IF @SnapshotRetentionDays IS NOT NULL AND @SnapshotRetentionDays > 0
        BEGIN
            CREATE TABLE #OldSnapshotRun
            (
                SnapshotRunId BIGINT NOT NULL PRIMARY KEY
            );

            INSERT #OldSnapshotRun (SnapshotRunId)
            SELECT SnapshotRunId
            FROM size_monitoring.SnapshotRun
            WHERE SnapshotTimeUtc < DATEADD(DAY, -@SnapshotRetentionDays, SYSUTCDATETIME())
              AND SnapshotRunId <> @SnapshotRunId;

            DELETE c
            FROM size_monitoring.CaptureError AS c
            INNER JOIN #OldSnapshotRun AS old
                ON old.SnapshotRunId = c.SnapshotRunId;

            DELETE t
            FROM size_monitoring.TableSizeSnapshot AS t
            INNER JOIN #OldSnapshotRun AS old
                ON old.SnapshotRunId = t.SnapshotRunId;

            DELETE f
            FROM size_monitoring.DatabaseFileSizeSnapshot AS f
            INNER JOIN #OldSnapshotRun AS old
                ON old.SnapshotRunId = f.SnapshotRunId;

            DELETE d
            FROM size_monitoring.DatabaseSizeSnapshot AS d
            INNER JOIN #OldSnapshotRun AS old
                ON old.SnapshotRunId = d.SnapshotRunId;

            DELETE r
            FROM size_monitoring.SnapshotRun AS r
            INNER JOIN #OldSnapshotRun AS old
                ON old.SnapshotRunId = r.SnapshotRunId;
        END;

        UPDATE size_monitoring.SnapshotRun
        SET
            FinishedAtUtc = SYSUTCDATETIME(),
            Status = CASE WHEN @ErrorCount > 0 THEN 'completed-with-errors' ELSE 'completed' END
        WHERE SnapshotRunId = @SnapshotRunId;

        SELECT
            @SnapshotRunId AS SnapshotRunId,
            CASE WHEN @ErrorCount > 0 THEN 'completed-with-errors' ELSE 'completed' END AS Status,
            (SELECT COUNT(*) FROM size_monitoring.DatabaseSizeSnapshot WHERE SnapshotRunId = @SnapshotRunId) AS DatabaseCount,
            (SELECT COUNT(*) FROM size_monitoring.DatabaseFileSizeSnapshot WHERE SnapshotRunId = @SnapshotRunId) AS FileCount,
            (SELECT COUNT(*) FROM size_monitoring.TableSizeSnapshot WHERE SnapshotRunId = @SnapshotRunId) AS TableCount,
            @ErrorCount AS ErrorCount;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'DatabaseCursor') >= -1
        BEGIN
            IF CURSOR_STATUS('local', 'DatabaseCursor') > -1
                CLOSE DatabaseCursor;

            DEALLOCATE DatabaseCursor;
        END;

        IF @SnapshotRunId IS NOT NULL
        BEGIN
            UPDATE size_monitoring.SnapshotRun
            SET
                FinishedAtUtc = SYSUTCDATETIME(),
                Status = 'failed',
                ErrorNumber = ERROR_NUMBER(),
                ErrorMessage = ERROR_MESSAGE()
            WHERE SnapshotRunId = @SnapshotRunId;
        END;

        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE size_monitoring.ReportTableGrowthBetweenSnapshots
    @FromSnapshotRunId BIGINT = NULL,
    @ToSnapshotRunId BIGINT = NULL,
    @DatabaseName SYSNAME = NULL,
    @TopN INT = 50
AS
BEGIN
    SET NOCOUNT ON;

    IF @TopN IS NULL OR @TopN < 1
        SET @TopN = 50;

    DECLARE
        @EffectiveFromSnapshotRunId BIGINT = @FromSnapshotRunId,
        @EffectiveToSnapshotRunId BIGINT = @ToSnapshotRunId,
        @FromSnapshotTimeUtc DATETIME2(0),
        @ToSnapshotTimeUtc DATETIME2(0);

    IF @EffectiveToSnapshotRunId IS NULL
    BEGIN
        SELECT TOP (1)
            @EffectiveToSnapshotRunId = SnapshotRunId
        FROM size_monitoring.SnapshotRun
        WHERE Status IN ('completed', 'completed-with-errors')
        ORDER BY SnapshotTimeUtc DESC, SnapshotRunId DESC;
    END;

    IF @EffectiveFromSnapshotRunId IS NULL
    BEGIN
        SELECT TOP (1)
            @EffectiveFromSnapshotRunId = SnapshotRunId
        FROM size_monitoring.SnapshotRun
        WHERE Status IN ('completed', 'completed-with-errors')
          AND SnapshotRunId <> @EffectiveToSnapshotRunId
          AND SnapshotTimeUtc <=
          (
              SELECT SnapshotTimeUtc
              FROM size_monitoring.SnapshotRun
              WHERE SnapshotRunId = @EffectiveToSnapshotRunId
          )
        ORDER BY SnapshotTimeUtc DESC, SnapshotRunId DESC;
    END;

    IF @EffectiveFromSnapshotRunId IS NULL OR @EffectiveToSnapshotRunId IS NULL
        THROW 51000, 'Es sind mindestens zwei erfolgreiche Snapshot-Laeufe erforderlich.', 1;

    SELECT @FromSnapshotTimeUtc = SnapshotTimeUtc
    FROM size_monitoring.SnapshotRun
    WHERE SnapshotRunId = @EffectiveFromSnapshotRunId;

    SELECT @ToSnapshotTimeUtc = SnapshotTimeUtc
    FROM size_monitoring.SnapshotRun
    WHERE SnapshotRunId = @EffectiveToSnapshotRunId;

    ;WITH FromTables AS
    (
        SELECT *
        FROM size_monitoring.TableSizeSnapshot
        WHERE SnapshotRunId = @EffectiveFromSnapshotRunId
    ),
    ToTables AS
    (
        SELECT *
        FROM size_monitoring.TableSizeSnapshot
        WHERE SnapshotRunId = @EffectiveToSnapshotRunId
    )
    SELECT TOP (@TopN)
        @EffectiveFromSnapshotRunId AS FromSnapshotRunId,
        @FromSnapshotTimeUtc AS FromSnapshotTimeUtc,
        @EffectiveToSnapshotRunId AS ToSnapshotRunId,
        @ToSnapshotTimeUtc AS ToSnapshotTimeUtc,
        COALESCE(t2.DatabaseName, t1.DatabaseName) AS DatabaseName,
        COALESCE(t2.SchemaName, t1.SchemaName) AS SchemaName,
        COALESCE(t2.TableName, t1.TableName) AS TableName,
        CASE
            WHEN t1.ObjectId IS NULL THEN 'new'
            WHEN t2.ObjectId IS NULL THEN 'dropped'
            ELSE 'existing'
        END AS ChangeType,
        t1.[RowCount] AS FromRowCount,
        t2.[RowCount] AS ToRowCount,
        COALESCE(t2.[RowCount], 0) - COALESCE(t1.[RowCount], 0) AS RowCountDelta,
        t1.ReservedMB AS FromReservedMB,
        t2.ReservedMB AS ToReservedMB,
        COALESCE(t2.ReservedMB, 0) - COALESCE(t1.ReservedMB, 0) AS ReservedMBDelta,
        t1.DataMB AS FromDataMB,
        t2.DataMB AS ToDataMB,
        COALESCE(t2.DataMB, 0) - COALESCE(t1.DataMB, 0) AS DataMBDelta,
        t1.IndexMB AS FromIndexMB,
        t2.IndexMB AS ToIndexMB,
        COALESCE(t2.IndexMB, 0) - COALESCE(t1.IndexMB, 0) AS IndexMBDelta,
        t1.UnusedMB AS FromUnusedMB,
        t2.UnusedMB AS ToUnusedMB,
        COALESCE(t2.UnusedMB, 0) - COALESCE(t1.UnusedMB, 0) AS UnusedMBDelta
    FROM FromTables AS t1
    FULL OUTER JOIN ToTables AS t2
        ON t2.DatabaseName = t1.DatabaseName
       AND t2.SchemaName = t1.SchemaName
       AND t2.TableName = t1.TableName
    WHERE @DatabaseName IS NULL OR COALESCE(t2.DatabaseName, t1.DatabaseName) = @DatabaseName
    ORDER BY
        ReservedMBDelta DESC,
        COALESCE(t2.ReservedMB, t1.ReservedMB, 0) DESC,
        DatabaseName,
        SchemaName,
        TableName;
END;
GO

CREATE OR ALTER PROCEDURE size_monitoring.ReportDatabaseGrowthBetweenSnapshots
    @FromSnapshotRunId BIGINT = NULL,
    @ToSnapshotRunId BIGINT = NULL,
    @DatabaseName SYSNAME = NULL,
    @TopN INT = 50
AS
BEGIN
    SET NOCOUNT ON;

    IF @TopN IS NULL OR @TopN < 1
        SET @TopN = 50;

    DECLARE
        @EffectiveFromSnapshotRunId BIGINT = @FromSnapshotRunId,
        @EffectiveToSnapshotRunId BIGINT = @ToSnapshotRunId,
        @FromSnapshotTimeUtc DATETIME2(0),
        @ToSnapshotTimeUtc DATETIME2(0);

    IF @EffectiveToSnapshotRunId IS NULL
    BEGIN
        SELECT TOP (1)
            @EffectiveToSnapshotRunId = SnapshotRunId
        FROM size_monitoring.SnapshotRun
        WHERE Status IN ('completed', 'completed-with-errors')
        ORDER BY SnapshotTimeUtc DESC, SnapshotRunId DESC;
    END;

    IF @EffectiveFromSnapshotRunId IS NULL
    BEGIN
        SELECT TOP (1)
            @EffectiveFromSnapshotRunId = SnapshotRunId
        FROM size_monitoring.SnapshotRun
        WHERE Status IN ('completed', 'completed-with-errors')
          AND SnapshotRunId <> @EffectiveToSnapshotRunId
          AND SnapshotTimeUtc <=
          (
              SELECT SnapshotTimeUtc
              FROM size_monitoring.SnapshotRun
              WHERE SnapshotRunId = @EffectiveToSnapshotRunId
          )
        ORDER BY SnapshotTimeUtc DESC, SnapshotRunId DESC;
    END;

    IF @EffectiveFromSnapshotRunId IS NULL OR @EffectiveToSnapshotRunId IS NULL
        THROW 51001, 'Es sind mindestens zwei erfolgreiche Snapshot-Laeufe erforderlich.', 1;

    SELECT @FromSnapshotTimeUtc = SnapshotTimeUtc
    FROM size_monitoring.SnapshotRun
    WHERE SnapshotRunId = @EffectiveFromSnapshotRunId;

    SELECT @ToSnapshotTimeUtc = SnapshotTimeUtc
    FROM size_monitoring.SnapshotRun
    WHERE SnapshotRunId = @EffectiveToSnapshotRunId;

    ;WITH FromDatabases AS
    (
        SELECT *
        FROM size_monitoring.DatabaseSizeSnapshot
        WHERE SnapshotRunId = @EffectiveFromSnapshotRunId
    ),
    ToDatabases AS
    (
        SELECT *
        FROM size_monitoring.DatabaseSizeSnapshot
        WHERE SnapshotRunId = @EffectiveToSnapshotRunId
    )
    SELECT TOP (@TopN)
        @EffectiveFromSnapshotRunId AS FromSnapshotRunId,
        @FromSnapshotTimeUtc AS FromSnapshotTimeUtc,
        @EffectiveToSnapshotRunId AS ToSnapshotRunId,
        @ToSnapshotTimeUtc AS ToSnapshotTimeUtc,
        COALESCE(d2.DatabaseName, d1.DatabaseName) AS DatabaseName,
        CASE
            WHEN d1.DatabaseId IS NULL THEN 'new'
            WHEN d2.DatabaseId IS NULL THEN 'dropped'
            ELSE 'existing'
        END AS ChangeType,
        d1.TotalSizeMB AS FromTotalSizeMB,
        d2.TotalSizeMB AS ToTotalSizeMB,
        COALESCE(d2.TotalSizeMB, 0) - COALESCE(d1.TotalSizeMB, 0) AS TotalSizeMBDelta,
        d1.DataSizeMB AS FromDataSizeMB,
        d2.DataSizeMB AS ToDataSizeMB,
        COALESCE(d2.DataSizeMB, 0) - COALESCE(d1.DataSizeMB, 0) AS DataSizeMBDelta,
        d1.LogSizeMB AS FromLogSizeMB,
        d2.LogSizeMB AS ToLogSizeMB,
        COALESCE(d2.LogSizeMB, 0) - COALESCE(d1.LogSizeMB, 0) AS LogSizeMBDelta,
        d1.DataUsedMB AS FromDataUsedMB,
        d2.DataUsedMB AS ToDataUsedMB,
        COALESCE(d2.DataUsedMB, 0) - COALESCE(d1.DataUsedMB, 0) AS DataUsedMBDelta,
        d1.LogUsedMB AS FromLogUsedMB,
        d2.LogUsedMB AS ToLogUsedMB,
        COALESCE(d2.LogUsedMB, 0) - COALESCE(d1.LogUsedMB, 0) AS LogUsedMBDelta
    FROM FromDatabases AS d1
    FULL OUTER JOIN ToDatabases AS d2
        ON d2.DatabaseName = d1.DatabaseName
    WHERE @DatabaseName IS NULL OR COALESCE(d2.DatabaseName, d1.DatabaseName) = @DatabaseName
    ORDER BY
        TotalSizeMBDelta DESC,
        COALESCE(d2.TotalSizeMB, d1.TotalSizeMB, 0) DESC,
        DatabaseName;
END;
GO

DECLARE
    @CreateSqlAgentJob BIT = 1,
    @JobName SYSNAME = N'DatabaseSizeGrowthMonitor - Daily Snapshot',
    @JobStepName SYSNAME = N'Capture database size snapshot',
    @ScheduleName SYSNAME = N'DatabaseSizeGrowthMonitor - Daily 02:00',
    @CategoryName SYSNAME = N'Database Monitoring',
    @RunTimeHHMMSS INT = 20000, -- 02:00:00
    @IncludeSystemDatabases BIT = 0,
    @SnapshotRetentionDays INT = 400,
    @TargetDatabase SYSNAME = DB_NAME(),
    @JobId UNIQUEIDENTIFIER,
    @ExistingStepId INT,
    @Command NVARCHAR(MAX);

IF @CreateSqlAgentJob = 1
BEGIN
    SET @Command = N'EXEC size_monitoring.CaptureDatabaseSizeSnapshot' + CHAR(13) + CHAR(10)
        + N'    @IncludeSystemDatabases = ' + CONVERT(NVARCHAR(1), @IncludeSystemDatabases) + N',' + CHAR(13) + CHAR(10)
        + N'    @SnapshotRetentionDays = ' + CONVERT(NVARCHAR(20), @SnapshotRetentionDays) + N';';

    IF NOT EXISTS
    (
        SELECT 1
        FROM msdb.dbo.syscategories
        WHERE category_class = 1
          AND name = @CategoryName
    )
    BEGIN
        EXEC msdb.dbo.sp_add_category
            @class = N'JOB',
            @type = N'LOCAL',
            @name = @CategoryName;
    END;

    SELECT @JobId = job_id
    FROM msdb.dbo.sysjobs
    WHERE name = @JobName;

    IF @JobId IS NULL
    BEGIN
        EXEC msdb.dbo.sp_add_job
            @job_name = @JobName,
            @enabled = 1,
            @description = N'Captures database, file and table size snapshots into size_monitoring once per day.',
            @category_name = @CategoryName,
            @job_id = @JobId OUTPUT;
    END;

    SELECT @ExistingStepId = step_id
    FROM msdb.dbo.sysjobsteps
    WHERE job_id = @JobId
      AND step_name = @JobStepName;

    IF @ExistingStepId IS NOT NULL
    BEGIN
        EXEC msdb.dbo.sp_delete_jobstep
            @job_id = @JobId,
            @step_id = @ExistingStepId;
    END;

    EXEC msdb.dbo.sp_add_jobstep
        @job_id = @JobId,
        @step_name = @JobStepName,
        @subsystem = N'TSQL',
        @database_name = @TargetDatabase,
        @command = @Command,
        @retry_attempts = 1,
        @retry_interval = 5,
        @on_success_action = 1,
        @on_fail_action = 2;

    SELECT @ExistingStepId = step_id
    FROM msdb.dbo.sysjobsteps
    WHERE job_id = @JobId
      AND step_name = @JobStepName;

    EXEC msdb.dbo.sp_update_job
        @job_id = @JobId,
        @enabled = 1,
        @start_step_id = @ExistingStepId;

    IF NOT EXISTS
    (
        SELECT 1
        FROM msdb.dbo.sysschedules
        WHERE name = @ScheduleName
    )
    BEGIN
        EXEC msdb.dbo.sp_add_schedule
            @schedule_name = @ScheduleName,
            @enabled = 1,
            @freq_type = 4,
            @freq_interval = 1,
            @freq_subday_type = 1,
            @freq_subday_interval = 0,
            @active_start_time = @RunTimeHHMMSS;
    END
    ELSE
    BEGIN
        EXEC msdb.dbo.sp_update_schedule
            @name = @ScheduleName,
            @enabled = 1,
            @freq_type = 4,
            @freq_interval = 1,
            @freq_subday_type = 1,
            @freq_subday_interval = 0,
            @active_start_time = @RunTimeHHMMSS;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM msdb.dbo.sysjobschedules AS js
        INNER JOIN msdb.dbo.sysschedules AS s
            ON s.schedule_id = js.schedule_id
        WHERE js.job_id = @JobId
          AND s.name = @ScheduleName
    )
    BEGIN
        EXEC msdb.dbo.sp_attach_schedule
            @job_id = @JobId,
            @schedule_name = @ScheduleName;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM msdb.dbo.sysjobservers
        WHERE job_id = @JobId
    )
    BEGIN
        EXEC msdb.dbo.sp_add_jobserver
            @job_id = @JobId,
            @server_name = N'(LOCAL)';
    END;
END;
GO
