/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "DatabaseShrinkAnalysis.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "20_Create_Database"
purpose: >
  Analysiert fuer genau eine Datenbank, welche Daten- und Logdateien
  realistische Shrink-Kandidaten sein koennen. Das Skript berechnet
  freien Platz, vorsichtige Zielgroessen und optionale DBCC-SHRINKFILE-
  Vorlagen, ohne einen Shrink auszufuehren.

parameters:
  - name: "@DatabaseName"
    sql_type: "SYSNAME"
    direction: "IN"
    required: true
    description: "Name der zu analysierenden Datenbank"
  - name: "@TargetVolumeRoot"
    sql_type: "NVARCHAR(260)"
    direction: "IN"
    required: false
    description: "Optionales Laufwerk oder Volume-Prefix; NULL analysiert alle Dateien der Datenbank"
  - name: "@MinimumRecoverableMB"
    sql_type: "DECIMAL(18,2)"
    direction: "IN"
    required: false
    description: "Mindestmenge in MB, die pro Datei als potentiell rueckgewinnbar gelten muss"
  - name: "@MinimumRecoverablePct"
    sql_type: "DECIMAL(5,2)"
    direction: "IN"
    required: false
    description: "Mindestanteil freien Platzes in Prozent, ab dem eine Datei als Kandidat gilt"
  - name: "@MinimumTargetSizeMB"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Absolute Untergrenze fuer generierte Shrink-Zielgroessen"
  - name: "@MinimumPostShrinkFreeMB"
    sql_type: "DECIMAL(18,2)"
    direction: "IN"
    required: false
    description: "Freier Puffer in MB, der nach einem Shrink mindestens verbleiben soll"
  - name: "@TargetFreePctAfterShrink"
    sql_type: "DECIMAL(5,2)"
    direction: "IN"
    required: false
    description: "Zusaetzlicher Zielpuffer in Prozent der genutzten Groesse"
  - name: "@MaxLogBackupAgeMinutes"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Maximales Alter eines Logbackups, damit FULL/BULK_LOGGED als shrink-vorbereitet gilt"
  - name: "@AllowSystemDatabase"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = Systemdatenbanken duerfen analysiert werden"
  - name: "@OnlyShowCandidates"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = in der Dateiansicht nur Kandidaten oder problematische Dateien anzeigen"
  - name: "@IncludeCommandTemplates"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zusaetzlich DBCC SHRINKFILE Vorlagen fuer Kandidatendateien ausgeben"

result_sets:
  - name: "DatabaseShrinkAnalysisSummary"
    description: "Zusammenfassung der Shrink-Potentiale und naechsten Schritte fuer die ausgewaehlte Datenbank"
  - name: "DatabaseFileShrinkAnalysis"
    description: "Dateischarfe Analyse von Daten- und Logdateien mit Zielgroesse, Potential und Risiko"
  - name: "ShrinkCommandTemplates"
    description: "Optionale DBCC SHRINKFILE Vorlagen pro Kandidatendatei"
  - name: "ScanErrors"
    description: "Scanphasen, die nicht vollstaendig gelesen werden konnten"

dependencies:
  - "sys.databases"
  - "sys.database_files"
  - "FILEPROPERTY"
  - "sys.dm_db_log_space_usage"
  - "sys.dm_db_log_info"
  - "msdb.dbo.backupset"
  - "tempdb temporary tables"
  - "dynamic SQL"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/20_Create_Database/SQLScripts/DatabaseShrinkAnalysis.md"
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
    description: "Erstversion der Shrink-Analyse fuer eine einzelne Datenbank"

notes:
  - "Das Skript fuehrt keinen Shrink aus und erzeugt nur Review- und Command-Vorlagen."
  - "Fuer FULL und BULK_LOGGED wird ein frisches Logbackup als Guardrail bewertet."
  - "Datenfile-Shrinks koennen Fragmentierung erzeugen und sollten nur gezielt erfolgen."
  - "Bei mehreren Logdateien ist die DB-weite Lognutzung nicht exakt dateischarf."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

-- 1. Parameter vorbereiten
DECLARE @DatabaseName SYSNAME = N'DeineDatenbank';
DECLARE @TargetVolumeRoot NVARCHAR(260) = NULL; -- NULL = alle Dateien der DB analysieren, z. B. N'L:\' fuer ein Volume
DECLARE @MinimumRecoverableMB DECIMAL(18, 2) = 1024.00;
DECLARE @MinimumRecoverablePct DECIMAL(5, 2) = 20.00;
DECLARE @MinimumTargetSizeMB INT = 256;
DECLARE @MinimumPostShrinkFreeMB DECIMAL(18, 2) = 512.00;
DECLARE @TargetFreePctAfterShrink DECIMAL(5, 2) = 10.00;
DECLARE @MaxLogBackupAgeMinutes INT = 120;
DECLARE @AllowSystemDatabase BIT = 0;
DECLARE @OnlyShowCandidates BIT = 0;
DECLARE @IncludeCommandTemplates BIT = 1;

DECLARE @NormalizedVolumeRoot NVARCHAR(260);
DECLARE @DatabaseId INT;
DECLARE @StateDesc NVARCHAR(60);
DECLARE @UserAccessDesc NVARCHAR(60);
DECLARE @RecoveryModelDesc NVARCHAR(60);
DECLARE @LogReuseWaitDesc NVARCHAR(120);
DECLARE @IsReadOnly BIT;
DECLARE @LastFullBackupAt DATETIME;
DECLARE @LastLogBackupAt DATETIME;
DECLARE @LastLogBackupAgeMinutes INT;
DECLARE @LogFileCount INT;
DECLARE @Sql NVARCHAR(MAX);

SET @DatabaseName = NULLIF(LTRIM(RTRIM(@DatabaseName)), N'');
SET @TargetVolumeRoot = NULLIF(LTRIM(RTRIM(@TargetVolumeRoot)), N'');

IF @DatabaseName IS NULL
BEGIN
    THROW 50000, '@DatabaseName muss angegeben werden.', 1;
END;

SELECT
    @DatabaseId = d.database_id,
    @StateDesc = d.state_desc,
    @UserAccessDesc = d.user_access_desc,
    @RecoveryModelDesc = d.recovery_model_desc,
    @LogReuseWaitDesc = d.log_reuse_wait_desc,
    @IsReadOnly = d.is_read_only
FROM sys.databases AS d
WHERE d.name = @DatabaseName;

IF @DatabaseId IS NULL
BEGIN
    THROW 50001, '@DatabaseName verweist auf keine vorhandene Datenbank.', 1;
END;

IF @DatabaseId <= 4 AND @AllowSystemDatabase = 0
BEGIN
    THROW 50002, 'Systemdatenbanken werden standardmaessig nicht analysiert. Fuer bewusste Analysen @AllowSystemDatabase = 1 setzen.', 1;
END;

IF @StateDesc <> N'ONLINE'
BEGIN
    THROW 50003, 'Die Datenbank muss ONLINE sein.', 1;
END;

IF @MinimumRecoverableMB < 0
BEGIN
    THROW 50004, '@MinimumRecoverableMB darf nicht negativ sein.', 1;
END;

IF @MinimumRecoverablePct < 0 OR @MinimumRecoverablePct > 100
BEGIN
    THROW 50005, '@MinimumRecoverablePct muss zwischen 0 und 100 liegen.', 1;
END;

IF @MinimumTargetSizeMB < 1
BEGIN
    THROW 50006, '@MinimumTargetSizeMB muss mindestens 1 sein.', 1;
END;

IF @MinimumPostShrinkFreeMB < 0
BEGIN
    THROW 50007, '@MinimumPostShrinkFreeMB darf nicht negativ sein.', 1;
END;

IF @TargetFreePctAfterShrink < 0 OR @TargetFreePctAfterShrink > 100
BEGIN
    THROW 50008, '@TargetFreePctAfterShrink muss zwischen 0 und 100 liegen.', 1;
END;

IF @MaxLogBackupAgeMinutes < 0
BEGIN
    THROW 50009, '@MaxLogBackupAgeMinutes darf nicht negativ sein.', 1;
END;

IF @AllowSystemDatabase NOT IN (0, 1)
BEGIN
    THROW 50010, '@AllowSystemDatabase muss 0 oder 1 sein.', 1;
END;

IF @OnlyShowCandidates NOT IN (0, 1)
BEGIN
    THROW 50011, '@OnlyShowCandidates muss 0 oder 1 sein.', 1;
END;

IF @IncludeCommandTemplates NOT IN (0, 1)
BEGIN
    THROW 50012, '@IncludeCommandTemplates muss 0 oder 1 sein.', 1;
END;

IF @TargetVolumeRoot IS NOT NULL
BEGIN
    SET @NormalizedVolumeRoot = REPLACE(@TargetVolumeRoot, N'/', N'\');

    IF LEN(@NormalizedVolumeRoot) = 2
       AND SUBSTRING(@NormalizedVolumeRoot, 2, 1) = N':'
    BEGIN
        SET @NormalizedVolumeRoot = @NormalizedVolumeRoot + N'\';
    END;

    IF RIGHT(@NormalizedVolumeRoot, 1) <> N'\'
    BEGIN
        SET @NormalizedVolumeRoot = @NormalizedVolumeRoot + N'\';
    END;
END;

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

DROP TABLE IF EXISTS #DatabaseFiles;
DROP TABLE IF EXISTS #LogSpace;
DROP TABLE IF EXISTS #LogVlfEnd;
DROP TABLE IF EXISTS #FileAnalysis;
DROP TABLE IF EXISTS #ScanErrors;

CREATE TABLE #DatabaseFiles
(
    DatabaseId INT NOT NULL,
    DatabaseName SYSNAME NOT NULL,
    FileId INT NOT NULL,
    FileTypeDesc NVARCHAR(60) NOT NULL,
    LogicalFileName SYSNAME NOT NULL,
    PhysicalFileName NVARCHAR(260) NOT NULL,
    AllocatedMB DECIMAL(18, 2) NOT NULL,
    UsedMB DECIMAL(18, 2) NULL,
    FreeMB DECIMAL(18, 2) NULL,
    Growth INT NOT NULL,
    IsPercentGrowth BIT NOT NULL,
    MaxSize INT NOT NULL
);

CREATE TABLE #LogSpace
(
    DatabaseId INT NOT NULL,
    DatabaseName SYSNAME NOT NULL,
    TotalLogMB DECIMAL(18, 2) NOT NULL,
    UsedLogMB DECIMAL(18, 2) NOT NULL,
    UsedLogPct DECIMAL(9, 2) NOT NULL,
    LogSinceLastBackupMB DECIMAL(18, 2) NULL
);

CREATE TABLE #LogVlfEnd
(
    DatabaseId INT NOT NULL,
    DatabaseName SYSNAME NOT NULL,
    FileId INT NOT NULL,
    LastActiveVlfEndMB DECIMAL(18, 2) NULL
);

CREATE TABLE #ScanErrors
(
    DatabaseName SYSNAME NULL,
    ScanPhase VARCHAR(40) NOT NULL,
    ErrorNumber INT NOT NULL,
    ErrorMessage NVARCHAR(4000) NOT NULL
);

CREATE TABLE #FileAnalysis
(
    FileKind VARCHAR(10) NOT NULL,
    DatabaseName SYSNAME NOT NULL,
    FileId INT NOT NULL,
    LogicalFileName SYSNAME NOT NULL,
    PhysicalFileName NVARCHAR(260) NOT NULL,
    AllocatedMB DECIMAL(18, 2) NOT NULL,
    UsedOrAnchorMB DECIMAL(18, 2) NULL,
    FreeMB DECIMAL(18, 2) NULL,
    FreePct DECIMAL(9, 2) NULL,
    TargetSizeMB DECIMAL(18, 2) NOT NULL,
    RecoverableMB DECIMAL(18, 2) NOT NULL,
    MeetsThreshold BIT NOT NULL,
    IsExecutableCandidate BIT NOT NULL,
    ActionClass VARCHAR(40) NOT NULL,
    RiskLevel VARCHAR(20) NOT NULL,
    Prerequisite NVARCHAR(400) NOT NULL,
    CommandTemplate NVARCHAR(MAX) NOT NULL,
    CommandNote NVARCHAR(400) NOT NULL
);

-- 2. Datenbanklokale Dateiinformationen einsammeln
SET @Sql = N'USE ' + QUOTENAME(@DatabaseName) + N';

BEGIN TRY
    INSERT INTO #DatabaseFiles
    (
        DatabaseId,
        DatabaseName,
        FileId,
        FileTypeDesc,
        LogicalFileName,
        PhysicalFileName,
        AllocatedMB,
        UsedMB,
        FreeMB,
        Growth,
        IsPercentGrowth,
        MaxSize
    )
    SELECT
        DB_ID(),
        DB_NAME(),
        df.file_id,
        df.type_desc,
        df.name,
        df.physical_name,
        CAST(df.size / 128.0 AS DECIMAL(18, 2)) AS AllocatedMB,
        CASE
            WHEN df.type_desc = ''ROWS''
                THEN CAST(COALESCE(FILEPROPERTY(df.name, ''SpaceUsed''), 0) / 128.0 AS DECIMAL(18, 2))
            ELSE NULL
        END AS UsedMB,
        CASE
            WHEN df.type_desc = ''ROWS''
                THEN CAST((df.size - COALESCE(FILEPROPERTY(df.name, ''SpaceUsed''), 0)) / 128.0 AS DECIMAL(18, 2))
            ELSE NULL
        END AS FreeMB,
        df.growth,
        df.is_percent_growth,
        df.max_size
    FROM sys.database_files AS df
    WHERE df.type_desc IN (''ROWS'', ''LOG'');
END TRY
BEGIN CATCH
    INSERT INTO #ScanErrors
    (
        DatabaseName,
        ScanPhase,
        ErrorNumber,
        ErrorMessage
    )
    SELECT DB_NAME(), ''file-scan'', ERROR_NUMBER(), ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    INSERT INTO #LogSpace
    (
        DatabaseId,
        DatabaseName,
        TotalLogMB,
        UsedLogMB,
        UsedLogPct,
        LogSinceLastBackupMB
    )
    SELECT
        DB_ID(),
        DB_NAME(),
        CAST(total_log_size_in_bytes / 1048576.0 AS DECIMAL(18, 2)),
        CAST(used_log_space_in_bytes / 1048576.0 AS DECIMAL(18, 2)),
        CAST(used_log_space_in_percent AS DECIMAL(9, 2)),
        CAST(log_space_in_bytes_since_last_backup / 1048576.0 AS DECIMAL(18, 2))
    FROM sys.dm_db_log_space_usage;
END TRY
BEGIN CATCH
    INSERT INTO #ScanErrors
    (
        DatabaseName,
        ScanPhase,
        ErrorNumber,
        ErrorMessage
    )
    SELECT DB_NAME(), ''log-space-scan'', ERROR_NUMBER(), ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    INSERT INTO #LogVlfEnd
    (
        DatabaseId,
        DatabaseName,
        FileId,
        LastActiveVlfEndMB
    )
    SELECT
        DB_ID(),
        DB_NAME(),
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
    GROUP BY li.file_id;
END TRY
BEGIN CATCH
    INSERT INTO #ScanErrors
    (
        DatabaseName,
        ScanPhase,
        ErrorNumber,
        ErrorMessage
    )
    SELECT DB_NAME(), ''log-vlf-scan'', ERROR_NUMBER(), ERROR_MESSAGE();
END CATCH;';

EXEC sys.sp_executesql @Sql;

SELECT @LogFileCount = COUNT(*)
FROM #DatabaseFiles AS df
WHERE df.FileTypeDesc = 'LOG';

-- 3. Datenfile-Kandidaten ableiten
INSERT INTO #FileAnalysis
(
    FileKind,
    DatabaseName,
    FileId,
    LogicalFileName,
    PhysicalFileName,
    AllocatedMB,
    UsedOrAnchorMB,
    FreeMB,
    FreePct,
    TargetSizeMB,
    RecoverableMB,
    MeetsThreshold,
    IsExecutableCandidate,
    ActionClass,
    RiskLevel,
    Prerequisite,
    CommandTemplate,
    CommandNote
)
SELECT
    'DATA' AS FileKind,
    df.DatabaseName,
    df.FileId,
    df.LogicalFileName,
    df.PhysicalFileName,
    df.AllocatedMB,
    df.UsedMB AS UsedOrAnchorMB,
    df.FreeMB,
    fp.FreePct,
    target.TargetSizeMB,
    potential.RecoverableMB,
    meets.MeetsThreshold,
    CAST(0 AS BIT) AS IsExecutableCandidate,
    CASE
        WHEN meets.MeetsThreshold = 1 THEN 'datafile-last-resort'
        ELSE 'no-candidate'
    END AS ActionClass,
    CASE
        WHEN meets.MeetsThreshold = 1 THEN 'high'
        ELSE 'low'
    END AS RiskLevel,
    N'Datenfile-Shrink nur gezielt nach Datenloeschung oder akuter Speicherplatz-Notlage ausfuehren.' AS Prerequisite,
    N'USE ' + QUOTENAME(df.DatabaseName) +
        N'; DBCC SHRINKFILE (N''' + REPLACE(df.LogicalFileName, N'''', N'''''') +
        N''', ' + CONVERT(NVARCHAR(20), CONVERT(BIGINT, target.TargetSizeMB)) + N');' AS CommandTemplate,
    N'Danach Fragmentierung, Indexwartung, Autogrowth und passende Dateigroesse pruefen.' AS CommandNote
FROM #DatabaseFiles AS df
CROSS APPLY
(
    SELECT CAST((df.FreeMB * 100.0) / NULLIF(df.AllocatedMB, 0) AS DECIMAL(9, 2)) AS FreePct
) AS fp
CROSS APPLY
(
    SELECT
        CAST
        (
            CASE
                WHEN df.UsedMB * @TargetFreePctAfterShrink / 100.0 > @MinimumPostShrinkFreeMB
                    THEN df.UsedMB * @TargetFreePctAfterShrink / 100.0
                ELSE @MinimumPostShrinkFreeMB
            END AS DECIMAL(18, 2)
        ) AS BufferMB
) AS buffer
CROSS APPLY
(
    SELECT
        CAST
        (
            CEILING
            (
                CASE
                    WHEN df.UsedMB + buffer.BufferMB < @MinimumTargetSizeMB
                        THEN @MinimumTargetSizeMB
                    ELSE df.UsedMB + buffer.BufferMB
                END
            ) AS DECIMAL(18, 2)
        ) AS TargetSizeMB
) AS target
CROSS APPLY
(
    SELECT
        CAST
        (
            CASE
                WHEN df.AllocatedMB > target.TargetSizeMB THEN df.AllocatedMB - target.TargetSizeMB
                ELSE 0
            END AS DECIMAL(18, 2)
        ) AS RecoverableMB
) AS potential
CROSS APPLY
(
    SELECT
        CAST
        (
            CASE
                WHEN potential.RecoverableMB >= @MinimumRecoverableMB
                 AND fp.FreePct >= @MinimumRecoverablePct THEN 1
                ELSE 0
            END AS BIT
        ) AS MeetsThreshold
) AS meets
WHERE df.FileTypeDesc = 'ROWS'
  AND
  (
      @NormalizedVolumeRoot IS NULL
      OR LEFT(UPPER(COALESCE(df.PhysicalFileName, N'')), LEN(@NormalizedVolumeRoot)) = UPPER(@NormalizedVolumeRoot)
  );

-- 4. Logfile-Kandidaten ableiten
INSERT INTO #FileAnalysis
(
    FileKind,
    DatabaseName,
    FileId,
    LogicalFileName,
    PhysicalFileName,
    AllocatedMB,
    UsedOrAnchorMB,
    FreeMB,
    FreePct,
    TargetSizeMB,
    RecoverableMB,
    MeetsThreshold,
    IsExecutableCandidate,
    ActionClass,
    RiskLevel,
    Prerequisite,
    CommandTemplate,
    CommandNote
)
SELECT
    'LOG' AS FileKind,
    lf.DatabaseName,
    lf.FileId,
    lf.LogicalFileName,
    lf.PhysicalFileName,
    lf.AllocatedMB,
    anchor.UsedOrAnchorMB,
    CAST(lf.AllocatedMB - anchor.UsedOrAnchorMB AS DECIMAL(18, 2)) AS FreeMB,
    fp.LogFreePct AS FreePct,
    target.TargetSizeMB,
    potential.RecoverableMB,
    meets.MeetsThreshold,
    executable.IsExecutableCandidate,
    CASE
        WHEN anchor.HasSizingConfidence = 0 THEN 'vlf-info-missing'
        WHEN meets.MeetsThreshold = 0 THEN 'no-candidate'
        WHEN executable.IsExecutableCandidate = 1 THEN 'log-shrink-ready'
        WHEN @IsReadOnly = 1 THEN 'read-only-database'
        WHEN @RecoveryModelDesc IN (N'FULL', N'BULK_LOGGED')
         AND (@LastLogBackupAt IS NULL OR @LastLogBackupAgeMinutes > @MaxLogBackupAgeMinutes) THEN 'take-log-backup-first'
        WHEN @LogReuseWaitDesc NOT IN (N'NOTHING', N'CHECKPOINT') THEN 'fix-log-reuse-first'
        ELSE 'manual-review'
    END AS ActionClass,
    CASE
        WHEN meets.MeetsThreshold = 0 THEN 'low'
        WHEN executable.IsExecutableCandidate = 1 THEN 'medium'
        ELSE 'blocked'
    END AS RiskLevel,
    CASE
        WHEN anchor.HasSizingConfidence = 0 THEN N'VLF-Information oder Log-Space-Messung fehlt; erst Scanfehler pruefen und erneut messen.'
        WHEN @IsReadOnly = 1 THEN N'Datenbank ist READ_ONLY; Shrink nur nach bewusster Statusaenderung pruefen.'
        WHEN @RecoveryModelDesc IN (N'FULL', N'BULK_LOGGED')
         AND (@LastLogBackupAt IS NULL OR @LastLogBackupAgeMinutes > @MaxLogBackupAgeMinutes)
            THEN N'Zuerst ein regulaeres Logbackup ausfuehren und die Backup-Kette erhalten.'
        WHEN @LogReuseWaitDesc = N'LOG_BACKUP' THEN N'Logbackup ausfuehren, danach Lognutzung erneut messen.'
        WHEN @LogReuseWaitDesc NOT IN (N'NOTHING', N'CHECKPOINT')
            THEN N'Logreuse-Wait beheben: ' + @LogReuseWaitDesc + N'. Danach erneut messen.'
        WHEN @RecoveryModelDesc = N'SIMPLE' THEN N'CHECKPOINT ausfuehren, Ursache des Logwachstums klaeren und nur einmalig shrinken.'
        ELSE N'Vor dem Shrink Recovery-Modell, Logbackup-Kette und Ursache des Logwachstums dokumentieren.'
    END AS Prerequisite,
    CASE
        WHEN @RecoveryModelDesc IN (N'FULL', N'BULK_LOGGED') THEN
            N'-- Vorher regulaeres Logbackup ausfuehren/pruefen. USE ' + QUOTENAME(lf.DatabaseName) +
            N'; DBCC SHRINKFILE (N''' + REPLACE(lf.LogicalFileName, N'''', N'''''') +
            N''', ' + CONVERT(NVARCHAR(20), CONVERT(BIGINT, target.TargetSizeMB)) + N');'
        ELSE
            N'USE ' + QUOTENAME(lf.DatabaseName) +
            N'; CHECKPOINT; DBCC SHRINKFILE (N''' + REPLACE(lf.LogicalFileName, N'''', N'''''') +
            N''', ' + CONVERT(NVARCHAR(20), CONVERT(BIGINT, target.TargetSizeMB)) + N');'
    END AS CommandTemplate,
    CASE
        WHEN @LogFileCount > 1 THEN N'Mehrere Logdateien: DB-weite Lognutzung ist nicht dateischarf; VLF-Ende und Ergebnis besonders pruefen.'
        WHEN @RecoveryModelDesc IN (N'FULL', N'BULK_LOGGED') THEN N'Nicht auf SIMPLE wechseln, wenn Point-in-Time-Recovery benoetigt wird; erst Logbackup, dann gezielter Shrink.'
        ELSE N'Log-Shrink nur nach behobener Ursache; danach Autogrowth und Zielgroesse passend setzen.'
    END AS CommandNote
FROM #DatabaseFiles AS lf
LEFT JOIN #LogSpace AS ls
    ON ls.DatabaseId = lf.DatabaseId
LEFT JOIN #LogVlfEnd AS vlf
    ON vlf.DatabaseId = lf.DatabaseId
   AND vlf.FileId = lf.FileId
CROSS APPLY
(
    SELECT CAST(100.0 - COALESCE(ls.UsedLogPct, 100.0) AS DECIMAL(9, 2)) AS LogFreePct
) AS fp
CROSS APPLY
(
    SELECT
        CAST
        (
            CASE
                WHEN @LogFileCount = 1 AND ls.UsedLogMB IS NOT NULL THEN 1
                WHEN @LogFileCount > 1 AND vlf.LastActiveVlfEndMB IS NOT NULL THEN 1
                ELSE 0
            END AS BIT
        ) AS HasSizingConfidence,
        CAST
        (
            CASE
                WHEN @LogFileCount = 1 THEN COALESCE(ls.UsedLogMB, vlf.LastActiveVlfEndMB, lf.AllocatedMB)
                ELSE COALESCE(vlf.LastActiveVlfEndMB, lf.AllocatedMB)
            END AS DECIMAL(18, 2)
        ) AS UsedOrAnchorMB
) AS anchor
CROSS APPLY
(
    SELECT
        CAST
        (
            CASE
                WHEN @LogFileCount = 1
                 AND COALESCE(ls.UsedLogMB, 0.00) * @TargetFreePctAfterShrink / 100.0 > @MinimumPostShrinkFreeMB
                    THEN COALESCE(ls.UsedLogMB, 0.00) * @TargetFreePctAfterShrink / 100.0
                ELSE @MinimumPostShrinkFreeMB
            END AS DECIMAL(18, 2)
        ) AS BufferMB
) AS buffer
CROSS APPLY
(
    SELECT
        CAST
        (
            CASE
                WHEN anchor.HasSizingConfidence = 0 THEN lf.AllocatedMB
                WHEN @LogFileCount = 1 THEN
                    CASE
                        WHEN COALESCE(vlf.LastActiveVlfEndMB, 0.00) > COALESCE(ls.UsedLogMB, 0.00) + buffer.BufferMB
                            THEN COALESCE(vlf.LastActiveVlfEndMB, 0.00)
                        ELSE COALESCE(ls.UsedLogMB, 0.00) + buffer.BufferMB
                    END
                ELSE anchor.UsedOrAnchorMB + buffer.BufferMB
            END AS DECIMAL(18, 2)
        ) AS RawTargetSizeMB
) AS rawtarget
CROSS APPLY
(
    SELECT
        CAST
        (
            CEILING
            (
                CASE
                    WHEN rawtarget.RawTargetSizeMB < @MinimumTargetSizeMB THEN @MinimumTargetSizeMB
                    ELSE rawtarget.RawTargetSizeMB
                END
            ) AS DECIMAL(18, 2)
        ) AS TargetSizeMB
) AS target
CROSS APPLY
(
    SELECT
        CAST
        (
            CASE
                WHEN lf.AllocatedMB > target.TargetSizeMB THEN lf.AllocatedMB - target.TargetSizeMB
                ELSE 0
            END AS DECIMAL(18, 2)
        ) AS RecoverableMB
) AS potential
CROSS APPLY
(
    SELECT
        CAST
        (
            CASE
                WHEN anchor.HasSizingConfidence = 1
                 AND potential.RecoverableMB >= @MinimumRecoverableMB
                 AND fp.LogFreePct >= @MinimumRecoverablePct THEN 1
                ELSE 0
            END AS BIT
        ) AS MeetsThreshold
) AS meets
CROSS APPLY
(
    SELECT
        CAST
        (
            CASE
                WHEN meets.MeetsThreshold = 1
                 AND @IsReadOnly = 0
                 AND @LogReuseWaitDesc IN (N'NOTHING', N'CHECKPOINT')
                 AND
                 (
                     @RecoveryModelDesc = N'SIMPLE'
                     OR
                     (
                         @RecoveryModelDesc IN (N'FULL', N'BULK_LOGGED')
                         AND @LastLogBackupAt IS NOT NULL
                         AND @LastLogBackupAgeMinutes <= @MaxLogBackupAgeMinutes
                     )
                 ) THEN 1
                ELSE 0
            END AS BIT
        ) AS IsExecutableCandidate
) AS executable
WHERE lf.FileTypeDesc = 'LOG'
  AND
  (
      @NormalizedVolumeRoot IS NULL
      OR LEFT(UPPER(COALESCE(lf.PhysicalFileName, N'')), LEN(@NormalizedVolumeRoot)) = UPPER(@NormalizedVolumeRoot)
  );

-- 5. Zusammenfassung ausgeben
;WITH FileScope AS
(
    SELECT
        df.FileTypeDesc,
        df.AllocatedMB,
        df.UsedMB,
        df.FreeMB
    FROM #DatabaseFiles AS df
    WHERE @NormalizedVolumeRoot IS NULL
       OR LEFT(UPPER(COALESCE(df.PhysicalFileName, N'')), LEN(@NormalizedVolumeRoot)) = UPPER(@NormalizedVolumeRoot)
),
FileRollup AS
(
    SELECT
        SUM(CASE WHEN fs.FileTypeDesc = 'ROWS' THEN fs.AllocatedMB ELSE 0 END) AS DataAllocatedMB,
        SUM(CASE WHEN fs.FileTypeDesc = 'ROWS' THEN COALESCE(fs.UsedMB, 0) ELSE 0 END) AS DataUsedMB,
        SUM(CASE WHEN fs.FileTypeDesc = 'ROWS' THEN COALESCE(fs.FreeMB, 0) ELSE 0 END) AS DataFreeMB,
        SUM(CASE WHEN fs.FileTypeDesc = 'LOG' THEN fs.AllocatedMB ELSE 0 END) AS LogAllocatedMB,
        COUNT(CASE WHEN fs.FileTypeDesc = 'ROWS' THEN 1 END) AS DataFileCount,
        COUNT(CASE WHEN fs.FileTypeDesc = 'LOG' THEN 1 END) AS ScopedLogFileCount
    FROM FileScope AS fs
),
PotentialRollup AS
(
    SELECT
        SUM(CASE WHEN fa.FileKind = 'DATA' AND fa.MeetsThreshold = 1 THEN fa.RecoverableMB ELSE 0 END) AS DataPotentialMB,
        SUM(CASE WHEN fa.FileKind = 'LOG' AND fa.MeetsThreshold = 1 THEN fa.RecoverableMB ELSE 0 END) AS LogPotentialMB,
        SUM(CASE WHEN fa.FileKind = 'LOG' AND fa.IsExecutableCandidate = 1 THEN fa.RecoverableMB ELSE 0 END) AS ExecutableLogPotentialMB,
        SUM(CASE WHEN fa.FileKind = 'LOG' AND fa.MeetsThreshold = 1 AND fa.IsExecutableCandidate = 0 THEN fa.RecoverableMB ELSE 0 END) AS BlockedLogPotentialMB,
        SUM(CASE WHEN fa.MeetsThreshold = 1 THEN fa.RecoverableMB ELSE 0 END) AS TotalPotentialMB
    FROM #FileAnalysis AS fa
)
SELECT
    @DatabaseName AS DatabaseName,
    COALESCE(@NormalizedVolumeRoot, N'<all database files>') AS TargetVolumeRoot,
    @StateDesc AS StateDesc,
    @UserAccessDesc AS UserAccessDesc,
    @RecoveryModelDesc AS RecoveryModelDesc,
    @LogReuseWaitDesc AS LogReuseWaitDesc,
    @IsReadOnly AS IsReadOnly,
    @LastFullBackupAt AS LastFullBackupAt,
    @LastLogBackupAt AS LastLogBackupAt,
    @LastLogBackupAgeMinutes AS LastLogBackupAgeMinutes,
    fr.DataFileCount,
    fr.ScopedLogFileCount AS LogFileCountInScope,
    fr.DataAllocatedMB,
    fr.DataUsedMB,
    fr.DataFreeMB,
    CAST((fr.DataFreeMB * 100.0) / NULLIF(fr.DataAllocatedMB, 0) AS DECIMAL(9, 2)) AS DataFreePct,
    fr.LogAllocatedMB,
    ls.UsedLogMB,
    CAST(fr.LogAllocatedMB - COALESCE(ls.UsedLogMB, 0.00) AS DECIMAL(18, 2)) AS LogFreeMB,
    CAST(100.0 - COALESCE(ls.UsedLogPct, 100.0) AS DECIMAL(9, 2)) AS LogFreePct,
    COALESCE(pr.ExecutableLogPotentialMB, 0.00) AS ExecutableLogPotentialMB,
    COALESCE(pr.BlockedLogPotentialMB, 0.00) AS BlockedLogPotentialMB,
    COALESCE(pr.LogPotentialMB, 0.00) AS LogPotentialMB,
    COALESCE(pr.DataPotentialMB, 0.00) AS DataPotentialMB,
    COALESCE(pr.TotalPotentialMB, 0.00) AS TotalPotentialMB,
    CAST(COALESCE(pr.TotalPotentialMB, 0.00) / 1024.0 AS DECIMAL(18, 3)) AS TotalPotentialGB,
    (SELECT COUNT(*) FROM #ScanErrors) AS ScanErrorCount,
    CASE
        WHEN COALESCE(pr.ExecutableLogPotentialMB, 0.00) > 0 THEN 'log-shrink-ready'
        WHEN COALESCE(pr.BlockedLogPotentialMB, 0.00) > 0 THEN 'fix-log-prerequisites-first'
        WHEN COALESCE(pr.DataPotentialMB, 0.00) > 0 THEN 'datafile-last-resort'
        WHEN (SELECT COUNT(*) FROM #ScanErrors) > 0 THEN 'scan-error-review'
        ELSE 'no-candidate'
    END AS ActionClass,
    CASE
        WHEN COALESCE(pr.ExecutableLogPotentialMB, 0.00) > 0 THEN 'Logdatei ist der naheliegende Kandidat; Shrink nur nach Ursachenanalyse und mit Zielgroesse aus der Detailansicht pruefen.'
        WHEN COALESCE(pr.BlockedLogPotentialMB, 0.00) > 0 THEN 'Logdatei wirkt gross, aber Backup-, Reuse-Wait- oder Recovery-Voraussetzungen zuerst klaeren.'
        WHEN COALESCE(pr.DataPotentialMB, 0.00) > 0 THEN 'Datenfile-Shrink ist nur ein letzter Notfallpfad; Fragmentierung und Autogrowth danach einplanen.'
        WHEN (SELECT COUNT(*) FROM #ScanErrors) > 0 THEN 'Mindestens ein Scan-Schritt ist fehlgeschlagen; ScanErrors pruefen.'
        ELSE 'Nach den gesetzten Schwellenwerten gibt es keinen sinnvollen Shrink-Kandidaten.'
    END AS ReviewFocus
FROM FileRollup AS fr
CROSS JOIN PotentialRollup AS pr
LEFT JOIN #LogSpace AS ls
    ON ls.DatabaseId = @DatabaseId;

-- 6. Dateischarfe Analyse ausgeben
SELECT
    COALESCE(@NormalizedVolumeRoot, N'<all database files>') AS TargetVolumeRoot,
    fa.FileKind,
    fa.DatabaseName,
    fa.FileId,
    fa.LogicalFileName,
    fa.PhysicalFileName,
    fa.AllocatedMB,
    fa.UsedOrAnchorMB,
    fa.FreeMB,
    fa.FreePct,
    fa.TargetSizeMB,
    fa.RecoverableMB,
    CAST(fa.RecoverableMB / 1024.0 AS DECIMAL(18, 3)) AS RecoverableGB,
    fa.MeetsThreshold,
    fa.IsExecutableCandidate,
    fa.ActionClass,
    fa.RiskLevel,
    fa.Prerequisite,
    fa.CommandNote
FROM #FileAnalysis AS fa
WHERE @OnlyShowCandidates = 0
   OR fa.MeetsThreshold = 1
   OR fa.ActionClass IN ('vlf-info-missing', 'fix-log-reuse-first', 'take-log-backup-first')
ORDER BY
    CASE WHEN fa.FileKind = 'LOG' THEN 1 ELSE 2 END,
    fa.IsExecutableCandidate DESC,
    fa.RecoverableMB DESC,
    fa.FileId;

-- 7. Optionale Command-Vorlagen ausgeben
SELECT
    fa.FileKind,
    fa.DatabaseName,
    fa.FileId,
    fa.LogicalFileName,
    fa.PhysicalFileName,
    fa.TargetSizeMB,
    fa.RecoverableMB,
    CAST(fa.RecoverableMB / 1024.0 AS DECIMAL(18, 3)) AS RecoverableGB,
    fa.ActionClass,
    fa.RiskLevel,
    fa.Prerequisite,
    fa.CommandTemplate,
    fa.CommandNote
FROM #FileAnalysis AS fa
WHERE @IncludeCommandTemplates = 1
  AND fa.MeetsThreshold = 1
ORDER BY
    CASE WHEN fa.FileKind = 'LOG' THEN 1 ELSE 2 END,
    fa.IsExecutableCandidate DESC,
    fa.RecoverableMB DESC,
    fa.FileId;

-- 8. Scanfehler transparent machen
SELECT
    se.DatabaseName,
    se.ScanPhase,
    se.ErrorNumber,
    se.ErrorMessage
FROM #ScanErrors AS se
ORDER BY
    se.ScanPhase,
    se.ErrorNumber;
