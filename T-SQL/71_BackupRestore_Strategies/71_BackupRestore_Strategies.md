# T-SQL Backup & Restore – Strategien  
*Backup-Typen, Recovery-Modelle, Point-in-Time-Restores, Log-Ketten & Copy-Only*

## 1 | Begriffsdefinition

| SQL-Term | Beschreibung |
|---|---|
| **Recovery Model** | Steuert Log-Verhalten & Wiederherstellbarkeit: **FULL**, **SIMPLE**, **BULK_LOGGED**. |
| **Full Backup** | Vollständige Kopie der DB inkl. Teile des Logs zur Konsistenz; Basis für **Differential**. |
| **Differential Backup** | Änderungen seit **letztem Full** (Differential Base). Schneller restore: Full + letztes Diff (+ Logs, falls FULL/BULK_LOGGED). |
| **Transaction Log Backup** | Sichert Log-Sequenz (**LSN-Chain**) – Voraussetzung für Point-in-Time & Log-Verkürzung im **FULL/BULK_LOGGED**. |
| **Copy-Only Backup** | Spezial-Backup, das **Differential Base nicht verändert** (Full) bzw. **Log-Chain nicht beeinflusst** (Log). |
| **Tail-Log Backup** | Sichert **letzten Log-Abschnitt** bei Ausfall **vor** RESTORE (sofern Log zugreifbar). |
| **LSN / Log Chain** | Log Sequence Number – lückenlose Kette an Log-Backups; Lücken → kein vollständiger Restore. |
| **PITR (Point-in-Time)** | Wiederherstellung bis `STOPAT` (Zeit) oder `STOPATMARK` (markierte Transaktion) mit Full/Diff/Logs. |
| **NORECOVERY/RECOVERY/STANDBY** | RESTORE-Modi in Ketten: **NORECOVERY** hält DB „restorefähig“, **RECOVERY** schließt ab, **STANDBY** = read-only mit Undo-File. |
| **File/Filegroup Backup** | Teilbackups großer DBs – kombiniert mit **Piecemeal Restore**. |
| **Page Restore** | Selektives Wiederherstellen korrupter **Daten-Seiten** (8 KB) aus Backups. |
| **Striped Backup** | Parallel auf mehrere Dateien (Medienfamilien) schreiben → Durchsatz/Redundanz. |
| **Backup Compression** | Komprimiert Backups (CPU vs. I/O-Trade-off). |
| **Backup Encryption** | Verschlüsselt Backups (Zertifikat/Asym. Key); **TDE** erfordert Schlüssel/Cert beim Restore. |
| **VERIFYONLY/CHECKSUM** | `RESTORE VERIFYONLY`/`WITH CHECKSUM` – **Erkennungs**-, nicht **Korrektur**-Prüfungen. |
| **Backup to URL** | Sicherung nach **Azure Blob Storage** (`TO URL`/`CREDENTIAL`/Managed Identity). |
| **msdb-Historie** | Backup-Metadaten: `msdb.dbo.backupset`, `backupmediafamily`, `backupfile`. |
| **RPO/RTO** | Recovery Point/Time Objective – definiert **Intervall** der Backups und **Restore-Zeit**. |

---

## 2 | Struktur (Backup-Themen)

### 2.1 | Planung: RPO/RTO, Topologien & Grundmuster
> **Kurzbeschreibung:** Ziele definieren, passende Recovery-Modelle & Backup-Kombinationen auswählen.

- 📓 **Notebook:**  
  [`08_01_backup_planning_rpo_rto.ipynb`](08_01_backup_planning_rpo_rto.ipynb)
- 🎥 **YouTube:**  
  - [SQL Server Backup Strategy Overview](https://www.youtube.com/results?search_query=sql+server+backup+strategy+overview)
- 📘 **Docs:**  
  - [Backup Overview (SQL Server)](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/back-up-and-restore-of-sql-server-databases)

---

### 2.2 | Recovery-Modelle: FULL, SIMPLE, BULK_LOGGED
> **Kurzbeschreibung:** Log-Verhalten, Bulk-Operationen, Wechselwirkungen mit Log-Backups.

- 📓 **Notebook:**  
  [`08_02_recovery_models_basics.ipynb`](08_02_recovery_models_basics.ipynb)
- 🎥 **YouTube:**  
  - [Recovery Models Explained](https://www.youtube.com/results?search_query=sql+server+recovery+models)
- 📘 **Docs:**  
  - [Recovery Models](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/recovery-models-sql-server)

---

### 2.3 | Backup-Typen: Full, Differential, Log, Copy-Only
> **Kurzbeschreibung:** Differential-Base, Log-Kette, Einsatz von Copy-Only ohne Basis zu stören.

- 📓 **Notebook:**  
  [`08_03_backup_types_and_copyonly.ipynb`](08_03_backup_types_and_copyonly.ipynb)
- 🎥 **YouTube:**  
  - [Full vs Diff vs Log vs Copy-Only](https://www.youtube.com/results?search_query=sql+server+full+differential+log+copy-only)
- 📘 **Docs:**  
  - [Differential Backups](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/differential-backups-sql-server)  
  - [Copy-Only Backups](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/copy-only-backups-sql-server)

---

### 2.4 | BACKUP DATABASE/LOG – Syntax & Optionen
> **Kurzbeschreibung:** `WITH COMPRESSION`, `CHECKSUM`, `STATS`, `INIT/FORMAT`, Striping (`TO DISK = ... , ...`).

- 📓 **Notebook:**  
  [`08_04_backup_syntax_options.ipynb`](08_04_backup_syntax_options.ipynb)
- 🎥 **YouTube:**  
  - [BACKUP DATABASE Tutorial](https://www.youtube.com/results?search_query=sql+server+backup+database+tutorial)
- 📘 **Docs:**  
  - [`BACKUP DATABASE`](https://learn.microsoft.com/en-us/sql/t-sql/statements/backup-transact-sql)

---

### 2.5 | Performance: Striping, Compression, BUFFERCOUNT
> **Kurzbeschreibung:** Mehrere Ziele (Striping), Transfergrößen, `MAXTRANSFERSIZE`, `BLOCKSIZE`, IO/CPU abwägen.

- 📓 **Notebook:**  
  [`08_10_backup_performance_tuning.ipynb`](08_10_backup_performance_tuning.ipynb)
- 🎥 **YouTube:**  
  - [Speed Up Backups](https://www.youtube.com/results?search_query=sql+server+backup+performance+striped)
- 📘 **Docs:**  
  - [Optimize Backup and Restore Performance](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/tune-performance-of-backup-operations)

---

### 2.6 | Sicherheit: Verschlüsselung, TDE & Schutz der Dateien
> **Kurzbeschreibung:** Backup Encryption (Cert/Asym), TDE-Key-Export, Offsite/Immutability (3-2-1-Regel).

- 📓 **Notebook:**  
  [`08_11_backup_encryption_tde_security.ipynb`](08_11_backup_encryption_tde_security.ipynb)
- 🎥 **YouTube:**  
  - [Encrypted Backups & TDE](https://www.youtube.com/results?search_query=sql+server+backup+encryption+tde)
- 📘 **Docs:**  
  - [Backup Encryption](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/backup-encryption)  
  - [TDE – Export/Import Keys](https://learn.microsoft.com/en-us/sql/relational-databases/security/encryption/transparent-data-encryption)

---

### 2.7 | Backups in die Cloud: `TO URL` (Azure Blob)
> **Kurzbeschreibung:** Sicherungen direkt nach Azure Blob (SAS/Credential/MI), Throttling & Kosten.

- 📓 **Notebook:**  
  [`08_12_backup_to_url_azure_blob.ipynb`](08_12_backup_to_url_azure_blob.ipynb)
- 🎥 **YouTube:**  
  - [Backup to URL Demo](https://www.youtube.com/results?search_query=sql+server+backup+to+url+azure+blob)
- 📘 **Docs:**  
  - [SQL Server Backup to URL](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/sql-server-backup-to-url)

---

### 2.8 | Verifikation & Integrität: VERIFYONLY, CHECKSUM, Test-Restores
> **Kurzbeschreibung:** Prüfen, ob das Backup **lesbar** ist; Restore-Probe, `DBCC CHECKDB` nach Restore.

- 📓 **Notebook:**  
  [`08_13_verify_checksum_testrestore.ipynb`](08_13_verify_checksum_testrestore.ipynb)
- 🎥 **YouTube:**  
  - [Restore VERIFYONLY vs CHECKSUM](https://www.youtube.com/results?search_query=sql+server+restore+verifyonly+checksum)
- 📘 **Docs:**  
  - [`RESTORE VERIFYONLY`](https://learn.microsoft.com/en-us/sql/t-sql/statements/restore-statements-verifyonly-transact-sql)  
  - [Backup Checksums](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/backup-checksums-sql-server)

---

### 2.9 | Automatisierung & Aufräumen: Wartung, msdb, Retention
> **Kurzbeschreibung:** Jobs/Plans/Skripte, `msdb`-Historie, Lösch-/Kopier-Policies, Reporting.

- 📓 **Notebook:**  
  [`08_14_automation_msdb_retention.ipynb`](08_14_automation_msdb_retention.ipynb)
- 🎥 **YouTube:**  
  - [Automate SQL Backups](https://www.youtube.com/results?search_query=sql+server+automate+backups+ola+hallengren)
- 📘 **Docs:**  
  - [msdb Backup History Tables](https://learn.microsoft.com/en-us/sql/relational-databases/system-tables/backup-and-restore-tables-msdb-database)

---

### 2.10 | HA/DR-Integration: AG, Log Shipping & Copy-Only
> **Kurzbeschreibung:** Backup-Präferenzen in **Always On AG**, Sekundärknoten-Backups, Log Shipping-Ketten, Copy-Only bei Ad-hoc.

- 📓 **Notebook:**  
  [`08_15_hadr_ag_logshipping_backups.ipynb`](08_15_hadr_ag_logshipping_backups.ipynb)
- 🎥 **YouTube:**  
  - [AG Backup Preferences](https://www.youtube.com/results?search_query=sql+server+availability+groups+backup+preferences)
- 📘 **Docs:**  
  - [Backups on Always On Availability Groups](https://learn.microsoft.com/en-us/sql/database-engine/availability-groups/windows/active-secondaries-backup-on-secondary-replicas)  
  - [Log Shipping](https://learn.microsoft.com/en-us/sql/database-engine/log-shipping/about-log-shipping-sql-server)

---

### 2.11 | Anti-Patterns & Checkliste
> **Kurzbeschreibung:** Nur Full-Backups im FULL-Model (ohne Log), keine Restore-Tests, Copy-Only falsch eingesetzt, Differential-Basen zerstört, LSN-Lücken, ungeprüfte Verschlüsselungs-Keys, fehlende Offsite/Immutability, `msdb`-Cleanup vergessen.

- 📓 **Notebook:**  
  [`08_16_backup_restore_antipatterns_checklist.ipynb`](08_16_backup_restore_antipatterns_checklist.ipynb)
- 🎥 **YouTube:**  
  - [Common Backup/Restore Mistakes](https://www.youtube.com/results?search_query=sql+server+backup+restore+mistakes)
- 📘 **Docs/Blog:**  
  - [Backup/Restore Best Practices](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/back-up-and-restore-of-sql-server-databases#best-practices)

---

## 3 | Datenbank-Status: Wie es dazu kommt und was er bedeutet

Bevor über die passende Restore-Art entschieden werden kann, muss zuerst klar sein, **in welchem Zustand sich die Datenbank gerade befindet** — SQL Server zeigt das über `sys.databases.state_desc`. Dieses Kapitel erklärt, wie es zu den einzelnen Zuständen kommt und was jeweils zu tun ist.

### 3.1 | Status auslesen

```sql
SELECT name, state_desc, recovery_model_desc, user_access_desc
FROM sys.databases;
```

Für eine vollständige, sofort einsetzbare Abfrage mit Klartext-Einordnung und Kritikalitäts-Sortierung siehe [SQLScripts/DatabaseStatusOverview.sql](SQLScripts/DatabaseStatusOverview.sql) (Doku: [SQLScripts/DatabaseStatusOverview.md](SQLScripts/DatabaseStatusOverview.md)) — das Skript ordnet jeden Status direkt in Klartext ein und sortiert kritische Zustände (`SUSPECT`, `RECOVERY_PENDING`, `EMERGENCY`) an den Anfang der Ausgabe. Zeigt es eine betroffene Datenbank an, hilft als nächster Schritt [SQLScripts/SuspectOrRecoveryPendingDatabaseRootCauseCheck.sql](SQLScripts/SuspectOrRecoveryPendingDatabaseRootCauseCheck.sql) (Doku: [SQLScripts/SuspectOrRecoveryPendingDatabaseRootCauseCheck.md](SQLScripts/SuspectOrRecoveryPendingDatabaseRootCauseCheck.md)), die konkrete Ursache automatisiert einzugrenzen (Dateizugriff, Speicherplatz, Seitenkorruption, Errorlog).

### 3.2 | Die Zustände im Detail: Wie sie entstehen und was sie bedeuten

| Status | Wie es dazu kommt | Bedeutung | Erforderliches Handeln |
|---|---|---|---|
| **ONLINE** | Normalzustand — die Datenbank ist vollständig hochgefahren und für Lese-/Schreibzugriffe verfügbar. | Alles in Ordnung. | Keins. |
| **RESTORING** | Ein `RESTORE DATABASE`/`RESTORE LOG` läuft gerade, oder eine vorherige Restore-Kette wurde mit `WITH NORECOVERY` abgebrochen und wartet auf den nächsten Schritt (weiteres Backup oder `WITH RECOVERY`). | Die Datenbank befindet sich mitten in einem manuell gesteuerten Wiederherstellungsvorgang. | Restore-Kette fortsetzen (nächstes Backup einspielen) oder mit `WITH RECOVERY` abschließen. Läuft die Kette unerwartet lange oder hängt fest (z. B. wegen Speicherplatzmangels), siehe Abschnitt 3.5. |
| **RECOVERING** | SQL Server durchläuft nach einem Neustart, einem Failover oder direkt nach einem Restore automatisch die **Crash Recovery** (Analysis → Redo → Undo), um die Datenbank anhand des Transaktionslogs wieder in einen konsistenten Zustand zu bringen. | Übergangszustand, der bei sauberem Log i.d.R. **automatisch** und **temporär** durchlaufen wird. | I.d.R. keins — abwarten. Bei sehr großen Logs oder vielen offenen Transaktionen kann dies dauern; bleibt die Datenbank ungewöhnlich lange in `RECOVERING`, Errorlog auf Fortschritt prüfen. |
| **RECOVERY_PENDING** | Die Crash Recovery (siehe `RECOVERING`) konnte **gar nicht erst starten** — typischerweise weil eine Datendatei fehlt, gesperrt oder nicht erreichbar ist, der Datenträger voll ist, oder SQL Server aus einem anderen Ressourcengrund nicht mit der Recovery beginnen kann. | SQL Server "weiß", dass etwas fehlt, hat aber noch nicht versucht, das Log tatsächlich anzuwenden — anders als bei `SUSPECT` ist meist noch kein Recovery-Versuch fehlgeschlagen, sondern er konnte nicht beginnen. Die Datenbank ist über `sys.databases`/`sys.master_files` i.d.R. noch lesbar (kein `Msg 926`). | Manueller Eingriff durch einen DBA: Ursache beheben (z. B. fehlende Datei bereitstellen, Speicherplatz freigeben, Berechtigung korrigieren) und die Datenbank danach neu starten lassen (`ALTER DATABASE ... SET ONLINE`) bzw. mit [SQLScripts/RecoveryPendingRepairWithoutBackup.sql](SQLScripts/RecoveryPendingRepairWithoutBackup.sql) (Doku: [SQLScripts/RecoveryPendingRepairWithoutBackup.md](SQLScripts/RecoveryPendingRepairWithoutBackup.md)) prüfen/reparieren. |
| **SUSPECT** | Die Crash Recovery **wurde versucht, ist aber fehlgeschlagen** — meist wegen Seitenkorruption (`msdb.dbo.suspect_pages`, Fehler 823/824) oder eines beschädigten Transaktionslogs, das nicht angewendet werden konnte. | Die Datenbank gilt als potenziell inkonsistent und verweigert **jeden** Zugriff (auch rein lesende Abfragen) mit `Msg 926`, solange sie nicht per `ALTER DATABASE ... SET EMERGENCY` zugänglich gemacht wurde. | Manueller Eingriff zwingend erforderlich: siehe Kapitel 4 (Restores) — je nach Backup-Lage vollständiger Restore, Page Restore, VM-/Disk-Level-Restore oder als letztes Mittel [SQLScripts/SuspectDatabaseRepairWithoutBackup.sql](SQLScripts/SuspectDatabaseRepairWithoutBackup.sql) (Doku: [SQLScripts/SuspectDatabaseRepairWithoutBackup.md](SQLScripts/SuspectDatabaseRepairWithoutBackup.md)). |
| **EMERGENCY** | Wird **nicht** von SQL Server automatisch gesetzt, sondern bewusst manuell per `ALTER DATABASE ... SET EMERGENCY` aktiviert — meist als Zwischenschritt, um eine `SUSPECT`-Datenbank überhaupt wieder lesbar zu machen. | Die Datenbank ist nur eingeschränkt (meist `READ_ONLY`, `SINGLE_USER`) zugänglich, i.d.R. zu reinen Diagnose- oder Reparaturzwecken. | Sollte nie ein Dauerzustand sein — nach Abschluss der Reparatur/Extraktion entweder `SET ONLINE`/`SET MULTI_USER` oder die Datenbank gezielt verwerfen (siehe [SQLScripts/DropDatabaseCompletely.sql](SQLScripts/DropDatabaseCompletely.sql), Doku: [SQLScripts/DropDatabaseCompletely.md](SQLScripts/DropDatabaseCompletely.md)). |
| **OFFLINE** | Eine Datenbank wurde bewusst per `ALTER DATABASE ... SET OFFLINE` deaktiviert, z. B. um Dateien zu verschieben, auszutauschen oder für einen VM-/Disk-Level-Restore freizugeben. | Kontrollierter, gewollter Zustand. | `ALTER DATABASE ... SET ONLINE`, sobald die zugrunde liegende Wartungsaktion abgeschlossen ist. |
| **COPYING** | Nur bei Azure SQL Database: Die Datenbank wird gerade als Kopiervorgang (`CREATE DATABASE ... AS COPY OF`) angelegt. | Übergangszustand, temporär. | Abwarten, bis der Kopiervorgang abgeschlossen ist. |

### 3.3 | Ist SUSPECT ein fehlgeschlagenes RECOVERY_PENDING? Die genaue Zustandskette

**Kurze Antwort: Nein.** `SUSPECT` ist **kein** Folgezustand von `RECOVERY_PENDING`. Beide Zustände entstehen aus unterschiedlichen Ursachen und an unterschiedlichen Stellen im Startvorgang — sie sind **zwei getrennte, parallele Zweige**, keine lineare Kette. Das ist ein häufiges Missverständnis, deshalb hier die exakte, an der offiziellen Microsoft-Dokumentation verifizierte Zustandslogik.

**Wörtliche Definitionen laut Microsoft Learn** ([Database States](https://learn.microsoft.com/en-us/sql/relational-databases/databases/database-states?view=sql-server-ver17)):

- **RECOVERING:** *"Database is being recovered. The recovering process is a transient state; the database automatically becomes online if the recovery succeeds. **If the recovery fails, the database becomes suspect.**"*
- **RECOVERY PENDING:** *"SQL Server has encountered a resource-related error during recovery. **The database isn't damaged**, but files might be missing or system resource limitations might be preventing it from starting."*
- **SUSPECT:** *"At least the primary filegroup is suspect and **might be damaged**. The database can't be recovered during startup of SQL Server."*

Der entscheidende Satz steht bei `RECOVERING`, nicht bei `RECOVERY_PENDING`: **`SUSPECT` entsteht ausschließlich aus einem fehlgeschlagenen `RECOVERING`-Vorgang** (Redo/Undo lief tatsächlich und scheiterte an einer Beschädigung). `RECOVERY_PENDING` wird in der Microsoft-Doku an keiner Stelle als Vorstufe zu `SUSPECT` beschrieben — im Gegenteil, die Datenbank gilt dabei explizit als *"not damaged"*.

**Der eigentliche Unterschied liegt im Zeitpunkt des Scheiterns:**

| | RECOVERY_PENDING | SUSPECT |
|---|---|---|
| **Wann tritt es auf?** | *Bevor* der eigentliche Redo/Undo-Vorgang (`RECOVERING`) überhaupt beginnen kann | *Während* der Redo/Undo-Vorgang (`RECOVERING`) bereits läuft |
| **Was fehlt/schlägt fehl?** | Eine Ressource ist nicht verfügbar (Datei fehlt/gesperrt, Speicherplatz, Systemressource) — SQL Server weiß, dass Recovery nötig ist, kann aber nicht starten | Der Redo- oder Undo-Vorgang selbst scheitert an beschädigten Daten (Seitenkorruption) oder einem beschädigten Log, das nicht angewendet werden kann |
| **Ist die Datenbank beschädigt?** | Laut Microsoft explizit **nein** — reines Ressourcenproblem | Laut Microsoft **ja, möglicherweise** — mindestens die primäre Filegroup gilt als potenziell beschädigt |

Diese Einordnung deckt sich mit der Praxiserfahrung von Paul Randal (SQLskills, Mitentwickler von `DBCC CHECKDB`) in [Search Engine Q&A #4](https://www.sqlskills.com/blogs/paul/search-engine-qa-4-using-emergency-mode-to-access-a-recovery-pending-or-suspect-database/): *"SQL Server knows that recovery needs to be run on the database but something is preventing recovery from starting"* (RECOVERY_PENDING) — ohne jede Garantie, dass die Recovery bei Behebung des Problems tatsächlich scheitern würde.

**Die korrekte Zustandskette beim Hochfahren einer Datenbank:**

```mermaid
flowchart TD
    Start(["Datenbank wird gestartet\n(Neustart, Failover, nach RESTORE)"]) --> Check{"Kann SQL Server\nden Recovery-Vorgang\nüberhaupt STARTEN?"}

    Check -->|"Nein - Ressource fehlt:\nDatei nicht erreichbar,\nSpeicherplatz, Systemressource"| RP["RECOVERY_PENDING\n(Datenbank laut MS 'not damaged')"]
    Check -->|"Ja - Redo/Undo beginnt"| REC["RECOVERING\n(Analysis -> Redo -> Undo laeuft)"]

    REC -->|"Redo/Undo erfolgreich\nabgeschlossen"| ON["ONLINE"]
    REC -->|"Redo/Undo scheitert:\nSeitenkorruption oder\nbeschaedigtes Log"| SUS["SUSPECT\n('at least the primary\nfilegroup might be damaged')"]

    RP -.->|"Ursache behoben\n(Datei bereitgestellt,\nPlatz geschaffen) + Neustart"| REC

    style RP fill:#8a6d1f,stroke:#8a6d1f,color:#fff
    style SUS fill:#8a3b3b,stroke:#8a3b3b,color:#fff
    style ON fill:#2f6f4f,stroke:#2f6f4f,color:#fff
```

**Wichtige Lesehinweise zum Diagramm:**

- Der Pfeil von `RECOVERY_PENDING` zurück zu `RECOVERING` (gestrichelt) ist **kein automatischer Übergang**, sondern setzt voraus, dass die blockierende Ursache manuell behoben und die Datenbank neu gestartet/online genommen wird. Erst dann beginnt der eigentliche Redo/Undo-Vorgang — und *dieser* könnte anschließend ebenfalls fehlschlagen und in `SUSPECT` münden. Ein direkter Übergang `RECOVERY_PENDING → SUSPECT` ohne den Zwischenschritt `RECOVERING` ist nach den offiziellen Zustandsdefinitionen nicht vorgesehen.
- Es gibt **kein offizielles, grafisches Zustandsdiagramm von Microsoft** — die obige Darstellung ist eine Synthese aus den wörtlichen Zustandsdefinitionen der Microsoft-Dokumentation, keine 1:1-Übernahme eines Original-Diagramms.
- Die numerischen `state`-Werte in `sys.databases` (0=ONLINE, 1=RESTORING, 2=RECOVERING, 3=RECOVERY_PENDING, 4=SUSPECT, 5=EMERGENCY, 6=OFFLINE, 7=COPYING) folgen einer internen Enum-Reihenfolge und sind **keine Aussage über eine zeitliche Abfolge** — Zustand 3 kommt nummerisch vor Zustand 4, aber das bedeutet nicht, dass RECOVERY_PENDING zeitlich vor SUSPECT durchlaufen wird.

**Praktische Konsequenz:** Zeigt `DatabaseStatusOverview.sql` eine Datenbank als `RECOVERY_PENDING`, ist die Wahrscheinlichkeit hoch, dass die Datenbank **noch nicht beschädigt** ist und sich das Problem durch Beheben der Ressourcenursache (siehe [RecoveryPendingRepairWithoutBackup.md](SQLScripts/RecoveryPendingRepairWithoutBackup.md)) ohne Datenverlust lösen lässt. Erst wenn danach ein erneuter Recovery-Versuch tatsächlich fehlschlägt, wird `SUSPECT` erreicht — und damit auch erst dann der datenverlustbehaftete Reparaturpfad relevant ([SuspectDatabaseRepairWithoutBackup.md](SQLScripts/SuspectDatabaseRepairWithoutBackup.md)).

### 3.4 | Typische Root Causes: Wodurch RECOVERY_PENDING/SUSPECT in der Praxis tatsächlich ausgelöst wird

Die Tabelle in 3.2 beschreibt die **mechanische** Ursache auf SQL-Server-Ebene (Crash Recovery schlägt fehl bzw. kann nicht starten). Dahinter steht aber fast immer ein konkretes Ereignis auf **Infrastrukturebene**, das SQL Server mitten in einem schreibenden Vorgang oder beim Hochfahren gestört hat:

| Root Cause | Typischer betroffener Status | Wie es dazu kommt |
|---|---|---|
| **Fehlgeschlagenes/erzwungenes Windows-Update mit Neustart** | `RECOVERY_PENDING`, seltener `SUSPECT` | Ein Windows-Update erzwingt einen Neustart, während SQL Server gerade schreibend auf Daten-/Logdateien zugreift (z. B. während eines aktiven Checkpoints oder einer laufenden Transaktion). Der Dienst wird nicht sauber heruntergefahren, sondern abrupt beendet — vergleichbar mit einem Stromausfall. Startet SQL Server danach neu, muss die Crash Recovery greifen; gelingt das nicht (z. B. weil eine Datei durch den harten Abbruch inkonsistent wurde oder das Update selbst Dateien am Datenträger verschoben/gesperrt hat), bleibt die Datenbank in `RECOVERY_PENDING` oder `SUSPECT` hängen. |
| **Dateisystemfehler / Storage-Probleme** | `SUSPECT` (Seitenkorruption) | Fehlerhafte Sektoren, ein RAID-Controller-Fehler, ein Firmware-Bug im Storage, oder ein unsauber getrenntes Netzlaufwerk/SAN können dazu führen, dass einzelne 8-KB-Seiten beim Schreiben oder Lesen beschädigt werden (Fehler 823/824, sichtbar in `msdb.dbo.suspect_pages`). SQL Server erkennt das beim nächsten Zugriff und markiert die Datenbank als `SUSPECT`. |
| **Voller Datenträger während eines Schreibvorgangs** | `RECOVERY_PENDING`, teils `SUSPECT` | Läuft der Datenträger mit den Daten- oder Logdateien während eines aktiven Vorgangs (Transaktion, Checkpoint, Autogrowth) voll, kann SQL Server die Operation nicht abschließen. Bei einem darauffolgenden Neustart fehlt dann ggf. ein konsistenter Zustand, den die Crash Recovery erwartet. |
| **Fehlende/verschobene/umbenannte Datendatei** | `RECOVERY_PENDING` | Eine `.mdf`/`.ndf`/`.ldf`-Datei wurde versehentlich gelöscht, auf ein anderes Laufwerk verschoben, oder ein Laufwerksbuchstabe hat sich geändert (z. B. nach einem Neustart mit anderer Laufwerkszuordnung). SQL Server findet die Datei am erwarteten Pfad nicht mehr und kann die Recovery gar nicht erst starten. |
| **Antivirus-/Backup-Software greift auf offene Datenbankdateien zu** | `RECOVERY_PENDING`, seltener `SUSPECT` | Ein Virenscanner oder ein Backup-Agent, der `.mdf`/`.ldf`-Dateien fälschlich in seinen Scan-/Sicherungsbereich einbezieht (statt sie über die SQL-Server-VSS-Writer-Schnittstelle korrekt zu behandeln), kann Dateisperren verursachen oder Dateien in einem inkonsistenten Moment kopieren/verschieben. |
| **Plötzlicher Stromausfall / harter Server-Reset** | `RECOVERY_PENDING`, `SUSPECT` | Wie beim erzwungenen Windows-Update: SQL Server wird ohne sauberen Shutdown beendet, während Daten- oder Logdateien offene, nicht committete Änderungen enthalten. |
| **Speicherengpass / Ressourcenmangel beim Hochfahren** | `RECOVERY_PENDING` | Reicht der verfügbare Arbeitsspeicher oder tempdb-Speicherplatz beim Start nicht aus, um die Crash Recovery durchzuführen, bleibt die Datenbank ebenfalls in `RECOVERY_PENDING` hängen, bis die Ressource verfügbar ist. |

**Praktischer Hinweis:** Für die Root-Cause-Analyse eines konkreten Falls automatisiert [SQLScripts/SuspectOrRecoveryPendingDatabaseRootCauseCheck.sql](SQLScripts/SuspectOrRecoveryPendingDatabaseRootCauseCheck.sql) (Doku: [SQLScripts/SuspectOrRecoveryPendingDatabaseRootCauseCheck.md](SQLScripts/SuspectOrRecoveryPendingDatabaseRootCauseCheck.md)) genau diese Kategorien: Es prüft Dateizugriff, freien Speicherplatz, bekannte Suspect Pages und durchsucht das SQL-Server-Errorlog nach passenden Einträgen (z. B. Hinweisen auf einen unsauberen Shutdown oder I/O-Fehler kurz vor dem Auftreten des Status).

### 3.5 | Sonderfall: Restore bricht wegen Speicherplatzmangel ab

Ein in der Praxis häufiger Auslöser für einen hängenden `RESTORING`-Zustand: Der Datenträger, auf den restored wird, hat **während** des Restore-Vorgangs nicht genug freien Speicherplatz — der Restore bricht ab, die Datenbank bleibt aber im `RESTORING`-Zustand hängen (weder online noch sauber abgebrochen) und blockiert damit den Datenbanknamen für einen erneuten Versuch.

**Vorgehen zum Abbrechen eines hängenden Restores:**

1. **Restore mit `WITH RECOVERY` beenden**, um die Datenbank aus dem `RESTORING`-Zustand herauszuholen:

   ```sql
   RESTORE DATABASE [DeineDatenbank] WITH RECOVERY;
   ```

   Das bringt die Datenbank je nach Fortschritt entweder in einen nutzbaren Zustand (falls der Restore fast abgeschlossen war) oder zumindest in einen Zustand, in dem sie regulär gelöscht und danach neu wiederhergestellt werden kann.

2. **Mögliche Fehlermeldung**, falls noch eine Verbindung/ein Prozess exklusiven Zugriff blockiert:

   ```text
   Msg 3101, Level 16, State 1, Line 1
   Exclusive access could not be obtained because the database is in use.
   Msg 3013, Level 16, State 1, Line 1
   RESTORE DATABASE is terminating abnormally.
   ```

   > **Anmerkung:** Auch wenn dieser Befehl fehlschlägt, befindet sich die Datenbank danach möglicherweise bereits nicht mehr im Restore-Modus — vorher `sys.databases.state_desc` erneut prüfen, bevor der nächste Schritt versucht wird.

3. **Falls `WITH RECOVERY` nicht funktioniert**, die Datenbank offline nehmen und vollständig entfernen, um danach sauber neu zu starten:

   ```sql
   ALTER DATABASE [DeineDatenbank] SET OFFLINE WITH ROLLBACK IMMEDIATE;
   DROP DATABASE [DeineDatenbank];
   ```

   Für ein robusteres, automatisiertes Vorgehen (killt aktive Verbindungen, entfernt auch am Dateisystem verbliebene Dateien via `xp_cmdshell`-Fallback) siehe [SQLScripts/DropDatabaseCompletely.sql](SQLScripts/DropDatabaseCompletely.sql) (Doku: [SQLScripts/DropDatabaseCompletely.md](SQLScripts/DropDatabaseCompletely.md)).

4. **Vor dem erneuten Restore-Versuch**: Speicherplatz auf dem Zieldatenträger sicherstellen (freien Platz prüfen, ggf. alte Backups/Logs verschieben oder ein Laufwerk mit mehr Kapazität wählen) — sonst wiederholt sich derselbe Abbruch.

---

### 3.6 | Weiterführende Informationen zu Kapitel 3

- 📘 Microsoft Learn: [Database States (SQL Server)](https://learn.microsoft.com/en-us/sql/relational-databases/databases/database-states?view=sql-server-ver17) — offizielle Referenz aller `state_desc`-Werte (ONLINE, RESTORING, RECOVERING, RECOVERY_PENDING, SUSPECT, EMERGENCY, OFFLINE, COPYING).
- 📘 Microsoft Learn: [`sys.databases` (Transact-SQL)](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-databases-transact-sql?view=sql-server-ver17) — Spaltenreferenz der Katalogsicht inkl. `state_desc`, Basis für die Statusabfragen in 3.1.
- 📘 Microsoft Learn: [Always On DB in recovery pending or suspect state](https://learn.microsoft.com/en-us/troubleshoot/sql/database-engine/availability-groups/alwayson-availability-databases-recovery-pending-suspect) — Troubleshooting-Guide, der den Unterschied zwischen `RECOVERY_PENDING` und `SUSPECT` konkret erklärt.
- 📘 Microsoft Learn: [Restore and Recovery Overview (SQL Server)](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/restore-and-recovery-overview-sql-server?view=sql-server-ver17) — offizielle Beschreibung des Crash-Recovery-Prozesses (Analysis/Redo/Undo).
- 📘 Microsoft Learn: [MSSQLSERVER_824 (Database Engine Error)](https://learn.microsoft.com/en-us/sql/relational-databases/errors-events/mssqlserver-824-database-engine-error?view=sql-server-ver16) — Fehlerreferenz zur logischen Seitenkorruption, die zu `SUSPECT` führt.
- 📘 Microsoft Learn: [SQL Server diagnostics detects unreported I/O problems](https://learn.microsoft.com/lv-lv/troubleshoot/sql/database-engine/database-file-operations/diagnostics-for-unreported-io-problems) — Troubleshooting zu Fehler 823/824 und I/O-Subsystem-Problemen als Root Cause.
- 📘 Microsoft Learn: [Configure antivirus software to work with SQL Server](https://learn.microsoft.com/en-US/troubleshoot/sql/database-engine/security/antivirus-and-sql-server) — offizielle Ausschlussempfehlungen für `.mdf`/`.ldf`/`.bak`, relevant für den Root Cause "Antivirus-Konflikte".
- 📘 Microsoft Learn: [`DBCC CHECKDB` (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/database-console-commands/dbcc-checkdb-transact-sql?view=sql-server-ver17) — Referenz inkl. `REPAIR_ALLOW_DATA_LOSS`, zentrales Werkzeug bei `SUSPECT`/Korruption.
- 📝 Paul Randal (SQLskills, Originalautor von `DBCC CHECKDB`): [Creating, detaching, re-attaching and fixing a suspect database](https://www.sqlskills.com/blogs/paul/creating-detaching-re-attaching-and-fixing-a-suspect-database/) — die in der Community meistzitierte Praxisanleitung zum Reparieren einer `SUSPECT`-Datenbank.
- 📝 Paul Randal (SQLskills): [Search Engine Q&A #4: Using Emergency mode to access a RECOVERY_PENDING or SUSPECT database](https://www.sqlskills.com/blogs/paul/search-engine-qa-4-using-emergency-mode-to-access-a-recovery-pending-or-suspect-database/) — Primärquelle für die exakte Abgrenzung zwischen `RECOVERY_PENDING` und `SUSPECT` in Abschnitt 3.3.
- 📝 Brent Ozar: [What to Do When DBCC CHECKDB Reports Corruption](https://www.brentozar.com/archive/2016/05/dbcc-checkdb-reports-corruption/) — operativer DBA-Blickwinkel auf gemeldete Korruption, ergänzt Paul Randals Perspektive.
- 📝 SQLServerCentral: [Recover a Database from Suspect Mode Step by Step](https://www.sqlservercentral.com/articles/recover-a-database-from-suspect-mode-step-by-step) — Community-Anleitung mit weiterem praktischen Ablauf zur Wiederherstellung aus `SUSPECT`.

---

## 4 | Restores

Dieses Kapitel bündelt alle **Arten von Restores** in SQL Server — von der kompletten Datenbankwiederherstellung bis zur gezielten Reparatur einzelner Seiten. Jede Art wird kurz und präzise beschrieben (was sie bedeutet, wann sie zum Einsatz kommt), gefolgt von den zugehörigen Lernressourcen. Eine **Übersichtstabelle** am Ende von Kapitel 4 vergleicht alle Arten auf einen Blick.

### 4.0 | Entscheidungsdiagramm: Welche Restore-Art passt?

Das folgende Diagramm führt Schritt für Schritt zur passenden Restore-Art — abhängig davon, ob überhaupt ein Backup existiert, welches Recovery Model aktiv ist (`SIMPLE` vs. `FULL`/`BULK_LOGGED`), wie die Log-Kette beschaffen ist und welcher Fehler konkret vorliegt (ganze DB betroffen, einzelne Seiten korrupt, versehentliche Datenänderung, Filegroup betroffen). Die Nummern in Klammern verweisen auf die zugehörigen Abschnitte 4.1–4.7.

```mermaid
flowchart TD
    Start(["Datenbank fehlerhaft /\nnicht mehr online"]) --> Q1{"Existiert ein\nSQL-natives Backup\n(Full/Diff/Log)?"}

    Q1 -->|"Nein"| Q1a{"Existiert ein\nkomplettes VM-/Disk-/\nStorage-Backup\n(vor dem Ereignis)?"}
    Q1a -->|"Ja"| R6["VM-/Disk-Level-Restore (4.6)\nunbeschädigte .mdf/.ldf aus\nVM-Backup zurückkopieren"]
    Q1a -->|"Nein"| R7["Reparatur ohne Backup (4.7)\nDBCC CHECKDB REPAIR_ALLOW_DATA_LOSS\n-> dauerhafter Datenverlust"]

    Q1 -->|"Ja"| Q2{"Ist die Datenbank/das Log\nnoch (teilweise) zugreifbar?"}
    Q2 -->|"Ja"| T3["Tail-Log-Backup sichern (4.3)\nBACKUP LOG ... WITH NO_TRUNCATE\n(WITH CONTINUE_AFTER_ERROR falls Log beschädigt)"]
    Q2 -->|"Nein / DB bereits SUSPECT\noder Datei fehlt"| Q3

    T3 --> Q3{"Art des Fehlers /\nWiederherstellungsziel?"}

    Q3 -->|"Gesamte Datenbank betroffen\noder unklar - vollständiger\nRestore gewünscht"| Q4{"Recovery Model?"}
    Q4 -->|"SIMPLE"| R1a["Vollständiger DB-Restore (4.1)\nnur Full + letztes Diff,\nKEIN Point-in-Time moeglich\n(kein Log-Backup vorhanden)"]
    Q4 -->|"FULL / BULK_LOGGED"| Q5{"Bis zu einem exakten\nZeitpunkt/vor einem\nbekannten Fehler wiederherstellen?"}
    Q5 -->|"Nein - bis zum letzten\nverfuegbaren Backup"| R1["Vollständiger DB-Restore (4.1)\nFull -> Diff -> alle Logs\nWITH RECOVERY"]
    Q5 -->|"Ja"| Q5a{"Log-Kette vom Full-Backup\nbis zum Zielzeitpunkt\nlückenlos?"}
    Q5a -->|"Ja"| R2["Point-in-Time-Restore (4.2)\nRESTORE LOG ... WITH STOPAT / STOPATMARK"]
    Q5a -->|"Nein - Lücke\nin der Log-Kette"| R1x["Nur vollständiger Restore (4.1)\nbis zum letzten Backup VOR der Lücke\n-> PITR ab der Lücke nicht möglich"]

    Q3 -->|"Nur einzelne 8-KB-Seiten\nkorrupt (msdb.dbo.suspect_pages,\nFehler 823/824)"| Q6{"Recovery Model FULL\noder BULK_LOGGED,\nund Log-Kette lückenlos?"}
    Q6 -->|"Ja"| R5["Page Restore (4.5)\nRESTORE DATABASE ... PAGE = 'FileID:PageID'\n+ nachfolgende Log-Backups"]
    Q6 -->|"Nein - SIMPLE Model\noder Log-Kette unterbrochen"| R1y["Nur vollständiger Restore (4.1)\nPage Restore technisch nicht möglich"]

    Q3 -->|"Nur eine bestimmte\nDatei/Filegroup betroffen"| Q7{"Datenbank ist in\nmehrere Filegroups\nunterteilt?"}
    Q7 -->|"Ja"| R4["Piecemeal Restore (4.4)\nnur betroffene Filegroup restoren,\nRest ggf. weiter online"]
    Q7 -->|"Nein - nur eine\nDatendatei insgesamt"| R1z["Vollständiger Restore (4.1)\nFilegroup-Trennung nicht vorhanden"]

    style R1 fill:#2f6f4f,stroke:#2f6f4f,color:#fff
    style R2 fill:#2f6f4f,stroke:#2f6f4f,color:#fff
    style R4 fill:#2f6f4f,stroke:#2f6f4f,color:#fff
    style R5 fill:#2f6f4f,stroke:#2f6f4f,color:#fff
    style R6 fill:#2f6f4f,stroke:#2f6f4f,color:#fff
    style R7 fill:#8a3b3b,stroke:#8a3b3b,color:#fff
```

**Wie das Diagramm zu lesen ist:**

- **Erste Weiche (Backup vorhanden?):** Ohne jegliches Backup (weder SQL-nativ noch VM-Ebene) bleibt nur die datenverlustbehaftete Reparatur (4.7) — rot markiert, da hier immer echte Daten verloren gehen. Existiert wenigstens ein VM-/Disk-Backup, ist der VM-/Disk-Level-Restore (4.6) fast immer vorzuziehen.
- **Tail-Log-Backup (4.3)** ist kein eigenständiges Ziel, sondern eine Pflichtstation, sobald die Datenbank/das Log noch irgendwie lesbar ist — sonst gehen die Transaktionen seit dem letzten Log-Backup unnötig verloren.
- **Recovery Model entscheidet direkt über die Optionen:** In `SIMPLE` gibt es **keine** Log-Backups, damit sind Point-in-Time-Restore (4.2) und Page Restore (4.5) **grundsätzlich ausgeschlossen** — es bleibt nur der vollständige Restore aus Full/Differential. Nur in `FULL`/`BULK_LOGGED` mit lückenloser Log-Kette sind PITR und Page Restore technisch möglich.
- **Eine Lücke in der Log-Kette** (z. B. ein fehlendes Log-Backup) begrenzt einen Point-in-Time-Restore auf den letzten Stand **vor** der Lücke — alles danach ist nur noch über ein neueres Backup nach der Lücke erreichbar, falls vorhanden.
- **Filegroup-Aufteilung ist eine Vorbedingung, keine Nachrüstoption:** Piecemeal Restore (4.4) funktioniert nur, wenn die Datenbank *im Vorfeld* in mehrere Filegroups strukturiert wurde — bei einer einzigen Datendatei bleibt nur der vollständige Restore.

### 4.1 | Vollständiger Datenbank-Restore (Full/Diff/Log-Kette)
> **Bedeutung:** Die komplette Datenbank wird aus einem Full-Backup (optional + letztem Differential, optional + allen nachfolgenden Log-Backups) wiederhergestellt. Steuerung der Kette über `WITH NORECOVERY` (weitere Backups folgen), `WITH RECOVERY` (Kette abschließen, DB wird nutzbar) oder `WITH STANDBY` (DB wird read-only mit Undo-Datei nutzbar, weitere Logs können trotzdem noch nachgezogen werden). Dies ist die **sicherste** Restore-Art, da die gesamte Datenbank konsistent aus dem Backup wiederhergestellt wird — kein Restrisiko einzelner, nicht erkannter Folgeschäden. Downtime betrifft die **gesamte** Datenbank für die Dauer des Restores.

- 📓 **Notebook:**  
  [`08_05_restore_chains_norecovery_standby.ipynb`](08_05_restore_chains_norecovery_standby.ipynb)
- 🎥 **YouTube:**  
  - [RESTORE Sequence Basics](https://www.youtube.com/results?search_query=sql+server+restore+sequence+norecovery)
- 📘 **Docs:**  
  - [`RESTORE` Statements](https://learn.microsoft.com/en-us/sql/t-sql/statements/restore-statements-transact-sql)

---

### 4.2 | Point-in-Time-Restore (PITR) & Marked Transactions
> **Bedeutung:** Eine Sonderform des vollständigen Restores, die die Wiederherstellung nicht am Ende des letzten Log-Backups stoppt, sondern gezielt bei `STOPAT` (einem konkreten Zeitpunkt) oder `STOPATMARK`/`STOPBEFOREMARK` (einer markierten, logisch konsistenten Transaktion). Damit lässt sich z. B. exakt bis kurz **vor** einem fehlerhaften `DELETE` oder einer Korruption zurückgehen, ohne spätere, noch unbeschädigte Transaktionen zu verlieren. Voraussetzung ist eine lückenlose Log-Kette bis zum gewünschten Zeitpunkt (Recovery Model `FULL`/`BULK_LOGGED`).

- 📓 **Notebook:**  
  [`08_06_point_in_time_stopat_mark.ipynb`](08_06_point_in_time_stopat_mark.ipynb)
- 🎥 **YouTube:**  
  - [Point-in-Time Restore](https://www.youtube.com/results?search_query=sql+server+point+in+time+restore)
- 📘 **Docs:**  
  - [Restore to a Point in Time](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/restore-a-sql-server-database-to-a-point-in-time)  
  - [Marked Transactions](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/transaction-log-marking-and-recovery)

---

### 4.3 | Tail-Log-Restore (Notfallwiederherstellung)
> **Bedeutung:** Kein eigener Restore-Typ im engeren Sinn, sondern der **vorbereitende Schritt** vor jedem Restore einer noch (teilweise) zugreifbaren, aber beschädigten Datenbank: `BACKUP LOG ... WITH NO_TRUNCATE` sichert den allerletzten, noch nicht gesicherten Log-Abschnitt, bevor die Restore-Kette beginnt — nur so gehen die Transaktionen zwischen dem letzten regulären Log-Backup und dem Ausfallzeitpunkt nicht verloren. `WITH CONTINUE_AFTER_ERROR` erlaubt das Sichern sogar bei bereits beschädigten Bereichen, auf Kosten einzelner fehlender Log-Einträge.

- 📓 **Notebook:**  
  [`08_07_tail_log_disaster_recovery.ipynb`](08_07_tail_log_disaster_recovery.ipynb)
- 🎥 **YouTube:**  
  - [Tail-Log Backup Demo](https://www.youtube.com/results?search_query=sql+server+tail+log+backup)
- 📘 **Docs:**  
  - [Tail-Log Backups](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/tail-log-backups-sql-server)

---

### 4.4 | Piecemeal Restore (File-/Filegroup-Restore)
> **Bedeutung:** Statt der gesamten Datenbank wird nur eine einzelne Datei oder Filegroup aus einem File-/Filegroup-Backup wiederhergestellt. Sinnvoll bei sehr großen Datenbanken, die aus mehreren Filegroups bestehen (z. B. eine historische, read-only Filegroup getrennt von einer aktiven) — nur die tatsächlich betroffene Filegroup muss zurückgespielt werden, der Rest der Datenbank bleibt (je nach Edition und Konfiguration) online nutzbar. Erfordert eine durchdachte Filegroup-Architektur im Vorfeld.

- 📓 **Notebook:**  
  [`08_08_file_filegroup_piecemeal.ipynb`](08_08_file_filegroup_piecemeal.ipynb)
- 🎥 **YouTube:**  
  - [Filegroup Backup and Restore](https://www.youtube.com/results?search_query=sql+server+filegroup+backup+restore)
- 📘 **Docs:**  
  - [Full/Partial/Piecemeal Restore](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/restore-and-recovery-overview-sql-server#piecemeal-restore)

---

### 4.5 | Page Restore (gezielte Seitenwiederherstellung)
> **Bedeutung:** Die granularste Restore-Art — statt einer ganzen Datei/Filegroup werden nur einzelne, konkret als beschädigt identifizierte 8-KB-Datenseiten (`msdb.dbo.suspect_pages`, Fehler 823/824) aus dem Backup eingespielt (`RESTORE DATABASE ... PAGE = 'FileID:PageID'`). Voraussetzung: Recovery Model `FULL`/`BULK_LOGGED`, ein Backup, das die betroffene Seite unbeschädigt enthält, und eine lückenlose Log-Kette bis zur aktuellen Zeit. Kürzeste Downtime aller Restore-Arten bei wenigen betroffenen Seiten; in Enterprise Edition sogar online möglich, während der Rest der Datenbank weiterläuft.

- 📓 **Notebook:**  
  [`08_09_page_restore_targeted.ipynb`](08_09_page_restore_targeted.ipynb)
- 🎥 **YouTube:**  
  - [Page Restore in SQL Server](https://www.youtube.com/results?search_query=sql+server+page+restore)
- 📘 **Docs:**  
  - [Restore Pages](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/restore-pages-sql-server)

---

### 4.6 | VM-/Disk-Level-Restore (Wiederherstellung ohne SQL-natives Backup)
> **Bedeutung:** Kein SQL-Server-`RESTORE`-Befehl im eigentlichen Sinn, sondern das Zurückkopieren unbeschädigter `.mdf`/`.ldf`-Dateien aus einem **kompletten VM-/Disk-/Storage-Backup** (Hyper-V-Checkpoint, VMware-Snapshot, Cloud-Snapshot, SAN-Snapshot) auf Dateisystemebene. Kommt zum Einsatz, wenn kein SQL-natives Backup existiert, aber ein VM-Backup von vor dem Korruptions-/Ausfallereignis vorhanden ist. Bedeutet in der Regel Datenverlust für alle Transaktionen seit dem VM-Backup-Zeitpunkt (kein Tail-Log-Backup möglich, da die DB bereits nicht mehr zugreifbar ist), ist aber der SQL-nativen `REPAIR_ALLOW_DATA_LOSS`-Notlösung meist vorzuziehen, da keine Daten durch Entfernen beschädigter Seiten verloren gehen, sondern nur der Zeitstand zurückgesetzt wird.

- 📄 **Praxis-Anleitung (Wiederherstellung über ein VM-/Disk-Backup):**  
  [`SuspectOrRecoveryPendingDatabase_VMDiskLevelRestore.md`](SuspectOrRecoveryPendingDatabase_VMDiskLevelRestore.md) — Voraussetzungen, Schritt-für-Schritt-Ablauf, Datenverlust-Analyse und Risiken.

---

### 4.7 | Reparatur ohne Backup (`DBCC CHECKDB ... REPAIR_ALLOW_DATA_LOSS`)
> **Bedeutung:** **Kein echter Restore**, sondern die letzte Notlösung, wenn weder ein vollständiger Restore noch ein Page Restore noch ein VM-/Disk-Level-Restore möglich ist: `DBCC CHECKDB` entfernt beschädigte Seiten/Zeilen/Strukturen dauerhaft, um die Datenbank wieder konsistent (aber unvollständig) zu machen. Wird hier dennoch mitgeführt, da sie in der Praxis regelmäßig als letzte Eskalationsstufe neben den echten Restore-Arten steht.

- 📄 **Praxis-Anleitung (SUSPECT-/RECOVERY_PENDING-Datenbank reparieren):**  
  [`SuspectOrRecoveryPendingDatabase_RepairOptions.md`](SuspectOrRecoveryPendingDatabase_RepairOptions.md) — ausführlicher Vergleich aller Restore-Arten bei Seitenkorruption (`msdb.dbo.suspect_pages`, Fehler 823/824) und der `REPAIR_ALLOW_DATA_LOSS`-Notlösung, mit kompletten T-SQL-Befehlen am Beispiel einer Datenbank `BI_DQ`. Siehe auch [`SQLScripts/SuspectOrRecoveryPendingDatabaseRootCauseCheck.sql`](SQLScripts/SuspectOrRecoveryPendingDatabaseRootCauseCheck.sql) (Doku: [`SQLScripts/SuspectOrRecoveryPendingDatabaseRootCauseCheck.md`](SQLScripts/SuspectOrRecoveryPendingDatabaseRootCauseCheck.md)) zur automatisierten Ursachenanalyse.

---

### 4.8 | Übersichtstabelle: Restore-Arten im Vergleich

| Restore-Art | Umfang | Voraussetzung | Datenverlust | Downtime | Wann einsetzen |
|---|---|---|---|---|---|
| **Vollständiger DB-Restore** (4.1) | Gesamte Datenbank | Full-Backup, optional Diff, optional Logs | Nein (bis zum Backup-/Log-Zeitpunkt) | Gesamte DB für Restore-Dauer | Standardfall bei vorhandenem Backup; sicherste Option |
| **Point-in-Time-Restore** (4.2) | Gesamte Datenbank, bis zu einem exakten Zeitpunkt/Marker | Full/Diff + lückenlose Log-Kette, Recovery Model FULL/BULK_LOGGED | Nein bis zum gewählten Zeitpunkt | Gesamte DB für Restore-Dauer | Gezielt vor einem bekannten Fehlerereignis zurückgehen |
| **Tail-Log-Restore** (4.3) | Vorbereitender Schritt, kein eigenständiger Restore | Log noch zugreifbar | Minimiert Verlust der letzten Transaktionen | – (Vorbereitung) | Immer vor einem Restore, wenn das Log noch lesbar ist |
| **Piecemeal Restore** (4.4) | Einzelne Datei/Filegroup | File-/Filegroup-Backup-Strategie, durchdachte Filegroup-Architektur | Nein (bis zum Backup-/Log-Zeitpunkt) | Nur betroffene Filegroup; Rest ggf. weiter nutzbar | Sehr große Datenbanken mit klar getrennten Filegroups |
| **Page Restore** (4.5) | Einzelne 8-KB-Seite(n) | Full-Backup + lückenlose Log-Kette, Recovery Model FULL/BULK_LOGGED | Nein (bis zum Log-Zeitpunkt) | Kürzeste Downtime; Enterprise Edition ggf. online | Wenige, klar identifizierte beschädigte Seiten bei großer DB |
| **VM-/Disk-Level-Restore** (4.6) | Gesamte Datenbankdatei(en) auf Dateisystemebene | Vollständiges VM-/Disk-/Storage-Backup vor dem Ereignis | Transaktionen seit VM-Backup-Zeitpunkt | Abhängig vom Disk-Mount-/Kopiervorgang | Kein SQL-natives Backup vorhanden, aber VM-/Snapshot-Backup existiert |
| **Repair ohne Backup** (4.7) | Beschädigte Seiten/Zeilen (werden entfernt, nicht wiederhergestellt) | Keine (funktioniert immer, aber mit Verlust) | Ja, dauerhaft | Kurz, aber Datenintegrität unvollständig | Letztes Mittel, wenn keine der obigen Optionen möglich ist |

---

## 5 | Weiterführende Informationen

- 📘 Microsoft Learn: [Backup & Restore – Überblick](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/back-up-and-restore-of-sql-server-databases)  
- 📘 Microsoft Learn: [Recovery-Modelle (FULL/SIMPLE/BULK_LOGGED)](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/recovery-models-sql-server)  
- 📘 Microsoft Learn: [`BACKUP DATABASE` / `BACKUP LOG`](https://learn.microsoft.com/en-us/sql/t-sql/statements/backup-transact-sql)  
- 📘 Microsoft Learn: [`RESTORE`-Anweisungen](https://learn.microsoft.com/en-us/sql/t-sql/statements/restore-statements-transact-sql) ・ [`FILELISTONLY`/`HEADERONLY`](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/restore-statements-filelistonly-transact-sql)  
- 📘 Microsoft Learn: [Differential-Backups](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/differential-backups-sql-server) ・ [Copy-Only](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/copy-only-backups-sql-server)  
- 📘 Microsoft Learn: [Point-in-Time / Marked Transactions](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/restore-a-sql-server-database-to-a-point-in-time)  
- 📘 Microsoft Learn: [Tail-Log-Backups](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/tail-log-backups-sql-server)  
- 📘 Microsoft Learn: [Filegroup-Backups & Piecemeal Restore](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/restore-and-recovery-overview-sql-server#piecemeal-restore)  
- 📘 Microsoft Learn: [Page Restore](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/restore-pages-sql-server)  
- 📘 Microsoft Learn: [Backup Compression](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/backup-compression-sql-server) ・ [Performance-Tuning für Backups](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/tune-performance-of-backup-operations)  
- 📘 Microsoft Learn: [Backup Encryption](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/backup-encryption) ・ [TDE Schlüsselverwaltung](https://learn.microsoft.com/en-us/sql/relational-databases/security/encryption/transparent-data-encryption)  
- 📘 Microsoft Learn: [Backup to URL (Azure Blob)](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/sql-server-backup-to-url)  
- 📘 Microsoft Learn: [`msdb` Backup/Restore-Tabellen](https://learn.microsoft.com/en-us/sql/relational-databases/system-tables/backup-and-restore-tables-msdb-database)  
- 📝 SQLSkills (Paul Randal): *Backup/Restore Internals & Myths* – https://www.sqlskills.com/  
- 📝 Ola Hallengren: *SQL Server Maintenance Solution (Backups/Integrity/Index)* – https://ola.hallengren.com/  
- 📝 SQLPerformance: *Backup Performance & Striping* – https://www.sqlperformance.com/?s=backup  
- 📝 Brent Ozar: *Perfect SQL Server Backups & Restores* – https://www.brentozar.com/  
- 📝 Redgate Simple Talk: *Backup Strategies & Verification* – https://www.red-gate.com/simple-talk/  
- 🎥 YouTube (Data Exposed): *SQL Server Backup & Restore Deep Dives* – Suchlink  
- 🎥 YouTube: *Point-in-Time & Tail-Log Restore Demos* – Suchlink  
