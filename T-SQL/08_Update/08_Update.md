# Update mit T-SQL – Übersicht

## 1) Begriffsdefinition

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

## 2) Struktur (Themenblöcke → je eigenes Notebook)

- [Grundlagen & Syntax](#grundlagen--syntax) – Einfaches `UPDATE`, SET-Liste, sichere Filter.  
  [`08_01_grundlagen_und_syntax.ipynb`](./08_01_grundlagen_und_syntax.ipynb)

- [UPDATE … FROM (Join-Update)](#update--from-join-update) – Ziel/Quelle abgleichen, Join-Eindeutigkeit sicherstellen.  
  [`08_02_update_from_join.ipynb`](./08_02_update_from_join.ipynb)

- [UPDATE mit CTE](#update-mit-cte) – Zielmenge vorstrukturieren, Lesbarkeit erhöhen.  
  [`08_03_update_mit_cte.ipynb`](./08_03_update_mit_cte.ipynb)

- [Transaktionen & TRY/CATCH](#transaktionen--trycatch) – Atomarität, Fehlerbehandlung, saubere Rollbacks.  
  [`08_04_transaktionen_try_catch.ipynb`](./08_04_transaktionen_try_catch.ipynb)

- [Isolation & Lock-Hinweise](#isolation--lock-hinweise) – Auswirkungen von `SNAPSHOT`, `UPDLOCK`, `ROWLOCK`.  
  [`08_05_isolation_und_locks.ipynb`](./08_05_isolation_und_locks.ipynb)

- [Batching (TOP-N-Loops)](#batching-top-n-loops) – Durchsatz steuern, Log-Wachstum/Blockaden reduzieren.  
  [`08_06_batching_topn.ipynb`](./08_06_batching_topn.ipynb)

- [OUTPUT & Auditing](#output--auditing) – Änderungen protokollieren, Delta erfassen.  
  [`08_07_output_und_auditing.ipynb`](./08_07_output_und_auditing.ipynb)

- [Idempotente Updates](#idempotente-updates) – Nur ändern, wenn Werte tatsächlich differieren.  
  [`08_08_idempotente_updates.ipynb`](./08_08_idempotente_updates.ipynb)

- [Optimistic Concurrency (rowversion)](#optimistic-concurrency-rowversion) – Parallelkonflikte erkennen und behandeln.  
  [`08_09_rowversion_concurrency.ipynb`](./08_09_rowversion_concurrency.ipynb)

- [Performance & SARGability](#performance--sargability) – Indizes, Statistiken, plan-sensitive Optionen.  
  [`08_10_performance_sargability.ipynb`](./08_10_performance_sargability.ipynb)

- [Window-Funktionen im UPDATE](#window-funktionen-im-update) – Flags/Rankings via `ROW_NUMBER()`, `PARTITION BY`.  
  [`08_11_update_mit_windowfunktionen.ipynb`](./08_11_update_mit_windowfunktionen.ipynb)

- [Partitionierte Updates](#partitionierte-updates) – Große Tabellen segmentiert aktualisieren, Hotspots vermeiden.  
  [`08_12_partitionierte_updates.ipynb`](./08_12_partitionierte_updates.ipynb)

- [Upsert ohne MERGE](#upsert-ohne-merge) – Zweistufig (erst UPDATE, dann INSERT fehlender Schlüssel).  
  [`08_13_upsert_ohne_merge.ipynb`](./08_13_upsert_ohne_merge.ipynb)

- [Temporal/CDC-Awareness](#temporalcdc-awareness) – Historien-/CT-Nebenwirkungen verstehen und steuern.  
  [`08_14_temporal_cdc_awareness.ipynb`](./08_14_temporal_cdc_awareness.ipynb)

- [Qualität & Betrieb](#qualität--betrieb) – `@@ROWCOUNT`, Vor/Nach-Zählung, Logging-Konventionen.  
  [`08_15_quality_operations.ipynb`](./08_15_quality_operations.ipynb)

- [Anti-Patterns](#anti-patterns) – UPDATE ohne WHERE, nicht-deterministische Joins, Funktions-Filter.  
  [`08_16_anti_patterns.ipynb`](./08_16_anti_patterns.ipynb)

---

## Kapitel

### Grundlagen & Syntax
### UPDATE … FROM (Join-Update)
### UPDATE mit CTE
### Transaktionen & TRY/CATCH
### Isolation & Lock-Hinweise
### Batching (TOP-N-Loops)
### OUTPUT & Auditing
### Idempotente Updates
### Optimistic Concurrency (rowversion)
### Performance & SARGability
### Window-Funktionen im UPDATE
### Partitionierte Updates
### Upsert ohne MERGE
### Temporal/CDC-Awareness
### Qualität & Betrieb
### Anti-Patterns
