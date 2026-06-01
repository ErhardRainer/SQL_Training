# SQL_LogBackup

**Quelle:** `T-SQL\71_BackupRestore_Strategies\SQL_LogBackup.ipynb`  
**Generiert:** 2026-04-18 21:13:31  
**Markdown-Zellen:** 18  
**SQL-Zellen:** 9  

---

# Logs einer Datenbank

## Was sind (Transaktions-)Logs in SQL Server – ein tiefes Verständnis

Transaktionslogs (kurz: **Logs**) sind das **zeitlich geordnete Änderungsprotokoll** einer Datenbank. Jede Änderung an Daten oder Metadaten wird als **Log-Eintrag** aufgezeichnet – unabhängig davon, ob die Änderung später **committet** oder **zurückgerollt** wird. Dieses Protokoll ist das Fundament für

- **ACID-Eigenschaften** (v. a. _Atomicity_ & _Durability_),
    
- **Crash-Recovery** nach Server- oder Prozessabstürzen,
    
- **Point-in-Time-Restore** (zeitpunktgenaue Wiederherstellung) und
    
- **Log-basierte Technologien** wie **Always On** (HADR), **Log Shipping**, **Transaktionsreplikation** und **Change Data Capture (CDC)**.
    

Kurz: Ohne Log gäbe es keine verlässliche Transaktionssicherheit und keine sauberen Wiederherstellungsstrategien.

* * *

## 1) Grundprinzip: Write-Ahead Logging (WAL) & ACID

SQL Server verwendet **Write-Ahead Logging (WAL)**. Die Idee:

- **Bevor** eine geänderte Datenseite dauerhaft auf die Datendatei (MDF/NDF) geschrieben werden darf, muss der **zugehörige Log-Eintrag** bereits **persistiert** (auf die LDF geschrieben) sein.
    
- Dadurch ist eine Transaktion **dauerhaft** (_Durability_), sobald ihr **Commit-Eintrag** im Log bestätigt wurde – selbst wenn die Datenseiten noch **nur im Buffer Cache** liegen.
    

**Atomicity** wird gewährleistet, weil das Log die **Schritte vor und zurück** kennt: Bei einem Rollback nutzt SQL Server die Log-Einträge, um Änderungen rückgängig zu machen.

* * *

## 2) Was steht im Log? (Aufbau & Inhalte)

Ein Log besteht aus einer **linearen Folge von Log-Records**. Wichtige Konzepte:

- **LSN (Log Sequence Number):** monotone, eindeutig aufsteigende IDs, die jeden Log-Eintrag adressieren und eine **Kette** bilden.
    
- **Log-Record-Typen:** z. B. _Begin Tran_, _Commit_, _Abort_, _Insert/Update/Delete_ auf Zeilen, _Seiten- oder Extent-Allokationen_, _Index-Operationen_, _DDL_ usw.
    
- **Physische Organisation:** Die Logdatei ist intern in **VLFs (Virtual Log Files)** segmentiert. VLFs sind die minimalen Einheiten für **Trunkierung** (Freigabe) und bestimmen **Start/Ende** von Backup-Abschnitten.
    
- **Log-Puffer & Flush:** Im Arbeitsspeicher gibt es einen **Log-Puffer**. Er wird u. a. bei **Commit**, bei Füllstand oder periodisch **zwangsgeschrieben** („flush“) – **immer** vor dem Zurückschreiben der zugehörigen Datenseiten.
    

**Merke:** Das Log ist **append-only** (hintereinandergeschrieben). Lesen erfolgt sequenziell – ideal für **Replikation**, **HADR** & **Backups**.

* * *

## 3) Lebenszyklus einer Änderung

1. **Transaktion startet** → „Begin Tran“-Record.
    
2. **Änderungen** (DML/DDL) → je Operation **Log-Records** in den Log-Puffer.
    
3. **Commit** → „Commit“-Record wird geschrieben, **Log-Puffer** bis zum Commit-LSN **persistiert** (Flush zur LDF).
    
4. **Checkpoint** (zyklisch/ereignisgetrieben) schreibt **schmutzige Datenseiten** in die Datendateien; **WAL-Regel** stellt sicher, dass zugehörige Log-Records bereits auf Platte sind.
    

### Recovery nach Absturz (vereinfacht)

- **Analysis-Phase:** Welche Transaktionen liefen? Welche Seiten sind betroffen?
    
- **Redo-Phase:** Alle **committeten** Änderungen bis zum letzten LSN wiederholen (Vorwärtswiederherstellung).
    
- **Undo-Phase:** **Uncommittete** Transaktionen rückgängig machen (Rückwärtswiederherstellung).
    

* * *

## 4) Wofür werden Logs konkret genutzt?

- **Crash-Recovery:** Sicherstellen, dass nach Re-Start **alle Commits vorhanden** und **alle Abbrüche zurückgerollt** sind.
    
- **Backups & Restore:**
    
    - **Full/Diff-Backups** plus **Log-Backups** ermöglichen **Point-in-Time-Recovery**.
        
    - Log-Backups bilden eine **Kette** (per LSNs) zwischen Full/Diff-Backups.
        
- **Hochverfügbarkeit/Desaster Recovery (HADR):**
    
    - **Always On** (synchron/asynchron) transportiert Log-Records zu Replikas.
        
    - **Log Shipping**: periodische Auslieferung von Log-Backups auf Sekundärserver.
        
- **Transaktionsreplikation:** Ein **Log Reader** liest relevante Log-Records und verteilt sie an Abonnenten.
    
- **Change Data Capture (CDC):** Ein Agent liest das **Log**, schreibt Änderungen in **Change-Tabellen**.
    

* * *

## 5) Log-Trunkierung vs. physisches Schrumpfen

- **Trunkierung** bedeutet: Teile des Logs gelten als **wiederverwendbar** (frei für neue Einträge). Das ist **logisch**, ändert aber **nicht** zwangsläufig die **Dateigröße** (LDF bleibt physisch groß).
    
- **Physisches Schrumpfen** (`DBCC SHRINKFILE`) verkleinert die **Datei**. Das ist **sehr sparsam** zu verwenden:
    
    - Regelmäßiges Schrumpfen führt zu **Fragmentierung** im Log (viele kleine VLFs) und zu **Wachstumsspitzen**.
        
    - Besser: **sauber vorsizen**, **sinnvolle Autogrowth-Schritte** (MB/GB, nicht Prozent) und **Trunkierung** durch **Log-Backups** steuern.
        

**Trunkierungs-Trigger je nach Recovery Model:**

- **SIMPLE:** bei **Checkpoint** (sofern Log-Abschnitte nicht mehr benötigt werden).
    
- **FULL / BULK\_LOGGED:** **nur** nach **Log-Backup**.
    

* * *

## 6) Recovery Models & Minimal Logging

- **SIMPLE:** Keine Log-Backups; automatische Trunkierung. **Kein Point-in-Time-Restore.**
    
- **FULL:** Volle Protokollierung, Trunkierung **nur** per **Log-Backup**, **Point-in-Time** möglich.
    
- **BULK\_LOGGED:** Wie FULL, aber **minimal geloggte** Bulk-Operationen (unter Bedingungen). Log-Backups erforderlich; **Point-in-Time** kann **eingeschränkt** sein, wenn Bulk-Fenster betroffen sind.
    

**Minimal Logging** reduziert Log-Volumen für Massenlasten (z. B. `BULK INSERT`, `SELECT INTO`, bestimmte `INDEX REBUILD/REORGANIZE`\-Varianten). Nützlich für Performance, aber **Restore-Granularität** kann eingeschränkt sein.

* * *

## 7) VLFs (Virtual Log Files) – warum sie wichtig sind

- Jedes Wachstum der LDF erzeugt **VLFs**. Sehr **viele** VLFs (z. B. mehrere tausend) verlangsamen
    
    - **Recovery-Zeiten**,
        
    - **Log-Backups**,
        
    - **HADR/Replication** (mehr Verwaltungsoverhead).
        
- **Best Practice:**
    
    - Log **vor-dimensionieren** (z. B. direkt einige GB, passend zur Workload).
        
    - **Autogrowth in festen MB/GB-Schritten**, nicht in Prozent (z. B. 512 MB, 1 GB, 4 GB – je nach System).
        
    - VLF-Zahl **im niedrigen bis mittleren Hunderterbereich** halten; tausende vermeiden.
        
    - Bei „VLF-Explosion“: **einmalig shrinken** (gezielt) → **in großen Blöcken wieder wachsen lassen**, um **wenige, größere VLFs** zu erzeugen.


**Hilfreiche DMV/Kommandos (Version abhängig):**


```sql
/*
    Universelle Log-Infos (funktioniert quer über SQL-Server-Versionen)
    - @DbName: Ziel-Datenbank
    Ergebnis:
      1) Logbelegung: total_log_size_mb, used_log_space_in_percent
      2) VLF-Infos:   bevorzugt sys.dm_db_log_info(); Fallback: DBCC LOGINFO
*/

DECLARE @DbName sysname = N'BI_RAW';

/* -----------------------------------------------------------
   1) Logbelegung (robust über Versionen)
   ----------------------------------------------------------- */
BEGIN TRY
    -- Moderner Weg (SQL 2016 SP2+ / 2017 / 2019 / 2022 und Azure SQL):
    -- DMV ist kontextgebunden → in Ziel-DB ausführen.
    DECLARE @sql1 nvarchar(max) = N'
        USE ' + QUOTENAME(@DbName) + N';
        SELECT
            total_log_size_mb        = total_log_size_in_bytes / 1024.0 / 1024.0,
            used_log_space_in_percent
        FROM sys.dm_db_log_space_usage;';
    EXEC (@sql1);
END TRY
BEGIN CATCH
    -- Fallback für ältere Varianten: DBCC SQLPERF(LOGSPACE)
    -- Liefert alle DBs → auf @DbName filtern
    IF OBJECT_ID('tempdb..#LogSpace') IS NOT NULL DROP TABLE #LogSpace;
    CREATE TABLE #LogSpace
    (
        DatabaseName       sysname,
        LogSizeMB          float,
        LogSpaceUsedPct    float,
        [Status]           int
    );

    INSERT INTO #LogSpace
    EXEC ('DBCC SQLPERF(LOGSPACE)');

    SELECT
        total_log_size_mb         = LogSizeMB,
        used_log_space_in_percent = LogSpaceUsedPct
    FROM #LogSpace
    WHERE DatabaseName = @DbName;

    DROP TABLE #LogSpace;
END CATCH;

/* -----------------------------------------------------------
   2) VLF-Infos (Virtual Log Files)
      Bevorzugt sys.dm_db_log_info(); Fallback: DBCC LOGINFO
   ----------------------------------------------------------- */
PRINT '--- VLF-Informationen ---';
BEGIN TRY
    -- Verfügbar ab SQL 2016 SP2 (und neuer sowie Azure SQL/MI):
    SELECT *
    FROM sys.dm_db_log_info(DB_ID(@DbName));
END TRY
BEGIN CATCH
    -- Fallback (undokumentiert, aber weit verbreitet):
    DECLARE @sql2 nvarchar(400) =
        N'DBCC LOGINFO(' + QUOTENAME(@DbName,'''') + N')';
    EXEC (@sql2);
END CATCH;

```

**Hinweise:**

- Der erste Block versucht die moderne DMV **`sys.dm_db_log_space_usage`** kontextgebunden in der Ziel-DB auszulesen; wenn das in deiner Version nicht verfügbar ist, fällt er automatisch auf **`DBCC SQLPERF(LOGSPACE)`** zurück und filtert auf die gewünschte DB.
    
- Für **VLF-Details** nutzt der zweite Block bevorzugt **`sys.dm_db_log_info()`**; falls das nicht vorhanden ist, wird **`DBCC LOGINFO(<DbName>)`** ausgeführt (undokumentiert, aber bewährt).
    
- Das Skript liefert zwei Resultsets: zuerst die **Logbelegung**, danach die **VLF-Infos**.


## 8) Warum das Log „nicht frei wird“ – typische Ursachen

In `sys.databases.log_reuse_wait_desc` siehst du, **warum** nicht getrimmt wird, z. B.:

- `ACTIVE_TRANSACTION` – lange Transaktion offen (auch „verwaiste“/inaktive Sessions!).
    
- `LOG_BACKUP` – bei FULL/BULK\_LOGGED fehlt ein Log-Backup.
    
- `REPLICATION` / `AVAILABILITY_REPLICA` – Log wird für Replikation/HADR benötigt (Stau auf Sekundär).
    
- `ACTIVE_BACKUP_OR_RESTORE` – laufendes Backup/Restore blockiert Trunkierung.
    
- `CHECKPOINT` – Checkpoint ausständig.
    
- `OTHER_TRANSIENT` – temporäre Zustände.
    

**Vorgehen:** Grund **gezielt** adressieren (Transaktion abschließen, HADR-Queue prüfen, Log-Backup fahren, Checkpoint etc.).

* * *

## 9) Größe & Wachstum – Performance-Aspekte

- **Pre-Size**: Setze die Logdatei auf eine **realistische Startgröße** (z. B. 8–32 GB oder mehr – abhängig von Workload, Batch-Fenstern, Rebuild-Strategien).
    
- **Autogrowth**: **Feste MB/GB-Schritte**, nicht Prozent. Wenige große Sprünge sind besser als viele kleine.
    
- **Instant File Initialization (IFI)** gilt **nicht** für Logdateien – das **Wachsen** kann daher spürbar dauern. Noch ein Grund, **Wachstumsvorgänge zu minimieren**.
    
- **Ein Logfile pro Datenbank** ist **empfohlen**. Mehrere Logfiles bringen **keinen Durchsatzvorteil** (sie werden nicht parallel beschrieben) und erschweren Verwaltung.


## 10) Monitoring & Werkzeuge


### **Belegung & Füllgrad:**

**<u>Was funktioniert auf welchen Versionen?</u>**

- **`sys.dm_db_log_space_usage`**
    
    - **Verfügbar ab SQL Server 2012** (11.x) und in allen neueren Versionen (2014/2016/2017/2019/2022), inkl. **Azure SQL Database** und **Azure SQL Managed Instance**.
        
    - **Wichtig:** Die DMV ist **Datenbank-kontextsensitiv** → vorher `USE <DB>` (so wie im Code oben per dynamischem `EXEC` gelöst).
        
    - **Spaltennamen:** u. a. `total_log_size_in_bytes`, `used_log_space_in_percent`.
        
    - **Hinweis:** Es gibt **keine** Spalte `used_log_space_pct`.
        
- **`DBCC SQLPERF(LOGSPACE)`** (Fallback im TRY/CATCH)
    
    - Sehr breit verfügbar (ältere On-Premises-Versionen inkl. SQL Server 2005/2008/2008R2).
        
    - Liefert eine Zeile **pro Datenbank** mit `Log Size (MB)` und `Log Space Used (%)`.
        
    - Im Code wird daraus auf einheitliche Spaltennamen **gemappt**.
        
- **Verwandte DMVs (optional, nicht im Code):**
    
    - `sys.dm_db_log_info(DB_ID())` – detaillierte VLF-Infos, ab **SQL Server 2016 SP2**/neuer.
        
    - `sys.dm_db_log_stats(DB_ID())` – zusätzliche Log-Statistiken, ab **SQL Server 2019**/Azure.
        

Mit der  TRY/CATCH-Strategie bekommst du **immer** ein Ergebnis in den stabilen Spalten  
`total_log_size_mb` und `used_log_space_in_percent` – unabhängig davon, ob die moderne DMV verfügbar ist.

<u>weiterführende Links:</u>

- [sys.dm\_db\_log\_space\_usage (Transact-SQL)](https:\learn.microsoft.com\en-us\sql\relational-databases\system-dynamic-management-views\sys-dm-db-log-space-usage-transact-sql?view=sql-server-ver16)
- [SQL SERVER – Introduction to Log Space Usage DMV – sys.dm\_db\_log\_space\_usage](https:\blog.sqlauthority.com\2018\01\09\sql-server-introduction-log-space-usage-dmv-sys-dm_db_log_space_usage\)


```sql
DECLARE @DbName sysname = N'BI_RAW';

-- Ergebnis-Puffer mit stabilen Spaltennamen
IF OBJECT_ID('tempdb..#Log') IS NOT NULL DROP TABLE #Log;
CREATE TABLE #Log
(
    total_log_size_mb           decimal(18,2),
    used_log_space_in_percent   decimal(5,2)
);

BEGIN TRY
    -- Moderner Weg (seit SQL Server 2012+, siehe Erläuterung):
    DECLARE @sql nvarchar(max) = N'
        USE ' + QUOTENAME(@DbName) + N';
        SELECT
            total_log_size_mb         = CAST(total_log_size_in_bytes/1024.0/1024.0 AS decimal(18,2)),
            used_log_space_in_percent = CAST(used_log_space_in_percent AS decimal(5,2))
        FROM sys.dm_db_log_space_usage;';
    INSERT INTO #Log(total_log_size_mb, used_log_space_in_percent)
    EXEC (@sql);
END TRY
BEGIN CATCH
    -- Fallback: funktioniert auch auf sehr alten Versionen
    IF OBJECT_ID('tempdb..#LogSpace') IS NOT NULL DROP TABLE #LogSpace;
    CREATE TABLE #LogSpace
    (
        DatabaseName     sysname,
        LogSizeMB        float,
        LogSpaceUsedPct  float,
        [Status]         int
    );
    INSERT INTO #LogSpace EXEC('DBCC SQLPERF(LOGSPACE)');
    INSERT INTO #Log(total_log_size_mb, used_log_space_in_percent)
    SELECT
        CAST(LogSizeMB AS decimal(18,2)),
        CAST(LogSpaceUsedPct AS decimal(5,2))
    FROM #LogSpace
    WHERE DatabaseName = @DbName;
END CATCH;

-- Einheitliche Ausgabe (eine Zeile für @DbName)
SELECT
    total_log_size_mb,
    used_log_space_in_percent
FROM #Log;

```

### **Trunkierungsgrund**

Die Spalte **`log_reuse_wait_desc`** in `sys.databases` zeigt **warum SQL Server das Transaktionslog aktuell nicht „trunkieren“ (wiederverwenden)** kann.  
Wichtig: **Trunkierung** gibt _internen Lograum_ wieder frei, **verkleinert aber nicht die physische LDF-Datei**. Physisches Verkleinern erfolgt separat via `DBCC SHRINKFILE` und ist nur sinnvoll, wenn zuvor ausreichend Logabschnitte freigegeben wurden.

<u>Häufige `log_reuse_wait_desc`\-Werte (Bedeutung & Maßnahmen)</u>

| Wert | Bedeutung (Warum wird nicht getrimmt?) | Was prüfen / tun |
| --- | --- | --- |
| **NOTHING** | Es gibt **keinen** Blocker; das Log **kann** getrimmt werden (abhängig vom Recovery Model). | Bei **FULL/BULK\_LOGGED**: ein **LOG-Backup** ausführen, damit die Trunkierung passiert. Bei **SIMPLE** reicht der nächste **CHECKPOINT**. |
| **CHECKPOINT** | Ein **Checkpoint** steht aus; bis dahin sind Teile des Logs noch nötig. | Manuell **`CHECKPOINT;`** in der DB ausführen (oder abwarten, bis der reguläre Checkpoint läuft). |
| **LOG\_BACKUP** | In **FULL/BULK\_LOGGED** wurde **zuletzt kein Log-Backup** durchgeführt; daher keine Trunkierung. | **`BACKUP LOG <DB>`** durchführen. Regelmäßige Log-Backup-Jobs einrichten (z. B. alle 5–15 Min.). |
| **ACTIVE\_TRANSACTION** | Es läuft eine **aktive (lange) Transaktion**; deren Logbereich darf nicht freigegeben werden. | Lange Transaktionen identifizieren (z. B. per `sys.dm_tran_session_transactions`, `sys.dm_exec_requests`) und beenden/abschließen; ggf. Anwendungen prüfen. |
| **ACTIVE\_BACKUP\_OR\_RESTORE** | Während eines **Backup-/Restore-Vorgangs** hält SQL Server Logabschnitte zurück. | Backup-/Restore-Status prüfen; Vorgang **abschließen** lassen. |
| **REPLICATION** | Für **Transaktionsreplikation** (oder Logreader-Szenarien) müssen Logdatensätze noch abgearbeitet werden. | Replikations-Agents prüfen (laufen sie? Rückstau?). Fehlermeldungen/Latencies im Repl-Monitoring beheben. |
| **AVAILABILITY\_REPLICA** | In **Always On AG** ist eine Replik(a) **nicht nachgezogen**; Log bleibt bis zur Bestätigung erhalten. | HADR-Gesundheit prüfen (Queue, Latenz, Synchronisierung). Netzwerk/Redo-Waits/Fehler auf Sekundär beheben. |
| **DATABASE\_MIRRORING** _(ältere Versionen)_ | Bei **Mirroring** ist der Partner im Rückstand; Log darf noch nicht freigegeben werden. | Mirroring-Status prüfen; Synchronität wiederherstellen. |
| **DATABASE\_SNAPSHOT\_CREATION** | Während der **Erstellung eines DB-Snapshots** werden bestimmte Logbereiche benötigt. | Snapshot-Erstellung abwarten bzw. deren Status prüfen. |
| **LOG\_SCAN** | SQL Server muss Logeinträge noch **scannen** (z. B. für Recovery/Crash-Recovery/Interne Prozesse). | Kurzfristig; typischerweise **vorübergehend**. Abwarten, Server-/Fehlerlog prüfen, ob ungewöhnlich lange dauert. |
| **OLDEST\_PAGE** | Ein sehr **alte Seite** (z. B. mit Snapshot/Versionen) erfordert Aufbewahrung von Logeinträgen. | Vorhandene **Snapshots** prüfen bzw. row versioning/long-running Readers analysieren. |
| **XTP\_CHECKPOINT** | **Memory-optimized** (In-Memory OLTP) Checkpoint ist ausständig; Logeinträge werden noch benötigt. | XTP-Checkpoint-Status prüfen, In-Memory-Objekte/Last analysieren. |
| **OTHER\_TRANSIENT** | **Vorübergehender** Zustand ohne dauerhafte Ursache. | Meist **kurzzeitig**; erneut prüfen. Falls dauerhaft: Fehlerlog/DMVs auf Hinweise durchsuchen. |

> Hinweis: Die tatsächlich möglichen Texte können je nach **SQL-Server-Version** leicht variieren; die obige Tabelle deckt die gängigen Gründe ab.

* * *

**<u>Praxisleitfaden</u>**

1. **Recovery Model klären**
    
    - **SIMPLE**: Trunkierung passiert bei **Checkpoint** automatisch (sofern kein Blocker).
        
    - **FULL/BULK\_LOGGED**: Trunkierung passiert **nur** nach **Log-Backup** – _und_ nur, wenn kein Blocker vorliegt.
        
2. **Blocker gezielt beheben**
    
    - `LOG_BACKUP` → **LOG-Backup** fahren.
        
    - `ACTIVE_TRANSACTION` → lange Transaktionen identifizieren und sauber beenden.
        
    - `REPLICATION`/`AVAILABILITY_REPLICA` → **Queues/Latenzen** auflösen, Agents/Replikas stabilisieren.
        
    - `ACTIVE_BACKUP_OR_RESTORE`/`DATABASE_SNAPSHOT_CREATION` → **abwarten** bis fertig.
        
    - `CHECKPOINT` → **`CHECKPOINT;`** ausführen.
        
3. **Erst wenn `log_reuse_wait_desc = NOTHING`** (oder ein kurzlebiger, unkritischer Grund) und—bei FULL/BULK\_LOGGED—**ein Log-Backup erfolgt ist**, kann ein **Shrinken** der LDF-Datei _wirkung zeigen_ (und ist nur dann in Ausnahmen zu empfehlen).


```sql
SELECT name, recovery_model_desc, log_reuse_wait_desc
FROM sys.databases
WHERE name = N'BI_RAW';
```

<u>**Alle Datenbanken mit aktuellem Trunkierungsgrund:**</u>


```sql
SELECT name,
       recovery_model_desc,
       log_reuse_wait_desc
FROM sys.databases
ORDER BY
  CASE log_reuse_wait_desc WHEN 'NOTHING' THEN 1 ELSE 0 END,
  name;
```

**<u>Lange Transaktionen finden (Beispiel):</u>**


```sql
SELECT s.session_id, r.status, r.command, r.start_time,
       DB_NAME(r.database_id) AS dbname,
       r.percent_complete, t.transaction_id
FROM sys.dm_exec_requests r
LEFT JOIN sys.dm_tran_session_transactions t ON t.session_id = r.session_id
LEFT JOIN sys.dm_exec_sessions s ON s.session_id = r.session_id
WHERE r.database_id = DB_ID(N'BI_RAW')
ORDER BY r.start_time;

```

### **<u>Merksätze</u>**

- **Trunkierung ≠ Shrink.** Trunkierung macht Logsegmente wiederverwendbar; Shrink verkleinert die Datei physisch.
    
- In **FULL/BULK\_LOGGED** ohne **LOG-Backups** wird die LDF **immer weiter wachsen**.
    
- **Shrinks sparsam einsetzen**: Besser passend **vorsizen** und **Autogrowth (MB/GB, nicht %) sinnvoll** konfigurieren.
    
- `log_reuse_wait_desc` ist dein **Kompass**: Er zeigt, **warum** kein Platz freigegeben wird – und damit **wo** du ansetzen musst.


### **Logspace über alle Datenbanken:**

**weiterführende Links:**

- [DBCC SQLPERF (Transact-SQL)](https:\learn.microsoft.com\en-us\sql\t-sql\database-console-commands\dbcc-sqlperf-transact-sql?view=sql-server-ver17)


```sql
DBCC SQLPERF(LOGSPACE);
```

**Diagnose einzelner Log-Records:**  
`fn_dblog` <span style="color: var(--vscode-foreground);">&nbsp;/&nbsp;</span> `DBCC LOG` <span style="color: var(--vscode-foreground);">&nbsp;sind&nbsp;</span> **undokumentiert** <span style="color: var(--vscode-foreground);">&nbsp;bzw. nur für&nbsp;</span> **forensische** <span style="color: var(--vscode-foreground);">&nbsp;Analysen gedacht – vorsichtig verwenden.</span>


## 11) Typische Anti-Pattern & Best Practices

**Vermeiden:**

- **Regelmäßiges Schrumpfen** der LDF „weil sie groß ist“. Besser: **richtige Größe** finden, **regelmäßige Log-Backups**, sauberes **Autogrowth**.
    
- **Prozentuale** Autogrowth-Werte (führen bei großen Dateien zu gigantischen Sprüngen, bei kleinen zu vielen Mini-VLFs).
    
- **Viele parallele Index-Rebuilds** ohne Planung – erzeugen massives Logaufkommen.
    
- **Lange offene Transaktionen** (z. B. vergessenes `BEGIN TRAN`/`COMMIT` in Batch-Skripten).
    

**Empfohlen:**

- **Recovery Model passend zur Anforderung** wählen (Point-in-Time nötig? ⇒ FULL).
    
- **Regelmäßige Log-Backups** (z. B. alle 5–15 Minuten in OLTP-Systemen).
    
- **VLF-Zahl** überwachen und ggf. korrigieren (gezieltes Shrink + kontrolliertes Wachstum).
    
- **Autogrowth in MB/GB** und **Vor-Sizing**.
    
- **Jobs & Alerts** für `log_reuse_wait_desc`, ungewöhnliche `used_log_space_pct`, fehlschlagende Backups.
    

* * *

## 12) Zusammenfassung

- Das **Transaktionslog** ist das **lineare Änderungsprotokoll** der Datenbank – Herzstück für **Transaktionssicherheit**, **Recovery** und **Wiederherstellbarkeit**.
    
- **WAL** garantiert: **Log zuerst**, dann **Daten** – so bleiben Commits sicher.
    
- **SIMPLE**: Trunkierung bei **Checkpoint**, **keine** Log-Backups, **kein** Point-in-Time.  
    **FULL/BULK\_LOGGED**: Trunkierung **nur** durch **Log-Backups**, **Point-in-Time** möglich (mit Einschränkungen bei BULK\_LOGGED).
    
- **Full-Backup** ist die **Baseline** der Log-Kette; ohne sie schlägt das erste Log-Backup mit **Fehler 4214** fehl.
    
- **Größe/VLFs** aktiv managen (Pre-Size, MB/GB-Autogrowth, VLF-Count im Blick), **regelmäßige Log-Backups** planen, **Ursachen** für ausbleibende Trunkierung gezielt beheben.
    

Mit diesem Verständnis kannst du fundierte Entscheidungen zu **Recovery Model**, **Backup-Strategie**, **HADR-Design** und **Performance-Tuning** des Logs treffen – und Probleme wie **unkontrolliertes Logwachstum** oder **lange Recovery-Zeiten** proaktiv vermeiden.


## Log-Analyse mit Backup-Checks, Shrink-Empfehlung & Max-Growth

## Zweck & Nutzen

Das Skript analysiert **alle (oder gefilterte)** Datenbanken einer SQL-Server-Instanz hinsichtlich ihres **Transaktionslogs** und erstellt:

1. Eine **Detailtabelle je Datenbank** mit:
    
    - aktueller Loggröße und Auslastung
        
    - Recovery Model & `log_reuse_wait_desc`
        
    - Backup-Status (Full/Log), Alter des letzten Log-Backups
        
    - **standardisierte Empfehlung**: „**shrink**“ oder „**don’t shrink**“
        
    - **Projected Size After Shrink** (MB/GB) – falls ein Shrink empfohlen wird
        
2. Eine **Summary** über alle (gefilterten) Datenbanken:
    
    - **aktueller Gesamt-Logplatz** vs. **projizierter Gesamt-Logplatz** (wenn überall empfohlenes Shrink ausgeführt würde)
        
    - **Einsparpotenzial** (MB/GB)
        
3. **Pro-Logfile-Details**:
    
    - Autogrowth-Einstellungen (MB oder %)
        
    - Maximalgröße (MB/GB bzw. UNLIMITED)
        
    - verbleibendes Wachstum bis zur Maximalgröße
        
    - physischer Pfad
        

> Das Skript **führt kein Shrink** aus. Es liefert **Transparenz** und eine **handlungsleitende Empfehlung**, damit der operative Shrink (separater Job/Prozedur) fundiert und sicher erfolgen kann.

* * *

## Ein-/Ausgabeverhalten

### Eingangsparameter (am Kopf des Skripts)

- `@DbNameFilter sysname = NULL`  
    Filter auf **eine** Datenbank (z. B. `N'BI_RAW'`). `NULL` = **alle** Datenbanken.
    
- `@MaxLogBackupAgeMinutes int = 120`  
    **Frische-Schwelle** fürs **letzte Log-Backup**. Älter ⇒ Empfehlung eher _don’t shrink_ in FULL/BULK\_LOGGED.
    
- `@ResultFillPct int = 90`  
    **Ziel-Füllgrad** (%) nach Shrink. Dient der **Zielgrößenberechnung**.
    
- `@MinTargetMB int = 256`  
    **Mindestzielgröße** (MB) nach Shrink (Untergrenze).
    

### Output 1: **Detailergebnis je Datenbank** (`#LogDetail`)

Wichtige Spalten (Auszug):

- **Database Name** – Name der DB
    
- **Log Size (MB/GB)** – aktuelle physische Größe des Transaktionslogs
    
- **Log Space Used (%)** – relativer Nutzungsgrad (aus `DBCC SQLPERF(LOGSPACE)`)
    
- **Recovery Model** – `SIMPLE`, `FULL` oder `BULK_LOGGED`
    
- **Log Reuse Wait** – Grund, warum Log noch nicht getrimmt wird (z. B. `ACTIVE_TRANSACTION`, `LOG_BACKUP`, …)
    
- **Used (MB/GB)** – theoretisch aktuell belegter Platz
    
    - Formel: `UsedMB = LogSizeMB * (LogSpaceUsedPct / 100.0)`
        
- **Has Full Backup / Has Log Backup** – 1/0 anhand `msdb.dbo.backupset`
    
- **Age of Log Backup (min)** – Minuten seit letztem Log-Backup (NULL, wenn keines existiert)
    
- **Last Full/Log Backup At** – Zeitstempel der letzten Backups
    
- **Recommendation** – „**shrink**“ oder „**don’t shrink**“
    
- **Projected Size After Shrink (MB/GB)** – Zielgröße, **nur gefüllt bei Empfehlung `shrink`**
    
    - Formel (MB):
        
        ```
        NeededMB   = UsedMB / (ResultFillPct / 100)
        TargetMB   = CEILING(NeededMB)
        Projected  = MAX(TargetMB, MinTargetMB)
        
        ```
        
        (entspricht: „belegter Platz plus Puffer“; kein Ziel kleiner als `@MinTargetMB`)
        

### Output 2: **Summary über alle Datenbanken**

- **CurrentTotalMB/GB** – Summe der aktuellen Loggrößen
    
- **ProjectedTotalMB/GB** – Summe, bei der für DBs mit „shrink“ die _Projected Size_ eingesetzt wird (sonst aktuelle Größe)
    
- **SavingsMB/GB** – Einsparpotenzial = Current − Projected
    

### Output 3: **Pro-Logfile-Details** (`#LogFiles`)

Pro **Logdatei** (nicht nur pro DB):

- **Growth Type** – `MB` oder `PERCENT`
    
- **Growth (MB)** – Wachstumsinkrement in MB (falls GrowthType = MB)
    
- **Growth (%)** – Wachstumsprozentsatz (falls GrowthType = PERCENT)
    
- **Max Size (MB/GB)** – maximale Größe (NULL = „UNLIMITED“)
    
- **Remaining to Max (MB/GB)** – verbleibender Spielraum bis Max (NULL bei „UNLIMITED“)
    
- **Physical Name** – physischer Dateipfad
    

**Hinweis zu Einheiten:**  
`sys.master_files.size`, `.growth`, `.max_size` sind **8-KB-Pages** (außer `.growth` bei Prozent-Wachstum ⇒ Prozentwert).  
Umrechnung:

- MB = `pages * 8 / 1024`
    
- GB = `pages * 8 / 1024 / 1024`
    

* * *

## Datenquellen & technische Basis

- **Loggröße & Auslastung**: `DBCC SQLPERF(LOGSPACE)` → in **#LogSpace** materialisiert.
    
- **Recovery Model & Reuse-Wait**: `sys.databases` (Spalten `recovery_model_desc`, `log_reuse_wait_desc`).
    
- **Backup-Historie**: `msdb.dbo.backupset` (Aggregation via CTE `BackupAgg` auf `MAX(backup_finish_date)` für `[type] = 'D'` Full und `[type] = 'L'` Log).
    
- **Autogrowth & Max Size**: `sys.master_files` gefiltert auf `type_desc='LOG'`.
    

* * *

## Entscheidungslogik „Recommendation“

Ziel: **sinnvolles, risikoarmes** Shrink-Signal.

### SIMPLE

- Wenn **Log Space Used (%) \< 20 %** → **„shrink“**
    
- Sonst → **„don’t shrink“**
    

### FULL / BULK\_LOGGED

**Alle** Bedingungen müssen erfüllt sein, sonst → „don’t shrink“:

1. `Has Full Backup = 1` (Baseline vorhanden)
    
2. `Has Log Backup = 1` (Trunkierung grundsätzlich möglich)
    
3. **Alter des letzten Log-Backups** ≤ `@MaxLogBackupAgeMinutes`
    
4. `log_reuse_wait_desc` **nicht** in  
    `('LOG_BACKUP','ACTIVE_TRANSACTION','ACTIVE_BACKUP_OR_RESTORE','REPLICATION','AVAILABILITY_REPLICA')`  
    (→ andernfalls wird Log gerade **berechtigterweise nicht getrimmt**)
    
5. **Log Space Used (%) \< 20 %**
    

**Begründung:**

- In FULL/BULK\_LOGGED **trunkiert** SQL Server das Log **nur** durch **Log-Backups**; „ur-große“ Logs ohne frisches Log-Backup oder mit aktiven Wiederverwendungs-Blockern werden durch Shrink **nicht** nachhaltig kleiner.
    
- `< 20 %` als Schwelle ist ein **konservativer Richtwert** – kann projektspezifisch angepasst werden.
    

* * *

## Projektion der Zielgröße (nur bei „shrink“)

**Formel:**

```
UsedMB     = LogSizeMB * (Used% / 100)
NeededMB   = UsedMB / (ResultFillPct / 100)
TargetMB   = CEILING(NeededMB)
ProjectedMB= MAX(TargetMB, MinTargetMB)
ProjectedGB= ProjectedMB / 1024

```

**Beispiel:**

- LogSize = 10 000 MB, Used% = 35 %, ResultFillPct = 90 %, MinTargetMB = 256
    
- UsedMB = 3 500
    
- NeededMB = 3 500 / 0,90 = 3 888,89 → TargetMB = 3 889
    
- Projected = MAX(3 889, 256) = **3 889 MB**
    

* * *

## Summary-Berechnungen

- **CurrentTotalMB** = `SUM([Log Size (MB)])`
    
- **ProjectedTotalMB** = `SUM(CASE WHEN Recommendation='shrink' AND Projected IS NOT NULL THEN Projected ELSE LogSizeMB END)`
    
- **SavingsMB** = `CurrentTotalMB - ProjectedTotalMB`
    
- GB-Werte = jeweilige MB-Werte `/ 1024.0`
    

* * *

## Berechtigungen & Kompatibilität

- **Lesen** aus `sys.databases`, `sys.master_files` erfordert übliche Sichtrechte.
    
- **msdb.dbo.backupset**: Standardmäßig lesbar; je nach Umgebung evtl. Rolle `msdb`\-`db_datareader` nötig.
    
- Verwendet **keine** undocumented Funktionen außer `DBCC SQLPERF(LOGSPACE)` (dies ist offiziell dokumentiert).
    
- **Azure SQL Database (PaaS)**: `msdb`\-Backuphistorie und `DBCC SQLPERF` können abweichen; auf **Managed Instance** i. d. R. kompatibel.
    

* * *

## Performance & Betrieb

- `DBCC SQLPERF(LOGSPACE)` liefert **alle DBs**; bei großen Umgebungen kann ein **Filter** mit `@DbNameFilter` sinnvoll sein.
    
- `backupset`\-Abfrage nutzt `MAX(backup_finish_date)` **ohne Zeitfilter** – stellt sicher, dass auch ältere, aber gültige Backups erkannt werden. (Optional kann ein Retention-Fenster ergänzt werden.)
    
- **Temp-Tabellen** (`#LogSpace`, `#LogDetail`, `#LogFiles`) werden **vorher gedroppt** ∴ mehrfach ausführbar.
    
- `SET NOCOUNT ON` reduziert Output-Noise.
    

* * *

## Typische Anwendungsfälle

- **Kapazitätsreporting**: Wo liegen große Logs, wie hoch ist das Einsparpotenzial?
    
- **Wartungsfensterplanung**: Welche DBs sind **sicher** shrink-fähig (inkl. Backup-Checks)?
    
- **Autogrowth-Audit**: Wo sind Prozent-Wachstum oder fehlende Max-Größen definiert (Risiko unkontrollierten Wachstums)?
    

* * *

## Best Practices & Hinweise

- **Shrink gezielt** einsetzen, nicht als Dauermaßnahme.
    
- Logs **vorsizen** (realistische Startgrößen), **Autogrowth in MB/GB** statt Prozent.
    
- Bei **sehr vielen VLFs** (Virtual Log Files) kann ein einmaliger **Shrink + kontrolliertes Wiederwachstum** sinnvoll sein.
    
- **Ursachen** für hohe Nutzung prüfen (`log_reuse_wait_desc`), bevor man shrinkt: offene Transaktionen, fehlende Log-Backups, HADR-Stau usw.
    

* * *

## Troubleshooting (häufige Stolpersteine)

- **„Invalid column name …“**  
    Entsteht meist durch **Alias-Mismatches**. In der finalen Version werden Spalten konsistent via `SELECT … INTO #LogDetail` erzeugt.
    
- **„Incorrect syntax near CREATE“**  
    Tritt auf, wenn nach einer `;WITH`\-CTE nicht **direkt** genau **eine** Anweisung folgt. In der finalen Version folgt direkt das `SELECT … INTO`.
    
- **„There is already an object named ‘#…’“**  
    Temp-Tabellen werden vor Anlage **gedroppt**; bei manuellen Änderungen immer `DROP TABLE` voranstellen.
    

* * *

## Anpassungen & Erweiterungen (optional)

- **Threshold anpassen**: `@MaxLogBackupAgeMinutes`, `@ResultFillPct`, `@MinTargetMB`, Schwelle `< 20 %` für „shrink“.
    
- **Begründungs-Spalte** ergänzen: Neben „Recommendation“ eine **Reason** (z. B. „missing full backup“, „reuse wait = ACTIVE\_TRANSACTION“, …).
    
- **Stored Procedure**: Skript als `dbo.usp_LogSpaceOverviewWithRecommendation` kapseln; Parameter sichtbar machen.
    
- **Export**: Ergebnis als CSV (z. B. via SQL Agent Job + `sqlcmd`/`bcp`).
    

* * *

## Beispiel: Interpretation eines Eintrags

- `Database Name = BI_RAW`
    
- `Log Size (MB) = 10 240`, `Log Space Used (%) = 12,5` → `Used (MB) = 1280`
    
- Recovery Model `FULL`, `Has Full Backup = 1`, `Has Log Backup = 1`
    
- `Age of Log Backup (min) = 15` (≤ 120)
    
- `log_reuse_wait_desc = NOTHING`
    
- **Recommendation = shrink**
    
- `Projected Size After Shrink (MB)` = `max(256, CEILING(1280 / 0,9)) = 1423`  
    → Shrink von 10 240 MB auf ~1 423 MB sinnvoll.


```sql
/* ============================================================================
   Universelle Log-Übersicht inkl. Backup-Checks, Empfehlung & Projektion
   - @DbNameFilter            : NULL = alle DBs; sonst z. B. N'BI_RAW'
   - @MaxLogBackupAgeMinutes  : maximale "Frische" des letzten Log-Backups
   - @ResultFillPct           : Ziel-Füllgrad (%) nach Shrink (Default 90)
   - @MinTargetMB             : Mindestzielgröße (MB) nach Shrink (Default 256)
   Ergebnis:
     (1) #LogDetail: je DB inkl. Projected Size After Shrink (MB/GB)
     (2) Summary: Current vs. Projected vs. Savings (MB/GB)
     (3) #LogFiles: pro Logfile Autogrowth & Max Size
   ============================================================================ */

SET NOCOUNT ON;

DECLARE @DbNameFilter            sysname = NULL;  -- z.B. N'BI_RAW' (NULL = alle)
DECLARE @MaxLogBackupAgeMinutes  int     = 120;   -- Policy-Grenze für "frisches" Log-Backup
DECLARE @ResultFillPct           int     = 90;    -- Ziel-Füllgrad (%) nach Shrink
DECLARE @MinTargetMB             int     = 256;   -- Mindestgröße (MB) nach Shrink

PRINT 'Aktuelle Logspace-Nutzung (mit Backup-Checks, Empfehlung & Projektion):';

IF OBJECT_ID('tempdb..#LogSpace')  IS NOT NULL DROP TABLE #LogSpace;
IF OBJECT_ID('tempdb..#LogDetail') IS NOT NULL DROP TABLE #LogDetail;
IF OBJECT_ID('tempdb..#LogFiles')  IS NOT NULL DROP TABLE #LogFiles;

CREATE TABLE #LogSpace
(
    DatabaseName     sysname,
    LogSizeMB        float,
    LogSpaceUsedPct  float,
    [Status]         int
);

-- Quelle für Loggröße/-auslastung (alle DBs)
INSERT INTO #LogSpace
EXEC('DBCC SQLPERF(LOGSPACE)');

;WITH BackupAgg AS
(
    SELECT
        bs.database_name,
        LastFullBackup = MAX(CASE WHEN bs.[type] = 'D' THEN bs.backup_finish_date END),
        LastLogBackup  = MAX(CASE WHEN bs.[type] = 'L' THEN bs.backup_finish_date END)
    FROM msdb.dbo.backupset bs
    GROUP BY bs.database_name
),
Detail AS
(
    SELECT
        ls.DatabaseName                                        AS [Database Name],
        CAST(ls.LogSizeMB AS decimal(18,2))                    AS [Log Size (MB)],
        CAST(ls.LogSpaceUsedPct AS decimal(5,2))               AS [Log Space Used (%)],
        ls.[Status]                                            AS [Status],
        sd.recovery_model_desc                                 AS [Recovery Model],
        sd.log_reuse_wait_desc                                 AS [Log Reuse Wait],
        -- theoretisch belegter Platz
        UsedMB = CAST(ls.LogSizeMB * (ls.LogSpaceUsedPct/100.0) AS decimal(18,2)),
        UsedGB = CAST(ls.LogSizeMB * (ls.LogSpaceUsedPct/100.0) / 1024.0 AS decimal(18,3)),
        HasFullBackup = CASE WHEN ba.LastFullBackup IS NOT NULL THEN 1 ELSE 0 END,
        HasLogBackup  = CASE WHEN ba.LastLogBackup  IS NOT NULL THEN 1 ELSE 0 END,
        AgeOfLogBackupMin = CAST(CASE
                                   WHEN ba.LastLogBackup IS NULL THEN NULL
                                   ELSE DATEDIFF(MINUTE, ba.LastLogBackup, GETDATE())
                                 END AS int),
        LastFullBackupAt = ba.LastFullBackup,
        LastLogBackupAt  = ba.LastLogBackup,
        -- Empfehlung
        Recommendation =
            CASE
                WHEN sd.recovery_model_desc = 'SIMPLE' THEN
                    CASE WHEN ls.LogSpaceUsedPct < 20.0
                         THEN 'shrink'
                         ELSE 'don''t shrink'
                    END
                WHEN sd.recovery_model_desc IN ('FULL','BULK_LOGGED') THEN
                    CASE
                        WHEN ba.LastFullBackup IS NULL
                             OR ba.LastLogBackup IS NULL
                             OR DATEDIFF(MINUTE, ba.LastLogBackup, GETDATE()) > @MaxLogBackupAgeMinutes
                             OR sd.log_reuse_wait_desc IN ('LOG_BACKUP','ACTIVE_TRANSACTION',
                                                           'ACTIVE_BACKUP_OR_RESTORE','REPLICATION',
                                                           'AVAILABILITY_REPLICA')
                        THEN 'don''t shrink'
                        WHEN ls.LogSpaceUsedPct < 20.0
                        THEN 'shrink'
                        ELSE 'don''t shrink'
                    END
                ELSE 'don''t shrink'
            END,
        -- Projektierte Zielgröße NUR falls "shrink" empfohlen:
        ProjectedSizeMB =
            CAST(CASE
                     WHEN
                     (
                         (sd.recovery_model_desc = 'SIMPLE' AND ls.LogSpaceUsedPct < 20.0)
                      OR (sd.recovery_model_desc IN ('FULL','BULK_LOGGED')
                          AND ba.LastFullBackup IS NOT NULL
                          AND ba.LastLogBackup  IS NOT NULL
                          AND DATEDIFF(MINUTE, ba.LastLogBackup, GETDATE()) <= @MaxLogBackupAgeMinutes
                          AND sd.log_reuse_wait_desc NOT IN ('LOG_BACKUP','ACTIVE_TRANSACTION',
                                                             'ACTIVE_BACKUP_OR_RESTORE','REPLICATION',
                                                             'AVAILABILITY_REPLICA')
                          AND ls.LogSpaceUsedPct < 20.0)
                     )
                     THEN
                        CASE
                            WHEN CEILING( (ls.LogSizeMB * (ls.LogSpaceUsedPct/100.0)) / (@ResultFillPct/100.0) ) < @MinTargetMB
                                 THEN @MinTargetMB
                            ELSE CEILING( (ls.LogSizeMB * (ls.LogSpaceUsedPct/100.0)) / (@ResultFillPct/100.0) )
                        END
                     ELSE NULL
                 END AS decimal(18,2)),
        ProjectedSizeGB =
            CAST(CASE
                     WHEN
                     (
                         (sd.recovery_model_desc = 'SIMPLE' AND ls.LogSpaceUsedPct < 20.0)
                      OR (sd.recovery_model_desc IN ('FULL','BULK_LOGGED')
                          AND ba.LastFullBackup IS NOT NULL
                          AND ba.LastLogBackup  IS NOT NULL
                          AND DATEDIFF(MINUTE, ba.LastLogBackup, GETDATE()) <= @MaxLogBackupAgeMinutes
                          AND sd.log_reuse_wait_desc NOT IN ('LOG_BACKUP','ACTIVE_TRANSACTION',
                                                             'ACTIVE_BACKUP_OR_RESTORE','REPLICATION',
                                                             'AVAILABILITY_REPLICA')
                          AND ls.LogSpaceUsedPct < 20.0)
                     )
                     THEN
                        CASE
                            WHEN CEILING( (ls.LogSizeMB * (ls.LogSpaceUsedPct/100.0)) / (@ResultFillPct/100.0) ) < @MinTargetMB
                                 THEN @MinTargetMB / 1024.0
                            ELSE CEILING( (ls.LogSizeMB * (ls.LogSpaceUsedPct/100.0)) / (@ResultFillPct/100.0) ) / 1024.0
                        END
                     ELSE NULL
                 END AS decimal(18,3))
    FROM #LogSpace ls
    JOIN sys.databases sd
      ON sd.name = ls.DatabaseName
    LEFT JOIN BackupAgg ba
      ON ba.database_name = ls.DatabaseName
    WHERE (@DbNameFilter IS NULL OR ls.DatabaseName = @DbNameFilter)
)
-- WICHTIG: Direktes SELECT INTO nach der CTE (erzeugt #LogDetail samt Spaltennamen)
SELECT
    [Database Name],
    [Log Size (MB)],
    CAST([Log Size (MB)]/1024.0 AS decimal(18,3))           AS [Log Size (GB)],
    [Log Space Used (%)],
    [Status],
    [Recovery Model],
    [Log Reuse Wait],
    UsedMB                                                   AS [Used (MB)],
    UsedGB                                                   AS [Used (GB)],
    HasFullBackup                                            AS [Has Full Backup],
    HasLogBackup                                             AS [Has Log Backup],
    AgeOfLogBackupMin                                        AS [Age of Log Backup (min)],
    LastFullBackupAt                                         AS [Last Full Backup At],
    LastLogBackupAt                                          AS [Last Log Backup At],
    Recommendation,
    ProjectedSizeMB                                          AS [Projected Size After Shrink (MB)],
    ProjectedSizeGB                                          AS [Projected Size After Shrink (GB)]
INTO #LogDetail
FROM Detail;

-- (1) Detail-Ergebnis
SELECT *
FROM #LogDetail
ORDER BY 
    CASE [Recommendation] WHEN 'shrink' THEN 0 ELSE 1 END,
    [Used (MB)] DESC;

-- (2) Summary: aktueller Gesamtplatz vs. projizierter Platz (nur dort empfohlen)
SELECT
    CurrentTotalMB   = CAST(SUM([Log Size (MB)]) AS decimal(18,2)),
    CurrentTotalGB   = CAST(SUM([Log Size (MB)])/1024.0 AS decimal(18,3)),
    ProjectedTotalMB = CAST(SUM(CASE WHEN [Recommendation] = 'shrink' AND [Projected Size After Shrink (MB)] IS NOT NULL
                                    THEN [Projected Size After Shrink (MB)]
                                    ELSE [Log Size (MB)]
                               END) AS decimal(18,2)),
    ProjectedTotalGB = CAST(SUM(CASE WHEN [Recommendation] = 'shrink' AND [Projected Size After Shrink (MB)] IS NOT NULL
                                    THEN [Projected Size After Shrink (MB)]
                                    ELSE [Log Size (MB)]
                               END)/1024.0 AS decimal(18,3)),
    SavingsMB        = CAST(SUM([Log Size (MB)]) - 
                            SUM(CASE WHEN [Recommendation] = 'shrink' AND [Projected Size After Shrink (MB)] IS NOT NULL
                                     THEN [Projected Size After Shrink (MB)]
                                     ELSE [Log Size (MB)]
                                END) AS decimal(18,2)),
    SavingsGB        = CAST( (SUM([Log Size (MB)]) - 
                              SUM(CASE WHEN [Recommendation] = 'shrink' AND [Projected Size After Shrink (MB)] IS NOT NULL
                                       THEN [Projected Size After Shrink (MB)]
                                       ELSE [Log Size (MB)]
                                  END)) / 1024.0 AS decimal(18,3))
FROM #LogDetail;

/* -------------------------------------------------------------------------
   (3) Pro-Logfile-Details: Autogrowth & Maximalgröße
   ------------------------------------------------------------------------- */

CREATE TABLE #LogFiles
(
    [Database Name]        sysname,
    [File ID]              int,
    [Logical Name]         sysname,
    [Physical Name]        nvarchar(260),
    [Current Size (MB)]    decimal(18,2),
    [Current Size (GB)]    decimal(18,3),
    [Growth Type]          varchar(10),     -- 'MB' oder 'PERCENT'
    [Growth (MB)]          decimal(18,2) NULL,
    [Growth (%)]           int NULL,
    [Max Size (MB)]        decimal(18,2) NULL,
    [Max Size (GB)]        decimal(18,3) NULL,
    [Max Size Desc]        varchar(20),     -- 'UNLIMITED' oder Zahl
    [Remaining to Max (MB)] decimal(18,2) NULL,
    [Remaining to Max (GB)] decimal(18,3) NULL
);

INSERT INTO #LogFiles
SELECT
    d.name                                        AS [Database Name],
    mf.file_id                                    AS [File ID],
    mf.name                                       AS [Logical Name],
    mf.physical_name                              AS [Physical Name],
    CAST(mf.size * 8.0 / 1024.0 AS decimal(18,2))                AS [Current Size (MB)],
    CAST(mf.size * 8.0 / 1024.0 / 1024.0 AS decimal(18,3))       AS [Current Size (GB)],
    CASE WHEN mf.is_percent_growth = 1 THEN 'PERCENT' ELSE 'MB' END AS [Growth Type],
    -- Growth-Schritt in MB (bei fester MB-Wachstumsgröße)
    CAST(CASE WHEN mf.is_percent_growth = 1 THEN NULL
              ELSE mf.growth * 8.0 / 1024.0 END AS decimal(18,2)) AS [Growth (MB)],
    -- Growth in % (bei Prozent-Wachstum)
    CASE WHEN mf.is_percent_growth = 1 THEN mf.growth ELSE NULL END AS [Growth (%)],
    -- Max. Größe in MB/GB (NULL = UNLIMITED)
    CAST(CASE WHEN mf.max_size = -1 THEN NULL
              ELSE mf.max_size * 8.0 / 1024.0 END AS decimal(18,2)) AS [Max Size (MB)],
    CAST(CASE WHEN mf.max_size = -1 THEN NULL
              ELSE mf.max_size * 8.0 / 1024.0 / 1024.0 END AS decimal(18,3)) AS [Max Size (GB)],
    CASE WHEN mf.max_size = -1 THEN 'UNLIMITED'
         ELSE CONVERT(varchar(20), CAST(mf.max_size * 8.0 / 1024.0 AS decimal(18,2)))
    END AS [Max Size Desc],
    -- verbleibendes Wachstum bis Max (NULL bei UNLIMITED)
    CAST(CASE WHEN mf.max_size = -1 THEN NULL
              ELSE (mf.max_size - mf.size) * 8.0 / 1024.0 END AS decimal(18,2)) AS [Remaining to Max (MB)],
    CAST(CASE WHEN mf.max_size = -1 THEN NULL
              ELSE (mf.max_size - mf.size) * 8.0 / 1024.0 / 1024.0 END AS decimal(18,3)) AS [Remaining to Max (GB)]
FROM sys.master_files mf
JOIN sys.databases d
  ON d.database_id = mf.database_id
WHERE mf.type_desc = 'LOG'
  AND (@DbNameFilter IS NULL OR d.name = @DbNameFilter)
ORDER BY [Database Name], [File ID];

-- Ausgabe der pro-Logfile-Infos
SELECT *
FROM #LogFiles;
```

# Log-Backup

## (1) Recovery Model & Log-Backups – wie hängt das zusammen?

**Grundidee des Transaktionslogs:** Jede Änderung (INSERT/UPDATE/DELETE, DDL) wird zunächst **sequenziell** ins Transaktionslog geschrieben. Dieses Log ist die Basis für **Wiederherstellung** (Recovery) und **Transaktionssicherheit**.  
Wie das Log wiederverwendet/„freigeräumt“ wird, bestimmt das **Recovery Model**:

- **SIMPLE**
    
    - **Trunkierung** (Wiederverwendbarmachen älterer Log-Abschnitte) erfolgt **automatisch bei CHECKPOINT**, sobald die darin enthaltenen Einträge nicht mehr für Crash-Recovery benötigt werden.
        
    - Es gibt **keine Log-Backup-Kette**; **Log-Backups sind nicht möglich**.
        
    - **Wiederherstellung** ist nur **bis zum letzten Full/Diff-Backup** möglich (keine Point-in-Time-Recovery).
        
    - Praktische Auswirkung: das Log wächst meist nur temporär (z. B. bei großen Transaktionen), kann danach durch Checkpoints wieder schrumpfen (logisch, nicht physisch). Häufiges physisches Shrinken ist trotzdem keine Best Practice.
        
- **FULL**
    
    - **Trunkierung** erfolgt **nur** durch **erfolgreiche Log-Backups**. Ohne regelmäßige Log-Backups **wächst** die LDF-Datei **kontinuierlich**, weil alte Log-Segmente nicht freigegeben werden.
        
    - Es gibt eine **Log-Backup-Kette** (LSN-Kette). Du kannst **zeitpunktgenau** (Point-in-Time) wiederherstellen.
        
    - Best Practice: **regelmäßige Log-Backups** (z. B. alle 5–15 Minuten bei OLTP), um Logwachstum zu begrenzen und RPO niedrig zu halten.
        
- **BULK\_LOGGED**
    
    - Wie FULL, aber bestimmte Massenoperationen werden **minimal geloggt** (z. B. `BULK INSERT`, `SELECT INTO`, `INDEX REBUILD` unter Bedingungen).
        
    - **Log-Backups sind erforderlich**, Trunkierung passiert wie bei FULL nur nach Log-Backup. **Point-in-Time** ist **eingeschränkt** möglich (während eines bulk-geloggten Fensters kann eine punktgenaue Wiederherstellung ggf. nicht möglich sein).
        

**Warum bei SIMPLE kein Log-Backup nötig/möglich ist:**  
Weil es **keine Log-Backup-Kette** gibt und das System die **Trunkierung bei CHECKPOINT** selbst erledigt. Log-Backups würden keinen Mehrwert für die Wiederherstellung bringen – deshalb sind sie deaktiviert.

**Warum bei FULL/BULK\_LOGGED Log-Backups nötig sind:**  
Nur **Log-Backups** markieren die bereits wiederherstellbaren Log-Abschnitte als **wiederverwendbar**. Ohne sie bleibt das Log **belegt** und wächst. Zudem sind Log-Backups die **Grundlage für Point-in-Time-Recoveries**.

* * *

## (2) Warum braucht man **vorher** ein Full-Backup?

Ein **Transaktionslog-Backup** ist Teil einer **Backup-Kette**. Diese Kette beginnt immer mit einem **vollständigen Datenbank-Backup** (optional gefolgt von Differenzial-Backups) und wird durch **Log-Backups** fortgesetzt. Technisch wird das durch **Log Sequence Numbers (LSN)** abgebildet.

- Wechselst du das Recovery Model von **SIMPLE → FULL/BULK\_LOGGED**, existiert **keine gültige Full-Backup-Basis** für die Log-Kette.
    
- Versuchst du in dieser Situation ein Log-Backup, erhältst du **Fehler 4214**:
    
    > _“BACKUP LOG cannot be performed because there is no current database backup.”_
    
- Erst ein **vollständiges Datenbank-Backup** schafft die **Baseline** der Kette. Danach sind **Log-Backups** möglich und **trunkieren** das Log wieder ordnungsgemäß.
    

**Merke:**  
Nach Umstellung auf FULL/BULK\_LOGGED **immer zuerst** ein **Full-Backup** ausführen. Danach funktionieren Log-Backups und das Log beginnt wieder mit normaler Trunkierung nach jedem Log-Backup.

* * *

## (3) Detaillierte Beschreibung des Skripts (Smartes Log-Backup mit 4214-Handling)

Das Skript automatisiert das Log-Backup für eine **übergebene Datenbank**. Es prüft das **Recovery Model**, führt – wenn möglich – ein **Log-Backup** aus und fängt **Fehler 4214** ab, indem es **automatisch ein Full-Backup** voranstellt und das **Log-Backup erneut** ausführt.

## Parameter

- `@DbName sysname`  
    Ziel-Datenbank (z. B. `N'BI_RAW'`).
    
- `@BackupDir nvarchar(4000) = NULL`  
    Optionaler Zielordner für `.bak`/`.trn`. Wenn `NULL`, wird versucht, den **Instanz-Default** aus der Registry zu lesen; sonst wird ein Standardpfad verwendet.
    
- `@Debug bit = 0`  
    `1` = **nur Befehle ausgeben** (Dry-Run), `0` = **ausführen**.
    

## Ablauf im Detail

1. **Validierung & Recovery Model**
    
    - Prüft, ob `@DbName` existiert.
        
    - Liest `recovery_model_desc` aus `sys.databases`.
        
    - **SIMPLE** → Hinweis ausgeben, **Abbruch** (Log-Backups nicht möglich).
        
    - **FULL/BULK\_LOGGED** → weiter.
        
2. **Backup-Verzeichnis bestimmen**
    
    - Wenn `@BackupDir` leer ist, versucht das Skript via  
        `master.dbo.xp_instance_regread` den Registry-Wert  
        `HKLM\SOFTWARE\Microsoft\MSSQLServer\MSSQLServer\BackupDirectory` zu lesen.
        
    - Fallback auf einen Standardpfad, wenn Registry nicht lesbar ist.
        
    - Hinweis: **Erfordert entsprechende Rechte** und ist **nicht** für **Azure SQL Database** geeignet (dort gibt es keine Registry). Alternative: `@BackupDir` explizit setzen.
        
3. **Dateinamen erzeugen**
    
    - Baut Dateinamen mit Zeitstempel `yyyyMMddHHmmss`, z. B.`MyDb_full_20250826T112233.bak`, `MyDb_log_20250826T112233.trn`.
4. **Backup-Befehle vorbereiten**
    
    - `@SQLFull`:
        
        ```
        BACKUP DATABASE [Db] TO DISK = '...\Db_full_yyyymmddHHMMss.bak'
          WITH INIT, COMPRESSION, STATS = 10;
        
        ```
        
    - `@SQLLog`:
        
        ```
        BACKUP LOG [Db] TO DISK = '...\Db_log_yyyymmddHHMMss.trn'
          WITH COMPRESSION, STATS = 10;
        
        ```
        
5. **Debug-Modus**
    
    - Bei `@Debug=1` werden die finalen T-SQL-Befehle **nur gedruckt**, nicht ausgeführt (nützlich für Freigaben, Reviews, Agent-Jobs).
6. **Ausführung & Fehlerbehandlung**
    
    - **Erster Versuch:** `EXEC(@SQLLog)`.
        
    - **TRY…CATCH:**
        
        - **Wenn `ERROR_NUMBER() = 4214`**  
            → Kein Full-Backup in der aktuellen Kette vorhanden:
            
            1. `EXEC(@SQLFull)` ausführen (legt die Basis der Kette).
                
            2. `EXEC(@SQLLog)` **erneut** ausführen.
                
        - **Sonstiger Fehler**  
            → Fehlermeldungen (Nummer, Severity, State, Message) ausgeben und **abbrechen**.
            
7. **Kontrolle nach Backup**
    
    - Gibt die **Logbelegung** aus `sys.dm_db_log_space_usage` aus (in MB und %), um unmittelbar zu sehen, ob das Log-Backup Wirkung gezeigt hat.

## Sicherheit & Berechtigungen

- Erfordert **BACKUP DATABASE/LOG** Berechtigungen (z. B. Rolle `db_backupoperator` in Kombination mit Instanzrechten bzw. einfacher: Mitgliedschaft in `sysadmin`).
    
- Registry-Zugriff via `xp_instance_regread` erfordert entsprechende Instanzrechte. In **Azure SQL Database** ist das nicht verfügbar – dort **immer** `@BackupDir` angeben (oder Managed Instance spezifisch handeln).
    

## Portabilität

- **On-Prem/VM/Managed Instance:** Skript wie gezeigt verwendbar (bei MI ggf. ohne Registry-Lookup).
    
- **Azure SQL Database (PaaS):** Klassische T-SQL-Backups stehen **nicht** zur Verfügung (automatische Backups durch Azure). Das Skript ist hierfür **nicht** gedacht.
    

## Best Practices & Hinweise

- **Log-Backups regelmäßig** planen (SQL Agent Job), um Log-Wachstum zu begrenzen und **RPO** zu erfüllen.
    
- **Kein übermäßiges Shrinken** der Log-Datei. Besser: sinnvolle **Wachstumsinkremente** setzen und **VLF-Anzahl** im Blick behalten.
    
- Häufiger Hindernisgrund für Trunkierung in `sys.databases.log_reuse_wait_desc`:  
    `ACTIVE_TRANSACTION`, `REPLICATION`, `AVAILABILITY_REPLICA`, `LOG_BACKUP` usw. – diese Ursachen ggf. gezielt beheben.
    
- Nach Umschalten auf **FULL/BULK\_LOGGED** **immer** ein **Full-Backup** starten, bevor du Log-Backups erwartest.
    

## Nützliche Prüf-Snippets

**Recovery Model & Trunkierungsgrund:**

```
SELECT name, recovery_model_desc, log_reuse_wait_desc
FROM sys.databases
WHERE name = N'YourDb';

```

**Loggröße & Auslastung:**

```
USE [YourDb];
SELECT total_log_size_mb = total_log_size_in_bytes/1024.0/1024.0,
       used_log_space_pct
FROM sys.dm_db_log_space_usage;

```

**Tail-Log-Backup (für Notfälle vor Restore):**

```
BACKUP LOG [YourDb]
  TO DISK = N'E:\SQLBackups\YourDb_tail.trn'
  WITH NO_TRUNCATE, NORECOVERY, STATS = 10;  -- setzt DB in RESTORING

```

* * *

**Kurzfazit:**

- **SIMPLE**: keine Log-Backups, automatische Trunkierung bei Checkpoint, keine Point-in-Time-Recovery.
    
- **FULL/BULK\_LOGGED**: Log-Backups sind **essenziell** (Trunkierung, RPO, Wiederherstellbarkeit).
    
- **Ohne vorheriges Full-Backup** (nach Modelwechsel): Log-Backup schlägt mit **4214** fehl – daher Full-Backup **zuerst**.
    
- Das bereitgestellte Skript automatisiert genau diesen Ablauf inkl. **4214-Fallback** und **Statusausgabe**.


```sql
/*
    Log-Backup je nach Recovery Model
    - @DbName     : Ziel-Datenbank
    - @BackupDir  : Zielordner für .bak/.trn (optional; Standard = Instanz-Backupordner)
    - @Debug      : 1 = nur Befehl ausgeben, 0 = ausführen
*/
DECLARE @DbName    sysname        = N'BI_RAW';
DECLARE @BackupDir nvarchar(4000) = N'\\clrz0101.mp.local\backup_srv-rz-bi-03';
DECLARE @Debug     bit            = 0;

-------------------------------------------------------------------------------
-- 1) Recovery Model prüfen
-------------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = @DbName)
BEGIN
    RAISERROR('Datenbank %s nicht gefunden.', 16, 1, @DbName);
    RETURN;
END;

DECLARE @RecModel sysname;
SELECT @RecModel = recovery_model_desc
FROM sys.databases
WHERE name = @DbName;

PRINT CONCAT('DB: ', @DbName, ' | Recovery Model: ', @RecModel);

IF @RecModel NOT IN (N'FULL', N'BULK_LOGGED')
BEGIN
    PRINT 'Hinweis: Recovery Model ist SIMPLE – Log-Backups sind nicht möglich.';
    RETURN;
END;

-------------------------------------------------------------------------------
-- 2) Backup-Verzeichnis bestimmen (Default = Instanz-Backupordner)
-------------------------------------------------------------------------------
IF @BackupDir IS NULL
BEGIN
    DECLARE @rc int;
    EXEC @rc = master.dbo.xp_instance_regread
        N'HKEY_LOCAL_MACHINE',
        N'SOFTWARE\Microsoft\MSSQLServer\MSSQLServer',
        N'BackupDirectory',
        @BackupDir OUTPUT,
        N'no_output';
    IF @rc <> 0 OR @BackupDir IS NULL
        SET @BackupDir = N'C:\Program Files\Microsoft SQL Server\MSSQL\Backup';
END;

IF RIGHT(@BackupDir,1) IN ('/','\') SET @BackupDir = LEFT(@BackupDir,LEN(@BackupDir)-1);

-------------------------------------------------------------------------------
-- 3) Dateinamen bauen
-------------------------------------------------------------------------------
DECLARE @dt nvarchar(19) =
    REPLACE(REPLACE(CONVERT(nvarchar(19), GETDATE(), 120),'-',''),':',''); -- yyyyMMddHHmmss
DECLARE @LogFile  nvarchar(4000) = CONCAT(@BackupDir, N'\', @DbName, N'_log_', @dt, N'.trn');
DECLARE @FullFile nvarchar(4000) = CONCAT(@BackupDir, N'\', @DbName, N'_full_', @dt, N'.bak');

-------------------------------------------------------------------------------
-- 4) Hilfsprozeduren: Full & Log Backup bauen
-------------------------------------------------------------------------------
DECLARE @SQLFull nvarchar(max) = N'
BACKUP DATABASE ' + QUOTENAME(@DbName) + N'
 TO DISK = N''' + REPLACE(@FullFile,'''','''''') + N'''
 WITH INIT, COMPRESSION, STATS = 10;';

DECLARE @SQLLog nvarchar(max) = N'
BACKUP LOG ' + QUOTENAME(@DbName) + N'
 TO DISK = N''' + REPLACE(@LogFile,'''','''''') + N'''
 WITH COMPRESSION, STATS = 10;';

-------------------------------------------------------------------------------
-- 5) Backup ausführen mit Fehlerbehandlung
-------------------------------------------------------------------------------
IF @Debug = 1
BEGIN
    PRINT 'DEBUG: Folgende Befehle würden ausgeführt:';
    PRINT '-- Full-Backup';
    PRINT @SQLFull;
    PRINT '-- Log-Backup';
    PRINT @SQLLog;
    RETURN;
END;

BEGIN TRY
    EXEC(@SQLLog);
    PRINT CONCAT('Log-Backup erfolgreich: ', @LogFile);
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 4214
    BEGIN
        PRINT 'Fehler 4214: Kein Full Backup vorhanden – führe Full Backup durch.';
        EXEC(@SQLFull);
        PRINT CONCAT('Full-Backup erfolgreich: ', @FullFile);

        PRINT 'Starte Log-Backup erneut...';
        EXEC(@SQLLog);
        PRINT CONCAT('Log-Backup erfolgreich nach Full Backup: ', @LogFile);
    END
    ELSE
    BEGIN
        PRINT CONCAT('Fehler beim Backup. Msg ', ERROR_NUMBER(),
                     ', Level ', ERROR_SEVERITY(),
                     ', State ', ERROR_STATE());
        PRINT ERROR_MESSAGE();
        RETURN;
    END
END CATCH;

-------------------------------------------------------------------------------
-- 6) Log-Nutzung nach Backup anzeigen
-------------------------------------------------------------------------------
DECLARE @AfterSQL nvarchar(max) = N'
USE ' + QUOTENAME(@DbName) + N';
SELECT total_log_size_mb = total_log_size_in_bytes/1024.0/1024.0,
       used_log_space_pct
FROM sys.dm_db_log_space_usage;';
EXEC(@AfterSQL);

```

# eine bestimmte Log-Datei shrinken


### einfaches Beispiel


### Zielgerichtetes Shrinken des Transaktionslogs mit Backup-Checks, Vorher/Nachher-Messung und Savings

**<u>Zweck & Nutzen</u>**

Dieses Skript verkleinert (optional) die **Log-Datei einer einzelnen Datenbank** und liefert **transparente Kennzahlen vor und nach dem Shrink**. Es führt **Sicherheitsprüfungen** aus, misst die **Loggröße und Lognutzung** vorher und nachher und berechnet daraus das **Einsparpotenzial** in **MB** und **GB** (sowohl Datei-Größe als auch tatsächlich genutzter Log-Platz).

**Wichtige Eigenschaften:**

- Prüft **Recovery Model** und **Backup-Voraussetzungen** (FULL/BULK\_LOGGED).
    
- **Bricht nicht hart ab**: Falls Bedingungen nicht erfüllt sind, wird der Shrink **übersprungen**, aber **Vorher/Nachher** trotzdem gemessen (so bleibt der Report konsistent).
    
- **Debug-Modus**: Druckt nur den T-SQL-Befehl (Dry-Run), führt nichts aus.
    
- Liefert eine **kompakte Ein-Zeilen-Tabelle** mit allen Vorher/Nachher-Werten und Savings.
    

* * *

**<u>Parameter</u>**

| Parameter | Typ | Standard | Bedeutung |
| --- | --- | --- | --- |
| `@DbName` | `sysname` | `N'BI_RAW'` | Ziel-Datenbank |
| `@ResultFillPct` | `int` | `90` | Ziel-Füllgrad (%) nach Shrink (z. B. 90 % = 10 % Puffer) |
| `@MinTargetMB` | `int` | `256` | Untergrenze für die Zielgröße (MB) |
| `@MaxAgeMinutes` | `int` | `60` | Max. akzeptables Alter des **letzten Log-Backups** (Minuten) in FULL/BULK\_LOGGED |
| `@Debug` | `bit` | `0` | `1` = nur ausgeben, `0` = ausführen |

* * *

**<u>Funktionsprinzip & Ablauf</u>**

_<u>0) Grundprüfung</u>_

- Validiert, dass `@DbName` existiert.
    
- Ermittelt das **Recovery Model** (`SIMPLE`/`FULL`/`BULK_LOGGED`) aus `sys.databases`.
    

_<u>1) **Vorher-Messung** & Log-Dateiname</u>_

- In der Ziel-DB (`USE [Db]`):
    
    - Liest aus `sys.dm_db_log_space_usage`:
        
        - `total_log_size_in_bytes` → `@BeforeTotalMB`
            
        - `used_log_space_in_percent` → `@BeforeUsedPct`
            
    - Ermittelt den **Log-Dateinamen** aus `sys.database_files WHERE type_desc='LOG'`.
        
- Berechnet **theoretisch genutzten Platz**:
    
    - `@BeforeUsedMB = @BeforeTotalMB * (@BeforeUsedPct / 100)`

_<u>2) Backup-Infos & **Policy-Prüfungen**</u>_

- Aus `msdb.dbo.backupset`:
    
    - `@LastFullBackup = MAX(backup_finish_date) WHERE type='D'`
        
    - `@LastLogBackup = MAX(backup_finish_date) WHERE type='L'`
        
- **Steuerlogik**:
    
    - In **SIMPLE**: kein Log-Backup nötig → Shrink **erlaubt**.
        
    - In **FULL/BULK\_LOGGED**:
        
        - **Fehlt** Full-Backup → Shrink **überspringen** (Info).
            
        - **Fehlt** Log-Backup → Shrink **überspringen** (Info).
            
        - **Zu altes** Log-Backup (`DATEDIFF(MINUTE) > @MaxAgeMinutes`) → Shrink **überspringen** (Info).
            
- Anstatt `RETURN` werden **Flags** (`@Abort`, `@AbortReason`) gesetzt; so erfolgt später trotzdem eine Nachher-Messung und eine saubere Zusammenfassung.
    

_<u>3) Zielgröße berechnen (basierend auf **Vorher-Werten**)</u>_

Formel für die **Zielgröße** (MB):

```
UsedMB     = BeforeTotalMB * (BeforeUsedPct / 100)
NeededMB   = UsedMB / (ResultFillPct / 100)
TargetMB   = CEILING(NeededMB)
FinalTarget= MAX(TargetMB, MinTargetMB)

```

- Bei unplausiblem `@ResultFillPct` (\<1 oder \>100) wird konservativ auf `CEILING(BeforeTotalMB)` zurückgefallen.
    
- Die **Zielgröße** ist damit „benötigter Platz + Puffer“, jedoch **nie kleiner** als `@MinTargetMB`.
    

<u>4) Shrink vorbereiten & ausführen (oder überspringen)</u>

- SQL:
    
    ```
    USE [Db];
    CHECKPOINT;
    DBCC SHRINKFILE(N'<LogLogicalName>', <@TargetMB>);
    
    ```
    
- Ausführungsregeln:
    
    - **Überspringen**, wenn `@Abort=1` (Policy-Verstoß) → Infoausgabe.
        
    - **Debug-Modus (`@Debug=1`)**: Befehl wird **nur ausgegeben**, nicht ausgeführt.
        
    - **Normalfall**: Befehl wird ausgeführt.
        

_<u>5) **Nachher-Messung** (immer)</u>_

- Erneut `sys.dm_db_log_space_usage` in der Ziel-DB:
    
    - `@AfterTotalMB`, `@AfterUsedPct`, abgeleitet `@AfterUsedMB`.

_<u>6) **Savings-Berechnung** & Zusammenfassung</u>_

- **Datei-Größen-Ersparnis**:
    
    - `FileSavingsMB = @BeforeTotalMB - @AfterTotalMB`
        
    - `FileSavingsGB = FileSavingsMB / 1024.0`
        
- **Genutzter Platz – Ersparnis**:
    
    - `UsedSavingsMB = @BeforeUsedMB - @AfterUsedMB`
        
    - `UsedSavingsGB = UsedSavingsMB / 1024.0`
        
- Ausgabe als **PRINT** und **kompakte Result-Tabelle** mit allen Kennzahlen (inkl. `AbortOccurred` / `AbortReason`).
    

* * *

**<u>Ein-/Ausgaben im Detail</u>**

_<u>Eingaben</u>_

- Parameter am Skriptkopf (siehe Tabelle oben).

_<u>Konsolenmeldungen (PRINT)</u>_

- Recovery Model, Logfile-Name, Vorher-Werte.
    
- Backup-Zeitpunkte (Full/Log) und ggf. **Abbruchbedingungen** mit Erklärung.
    
- Berechnete Zielgröße.
    
- Ausgeführter/Geplanter Shrink-Befehl (oder Skip/Debug-Hinweis).
    
- Nachher-Werte und **Savings-Zusammenfassung**.
    

_<u>Ergebnis-Tabelle (eine Zeile)</u>_

Beispielspalten:

- `DatabaseName`, `RecoveryModel`, `LogFileName`
    
- Policy/Steuerung: `ResultFillPct`, `MinTargetMB`, `MaxAgeMinutes`, `AbortOccurred`, `AbortReason`
    
- **Vorher**: `Before_TotalMB`, `Before_UsedPct`, `Before_UsedMB`
    
- **Ziel**: `TargetMB_Calculated`
    
- **Nachher**: `After_TotalMB`, `After_UsedPct`, `After_UsedMB`
    
- **Savings**: `Savings_File_MB/GB`, `Savings_Used_MB/GB`
    

* * *

**<u>Formeln (kompakt)</u>**

- **Vorher/Nachher genutzter Platz (MB)**  
    `UsedMB = TotalMB * (UsedPct / 100)`
    
- **Berechnung Zielgröße (MB)**
    
    ```
    NeededMB   = UsedMB / (ResultFillPct / 100)
    TargetMB   = CEILING(NeededMB)
    FinalTarget= MAX(TargetMB, MinTargetMB)
    
    ```
    
- **Einsparungen**
    
    ```
    FileSavingsMB = BeforeTotalMB - AfterTotalMB
    FileSavingsGB = FileSavingsMB / 1024
    UsedSavingsMB = BeforeUsedMB  - AfterUsedMB
    UsedSavingsGB = UsedSavingsMB / 1024
    
    ```
    

* * *

**<u>Voraussetzungen & Berechtigungen</u>**

- Leserechte auf:
    
    - `sys.databases`, `sys.database_files`, `sys.dm_db_log_space_usage` (in der Ziel-DB).
        
    - `msdb.dbo.backupset` (zur Backup-Historie).
        
- Ausführungsrecht für:
    
    - `DBCC SHRINKFILE` (typischerweise `db_owner` / `sysadmin`).
- **Kompatibilität:** `sys.dm_db_log_space_usage` ist auf modernen Versionen breit verfügbar. Wenn eure Umgebung sehr alte Versionen enthält, kann alternativ `DBCC SQLPERF(LOGSPACE)` als Quelle verwendet werden (hier nicht eingebaut, aber leicht erweiterbar).
    

* * *

**<u>Best Practices & Empfehlungen</u>**

- **Shrink selektiv** einsetzen. Ziel ist **saubere Dimensionierung**, nicht regelmäßiges „Leerfegen“.
    
- In **FULL/BULK\_LOGGED**: Regelmäßige **Log-Backups** (und frische Kette) sind Grundvoraussetzung, damit Shrinks **wirksam** und **nachhaltig** sind.
    
- Schwellwerte anpassen:
    
    - `@MaxAgeMinutes` (RPO-Policy),
        
    - `@ResultFillPct` (wie „eng“ du dimensionieren willst),
        
    - `@MinTargetMB` (untere harte Grenze).
        
- Vor Shrinks Ursachen prüfen (z. B. `log_reuse_wait_desc` auf `ACTIVE_TRANSACTION`, `LOG_BACKUP`, `REPLICATION`, …).
    
- **Autogrowth** der Logdatei **in MB/GB** statt Prozent konfigurieren; **realistische Startgröße** wählen, um häufiges Wachstum zu vermeiden.
    
- **HADR/Replication**: Eng verknüpft mit Log-Trunkierung – ggf. Verzögerungen/Queues prüfen.
    

* * *

<u>**Typische Szenarien**</u>

- **SIMPLE-Recovery**  
    Du möchtest eine temporär groß gewordene Logdatei wieder auf ein sinnvolles Maß bringen. Das Skript wird sofort shrinken (keine Log-Backup-Pflicht), und Vorher/Nachher klar ausweisen.
    
- **FULL/BULK\_LOGGED-Recovery**  
    Du willst gezielt shrinken, **aber nur**, wenn die **Backup-Kette intakt** und **frisch genug** ist. Das Skript schützt dich vor „Placebo-Shrinks“, die wegen fehlender Trunkierungsvoraussetzungen nichts bringen würden.
    

* * *

**<u>Fehlersuche & typische Meldungen</u>**

- **„Keine Log-Datei gefunden“**  
    Ungewöhnlich; prüfe, ob die DB korrekt angegeben ist und eine Standard-Logdatei existiert.
    
- **Shrink wird „übersprungen“**  
    Siehe `AbortOccurred = 1` und `AbortReason`; Ursachen sind im Klartext genannt (z. B. „Kein Full-Backup vorhanden“, „Log-Backup zu alt“).
    
- **Keine bzw. geringe Savings**  
    Typisch, wenn Shrink im Debug war, übersprungen wurde, oder die Datei bereits am Ziel ist. Prüfe `TargetMB_Calculated` vs. `Before_TotalMB`.
    

* * *

**<u>Erweiterungen (optional)</u>**

- **Begründungsspalte** („Reason“): Neben `AbortReason` auch für den „ausgeführten“ Fall eine knappe Begründung (z. B. „Used% low; policy ok“).
    
- **Automatisches Backup** (nur wenn gewünscht): Automatischer 4214-Fallback und frisches Log-Backup **vor** Shrink (in diesem Skript explizit **nicht** enthalten).
    
- **Stored Procedure**: Kapselung mit Parametern; Rückgabe des Resultsets für Monitoring-Pipelines/Reports.
    

* * *

**<u>Beispielinterpretation</u>**

- Vorher: `TotalMB=10240`, `Used%=35` → `UsedMB=3584`
    
- Parameter: `ResultFillPct=90`, `MinTargetMB=256`
    
- Zielgröße: `NeededMB=3584/0,9=3982,22` → `TargetMB=3983` → `FinalTarget=max(3983,256)=3983`
    
- Nachher: `TotalMB≈3983` (bei tatsächlicher Ausführung), `Used%` typischerweise **höher** (weil Datei kleiner), `UsedMB` ähnlich wie vorher ± aktuelle Workload
    
- Savings: `FileSavingsMB ≈ 10240 − 3983 = 6257 MB ≈ 6,114 GB`.
    

* * *

**Kurzfazit:**  
Das Skript bietet **sichere, nachvollziehbare Shrinks** mit **klaren Vorher/Nachher-Zahlen** und **Savings**. Es verhindert wirkungslose Aktionen in **FULL/BULK\_LOGGED** (fehlende/alte Backups) und gibt dir alle Kennzahlen in einer **kompakten Ergebniszeile** an die Hand.


```sql
/*
    Shrink LOG file of a specific database (mit Backup-Prüfung & Savings-Messung)
    - @DbName        : Ziel-Datenbank
    - @ResultFillPct : Ziel-Füllstand in % nach dem Shrink (Default 90%)
    - @MinTargetMB   : Untergrenze für Zielgröße in MB (Default 256 MB)
    - @MaxAgeMinutes : Maximales Alter des letzten Log-Backups (Policy)
    - @Debug         : 1 = nur SQL ausgeben, 0 = ausführen

    NEU:
      * Vorher-/Nachher-Messung von Total/Used
      * Savings in MB/GB (Dateigröße & genutzter Platz)
      * Kein hartes RETURN mehr bei Prüf-Fehlern -> Shrink wird nur übersprungen
*/

SET NOCOUNT ON;

DECLARE @DbName        sysname = N'BI_RAW';
DECLARE @ResultFillPct int     = 90;     -- Ziel: ~90% Füllgrad nach Shrink
DECLARE @MinTargetMB   int     = 256;    -- nie kleiner als 256 MB schrumpfen
DECLARE @MaxAgeMinutes int     = 60;     -- Policy: Log-Backup max. so alt
DECLARE @Debug         bit     = 0;

--------------------------------------------------------------------------------
-- Variablen
--------------------------------------------------------------------------------
DECLARE @LogFileName sysname;
DECLARE @SQL         nvarchar(max);

-- Vorher/Nachher-Messung
DECLARE @BeforeTotalMB decimal(18,2), @BeforeUsedPct decimal(5,2), @BeforeUsedMB decimal(18,2);
DECLARE @AfterTotalMB  decimal(18,2), @AfterUsedPct  decimal(5,2), @AfterUsedMB  decimal(18,2);

-- Zielgröße
DECLARE @TargetMB int;

-- Recovery/Backup
DECLARE @RecModel        sysname;
DECLARE @LastFullBackup  datetime2(0);
DECLARE @LastLogBackup   datetime2(0);
DECLARE @AgeMin          int;

-- Steuerung
DECLARE @Abort bit = 0;
DECLARE @AbortReason nvarchar(4000) = N'';

--------------------------------------------------------------------------------
-- 0) Grund-Checks
--------------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = @DbName)
BEGIN
    RAISERROR('Datenbank %s nicht gefunden.', 16, 1, @DbName);
    RETURN;
END;

SELECT @RecModel = recovery_model_desc
FROM sys.databases
WHERE name = @DbName;

PRINT CONCAT('DB: ', @DbName, ' | Recovery Model: ', @RecModel);

--------------------------------------------------------------------------------
-- 1) VORHER: Log-Auslastung + Log-Dateiname
--------------------------------------------------------------------------------
SET @SQL = N'
USE ' + QUOTENAME(@DbName) + N';
SELECT
    @BeforeTotalMB = CAST(total_log_size_in_bytes/1024.0/1024.0 AS decimal(18,2)),
    @BeforeUsedPct = CAST(used_log_space_in_percent AS decimal(5,2))
FROM sys.dm_db_log_space_usage;

SELECT @LogFileName = name
FROM sys.database_files
WHERE type_desc = ''LOG'';';

EXEC sp_executesql
     @SQL
   , N'@BeforeTotalMB decimal(18,2) OUTPUT, @BeforeUsedPct decimal(5,2) OUTPUT, @LogFileName sysname OUTPUT'
   , @BeforeTotalMB = @BeforeTotalMB OUTPUT
   , @BeforeUsedPct = @BeforeUsedPct OUTPUT
   , @LogFileName   = @LogFileName   OUTPUT;

SET @BeforeUsedMB = CAST(@BeforeTotalMB * (@BeforeUsedPct/100.0) AS decimal(18,2));

PRINT CONCAT('VORHER | LogFile: ', ISNULL(@LogFileName,'<unbekannt>'),
             ' | TotalMB: ', @BeforeTotalMB, ' | Used%: ', @BeforeUsedPct,
             ' | UsedMB: ', @BeforeUsedMB);

IF @LogFileName IS NULL
BEGIN
    RAISERROR('Keine Log-Datei in %s gefunden.', 16, 1, @DbName);
    RETURN;
END;

--------------------------------------------------------------------------------
-- 2) Backup-Infos & Policy-Prüfungen (steuern nur @Abort, kein RETURN)
--------------------------------------------------------------------------------
SELECT @LastFullBackup = MAX(backup_finish_date)
FROM msdb.dbo.backupset
WHERE database_name = @DbName
  AND [type] = 'D'
  AND backup_finish_date IS NOT NULL;

SELECT @LastLogBackup = MAX(backup_finish_date)
FROM msdb.dbo.backupset
WHERE database_name = @DbName
  AND [type] = 'L'
  AND backup_finish_date IS NOT NULL;

PRINT CONCAT('Letztes Full: ', COALESCE(CONVERT(varchar(19), @LastFullBackup, 120), '<nicht vorhanden>'));
PRINT CONCAT('Letztes Log : ', COALESCE(CONVERT(varchar(19), @LastLogBackup, 120), '<nicht vorhanden>'));

IF @RecModel = N'SIMPLE'
BEGIN
    PRINT 'Hinweis: SIMPLE – Log-Backups nicht erforderlich. Shrink kann direkt ausgeführt werden.';
END
ELSE IF @RecModel IN (N'FULL', N'BULK_LOGGED')
BEGIN
    IF @LastFullBackup IS NULL
    BEGIN
        SET @Abort = 1;
        SET @AbortReason = @AbortReason + N'Kein Full-Backup vorhanden. ';
        PRINT 'ABBRUCHBEDINGUNG: Kein Full-Backup vorhanden. Bitte zuerst ein Full-Backup anlegen.';
    END;

    IF @LastLogBackup IS NULL
    BEGIN
        SET @Abort = 1;
        SET @AbortReason = @AbortReason + N'Kein Log-Backup vorhanden. ';
        PRINT 'ABBRUCHBEDINGUNG: Kein Log-Backup vorhanden. Bitte zuerst ein Log-Backup anlegen.';
    END;

    IF @LastLogBackup IS NOT NULL
    BEGIN
        SET @AgeMin = DATEDIFF(MINUTE, @LastLogBackup, GETDATE());
        IF @AgeMin > @MaxAgeMinutes
        BEGIN
            SET @Abort = 1;
            SET @AbortReason = @AbortReason + N'Log-Backup zu alt. ';
            PRINT CONCAT('ABBRUCHBEDINGUNG: Letztes Log-Backup ist ', @AgeMin,
                         ' Minuten alt (Grenze: ', @MaxAgeMinutes, '). Bitte frisches Log-Backup ausführen.');
        END;
    END;
END
ELSE
BEGIN
    PRINT CONCAT('Unbekanntes Recovery Model: ', @RecModel, '. Fahre fort mit Vorsicht.');
END;

--------------------------------------------------------------------------------
-- 3) Zielgröße berechnen (aus den VORHER-Werten)
--------------------------------------------------------------------------------
SET @TargetMB =
    CASE
        WHEN @ResultFillPct <= 0 OR @ResultFillPct > 100 THEN CEILING(@BeforeTotalMB)
        ELSE
            CASE
                WHEN CEILING((@BeforeTotalMB * (@BeforeUsedPct/100.0)) / (@ResultFillPct/100.0)) < @MinTargetMB
                    THEN @MinTargetMB
                ELSE CEILING((@BeforeTotalMB * (@BeforeUsedPct/100.0)) / (@ResultFillPct/100.0))
            END
    END;

PRINT CONCAT('Berechnete Zielgröße: ', @TargetMB, ' MB (MinTargetMB=', @MinTargetMB, ', ZielFüll%=', @ResultFillPct, ')');

--------------------------------------------------------------------------------
-- 4) Shrink vorbereiten & ggf. ausführen
--------------------------------------------------------------------------------
SET @SQL = N'
USE ' + QUOTENAME(@DbName) + N';
CHECKPOINT;
DBCC SHRINKFILE(' + QUOTENAME(@LogFileName,'''') + N', ' + CAST(@TargetMB AS nvarchar(20)) + N');
';

IF @Abort = 1
BEGIN
    PRINT 'Hinweis: Shrink wird aufgrund der Abbruchbedingungen NICHT ausgeführt.';
END
ELSE IF @Debug = 1
BEGIN
    PRINT 'DEBUG: Folgender Befehl würde ausgeführt:';
    PRINT @SQL;
END
ELSE
BEGIN
    PRINT CONCAT('Shrink Log "', @LogFileName, '" in DB ', @DbName, ' auf ', @TargetMB, ' MB ...');
    EXEC (@SQL);
END;

--------------------------------------------------------------------------------
-- 5) NACHHER: Log-Auslastung erneut messen (immer, auch wenn Shrink übersprungen)
--------------------------------------------------------------------------------
SET @SQL = N'
USE ' + QUOTENAME(@DbName) + N';
SELECT
    @AfterTotalMB = CAST(total_log_size_in_bytes/1024.0/1024.0 AS decimal(18,2)),
    @AfterUsedPct = CAST(used_log_space_in_percent AS decimal(5,2))
FROM sys.dm_db_log_space_usage;';

EXEC sp_executesql
     @SQL
   , N'@AfterTotalMB decimal(18,2) OUTPUT, @AfterUsedPct decimal(5,2) OUTPUT'
   , @AfterTotalMB = @AfterTotalMB OUTPUT
   , @AfterUsedPct = @AfterUsedPct OUTPUT;

SET @AfterUsedMB = CAST(@AfterTotalMB * (@AfterUsedPct/100.0) AS decimal(18,2));

PRINT CONCAT('NACHHER | TotalMB: ', @AfterTotalMB, ' | Used%: ', @AfterUsedPct,
             ' | UsedMB: ', @AfterUsedMB);

--------------------------------------------------------------------------------
-- 6) Savings berechnen & ausgeben (Dateigröße & genutzter Platz)
--------------------------------------------------------------------------------
DECLARE @FileSavingsMB decimal(18,2) = @BeforeTotalMB - @AfterTotalMB;
DECLARE @FileSavingsGB decimal(18,3) = @FileSavingsMB / 1024.0;

DECLARE @UsedSavingsMB decimal(18,2) = @BeforeUsedMB  - @AfterUsedMB;
DECLARE @UsedSavingsGB decimal(18,3) = @UsedSavingsMB / 1024.0;

PRINT '--- Zusammenfassung (Savings) ---';
PRINT CONCAT('Dateigröße eingespart: ', @FileSavingsMB, ' MB (', @FileSavingsGB, ' GB)');
PRINT CONCAT('Genutzter Log-Platz eingespart: ', @UsedSavingsMB, ' MB (', @UsedSavingsGB, ' GB)');

-- tabellarische Ausgabe aller Kennzahlen (eine Zeile)
SELECT
    DatabaseName                 = @DbName,
    RecoveryModel                = @RecModel,
    LogFileName                  = @LogFileName,
    ResultFillPct                = @ResultFillPct,
    MinTargetMB                  = @MinTargetMB,
    MaxAgeMinutes                = @MaxAgeMinutes,
    AbortOccurred                = @Abort,
    AbortReason                  = NULLIF(@AbortReason, N''),
    -- Vorher
    Before_TotalMB               = @BeforeTotalMB,
    Before_UsedPct               = @BeforeUsedPct,
    Before_UsedMB                = @BeforeUsedMB,
    -- Ziel
    TargetMB_Calculated          = @TargetMB,
    -- Nachher
    After_TotalMB                = @AfterTotalMB,
    After_UsedPct                = @AfterUsedPct,
    After_UsedMB                 = @AfterUsedMB,
    -- Savings
    Savings_File_MB              = @FileSavingsMB,
    Savings_File_GB              = @FileSavingsGB,
    Savings_Used_MB              = @UsedSavingsMB,
    Savings_Used_GB              = @UsedSavingsGB;

```
