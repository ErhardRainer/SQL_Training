# FAQ

## Datenbank- und Tabellengroessen ermitteln

### Wie ermittle ich die Groesse aller Datenbanken auf einer SQL-Server-Instanz?

Nutze [DatabaseSizeInventory.md](20_Create_Database/SQLScripts/DatabaseSizeInventory.md). Der Artikel beschreibt die Abfrage [DatabaseSizeInventory.sql](20_Create_Database/SQLScripts/DatabaseSizeInventory.sql), die `sys.databases` und `sys.master_files` auswertet und pro Datenbank Daten-, Log-, sonstige und gesamte Dateigroessen ausgibt.

### Wie ermittle ich die Groesse aller Tabellen einer Datenbank?

Nutze [TableSizeInventory.md](20_Create_Database/SQLScripts/TableSizeInventory.md). Der Artikel beschreibt die Abfrage [TableSizeInventory.sql](20_Create_Database/SQLScripts/TableSizeInventory.sql), die in der aktuell ausgewaehlten Datenbank `sys.tables`, `sys.schemas` und `sys.dm_db_partition_stats` nutzt und pro Tabelle `ReservedMB`, `UsedMB`, `DataMB`, `IndexMB` und `UnusedMB` ausgibt.

### Die Festplatte ist fast voll: Welche Datenbanken sollte ich zuerst fuer Shrink pruefen?

Nutze [DatabaseShrinkCandidateReview.md](20_Create_Database/SQLScripts/DatabaseShrinkCandidateReview.md). Der Artikel beschreibt die Abfrage [DatabaseShrinkCandidateReview.sql](20_Create_Database/SQLScripts/DatabaseShrinkCandidateReview.sql), bei der du mit `@TargetVolumeRoot` das betroffene Laufwerk oder Volume vorgibst, z. B. `L:\`. Nur Dateien auf diesem Pfad werden bewertet; Logdateien und Datenfiles werden getrennt priorisiert und vorsichtige `DBCC SHRINKFILE`-Vorlagen werden erzeugt, ohne sie auszufuehren.

### Wie kann ich eine Datenbank shrinken?

Die ausfuehrliche Theorie, Entscheidungslogik und Skript-Uebersicht steht in [Shrink.md](Shrink.md).

Shrink ist eine Ausnahmehandlung, keine regelmaessige Wartungsstrategie. Pruefe zuerst mit [DatabaseShrinkCandidateReview.sql](20_Create_Database/SQLScripts/DatabaseShrinkCandidateReview.sql), [DatabaseShrinkAnalysis.sql](20_Create_Database/SQLScripts/DatabaseShrinkAnalysis.sql), [ListLogUsageOfAllDB.sql](19_Transaktions/SQLScripts/ListLogUsageOfAllDB.sql) oder [LogReuseWaitSnapshot.sql](19_Transaktions/SQLScripts/LogReuseWaitSnapshot.sql), ob wirklich freier Log- oder Datenfile-Platz zurueckgewonnen werden kann und ob `log_reuse_wait_desc` einen Shrink blockiert.

Wenn du nur eine konkrete Datenbank beurteilen willst, nutze [DatabaseShrinkAnalysis.md](20_Create_Database/SQLScripts/DatabaseShrinkAnalysis.md). Das Skript [DatabaseShrinkAnalysis.sql](20_Create_Database/SQLScripts/DatabaseShrinkAnalysis.sql) arbeitet mit `@DatabaseName`, optional mit `@TargetVolumeRoot`, analysiert Daten- und Logdateien dateischarf und erzeugt `DBCC SHRINKFILE`-Vorlagen, ohne sie auszufuehren. Fuer `FULL` und `BULK_LOGGED` bewertet es zusaetzlich, ob ein frisches Logbackup vorhanden ist.

Fuer Datenbanken im Recovery-Modell `SIMPLE` verwendest du die Skripte aus [19_Transaktions/SQLScripts](19_Transaktions/SQLScripts/):

- Genau eine Log-Datei: [ShrinkSimple.sql](19_Transaktions/SQLScripts/ShrinkSimple.sql). Das Skript verarbeitet SIMPLE-Datenbanken mit genau einer Log-Datei, fuehrt `CHECKPOINT` aus, berechnet eine sichere Zielgroesse und ruft `DBCC SHRINKFILE` nur bei ausreichend freiem Log-Platz auf.
- Mehrere Log-Dateien: [ShrinkSimple_multiple_Files.sql](19_Transaktions/SQLScripts/ShrinkSimple_multiple_Files.sql). Dieses Skript ist fuer SIMPLE-Datenbanken mit mehr als einer Log-Datei gedacht. Es bewertet jede Logdatei separat, prueft aktive Transaktionen sowie Holdup-Reasons und nutzt VLF-Informationen fuer realistischere Zielgroessen.
- Einzelne gezielte Datenbank mit Recovery-Wechsel: [SetDBSimple.sql](19_Transaktions/SQLScripts/SetDBSimple.sql). Dieses Skript setzt die angegebene Datenbank dauerhaft auf `SIMPLE`, fuehrt `CHECKPOINT` aus und shrinkt danach die Log-Datei. Das ist nur sinnvoll, wenn der Recovery-Wechsel fachlich gewollt ist; bei produktiven FULL-Datenbanken vorher Backup-Strategie und Restore-Anforderungen pruefen.

Fuer Datenbanken, die nicht im Recovery-Modell `SIMPLE` laufen, also typischerweise `FULL` oder `BULK_LOGGED`, nicht einfach `ShrinkSimple.sql` ausfuehren. In diesen Modellen wird Log-Platz erst durch ein Log-Backup wiederverwendbar. Der sichere Ablauf ist:

1. Mit [LogReuseWaitSnapshot.sql](19_Transaktions/SQLScripts/LogReuseWaitSnapshot.sql) oder `sys.databases.log_reuse_wait_desc` pruefen, ob offene Transaktionen, Replikation, HADR, fehlende Log-Backups oder andere Ursachen die Log-Trunkierung verhindern.
2. Falls die Datenbank in `FULL` oder `BULK_LOGGED` bleiben soll, zuerst ein regulaeres Log-Backup durchfuehren und die Backup-Kette nicht unterbrechen.
3. Anschliessend einen gezielten Log-Shrink ausfuehren, z. B. mit [usp_LogShrink.sql](71_BackupRestore_Strategies/usp_LogShrink.sql). Die Prozedur prueft Recovery-Modell und Backup-Voraussetzungen, misst Before/After-Werte und kann mit `@Debug = 1` zuerst als Dry-Run genutzt werden.
4. Nach dem Shrink Autogrowth und Zielgroesse pruefen. Wenn die Log-Datei direkt wieder waechst, wurde nicht die Ursache geloest, sondern nur kurzfristig Platz freigemacht.

Datenfile-Shrinks sind noch vorsichtiger zu behandeln als Log-Shrinks, weil sie Fragmentierung und Laufzeitlast erzeugen koennen. Wenn Datenfiles betroffen sind, nutze zuerst [DatabaseShrinkCandidateReview.sql](20_Create_Database/SQLScripts/DatabaseShrinkCandidateReview.sql) fuer eine serverweite priorisierte Bewertung oder [DatabaseShrinkAnalysis.sql](20_Create_Database/SQLScripts/DatabaseShrinkAnalysis.sql) fuer eine einzelne Datenbank. Fuehre die erzeugten `DBCC SHRINKFILE`-Vorlagen nur gezielt in einem Wartungsfenster aus.
