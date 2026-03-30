SET NOCOUNT ON;

DECLARE @MinFreePct            DECIMAL(5,2) = 60.00; -- X: nur shrinken, wenn mehr als X % frei sind
DECLARE @MinimumTargetSizeMB   INT          = 256;   -- Logdatei nie kleiner als dieser Wert

DECLARE @DBName                SYSNAME;
DECLARE @LogLogicalName        SYSNAME;
DECLARE @LogFileCount          INT;

DECLARE @LogSizeMB             DECIMAL(18,2);
DECLARE @LogUsedPct            DECIMAL(18,2);
DECLARE @LogFreePct            DECIMAL(18,2);
DECLARE @LogUsedMB             DECIMAL(18,2);

DECLARE @TargetSizeMB          INT;
DECLARE @PotentialGainMB       DECIMAL(18,2);

DECLARE @AfterLogSizeMB        DECIMAL(18,2);
DECLARE @AfterLogUsedPct       DECIMAL(18,2);
DECLARE @AfterLogFreePct       DECIMAL(18,2);

DECLARE @LogReuseWaitDesc      NVARCHAR(120);
DECLARE @sql                   NVARCHAR(MAX);
DECLARE @ErrorMessage          NVARCHAR(4000);

IF OBJECT_ID('tempdb..#LogSpace') IS NOT NULL
    DROP TABLE #LogSpace;

CREATE TABLE #LogSpace
(
    [Database Name]      SYSNAME,
    [Log Size (MB)]      DECIMAL(18,2),
    [Log Space Used (%)] DECIMAL(18,2),
    [Status]             INT
);

IF OBJECT_ID('tempdb..#Result') IS NOT NULL
    DROP TABLE #Result;

CREATE TABLE #Result
(
    DatabaseName         SYSNAME,
    RecoveryModel        NVARCHAR(60),
    LogReuseWaitDesc     NVARCHAR(120),
    LogFileCount         INT,
    LogLogicalName       SYSNAME NULL,
    LogSizeMB_Before     DECIMAL(18,2) NULL,
    LogUsedPct_Before    DECIMAL(18,2) NULL,
    LogFreePct_Before    DECIMAL(18,2) NULL,
    TargetSizeMB         INT NULL,
    PotentialGainMB      DECIMAL(18,2) NULL,
    LogSizeMB_After      DECIMAL(18,2) NULL,
    LogUsedPct_After     DECIMAL(18,2) NULL,
    LogFreePct_After     DECIMAL(18,2) NULL,
    ActionStatus         NVARCHAR(200),
    ErrorMessage         NVARCHAR(4000) NULL
);

DECLARE curDB CURSOR LOCAL FAST_FORWARD FOR
SELECT d.name
FROM sys.databases AS d
WHERE d.database_id > 4              -- nur User-DBs
  AND d.name <> N'tempdb'            -- tempdb bewusst ausgenommen
  AND d.state_desc = N'ONLINE'
  AND d.is_read_only = 0
  AND d.recovery_model_desc = N'SIMPLE'
ORDER BY d.name;

OPEN curDB;
FETCH NEXT FROM curDB INTO @DBName;

WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        SET @LogLogicalName   = NULL;
        SET @LogFileCount     = NULL;
        SET @LogSizeMB        = NULL;
        SET @LogUsedPct       = NULL;
        SET @LogFreePct       = NULL;
        SET @LogUsedMB        = NULL;
        SET @TargetSizeMB     = NULL;
        SET @PotentialGainMB  = NULL;
        SET @AfterLogSizeMB   = NULL;
        SET @AfterLogUsedPct  = NULL;
        SET @AfterLogFreePct  = NULL;
        SET @LogReuseWaitDesc = NULL;
        SET @ErrorMessage     = NULL;

        SELECT
            @LogFileCount = COUNT(*),
            @LogLogicalName = CASE WHEN COUNT(*) = 1 THEN MAX(mf.name) END
        FROM sys.master_files AS mf
        WHERE mf.database_id = DB_ID(@DBName)
          AND mf.type = 1;

        SELECT
            @LogReuseWaitDesc = d.log_reuse_wait_desc
        FROM sys.databases AS d
        WHERE d.name = @DBName;

        IF @LogFileCount <> 1
        BEGIN
            INSERT INTO #Result
            (
                DatabaseName, RecoveryModel, LogReuseWaitDesc, LogFileCount, LogLogicalName, ActionStatus
            )
            VALUES
            (
                @DBName, N'SIMPLE', @LogReuseWaitDesc, @LogFileCount, @LogLogicalName, N'Übersprungen: nicht genau eine Logdatei'
            );

            FETCH NEXT FROM curDB INTO @DBName;
            CONTINUE;
        END;

        SET @sql = N'USE ' + QUOTENAME(@DBName) + N'; CHECKPOINT;';
        EXEC sys.sp_executesql @sql;

        TRUNCATE TABLE #LogSpace;
        INSERT INTO #LogSpace
        EXEC ('DBCC SQLPERF(LOGSPACE)');

        SELECT
            @LogSizeMB  = ls.[Log Size (MB)],
            @LogUsedPct = ls.[Log Space Used (%)]
        FROM #LogSpace AS ls
        WHERE ls.[Database Name] = @DBName;

        SET @LogFreePct = CAST(100.0 - @LogUsedPct AS DECIMAL(18,2));
        SET @LogUsedMB  = CAST(@LogSizeMB * @LogUsedPct / 100.0 AS DECIMAL(18,2));

        SET @TargetSizeMB =
            CASE
                WHEN CEILING(@LogUsedMB * 2.0) > @MinimumTargetSizeMB
                    THEN CAST(CEILING(@LogUsedMB * 2.0) AS INT)
                ELSE @MinimumTargetSizeMB
            END;

        SET @PotentialGainMB = CAST(@LogSizeMB - @TargetSizeMB AS DECIMAL(18,2));

        IF @LogFreePct <= @MinFreePct
        BEGIN
            INSERT INTO #Result
            (
                DatabaseName, RecoveryModel, LogReuseWaitDesc, LogFileCount, LogLogicalName,
                LogSizeMB_Before, LogUsedPct_Before, LogFreePct_Before,
                TargetSizeMB, PotentialGainMB, ActionStatus
            )
            VALUES
            (
                @DBName, N'SIMPLE', @LogReuseWaitDesc, @LogFileCount, @LogLogicalName,
                @LogSizeMB, @LogUsedPct, @LogFreePct,
                @TargetSizeMB, @PotentialGainMB, N'Übersprungen: Freiraum nicht größer als X %'
            );

            FETCH NEXT FROM curDB INTO @DBName;
            CONTINUE;
        END;

        IF @TargetSizeMB >= CEILING(@LogSizeMB)
        BEGIN
            INSERT INTO #Result
            (
                DatabaseName, RecoveryModel, LogReuseWaitDesc, LogFileCount, LogLogicalName,
                LogSizeMB_Before, LogUsedPct_Before, LogFreePct_Before,
                TargetSizeMB, PotentialGainMB, ActionStatus
            )
            VALUES
            (
                @DBName, N'SIMPLE', @LogReuseWaitDesc, @LogFileCount, @LogLogicalName,
                @LogSizeMB, @LogUsedPct, @LogFreePct,
                @TargetSizeMB, @PotentialGainMB, N'Übersprungen: Zielgröße nicht kleiner als Istgröße'
            );

            FETCH NEXT FROM curDB INTO @DBName;
            CONTINUE;
        END;

        SET @sql =
            N'USE ' + QUOTENAME(@DBName) + N';
              DBCC SHRINKFILE (N''' + REPLACE(@LogLogicalName, '''', '''''') + N''', ' + CAST(@TargetSizeMB AS NVARCHAR(20)) + N');';

        EXEC sys.sp_executesql @sql;

        TRUNCATE TABLE #LogSpace;
        INSERT INTO #LogSpace
        EXEC ('DBCC SQLPERF(LOGSPACE)');

        SELECT
            @AfterLogSizeMB  = ls.[Log Size (MB)],
            @AfterLogUsedPct = ls.[Log Space Used (%)]
        FROM #LogSpace AS ls
        WHERE ls.[Database Name] = @DBName;

        SET @AfterLogFreePct = CAST(100.0 - @AfterLogUsedPct AS DECIMAL(18,2));

        INSERT INTO #Result
        (
            DatabaseName, RecoveryModel, LogReuseWaitDesc, LogFileCount, LogLogicalName,
            LogSizeMB_Before, LogUsedPct_Before, LogFreePct_Before,
            TargetSizeMB, PotentialGainMB,
            LogSizeMB_After, LogUsedPct_After, LogFreePct_After,
            ActionStatus
        )
        VALUES
        (
            @DBName, N'SIMPLE', @LogReuseWaitDesc, @LogFileCount, @LogLogicalName,
            @LogSizeMB, @LogUsedPct, @LogFreePct,
            @TargetSizeMB, @PotentialGainMB,
            @AfterLogSizeMB, @AfterLogUsedPct, @AfterLogFreePct,
            N'Geschrumpft'
        );
    END TRY
    BEGIN CATCH
        SET @ErrorMessage = ERROR_MESSAGE();

        INSERT INTO #Result
        (
            DatabaseName, RecoveryModel, LogReuseWaitDesc, LogFileCount, LogLogicalName,
            LogSizeMB_Before, LogUsedPct_Before, LogFreePct_Before,
            TargetSizeMB, PotentialGainMB, ActionStatus, ErrorMessage
        )
        VALUES
        (
            @DBName, N'SIMPLE', @LogReuseWaitDesc, @LogFileCount, @LogLogicalName,
            @LogSizeMB, @LogUsedPct, @LogFreePct,
            @TargetSizeMB, @PotentialGainMB, N'Fehler', @ErrorMessage
        );
    END CATCH;

    FETCH NEXT FROM curDB INTO @DBName;
END;

CLOSE curDB;
DEALLOCATE curDB;

SELECT
    DatabaseName,
    RecoveryModel,
    LogReuseWaitDesc,
    LogFileCount,
    LogLogicalName,
    LogSizeMB_Before,
    LogUsedPct_Before,
    LogFreePct_Before,
    TargetSizeMB,
    PotentialGainMB,
    LogSizeMB_After,
    LogUsedPct_After,
    LogFreePct_After,
    ActionStatus,
    ErrorMessage
FROM #Result
ORDER BY
    CASE
        WHEN ActionStatus = N'Geschrumpft' THEN 0
        WHEN ActionStatus LIKE N'Übersprungen:%' THEN 1
        ELSE 2
    END,
    PotentialGainMB DESC,
    DatabaseName;