# T-SQL GROUPING SETS, ROLLUP, CUBE – Übersicht

## 1 | Begriffsdefinition

| SQL-Term | Beschreibung |
|---|---|
| Erweiterte Aggregation | `GROUP BY GROUPING SETS (...)`, `ROLLUP (...)`, `CUBE (...)` erzeugen **mehrere Aggregationsebenen** in **einem** Statement. |
| `GROUPING SETS` | Explizite Menge von Gruppierungen: z. B. `GROUPING SETS ((a,b), (a), ())` – frei kombinierbar. |
| `ROLLUP` | Hierarchisches Totalschema von links nach rechts (z. B. `Year → Month → Day → Grand Total`). |
| `CUBE` | Alle Kombinationen der angegebenen Spalten (Potenzmenge) – erzeugt viele Ebenen (2^n). |
| Leere Gruppierung `()` | **Grand Total** (Aggregation über alle Zeilen). |
| Kompositlisten | Klammerpaare in `GROUPING SETS` (z. B. `(Region, Product)`), auch Mischungen aus Spalten und Ausdrücken erlaubt. |
| `GROUPING()` | Kennzeichnet **aggregierte** Spalten in erweiterten Gruppierungen: 1 = „wurde aggregiert“, 0 = „normale Gruppenspalte“. |
| `GROUPING_ID()` | Bitmaske über mehrere Spalten, um die **Ebene** zu identifizieren (z. B. 0=Detail, 3=Grand Total bei zwei Spalten). |
| `HAVING` | Filtert **Gruppen** (auch auf Teilmengen-Ebenen). |
| Ordnung | Ergebnis ist ohne `ORDER BY` nicht determiniert; für saubere Berichte stets `ORDER BY` (z. B. nach `GROUPING_ID()`). |
| Distinct-Aggregate | `SUM(DISTINCT ...)` etc. wird pro Ebene berechnet; kann Sort/Hash-Kosten erhöhen. |
| Performance | `CUBE` explodiert schnell; `GROUPING SETS` wählen oft günstiger. Indizes/Columnstore & Partition Elimination helfen. |
| Kompatibilität | Moderne Syntax: `GROUP BY ROLLUP(...)`/`CUBE(...)`/`GROUPING SETS(...)`. Historische `WITH ROLLUP/CUBE` existiert, moderne Form bevorzugen. |

---

## 2 | Struktur

### 2.1 | Überblick & Syntax: GROUPING SETS / ROLLUP / CUBE
> **Kurzbeschreibung:** Wann welches Konstrukt? Lesbare Beispiele, Unterschiede und typische Einsatzfälle (Totals, Subtotals, Cross-Tabs).

- 📓 **Notebook:**  
  [`08_01_grouping_sets_rollup_cube_grundlagen.ipynb`](08_01_grouping_sets_rollup_cube_grundlagen.ipynb)

- 🎥 **YouTube:**  
  - [GROUPING SETS / ROLLUP / CUBE – Basics](https://www.youtube.com/results?search_query=sql+server+grouping+sets+rollup+cube)  

- 📘 **Docs:**  
  - [`GROUP BY` – Erweiterungen: GROUPING SETS, ROLLUP, CUBE](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-group-by-transact-sql#grouping-sets-cube-and-rollup)

---

### 2.2 | `ROLLUP` – Hierarchische Totals
> **Kurzbeschreibung:** Von Detail zu Zwischensummen zu Grand Total in einer definierten Reihenfolge (links → rechts).

- 📓 **Notebook:**  
  [`08_02_rollup_hierarchien.ipynb`](08_02_rollup_hierarchien.ipynb)

- 🎥 **YouTube:**  
  - [ROLLUP explained](https://www.youtube.com/results?search_query=sql+server+rollup+tutorial)

- 📘 **Docs:**  
  - [`ROLLUP` – Beispiele](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-group-by-transact-sql#rollup)

---

### 2.3 | `CUBE` – Alle Kombinationen
> **Kurzbeschreibung:** Vollständige Kreuzaggregation über alle Spaltenkombinationen; Nutzen & Vorsicht bei hoher Dimensionalität.

- 📓 **Notebook:**  
  [`08_03_cube_kombinationen.ipynb`](08_03_cube_kombinationen.ipynb)

- 🎥 **YouTube:**  
  - [CUBE with examples](https://www.youtube.com/results?search_query=sql+server+cube+group+by)

- 📘 **Docs:**  
  - [`CUBE` – Beispiele](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-group-by-transact-sql#cube)

---

### 2.4 | `GROUPING SETS` – Feingranulare Kontrolle
> **Kurzbeschreibung:** Exakte Ebenen definieren (z. B. `(Region, Product)`, `(Region)`, `(Product)`, `()`), gemischte Ausdrücke/Listen.

- 📓 **Notebook:**  
  [`08_04_grouping_sets_feinsteuerung.ipynb`](08_04_grouping_sets_feinsteuerung.ipynb)

- 🎥 **YouTube:**  
  - [Grouping Sets – Practical Guide](https://www.youtube.com/results?search_query=sql+server+grouping+sets+examples)

- 📘 **Docs:**  
  - [`GROUPING SETS` – Syntax & Beispiele](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-group-by-transact-sql#grouping-sets)

---

### 2.5 | Ebenen kennzeichnen mit `GROUPING()`/`GROUPING_ID()`
> **Kurzbeschreibung:** Zeilenlabeling (Detail/Subtotal/Grand Total), Sortierung & Reporting; Bitmasken lesen.

- 📓 **Notebook:**  
  [`08_05_grouping_groupingid_labels.ipynb`](08_05_grouping_groupingid_labels.ipynb)

- 🎥 **YouTube:**  
  - [GROUPING() & GROUPING_ID()](https://www.youtube.com/results?search_query=sql+server+grouping+grouping_id)

- 📘 **Docs:**  
  - [`GROUPING`](https://learn.microsoft.com/en-us/sql/t-sql/functions/grouping-transact-sql) · [`GROUPING_ID`](https://learn.microsoft.com/en-us/sql/t-sql/functions/grouping-id-transact-sql)

---

### 2.6 | `HAVING` & Filterlogik über Ebenen
> **Kurzbeschreibung:** Gruppen nach der Aggregation filtern (z. B. nur Subtotals mit Umsatz > X); Kombination mit `GROUPING_ID()`.

- 📓 **Notebook:**  
  [`08_06_having_mit_grouping_sets.ipynb`](08_06_having_mit_grouping_sets.ipynb)

- 🎥 **YouTube:**  
  - [HAVING with advanced GROUP BY](https://www.youtube.com/results?search_query=sql+server+having+grouping+sets)

- 📘 **Docs:**  
  - [`HAVING` – Referenz](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-having-transact-sql)

---

### 2.7 | Präsentation: Sortierung & „schöne“ Labels
> **Kurzbeschreibung:** Sinnvolle `ORDER BY` (z. B. nach `GROUPING_ID()`, Dimensionen), `ISNULL/COALESCE` für Lesbarkeit, Grand-Total-Label.

- 📓 **Notebook:**  
  [`08_07_orderby_labels_grouping.ipynb`](08_07_orderby_labels_grouping.ipynb)

- 🎥 **YouTube:**  
  - [Report-friendly Grouping](https://www.youtube.com/results?search_query=sql+server+grouping+id+report)

- 📘 **Docs:**  
  - [`ORDER BY` (Gesamtergebnis)](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-order-by-clause-transact-sql)

---

### 2.8 | Performance: Hash/Stream Aggregate, Columnstore & Parallelität
> **Kurzbeschreibung:** Operatoren & Memory Grants, Nutzen von Vorfilterung, Columnstore/Batch Mode, Partition Elimination.

- 📓 **Notebook:**  
  [`08_08_performance_grouping_sets.ipynb`](08_08_performance_grouping_sets.ipynb)

- 🎥 **YouTube:**  
  - [Execution Plans for GROUPING SETS](https://www.youtube.com/results?search_query=sql+server+grouping+sets+execution+plan)

- 📘 **Docs:**  
  - [Query Processing Architecture Guide](https://learn.microsoft.com/en-us/sql/relational-databases/query-processing-architecture-guide)  
  - [Columnstore – Query Performance](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/columnstore-indexes-query-performance)

---

### 2.9 | DISTINCT, Mehrfachzählungen & fachliche Korrektheit
> **Kurzbeschreibung:** `COUNT(DISTINCT ...)` pro Ebene, doppelte Beiträge vermeiden (z. B. bei Multi-Mappings), Validierung.

- 📓 **Notebook:**  
  [`08_09_distinct_und_validierung.ipynb`](08_09_distinct_und_validierung.ipynb)

- 🎥 **YouTube:**  
  - [COUNT DISTINCT with ROLLUP/CUBE](https://www.youtube.com/results?search_query=sql+server+count+distinct+rollup)

- 📘 **Docs:**  
  - [Aggregate Functions – DISTINCT](https://learn.microsoft.com/en-us/sql/t-sql/functions/aggregate-functions-transact-sql#remarks)

---

### 2.10 | Mischung mit `PIVOT` / bedingter Aggregation
> **Kurzbeschreibung:** Kreuztabellen via `GROUP BY` + `CASE` gegenüber `PIVOT`; wann kombinieren, wann trennen.

- 📓 **Notebook:**  
  [`08_10_grouping_sets_pivot_patterns.ipynb`](08_10_grouping_sets_pivot_patterns.ipynb)

- 🎥 **YouTube:**  
  - [Grouping Sets vs PIVOT](https://www.youtube.com/results?search_query=sql+server+pivot+grouping+sets)

- 📘 **Docs:**  
  - [`PIVOT/UNPIVOT`](https://learn.microsoft.com/en-us/sql/t-sql/queries/from-using-pivot-and-unpivot)

---

### 2.11 | Zeitliche Hierarchien (Jahr/Quartal/Monat/Tag)
> **Kurzbeschreibung:** Kalendermuster mit `ROLLUP(Year, Quarter, Month, Day)`, `EOMONTH`, Datumsdimensionen.

- 📓 **Notebook:**  
  [`08_11_zeitliche_rollups.ipynb`](08_11_zeitliche_rollups.ipynb)

- 🎥 **YouTube:**  
  - [Date Hierarchies with ROLLUP](https://www.youtube.com/results?search_query=sql+server+rollup+date+hierarchy)

- 📘 **Docs:**  
  - [Date & Time Functions](https://learn.microsoft.com/en-us/sql/t-sql/functions/date-and-time-data-types-and-functions-transact-sql)

---

### 2.12 | Ausdrucksbasierte Gruppierung & berechnete Spalten
> **Kurzbeschreibung:** Gruppieren über Ausdrücke; sargierbare Alternativen via **persistierter berechneter Spalte**.

- 📓 **Notebook:**  
  [`08_12_ausdruecke_vs_computed_grouping.ipynb`](08_12_ausdruecke_vs_computed_grouping.ipynb)

- 🎥 **YouTube:**  
  - [Computed Columns for Grouping](https://www.youtube.com/results?search_query=sql+server+computed+column+group+by)

- 📘 **Docs:**  
  - [Indexes on Computed Columns](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/indexes-on-computed-columns)

---

### 2.13 | Validierung & Tests: Soll-/Ist-Raster
> **Kurzbeschreibung:** Erwartete Ebenen prüfen (`EXCEPT`/`INTERSECT`), Regressionschecks für Summen & Stückzahlen.

- 📓 **Notebook:**  
  [`08_13_validierung_grouping_sets.ipynb`](08_13_validierung_grouping_sets.ipynb)

- 🎥 **YouTube:**  
  - [Validate Aggregations](https://www.youtube.com/results?search_query=sql+server+validate+aggregation)

- 📘 **Docs:**  
  - [`EXCEPT` / `INTERSECT`](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/set-operators-except-and-intersect-transact-sql)

---

### 2.14 | Sicherheit & RLS-Auswirkungen
> **Kurzbeschreibung:** Row-Level Security filtert **vor** der Aggregation; kann Ebenen und Totals verändern.

- 📓 **Notebook:**  
  [`08_14_sicherheit_rls_aggregation.ipynb`](08_14_sicherheit_rls_aggregation.ipynb)

- 🎥 **YouTube:**  
  - [RLS & Aggregations](https://www.youtube.com/results?search_query=sql+server+row+level+security+group+by)

- 📘 **Docs:**  
  - [Row-Level Security](https://learn.microsoft.com/en-us/sql/relational-databases/security/row-level-security)

---

### 2.15 | OLAP-ähnliche Szenarien vs. Window-Aggregate
> **Kurzbeschreibung:** Wann `SUM() OVER(...)` sinnvoller ist (keine Verdichtung) und wann `ROLLUP/CUBE` (Verdichtung mehrerer Ebenen).

- 📓 **Notebook:**  
  [`08_15_window_vs_grouping_sets.ipynb`](08_15_window_vs_grouping_sets.ipynb)

- 🎥 **YouTube:**  
  - [Window vs Grouping Sets](https://www.youtube.com/results?search_query=sql+server+window+functions+vs+grouping+sets)

- 📘 **Docs:**  
  - [`OVER`-Klausel](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-over-clause-transact-sql)

---

### 2.16 | Anti-Patterns & Fallstricke
> **Kurzbeschreibung:** Unnötiges `CUBE` statt gezielter `GROUPING SETS`, fehlende Labels, doppelte Zählungen, `ORDER BY` auf Detailspalten ohne Ebene, massive Ebenenexplosion.

- 📓 **Notebook:**  
  [`08_16_grouping_sets_anti_patterns.ipynb`](08_16_grouping_sets_anti_patterns.ipynb)

- 🎥 **YouTube:**  
  - [Common mistakes with ROLLUP/CUBE](https://www.youtube.com/results?search_query=sql+server+rollup+cube+mistakes)

- 📘 **Docs/Blog:**  
  - [Aggregate Functions – Referenz](https://learn.microsoft.com/en-us/sql/t-sql/functions/aggregate-functions-transact-sql)

---

## 3 | Weiterführende Informationen

- 📘 Microsoft Learn: [`GROUP BY` – GROUPING SETS, ROLLUP, CUBE](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-group-by-transact-sql#grouping-sets-cube-and-rollup)  
- 📘 Microsoft Learn: [`GROUPING`](https://learn.microsoft.com/en-us/sql/t-sql/functions/grouping-transact-sql) · [`GROUPING_ID`](https://learn.microsoft.com/en-us/sql/t-sql/functions/grouping-id-transact-sql)  
- 📘 Microsoft Learn: [Aggregate Functions – Übersicht](https://learn.microsoft.com/en-us/sql/t-sql/functions/aggregate-functions-transact-sql)  
- 📘 Microsoft Learn: [Query Processing Architecture Guide](https://learn.microsoft.com/en-us/sql/relational-databases/query-processing-architecture-guide)  
- 📘 Microsoft Learn: [Columnstore – Query Performance](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/columnstore-indexes-query-performance)  
- 📝 Simple Talk (Redgate): *Grouping Sets, Rollup, and Cube* (Artikelserie)  
- 📝 SQLShack: *SQL Server Grouping Sets, Rollup & Cube – Beispiele*  
- 📝 SQLPerformance: *Tuning GROUP BY & Aggregations* (Suchsammlung)  
- 📝 Itzik Ben-Gan: *Advanced Aggregations & GROUPING_ID Patterns* – Sammlung auf tsql.solidq.com  
- 📝 Brent Ozar: *SARGability vor Aggregation & cardinality pitfalls*  
- 🎥 YouTube: *GROUPING SETS / ROLLUP / CUBE – Tutorials* (diverse Channels)  
- 🎥 YouTube: *GROUPING_ID for Reporting – Demo*  

