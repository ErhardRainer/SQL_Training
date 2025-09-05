# T-SQL Columnstore Indexes – Übersicht  
*OLAP-optimierte Indizes, Batch Mode Processing, Data Warehousing*

## 1 | Begriffsdefinition

| SQL-Term | Beschreibung |
|---|---|
| Columnstore | Spaltenorientierte Speicherung (**PAX**-Format) für analytische Abfragen; hohe Kompression & Scan-Durchsatz. |
| CCI (Clustered Columnstore Index) | Primärer Speicher der Tabelle im Columnstore (keine separate Rowstore-Struktur). |
| NCCI (Nonclustered Columnstore Index) | Zusatzindex auf Rowstore-Tabellen für **Operational Analytics** (Hybrid OLTP+Analytics). |
| Rowgroup | Horizontaler Chunk (Zielgröße ~**1.048.576** Zeilen). Besteht aus **Segmenten** je Spalte. |
| Segment | Spaltenabschnitt einer Rowgroup mit **Min/Max**-Metadaten, Kompressions- & Dictionary-Infos. |
| Delta Store | Rowstore-(B-Tree-)Puffer für kleine Inkremente (<~**102.400** Zeilen/Batch). **Tuple Mover** komprimiert später. |
| Deleted Bitmap | Markiert gelöschte/aktualisierte Zeilen in komprimierten Rowgroups (logischer Delete). |
| Batch Mode | Vektorisierte Operatoren verarbeiten Zeilen im **Batch** (i. d. R. 64/900+ Zeilen) → drastisch weniger CPU/Branch-Miss. |
| Predicate/Projection Pushdown | Filter/Spaltenprojektion werden früh in den Scan verlagert; nutzt **Segment (Rowgroup) Elimination** via Min/Max. |
| Aggregate Pushdown | `SUM/COUNT/AVG/MIN/MAX` werden teils im Storage-Scan voraggregiert. |
| Kompression | Dictionary/Run-Length/Bit-Packing; optional **`COLUMNSTORE_ARCHIVE`** für maximale Kompression (langsamer). |
| Rebuild/Reorg | `ALTER INDEX … REBUILD` (voll), `… REORGANIZE` (defragmentiert/mergt Rowgroups, trimmt Delete Bitmap). |
| Datentypen | Die meisten Typen unterstützt; sehr breite oder LOB-Spalten beeinträchtigen Kompression/Batch-Fähigkeit. |
| Partitionierung | Je Partition eigene Rowgroups/Segmente; zu feine Partitionierung ⇒ kleine Rowgroups ⇒ schlechter. |
| Ordered CCI (optional) | (Neuere Versionen) CCI mit **ORDER(...)** für bessere Segment-Elimination (Workload-abhängig). |

---

## 2 | Struktur

### 2.1 | Architektur & Grundlagen: Columnstore vs. Rowstore
> **Kurzbeschreibung:** Spaltenorientierte Speicherung, PAX-Layout, warum Columnstore für DW-Workloads überlegen ist.

- 📓 **Notebook:**  
  [`08_01_architektur_columnstore_vs_rowstore.ipynb`](08_01_architektur_columnstore_vs_rowstore.ipynb)
- 🎥 **YouTube:**  
  - [Columnstore Indexes – Overview (Data Exposed)](https://www.youtube.com/results?search_query=sql+server+columnstore+indexes+overview)
  - [Rowstore vs Columnstore Explained](https://www.youtube.com/results?search_query=rowstore+vs+columnstore+sql+server)
- 📘 **Docs:**  
  - [Columnstore Indexes – Overview](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/columnstore-indexes-overview)

---

### 2.2 | Speicherinterna: Rowgroups, Segmente, Dictionaries
> **Kurzbeschreibung:** Aufbau einer Rowgroup, Segment-Metadaten (Min/Max), Dictionary-/RLE-/Bitpack-Kompression.

- 📓 **Notebook:**  
  [`08_02_internals_rowgroup_segment_dictionary.ipynb`](08_02_internals_rowgroup_segment_dictionary.ipynb)
- 🎥 **YouTube:**  
  - [Columnstore Internals](https://www.youtube.com/results?search_query=sql+server+columnstore+internals)
- 📘 **Docs:**  
  - [Architectural Concepts](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/columnstore-indexes-architectural-concepts)

---

### 2.3 | Delta Store & Tuple Mover
> **Kurzbeschreibung:** Kleine Inkremente landen im Delta Store; der Tuple Mover komprimiert, wenn Schwellen erreicht sind.

- 📓 **Notebook:**  
  [`08_03_delta_store_tuple_mover.ipynb`](08_03_delta_store_tuple_mover.ipynb)
- 🎥 **YouTube:**  
  - [Delta Store & Tuple Mover](https://www.youtube.com/results?search_query=delta+store+tuple+mover+sql+server)
- 📘 **Docs:**  
  - [Design Guidance – Delta Store](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/columnstore-indexes-design-guidance)

---

### 2.4 | Batch Mode Processing
> **Kurzbeschreibung:** Wie Batch Mode Operatoren CPU sparen; Interaktion mit Joins/Aggregates; Batch Mode on Rowstore (Überblick).

- 📓 **Notebook:**  
  [`08_04_batch_mode_processing.ipynb`](08_04_batch_mode_processing.ipynb)
- 🎥 **YouTube:**  
  - [Batch Mode Explained](https://www.youtube.com/results?search_query=batch+mode+sql+server)
- 📘 **Docs:**  
  - [Batch Mode Processing](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/columnstore-indexes-overview#batch-mode-processing)

---

### 2.5 | Predicate/Projection Pushdown & Segment Elimination
> **Kurzbeschreibung:** Wie Min/Max-Metadaten Scans reduzieren; SARGability & passende Filterformen.

- 📓 **Notebook:**  
  [`08_05_pushdown_segment_elimination.ipynb`](08_05_pushdown_segment_elimination.ipynb)
- 🎥 **YouTube:**  
  - [Segment Elimination Demo](https://www.youtube.com/results?search_query=segment+elimination+columnstore)
- 📘 **Docs:**  
  - [Rowgroup Elimination & Pushdown](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/columnstore-indexes-overview#pruning-rowgroups)

---

### 2.6 | Erstellen & Laden: CCI/NCCI, Minimal Logging
> **Kurzbeschreibung:** `CREATE/ALTER INDEX`-Optionen, `TABLOCK`/Bulkload, Batchgrößen (~100k+ Zeilen) für direkte Komprimierung.

- 📓 **Notebook:**  
  [`08_06_create_load_minlog_cc_ncc.ipynb`](08_06_create_load_minlog_cc_ncc.ipynb)
- 🎥 **YouTube:**  
  - [Create & Load Columnstore Fast](https://www.youtube.com/results?search_query=create+columnstore+index+bulk+load+sql+server)
- 📘 **Docs:**  
  - [Create Columnstore Indexes](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/create-columnstore-index)  
  - [Load Guidance](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/columnstore-indexes-data-loading-guidance)

---

### 2.7 | Wartung: REBUILD/REORGANIZE, Delete Bitmap, Fragmentierung
> **Kurzbeschreibung:** Wann Rebuild vs. Reorg? Delete-Bitmap-Trimmen, kleine Rowgroups mergen.

- 📓 **Notebook:**  
  [`08_07_maintenance_rebuild_reorg.ipynb`](08_07_maintenance_rebuild_reorg.ipynb)
- 🎥 **YouTube:**  
  - [Maintain Columnstore Indexes](https://www.youtube.com/results?search_query=maintain+columnstore+indexes)
- 📘 **Docs:**  
  - [Defragment Columnstore Indexes](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/columnstore-indexes-defragmentation)

---

### 2.8 | Kompression & Archivierung
> **Kurzbeschreibung:** Standard vs. `COLUMNSTORE_ARCHIVE`; Trade-offs zwischen Platz und CPU/Abfragezeit.

- 📓 **Notebook:**  
  [`08_08_compression_archive.ipynb`](08_08_compression_archive.ipynb)
- 🎥 **YouTube:**  
  - [Archive Compression for Columnstore](https://www.youtube.com/results?search_query=columnstore+archive+compression+sql+server)
- 📘 **Docs:**  
  - [Archive Compression](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/columnstore-indexes-overview#columnstore-archive-compression)

---

### 2.9 | Abfragepatterns: Star Schema, KNN-ähnliche Filter, Window-Aggr.
> **Kurzbeschreibung:** DW-typische Abfragen (`GROUP BY`, Window-Funktionen) effizient gestalten; nur benötigte Spalten projizieren.

- 📓 **Notebook:**  
  [`08_09_query_patterns_dw_analytics.ipynb`](08_09_query_patterns_dw_analytics.ipynb)
- 🎥 **YouTube:**  
  - [DW Query Patterns on Columnstore](https://www.youtube.com/results?search_query=data+warehouse+columnstore+query+patterns)
- 📘 **Docs:**  
  - [Performance Considerations](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/columnstore-indexes-overview#performance-considerations)

---

### 2.10 | NCCI für Operational Analytics (Hybrid)
> **Kurzbeschreibung:** NCCI auf OLTP-Tabellen: Schreibkosten vs. Reporting-Gewinn; Filtered NCCI für gezielte Sichten.

- 📓 **Notebook:**  
  [`08_10_ncci_operational_analytics.ipynb`](08_10_ncci_operational_analytics.ipynb)
- 🎥 **YouTube:**  
  - [Operational Analytics with NCCI](https://www.youtube.com/results?search_query=operational+analytics+columnstore+sql+server)
- 📘 **Docs:**  
  - [Use NCCI on OLTP Tables](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/columnstore-indexes-design-guidance#use-a-nonclustered-columnstore-index-on-an-oltp-table)

---

### 2.11 | Partitionierung & Sliding Window
> **Kurzbeschreibung:** Partitionierte CCIs, Switch-In/Out von Fact-Partitionen, Fallstricke zu kleinen Rowgroups.

- 📓 **Notebook:**  
  [`08_11_partitioning_sliding_window_ccis.ipynb`](08_11_partitioning_sliding_window_ccis.ipynb)
- 🎥 **YouTube:**  
  - [Partitioned Columnstore Strategies](https://www.youtube.com/results?search_query=partitioned+columnstore+sql+server)
- 📘 **Docs:**  
  - [Partitioned Columnstore – Guidance](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/columnstore-indexes-design-guidance#partitioned-tables)

---

### 2.12 | SARGability, Pushdown-Fähigkeit & Planhinweise
> **Kurzbeschreibung:** Ausdrücke vermeiden, die Pushdown verhindern; nur benötigte Spalten; ggf. `OPTION (RECOMPILE)` bei ParamSniffing.

- 📓 **Notebook:**  
  [`08_12_sargability_pushdown_plans.ipynb`](08_12_sargability_pushdown_plans.ipynb)
- 🎥 **YouTube:**  
  - [SARGable Analytics on Columnstore](https://www.youtube.com/results?search_query=sargable+columnstore+sql+server)
- 📘 **Docs:**  
  - [Query Processing & Pushdown](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/columnstore-indexes-overview#query-optimizations)

---

### 2.13 | DML & Concurrency: Inserts/Updates/Deletes
> **Kurzbeschreibung:** Auswirkungen auf Delta Store/Deleted Bitmap, Bulk-Insert-Muster, Batchgrößen & Log-Verhalten.

- 📓 **Notebook:**  
  [`08_13_dml_concurrency_delta_deletedbitmap.ipynb`](08_13_dml_concurrency_delta_deletedbitmap.ipynb)
- 🎥 **YouTube:**  
  - [DML on Columnstore Tables](https://www.youtube.com/results?search_query=dml+on+columnstore+sql+server)
- 📘 **Docs:**  
  - [DML & Columnstore](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/columnstore-indexes-overview#dml-operations)

---

### 2.14 | Diagnose & DMVs/Kataloge
> **Kurzbeschreibung:** `sys.column_store_row_groups`, `sys.dm_db_column_store_row_group_physical_stats`, `sys.column_store_dictionaries`.

- 📓 **Notebook:**  
  [`08_14_dmvs_diagnostics_columnstore.ipynb`](08_14_dmvs_diagnostics_columnstore.ipynb)
- 🎥 **YouTube:**  
  - [DMVs for Columnstore](https://www.youtube.com/results?search_query=sys.column_store_row_groups)
- 📘 **Docs:**  
  - [Columnstore Catalog/DMVs](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-column-store-row-group-physical-stats-transact-sql)

---

### 2.15 | Ordered CCI & Segment-Zuschnitt (optional)
> **Kurzbeschreibung:** (Je nach Version) `ORDER (col, …)` beim CCI für bessere Eliminierung/Kompression; Workload prüfen.

- 📓 **Notebook:**  
  [`08_15_ordered_cci_segment_tuning.ipynb`](08_15_ordered_cci_segment_tuning.ipynb)
- 🎥 **YouTube:**  
  - [Ordered Columnstore (Overview)](https://www.youtube.com/results?search_query=ordered+columnstore+sql+server)
- 📘 **Docs:**  
  - [CREATE COLUMNSTORE INDEX – ORDER](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-columnstore-index-transact-sql)

---

### 2.16 | Anti-Patterns & Checkliste
> **Kurzbeschreibung:** Zu feine Partitionierung → Mini-Rowgroups; breite LOB-Spalten; Filter mit Funktionen; nur CCI aber 100% OLTP; Rebuilds ohne Bedarf; kein Monitoring von Delete Bitmap.

- 📓 **Notebook:**  
  [`08_16_antipatterns_checkliste_columnstore.ipynb`](08_16_antipatterns_checkliste_columnstore.ipynb)
- 🎥 **YouTube:**  
  - [Common Columnstore Mistakes](https://www.youtube.com/results?search_query=columnstore+mistakes+sql+server)
- 📘 **Docs/Blog:**  
  - [Design Guidance – Do/Don’t](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/columnstore-indexes-design-guidance)

---

## 3 | Weiterführende Informationen

- 📘 Microsoft Learn: [Columnstore Indexes – Overview](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/columnstore-indexes-overview)  
- 📘 Microsoft Learn: [Architectural Concepts (Rowgroups/Segments)](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/columnstore-indexes-architectural-concepts)  
- 📘 Microsoft Learn: [Design Guidance (DW/OLTP/NCCI/Partitioning)](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/columnstore-indexes-design-guidance)  
- 📘 Microsoft Learn: [Create Columnstore Index (`ORDER`, `DROP_EXISTING`, `COMPRESSION_DELAY`)](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-columnstore-index-transact-sql)  
- 📘 Microsoft Learn: [Defragment/REORGANIZE/REBUILD](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/columnstore-indexes-defragmentation)  
- 📘 Microsoft Learn: [Data Loading Guidance (Bulk, Minimal Logging, TABLOCK)](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/columnstore-indexes-data-loading-guidance)  
- 📘 Microsoft Learn: [DMVs/Catalog Views (`sys.column_store_*`)](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-column-store-dictionaries-transact-sql)  
- 📘 Microsoft Learn: [Batch Mode Processing & Pushdown](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/columnstore-indexes-overview#batch-mode-processing)  
- 📝 Niko Neugebauer: *Columnstore Indexes – Series* (Deep Dive) – https://www.nikoport.com/columnstore/  
- 📝 SQLPerformance: *Tuning Columnstore Loads & Maintenance* – https://www.sqlperformance.com/?s=columnstore  
- 📝 Paul White (SQL Kiwi): *Batch Mode & Execution Plans* – https://www.sql.kiwi/  
- 📝 Brent Ozar: *When to use CCI vs. NCCI* – https://www.brentozar.com/  
- 📝 Erik Darling: *Delete Bitmaps, Rowgroup Quality & Queries* – https://www.erikdarlingdata.com/  
- 🎥 YouTube (Data Exposed): *Columnstore Deep Dives* – Suchlink  
- 🎥 YouTube: *Loading & Maintaining Columnstore – Demos* – Suchlink  
