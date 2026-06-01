/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "DatabaseShrinkCandidateReview.sql"
script_version: "1.1"
script_type: "diagnostic-query"
chapter: "20_Create_Database"
purpose: >
  Bewertet serverweit, welche Datenbankdateien auf einem betroffenen
  Laufwerk oder Volume realistische Shrink-Kandidaten sein koennen.
  Das Skript trennt Logdateien von Datenfiles, berechnet freies
  Potential und erzeugt vorsichtige DBCC-SHRINKFILE-Vorlagen ohne
  sie auszufuehren.

parameters:
  - name: "@TargetVolumeRoot"
    sql_type: "NVARCHAR(260)"
    direction: "IN"
    required: true
    description: "Betroffenes Laufwerk oder Volume-Prefix, z. B. D:\\ oder L:\\MSSQLData\\"
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
  - name: "@IncludeSystemDatabases"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = master, model, msdb und tempdb in die Analyse einbeziehen"
  - name: "@OnlyShowCandidates"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = nur Datenbanken mit Kandidaten oder Scanfehlern ausgeben"
  - name: "@IncludeCommandTemplates"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zusaetzlich DBCC SHRINKFILE Vorlagen fuer Kandidatendateien ausgeben"

result_sets:
  - name: "DatabaseShrinkPriority"
    description: "Priorisierte Datenbanken mit moeglichem Rueckgewinn auf dem angegebenen Laufwerk"
  - name: "ShrinkCommandTemplates"
    description: "Optionale DBCC SHRINKFILE Vorlagen pro Kandidatendatei"
  - name: "ScanErrors"
    description: "Datenbanken oder Scanphasen, die nicht vollstaendig gelesen werden konnten"

dependencies:
  - "sys.databases"
  - "sys.master_files"
  - "sys.database_files"
  - "FILEPROPERTY"
  - "sys.dm_db_log_space_usage"
  - "sys.dm_db_log_info"
  - "tempdb temporary tables"
  - "dynamic SQL"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/20_Create_Database/SQLScripts/DatabaseShrinkCandidateReview.md"
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
  - version: "1.1"
    date: "2026-05-11"
    user: "ER"
    description: "Ergaenzt Zielvolume-Parameter und filtert Daten- und Logdateien nach physical_name-Prefix"
  - version: "1.0"
    date: "2026-05-11"
    user: "ER"
    description: "Erstversion des Shrink-Kandidaten-Reviews fuer Plattenplatz-Notlagen"

notes:
  - "Nur Dateien, deren physical_name mit @TargetVolumeRoot beginnt, gehen in die Potentialberechnung ein."
  - "Das Skript fuehrt keinen Shrink aus und erzeugt nur Review- und Command-Vorlagen."
  - "Logdateien sind meist bessere Notfallkandidaten als Datenfiles, wenn der Logreuse-Wait geloest ist."
  - "Datenfile-Shrinks koennen Fragmentierung erzeugen und sollten nur gezielt und ausnahmsweise erfolgen."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

-- 1. Parameter vorbereiten
DECLARE @TargetVolumeRoot NVARCHAR(260) = N'D:\';
DECLARE @MinimumRecoverableMB DECIMAL(18, 2) = 1024.00;
DECLARE @MinimumRecoverablePct DECIMAL(5, 2) = 20.00;
DECLARE @MinimumPostShrinkFreeMB DECIMAL(18, 2) = 512.00;
DECLARE @TargetFreePctAfterShrink DECIMAL(5, 2) = 10.00;
DECLARE @IncludeSystemDatabases BIT = 0;
DECLARE @OnlyShowCandidates BIT = 1;
DECLARE @IncludeCommandTemplates BIT = 1;
DECLARE @NormalizedVolumeRoot NVARCHAR(260);

SET @TargetVolumeRoot = LTRIM(RTRIM(@TargetVolumeRoot));

IF @TargetVolumeRoot IS NULL OR @TargetVolumeRoot = N''
BEGIN
    THROW 50000, '@TargetVolumeRoot muss ein Laufwerk oder Volume-Prefix enthalten, z. B. D:\.', 1;
END;

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

IF @MinimumRecoverableMB < 0
BEGIN
    THROW 50001, '@MinimumRecoverableMB darf nicht negativ sein.', 1;
END;

IF @MinimumRecoverablePct < 0 OR @MinimumRecoverablePct > 100
BEGIN
    THROW 50002, '@MinimumRecoverablePct muss zwischen 0 und 100 liegen.', 1;
END;

IF @MinimumPostShrinkFreeMB < 0
BEGIN
    THROW 50003, '@MinimumPostShrinkFreeMB darf nicht negativ sein.', 1;
END;

IF @TargetFreePctAfterShrink < 0 OR @TargetFreePctAfterShrink > 100
BEGIN
    THROW 50004, '@TargetFreePctAfterShrink muss zwischen 0 und 100 liegen.', 1;
END;

IF @IncludeSystemDatabases NOT IN (0, 1)
BEGIN
    THROW 50005, '@IncludeSystemDatabases muss 0 oder 1 sein.', 1;
END;

IF @OnlyShowCandidates NOT IN (0, 1)
BEGIN
    THROW 50006, '@OnlyShowCandidates muss 0 oder 1 sein.', 1;
END;

IF @IncludeCommandTemplates NOT IN (0, 1)
BEGIN
    THROW 50007, '@IncludeCommandTemplates muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #DataFileSpace;
DROP TABLE IF EXISTS #LogSpace;
DROP TABLE IF EXISTS #LogVlfEnd;
DROP TABLE IF EXISTS #ShrinkCandidateFiles;
DROP TABLE IF EXISTS #DatabaseScanErrors;

CREATE TABLE #DataFileSpace
(
    DatabaseId INT NOT NULL,
    DatabaseName SYSNAME NOT NULL,
    FileId INT NOT NULL,
    LogicalFileName SYSNAME NOT NULL,
    PhysicalFileName NVARCHAR(260) NOT NULL,
    AllocatedMB DECIMAL(18, 2) NOT NULL,
    UsedMB DECIMAL(18, 2) NOT NULL,
    FreeMB DECIMAL(18, 2) NOT NULL,
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
    LogSinceLastBackupMB DECIMAL(18, 2) NOT NULL
);

CREATE TABLE #LogVlfEnd
(
    DatabaseId INT NOT NULL,
    DatabaseName SYSNAME NOT NULL,
    FileId INT NOT NULL,
    LastActiveVlfEndMB DECIMAL(18, 2) NULL
);

CREATE TABLE #DatabaseScanErrors
(
    DatabaseId INT NULL,
    DatabaseName SYSNAME NULL,
    ScanPhase VARCHAR(40) NOT NULL,
    ErrorNumber INT NOT NULL,
    ErrorMessage NVARCHAR(4000) NOT NULL
);

CREATE TABLE #ShrinkCandidateFiles
(
    CandidateSource VARCHAR(10) NOT NULL,
    DatabaseId INT NOT NULL,
    DatabaseName SYSNAME NOT NULL,
    FileId INT NOT NULL,
    LogicalFileName SYSNAME NOT NULL,
    PhysicalFileName NVARCHAR(260) NOT NULL,
    AllocatedMB DECIMAL(18, 2) NOT NULL,
    UsedOrAnchorMB DECIMAL(18, 2) NULL,
    FreePct DECIMAL(9, 2) NULL,
    TargetSizeMB DECIMAL(18, 2) NOT NULL,
    RecoverableMB DECIMAL(18, 2) NOT NULL,
    MeetsThreshold BIT NOT NULL,
    IsImmediate BIT NOT NULL,
    RiskLevel VARCHAR(20) NOT NULL,
    Prerequisite VARCHAR(260) NOT NULL,
    CommandTemplate NVARCHAR(1000) NOT NULL,
    CommandNote VARCHAR(360) NOT NULL
);

-- 2. Datenbanklokale Groesseninformationen einsammeln
DECLARE @DatabaseName SYSNAME;
DECLARE @Sql NVARCHAR(MAX);

DECLARE database_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT d.name
    FROM sys.databases AS d
    WHERE d.state_desc = 'ONLINE'
      AND d.source_database_id IS NULL
      AND (@IncludeSystemDatabases = 1 OR d.database_id > 4)
      AND EXISTS
      (
          SELECT 1
          FROM sys.master_files AS mf
          WHERE mf.database_id = d.database_id
            AND LEFT(UPPER(COALESCE(mf.physical_name, N'')), LEN(@NormalizedVolumeRoot)) = UPPER(@NormalizedVolumeRoot)
      )
    ORDER BY d.database_id;

OPEN database_cursor;
FETCH NEXT FROM database_cursor INTO @DatabaseName;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @Sql = N'USE ' + QUOTENAME(@DatabaseName) + N';

BEGIN TRY
    INSERT INTO #DataFileSpace
    (
        DatabaseId,
        DatabaseName,
        FileId,
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
        df.name,
        df.physical_name,
        CAST(df.size / 128.0 AS DECIMAL(18, 2)) AS AllocatedMB,
        CAST(COALESCE(FILEPROPERTY(df.name, ''SpaceUsed''), 0) / 128.0 AS DECIMAL(18, 2)) AS UsedMB,
        CAST((df.size - COALESCE(FILEPROPERTY(df.name, ''SpaceUsed''), 0)) / 128.0 AS DECIMAL(18, 2)) AS FreeMB,
        df.growth,
        df.is_percent_growth,
        df.max_size
    FROM sys.database_files AS df
    WHERE df.type_desc = ''ROWS''
      AND LEFT(UPPER(df.physical_name), LEN(@VolumeRoot)) = UPPER(@VolumeRoot);
END TRY
BEGIN CATCH
    INSERT INTO #DatabaseScanErrors
    (
        DatabaseId,
        DatabaseName,
        ScanPhase,
        ErrorNumber,
        ErrorMessage
    )
    SELECT DB_ID(), DB_NAME(), ''data-file-scan'', ERROR_NUMBER(), ERROR_MESSAGE();
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
    INSERT INTO #DatabaseScanErrors
    (
        DatabaseId,
        DatabaseName,
        ScanPhase,
        ErrorNumber,
        ErrorMessage
    )
    SELECT DB_ID(), DB_NAME(), ''log-space-scan'', ERROR_NUMBER(), ERROR_MESSAGE();
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
    INSERT INTO #DatabaseScanErrors
    (
        DatabaseId,
        DatabaseName,
        ScanPhase,
        ErrorNumber,
        ErrorMessage
    )
    SELECT DB_ID(), DB_NAME(), ''log-vlf-scan'', ERROR_NUMBER(), ERROR_MESSAGE();
END CATCH;';

    EXEC sys.sp_executesql
        @Sql,
        N'@VolumeRoot NVARCHAR(260)',
        @VolumeRoot = @NormalizedVolumeRoot;

    FETCH NEXT FROM database_cursor INTO @DatabaseName;
END;

CLOSE database_cursor;
DEALLOCATE database_cursor;

-- 3. Datenfile-Kandidaten ableiten
INSERT INTO #ShrinkCandidateFiles
(
    CandidateSource,
    DatabaseId,
    DatabaseName,
    FileId,
    LogicalFileName,
    PhysicalFileName,
    AllocatedMB,
    UsedOrAnchorMB,
    FreePct,
    TargetSizeMB,
    RecoverableMB,
    MeetsThreshold,
    IsImmediate,
    RiskLevel,
    Prerequisite,
    CommandTemplate,
    CommandNote
)
SELECT
    'DATA' AS CandidateSource,
    dfs.DatabaseId,
    dfs.DatabaseName,
    dfs.FileId,
    dfs.LogicalFileName,
    dfs.PhysicalFileName,
    dfs.AllocatedMB,
    dfs.UsedMB AS UsedOrAnchorMB,
    fp.FreePct,
    t.TargetSizeMB,
    p.RecoverableMB,
    CAST
    (
        CASE
            WHEN p.RecoverableMB >= @MinimumRecoverableMB
             AND fp.FreePct >= @MinimumRecoverablePct THEN 1
            ELSE 0
        END AS BIT
    ) AS MeetsThreshold,
    CAST(0 AS BIT) AS IsImmediate,
    'high' AS RiskLevel,
    'Nur in akuter Speicherplatz-Notlage; danach Fragmentierung, Autogrowth und Ursache des Wachstums pruefen.' AS Prerequisite,
    N'USE ' + QUOTENAME(dfs.DatabaseName) +
        N'; DBCC SHRINKFILE (N''' + REPLACE(dfs.LogicalFileName, N'''', N'''''') +
        N''', ' + CONVERT(NVARCHAR(20), CONVERT(BIGINT, t.TargetSizeMB)) + N');' AS CommandTemplate,
    'Datenfile-Shrink ist die letzte Option; gezielt pro Datei ausfuehren und nicht als Regeljob planen.' AS CommandNote
FROM #DataFileSpace AS dfs
CROSS APPLY
(
    SELECT CAST((dfs.FreeMB * 100.0) / NULLIF(dfs.AllocatedMB, 0) AS DECIMAL(9, 2)) AS FreePct
) AS fp
CROSS APPLY
(
    SELECT
        CAST
        (
            CASE
                WHEN dfs.UsedMB * @TargetFreePctAfterShrink / 100.0 > @MinimumPostShrinkFreeMB
                    THEN dfs.UsedMB * @TargetFreePctAfterShrink / 100.0
                ELSE @MinimumPostShrinkFreeMB
            END AS DECIMAL(18, 2)
        ) AS PostShrinkFreeMB
) AS b
CROSS APPLY
(
    SELECT CAST(CEILING(dfs.UsedMB + b.PostShrinkFreeMB) AS DECIMAL(18, 2)) AS TargetSizeMB
) AS t
CROSS APPLY
(
    SELECT
        CAST
        (
            CASE
                WHEN dfs.AllocatedMB > t.TargetSizeMB THEN dfs.AllocatedMB - t.TargetSizeMB
                ELSE 0
            END AS DECIMAL(18, 2)
        ) AS RecoverableMB
) AS p;

-- 4. Logfile-Kandidaten ableiten
;WITH ScopedLogFiles AS
(
    SELECT
        d.database_id AS DatabaseId,
        d.name AS DatabaseName,
        d.recovery_model_desc AS RecoveryModelDesc,
        d.log_reuse_wait_desc AS LogReuseWaitDesc,
        mf.file_id AS FileId,
        mf.name AS LogicalFileName,
        mf.physical_name AS PhysicalFileName,
        CAST(mf.size / 128.0 AS DECIMAL(18, 2)) AS AllocatedMB,
        COUNT(*) OVER (PARTITION BY d.database_id) AS LogFileCount,
        ls.UsedLogMB,
        ls.UsedLogPct,
        vlf.LastActiveVlfEndMB
    FROM sys.databases AS d
    INNER JOIN sys.master_files AS mf
        ON mf.database_id = d.database_id
       AND mf.type_desc = 'LOG'
    LEFT JOIN #LogSpace AS ls
        ON ls.DatabaseId = d.database_id
    LEFT JOIN #LogVlfEnd AS vlf
        ON vlf.DatabaseId = d.database_id
       AND vlf.FileId = mf.file_id
    WHERE d.state_desc = 'ONLINE'
      AND d.source_database_id IS NULL
      AND (@IncludeSystemDatabases = 1 OR d.database_id > 4)
      AND LEFT(UPPER(COALESCE(mf.physical_name, N'')), LEN(@NormalizedVolumeRoot)) = UPPER(@NormalizedVolumeRoot)
)
INSERT INTO #ShrinkCandidateFiles
(
    CandidateSource,
    DatabaseId,
    DatabaseName,
    FileId,
    LogicalFileName,
    PhysicalFileName,
    AllocatedMB,
    UsedOrAnchorMB,
    FreePct,
    TargetSizeMB,
    RecoverableMB,
    MeetsThreshold,
    IsImmediate,
    RiskLevel,
    Prerequisite,
    CommandTemplate,
    CommandNote
)
SELECT
    'LOG' AS CandidateSource,
    slf.DatabaseId,
    slf.DatabaseName,
    slf.FileId,
    slf.LogicalFileName,
    slf.PhysicalFileName,
    slf.AllocatedMB,
    CASE
        WHEN slf.LogFileCount = 1 THEN slf.UsedLogMB
        ELSE av.ActiveVlfEndMB
    END AS UsedOrAnchorMB,
    fp.LogFreePct AS FreePct,
    t.TargetSizeMB,
    p.RecoverableMB,
    CAST
    (
        CASE
            WHEN p.RecoverableMB >= @MinimumRecoverableMB
             AND fp.LogFreePct >= @MinimumRecoverablePct THEN 1
            ELSE 0
        END AS BIT
    ) AS MeetsThreshold,
    CAST
    (
        CASE
            WHEN p.RecoverableMB >= @MinimumRecoverableMB
             AND fp.LogFreePct >= @MinimumRecoverablePct
             AND slf.LogReuseWaitDesc IN ('NOTHING', 'CHECKPOINT') THEN 1
            ELSE 0
        END AS BIT
    ) AS IsImmediate,
    CASE
        WHEN slf.LogReuseWaitDesc IN ('NOTHING', 'CHECKPOINT') THEN 'medium'
        ELSE 'blocked'
    END AS RiskLevel,
    CASE
        WHEN slf.LogReuseWaitDesc = 'LOG_BACKUP' THEN 'Erst Logbackup ausfuehren; danach erneut messen.'
        WHEN slf.LogReuseWaitDesc NOT IN ('NOTHING', 'CHECKPOINT') THEN 'Logreuse-Wait beheben: ' + slf.LogReuseWaitDesc + '. Danach erneut messen.'
        ELSE 'Ursache des Logwachstums klaeren; danach einmalig shrinken und sinnvolle Loggroesse setzen.'
    END AS Prerequisite,
    N'USE ' + QUOTENAME(slf.DatabaseName) +
        N'; DBCC SHRINKFILE (N''' + REPLACE(slf.LogicalFileName, N'''', N'''''') +
        N''', ' + CONVERT(NVARCHAR(20), CONVERT(BIGINT, t.TargetSizeMB)) + N');' AS CommandTemplate,
    CASE
        WHEN slf.LogFileCount > 1 THEN 'Mehrere Logdateien: VLF-Lage pro Datei pruefen; DB-weiter UsedLogMB ist nicht dateischarf.'
        WHEN slf.LogReuseWaitDesc NOT IN ('NOTHING', 'CHECKPOINT') THEN 'Vor Ausfuehrung Reuse-Wait beheben, dann erneut messen.'
        ELSE 'Log-Shrink nur einmalig nach behobener Ursache; danach Autogrowth und Logbackup-Kette pruefen.'
    END AS CommandNote
FROM ScopedLogFiles AS slf
CROSS APPLY
(
    SELECT CAST(100.0 - COALESCE(slf.UsedLogPct, 100.0) AS DECIMAL(9, 2)) AS LogFreePct
) AS fp
CROSS APPLY
(
    SELECT CAST(COALESCE(slf.LastActiveVlfEndMB, 0.00) AS DECIMAL(18, 2)) AS ActiveVlfEndMB
) AS av
CROSS APPLY
(
    SELECT
        CAST
        (
            COALESCE(slf.UsedLogMB, slf.AllocatedMB) +
            CASE
                WHEN COALESCE(slf.UsedLogMB, 0.00) * @TargetFreePctAfterShrink / 100.0 > @MinimumPostShrinkFreeMB
                    THEN COALESCE(slf.UsedLogMB, 0.00) * @TargetFreePctAfterShrink / 100.0
                ELSE @MinimumPostShrinkFreeMB
            END AS DECIMAL(18, 2)
        ) AS UsedLogWithBufferMB
) AS ub
CROSS APPLY
(
    SELECT
        CAST
        (
            CASE
                WHEN slf.LogFileCount = 1 THEN
                    CASE
                        WHEN av.ActiveVlfEndMB > ub.UsedLogWithBufferMB THEN av.ActiveVlfEndMB
                        ELSE ub.UsedLogWithBufferMB
                    END
                ELSE
                    CASE
                        WHEN av.ActiveVlfEndMB > @MinimumPostShrinkFreeMB THEN av.ActiveVlfEndMB
                        ELSE @MinimumPostShrinkFreeMB
                    END
            END AS DECIMAL(18, 2)
        ) AS RawTargetSizeMB
) AS rt
CROSS APPLY
(
    SELECT
        CAST
        (
            CEILING
            (
                CASE
                    WHEN rt.RawTargetSizeMB < @MinimumPostShrinkFreeMB THEN @MinimumPostShrinkFreeMB
                    ELSE rt.RawTargetSizeMB
                END
            ) AS DECIMAL(18, 2)
        ) AS TargetSizeMB
) AS t
CROSS APPLY
(
    SELECT
        CAST
        (
            CASE
                WHEN slf.AllocatedMB > t.TargetSizeMB THEN slf.AllocatedMB - t.TargetSizeMB
                ELSE 0
            END AS DECIMAL(18, 2)
        ) AS RecoverableMB
) AS p;

-- 5. Datenbanken nach sinnvollstem Shrink-Potential priorisieren
;WITH DatabaseScope AS
(
    SELECT
        d.database_id AS DatabaseId,
        d.name AS DatabaseName,
        d.state_desc AS StateDesc,
        d.recovery_model_desc AS RecoveryModelDesc,
        d.log_reuse_wait_desc AS LogReuseWaitDesc,
        d.is_read_only AS IsReadOnly
    FROM sys.databases AS d
    WHERE d.state_desc = 'ONLINE'
      AND d.source_database_id IS NULL
      AND (@IncludeSystemDatabases = 1 OR d.database_id > 4)
      AND EXISTS
      (
          SELECT 1
          FROM sys.master_files AS mf
          WHERE mf.database_id = d.database_id
            AND LEFT(UPPER(COALESCE(mf.physical_name, N'')), LEN(@NormalizedVolumeRoot)) = UPPER(@NormalizedVolumeRoot)
      )
),
DataRollup AS
(
    SELECT
        dfs.DatabaseId,
        SUM(dfs.AllocatedMB) AS DataAllocatedMB,
        SUM(dfs.UsedMB) AS DataUsedMB,
        SUM(dfs.FreeMB) AS DataFreeMB,
        CAST((SUM(dfs.FreeMB) * 100.0) / NULLIF(SUM(dfs.AllocatedMB), 0) AS DECIMAL(9, 2)) AS DataFreePct
    FROM #DataFileSpace AS dfs
    GROUP BY dfs.DatabaseId
),
LogRollup AS
(
    SELECT
        d.database_id AS DatabaseId,
        SUM(CAST(mf.size / 128.0 AS DECIMAL(18, 2))) AS LogAllocatedMB,
        MAX(ls.UsedLogMB) AS LogUsedMB,
        CASE
            WHEN MAX(ls.UsedLogMB) IS NULL THEN NULL
            ELSE SUM(CAST(mf.size / 128.0 AS DECIMAL(18, 2))) - MAX(ls.UsedLogMB)
        END AS LogFreeMB,
        CAST(100.0 - MAX(ls.UsedLogPct) AS DECIMAL(9, 2)) AS LogFreePct,
        COUNT(mf.file_id) AS LogFileCount
    FROM sys.databases AS d
    INNER JOIN sys.master_files AS mf
        ON mf.database_id = d.database_id
       AND mf.type_desc = 'LOG'
    LEFT JOIN #LogSpace AS ls
        ON ls.DatabaseId = d.database_id
    WHERE d.state_desc = 'ONLINE'
      AND d.source_database_id IS NULL
      AND (@IncludeSystemDatabases = 1 OR d.database_id > 4)
      AND LEFT(UPPER(COALESCE(mf.physical_name, N'')), LEN(@NormalizedVolumeRoot)) = UPPER(@NormalizedVolumeRoot)
    GROUP BY d.database_id
),
CandidateRollup AS
(
    SELECT
        scf.DatabaseId,
        SUM(CASE WHEN scf.CandidateSource = 'DATA' AND scf.MeetsThreshold = 1 THEN scf.RecoverableMB ELSE 0 END) AS DataPotentialMB,
        SUM(CASE WHEN scf.CandidateSource = 'LOG' AND scf.MeetsThreshold = 1 THEN scf.RecoverableMB ELSE 0 END) AS LogPotentialMB,
        SUM(CASE WHEN scf.CandidateSource = 'LOG' AND scf.MeetsThreshold = 1 AND scf.IsImmediate = 1 THEN scf.RecoverableMB ELSE 0 END) AS ImmediateLogPotentialMB,
        SUM(CASE WHEN scf.CandidateSource = 'LOG' AND scf.MeetsThreshold = 1 AND scf.IsImmediate = 0 THEN scf.RecoverableMB ELSE 0 END) AS BlockedLogPotentialMB,
        SUM(CASE WHEN scf.MeetsThreshold = 1 THEN scf.RecoverableMB ELSE 0 END) AS TotalPotentialMB
    FROM #ShrinkCandidateFiles AS scf
    GROUP BY scf.DatabaseId
),
ErrorRollup AS
(
    SELECT
        dse.DatabaseId,
        COUNT(*) AS ScanErrorCount
    FROM #DatabaseScanErrors AS dse
    GROUP BY dse.DatabaseId
),
Prioritized AS
(
    SELECT
        ds.DatabaseId,
        ds.DatabaseName,
        ds.StateDesc,
        ds.RecoveryModelDesc,
        ds.LogReuseWaitDesc,
        ds.IsReadOnly,
        COALESCE(dr.DataAllocatedMB, 0.00) AS DataAllocatedMB,
        COALESCE(dr.DataUsedMB, 0.00) AS DataUsedMB,
        COALESCE(dr.DataFreeMB, 0.00) AS DataFreeMB,
        dr.DataFreePct,
        COALESCE(lr.LogAllocatedMB, 0.00) AS LogAllocatedMB,
        lr.LogUsedMB,
        lr.LogFreeMB,
        lr.LogFreePct,
        COALESCE(lr.LogFileCount, 0) AS LogFileCount,
        COALESCE(cr.DataPotentialMB, 0.00) AS DataPotentialMB,
        COALESCE(cr.LogPotentialMB, 0.00) AS LogPotentialMB,
        COALESCE(cr.ImmediateLogPotentialMB, 0.00) AS ImmediateLogPotentialMB,
        COALESCE(cr.BlockedLogPotentialMB, 0.00) AS BlockedLogPotentialMB,
        COALESCE(cr.TotalPotentialMB, 0.00) AS TotalPotentialMB,
        COALESCE(er.ScanErrorCount, 0) AS ScanErrorCount
    FROM DatabaseScope AS ds
    LEFT JOIN DataRollup AS dr
        ON dr.DatabaseId = ds.DatabaseId
    LEFT JOIN LogRollup AS lr
        ON lr.DatabaseId = ds.DatabaseId
    LEFT JOIN CandidateRollup AS cr
        ON cr.DatabaseId = ds.DatabaseId
    LEFT JOIN ErrorRollup AS er
        ON er.DatabaseId = ds.DatabaseId
)
SELECT
    ROW_NUMBER() OVER
    (
        ORDER BY
            CASE
                WHEN p.ImmediateLogPotentialMB > 0 THEN 1
                WHEN p.BlockedLogPotentialMB > 0 THEN 2
                WHEN p.DataPotentialMB > 0 THEN 3
                WHEN p.ScanErrorCount > 0 THEN 4
                ELSE 5
            END,
            p.TotalPotentialMB DESC,
            p.DatabaseName
    ) AS ShrinkPriorityRank,
    @NormalizedVolumeRoot AS TargetVolumeRoot,
    p.DatabaseName,
    p.StateDesc,
    p.RecoveryModelDesc,
    p.LogReuseWaitDesc,
    p.IsReadOnly,
    p.DataAllocatedMB,
    p.DataUsedMB,
    p.DataFreeMB,
    p.DataFreePct,
    p.LogAllocatedMB,
    p.LogUsedMB,
    p.LogFreeMB,
    p.LogFreePct,
    p.LogFileCount,
    p.ImmediateLogPotentialMB,
    p.BlockedLogPotentialMB,
    p.LogPotentialMB,
    p.DataPotentialMB,
    p.TotalPotentialMB,
    CAST(p.TotalPotentialMB / 1024.0 AS DECIMAL(18, 3)) AS TotalPotentialGB,
    p.ScanErrorCount,
    CASE
        WHEN p.ImmediateLogPotentialMB > 0 THEN 'immediate-log-shrink-review'
        WHEN p.BlockedLogPotentialMB > 0 THEN 'fix-log-reuse-first'
        WHEN p.DataPotentialMB > 0 THEN 'datafile-last-resort'
        WHEN p.ScanErrorCount > 0 THEN 'scan-error-review'
        ELSE 'no-candidate'
    END AS ActionClass,
    CASE
        WHEN p.ImmediateLogPotentialMB > 0 THEN 'Bester Notfall-Kandidat: Logdatei mit viel freiem Logspace und ohne blockierenden Reuse-Wait.'
        WHEN p.BlockedLogPotentialMB > 0 THEN 'Log wirkt gross, aber Reuse-Wait blockiert; Backup, offene Transaktionen, Replikation oder HA zuerst pruefen.'
        WHEN p.DataPotentialMB > 0 THEN 'Datenfile-Shrink nur als letzter Schritt; danach Fragmentierung und Autogrowth kontrollieren.'
        WHEN p.ScanErrorCount > 0 THEN 'Mindestens ein Scan-Schritt konnte nicht ausgefuehrt werden; ScanErrors pruefen.'
        ELSE 'Nach den gesetzten Schwellenwerten kein sinnvoller Shrink-Kandidat.'
    END AS ReviewFocus
FROM Prioritized AS p
WHERE @OnlyShowCandidates = 0
   OR p.TotalPotentialMB >= @MinimumRecoverableMB
   OR p.ScanErrorCount > 0
ORDER BY
    ShrinkPriorityRank;

-- 6. Optionale Command-Vorlagen fuer einzelne Kandidatendateien ausgeben
SELECT
    @NormalizedVolumeRoot AS TargetVolumeRoot,
    scf.CandidateSource,
    scf.DatabaseName,
    scf.FileId,
    scf.LogicalFileName,
    scf.PhysicalFileName,
    scf.AllocatedMB,
    scf.UsedOrAnchorMB,
    scf.FreePct,
    scf.TargetSizeMB,
    scf.RecoverableMB,
    CAST(scf.RecoverableMB / 1024.0 AS DECIMAL(18, 3)) AS RecoverableGB,
    scf.RiskLevel,
    scf.Prerequisite,
    scf.CommandTemplate,
    scf.CommandNote
FROM #ShrinkCandidateFiles AS scf
WHERE @IncludeCommandTemplates = 1
  AND scf.MeetsThreshold = 1
ORDER BY
    CASE WHEN scf.CandidateSource = 'LOG' THEN 1 ELSE 2 END,
    scf.IsImmediate DESC,
    scf.RecoverableMB DESC,
    scf.DatabaseName,
    scf.FileId;

-- 7. Scanfehler transparent machen
SELECT
    dse.DatabaseName,
    dse.ScanPhase,
    dse.ErrorNumber,
    dse.ErrorMessage
FROM #DatabaseScanErrors AS dse
ORDER BY
    dse.DatabaseName,
    dse.ScanPhase;
