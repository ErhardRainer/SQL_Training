# Shrink einer SQL-Server-Datenbank

Ein Shrink ist kein harmloses "Datei kleiner machen", sondern eine
physische Umorganisation von Datenbankdateien. Bei Datenfiles kann SQL Server
belegte 8-KB-Seiten vom Dateiende in freie Bereiche weiter vorne verschieben.
Bei Logfiles kann SQL Server nur freie Virtual Log Files am Ende der Logdatei
abschneiden. Beides erzeugt Last, kann lange dauern und ist fast nie eine gute
regelmaessige Wartungsmassnahme.

Dieser Artikel erklaert technisch, was dabei passiert, warum Shrinks oft sehr
lange laufen, warum man sie normalerweise vermeiden sollte und welche
Nacharbeiten danach wichtig sind.

## Kurzfassung

- `DBCC SHRINKFILE` verkleinert eine konkrete Datenbankdatei, nicht "die
  Datenbank" als logisches Objekt.
- Bei Datenfiles muessen belegte Seiten, die hinter der Zielgroesse liegen,
  nach vorne verschoben werden. Das erzeugt I/O, Log, Locks/Latches und meist
  starke Indexfragmentierung.
- Bei Logfiles werden keine Log-Datensaetze verschoben. SQL Server entfernt
  nur inaktive VLFs am Ende der Datei. Aktive VLFs am Dateiende blockieren den
  Shrink.
- Eine Datenbank offline zu nehmen hilft nicht. `DBCC SHRINKFILE` braucht eine
  online verfuegbare Datenbank. `SINGLE_USER` oder `RESTRICTED_USER` kann
  Stoerung reduzieren, macht den eigentlichen Datenbewegungsaufwand aber nicht
  kleiner.
- Shrink ist sinnvoll als Ausnahme: nach einmaliger Archivierung/Loeschung,
  nach versehentlichem Log-Wachstum, beim Entfernen einer Datei oder in einer
  echten Storage-Notlage.
- Ein besonders plausibler Sonderfall ist eine abgeschlossene Archivdatenbank:
  Wenn fachlich keine Aenderungen mehr passieren und danach nur noch gelesen
  wird, wird der freigegebene Platz voraussichtlich nicht wieder gebraucht.
- Nach einem Datenfile-Shrink sollte man Fragmentierung messen und gezielt
  Indizes reorganisieren/rebuilden, Statistiken aktualisieren und Autogrowth
  sauber einstellen.

## Beispiel: was bedeutet `DBCC SHRINKFILE (N'BIDWAX', 223159)`?

```sql
USE [BIDWAX_old];
DBCC SHRINKFILE (N'BIDWAX', 223159);
```

`BIDWAX` ist der logische Dateiname aus `sys.database_files`. `223159` ist die
Zielgroesse in MB, also ungefaehr 218 GB. SQL Server versucht, diese Datei auf
diese Groesse zu bringen. Wenn mehr Daten belegt sind oder am Dateiende noch
belegte Seiten liegen, muss SQL Server Daten umraeumen oder kann die Zielgroesse
nicht erreichen.

Wichtig: Der Target-Wert ist keine Aussage wie "loesche Daten bis auf 223159
MB". Daten werden nicht geloescht. SQL Server gibt nur unbenutzten,
physisch abschneidbaren Dateiraum an das Betriebssystem zurueck.

## Begriffe

| Begriff | Bedeutung |
|---|---|
| Datenfile | `.mdf` oder `.ndf`; enthaelt Daten- und Indexseiten. |
| Logfile | `.ldf`; enthaelt Transaktionslog-Datensaetze in VLFs. |
| Page | Kleinste Daten-I/O-Einheit in SQL Server, 8 KB. |
| Extent | 8 Pages, also 64 KB. |
| Allocation Maps | Interne Verwaltungsseiten wie PFS, GAM, SGAM und IAM, die freie/zugewiesene Seiten und Extents beschreiben. |
| Freier Platz in der Datei | Platz, den SQL Server innerhalb einer Datei wiederverwenden kann. Dieser Platz ist noch nicht frei fuer Windows. |
| Freier Platz auf dem Laufwerk | Platz, den das Betriebssystem wieder fuer andere Dateien nutzen kann. Shrink versucht genau diesen Platz zurueckzugeben. |
| VLF | Virtual Log File; interner Abschnitt einer Logdatei. Log-Shrink kann nur inaktive VLFs am Dateiende entfernen. |

## Shrink ist nicht gleich Shrink

### `DBCC SHRINKFILE`

`DBCC SHRINKFILE` arbeitet dateibezogen. Das ist fast immer die bessere Wahl,
weil man kontrolliert genau die Datei bearbeitet, die zu gross ist.

Typische Formen:

```sql
-- Datei auf Zielgroesse in MB verkleinern
DBCC SHRINKFILE (N'DataFileName', 200000);

-- Nur freien Platz am Dateiende abschneiden, keine Page-Moves
DBCC SHRINKFILE (N'DataFileName', TRUNCATEONLY);

-- Daten aus einer Datei in andere Dateien derselben Filegroup migrieren
DBCC SHRINKFILE (N'DataFileName', EMPTYFILE);
```

`TRUNCATEONLY` ist vergleichsweise billig, weil keine belegten Seiten umgezogen
werden. Es hilft nur, wenn am Dateiende bereits zusammenhaengend freier Platz
liegt.

`EMPTYFILE` ist ein Sonderfall: SQL Server verschiebt alle Daten aus dieser
Datei in andere Dateien derselben Filegroup und verhindert danach neue
Allokationen in dieser Datei. Das ist der typische Weg, um eine Datei spaeter
mit `ALTER DATABASE ... REMOVE FILE` entfernen zu koennen.

### `DBCC SHRINKDATABASE`

`DBCC SHRINKDATABASE` arbeitet datenbankweit und ist grober. Es versucht mehrere
Dateien anhand eines gewuenschten freien Prozentsatzes zu verkleinern. Im
Betrieb ist das meist weniger gut steuerbar als `DBCC SHRINKFILE`.

Empfehlung: Fuer produktive Eingriffe fast immer `DBCC SHRINKFILE` verwenden,
vorher messen und je Datei entscheiden.

## Wie funktioniert ein Datenfile-Shrink technisch?

Ein Datenfile ist eine Folge von 8-KB-Seiten. SQL Server kann eine Datei nur am
Ende physisch kuerzen. Wenn im hinteren Dateibereich noch belegte Seiten liegen,
muss SQL Server sie zuerst in freie Seiten weiter vorne verschieben.

Vereinfacht laeuft ein Datenfile-Shrink so:

1. SQL Server ermittelt die aktuelle Dateigroesse und die Zielgroesse.
2. SQL Server betrachtet den Bereich hinter der Zielgroesse. Dieser Bereich
   soll am Ende verschwinden.
3. Fuer jede belegte Seite in diesem hinteren Bereich sucht SQL Server freien
   Platz vor der Zielgrenze.
4. Die Seite wird an eine neue physische Position kopiert.
5. Interne Zuordnungen werden aktualisiert: Allocation Maps, IAM-Ketten,
   Seitenverweise und Objektmetadaten muessen zur neuen Page-ID passen.
6. Die alte Seite wird freigegeben.
7. Wenn am Dateiende nur noch freier Platz liegt, kann SQL Server die Datei
   kuerzen und Speicherplatz an das Betriebssystem zurueckgeben.

Das Entscheidende: Datenfile-Shrink erzeugt echte Datenbewegung. Je mehr
belegte Seiten am Dateiende liegen und je weniger zusammenhaengender freier
Platz vorne vorhanden ist, desto laenger dauert der Vorgang.

### Warum verursacht das Indexfragmentierung?

Ein B-Tree-Index hat eine logische Ordnung nach Schluesselwerten. Die
physische Lage der Indexseiten in der Datei ist fuer effiziente Scans trotzdem
wichtig, weil SQL Server bei Range-Scans gerne Seiten in logischer Reihenfolge
liest.

Beim Shrink ist das Ziel aber nicht "Indexseiten sauber sortieren", sondern
"Dateiende freiraeumen". SQL Server nimmt Seiten aus dem hinteren Bereich und
legt sie dort ab, wo vorne gerade Platz ist. Dadurch passt die physische
Reihenfolge der Seiten oft nicht mehr gut zur logischen Reihenfolge im Index.

Ergebnis:

- `avg_fragmentation_in_percent` steigt haeufig stark an.
- Page Density kann schlechter werden, wenn spaeter wieder Splits und
  ungeplante Growths auftreten.
- Grosse Scans und Range-Zugriffe koennen langsamer werden.
- Nachfolgende Indexwartung kann wieder Datenbankplatz benoetigen und einen
  Teil des Shrink-Effekts zunichtemachen.

Das ist der klassische Grund, warum "Shrink und danach Index Rebuild" zwar
technisch hilft, aber betrieblich absurd wirken kann: Der Shrink gibt Platz
frei, der Rebuild braucht wieder Platz fuer sortierte Indexstrukturen.

## Wie funktioniert ein Logfile-Shrink technisch?

Das Transaktionslog ist anders aufgebaut als Datenfiles. Es besteht intern aus
Virtual Log Files, kurz VLFs. Der logische Logstrom laeuft durch diese VLFs und
kann zirkulaer wiederverwendet werden, sobald Log-Datensaetze nicht mehr fuer
Recovery, Backup, Replikation, CDC, Availability Groups usw. benoetigt werden.

Ein Logfile-Shrink verschiebt keine Log-Datensaetze nach vorne. SQL Server kann
nur inaktive VLFs am Ende einer physischen Logdatei entfernen.

Darum gilt:

- Wenn am Ende der Logdatei ein aktiver VLF liegt, kann die Datei nicht unter
  diese Grenze schrumpfen.
- Das Ziel wird nur ungefaehr erreicht, weil VLF-Grenzen die kleinste
  abschneidbare Einheit sind.
- In `FULL` und `BULK_LOGGED` wird Lograum normalerweise erst nach Log-Backups
  wiederverwendbar.
- In `SIMPLE` hilft oft ein `CHECKPOINT`, sofern keine andere Ursache die
  Log-Wiederverwendung verhindert.

Log-Shrink ist also vor allem eine Frage von:

- Wie viel Log ist aktiv?
- Wo liegen die aktiven VLFs?
- Was sagt `log_reuse_wait_desc`?
- Gibt es lange Transaktionen, Replikation, CDC, AG-Redo, Log-Backup-Luecken
  oder andere Blocker?

## Warum dauert Shrink so lange?

Ein Datenfile-Shrink kann lange dauern, weil viele interne Arbeiten anfallen:

- **Zufaellige I/O-Muster:** Seiten werden vom Dateiende gelesen und an freien
  Stellen weiter vorne geschrieben.
- **Logging:** Page-Moves und Metadatenupdates muessen crash-sicher im
  Transaktionslog nachvollziehbar sein.
- **Locks und Latches:** SQL Server muss Seiten und interne Strukturen
  schuetzen, waehrend sie verschoben werden.
- **Buffer Pool Druck:** Viele Seiten werden gelesen und veraendert, obwohl
  der normale Workload sie vielleicht gerade nicht gebraucht haette.
- **Blocker:** Snapshot-Transaktionen, lange laufende Abfragen, offene
  Transaktionen oder intensive Schreiblast koennen den Shrink ausbremsen.
- **Ziel zu ambitioniert:** Wenn sehr weit heruntergeschrumpft werden soll,
  muessen entsprechend viele Seiten aus dem zu entfernenden Dateibereich weg.
- **Langsame Storage-Schicht:** Shrink ist oft I/O-lastig. Auf stark
  ausgelasteten oder langsamen Volumes faellt das massiv auf.

Bei Logfiles ist die Ursache anders:

- Aktive VLFs am Dateiende verhindern das Abschneiden.
- Fehlende Log-Backups in `FULL`/`BULK_LOGGED` verhindern Log-Trunkierung.
- Lange Transaktionen halten Logbereiche aktiv.
- HA/DR-Funktionen, Replikation, CDC oder andere Log-Leser koennen
  Wiederverwendung blockieren.

## Hilft es, die Datenbank offline zu nehmen?

Nein. Eine offline Datenbank kann nicht per `DBCC SHRINKFILE` bearbeitet
werden, weil SQL Server die Datenbank dafuer online oeffnen und intern
veraendern muss.

Was manchmal hilft:

```sql
ALTER DATABASE [BIDWAX_old] SET RESTRICTED_USER WITH ROLLBACK AFTER 60 SECONDS;
-- Shrink ausfuehren
ALTER DATABASE [BIDWAX_old] SET MULTI_USER;
```

Oder fuer ein sehr kontrolliertes Wartungsfenster:

```sql
ALTER DATABASE [BIDWAX_old] SET SINGLE_USER WITH ROLLBACK AFTER 60 SECONDS;
-- Shrink ausfuehren
ALTER DATABASE [BIDWAX_old] SET MULTI_USER;
```

Das reduziert konkurrierende Benutzeraktivitaet. Es reduziert aber nicht die
Menge der Seiten, die verschoben werden muessen. Fuer produktive Systeme ist
`SINGLE_USER` hart, weil es Benutzer trennt und auch Agent-Jobs oder Monitoring
aussperren kann.

## Warum sollte man Shrink normalerweise nicht machen?

### 1. Shrink beseitigt nicht die Ursache

Wenn eine Datei regelmaessig waechst, dann braucht die Workload diesen Platz.
Ein Shrink gibt ihn kurz zurueck, der naechste Autogrowth holt ihn wieder.
Dann hat man zwei teure Operationen bezahlt: Shrink und Wiederwachstum.

### 2. Datenfile-Shrink fragmentiert Indizes

Shrink verschiebt Seiten platzorientiert, nicht indexorientiert. Das fuehrt
haeufig zu starker logischer Fragmentierung. Danach werden Scans und grosse
Range-Zugriffe schlechter.

### 3. Shrink erzeugt zusaetzliches Log

Die Datenbewegung muss protokolliert werden. In `FULL` kann ein grosser
Datenfile-Shrink Log-Backups deutlich vergroessern und auf Availability
Replicas, Log Shipping oder Replikation zusaetzliche Arbeit erzeugen.

### 4. Autogrowth danach ist teuer

Wenn die Datei nach dem Shrink wieder wachsen muss, entstehen Pausen und I/O.
Bei Datenfiles kann Instant File Initialization helfen, wenn es korrekt
berechtigt ist. Bei Logfiles ist Wachstum besonders kritisch, weil Logbereiche
initialisiert werden muessen; versionsabhaengig hilft Instant File
Initialization fuer Logwachstum nur eingeschraenkt.

### 5. `AUTO_SHRINK` erzeugt ein Grow-Shrink-Pendel

`AUTO_SHRINK` laesst SQL Server im Hintergrund schrumpfen. Das kann mit
Autogrowth zu einem Kreislauf fuehren: Datei waechst, Hintergrundjob shrinkt,
Workload laesst sie wieder wachsen. Das ist fast immer ein Anti-Pattern.

### 6. Shrink konkurriert mit dem eigentlichen Workload

Shrink verbraucht I/O, CPU, Log-Durchsatz und interne Synchronisation. Wenn
parallel ETL, Reporting, Backups oder Benutzerlast laufen, bremst man genau das
System, dem man helfen wollte.

### 7. Shrink kann HA/DR nachziehen

In Always On, Log Shipping, Replikation oder Mirroring muessen die erzeugten
Log-Datensaetze ebenfalls verarbeitet werden. Dadurch koennen Redo Queues,
Send Queues oder Log-Shipping-Latenzen steigen.

## Wann ist Shrink trotzdem sinnvoll?

Shrink ist eine Ausnahmehandlung, aber keine verbotene Handlung. Sinnvoll ist
er zum Beispiel:

- Nach einmaliger Archivierung oder Loeschung grosser Datenmengen, wenn der
  Platz dauerhaft nicht mehr gebraucht wird.
- Bei einer fachlich abgeschlossenen Archiv- oder Alt-Datenbank, auf die nach
  dem Aufraeumen nur noch lesend zugegriffen wird.
- Nach `DROP TABLE`, `TRUNCATE TABLE`, Filegroup-Bereinigung oder
  Partition-Switch-out, wenn Speicher dauerhaft zurueckgegeben werden soll.
- Wenn eine Logdatei durch einen einmaligen Vorfall stark gewachsen ist:
  fehlendes Log-Backup, grosse Indexoperation, grosser Import, offene
  Transaktion.
- Wenn eine Datei mit `EMPTYFILE` geleert und danach entfernt werden soll.
- In einer akuten Storage-Notlage, wenn kurzfristig Platz frei werden muss.

Nicht sinnvoll ist Shrink:

- Als taeglicher oder woechentlicher Wartungsjob.
- Nur weil "viel freier Platz in der Datenbankdatei" sichtbar ist.
- Vorhersehbar vor einem Workload, der denselben Platz bald wieder benoetigt.
- Auf Verdacht, ohne Messung von UsedMB, FreeInsideFileMB und Wachstumshistorie.

### Sonderfall: abgeschlossene Archivdatenbank

Dein Gedanke ist richtig: Wenn in einer Datenbank keine fachlichen
Aenderungen mehr passieren und sie nur noch als historische Referenz gelesen
wird, ist ein einmaliger Shrink wesentlich besser begruendbar als bei einer
aktiven Produktionsdatenbank.

Der Grund ist einfach: Das wichtigste Gegenargument gegen Shrink ist das
Grow-Shrink-Pendel. Wenn die Datenbank nach dem Shrink wieder normal
beschrieben wird, braucht sie den freigegebenen Platz bald erneut. Dann bezahlt
man erst den teuren Shrink und spaeter teures Autogrowth. Bei einer echten
Archivdatenbank faellt dieses Gegenargument weitgehend weg, weil kein normales
Datenwachstum mehr zu erwarten ist.

Typisches Szenario:

1. Daten wurden archiviert, geloescht, partitioniert ausgelagert oder die
   Datenbank ist eine alte Kopie.
2. Es gibt noch viel freien Platz innerhalb der Datenfiles.
3. Die Datenbank wird kuenftig nur noch fuer Recherche, Audit, Reporting oder
   Nachweispflichten gelesen.
4. Es gibt keinen ETL-Prozess, keine Anwendung und keinen Job mehr, der Daten
   hinein schreibt.
5. Der freigegebene Storage wird auf dem Volume tatsaechlich anderweitig
   gebraucht.

In diesem Fall ist ein einmaliger, kontrollierter Shrink legitim. Trotzdem
bleiben die technischen Nebenwirkungen real:

- Der Shrink kann lange laufen.
- Der Shrink erzeugt I/O und Log.
- Datenfile-Shrink kann Indizes fragmentieren.
- Nacharbeiten bleiben notwendig, besonders Indexwartung und Statistiken.
- Die Zielgroesse sollte Reserve enthalten, z. B. fuer minimale administrative
  Aenderungen oder spaet entdeckte Korrekturen.

Wichtige Nuance: "Nur noch lesender Zugriff" und die SQL-Server-Option
`READ_ONLY` sind nicht dasselbe. Wenn die Datenbank noch `READ_WRITE` ist,
koennen trotz read-only Anwendung weiterhin Schreibvorgaenge entstehen, etwa
durch Query Store, automatische Statistiken, Wartungsjobs, Audit-/Hilfstabellen
oder versehentliche Benutzeraktionen. Wenn sie wirklich abgeschlossen ist, ist
ein guter Ablauf:

```sql
-- 1. Letzte geplante Datenbereinigung/Archivierung durchfuehren.
-- 2. Konsistenz, fachliche Vollstaendigkeit und Backup pruefen.
-- 3. Datenfile/Logfile bei Bedarf kontrolliert shrinken.
-- 4. Indizes/Statistiken fuer den kuenftigen Lesezugriff optimieren.
-- 5. Danach die Datenbank gegen weitere Aenderungen schuetzen.

ALTER DATABASE [BIDWAX_old] SET READ_ONLY WITH ROLLBACK AFTER 60 SECONDS;
```

Wenn die Datenbank bereits `READ_ONLY` ist und noch geschrumpft werden soll,
ist die saubere Betriebsentscheidung: kurz in ein Wartungsfenster nehmen,
falls noetig auf `READ_WRITE` setzen, Shrink und Nacharbeiten durchfuehren,
danach wieder `READ_ONLY` setzen. Bei Always-On-Secondaries oder Log-Shipping-
Standby-Datenbanken wird nicht auf der read-only Kopie geshrinkt, sondern auf
der schreibbaren Quelle bzw. im passenden Wartungsprozess.

Gerade bei Archivdatenbanken kann auch `TRUNCATEONLY` interessant sein:

```sql
USE [BIDWAX_old];
DBCC SHRINKFILE (N'BIDWAX', TRUNCATEONLY);
```

Das gibt nur freien Platz am Dateiende zurueck und verschiebt keine belegten
Datenpages. Wenn der freie Platz bereits hinten liegt, ist das deutlich
schonender. Wenn belegte Seiten am Dateiende liegen, reicht `TRUNCATEONLY`
nicht aus; dann braucht es den normalen Shrink mit Page-Moves oder man
akzeptiert die groessere Datei.

## Vorher messen: Welche Datei ist wirklich das Problem?

Zuerst muss klar sein, ob Datenfile oder Logfile betroffen ist und auf welchem
Volume die Datei liegt.

```sql
USE [BIDWAX_old];

SELECT
    DB_NAME() AS DatabaseName,
    file_id AS FileId,
    name AS LogicalFileName,
    type_desc AS FileType,
    physical_name AS PhysicalFileName,
    CAST(size / 128.0 AS DECIMAL(18, 2)) AS SizeMB,
    CAST(
        CASE
            WHEN type_desc = N'ROWS'
                THEN FILEPROPERTY(name, 'SpaceUsed') / 128.0
            ELSE NULL
        END
        AS DECIMAL(18, 2)
    ) AS DataUsedMB,
    CAST(
        CASE
            WHEN type_desc = N'ROWS'
                THEN (size - FILEPROPERTY(name, 'SpaceUsed')) / 128.0
            ELSE NULL
        END
        AS DECIMAL(18, 2)
    ) AS FreeInsideDataFileMB,
    growth AS GrowthValue,
    is_percent_growth AS IsPercentGrowth,
    max_size AS MaxSizeValue
FROM sys.database_files
ORDER BY file_id;
```

Log-Nutzung getrennt pruefen:

```sql
USE [BIDWAX_old];

SELECT
    DB_NAME() AS DatabaseName,
    CAST(total_log_size_in_bytes / 1048576.0 AS DECIMAL(18, 2)) AS TotalLogSizeMB,
    CAST(used_log_space_in_bytes / 1048576.0 AS DECIMAL(18, 2)) AS UsedLogSpaceMB,
    CAST(used_log_space_in_percent AS DECIMAL(9, 2)) AS UsedLogSpacePct
FROM sys.dm_db_log_space_usage;

SELECT
    name AS DatabaseName,
    recovery_model_desc,
    log_reuse_wait_desc
FROM sys.databases
WHERE name = DB_NAME();
```

Wenn mehrere Datenbanken auf einem vollen Laufwerk liegen, ist diese bestehende
Repo-Abfrage der bessere Einstieg:

- [DatabaseShrinkCandidateReview.md](SQLScripts/DatabaseShrinkCandidateReview.md)

Fuer dauerhaftes Monitoring der Groessenentwicklung:

- [DatabaseSizeGrowthMonitor](../72_SQLAgent_Jobs_Alerts/Solutions/DatabaseSizeGrowthMonitor/README.md)

## Zielgroesse richtig waehlen

Eine Zielgroesse sollte nicht "so klein wie moeglich" sein, sondern
"realistisch plus Reserve".

Fuer Datenfiles:

```text
Zielgroesse = belegter Platz + Wachstumsreserve + Betriebsreserve
```

Beispiel:

```text
Aktuelle Datei:        400 GB
Belegt:                180 GB
Sinnvolle Reserve:      40 GB
Zielgroesse:           220 GB
```

Wenn die Anwendung in den naechsten Tagen wieder 100 GB schreiben wird, ist ein
Ziel von 220 GB zu klein. Dann kommt Autogrowth zur unguenstigsten Zeit zurueck.

Fuer Logfiles:

```text
Zielgroesse = Logbedarf des groessten normalen Betriebsfensters + Reserve
```

Logbedarf entsteht zum Beispiel durch:

- groesste ETL-Batches
- groesste Indexwartung
- Zeitraum bis zum naechsten Log-Backup
- lange Transaktionen
- Bulk Loads
- Rebuilds grosser Indizes

## Ausfuehrung: kontrollierter Datenfile-Shrink

Wenn ein Datenfile wirklich schrumpfen soll, ist ein schrittweises Vorgehen oft
besser als ein einziger grosser Sprung. Man kann nach jedem Schritt abbrechen,
messen und bei Bedarf spaeter weitermachen.

Beispiel in 10-GB-Schritten:

```sql
USE [BIDWAX_old];

DECLARE
    @LogicalFileName SYSNAME = N'BIDWAX',
    @TargetMB INT = 223159,
    @StepMB INT = 10240,
    @CurrentMB INT,
    @NextTargetMB INT,
    @Sql NVARCHAR(MAX);

SELECT @CurrentMB = CAST(size / 128.0 AS INT)
FROM sys.database_files
WHERE name = @LogicalFileName;

WHILE @CurrentMB > @TargetMB
BEGIN
    SET @NextTargetMB =
        CASE
            WHEN @CurrentMB - @StepMB < @TargetMB THEN @TargetMB
            ELSE @CurrentMB - @StepMB
        END;

    RAISERROR('Shrink %s von %d MB auf %d MB', 10, 1, @LogicalFileName, @CurrentMB, @NextTargetMB) WITH NOWAIT;

    SET @Sql = N'DBCC SHRINKFILE (N'''
        + REPLACE(@LogicalFileName, '''', '''''')
        + N''', '
        + CONVERT(NVARCHAR(20), @NextTargetMB)
        + N') WITH NO_INFOMSGS;';

    EXEC sys.sp_executesql @Sql;

    SELECT @CurrentMB = CAST(size / 128.0 AS INT)
    FROM sys.database_files
    WHERE name = @LogicalFileName;
END;
```

Hinweise:

- Nicht mehrere Dateien derselben Datenbank parallel shrinken.
- Wartungsfenster mit geringer Last waehlen.
- Log-Backups waehrend langer Shrinks im Blick behalten.
- Bei AG/Log Shipping/Replikation Redo/Send/Delivery-Latenzen pruefen.
- Wenn der Shrink kaum Fortschritt macht, nicht blind weiterlaufen lassen:
  Blocker und Zielgroesse pruefen.

## Ausfuehrung: kontrollierter Logfile-Shrink

Bei Logfiles zuerst Ursache beheben. Shrink ohne Log-Trunkierung bringt wenig.

In `FULL` oder `BULK_LOGGED`:

```sql
BACKUP LOG [BIDWAX_old]
TO DISK = N'X:\SQLBackups\BIDWAX_old_ManualBeforeShrink.trn'
WITH INIT, COMPRESSION;

USE [BIDWAX_old];
DBCC SHRINKFILE (N'BIDWAX_log', 8192) WITH NO_INFOMSGS;
```

In `SIMPLE`:

```sql
USE [BIDWAX_old];
CHECKPOINT;
DBCC SHRINKFILE (N'BIDWAX_log', 8192) WITH NO_INFOMSGS;
```

Nicht leichtfertig:

```sql
ALTER DATABASE [BIDWAX_old] SET RECOVERY SIMPLE;
```

Das kann Point-in-Time-Recovery-Anforderungen verletzen und Backup-Ketten
beeinflussen. Nur machen, wenn die Recovery-Anforderung das erlaubt und danach
die Backup-Strategie sauber neu gestartet wird.

## Fortschritt und Blocker beobachten

Laufenden Shrink finden:

```sql
SELECT
    r.session_id,
    r.command,
    r.status,
    r.percent_complete,
    CAST(r.estimated_completion_time / 1000.0 / 60.0 AS DECIMAL(18, 2)) AS EstimatedMinutesRemaining,
    r.wait_type,
    r.wait_time,
    r.blocking_session_id,
    r.reads,
    r.writes,
    r.logical_reads,
    t.text AS RunningSql
FROM sys.dm_exec_requests AS r
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) AS t
WHERE r.command LIKE N'DbccFilesCompact%'
   OR t.text LIKE N'%SHRINKFILE%';
```

Blocker anzeigen:

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

Snapshot-Transaktionen koennen Shrink blockieren:

```sql
SELECT
    transaction_id,
    transaction_sequence_num,
    first_snapshot_sequence_num,
    elapsed_time_seconds,
    session_id
FROM sys.dm_tran_active_snapshot_database_transactions
ORDER BY elapsed_time_seconds DESC;
```

Log-Wiederverwendung pruefen:

```sql
SELECT
    name,
    recovery_model_desc,
    log_reuse_wait_desc
FROM sys.databases
WHERE name = N'BIDWAX_old';
```

## Was passiert beim Abbrechen?

Ein Shrink ist nicht wie ein einzelnes grosses User-Update zu verstehen, das am
Ende vollstaendig committet oder komplett zurueckgerollt wird. Die Arbeit
erfolgt intern in vielen kleineren Schritten. Wenn ein Shrink abgebrochen wird,
kann bereits erledigte Arbeit erhalten bleiben. Danach unbedingt neu messen:

```sql
USE [BIDWAX_old];

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

## Nacharbeiten nach einem Datenfile-Shrink

### 1. Groessen und freien Platz erneut messen

```sql
USE [BIDWAX_old];

SELECT
    name,
    type_desc,
    physical_name,
    CAST(size / 128.0 AS DECIMAL(18, 2)) AS SizeMB,
    CAST(
        CASE
            WHEN type_desc = N'ROWS'
                THEN FILEPROPERTY(name, 'SpaceUsed') / 128.0
            ELSE NULL
        END
        AS DECIMAL(18, 2)
    ) AS DataUsedMB,
    CAST(
        CASE
            WHEN type_desc = N'ROWS'
                THEN (size - FILEPROPERTY(name, 'SpaceUsed')) / 128.0
            ELSE NULL
        END
        AS DECIMAL(18, 2)
    ) AS FreeInsideDataFileMB
FROM sys.database_files;
```

### 2. Indexfragmentierung messen

Bestehendes Repo-Skript:

- [IndexFragmentation.sql](../26_Indexes_Basics/SQLScripts/IndexFragmentation.sql)

Direkte Beispielabfrage:

```sql
USE [BIDWAX_old];

SELECT
    DB_NAME() AS DatabaseName,
    OBJECT_SCHEMA_NAME(ips.object_id) AS SchemaName,
    OBJECT_NAME(ips.object_id) AS TableName,
    i.name AS IndexName,
    ips.index_id,
    ips.avg_fragmentation_in_percent,
    ips.avg_page_space_used_in_percent,
    ips.page_count
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'SAMPLED') AS ips
INNER JOIN sys.indexes AS i
    ON i.object_id = ips.object_id
   AND i.index_id = ips.index_id
WHERE ips.index_id > 0
  AND ips.page_count >= 1000
ORDER BY ips.avg_fragmentation_in_percent DESC;
```

### 3. Indizes gezielt defragmentieren

Typischer Startpunkt, nicht blindes Gesetz:

| Befund | Aktion |
|---|---|
| Kleine Indizes, z. B. unter 1000 Pages | Meist ignorieren. |
| 5-30 Prozent Fragmentierung | Eher `ALTER INDEX ... REORGANIZE`. |
| Ab ca. 30 Prozent Fragmentierung | Eher `ALTER INDEX ... REBUILD`, wenn Platz und Wartungsfenster reichen. |
| Schlechte Page Density | Rebuild kann sinnvoller sein als reine Fragmentierungsbetrachtung. |
| Columnstore | Eigene Logik: Rowgroups, Deleted Rows, Delta Stores beachten. |

Beispiele:

```sql
ALTER INDEX [IX_Name] ON [schema].[table] REORGANIZE;
```

```sql
ALTER INDEX [IX_Name] ON [schema].[table] REBUILD
WITH (SORT_IN_TEMPDB = ON);
```

Bei Enterprise/geeigneten Editionen und Versionen kann Online-Rebuild eine
Option sein:

```sql
ALTER INDEX [IX_Name] ON [schema].[table] REBUILD
WITH (ONLINE = ON, SORT_IN_TEMPDB = ON);
```

Achtung: Ein Rebuild braucht Platz. Je nach Index, Sortierung und Optionen
kann er im Datenfile und/oder in `tempdb` erheblich Platz benoetigen. Das kann
den gerade gewonnenen Speicher teilweise wieder verbrauchen.

### 4. Statistiken aktualisieren

Ein Index-Rebuild aktualisiert die Statistik des neu aufgebauten Indexes.
`REORGANIZE` tut das nicht. Spaltenstatistiken und nicht rebuildete
Statistiken bleiben ebenfalls ein Thema.

Nach groesseren Datenbewegungen oder Loeschaktionen:

```sql
EXEC sys.sp_updatestats;
```

Oder gezielt:

```sql
UPDATE STATISTICS [schema].[table] [StatisticOrIndexName] WITH FULLSCAN;
```

Nicht immer ist `FULLSCAN` sinnvoll. Bei sehr grossen Tabellen kann ein
gezielter Sample-Ansatz besser in das Wartungsfenster passen.

### 5. Filegroessen und Autogrowth neu setzen

Nach einem Shrink sollte die Datei nicht mit Mini-Autogrowth oder Prozentwerten
zurueckgelassen werden.

```sql
ALTER DATABASE [BIDWAX_old]
MODIFY FILE
(
    NAME = N'BIDWAX',
    FILEGROWTH = 1024MB
);
```

Fuer Logfiles lieber feste MB/GB-Schritte als Prozentwerte verwenden:

```sql
ALTER DATABASE [BIDWAX_old]
MODIFY FILE
(
    NAME = N'BIDWAX_log',
    FILEGROWTH = 1024MB
);
```

Wenn klar ist, dass die Datei wieder wachsen wird, ist es oft besser, sie
kontrolliert auf eine sinnvolle Steady-State-Groesse zu setzen, statt sie
zuerst klein zu machen und spaeter per Autogrowth wachsen zu lassen.

### 6. Log-Backup und VLFs pruefen

Nach grossem Datenfile-Shrink in `FULL` koennen die Log-Backups gross sein.
Log-Backup-Kette und Joblaufzeiten pruefen.

VLFs anzeigen:

```sql
USE [BIDWAX_old];

SELECT
    file_id,
    vlf_begin_offset,
    vlf_size_mb,
    vlf_sequence_number,
    vlf_active
FROM sys.dm_db_log_info(DB_ID())
ORDER BY file_id, vlf_begin_offset;
```

Wenn eine Logdatei nach einem Vorfall stark gewachsen ist, ist oft dieses
Muster sinnvoll:

1. Ursache beheben.
2. Log-Backup oder `CHECKPOINT`, je nach Recovery Model.
3. Log kontrolliert shrinken.
4. Log anschliessend auf realistische Zielgroesse manuell growen.
5. `FILEGROWTH` auf sinnvolle feste Groesse setzen.

### 7. HA/DR und Monitoring pruefen

Nach einem grossen Shrink:

- Availability Group Synchronisation und Redo Queue pruefen.
- Log Shipping Laufzeiten und Restore-Latenz pruefen.
- Replikation/CDC-Latenz pruefen.
- Backup-Jobs und Log-Backup-Groessen pruefen.
- Disk Alerts auf Daten- und Log-Volumes neu bewerten.
- Query Store oder wichtige Laufzeitreports nach Performance-Regressions
  pruefen.

### 8. `AUTO_SHRINK` deaktivieren

```sql
ALTER DATABASE [BIDWAX_old] SET AUTO_SHRINK OFF;
```

`AUTO_SHRINK ON` sollte eine bewusste Ausnahme sein. Fuer normale OLTP-, DWH-
oder ETL-Datenbanken ist es praktisch immer falsch.

## Nacharbeiten nach einem Logfile-Shrink

Bei Logfiles stehen andere Punkte im Vordergrund:

1. `log_reuse_wait_desc` muss wieder normal sein.
2. Log-Backup-Job muss laufen.
3. Datei muss gross genug fuer normale Lastfenster sein.
4. `FILEGROWTH` muss gross genug sein, um haeufiges Wachstum zu vermeiden.
5. VLF-Anzahl sollte plausibel sein.
6. Recovery Model und Backup-Strategie muessen zur RPO/RTO passen.

Pruefen:

```sql
SELECT
    d.name,
    d.recovery_model_desc,
    d.log_reuse_wait_desc,
    CAST(ls.total_log_size_in_bytes / 1048576.0 AS DECIMAL(18, 2)) AS TotalLogSizeMB,
    CAST(ls.used_log_space_in_bytes / 1048576.0 AS DECIMAL(18, 2)) AS UsedLogSpaceMB,
    CAST(ls.used_log_space_in_percent AS DECIMAL(9, 2)) AS UsedLogSpacePct
FROM sys.databases AS d
CROSS JOIN sys.dm_db_log_space_usage AS ls
WHERE d.name = DB_NAME();
```

Hinweis: `sys.dm_db_log_space_usage` liefert Werte fuer die aktuelle Datenbank.
Also vorher `USE [Datenbankname]` setzen.

## Entscheidungsbaum

```text
Ist das Laufwerk voll?
  |
  +-- Nein:
  |     Shrink in der Regel nicht ausfuehren.
  |
  +-- Ja:
        Welche Datei belegt das Laufwerk?
          |
          +-- Logfile:
          |     log_reuse_wait_desc pruefen.
          |     Ursache beheben.
          |     Log backup/checkpoint.
          |     Nur wenn dauerhaft zu gross: DBCC SHRINKFILE.
          |     Danach Log sinnvoll vorsizen und FILEGROWTH setzen.
          |
          +-- Datenfile:
                Wurde dauerhaft viel geloescht/archiviert?
                  |
                  +-- Nein:
                  |     Ist die DB fachlich abgeschlossen und kuenftig
                  |     nur noch lesend?
                  |       |
                  |       +-- Nein:
                  |       |     Besser Storage erweitern, Datei verschieben,
                  |       |     Daten archivieren oder Wachstum akzeptieren.
                  |       |
                  |       +-- Ja:
                  |             Shrink kann sinnvoll sein, wenn intern
                  |             genug freier Platz vorhanden ist.
                  |
                  +-- Ja:
                        Zielgroesse mit Reserve berechnen.
                        Backup/HA/Jobs pruefen.
                        In Wartungsfenster shrinken.
                        Danach Fragmentierung, Stats, Autogrowth,
                        Backups und Monitoring pruefen.
```

## Typische Fehler

| Fehler | Warum problematisch |
|---|---|
| `DBCC SHRINKDATABASE` pauschal auf produktiven DBs | Zu grob, schwer steuerbar, oft mit viel Nebenwirkung. |
| Shrink als regelmaessiger Job | Erzeugt Grow-Shrink-Zyklus, Fragmentierung und Last. |
| Datenfile auf knapp ueber UsedMB shrinken | Naechster normaler Schreibvorgang triggert Autogrowth. |
| Archivdatenbank vor dem finalen Shrink bereits dauerhaft `READ_ONLY` setzen | Der Shrink und die Nacharbeiten sind administrative Aenderungen; meist erst aufraeumen/shrinken/optimieren, danach `READ_ONLY`. |
| Logfile shrinken, ohne `log_reuse_wait_desc` zu pruefen | Shrink bringt wenig oder gar nichts. |
| Recovery Model auf `SIMPLE` setzen, ohne RPO zu klaeren | Point-in-Time-Recovery kann verloren gehen. |
| Nach Datenfile-Shrink keine Indexwartung | Performance kann deutlich schlechter werden. |
| Nach Shrink kein Autogrowth Review | Datei waechst spaeter unkontrolliert oder in zu kleinen Schritten. |
| Mehrere Shrinks parallel | Interne Metadaten- und I/O-Konkurrenz, laengere Laufzeiten. |

## Gute Alternativen zum Shrink

- Datei behalten und als Reserve fuer normales Wachstum verwenden.
- Daten sauber archivieren und Wachstumstrend ueberwachen.
- Partitionierung nutzen und alte Partitionen per Switch/Truncate entfernen.
- Datenkompression oder Indexkompression pruefen.
- Unbenutzte/duplizierte Indizes entfernen.
- Grosse Tabellen und Indizes auf andere Filegroups/Volumes verschieben.
- Storage erweitern oder Daten-/Logfiles sauber auf getrennte Volumes legen.
- Temporaere alte Datenbank wirklich droppen oder auf guenstigeren Storage
  auslagern, statt sie produktionsnah mitzuschleppen.

## Betriebs-Checkliste

Vorher:

- Aktuelles Backup vorhanden und Ruecksicherungskonzept klar.
- Betroffenes Volume und betroffene Datei identifiziert.
- Datenfile vs. Logfile geklaert.
- UsedMB, FreeInsideFileMB, LogUsedMB gemessen.
- Zielgroesse mit Reserve berechnet.
- Geklaert, ob die Datenbank aktiv bleibt oder fachlich abgeschlossen ist und
  kuenftig nur noch gelesen wird.
- Recovery Model und Log-Backup-Kette verstanden.
- `log_reuse_wait_desc` geprueft.
- Wartungsfenster abgestimmt.
- HA/DR-Auswirkungen bedacht.

Waehrenddessen:

- `sys.dm_exec_requests.percent_complete` beobachten.
- Waits und Blocker beobachten.
- Logwachstum und freie Disk pruefen.
- Nicht mehrere Shrinks derselben DB parallel starten.
- Bei sehr langer Laufzeit in Etappen arbeiten.

Nachher:

- Datei- und Laufwerksgroessen erneut messen.
- Indexfragmentierung und Page Density messen.
- Indizes gezielt reorganisieren/rebuilden.
- Statistiken aktualisieren, wenn noetig.
- Log-Backup pruefen.
- VLFs und Loggroesse plausibilisieren.
- Filegrowth auf feste, sinnvolle Groesse setzen.
- `AUTO_SHRINK OFF` sicherstellen.
- Bei abgeschlossener Archivdatenbank optional `READ_ONLY` setzen.
- Monitoring/Growth-Trend aktualisieren.

## Quellen und weiterfuehrende Links

- Microsoft Learn: [DBCC SHRINKFILE](https://learn.microsoft.com/en-us/sql/t-sql/database-console-commands/dbcc-shrinkfile-transact-sql)
- Microsoft Learn: [Manage transaction log file size](https://learn.microsoft.com/en-us/sql/relational-databases/logs/manage-the-size-of-the-transaction-log-file)
- Microsoft Learn: [Considerations for autogrow and autoshrink](https://learn.microsoft.com/en-us/troubleshoot/sql/database-engine/database-file-operations/considerations-autogrow-autoshrink)
- Microsoft Learn: [Optimize index maintenance](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/reorganize-and-rebuild-indexes)
- Repo: [DatabaseShrinkCandidateReview](SQLScripts/DatabaseShrinkCandidateReview.md)
- Repo: [DatabaseSizeGrowthMonitor](../72_SQLAgent_Jobs_Alerts/Solutions/DatabaseSizeGrowthMonitor/README.md)
