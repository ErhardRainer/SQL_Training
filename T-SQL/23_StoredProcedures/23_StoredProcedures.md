# T-SQL Stored Procedures – Übersicht  
*Einführung in Stored Procedures, Parameter, Resultsets*

## 1 | Begriffsdefinition

| SQL-Term | Beschreibung |
|---|---|
| Stored Procedure (`CREATE PROCEDURE`) | Benannte, wiederverwendbare T-SQL-Routine; kann Eingabe-/Ausgabeparameter, Resultsets und Nebenwirkungen (DML/DDL) haben. |
| `EXEC` / `EXECUTE` | Führt Prozeduren aus; unterstützt **benannte Parameter**, `OUTPUT`, `WITH RESULT SETS`, `EXECUTE AS`. |
| Parameter | Skalare Eingaben mit Typ/Default (`@p int = NULL`); Übergabe **positional** oder **benannt**. |
| `OUTPUT`-Parameter | Liefert skalare Rückgabewerte zusätzlich zum Resultset zurück (`@out int OUTPUT`). |
| Rückgabecode (`RETURN`) | Ganzzahliger Statuscode (0 = Erfolgskonvention); **nicht** für Daten verwenden. |
| Mehrere Resultsets | Eine Prozedur kann mehrere `SELECT`-Blöcke zurückgeben; Formate mit `WITH RESULT SETS` deklarierbar. |
| TVP (Table-Valued Parameter) | Übergibt tabellarische Daten, Typ via `CREATE TYPE` definiert; **READONLY**. |
| `WITH RESULT SETS` | Erzwingt/überschreibt das Schema der ausgegebenen Resultsets beim `EXEC`. |
| Fehlerbehandlung | `TRY…CATCH`, `THROW` (modern) / `RAISERROR` (legacy); `XACT_STATE()` für Transaktionszustand. |
| Transaktionen | `BEGIN/COMMIT/ROLLBACK` in Procs; `SET XACT_ABORT ON` für robustes Rollback bei Laufzeitfehlern. |
| Sicherheit | Rechte (`GRANT EXECUTE`), Ownership Chaining, **`EXECUTE AS`** (Caller/Owner/User) zur Kontextsteuerung. |
| Plan Caching | Parameter Sniffing, `OPTION (RECOMPILE)`/Proc-`WITH RECOMPILE`, `OPTIMIZE FOR`, `sp_recompile`. |
| Temp-Objekte | `#temp`/`@table` in Procs: Scope, Recompiles, Statistiken (nur `#temp`), Batch-Mode on Rowstore u. a. |
| Persistierte SET-Optionen | `QUOTED_IDENTIFIER`/`ANSI_NULLS`-Status wird beim **CREATE** im Modul gespeichert (`sys.sql_modules`). |
| Dynamisches SQL | Mit `sp_executesql` **parametrisiert** ausführen; Bezeichner mit `QUOTENAME()` sichern (SQL-Injection vermeiden). |

---

## 2 | Struktur

### 2.1 | Grundlagen & Syntax: `CREATE PROCEDURE` / `EXEC`
> **Kurzbeschreibung:** Minimalbeispiel, benannte Parameter, Mehrfach-Resultsets, `RETURN` vs. `SELECT`.

- 📓 **Notebook:**  
  [`08_01_sp_grundlagen.ipynb`](08_01_sp_grundlagen.ipynb)

- 🎥 **YouTube:**  
  - [Stored Procedures – Basics](https://www.youtube.com/results?search_query=sql+server+stored+procedure+tutorial)  

- 📘 **Docs:**  
  - [`CREATE PROCEDURE` (T-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-procedure-transact-sql)  
  - [`EXECUTE` (T-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/execute-transact-sql)

---

### 2.2 | Parameter, Defaultwerte & benannte Übergabe
> **Kurzbeschreibung:** Parameter deklarieren, Defaults setzen, `EXEC proc @p = 42`, Datentypen korrekt wählen.

- 📓 **Notebook:**  
  [`08_02_sp_parameter_defaults.ipynb`](08_02_sp_parameter_defaults.ipynb)

- 🎥 **YouTube:**  
  - [Stored Procedure Parameters](https://www.youtube.com/results?search_query=sql+server+stored+procedure+parameters)

- 📘 **Docs:**  
  - [`CREATE PROCEDURE` – Parameter](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-procedure-transact-sql#parameters)

---

### 2.3 | `OUTPUT`-Parameter & Rückgabecode
> **Kurzbeschreibung:** Unterschiede `OUTPUT` (Daten) vs. `RETURN` (Status); Aufrufsyntax und Best Practices.

- 📓 **Notebook:**  
  [`08_03_output_parameter_returncode.ipynb`](08_03_output_parameter_returncode.ipynb)

- 🎥 **YouTube:**  
  - [Output Parameters vs Return Value](https://www.youtube.com/results?search_query=sql+server+output+parameters+return+value)

- 📘 **Docs:**  
  - [`OUTPUT`-Parameter](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-procedure-transact-sql#using-output-parameters)  
  - [`RETURN` (T-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/return-transact-sql)

---

### 2.4 | Table-Valued Parameters (TVP)
> **Kurzbeschreibung:** Typ anlegen, Daten übergeben, Performance-Hinweise; TVP ist **READONLY**.

- 📓 **Notebook:**  
  [`08_04_table_valued_parameters.ipynb`](08_04_table_valued_parameters.ipynb)

- 🎥 **YouTube:**  
  - [Table-valued Parameters](https://www.youtube.com/results?search_query=sql+server+table+valued+parameters)

- 📘 **Docs:**  
  - [Table-Valued Parameters (Database Engine)](https://learn.microsoft.com/en-us/sql/relational-databases/tables/use-table-valued-parameters-database-engine)

---

### 2.5 | Mehrere Resultsets & `WITH RESULT SETS`
> **Kurzbeschreibung:** Formate deklarieren/erzwingen, kompatible Typen, Consumer-freundliche Schemas.

- 📓 **Notebook:**  
  [`08_05_multiple_result_sets_with_result_sets.ipynb`](08_05_multiple_result_sets_with_result_sets.ipynb)

- 🎥 **YouTube:**  
  - [WITH RESULT SETS Demo](https://www.youtube.com/results?search_query=sql+server+with+result+sets)

- 📘 **Docs:**  
  - [`EXECUTE … WITH RESULT SETS`](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/execute-transact-sql#with-result-sets)

---

### 2.6 | Resultset-Metadaten: `sp_describe_first_result_set`, `sys.parameters`
> **Kurzbeschreibung:** Shape vorab ermitteln, Metadaten prüfen, Contracts dokumentieren.

- 📓 **Notebook:**  
  [`08_06_resultset_metadata_introspection.ipynb`](08_06_resultset_metadata_introspection.ipynb)

- 🎥 **YouTube:**  
  - [Describe First Result Set](https://www.youtube.com/results?search_query=sp_describe_first_result_set)

- 📘 **Docs:**  
  - [`sp_describe_first_result_set`](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-describe-first-result-set-transact-sql)  
  - [`sys.parameters`](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-parameters-transact-sql)

---

### 2.7 | Fehlerbehandlung: `TRY…CATCH`, `THROW`/`RAISERROR`
> **Kurzbeschreibung:** Robuste Patterns, Fehlerlogik zentralisieren, Rückgabe sauber gestalten.

- 📓 **Notebook:**  
  [`08_07_try_catch_throw_raiserror.ipynb`](08_07_try_catch_throw_raiserror.ipynb)

- 🎥 **YouTube:**  
  - [TRY CATCH & THROW](https://www.youtube.com/results?search_query=sql+server+try+catch+throw)

- 📘 **Docs:**  
  - [`TRY…CATCH`](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/try-catch-transact-sql) · [`THROW`](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/throw-transact-sql)  
  - [`RAISERROR`](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/raiserror-transact-sql)

---

### 2.8 | Transaktionen in Procs & `SET XACT_ABORT`
> **Kurzbeschreibung:** Saubere Grenzen, `XACT_STATE()`, Rollback-Strategien, Interaktion mit Aufrufer-Transaktionen.

- 📓 **Notebook:**  
  [`08_08_transactions_in_procs_xact_abort.ipynb`](08_08_transactions_in_procs_xact_abort.ipynb)

- 🎥 **YouTube:**  
  - [Transactions in Stored Procedures](https://www.youtube.com/results?search_query=sql+server+transactions+stored+procedures)

- 📘 **Docs:**  
  - [`SET XACT_ABORT`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-xact-abort-transact-sql)  
  - [`XACT_STATE()`](https://learn.microsoft.com/en-us/sql/t-sql/functions/xact-state-transact-sql)

---

### 2.9 | Sicherheit: `GRANT EXECUTE`, Ownership Chaining, `EXECUTE AS`
> **Kurzbeschreibung:** Least Privilege via Schema/Role, Ausführungskontext steuern, Implikationen kennen.

- 📓 **Notebook:**  
  [`08_09_security_execute_as.ipynb`](08_09_security_execute_as.ipynb)

- 🎥 **YouTube:**  
  - [EXECUTE AS & Ownership Chains](https://www.youtube.com/results?search_query=sql+server+execute+as+ownership+chain)

- 📘 **Docs:**  
  - [`EXECUTE AS` (Clause)](https://learn.microsoft.com/en-us/sql/t-sql/statements/execute-as-clause-transact-sql)  
  - [Ownership Chains](https://learn.microsoft.com/en-us/sql/relational-databases/security/ownership-chains)

---

### 2.10 | Plan Caching, Parameter Sniffing & Recompiles
> **Kurzbeschreibung:** Ursachen & Gegenmaßnahmen: `OPTION (RECOMPILE)`, Proc-`WITH RECOMPILE`, `OPTIMIZE FOR`, `RECOMPILE`/`HINTS`.

- 📓 **Notebook:**  
  [`08_10_parameter_sniffing_recompile.ipynb`](08_10_parameter_sniffing_recompile.ipynb)

- 🎥 **YouTube:**  
  - [Parameter Sniffing Explained](https://www.youtube.com/results?search_query=sql+server+parameter+sniffing)

- 📘 **Docs:**  
  - [`OPTION (RECOMPILE)` / `OPTIMIZE FOR`](https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-query)  
  - [`sp_recompile`](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-recompile-transact-sql)

---

### 2.11 | Dynamisches SQL: `sp_executesql`, Parametrisierung & Sicherheit
> **Kurzbeschreibung:** Sichere Builds mit `sp_executesql` (Parameter), Bezeichner via `QUOTENAME()`, Anti-Injection.

- 📓 **Notebook:**  
  [`08_11_dynamic_sql_sp_executesql.ipynb`](08_11_dynamic_sql_sp_executesql.ipynb)

- 🎥 **YouTube:**  
  - [Dynamic SQL with sp_executesql](https://www.youtube.com/results?search_query=sql+server+sp_executesql+dynamic+sql)

- 📘 **Docs:**  
  - [`sp_executesql`](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-executesql-transact-sql)  
  - [`QUOTENAME`](https://learn.microsoft.com/en-us/sql/t-sql/functions/quotename-transact-sql)

---

### 2.12 | Temp-Tabellen vs. Table-Variablen in Procs
> **Kurzbeschreibung:** Performance/Pläne/Statistiken, Recompile-Effekte, Scope, Parallelität.

- 📓 **Notebook:**  
  [`08_12_temp_tables_vs_table_variables.ipynb`](08_12_temp_tables_vs_table_variables.ipynb)

- 🎥 **YouTube:**  
  - [Temp Tables vs Table Variables](https://www.youtube.com/results?search_query=sql+server+temp+tables+vs+table+variables)

- 📘 **Docs:**  
  - [Temporary Tables](https://learn.microsoft.com/en-us/sql/relational-databases/tempdb/tempdb-database)  
  - [Table Variables](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/declare-table-transact-sql)

---

### 2.13 | Persistierte SET-Optionen in Modulen
> **Kurzbeschreibung:** `QUOTED_IDENTIFIER`/`ANSI_NULLS` werden beim Create gespeichert und wirken bei Ausführung/Compile.

- 📓 **Notebook:**  
  [`08_13_persisted_set_options_in_modules.ipynb`](08_13_persisted_set_options_in_modules.ipynb)

- 🎥 **YouTube:**  
  - [Module SET Options](https://www.youtube.com/results?search_query=sql+server+quoted+identifier+stored+procedure)

- 📘 **Docs:**  
  - [`sys.sql_modules` – `is_quoted_ident_on`](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-sql-modules-transact-sql)  
  - [`SET QUOTED_IDENTIFIER`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-quoted-identifier-transact-sql)

---

### 2.14 | API-Design: Kontrakte, Idempotenz, Fehlerkonventionen
> **Kurzbeschreibung:** Stabile Parameter/Resultsets, `@@ROWCOUNT`, einheitliche Fehler/Return-Codes, Logging/Audit.

- 📓 **Notebook:**  
  [`08_14_api_design_sp_kontrakte.ipynb`](08_14_api_design_sp_kontrakte.ipynb)

- 🎥 **YouTube:**  
  - [Designing Stored Procedure APIs](https://www.youtube.com/results?search_query=sql+server+stored+procedure+best+practices)

- 📘 **Docs:**  
  - [`@@ROWCOUNT`](https://learn.microsoft.com/en-us/sql/t-sql/functions/rowcount-transact-sql)

---

### 2.15 | Deployment: `CREATE OR ALTER`, Rechte & Versionierung
> **Kurzbeschreibung:** Idempotente Deployments, `CREATE OR ALTER`, `GRANT EXECUTE`, Schema/Owner sauber setzen.

- 📓 **Notebook:**  
  [`08_15_deployment_create_or_alter.ipynb`](08_15_deployment_create_or_alter.ipynb)

- 🎥 **YouTube:**  
  - [CREATE OR ALTER Procedures](https://www.youtube.com/results?search_query=sql+server+create+or+alter+procedure)

- 📘 **Docs:**  
  - [`CREATE OR ALTER PROCEDURE`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-or-alter-procedure-transact-sql)  
  - [`GRANT EXECUTE`](https://learn.microsoft.com/en-us/sql/t-sql/statements/grant-transact-sql)

---

### 2.16 | Anti-Patterns & Fallstricke
> **Kurzbeschreibung:** `SELECT *` zurückgeben, unstrukturierte Mehrfach-Resultsets, unparametrisiertes dynamisches SQL, Statuscodes für Daten missbrauchen, fehlendes Error-/Txn-Handling, übermäßige `WITH RECOMPILE`.

- 📓 **Notebook:**  
  [`08_16_sp_anti_patterns.ipynb`](08_16_sp_anti_patterns.ipynb)

- 🎥 **YouTube:**  
  - [Stored Procedure Anti-Patterns](https://www.youtube.com/results?search_query=sql+server+stored+procedure+anti+patterns)

- 📘 **Docs/Blog:**  
  - [Security & Injection – Übersicht](https://learn.microsoft.com/en-us/sql/relational-databases/security/sql-injection)  

---

## 3 | Weiterführende Informationen

- 📘 Microsoft Learn: [`CREATE PROCEDURE`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-procedure-transact-sql) · [`EXECUTE`](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/execute-transact-sql)  
- 📘 Microsoft Learn: [`sp_describe_first_result_set`](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-describe-first-result-set-transact-sql) · [`WITH RESULT SETS`](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/execute-transact-sql#with-result-sets)  
- 📘 Microsoft Learn: [Table-Valued Parameters](https://learn.microsoft.com/en-us/sql/relational-databases/tables/use-table-valued-parameters-database-engine)  
- 📘 Microsoft Learn: [`TRY…CATCH` / `THROW` / `RAISERROR`](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/throw-transact-sql)  
- 📘 Microsoft Learn: [`SET XACT_ABORT`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-xact-abort-transact-sql) · [`XACT_STATE()`](https://learn.microsoft.com/en-us/sql/t-sql/functions/xact-state-transact-sql)  
- 📘 Microsoft Learn: [`EXECUTE AS` & Ownership Chains](https://learn.microsoft.com/en-us/sql/relational-databases/security/ownership-chains)  
- 📘 Microsoft Learn: [Query Hints – `OPTIMIZE FOR`, `RECOMPILE`](https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-query) · [`sp_recompile`](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-recompile-transact-sql)  
- 📘 Microsoft Learn: [`sp_executesql` & `QUOTENAME`](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-executesql-transact-sql) · (Quotename) [(link)](https://learn.microsoft.com/en-us/sql/t-sql/functions/quotename-transact-sql)  
- 📘 Microsoft Learn: [`CREATE OR ALTER PROCEDURE`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-or-alter-procedure-transact-sql) · [`GRANT EXECUTE`](https://learn.microsoft.com/en-us/sql/t-sql/statements/grant-transact-sql)  
- 📝 Erland Sommarskog: *Dynamic SQL & Parameter Sniffing* – https://www.sommarskog.se/  
- 📝 SQLPerformance: *Stored Procedures, Plans & Recompiles* – https://www.sqlperformance.com/?s=stored+procedure  
- 📝 Brent Ozar: *Parameter Sniffing & Fixes* – https://www.brentozar.com/  
- 📝 Erik Darling: *sp_executesql Patterns & Anti-Patterns* – https://www.erikdarlingdata.com/  
- 🎥 YouTube (Data Exposed): *Stored Procedure Best Practices* – Suchlink  
