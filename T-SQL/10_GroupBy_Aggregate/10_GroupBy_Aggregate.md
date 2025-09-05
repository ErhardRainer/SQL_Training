# T-SQL GROUP BY & Aggregate – Übersicht

## 1 | Begriffsdefinition

| SQL-Term | Beschreibung |
|---|---|
| Aggregatfunktion | Verdichtet mehrere Zeilen zu einem Wert: `SUM`, `AVG`, `COUNT`, `MIN`, `MAX`, `STRING_AGG`, `VAR`, `STDEV`, `CHECKSUM_AGG`, `APPROX_COUNT_DISTINCT` (SQL 2019+). |
| `GROUP BY` | Bildet Gruppen über eine oder mehrere Spalten/Ausdrücke; Aggregatfunktionen werden je Gruppe berechnet. |
| `HAVING` | Filtert **Gruppen** nach der Aggregation (im Gegensatz zu `WHERE`, das Zeilen vor Aggregation filtert). |
| Distinct-Aggregat | Aggregation über eindeutige Werte: z. B. `COUNT(DISTINCT Col)`, `SUM(DISTINCT Col)`, `AVG(DISTINCT Col)`. |
| Gruppierungsausdruck | Spalten- oder Ausdrucksliste in `GROUP BY`; jeder Ausdruck in der `SELECT`-Liste muss **aggregiert** oder **gruppiert** sein. |
| `GROUPING SETS` / `ROLLUP` / `CUBE` | Erweiterte Gruppierung: mehrere Ebenen/Hierarchien in einer Abfrage; Kennzeichnung per `GROUPING()`/`GROUPING_ID()`. |
| Window-Aggregat | `SUM() OVER (...)` u. ä. rechnen **ohne** Verdichtung (Zeilen bleiben erhalten); nicht mit `GROUP BY` verwechseln. |
| Dreiwertige Logik & `NULL` | `COUNT(*)` zählt **alle** Zeilen; `COUNT(Col)` ignoriert `NULL`. Gruppenschlüssel `NULL` bilden **eine** Gruppe. |
| Stream- vs. Hash-Aggregat | Planoperatoren: `Stream Aggregate` benötigt vorsortierte Eingabe (Index), `Hash Aggregate` nicht (benötigt Speicher). |
| Kardinalitätsschätzung (CE) | Schätzt Gruppenzahlen/Verteilungen; beeinflusst Join/Aggregat-Pläne und Memory Grants. |
| SARGability & Vorfilterung | Filter (`WHERE`) vor Aggregation reduziert Datenmenge; Funktionen auf Spalten können Indexnutzung verhindern. |
| Reihenfolge | Gruppierung **garantiert keine Sortierung**; `ORDER BY` nur auf **Gesamtergebnis**. |
| Approximation | `APPROX_COUNT_DISTINCT` liefert schnelle, speichersparende Schätzung mit definierter Fehlerrate (OLAP-Szenarien). |

---

## 2 | Struktur

### 2.1 | Grundlagen: `GROUP BY`, Aggregatfunktionen, `HAVING`
> **Kurzbeschreibung:** Syntax, logische Auswertungsreihenfolge, Unterschiede `WHERE` vs. `HAVING`, `COUNT(*)` vs. `COUNT(col)`.

- 📓 **Notebook:**  
  [`08_01_groupby_grundlagen.ipynb`](08_01_groupby_grundlagen.ipynb)

- 🎥 **YouTube:**  
  - [GROUP BY & HAVING – Basics](https://www.youtube.com/results?search_query=sql+server+group+by+having+tutorial)  
  - [COUNT(*) vs COUNT(col)](https://www.youtube.com/results?search_query=sql+server+count+star+vs+count+column)

- 📘 **Docs:**  
  - [`GROUP BY` (T-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-group-by-transact-sql)  
  - [`HAVING` (T-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-having-transact-sql)

---

### 2.2 | Aggregatfunktionen im Überblick
> **Kurzbeschreibung:** `SUM/AVG/MIN/MAX/COUNT`, `STRING_AGG`, Varianz/Standardabweichung, Besonderheiten und Datentypen.

- 📓 **Notebook:**  
  [`08_02_aggregatefunktionen_overview.ipynb`](08_02_aggregatefunktionen_overview.ipynb)

- 🎥 **YouTube:**  
  - [Aggregate Functions – Guide](https://www.youtube.com/results?search_query=sql+server+aggregate+functions)

- 📘 **Docs:**  
  - [Aggregate Functions (T-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/functions/aggregate-functions-transact-sql)  
  - [`STRING_AGG`](https://learn.microsoft.com/en-us/sql/t-sql/functions/string-agg-transact-sql)

---

### 2.3 | Distinct-Aggregate & Duplikate
> **Kurzbeschreibung:** Wann `DISTINCT` in Aggregaten sinnvoll ist (z. B. `COUNT(DISTINCT)`), Einfluss auf Pläne/Sortierungen.

- 📓 **Notebook:**  
  [`08_03_distinct_aggregate.ipynb`](08_03_distinct_aggregate.ipynb)

- 🎥 **YouTube:**  
  - [COUNT DISTINCT & Co.](https://www.youtube.com/results?search_query=sql+server+count+distinct+performance)

- 📘 **Docs:**  
  - [Aggregate Functions – DISTINCT](https://learn.microsoft.com/en-us/sql/t-sql/functions/aggregate-functions-transact-sql#remarks)

---

### 2.4 | Bedingte Aggregation mit `CASE`
> **Kurzbeschreibung:** „Gefilterte“ Summen/Counts je Kategorie ohne `FILTER`-Klausel; Pivot-ähnliche Kreuztabellen.

- 📓 **Notebook:**  
  [`08_04_bedingte_aggregation_case.ipynb`](08_04_bedingte_aggregation_case.ipynb)

- 🎥 **YouTube:**  
  - [Conditional Aggregation Patterns](https://www.youtube.com/results?search_query=sql+server+conditional+aggregation+case)

- 📘 **Docs:**  
  - [`CASE` Expression](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/case-transact-sql)

---

### 2.5 | Erweiterte Gruppierung: `GROUPING SETS`, `ROLLUP`, `CUBE`
> **Kurzbeschreibung:** Mehrere Aggregationsebenen in einem Lauf; `GROUPING()`/`GROUPING_ID()` zur Kennzeichnung.

- 📓 **Notebook:**  
  [`08_05_grouping_sets_rollup_cube.ipynb`](08_05_grouping_sets_rollup_cube.ipynb)

- 🎥 **YouTube:**  
  - [GROUPING SETS / ROLLUP / CUBE](https://www.youtube.com/results?search_query=sql+server+grouping+sets+rollup+cube)

- 📘 **Docs:**  
  - [`GROUP BY` – Erweiterungen](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-group-by-transact-sql#grouping-sets-cube-and-rollup)  
  - [`GROUPING` / `GROUPING_ID`](https://learn.microsoft.com/en-us/sql/t-sql/functions/grouping-transact-sql)

---

### 2.6 | Window-Aggregate vs. `GROUP BY`
> **Kurzbeschreibung:** Wann `SUM() OVER(PARTITION BY…)` statt `GROUP BY` sinnvoll ist (Top-N pro Gruppe, laufende Summen).

- 📓 **Notebook:**  
  [`08_06_window_aggregate_vs_groupby.ipynb`](08_06_window_aggregate_vs_groupby.ipynb)

- 🎥 **YouTube:**  
  - [Window Aggregates Deep Dive](https://www.youtube.com/results?search_query=sql+server+window+aggregate+over)

- 📘 **Docs:**  
  - [`OVER`-Klausel](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-over-clause-transact-sql)  
  - [Ranking Functions](https://learn.microsoft.com/en-us/sql/t-sql/functions/ranking-functions-transact-sql)

---

### 2.7 | Gruppierung nach Datums-/Zeitintervallen
> **Kurzbeschreibung:** Monate/Quartale/Jahre sauber bilden (`DATEADD`, `DATEDIFF`, `EOMONTH`), `DATEFIRST`/Kultur beachten.

- 📓 **Notebook:**  
  [`08_07_groupby_datum_zeit.ipynb`](08_07_groupby_datum_zeit.ipynb)

- 🎥 **YouTube:**  
  - [Group by Month/Quarter](https://www.youtube.com/results?search_query=sql+server+group+by+month+quarter)

- 📘 **Docs:**  
  - [Date & Time Functions](https://learn.microsoft.com/en-us/sql/t-sql/functions/date-and-time-data-types-and-functions-transact-sql)  
  - [`EOMONTH`](https://learn.microsoft.com/en-us/sql/t-sql/functions/eomonth-transact-sql)

---

### 2.8 | Textlisten & Aggregation: `STRING_AGG` mit `WITHIN GROUP (ORDER BY)`
> **Kurzbeschreibung:** Werte zu Listen zusammenfassen und stabil sortieren; Trennzeichen, `DISTINCT` in `STRING_AGG`.

- 📓 **Notebook:**  
  [`08_08_string_agg_listen.ipynb`](08_08_string_agg_listen.ipynb)

- 🎥 **YouTube:**  
  - [`STRING_AGG` Patterns](https://www.youtube.com/results?search_query=sql+server+string_agg+order+by)

- 📘 **Docs:**  
  - [`STRING_AGG`](https://learn.microsoft.com/en-us/sql/t-sql/functions/string-agg-transact-sql)

---

### 2.9 | Performance: Stream vs. Hash Aggregate, Indizes & Statistiken
> **Kurzbeschreibung:** Indexierte Gruppenschlüssel begünstigen `Stream Aggregate`; Statistiken/Merging, Memory Grants, Parallelität.

- 📓 **Notebook:**  
  [`08_09_performance_stream_hash.ipynb`](08_09_performance_stream_hash.ipynb)

- 🎥 **YouTube:**  
  - [Execution Plans: Aggregates](https://www.youtube.com/results?search_query=sql+server+execution+plan+aggregate)

- 📘 **Docs:**  
  - [Query Processing Architecture Guide](https://learn.microsoft.com/en-us/sql/relational-databases/query-processing-architecture-guide)  
  - [Statistics – Overview](https://learn.microsoft.com/en-us/sql/relational-databases/statistics/statistics)

---

### 2.10 | Approximation: `APPROX_COUNT_DISTINCT`
> **Kurzbeschreibung:** Sehr große Daten effizient schätzen; Trade-off Genauigkeit vs. Geschwindigkeit/Speicher.

- 📓 **Notebook:**  
  [`08_10_approx_count_distinct.ipynb`](08_10_approx_count_distinct.ipynb)

- 🎥 **YouTube:**  
  - [Approximate Count Distinct](https://www.youtube.com/results?search_query=sql+server+approx_count_distinct)

- 📘 **Docs:**  
  - [`APPROX_COUNT_DISTINCT`](https://learn.microsoft.com/en-us/sql/t-sql/functions/approx-count-distinct-transact-sql)

---

### 2.11 | Kollation, Typen & Präzision
> **Kurzbeschreibung:** Gruppierung über `varchar`/`nvarchar`, Kollationskonflikte (`COLLATE`), Dezimalpräzision/Überläufe.

- 📓 **Notebook:**  
  [`08_11_kollation_typen_praezision.ipynb`](08_11_kollation_typen_praezision.ipynb)

- 🎥 **YouTube:**  
  - [Collation & Aggregation](https://www.youtube.com/results?search_query=sql+server+collation+group+by)

- 📘 **Docs:**  
  - [Data Type Precedence](https://learn.microsoft.com/en-us/sql/t-sql/data-types/data-type-precedence-transact-sql)  
  - [Collation Precedence](https://learn.microsoft.com/en-us/sql/t-sql/statements/collation-precedence-transact-sql)

---

### 2.12 | Gruppieren über Ausdrücke & berechnete Spalten
> **Kurzbeschreibung:** Ausdruck in `GROUP BY` vs. vorab berechnete Spalte (persistierte computed column) – SARGability & Indizes.

- 📓 **Notebook:**  
  [`08_12_groupby_ausdruecke_computed.ipynb`](08_12_groupby_ausdruecke_computed.ipynb)

- 🎥 **YouTube:**  
  - [Computed Columns & Aggregation](https://www.youtube.com/results?search_query=sql+server+computed+column+group+by)

- 📘 **Docs:**  
  - [Indexes on Computed Columns](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/indexes-on-computed-columns)

---

### 2.13 | Filtern vor/nach Aggregation: `WHERE` vs. `HAVING`
> **Kurzbeschreibung:** Selektivität erhöhen, Worktables vermeiden; korrekte Platzierung von Bedingungen.

- 📓 **Notebook:**  
  [`08_13_where_vs_having_patterns.ipynb`](08_13_where_vs_having_patterns.ipynb)

- 🎥 **YouTube:**  
  - [WHERE vs HAVING](https://www.youtube.com/results?search_query=sql+server+where+vs+having)

- 📘 **Docs:**  
  - [`HAVING` – Referenz](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-having-transact-sql)

---

### 2.14 | Partitionsbewusste Aggregation (Partitioned Tables/Columnstore)
> **Kurzbeschreibung:** Partition Elimination nutzen; Batch Mode & Segment-Elimination bei Columnstore.

- 📓 **Notebook:**  
  [`08_14_partition_columnstore_aggregate.ipynb`](08_14_partition_columnstore_aggregate.ipynb)

- 🎥 **YouTube:**  
  - [Columnstore Aggregations](https://www.youtube.com/results?search_query=sql+server+columnstore+aggregate)

- 📘 **Docs:**  
  - [Partitioned Tables and Indexes](https://learn.microsoft.com/en-us/sql/relational-databases/partitions/partitioned-tables-and-indexes)  
  - [Columnstore – Query Performance](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/columnstore-indexes-query-performance)

---

### 2.15 | Qualitätssicherung & Regressionstests für Aggregationen
> **Kurzbeschreibung:** Erwartete Summen zählen/verifizieren (`EXCEPT`/`INTERSECT`/Tally-Tabellen), `@@ROWCOUNT`.

- 📓 **Notebook:**  
  [`08_15_qs_regression_aggregate.ipynb`](08_15_qs_regression_aggregate.ipynb)

- 🎥 **YouTube:**  
  - [Validate Aggregations](https://www.youtube.com/results?search_query=sql+server+validate+aggregation)

- 📘 **Docs:**  
  - [`EXCEPT` / `INTERSECT`](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/set-operators-except-and-intersect-transact-sql)  
  - [`@@ROWCOUNT`](https://learn.microsoft.com/en-us/sql/t-sql/functions/rowcount-transact-sql)

---

### 2.16 | Anti-Patterns & Fallstricke
> **Kurzbeschreibung:** Aggregieren ohne `GROUP BY`-Vollständigkeit, `ORDER BY` in Teilabfragen erwarten, `DISTINCT` als Ersatz für saubere Gruppierung, Ausdrücke auf Spalten (SARGability), unbewusste Duplikate durch Joins.

- 📓 **Notebook:**  
  [`08_16_groupby_anti_patterns.ipynb`](08_16_groupby_anti_patterns.ipynb)

- 🎥 **YouTube:**  
  - [Common GROUP BY Mistakes](https://www.youtube.com/results?search_query=sql+server+group+by+mistakes)

- 📘 **Docs/Blog:**  
  - [Query Processing Architecture](https://learn.microsoft.com/en-us/sql/relational-databases/query-processing-architecture-guide)  
  - [Joins & Dedupe – Grundlagen](https://learn.microsoft.com/en-us/sql/relational-databases/performance/joins)

---

## 3 | Weiterführende Informationen

- 📘 Microsoft Learn: [`GROUP BY` (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-group-by-transact-sql)  
- 📘 Microsoft Learn: [`HAVING` (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-having-transact-sql)  
- 📘 Microsoft Learn: [Aggregate Functions – Referenz](https://learn.microsoft.com/en-us/sql/t-sql/functions/aggregate-functions-transact-sql)  
- 📘 Microsoft Learn: [`STRING_AGG`](https://learn.microsoft.com/en-us/sql/t-sql/functions/string-agg-transact-sql)  
- 📘 Microsoft Learn: [`GROUPING` / `GROUPING_ID`](https://learn.microsoft.com/en-us/sql/t-sql/functions/grouping-transact-sql)  
- 📘 Microsoft Learn: [Data Type & Collation Precedence](https://learn.microsoft.com/en-us/sql/t-sql/data-types/data-type-precedence-transact-sql) · (Collation) (siehe *Collation Precedence*)  
- 📘 Microsoft Learn: [Statistics – Überblick](https://learn.microsoft.com/en-us/sql/relational-databases/statistics/statistics)  
- 📘 Microsoft Learn: [Columnstore – Performance](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/columnstore-indexes-query-performance)  
- 📘 Microsoft Learn: [`APPROX_COUNT_DISTINCT`](https://learn.microsoft.com/en-us/sql/t-sql/functions/approx-count-distinct-transact-sql)  
- 📘 Microsoft Learn: [Query Processing Architecture Guide](https://learn.microsoft.com/en-us/sql/relational-databases/query-processing-architecture-guide)  
- 📝 SQLPerformance: *Stream vs Hash Aggregate* (Suche) – [sqlperformance.com](https://www.sqlperformance.com/?s=aggregate)  
- 📝 Simple Talk (Redgate): *Grouping Sets, Rollup, Cube* – [red-gate.com/simple-talk](https://www.red-gate.com/simple-talk/?s=grouping+sets)  
- 📝 Itzik Ben-Gan: *Aggregation & Windowing Patterns* – [tsql.solidq.com](https://tsql.solidq.com/)  
- 📝 Brent Ozar: *SARGability & Aggregations* – [brentozar.com](https://www.brentozar.com/)  
- 🎥 YouTube Playlist: *GROUP BY / HAVING Tutorials* (Suche)  
