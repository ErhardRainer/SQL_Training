/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "ModelDatabaseOptionSnapshot.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "20_Create_Database"
purpose: >
  Erstellt einen lesenden Schnappschuss der wichtigsten Optionen der
  model-Datenbank als Baseline fuer neue SQL-Server-Datenbanken.
parameters:
  - name: "@DatabaseName"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Zieldatenbank fuer den Snapshot; standardmaessig model"
  - name: "@IncludeFileLayout"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zusaetzlich Dateilayout und Growth-Infos ausgeben"
result_sets:
  - name: "DatabaseOptionSnapshot"
    description: "Zentrale Datenbankoptionen und CREATE DATABASE-nahe Baseline-Eigenschaften"
  - name: "DatabaseFileLayout"
    description: "Datei- und Growth-Konfiguration der gewaehlten Datenbank"
dependencies:
  - "sys.databases"
  - "sys.master_files"
  - "DATABASEPROPERTYEX"
  - "tempdb temporary tables"
safety:
  level: "read-only"
  writes_data: false
documentation:
  markdown_file: "T-SQL/20_Create_Database/SQLScripts/ModelDatabaseOptionSnapshot.md"
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
    date: "2026-04-18"
    user: "ER"
    description: "Erstversion fuer Baseline-Snapshot der model-Datenbankoptionen"
notes:
  - "Das Skript aendert keine Datenbankoptionen und dient nur als Vergleichs- und Lernhilfe."
  - "Standardziel ist model, damit neue CREATE DATABASE-Szenarien auf ihre geerbten Defaults vorbereitet werden koennen."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @DatabaseName SYSNAME = N'model';
DECLARE @IncludeFileLayout BIT = 1;

IF DB_ID(@DatabaseName) IS NULL
BEGIN
    THROW 50000, '@DatabaseName verweist auf keine vorhandene Datenbank.', 1;
END;

IF @IncludeFileLayout NOT IN (0, 1)
BEGIN
    THROW 50001, '@IncludeFileLayout muss 0 oder 1 sein.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.databases AS d
    WHERE d.name = @DatabaseName
      AND d.state_desc = 'ONLINE'
)
BEGIN
    THROW 50002, 'Die gewaehlte Datenbank muss ONLINE sein.', 1;
END;

IF OBJECT_ID('tempdb..#DatabaseOptionSnapshot') IS NOT NULL
BEGIN
    DROP TABLE #DatabaseOptionSnapshot;
END;

CREATE TABLE #DatabaseOptionSnapshot
(
    SnapshotScope NVARCHAR(50) NOT NULL,
    DatabaseName SYSNAME NOT NULL,
    OwnerName SYSNAME NULL,
    CollationName SYSNAME NULL,
    CompatibilityLevel INT NULL,
    RecoveryModel NVARCHAR(60) NULL,
    UserAccess NVARCHAR(60) NULL,
    Containment NVARCHAR(60) NULL,
    PageVerify NVARCHAR(60) NULL,
    SnapshotIsolationState NVARCHAR(60) NULL,
    IsReadCommittedSnapshotOn BIT NULL,
    IsAutoCloseOn BIT NULL,
    IsAutoShrinkOn BIT NULL,
    IsAutoCreateStatsOn BIT NULL,
    IsAutoUpdateStatsOn BIT NULL,
    IsAutoUpdateStatsAsyncOn BIT NULL,
    IsAnsiNullDefaultOn BIT NULL,
    IsAnsiNullsOn BIT NULL,
    IsAnsiPaddingOn BIT NULL,
    IsAnsiWarningsOn BIT NULL,
    IsArithmeticAbortOn BIT NULL,
    IsQuotedIdentifierOn BIT NULL,
    IsRecursiveTriggersOn BIT NULL,
    IsBrokerEnabled BIT NULL,
    IsParameterizationForced BIT NULL,
    IsHonorBrokerPriorityOn BIT NULL,
    CreateDate DATETIME NULL
);

INSERT INTO #DatabaseOptionSnapshot
(
    SnapshotScope,
    DatabaseName,
    OwnerName,
    CollationName,
    CompatibilityLevel,
    RecoveryModel,
    UserAccess,
    Containment,
    PageVerify,
    SnapshotIsolationState,
    IsReadCommittedSnapshotOn,
    IsAutoCloseOn,
    IsAutoShrinkOn,
    IsAutoCreateStatsOn,
    IsAutoUpdateStatsOn,
    IsAutoUpdateStatsAsyncOn,
    IsAnsiNullDefaultOn,
    IsAnsiNullsOn,
    IsAnsiPaddingOn,
    IsAnsiWarningsOn,
    IsArithmeticAbortOn,
    IsQuotedIdentifierOn,
    IsRecursiveTriggersOn,
    IsBrokerEnabled,
    IsParameterizationForced,
    IsHonorBrokerPriorityOn,
    CreateDate
)
SELECT
    CASE
        WHEN d.name = N'model' THEN N'model-baseline'
        ELSE N'custom-database'
    END AS SnapshotScope,
    d.name AS DatabaseName,
    SUSER_SNAME(d.owner_sid) AS OwnerName,
    CAST(DATABASEPROPERTYEX(d.name, 'Collation') AS SYSNAME) AS CollationName,
    d.compatibility_level AS CompatibilityLevel,
    d.recovery_model_desc AS RecoveryModel,
    d.user_access_desc AS UserAccess,
    d.containment_desc AS Containment,
    d.page_verify_option_desc AS PageVerify,
    d.snapshot_isolation_state_desc AS SnapshotIsolationState,
    CAST(d.is_read_committed_snapshot_on AS BIT) AS IsReadCommittedSnapshotOn,
    CAST(d.is_auto_close_on AS BIT) AS IsAutoCloseOn,
    CAST(d.is_auto_shrink_on AS BIT) AS IsAutoShrinkOn,
    CAST(d.is_auto_create_stats_on AS BIT) AS IsAutoCreateStatsOn,
    CAST(d.is_auto_update_stats_on AS BIT) AS IsAutoUpdateStatsOn,
    CAST(d.is_auto_update_stats_async_on AS BIT) AS IsAutoUpdateStatsAsyncOn,
    CAST(d.is_ansi_null_default_on AS BIT) AS IsAnsiNullDefaultOn,
    CAST(d.is_ansi_nulls_on AS BIT) AS IsAnsiNullsOn,
    CAST(d.is_ansi_padding_on AS BIT) AS IsAnsiPaddingOn,
    CAST(d.is_ansi_warnings_on AS BIT) AS IsAnsiWarningsOn,
    CAST(d.is_arithabort_on AS BIT) AS IsArithmeticAbortOn,
    CAST(d.is_quoted_identifier_on AS BIT) AS IsQuotedIdentifierOn,
    CAST(d.is_recursive_triggers_on AS BIT) AS IsRecursiveTriggersOn,
    CAST(d.is_broker_enabled AS BIT) AS IsBrokerEnabled,
    CAST(d.is_parameterization_forced AS BIT) AS IsParameterizationForced,
    CAST(d.is_honor_broker_priority_on AS BIT) AS IsHonorBrokerPriorityOn,
    d.create_date AS CreateDate
FROM sys.databases AS d
WHERE d.name = @DatabaseName;

SELECT
    dos.SnapshotScope,
    dos.DatabaseName,
    dos.OwnerName,
    dos.CollationName,
    dos.CompatibilityLevel,
    dos.RecoveryModel,
    dos.UserAccess,
    dos.Containment,
    dos.PageVerify,
    dos.SnapshotIsolationState,
    dos.IsReadCommittedSnapshotOn,
    dos.IsAutoCloseOn,
    dos.IsAutoShrinkOn,
    dos.IsAutoCreateStatsOn,
    dos.IsAutoUpdateStatsOn,
    dos.IsAutoUpdateStatsAsyncOn,
    dos.IsAnsiNullDefaultOn,
    dos.IsAnsiNullsOn,
    dos.IsAnsiPaddingOn,
    dos.IsAnsiWarningsOn,
    dos.IsArithmeticAbortOn,
    dos.IsQuotedIdentifierOn,
    dos.IsRecursiveTriggersOn,
    dos.IsBrokerEnabled,
    dos.IsParameterizationForced,
    dos.IsHonorBrokerPriorityOn,
    dos.CreateDate
FROM #DatabaseOptionSnapshot AS dos;

IF @IncludeFileLayout = 1
BEGIN
    SELECT
        DB_NAME(mf.database_id) AS DatabaseName,
        mf.file_id AS FileId,
        mf.type_desc AS FileType,
        mf.name AS LogicalFileName,
        mf.physical_name AS PhysicalFileName,
        CAST(mf.size / 128.0 AS DECIMAL(18,2)) AS CurrentSizeMB,
        CASE
            WHEN mf.max_size = -1 THEN N'UNLIMITED'
            ELSE CONVERT(NVARCHAR(30), CAST(mf.max_size / 128.0 AS DECIMAL(18,2)))
        END AS MaxSizeMB,
        CASE
            WHEN mf.is_percent_growth = 1 THEN CONCAT(CONVERT(NVARCHAR(20), mf.growth), N'%')
            ELSE CONCAT(CONVERT(NVARCHAR(30), CAST(mf.growth / 128.0 AS DECIMAL(18,2))), N' MB')
        END AS GrowthSetting,
        mf.state_desc AS FileState,
        mf.is_percent_growth AS IsPercentGrowth
    FROM sys.master_files AS mf
    WHERE mf.database_id = DB_ID(@DatabaseName)
    ORDER BY
        CASE mf.type_desc WHEN 'ROWS' THEN 1 ELSE 2 END,
        mf.file_id;
END;

