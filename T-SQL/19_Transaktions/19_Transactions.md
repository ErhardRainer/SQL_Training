# T-SQL Transaktionen – Übersicht  
*`BEGIN` / `COMMIT` / `ROLLBACK`, Fehlerfälle & saubere Transaktionsgrenzen*

## 1 | Begriffsdefinition

| SQL-Term | Beschreibung |
|---|---|
| Transaktion | Atomare Einheit mehrerer Anweisungen; garantiert **ACID** (Atomicity, Consistency, Isolation, Durability). |
| Autocommit | Standardmodus in SQL Server: Jede Anweisung ist implizit eine eigene Transaktion. |
| Explizite Transaktion | Manuell mit `BEGIN [TRANSACTION] … COMMIT/ROLLBACK` umschlossen. |
| Implizite Transaktionen | `SET IMPLICIT_TRANSACTIONS ON` startet nach Ausführung bestimmter Befehle automatisch eine Transaktion (bis `COMMIT/ROLLBACK`). |
| `@@TRANCOUNT` | Aktueller **Verschachtelungszähler**; nur der äußerste `COMMIT` schreibt dauerhaft, `ROLLBACK` setzt auf 0. |
| `SAVE TRAN` | Setzt **Savepoint** in laufender Transaktion; `ROLLBACK TRAN savepoint` rollt bis dahin zurück. |
| `XACT_STATE()` | Liefert **-1** (nicht commitbar), **1** (commitbar), **0** (keine Transaktion). |
| `SET XACT_ABORT ON` | Laufzeitfehler bewirken automatischen **Rollback** der gesamten Transaktion. |
| `TRY…CATCH` / `THROW` | Fehlerhandhabung; in CATCH sauber aufräumen (`IF @@TRANCOUNT>0 ROLLBACK`) und **neu werfen**. |
| Isolation Level | `READ UNCOMMITTED` … `SERIALIZABLE`, `SNAPSHOT`; steuert Sichtbarkeit & Sperren. |
| Zeilenversionierung | `SNAPSHOT` & `READ COMMITTED SNAPSHOT (RCSI)` lesen **Versionen** statt Sperren zu setzen. |
| Deadlock | Zyklische Sperrwarte; SQL Server beendet einen **Opferprozess** (Fehler 1205). |
| Log & Dauer | Aktive Transaktionen verhindern **Log-Truncation**; lange Xacts → Log-Wachstum/Blocking. |
| Verteilte Transaktion | `BEGIN DISTRIBUTED TRANSACTION` über mehrere Ressourcen (MSDTC). |
| DDL & Trigger | Viele DDL/DML laufen **transaktional**; DML-Trigger laufen **im selben Kontext** wie der auslösende Befehl. |

---

## 2 | Struktur

### 2.1 | Grundlagen: BEGIN/COMMIT/ROLLBACK & Autocommit
> **Kurzbeschreibung:** Minimale Syntax, Standard-Autocommit, wann explizite Transaktionen sinnvoll sind.

- 📓 **Notebook:**  
  [`08_01_transaktionen_grundlagen.ipynb`](08_01_transaktionen_grundlagen.ipynb)

- 🎥 **YouTube:**  
  - [SQL Server Transactions – Basics](https://www.youtube.com/results?search_query=sql+server+transactions+begin+commit+rollback)

- 📘 **Docs:**  
  - [`BEGIN TRANSACTION`](https://learn.microsoft.com/en-us/sql/t-sql/statements/begin-transaction-transact-sql) · [`COMMIT`](https://learn.microsoft.com/en-us/sql/t-sql/statements/commit-transaction-transact-sql) · [`ROLLBACK`](https://learn.microsoft.com/en-us/sql/t-sql/statements/rollback-transaction-transact-sql)

---

### 2.2 | Autocommit vs. Implizit vs. Explizit
> **Kurzbeschreibung:** Verhalten & Stolperfallen von `SET IMPLICIT_TRANSACTIONS ON`, Unterschiede zum Standard.

- 📓 **Notebook:**  
  [`08_02_autocommit_vs_implizit_explizit.ipynb`](08_02_autocommit_vs_implizit_explizit.ipynb)

- 🎥 **YouTube:**  
  - [Implicit Transactions Explained](https://www.youtube.com/results?search_query=sql+server+implicit+transactions)

- 📘 **Docs:**  
  - [`SET IMPLICIT_TRANSACTIONS`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-implicit-transactions-transact-sql)

---

### 2.3 | TRY/CATCH, `THROW` & `XACT_STATE()` – robustes Fehlerhandling
> **Kurzbeschreibung:** Sauber aufräumen & neu werfen; uncommittable state erkennen.

- 📓 **Notebook:**  
  [`08_03_try_catch_throw_xact_state.ipynb`](08_03_try_catch_throw_xact_state.ipynb)

- 🎥 **YouTube:**  
  - [TRY…CATCH Pattern for Transactions](https://www.youtube.com/results?search_query=sql+server+try+catch+transactions)

- 📘 **Docs:**  
  - [`TRY…CATCH`](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/try-catch-transact-sql) · [`THROW`](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/throw-transact-sql)  
  - [`XACT_STATE()`](https://learn.microsoft.com/en-us/sql/t-sql/functions/xact-state-transact-sql)

---

### 2.4 | `SET XACT_ABORT ON` – Wann & warum?
> **Kurzbeschreibung:** Laufzeitfehler (z. B. FK-Verletzung) → gesamter Rollback; Interop mit TRY/CATCH.

- 📓 **Notebook:**  
  [`08_04_xact_abort_patterns.ipynb`](08_04_xact_abort_patterns.ipynb)

- 🎥 **YouTube:**  
  - [XACT_ABORT Deep Dive](https://www.youtube.com/results?search_query=sql+server+xact_abort)

- 📘 **Docs:**  
  - [`SET XACT_ABORT`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-xact-abort-transact-sql)

---

### 2.5 | Savepoints & „verschachtelte“ Transaktionen
> **Kurzbeschreibung:** `SAVE TRAN` nutzen, Verhalten von `@@TRANCOUNT`, echte vs. scheinbare Verschachtelung.

- 📓 **Notebook:**  
  [`08_05_savepoints_nested.ipynb`](08_05_savepoints_nested.ipynb)

- 🎥 **YouTube:**  
  - [SAVE TRAN / Nested Transactions](https://www.youtube.com/results?search_query=sql+server+save+transaction+nested)

- 📘 **Docs:**  
  - [`SAVE TRANSACTION`](https://learn.microsoft.com/en-us/sql/t-sql/statements/save-transaction-transact-sql) · [`@@TRANCOUNT`](https://learn.microsoft.com/en-us/sql/t-sql/functions/trancount-transact-sql)

---

### 2.6 | Isolation Levels & Row-Versioning (SNAPSHOT/RCSI)
> **Kurzbeschreibung:** Korrekte Isolation wählen; `SNAPSHOT`/`RCSI` aktivieren & Auswirkungen verstehen.

- 📓 **Notebook:**  
  [`08_06_isolation_snapshot_rcsi.ipynb`](08_06_isolation_snapshot_rcsi.ipynb)

- 🎥 **YouTube:**  
  - [Isolation Levels Explained](https://www.youtube.com/results?search_query=sql+server+isolation+levels)

- 📘 **Docs:**  
  - [`SET TRANSACTION ISOLATION LEVEL`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-transaction-isolation-level-transact-sql)  
  - [Row Versioning Isolation Levels](https://learn.microsoft.com/en-us/sql/relational-databases/tempdb/row-versioning-isolation-levels)

---

### 2.7 | Sperren & Eskalation im Transaktionskontext
> **Kurzbeschreibung:** Lock-Arten, Eskalation, typische Hints (`UPDLOCK`,`HOLDLOCK`) und Risiken.

- 📓 **Notebook:**  
  [`08_07_locks_escalation_transaktionen.ipynb`](08_07_locks_escalation_transaktionen.ipynb)

- 🎥 **YouTube:**  
  - [Locking & Blocking Basics](https://www.youtube.com/results?search_query=sql+server+locking+blocking)

- 📘 **Docs:**  
  - [Locking Overview](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-transaction-locking-and-row-versioning-guide)  
  - [Table Hints](https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-table)

---

### 2.8 | Deadlocks erkennen & Retry-Muster
> **Kurzbeschreibung:** Fehler 1205 behandeln, Backoff/Retry, Reihenfolgen & Zugriffsmuster harmonisieren.

- 📓 **Notebook:**  
  [`08_08_deadlocks_retry_pattern.ipynb`](08_08_deadlocks_retry_pattern.ipynb)

- 🎥 **YouTube:**  
  - [Deadlocks & Retry Logic](https://www.youtube.com/results?search_query=sql+server+deadlock+retry)

- 📘 **Docs:**  
  - [Deadlock Info & Monitoring](https://learn.microsoft.com/en-us/sql/relational-databases/performance/monitor-deadlocks)  
  - [Error 1205](https://learn.microsoft.com/en-us/sql/relational-databases/errors-events/database-engine-events-and-errors)

---

### 2.9 | Lange Transaktionen, Log & Betrieb
> **Kurzbeschreibung:** Aktive Xacts halten Log aktiv, verhindern Truncation; Auswirkungen auf Backup/KPIs.

- 📓 **Notebook:**  
  [`08_09_long_running_xacts_log.ipynb`](08_09_long_running_xacts_log.ipynb)

- 🎥 **YouTube:**  
  - [Transaction Log Basics](https://www.youtube.com/results?search_query=sql+server+transaction+log+basics)

- 📘 **Docs:**  
  - [Transaction Log – Architektur](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-transaction-log-architecture-and-management)

---

### 2.10 | DDL in Transaktionen & Sperrverhalten
> **Kurzbeschreibung:** Was geht, was sperrt lange; Schema-Änderungen, Indizes, Partition Switch.

- 📓 **Notebook:**  
  [`08_10_ddl_in_transaktionen.ipynb`](08_10_ddl_in_transaktionen.ipynb)

- 🎥 **YouTube:**  
  - [DDL & Locks](https://www.youtube.com/results?search_query=sql+server+ddl+locks)

- 📘 **Docs:**  
  - [Transactions & DDL (Überblick)](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/transactions-transact-sql)  
  - [Lock Escalation](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-lock-escalation)

---

### 2.11 | Trigger & Transaktionskontext
> **Kurzbeschreibung:** DML-Trigger laufen innerhalb derselben Transaktion; `ROLLBACK` im Trigger → rollt Aufrufer zurück.

- 📓 **Notebook:**  
  [`08_11_trigger_und_transaktionen.ipynb`](08_11_trigger_und_transaktionen.ipynb)

- 🎥 **YouTube:**  
  - [Triggers & Transactions](https://www.youtube.com/results?search_query=sql+server+trigger+transaction)

- 📘 **Docs:**  
  - [`CREATE TRIGGER`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-trigger-transact-sql)

---

### 2.12 | Verteilte & Cross-DB-Transaktionen (MSDTC)
> **Kurzbeschreibung:** `BEGIN DISTRIBUTED TRANSACTION`, Linked Servers; Latenz/Fehlerhandling beachten.

- 📓 **Notebook:**  
  [`08_12_distributed_transactions_msdtc.ipynb`](08_12_distributed_transactions_msdtc.ipynb)

- 🎥 **YouTube:**  
  - [Distributed Transactions – Overview](https://www.youtube.com/results?search_query=sql+server+begin+distributed+transaction)

- 📘 **Docs:**  
  - [`BEGIN DISTRIBUTED TRANSACTION`](https://learn.microsoft.com/en-us/sql/t-sql/statements/begin-distributed-transaction-transact-sql)  
  - [MSDTC – Leitfaden](https://learn.microsoft.com/en-us/troubleshoot/sql/database-engine/availability/transactions/understanding-msdtc)

---

### 2.13 | Muster: DML innerhalb von Transaktionen
> **Kurzbeschreibung:** Insert/Update/Delete mit Qualitätschecks (`@@ROWCOUNT`), Output/Audit, Fehlerrobustheit.

- 📓 **Notebook:**  
  [`08_13_dml_muster_in_transaktionen.ipynb`](08_13_dml_muster_in_transaktionen.ipynb)

- 🎥 **YouTube:**  
  - [DML Transaction Patterns](https://www.youtube.com/results?search_query=sql+server+dml+transaction+pattern)

- 📘 **Docs:**  
  - [`@@ROWCOUNT`](https://learn.microsoft.com/en-us/sql/t-sql/functions/rowcount-transact-sql)  
  - [`OUTPUT`-Klausel](https://learn.microsoft.com/en-us/sql/t-sql/queries/output-clause-transact-sql)

---

### 2.14 | Idempotenz, Retries & Nebenläufigkeit
> **Kurzbeschreibung:** „At-least-once“-Aufrufe sicher machen; eindeutige Schlüssel/Constraints als Schutz.

- 📓 **Notebook:**  
  [`08_14_idempotenz_retries.ipynb`](08_14_idempotenz_retries.ipynb)

- 🎥 **YouTube:**  
  - [Idempotent DML & Retries](https://www.youtube.com/results?search_query=sql+server+idempotent+retry)

- 📘 **Docs/Blog:**  
  - [Unique Constraints & Fehlercodes](https://learn.microsoft.com/en-us/sql/relational-databases/tables/create-unique-constraints)

---

### 2.15 | Monitoring: DMVs, XEvents & Diagnostik
> **Kurzbeschreibung:** Aktive Transaktionen & Sperren finden, Blockchains analysieren, Deadlocks capturen.

- 📓 **Notebook:**  
  [`08_15_monitoring_dmvs_xevents.ipynb`](08_15_monitoring_dmvs_xevents.ipynb)

- 🎥 **YouTube:**  
  - [DMVs for Blocking/Transactions](https://www.youtube.com/results?search_query=sql+server+dmv+transactions+blocking)

- 📘 **Docs:**  
  - [`sys.dm_tran_active_transactions`](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-tran-active-transactions-transact-sql)  
  - [`sys.dm_tran_locks`](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-tran-locks-transact-sql)

---

### 2.16 | Anti-Patterns & Checkliste
> **Kurzbeschreibung:** Transaktionen über UI/Netzwerkrunden halten, `COMMIT` vergessen, Mischbetrieb implizit/explizit, große SELECTs in `SERIALIZABLE`, fehlende Fehlerbehandlung.

- 📓 **Notebook:**  
  [`08_16_transaktionen_anti_patterns.ipynb`](08_16_transaktionen_anti_patterns.ipynb)

- 🎥 **YouTube:**  
  - [Common Transaction Mistakes](https://www.youtube.com/results?search_query=sql+server+transaction+mistakes)

- 📘 **Docs/Blog:**  
  - [Transactions – Überblick & Best Practices](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/transactions-transact-sql)

---

## 3 | Weiterführende Informationen

- 📘 Microsoft Learn: [`BEGIN` / `COMMIT` / `ROLLBACK` (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/transactions-transact-sql)  
- 📘 Microsoft Learn: [`TRY…CATCH`, `THROW`, `XACT_STATE()`](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/try-catch-transact-sql)  
- 📘 Microsoft Learn: [`SET XACT_ABORT`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-xact-abort-transact-sql)  
- 📘 Microsoft Learn: [Locking & Row Versioning Guide](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-transaction-locking-and-row-versioning-guide)  
- 📘 Microsoft Learn: [Isolation Levels & Row Versioning (SNAPSHOT/RCSI)](https://learn.microsoft.com/en-us/sql/relational-databases/tempdb/row-versioning-isolation-levels)  
- 📘 Microsoft Learn: [Deadlocks – Erkennen & Beheben](https://learn.microsoft.com/en-us/sql/relational-databases/performance/monitor-deadlocks)  
- 📘 Microsoft Learn: [Transaction Log – Architektur & Verwaltung](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-transaction-log-architecture-and-management)  
- 📘 Microsoft Learn: [`BEGIN DISTRIBUTED TRANSACTION`](https://learn.microsoft.com/en-us/sql/t-sql/statements/begin-distributed-transaction-transact-sql)  
- 📝 SQLSkills (Paul Randal): *XACT_ABORT & Error Handling* – https://www.sqlskills.com/  
- 📝 Kendra Little: *Deadlocks, Blocking & Retry Patterns* – https://kendralittle.com/  
- 📝 Erik Darling: *Transaction Anti-Patterns & Hints* – https://www.erikdarlingdata.com/  
- 📝 Brent Ozar: *Snapshot/RCSI – Praxis & Trade-offs* – https://www.brentozar.com/  
- 📝 SQLPerformance: *Long-Running Transactions & Log Growth* – https://www.sqlperformance.com/?s=transaction+log  
- 🎥 YouTube (Data Exposed): *Isolation Levels & Concurrency* – Suchlink  
- 🎥 YouTube: *TRY/CATCH + XACT_ABORT – Demo* – Suchlink  

