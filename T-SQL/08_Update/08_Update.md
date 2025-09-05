# T-SQL UPDATE – Übersicht

## 1 | Begriffsdefinition

| SQL-Term | Beschreibung |
|---|---|
| `UPDATE` | Ändert bestehende Zeilen in einer Tabelle oder updatable View; kein DDL (keine Schemaänderung). |
| Zielobjekt | Tabelle oder updatable View, deren Zeilen aktualisiert werden. |
| `SET`-Liste | Weist einer oder mehreren Spalten neue Werte oder Ausdrücke zu. |
| `WHERE`-Klausel | Bestimmt, **welche** Zeilen geändert werden; ohne `WHERE` wird alles aktualisiert. |
| `UPDATE … FROM` | T-SQL-Erweiterung: Join-basierte Updates mit externer Quelle (Tabelle/CTE/abgeleitete Tabelle). |
| `OUTPUT`-Klausel | Liefert geänderte Werte/Zeilen über Pseudo-Tabellen `inserted` (nachher) & `deleted` (vorher). |
| `TOP (N)` im `UPDATE` | Begrenzt die Anzahl aktualisierter Zeilen; **keine** definierte Reihenfolge ohne vorgelagerte Sortierung. |
| Transaktion | Atomare Einheit (`BEGIN TRAN`/`COMMIT`/`ROLLBACK`); mehrstufige Updates logisch bündeln. |
| Fehlerbehandlung | `TRY…CATCH`, `THROW`/`RAISERROR`, `XACT_STATE()`; optional `SET XACT_ABORT ON`. |
| Isolation Level | Sichtbarkeit/Konsistenz (`READ COMMITTED`, `SNAPSHOT`, `SERIALIZABLE` …). |
| Sperren (Locks) | `UPDLOCK`, `HOLDLOCK`, `ROWLOCK`, `PAGLOCK`, `TABLOCKX` etc.; Konkurrenz- & Deadlock-Verhalten. |
| SARGability | Filter/Join-Prädikate so formulieren, dass Indizes genutzt werden (keine Funktionen auf Spalten). |
| Batching | Updates in Portionen (`TOP (N)`-Schleifen) zur Steuerung von Log, Latches, Blocking. |
| Idempotenz | Wiederholtes Ausführen führt zum gleichen Endzustand (z. B. nur ändern, wenn Unterschiede bestehen). |
| Optimistic Concurrency | Konflikte via `rowversion`/Vergleich alter Werte erkennen; Update nur bei unverändertem Zustand. |
| `@@ROWCOUNT` | Anzahl betroffener Zeilen; zur Ergebnisprüfung/Qualitätssicherung. |
| Nebenwirkungen | Trigger, CDC, Temporal Tables, Replikation, Indizes/Statistiken – können zusätzliche Arbeit auslösen. |
| Einschränkungen | Bestimmte Spalten sind nicht änderbar (z. B. `rowversion` selbst, berechnete/persistierte je nach Definition). |

---

## 2 | Struktur

### 2.1 | Grundlagen & Syntax
> **Kurzbeschreibung:** Minimales `UPDATE`, `SET`-Ausdrücke, sicheres Filtern und typische Stolperfallen.

- 📓 **Notebook:**  
  [`08_01_grundlagen_und_syntax.ipynb`](08_01_grundlagen_und_syntax.ipynb)

- 🎥 **YouTube:**  
  - [SQL Server UPDATE Statement Tutorial](https://www.youtube.com/watch?v=fOAiM7bWcXc)  
  - [UPDATE Basics (MS Learn Community)](https://www.youtube.com/results?search_query=sql+server+update+basics)

- 📘 **Docs:**  
  - [UPDATE (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/queries/update-transact-sql)  
  - [Datentypkonvertierung: `CAST`/`CONVERT`](https://learn.microsoft.com/en-us/sql/t-sql/functions/cast-and-convert-transact-sql)

---

### 2.2 | `UPDATE … FROM` (Join-Update)
> **Kurzbeschreibung:** Werte aus einer Quelltabelle/CTE übernehmen; Eindeutigkeit und Duplikate korrekt behandeln.

- 📓 **Notebook:**  
  [`08_02_update_from_join.ipynb`](08_02_update_from_join.ipynb)

- 🎥 **YouTube:**  
  - [UPDATE with JOIN – Beispiele](https://www.youtube.com/results?search_query=sql+server+update+join)

- 📘 **Docs:**  
  - [UPDATE – `FROM`-Beispiele](https://learn.microsoft.com/en-us/sql/t-sql/queries/update-transact-sql#using-from)  
  - [JOINs (Überblick)](https://learn.microsoft.com/en-us/sql/relational-databases/performance/joins)

---

### 2.3 | UPDATE mit CTE
> **Kurzbeschreibung:** Ziel- oder Quellmenge per CTE vormodellieren; vereinfacht Window-Filter & komplexe Bedingungen.

- 📓 **Notebook:**  
  [`08_03_update_mit_cte.ipynb`](08_03_update_mit_cte.ipynb)

- 🎥 **YouTube:**  
  - [Common Table Expressions (CTE) – Crashkurs](https://www.youtube.com/results?search_query=sql+server+cte+tutorial)

- 📘 **Docs:**  
  - [CTE (`WITH`)](https://learn.microsoft.com/en-us/sql/t-sql/queries/with-common-table-expression-transact-sql)  
  - [Unterabfragen & abgeleitete Tabellen](https://learn.microsoft.com/en-us/sql/t-sql/queries/subqueries)

---

### 2.4 | Transaktionen, `TRY…CATCH`, `THROW`
> **Kurzbeschreibung:** Atomarität & sauberes Rollback; Fehler sicher signalisieren und Zwangs-Rollback mit `XACT_ABORT`.

- 📓 **Notebook:**  
  [`08_04_transaktionen_try_catch.ipynb`](08_04_transaktionen_try_catch.ipynb)

- 🎥 **YouTube:**  
  - [TRY…CATCH & THROW vs. RAISERROR](https://www.youtube.com/results?search_query=sql+server+try+catch+throw)

- 📘 **Docs:**  
  - [`TRY…CATCH`](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/try-catch-transact-sql)  
  - [`THROW` & `RAISERROR`](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/throw-transact-sql) / [RAISERROR](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/raiserror-transact-sql)  
  - [`SET XACT_ABORT`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-xact-abort-transact-sql)

---

### 2.5 | Isolation & Lock-Hinweise
> **Kurzbeschreibung:** Lesekonsistenz vs. Parallelität; passende Isolation wählen, Lock-Hints bewusst einsetzen.

- 📓 **Notebook:**  
  [`08_05_isolation_und_locks.ipynb`](08_05_isolation_und_locks.ipynb)

- 🎥 **YouTube:**  
  - [Transaction Isolation Levels – erklärt](https://www.youtube.com/watch?v=6I9b5V7AN4I)

- 📘 **Docs:**  
  - [`SET TRANSACTION ISOLATION LEVEL`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-transaction-isolation-level-transact-sql)  
  - [Table Hints (`UPDLOCK`, `HOLDLOCK`, …)](https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-table)  
  - [Snapshot-Isolation & RCSI](https://learn.microsoft.com/en-us/sql/relational-databases/tempdb/row-versioning-isolation-levels)

---

### 2.6 | Batching (`TOP`-Schleifen) & resumierbare Updates
> **Kurzbeschreibung:** Große Updates in handliche Portionen teilen; Logwachstum und Blocking minimieren;

- 📓 **Notebook:**  
  [`08_06_batching_topn.ipynb`](08_06_batching_topn.ipynb)
  
      2.6.1 UPDATE TOP(@N)–Loop (Minimalvariante)
      2.6.2 Deterministische Auswahl per CTE/Key-Liste
      2.6.3 Persistente Temp-Batchtabelle (#BatchDocs mit PK)
      2.6.4 Paging per Work-Flag (Processed-Spalte)
      2.6.5 Schlüsselbereiche/Ranges (BETWEEN-Min/Max)
      2.6.6 Parallelisierung mit READPAST (mehrere Worker)
      2.6.7 Throttling & Auto-Tuning der Batch-Size

- 🎥 **YouTube:**  
  - [Batch Processing Patterns](https://www.youtube.com/results?search_query=sql+server+batch+update+top)

- 📘 **Docs:**  
  - [`TOP` in DML (`UPDATE`/`DELETE`)](https://learn.microsoft.com/en-us/sql/t-sql/queries/top-transact-sql)  
  - [SQLPerformance – Batching Techniques](https://www.sqlperformance.com/2015/04/t-sql-queries/batching-techniques)

---

### 2.7 | `OUTPUT` & Auditing
> **Kurzbeschreibung:** Änderungen in eine Audit-/Delta-Tabelle schreiben; `inserted` vs. `deleted` richtig nutzen.

- 📓 **Notebook:**  
  [`08_07_output_und_auditing.ipynb`](08_07_output_und_auditing.ipynb)

- 🎥 **YouTube:**  
  - [OUTPUT Clause – Praxis](https://www.youtube.com/results?search_query=sql+server+output+clause)

- 📘 **Docs:**  
  - [`OUTPUT` (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/queries/output-clause-transact-sql)  
  - [DML-Trigger (INSTEAD OF/AFTER)](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-trigger-transact-sql)

---

### 2.8 | Idempotente Updates
> **Kurzbeschreibung:** Nur schreiben, wenn sich Werte wirklich ändern; unnötige Log-I/O und Trigger vermeiden.

- 📓 **Notebook:**  
  [`08_08_idempotente_updates.ipynb`](08_08_idempotente_updates.ipynb)

- 🎥 **YouTube:**  
  - [Idempotent DML Patterns](https://www.youtube.com/results?search_query=idempotent+sql+update)

- 📘 **Docs/Blog:**  
  - [Simple Talk – Idempotency in SQL](https://www.red-gate.com/simple-talk/databases/sql-server/t-sql-programming-sql-server/idempotency-in-sql/)  
  - [Erik Darling – Avoiding Useless Updates](https://www.erikdarlingdata.com/)

---

### 2.9 | Optimistic Concurrency (`rowversion`)
> **Kurzbeschreibung:** Parallelkonflikte erkennen: Vergleich alter Werte oder `rowversion`-Spalte; sauberes Fehlersignal.

- 📓 **Notebook:**  
  [`08_09_rowversion_concurrency.ipynb`](08_09_rowversion_concurrency.ipynb)

- 🎥 **YouTube:**  
  - [Optimistic Concurrency in SQL Server](https://www.youtube.com/results?search_query=sql+server+optimistic+concurrency+rowversion)

- 📘 **Docs:**  
  - [`rowversion` Datentyp](https://learn.microsoft.com/en-us/sql/t-sql/data-types/rowversion-transact-sql)  
  - [Optimistic Concurrency – Muster](https://learn.microsoft.com/en-us/ef/core/saving/concurrency?tabs=data-annotations#handling-concurrency) *(Konzeptuell nützlich)*

---

### 2.10 | Performance & SARGability
> **Kurzbeschreibung:** Richtig filtern/joinen, Statistiken aktuell halten, Pläne stabilisieren.

- 📓 **Notebook:**  
  [`08_10_performance_sargability.ipynb`](08_10_performance_sargability.ipynb)

- 🎥 **YouTube:**  
  - [SARGable Predicates erklärt](https://www.youtube.com/watch?v=Rkqbj82XVsI)

- 📘 **Docs/Blog:**  
  - [Index Design Guide](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-index-design-guide)  
  - [Paul White – Residual Predicates](https://www.sql.kiwi/)  

---

### 2.11 | Window-Funktionen im UPDATE
> **Kurzbeschreibung:** Mit `ROW_NUMBER()` & Co. Zeilen markieren/auswählen und anschließend gezielt aktualisieren.

- 📓 **Notebook:**  
  [`08_11_update_mit_windowfunktionen.ipynb`](08_11_update_mit_windowfunktionen.ipynb)

- 🎥 **YouTube:**  
  - [Window Functions Deep Dive](https://www.youtube.com/results?search_query=itzik+ben+gan+window+functions)

- 📘 **Docs:**  
  - [`OVER`-Klausel & Ranking](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-over-clause-transact-sql)  
  - [`ROW_NUMBER`](https://learn.microsoft.com/en-us/sql/t-sql/functions/row_number-transact-sql)

---

### 2.12 | Partitionierte Updates
> **Kurzbeschreibung:** Bereichsweise aktualisieren; Partition Elimination nutzen und Schlüsselupdates (Partition hops) vermeiden.

- 📓 **Notebook:**  
  [`08_12_partitionierte_updates.ipynb`](08_12_partitionierte_updates.ipynb)

- 🎥 **YouTube:**  
  - [Partitioned Tables – Praxis](https://www.youtube.com/results?search_query=sql+server+partitioned+tables+update)

- 📘 **Docs:**  
  - [Partitioned Tables and Indexes](https://learn.microsoft.com/en-us/sql/relational-databases/partitions/partitioned-tables-and-indexes)  
  - [Partition Switching (Advanced)](https://learn.microsoft.com/en-us/sql/relational-databases/partitions/switch-partitions)

---

### 2.13 | Upsert ohne `MERGE` (2-Phasen-Muster)
> **Kurzbeschreibung:** Erst `UPDATE` vorhandener Schlüssel, dann `INSERT` fehlender – robust & transparent.

- 📓 **Notebook:**  
  [`08_13_upsert_ohne_merge.ipynb`](08_13_upsert_ohne_merge.ipynb)

- 🎥 **YouTube:**  
  - [UPSERT Patterns (ohne MERGE)](https://www.youtube.com/results?search_query=sql+server+upsert+without+merge)

- 📘 **Docs/Blog:**  
  - [`MERGE` (Referenz)](https://learn.microsoft.com/en-us/sql/t-sql/statements/merge-transact-sql)  
  - [Aaron Bertrand – Problems with MERGE](https://sqlblog.org/2011/06/20/merge-what-was-i-thinking)

---

### 2.14 | Temporal/CDC-Awareness
> **Kurzbeschreibung:** Auswirkungen von `UPDATE` auf Systemversionierung, CDC & Change Tracking verstehen/prüfen.

- 📓 **Notebook:**  
  [`08_14_temporal_cdc_awareness.ipynb`](08_14_temporal_cdc_awareness.ipynb)

- 🎥 **YouTube:**  
  - [Temporal Tables – Überblick](https://www.youtube.com/results?search_query=sql+server+temporal+tables)

- 📘 **Docs:**  
  - [System-Versioned Temporal Tables](https://learn.microsoft.com/en-us/sql/relational-databases/tables/temporal-tables)  
  - [Change Data Capture (CDC)](https://learn.microsoft.com/en-us/sql/relational-databases/track-changes/about-change-data-capture-sql-server)  
  - [Change Tracking](https://learn.microsoft.com/en-us/sql/relational-databases/track-changes/about-change-tracking-sql-server)

---

### 2.15 | Qualität & Betrieb
> **Kurzbeschreibung:** Ergebnissicherung mit `@@ROWCOUNT`, Monitoring (DMVs), Logging-Konventionen.

- 📓 **Notebook:**  
  [`08_15_quality_operations.ipynb`](08_15_quality_operations.ipynb)

- 🎥 **YouTube:**  
  - [Error Handling & Logging Patterns](https://www.youtube.com/results?search_query=sql+server+error+handling+logging)

- 📘 **Docs:**  
  - [`@@ROWCOUNT`](https://learn.microsoft.com/en-us/sql/t-sql/functions/rowcount-transact-sql)  
  - [DMVs: Sperren & Ausführungsstatistiken](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/system-dynamic-management-views)

---

### 2.16 | Anti-Patterns & Sicherheit
> **Kurzbeschreibung:** `UPDATE` ohne `WHERE`, mehrdeutige `FROM`-Joins, Funktionen auf Spalten, blindes Hinting; Rechte & RLS beachten.

- 📓 **Notebook:**  
  [`08_16_anti_patterns.ipynb`](08_16_anti_patterns.ipynb)

- 🎥 **YouTube:**  
  - [SQL Server Anti-Patterns](https://www.youtube.com/results?search_query=sql+server+anti+patterns)

- 📘 **Docs/Blog:**  
  - [Row-Level Security (RLS)](https://learn.microsoft.com/en-us/sql/relational-databases/security/row-level-security)  
  - [Brent Ozar – Common UPDATE Mistakes](https://www.brentozar.com/archive/2019/06/sql-update-mistakes/)

---

## 3 | Weiterführende Informationen

- 📘 Microsoft Learn: [UPDATE (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/queries/update-transact-sql)  
- 📘 Microsoft Learn: [`OUTPUT`-Klausel](https://learn.microsoft.com/en-us/sql/t-sql/queries/output-clause-transact-sql)  
- 📘 Microsoft Learn: [`TOP` in DML](https://learn.microsoft.com/en-us/sql/t-sql/queries/top-transact-sql)  
- 📘 Microsoft Learn: [`TRY…CATCH`, `THROW`, `XACT_STATE()`](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/try-catch-transact-sql)  
- 📘 Microsoft Learn: [`SET XACT_ABORT`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-xact-abort-transact-sql)  
- 📘 Microsoft Learn: [Isolation Levels & Row Versioning (RCSI/Snapshot)](https://learn.microsoft.com/en-us/sql/relational-databases/tempdb/row-versioning-isolation-levels)  
- 📘 Microsoft Learn: [Table Hints – Referenz (`UPDLOCK`, …)](https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-table)  
- 📘 Microsoft Learn: [Temporal Tables – DML-Verhalten](https://learn.microsoft.com/en-us/sql/relational-databases/tables/temporal-table-considerations)  
- 📘 Microsoft Learn: [Change Data Capture / Change Tracking](https://learn.microsoft.com/en-us/sql/relational-databases/track-changes/track-data-changes-sql-server)  
- 📘 Microsoft Learn: [DML-Trigger (AFTER/INSTEAD OF)](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-trigger-transact-sql)  
- 📝 Blog (Aaron Bertrand): [Problems with MERGE](https://sqlblog.org/2011/06/20/merge-what-was-i-thinking)  
- 📝 Blog (Paul White): [Understanding `UPDATE … FROM`](https://www.sql.kiwi/)  
- 📝 Blog (Itzik Ben-Gan): [Set-based Patterns & Window Functions](https://tsql.solidq.com/)  
- 📝 Blog (SQLSkills): [XACT_ABORT & Error Handling](https://www.sqlskills.com/blogs/erin/)  
- 📝 Blog (Brent Ozar): [SARGability & Update-Fallstricke](https://www.brentozar.com/)  
- 🎥 YouTube (Microsoft Data Exposed): [Snapshot Isolation & RCSI](https://www.youtube.com/results?search_query=data+exposed+snapshot+isolation)  
- 🎥 YouTube (Itzik Ben-Gan): [T-SQL Tips – Windowing & Updates](https://www.youtube.com/results?search_query=itzik+ben+gan+t-sql)  

