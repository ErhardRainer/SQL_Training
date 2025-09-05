# T-SQL User-Defined Functions (UDFs) – Übersicht  
*Skalare & table-valued Funktionen (iTVF/mTVF), typische Anwendungsfälle*

## 1 | Begriffsdefinition

| SQL-Term | Beschreibung |
|---|---|
| Skalare UDF | `CREATE FUNCTION dbo.f(@x int) RETURNS int AS BEGIN RETURN @x*2 END;` – gibt **einen** skalaren Wert zurück. |
| Inline TVF (iTVF) | `RETURNS TABLE AS RETURN (SELECT …)` – reine **Abfrage** ohne Zwischentabelle; vom Optimizer wie ein **In-Line-View** behandelt. |
| Multi-Statement TVF (mTVF) | `RETURNS @t TABLE … BEGIN INSERT @t …; RETURN;` – baut eine **Tabellenvariable** intern auf; historisch schlechte Kardinalitätsschätzung (1 Zeile), verbessert durch **Interleaved Execution**. |
| `SCHEMABINDING` | Bindet Funktion an Basisobjekte; Voraussetzung für **Determinismus-Nachweis** (z. B. für persistierte berechnete Spalten). |
| Deterministisch/Präzise | Funktionen, die bei gleichen Eingaben immer das gleiche Ergebnis liefern/ohne Rundungsfehler; wichtig für Indizierung/Persistenz. |
| `RETURNS TABLE` vs. `RETURNS @t TABLE` | Kennzeichnet iTVF (einzelnes `RETURN (SELECT …)`) vs. mTVF (Table-Variable `@t`). |
| `CROSS/OUTER APPLY` | Setzt TVFs **zeilenweise** an (parameterisierte Joins/Expander). |
| Einschränkungen | UDFs dürfen **keine DML/DDL** ausführen, **keine Prozeduren** aufrufen, **kein dynamisches SQL**; begrenzte Anweisungen erlaubt. |
| Scalar UDF Inlining (SQL 2019+) | Kompat.-Level ≥150: viele skalare UDFs werden zu relationalen Ausdrücken **inlined**; Option `WITH INLINE = { ON | OFF }`. |
| Interleaved Execution (SQL 2017+) | Optimizer kann mTVF-Ergebnis **zur Laufzeit** abschätzen → bessere Pläne. |
| Sicherheit | Rechte: `GRANT EXECUTE ON FUNCTION …`; Ownership Chaining wirkt wie bei Views. |
| Performance-Grundsatz | iTVF ≈ schnell/composable, mTVF mit Vorsicht, skalare UDFs nur wenn nötig (oder mit Inlining). |

---

## 2 | Struktur

### 2.1 | Grundlagen: Arten von UDFs & Syntax
> **Kurzbeschreibung:** Überblick skalare UDF, iTVF, mTVF; Syntax, Rückgabetypen, Einsatzkriterien.

- 📓 **Notebook:**  
  [`08_01_udf_grundlagen.ipynb`](08_01_udf_grundlagen.ipynb)

- 🎥 **YouTube:**  
  - [SQL Server Functions – Basics](https://www.youtube.com/results?search_query=sql+server+user+defined+functions+tutorial)

- 📘 **Docs:**  
  - [`CREATE FUNCTION` (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-function-transact-sql)

---

### 2.2 | Inline TVF (iTVF) – composable & sargierbar
> **Kurzbeschreibung:** iTVFs als „parametrisierte Views“, Predicate Pushdown, Join-Folding, typische Muster.

- 📓 **Notebook:**  
  [`08_02_inline_tvf_patterns.ipynb`](08_02_inline_tvf_patterns.ipynb)

- 🎥 **YouTube:**  
  - [Inline Table-Valued Functions](https://www.youtube.com/results?search_query=sql+server+inline+table+valued+function)

- 📘 **Docs:**  
  - [`CREATE FUNCTION` – Inline TVF Beispiele](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-function-transact-sql#inline-table-valued-functions)

---

### 2.3 | Multi-Statement TVF (mTVF) – wann & wie?
> **Kurzbeschreibung:** Vorteile (komplexe Logik), Nachteile (Table-Variable, Schätzung); Alternativen aufzeigen.

- 📓 **Notebook:**  
  [`08_03_multistatement_tvf_patterns.ipynb`](08_03_multistatement_tvf_patterns.ipynb)

- 🎥 **YouTube:**  
  - [Multi-Statement TVF Explained](https://www.youtube.com/results?search_query=sql+server+multi+statement+tvf)

- 📘 **Docs:**  
  - [`CREATE FUNCTION` – Multi-Statement TVF](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-function-transact-sql#multi-statement-table-valued-functions)

---

### 2.4 | Skalare UDF – korrekt & performant einsetzen
> **Kurzbeschreibung:** Einsatzgrenzen, NULL-Behandlung, Datentypen, Alternativen (iTVF/`APPLY`/Computed Columns).

- 📓 **Notebook:**  
  [`08_04_scalar_udf_best_practices.ipynb`](08_04_scalar_udf_best_practices.ipynb)

- 🎥 **YouTube:**  
  - [Scalar Functions – Do’s & Don’ts](https://www.youtube.com/results?search_query=sql+server+scalar+functions+performance)

- 📘 **Docs:**  
  - [`CREATE FUNCTION` – Scalar](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-function-transact-sql#scalar-functions)

---

### 2.5 | `CROSS/OUTER APPLY` + TVF – Parameterisierte Joins
> **Kurzbeschreibung:** Zeilenweise Parametrisierung, Entzivieren, JSON Shredding + TVF.

- 📓 **Notebook:**  
  [`08_05_apply_with_tvf.ipynb`](08_05_apply_with_tvf.ipynb)

- 🎥 **YouTube:**  
  - [CROSS APPLY + TVF Patterns](https://www.youtube.com/results?search_query=sql+server+cross+apply+table+valued+function)

- 📘 **Docs:**  
  - [`FROM` – `APPLY`-Operator](https://learn.microsoft.com/en-us/sql/t-sql/queries/from-transact-sql#apply-operator)

---

### 2.6 | Determinismus, `SCHEMABINDING` & Persistenz
> **Kurzbeschreibung:** Deterministische/präzise UDFs, `SCHEMABINDING`, Einsatz in **persistierten** berechneten Spalten.

- 📓 **Notebook:**  
  [`08_06_determinism_schemabinding.ipynb`](08_06_determinism_schemabinding.ipynb)

- 🎥 **YouTube:**  
  - [Deterministic Functions in SQL Server](https://www.youtube.com/results?search_query=sql+server+deterministic+functions)

- 📘 **Docs:**  
  - [Deterministic/Precise Functions & Indexing](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/indexes-on-computed-columns)

---

### 2.7 | Scalar UDF Inlining (SQL Server 2019+)
> **Kurzbeschreibung:** Wie und wann der Optimizer skalare UDFs inlined; `WITH INLINE = ON|OFF`, Diagnostik.

- 📓 **Notebook:**  
  [`08_07_scalar_udf_inlining.ipynb`](08_07_scalar_udf_inlining.ipynb)

- 🎥 **YouTube:**  
  - [Scalar UDF Inlining Overview](https://www.youtube.com/results?search_query=sql+server+scalar+udf+inlining)

- 📘 **Docs:**  
  - [Scalar UDF Inlining](https://learn.microsoft.com/en-us/sql/relational-databases/user-defined-functions/scalar-udf-inlining)

---

### 2.8 | Interleaved Execution für mTVFs (SQL 2017+)
> **Kurzbeschreibung:** Bessere Zeilenzahlschätzung für mTVFs → stabilere Pläne.

- 📓 **Notebook:**  
  [`08_08_interleaved_execution_mtvf.ipynb`](08_08_interleaved_execution_mtvf.ipynb)

- 🎥 **YouTube:**  
  - [Interleaved Execution Demo](https://www.youtube.com/results?search_query=sql+server+interleaved+execution)

- 📘 **Docs:**  
  - [Interleaved Execution for MSTVFs](https://learn.microsoft.com/en-us/sql/relational-databases/performance/intelligent-query-processing-feedback#interleaved-execution-for-multi-statement-table-valued-functions)

---

### 2.9 | Fehler- & Transaktionsverhalten in UDFs
> **Kurzbeschreibung:** Was **nicht** erlaubt ist (DML/TRY-CATCH/`RAISERROR`), Null-Sicherheit, defensive Programmierung.

- 📓 **Notebook:**  
  [`08_09_udf_error_txn_semantics.ipynb`](08_09_udf_error_txn_semantics.ipynb)

- 🎥 **YouTube:**  
  - [UDF Limitations & Errors](https://www.youtube.com/results?search_query=sql+server+udf+limitations)

- 📘 **Docs:**  
  - [`CREATE FUNCTION` – Einschränkungen](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-function-transact-sql#function-restrictions)

---

### 2.10 | JSON, Strings & Datumslogik als UDF
> **Kurzbeschreibung:** Häufige Hilfsfunktionen (Parsing, Normalisierung), wann besser iTVF/`OPENJSON`/`APPLY` verwenden.

- 📓 **Notebook:**  
  [`08_10_udf_json_strings_dates.ipynb`](08_10_udf_json_strings_dates.ipynb)

- 🎥 **YouTube:**  
  - [OPENJSON + APPLY Patterns](https://www.youtube.com/results?search_query=sql+server+openjson+apply)

- 📘 **Docs:**  
  - [`OPENJSON`](https://learn.microsoft.com/en-us/sql/t-sql/functions/openjson-transact-sql)

---

### 2.11 | UDFs in Indizes/Computed Columns
> **Kurzbeschreibung:** Voraussetzungen für **persistierte** Computed Columns mit UDFs; Determinismus prüfen.

- 📓 **Notebook:**  
  [`08_11_udf_in_computed_columns.ipynb`](08_11_udf_in_computed_columns.ipynb)

- 🎥 **YouTube:**  
  - [Indexed Computed Columns – Rules](https://www.youtube.com/results?search_query=sql+server+indexed+computed+columns)

- 📘 **Docs:**  
  - [Indexes on Computed Columns – Requirements](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/indexes-on-computed-columns)

---

### 2.12 | Sicherheit & Rechte: `GRANT EXECUTE`, Ownership Chains
> **Kurzbeschreibung:** Rechte auf Funktionen, Schema-Design, `EXECUTE AS` bei CLR-/Externe Funktionsfälle.

- 📓 **Notebook:**  
  [`08_12_security_permissions_udf.ipynb`](08_12_security_permissions_udf.ipynb)

- 🎥 **YouTube:**  
  - [GRANT EXECUTE on Functions](https://www.youtube.com/results?search_query=sql+server+grant+execute+function)

- 📘 **Docs:**  
  - [`GRANT` – Permissions on Functions](https://learn.microsoft.com/en-us/sql/t-sql/statements/grant-transact-sql)

---

### 2.13 | Performance messen: iTVF vs. mTVF vs. Scalar
> **Kurzbeschreibung:** Plananalyse (Actual Rows/Estimate), Memory Grants, Batch Mode on Rowstore, Alternativen aufzeigen.

- 📓 **Notebook:**  
  [`08_13_perf_itvf_mtvf_scalar.ipynb`](08_13_perf_itvf_mtvf_scalar.ipynb)

- 🎥 **YouTube:**  
  - [UDF Performance Comparison](https://www.youtube.com/results?search_query=sql+server+udf+performance)

- 📘 **Docs:**  
  - [Query Processing Architecture Guide](https://learn.microsoft.com/en-us/sql/relational-databases/query-processing-architecture-guide)

---

### 2.14 | Testbarkeit & Vertrag: Eingaben/Outputs festlegen
> **Kurzbeschreibung:** Signaturen stabil halten, `NULL`-Verhalten dokumentieren, TVF-Schemas versionieren.

- 📓 **Notebook:**  
  [`08_14_testing_contracts_udf.ipynb`](08_14_testing_contracts_udf.ipynb)

- 🎥 **YouTube:**  
  - [Unit Testing T-SQL (tSQLt etc.)](https://www.youtube.com/results?search_query=tsql+unit+testing)

- 📘 **Docs:**  
  - [`sp_describe_first_result_set` (für TVF-Form)](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-describe-first-result-set-transact-sql)

---

### 2.15 | CLR-/Externe Funktionen (Kurzüberblick)
> **Kurzbeschreibung:** .NET-basierte UDFs für Spezialfälle (Regex, Geometrie); Sicherheits-/Deploymentaspekte.

- 📓 **Notebook:**  
  [`08_15_clr_udf_overview.ipynb`](08_15_clr_udf_overview.ipynb)

- 🎥 **YouTube:**  
  - [CLR Functions in SQL Server](https://www.youtube.com/results?search_query=sql+server+clr+functions)

- 📘 **Docs:**  
  - [CLR Functions – Overview](https://learn.microsoft.com/en-us/sql/relational-databases/clr-integration-database-objects-user-defined-functions/clr-user-defined-functions)

---

### 2.16 | Anti-Patterns & Fallstricke
> **Kurzbeschreibung:** Skalar-UDF in großen Prädikaten/Joins, mTVF als „Black Box“, undeterministische UDF in Persistenz, dynamisches SQL/Procs aus UDF, `SELECT *` in iTVF.

- 📓 **Notebook:**  
  [`08_16_udf_anti_patterns.ipynb`](08_16_udf_anti_patterns.ipynb)

- 🎥 **YouTube:**  
  - [Common UDF Mistakes](https://www.youtube.com/results?search_query=sql+server+udf+mistakes)

- 📘 **Docs/Blog:**  
  - [Function Restrictions & Best Practices](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-function-transact-sql#function-restrictions)

---

## 3 | Weiterführende Informationen

- 📘 Microsoft Learn: [`CREATE FUNCTION` (T-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-function-transact-sql)  
- 📘 Microsoft Learn: [Scalar UDF Inlining (SQL Server 2019+)](https://learn.microsoft.com/en-us/sql/relational-databases/user-defined-functions/scalar-udf-inlining)  
- 📘 Microsoft Learn: [Interleaved Execution for mTVFs](https://learn.microsoft.com/en-us/sql/relational-databases/performance/intelligent-query-processing-feedback#interleaved-execution-for-multi-statement-table-valued-functions)  
- 📘 Microsoft Learn: [`APPLY`-Operator](https://learn.microsoft.com/en-us/sql/t-sql/queries/from-transact-sql#apply-operator)  
- 📘 Microsoft Learn: [Indexes on Computed Columns – Determinismus](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/indexes-on-computed-columns)  
- 📘 Microsoft Learn: [JSON in SQL Server (`OPENJSON`, `JSON_VALUE`)](https://learn.microsoft.com/en-us/sql/relational-databases/json/json-data-sql-server)  
- 📝 Paul White: *Interleaved Execution for MSTVFs* – https://www.sql.kiwi/ (Suche)  
- 📝 Itzik Ben-Gan: *Inline vs. Multi-Statement TVFs & APPLY-Patterns* – https://tsql.solidq.com/  
- 📝 Erik Darling: *Scalar UDF Performance & Inlining* – https://www.erikdarlingdata.com/  
- 📝 SQLPerformance: *TVF Cardinality & Plan Quality* – https://www.sqlperformance.com/?s=tvf  
- 📝 Brent Ozar: *UDFs in the Real World (Anti-Patterns)* – https://www.brentozar.com/  
- 🎥 YouTube Playlist: *User-Defined Functions & APPLY* – (Suche)  


