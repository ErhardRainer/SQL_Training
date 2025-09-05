# T-SQL Isolation Levels – Übersicht  
*Isolationsstufen, Sperrverhalten, Nebenläufigkeit und Anomalien*

## 1 | Begriffsdefinition

| SQL-Term | Beschreibung |
|---|---|
| Isolation Level | Transaktionsisolation gemäß ANSI/ISO; steuert **Sichtbarkeit** und **Sperr-/Versionierungsverhalten**. |
| READ UNCOMMITTED | Schnellste, **unsicherste** Stufe; erlaubt **Dirty Reads**. Entspricht `WITH (NOLOCK)`-Hinweisen. |
| READ COMMITTED (RC) | Standard in SQL Server (ohne RCSI): **keine Dirty Reads**, aber **Non-Repeatable Reads**/**Phantoms** möglich. |
| READ COMMITTED SNAPSHOT (RCSI) | Variante von RC mit **Zeilenversionierung** (Statement-Snapshot). Leser blockieren **keine** Schreiber und umgekehrt. |
| SNAPSHOT (SI) | **Transaktions-Snapshot** über Version Store; keine Dirty/Non-Repeatable/Phantom Reads innerhalb der Transaktion. **Write-Write-Konflikte** → Fehler **3960** beim Commit. |
| REPEATABLE READ | Schutz vor **Non-Repeatable Reads** (Sperren bleiben), **Phantoms** weiterhin möglich. |
| SERIALIZABLE | Strengste Stufe; verhindert **Phantoms** (Range Locks), entspricht serieller Ausführung. |
| Sperrmodi | `S` (Shared), `U` (Update), `X` (Exclusive), Intent (`IS/IU/IX`), Schema (`Sch-S/Sch-M`), Range-Locks (`RangeS-S`, `RangeS-U`, `RangeI-N`, …). |
| Lock-Eskalation | Automatische Hochstufung von Zeilen/Seiten- auf **Tabellensperren** bei vielen Locks. |
| Version Store (tempdb) | Speicher für Zeilenversionen (RCSI/SI). Lange Leser/Transaktionen vergrößern den Store. |
| Anomalien | **Dirty Read**, **Non-Repeatable Read**, **Phantom**, (**Write Skew** in speziellen Mustern). |
| Hints (Tabelle/Query) | `WITH (NOLOCK|HOLDLOCK|UPDLOCK|READPAST|ROWLOCK|PAGLOCK|TABLOCK)`; Query-Hints: `OPTION (MAXDOP …, RECOMPILE, …)` + `SET TRANSACTION ISOLATION LEVEL …`. |
| Timeout/Priorität | `SET LOCK_TIMEOUT`, `SET DEADLOCK_PRIORITY`. |
| RCSI vs. SI | **RCSI:** Statement-weiser Snapshot nur für **Lesen**. **SI:** Transaktionsweiter Snapshot, **Lese-/Schreib-**Semantik, Write-Konfliktprüfung. |
| Best Practices | Standard i. d. R. **RCSI**; gezielt `UPDLOCK/HOLDLOCK` für Korrektheit; **keine** pauschalen `NOLOCK`. |

---

## 2 | Struktur

### 2.1 | Überblick & Zielkonflikte: Korrektheit vs. Durchsatz
> **Kurzbeschreibung:** Welche Stufe verhindert welche Anomalien? Trade-offs zwischen Blockieren, Versionieren und Konsistenz.

- 📓 **Notebook:**  
  [`08_01_isolation_overview.ipynb`](08_01_isolation_overview.ipynb)
- 🎥 **YouTube:**  
  - [SQL Server Isolation Levels – Overview](https://www.youtube.com/results?search_query=sql+server+isolation+levels+overview)  
  - [Concurrency Control Basics](https://www.youtube.com/results?search_query=sql+server+concurrency+control)
- 📘 **Docs:**  
  - [`SET TRANSACTION ISOLATION LEVEL`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-transaction-isolation-level-transact-sql)  
  - [Row Versioning Isolation Levels (Überblick)](https://learn.microsoft.com/en-us/sql/relational-databases/tempdb/row-versioning-isolation-levels)

---

### 2.2 | READ UNCOMMITTED & `NOLOCK` – warum (meist) nicht
> **Kurzbeschreibung:** Dirty Reads, Ghost-Record-Probleme, doppelte/fehlende Zeilen, Lesefehler bei Reorgs.

- 📓 **Notebook:**  
  [`08_02_read_uncommitted_nolock_risiken.ipynb`](08_02_read_uncommitted_nolock_risiken.ipynb)
- 🎥 **YouTube:**  
  - [The Problem with NOLOCK](https://www.youtube.com/results?search_query=sql+server+nolock+problems)
- 📘 **Docs:**  
  - [Table Hints – `NOLOCK`/`READUNCOMMITTED`](https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-table)

---

### 2.3 | READ COMMITTED (klassisch)
> **Kurzbeschreibung:** Standard ohne RCSI: Kurzzeit-`S`-Sperren; Leser ↔ Schreiber blockieren sich.

- 📓 **Notebook:**  
  [`08_03_read_committed_basics.ipynb`](08_03_read_committed_basics.ipynb)
- 🎥 **YouTube:**  
  - [Read Committed Explained](https://www.youtube.com/results?search_query=sql+server+read+committed)
- 📘 **Docs:**  
  - [`SET TRANSACTION ISOLATION LEVEL` – RC](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-transaction-isolation-level-transact-sql)

---

### 2.4 | READ COMMITTED SNAPSHOT (RCSI)
> **Kurzbeschreibung:** Statement-Snapshot: Leser sehen eine **konsistente** Momentaufnahme, blockieren keine Schreiber.

- 📓 **Notebook:**  
  [`08_04_rcsi_enable_patterns.ipynb`](08_04_rcsi_enable_patterns.ipynb)
- 🎥 **YouTube:**  
  - [RCSI vs Read Committed](https://www.youtube.com/results?search_query=sql+server+read+committed+snapshot)
- 📘 **Docs:**  
  - [`ALTER DATABASE … SET READ_COMMITTED_SNAPSHOT ON`](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-database-transact-sql-set-options)  
  - [Row Versioning (RCSI)](https://learn.microsoft.com/en-us/sql/relational-databases/tempdb/row-versioning-isolation-levels#read-committed-snapshot-isolation-rcsi)

---

### 2.5 | SNAPSHOT Isolation (SI)
> **Kurzbeschreibung:** Transaktionsweiter Snapshot; verhindert Dirty/Non-Repeatable/Phantom Reads; **3960** bei Write-Konflikt.

- 📓 **Notebook:**  
  [`08_05_snapshot_isolation_patterns.ipynb`](08_05_snapshot_isolation_patterns.ipynb)
- 🎥 **YouTube:**  
  - [Snapshot Isolation Deep Dive](https://www.youtube.com/results?search_query=sql+server+snapshot+isolation)
- 📘 **Docs:**  
  - [`ALTER DATABASE … SET ALLOW_SNAPSHOT_ISOLATION ON`](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-database-transact-sql-set-options)  
  - [Snapshot Isolation (Details & Konflikte 3960)](https://learn.microsoft.com/en-us/sql/relational-databases/tempdb/row-versioning-isolation-levels#snapshot-isolation-si)

---

### 2.6 | REPEATABLE READ
> **Kurzbeschreibung:** Hält `S`-Sperren bis Tx-Ende → keine Non-Repeatable Reads, aber **Phantoms** möglich.

- 📓 **Notebook:**  
  [`08_06_repeatable_read_basics.ipynb`](08_06_repeatable_read_basics.ipynb)
- 🎥 **YouTube:**  
  - [Repeatable Read Explained](https://www.youtube.com/results?search_query=sql+server+repeatable+read)
- 📘 **Docs:**  
  - [`SET TRANSACTION ISOLATION LEVEL` – RR](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-transaction-isolation-level-transact-sql)

---

### 2.7 | SERIALIZABLE & Range Locks
> **Kurzbeschreibung:** Strengste Isolation: Range Locks verhindern **Phantoms**; teuer bei hohem Durchsatz.

- 📓 **Notebook:**  
  [`08_07_serializable_range_locks.ipynb`](08_07_serializable_range_locks.ipynb)
- 🎥 **YouTube:**  
  - [Serializable Isolation & Range Locks](https://www.youtube.com/results?search_query=sql+server+serializable+range+locks)
- 📘 **Docs:**  
  - [Locking – Range Locks & Phantoms](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-transaction-locking-and-row-versioning-guide)

---

### 2.8 | Sperren verstehen: Modi, Hierarchie & Kompatibilität
> **Kurzbeschreibung:** `S/U/X`, Intent-Locks, Seiten/Tabellen, Kompatibilitätsmatrix korrekt lesen.

- 📓 **Notebook:**  
  [`08_08_lock_modes_compatibility.ipynb`](08_08_lock_modes_compatibility.ipynb)
- 🎥 **YouTube:**  
  - [SQL Server Locking Explained](https://www.youtube.com/results?search_query=sql+server+locking+explained)
- 📘 **Docs:**  
  - [Lock Modes & Compatibility](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-transaction-locking-and-row-versioning-guide#lock-modes)  

---

### 2.9 | Anomalien-Matrix (Dirty/Non-Repeatable/Phantom)
> **Kurzbeschreibung:** Gegenüberstellung je Stufe; wann zusätzliche Hints nötig sind.

- 📓 **Notebook:**  
  [`08_09_anomalies_matrix.ipynb`](08_09_anomalies_matrix.ipynb)
- 🎥 **YouTube:**  
  - [Isolation Phenomena](https://www.youtube.com/results?search_query=sql+server+isolation+phenomena)
- 📘 **Docs:**  
  - [Transaction Isolation Overview](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-transaction-locking-and-row-versioning-guide#transaction-isolation-levels)

---

### 2.10 | Lock-Eskalation & Granularität
> **Kurzbeschreibung:** Wann/warum SQL Server auf Tabellensperren eskaliert; Steuerung & Auswirkungen.

- 📓 **Notebook:**  
  [`08_10_lock_escalation_and_granularity.ipynb`](08_10_lock_escalation_and_granularity.ipynb)
- 🎥 **YouTube:**  
  - [Lock Escalation in Practice](https://www.youtube.com/results?search_query=sql+server+lock+escalation)
- 📘 **Docs:**  
  - [Lock Escalation](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-transaction-locking-and-row-versioning-guide#lock-escalation)

---

### 2.11 | Blocking, Deadlocks & Zeitlimits
> **Kurzbeschreibung:** Diagnose & Behebung; `SET DEADLOCK_PRIORITY`, `SET LOCK_TIMEOUT`, Retry-Pattern.

- 📓 **Notebook:**  
  [`08_11_blocking_deadlocks_timeouts.ipynb`](08_11_blocking_deadlocks_timeouts.ipynb)
- 🎥 **YouTube:**  
  - [Detect & Resolve Deadlocks](https://www.youtube.com/results?search_query=sql+server+deadlock+detection)
- 📘 **Docs:**  
  - [Deadlocks – Monitoring & Troubleshooting](https://learn.microsoft.com/en-us/sql/relational-databases/performance/monitor-deadlocks)  
  - [`SET LOCK_TIMEOUT`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-lock-timeout-transact-sql)

---

### 2.12 | Version Store in `tempdb` – Monitoring
> **Kurzbeschreibung:** DMVs/PerfCounter, lange Leser/Writer erkennen, Auswirkungen auf `tempdb`.

- 📓 **Notebook:**  
  [`08_12_version_store_monitoring.ipynb`](08_12_version_store_monitoring.ipynb)
- 🎥 **YouTube:**  
  - [Version Store Explained](https://www.youtube.com/results?search_query=sql+server+version+store)
- 📘 **Docs:**  
  - [`sys.dm_tran_version_store` / aktive Snapshot-Txs](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-tran-version-store-transact-sql)  
  - [`sys.dm_tran_active_snapshot_database_transactions`](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-tran-active-snapshot-database-transactions-transact-sql)

---

### 2.13 | Praktische Hints: `UPDLOCK`, `HOLDLOCK`, `READPAST`, `ROWLOCK`
> **Kurzbeschreibung:** Korrektheit & Contention steuern (z. B. „Take-and-hold“-Muster, Skip-Locked).

- 📓 **Notebook:**  
  [`08_13_table_hints_patterns.ipynb`](08_13_table_hints_patterns.ipynb)
- 🎥 **YouTube:**  
  - [Using UPDLOCK & HOLDLOCK](https://www.youtube.com/results?search_query=sql+server+updlock+holdlock)
- 📘 **Docs:**  
  - [Table Hints – Referenz](https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-table)

---

### 2.14 | Umstellung auf RCSI/SI – Risiken & Tests
> **Kurzbeschreibung:** Schritte/Checkliste, App-Kompatibilität, lange Transaktionen, `tempdb`-Sizing.

- 📓 **Notebook:**  
  [`08_14_migration_rcsi_si_checklist.ipynb`](08_14_migration_rcsi_si_checklist.ipynb)
- 🎥 **YouTube:**  
  - [Enabling RCSI Safely](https://www.youtube.com/results?search_query=enable+read+committed+snapshot+sql+server)
- 📘 **Docs:**  
  - [RCSI/SI – Aktivierung & Hinweise](https://learn.microsoft.com/en-us/sql/relational-databases/tempdb/row-versioning-isolation-levels)

---

### 2.15 | Performance & Waits: LCK\_*, PAGELATCH, Throughput
> **Kurzbeschreibung:** Typische Wartearten interpretieren; wie RCSI/Si Durchsatz und Latenz beeinflussen.

- 📓 **Notebook:**  
  [`08_15_perf_waits_throughput.ipynb`](08_15_perf_waits_throughput.ipynb)
- 🎥 **YouTube:**  
  - [Interpreting LCK Waits](https://www.youtube.com/results?search_query=sql+server+lck+waits)
- 📘 **Docs:**  
  - [`sys.dm_os_wait_stats` – LCK-Waits](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-os-wait-stats-transact-sql)  
  - [Query Processing & Concurrency](https://learn.microsoft.com/en-us/sql/relational-databases/query-processing-architecture-guide)

---

### 2.16 | Anti-Patterns & Checkliste
> **Kurzbeschreibung:** Pauschales `NOLOCK`, fehlende Indexe auf Hotpaths, **lange** SI-Transaktionen, unbedachte Range Locks, `LOCK_TIMEOUT -1`, kein Monitoring des Version Store.

- 📓 **Notebook:**  
  [`08_16_isolation_anti_patterns_checkliste.ipynb`](08_16_isolation_anti_patterns_checkliste.ipynb)
- 🎥 **YouTube:**  
  - [Common Isolation Mistakes](https://www.youtube.com/results?search_query=sql+server+isolation+mistakes)
- 📘 **Docs/Blog:**  
  - [Locking & Row Versioning Guide](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-transaction-locking-and-row-versioning-guide)

---

## 3 | Weiterführende Informationen

- 📘 Microsoft Learn: [`SET TRANSACTION ISOLATION LEVEL`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-transaction-isolation-level-transact-sql)  
- 📘 Microsoft Learn: [`ALTER DATABASE` – `READ_COMMITTED_SNAPSHOT` / `ALLOW_SNAPSHOT_ISOLATION`](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-database-transact-sql-set-options)  
- 📘 Microsoft Learn: [Locking & Row Versioning Guide (Komplett)](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-transaction-locking-and-row-versioning-guide)  
- 📘 Microsoft Learn: [Row Versioning Isolation Levels (RCSI/SI)](https://learn.microsoft.com/en-us/sql/relational-databases/tempdb/row-versioning-isolation-levels)  
- 📘 Microsoft Learn: [Lock Modes & Compatibility Matrix](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-transaction-locking-and-row-versioning-guide#lock-modes)  
- 📘 Microsoft Learn: [`sys.dm_tran_locks`](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-tran-locks-transact-sql) · [`sys.dm_tran_database_transactions`](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-tran-database-transactions-transact-sql)  
- 📘 Microsoft Learn: [`sys.dm_tran_version_store`](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-tran-version-store-transact-sql) · [`sys.dm_tran_active_snapshot_database_transactions`](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-tran-active-snapshot-database-transactions-transact-sql)  
- 📘 Microsoft Learn: [Deadlocks – Monitor & Troubleshoot](https://learn.microsoft.com/en-us/sql/relational-databases/performance/monitor-deadlocks) · [`SET DEADLOCK_PRIORITY`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-deadlock-priority-transact-sql)  
- 📘 Microsoft Learn: [`SET LOCK_TIMEOUT`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-lock-timeout-transact-sql)  
- 📘 Microsoft Learn: [Query Processing Architecture Guide](https://learn.microsoft.com/en-us/sql/relational-databases/query-processing-architecture-guide)  
- 📝 Itzik Ben-Gan: *Isolation Levels, RCSI & SI – Patterns* (Artikel/Präsentationen – Suche)  
- 📝 Paul White (SQL Kiwi): *Locking, Latches & Concurrency Internals* – https://www.sql.kiwi/  
- 📝 SQLPerformance: *RCSI vs Locking RC, Version Store, LCK Waits* – https://www.sqlperformance.com/?s=rcsi  
- 📝 Brent Ozar: *NOLOCK vs RCSI – Real World* – https://www.brentozar.com/  
- 📝 Erik Darling: *UPDLOCK/HOLDLOCK – Correctness Patterns* – https://www.erikdarlingdata.com/  
- 🎥 YouTube (Data Exposed): *Row Versioning & Isolation Levels* – Suchlink  
