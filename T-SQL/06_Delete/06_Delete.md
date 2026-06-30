# T-SQL DELETE – Übersicht

## 1 | Begriffsdefinition

| SQL-Term | Beschreibung |
|---|---|
| `DELETE` | Entfernt Zeilen aus einer Tabelle oder updatable View. Vollloggend (jede Zeile wird geloggt). |
| Zielobjekt | Tabelle oder updatable View, aus der Zeilen entfernt werden. |
| `WHERE`-Klausel | Bestimmt **welche** Zeilen gelöscht werden; ohne `WHERE` wird **alles** gelöscht. |
| `DELETE … FROM` | T-SQL-Erweiterung: Join-basierte Löschung über Ziel + zusätzliche Quellen (Tabelle/CTE/abgeleitete Tabelle). |
| `TOP (N)` in `DELETE` | Begrenzung der Löschmenge pro Statement – Reihenfolge ohne zusätzliche Technik nicht deterministisch. |
| `OUTPUT`-Klausel | Liefert gelöschte Zeilen über Pseudo-Tabelle `deleted` (Audit/ETL). |
| Transaktion | Atomare Einheit (`BEGIN/COMMIT/ROLLBACK`), optional `SET XACT_ABORT ON` bei Fehlern. |
| Isolation Level | Sichtbarkeit/Parallelität (`READ COMMITTED`, `SNAPSHOT`, `SERIALIZABLE` …). |
| Sperren (Locks) | `X`-/`IX`-Sperren; Hints wie `READPAST`, `ROWLOCK`, `PAGLOCK`, `TABLOCKX`, `HOLDLOCK`. |
| Batching | Große Löschungen in Portionen (z. B. `TOP (N)`-Schleife) zur Log-/Blocking-Kontrolle. |
| Kaskadierende Löschung | `FOREIGN KEY … ON DELETE CASCADE` löscht abhängige Zeilen automatisch. |
| Trigger | `AFTER DELETE`/`INSTEAD OF DELETE` reagieren auf Löschvorgänge; `deleted` enthält die betroffenen Zeilen. |
| Temporal/CDC/CT | Temporal: „aktuelle“ Zeilen wandern in Historie; CDC/Change Tracking protokollieren Löschungen. |
| `TRUNCATE TABLE` | Schnell, minimal geloggt, **ohne** `WHERE`; setzt Identity zurück; andere Regeln/Einschränkungen (kein Trigger, FK-Einschränkungen beachten). |
| Anti-Join-Löschung | Muster wie `DELETE t FROM t LEFT JOIN … WHERE … IS NULL` oder `DELETE t WHERE EXISTS/NOT EXISTS (…)`. |

---

## 2 | Struktur

### 2.1 | Grundlagen & Syntax
> **Kurzbeschreibung:** Minimale `DELETE`-Syntax, sichere Filterung, Pseudo-Tabelle `deleted`.

- 📓 **Notebook:**  
  [`08_01_delete_grundlagen.ipynb`](08_01_delete_grundlagen.ipynb)

- 🎥 **YouTube:**  
  - [SQL Server DELETE Statement – Basics](https://www.youtube.com/results?search_query=sql+server+delete+statement)  

- 📘 **Docs:**  
  - [DELETE (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/statements/delete-transact-sql)

---

### 2.2 | `DELETE … FROM` (Join-Delete)
> **Kurzbeschreibung:** Löschen anhand einer zweiten Quelle (Join/CTE) – Duplikate und Eindeutigkeit korrekt behandeln.

- 📓 **Notebook:**  
  [`08_02_delete_from_join.ipynb`](08_02_delete_from_join.ipynb)

- 🎥 **YouTube:**  
  - [DELETE with JOIN – Beispiele](https://www.youtube.com/results?search_query=sql+server+delete+with+join)

- 📘 **Docs:**  
  - [`DELETE` – Join-Beispiele](https://learn.microsoft.com/en-us/sql/t-sql/statements/delete-transact-sql#using-from)  
  - [FROM + JOIN (Grundlagen)](https://learn.microsoft.com/en-us/sql/t-sql/queries/from-transact-sql)

---

### 2.3 | Doppelte Zeilen löschen (CTE + `ROW_NUMBER`)
> **Kurzbeschreibung:** Duplikate per Window-Funktion markieren und gezielt entfernen.

- 📓 **Notebook:**  
  [`08_03_delete_duplicates_row_number.ipynb`](08_03_delete_duplicates_row_number.ipynb)

- 🎥 **YouTube:**  
  - [Delete Duplicates with ROW_NUMBER](https://www.youtube.com/results?search_query=sql+server+delete+duplicates+row_number)

- 📘 **Docs:**  
  - [`ROW_NUMBER`](https://learn.microsoft.com/en-us/sql/t-sql/functions/row-number-transact-sql)  
  - [CTE (`WITH`)](https://learn.microsoft.com/en-us/sql/t-sql/queries/with-common-table-expression-transact-sql)

---

### 2.4 | Transaktionen, Fehlerbehandlung & `XACT_ABORT`
> **Kurzbeschreibung:** Sauberes Rollback, Fehler signalisieren, Teilfehler vermeiden.

- 📓 **Notebook:**  
  [`08_04_transaktionen_try_catch_delete.ipynb`](08_04_transaktionen_try_catch_delete.ipynb)

- 🎥 **YouTube:**  
  - [TRY…CATCH & THROW für DML](https://www.youtube.com/results?search_query=sql+server+try+catch+throw)

- 📘 **Docs:**  
  - [`TRY…CATCH`](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/try-catch-transact-sql)  
  - [`SET XACT_ABORT`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-xact-abort-transact-sql)

---

### 2.5 | Isolation & Sperren in der Praxis
> **Kurzbeschreibung:** Deadlocks vermeiden, `READPAST` gezielt einsetzen, Lock Escalation verstehen.

- 📓 **Notebook:**  
  [`08_05_isolation_locks_delete.ipynb`](08_05_isolation_locks_delete.ipynb)

- 🎥 **YouTube:**  
  - [Transaction Isolation Levels – erklärt](https://www.youtube.com/results?search_query=sql+server+isolation+levels)

- 📘 **Docs:**  
  - [`SET TRANSACTION ISOLATION LEVEL`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-transaction-isolation-level-transact-sql)  
  - [Table Hints (`READPAST`, `ROWLOCK`, `HOLDLOCK` …)](https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-table)

---

### 2.6 | Batching & „Ordered Deletes“
> **Kurzbeschreibung:** Große Löschungen in Häppchen (`TOP (N)`-Schleife); deterministische Reihenfolge via Join auf eine geordnete Teilmenge.

- 📓 **Notebook:**  
  [`08_06_batching_ordered_deletes.ipynb`](08_06_batching_ordered_deletes.ipynb)

- 🎥 **YouTube:**  
  - [Batch Deletes – Patterns](https://www.youtube.com/results?search_query=sql+server+batch+delete+top)

- 📘 **Docs/Blog:**  
  - [`TOP` in DML](https://learn.microsoft.com/en-us/sql/t-sql/queries/top-transact-sql)  
  - [SQLPerformance – Batching Techniques](https://www.sqlperformance.com/2015/04/t-sql-queries/batching-techniques)

---

### 2.7 | `OUTPUT` für Auditing/ETL
> **Kurzbeschreibung:** Gelöschte Zeilen in eine Audit-/Staging-Tabelle schreiben.

- 📓 **Notebook:**  
  [`08_07_output_deleted_audit.ipynb`](08_07_output_deleted_audit.ipynb)

- 🎥 **YouTube:**  
  - [OUTPUT Clause – Praxis](https://www.youtube.com/results?search_query=sql+server+output+clause)

- 📘 **Docs:**  
  - [`OUTPUT` (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/queries/output-clause-transact-sql)

---

### 2.8 | Referentielle Integrität & Trigger
> **Kurzbeschreibung:** `ON DELETE CASCADE/SET NULL` planen; Auswirkungen von `AFTER/INSTEAD OF DELETE`-Triggern.

- 📓 **Notebook:**  
  [`08_08_fk_cascade_trigger.ipynb`](08_08_fk_cascade_trigger.ipynb)

- 🎥 **YouTube:**  
  - [Foreign Keys & Cascades](https://www.youtube.com/results?search_query=sql+server+foreign+key+on+delete+cascade)

- 📘 **Docs:**  
  - [FOREIGN KEY – Referenz & Aktionen](https://learn.microsoft.com/en-us/sql/relational-databases/tables/create-foreign-key-relationships)  
  - [DML-Trigger](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-trigger-transact-sql)

---

### 2.9 | Soft Delete & Sichtbarkeit (RLS, Filter)
> **Kurzbeschreibung:** „Soft Delete“ (z. B. `IsDeleted=1`) vs. hartes Löschen; gefilterte Indizes, RLS-Interaktion.

- 📓 **Notebook:**  
  [`08_09_soft_delete_und_rls.ipynb`](08_09_soft_delete_und_rls.ipynb)

- 🎥 **YouTube:**  
  - [Soft Delete Patterns](https://www.youtube.com/results?search_query=sql+server+soft+delete)

- 📘 **Docs:**  
  - [Row-Level Security (RLS)](https://learn.microsoft.com/en-us/sql/relational-databases/security/row-level-security)  
  - [Indexes on Filtered Data](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/create-filtered-indexes)

---

### 2.10 | Temporal, CDC & Change Tracking
> **Kurzbeschreibung:** Wie `DELETE` in systemversionierten Tabellen, CDC und Change Tracking protokolliert erscheint.

- 📓 **Notebook:**  
  [`08_10_temporal_cdc_ct_delete.ipynb`](08_10_temporal_cdc_ct_delete.ipynb)

- 🎥 **YouTube:**  
  - [Temporal Tables – Löschverhalten](https://www.youtube.com/results?search_query=sql+server+temporal+tables+delete)

- 📘 **Docs:**  
  - [Temporal Tables – Verhalten bei DML](https://learn.microsoft.com/en-us/sql/relational-databases/tables/temporal-table-considerations)  
  - [Change Data Capture (CDC)](https://learn.microsoft.com/en-us/sql/relational-databases/track-changes/about-change-data-capture-sql-server)  
  - [Change Tracking](https://learn.microsoft.com/en-us/sql/relational-databases/track-changes/about-change-tracking-sql-server)

---

### 2.11 | Partitionierte & großvolumige Löschungen
> **Kurzbeschreibung:** Bereichsweise löschen mit Partition Elimination; Partition **switch-out + TRUNCATE** als schnelles Muster.

- 📓 **Notebook:**  
  [`08_11_partitionierte_deletes.ipynb`](08_11_partitionierte_deletes.ipynb)

- 🎥 **YouTube:**  
  - [Partition Switching – Pattern](https://www.youtube.com/results?search_query=sql+server+partition+switch+truncate)

- 📘 **Docs:**  
  - [Partitioned Tables & Indexes](https://learn.microsoft.com/en-us/sql/relational-databases/partitions/partitioned-tables-and-indexes)  
  - [Switch Partitions](https://learn.microsoft.com/en-us/sql/relational-databases/partitions/switch-partitions)

---

### 2.12 | `TRUNCATE TABLE` vs. `DELETE`
> **Kurzbeschreibung:** Unterschiede bei Logging, Einschränkungen, Identity-Reset, Triggern und FK-Beziehungen.

- 📓 **Notebook:**  
  [`08_12_truncate_vs_delete.ipynb`](08_12_truncate_vs_delete.ipynb)

- 🎥 **YouTube:**  
  - [TRUNCATE vs DELETE – Vergleich](https://www.youtube.com/results?search_query=sql+server+truncate+vs+delete)

- 📘 **Docs:**  
  - [`TRUNCATE TABLE`](https://learn.microsoft.com/en-us/sql/t-sql/statements/truncate-table-transact-sql)  
  - [`DBCC CHECKIDENT` (Identity-Seed prüfen)](https://learn.microsoft.com/en-us/sql/t-sql/database-console-commands/dbcc-checkident-transact-sql)

---

### 2.13 | `MERGE` & synchronisierendes Löschen
> **Kurzbeschreibung:** „Not matched by source then DELETE“ – sauber, aber bekannte `MERGE`-Fallstricke beachten.

- 📓 **Notebook:**  
  [`08_13_merge_delete_patterns.ipynb`](08_13_merge_delete_patterns.ipynb)

- 🎥 **YouTube:**  
  - [MERGE – Should You Use It?](https://www.youtube.com/results?search_query=sql+server+merge+problems)

- 📘 **Docs/Blog:**  
  - [`MERGE` (Referenz)](https://learn.microsoft.com/en-us/sql/t-sql/statements/merge-transact-sql)  
  - [Aaron Bertrand – Problems with MERGE](https://sqlblog.org/2011/06/20/merge-what-was-i-thinking)

---

### 2.14 | Qualität, Betrieb & Überwachung
> **Kurzbeschreibung:** `@@ROWCOUNT`, Warte-Mechanismen, Protokoll-/Fragmentationsfolgen, DMVs/Extended Events.

- 📓 **Notebook:**  
  [`08_14_quality_ops_delete.ipynb`](08_14_quality_ops_delete.ipynb)

- 🎥 **YouTube:**  
  - [Monitoring DML & Blocking](https://www.youtube.com/results?search_query=sql+server+monitoring+blocking+dmv)

- 📘 **Docs:**  
  - [`@@ROWCOUNT`](https://learn.microsoft.com/en-us/sql/t-sql/functions/rowcount-transact-sql)  
  - [DMVs – Sperren/Abfragen](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/system-dynamic-management-views)

---

### 2.15 | Anti-Patterns & Sicherheit
> **Kurzbeschreibung:** `DELETE` ohne `WHERE`, ungeprüfte Join-Löschungen, `NOT IN` + `NULL`, Funktionen auf Spalten, fehlende Rechte/RLS.

- 📓 **Notebook:**  
  [`08_15_delete_anti_patterns.ipynb`](08_15_delete_anti_patterns.ipynb)

- 🎥 **YouTube:**  
  - [Common T-SQL Mistakes – DELETE](https://www.youtube.com/results?search_query=sql+server+delete+mistakes)

- 📘 **Docs/Blog:**  
  - [SARGability – Grundlagen](https://www.brentozar.com/archive/2018/02/sargable-queries/)  
  - [Permissions: `DELETE`/`REFERENCES`/`ALTER`](https://learn.microsoft.com/en-us/sql/relational-databases/security/permissions-database-engine)

---

### 2.16 | Alle Tabellen einer Datenbank leeren (`TRUNCATE` vs. `DELETE`)
> **Kurzbeschreibung:** Zwei Produktionsskripte leeren alle Benutzertabellen einer Datenbank – eines via `TRUNCATE TABLE` mit FK-Deaktivierung, eines via `DELETE FROM` mit topologischer Sortierung des FK-Graphen.

Beide Skripte teilen denselben Sicherheitsrahmen (`@PreviewOnly = 1` als Default, explizites Approval-Token) und die gleichen Filteroptionen (`@SchemaFilter`, `@TableList`). Die grundlegenden Unterschiede:

| Merkmal | `TRUNCATE`-Variante | `DELETE`-Variante |
|---|---|---|
| Logging | Minimal (Seitendeallokation) | Vollständig (jede Zeile) |
| IDENTITY-Zähler | Wird zurückgesetzt | Bleibt erhalten |
| DML-Trigger | Werden **nicht** ausgelöst | Werden ausgelöst |
| FK-Strategie | Alle FKs deaktivieren → leeren → reaktivieren | Topologische Sortierung (Kind vor Elternteil) |
| Rollback | Nur innerhalb des Skripts möglich | Vollständig über `@UseTransaction = 1` |
| Zirkuläre FKs | Kein Problem | Landen am Ende, können Fehler auslösen |
| Approval-Token | `TRUNCATE-ALL-CONFIRMED` | `DELETE-ALL-CONFIRMED` |

- 📄 **Scripts:**
  - [`SQLScripts/TruncateAllTablesInSchema.sql`](SQLScripts/TruncateAllTablesInSchema.sql) – `TRUNCATE` mit FK-Deaktivierung
  - [`SQLScripts/DeleteAllTablesInSchema.sql`](SQLScripts/DeleteAllTablesInSchema.sql) – `DELETE FROM` mit FK-Graph-Sortierung

- 📘 **Docs:**
  - [`TRUNCATE TABLE`](https://learn.microsoft.com/en-us/sql/t-sql/statements/truncate-table-transact-sql)
  - [`ALTER TABLE … NOCHECK CONSTRAINT`](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-table-transact-sql)
  - [`sys.foreign_keys`](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-foreign-keys-transact-sql)
  - [`sp_executesql`](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-executesql-transact-sql)

---

## 3 | Weiterführende Informationen

- 📘 Microsoft Learn: [DELETE (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/statements/delete-transact-sql)  
- 📘 Microsoft Learn: [`TRUNCATE TABLE`](https://learn.microsoft.com/en-us/sql/t-sql/statements/truncate-table-transact-sql)  
- 📘 Microsoft Learn: [`OUTPUT`-Klausel](https://learn.microsoft.com/en-us/sql/t-sql/queries/output-clause-transact-sql)  
- 📘 Microsoft Learn: [Table Hints – Referenz (`READPAST`, `ROWLOCK`, …)](https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-table)  
- 📘 Microsoft Learn: [FOREIGN KEY – `ON DELETE`-Optionen](https://learn.microsoft.com/en-us/sql/relational-databases/tables/create-foreign-key-relationships)  
- 📘 Microsoft Learn: [Temporal Tables – DML-Verhalten](https://learn.microsoft.com/en-us/sql/relational-databases/tables/temporal-table-considerations)  
- 📘 Microsoft Learn: [CDC & Change Tracking – Überblick](https://learn.microsoft.com/en-us/sql/relational-databases/track-changes/track-data-changes-sql-server)  
- 📘 Microsoft Learn: [`MERGE` – Referenz & Beispiele](https://learn.microsoft.com/en-us/sql/t-sql/statements/merge-transact-sql)  
- 📘 Microsoft Learn: [Isolation Levels (Snapshot/RCSI)](https://learn.microsoft.com/en-us/sql/relational-databases/tempdb/row-versioning-isolation-levels)  
- 📝 Blog (SQLPerformance): [Batching Large Deletes](https://www.sqlperformance.com/2015/04/t-sql-queries/batching-techniques)  
- 📝 Blog (Brent Ozar): [SARGable Queries – Primer](https://www.brentozar.com/archive/2018/02/sargable-queries/)  
- 📝 Blog (Itzik Ben-Gan): [Deleting Duplicates with Window Functions](https://tsql.solidq.com/)  
- 🎥 YouTube: [DELETE with JOIN – Tutorial](https://www.youtube.com/results?search_query=sql+server+delete+with+join)  
- 🎥 YouTube: [TRUNCATE vs DELETE – Performance](https://www.youtube.com/results?search_query=sql+server+truncate+vs+delete)  
