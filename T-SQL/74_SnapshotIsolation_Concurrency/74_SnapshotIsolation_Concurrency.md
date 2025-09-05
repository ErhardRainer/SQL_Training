# T-SQL Snapshot Isolation & RCSI – Übersicht  
*`READ_COMMITTED_SNAPSHOT (RCSI)`, `SNAPSHOT ISOLATION (SI)`, Auswirkungen auf tempdb & Performance*

## 1 | Begriffsdefinition

| SQL-Term | Beschreibung |
|---|---|
| **Row-Versionierung** | Bei DML wird eine **Vorversion** der Zeile im **Version Store** von **tempdb** abgelegt; Datensätze enthalten einen 14-Byte-Versionzeiger. |
| **READ COMMITTED SNAPSHOT (RCSI)** | Ersetzt das klassische READ COMMITTED durch **statement-weises** Snapshot-Reading. Leser blockieren **keine** Schreiber und umgekehrt; Schreibsperren bleiben nötig. |
| **SNAPSHOT ISOLATION (SI)** | **Transaktionsweiter** Snapshot. Verhindert Dirty/Non-Repeatable/Phantom Reads **innerhalb** der Transaktion. **Write-Write-Konflikte** führen beim Commit zu **Fehler 3960** (First-Committer-Wins). |
| **Aktivierung (DB-Optionen)** | `ALTER DATABASE … SET READ_COMMITTED_SNAPSHOT ON;` und `… SET ALLOW_SNAPSHOT_ISOLATION ON;` (Optional beides). RCSI wirkt sofort auf **alle** Sessions der DB; SI muss pro Session via `SET TRANSACTION ISOLATION LEVEL SNAPSHOT` aktiviert werden. |
| **Version Store (tempdb)** | Speichert Zeilenversionen. Cleanup-Thread entfernt **nicht mehr benötigte** Versionen, sobald keine Transaktionen mit älteren Schnappschüssen aktiv sind. |
| **SARGability** | Unverändert wichtig: Versionierung ändert **keine** Prädikatlogik; gute Indizes bleiben entscheidend. |
| **Lange Leser** | Lange laufende (Snapshot-)Transaktionen verhindern Cleanup ⇒ **Version Store wächst**, tempdb-Druck. |
| **Monitoring** | DMVs/PerfCounter: `sys.dm_tran_version_store_space_usage`, `sys.dm_tran_active_snapshot_database_transactions`, `sys.dm_tran_top_version_generators`, `sys.dm_db_file_space_usage`; PerfMon *Version Store Size / Generation / Cleanup rate*. |
| **Locking** | Leser unter RCSI/SI nehmen **keine S-Locks** für Datenzugriff. **Schreiber** benutzen weiterhin X/U-Locks. |
| **NOLOCK** | Unter RCSI/SI **nicht nötig** und weiterhin riskant (Inkonsistenzen). |
| **tempdb-Best Practices** | Ausreichend große tempdb (Data/Log) mit **mehreren Datenfiles** (gleich groß), schnelle Storage, Autogrowth moderat, Monitoring. |

---

## 2 | Struktur

### 2.1 | Überblick: RCSI vs. SI – Ziele, Unterschiede, Trade-offs
> **Kurzbeschreibung:** Statement-Snapshot (RCSI) vs. Transaktions-Snapshot (SI); wann welches Modell sinnvoll ist.

- 📓 **Notebook:**  
  [`08_01_rcsi_vs_si_overview.ipynb`](08_01_rcsi_vs_si_overview.ipynb)
- 🎥 **YouTube:**  
  - [Snapshot Isolation vs Read Committed Snapshot](https://www.youtube.com/results?search_query=sql+server+snapshot+isolation+vs+read+committed+snapshot)
- 📘 **Docs:**  
  - [Row Versioning Isolation Levels – Überblick](https://learn.microsoft.com/en-us/sql/relational-databases/tempdb/row-versioning-isolation-levels)

---

### 2.2 | Aktivierung & Rollout-Strategie
> **Kurzbeschreibung:** Sicheres Aktivieren (Rollback-Window), App-Kompatibilität, `ALTER DATABASE`-Optionen & Rollback-Strategien.

- 📓 **Notebook:**  
  [`08_02_activation_rollout.ipynb`](08_02_activation_rollout.ipynb)
- 🎥 **YouTube:**  
  - [Enable RCSI/SI – Step by Step](https://www.youtube.com/results?search_query=enable+read+committed+snapshot+sql+server)
- 📘 **Docs:**  
  - [`ALTER DATABASE … SET READ_COMMITTED_SNAPSHOT`](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-database-transact-sql-set-options)  
  - [`ALLOW_SNAPSHOT_ISOLATION`](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-database-transact-sql-set-options#allow_snapshot_isolation)

---

### 2.3 | tempdb Version Store – Interna & Speicherpfad
> **Kurzbeschreibung:** Was wird versioniert, wie Zeilen verkettet sind, Auswirkungen von UPDATE/DELETE/INSERT.

- 📓 **Notebook:**  
  [`08_03_tempdb_version_store_internals.ipynb`](08_03_tempdb_version_store_internals.ipynb)
- 🎥 **YouTube:**  
  - [Version Store Internals](https://www.youtube.com/results?search_query=sql+server+version+store+internals)
- 📘 **Docs:**  
  - [Version Store – Grundlagen](https://learn.microsoft.com/en-us/sql/relational-databases/tempdb/row-versioning-isolation-levels#version-store)

---

### 2.4 | Monitoring: Größe, Top-Generatoren & aktive Snapshots
> **Kurzbeschreibung:** DMVs & PerfCounter für Verbrauch/Verursacher, Alarme und Visualisierung.

- 📓 **Notebook:**  
  [`08_04_monitoring_version_store_dmvs.ipynb`](08_04_monitoring_version_store_dmvs.ipynb)
- 🎥 **YouTube:**  
  - [Monitor Version Store Usage](https://www.youtube.com/results?search_query=monitor+version+store+sql+server)
- 📘 **Docs:**  
  - [`sys.dm_tran_version_store_space_usage`](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-tran-version-store-space-usage-transact-sql)  
  - [`sys.dm_tran_active_snapshot_database_transactions`](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-tran-active-snapshot-database-transactions-transact-sql)

---

### 2.5 | Performance: Latch/IO in tempdb reduzieren
> **Kurzbeschreibung:** tempdb-Sizing, mehrere Datenfiles, Autogrowth-Strategie, schneller Storage, Wartung.

- 📓 **Notebook:**  
  [`08_05_tempdb_sizing_scaling.ipynb`](08_05_tempdb_sizing_scaling.ipynb)
- 🎥 **YouTube:**  
  - [Tune tempdb for Snapshot Isolation](https://www.youtube.com/results?search_query=tune+tempdb+snapshot+isolation)
- 📘 **Docs:**  
  - [tempdb – Best Practices](https://learn.microsoft.com/en-us/sql/relational-databases/databases/tempdb-database)

---

### 2.6 | Abfragekorrektheit & Anomalien
> **Kurzbeschreibung:** Welche Phänomene RCSI/SI verhindern bzw. zulassen; „First-Committer-Wins“ unter SI, wiederholte Reads unter RCSI.

- 📓 **Notebook:**  
  [`08_06_correctness_anomalies.ipynb`](08_06_correctness_anomalies.ipynb)
- 🎥 **YouTube:**  
  - [Isolation Phenomena with RCSI/SI](https://www.youtube.com/results?search_query=sql+server+isolation+phenomena+snapshot)
- 📘 **Docs:**  
  - [Isolation Levels – Verhalten](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-transaction-locking-and-row-versioning-guide#transaction-isolation-levels)

---

### 2.7 | Schreibkonflikte & Fehler 3960 (SI)
> **Kurzbeschreibung:** Write-Write-Konflikte erkennen/behandeln, Retry-Muster, Granularität (Zeile/Index-Key).

- 📓 **Notebook:**  
  [`08_07_write_conflicts_snapshot.ipynb`](08_07_write_conflicts_snapshot.ipynb)
- 🎥 **YouTube:**  
  - [Snapshot Write Conflict 3960](https://www.youtube.com/results?search_query=sql+server+snapshot+isolation+3960)
- 📘 **Docs:**  
  - [Snapshot Isolation – Konflikte](https://learn.microsoft.com/en-us/sql/relational-databases/tempdb/row-versioning-isolation-levels#snapshot-isolation-si)

---

### 2.8 | Locking-Interaktion & Hints
> **Kurzbeschreibung:** Warum `NOLOCK` obsolet ist; gezielte Hints (`UPDLOCK`/`HOLDLOCK`) für Korrektheit in Upsert-Pfaden.

- 📓 **Notebook:**  
  [`08_08_locking_interaction_hints.ipynb`](08_08_locking_interaction_hints.ipynb)
- 🎥 **YouTube:**  
  - [RCSI with UPDLOCK/HOLDLOCK](https://www.youtube.com/results?search_query=sql+server+rcsi+updlock+holdlock)
- 📘 **Docs:**  
  - [Table Hints – Referenz](https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-table)

---

### 2.9 | Lange Transaktionen & Cleanup-Stau
> **Kurzbeschreibung:** Ursachen (lange Reports, Offene Transaktionen), Erkennen & Auflösen, Timeout-Strategien.

- 📓 **Notebook:**  
  [`08_09_long_running_snapshots_cleanup.ipynb`](08_09_long_running_snapshots_cleanup.ipynb)
- 🎥 **YouTube:**  
  - [Version Store Cleanup Issues](https://www.youtube.com/results?search_query=version+store+cleanup+sql+server)
- 📘 **Docs:**  
  - [Version Cleanup – Hinweise](https://learn.microsoft.com/en-us/sql/relational-databases/tempdb/row-versioning-isolation-levels#version-store-cleanup)

---

### 2.10 | Indizes, SARGability & Pläne unter RCSI/SI
> **Kurzbeschreibung:** Warum gute Indizes weiterhin alles sind; Filter „auf Spalte“ (nicht auf Ausdruck), Plan-Stabilität.

- 📓 **Notebook:**  
  [`08_10_indexing_sargability_under_versioning.ipynb`](08_10_indexing_sargability_under_versioning.ipynb)
- 🎥 **YouTube:**  
  - [SARGability Still Matters](https://www.youtube.com/results?search_query=sargability+sql+server)
- 📘 **Docs:**  
  - [Query Processing Architecture](https://learn.microsoft.com/en-us/sql/relational-databases/query-processing-architecture-guide)

---

### 2.11 | DML-Patterns: Batch-Reads/Upserts sicher gestalten
> **Kurzbeschreibung:** Lesende Batch-Jobs ohne Blockaden; Upsert-Muster mit `UPDLOCK`/`HOLDLOCK` + RCSI/SI.

- 📓 **Notebook:**  
  [`08_11_dml_patterns_with_rcsi_si.ipynb`](08_11_dml_patterns_with_rcsi_si.ipynb)
- 🎥 **YouTube:**  
  - [UPSERT Patterns under Snapshot](https://www.youtube.com/results?search_query=sql+server+upsert+snapshot+isolation)
- 📘 **Docs:**  
  - [`UPDATE … FROM` / `MERGE` – Hinweise](https://learn.microsoft.com/en-us/sql/t-sql/statements/merge-transact-sql)

---

### 2.12 | Reporting & Analytics: Reprozierbare Reads planen
> **Kurzbeschreibung:** SI für komplexe Mehr-Statement-Reports; Abgrenzung zu RCSI (Statement-Snapshots).

- 📓 **Notebook:**  
  [`08_12_reporting_consistent_reads.ipynb`](08_12_reporting_consistent_reads.ipynb)
- 🎥 **YouTube:**  
  - [Consistent Reporting with Snapshot](https://www.youtube.com/results?search_query=reporting+snapshot+isolation+sql+server)
- 📘 **Docs:**  
  - [Snapshot Isolation – Details](https://learn.microsoft.com/en-us/sql/relational-databases/tempdb/row-versioning-isolation-levels#snapshot-isolation-si)

---

### 2.13 | Always On & Replikation – Interaktion
> **Kurzbeschreibung:** Auswirkungen auf Sekundär-Reads (AG), Logversand, Replikation – Version Store bleibt **pro DB**.

- 📓 **Notebook:**  
  [`08_13_hadr_interactions_rcsi_si.ipynb`](08_13_hadr_interactions_rcsi_si.ipynb)
- 🎥 **YouTube:**  
  - [RCSI/SI with AG Readables](https://www.youtube.com/results?search_query=sql+server+rcsi+always+on)
- 📘 **Docs:**  
  - [AG Readable Secondaries – Isolation](https://learn.microsoft.com/en-us/sql/database-engine/availability-groups/windows/active-secondaries-readable-secondary-replicas)

---

### 2.14 | Kapazitätsplanung & Alarmierung
> **Kurzbeschreibung:** Forecast für tempdb (Peak-Versionstore), Alarme (PerfMon/DMVs), Notfallmaßnahmen (Auto-Growth, Pre-Size, Offload-Reports).

- 📓 **Notebook:**  
  [`08_14_capacity_alerting_tempdb_versioning.ipynb`](08_14_capacity_alerting_tempdb_versioning.ipynb)
- 🎥 **YouTube:**  
  - [Capacity Planning for tempdb](https://www.youtube.com/results?search_query=capacity+planning+tempdb)
- 📘 **Docs:**  
  - [`sys.dm_db_file_space_usage`](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-file-space-usage-transact-sql)

---

### 2.15 | Migration auf RCSI/SI – Checkliste & Tests
> **Kurzbeschreibung:** Kompatibilitäts-Risiken (App-Annahmen, Trigger, lange TX), Pilotierung, Canary-Datenbanken.

- 📓 **Notebook:**  
  [`08_15_migration_checklist_tests.ipynb`](08_15_migration_checklist_tests.ipynb)
- 🎥 **YouTube:**  
  - [RCSI Migration Checklist](https://www.youtube.com/results?search_query=rcsi+migration+checklist+sql+server)
- 📘 **Docs:**  
  - [Row Versioning – Best Practices](https://learn.microsoft.com/en-us/sql/relational-databases/tempdb/row-versioning-isolation-levels#best-practices)

---

### 2.16 | Anti-Patterns & Checkliste
> **Kurzbeschreibung:** RCSI aktiv, aber weiterhin `NOLOCK`; endlose Snapshot-Transaktionen; ungeplante tempdb-Autogrowth-Loops; fehlendes Monitoring; falsche Erwartung „RCSI löst alle Deadlocks“; keine Indizes auf Hot-Prädikaten.

- 📓 **Notebook:**  
  [`08_16_rcsi_si_antipatterns_checkliste.ipynb`](08_16_rcsi_si_antipatterns_checkliste.ipynb)
- 🎥 **YouTube:**  
  - [Common Mistakes with RCSI/SI](https://www.youtube.com/results?search_query=rcsi+snapshot+isolation+mistakes+sql+server)
- 📘 **Docs/Blog:**  
  - [Locking & Row Versioning Guide](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-transaction-locking-and-row-versioning-guide)

---

## 3 | Weiterführende Informationen

- 📘 Microsoft Learn: [Row Versioning Isolation Levels (RCSI/SI)](https://learn.microsoft.com/en-us/sql/relational-databases/tempdb/row-versioning-isolation-levels)  
- 📘 Microsoft Learn: [`ALTER DATABASE` – `READ_COMMITTED_SNAPSHOT` / `ALLOW_SNAPSHOT_ISOLATION`](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-database-transact-sql-set-options)  
- 📘 Microsoft Learn: [SQL Server Locking & Row Versioning Guide (Komplett)](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-transaction-locking-and-row-versioning-guide)  
- 📘 Microsoft Learn: [tempdb – Überblick & Best Practices](https://learn.microsoft.com/en-us/sql/relational-databases/databases/tempdb-database)  
- 📘 Microsoft Learn: DMVs – [`sys.dm_tran_version_store_space_usage`](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-tran-version-store-space-usage-transact-sql), [`sys.dm_tran_active_snapshot_database_transactions`](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-tran-active-snapshot-database-transactions-transact-sql), [`sys.dm_tran_top_version_generators`](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-tran-top-version-generators-transact-sql)  
- 📘 Microsoft Learn: [Performance Counters – Row Versioning](https://learn.microsoft.com/en-us/sql/relational-databases/performance/monitor-and-tune-for-performance) *(Kategorie „SQLServer:Transactions“)*  
- 📘 Microsoft Learn: [Isolation Levels – Verhalten & Beispiele](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-transaction-isolation-level-transact-sql)  
- 📝 SQLPerformance: *RCSI vs. Locking RC, Version Store & Waits* – https://www.sqlperformance.com/?s=rcsi  
- 📝 Paul White (SQL Kiwi): *Snapshot Isolation & Concurrency Internals* – https://www.sql.kiwi/  
- 📝 Brent Ozar: *RCSI in the Real World* – https://www.brentozar.com/  
- 📝 Erik Darling: *When RCSI Isn’t Enough (Use UPDLOCK/HOLDLOCK)* – https://www.erikdarlingdata.com/  
- 📝 Simple Talk (Redgate): *Practical Guide to Snapshot Isolation* – https://www.red-gate.com/simple-talk/  
- 🎥 YouTube (Data Exposed): *Row Versioning & Snapshot Isolation – Deep Dive* – Suchlink  
- 🎥 YouTube: *Diagnose Version Store Growth – DMVs & PerfMon* – Suchlink  
