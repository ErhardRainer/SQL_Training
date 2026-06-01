/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "Report_TableGrowthBetweenSnapshots.sql"
script_version: "1.0"
script_type: "solution-report"
chapter: "72_SQLAgent_Jobs_Alerts"
purpose: >
  Zeigt Datenbank- und Tabellenwachstum zwischen zwei Snapshots der
  DatabaseSizeGrowthMonitor-Loesung. Wenn keine SnapshotRunIds angegeben
  werden, werden automatisch die beiden neuesten erfolgreichen Laeufe
  verglichen.

parameters:
  - name: "@FromSnapshotRunId"
    description: "Start-Snapshot; NULL = vorletzter erfolgreicher Snapshot"
  - name: "@ToSnapshotRunId"
    description: "Ziel-Snapshot; NULL = letzter erfolgreicher Snapshot"
  - name: "@DatabaseName"
    description: "Optionale Einschraenkung auf eine Datenbank"
  - name: "@TopN"
    description: "Anzahl der groessten Wachstumszeilen"

result_sets:
  - name: "DatabaseGrowth"
    description: "Groessenveraenderung je Datenbank"
  - name: "TableGrowth"
    description: "Groessenveraenderung je Tabelle"

dependencies:
  - "size_monitoring.ReportDatabaseGrowthBetweenSnapshots"
  - "size_monitoring.ReportTableGrowthBetweenSnapshots"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/72_SQLAgent_Jobs_Alerts/Solutions/DatabaseSizeGrowthMonitor/README.md"

main_responsible:
  name: "Erhard Rainer"
  initials: "ER"

version_history:
  - version: "1.0"
    date: "2026-05-11"
    user: "ER"
    description: "Erstversion des Growth-Reports"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE
    @FromSnapshotRunId BIGINT = NULL,
    @ToSnapshotRunId BIGINT = NULL,
    @DatabaseName SYSNAME = NULL,
    @TopN INT = 50;

EXEC size_monitoring.ReportDatabaseGrowthBetweenSnapshots
    @FromSnapshotRunId = @FromSnapshotRunId,
    @ToSnapshotRunId = @ToSnapshotRunId,
    @DatabaseName = @DatabaseName,
    @TopN = @TopN;

EXEC size_monitoring.ReportTableGrowthBetweenSnapshots
    @FromSnapshotRunId = @FromSnapshotRunId,
    @ToSnapshotRunId = @ToSnapshotRunId,
    @DatabaseName = @DatabaseName,
    @TopN = @TopN;
