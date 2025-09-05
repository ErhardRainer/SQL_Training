# T-SQL Indexes – Basics  
*Clustered/NONCLUSTERED Indizes, Schlüssel/INCLUDE, Performancegrundlagen*

## 1 | Begriffsdefinition

| SQL-Term | Beschreibung |
|---|---|
| Heap | Tabelle **ohne** Clustered Index; Zeilen über **RID** (File:Page:Slot) adressiert. |
| Clustered Index (CI) | Sortiert die **physische** Zeilenspeicherung nach dem **Cluster-Key**; eine Tabelle kann genau **einen** CI haben. |
| Nonclustered Index (NCI) | Eigenständiger B-Baum mit **Key** + optionalen **INCLUDE**-Spalten; verweist auf Zeilen über **Cluster-Key** (bei CI) bzw. **RID** (bei Heap). |
| B-Baum / Ebenen | Struktur: **Root** → **Intermediate** → **Leaf**; Leaf enthält (NCI:) Schlüssel + Include, (CI:) Datenzeilen. |
| Index Key | Spalten, die die **Sortierreihenfolge** definieren; bestimmen Seeks/Scans und Schlüsselgröße. |
| INCLUDE-Spalten | Nicht-schlüsselnde Spalten nur im **Leaf**; vergrößern Seiten, beeinflussen aber **Sortierung** nicht. |
| Covering Index | Index enthält **alle** für eine Abfrage nötigen Spalten → keine Lookups. |
| Key Lookup / RID Lookup | Nachschlagen der restlichen Spalten aus der Basistabelle (über Cluster-Key bzw. RID); kann teuer werden. |
| Seek / Scan | **Seek** nutzt selektive Schlüsselpräfixe; **Scan** liest viele Leaf-Seiten/ganzen Index. |
| SARGability | „Search ARGument-able“ – Prädikate, die Indexzugriff erlauben (keine Funktionen auf Spalten, passender Typ/Kollation). |
| Selektivität | Anteil passender Zeilen; hohe Selektivität begünstigt Seeks/NCI-Nutzen. |
| Filtered Index | Teilindex mit `WHERE`-Prädikat, z. B. nur aktive/NOT NULL-Zeilen → kleiner & selektiver. |
| UNIQUE-Index | Erzwingt **Eindeutigkeit**; kann CI oder NCI sein. |
| Fillfactor | Prozentsatz freier Platz pro Seite beim Erstellen/Rebuild; beeinflusst **Page Splits**/Schreiblast. |
| Fragmentierung | **Logische** Unordnung (externer/innerer Art) im B-Baum; kann Scans/Range-Zugriffe beeinträchtigen. |
| Statistiken | Kardinalitätsinformationen pro Index/Spalte; beeinflussen Planwahl (Seeks/Joins). |
| ASC/DESC pro Spalte | Pro Key-Spalte definierbar; wichtig für ORDER BY/Range-Queries. |
| Rowstore vs. Columnstore | **Rowstore** = klassische B-Bäume (OLTP/Ad-hoc); **Columnstore** = spaltenbasiert (OLAP). |

---

## 2 | Struktur

### 2.1 | Index-Grundlagen & B-Baum-Logik
> **Kurzbeschreibung:** CI vs. NCI, Heap, B-Baum-Ebenen, Seek/Scan, Lookups.

- 📓 **Notebook:**  
  [`08_01_index_grundlagen_bbaum.ipynb`](08_01_index_grundlagen_bbaum.ipynb)

- 🎥 **YouTube:**  
  - [SQL Server Index Basics](https://www.youtube.com/results?search_query=sql+server+index+basics)

- 📘 **Docs:**  
  - [Clustered and Nonclustered Index Architecture](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-index-design-guide#clustered-and-nonclustered)  

---

### 2.2 | Clustered Index vs. Heap – Wahl des Primärspeichers
> **Kurzbeschreibung:** Vor- & Nachteile, CI-Schlüssel wählen, Heaps nur in Spezialfällen.

- 📓 **Notebook:**  
  [`08_02_clustered_vs_heap_design.ipynb`](08_02_clustered_vs_heap_design.ipynb)

- 🎥 **YouTube:**  
  - [Clustered vs Heap](https://www.youtube.com/results?search_query=sql+server+clustered+index+vs+heap)

- 📘 **Docs:**  
  - [Heaps (Tables without Clustered Indexes)](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/heaps-tables-without-clustered-indexes)

---

### 2.3 | Nonclustered Index: Key & INCLUDE richtig wählen
> **Kurzbeschreibung:** Schlüsselpräfixe (Gleichheit → Range → ORDER), INCLUDE zum Covering, Schlüssel schlank halten.

- 📓 **Notebook:**  
  [`08_03_nonclustered_key_include.ipynb`](08_03_nonclustered_key_include.ipynb)

- 🎥 **YouTube:**  
  - [Included Columns & Covering](https://www.youtube.com/results?search_query=sql+server+included+columns+covering+index)

- 📘 **Docs:**  
  - [Create Index with Included Columns](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/create-indexes-with-included-columns)

---

### 2.4 | Covering-Strategien & Key Lookups verstehen
> **Kurzbeschreibung:** Wann Lookups teuer werden (Tipping Point), Abwägen: Covering vs. Lookup vs. Recompile.

- 📓 **Notebook:**  
  [`08_04_covering_vs_key_lookup.ipynb`](08_04_covering_vs_key_lookup.ipynb)

- 🎥 **YouTube:**  
  - [Key Lookup Explained](https://www.youtube.com/results?search_query=sql+server+key+lookup)

- 📘 **Docs:**  
  - [Query Tuning with Covering Indexes](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-index-design-guide#covering-indexes)

---

### 2.5 | Filtered Indexes – klein, schnell, selektiv
> **Kurzbeschreibung:** Teilmengen indizieren (z. B. Status, NOT NULL, aktuelle Daten).

- 📓 **Notebook:**  
  [`08_05_filtered_indexes.ipynb`](08_05_filtered_indexes.ipynb)

- 🎥 **YouTube:**  
  - [Filtered Indexes Tutorial](https://www.youtube.com/results?search_query=sql+server+filtered+index)

- 📘 **Docs:**  
  - [Create Filtered Indexes](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/create-filtered-indexes)

---

### 2.6 | UNIQUE-Index & Constraints
> **Kurzbeschreibung:** Datenintegrität + Planvorteile, Unterschiede `UNIQUE INDEX` vs. `UNIQUE CONSTRAINT`.

- 📓 **Notebook:**  
  [`08_06_unique_index_constraint.ipynb`](08_06_unique_index_constraint.ipynb)

- 🎥 **YouTube:**  
  - [Unique Index vs Constraint](https://www.youtube.com/results?search_query=sql+server+unique+index+vs+constraint)

- 📘 **Docs:**  
  - [Unique Constraints and Indexes](https://learn.microsoft.com/en-us/sql/relational-databases/tables/create-unique-constraints)

---

### 2.7 | SARGability & Ausdrucks-Patterns
> **Kurzbeschreibung:** Funktionsaufrufe auf Spalten vermeiden, Typ/Kollation passend, berechnete/persistierte Spalten.

- 📓 **Notebook:**  
  [`08_07_sargability_patterns.ipynb`](08_07_sargability_patterns.ipynb)

- 🎥 **YouTube:**  
  - [SARGable Queries](https://www.youtube.com/results?search_query=sql+server+sargable+queries)

- 📘 **Docs:**  
  - [Search Arguments & Index Use (Guide)](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-index-design-guide#search-arguments-sargability)

---

### 2.8 | Key-Order: Kompositkeys, ASC/DESC & Sortvermeidung
> **Kurzbeschreibung:** Gleichheit vor Range, passende Sortreihenfolge wählen, `ORDER BY` ausnutzen.

- 📓 **Notebook:**  
  [`08_08_key_order_composites.ipynb`](08_08_key_order_composites.ipynb)

- 🎥 **YouTube:**  
  - [Composite Index Order](https://www.youtube.com/results?search_query=sql+server+composite+index+order)

- 📘 **Docs:**  
  - [Sort Order (ASC/DESC) in Index Keys](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/create-indexes#sort-order)

---

### 2.9 | Statistiken & Selektivität – Planentscheidungen verstehen
> **Kurzbeschreibung:** Auto-Update, Histogramm/Dichte, `AUTO_CREATE/UPDATE STATISTICS`, Persistenz.

- 📓 **Notebook:**  
  [`08_09_statistics_selectivity.ipynb`](08_09_statistics_selectivity.ipynb)

- 🎥 **YouTube:**  
  - [SQL Server Statistics Basics](https://www.youtube.com/results?search_query=sql+server+statistics+histogram)

- 📘 **Docs:**  
  - [Statistics – Overview](https://learn.microsoft.com/en-us/sql/relational-databases/statistics/statistics)

---

### 2.10 | Pflege: Rebuild vs. Reorganize, Fillfactor & Fragmentierung
> **Kurzbeschreibung:** Schwellen, Online/Offline, Auswirkungen auf Log/Locks/Verfügbarkeit.

- 📓 **Notebook:**  
  [`08_10_rebuild_reorganize_fillfactor.ipynb`](08_10_rebuild_reorganize_fillfactor.ipynb)

- 🎥 **YouTube:**  
  - [Index Maintenance Explained](https://www.youtube.com/results?search_query=sql+server+index+rebuild+reorganize)

- 📘 **Docs:**  
  - [`ALTER INDEX` – REBUILD/REORGANIZE](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-index-transact-sql)

---

### 2.11 | Schreiblast: Page Splits, Hotspots & CI-Schlüssel
> **Kurzbeschreibung:** Monoton steigende Keys (`IDENTITY`,`SEQUENCE`) vs. **GUID**; `FILLFACTOR`, `NEWSEQUENTIALID()`.

- 📓 **Notebook:**  
  [`08_11_writes_pagesplits_hotspots.ipynb`](08_11_writes_pagesplits_hotspots.ipynb)

- 🎥 **YouTube:**  
  - [Page Splits & Fillfactor](https://www.youtube.com/results?search_query=sql+server+page+splits+fillfactor)

- 📘 **Docs:**  
  - [GUIDs and NEWSEQUENTIALID](https://learn.microsoft.com/en-us/sql/t-sql/functions/newsequentialid-transact-sql)  

---

### 2.12 | Monitoring: Nutzung, fehlende Indizes, DMVs
> **Kurzbeschreibung:** `sys.dm_db_index_usage_stats`, fehlende-Index-DMVs, Showplan-Meldungen.

- 📓 **Notebook:**  
  [`08_12_dmvs_index_usage_missing.ipynb`](08_12_dmvs_index_usage_missing.ipynb)

- 🎥 **YouTube:**  
  - [Find Missing/Unused Indexes](https://www.youtube.com/results?search_query=sql+server+missing+index+dmv)

- 📘 **Docs:**  
  - [`sys.dm_db_index_usage_stats`](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-index-usage-stats-transact-sql)  
  - [Missing Index DMVs](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/find-missing-indexes)

---

### 2.13 | Partitionierung & ausgerichtete Indizes (Überblick)
> **Kurzbeschreibung:** Partitionierte Tabellen/Indizes, Elimination, Wartung pro Partition.

- 📓 **Notebook:**  
  [`08_13_partitioned_indexes_overview.ipynb`](08_13_partitioned_indexes_overview.ipynb)

- 🎥 **YouTube:**  
  - [Partitioned Index Basics](https://www.youtube.com/results?search_query=sql+server+partitioned+indexes)

- 📘 **Docs:**  
  - [Partitioned Tables and Indexes](https://learn.microsoft.com/en-us/sql/relational-databases/partitions/partitioned-tables-and-indexes)

---

### 2.14 | Kompression & Speicher: Row/Page Compression
> **Kurzbeschreibung:** Speicher/IO senken, CPU-Tradeoffs, Einfluss auf Leaf-Breite und Scans.

- 📓 **Notebook:**  
  [`08_14_row_page_compression.ipynb`](08_14_row_page_compression.ipynb)

- 🎥 **YouTube:**  
  - [Index Compression](https://www.youtube.com/results?search_query=sql+server+index+compression)

- 📘 **Docs:**  
  - [Data Compression](https://learn.microsoft.com/en-us/sql/relational-databases/data-compression/data-compression)

---

### 2.15 | Workload-Patterns: OLTP vs. Reporting
> **Kurzbeschreibung:** OLTP: wenige, selektive NCIs; Reporting: Covering/Filtered, ggf. Columnstore (Hinweis).

- 📓 **Notebook:**  
  [`08_15_workload_patterns_oltp_reporting.ipynb`](08_15_workload_patterns_oltp_reporting.ipynb)

- 🎥 **YouTube:**  
  - [Indexing for OLTP vs OLAP](https://www.youtube.com/results?search_query=sql+server+indexing+oltp+vs+olap)

- 📘 **Docs:**  
  - [SQL Server Index Design Guide](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-index-design-guide)

---

### 2.16 | Anti-Patterns & Checkliste
> **Kurzbeschreibung:** Breite CI-Schlüssel, zu viele NCIs, `SELECT *`, funktionsbasierte Prädikate, falscher Datentyp/Kollation, keine Pflege/Stats, blindes „fehlende Indexe“-Skripten.

- 📓 **Notebook:**  
  [`08_16_index_anti_patterns_checkliste.ipynb`](08_16_index_anti_patterns_checkliste.ipynb)

- 🎥 **YouTube:**  
  - [Common Indexing Mistakes](https://www.youtube.com/results?search_query=sql+server+indexing+mistakes)

- 📘 **Docs/Blog:**  
  - [Index Design – Pitfalls](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-index-design-guide#common-pitfalls)

---

## 3 | Weiterführende Informationen

- 📘 Microsoft Learn: [SQL Server Index Design Guide](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-index-design-guide)  
- 📘 Microsoft Learn: [CREATE INDEX (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-index-transact-sql)  
- 📘 Microsoft Learn: [ALTER INDEX – REBUILD/REORGANIZE](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-index-transact-sql)  
- 📘 Microsoft Learn: [Create Indexes with Included Columns](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/create-indexes-with-included-columns)  
- 📘 Microsoft Learn: [Create Filtered Indexes](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/create-filtered-indexes)  
- 📘 Microsoft Learn: [Statistics – Overview & Maintenance](https://learn.microsoft.com/en-us/sql/relational-databases/statistics/statistics)  
- 📘 Microsoft Learn: [Heaps vs. Clustered Indexes](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/heaps-tables-without-clustered-indexes)  
- 📘 Microsoft Learn: [Partitioned Tables and Indexes](https://learn.microsoft.com/en-us/sql/relational-databases/partitions/partitioned-tables-and-indexes)  
- 📘 Microsoft Learn: [Data Compression (Row/Page)](https://learn.microsoft.com/en-us/sql/relational-databases/data-compression/data-compression)  
- 📘 Microsoft Learn: [Missing Index DMVs (Details/Summary/Groups)](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/find-missing-indexes)  
- 📘 Microsoft Learn: [`sys.dm_db_index_usage_stats`](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-index-usage-stats-transact-sql)  
- 📝 SQLPerformance: *Key Lookups, Covering & Tipping Point* – https://www.sqlperformance.com/?s=key+lookup  
- 📝 Paul Randal (SQLSkills): *Rebuild vs Reorganize & Fragmentation* – https://www.sqlskills.com/  
- 📝 Brent Ozar: *Indexing Best Practices* – https://www.brentozar.com/  
- 📝 Erik Darling: *SARGability & Index Patterns* – https://www.erikdarlingdata.com/  
- 🎥 YouTube Playlist: *SQL Server Indexing* – Suchlink  
