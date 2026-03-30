SET NOCOUNT ON;

DECLARE @MinFreePct             DECIMAL(5,2) = 60.00; -- nur shrinken, wenn insgesamt mehr als X % Log frei sind
DECLARE @MinimumTargetSizeMB    INT          = 256;   -- keine Logdatei kleiner als dieser Wert

DECLARE @DBName                 SYSNAME;
DECLARE @LogFileCount           INT;
DECLARE @LogReuseWaitDesc       NVARCHAR(120);
DECLARE @ActiveTransactionCount INT;

DECLARE @DatabaseLogSizeMB      DECIMAL(18,2);
DECLARE @DatabaseLogUsedPct     DECIMAL(18,2);
DECLARE @DatabaseLogFreePct     DECIMAL(18,2);

DECLARE @FileId                 INT;
DECLARE @LogLogicalName         SYSNAME;
DECLARE @PhysicalName           NVARCHAR(260);

DECLARE @LogSizeMB              DECIMAL(18,2);
DECLARE @ActiveLogMB            DECIMAL(18,2);
DECLARE @ActiveLogPct           DECIMAL(18,2);
DECLARE @FileFreePct            DECIMAL(18,2);

DECLARE @TargetSizeMB           INT;
DECLARE @PotentialGainMB        DECIMAL(18,2);

DECLARE @AfterLogSizeMB         DECIMAL(18,2);
DECLARE @AfterActiveLogMB       DECIMAL(18,2);
DECLARE @AfterActiveLogPct      DECIMAL(18,2);
DECLARE @AfterFileFreePct       DECIMAL(18,2);

DECLARE @ActionStatus           NVARCHAR(200);
DECLARE @sql                    NVARCHAR(MAX);
DECLARE @ErrorMessage           NVARCHAR(4000);

IF OBJECT_ID('tempdb..#LogSpace') IS NOT NULL
    DROP TABLE #LogSpace;

CREATE TABLE #LogSpace
(
    [Database Name]      SYSNAME,
    [Log Size (MB)]      DECIMAL(18,2),
    [Log Space Used (%)] DECIMAL(18,2),
    [Status]             INT
);

DECLARE @LogFiles TABLE
(
    FileId               INT PRIMARY KEY,
    LogLogicalName       SYSNAME,
    PhysicalName         NVARCHAR(260),
    LogSizeMB_Before     DECIMAL(18,2),
    ActiveLogMB_Before   DECIMAL(18,2),
    ActiveLogPct_Before  DECIMAL(18,2),
    FileFreePct_Before   DECIMAL(18,2),
    TargetSizeMB         INT NULL,
    PotentialGainMB      DECIMAL(18,2) NULL
);

DECLARE @Result TABLE
(
    DatabaseName              SYSNAME,
    RecoveryModel             NVARCHAR(60),
    LogReuseWaitDesc          NVARCHAR(120),
    ActiveTransactionCount    INT,
    LogFileCount              INT,
    FileId                    INT NULL,
    LogLogicalName            SYSNAME NULL,
    PhysicalName              NVARCHAR(260) NULL,
    DatabaseLogSizeMB_Before  DECIMAL(18,2) NULL,
    DatabaseLogUsedPct_Before DECIMAL(18,2) NULL,
    DatabaseLogFreePct_Before DECIMAL(18,2) NULL,
    LogSizeMB_Before          DECIMAL(18,2) NULL,
    ActiveLogMB_Before        DECIMAL(18,2) NULL,
    ActiveLogPct_Before       DECIMAL(18,2) NULL,
    FileFreePct_Before        DECIMAL(18,2) NULL,
    TargetSizeMB              INT NULL,
    PotentialGainMB           DECIMAL(18,2) NULL,
    LogSizeMB_After           DECIMAL(18,2) NULL,
    ActiveLogMB_After         DECIMAL(18,2) NULL,
    ActiveLogPct_After        DECIMAL(18,2) NULL,
    FileFreePct_After         DECIMAL(18,2) NULL,
    ActionStatus              NVARCHAR(200),
    ErrorMessage              NVARCHAR(4000) NULL
);

DECLARE curDB CURSOR LOCAL FAST_FORWARD FOR
SELECT d.name
FROM sys.databases AS d
WHERE d.database_id > 4
  AND d.name <> N'tempdb'
  AND d.state_desc = N'ONLINE'
  AND d.is_read_only = 0
  AND d.recovery_model_desc = N'SIMPLE'
ORDER BY d.name;

OPEN curDB;
FETCH NEXT FROM curDB INTO @DBName;

WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        SET @LogFileCount           = NULL;
        SET @LogReuseWaitDesc       = NULL;
        SET @ActiveTransactionCount = 0;
        SET @DatabaseLogSizeMB      = NULL;
        SET @DatabaseLogUsedPct     = NULL;
        SET @DatabaseLogFreePct     = NULL;
        SET @ErrorMessage           = NULL;

        SELECT
            @LogFileCount = COUNT(*)
        FROM sys.master_files AS mf
        WHERE mf.database_id = DB_ID(@DBName)
          AND mf.type = 1;

        SELECT
            @LogReuseWaitDesc = d.log_reuse_wait_desc
        FROM sys.databases AS d
        WHERE d.name = @DBName;

        SELECT
            @ActiveTransactionCount = COUNT(DISTINCT at.transaction_id)
        FROM sys.dm_exec_sessions AS s
        INNER JOIN sys.dm_tran_session_transactions AS st
            ON st.session_id = s.session_id
        INNER JOIN sys.dm_tran_active_transactions AS at
            ON at.transaction_id = st.transaction_id
        INNER JOIN sys.dm_tran_database_transactions AS dt
            ON dt.transaction_id = at.transaction_id
        WHERE s.is_user_process = 1
          AND s.session_id <> @@SPID
          AND dt.database_id = DB_ID(@DBName)
          AND at.transaction_state NOT IN (3, 6, 8);

        IF ISNULL(@ActiveTransactionCount, 0) > 0
           OR @LogReuseWaitDesc = N'ACTIVE_TRANSACTION'
        BEGIN
            INSERT INTO @Result
            (
                DatabaseName, RecoveryModel, LogReuseWaitDesc, ActiveTransactionCount, LogFileCount, ActionStatus
            )
            VALUES
            (
                @DBName, N'SIMPLE', @LogReuseWaitDesc, @ActiveTransactionCount, @LogFileCount,
                N'Übersprungen: aktive Transaktionen vorhanden'
            );

            FETCH NEXT FROM curDB INTO @DBName;
            CONTINUE;
        END;

        IF @LogFileCount <= 1
        BEGIN
            INSERT INTO @Result
            (
                DatabaseName, RecoveryModel, LogReuseWaitDesc, ActiveTransactionCount, LogFileCount, ActionStatus
            )
            VALUES
            (
                @DBName, N'SIMPLE', @LogReuseWaitDesc, @ActiveTransactionCount, @LogFileCount,
                N'Übersprungen: nicht mehr als eine Logdatei'
            );

            FETCH NEXT FROM curDB INTO @DBName;
            CONTINUE;
        END;

        SET @sql = N'USE ' + QUOTENAME(@DBName) + N'; CHECKPOINT; CHECKPOINT;';
        EXEC sys.sp_executesql @sql;

        TRUNCATE TABLE #LogSpace;

        INSERT INTO #LogSpace
        EXEC (N'DBCC SQLPERF(LOGSPACE)');

        SELECT
            @DatabaseLogSizeMB  = ls.[Log Size (MB)],
            @DatabaseLogUsedPct = ls.[Log Space Used (%)],
            @DatabaseLogFreePct = CAST(100.0 - ls.[Log Space Used (%)] AS DECIMAL(18,2))
        FROM #LogSpace AS ls
        WHERE ls.[Database Name] = @DBName;

        IF @DatabaseLogFreePct <= @MinFreePct
        BEGIN
            INSERT INTO @Result
            (
                DatabaseName, RecoveryModel, LogReuseWaitDesc, ActiveTransactionCount, LogFileCount,
                DatabaseLogSizeMB_Before, DatabaseLogUsedPct_Before, DatabaseLogFreePct_Before,
                ActionStatus
            )
            VALUES
            (
                @DBName, N'SIMPLE', @LogReuseWaitDesc, @ActiveTransactionCount, @LogFileCount,
                @DatabaseLogSizeMB, @DatabaseLogUsedPct, @DatabaseLogFreePct,
                N'Übersprungen: Freiraum nicht größer als X %'
            );

            FETCH NEXT FROM curDB INTO @DBName;
            CONTINUE;
        END;

        DELETE FROM @LogFiles;

        INSERT INTO @LogFiles
        (
            FileId,
            LogLogicalName,
            PhysicalName,
            LogSizeMB_Before,
            ActiveLogMB_Before,
            ActiveLogPct_Before,
            FileFreePct_Before
        )
        SELECT
            mf.file_id,
            mf.name,
            mf.physical_name,
            CAST(mf.size / 128.0 AS DECIMAL(18,2)) AS LogSizeMB_Before,
            CAST(ISNULL(SUM(CASE WHEN li.vlf_active = 1 THEN li.vlf_size_mb ELSE 0 END), 0.0) AS DECIMAL(18,2)) AS ActiveLogMB_Before,
            CAST
            (
                CASE
                    WHEN mf.size > 0
                        THEN ISNULL(SUM(CASE WHEN li.vlf_active = 1 THEN li.vlf_size_mb ELSE 0 END), 0.0) * 100.0
                             / (mf.size / 128.0)
                    ELSE 0
                END
                AS DECIMAL(18,2)
            ) AS ActiveLogPct_Before,
            CAST
            (
                100.0 -
                CASE
                    WHEN mf.size > 0
                        THEN ISNULL(SUM(CASE WHEN li.vlf_active = 1 THEN li.vlf_size_mb ELSE 0 END), 0.0) * 100.0
                             / (mf.size / 128.0)
                    ELSE 0
                END
                AS DECIMAL(18,2)
            ) AS FileFreePct_Before
        FROM sys.master_files AS mf
        LEFT JOIN sys.dm_db_log_info(DB_ID(@DBName)) AS li
            ON li.file_id = mf.file_id
        WHERE mf.database_id = DB_ID(@DBName)
          AND mf.type = 1
        GROUP BY
            mf.file_id,
            mf.name,
            mf.physical_name,
            mf.size;

        UPDATE @LogFiles
        SET
            TargetSizeMB =
                CASE
                    WHEN CEILING(ActiveLogMB_Before * 2.0) > @MinimumTargetSizeMB
                        THEN CAST(CEILING(ActiveLogMB_Before * 2.0) AS INT)
                    ELSE @MinimumTargetSizeMB
                END,
            PotentialGainMB =
                CAST
                (
                    LogSizeMB_Before -
                    CASE
                        WHEN CEILING(ActiveLogMB_Before * 2.0) > @MinimumTargetSizeMB
                            THEN CAST(CEILING(ActiveLogMB_Before * 2.0) AS INT)
                        ELSE @MinimumTargetSizeMB
                    END
                    AS DECIMAL(18,2)
                );

        WHILE EXISTS (SELECT 1 FROM @LogFiles)
        BEGIN
            SELECT TOP (1)
                @FileId         = lf.FileId,
                @LogLogicalName = lf.LogLogicalName,
                @PhysicalName   = lf.PhysicalName,
                @LogSizeMB      = lf.LogSizeMB_Before,
                @ActiveLogMB    = lf.ActiveLogMB_Before,
                @ActiveLogPct   = lf.ActiveLogPct_Before,
                @FileFreePct    = lf.FileFreePct_Before,
                @TargetSizeMB   = lf.TargetSizeMB,
                @PotentialGainMB = lf.PotentialGainMB
            FROM @LogFiles AS lf
            ORDER BY lf.FileId;

            DELETE FROM @LogFiles
            WHERE FileId = @FileId;

            BEGIN TRY
                SET @AfterLogSizeMB    = NULL;
                SET @AfterActiveLogMB  = NULL;
                SET @AfterActiveLogPct = NULL;
                SET @AfterFileFreePct  = NULL;
                SET @ActionStatus      = NULL;
                SET @ErrorMessage      = NULL;

                IF @TargetSizeMB >= CEILING(@LogSizeMB)
                BEGIN
                    INSERT INTO @Result
                    (
                        DatabaseName, RecoveryModel, LogReuseWaitDesc, ActiveTransactionCount, LogFileCount,
                        FileId, LogLogicalName, PhysicalName,
                        DatabaseLogSizeMB_Before, DatabaseLogUsedPct_Before, DatabaseLogFreePct_Before,
                        LogSizeMB_Before, ActiveLogMB_Before, ActiveLogPct_Before, FileFreePct_Before,
                        TargetSizeMB, PotentialGainMB, ActionStatus
                    )
                    VALUES
                    (
                        @DBName, N'SIMPLE', @LogReuseWaitDesc, @ActiveTransactionCount, @LogFileCount,
                        @FileId, @LogLogicalName, @PhysicalName,
                        @DatabaseLogSizeMB, @DatabaseLogUsedPct, @DatabaseLogFreePct,
                        @LogSizeMB, @ActiveLogMB, @ActiveLogPct, @FileFreePct,
                        @TargetSizeMB, @PotentialGainMB, N'Übersprungen: Zielgröße nicht kleiner als Istgröße'
                    );

                    CONTINUE;
                END;

                SET @sql =
                    N'USE ' + QUOTENAME(@DBName) + N';
                      CHECKPOINT;
                      DBCC SHRINKFILE (' + CAST(@FileId AS NVARCHAR(20)) + N', ' + CAST(@TargetSizeMB AS NVARCHAR(20)) + N');';

                EXEC sys.sp_executesql @sql;

                SELECT
                    @AfterLogSizeMB = CAST(mf.size / 128.0 AS DECIMAL(18,2))
                FROM sys.master_files AS mf
                WHERE mf.database_id = DB_ID(@DBName)
                  AND mf.file_id = @FileId
                  AND mf.type = 1;

                SELECT
                    @AfterActiveLogMB =
                        CAST(ISNULL(SUM(CASE WHEN li.vlf_active = 1 THEN li.vlf_size_mb ELSE 0 END), 0.0) AS DECIMAL(18,2))
                FROM sys.dm_db_log_info(DB_ID(@DBName)) AS li
                WHERE li.file_id = @FileId;

                SET @AfterActiveLogPct =
                    CAST
                    (
                        CASE
                            WHEN @AfterLogSizeMB > 0
                                THEN @AfterActiveLogMB * 100.0 / @AfterLogSizeMB
                            ELSE 0
                        END
                        AS DECIMAL(18,2)
                    );

                SET @AfterFileFreePct =
                    CAST(100.0 - @AfterActiveLogPct AS DECIMAL(18,2));

                SET @ActionStatus =
                    CASE
                        WHEN @AfterLogSizeMB < @LogSizeMB THEN N'Geschrumpft'
                        ELSE N'Shrink ausgeführt, aber keine Größenänderung'
                    END;

                INSERT INTO @Result
                (
                    DatabaseName, RecoveryModel, LogReuseWaitDesc, ActiveTransactionCount, LogFileCount,
                    FileId, LogLogicalName, PhysicalName,
                    DatabaseLogSizeMB_Before, DatabaseLogUsedPct_Before, DatabaseLogFreePct_Before,
                    LogSizeMB_Before, ActiveLogMB_Before, ActiveLogPct_Before, FileFreePct_Before,
                    TargetSizeMB, PotentialGainMB,
                    LogSizeMB_After, ActiveLogMB_After, ActiveLogPct_After, FileFreePct_After,
                    ActionStatus
                )
                VALUES
                (
                    @DBName, N'SIMPLE', @LogReuseWaitDesc, @ActiveTransactionCount, @LogFileCount,
                    @FileId, @LogLogicalName, @PhysicalName,
                    @DatabaseLogSizeMB, @DatabaseLogUsedPct, @DatabaseLogFreePct,
                    @LogSizeMB, @ActiveLogMB, @ActiveLogPct, @FileFreePct,
                    @TargetSizeMB, @PotentialGainMB,
                    @AfterLogSizeMB, @AfterActiveLogMB, @AfterActiveLogPct, @AfterFileFreePct,
                    @ActionStatus
                );
            END TRY
            BEGIN CATCH
                SET @ErrorMessage = ERROR_MESSAGE();

                INSERT INTO @Result
                (
                    DatabaseName, RecoveryModel, LogReuseWaitDesc, ActiveTransactionCount, LogFileCount,
                    FileId, LogLogicalName, PhysicalName,
                    DatabaseLogSizeMB_Before, DatabaseLogUsedPct_Before, DatabaseLogFreePct_Before,
                    LogSizeMB_Before, ActiveLogMB_Before, ActiveLogPct_Before, FileFreePct_Before,
                    TargetSizeMB, PotentialGainMB, ActionStatus, ErrorMessage
                )
                VALUES
                (
                    @DBName, N'SIMPLE', @LogReuseWaitDesc, @ActiveTransactionCount, @LogFileCount,
                    @FileId, @LogLogicalName, @PhysicalName,
                    @DatabaseLogSizeMB, @DatabaseLogUsedPct, @DatabaseLogFreePct,
                    @LogSizeMB, @ActiveLogMB, @ActiveLogPct, @FileFreePct,
                    @TargetSizeMB, @PotentialGainMB, N'Fehler', @ErrorMessage
                );
            END CATCH;
        END;
    END TRY
    BEGIN CATCH
        SET @ErrorMessage = ERROR_MESSAGE();

        INSERT INTO @Result
        (
            DatabaseName, RecoveryModel, LogReuseWaitDesc, ActiveTransactionCount, LogFileCount,
            DatabaseLogSizeMB_Before, DatabaseLogUsedPct_Before, DatabaseLogFreePct_Before,
            ActionStatus, ErrorMessage
        )
        VALUES
        (
            @DBName, N'SIMPLE', @LogReuseWaitDesc, @ActiveTransactionCount, @LogFileCount,
            @DatabaseLogSizeMB, @DatabaseLogUsedPct, @DatabaseLogFreePct,
            N'Fehler', @ErrorMessage
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
    ActiveTransactionCount,
    LogFileCount,
    FileId,
    LogLogicalName,
    PhysicalName,
    DatabaseLogSizeMB_Before,
    DatabaseLogUsedPct_Before,
    DatabaseLogFreePct_Before,
    LogSizeMB_Before,
    ActiveLogMB_Before,
    ActiveLogPct_Before,
    FileFreePct_Before,
    TargetSizeMB,
    PotentialGainMB,
    LogSizeMB_After,
    ActiveLogMB_After,
    ActiveLogPct_After,
    FileFreePct_After,
    ActionStatus,
    ErrorMessage
FROM @Result
ORDER BY
    CASE
        WHEN ActionStatus = N'Geschrumpft' THEN 0
        WHEN ActionStatus = N'Shrink ausgeführt, aber keine Größenänderung' THEN 1
        WHEN ActionStatus LIKE N'Übersprungen:%' THEN 2
        ELSE 3
    END,
    PotentialGainMB DESC,
    DatabaseName,
    FileId;
