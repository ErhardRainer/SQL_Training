/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "ShrinkFullDatabase.sql"
script_version: "1.0"
script_type: "admin-change"
chapter: "19_Transaktions"

purpose: >
  Shrinkt die Logdatei einer einzelnen Datenbank im Recovery-Modell FULL
  oder BULK_LOGGED mit Guardrails fuer Full-Backup, Log-Backup-Kette,
  Log-Reuse-Wait, Mindestfreiraum und Zielgroesse. Das Skript kann zuerst
  als Preview laufen und fuehrt DBCC SHRINKFILE erst mit @ExecuteShrink = 1 aus.

parameters:
  - name: "@DatabaseName"
    sql_type: "SYSNAME"
    direction: "IN"
    required: true
    description: "Name der zu verarbeitenden Datenbank"
  - name: "@TakeLogBackupBeforeShrink"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = vor dem Shrink ein regulaeres Logbackup erstellen"
  - name: "@LogBackupDirectory"
    sql_type: "NVARCHAR(260)"
    direction: "IN"
    required: false
    description: "Zielordner fuer das optionale Logbackup; erforderlich wenn @TakeLogBackupBeforeShrink = 1"
  - name: "@BackupWithCompression"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = optionales Logbackup mit COMPRESSION ausfuehren"
  - name: "@MaxLogBackupAgeMinutes"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Maximales Alter des letzten Logbackups, wenn kein neues Logbackup erstellt wird"
  - name: "@ResultFillPct"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Ziel-Fuellgrad der Logdatei nach Shrink in Prozent"
  - name: "@MinimumTargetSizeMB"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Absolute Untergrenze fuer die Zielgroesse der Logdatei"
  - name: "@MinimumFreePct"
    sql_type: "DECIMAL(5,2)"
    direction: "IN"
    required: false
    description: "Mindestfreiraum in Prozent vor dem Shrink"
  - name: "@MinShrinkGainMB"
    sql_type: "DECIMAL(18,2)"
    direction: "IN"
    required: false
    description: "Mindestersparnis in MB; bei weniger Potenzial wird nicht geshrinkt"
  - name: "@AllowBulkLogged"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = BULK_LOGGED-Datenbanken duerfen verarbeitet werden"
  - name: "@AllowSystemDatabase"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = Systemdatenbanken duerfen verarbeitet werden"
  - name: "@ExecuteShrink"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "0 = Preview; 1 = optionales Logbackup und DBCC SHRINKFILE ausfuehren"

result_sets:
  - name: "ShrinkFullDatabaseResult"
    description: "Zusammenfassung der Guardrails, Zielgroesse, Aktion und Before/After-Werte"
  - name: "LogFileSnapshots"
    description: "Messpunkte der Logdatei vor Backup, nach Backup und nach dem Shrink-Versuch"
  - name: "ActionCommands"
    description: "Ausgefuehrte oder geplante Backup- und Shrink-Befehle"
  - name: "ScanErrors"
    description: "Fehler beim Lesen der Log- oder VLF-Informationen"

dependencies:
  - "DBCC SHRINKFILE"
  - "BACKUP LOG"
  - "sys.databases"
  - "sys.database_files"
  - "sys.dm_db_log_space_usage"
  - "sys.dm_db_log_info"
  - "msdb.dbo.backupset"
  - "sys.sp_executesql"
  - "tempdb temporary tables"

safety:
  level: "admin-change"
  writes_data: true

documentation:
  markdown_file: "T-SQL/19_Transaktions/SQLScripts/ShrinkFullDatabase.md"
  sync_blocks:
    - "SUMMARY_TABLE"
    - "PARAMETERS_TABLE"
    - "DEPENDENCIES_LIST"
    - "VERSION_HISTORY_TABLE"
    - "SQL_CODE"
  mermaid:
    mode: "ai-agent-from-sql"
    source: "script-body"

main_responsible:
  name: "Erhard Rainer"
  initials: "ER"

version_history:
  - version: "1.0"
    date: "2026-06-01"
    user: "ER"
    description: "Erstversion fuer gezielten Log-Shrink von FULL- und BULK_LOGGED-Datenbanken"

notes:
  - "Das Skript wechselt das Recovery Model nicht auf SIMPLE."
  - "Ein optionales Logbackup ist ein regulaeres Logbackup und gehoert zur Restore-Kette."
  - "Mehrere Logdateien werden bewusst nicht automatisch geshrinkt."
  - "Default ist Preview; echte Ausfuehrung erst mit @ExecuteShrink = 1."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

-- 1. Parameter vorbereiten
DECLARE @DatabaseName SYSNAME = N'DeineDatenbank';
DECLARE @TakeLogBackupBeforeShrink BIT = 0;
DECLARE @LogBackupDirectory NVARCHAR(260) = NULL; -- z. B. N'L:\SQLBackups\Log'
DECLARE @BackupWithCompression BIT = 0;
DECLARE @MaxLogBackupAgeMinutes INT = 60;
DECLARE @ResultFillPct INT = 90;
DECLARE @MinimumTargetSizeMB INT = 256;
DECLARE @MinimumFreePct DECIMAL(5, 2) = 60.00;
DECLARE @MinShrinkGainMB DECIMAL(18, 2) = 256.00;
DECLARE @AllowBulkLogged BIT = 1;
DECLARE @AllowSystemDatabase BIT = 0;
DECLARE @ExecuteShrink BIT = 0; -- 0 = Preview, 1 = optionales Logbackup und Shrink ausfuehren

DECLARE @DatabaseId INT;
DECLARE @StateDesc NVARCHAR(60);
DECLARE @RecoveryModelDesc NVARCHAR(60);
DECLARE @LogReuseWaitDesc NVARCHAR(120);
DECLARE @IsReadOnly BIT;
DECLARE @Sql NVARCHAR(MAX);
DECLARE @SnapshotSql NVARCHAR(MAX);
DECLARE @BackupSql NVARCHAR(MAX);
DECLARE @ShrinkSql NVARCHAR(MAX);
DECLARE @ActionStatus NVARCHAR(200) = N'Nicht gestartet';
DECLARE @Abort BIT = 0;
DECLARE @AbortReason NVARCHAR(4000) = N'';
DECLARE @LastFullBackupAt DATETIME;
DECLARE @LastLogBackupAt DATETIME;
DECLARE @LastLogBackupAgeMinutes INT;
DECLARE @NormalizedBackupDirectory NVARCHAR(260);
DECLARE @BackupFilePath NVARCHAR(4000);
DECLARE @SafeDatabaseName NVARCHAR(260);
DECLARE @TimestampSuffix CHAR(15);

DECLARE @LogFileCount INT;
DECLARE @LogFileId INT;
DECLARE @LogLogicalName SYSNAME;
DECLARE @LogPhysicalName NVARCHAR(260);
DECLARE @SizingSnapshotLabel VARCHAR(30);
DECLARE @SizingTotalLogMB DECIMAL(18, 2);
DECLARE @SizingUsedLogMB DECIMAL(18, 2);
DECLARE @SizingUsedLogPct DECIMAL(9, 2);
DECLARE @SizingFreePct DECIMAL(9, 2);
DECLARE @SizingLastActiveVlfEndMB DECIMAL(18, 2);
DECLARE @TargetByFillMB INT;
DECLARE @TargetByVlfMB INT;
DECLARE @TargetSizeMB INT;
DECLARE @PotentialGainMB DECIMAL(18, 2);
DECLARE @MeetsSizeThreshold BIT = 0;
DECLARE @ShrinkAttempted BIT = 0;
DECLARE @LogBackupAttempted BIT = 0;
DECLARE @LogBackupSucceeded BIT = 0;

DROP TABLE IF EXISTS #LogFileSnapshot;
DROP TABLE IF EXISTS #ActionCommands;
DROP TABLE IF EXISTS #ScanErrors;

CREATE TABLE #LogFileSnapshot
(
    SnapshotLabel VARCHAR(30) NOT NULL,
    SnapshotAt DATETIME2(0) NOT NULL,
    DatabaseId INT NOT NULL,
    DatabaseName SYSNAME NOT NULL,
    RecoveryModelDesc NVARCHAR(60) NOT NULL,
    LogReuseWaitDesc NVARCHAR(120) NOT NULL,
    IsReadOnly BIT NOT NULL,
    LogFileCount INT NOT NULL,
    FileId INT NOT NULL,
    LogicalFileName SYSNAME NOT NULL,
    PhysicalFileName NVARCHAR(260) NOT NULL,
    CurrentSizeMB DECIMAL(18, 2) NOT NULL,
    TotalLogMB DECIMAL(18, 2) NOT NULL,
    UsedLogMB DECIMAL(18, 2) NOT NULL,
    UsedLogPct DECIMAL(9, 2) NOT NULL,
    FreeLogPct DECIMAL(9, 2) NOT NULL,
    LogSinceLastBackupMB DECIMAL(18, 2) NULL,
    LastActiveVlfEndMB DECIMAL(18, 2) NULL
);

CREATE TABLE #ActionCommands
(
    StepName VARCHAR(40) NOT NULL,
    CommandStatus VARCHAR(30) NOT NULL,
    CommandText NVARCHAR(MAX) NULL,
    MessageText NVARCHAR(4000) NOT NULL,
    LoggedAt DATETIME2(0) NOT NULL
);

CREATE TABLE #ScanErrors
(
    SnapshotLabel VARCHAR(30) NULL,
    ErrorNumber INT NOT NULL,
    ErrorMessage NVARCHAR(4000) NOT NULL,
    ErrorAt DATETIME2(0) NOT NULL
);

SET @DatabaseName = NULLIF(LTRIM(RTRIM(@DatabaseName)), N'');
SET @LogBackupDirectory = NULLIF(LTRIM(RTRIM(@LogBackupDirectory)), N'');

IF @DatabaseName IS NULL
BEGIN
    THROW 50000, '@DatabaseName muss angegeben werden.', 1;
END;

IF @TakeLogBackupBeforeShrink NOT IN (0, 1)
BEGIN
    THROW 50001, '@TakeLogBackupBeforeShrink muss 0 oder 1 sein.', 1;
END;

IF @BackupWithCompression NOT IN (0, 1)
BEGIN
    THROW 50002, '@BackupWithCompression muss 0 oder 1 sein.', 1;
END;

IF @TakeLogBackupBeforeShrink = 1 AND @LogBackupDirectory IS NULL
BEGIN
    THROW 50003, '@LogBackupDirectory ist erforderlich, wenn @TakeLogBackupBeforeShrink = 1 ist.', 1;
END;

IF @MaxLogBackupAgeMinutes < 0
BEGIN
    THROW 50004, '@MaxLogBackupAgeMinutes darf nicht negativ sein.', 1;
END;

IF @ResultFillPct <= 0 OR @ResultFillPct > 100
BEGIN
    THROW 50005, '@ResultFillPct muss zwischen 1 und 100 liegen.', 1;
END;

IF @MinimumTargetSizeMB < 1
BEGIN
    THROW 50006, '@MinimumTargetSizeMB muss mindestens 1 sein.', 1;
END;

IF @MinimumFreePct < 0 OR @MinimumFreePct >= 100
BEGIN
    THROW 50007, '@MinimumFreePct muss zwischen 0 und kleiner 100 liegen.', 1;
END;

IF @MinShrinkGainMB < 0
BEGIN
    THROW 50008, '@MinShrinkGainMB darf nicht negativ sein.', 1;
END;

IF @AllowBulkLogged NOT IN (0, 1)
BEGIN
    THROW 50009, '@AllowBulkLogged muss 0 oder 1 sein.', 1;
END;

IF @AllowSystemDatabase NOT IN (0, 1)
BEGIN
    THROW 50010, '@AllowSystemDatabase muss 0 oder 1 sein.', 1;
END;

IF @ExecuteShrink NOT IN (0, 1)
BEGIN
    THROW 50011, '@ExecuteShrink muss 0 oder 1 sein.', 1;
END;

SELECT
    @DatabaseId = d.database_id,
    @StateDesc = d.state_desc,
    @RecoveryModelDesc = d.recovery_model_desc,
    @LogReuseWaitDesc = d.log_reuse_wait_desc,
    @IsReadOnly = d.is_read_only
FROM sys.databases AS d
WHERE d.name = @DatabaseName;

IF @DatabaseId IS NULL
BEGIN
    THROW 50012, '@DatabaseName verweist auf keine vorhandene Datenbank.', 1;
END;

IF @DatabaseId <= 4 AND @AllowSystemDatabase = 0
BEGIN
    THROW 50013, 'Systemdatenbanken werden standardmaessig nicht verarbeitet. Fuer bewusste Analysen @AllowSystemDatabase = 1 setzen.', 1;
END;

IF @StateDesc <> N'ONLINE'
BEGIN
    THROW 50014, 'Die Datenbank muss ONLINE sein.', 1;
END;

IF @IsReadOnly = 1
BEGIN
    THROW 50015, 'Die Datenbank ist READ_ONLY und kann nicht geshrinkt werden.', 1;
END;

IF @RecoveryModelDesc = N'SIMPLE'
BEGIN
    SET @Abort = 1;
    SET @AbortReason += N'Datenbank ist SIMPLE; dafuer ShrinkSimple.sql oder ShrinkSimple_multiple_Files.sql verwenden. ';
END;

IF @RecoveryModelDesc NOT IN (N'FULL', N'BULK_LOGGED', N'SIMPLE')
BEGIN
    SET @Abort = 1;
    SET @AbortReason += N'Nicht unterstuetztes Recovery Model. ';
END;

IF @RecoveryModelDesc = N'BULK_LOGGED' AND @AllowBulkLogged = 0
BEGIN
    SET @Abort = 1;
    SET @AbortReason += N'BULK_LOGGED ist nicht freigegeben; @AllowBulkLogged = 1 setzen oder Recovery-Modell pruefen. ';
END;

IF @LogBackupDirectory IS NOT NULL
BEGIN
    SET @NormalizedBackupDirectory = REPLACE(@LogBackupDirectory, N'/', N'\');

    IF RIGHT(@NormalizedBackupDirectory, 1) <> N'\'
    BEGIN
        SET @NormalizedBackupDirectory += N'\';
    END;
END;

SET @SnapshotSql = N'USE ' + QUOTENAME(@DatabaseName) + N';

;WITH LogFiles AS
(
    SELECT
        df.file_id,
        df.name AS LogicalFileName,
        df.physical_name AS PhysicalFileName,
        CAST(df.size / 128.0 AS DECIMAL(18, 2)) AS CurrentSizeMB,
        COUNT(*) OVER () AS LogFileCount
    FROM sys.database_files AS df
    WHERE df.type_desc = ''LOG''
),
VlfEnd AS
(
    SELECT
        li.file_id,
        CAST
        (
            MAX
            (
                CASE
                    WHEN li.vlf_active = 1
                        THEN (CAST(li.vlf_begin_offset AS DECIMAL(38, 2)) / 1048576.0) + li.vlf_size_mb
                    ELSE NULL
                END
            ) AS DECIMAL(18, 2)
        ) AS LastActiveVlfEndMB
    FROM sys.dm_db_log_info(DB_ID()) AS li
    GROUP BY li.file_id
),
LogUsage AS
(
    SELECT
        CAST(total_log_size_in_bytes / 1048576.0 AS DECIMAL(18, 2)) AS TotalLogMB,
        CAST(used_log_space_in_bytes / 1048576.0 AS DECIMAL(18, 2)) AS UsedLogMB,
        CAST(used_log_space_in_percent AS DECIMAL(9, 2)) AS UsedLogPct,
        CAST(log_space_in_bytes_since_last_backup / 1048576.0 AS DECIMAL(18, 2)) AS LogSinceLastBackupMB
    FROM sys.dm_db_log_space_usage
)
INSERT INTO #LogFileSnapshot
(
    SnapshotLabel,
    SnapshotAt,
    DatabaseId,
    DatabaseName,
    RecoveryModelDesc,
    LogReuseWaitDesc,
    IsReadOnly,
    LogFileCount,
    FileId,
    LogicalFileName,
    PhysicalFileName,
    CurrentSizeMB,
    TotalLogMB,
    UsedLogMB,
    UsedLogPct,
    FreeLogPct,
    LogSinceLastBackupMB,
    LastActiveVlfEndMB
)
SELECT
    @SnapshotLabel,
    SYSDATETIME(),
    DB_ID(),
    DB_NAME(),
    d.recovery_model_desc,
    d.log_reuse_wait_desc,
    d.is_read_only,
    lf.LogFileCount,
    lf.file_id,
    lf.LogicalFileName,
    lf.PhysicalFileName,
    lf.CurrentSizeMB,
    lu.TotalLogMB,
    lu.UsedLogMB,
    lu.UsedLogPct,
    CAST(100.0 - lu.UsedLogPct AS DECIMAL(9, 2)),
    lu.LogSinceLastBackupMB,
    vlf.LastActiveVlfEndMB
FROM sys.databases AS d
CROSS JOIN LogUsage AS lu
INNER JOIN LogFiles AS lf
    ON 1 = 1
LEFT JOIN VlfEnd AS vlf
    ON vlf.file_id = lf.file_id
WHERE d.database_id = DB_ID();';

-- 2. Backup-Historie und BEFORE-Snapshot lesen
SELECT @LastFullBackupAt = MAX(bs.backup_finish_date)
FROM msdb.dbo.backupset AS bs
WHERE bs.database_name = @DatabaseName
  AND bs.type = 'D'
  AND bs.backup_finish_date IS NOT NULL;

SELECT @LastLogBackupAt = MAX(bs.backup_finish_date)
FROM msdb.dbo.backupset AS bs
WHERE bs.database_name = @DatabaseName
  AND bs.type = 'L'
  AND bs.backup_finish_date IS NOT NULL;

SET @LastLogBackupAgeMinutes =
    CASE
        WHEN @LastLogBackupAt IS NULL THEN NULL
        ELSE DATEDIFF(MINUTE, @LastLogBackupAt, SYSDATETIME())
    END;

BEGIN TRY
    EXEC sys.sp_executesql
        @SnapshotSql,
        N'@SnapshotLabel VARCHAR(30)',
        @SnapshotLabel = 'before';
END TRY
BEGIN CATCH
    INSERT INTO #ScanErrors (SnapshotLabel, ErrorNumber, ErrorMessage, ErrorAt)
    VALUES ('before', ERROR_NUMBER(), ERROR_MESSAGE(), SYSDATETIME());

    SET @Abort = 1;
    SET @AbortReason += N'Before-Snapshot konnte nicht gelesen werden. ';
END CATCH;

SELECT TOP (1)
    @LogFileCount = s.LogFileCount,
    @LogFileId = s.FileId,
    @LogLogicalName = s.LogicalFileName,
    @LogPhysicalName = s.PhysicalFileName
FROM #LogFileSnapshot AS s
WHERE s.SnapshotLabel = 'before'
ORDER BY s.FileId;

IF @LogFileCount IS NULL
BEGIN
    SET @Abort = 1;
    SET @AbortReason += N'Keine Logdatei gefunden. ';
END;

IF @LogFileCount > 1
BEGIN
    SET @Abort = 1;
    SET @AbortReason += N'Mehrere Logdateien gefunden; dieses Skript shrinkt bewusst nur Datenbanken mit genau einer Logdatei. ';
END;

IF @RecoveryModelDesc IN (N'FULL', N'BULK_LOGGED')
BEGIN
    IF @LastFullBackupAt IS NULL
    BEGIN
        SET @Abort = 1;
        SET @AbortReason += N'Kein Full-Backup gefunden; zuerst Full-Backup erstellen. ';
    END;

    IF @TakeLogBackupBeforeShrink = 0
    BEGIN
        IF @LastLogBackupAt IS NULL
        BEGIN
            SET @Abort = 1;
            SET @AbortReason += N'Kein Logbackup gefunden; entweder Logbackup erstellen oder @TakeLogBackupBeforeShrink = 1 verwenden. ';
        END
        ELSE IF @LastLogBackupAgeMinutes > @MaxLogBackupAgeMinutes
        BEGIN
            SET @Abort = 1;
            SET @AbortReason += N'Letztes Logbackup ist aelter als @MaxLogBackupAgeMinutes. ';
        END;
    END;
END;

-- 3. Optionales regulaeres Logbackup vorbereiten oder ausfuehren
IF @TakeLogBackupBeforeShrink = 1
BEGIN
    SET @SafeDatabaseName = @DatabaseName;
    SET @SafeDatabaseName = REPLACE(@SafeDatabaseName, N'\', N'_');
    SET @SafeDatabaseName = REPLACE(@SafeDatabaseName, N'/', N'_');
    SET @SafeDatabaseName = REPLACE(@SafeDatabaseName, N':', N'_');
    SET @SafeDatabaseName = REPLACE(@SafeDatabaseName, N'*', N'_');
    SET @SafeDatabaseName = REPLACE(@SafeDatabaseName, N'?', N'_');
    SET @SafeDatabaseName = REPLACE(@SafeDatabaseName, N'"', N'_');
    SET @SafeDatabaseName = REPLACE(@SafeDatabaseName, N'<', N'_');
    SET @SafeDatabaseName = REPLACE(@SafeDatabaseName, N'>', N'_');
    SET @SafeDatabaseName = REPLACE(@SafeDatabaseName, N'|', N'_');
    SET @SafeDatabaseName = REPLACE(@SafeDatabaseName, N' ', N'_');

    SET @TimestampSuffix =
        CONVERT(CHAR(8), SYSDATETIME(), 112) + N'_' +
        REPLACE(CONVERT(CHAR(8), CAST(SYSDATETIME() AS TIME(0)), 108), N':', N'');

    SET @BackupFilePath =
        @NormalizedBackupDirectory +
        @SafeDatabaseName +
        N'_before_shrink_' +
        @TimestampSuffix +
        N'.trn';

    SET @BackupSql =
        N'BACKUP LOG ' + QUOTENAME(@DatabaseName) +
        N' TO DISK = N''' + REPLACE(@BackupFilePath, N'''', N'''''') +
        N''' WITH INIT, CHECKSUM, STATS = 5' +
        CASE WHEN @BackupWithCompression = 1 THEN N', COMPRESSION' ELSE N'' END +
        N';';

    INSERT INTO #ActionCommands (StepName, CommandStatus, CommandText, MessageText, LoggedAt)
    VALUES
    (
        'log-backup',
        CASE WHEN @ExecuteShrink = 1 AND @Abort = 0 THEN 'planned' ELSE 'preview' END,
        @BackupSql,
        N'Regulaeres Logbackup vor dem Shrink; diese .trn-Datei gehoert zur Restore-Kette.',
        SYSDATETIME()
    );

    IF @ExecuteShrink = 1 AND @Abort = 0
    BEGIN
        BEGIN TRY
            SET @LogBackupAttempted = 1;
            EXEC sys.sp_executesql @BackupSql;
            SET @LogBackupSucceeded = 1;

            UPDATE #ActionCommands
            SET CommandStatus = 'executed',
                MessageText = N'Logbackup erfolgreich ausgefuehrt; Datei gehoert zur Restore-Kette.'
            WHERE StepName = 'log-backup';
        END TRY
        BEGIN CATCH
            SET @Abort = 1;
            SET @AbortReason += N'Logbackup ist fehlgeschlagen. ';

            INSERT INTO #ScanErrors (SnapshotLabel, ErrorNumber, ErrorMessage, ErrorAt)
            VALUES ('log-backup', ERROR_NUMBER(), ERROR_MESSAGE(), SYSDATETIME());

            UPDATE #ActionCommands
            SET CommandStatus = 'failed',
                MessageText = ERROR_MESSAGE()
            WHERE StepName = 'log-backup';
        END CATCH;
    END;

    IF @ExecuteShrink = 1 AND @LogBackupSucceeded = 1
    BEGIN
        SELECT @LastLogBackupAt = MAX(bs.backup_finish_date)
        FROM msdb.dbo.backupset AS bs
        WHERE bs.database_name = @DatabaseName
          AND bs.type = 'L'
          AND bs.backup_finish_date IS NOT NULL;

        SET @LastLogBackupAgeMinutes =
            CASE
                WHEN @LastLogBackupAt IS NULL THEN NULL
                ELSE DATEDIFF(MINUTE, @LastLogBackupAt, SYSDATETIME())
            END;

        BEGIN TRY
            EXEC sys.sp_executesql
                @SnapshotSql,
                N'@SnapshotLabel VARCHAR(30)',
                @SnapshotLabel = 'after-log-backup';
        END TRY
        BEGIN CATCH
            INSERT INTO #ScanErrors (SnapshotLabel, ErrorNumber, ErrorMessage, ErrorAt)
            VALUES ('after-log-backup', ERROR_NUMBER(), ERROR_MESSAGE(), SYSDATETIME());

            SET @Abort = 1;
            SET @AbortReason += N'After-Logbackup-Snapshot konnte nicht gelesen werden. ';
        END CATCH;
    END;
END;

-- 4. Shrink-Zielgroesse aus aktuellem Snapshot berechnen
SELECT TOP (1)
    @SizingSnapshotLabel = s.SnapshotLabel,
    @SizingTotalLogMB = s.TotalLogMB,
    @SizingUsedLogMB = s.UsedLogMB,
    @SizingUsedLogPct = s.UsedLogPct,
    @SizingFreePct = s.FreeLogPct,
    @SizingLastActiveVlfEndMB = s.LastActiveVlfEndMB,
    @RecoveryModelDesc = s.RecoveryModelDesc,
    @LogReuseWaitDesc = s.LogReuseWaitDesc,
    @LogFileCount = s.LogFileCount,
    @LogFileId = s.FileId,
    @LogLogicalName = s.LogicalFileName,
    @LogPhysicalName = s.PhysicalFileName
FROM #LogFileSnapshot AS s
WHERE s.SnapshotLabel IN ('after-log-backup', 'before')
ORDER BY
    CASE s.SnapshotLabel WHEN 'after-log-backup' THEN 1 ELSE 2 END,
    s.FileId;

IF @SizingTotalLogMB IS NULL
BEGIN
    SET @Abort = 1;
    SET @AbortReason += N'Keine verwertbare Logmessung vorhanden. ';
END;

IF @LogReuseWaitDesc NOT IN (N'NOTHING', N'CHECKPOINT')
BEGIN
    SET @Abort = 1;
    SET @AbortReason += N'Log-Reuse-Wait blockiert den Shrink: ' + COALESCE(@LogReuseWaitDesc, N'<unknown>') + N'. ';
END;

IF @SizingTotalLogMB IS NOT NULL
BEGIN
    SET @TargetByFillMB = CEILING(@SizingUsedLogMB / (@ResultFillPct / 100.0));
    SET @TargetByVlfMB = CEILING(COALESCE(@SizingLastActiveVlfEndMB, @SizingUsedLogMB));

    SET @TargetSizeMB =
        (
            SELECT MAX(v.TargetCandidateMB)
            FROM
            (
                VALUES
                    (@MinimumTargetSizeMB),
                    (@TargetByFillMB),
                    (@TargetByVlfMB)
            ) AS v(TargetCandidateMB)
        );

    SET @PotentialGainMB =
        CASE
            WHEN @SizingTotalLogMB > @TargetSizeMB THEN @SizingTotalLogMB - @TargetSizeMB
            ELSE 0
        END;

    SET @MeetsSizeThreshold =
        CASE
            WHEN @SizingFreePct >= @MinimumFreePct
             AND @PotentialGainMB >= @MinShrinkGainMB
             AND @TargetSizeMB < @SizingTotalLogMB THEN 1
            ELSE 0
        END;
END;

IF @Abort = 0 AND @MeetsSizeThreshold = 0
BEGIN
    SET @ActionStatus = N'Uebersprungen: Freiraum oder potentielle Ersparnis liegt unter den Grenzwerten.';
END
ELSE IF @Abort = 1
BEGIN
    SET @ActionStatus = N'Abgebrochen: Guardrails nicht erfuellt.';
END
ELSE
BEGIN
    SET @ShrinkSql =
        N'USE ' + QUOTENAME(@DatabaseName) + N';
CHECKPOINT;
DBCC SHRINKFILE (N''' + REPLACE(@LogLogicalName, N'''', N'''''') + N''', ' + CONVERT(NVARCHAR(20), @TargetSizeMB) + N') WITH NO_INFOMSGS;';

    INSERT INTO #ActionCommands (StepName, CommandStatus, CommandText, MessageText, LoggedAt)
    VALUES
    (
        'shrink-log',
        CASE WHEN @ExecuteShrink = 1 THEN 'planned' ELSE 'preview' END,
        @ShrinkSql,
        N'Gezielter DBCC SHRINKFILE auf die berechnete Zielgroesse.',
        SYSDATETIME()
    );

    IF @ExecuteShrink = 1
    BEGIN
        BEGIN TRY
            SET @ShrinkAttempted = 1;
            EXEC sys.sp_executesql @ShrinkSql;
            SET @ActionStatus = N'Shrink ausgefuehrt.';

            UPDATE #ActionCommands
            SET CommandStatus = 'executed',
                MessageText = N'DBCC SHRINKFILE wurde ausgefuehrt.'
            WHERE StepName = 'shrink-log';
        END TRY
        BEGIN CATCH
            SET @ActionStatus = N'Shrink fehlgeschlagen.';
            SET @Abort = 1;
            SET @AbortReason += N'DBCC SHRINKFILE ist fehlgeschlagen. ';

            INSERT INTO #ScanErrors (SnapshotLabel, ErrorNumber, ErrorMessage, ErrorAt)
            VALUES ('shrink-log', ERROR_NUMBER(), ERROR_MESSAGE(), SYSDATETIME());

            UPDATE #ActionCommands
            SET CommandStatus = 'failed',
                MessageText = ERROR_MESSAGE()
            WHERE StepName = 'shrink-log';
        END CATCH;
    END
    ELSE
    BEGIN
        SET @ActionStatus = N'Preview: Shrink-Befehl wurde nur ausgegeben.';
    END;
END;

-- 5. Finalen Snapshot lesen
BEGIN TRY
    EXEC sys.sp_executesql
        @SnapshotSql,
        N'@SnapshotLabel VARCHAR(30)',
        @SnapshotLabel = 'after-run';
END TRY
BEGIN CATCH
    INSERT INTO #ScanErrors (SnapshotLabel, ErrorNumber, ErrorMessage, ErrorAt)
    VALUES ('after-run', ERROR_NUMBER(), ERROR_MESSAGE(), SYSDATETIME());
END CATCH;

-- 6. Ergebnis ausgeben
;WITH BeforeSnapshot AS
(
    SELECT TOP (1)
        s.TotalLogMB,
        s.UsedLogMB,
        s.UsedLogPct,
        s.FreeLogPct,
        s.LastActiveVlfEndMB
    FROM #LogFileSnapshot AS s
    WHERE s.SnapshotLabel = 'before'
    ORDER BY s.FileId
),
AfterRunSnapshot AS
(
    SELECT TOP (1)
        s.TotalLogMB,
        s.UsedLogMB,
        s.UsedLogPct,
        s.FreeLogPct,
        s.LastActiveVlfEndMB
    FROM #LogFileSnapshot AS s
    WHERE s.SnapshotLabel = 'after-run'
    ORDER BY s.FileId
)
SELECT
    DatabaseName = @DatabaseName,
    RecoveryModelDesc = @RecoveryModelDesc,
    LogReuseWaitDesc = @LogReuseWaitDesc,
    LogFileCount = @LogFileCount,
    LogLogicalName = @LogLogicalName,
    LogPhysicalName = @LogPhysicalName,
    ExecuteShrink = @ExecuteShrink,
    TakeLogBackupBeforeShrink = @TakeLogBackupBeforeShrink,
    LogBackupAttempted = @LogBackupAttempted,
    LogBackupSucceeded = @LogBackupSucceeded,
    LastFullBackupAt = @LastFullBackupAt,
    LastLogBackupAt = @LastLogBackupAt,
    LastLogBackupAgeMinutes = @LastLogBackupAgeMinutes,
    SizingSnapshotLabel = @SizingSnapshotLabel,
    ResultFillPct = @ResultFillPct,
    MinimumTargetSizeMB = @MinimumTargetSizeMB,
    MinimumFreePct = @MinimumFreePct,
    MinShrinkGainMB = @MinShrinkGainMB,
    TargetByFillMB = @TargetByFillMB,
    TargetByVlfMB = @TargetByVlfMB,
    TargetSizeMB = @TargetSizeMB,
    PotentialGainMB = @PotentialGainMB,
    PotentialGainGB = CAST(@PotentialGainMB / 1024.0 AS DECIMAL(18, 3)),
    MeetsSizeThreshold = @MeetsSizeThreshold,
    ShrinkAttempted = @ShrinkAttempted,
    AbortOccurred = @Abort,
    AbortReason = NULLIF(@AbortReason, N''),
    ActionStatus = @ActionStatus,
    BeforeTotalLogMB = b.TotalLogMB,
    BeforeUsedLogMB = b.UsedLogMB,
    BeforeUsedLogPct = b.UsedLogPct,
    BeforeFreeLogPct = b.FreeLogPct,
    BeforeLastActiveVlfEndMB = b.LastActiveVlfEndMB,
    AfterTotalLogMB = a.TotalLogMB,
    AfterUsedLogMB = a.UsedLogMB,
    AfterUsedLogPct = a.UsedLogPct,
    AfterFreeLogPct = a.FreeLogPct,
    AfterLastActiveVlfEndMB = a.LastActiveVlfEndMB,
    FileSavingsMB =
        CASE
            WHEN b.TotalLogMB IS NULL OR a.TotalLogMB IS NULL THEN NULL
            ELSE b.TotalLogMB - a.TotalLogMB
        END,
    FileSavingsGB =
        CASE
            WHEN b.TotalLogMB IS NULL OR a.TotalLogMB IS NULL THEN NULL
            ELSE CAST((b.TotalLogMB - a.TotalLogMB) / 1024.0 AS DECIMAL(18, 3))
        END
FROM BeforeSnapshot AS b
FULL OUTER JOIN AfterRunSnapshot AS a
    ON 1 = 1;

SELECT
    SnapshotLabel,
    SnapshotAt,
    DatabaseName,
    RecoveryModelDesc,
    LogReuseWaitDesc,
    IsReadOnly,
    LogFileCount,
    FileId,
    LogicalFileName,
    PhysicalFileName,
    CurrentSizeMB,
    TotalLogMB,
    UsedLogMB,
    UsedLogPct,
    FreeLogPct,
    LogSinceLastBackupMB,
    LastActiveVlfEndMB
FROM #LogFileSnapshot
ORDER BY
    CASE SnapshotLabel
        WHEN 'before' THEN 1
        WHEN 'after-log-backup' THEN 2
        WHEN 'after-run' THEN 3
        ELSE 9
    END,
    FileId;

SELECT
    StepName,
    CommandStatus,
    CommandText,
    MessageText,
    LoggedAt
FROM #ActionCommands
ORDER BY
    LoggedAt,
    StepName;

SELECT
    SnapshotLabel,
    ErrorNumber,
    ErrorMessage,
    ErrorAt
FROM #ScanErrors
ORDER BY
    ErrorAt,
    SnapshotLabel;
