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

## 2 | Struktur (Themenblöcke → je eigenes Notebook)

### 2.1 | Grundlagen & Syntax
Kurzüberblick zu einfachem `UPDATE`, SET-Liste, sicherer WHERE-Filter.  
* _Notebook_: [`08_01_grundlagen_und_syntax.ipynb`](./08_01_grundlagen_und_syntax.ipynb)

### 2.2 | UPDATE ... FROM (Join-Update)
Join-basiertes UPDATE zwischen Ziel- und Quellmenge; Eindeutigkeit sicherstellen.  
* _Notebook_: [`08_02_update_from_join.ipynb`](./08_02_update_from_join.ipynb)

### 2.3 | UPDATE mit CTE
CTE zur Vorstrukturierung/Lesbarkeit der Zielmenge verwenden.  
* _Notebook_: [`08_03_update_mit_cte.ipynb`](./08_03_update_mit_cte.ipynb)

### 2.4 | Transaktionen & TRY/CATCH
Atomarität, Fehlerbehandlung, Rollback-Strategien.  
* _Notebook_: [`08_04_transaktionen_try_catch.ipynb`](./08_04_transaktionen_try_catch.ipynb)

### 2.5 | Isolation & Lock-Hinweise
Auswirkungen von `SNAPSHOT`, `UPDLOCK`, `ROWLOCK` auf Parallelität und Sperren.  
* _Notebook_: [`08_05_isolation_und_locks.ipynb`](./08_05_isolation_und_locks.ipynb)

### 2.6 | Batching (TOP-N-Loops)
Durchsatz steuern, Log-Wachstum und Blockaden reduzieren.  
* _Notebook_: [`08_06_batching_topn.ipynb`](./08_06_batching_topn.ipynb)

### 2.7 | OUTPUT & Auditing
Änderungen per `OUTPUT` erfassen; Deltas/Audits speichern.  
* _Notebook_: [`08_07_output_und_auditing.ipynb`](./08_07_output_und_auditing.ipynb)

### 2.8 | Idempotente Updates
Nur ändern, wenn Werte differieren; unnötige Writes vermeiden.  
* _Notebook_: [`08_08_idempotente_updates.ipynb`](./08_08_idempotente_updates.ipynb)

### 2.9 | Optimistic Concurrency (rowversion)
Parallelkonflikte via `rowversion` erkennen und behandeln.  
* _Notebook_: [`08_09_rowversion_concurrency.ipynb`](./08_09_rowversion_concurrency.ipynb)

### 2.10 | Performance & SARGability
Indizes, Statistiken, SARGable-Filter, plan-sensitive Optionen.  
* _Notebook_: [`08_10_performance_sargability.ipynb`](./08_10_performance_sargability.ipynb)

### 2.11 | Window-Funktionen im UPDATE
Flags/Rankings mit `ROW_NUMBER()`/`PARTITION BY` setzen.  
* _Notebook_: [`08_11_update_mit_windowfunktionen.ipynb`](./08_11_update_mit_windowfunktionen.ipynb)

### 2.12 | Partitionierte Updates
Große Tabellen segmentiert aktualisieren, Hotspots vermeiden.  
* _Notebook_: [`08_12_partitionierte_updates.ipynb`](./08_12_partitionierte_updates.ipynb)

### 2.13 | Upsert ohne MERGE
Robustes Zweistufenmuster: UPDATE vorhandener, INSERT neuer Schlüssel.  
* _Notebook_: [`08_13_upsert_ohne_merge.ipynb`](./08_13_upsert_ohne_merge.ipynb)

### 2.14 | Temporal/CDC-Awareness
Nebenwirkungen auf Historien-/CT-Tabellen verstehen und steuern.  
* _Notebook_: [`08_14_temporal_cdc_awareness.ipynb`](./08_14_temporal_cdc_awareness.ipynb)

### 2.15 | Qualität & Betrieb
`@@ROWCOUNT`, Vor/Nach-Zählung, Logging-Konventionen, Betriebssicherheit.  
* _Notebook_: [`08_15_quality_operations.ipynb`](./08_15_quality_operations.ipynb)

### 2.16 | Anti-Patterns
UPDATE ohne WHERE, nicht-deterministische Joins, Funktions-Filter, blindes Lock-Hinting.  
* _Notebook_: [`08_16_anti_patterns.ipynb`](./08_16_anti_patterns.ipynb)
