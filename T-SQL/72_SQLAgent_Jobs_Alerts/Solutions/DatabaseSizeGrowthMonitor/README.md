# DatabaseSizeGrowthMonitor

Die Loesung protokolliert einmal taeglich die Groesse aller erreichbaren
Benutzerdatenbanken und darunter die Groesse jeder Tabelle. Damit laesst sich
zwischen zwei Snapshots erkennen, welche Datenbank oder Tabelle am staerksten
gewachsen ist.

## Ablage und Schema

- Ordner: `T-SQL/72_SQLAgent_Jobs_Alerts/Solutions/DatabaseSizeGrowthMonitor`
- Schema im Zielsystem: `size_monitoring`
- Typischer Zielort: eine zentrale DBA- oder Admin-Datenbank, nicht jede einzelne Fach-Datenbank

## Enthaltene Skripte

| Skript | Zweck |
|---|---|
| `Install_DatabaseSizeGrowthMonitor.sql` | Legt Schema, Tabellen, Prozeduren, Indizes und optional den SQL-Agent-Job an. |
| `Report_TableGrowthBetweenSnapshots.sql` | Vergleicht die beiden neuesten Snapshots oder explizit angegebene SnapshotRunIds. |
| `Uninstall_DatabaseSizeGrowthMonitor.sql` | Loescht optional den Job und nur nach Freigabe auch Monitoring-Objekte und Historie. |

## Installation

1. In der gewuenschten DBA-/Admin-Datenbank ausfuehren.
2. Im Installationsskript bei Bedarf diese Variablen im letzten Batch anpassen:
   - `@CreateSqlAgentJob`: `1` legt den SQL-Agent-Job an.
   - `@RunTimeHHMMSS`: Startzeit des taeglichen Jobs im Format `HHMMSS`, Standard `20000` fuer 02:00:00.
   - `@IncludeSystemDatabases`: `1` erfasst auch Systemdatenbanken.
   - `@SnapshotRetentionDays`: Historienaufbewahrung in Tagen.
3. Das Skript mit einem `GO`-faehigen Tool ausfuehren, z. B. SSMS, Azure Data Studio oder `sqlcmd`.

Der Job heisst standardmaessig:

```sql
DatabaseSizeGrowthMonitor - Daily Snapshot
```

## Manuelle Ausfuehrung

```sql
EXEC size_monitoring.CaptureDatabaseSizeSnapshot
    @IncludeSystemDatabases = 0,
    @SnapshotRetentionDays = 400;
```

## Wachstum auswerten

Die bequemste Variante ist das Report-Skript:

```sql
:r .\Report_TableGrowthBetweenSnapshots.sql
```

Oder direkt per Prozedur:

```sql
EXEC size_monitoring.ReportDatabaseGrowthBetweenSnapshots
    @FromSnapshotRunId = NULL,
    @ToSnapshotRunId = NULL,
    @DatabaseName = NULL,
    @TopN = 50;

EXEC size_monitoring.ReportTableGrowthBetweenSnapshots
    @FromSnapshotRunId = NULL,
    @ToSnapshotRunId = NULL,
    @DatabaseName = NULL,
    @TopN = 50;
```

Wenn `@FromSnapshotRunId` und `@ToSnapshotRunId` `NULL` sind, werden automatisch
die beiden neuesten erfolgreichen Snapshot-Laeufe verglichen.

## Wichtige Objekte

| Objekt | Inhalt |
|---|---|
| `size_monitoring.SnapshotRun` | Ein Lauf pro Snapshot inklusive Status und Fehlerstatus. |
| `size_monitoring.DatabaseSizeSnapshot` | Aggregierte Groesse je Datenbank. |
| `size_monitoring.DatabaseFileSizeSnapshot` | Groesse je Datenbankdatei inklusive physischem Pfad. |
| `size_monitoring.TableSizeSnapshot` | Groesse je Tabelle inklusive RowCount, DataMB, IndexMB und UnusedMB. |
| `size_monitoring.CaptureError` | Nicht-fatale Capture-Fehler je Datenbank und Phase. |

## Berechtigungen

Fuer die vollstaendige Erfassung sind ausreichende Leserechte auf die
Benutzerdatenbanken sowie Sichtbarkeit der relevanten DMVs notwendig. Das
Anlegen oder Aktualisieren des SQL-Agent-Jobs benoetigt passende Rechte in
`msdb`, in der Praxis haeufig `sysadmin` oder eine sauber delegierte
Agent-Administration.

## Hinweise zur Interpretation

- Datenbankgroessen basieren auf allokierten Dateien.
- `DataUsedMB` und `DataFreeMB` werden aus Datenbankdateien berechnet.
- `LogUsedMB` und `LogUsedPct` kommen aus `sys.dm_db_log_space_usage`.
- Tabellenwachstum basiert auf `sys.dm_db_partition_stats`; Umbenennungen werden als `dropped` und `new` sichtbar.
