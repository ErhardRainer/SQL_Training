# FAQ

## Datenbank- und Tabellengroessen ermitteln

### Wie ermittle ich die Groesse aller Datenbanken auf einer SQL-Server-Instanz?

Nutze [DatabaseSizeInventory.md](20_Create_Database/SQLScripts/DatabaseSizeInventory.md). Der Artikel beschreibt die Abfrage [DatabaseSizeInventory.sql](20_Create_Database/SQLScripts/DatabaseSizeInventory.sql), die `sys.databases` und `sys.master_files` auswertet und pro Datenbank Daten-, Log-, sonstige und gesamte Dateigroessen ausgibt. Sie gibt keine Auskünfte über den Füllstand der Datenbanken. 

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

## Tabellen und Datenbanken leeren (DELETE/TRUNCATE)

### Wie leere ich alle Tabellen einer Datenbank oder eines Schemas komplett?

Es gibt dafuer zwei Skripte in [06_Delete/SQLScripts](06_Delete/SQLScripts/), die beide standardmaessig im sicheren Preview-Modus laufen (`@PreviewOnly = 1`, kein Approval-Token gesetzt):

- [TruncateAllTablesInSchema.md](06_Delete/SQLScripts/TruncateAllTablesInSchema.md) – nutzt `TRUNCATE TABLE`. Schnell, minimal geloggt, setzt IDENTITY zurueck. Deaktiviert dazu alle Foreign Keys per `NOCHECK CONSTRAINT`, leert die Tabellen und reaktiviert die FKs anschliessend. Freischaltung nur mit `@ApprovalToken = 'TRUNCATE-ALL-CONFIRMED'`.
- [DeleteAllTablesInSchema.md](06_Delete/SQLScripts/DeleteAllTablesInSchema.md) – nutzt `DELETE FROM`. Langsamer, vollstaendig geloggt, IDENTITY bleibt erhalten, Trigger werden ausgeloest. Berechnet die Loeschreihenfolge automatisch aus dem FK-Graphen (Kind vor Elternteil) statt FKs zu deaktivieren. Optional per `@UseTransaction = 1` komplett rollbackfaehig. Freischaltung nur mit `@ApprovalToken = 'DELETE-ALL-CONFIRMED'`.

Beide Skripte unterstuetzen `@SchemaFilter` (nur ein Schema) und `@TableList` (nur bestimmte Tabellen). Eine ausfuehrliche Gegenueberstellung samt Entscheidungshilfe steht im Abschnitt [Gemeinsamkeiten und Unterschiede](06_Delete/SQLScripts/DeleteAllTablesInSchema.md#gemeinsamkeiten-und-unterschiede).

### TRUNCATE oder DELETE – welches Skript passt fuer meinen Fall?

| Szenario | Empfehlung |
|---|---|
| Testdatenbank-Reset, Geschwindigkeit wichtig | [TruncateAllTablesInSchema.sql](06_Delete/SQLScripts/TruncateAllTablesInSchema.sql) |
| IDENTITY-Zaehler sollen erhalten bleiben | [DeleteAllTablesInSchema.sql](06_Delete/SQLScripts/DeleteAllTablesInSchema.sql) |
| Trigger muessen beim Leeren ausgeloest werden (z. B. Audit-Log) | [DeleteAllTablesInSchema.sql](06_Delete/SQLScripts/DeleteAllTablesInSchema.sql) |
| Rollback der gesamten Bereinigung muss moeglich sein | [DeleteAllTablesInSchema.sql](06_Delete/SQLScripts/DeleteAllTablesInSchema.sql) mit `@UseTransaction = 1` |
| Zirkulaere FK-Beziehungen vorhanden | [TruncateAllTablesInSchema.sql](06_Delete/SQLScripts/TruncateAllTablesInSchema.sql) |
| Grosse Tabellen mit Millionen von Zeilen | [TruncateAllTablesInSchema.sql](06_Delete/SQLScripts/TruncateAllTablesInSchema.sql) |

### Wie loesche ich grosse Datenmengen kontrolliert in Portionen, ohne Log/Blocking zu sprengen?

Nutze [BatchedDeleteTemplate.md](06_Delete/SQLScripts/BatchedDeleteTemplate.md) fuer eine generische `TOP (N)`-Schleife, [DeleteBatchProgressTemplate.md](06_Delete/SQLScripts/DeleteBatchProgressTemplate.md) fuer dieselbe Technik mit Fortschrittsprotokoll, oder [DeleteByWindowingTemplate.md](06_Delete/SQLScripts/DeleteByWindowingTemplate.md) und [DeleteTopLoopWithOrder.md](06_Delete/SQLScripts/DeleteTopLoopWithOrder.md), wenn eine deterministische Reihenfolge innerhalb der Batches gebraucht wird.

### Wie pruefe ich vorher, welche Zeilen ein DELETE betreffen wuerde – ohne etwas zu loeschen?

Nutze [SafeDeletePreview.md](06_Delete/SQLScripts/SafeDeletePreview.md) oder [DeleteImpactPreviewByKey.md](06_Delete/SQLScripts/DeleteImpactPreviewByKey.md) fuer eine reine Vorschau der betroffenen Zeilen anhand von Schluesselwerten. Fuer die Auswirkung auf abhaengige Tabellen (Kaskaden ueber FKs) nutze [CascadingDeleteImpactCheck.md](06_Delete/SQLScripts/CascadingDeleteImpactCheck.md). Fuer einen Snapshot der zu loeschenden Kandidaten vor einer groesseren Aktion nutze [DeleteCandidateSnapshot.md](06_Delete/SQLScripts/DeleteCandidateSnapshot.md).

### Wie sichere ich geloeschte Zeilen ab, bevor sie endgueltig weg sind (Audit/Archiv)?

- [DeleteWithOutputAudit.md](06_Delete/SQLScripts/DeleteWithOutputAudit.md) – schreibt geloeschte Zeilen ueber die `OUTPUT`-Klausel in eine Audit-Tabelle.
- [DeleteAuditMirrorPattern.md](06_Delete/SQLScripts/DeleteAuditMirrorPattern.md) – spiegelt geloeschte Zeilen dauerhaft in eine Mirror-/Audit-Tabelle.
- [DeleteArchiveBeforeRemove.md](06_Delete/SQLScripts/DeleteArchiveBeforeRemove.md) – archiviert Zeilen vor dem eigentlichen Loeschen in eine separate Archivtabelle.
- [DeleteArchiveSwitchPattern.md](06_Delete/SQLScripts/DeleteArchiveSwitchPattern.md) – nutzt Partition-Switching, um grosse Datenmengen ohne klassisches `DELETE` auszulagern.

### Wie gehe ich mit Loeschungen ueber Joins oder mehrere Tabellen sicher um?

Nutze [DeleteJoinSafetyHarness.md](06_Delete/SQLScripts/DeleteJoinSafetyHarness.md) als abgesichertes Muster fuer `DELETE ... FROM` mit Join, inklusive Vorschau und Sicherheitspruefungen gegen ungewollte Treffer.

### Wie teste ich ein DELETE-Skript, ohne ein Risiko fuer echte Daten einzugehen?

Nutze [DeleteRollbackDrill.md](06_Delete/SQLScripts/DeleteRollbackDrill.md) als Uebungsmuster mit expliziter Transaktion und `ROLLBACK`, um DELETE-Logik gefahrlos durchzuspielen, bevor sie produktiv mit `COMMIT` laeuft.

### Wie richte ich Soft Delete statt eines echten Loeschens ein?

Nutze [SoftDeleteMigrationTemplate.md](06_Delete/SQLScripts/SoftDeleteMigrationTemplate.md) fuer die generelle Migration auf ein Soft-Delete-Muster oder [SoftDeleteFlagMigration.md](06_Delete/SQLScripts/SoftDeleteFlagMigration.md), wenn konkret ein `IsDeleted`-Flag (oder aehnlich) eingefuehrt werden soll, inklusive Anpassung bestehender Abfragen/Indizes.

### Wo finde ich die Theorie zu DELETE, TRUNCATE, Batching, Trigger-Verhalten etc.?

Die vollstaendige thematische Uebersicht mit Notebooks, Videos und Docs-Links steht in [06_Delete.md](06_Delete/06_Delete.md), inklusive Abschnitten zu `DELETE ... FROM` (Join-Delete), Duplikate loeschen per `ROW_NUMBER`, Transaktionen/`XACT_ABORT`, Isolation Levels/Locks, `TRUNCATE` vs. `DELETE`, Temporal/CDC/Change Tracking sowie Anti-Patterns.
