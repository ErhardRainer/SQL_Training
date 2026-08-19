/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "BackupChainIntegrityCheck.sql"
script_version: "1.0"
script_type: "diagnostic"
chapter: "71_BackupRestore_Strategies"
purpose: >
  Prueft fuer eine oder alle Datenbanken, ob die Log-Backup-Kette
  (LSN-Kette) seit dem letzten Full-/Differential-Backup lueckenlos ist -
  d.h. ob jedes Log-Backup nahtlos an die last_lsn des vorherigen anschliesst
  (first_lsn = last_lsn des Vorgaengers). Eine Luecke bedeutet, dass ein
  Point-in-Time-Restore ueber diese Stelle hinweg NICHT moeglich ist, selbst
  wenn alle Backup-Dateien vorhanden sind. Zeigt zusaetzlich an, ob die
  physischen Backup-Dateien laut msdb.dbo.backupmediafamily ueberhaupt noch
  existieren (sofern lokal pruefbar).

parameters:
  - name: "@TargetDatabaseName"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Name einer einzelnen zu pruefenden Datenbank; NULL (Default) prueft alle Datenbanken mit Recovery Model FULL oder BULK_LOGGED, die mindestens ein Full-Backup besitzen"
  - name: "@CheckPhysicalFileExistence"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 (Default) = prueft zusaetzlich per sys.dm_os_file_exists, ob die in msdb referenzierten Backup-Dateien noch physisch vorhanden sind (nur fuer lokale Pfade moeglich); 0 = nur LSN-Kettenpruefung ohne Dateisystemzugriff"

result_sets:
  - name: "BackupChainIntegrityCheck"
    description: "Je Datenbank und je Log-Backup in der Kette: LSN-Werte, ob nahtloser Anschluss an den Vorgaenger besteht, und (optional) ob die Backup-Datei noch existiert"
  - name: "BackupChainSummary"
    description: "Je Datenbank verdichtete Aussage: Anzahl gefundener Luecken, aeltestes/juengstes Backup in der Kette, und eine Klartext-Einordnung (INTAKT / LUECKENHAFT / KEINE KETTE)"

dependencies:
  - "sys.databases"
  - "msdb.dbo.backupset"
  - "msdb.dbo.backupmediafamily"
  - "sys.dm_os_file_exists"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/71_BackupRestore_Strategies/SQLScripts/BackupChainIntegrityCheck.md"
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
    date: "2026-08-14"
    user: "ER"
    description: "Erstversion: LSN-Ketten-Pruefung (first_lsn/last_lsn) fuer Log-Backups seit dem letzten Full/Differential je Datenbank, mit optionaler physischer Dateiexistenzpruefung"

notes:
  - "Eine LSN-Luecke bedeutet NICHT zwingend Datenverlust im Sinne einer beschaedigten Datenbank - sie bedeutet, dass ein Point-in-Time-Restore ueber die Luecke hinweg nicht moeglich ist. Ursachen sind meist ein manuell geloeschtes/uebersehenes Log-Backup, ein Recovery-Model-Wechsel zu SIMPLE und zurueck, oder ein fehlgeschlagener Log-Backup-Job."
  - "Nur Datenbanken im Recovery Model FULL oder BULK_LOGGED werden geprueft (Default-Modus ohne @TargetDatabaseName) - im SIMPLE Model gibt es keine Log-Kette."
  - "Die physische Dateiexistenzpruefung (sys.dm_os_file_exists) funktioniert nur fuer Pfade, die vom SQL-Server-Dienstkonto aus erreichbar sind, und wird bei fehlenden Berechtigungen oder nicht erreichbaren Netzlaufwerken als 'nicht pruefbar' statt faelschlich als 'fehlt' ausgewiesen."
  - "Dieses Skript ist die Ergaenzung zu RestoreDatabaseFromLatestBackup.sql: Bevor eine automatisch ermittelte Kette tatsaechlich fuer einen Restore verwendet wird, sollte mit diesem Skript geprueft werden, ob sie ueberhaupt luecklos ist."
  - "Fuer die Backup-Historie-Abfrage als Ausgangsbasis siehe auch SuspectOrRecoveryPendingDatabase_RepairOptions.md Abschnitt 5."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

-- 1. Parameter vorbereiten
DECLARE @TargetDatabaseName SYSNAME = NULL;
DECLARE @CheckPhysicalFileExistence BIT = 1;

IF @TargetDatabaseName IS NOT NULL AND LTRIM(RTRIM(@TargetDatabaseName)) = N''
BEGIN
    THROW 50000, '@TargetDatabaseName darf, wenn angegeben, nicht leer sein.', 1;
END;

IF @TargetDatabaseName IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = @TargetDatabaseName)
BEGIN
    THROW 50001, 'Die angegebene Datenbank wurde nicht in sys.databases gefunden.', 1;
END;

IF @CheckPhysicalFileExistence IS NULL OR @CheckPhysicalFileExistence NOT IN (0, 1)
BEGIN
    THROW 50002, '@CheckPhysicalFileExistence muss 0 oder 1 sein.', 1;
END;

-- 2. Zu pruefende Datenbanken ermitteln
DROP TABLE IF EXISTS #DatabasesToCheck;
CREATE TABLE #DatabasesToCheck (DatabaseName SYSNAME NOT NULL);

INSERT INTO #DatabasesToCheck (DatabaseName)
SELECT d.name
FROM sys.databases AS d
WHERE (@TargetDatabaseName IS NOT NULL AND d.name = @TargetDatabaseName)
   OR (@TargetDatabaseName IS NULL
       AND d.recovery_model_desc IN ('FULL', 'BULK_LOGGED')
       AND EXISTS (SELECT 1 FROM msdb.dbo.backupset WHERE database_name = d.name AND type = 'D'));

-- 3. Je Datenbank: letztes Full-/Differential-Backup (Kettenbasis) und alle Log-Backups danach ermitteln
DROP TABLE IF EXISTS #ChainBase;
CREATE TABLE #ChainBase
(
    DatabaseName  SYSNAME  NOT NULL,
    BaseLSN       NUMERIC(25,0) NULL,
    BaseFinishDate DATETIME NULL
);

INSERT INTO #ChainBase (DatabaseName, BaseLSN, BaseFinishDate)
SELECT
    dtc.DatabaseName,
    latest.LastLSN,
    latest.BackupFinishDate
FROM #DatabasesToCheck AS dtc
OUTER APPLY (
    SELECT TOP (1) bs.last_lsn AS LastLSN, bs.backup_finish_date AS BackupFinishDate
    FROM msdb.dbo.backupset AS bs
    WHERE bs.database_name = dtc.DatabaseName AND bs.type IN ('D', 'I')
    ORDER BY bs.backup_finish_date DESC
) AS latest;

DROP TABLE IF EXISTS #LogChain;
CREATE TABLE #LogChain
(
    DatabaseName     SYSNAME       NOT NULL,
    BackupSetId      INT           NOT NULL,
    FirstLSN         NUMERIC(25,0) NOT NULL,
    LastLSN          NUMERIC(25,0) NOT NULL,
    BackupStartDate  DATETIME      NOT NULL,
    BackupFinishDate DATETIME      NOT NULL,
    RowNum           INT           NOT NULL
);

INSERT INTO #LogChain (DatabaseName, BackupSetId, FirstLSN, LastLSN, BackupStartDate, BackupFinishDate, RowNum)
SELECT
    bs.database_name,
    bs.backup_set_id,
    bs.first_lsn,
    bs.last_lsn,
    bs.backup_start_date,
    bs.backup_finish_date,
    ROW_NUMBER() OVER (PARTITION BY bs.database_name ORDER BY bs.backup_finish_date ASC)
FROM msdb.dbo.backupset AS bs
JOIN #ChainBase AS cb
    ON cb.DatabaseName = bs.database_name AND cb.BaseLSN IS NOT NULL
WHERE bs.type = 'L'
  AND bs.backup_finish_date >= cb.BaseFinishDate;

-- 4. Luecken ermitteln: first_lsn eines Log-Backups muss dem last_lsn des Vorgaengers entsprechen
--    (bzw. dem BaseLSN des Full/Diff-Backups fuer das allererste Log-Backup in der Kette)
DROP TABLE IF EXISTS #ChainCheck;
CREATE TABLE #ChainCheck
(
    DatabaseName     SYSNAME       NOT NULL,
    BackupSetId      INT           NOT NULL,
    RowNum           INT           NOT NULL,
    FirstLSN         NUMERIC(25,0) NOT NULL,
    LastLSN          NUMERIC(25,0) NOT NULL,
    ExpectedFirstLSN NUMERIC(25,0) NULL,
    IsSeamless       BIT           NOT NULL,
    BackupStartDate  DATETIME      NOT NULL,
    BackupFinishDate DATETIME      NOT NULL
);

INSERT INTO #ChainCheck (DatabaseName, BackupSetId, RowNum, FirstLSN, LastLSN, ExpectedFirstLSN, IsSeamless, BackupStartDate, BackupFinishDate)
SELECT
    lc.DatabaseName,
    lc.BackupSetId,
    lc.RowNum,
    lc.FirstLSN,
    lc.LastLSN,
    COALESCE(prev.LastLSN, cb.BaseLSN)                                        AS ExpectedFirstLSN,
    CASE WHEN lc.FirstLSN = COALESCE(prev.LastLSN, cb.BaseLSN) THEN 1 ELSE 0 END AS IsSeamless,
    lc.BackupStartDate,
    lc.BackupFinishDate
FROM #LogChain AS lc
JOIN #ChainBase AS cb
    ON cb.DatabaseName = lc.DatabaseName
LEFT JOIN #LogChain AS prev
    ON prev.DatabaseName = lc.DatabaseName AND prev.RowNum = lc.RowNum - 1;

-- 5. Physische Dateien optional pruefen
DROP TABLE IF EXISTS #FileCheck;
CREATE TABLE #FileCheck
(
    DatabaseName SYSNAME NOT NULL,
    BackupSetId  INT     NOT NULL,
    PhysicalDeviceName NVARCHAR(260) NULL,
    FileExists   BIT     NULL
);

IF @CheckPhysicalFileExistence = 1
BEGIN
    INSERT INTO #FileCheck (DatabaseName, BackupSetId, PhysicalDeviceName, FileExists)
    SELECT
        cc.DatabaseName,
        cc.BackupSetId,
        bmf.physical_device_name,
        fe.file_exists
    FROM #ChainCheck AS cc
    JOIN msdb.dbo.backupmediafamily AS bmf
        ON bmf.media_set_id = (SELECT media_set_id FROM msdb.dbo.backupset WHERE backup_set_id = cc.BackupSetId)
    CROSS APPLY sys.dm_os_file_exists(bmf.physical_device_name) AS fe;
END;

-- 6. Ergebnis je Log-Backup ausgeben
SELECT
    cc.DatabaseName,
    cc.RowNum                                                              AS SequenceInChain,
    cc.BackupSetId,
    cc.BackupStartDate,
    cc.BackupFinishDate,
    cc.ExpectedFirstLSN,
    cc.FirstLSN,
    cc.LastLSN,
    CASE cc.IsSeamless WHEN 1 THEN 'OK' ELSE 'LUECKE' END                   AS ChainStatus,
    fc.PhysicalDeviceName,
    CASE
        WHEN @CheckPhysicalFileExistence = 0 THEN 'Nicht geprueft'
        WHEN fc.FileExists IS NULL THEN 'Nicht pruefbar'
        WHEN fc.FileExists = 1 THEN 'Vorhanden'
        ELSE 'FEHLT'
    END                                                                     AS PhysicalFileStatus
FROM #ChainCheck AS cc
LEFT JOIN #FileCheck AS fc
    ON fc.DatabaseName = cc.DatabaseName AND fc.BackupSetId = cc.BackupSetId
ORDER BY
    cc.DatabaseName,
    cc.RowNum;

-- 7. Verdichtete Zusammenfassung je Datenbank
SELECT
    dtc.DatabaseName,
    cb.BaseFinishDate                                                       AS ChainStartsAt,
    (SELECT MAX(BackupFinishDate) FROM #LogChain WHERE DatabaseName = dtc.DatabaseName) AS LastLogBackupAt,
    (SELECT COUNT(*) FROM #LogChain WHERE DatabaseName = dtc.DatabaseName)   AS LogBackupCount,
    (SELECT COUNT(*) FROM #ChainCheck WHERE DatabaseName = dtc.DatabaseName AND IsSeamless = 0) AS GapCount,
    CASE
        WHEN cb.BaseLSN IS NULL THEN 'KEINE KETTE - kein Full/Differential-Backup vorhanden.'
        WHEN NOT EXISTS (SELECT 1 FROM #LogChain WHERE DatabaseName = dtc.DatabaseName) THEN 'Kein Log-Backup nach dem letzten Full/Differential vorhanden.'
        WHEN EXISTS (SELECT 1 FROM #ChainCheck WHERE DatabaseName = dtc.DatabaseName AND IsSeamless = 0) THEN 'LUECKENHAFT - Point-in-Time-Restore ueber die Luecke(n) hinweg nicht moeglich.'
        WHEN @CheckPhysicalFileExistence = 1 AND EXISTS (SELECT 1 FROM #FileCheck WHERE DatabaseName = dtc.DatabaseName AND FileExists = 0) THEN 'LSN-Kette intakt, aber mindestens eine Backup-Datei fehlt physisch.'
        ELSE 'INTAKT - LSN-Kette lueckenlos.'
    END                                                                     AS Assessment
FROM #DatabasesToCheck AS dtc
LEFT JOIN #ChainBase AS cb
    ON cb.DatabaseName = dtc.DatabaseName
ORDER BY
    CASE
        WHEN cb.BaseLSN IS NULL THEN 0
        WHEN EXISTS (SELECT 1 FROM #ChainCheck WHERE DatabaseName = dtc.DatabaseName AND IsSeamless = 0) THEN 1
        ELSE 2
    END,
    dtc.DatabaseName;
