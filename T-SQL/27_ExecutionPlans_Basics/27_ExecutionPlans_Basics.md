# T-SQL Execution Plans – Basics  
*Execution Plans lesen & verstehen, Kardinalitätsschätzung (CE)*

## 1 | Begriffsdefinition

| SQL-Term | Beschreibung |
|---|---|
| Ausführungsplan (Execution Plan) | Vom Optimizer gewählter **physischer Plan** (Operator-Baum) zur Ausführung einer Abfrage; als **Estimated** oder **Actual** verfügbar. |
| Estimated vs. Actual | *Estimated* zeigt **Schätzungen** (Kosten/Zeilenzahlen); *Actual* ergänzt **Istwerte** (gelesene/ausgegebene Zeilen, Warnungen). |
| Operator | Knoten im Plan (z. B. **Index Seek/Scan, Key Lookup, Hash Match, Sort, Nested Loops, Merge Join, Parallelism**). |
| Seek-/Residual Predicate | **Seek-Predicate** nutzt Schlüssel für zielgerichteten Zugriff; **Residual** wird nachgeladen (Filter auf Zeilen nach Zugriff). |
| Key/RID Lookup | Nachschlagen weiterer Spalten aus CI/Heap; teuer bei vielen Treffern („Tipping Point“). |
| CE (Cardinality Estimator) | Modell zur **Zeilenanzahl-Schätzung**; beeinflusst Join-/Operatorwahl & Memory Grants. |
| Statistiken | Histogramm/Dichte je Spalte/Index; Grundlage für CE-Schätzungen (`AUTO_CREATE/UPDATE STATISTICS`). |
| Memory Grant | Zugeteilter Arbeitsspeicher für Sort/Hash; **Spills** bei Untergrant → TempDB-Auslagerung. |
| Parallelism | Austausch-Operatoren (**Distribute/Repartition/Gather Streams**), DOP, mögliche Skews. |
| Row Goal | Vom Optimizer abgeleitetes Ziel (z. B. `TOP`), beeinflusst Planwahl (z. B. Nested Loops). |
| Adaptive/Batch Mode (IQP) | Moderne Features wie **Adaptive Join**, **Memory Grant Feedback**, **Batch Mode on Rowstore** verbessern Pläne zur Laufzeit. |
| Parameter Sniffing | Plan auf Basis **erster** Parameter kompiliert; kann später unpassend sein (Fix: Hints/Recompile/Design). |
| Plan Cache/Handles | Zwischengespeicherte Pläne (`sys.dm_exec_query_stats`, `sys.dm_exec_query_plan`) – Wiederverwendung/Regressionen analysieren. |
| Showplan-Formate | Grafisch (SSMS), **XML** (`STATISTICS XML`, `SHOWPLAN_XML`), Text/Profile (Legacy). |

---

## 2 | Struktur

### 2.1 | Einstieg: Estimated vs. Actual Plan, XML & Live Stats
> **Kurzbeschreibung:** Wo Pläne herkommen, Unterschiede Estimated/Actual, XML öffnen/lesen, Live Query Statistics.

- 📓 **Notebook:**  
  [`08_01_estimated_vs_actual_plan.ipynb`](08_01_estimated_vs_actual_plan.ipynb)
- 🎥 **YouTube:**  
  - [Estimated vs Actual Plan](https://www.youtube.com/results?search_query=sql+server+estimated+vs+actual+execution+plan)
- 📘 **Docs:**  
  - [Display the Actual/Estimated Execution Plan](https://learn.microsoft.com/en-us/sql/relational-databases/performance/display-the-actual-execution-plan)

---

### 2.2 | Operatoren lesen: Seek/Scan/Lookup & Predicates
> **Kurzbeschreibung:** Index Seek/Scan, Key/RID Lookup, **Seek-** vs. **Residual Predicate**, ORDER/Top/Row Goal.

- 📓 **Notebook:**  
  [`08_02_operators_seek_scan_lookup.ipynb`](08_02_operators_seek_scan_lookup.ipynb)
- 🎥 **YouTube:**  
  - [Index Seek vs Scan](https://www.youtube.com/results?search_query=sql+server+index+seek+vs+scan)
- 📘 **Docs:**  
  - [Logical and Physical Showplan Operators](https://learn.microsoft.com/en-us/sql/relational-databases/showplan-logical-and-physical-operators-reference)

---

### 2.3 | Join-Algorithmen: Nested Loops, Merge, Hash
> **Kurzbeschreibung:** Auswahlkriterien (Sortierung, Kardinalität, Selektivität), typische Kosten-/Datenmuster.

- 📓 **Notebook:**  
  [`08_03_join_algorithms_plans.ipynb`](08_03_join_algorithms_plans.ipynb)
- 🎥 **YouTube:**  
  - [Join Algorithms Explained](https://www.youtube.com/results?search_query=sql+server+join+algorithms+execution+plan)
- 📘 **Docs:**  
  - [Showplan Operators – Joins](https://learn.microsoft.com/en-us/sql/relational-databases/showplan-logical-and-physical-operators-reference#join-operators)

---

### 2.4 | Sort/Hash/Aggregate & TempDB-Spills
> **Kurzbeschreibung:** Erkennen von **Spills** (Hash/Sort Warnings), Ursachen (Grant/CE), Gegenmaßnahmen.

- 📓 **Notebook:**  
  [`08_04_sort_hash_aggregate_spills.ipynb`](08_04_sort_hash_aggregate_spills.ipynb)
- 🎥 **YouTube:**  
  - [Hash/Sort Spill Warnings](https://www.youtube.com/results?search_query=sql+server+hash+sort+spill+execution+plan)
- 📘 **Docs:**  
  - [Actual Execution Plan – Warnings](https://learn.microsoft.com/en-us/sql/relational-databases/performance/execution-plan-warnings)

---

### 2.5 | Kardinalitätsschätzung – Grundlagen & Statistiken
> **Kurzbeschreibung:** Histogramm/Dichte, Unabhängigkeitsannahme, Korrelation, Ascending-Key-Problem.

- 📓 **Notebook:**  
  [`08_05_cardinality_estimation_basics.ipynb`](08_05_cardinality_estimation_basics.ipynb)
- 🎥 **YouTube:**  
  - [Cardinality Estimation Basics](https://www.youtube.com/results?search_query=sql+server+cardinality+estimation)
- 📘 **Docs:**  
  - [Statistics – Overview](https://learn.microsoft.com/en-us/sql/relational-databases/statistics/statistics)

---

### 2.6 | CE-Versionen & Konfiguration (Legacy vs. Modern)
> **Kurzbeschreibung:** Legacy CE vs. CE 120/130/140/150+, DB-scoped Config `LEGACY_CARDINALITY_ESTIMATION`, Compat Level, Query Hints.

- 📓 **Notebook:**  
  [`08_06_ce_versions_config.ipynb`](08_06_ce_versions_config.ipynb)
- 🎥 **YouTube:**  
  - [Legacy vs New CE](https://www.youtube.com/results?search_query=sql+server+legacy+cardinality+estimator)
- 📘 **Docs:**  
  - [Cardinality Estimation (SQL Server)](https://learn.microsoft.com/en-us/sql/relational-databases/performance/cardinality-estimation-sql-server)

---

### 2.7 | Parameter Sniffing & Sensitivität
> **Kurzbeschreibung:** Symptome im Plan (Actual vs Estimated Rows), Gegenmaßnahmen: `OPTIMIZE FOR`, `RECOMPILE`, Split-Procs/Views, iTVF.

- 📓 **Notebook:**  
  [`08_07_parameter_sniffing_signs_fixes.ipynb`](08_07_parameter_sniffing_signs_fixes.ipynb)
- 🎥 **YouTube:**  
  - [Parameter Sniffing Demo](https://www.youtube.com/results?search_query=sql+server+parameter+sniffing+demo)
- 📘 **Docs:**  
  - [Query Hints (`OPTIMIZE FOR`, `RECOMPILE`)](https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-query)

---

### 2.8 | Memory Grants & Feedback
> **Kurzbeschreibung:** Lesen/Deuten von `MemoryGrantInfo`, Under/Over Grant, **Memory Grant Feedback** (Row/Batch Mode).

- 📓 **Notebook:**  
  [`08_08_memory_grants_feedback.ipynb`](08_08_memory_grants_feedback.ipynb)
- 🎥 **YouTube:**  
  - [Memory Grants Explained](https://www.youtube.com/results?search_query=sql+server+memory+grant+feedback)
- 📘 **Docs:**  
  - [Intelligent Query Processing – Memory Grant Feedback](https://learn.microsoft.com/en-us/sql/relational-databases/performance/intelligent-query-processing-feedback#memory-grant-feedback)

---

### 2.9 | Parallelismus im Plan
> **Kurzbeschreibung:** Exchange-Operatoren, DOP, Skew erkennen, Kosten vs. Latenz, Hinweise (`MAXDOP`, `COST THRESHOLD`).

- 📓 **Notebook:**  
  [`08_09_parallelism_exchange_operators.ipynb`](08_09_parallelism_exchange_operators.ipynb)
- 🎥 **YouTube:**  
  - [Parallelism Operators](https://www.youtube.com/results?search_query=sql+server+parallelism+execution+plan)
- 📘 **Docs:**  
  - [Configure max degree of parallelism](https://learn.microsoft.com/en-us/sql/database-engine/configure-windows/configure-the-max-degree-of-parallelism-server-configuration-option)

---

### 2.10 | Row Goals, TOP & Tipping Point
> **Kurzbeschreibung:** Wie `TOP/OPTION(FAST N)` Planwahl (Loops) steuern; „Tipping Point“ für Lookups/Covering.

- 📓 **Notebook:**  
  [`08_10_row_goals_top_tipping_point.ipynb`](08_10_row_goals_top_tipping_point.ipynb)
- 🎥 **YouTube:**  
  - [Row Goals & FAST N](https://www.youtube.com/results?search_query=sql+server+row+goal+fast+n)
- 📘 **Docs:**  
  - [Execution Plan Tips – Row Goal](https://learn.microsoft.com/en-us/sql/relational-databases/performance/actual-execution-plan#row-goal)

---

### 2.11 | Showplan-XML & Plan-Attribute lesen
> **Kurzbeschreibung:** `EstimateRows`, `ActualRows`, `EstimatedRowsRead`, `ParameterList` (Compiled/Runtime), Warnings.

- 📓 **Notebook:**  
  [`08_11_showplan_xml_attributes.ipynb`](08_11_showplan_xml_attributes.ipynb)
- 🎥 **YouTube:**  
  - [Read Showplan XML](https://www.youtube.com/results?search_query=sql+server+showplan+xml)
- 📘 **Docs:**  
  - [Showplan XML Schema](https://learn.microsoft.com/en-us/sql/relational-databases/showplan/showplan-xml-schema-structure)

---

### 2.12 | Plan-Erzeugung: Trivial vs. Full Optimization
> **Kurzbeschreibung:** Trivial Plan, Timeout im Optimizer, Stufe/Phase, `QUERY_OPTIMIZER_COMPATIBILITY_LEVEL_*`-Hints.

- 📓 **Notebook:**  
  [`08_12_trivial_vs_full_optimization.ipynb`](08_12_trivial_vs_full_optimization.ipynb)
- 🎥 **YouTube:**  
  - [Trivial Plan vs Full Opt](https://www.youtube.com/results?search_query=sql+server+trivial+plan)
- 📘 **Docs:**  
  - [Query Processing Architecture Guide](https://learn.microsoft.com/en-us/sql/relational-databases/query-processing-architecture-guide)

---

### 2.13 | DMVs: Pläne & Laufzeitstatistiken
> **Kurzbeschreibung:** `sys.dm_exec_query_stats`, `sys.dm_exec_query_plan`, `sys.dm_exec_sql_text`, `query_hash/plan_hash`.

- 📓 **Notebook:**  
  [`08_13_dmvs_plans_runtime.ipynb`](08_13_dmvs_plans_runtime.ipynb)
- 🎥 **YouTube:**  
  - [DMVs for Plans](https://www.youtube.com/results?search_query=sql+server+dmv+execution+plans)
- 📘 **Docs:**  
  - [`sys.dm_exec_query_stats`](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-query-stats-transact-sql)

---

### 2.14 | Query Store – Pläne beobachten & forcieren
> **Kurzbeschreibung:** Capture/Regressionsanalyse, **Plan Forcing**, War Stories.

- 📓 **Notebook:**  
  [`08_14_query_store_forcing.ipynb`](08_14_query_store_forcing.ipynb)
- 🎥 **YouTube:**  
  - [Query Store Basics](https://www.youtube.com/results?search_query=sql+server+query+store+plan+forcing)
- 📘 **Docs:**  
  - [Use the Query Store](https://learn.microsoft.com/en-us/sql/relational-databases/performance/monitoring-performance-by-using-the-query-store)

---

### 2.15 | IQP-Features: Adaptive Join, Interleaved Exec, Batch Mode
> **Kurzbeschreibung:** Wann und wie der Plan sich **zur Laufzeit** anpasst; Voraussetzungen & Plan-Anzeige.

- 📓 **Notebook:**  
  [`08_15_iqp_adaptive_batchmode.ipynb`](08_15_iqp_adaptive_batchmode.ipynb)
- 🎥 **YouTube:**  
  - [Adaptive Joins & Batch Mode](https://www.youtube.com/results?search_query=sql+server+adaptive+join+batch+mode)
- 📘 **Docs:**  
  - [Intelligent Query Processing Family](https://learn.microsoft.com/en-us/sql/relational-databases/performance/intelligent-query-processing)

---

### 2.16 | Anti-Patterns & Checkliste beim Planlesen
> **Kurzbeschreibung:** **Nur** auf Kosten schauen, Ist-/Soll-Zeilen ignorieren, Warnings übersehen, CE/Stats vernachlässigen, falsche Schlüsse aus Seek/Scan.

- 📓 **Notebook:**  
  [`08_16_execution_plans_anti_patterns.ipynb`](08_16_execution_plans_anti_patterns.ipynb)
- 🎥 **YouTube:**  
  - [Common Execution Plan Mistakes](https://www.youtube.com/results?search_query=sql+server+execution+plan+mistakes)
- 📘 **Docs/Blog:**  
  - [Execution Plan – Best Practices](https://learn.microsoft.com/en-us/sql/relational-databases/performance/actual-execution-plan)

---

## 3 | Weiterführende Informationen

- 📘 Microsoft Learn: [Query Processing Architecture Guide](https://learn.microsoft.com/en-us/sql/relational-databases/query-processing-architecture-guide)  
- 📘 Microsoft Learn: [Showplan Operators Reference](https://learn.microsoft.com/en-us/sql/relational-databases/showplan-logical-and-physical-operators-reference)  
- 📘 Microsoft Learn: [Statistics – Concepts & Management](https://learn.microsoft.com/en-us/sql/relational-databases/statistics/statistics)  
- 📘 Microsoft Learn: [Cardinality Estimation (CE)](https://learn.microsoft.com/en-us/sql/relational-databases/performance/cardinality-estimation-sql-server)  
- 📘 Microsoft Learn: [Execution Plan Warnings (Spills/Conversions/Missing Index)](https://learn.microsoft.com/en-us/sql/relational-databases/performance/execution-plan-warnings)  
- 📘 Microsoft Learn: [Query Store – Monitor & Force Plans](https://learn.microsoft.com/en-us/sql/relational-databases/performance/monitoring-performance-by-using-the-query-store)  
- 📘 Microsoft Learn: [Intelligent Query Processing (Adaptive, Feedback, Batch Mode)](https://learn.microsoft.com/en-us/sql/relational-databases/performance/intelligent-query-processing)  
- 📘 Microsoft Learn: [Showplan XML – Schema/Attributes](https://learn.microsoft.com/en-us/sql/relational-databases/showplan/showplan-xml-schema-structure)  
- 📝 Paul White (SQL Kiwi): *Execution Plans & CE Deep Dives* – https://www.sql.kiwi/  
- 📝 SQLPerformance: *Parameter Sniffing, Memory Grants, Spills* – https://www.sqlperformance.com/?s=execution+plan  
- 📝 Brent Ozar: *How to Read Execution Plans* – https://www.brentozar.com/  
- 📝 Erik Darling: *Plan Triage & Fixes* – https://www.erikdarlingdata.com/  
- 📝 Itzik Ben-Gan: *Understanding the Optimizer & CE* – https://tsql.solidq.com/  
- 🎥 YouTube Playlist: *Execution Plans & Query Tuning* – (Suche)  
