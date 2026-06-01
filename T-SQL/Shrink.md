# Shrink in SQL Server

Dieses Dokument ist die zentrale Uebersicht fuer Shrink-Szenarien in diesem Repository. Es erklaert die Theorie hinter `DBCC SHRINKFILE`, den Unterschied zwischen Datenfile- und Logfile-Shrink, die Relevanz der Recovery Models `SIMPLE`, `FULL` und `BULK_LOGGED`, typische Notfallfragen wie "geht das auch bei 0 Byte freiem Speicherplatz?" und verlinkt die passenden Skripte.

## Kurzfassung

Shrink ist kein normaler Wartungsjob. Shrink ist eine administrative Ausnahmehandlung, wenn eine Datei dauerhaft zu gross geworden ist oder in einer akuten Speicherplatzlage gezielt Platz an das Betriebssystem zurueckgegeben werden muss.

Die wichtigsten Punkte:

- `DBCC SHRINKFILE` verkleinert eine konkrete Datei, nicht die logische Datenbank.
- Datenfile-Shrink verschiebt belegte Daten- und Indexseiten innerhalb der Datei.
- Logfile-Shrink verschiebt keine Logeintraege, sondern kann nur inaktive VLFs am Dateiende abschneiden.
- Das Recovery Model ist fuer Logdateien entscheidend, weil es bestimmt, wodurch Logbereiche wiederverwendbar werden.
- In `SIMPLE` reicht oft ein `CHECKPOINT`, sofern keine andere Ursache die Wiederverwendung blockiert.
- In `FULL` und `BULK_LOGGED` ist ein regulaeres Logbackup zentral, weil es die Logkette erhaelt und inaktive Logbereiche wiederverwendbar macht.
- Ein Wechsel auf `SIMPLE` und danach zurueck auf `FULL` ist technisch moeglich, unterbricht aber die bisherige Log-Backup-Kette und muss fachlich freigegeben sein.
- Bei 0 Byte freiem Speicherplatz auf dem Volume kann Shrink manchmal noch helfen, aber nicht immer. Entscheidend ist, ob SQL Server fuer die konkrete Aktion noch Log schreiben, ggf. ein Logbackup ablegen und interne Seiten bewegen kann.
- Nach einem Datenfile-Shrink sind Fragmentierung, Statistiken und Autogrowth zu pruefen.
- Nach einem Logfile-Shrink sind Logbackup-Takt, VLFs, Zielgroesse und Autogrowth zu pruefen.

## Passende Skripte und Dokumentationen

| Doku | Skript | Einsatzfall | Fuehrt Shrink aus? |
|---|---|---|---|
| [DatabaseShrinkCandidateReview.md](20_Create_Database/SQLScripts/DatabaseShrinkCandidateReview.md) | [DatabaseShrinkCandidateReview.sql](20_Create_Database/SQLScripts/DatabaseShrinkCandidateReview.sql) | Serverweite Analyse eines betroffenen Laufwerks oder Volumes; priorisiert Datenbanken und erzeugt Shrink-Vorlagen. | Nein |
| [DatabaseShrinkAnalysis.md](20_Create_Database/SQLScripts/DatabaseShrinkAnalysis.md) | [DatabaseShrinkAnalysis.sql](20_Create_Database/SQLScripts/DatabaseShrinkAnalysis.sql) | Analyse einer einzelnen Datenbank mit Datenfile-/Logfile-Bewertung, optionalem Volume-Filter und Command-Vorlagen. | Nein |
| [ListLogUsageOfAllDB.md](19_Transaktions/SQLScripts/ListLogUsageOfAllDB.md) | [ListLogUsageOfAllDB.sql](19_Transaktions/SQLScripts/ListLogUsageOfAllDB.sql) | Uebersicht ueber Logdateien, Lognutzung, theoretisches Shrink-Potential und generierte Befehle. | Nein |
| [LogReuseWaitSnapshot.md](19_Transaktions/SQLScripts/LogReuseWaitSnapshot.md) | [LogReuseWaitSnapshot.sql](19_Transaktions/SQLScripts/LogReuseWaitSnapshot.sql) | Diagnose von `log_reuse_wait_desc`, bevor ein Log-Shrink ueberhaupt sinnvoll ist. | Nein |
| [ShrinkSimple.md](19_Transaktions/SQLScripts/ShrinkSimple.md) | [ShrinkSimple.sql](19_Transaktions/SQLScripts/ShrinkSimple.sql) | Shrink von SIMPLE-Datenbanken mit genau einer Logdatei. | Ja |
| [ShrinkSimple_multiple_Files.md](19_Transaktions/SQLScripts/ShrinkSimple_multiple_Files.md) | [ShrinkSimple_multiple_Files.sql](19_Transaktions/SQLScripts/ShrinkSimple_multiple_Files.sql) | Shrink von SIMPLE-Datenbanken mit mehreren Logdateien und VLF-basierten Guardrails. | Ja |
| [ShrinkFullDatabase.md](19_Transaktions/SQLScripts/ShrinkFullDatabase.md) | [ShrinkFullDatabase.sql](19_Transaktions/SQLScripts/ShrinkFullDatabase.sql) | Shrink einer einzelnen FULL- oder BULK_LOGGED-Datenbank ohne Wechsel auf SIMPLE, optional mit regulaerem Logbackup. | Ja, erst mit `@ExecuteShrink = 1` |
| [SetDBSimple.md](19_Transaktions/SQLScripts/SetDBSimple.md) | [SetDBSimple.sql](19_Transaktions/SQLScripts/SetDBSimple.sql) | Sonderfall: Datenbank dauerhaft auf SIMPLE setzen und danach Logdatei shrinken. | Ja |
| [MoveLastActiveVlfOffFileEnd.md](19_Transaktions/SQLScripts/MoveLastActiveVlfOffFileEnd.md) | [MoveLastActiveVlfOffFileEnd.sql](19_Transaktions/SQLScripts/MoveLastActiveVlfOffFileEnd.sql) | Spezialfall: letztes aktives VLF liegt am Dateiende und verhindert Log-Shrink. | Nein, erzeugt aber bewusst Logaktivitaet |
| [usp_LogShrink.sql](71_BackupRestore_Strategies/usp_LogShrink.sql) | [usp_LogShrink.sql](71_BackupRestore_Strategies/usp_LogShrink.sql) | Stored Procedure fuer Log-Shrink mit Backup-Guardrails, Before/After-Messung und Dry-Run. | Ja, wenn nicht im Debug-Modus |
| [Shrink_Database.md](20_Create_Database/Shrink_Database.md) | - | Ergaenzende Theorie und Beispiele zum Datenbank-Shrink. | Nein |

## Begriffe

| Begriff | Bedeutung |
|---|---|
| Datenfile | `.mdf` oder `.ndf`; enthaelt Daten- und Indexseiten. |
| Logfile | `.ldf`; enthaelt Transaktionslog-Datensaetze. |
| Page | Kleinste Daten-I/O-Einheit in SQL Server, 8 KB. |
| Extent | 8 Pages, also 64 KB. |
| Freier Platz in der Datei | Platz innerhalb einer Datenbankdatei, den SQL Server wiederverwenden kann. Dieser Platz ist noch nicht fuer Windows frei. |
| Freier Platz auf dem Volume | Speicherplatz, den das Betriebssystem fuer andere Dateien nutzen kann. Shrink versucht, solchen Platz zurueckzugeben. |
| VLF | Virtual Log File; interner Abschnitt einer Logdatei. Log-Shrink kann nur inaktive VLFs am Dateiende abschneiden. |
| Recovery Model | Datenbankeigenschaft, die Logverhalten, Logbackups und Restore-Moeglichkeiten bestimmt. |
| Log-Trunkierung | Freigabe von nicht mehr benoetigten Logbereichen zur Wiederverwendung innerhalb der Logdatei. |
| Shrink | Physisches Verkleinern einer Datenbankdatei. Trunkierung und Shrink sind nicht dasselbe. |

## Was Shrink wirklich macht

SQL Server verwaltet Datenbanken als Dateien. Diese Dateien koennen intern freien Platz enthalten, ohne dass das Betriebssystem diesen Platz sieht. Ein Datenfile mit 500 GB kann intern nur 200 GB belegt haben; Windows sieht trotzdem eine 500-GB-Datei. Shrink versucht, den ungenutzten Bereich am Dateiende so freizuraeumen, dass die Datei physisch kleiner werden kann.

Das ist wichtig: Shrink loescht keine Daten. Shrink macht keine Datenbank "fachlich kleiner". Shrink gibt nur physisch abschneidbaren Dateiraum an das Betriebssystem zurueck.

Es gibt zwei sehr unterschiedliche Welten:

- Datenfile-Shrink bewegt Daten- und Indexseiten.
- Logfile-Shrink schneidet inaktive VLFs am Dateiende ab.

Diese Unterscheidung ist der Kern fast aller Shrink-Entscheidungen.

## `DBCC SHRINKFILE` vs. `DBCC SHRINKDATABASE`

`DBCC SHRINKFILE` arbeitet dateibezogen. Man sagt SQL Server: "Diese konkrete Datei soll auf Zielgroesse X MB gebracht werden." Das ist kontrollierbar und fuer produktive Eingriffe fast immer die bessere Wahl.

```sql
USE [MeineDatenbank];
DBCC SHRINKFILE (N'MeineDatei', 10240);
```

`DBCC SHRINKDATABASE` arbeitet datenbankweit und ist grober. SQL Server versucht, mehrere Dateien der Datenbank auf einen gewuenschten freien Prozentsatz zu bringen. Das ist schwerer zu steuern und kann unerwuenscht Dateien anfassen, die man gar nicht gezielt bearbeiten wollte.

```sql
DBCC SHRINKDATABASE (N'MeineDatenbank', 10);
```

Praxisregel: Fuer geplante Admin-Eingriffe lieber `DBCC SHRINKFILE` verwenden, vorher messen und je Datei entscheiden.

## Datenfile-Shrink

Ein Datenfile ist eine Folge von 8-KB-Seiten. SQL Server kann eine Datei nur am Ende physisch kuerzen. Wenn hinter der gewuenschten Zielgroesse noch belegte Seiten liegen, muessen diese Seiten zuerst nach vorne in freie Bereiche verschoben werden.

Vereinfacht:

1. Zielgroesse bestimmen.
2. Bereich hinter der Zielgroesse untersuchen.
3. Belegte Seiten aus diesem Bereich nach vorne verschieben.
4. Allocation Maps und interne Seitenverweise aktualisieren.
5. Alte Seiten freigeben.
6. Freien Bereich am Dateiende an das Betriebssystem zurueckgeben.

Das ist echte Datenbewegung. Sie erzeugt I/O, Log, Locks, Latches und meistens Indexfragmentierung.

### Warum Datenfile-Shrink fragmentiert

Ein Index hat eine logische Reihenfolge. Shrink interessiert sich aber nicht fuer diese Reihenfolge, sondern fuer das Freiraeumen des Dateiendbereichs. Seiten aus dem hinteren Dateibereich werden dort abgelegt, wo weiter vorne gerade Platz ist. Dadurch kann die physische Seitenreihenfolge schlechter zur logischen Indexreihenfolge passen.

Folgen:

- `avg_fragmentation_in_percent` kann stark steigen.
- Grosse Scans und Range-Zugriffe koennen langsamer werden.
- Page Density kann leiden.
- Nachfolgende Indexwartung kann wieder Platz brauchen.

Deshalb wirkt "Shrink und danach Index Rebuild" oft widerspruechlich: Der Shrink gibt Platz frei, der Rebuild braucht wieder Platz, um Indizes sauber aufzubauen.

### Wann Datenfile-Shrink sinnvoll sein kann

Datenfile-Shrink ist nicht verboten. Er braucht nur einen guten Grund:

- Eine grosse Datenmenge wurde dauerhaft geloescht oder archiviert.
- Eine alte Datenbank wird nur noch gelesen und braucht den frueher reservierten Platz nicht mehr.
- Eine Datei soll mit `EMPTYFILE` geleert und entfernt werden.
- Ein Volume ist akut voll und andere Massnahmen reichen nicht schnell genug.
- Eine einmalige Fehlkonfiguration hat zu uebergrossen Dateien gefuehrt.

Nicht sinnvoll ist Datenfile-Shrink:

- als regelmaessiger Wartungsjob,
- nur weil intern freier Platz sichtbar ist,
- wenn die Anwendung denselben Platz bald wieder braucht,
- ohne Plan fuer Indexwartung, Statistiken und Autogrowth.

## Logfile-Shrink

Das Transaktionslog funktioniert anders. Logdateien bestehen intern aus Virtual Log Files. SQL Server schreibt den logischen Logstrom durch diese VLFs. Ein Logfile-Shrink verschiebt keine Logdatensaetze. Er kann nur inaktive VLFs am physischen Dateiende entfernen.

Darum kann eine Logdatei trotz wenig genutztem Logspace nicht schrumpfen, wenn am Dateiende noch ein aktives VLF liegt. Der aktive Bereich muss erst wiederverwendbar werden oder durch normale Logaktivitaet weiterwandern.

Wichtige Fragen vor einem Logfile-Shrink:

- Welches Recovery Model hat die Datenbank?
- Wie viel Log ist aktuell genutzt?
- Was sagt `log_reuse_wait_desc`?
- Gibt es offene Transaktionen?
- Gibt es Logbackups?
- Gibt es Replikation, CDC, Availability Groups, Mirroring oder andere Logleser?
- Liegt das letzte aktive VLF am Dateiende?

## Recovery Models und warum sie fuer Shrink relevant sind

Das Recovery Model bestimmt nicht direkt, ob `DBCC SHRINKFILE` technisch erlaubt ist. Es bestimmt aber, wann Logbereiche wiederverwendbar werden. Genau das entscheidet, ob ein Log-Shrink ueberhaupt etwas bewirken kann.

### SIMPLE

In `SIMPLE` verwaltet SQL Server die Log-Wiederverwendung automatisch. Nach einem `CHECKPOINT` koennen inaktive Logbereiche wiederverwendbar werden, sofern keine andere Ursache blockiert.

Typischer Ablauf:

```sql
USE [MeineSimpleDB];
CHECKPOINT;
DBCC SHRINKFILE (N'MeineSimpleDB_log', 1024);
```

Das Repository enthaelt dafuer:

- [ShrinkSimple.md](19_Transaktions/SQLScripts/ShrinkSimple.md)
- [ShrinkSimple_multiple_Files.md](19_Transaktions/SQLScripts/ShrinkSimple_multiple_Files.md)

Wichtig: Auch in `SIMPLE` koennen aktive Transaktionen, Replikation, CDC, Snapshot-Kontext oder andere Ursachen die Wiederverwendung blockieren.

### FULL

In `FULL` bleibt das Log erhalten, bis es per Logbackup gesichert wurde. Das ist die Grundlage fuer Point-in-Time-Recovery. Ein `CHECKPOINT` allein reicht nicht, um die Logkette zu trunkierten.

Typischer Ablauf:

```sql
BACKUP LOG [MeineFullDB]
TO DISK = N'X:\SQLBackups\MeineFullDB_before_shrink.trn'
WITH INIT, CHECKSUM;

USE [MeineFullDB];
DBCC SHRINKFILE (N'MeineFullDB_log', 4096);
```

Das Logbackup ist kein Wegwerf-Artefakt. Es gehoert zur Restore-Kette. Wenn man es verliert, kann die Restore-Kette fuer Point-in-Time-Recovery unterbrochen sein.

Das Repository enthaelt dafuer:

- [ShrinkFullDatabase.md](19_Transaktions/SQLScripts/ShrinkFullDatabase.md)
- [usp_LogShrink.sql](71_BackupRestore_Strategies/usp_LogShrink.sql)

### BULK_LOGGED

`BULK_LOGGED` ist ein Sondermodell fuer bestimmte bulk-orientierte Operationen. Es kann Logging reduzieren, hat aber Restore-Einschraenkungen fuer Zeitpunkte innerhalb bulk-logged Operationen. Fuer Shrink ist wichtig:

- Logbackups bleiben relevant.
- Log-Reuse-Wait bleibt relevant.
- Point-in-Time-Recovery muss fachlich genauer betrachtet werden.
- Bulk-logged Operationen koennen grosse Logbereiche beeinflussen.

Wenn `BULK_LOGGED` im Einsatz ist, sollte ein Shrink immer mit Backup-/Restore-Verantwortlichen abgestimmt werden.

### Wechsel auf SIMPLE und zurueck auf FULL

Technisch kann man eine `FULL`-Datenbank kurz auf `SIMPLE` setzen, dann shrinken und danach wieder auf `FULL` stellen:

```sql
ALTER DATABASE [MeineDB] SET RECOVERY SIMPLE;
CHECKPOINT;
DBCC SHRINKFILE (N'MeineDB_log', 4096);
ALTER DATABASE [MeineDB] SET RECOVERY FULL;
```

Das ist aber kein harmloser Trick. Dabei ist zu beachten:

- Der Wechsel auf `SIMPLE` unterbricht die bisherige Log-Backup-Kette.
- Point-in-Time-Recovery fuer den bisherigen Verlauf ist danach nicht mehr wie vorher moeglich.
- Nach dem Wechsel zurueck auf `FULL` muss die Backup-Strategie neu sauber gestartet werden.
- Direkt nach dem Wechsel von `SIMPLE` auf `FULL` ist ein neues Full- oder Differential-Backup noetig, damit die Logkette fuer weitere Logbackups sinnvoll startet.
- Log-Shipping, Always On, Replikation, CDC, Audit- und Restore-Vorgaben koennen betroffen sein.
- In produktiven Systemen ist dieser Weg meist nur erlaubt, wenn RPO/RTO und Restore-Anforderungen das ausdruecklich zulassen.

Kurz: Der SIMPLE-Umweg kann in Labor-, Test- oder bewusst freigegebenen Notfallsituationen passen. Fuer produktive `FULL`-Datenbanken ist der sauberere Weg meistens ein regulaeres Logbackup plus gezielter Log-Shrink ohne Recovery-Model-Wechsel.

## Trunkierung ist nicht Shrink

Diese Verwechslung ist sehr haeufig.

| Vorgang | Bedeutung |
|---|---|
| Log-Trunkierung | Inaktive Logbereiche werden innerhalb der Logdatei wiederverwendbar. Die `.ldf`-Datei wird dadurch nicht automatisch kleiner. |
| Log-Shrink | Die physische `.ldf`-Datei wird kleiner, indem inaktive VLFs am Dateiende entfernt werden. |
| Datenfile-Freiraum | SQL Server hat intern freien Platz in der `.mdf`/`.ndf`. Windows sieht diesen Platz noch nicht. |
| Datenfile-Shrink | SQL Server versucht, freien Platz am Dateiende an Windows zurueckzugeben. |

In `FULL` kann ein Logbackup Log-Trunkierung ermoeglichen. Es verkleinert aber die Logdatei nicht. Dafuer braucht es zusaetzlich `DBCC SHRINKFILE`.

## Braucht man freien Speicherplatz, um zu shrinken?

Die ehrliche Antwort lautet: Es kommt darauf an, welche Datei geshrinkt wird und was SQL Server dafuer intern noch tun muss.

### Datenfile-Shrink und freier OS-Platz

Ein Datenfile-Shrink braucht nicht zwingend zusaetzlichen freien Platz auf dem Betriebssystem-Volume in der Groesse der zu verschiebenden Daten. SQL Server verschiebt Seiten innerhalb der bestehenden Datenbankdatei. Entscheidend ist freier Platz innerhalb der Datei vor der Zielgroesse.

Trotzdem kann ein Datenfile-Shrink indirekt freien Platz brauchen:

- Die Seitenbewegungen werden protokolliert. Das Transaktionslog muss genug Platz haben oder wachsen koennen.
- Wenn das Log auf demselben vollen Volume liegt und nicht wachsen kann, kann der Shrink scheitern oder blockieren.
- In `FULL` erzeugt der Shrink Log, das spaeter per Logbackup gesichert werden muss.
- Nacharbeiten wie Index Rebuilds koennen erheblich Platz in Datenfile und/oder `tempdb` brauchen.

### Logfile-Shrink und freier OS-Platz

Ein Logfile-Shrink gibt normalerweise Platz frei, statt zusaetzlichen OS-Platz zu brauchen. Aber auch hier gibt es Voraussetzungen:

- Der zu entfernende Bereich am Ende muss aus inaktiven VLFs bestehen.
- In `FULL`/`BULK_LOGGED` braucht man meist ein Logbackup, bevor genug Logbereiche wiederverwendbar sind.
- Dieses Logbackup muss irgendwo gespeichert werden. Wenn das Zielvolume 0 Byte frei hat, muss das Backup auf ein anderes Volume oder eine Netzwerkfreigabe.
- Wenn `log_reuse_wait_desc` einen Blocker zeigt, hilft Shrink nicht.

### Geht Shrink bei 0 Byte freiem Speicherplatz?

Manchmal ja, manchmal nein.

| Situation | Chance | Begruendung |
|---|---|---|
| Datenfile hat am Ende bereits freien Platz, `TRUNCATEONLY` reicht | Gut | SQL Server kann das Dateiende abschneiden, ohne viele Seiten zu bewegen. |
| Datenfile hat intern freien Platz, aber belegte Seiten am Ende | Mittel | Page-Moves laufen innerhalb der Datei, aber das Log muss die Bewegungen aufnehmen koennen. |
| Logfile hat inaktive VLFs am Ende | Gut | SQL Server kann die `.ldf` kuerzen und gibt sofort OS-Platz frei. |
| FULL-DB braucht erst ein Logbackup, aber das Backupziel liegt auf dem vollen Volume | Schlecht | Das Backup braucht Speicher. Backup auf anderes Volume oder Share schreiben. |
| Transaktionslog ist voll und kann nicht wachsen | Schlecht | Datenfile-Shrink erzeugt Log; ohne Logplatz kann der Vorgang scheitern. |
| `log_reuse_wait_desc = ACTIVE_TRANSACTION` | Schlecht | Aktive Transaktion haelt Log aktiv; erst Ursache klaeren. |
| 0 Byte frei, aber Datenfile-Shrink wuerde zuerst viel Log erzeugen | Riskant | Kann genau den Raum brauchen, der nicht mehr verfuegbar ist. |

Praktische Notfallregel:

1. Nicht sofort blind shrinken.
2. Herausfinden, welche Datei das Volume fuellt.
3. Wenn es das Log ist: `log_reuse_wait_desc`, offene Transaktionen und Logbackup pruefen.
4. Wenn ein Logbackup noetig ist: auf ein anderes Volume oder Share sichern.
5. Wenn ein Datenfile betroffen ist: pruefen, ob `TRUNCATEONLY` schon hilft.
6. Wenn normaler Datenfile-Shrink noetig ist: Logplatz und `tempdb`/Nacharbeiten beachten.

## Was tun, wenn wirklich 0 Byte frei sind?

Eine 0-Byte-Situation ist eine Stoerung, kein normales Wartungsfenster. Ziel ist zuerst Stabilisierung.

Moegliche Sofortmassnahmen:

- Logbackup auf ein anderes Volume oder eine Netzwerkfreigabe schreiben.
- Nicht benoetigte `.bak`, `.trn`, `.xel`, Dumps oder alte Exportdateien auf dem Volume verschieben, nicht loeschen ohne Freigabe.
- SQL-Agent-Jobs stoppen, die weiter Daten schreiben oder Log erzeugen.
- Offene, grosse Transaktionen identifizieren.
- Wenn das Log durch `LOG_BACKUP` blockiert ist: Logbackup ausfuehren.
- Wenn das Log inaktive VLFs am Ende hat: gezielter Log-Shrink.
- Wenn ein Datenfile am Ende freien Platz hat: `DBCC SHRINKFILE (..., TRUNCATEONLY)`.
- Wenn Datenfile-Shrink Page-Moves braucht: vorher sicherstellen, dass das Log nicht sofort voll laeuft.

Was man vermeiden sollte:

- Recovery Model hektisch auf `SIMPLE` setzen, ohne Restore-Anforderungen zu klaeren.
- Backups auf dasselbe volle Volume schreiben.
- `DBCC SHRINKDATABASE` pauschal ueber alle Dateien laufen lassen.
- Daten oder Backups loeschen, ohne sicher zu wissen, ob sie noch gebraucht werden.
- Einen langen Datenfile-Shrink starten, wenn das Log schon keinen Platz mehr hat.

## Warum Recovery Model und Datenbanktyp relevant sind

Mit "Datenbanktyp" ist in diesem Kontext meist das Recovery Model gemeint. Es ist relevant, weil Shrink technisch auf Dateien wirkt, aber die Wiederverwendbarkeit des Logs vom Recovery Model abhaengt.

| Recovery Model | Log-Wiederverwendung | Shrink-Konsequenz |
|---|---|---|
| `SIMPLE` | Nach `CHECKPOINT`, sofern kein anderer Blocker existiert. | Log-Shrink kann nach `CHECKPOINT` sinnvoll sein. |
| `FULL` | Nach regulaerem Logbackup, sofern kein anderer Blocker existiert. | Log-Shrink ohne Logbackup bringt oft nichts und darf die Backup-Kette nicht umgehen. |
| `BULK_LOGGED` | Ebenfalls Logbackup-orientiert, mit Besonderheiten bei bulk-logged Operationen. | Shrink nur mit Blick auf Restore-Einschraenkungen und Backup-Kette. |

Weitere "Datenbanktypen" oder Betriebsformen koennen ebenfalls relevant sein:

| Betriebsform | Relevanz fuer Shrink |
|---|---|
| Aktive OLTP-Datenbank | Shrink konkurriert mit User-Workload und erzeugt oft Grow-Shrink-Zyklen. |
| DWH/ETL-Datenbank | Grosse Ladefenster koennen Dateien regelmaessig brauchen; Shrink kann den naechsten Load verschlechtern. |
| Archivdatenbank | Ein einmaliger Shrink ist plausibler, wenn danach wirklich nur noch gelesen wird. |
| Always On Availability Group | Shrink erzeugt Log und kann Send-/Redo-Queues beeinflussen. |
| Log Shipping | Logbackup-Kette und Restore-Latenz beachten. |
| Replikation/CDC | Logleser koennen Log-Wiederverwendung blockieren. |
| Read-only Datenbank | Fuer Shrink und Nacharbeiten muss ggf. ein bewusstes Wartungsfenster mit Schreibbarkeit geplant werden. |

## `log_reuse_wait_desc` verstehen

`log_reuse_wait_desc` ist einer der wichtigsten Werte vor einem Log-Shrink.

```sql
SELECT
    name,
    recovery_model_desc,
    log_reuse_wait_desc
FROM sys.databases
WHERE name = N'MeineDatenbank';
```

Typische Werte:

| Wert | Bedeutung | Naechster Schritt |
|---|---|---|
| `NOTHING` | Kein bekannter Blocker. | Shrink kann technisch eher Wirkung haben, wenn VLFs am Ende frei sind. |
| `CHECKPOINT` | Checkpoint steht aus oder ist relevant. | In `SIMPLE` `CHECKPOINT` pruefen; danach erneut messen. |
| `LOG_BACKUP` | Logbackup erforderlich. | In `FULL`/`BULK_LOGGED` regulaeres Logbackup ausfuehren. |
| `ACTIVE_TRANSACTION` | Eine Transaktion haelt Log aktiv. | Langlaeufer finden, nicht blind shrinken. |
| `REPLICATION`, `CDC` | Logleser brauchen noch Log. | Replikation/CDC-Latenz pruefen. |
| `AVAILABILITY_REPLICA`, `DATABASE_MIRRORING` | HA/DR braucht noch Log. | AG/Mirroring Queue und Zustand pruefen. |
| `ACTIVE_BACKUP_OR_RESTORE` | Backup/Restore laeuft. | Vorgang abwarten oder Status pruefen. |

## Zielgroesse bestimmen

Eine gute Zielgroesse ist nicht "so klein wie moeglich", sondern "klein genug, um das Problem zu loesen, und gross genug, um normales Arbeiten ohne sofortiges Wachstum zu erlauben".

Fuer Datenfiles:

```text
Zielgroesse = aktuell belegter Platz + fachliche Wachstumsreserve + Betriebsreserve
```

Fuer Logfiles:

```text
Zielgroesse = normaler Logbedarf des groessten Betriebsfensters + Reserve
```

Der normale Logbedarf haengt ab von:

- groessten ETL-Batches,
- groessten Indexoperationen,
- Dauer bis zum naechsten Logbackup,
- langen Transaktionen,
- Bulk Loads,
- Wartungsjobs,
- Replikation/HA-Verzoegerungen.

## Vorgehen: Analyse vor Ausfuehrung

Serverweit:

1. Betroffenes Laufwerk identifizieren.
2. [DatabaseShrinkCandidateReview.md](20_Create_Database/SQLScripts/DatabaseShrinkCandidateReview.md) ausfuehren.
3. Kandidaten nach Log vs. Datenfile trennen.
4. Bei Logdateien `log_reuse_wait_desc` pruefen.
5. Bei Datenfiles Fragmentierungs- und Nacharbeitskosten einplanen.

Fuer eine einzelne Datenbank:

1. [DatabaseShrinkAnalysis.md](20_Create_Database/SQLScripts/DatabaseShrinkAnalysis.md) verwenden.
2. `@DatabaseName` setzen.
3. Optional `@TargetVolumeRoot` setzen.
4. Ergebnis `ActionClass`, `RecoverableMB`, `TargetSizeMB`, `Prerequisite` lesen.
5. Erst danach ein ausfuehrendes Skript waehlen.

## Vorgehen: SIMPLE-Log shrinken

Fuer SIMPLE-Datenbanken:

- Eine Logdatei: [ShrinkSimple.md](19_Transaktions/SQLScripts/ShrinkSimple.md)
- Mehrere Logdateien: [ShrinkSimple_multiple_Files.md](19_Transaktions/SQLScripts/ShrinkSimple_multiple_Files.md)

Typische Logik:

```sql
USE [MeineSimpleDB];
CHECKPOINT;
DBCC SHRINKFILE (N'MeineSimpleDB_log', 1024);
```

Aber: Wenn aktive Transaktionen oder andere Blocker existieren, hilft der Shrink nicht oder nur teilweise.

## Vorgehen: FULL- oder BULK_LOGGED-Log shrinken

Fuer FULL/BULK_LOGGED-Datenbanken:

- [ShrinkFullDatabase.md](19_Transaktions/SQLScripts/ShrinkFullDatabase.md)
- [usp_LogShrink.sql](71_BackupRestore_Strategies/usp_LogShrink.sql)

Typische Logik:

```sql
BACKUP LOG [MeineFullDB]
TO DISK = N'X:\SQLBackups\MeineFullDB_before_shrink.trn'
WITH INIT, CHECKSUM;

USE [MeineFullDB];
DBCC SHRINKFILE (N'MeineFullDB_log', 4096);
```

Das Backup muss zur Restore-Kette passen und sicher aufbewahrt werden.

## Vorgehen: Datenfile shrinken

Datenfile-Shrink ist der teuerste und riskanteste Shrink-Typ. Er sollte nur nach Analyse und mit Wartungsfenster erfolgen.

Minimalbeispiel:

```sql
USE [MeineDatenbank];
DBCC SHRINKFILE (N'MeineDatenDatei', 200000);
```

Schonender, wenn am Dateiende bereits freier Platz liegt:

```sql
USE [MeineDatenbank];
DBCC SHRINKFILE (N'MeineDatenDatei', TRUNCATEONLY);
```

Wenn eine Datei entfernt werden soll:

```sql
USE [MeineDatenbank];
DBCC SHRINKFILE (N'AlteNdfDatei', EMPTYFILE);

ALTER DATABASE [MeineDatenbank]
REMOVE FILE [AlteNdfDatei];
```

Nach Datenfile-Shrink:

1. Groesse erneut messen.
2. Indexfragmentierung messen.
3. Indizes gezielt reorganisieren/rebuilden.
4. Statistiken aktualisieren.
5. Autogrowth auf feste, sinnvolle Groesse setzen.
6. Monitoring anpassen.

## Fortschritt beobachten

Laufenden Shrink finden:

```sql
SELECT
    r.session_id,
    r.command,
    r.status,
    r.percent_complete,
    CAST(r.estimated_completion_time / 1000.0 / 60.0 AS DECIMAL(18, 2)) AS EstimatedMinutesRemaining,
    r.wait_type,
    r.blocking_session_id,
    r.reads,
    r.writes,
    t.text AS RunningSql
FROM sys.dm_exec_requests AS r
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) AS t
WHERE r.command LIKE N'DbccFilesCompact%'
   OR t.text LIKE N'%SHRINKFILE%';
```

Blocker finden:

```sql
SELECT
    r.session_id,
    r.blocking_session_id,
    r.wait_type,
    r.wait_time,
    r.command,
    DB_NAME(r.database_id) AS DatabaseName,
    t.text AS SqlText
FROM sys.dm_exec_requests AS r
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) AS t
WHERE r.blocking_session_id <> 0
   OR r.command LIKE N'DbccFilesCompact%';
```

## Was passiert beim Abbruch?

`DBCC SHRINKFILE` kann abgebrochen werden. Bereits abgeschlossene interne Arbeit kann erhalten bleiben. Danach muss man neu messen. Nicht davon ausgehen, dass alles automatisch auf den Ausgangszustand zurueckgerollt wurde.

Neu messen:

```sql
USE [MeineDatenbank];

SELECT
    name,
    type_desc,
    CAST(size / 128.0 AS DECIMAL(18, 2)) AS SizeMB,
    CAST(
        CASE
            WHEN type_desc = N'ROWS'
                THEN FILEPROPERTY(name, 'SpaceUsed') / 128.0
            ELSE NULL
        END
        AS DECIMAL(18, 2)
    ) AS DataUsedMB
FROM sys.database_files;
```

## AUTO_SHRINK

`AUTO_SHRINK` sollte fuer normale produktive Datenbanken deaktiviert bleiben.

```sql
ALTER DATABASE [MeineDatenbank] SET AUTO_SHRINK OFF;
```

Warum?

- Hintergrund-Shrink konkurriert mit normaler Last.
- Dateien koennen danach wieder wachsen muessen.
- Grow-Shrink-Zyklen erzeugen Overhead.
- Dateisystemfragmentierung und Performanceprobleme werden wahrscheinlicher.
- Man verliert die Kontrolle ueber Zeitpunkt und Umfang des Shrinks.

## Autogrowth nach Shrink

Nach einem Shrink muss die Datei sinnvoll wachsen koennen. Prozentuale Growth-Werte sind oft unguenstig, weil sie bei grossen Dateien sehr grosse und bei kleinen Dateien sehr kleine Spruenge erzeugen.

Datenfile:

```sql
ALTER DATABASE [MeineDatenbank]
MODIFY FILE
(
    NAME = N'MeineDatenDatei',
    FILEGROWTH = 1024MB
);
```

Logfile:

```sql
ALTER DATABASE [MeineDatenbank]
MODIFY FILE
(
    NAME = N'MeineLogDatei',
    FILEGROWTH = 1024MB
);
```

Wenn klar ist, dass eine Datei wieder wachsen wird, ist kontrolliertes Presizing besser als ein sehr kleiner Shrink mit anschliessendem Autogrowth.

## Entscheidungsbaum

```text
Ist ein Volume voll oder soll dauerhaft Platz zurueckgegeben werden?
  |
  +-- Nein:
  |     Shrink meist nicht ausfuehren.
  |
  +-- Ja:
        Welche Datei ist betroffen?
          |
          +-- Logfile:
          |     Recovery Model pruefen.
          |       |
          |       +-- SIMPLE:
          |       |     CHECKPOINT, log_reuse_wait_desc, aktive Transaktionen.
          |       |     Dann ShrinkSimple-Skript.
          |       |
          |       +-- FULL/BULK_LOGGED:
          |             Logbackup-Kette pruefen.
          |             Ggf. Logbackup auf anderes Volume/Share.
          |             log_reuse_wait_desc beheben.
          |             Dann ShrinkFullDatabase oder usp_LogShrink.
          |
          +-- Datenfile:
                Wurde dauerhaft viel geloescht/archiviert?
                  |
                  +-- Nein:
                  |     Besser Datei als Reserve behalten oder Storage/Archivierung planen.
                  |
                  +-- Ja:
                        Zielgroesse mit Reserve berechnen.
                        Datenfile-Shrink im Wartungsfenster.
                        Danach Indexe, Statistiken, Autogrowth, Monitoring.
```

## Betriebs-Checkliste

Vorher:

- Betroffene Datei und betroffenes Volume identifiziert.
- Datenfile vs. Logfile geklaert.
- Recovery Model geprueft.
- `log_reuse_wait_desc` geprueft.
- Aktuelle Backups vorhanden.
- Restore-Anforderung verstanden.
- Zielgroesse mit Reserve berechnet.
- Bei `FULL`/`BULK_LOGGED`: Logbackup-Kette verstanden.
- Bei 0 Byte frei: Backupziel ausserhalb des vollen Volumes verfuegbar.
- Wartungsfenster abgestimmt.
- HA/DR, Replikation, CDC und Jobs bedacht.

Waehrenddessen:

- Fortschritt und Waits beobachten.
- Logwachstum beobachten.
- Nicht mehrere Shrinks derselben DB parallel starten.
- Bei langer Laufzeit in Etappen arbeiten.
- Bei Blockern nicht blind weiterlaufen lassen.

Nachher:

- Datei- und Volume-Groessen erneut messen.
- Logbackup-Jobs pruefen.
- VLFs plausibilisieren.
- Indexfragmentierung messen.
- Indizes und Statistiken gezielt warten.
- `FILEGROWTH` setzen.
- `AUTO_SHRINK OFF` sicherstellen.
- Monitoring und Dokumentation aktualisieren.

## Typische Fehler

| Fehler | Warum problematisch |
|---|---|
| `DBCC SHRINKDATABASE` pauschal ausfuehren | Zu grob, schwer steuerbar, hohe Nebenwirkungen. |
| Shrink als regelmaessiger Job | Erzeugt Grow-Shrink-Zyklen und Last. |
| Datenfile auf knapp ueber UsedMB shrinken | Naechste normale Aenderung triggert Autogrowth. |
| Logfile shrinken ohne Log-Reuse-Wait-Pruefung | Bringt oft keine Wirkung. |
| FULL-DB auf SIMPLE setzen ohne Freigabe | Unterbricht Log-Backup-Kette und gefaehrdet Restore-Ziele. |
| Logbackup auf volles Volume schreiben | Backup schlaegt fehl und loest das Problem nicht. |
| Nach Datenfile-Shrink keine Indexwartung | Performance kann schlechter werden. |
| Nach Shrink kein Autogrowth-Review | Datei waechst spaeter in unpassenden Schritten. |
| 0-Byte-Notfall mit langem Datenfile-Shrink starten | Der Shrink kann Log brauchen, das nicht mehr wachsen kann. |

## Gute Alternativen zum Shrink

- Datei als Reserve fuer erwartetes Wachstum behalten.
- Daten archivieren statt nur Datei zu schrumpfen.
- Alte Partitionen per Partition Switch entfernen.
- Unbenutzte oder doppelte Indizes entfernen.
- Daten- oder Indexkompression pruefen.
- Datei oder Filegroup auf anderes Volume verschieben.
- Storage erweitern.
- Alte Datenbank wirklich droppen oder auf guenstigeren Storage verschieben.
- Logbackup-Takt verbessern, wenn Logs regelmaessig wachsen.
- Transaktionen verkleinern oder ETL-Batches staffeln.

## Quellen

- Microsoft Learn: [DBCC SHRINKFILE](https://learn.microsoft.com/en-us/sql/t-sql/database-console-commands/dbcc-shrinkfile-transact-sql)
- Microsoft Learn: [Back up a transaction log](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/back-up-a-transaction-log-sql-server)
- Microsoft Learn: [View or change the recovery model of a database](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/view-or-change-the-recovery-model-of-a-database-sql-server)
- Microsoft Learn: [Considerations for autogrow and autoshrink](https://learn.microsoft.com/en-us/troubleshoot/sql/database-engine/database-file-operations/considerations-autogrow-autoshrink)
