# T-SQL – 64_PerformanceTuning_Advanced – Übersicht

Erweiterte Performance-Optimierung mit Fokus auf Query Store, Parameter Sniffing & Intelligent Query Processing (SQL Server 2016–2022 / Azure SQL).

---

## 1 | Begriffsdefinition

| SQL-Term | Beschreibung |
|---|---|
| Query Store (QS) | Datenbankweite Historisierung von Abfragen, Plänen & Laufzeitmetriken; Plan-Erzwingung (force/unforce), Wartezeit-Erfassung, automatische Plan-Korrektur. |
| QS Capture Mode (ALL/AUTO/CUSTOM) | Steuerung, welche Abfragen erfasst werden (z. B. Schwellenwerte bei CUSTOM). |
| Plan Forcing | Erzwingung eines bestimmten Ausführungsplans für eine Query über Query Store (manuell oder automatisch). |
| Automatic Plan Correction (FGLP) | „FORCE_LAST_GOOD_PLAN“ – erkennt Planregressionen und erzwingt den letzten guten Plan (abhängig von aktivem Query Store). |
| Query Store Hints (SQL 2022+) | Hints wie `MAXDOP`, `OPTIMIZE FOR`, `USE HINT(...)` ohne Codeänderung per `sp_query_store_set_hints`. |
| Parameter Sniffing | Optimierer verwendet beim Kompilieren konkrete Parameterwerte → Plan passt evtl. nicht für andere Werteverteilungen. |
| Parameter Sensitive Plan (PSP, SQL 2022+) | Mehrere Pläne pro parameterisiertem Statement je nach Parameterklassen zur Entschärfung von Parameter-Sniffing. |
| Database Scoped Configuration | DB-weite Schalter wie `PARAMETER_SNIFFING`, `QUERY_OPTIMIZER_HOTFIXES`, `OPTIMIZE_FOR_AD_HOC_WORKLOADS`, `CLEAR PROCEDURE_CACHE`. |
| `OPTIMIZE FOR` | Query-Hint zur Festlegung von Kompilierwerten; `OPTIMIZE FOR UNKNOWN` nutzt Statistiken statt konkreter Werte. |
| `OPTION (RECOMPILE)` | Kompiliert bei jedem Lauf neu (umgeht Cache/Param-Sniffing, erhöht CPU/Kompilierkosten). |
| Plan Guides | Ältere Technik zur Hint-Erzwingung ohne Codeänderung; seit SQL 2022 oft durch QS Hints ersetzbar. |
| Plan Cache | Zwischenspeicherung kompilierter Pläne; Analyse via `sys.dm_exec_query_stats`, `sys.dm_exec_cached_plans` etc. |
| DBCC FREEPROCCACHE / CLEAR PROCEDURE_CACHE | Gezieltes/komplettes Löschen aus dem Plancache (mit Bedacht einsetzen!). |
| Cardinality Estimator (CE) & Compat Level | CE-Modell variiert mit Kompatibilitätsstufe; beeinflusst Schätzungen & Plansuche. |
| Intelligent Query Processing (IQP) | Feature-Familie: z. B. Memory Grant Feedback, Table Variable Deferred Compilation, Scalar UDF Inlining, Batch Mode on Rowstore, PSP, DOP Feedback. |
| Memory Grant Feedback | Passt überhöhte/zu geringe Speicherzuteilung für wiederkehrende Queries an. |
| DOP Feedback (SQL 2022+) | Passt MaxDOP für wiederkehrende Queries dynamisch an. |
| Batch Mode on Rowstore (SQL 2019+) | Batchausführung auch ohne Columnstore → oft massiver Speedup für analytische Scans. |
| Scalar UDF Inlining (SQL 2019+) | Inlinet skalare UDFs in relationale Pläne → weniger RBAR-Kosten. |
| Statistikoptionen | `AUTO_UPDATE_STATISTICS[_ASYNC]`, inkrementelle/gefilt. Statistiken, sampled vs. fullscan. |
| Parameterization (SIMPLE/FORCED) | Erzwingt Parametrisierung für Ad-hoc-Workloads; beeinflusst Planvielfalt & Reuse. |
| Optimize for Ad Hoc Workloads | (Server- & DB-Scope) Speichert bei Erstlauf nur Plan-Stub → weniger Cache-Druck bei Single-Use-Plänen. |
| Wait Statistics | Ursachenanalyse über `sys.dm_os_wait_stats` und Query-Store-Waits pro Query. |

---

## 2 | Struktur

### 2.1 | Query Store – Aktivierung, Capture & Grundprinzip
> **Kurzbeschreibung:** Einrichtung in `READ_WRITE`, Wahl des Capture-Modus (ALL/AUTO/CUSTOM), Speichergrenzen & Cleanup-Politik; QS ist in SQL Server 2022 für neue DBs standardmäßig aktiv.

- 📓 **Notebook:**  
  [`08_01_query_store_setup.ipynb`](08_01_query_store_setup.ipynb)

- 🎥 **YouTube:**  
  - [Why You Need Query Store (Erin Stellato)](https://www.youtube.com/watch?v=WBy4FPlL0EA)  
  - [Query Store Best Practices (Session)](https://www.youtube.com/watch?v=RKnoeIVwSRk)

- 📘 **Docs:**  
  - [Monitoring performance by using Query Store](https://learn.microsoft.com/en-us/sql/relational-databases/performance/monitoring-performance-by-using-the-query-store)  
  - [Query Store options & CUSTOM capture](https://learn.microsoft.com/en-us/sql/relational-databases/performance/manage-the-query-store)

---

### 2.2 | Query Store – Plan Forcing & Automatische Plan-Korrektur
> **Kurzbeschreibung:** Manuelles `sp_query_store_force_plan`/`...unforce_plan`, Plan-Forcing-Grenzen & Fehlerdiagnose; automatische Korrektur („Last Good Plan“).

- 📓 **Notebook:**  
  [`08_02_query_store_plan_forcing.ipynb`](08_02_query_store_plan_forcing.ipynb)

- 🎥 **YouTube:**  
  - [Stabilizing Performance with Query Store](https://www.youtube.com/watch?v=D7K2mswbZUE)  
  - [Accelerate query performance (Optimized Plan Forcing, SQL 2022)](https://www.youtube.com/watch?v=FKLFgJgETsw)

- 📘 **Docs:**  
  - [`sp_query_store_force_plan`](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-query-store-force-plan-transact-sql)  
  - [Automatic tuning / plan correction](https://learn.microsoft.com/en-us/sql/relational-databases/automatic-tuning/automatic-tuning)

---

### 2.3 | Query Store Hints (SQL 2022+) – Hints ohne Codeänderung
> **Kurzbeschreibung:** Hints per `sp_query_store_set_hints` (z. B. `MAXDOP`, `OPTIMIZE FOR`, `USE HINT`), Governance & Replikagruppen.

- 📓 **Notebook:**  
  [`08_03_query_store_hints.ipynb`](08_03_query_store_hints.ipynb)

- 🎥 **YouTube:**  
  - [Mitigate performance problems using Query Store hints](https://www.youtube.com/watch?v=NZVHIzuW7aE)  
  - [Using Query Store Hints to Stabilize Query Performance](https://www.youtube.com/watch?v=suCY9jYu0CA)

- 📘 **Docs:**  
  - [Query Store Hints](https://learn.microsoft.com/en-us/sql/relational-databases/performance/query-store-hints)  
  - [`sys.sp_query_store_set_hints`](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sys-sp-query-store-set-hints-transact-sql)

---

### 2.4 | Parameter Sniffing – Erkennen & schnelle Gegenmaßnahmen
> **Kurzbeschreibung:** Symptome in Plänen/DMVs, kurzfristige Abhilfen: `RECOMPILE`, `OPTIMIZE FOR UNKNOWN`, lokale Variablen (mit Trade-offs).

- 📓 **Notebook:**  
  [`08_04_parameter_sniffing_basics.ipynb`](08_04_parameter_sniffing_basics.ipynb)

- 🎥 **YouTube:**  
  - [Identifying & Fixing Parameter Sniffing (Brent Ozar)](https://www.youtube.com/watch?v=pd7xqLT_-2k)  
  - [How to Stop Parameter Sniffing](https://www.youtube.com/watch?v=qo9iWKYqJDA)

- 📘 **Docs:**  
  - [Query hints – `OPTIMIZE FOR`](https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-query)  
  - [Recompile a Stored Procedure / `OPTION(RECOMPILE)`](https://learn.microsoft.com/en-us/sql/relational-databases/stored-procedures/recompile-a-stored-procedure)

---

### 2.5 | Parameter Sensitive Plan (PSP, SQL 2022+)
> **Kurzbeschreibung:** Mehrere Pläne je Parameterklasse bei schiefer Datenverteilung; Aktivierungsbedingungen & Interaktion mit QS.

- 📓 **Notebook:**  
  [`08_05_psp_optimization.ipynb`](08_05_psp_optimization.ipynb)

- 🎥 **YouTube:**  
  - [Intelligent Query Processing in SQL Server 2022 (Data Exposed)](https://www.youtube.com/watch?v=bbXM3Pk9Ejw)  
  - [No-Code Performance Gains with IQP](https://www.youtube.com/watch?v=1j0rXirslU4)

- 📘 **Docs:**  
  - [Parameter Sensitive Plan optimization](https://learn.microsoft.com/en-us/sql/relational-databases/performance/parameter-sensitive-plan-optimization)  
  - [IQP – Übersicht & Details](https://learn.microsoft.com/en-us/sql/relational-databases/performance/intelligent-query-processing)

---

### 2.6 | Database Scoped Configuration – Schalter für Stabilität
> **Kurzbeschreibung:** `PARAMETER_SNIFFING` (ON/OFF), `QUERY_OPTIMIZER_HOTFIXES`, gezieltes `CLEAR PROCEDURE_CACHE`, DB-weises `OPTIMIZE_FOR_AD_HOC_WORKLOADS`.

- 📓 **Notebook:**  
  [`08_06_db_scoped_configuration.ipynb`](08_06_db_scoped_configuration.ipynb)

- 🎥 **YouTube:**  
  - [Query Store & Built-in Intelligence (SQL 2022)](https://www.youtube.com/watch?v=Nd0mKM3O3sQ)  
  - [Query Store Tutorial (Rich Benner)](https://www.youtube.com/watch?v=lTpW6xJpRXs)

- 📘 **Docs:**  
  - [`ALTER DATABASE SCOPED CONFIGURATION`](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-database-scoped-configuration-transact-sql)  
  - [`sys.database_scoped_configurations`](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-scoped-configurations-transact-sql)

---

### 2.7 | Plan Cache & DMVs – fundierte Diagnose
> **Kurzbeschreibung:** `sys.dm_exec_query_stats`, `...cached_plans`, `...query_plan`, `...function_stats`; Identifikation von Regressions, Single-Use-Plänen & Cache-Bloat.

- 📓 **Notebook:**  
  [`08_07_dmvs_plan_cache.ipynb`](08_07_dmvs_plan_cache.ipynb)

- 🎥 **YouTube:**  
  - [Free Training – Brent Ozar: First Responder Kit](https://www.brentozar.com/free-sql-server-training-videos/)  
  - [Parameter Sniffing – Visual Walkthrough](https://www.youtube.com/watch?v=bELe6m_Xa8I)

- 📘 **Docs:**  
  - [`sys.dm_exec_query_stats`](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-query-stats-transact-sql)  
  - [`sys.dm_exec_cached_plans`](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-cached-plans-transact-sql)

---

### 2.8 | Wait Statistics – global & pro Query (Query Store)
> **Kurzbeschreibung:** Top-Waits serverweit (`sys.dm_os_wait_stats`) und QS-Waits pro Query für zielgenaue Ursachenanalyse (I/O, CPU, Latches, Locks).

- 📓 **Notebook:**  
  [`08_08_wait_stats_qs.ipynb`](08_08_wait_stats_qs.ipynb)

- 🎥 **YouTube:**  
  - [Performance Demos – IQP & Feedback Features](https://www.youtube.com/watch?v=HzdLkspncdQ)  
  - [Query Store Reports – Demo](https://www.youtube.com/watch?v=UibSRkU-Egk)

- 📘 **Docs:**  
  - [`sys.query_store_wait_stats`](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-query-store-wait-stats-transact-sql)  
  - [`sys.dm_os_wait_stats`](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-os-wait-stats-transact-sql)

---

### 2.9 | Intelligent Query Processing – Memory/DOP Feedback & Co.
> **Kurzbeschreibung:** Überblick & Praxisnutzen (Memory Grant Feedback, DOP Feedback, Table Variable Deferred Compilation, Approx. Aggregates etc.).

- 📓 **Notebook:**  
  [`08_09_iqp_feedback_features.ipynb`](08_09_iqp_feedback_features.ipynb)

- 🎥 **YouTube:**  
  - [Built-in Query Intelligence (SQL 2022)](https://www.youtube.com/watch?v=Nd0mKM3O3sQ)  
  - [No-Code Performance Gains (IQP)](https://www.youtube.com/watch?v=1j0rXirslU4)

- 📘 **Docs:**  
  - [IQP – Übersicht](https://learn.microsoft.com/en-us/sql/relational-databases/performance/intelligent-query-processing)  
  - [IQP – Details (Batch Mode on Rowstore, Limits)](https://learn.microsoft.com/en-us/sql/relational-databases/performance/intelligent-query-processing-details)

---

### 2.10 | Batch Mode on Rowstore (SQL 2019+)
> **Kurzbeschreibung:** Batchmodus ohne Columnstore zur Beschleunigung analytischer Abfragen über Rowstore; Voraussetzungen & Grenzen.

- 📓 **Notebook:**  
  [`08_10_batch_mode_rowstore.ipynb`](08_10_batch_mode_rowstore.ipynb)

- 🎥 **YouTube:**  
  - [IQP in SQL 2022 – Ep.3](https://www.youtube.com/watch?v=bbXM3Pk9Ejw)  
  - [Query Performance with IQP](https://www.youtube.com/watch?v=FE0VV0Driu0)

- 📘 **Docs:**  
  - [IQP-Details: Batch mode on rowstore](https://learn.microsoft.com/en-us/sql/relational-databases/performance/intelligent-query-processing-details)  
  - [Blog: Introducing Batch Mode on Rowstore](https://techcommunity.microsoft.com/blog/azuresqlblog/introducing-batch-mode-on-rowstore/386256)

---

### 2.11 | Scalar UDF Inlining (SQL 2019+)
> **Kurzbeschreibung:** Automatisches Inlining skalare UDFs → weniger RBAR, bessere Schätzung & Parallelismus; Ausschlüsse & Hints zum Deaktivieren.

- 📓 **Notebook:**  
  [`08_11_scalar_udf_inlining.ipynb`](08_11_scalar_udf_inlining.ipynb)

- 🎥 **YouTube:**  
  - [Intelligent Query Processing – Overview](https://www.youtube.com/watch?v=bbXM3Pk9Ejw)  
  - [IQP Demos](https://www.youtube.com/watch?v=HzdLkspncdQ)

- 📘 **Docs:**  
  - [Scalar UDF Inlining](https://learn.microsoft.com/en-us/sql/relational-databases/user-defined-functions/scalar-udf-inlining)  
  - [KB Fixes & Notes](https://support.microsoft.com/en-us/topic/kb4538581-fix-scalar-udf-inlining-issues-in-sql-server-2022-and-2019-f52d3759-a8b7-a107-1ab9-7fbee264dd5d)

---

### 2.12 | CE & Kompatibilitätsstufe – risikofrei migrieren
> **Kurzbeschreibung:** CE-Wechsel seit 2014 (Level 120+), Regressionskontrolle via Compat-Level/`USE HINT('QUERY_OPTIMIZER_COMPATIBILITY_LEVEL_...')`, Plan-Stabilisierung mit QS.

- 📓 **Notebook:**  
  [`08_12_ce_compat_level.ipynb`](08_12_ce_compat_level.ipynb)

- 🎥 **YouTube:**  
  - [SQL Server 2022: Intelligent Query Processing](https://www.youtube.com/watch?v=ZDDF0-pVAzE)  
  - [IQP in SQL 2022 – Ep.3](https://www.youtube.com/watch?v=bbXM3Pk9Ejw)

- 📘 **Docs:**  
  - [Cardinality Estimation – Überblick](https://learn.microsoft.com/en-us/sql/relational-databases/performance/cardinality-estimation-sql-server)  
  - [Query hints incl. `QUERY_OPTIMIZER_COMPATIBILITY_LEVEL_n`](https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-query)

---

### 2.13 | Statistik-Strategien für stabile Pläne
> **Kurzbeschreibung:** `AUTO_UPDATE_STATISTICS[_ASYNC]`, gefilterte & inkrementelle Statistiken (Partitionen), Update-Taktik & Fullscan-Ausnahmen.

- 📓 **Notebook:**  
  [`08_13_statistics_strategies.ipynb`](08_13_statistics_strategies.ipynb)

- 🎥 **YouTube:**  
  - [DB Options: Auto Create/Incremental Stats (Kurzvideo)](https://www.youtube.com/watch?v=8yS24q-dFHo)  
  - [Stats Q&A (Erin Stellato – Blogserie, Videohinweise)](https://www.sqlskills.com/blogs/erin/creating-statistics/)

- 📘 **Docs:**  
  - [Statistics – Overview](https://learn.microsoft.com/en-us/sql/relational-databases/statistics/statistics)  
  - [`CREATE STATISTICS` (INCREMENTAL)](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-statistics-transact-sql)

---

### 2.14 | Parameterization & Ad-hoc-Workloads
> **Kurzbeschreibung:** `ALTER DATABASE ... SET PARAMETERIZATION FORCED` vs. SIMPLE; `OPTIMIZE_FOR_AD_HOC_WORKLOADS` (Server & DB-Scope) – Vor-/Nachteile.

- 📓 **Notebook:**  
  [`08_14_parameterization_and_adhoc.ipynb`](08_14_parameterization_and_adhoc.ipynb)

- 🎥 **YouTube:**  
  - [Simple Parameterization & Trivial Plans (Serie)](https://www.sql.kiwi/2022/03/simple-param-trivial-plans-1/)  
  - [Query Store Best Practices – PASS](https://www.youtube.com/watch?v=RKnoeIVwSRk)

- 📘 **Docs:**  
  - [`ALTER DATABASE ... SET PARAMETERIZATION`](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-database-transact-sql-set-options)  
  - [Serveroption „Optimize for ad hoc workloads“](https://learn.microsoft.com/en-us/sql/database-engine/configure-windows/optimize-for-ad-hoc-workloads-server-configuration-option) / [DB-Scope-Variante](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-database-scoped-configuration-transact-sql)

---

### 2.15 | Gezieltes Cache-Management – sicher statt brachial
> **Kurzbeschreibung:** Selektives Löschen per Plan-Handle/Resource-Pool, Risiken eines kompletten Cache-Flush, Alternativen via DB-Scope-`CLEAR PROCEDURE_CACHE`.

- 📓 **Notebook:**  
  [`08_15_cache_management_safe.ipynb`](08_15_cache_management_safe.ipynb)

- 🎥 **YouTube:**  
  - [Finding & Stabilizing Performance Problems with Query Store](https://www.youtube.com/playlist?list=PLrVky5qNPwgpw8HvqYRFVO9jZ0pW5j6kL)  
  - [SQL 2022 – Built-in Query Intelligence](https://www.youtube.com/watch?v=Nd0mKM3O3sQ)

- 📘 **Docs:**  
  - [`DBCC FREEPROCCACHE`](https://learn.microsoft.com/en-us/sql/t-sql/database-console-commands/dbcc-freeproccache-transact-sql)  
  - [`ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE`](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-database-scoped-configuration-transact-sql)

---

### 2.16 | Tools & Reports – SSMS & QS-DMVs richtig nutzen
> **Kurzbeschreibung:** QS-Berichte (Top Regressed, Wait Statistics, Forced Plans), DMVs/DMFs für Text/Plan, XEvent bei Forcing-Fehlern.

- 📓 **Notebook:**  
  [`08_16_ssms_qs_reports_dmvs.ipynb`](08_16_ssms_qs_reports_dmvs.ipynb)

- 🎥 **YouTube:**  
  - [Query Store Common Reports – Demo](https://www.youtube.com/watch?v=UibSRkU-Egk)  
  - [Query Store Tutorial](https://www.youtube.com/watch?v=lTpW6xJpRXs)

- 📘 **Docs:**  
  - [`sys.query_store_plan`](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-query-store-plan-transact-sql)  
  - [`sys.dm_exec_query_plan`](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-query-plan-transact-sql)

---

## 3 | Weiterführende Informationen

- 📘 Microsoft Blog: [Query Store enabled by default in SQL Server 2022](https://www.microsoft.com/en-us/sql-server/blog/2022/08/18/query-store-is-enabled-by-default-in-sql-server-2022/)  
- 📘 Docs: [Parameter Sensitive Plan optimization (PSP)](https://learn.microsoft.com/en-us/sql/relational-databases/performance/parameter-sensitive-plan-optimization)  
- 📘 Docs: [Query Store Hints – Überblick](https://learn.microsoft.com/en-us/sql/relational-databases/performance/query-store-hints)  
- 📘 Docs: [Automatic tuning / Automatic plan correction (FORCE_LAST_GOOD_PLAN)](https://learn.microsoft.com/en-us/sql/relational-databases/automatic-tuning/automatic-tuning)  
- 📘 Docs: [`sp_query_store_force_plan` / `...unforce_plan`](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-query-store-force-plan-transact-sql)  
- 📘 Docs: [IQP – Details (Batch Mode on Rowstore, Feedback-Features)](https://learn.microsoft.com/en-us/sql/relational-databases/performance/intelligent-query-processing-details)  
- 📘 Docs: [`ALTER DATABASE SCOPED CONFIGURATION` (inkl. `PARAMETER_SNIFFING`, `OPTIMIZE_FOR_AD_HOC_WORKLOADS`)](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-database-scoped-configuration-transact-sql)  
- 📘 Docs: [Query hints (`OPTIMIZE FOR`, `USE HINT` u. a.)](https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-query)  
- 📝 Blog: Erin Stellato – [Query Store Best Practices](https://www.sqlskills.com/blogs/erin/query-store-best-practices/)  
- 📝 Blog: SQL Server Central – [Optimized plan forcing (SQL 2022)](https://www.sqlservercentral.com/articles/optimized-plan-forcing-with-query-store-in-sql-server-2022)  
- 📝 Blog: Brent Ozar – [Parameter Sniffing – Überblick & PSP](https://www.brentozar.com/sql/parameter-sniffing/)  
- 📝 Blog: SentryOne – [Compatibility levels & CE Primer](https://sqlperformance.com/2019/01/sql-performance/compatibility-levels-and-cardinality-estimation-primer)  
- 📘 Docs: [`sys.dm_exec_query_stats`](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-query-stats-transact-sql), [`sys.dm_os_wait_stats`](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-os-wait-stats-transact-sql)  
