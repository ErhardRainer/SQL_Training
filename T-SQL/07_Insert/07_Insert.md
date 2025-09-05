# T-SQL INSERT – Übersicht

## 1 | Begriffsdefinition

| SQL-Term | Beschreibung |
|---|---|
| `INSERT` | Fügt Zeilen in eine Tabelle oder updatable View ein. |
| Zielobjekt | Tabelle oder updatable View, in die geschrieben wird. |
| Spaltenliste | Explizite Auflistung der Zielspalten – vermeidet Brüche bei Schemaänderungen. |
| `VALUES` (mehrzeilig) | Mehrere Zeilen in einem Statement einfügen (`VALUES (...), (...), ...`). |
| `DEFAULT VALUES` | Fügt eine Zeile mit allen Standardwerten/`NULL` (gemäß Definition) ein. |
| `INSERT … SELECT` | Übernimmt Zeilen aus einer Abfrage/Join als Quelle. |
| `INSERT TOP (N)` | Begrenzt die Anzahl eingefügter Zeilen (typisch in Kombi mit `SELECT`). |
| `OUTPUT`-Klausel | Liefert direkt die eingefügten Werte (`inserted`) – z. B. für Audit, Kaskaden-INSERTs. |
| Identität (`IDENTITY`) | Automatische Schlüssel; neue Werte via `SCOPE_IDENTITY()` oder `OUTPUT inserted.<id>`. |
| `IDENTITY_INSERT` | Erlaubt das explizite Setzen von Identity-Werten (temporär pro Tabelle). |
| Sequenz | Objektbasierte Nummernvergabe (`CREATE SEQUENCE`, `NEXT VALUE FOR`) – tabellenübergreifend nutzbar. |
| `DEFAULT`-Constraint | Spaltenstandard, der greift, wenn Spalte im `INSERT` fehlt oder `DEFAULT` angegeben ist. |
| Integritätsregeln | `NOT NULL`, `CHECK`, `UNIQUE`, `FOREIGN KEY` – validieren/erzwingen Datenqualität. |
| Trigger | `AFTER/INSTEAD OF INSERT` reagieren auf Einfügevorgänge; Pseudo-Tabelle `inserted`. |
| TVP (Table-Valued Parameter) | Übergabe vieler Zeilen aus Anwendungen an Procs/Funktionen. |
| Bulkload | Hochdurchsatz mit `BULK INSERT`, `OPENROWSET(BULK ...)`, `bcp`; ggf. minimal geloggt. |
| Transaktion/Isolation | Atomarität & Sichtbarkeit (`BEGIN/COMMIT`, `SNAPSHOT`, `SERIALIZABLE` …). |
| Idempotenz/Upsert | Mehrfachausführung ohne Duplikate; Muster: `INSERT … SELECT WHERE NOT EXISTS`, 2-Phasen-Upsert. |

---

## 2 | Struktur

### 2.1 | Grundlagen & Syntax
> **Kurzbeschreibung:** Minimales `INSERT`, Spaltenliste, `VALUES`, `DEFAULT VALUES`, typische Fehlermeldungen.

- 📓 **Notebook:**  
  [`08_01_insert_grundlagen.ipynb`](08_01_insert_grundlagen.ipynb)

- 🎥 **YouTube:**  
  - [SQL Server INSERT Statement – Basics](https://www.youtube.com/results?search_query=sql+server+insert+statement)

- 📘 **Docs:**  
  - [INSERT (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/statements/insert-transact-sql)

---

### 2.2 | Mehrzeilige `VALUES` & `DEFAULT`
> **Kurzbeschreibung:** Viele Zeilen effizient per `VALUES (...), (...)`; `DEFAULT` pro Spalte vs. `DEFAULT VALUES`.

- 📓 **Notebook:**  
  [`08_02_values_multizeilig_default.ipynb`](08_02_values_multizeilig_default.ipynb)

- 🎥 **YouTube:**  
  - [INSERT Multiple Rows](https://www.youtube.com/results?search_query=sql+server+insert+multiple+rows)

- 📘 **Docs:**  
  - [`DEFAULT`-Constraints & `DEFAULT VALUES`](https://learn.microsoft.com/en-us/sql/t-sql/statements/insert-transact-sql#default-values)

---

### 2.3 | `INSERT … SELECT` (aus Abfragen/Joins)
> **Kurzbeschreibung:** Zeilen aus anderen Tabellen/Joins übernehmen; Spaltenzuordnung & Datentypkompatibilität.

- 📓 **Notebook:**  
  [`08_03_insert_select_joins.ipynb`](08_03_insert_select_joins.ipynb)

- 🎥 **YouTube:**  
  - [INSERT INTO … SELECT – Patterns](https://www.youtube.com/results?search_query=sql+server+insert+into+select)

- 📘 **Docs:**  
  - [INSERT – `SELECT` als Quelle](https://learn.microsoft.com/en-us/sql/t-sql/statements/insert-transact-sql#inserting-data-from-other-tables)

---

### 2.4 | `OUTPUT`-Klausel (IDs & Delta erfassen)
> **Kurzbeschreibung:** Neu erzeugte Schlüssel/Spaltenwerte direkt abgreifen; Kaskaden-INSERT (Parent→Child) mit `OUTPUT INTO`.

- 📓 **Notebook:**  
  [`08_04_output_clause_insert.ipynb`](08_04_output_clause_insert.ipynb)

- 🎥 **YouTube:**  
  - [OUTPUT Clause – INSERT](https://www.youtube.com/results?search_query=sql+server+output+clause+insert)

- 📘 **Docs:**  
  - [`OUTPUT` (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/queries/output-clause-transact-sql)

---

### 2.5 | Identitäten: `IDENTITY`, `SCOPE_IDENTITY()`, `IDENTITY_INSERT`
> **Kurzbeschreibung:** Sicher neue ID beziehen (`SCOPE_IDENTITY()`/`OUTPUT`), `@@IDENTITY`/`IDENT_CURRENT` vermeiden; gezielt `IDENTITY_INSERT`.

- 📓 **Notebook:**  
  [`08_05_identity_scope_identity.ipynb`](08_05_identity_scope_identity.ipynb)

- 🎥 **YouTube:**  
  - [Identity Columns & SCOPE_IDENTITY](https://www.youtube.com/results?search_query=sql+server+scope_identity)

- 📘 **Docs:**  
  - [`IDENTITY`-Eigenschaft](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-table-transact-sql-identity-property)  
  - [`SCOPE_IDENTITY`](https://learn.microsoft.com/en-us/sql/t-sql/functions/scope-identity-transact-sql) · [`SET IDENTITY_INSERT`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-identity-insert-transact-sql)

---

### 2.6 | Sequenzen (`CREATE SEQUENCE`, `NEXT VALUE FOR`)
> **Kurzbeschreibung:** Schlüssel ohne Tabellengebindung; Nutzung in `INSERT`/Default-Constraints; Lücken/Parallelität.

- 📓 **Notebook:**  
  [`08_06_sequence_next_value_for.ipynb`](08_06_sequence_next_value_for.ipynb)

- 🎥 **YouTube:**  
  - [SQL Server Sequences – Tutorial](https://www.youtube.com/results?search_query=sql+server+sequence+next+value+for)

- 📘 **Docs:**  
  - [`CREATE SEQUENCE`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-sequence-transact-sql) · [`NEXT VALUE FOR`](https://learn.microsoft.com/en-us/sql/t-sql/functions/next-value-for-transact-sql)

---

### 2.7 | Constraints & Trigger (`AFTER/INSTEAD OF INSERT`)
> **Kurzbeschreibung:** Validierung durch `CHECK`/`FOREIGN KEY`/`UNIQUE`; Triggerlogik & Pseudo-Tabelle `inserted`.

- 📓 **Notebook:**  
  [`08_07_constraints_trigger_insert.ipynb`](08_07_constraints_trigger_insert.ipynb)

- 🎥 **YouTube:**  
  - [INSERT Triggers Explained](https://www.youtube.com/results?search_query=sql+server+insert+trigger)

- 📘 **Docs:**  
  - [CHECK/UNIQUE/FOREIGN KEY – Übersicht](https://learn.microsoft.com/en-us/sql/relational-databases/tables/tables)  
  - [CREATE TRIGGER](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-trigger-transact-sql)

---

### 2.8 | Transaktionen & Fehlerbehandlung
> **Kurzbeschreibung:** `BEGIN/COMMIT/ROLLBACK`, `TRY…CATCH`, `THROW`, `XACT_ABORT ON` – sauber abbrechen & signalisieren.

- 📓 **Notebook:**  
  [`08_08_transaktionen_try_catch_insert.ipynb`](08_08_transaktionen_try_catch_insert.ipynb)

- 🎥 **YouTube:**  
  - [TRY…CATCH & THROW – DML](https://www.youtube.com/results?search_query=sql+server+try+catch+throw)

- 📘 **Docs:**  
  - [`TRY…CATCH`](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/try-catch-transact-sql) · [`THROW`](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/throw-transact-sql)  
  - [`SET XACT_ABORT`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-xact-abort-transact-sql)

---

### 2.9 | Table-Valued Parameters (TVP) & `INSERT EXEC`
> **Kurzbeschreibung:** Große Datenmengen aus Apps effizient übergeben; Alternativen: `INSERT EXEC proc` für Zwischenergebnisse.

- 📓 **Notebook:**  
  [`08_09_tvp_insert_exec.ipynb`](08_09_tvp_insert_exec.ipynb)

- 🎥 **YouTube:**  
  - [Table-Valued Parameters – Demo](https://www.youtube.com/results?search_query=sql+server+table+valued+parameters)

- 📘 **Docs:**  
  - [Verwenden von TVPs](https://learn.microsoft.com/en-us/sql/relational-databases/tables/use-table-valued-parameters-database-engine)  
  - [`INSERT EXEC` – Hinweise](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/insert-transact-sql#inserting-data-by-executing-a-stored-procedure)

---

### 2.10 | Bulkload: `BULK INSERT`, `OPENROWSET(BULK)`, `bcp`
> **Kurzbeschreibung:** Hochdurchsatz-Loads, Dateiformate, Fehlerzeilen; minimal logging unter geeigneten Bedingungen.

- 📓 **Notebook:**  
  [`08_10_bulk_insert_openrowset_bcp.ipynb`](08_10_bulk_insert_openrowset_bcp.ipynb)

- 🎥 **YouTube:**  
  - [BULK INSERT – Praxis](https://www.youtube.com/results?search_query=sql+server+bulk+insert+tutorial)

- 📘 **Docs:**  
  - [`BULK INSERT`](https://learn.microsoft.com/en-us/sql/t-sql/statements/bulk-insert-transact-sql) · [`OPENROWSET(BULK)`](https://learn.microsoft.com/en-us/sql/t-sql/functions/openrowset-transact-sql)  
  - [bcp Utility](https://learn.microsoft.com/en-us/sql/tools/bcp-utility)

---

### 2.11 | `SELECT INTO` vs. `INSERT … SELECT`
> **Kurzbeschreibung:** Neue Tabelle on-the-fly erzeugen vs. in bestehende Struktur laden; Logging/Parallelität/Indizes.

- 📓 **Notebook:**  
  [`08_11_select_into_vs_insert_select.ipynb`](08_11_select_into_vs_insert_select.ipynb)

- 🎥 **YouTube:**  
  - [SELECT INTO vs INSERT SELECT](https://www.youtube.com/results?search_query=sql+server+select+into+vs+insert+select)

- 📘 **Docs:**  
  - [`SELECT INTO`](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-into-clause-transact-sql)  
  - [`INSERT … SELECT`](https://learn.microsoft.com/en-us/sql/t-sql/statements/insert-transact-sql#inserting-data-from-other-tables)

---

### 2.12 | Batching & Durchsatz-Optimierung
> **Kurzbeschreibung:** Paketgrößen, `TABLOCK`, Indizes/Triggers deaktivieren (wo vertretbar), Wiederaufnahmefähige Loads.

- 📓 **Notebook:**  
  [`08_12_batching_throughput.ipynb`](08_12_batching_throughput.ipynb)

- 🎥 **YouTube:**  
  - [High-Throughput Inserts](https://www.youtube.com/results?search_query=sql+server+high+throughput+insert)

- 📘 **Docs/Blog:**  
  - [Index Design & Auswirkungen auf DML](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-index-design-guide)  
  - [Minimal Logging – Überblick](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-transaction-log-architecture-and-management)

---

### 2.13 | Idempotente Inserts & Upsert ohne `MERGE`
> **Kurzbeschreibung:** Doppelte vermeiden (`WHERE NOT EXISTS`/`EXCEPT`/`LEFT JOIN … IS NULL`) und robustes 2-Phasen-Upsert.

- 📓 **Notebook:**  
  [`08_13_idempotente_inserts_upsert.ipynb`](08_13_idempotente_inserts_upsert.ipynb)

- 🎥 **YouTube:**  
  - [UPSERT Patterns (ohne MERGE)](https://www.youtube.com/results?search_query=sql+server+upsert+without+merge)

- 📘 **Docs/Blog:**  
  - [`MERGE` – Referenz (Hinweise & Risiken)](https://learn.microsoft.com/en-us/sql/t-sql/statements/merge-transact-sql)  
  - [Aaron Ber]()
