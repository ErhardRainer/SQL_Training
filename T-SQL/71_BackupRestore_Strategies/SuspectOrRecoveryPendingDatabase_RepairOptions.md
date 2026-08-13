# SUSPECT- oder RECOVERY_PENDING-Datenbank reparieren: Vollstaendiger Restore, Page Restore oder Datenverlust in Kauf nehmen

Dieses Dokument beschreibt ausfuehrlich, welche Optionen bestehen, wenn eine Datenbank durch Seitenkorruption (`msdb.dbo.suspect_pages`, i.d.R. Fehler **823/824**) in den Status **SUSPECT** oder **RECOVERY_PENDING** geraten ist, und zeigt konkrete T-SQL-Befehle am Beispiel einer Datenbank namens **`BI_DQ`**.

Hintergrund und Diagnose siehe:
- [SQL_Crash-Recovery_Startup.ipynb](SQL_Crash-Recovery_Startup.ipynb) — was `RECOVERING`, `RECOVERY_PENDING` und `SUSPECT` bedeuten
- [SQLScripts/DatabaseStatusOverview.sql](SQLScripts/DatabaseStatusOverview.sql) — Status aller Datenbanken auf einen Blick
- [SQLScripts/SuspectOrRecoveryPendingDatabaseRootCauseCheck.sql](SQLScripts/SuspectOrRecoveryPendingDatabaseRootCauseCheck.sql) — automatische Ursachenanalyse (Dateizugriff, Speicherplatz, Suspect Pages, Errorlog)
- [SSMS_GenerateScripts_Anleitung.md](SSMS_GenerateScripts_Anleitung.md) — der alternative, GUI-basierte Weg über SSMS "Generate Scripts", inkl. seiner eigenen Möglichkeiten und Einschränkungen (funktioniert nur bei online lesbarer Datenbank)
- [SuspectOrRecoveryPendingDatabase_VMDiskLevelRestore.md](SuspectOrRecoveryPendingDatabase_VMDiskLevelRestore.md) — vierte Option, falls kein SQL-natives Backup, aber ein komplettes VM-/Disk-Backup existiert: alte, unbeschädigte Datenbankdateien direkt aus dem VM-Backup zurückkopieren

> **Wichtiger Grundsatz:** Ohne ein brauchbares Backup gibt es **keine echte Wiederherstellung** korrupter Seiten — nur die Möglichkeit, die Datenbank durch das Entfernen der beschädigten Daten wieder konsistent (aber unvollständig) zu machen. Alle Befehle unten sind vor der Ausführung an die tatsächliche Umgebung anzupassen (Pfade, Backup-Dateinamen, Dateigrößen) und sollten, wo möglich, zuerst gegen eine Kopie/einen Test-Restore geprüft werden.

---

## 1 | Ausgangslage: Wie erkennt man die betroffenen Seiten?

```sql
-- Betroffene Seiten der Datenbank BI_DQ ermitteln
SELECT
    database_id,
    DB_NAME(database_id) AS DatabaseName,
    file_id,
    page_id,
    event_type,
    error_count,
    last_update_date
FROM msdb.dbo.suspect_pages
WHERE database_id = DB_ID(N'BI_DQ')
ORDER BY last_update_date DESC;
```

Zusätzlich lohnt sich ein `DBCC CHECKDB` (rein lesend, ohne Reparaturoption), um den vollen Umfang der Beschädigung zu sehen, **bevor** eine Entscheidung getroffen wird:

```sql
DBCC CHECKDB (N'BI_DQ') WITH NO_INFOMSGS, ALL_ERRORMSGS;
```

Je nach Ergebnis (Anzahl betroffener Seiten, betroffene Objekte/Indizes, Systemtabellen vs. Benutzerdaten) ergeben sich die drei folgenden Optionen.

---

## 2 | Option 1: Vollständiger Restore der kompletten Datenbank

**Wann sinnvoll:** Wenn ein aktuelles, valides Backup existiert und eine kurze Downtime akzeptabel ist. Dies ist die **sicherste** Option, da die gesamte Datenbank konsistent aus dem Backup wiederhergestellt wird — es bleibt kein Restrisiko einzelner, nicht erkannter Folgeschäden.

**Voraussetzung:** Ein Full-Backup, optional gefolgt von Differential-Backup(s), optional gefolgt von Transaction-Log-Backups (bei `FULL`/`BULK_LOGGED` Recovery Model) bis zum gewünschten Wiederherstellungszeitpunkt.

### 2.1 Tail-Log-Backup sichern (falls die Datenbank noch teilweise zugreifbar ist)

Bevor restored wird, sollte — sofern möglich — der aktuelle Log-Stand gesichert werden, um keine Transaktionen seit dem letzten Backup zu verlieren:

```sql
BACKUP LOG [BI_DQ]
TO DISK = N'D:\Backup\BI_DQ_TailLog.trn'
WITH NORECOVERY, NO_TRUNCATE, INIT;
```

> `NO_TRUNCATE` erlaubt das Sichern des Logs auch bei einer beschädigten Datenbank; `NORECOVERY` versetzt die Datenbank direkt in den Restoring-Zustand, damit die folgende Restore-Kette nahtlos anschließt.

### 2.2 Restore-Kette einspielen

```sql
-- 1. Full-Backup einspielen (NORECOVERY, da weitere Backups folgen)
RESTORE DATABASE [BI_DQ]
FROM DISK = N'D:\Backup\BI_DQ_Full.bak'
WITH NORECOVERY, REPLACE, STATS = 10;

-- 2. Optional: letztes Differential-Backup einspielen
RESTORE DATABASE [BI_DQ]
FROM DISK = N'D:\Backup\BI_DQ_Diff.bak'
WITH NORECOVERY, STATS = 10;

-- 3. Alle Transaction-Log-Backups seit dem Full/Diff-Backup in chronologischer Reihenfolge einspielen
RESTORE LOG [BI_DQ]
FROM DISK = N'D:\Backup\BI_DQ_Log_01.trn'
WITH NORECOVERY, STATS = 10;

RESTORE LOG [BI_DQ]
FROM DISK = N'D:\Backup\BI_DQ_Log_02.trn'
WITH NORECOVERY, STATS = 10;

-- 4. Zuletzt den zuvor gesicherten Tail-Log-Backup einspielen (falls unter 2.1 erstellt)
RESTORE LOG [BI_DQ]
FROM DISK = N'D:\Backup\BI_DQ_TailLog.trn'
WITH NORECOVERY, STATS = 10;

-- 5. Datenbank abschliessend online schalten
RESTORE DATABASE [BI_DQ] WITH RECOVERY;
```

Alternativ, für einen Restore bis zu einem bestimmten Zeitpunkt **vor** dem Korruptionsereignis (Point-in-Time Restore):

```sql
RESTORE LOG [BI_DQ]
FROM DISK = N'D:\Backup\BI_DQ_Log_02.trn'
WITH RECOVERY, STOPAT = '2026-08-13 08:00:00';
```

### 2.3 Ergebnis prüfen

```sql
SELECT name, state_desc, recovery_model_desc
FROM sys.databases
WHERE name = N'BI_DQ';

DBCC CHECKDB (N'BI_DQ') WITH NO_INFOMSGS, ALL_ERRORMSGS;
```

---

## 3 | Option 2: Page Restore — nur die betroffenen Seiten aus dem Backup wiederherstellen

**Wann sinnvoll:** Wenn nur wenige, klar identifizierte Seiten betroffen sind (siehe `msdb.dbo.suspect_pages`) und eine möglichst kurze Downtime gewünscht ist — die restliche Datenbank bleibt (in Enterprise Edition sogar online) verfügbar.

**Voraussetzung (zwingend):**
- Recovery Model `FULL` oder `BULK_LOGGED` (in `SIMPLE` ist Page Restore nicht möglich)
- Ein Full-Backup (und ggf. Differential-Backup), das die betroffene Seite **unbeschädigt** enthält
- Eine **lückenlose Transaction-Log-Kette** vom verwendeten Backup bis zur aktuellen Zeit
- Standard Edition: Die Datenbank muss während des Page Restores **offline** sein (kein gleichzeitiger Zugriff); Enterprise Edition erlaubt Online Page Restore für Benutzerdatenbanken (mit Einschränkungen für die betroffenen Seiten selbst)

### 3.1 Betroffene Seiten ermitteln

```sql
SELECT DISTINCT file_id, page_id
FROM msdb.dbo.suspect_pages
WHERE database_id = DB_ID(N'BI_DQ')
  AND event_type IN (1, 2, 3); -- 1/2/3 = tatsaechliche Korruption, nicht bereits reparierte Eintraege
```

Angenommen, das Ergebnis liefert `file_id = 1, page_id = 24539136` (siehe Praxisbeispiel im [Diagnose-Skript](SQLScripts/SuspectOrRecoveryPendingDatabaseRootCauseCheck.md)).

### 3.2 Tail-Log-Backup sichern

Wie bei Option 1 — auch beim Page Restore wird zuletzt der aktuelle Log-Stand benötigt:

```sql
BACKUP LOG [BI_DQ]
TO DISK = N'D:\Backup\BI_DQ_TailLog.trn'
WITH NORECOVERY, NO_TRUNCATE, INIT;
```

### 3.3 Page Restore durchführen

```sql
-- 1. Die konkrete(n) Seite(n) aus dem Full-Backup restoren (Syntax: FileID:PageID)
RESTORE DATABASE [BI_DQ]
PAGE = '1:24539136'
FROM DISK = N'D:\Backup\BI_DQ_Full.bak'
WITH NORECOVERY, STATS = 10;

-- 2. Falls vorhanden: Differential-Backup einspielen
RESTORE DATABASE [BI_DQ]
PAGE = '1:24539136'
FROM DISK = N'D:\Backup\BI_DQ_Diff.bak'
WITH NORECOVERY, STATS = 10;

-- 3. Alle Log-Backups seit dem verwendeten Full/Diff-Backup nachziehen
RESTORE LOG [BI_DQ]
FROM DISK = N'D:\Backup\BI_DQ_Log_01.trn'
WITH NORECOVERY, STATS = 10;

RESTORE LOG [BI_DQ]
FROM DISK = N'D:\Backup\BI_DQ_Log_02.trn'
WITH NORECOVERY, STATS = 10;

-- 4. Zuletzt den Tail-Log-Backup aus Schritt 3.2 einspielen
RESTORE LOG [BI_DQ]
FROM DISK = N'D:\Backup\BI_DQ_TailLog.trn'
WITH RECOVERY, STATS = 10;
```

> Mehrere betroffene Seiten koennen in einem einzigen `RESTORE DATABASE ... PAGE = '1:100, 1:101, 3:55'`-Befehl kombiniert werden (kommagetrennte Liste `FileID:PageID`).

### 3.4 Ergebnis prüfen

```sql
DBCC CHECKDB (N'BI_DQ') WITH NO_INFOMSGS, ALL_ERRORMSGS;

SELECT * FROM msdb.dbo.suspect_pages WHERE database_id = DB_ID(N'BI_DQ');
```

Erfolgreich reparierte Seiten erscheinen in `suspect_pages` mit `event_type = 7` ("Restored"). Diese Einträge können danach bei Bedarf bereinigt werden:

```sql
DELETE FROM msdb.dbo.suspect_pages
WHERE database_id = DB_ID(N'BI_DQ') AND event_type = 7;
```

---

## 4 | Option 3: Ohne brauchbares Backup — Datenverlust in Kauf nehmen

**Wann notwendig:** Wenn kein Backup existiert, das die betroffene(n) Seite(n) unbeschädigt enthält, oder die Log-Kette zum Nachziehen fehlt. Dies ist ein **Notnagel**, keine Wiederherstellung — betroffene Daten gehen dabei tatsächlich und endgültig verloren.

> Für diese Option gibt es ein eigenständiges, wiederverwendbares Skript mit expliziter Sicherheitsabfrage: [SQLScripts/SuspectDatabaseRepairWithoutBackup.sql](SQLScripts/SuspectDatabaseRepairWithoutBackup.sql) (Doku: [SQLScripts/SuspectDatabaseRepairWithoutBackup.md](SQLScripts/SuspectDatabaseRepairWithoutBackup.md)). Es führt den destruktiven `REPAIR_ALLOW_DATA_LOSS`-Schritt nur aus, wenn der Parameter `@ConfirmDataLoss` explizit auf `1` gesetzt wird; ansonsten läuft nur ein lesender Vorab-Check.

### 4.1 Datenbank in den Notfallmodus versetzen

```sql
ALTER DATABASE [BI_DQ] SET EMERGENCY;
ALTER DATABASE [BI_DQ] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
```

### 4.2 Umfang der Beschädigung final prüfen

```sql
DBCC CHECKDB (N'BI_DQ') WITH NO_INFOMSGS, ALL_ERRORMSGS;
```

Die Ausgabe zeigt am Ende die empfohlene minimale Reparaturstufe (z.B. `repair_rebuild` oder `repair_allow_data_loss`). **Nur** wenn `REPAIR_ALLOW_DATA_LOSS` tatsächlich erforderlich ist (nicht schon `REPAIR_REBUILD` ausreicht), fortfahren:

### 4.3 Reparatur mit Datenverlust durchführen

```sql
DBCC CHECKDB (N'BI_DQ', REPAIR_ALLOW_DATA_LOSS) WITH NO_INFOMSGS, ALL_ERRORMSGS;
```

> Dieser Befehl kann Seiten, Zeilen oder ganze Index-/Tabellenstrukturen entfernen, um Konsistenz wiederherzustellen. Es gibt **keine Möglichkeit**, die entfernten Daten anschließend zurückzuholen, außer aus einem (dann doch noch gefundenen) Backup.

### 4.4 Datenbank wieder normal nutzbar machen

```sql
ALTER DATABASE [BI_DQ] SET MULTI_USER;
```

### 4.5 Nacharbeiten

- `DBCC CHECKDB` erneut ausführen, um zu bestätigen, dass keine weiteren Fehler bestehen.
- Betroffene Tabellen/Bereiche identifizieren (aus der `DBCC CHECKDB`-Ausgabe) und fachlich prüfen, welche Daten fehlen.
- Wo möglich, fehlende Daten aus anderen Quellen (ETL-Historie, Quellsystem, Replikation, älteres Backup) nachträglich neu laden.
- **Sofort danach** ein frisches Full-Backup ziehen, um den aktuellen (bereinigten) Zustand zu sichern:

```sql
BACKUP DATABASE [BI_DQ]
TO DISK = N'D:\Backup\BI_DQ_PostRepair_Full.bak'
WITH INIT, COMPRESSION, STATS = 10;
```

### 4.6 Wenn selbst `REPAIR_ALLOW_DATA_LOSS` scheitert

Bei sehr großflächiger Storage-Korruption kann `DBCC CHECKDB ... REPAIR_ALLOW_DATA_LOSS` die Datenbank nicht mehr in einen konsistenten Zustand bringen. SQL Server meldet das explizit:

```text
CHECKDB found 294 allocation errors and 136381 consistency errors in database 'BI_DQ'.
Msg 7909, Level 20, State 1
The emergency-mode repair failed. You must restore from backup.
```

In diesem Fall ist die Datenbank praktisch verloren — typischerweise, weil die zugrunde liegende Datendatei auf Storage-Ebene grossflächig beschädigt ist (nicht nur einzelne Seiten). Die Datenbank fällt danach wieder in den Status `SUSPECT` zurück und ist nicht mehr zugänglich (`Msg 926`).

**Letzter Rettungsversuch — nur das Schema retten:** Wenn wenigstens die Objektstruktur (Tabellen, Views, Stored Procedures, Functions, Trigger, Constraints, Indizes) erhalten werden soll, gibt es dafür ein eigenständiges Skript, das die Datenbank **nur** in `EMERGENCY`/`READ_ONLY` versetzt (ohne weiteren Reparaturversuch) und versucht, alle `CREATE`-Definitionen über die Systemkataloge auszulesen: [SQLScripts/SuspectDatabaseScriptSchemaOnly.sql](SQLScripts/SuspectDatabaseScriptSchemaOnly.sql) (Doku: [SQLScripts/SuspectDatabaseScriptSchemaOnly.md](SQLScripts/SuspectDatabaseScriptSchemaOnly.md)). Ob dies gelingt, hängt davon ab, ob die Metadaten-Seiten selbst zu den beschädigten Bereichen gehören. Gelingt die Extraktion, kann die Datenbank anschließend verworfen und aus dem geretteten Schema leer neu aufgebaut werden.

**Wichtig:** Die reine Ergebnistabelle aus `SuspectDatabaseScriptSchemaOnly.sql` ist noch **kein** direkt ausführbares Skript (es fehlen `CREATE DATABASE`/`USE` und `GO`-Trenner). Um daraus eine tatsächlich lauffähige `.sql`-Datei zu erzeugen, direkt im Anschluss (in derselben Session) [SQLScripts/AssembleExecutableCreateScript.sql](SQLScripts/AssembleExecutableCreateScript.sql) (Doku: [SQLScripts/AssembleExecutableCreateScript.md](SQLScripts/AssembleExecutableCreateScript.md)) ausführen.

**Alternative — Schema stattdessen per SSMS Generate Scripts sichern:** Wird eine vollständigere Extraktion benötigt (inkl. Users, Berechtigungen, SQL Assemblies, User-Defined Types — das leistet `SuspectDatabaseScriptSchemaOnly.sql` nicht), kann statt der eigenen T-SQL-Extraktion auch **SSMS "Generate Scripts"** (bzw. eine seiner programmatischen Alternativen wie SMO/PowerShell, `dbatools` oder `mssql-scripter`, siehe [SSMS_GenerateScripts_Anleitung.md](SSMS_GenerateScripts_Anleitung.md) Abschnitt 7) verwendet werden. Dafür die Datenbank zunächst per [SQLScripts/DatabaseEmergencyReadOnlyForGenerateScripts.sql](SQLScripts/DatabaseEmergencyReadOnlyForGenerateScripts.sql) (Doku: [SQLScripts/DatabaseEmergencyReadOnlyForGenerateScripts.md](SQLScripts/DatabaseEmergencyReadOnlyForGenerateScripts.md)) nur nach `EMERGENCY`/`READ_ONLY` versetzen (ohne eigene Extraktion) und anschließend Generate Scripts gegen die dann lesbare Datenbank ausführen. Bricht Generate Scripts/SMO wegen beschädigter Metadaten ab, bleibt `SuspectDatabaseScriptSchemaOnly.sql` mit seiner objektweisen `TRY/CATCH`-Fehlertoleranz der robustere Fallback.

**Datenbank danach vollständig entfernen:** Ist die Datenbank irreparabel und (falls gewünscht) das Schema bereits gesichert, kann sie inklusive aller physischen Dateien vollständig entfernt werden: [SQLScripts/DropDatabaseCompletely.sql](SQLScripts/DropDatabaseCompletely.sql) (Doku: [SQLScripts/DropDatabaseCompletely.md](SQLScripts/DropDatabaseCompletely.md)). Das Skript killt aktive Verbindungen, führt `DROP DATABASE` aus und entfernt über einen `xp_cmdshell`-Fallback auch Dateien, die nach dem Drop noch am Dateisystem verblieben sind (typisch bei zuvor `SUSPECT`/`EMERGENCY`-Datenbanken).

---

## 5 | Entscheidungshilfe: Welche Option wählen?

| Kriterium | Option 1: Vollständiger Restore | Option 2: Page Restore | Option 3a: VM-/Disk-Level-Restore | Option 3b: Repair mit Datenverlust |
|---|---|---|---|---|
| Voraussetzung | Beliebiges gültiges SQL-natives Backup | Full-Backup + lückenlose Log-Kette, Recovery Model FULL/BULK_LOGGED | Komplettes VM-/Disk-/Storage-Backup, das älter als das Korruptionsereignis ist | Keine (funktioniert immer, aber mit Verlust) |
| Datenverlust | Nein (bis zum Backup-/Log-Zeitpunkt) | Nein (bis zum Log-Zeitpunkt) | Transaktionen seit dem VM-Backup-Zeitpunkt (kein Tail-Log möglich) | Ja, dauerhaft |
| Downtime | Gesamte DB für die Dauer des Restores | Nur die betroffene(n) Seite(n)/Datei; Rest ggf. weiter nutzbar (Enterprise Edition) | Abhängig vom Disk-Mount-/Kopiervorgang | Kurz, aber Datenintegrität nicht mehr vollständig |
| Empfehlung | Bevorzugen, wenn Zeit/SQL-Backup vorhanden | Bevorzugen bei wenigen betroffenen Seiten und großer DB | Wenn kein SQL-natives Backup, aber ein VM-/Snapshot-Backup existiert — siehe [SuspectOrRecoveryPendingDatabase_VMDiskLevelRestore.md](SuspectOrRecoveryPendingDatabase_VMDiskLevelRestore.md) | Nur letztes Mittel, wenn 1, 2 und 3a nicht möglich sind |

**Grundsatz:** Immer zuerst prüfen, ob Option 1 oder 2 machbar ist (`RESTORE HEADERONLY` / `RESTORE VERIFYONLY` gegen die vorhandenen Backup-Dateien, Log-Kette per `msdb.dbo.backupset`/`backupfile` verifizieren). Existiert kein SQL-natives Backup, aber ein vollständiges VM-/Disk-Backup, ist Option 3a (VM-/Disk-Level-Restore) in aller Regel Option 3b (Datenverlust durch `REPAIR_ALLOW_DATA_LOSS`) vorzuziehen, da sie bei anwendungskonsistentem Backup keinen echten Datenverlust der Struktur/Daten bedeutet — nur eine zeitliche Rückstufung auf den Snapshot-Zeitpunkt.

```sql
-- Backup-Historie und Log-Kette fuer BI_DQ pruefen
SELECT
    bs.database_name,
    bs.type, -- D=Full, I=Differential, L=Log
    bs.backup_start_date,
    bs.backup_finish_date,
    bs.first_lsn,
    bs.last_lsn,
    bmf.physical_device_name
FROM msdb.dbo.backupset AS bs
JOIN msdb.dbo.backupmediafamily AS bmf
    ON bs.media_set_id = bmf.media_set_id
WHERE bs.database_name = N'BI_DQ'
ORDER BY bs.backup_start_date DESC;
```

---

## 6 | Weiterführende Informationen

- 📘 Microsoft Learn: [Restore Pages (Page Restore)](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/restore-pages-sql-server)
- 📘 Microsoft Learn: [RESTORE Statements](https://learn.microsoft.com/en-us/sql/t-sql/statements/restore-statements-transact-sql)
- 📘 Microsoft Learn: [DBCC CHECKDB](https://learn.microsoft.com/en-us/sql/t-sql/database-console-commands/dbcc-checkdb-transact-sql)
- 📘 Microsoft Learn: [Tail-Log-Backups](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/tail-log-backups-sql-server)
- 📘 Microsoft Learn: [suspect_pages (Transact-SQL)](https://learn.microsoft.com/en-us/sql/relational-databases/system-tables/msdb-dbo-suspect-pages-transact-sql)
