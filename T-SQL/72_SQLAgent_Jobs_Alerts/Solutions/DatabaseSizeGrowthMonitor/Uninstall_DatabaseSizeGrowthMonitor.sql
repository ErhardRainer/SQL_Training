/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "Uninstall_DatabaseSizeGrowthMonitor.sql"
script_version: "1.0"
script_type: "solution-uninstall"
chapter: "72_SQLAgent_Jobs_Alerts"
purpose: >
  Entfernt optional den SQL-Agent-Job und bei ausdruecklicher Freigabe
  auch die Monitoring-Objekte der DatabaseSizeGrowthMonitor-Loesung.

parameters:
  - name: "@DropSqlAgentJob"
    description: "1 = SQL-Agent-Job loeschen"
  - name: "@DropMonitoringObjects"
    description: "1 = Schemaobjekte und gespeicherte Historie loeschen"

result_sets: []

dependencies:
  - "msdb.dbo.sp_delete_job"
  - "size_monitoring"

safety:
  level: "destructive-optional"
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
    description: "Erstversion des vorsichtigen Uninstall-Skripts"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE
    @DropSqlAgentJob BIT = 1,
    @DropMonitoringObjects BIT = 0,
    @JobName SYSNAME = N'DatabaseSizeGrowthMonitor - Daily Snapshot';

IF @DropSqlAgentJob = 1
   AND EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = @JobName)
BEGIN
    EXEC msdb.dbo.sp_delete_job
        @job_name = @JobName,
        @delete_unused_schedule = 1;
END;

IF @DropMonitoringObjects = 1
BEGIN
    DROP PROCEDURE IF EXISTS size_monitoring.ReportDatabaseGrowthBetweenSnapshots;
    DROP PROCEDURE IF EXISTS size_monitoring.ReportTableGrowthBetweenSnapshots;
    DROP PROCEDURE IF EXISTS size_monitoring.CaptureDatabaseSizeSnapshot;

    DROP TABLE IF EXISTS size_monitoring.CaptureError;
    DROP TABLE IF EXISTS size_monitoring.TableSizeSnapshot;
    DROP TABLE IF EXISTS size_monitoring.DatabaseFileSizeSnapshot;
    DROP TABLE IF EXISTS size_monitoring.DatabaseSizeSnapshot;
    DROP TABLE IF EXISTS size_monitoring.SnapshotRun;

    IF SCHEMA_ID(N'size_monitoring') IS NOT NULL
       AND NOT EXISTS
       (
           SELECT 1
           FROM sys.objects
           WHERE schema_id = SCHEMA_ID(N'size_monitoring')
       )
    BEGIN
        DROP SCHEMA size_monitoring;
    END;
END
ELSE
BEGIN
    PRINT 'Monitoring-Objekte und Historie bleiben erhalten. Setze @DropMonitoringObjects = 1, um sie zu loeschen.';
END;
