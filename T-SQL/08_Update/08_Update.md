# Update mit T-SQL – Übersicht

## 1 | Begriffsdefinition

| SQL-Term            | Update |
|---                  |---|
| **Was macht es**    | Ändert Dateninhalte; keine Schemaänderung. |
| **SQL-Typ**         | DML (Data Manipulation Language) |
| **Zieltabelle**     | Tabelle/Ansicht, deren Zeilen aktualisiert werden. |
| **WHERE-Klausel**   | Definiert, welche Zeilen geändert werden. |
| **JOIN-Quelle**     | Externe Quelle (Tabelle/Query) liefert Werte/Schlüssel. |
| **Transaktion**     | Atomarer Block (`BEGIN/COMMIT/ROLLBACK`). |
| **Isolation Level** | Parallelitäts-/Sichtbarkeitsregeln (z. B. `READ COMMITTED`, `SNAPSHOT`). |
| **Sperren (Locks)** | Konkurrenzkontrolle (ROW/PAGE/TABLE; z. B. `UPDLOCK`, `ROWLOCK`). |
| **Batching**        | Teilmengen-Updates (`TOP (N)`) zur Last-/Log-Steuerung. |
| **Idempotenz**      | Mehrfache Ausführung → gleicher Endzustand. |
| **OUTPUT-Clause**   | Liefert geänderte Zeilen/Werte (Auditing). |
| **Rowversion**      | Optimistic Concurrency via `rowversion/timestamp`. |

---

## 2 | Struktur

### 2.1 | Grundlagen & Syntax
Kurzüberblick zu einfachem `UPDATE`, SET-Liste, sicherer WHERE-Filter.  
* _Notebook_: [`08_01_grundlagen_und_syntax.ipynb`](./08_01_grundlagen_und_syntax.ipynb)  
* _Youtube_: [SQL Server UPDATE Tutorial](https://www.youtube.com/watch?v=fOAiM7bWcXc)  
* _Webseite_: [Microsoft Docs: UPDATE](https://learn.microsoft.com/de-de/sql/t-sql/queries/update-transact-sql)

### 2.2 | UPDATE ... FROM (Join-Update)
Join-basiertes UPDATE zwischen Ziel- und Quellmenge; Eindeutigkeit sicherstellen.  
* _Notebook_: [`08_02_update_from_join.ipynb`](./08_02_update_from_join.ipynb)  
* _Youtube_: [SQL Update Join Example](https://www.youtube.com/watch?v=3t5yBzS2kXs)  
* _Webseite_: [SQLShack: UPDATE with JOIN](https://www.sqlshack.com/sql-server-update-join/)

### 2.3 | UPDATE mit CTE
CTE zur Vorstrukturierung/Lesbarkeit der Zielmenge verwenden.  
* _Notebook_: [`08_03_update_mit_cte.ipynb`](./08_03_update_mit_cte.ipynb)  
* _Youtube_: [SQL CTE Tutorial](https://www.youtube.com/watch?v=2ymzF4iVj2E)  
* _Webseite_: [MS Docs: Common Table Expressions](https://learn.microsoft.com/de-de/sql/t-sql/queries/with-common-table-expression-transact-sql)

### 2.4 | Transaktionen & TRY/CATCH
Atomarität, Fehlerbehandlung, Rollback-Strategien.  
* _Notebook_: [`08_04_transaktionen_try_catch.ipynb`](./08_04_transaktionen_try_catch.ipynb)  
* _Youtube_: [SQL Server Transactions & Error Handling](https://www.youtube.com/watch?v=E0y6N5hWc3Q)  
* _Webseite_: [MS Docs: TRY...CATCH](https://learn.microsoft.com/de-de/sql/t-sql/language-elements/try-catch-transact-sql)

### 2.5 | Isolation & Lock-Hinweise
Auswirkungen von `SNAPSHOT`, `UPDLOCK`, `ROWLOCK` auf Parallelität und Sperren.  
* _Notebook_: [`08_05_isolation_und_locks.ipynb`](./08_05_isolation_und_locks.ipynb)  
* _Youtube_: [SQL Server Isolation Levels Explained](https://www.youtube.com/watch?v=6I9b5V7AN4I)  
* _Webseite_: [MS Docs: Isolation Level](https://learn.microsoft.com/de-de/sql/t-sql/statements/set-transaction-isolation-level-transact-sql)

### 2.6 | Batching (TOP-N-Loops)
Durchsatz steuern, Log-Wachstum und Blockaden reduzieren.  
* _Notebook_: [`08_06_batching_topn.ipynb`](./08_06_batching_topn.ipynb)  
* _Youtube_: [Batch Processing in SQL Server](https://www.youtube.com/watch?v=5w6vDnb5V0k)  
* _Webseite_: [SQLPerformance: Batching Techniques](https://www.sqlperformance.com/2015/04/t-sql-queries/batching-techniques)

### 2.7 | OUTPUT & Auditing
Änderungen per `OUTPUT` erfassen; Deltas/Audits speichern.  
* _Notebook_: [`08_07_output_und_auditing.ipynb`](./08_07_output_und_auditing.ipynb)  
* _Youtube_: [SQL Server OUTPUT Clause](https://www.youtube.com/watch?v=hWzdy1yAZIk)  
* _Webseite_: [MS Docs: OUTPUT-Klausel](https://learn.microsoft.com/de-de/sql/t-sql/queries/output-clause-transact-sql)

### 2.8 | Idempotente Updates
Nur ändern, wenn Werte differieren; unnötige Writes vermeiden.  
* _Notebook_: [`08_08_idempotente_updates.ipynb`](./08_08_idempotente_updates.ipynb)  
* _Youtube_: [Best Practices for SQL Updates](https://www.youtube.com/watch?v=mr0QvV6nQz4)  
* _Webseite_: [Use Idempotency in SQL Updates (Blog)](https://www.red-gate.com/simple-talk/databases/sql-server/t-sql-programming-sql-server/idempotency-in-sql/)

### 2.9 | Optimistic Concurrency (rowversion)
Parallelkonflikte via `rowversion` erkennen und behandeln.  
* _Notebook_: [`08_09_rowversion_concurrency.ipynb`](./08_09_rowversion_concurrency.ipynb)  
* _Youtube_: [Rowversion in SQL Server](https://www.youtube.com/watch?v=2tYc0Y5klCc)  
* _Webseite_: [MS Docs: rowversion](https://learn.microsoft.com/de-de/sql/t-sql/data-types/rowversion-transact-sql)

### 2.10 | Performance & SARGability
Indizes, Statistiken, SARGable-Filter, plan-sensitive Optionen.  
* _Notebook_: [`08_10_performance_sargability.ipynb`](./08_10_performance_sargability.ipynb)  
* _Youtube_: [SARGability Explained](https://www.youtube.com/watch?v=Rkqbj82XVsI)  
* _Webseite_: [Brent Ozar: SARGability](https://www.brentozar.com/archive/2018/02/sargable-queries/)

### 2.11 | Window-Funktionen im UPDATE
Flags/Rankings mit `ROW_NUMBER()`/`PARTITION BY` setzen.  
* _Notebook_: [`08_11_update_mit_windowfunktionen.ipynb`](./08_11_update_mit_windowfunktionen.ipynb)  
* _Youtube_: [SQL Server Window Functions](https://www.youtube.com/watch?v=Y4O2h4iJjKQ)  
* _Webseite_: [MS Docs: Window Functions](https://learn.microsoft.com/de-de/sql/t-sql/queries/select-over-clause-transact-sql)

### 2.12 | Partitionierte Updates
Große Tabellen segmentiert aktualisieren, Hotspots vermeiden.  
* _Notebook_: [`08_12_partitionierte_updates.ipynb`](./08_12_partitionierte_updates.ipynb)  
* _Youtube_: [Partitioning in SQL Server](https://www.youtube.com/watch?v=89oC6Qd_2zA)  
* _Webseite_: [MS Docs: Partitioned Tables and Indexes](https://learn.microsoft.com/de-de/sql/relational-databases/partitions/partitioned-tables-and-indexes)

### 2.13 | Upsert ohne MERGE
Robustes Zweistufenmuster: UPDATE vorhandener, INSERT neuer Schlüssel.  
* _Notebook_: [`08_13_upsert_ohne_merge.ipynb`](./08_13_upsert_ohne_merge.ipynb)  
* _Youtube_: [SQL Server UPSERT Pattern](https://www.youtube.com/watch?v=gx1RkR6lFME)  
* _Webseite_: [Aaron Bertrand: Problems with MERGE](https://sqlblog.org/2011/06/20/merge-what-was-i-thinking)

### 2.14 | Temporal/CDC-Awareness
Nebenwirkungen auf Historien-/CT-Tabellen verstehen und steuern.  
* _Notebook_: [`08_14_temporal_cdc_awareness.ipynb`](./08_14_temporal_cdc_awareness.ipynb)  
* _Youtube_: [Temporal Tables in SQL Server](https://www.youtube.com/watch?v=feUw4vL7i34)  
* _Webseite_: [MS Docs: Temporal Tables](https://learn.microsoft.com/de-de/sql/relational-databases/tables/temporal-tables)

### 2.15 | Qualität & Betrieb
`@@ROWCOUNT`, Vor/Nach-Zählung, Logging-Konventionen, Betriebssicherheit.  
* _Notebook_: [`08_15_quality_operations.ipynb`](./08_15_quality_operations.ipynb)  
* _Youtube_: [SQL Server Error Handling & Logging](https://www.youtube.com/watch?v=rrgvL4ONWAw)  
* _Webseite_: [MS Docs: @@ROWCOUNT](https://learn.microsoft.com/de-de/sql/t-sql/functions/rowcount-transact-sql)

### 2.16 | Anti-Patterns
UPDATE ohne WHERE, nicht-deterministische Joins, Funktions-Filter, blindes Lock-Hinting.  
* _Notebook_: [`08_16_anti_patterns.ipynb`](./08_16_anti_patterns.ipynb)  
* _Youtube_: [SQL Server Anti-Patterns](https://www.youtube.com/watch?v=Yf2d4XKcX6o)  
* _Webseite_: [Brent Ozar: SQL Update Mistakes](https://www.brentozar.com/archive/2019/06/sql-update-mistakes/)

## 3 | Weiterführende Informationen

- [Microsoft Docs: UPDATE (Transact-SQL)](https://learn.microsoft.com/de-de/sql/t-sql/queries/update-transact-sql)
- [Microsoft Docs: OUTPUT-Klausel (Transact-SQL)](https://learn.microsoft.com/de-de/sql/t-sql/queries/output-clause-transact-sql)
- [Microsoft Docs: Transaktionen (SQL Server)](https://learn.microsoft.com/de-de/sql/t-sql/language-elements/transactions-transact-sql)
- [Microsoft Docs: SET TRANSACTION ISOLATION LEVEL](https://learn.microsoft.com/de-de/sql/t-sql/statements/set-transaction-isolation-level-transact-sql)
- [Microsoft Docs: Sperrhinweise (Table Hints)](https://learn.microsoft.com/de-de/sql/t-sql/queries/hints-transact-sql-table)
- [Microsoft Docs: Rowversion und Timestamp](https://learn.microsoft.com/de-de/sql/t-sql/data-types/rowversion-transact-sql)
- [SQLShack: Using UPDATE with JOIN in SQL Server](https://www.sqlshack.com/sql-server-update-join/)
- [SQLPerformance: Batching Techniques for Large Updates](https://www.sqlperformance.com/2015/04/t-sql-queries/batching-techniques)
- [YouTube: SQL Server Transaction Isolation Levels Explained](https://www.youtube.com/watch?v=6I9b5V7AN4I)
- [YouTube: SQL Server Update Statement Tutorial](https://www.youtube.com/watch?v=fOAiM7bWcXc)
