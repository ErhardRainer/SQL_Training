# T-SQL Window Functions – Übersicht  

## 1 | Begriffsdefinition

| SQL-Term | Beschreibung |
|---|---|
| `OVER()` | Rahmenklausel für Fensterfunktionen; definiert **Partition** (`PARTITION BY`), **Reihenfolge** (`ORDER BY`) und optional den **Frame** (`ROWS`/`RANGE`). |
| Partition | Logische Unterteilung der Eingabemenge; Fensterfunktionen werden je Partition berechnet. |
| Fensterreihenfolge | `ORDER BY` innerhalb von `OVER()`; bestimmt Rangfolge und „vorher/nachher“ für `LAG/LEAD`. |
| Frame (`ROWS`/`RANGE`) | Bereich relativ zur aktuellen Zeile (z. B. laufende Summen). In T-SQL ist `RANGE` eingeschränkt; für gleitende Fenster i. d. R. `ROWS` verwenden. |
| `ROW_NUMBER()` | Fortlaufende Zeilennummer **ohne** Lücken innerhalb einer Partition; benötigt `ORDER BY`. |
| `RANK()` / `DENSE_RANK()` | Rang mit/ohne Lücken bei Gleichständen („Ties“). |
| `NTILE(n)` | Teilt geordnete Partition in `n` möglichst gleich große **Buckets**. |
| `LAG(expr, off, def)` | Wert **vorheriger** Zeile relativ zur aktuellen; `off`/`def` optional. |
| `LEAD(expr, off, def)` | Wert **folgender** Zeile relativ zur aktuellen. |
| `FIRST_VALUE()` / `LAST_VALUE()` | Ersten/letzten Wert im **Frame** (nicht zwingend ganze Partition!) – Frame korrekt setzen. |
| Window-Aggregate | Aggregatfunktionen in `OVER()` (z. B. `SUM() OVER(...)`) – **verdichten nicht**, Zeilen bleiben erhalten. |
| Determinismus | Eindeutige Reihenfolge durch zusätzliche Sortschlüssel (Tiebreaker) sicherstellen, sonst können Ergebnisse schwanken. |
| NULL-Ordnung | SQL Server kennt kein `NULLS FIRST/LAST`; `NULL` sortiert standardmäßig wie „sehr klein“ bei `ASC`. |
| Performance | Sort/Spool/Memory Grants möglich; Partitionierung & Indexe auf Sortierschlüssel helfen. |

---

## 2 | Struktur

### 2.1 | `OVER()`-Grundlagen: PARTITION, ORDER, Frame
> **Kurzbeschreibung:** Syntax & Bausteine von `OVER()`, Unterschiede zu `GROUP BY`, logische Auswertung.

- 📓 **Notebook:**  
  [`08_01_over_grundlagen.ipynb`](08_01_over_grundlagen.ipynb)

- 🎥 **YouTube:**  
  - [OVER Clause – Basics](https://www.youtube.com/results?search_query=sql+server+over+clause+basics)

- 📘 **Docs:**  
  - [`OVER`-Klausel](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-over-clause-transact-sql)

---

### 2.2 | Ranking: `ROW_NUMBER()` vs. `RANK()` vs. `DENSE_RANK()` (+ `NTILE`)
> **Kurzbeschreibung:** Gleichstände, Lücken, Ties; geeignete Anwendungsfälle und Tiebreaker.

- 📓 **Notebook:**  
  [`08_02_ranking_row_number_rank_dense_rank_ntile.ipynb`](08_02_ranking_row_number_rank_dense_rank_ntile.ipynb)

- 🎥 **YouTube:**  
  - [ROW_NUMBER vs RANK vs DENSE_RANK](https://www.youtube.com/results?search_query=sql+server+row_number+rank+dense_rank)

- 📘 **Docs:**  
  - [Ranking Functions (`ROW_NUMBER`, `RANK`, `DENSE_RANK`, `NTILE`)](https://learn.microsoft.com/en-us/sql/t-sql/functions/ranking-functions-transact-sql)

---

### 2.3 | Offsets: `LAG()` & `LEAD()` in der Praxis
> **Kurzbeschreibung:** Vorher/Nachher-Vergleiche, Delta-Berechnungen, Standardwerte am Rand der Partition.

- 📓 **Notebook:**  
  [`08_03_lag_lead_patterns.ipynb`](08_03_lag_lead_patterns.ipynb)

- 🎥 **YouTube:**  
  - [Using LAG/LEAD](https://www.youtube.com/results?search_query=sql+server+lag+lead)

- 📘 **Docs:**  
  - [`LAG`](https://learn.microsoft.com/en-us/sql/t-sql/functions/lag-transact-sql) · [`LEAD`](https://learn.microsoft.com/en-us/sql/t-sql/functions/lead-transact-sql)

---

### 2.4 | Laufende Summen & gleitende Fenster
> **Kurzbeschreibung:** `SUM() OVER(ORDER BY … ROWS BETWEEN …)` für Running Totals, Moving Averages, Window Count.

- 📓 **Notebook:**  
  [`08_04_running_totals_moving_avg.ipynb`](08_04_running_totals_moving_avg.ipynb)

- 🎥 **YouTube:**  
  - [Running Totals with WINDOW](https://www.youtube.com/results?search_query=sql+server+running+total+window+functions)

- 📘 **Docs:**  
  - [`OVER` – Frames mit `ROWS`/`RANGE`](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-over-clause-transact-sql#arguments)

---

### 2.5 | Frames verstehen: `ROWS` vs. `RANGE`
> **Kurzbeschreibung:** Korrekte Frames definieren, Limitierungen von `RANGE` in T-SQL, Ties & numerische/orderbare Typen.

- 📓 **Notebook:**  
  [`08_05_rows_vs_range_frames.ipynb`](08_05_rows_vs_range_frames.ipynb)

- 🎥 **YouTube:**  
  - [ROWS vs RANGE explained](https://www.youtube.com/results?search_query=sql+server+rows+vs+range)

- 📘 **Docs:**  
  - [`OVER` – Frame-Klausel](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-over-clause-transact-sql#rows-and-range)

---

### 2.6 | Top-N pro Gruppe: `ROW_NUMBER()` filtern
> **Kurzbeschreibung:** „Beste“ Zeile je Partition ermitteln (Top-1/Top-N), typische CTE-Muster.

- 📓 **Notebook:**  
  [`08_06_top_n_per_group_row_number.ipynb`](08_06_top_n_per_group_row_number.ipynb)

- 🎥 **YouTube:**  
  - [Top N per Group with ROW_NUMBER](https://www.youtube.com/results?search_query=sql+server+top+n+per+group+row_number)

- 📘 **Docs:**  
  - [`ROW_NUMBER`](https://learn.microsoft.com/en-us/sql/t-sql/functions/row-number-transact-sql)

---

### 2.7 | Pagination: `ROW_NUMBER()` vs. `OFFSET/FETCH`
> **Kurzbeschreibung:** Stabil paginieren mit eindeutigem `ORDER BY`; Vor-/Nachteile beider Ansätze.

- 📓 **Notebook:**  
  [`08_07_pagination_row_number_offset_fetch.ipynb`](08_07_pagination_row_number_offset_fetch.ipynb)

- 🎥 **YouTube:**  
  - [Paging Strategies in T-SQL](https://www.youtube.com/results?search_query=sql+server+pagination+row_number+offset+fetch)

- 📘 **Docs:**  
  - [`ORDER BY … OFFSET/FETCH`](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-order-by-clause-transact-sql)

---

### 2.8 | Gaps & Islands mit `LAG()`
> **Kurzbeschreibung:** Folgen/Gruppen erkennen (Sessions, zusammenhängende Bereiche), Start/Ende je Insel bestimmen.

- 📓 **Notebook:**  
  [`08_08_gaps_and_islands_with_lag.ipynb`](08_08_gaps_and_islands_with_lag.ipynb)

- 🎥 **YouTube:**  
  - [Gaps & Islands (Window Functions)](https://www.youtube.com/results?search_query=sql+server+gaps+and+islands+lag)

- 📘 **Docs/Blog:**  
  - [`LAG`](https://learn.microsoft.com/en-us/sql/t-sql/functions/lag-transact-sql)

---

### 2.9 | Deduplizieren: Duplikate per `ROW_NUMBER()` entfernen
> **Kurzbeschreibung:** Dubs markieren (`ROW_NUMBER()` über Schlüssel, ORDER BY Präferenz) und mit `DELETE`/`QUALIFY`-Äquivalent löschen.

- 📓 **Notebook:**  
  [`08_09_dedupe_with_row_number.ipynb`](08_09_dedupe_with_row_number.ipynb)

- 🎥 **YouTube:**  
  - [Remove Duplicates with ROW_NUMBER](https://www.youtube.com/results?search_query=sql+server+remove+duplicates+row_number)

- 📘 **Docs:**  
  - [`ROW_NUMBER`](https://learn.microsoft.com/en-us/sql/t-sql/functions/row-number-transact-sql)

---

### 2.10 | `FIRST_VALUE`/`LAST_VALUE` – Frame-Fallstricke
> **Kurzbeschreibung:** Warum `LAST_VALUE()` oft den **aktuellen** Wert liefert; richtigen Frame setzen (`ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING`).

- 📓 **Notebook:**  
  [`08_10_first_last_value_frames.ipynb`](08_10_first_last_value_frames.ipynb)

- 🎥 **YouTube:**  
  - [FIRST/LAST VALUE Gotchas](https://www.youtube.com/results?search_query=sql+server+first_value+last_value+frame)

- 📘 **Docs:**  
  - [`FIRST_VALUE`](https://learn.microsoft.com/en-us/sql/t-sql/functions/first-value-transact-sql) · [`LAST_VALUE`](https://learn.microsoft.com/en-us/sql/t-sql/functions/last-value-transact-sql)

---

### 2.11 | Prozent-Rang & kumulative Verteilung
> **Kurzbeschreibung:** `PERCENT_RANK()`/`CUME_DIST()` für Perzentile, Rankings in Analysen.

- 📓 **Notebook:**  
  [`08_11_percent_rank_cume_dist.ipynb`](08_11_percent_rank_cume_dist.ipynb)

- 🎥 **YouTube:**  
  - [Percent Rank & Cume Dist](https://www.youtube.com/results?search_query=sql+server+percent_rank+cume_dist)

- 📘 **Docs:**  
  - [`PERCENT_RANK`](https://learn.microsoft.com/en-us/sql/t-sql/functions/percent-rank-transact-sql) · [`CUME_DIST`](https://learn.microsoft.com/en-us/sql/t-sql/functions/cume-dist-transact-sql)

---

### 2.12 | Null-Handling & Ties: deterministische Ergebnisse
> **Kurzbeschreibung:** NULL-Verhalten, stabile Sortierung mit zusätzlichen Keys, Kollationsaspekte bei Text.

- 📓 **Notebook:**  
  [`08_12_nulls_ties_determinism.ipynb`](08_12_nulls_ties_determinism.ipynb)

- 🎥 **YouTube:**  
  - [Deterministic Window Results](https://www.youtube.com/results?search_query=sql+server+deterministic+order+by+ties)

- 📘 **Docs:**  
  - [Data Type/Collation Precedence](https://learn.microsoft.com/en-us/sql/t-sql/data-types/data-type-precedence-transact-sql)

---

### 2.13 | Performance: Indizes, Sorts, Memory Grants
> **Kurzbeschreibung:** Wie Indizes auf (`PARTITION BY`+`ORDER BY`) helfen; Parallelität, Spools, Batch Mode on Rowstore (2019+).

- 📓 **Notebook:**  
  [`08_13_performance_window_functions.ipynb`](08_13_performance_window_functions.ipynb)

- 🎥 **YouTube:**  
  - [T-SQL Window Functions – Performance](https://www.youtube.com/results?search_query=sql+server+window+functions+performance)

- 📘 **Docs:**  
  - [Query Processing Architecture](https://learn.microsoft.com/en-us/sql/relational-databases/query-processing-architecture-guide)

---

### 2.14 | Columnstore & große Partitionen
> **Kurzbeschreibung:** Batch Mode, Segment-Elimination, Einfluss auf Ranking/Offsets.

- 📓 **Notebook:**  
  [`08_14_columnstore_windowing.ipynb`](08_14_columnstore_windowing.ipynb)

- 🎥 **YouTube:**  
  - [Windowing on Columnstore](https://www.youtube.com/results?search_query=sql+server+columnstore+window+functions)

- 📘 **Docs:**  
  - [Columnstore – Query Performance](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/columnstore-indexes-query-performance)

---

### 2.15 | Qualität & Tests
> **Kurzbeschreibung:** Erwartete Rangfolgen prüfen, Gleichstands-Szenarien testen, Regressionen via kontrollierter Datenstubs.

- 📓 **Notebook:**  
  [`08_15_quality_testing_window.ipynb`](08_15_quality_testing_window.ipynb)

- 🎥 **YouTube:**  
  - [Testing Window Queries](https://www.youtube.com/results?search_query=sql+server+test+window+functions)

- 📘 **Docs:**  
  - [DMVs/Execution Plans – Überblick](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/system-dynamic-management-views)

---

### 2.16 | Anti-Patterns & Fallstricke
> **Kurzbeschreibung:** Fehlende/instabile `ORDER BY`-Keys, falsche Frames bei `LAST_VALUE`, Funktionen in Sortschlüsseln, gigantische Partitionen ohne Vorfilter.

- 📓 **Notebook:**  
  [`08_16_window_anti_patterns.ipynb`](08_16_window_anti_patterns.ipynb)

- 🎥 **YouTube:**  
  - [Common Window Function Mistakes](https://www.youtube.com/results?search_query=sql+server+window+functions+mistakes)

- 📘 **Docs/Blog:**  
  - [`OVER` – Hinweise & Einschränkungen](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-over-clause-transact-sql#remarks)  
  - [SARGability & Expressions](https://www.brentozar.com/archive/2018/02/sargable-queries/)

---

## 3 | Weiterführende Informationen

- 📘 Microsoft Learn: [`OVER`-Klausel – Referenz](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-over-clause-transact-sql)  
- 📘 Microsoft Learn: [Ranking Functions (`ROW_NUMBER`/`RANK`/`DENSE_RANK`/`NTILE`)](https://learn.microsoft.com/en-us/sql/t-sql/functions/ranking-functions-transact-sql)  
- 📘 Microsoft Learn: [`LAG` & `LEAD`](https://learn.microsoft.com/en-us/sql/t-sql/functions/lag-transact-sql) · (Lead) [(link)](https://learn.microsoft.com/en-us/sql/t-sql/functions/lead-transact-sql)  
- 📘 Microsoft Learn: [`FIRST_VALUE` / `LAST_VALUE`](https://learn.microsoft.com/en-us/sql/t-sql/functions/first-value-transact-sql)  
- 📘 Microsoft Learn: [Windowed Aggregates – Beispiele](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-over-clause-transact-sql#examples)  
- 📘 Microsoft Learn: [`ORDER BY` & Pagination (`OFFSET/FETCH`)](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-order-by-clause-transact-sql)  
- 📘 Microsoft Learn: [Data Type / Collation Precedence](https://learn.microsoft.com/en-us/sql/t-sql/data-types/data-type-precedence-transact-sql)  
- 📘 Microsoft Learn: [Query Processing Architecture Guide](https://learn.microsoft.com/en-us/sql/relational-databases/query-processing-architecture-guide)  
- 📘 Microsoft Learn: [Columnstore – Performance](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/columnstore-indexes-query-performance)  
- 📝 SQLPerformance: *Window Functions – Planformen & Tuning* (Suche) – https://www.sqlperformance.com/?s=window+functions  
- 📝 Itzik Ben-Gan: *Windowing Patterns & Best Practices* – https://tsql.solidq.com/  
- 📝 Erik Darling: *Frames, Ties & Performance-Hinweise* – https://www.erikdarlingdata.com/  
- 📝 Simple Talk (Redgate): *Practical Window Functions* – https://www.red-gate.com/simple-talk/?s=window+functions  
- 🎥 YouTube Playlist: *T-SQL Window Functions* (Sammlung) – https://www.youtube.com/results?search_query=itzik+ben+gan+window+functions  
