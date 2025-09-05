# T-SQL Partitioning – Übersicht  
*Partitionierte Tabellen & Indizes, Sliding-/Switch-Strategien*

## 1 | Begriffsdefinition

| SQL-Term | Beschreibung |
|---|---|
| Partitionierung | Horizontale Aufteilung einer Tabelle/eines Indexes in **Partitionen** nach Schlüssel (z. B. Datum). Ziel: **Verwaltbarkeit**, ggf. I/O/Parallelismus. |
| Partition Function | `CREATE PARTITION FUNCTION pf_... (datatype) AS RANGE { LEFT | RIGHT } FOR VALUES (...);` – definiert **Grenzwerte** → Partitionsnummern. |
| Partition Scheme | `CREATE PARTITION SCHEME ps_... AS PARTITION pf_... TO (FG1, FG2, …);` – **Zuweisung** der Partitionen zu Filegroups/Storage. |
| LEFT/RIGHT | Grenzwert-Zugehörigkeit: **LEFT** → Grenzwert gehört zur **linken** Partition; **RIGHT** → zur **rechten**. |
| Aligned Index | Index, der **auf demselben** Partition Scheme/Function wie die Basistabelle liegt (gleicher Schlüssel) → Voraussetzung für **SWITCH**. |
| Partition Elimination | Optimizer liest nur **relevante** Partitionen, wenn Prädikat **sargierbar** auf Partitionierungsspalte ist. |
| Split/Merge | `ALTER PARTITION FUNCTION ... SPLIT RANGE(...)` (neue Grenze hinzufügen) / `... MERGE RANGE(...)` (Grenze entfernen). |
| SWITCH | `ALTER TABLE ... SWITCH { PARTITION n } TO ...` – **Metadaten-Operation** (schnell, minimal loggend) zum **IN/OUT**-Wechseln ganzer Partitionen. |
| Sliding Window | Betriebs­muster: **neue** Partition splitten + **Daten rein-switchen**, **alte** raus-switchen/archivieren/entfernen. |
| UNIQUE & Partition Key | Eindeutige Indexe auf partitionierten Tabellen **müssen** den Partition Key enthalten. |
| Incremental Statistics | Partitionierte Tabellen können **inkrementelle Statistiken** je Partition führen (Wartung nur auf geänderten Partitions). |
| $PARTITION | `$PARTITION.pf_name(col)` liefert die **Partitionsnummer** einer Zeile – nützlich zur Diagnose. |
| Kompression je Partition | `ALTER INDEX ... REBUILD PARTITION = n WITH (DATA_COMPRESSION = ROW|PAGE|COLUMNSTORE_ARCHIVE)` – unterschiedlich pro Partition. |
| Partitionierte Views | „Poor man’s partitioning“ (UNION ALL über Tabellen mit CHECK-Constraints); historisch, i. d. R. echte Partitionierung vorziehen. |
| Grenzen | Partitionierung ersetzt **keine** Indizierung; Performancegewinne nur bei **passenden Prädikaten** / Wartungsfällen. |

---

## 2 | Struktur

### 2.1 | Grundlagen: Warum partitionieren?
> **Kurzbeschreibung:** Ziele (Verwaltbarkeit, Fast Purge/Load, Filegroup-Platzierung), typische Keys (Datum, ID-Ranges).

- 📓 **Notebook:**  
  [`08_01_partitioning_motivation_basics.ipynb`](08_01_partitioning_motivation_basics.ipynb)
- 🎥 **YouTube:**  
  - [SQL Server Table Partitioning – Overview](https://www.youtube.com/results?search_query=sql+server+table+partitioning+overview)
- 📘 **Docs:**  
  - [Partitioned Tables and Indexes](https://learn.microsoft.com/en-us/sql/relational-databases/partitions/partitioned-tables-and-indexes)

---

### 2.2 | Partition Function: Grenzen & LEFT/RIGHT
> **Kurzbeschreibung:** Grenzwertlogik, leere „Sicherheits“-Partition, Wahl der Datentypen.

- 📓 **Notebook:**  
  [`08_02_partition_function_left_right.ipynb`](08_02_partition_function_left_right.ipynb)
- 🎥 **YouTube:**  
  - [Partition Function LEFT vs RIGHT](https://www.youtube.com/results?search_query=sql+server+partition+function+left+right)
- 📘 **Docs:**  
  - [`CREATE PARTITION FUNCTION`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-partition-function-transact-sql)

---

### 2.3 | Partition Scheme & Filegroups
> **Kurzbeschreibung:** Filegroup-Layout, Heiß/Kalt-Daten, Storage-Tiering.

- 📓 **Notebook:**  
  [`08_03_partition_scheme_filegroups.ipynb`](08_03_partition_scheme_filegroups.ipynb)
- 🎥 **YouTube:**  
  - [Partition Scheme & Filegroups](https://www.youtube.com/results?search_query=sql+server+partition+scheme+filegroups)
- 📘 **Docs:**  
  - [`CREATE PARTITION SCHEME`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-partition-scheme-transact-sql)

---

### 2.4 | Tabellen & **aligned** Indizes anlegen
> **Kurzbeschreibung:** Warum alle relevanten Indexe **aligned** sein sollten (Elimination & SWITCH); UNIQUE-Regel beachten.

- 📓 **Notebook:**  
  [`08_04_create_partitioned_table_aligned_indexes.ipynb`](08_04_create_partitioned_table_aligned_indexes.ipynb)
- 🎥 **YouTube:**  
  - [Aligned Indexes Explained](https://www.youtube.com/results?search_query=sql+server+aligned+indexes+partitioning)
- 📘 **Docs:**  
  - [Indexing on Partitioned Tables](https://learn.microsoft.com/en-us/sql/relational-databases/partitions/partitioned-tables-and-indexes#indexes-on-partitioned-tables)

---

### 2.5 | Partition Elimination – sargierbare Prädikate
> **Kurzbeschreibung:** Nur lesende Partitionen; Filter **auf** Partition Key, keine Funktionsaufrufe auf der Spalte.

- 📓 **Notebook:**  
  [`08_05_partition_elimination_sargability.ipynb`](08_05_partition_elimination_sargability.ipynb)
- 🎥 **YouTube:**  
  - [Partition Elimination Demo](https://www.youtube.com/results?search_query=sql+server+partition+elimination)
- 📘 **Docs:**  
  - [Query Processing & Partition Elimination](https://learn.microsoft.com/en-us/sql/relational-databases/partitions/partitioned-tables-and-indexes#query-processing)

---

### 2.6 | SPLIT & MERGE – Grenzen pflegen
> **Kurzbeschreibung:** Neue Perioden vorbereiten (SPLIT), alte zusammenfassen (MERGE); Log/Fragmentierung im Blick.

- 📓 **Notebook:**  
  [`08_06_split_merge_patterns.ipynb`](08_06_split_merge_patterns.ipynb)
- 🎥 **YouTube:**  
  - [ALTER PARTITION FUNCTION SPLIT/MERGE](https://www.youtube.com/results?search_query=sql+server+alter+partition+function+split+merge)
- 📘 **Docs:**  
  - [`ALTER PARTITION FUNCTION`](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-partition-function-transact-sql)

---

### 2.7 | SWITCH IN/OUT – Sliding Window in der Praxis
> **Kurzbeschreibung:** Bulk-Load und Fast-Purge via **metadata-only**; Staging-Tabelle mit **CHECK** passend zur Zielpartition.

- 📓 **Notebook:**  
  [`08_07_switch_in_out_sliding_window.ipynb`](08_07_switch_in_out_sliding_window.ipynb)
- 🎥 **YouTube:**  
  - [Partition SWITCH Demo](https://www.youtube.com/results?search_query=sql+server+partition+switch)
- 📘 **Docs:**  
  - [Switching Partitions](https://learn.microsoft.com/en-us/sql/relational-databases/partitions/switching-partitions)

---

### 2.8 | SWITCH – Kompatibilitätsanforderungen
> **Kurzbeschreibung:** Identisches Schema/Index-Layout, **aligned** Indizes, **trusted CHECK** auf Staging, keine konfliktreichen FKs/Trigger (feuern nicht bei SWITCH).

- 📓 **Notebook:**  
  [`08_08_switch_compat_requirements.ipynb`](08_08_switch_compat_requirements.ipynb)
- 🎥 **YouTube:**  
  - [Requirements for Partition Switch](https://www.youtube.com/results?search_query=sql+server+partition+switch+requirements)
- 📘 **Docs:**  
  - [Partition Switch – Requirements](https://learn.microsoft.com/en-us/sql/relational-databases/partitions/switching-partitions#requirements)

---

### 2.9 | Inkrementelle Statistiken & Wartung je Partition
> **Kurzbeschreibung:** Nur geänderte Partitionen neu indizieren/statistiken aktualisieren; `ALTER INDEX ... REBUILD PARTITION = n`.

- 📓 **Notebook:**  
  [`08_09_incremental_statistics_partition_maintenance.ipynb`](08_09_incremental_statistics_partition_maintenance.ipynb)
- 🎥 **YouTube:**  
  - [Incremental Stats on Partitioned Tables](https://www.youtube.com/results?search_query=sql+server+incremental+statistics+partitioned)
- 📘 **Docs:**  
  - [Incremental Statistics](https://learn.microsoft.com/en-us/sql/relational-databases/statistics/incremental-statistics)

---

### 2.10 | Kompression je Partition (Row/Page/Columnstore)
> **Kurzbeschreibung:** Heiß/Kalt-Strategien: heiße Partitionen ohne/Row, kalte mit Page/Archiv; Columnstore-Archive für Altbestände.

- 📓 **Notebook:**  
  [`08_10_partition_compression_strategies.ipynb`](08_10_partition_compression_strategies.ipynb)
- 🎥 **YouTube:**  
  - [Per-Partition Compression](https://www.youtube.com/results?search_query=sql+server+partition+compression)
- 📘 **Docs:**  
  - [Data Compression](https://learn.microsoft.com/en-us/sql/relational-databases/data-compression/data-compression)  
  - [Columnstore Indexes – Archival](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/columnstore-indexes-overview#columnstore-archive-compression)

---

### 2.11 | Diagnose & DMVs: Welche Zeilen in welcher Partition?
> **Kurzbeschreibung:** `$PARTITION`, `sys.partitions`, `sys.partition_range_values`, `sys.dm_db_partition_stats`.

- 📓 **Notebook:**  
  [`08_11_dmvs_partition_inspection.ipynb`](08_11_dmvs_partition_inspection.ipynb)
- 🎥 **YouTube:**  
  - [DMVs for Partitioning](https://www.youtube.com/results?search_query=sql+server+dmv+partitioning)
- 📘 **Docs:**  
  - [`sys.partitions`](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-partitions-transact-sql) ・ [`sys.partition_range_values`](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-partition-range-values-transact-sql)

---

### 2.12 | Columnstore + Partitionierung (DW-Pattern)
> **Kurzbeschreibung:** Kompatibilität, Segment-Pruning vs. Partition Elimination, Bulk-Load & Switch.

- 📓 **Notebook:**  
  [`08_12_columnstore_with_partitioning.ipynb`](08_12_columnstore_with_partitioning.ipynb)
- 🎥 **YouTube:**  
  - [Partitioned Columnstore Strategies](https://www.youtube.com/results?search_query=sql+server+partitioned+columnstore)
- 📘 **Docs:**  
  - [Columnstore & Partitioning](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/columnstore-indexes-overview#partitioning-considerations)

---

### 2.13 | Partitionierte Views vs. echte Partitionierung
> **Kurzbeschreibung:** UNION-ALL-Views mit CHECK-Constraints – Vor-/Nachteile, Migration zu echten Partitionen.

- 📓 **Notebook:**  
  [`08_13_partitioned_views_vs_tables.ipynb`](08_13_partitioned_views_vs_tables.ipynb)
- 🎥 **YouTube:**  
  - [Partitioned Views Explained](https://www.youtube.com/results?search_query=sql+server+partitioned+views)
- 📘 **Docs:**  
  - [Partitioned Views](https://learn.microsoft.com/en-us/sql/relational-databases/views/create-partitioned-views)

---

### 2.14 | Typische Fehler & Korrekturen (Boundary, CHECK, FKs)
> **Kurzbeschreibung:** Falsch gesetzte LEFT/RIGHT-Grenzen, nicht-trusted CHECKs, Non-Aligned Indexe verhindern SWITCH.

- 📓 **Notebook:**  
  [`08_14_partition_troubleshooting.ipynb`](08_14_partition_troubleshooting.ipynb)
- 🎥 **YouTube:**  
  - [Partitioning Gotchas](https://www.youtube.com/results?search_query=sql+server+partitioning+gotchas)
- 📘 **Docs:**  
  - [Troubleshoot Partitioned Tables](https://learn.microsoft.com/en-us/sql/relational-databases/partitions/partitioned-tables-and-indexes#troubleshooting)

---

### 2.15 | Governance & Betrieb: Backups, Restore, Filegroups
> **Kurzbeschreibung:** Filegroup-Backups, selective Restore, Ruhezustand alter Partitionen (READ_ONLY-FG).

- 📓 **Notebook:**  
  [`08_15_operations_filegroup_backup_restore.ipynb`](08_15_operations_filegroup_backup_restore.ipynb)
- 🎥 **YouTube:**  
  - [Filegroup Backups for Partitions](https://www.youtube.com/results?search_query=sql+server+filegroup+backup+partitioning)
- 📘 **Docs:**  
  - [Using Filegroups for Administration](https://learn.microsoft.com/en-us/sql/relational-databases/databases/database-files-and-filegroups)

---

### 2.16 | Anti-Patterns & Checkliste
> **Kurzbeschreibung:** Partitionierung ohne passenden Key/Prädikate, **NOT** aligned Indexe, fehlende CHECKs bei Staging, grenzenloses SPLIT (zu viele Partitionen), „Partitioning als Performance-Wundermittel“, Statistiken/Kompression nicht per Partition steuern.

- 📓 **Notebook:**  
  [`08_16_partitioning_anti_patterns_checklist.ipynb`](08_16_partitioning_anti_patterns_checklist.ipynb)
- 🎥 **YouTube:**  
  - [Common Partitioning Mistakes](https://www.youtube.com/results?search_query=sql+server+partitioning+mistakes)
- 📘 **Docs/Blog:**  
  - [Best Practices for Partitioning](https://learn.microsoft.com/en-us/sql/relational-databases/partitions/partitioned-tables-and-indexes#best-practices)

---

## 3 | Weiterführende Informationen

- 📘 Microsoft Learn: [Partitioned Tables and Indexes – Überblick & Beispiele](https://learn.microsoft.com/en-us/sql/relational-databases/partitions/partitioned-tables-and-indexes)  
- 📘 Microsoft Learn: [`CREATE PARTITION FUNCTION`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-partition-function-transact-sql) ・ [`CREATE PARTITION SCHEME`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-partition-scheme-transact-sql)  
- 📘 Microsoft Learn: [`ALTER PARTITION FUNCTION` (SPLIT/MERGE)](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-partition-function-transact-sql) ・ [`ALTER PARTITION SCHEME`](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-partition-scheme-transact-sql)  
- 📘 Microsoft Learn: [Switching Partitions (IN/OUT)](https://learn.microsoft.com/en-us/sql/relational-databases/partitions/switching-partitions)  
- 📘 Microsoft Learn: [Indexes on Partitioned Tables (Aligned/Unique-Regeln)](https://learn.microsoft.com/en-us/sql/relational-databases/partitions/partitioned-tables-and-indexes#indexes-on-partitioned-tables)  
- 📘 Microsoft Learn: [Incremental Statistics](https://learn.microsoft.com/en-us/sql/relational-databases/statistics/incremental-statistics)  
- 📘 Microsoft Learn: [Data Compression & Columnstore Archive](https://learn.microsoft.com/en-us/sql/relational-databases/data-compression/data-compression) ・ [Columnstore – Overview](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/columnstore-indexes-overview)  
- 📘 Microsoft Learn: [DMVs: `sys.partitions`, `sys.partition_range_values`, `sys.dm_db_partition_stats`](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-partitions-transact-sql)  
- 📘 Microsoft Learn: [Query Processing & Partition Elimination](https://learn.microsoft.com/en-us/sql/relational-databases/partitions/partitioned-tables-and-indexes#query-processing)  
- 📝 SQLPerformance: *Sliding Window & SWITCH Patterns* – https://www.sqlperformance.com/?s=partition+switch  
- 📝 Simple Talk (Redgate): *Table Partitioning in Practice*  
- 📝 Brent Ozar: *When (not) to Partition Tables* – https://www.brentozar.com/  
- 📝 Erik Darling: *Partition Elimination & SARGability* – https://www.erikdarlingdata.com/  
- 📝 Paul White (SQL Kiwi): *Partitioning Internals & Plans* – https://www.sql.kiwi/  
- 🎥 YouTube (Data Exposed): *Managing Partitioned Tables* – Suchlink  
- 🎥 YouTube: *SWITCH IN/OUT & Sliding Window Demo* – Suchlink  
