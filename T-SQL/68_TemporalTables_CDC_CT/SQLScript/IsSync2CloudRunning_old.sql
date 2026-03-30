DECLARE @DBName SYSNAME = N'BI_DWH';
DECLARE @StaleMinutes INT = 15;
DECLARE @SQL NVARCHAR(MAX);

------------------------------------------------------------
-- 1) Instanz / Version / DB-Status
------------------------------------------------------------
SELECT
    @@SERVERNAME AS ServerName,
    CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(128)) AS ProductVersion,
    CAST(SERVERPROPERTY('ProductMajorVersion') AS NVARCHAR(128)) AS ProductMajorVersion,
    CAST(SERVERPROPERTY('Edition') AS NVARCHAR(128)) AS Edition;

SELECT
    d.name AS DatabaseName,
    d.state_desc,
    d.recovery_model_desc,
    d.log_reuse_wait_desc,
    d.is_cdc_enabled
FROM sys.databases AS d
WHERE d.name = @DBName;

------------------------------------------------------------
-- 2) CDC-tabellen in der DB
------------------------------------------------------------
SET @SQL = N'
USE ' + QUOTENAME(@DBName) + N';

SELECT
    s.name AS SchemaName,
    t.name AS TableName,
    t.is_tracked_by_cdc
FROM sys.tables AS t
INNER JOIN sys.schemas AS s
    ON s.schema_id = t.schema_id
WHERE t.is_tracked_by_cdc = 1
ORDER BY s.name, t.name;
';
EXEC sys.sp_executesql @stmt = @SQL;

------------------------------------------------------------
-- 3) Letzte CDC-Log-Scan-Sessions
------------------------------------------------------------
SET @SQL = N'
USE ' + QUOTENAME(@DBName) + N';

BEGIN TRY
    ;WITH LastSessions AS
    (
        SELECT TOP (5)
            session_id,
            start_time,
            end_time,
            duration,
            scan_phase,
            error_count,
            start_lsn,
            current_lsn,
            end_lsn,
            tran_count,
            last_commit_lsn,
            last_commit_time,
            log_record_count,
            schema_change_count,
            command_count,
            first_begin_cdc_lsn,
            last_commit_cdc_lsn,
            last_commit_cdc_time,
            latency,
            empty_scan_count,
            failed_sessions_count
        FROM sys.dm_cdc_log_scan_sessions
        WHERE session_id > 0
        ORDER BY session_id DESC
    )
    SELECT
        session_id,
        start_time,
        end_time,
        CASE
            WHEN end_time IS NULL THEN ''ACTIVE''
            WHEN error_count > 0 OR failed_sessions_count > 0 THEN ''ERROR_OR_RETRY''
            WHEN last_commit_cdc_time >= DATEADD(MINUTE, -' + CAST(@StaleMinutes AS NVARCHAR(10)) + N', GETDATE()) THEN ''RUNNING_RECENTLY''
            ELSE ''STALE''
        END AS SyncHealth,
        duration,
        scan_phase,
        error_count,
        tran_count,
        command_count,
        last_commit_lsn,
        last_commit_time,
        last_commit_cdc_lsn,
        last_commit_cdc_time,
        latency,
        empty_scan_count,
        failed_sessions_count,
        start_lsn,
        current_lsn,
        end_lsn
    FROM LastSessions
    ORDER BY session_id DESC;
END TRY
BEGIN CATCH
    SELECT
        ERROR_NUMBER() AS ErrorNumber,
        ERROR_MESSAGE() AS ErrorMessage;
END CATCH;
';
EXEC sys.sp_executesql @stmt = @SQL;

------------------------------------------------------------
-- 4) CDC-Jobs
------------------------------------------------------------
SET @SQL = N'
USE ' + QUOTENAME(@DBName) + N';

BEGIN TRY
    EXEC sys.sp_cdc_help_jobs;
END TRY
BEGIN CATCH
    SELECT
        ERROR_NUMBER() AS ErrorNumber,
        ERROR_MESSAGE() AS ErrorMessage;
END CATCH;
';
EXEC sys.sp_executesql @stmt = @SQL;

------------------------------------------------------------
-- 5) CDC-Fehler
------------------------------------------------------------
SET @SQL = N'
USE ' + QUOTENAME(@DBName) + N';

BEGIN TRY
    SELECT TOP (20)
        entry_time,
        error_number,
        error_severity,
        error_state,
        error_message,
        start_lsn,
        begin_lsn,
        sequence_value
    FROM sys.dm_cdc_errors
    ORDER BY entry_time DESC;
END TRY
BEGIN CATCH
    SELECT
        ERROR_NUMBER() AS ErrorNumber,
        ERROR_MESSAGE() AS ErrorMessage;
END CATCH;
';
EXEC sys.sp_executesql @stmt = @SQL;

/*
So liest du das Ergebnis:

is_cdc_enabled = 1 und es gibt Tabellen mit is_tracked_by_cdc = 1
→ die DB ist aus SQL-Server-Sicht für CDC-basiertes Mirroring/Change-Capture vorbereitet.

In sys.dm_cdc_log_scan_sessions ist die letzte Session ACTIVE oder RUNNING_RECENTLY, und last_commit_cdc_time ist frisch
→ der Leser verarbeitet aktuell oder sehr kürzlich Änderungen aus dem Log. Die DMV ist genau für den Status der aktuellen bzw. letzten Log-Scan-Sessions gedacht; last_commit_cdc_time, tran_count, command_count, error_count und failed_sessions_count sind die relevanten Indikatoren.

ERROR_OR_RETRY oder Einträge in sys.dm_cdc_errors
→ der Capture-Pfad hat Fehler. sys.dm_cdc_errors liefert laut Microsoft eine Zeile pro Fehler während einer CDC-Log-Scan-Session.

STALE und last_commit_cdc_time ist alt
→ aus der Quelle werden gerade keine frischen Änderungen mehr verarbeitet; dann musst du in Richtung CDC-Capture-Job, SQL Agent oder Fabric-Seite weitergehen. sys.sp_cdc_help_jobs zeigt dir die konfigurierten Capture-/Cleanup-Jobs der Datenbank.

Wichtig noch: Meine Spalte SyncHealth ist eine praktische Auswertungsschicht von mir. Die offiziellen Rohsignale sind end_time, last_commit_cdc_time, error_count, failed_sessions_count, tran_count und command_count.
*/