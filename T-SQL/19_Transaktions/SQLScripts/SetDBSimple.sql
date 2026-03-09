SET NOCOUNT ON;

DECLARE @DBName                SYSNAME        = N'DeineDatenbank';
DECLARE @ReserveAfterShrinkMB  INT            = 512;   -- freier Puffer nach dem Shrink
DECLARE @MinimumTargetSizeMB   INT            = 256;   -- Logdatei nie kleiner als dieser Wert
DECLARE @MinShrinkGainMB       INT            = 256;   -- nur shrinken, wenn mindestens so viele MB frei werden

DECLARE @RecoveryModelBefore   NVARCHAR(60);
DECLARE @RecoveryModelAfter    NVARCHAR(60);
DECLARE @LogReuseWaitDesc      NVARCHAR(120);

DECLARE @LogSizeMB             DECIMAL(18,2);
DECLARE @LogUsedPct            DECIMAL(18,2);
DECLARE @LogUsedMB             DECIMAL(18,2);
DECLARE @LogFreeMB             DECIMAL(18,2);

DECLARE @LogFileCount          INT;
DECLARE @LogFileId             INT;

DECLARE @ShrinkTargetMB        INT;
DECLARE @ShrinkGainMB          DECIMAL(18,2);

DECLARE @sql                   NVARCHAR(MAX);
DECLARE @Action                NVARCHAR(4000) = N'';
DECLARE @DidShrink             BIT = 0;

IF DB_ID(@DBName) IS NULL
BEGIN
    THROW 50000, 'Die angegebene Datenbank existiert nicht.', 1;
END;

IF OBJECT_ID('tempdb..#LogSpace') IS NOT NULL
    DROP TABLE #LogSpace;

CREATE TABLE #LogSpace
(
    [Database Name]      SYSNAME,
    [Log Size (MB)]      DECIMAL(18,2),
    [Log Space Used (%)] DECIMAL(18,2),
    [Status]             INT
);

INSERT INTO #LogSpace
EXEC ('DBCC SQLPERF(LOGSPACE)');

SELECT
    @RecoveryModelBefore = d.recovery_model_desc,
    @LogReuseWaitDesc    = d.log_reuse_wait_desc,
    @LogSizeMB           = ls.[Log Size (MB)],
    @LogUsedPct          = ls.[Log Space Used (%)],
    @LogUsedMB           = CAST(ls.[Log Size (MB)] * ls.[Log Space Used (%)] / 100.0 AS DECIMAL(18,2)),
    @LogFreeMB           = CAST(ls.[Log Size (MB)] * (100.0 - ls.[Log Space Used (%)]) / 100.0 AS DECIMAL(18,2))
FROM sys.databases AS d
INNER JOIN #LogSpace AS ls
    ON ls.[Database Name] = d.name
WHERE d.name = @DBName;

SELECT
    @LogFileCount = COUNT(*),
    @LogFileId    = CASE WHEN COUNT(*) = 1 THEN MAX(file_id) END
FROM sys.master_files
WHERE database_id = DB_ID(@DBName)
  AND type = 1; -- LOG

SELECT
    [Step]                = 'Before',
    DatabaseName          = @DBName,
    RecoveryModel         = @RecoveryModelBefore,
    LogReuseWaitDesc      = @LogReuseWaitDesc,
    LogFileCount          = @LogFileCount,
    LogSizeMB             = @LogSizeMB,
    LogUsedPct            = @LogUsedPct,
    LogUsedMB             = @LogUsedMB,
    LogFreeMB             = @LogFreeMB;

IF @RecoveryModelBefore <> N'SIMPLE'
BEGIN
    SET @sql = N'ALTER DATABASE ' + QUOTENAME(@DBName) + N' SET RECOVERY SIMPLE;';
    EXEC sys.sp_executesql @sql;
    SET @Action = N'Recovery Model wurde auf SIMPLE gesetzt. ';
END
ELSE
BEGIN
    SET @Action = N'Datenbank war bereits SIMPLE. ';
END;

SET @sql = N'USE ' + QUOTENAME(@DBName) + N'; CHECKPOINT;';
EXEC sys.sp_executesql @sql;

TRUNCATE TABLE #LogSpace;

INSERT INTO #LogSpace
EXEC ('DBCC SQLPERF(LOGSPACE)');

SELECT
    @RecoveryModelAfter = d.recovery_model_desc,
    @LogReuseWaitDesc   = d.log_reuse_wait_desc,
    @LogSizeMB          = ls.[Log Size (MB)],
    @LogUsedPct         = ls.[Log Space Used (%)],
    @LogUsedMB          = CAST(ls.[Log Size (MB)] * ls.[Log Space Used (%)] / 100.0 AS DECIMAL(18,2)),
    @LogFreeMB          = CAST(ls.[Log Size (MB)] * (100.0 - ls.[Log Space Used (%)]) / 100.0 AS DECIMAL(18,2))
FROM sys.databases AS d
INNER JOIN #LogSpace AS ls
    ON ls.[Database Name] = d.name
WHERE d.name = @DBName;

SET @ShrinkTargetMB =
    CASE
        WHEN CEILING(@LogUsedMB + @ReserveAfterShrinkMB) > @MinimumTargetSizeMB
            THEN CAST(CEILING(@LogUsedMB + @ReserveAfterShrinkMB) AS INT)
        ELSE @MinimumTargetSizeMB
    END;

SET @ShrinkGainMB = CAST(@LogSizeMB - @ShrinkTargetMB AS DECIMAL(18,2));

SELECT
    [Step]                = 'After Recovery Change / Checkpoint',
    DatabaseName          = @DBName,
    RecoveryModel         = @RecoveryModelAfter,
    LogReuseWaitDesc      = @LogReuseWaitDesc,
    LogFileCount          = @LogFileCount,
    LogSizeMB             = @LogSizeMB,
    LogUsedPct            = @LogUsedPct,
    LogUsedMB             = @LogUsedMB,
    LogFreeMB             = @LogFreeMB,
    ShrinkTargetMB        = @ShrinkTargetMB,
    ShrinkGainMB          = @ShrinkGainMB;

IF @LogFileCount <> 1
BEGIN
    SET @Action = @Action + N'Kein Shrink durchgeführt, da die Datenbank nicht genau eine Logdatei hat.';
END
ELSE IF @ShrinkGainMB < @MinShrinkGainMB
BEGIN
    SET @Action = @Action + N'Kein Shrink durchgeführt, da das Shrink-Potenzial kleiner als der Schwellwert ist.';
END
ELSE IF @ShrinkTargetMB >= CEILING(@LogSizeMB)
BEGIN
    SET @Action = @Action + N'Kein Shrink durchgeführt, da die Zielgröße nicht kleiner als die aktuelle Größe ist.';
END
ELSE
BEGIN
    SET @sql =
        N'USE ' + QUOTENAME(@DBName) + N';
          DBCC SHRINKFILE (' + CAST(@LogFileId AS NVARCHAR(20)) + N', ' + CAST(@ShrinkTargetMB AS NVARCHAR(20)) + N');';

    EXEC sys.sp_executesql @sql;

    SET @DidShrink = 1;
    SET @Action = @Action + N'Logdatei wurde geschrumpft.';
END;

TRUNCATE TABLE #LogSpace;

INSERT INTO #LogSpace
EXEC ('DBCC SQLPERF(LOGSPACE)');

SELECT
    @LogReuseWaitDesc = d.log_reuse_wait_desc,
    @LogSizeMB        = ls.[Log Size (MB)],
    @LogUsedPct       = ls.[Log Space Used (%)],
    @LogUsedMB        = CAST(ls.[Log Size (MB)] * ls.[Log Space Used (%)] / 100.0 AS DECIMAL(18,2)),
    @LogFreeMB        = CAST(ls.[Log Size (MB)] * (100.0 - ls.[Log Space Used (%)]) / 100.0 AS DECIMAL(18,2))
FROM sys.databases AS d
INNER JOIN #LogSpace AS ls
    ON ls.[Database Name] = d.name
WHERE d.name = @DBName;

SELECT
    [Step]                = 'Final',
    DatabaseName          = @DBName,
    RecoveryModel         = @RecoveryModelAfter,
    LogReuseWaitDesc      = @LogReuseWaitDesc,
    LogFileCount          = @LogFileCount,
    LogSizeMB             = @LogSizeMB,
    LogUsedPct            = @LogUsedPct,
    LogUsedMB             = @LogUsedMB,
    LogFreeMB             = @LogFreeMB,
    ShrinkTargetMB        = @ShrinkTargetMB,
    ShrinkPerformed       = @DidShrink,
    ActionSummary         = @Action;