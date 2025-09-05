# T-SQL Subqueries, CTEs & Temp Objects – Übersicht  
*Unterabfragen, `WITH` CTE, temporäre Tabellen & Tabellenvariablen*

## 1 | Begriffsdefinition

| SQL-Term | Beschreibung |
|---|---|
| Unterabfrage (Subquery) | Abfrage innerhalb von `SELECT`/`WHERE`/`HAVING`/`FROM`. Varianten: **skalare** (liefert 1 Wert), **mehrzeilige** (`IN/EXISTS/ANY/ALL`), **korrelierte** (bezieht sich auf äußere Zeile). |
| Abgeleitete Tabelle (Derived Table) | Subquery im `FROM` mit Alias: `FROM (SELECT …) AS d`. Nur im aktuellen Statement sichtbar. |
| CTE (`WITH cte AS (…)`) | Benannter Abfrageausdruck, gilt **nur für das nächste Statement**. Mehrere CTEs kommagetrennt definierbar. |
| Rekursive CTE | `WITH cte AS (Anchor UNION ALL RecursivePart)` – Traversal/Hierarchien. `OPTION (MAXRECURSION n)` (Standard 100; `0` = unbegrenzt). |
| `EXISTS` / `NOT EXISTS` | Semijoin-/Anti-Semijoin-Muster. Bevorzugt gegenüber `IN/NOT IN` bei `NULL`-Fallstricken. |
| `IN` / `ANY|SOME|ALL` | Mengentests; `NOT IN` mit `NULL` in der Menge → **keine Treffer** (dreiwertige Logik beachten). |
| `APPLY` (CROSS/OUTER) | Zeilenweises Anwenden eines tabellenwertigen Ausdrucks/TVF; oft Alternative zu korrelierten Subqueries. |
| Temporäre Tabelle `#temp` | Physisch in `tempdb`; besitzt **Statistiken** (Auto-Create/Update), frei indizierbar, Scope = Session/Proc. |
| Tabellenvariable `@t` | Deklaratives Temp-Objekt; **keine Auto-Statistiken**; Indizes via **PRIMARY KEY/UNIQUE**-Constraints. SQL 2019+: **Deferred Compilation** verbessert Schätzungen. |
| `SELECT INTO` | Schnelles Erzeugen & Befüllen einer (Temp-)Tabelle in einem Schritt: `SELECT … INTO #t FROM …`. |
| Materialisierung | CTE/Derived Table werden i. d. R. **nicht** materialisiert (Inline-Expansion). `#temp/@t` **materialisieren** Ergebnisse. |
| SARGability | Funktionen auf Spalten in Subqueries vermeiden; besser Literale/Variablen transformieren. |
| Best Practices | `EXISTS`/`NOT EXISTS` für (Anti-)Semijoins, CTE für Lesbarkeit/Hierarchien, `#temp` bei Wiederverwendung/Indexbedarf, `@t` für kleine Mengen/TVPs. |

---

## 2 | Struktur

### 2.1 | Subquery-Grundlagen: Skalar, IN/EXISTS, Positionen
> **Kurzbeschreibung:** Einsatz in `SELECT`/`WHERE`/`HAVING`, Unterschiede skalar vs. mehrzeilig, dreiwertige Logik (`NULL`).

- 📓 **Notebook:**  
  [`08_01_subquery_grundlagen.ipynb`](08_01_subquery_grundlagen.ipynb)
- 🎥 **YouTube:**  
  - [SQL Subqueries Basics](https://www.youtube.com/results?search_query=sql+server+subquery+tutorial)
- 📘 **Docs:**  
  - [Subqueries (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/queries/subqueries)

---

### 2.2 | `EXISTS` vs. `IN` vs. `JOIN` (Semi-/Anti-Join)
> **Kurzbeschreibung:** Korrektheits- & Performanceaspekte; `NOT EXISTS` statt `NOT IN` bei `NULL`-Risiken.

- 📓 **Notebook:**  
  [`08_02_exists_in_join_patterns.ipynb`](08_02_exists_in_join_patterns.ipynb)
- 🎥 **YouTube:**  
  - [EXISTS vs IN Explained](https://www.youtube.com/results?search_query=sql+server+exists+vs+in)
- 📘 **Docs:**  
  - [`EXISTS` (T-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/exists-transact-sql) ・ [`IN` (T-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/in-transact-sql)

---

### 2.3 | Korrelierte Unterabfragen – Chancen & Risiken
> **Kurzbeschreibung:** Zeilenweise Auswertung; typische Rewrites zu `APPLY`/`JOIN`; Top-1-pro-Gruppe.

- 📓 **Notebook:**  
  [`08_03_correlated_subqueries.ipynb`](08_03_correlated_subqueries.ipynb)
- 🎥 **YouTube:**  
  - [Correlated Subqueries](https://www.youtube.com/results?search_query=sql+server+correlated+subquery)
- 📘 **Docs:**  
  - [Subqueries – Correlated](https://learn.microsoft.com/en-us/sql/t-sql/queries/subqueries#correlated-subqueries)

---

### 2.4 | Abgeleitete Tabellen & Mehrfachverwendung
> **Kurzbeschreibung:** `(SELECT …) d` im `FROM`, Aliaspflicht, Limitierungen, Vergleich zu CTE.

- 📓 **Notebook:**  
  [`08_04_derived_tables_vs_cte.ipynb`](08_04_derived_tables_vs_cte.ipynb)
- 🎥 **YouTube:**  
  - [Derived Tables Tutorial](https://www.youtube.com/results?search_query=sql+server+derived+table)
- 📘 **Docs:**  
  - [FROM – Subqueries as Derived Tables](https://learn.microsoft.com/en-us/sql/t-sql/queries/from-transact-sql)

---

### 2.5 | CTE `WITH` – Syntax, Scope & Ketten
> **Kurzbeschreibung:** Mehrere CTEs, nur **nächstes Statement** sichtbar, Lesbarkeit/Komposition.

- 📓 **Notebook:**  
  [`08_05_cte_basics.ipynb`](08_05_cte_basics.ipynb)
- 🎥 **YouTube:**  
  - [Common Table Expressions Basics](https://www.youtube.com/results?search_query=sql+server+cte+tutorial)
- 📘 **Docs:**  
  - [`WITH` common_table_expression](https://learn.microsoft.com/en-us/sql/t-sql/queries/with-common-table-expression-transact-sql)

---

### 2.6 | Rekursive CTEs – Hierarchien & Graphen
> **Kurzbeschreibung:** Anchor/Recursive-Member, Zyklenkontrolle, `MAXRECURSION`.

- 📓 **Notebook:**  
  [`08_06_recursive_cte_hierarchies.ipynb`](08_06_recursive_cte_hierarchies.ipynb)
- 🎥 **YouTube:**  
  - [Recursive CTE Demo](https://www.youtube.com/results?search_query=sql+server+recursive+cte)
- 📘 **Docs:**  
  - [Recursive CTE – Beispiele & `MAXRECURSION`](https://learn.microsoft.com/en-us/sql/t-sql/queries/with-common-table-expression-transact-sql#guidelines-for-using-recursive-common-table-expressions)

---

### 2.7 | CTE + Fensterfunktionen (`OVER()`)
> **Kurzbeschreibung:** Rankings/Aggregate in CTE vorrechnen, danach filtern/materialisieren.

- 📓 **Notebook:**  
  [`08_07_cte_with_window_functions.ipynb`](08_07_cte_with_window_functions.ipynb)
- 🎥 **YouTube:**  
  - [CTE with Window Functions](https://www.youtube.com/results?search_query=sql+server+cte+window+functions)
- 📘 **Docs:**  
  - [Window Functions (`OVER`) Übersicht](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-over-clause-transact-sql)

---

### 2.8 | `APPLY` statt korrelierter Subqueries
> **Kurzbeschreibung:** `CROSS/OUTER APPLY` mit TVFs/Inline-Views; Top-N-pro-Gruppe ohne korrelierte Subquery.

- 📓 **Notebook:**  
  [`08_08_apply_patterns.ipynb`](08_08_apply_patterns.ipynb)
- 🎥 **YouTube:**  
  - [CROSS APPLY Patterns](https://www.youtube.com/results?search_query=sql+server+cross+apply+examples)
- 📘 **Docs:**  
  - [`APPLY`-Operator](https://learn.microsoft.com/en-us/sql/t-sql/queries/from-transact-sql#apply-operator)

---

### 2.9 | Temp-Tabelle `#temp` – wann & wie?
> **Kurzbeschreibung:** Erstellen (`CREATE`/`SELECT INTO`), **Statistiken/Indizes**, Wiederverwendung über mehrere Statements.

- 📓 **Notebook:**  
  [`08_09_temp_tables_basics.ipynb`](08_09_temp_tables_basics.ipynb)
- 🎥 **YouTube:**  
  - [Temp Tables Explained](https://www.youtube.com/results?search_query=sql+server+temp+tables)
- 📘 **Docs:**  
  - [TempDB & Temporary Tables](https://learn.microsoft.com/en-us/sql/relational-databases/databases/tempdb-database)

---

### 2.10 | Tabellenvariablen `@t` – Eigenschaften & Grenzen
> **Kurzbeschreibung:** Scope, **keine Auto-Stats**, Indizes via PK/UNIQUE; **SQL 2019: Deferred Compilation** für bessere Pläne.

- 📓 **Notebook:**  
  [`08_10_table_variables_basics.ipynb`](08_10_table_variables_basics.ipynb)
- 🎥 **YouTube:**  
  - [Table Variables vs Temp Tables](https://www.youtube.com/results?search_query=sql+server+table+variables+vs+temp+tables)
- 📘 **Docs:**  
  - [Table Variables – Referenz](https://learn.microsoft.com/en-us/sql/t-sql/data-types/table-transact-sql) ・ [Deferred Compilation for Table Variables](https://learn.microsoft.com/en-us/sql/relational-databases/performance/intelligent-query-processing-feedback#table-variable-deferred-compilation)

---

### 2.11 | `SELECT INTO` vs. `CREATE TABLE` + `INSERT`
> **Kurzbeschreibung:** Schnelles Prototyping vs. Kontrolle über Typen/Indizes/Nullability; Auswirkungen auf Stats/Recompiles.

- 📓 **Notebook:**  
  [`08_11_select_into_vs_create_insert.ipynb`](08_11_select_into_vs_create_insert.ipynb)
- 🎥 **YouTube:**  
  - [SELECT INTO Tips](https://www.youtube.com/results?search_query=sql+server+select+into+temp+table)
- 📘 **Docs:**  
  - [`SELECT INTO`](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-into-clause-transact-sql)

---

### 2.12 | Performance: Schätzungen, Stats & Recompiles
> **Kurzbeschreibung:** Warum `#temp` oft bessere Pläne liefert (Stats), `OPTION (RECOMPILE)`-Muster, große Ketten in CTE/Derived vs. Materialisieren.

- 📓 **Notebook:**  
  [`08_12_perf_stats_recompile.ipynb`](08_12_perf_stats_recompile.ipynb)
- 🎥 **YouTube:**  
  - [Recompiles & Temp Tables](https://www.youtube.com/results?search_query=sql+server+recompile+temp+tables)
- 📘 **Docs:**  
  - [Statistics – Overview](https://learn.microsoft.com/en-us/sql/relational-databases/statistics/statistics)

---

### 2.13 | Wiederverwendung & Mehrfachzugriffe
> **Kurzbeschreibung:** Ein CTE gilt **einmal**; bei Mehrfachnutzung/Indexbedarf → `#temp`. Lese-/Schreibmischung beachten.

- 📓 **Notebook:**  
  [`08_13_reuse_vs_materialize.ipynb`](08_13_reuse_vs_materialize.ipynb)
- 🎥 **YouTube:**  
  - [When to Materialize](https://www.youtube.com/results?search_query=sql+server+cte+vs+temp+table+when)
- 📘 **Docs:**  
  - [CTE – Scope & Usage](https://learn.microsoft.com/en-us/sql/t-sql/queries/with-common-table-expression-transact-sql#remarks)

---

### 2.14 | `NOT IN`/`NULL`-Fallen & sichere Anti-Joins
> **Kurzbeschreibung:** Dreiwertige Logik verstehen; sichere Alternativen mit `NOT EXISTS`/`EXCEPT`.

- 📓 **Notebook:**  
  [`08_14_not_in_null_pitfalls.ipynb`](08_14_not_in_null_pitfalls.ipynb)
- 🎥 **YouTube:**  
  - [NOT IN and NULLs](https://www.youtube.com/results?search_query=sql+server+not+in+null)
- 📘 **Docs:**  
  - [`EXCEPT` / `INTERSECT`](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/set-operators-union-transact-sql)

---

### 2.15 | TempDB-Monitoring & Speicherverbrauch
> **Kurzbeschreibung:** DMVs für Session/Task-Space, Hotspots erkennen (`sys.dm_db_session_space_usage`, `sys.dm_db_task_space_usage`).

- 📓 **Notebook:**  
  [`08_15_tempdb_monitoring_dmvs.ipynb`](08_15_tempdb_monitoring_dmvs.ipynb)
- 🎥 **YouTube:**  
  - [Monitor tempdb Usage](https://www.youtube.com/results?search_query=sql+server+monitor+tempdb+usage)
- 📘 **Docs:**  
  - [Monitor tempdb Space Usage](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-task-space-usage-transact-sql)

---

### 2.16 | Anti-Patterns & Checkliste
> **Kurzbeschreibung:** `NOT IN` mit `NULL`, riesige korrelierte Subqueries, tiefe CTE-Ketten ohne Indizes, `@t` für große Mengen, `SELECT *` in CTE/Derived, fehlende Indizes auf `#temp`, unendliche Rekursionen ohne Stopbedingung.

- 📓 **Notebook:**  
  [`08_16_subquery_cte_temp_antipatterns.ipynb`](08_16_subquery_cte_temp_antipatterns.ipynb)
- 🎥 **YouTube:**  
  - [Common CTE/Subquery Mistakes](https://www.youtube.com/results?search_query=sql+server+cte+subquery+mistakes)
- 📘 **Docs/Blog:**  
  - [CTE Guidelines & MAXRECURSION](https://learn.microsoft.com/en-us/sql/t-sql/queries/with-common-table-expression-transact-sql#guidelines-for-using-recursive-common-table-expressions)

---

## 3 | Weiterführende Informationen

- 📘 Microsoft Learn: [Subqueries (T-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/queries/subqueries)  
- 📘 Microsoft Learn: [`WITH` common_table_expression](https://learn.microsoft.com/en-us/sql/t-sql/queries/with-common-table-expression-transact-sql)  
- 📘 Microsoft Learn: [`EXISTS` / `IN` / `ANY|ALL`](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/in-transact-sql)  
- 📘 Microsoft Learn: [`APPLY`-Operator](https://learn.microsoft.com/en-us/sql/t-sql/queries/from-transact-sql#apply-operator)  
- 📘 Microsoft Learn: [`SELECT INTO`](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-into-clause-transact-sql)  
- 📘 Microsoft Learn: [`table`-Datentyp (Tabellenvariablen)](https://learn.microsoft.com/en-us/sql/t-sql/data-types/table-transact-sql)  
- 📘 Microsoft Learn: [Intelligent Query Processing – **Table Variable Deferred Compilation**](https://learn.microsoft.com/en-us/sql/relational-databases/performance/intelligent-query-processing-feedback#table-variable-deferred-compilation)  
- 📘 Microsoft Learn: [Statistics – Concepts & Management](https://learn.microsoft.com/en-us/sql/relational-databases/statistics/statistics)  
- 📘 Microsoft Learn: [tempdb – Überblick & Best Practices](https://learn.microsoft.com/en-us/sql/relational-databases/databases/tempdb-database)  
- 📘 Microsoft Learn: [DMVs: `sys.dm_db_session_space_usage` / `sys.dm_db_task_space_usage`](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-task-space-usage-transact-sql)  
- 📝 Itzik Ben-Gan: *Top-N-per-Group mit APPLY/Windowing* – Sammlung  
- 📝 Paul White (SQL Kiwi): *APPLY, CTEs & Execution Plans* – https://www.sql.kiwi/  
- 📝 SQLPerformance: *Temp Tables vs Table Variables – Schätzungen & Recompiles* – https://www.sqlperformance.com/?s=table+variable  
- 📝 Brent Ozar: *When to use Temp Tables vs CTEs* – https://www.brentozar.com/  
- 📝 Erik Darling: *NOT IN & NULLs, EXISTS Patterns* – https://www.erikdarlingdata.com/  
- 📝 Redgate Simple Talk: *Working with CTEs & Recursive Queries* – https://www.red-gate.com/simple-talk/  
- 🎥 YouTube (Data Exposed): *CTEs, APPLY & Temp Objects* – Suchlink  
- 🎥 YouTube Playlist: *Subqueries & CTEs – Best Practices* – Suchlink  
