# T-SQL Table-Valued Parameters (TVPs) & Table Types – Übersicht  
*Effiziente Schnittstellen für Prozeduren*

## 1 | Begriffsdefinition

| SQL-Term | Beschreibung |
|---|---|
| **User-Defined Table Type (UDTT)** | Schemaobjekt: `CREATE TYPE … AS TABLE (…)`. Dient als Datentyp für TVPs oder als Tabellenvariable (`DECLARE @t dbo.Typ`). |
| **Table-Valued Parameter (TVP)** | Prozedurparameter vom UDTT-Typ: `@items dbo.Typ **READONLY**`. Ermöglicht **Batch-Input** (viele Zeilen) in **einem** Call. |
| **READONLY** | Pflicht-Attribut bei TVPs – innerhalb der Proc **kein** `INSERT/UPDATE/DELETE` auf dem Parameternamen. |
| **Temporäre Speicherung** | Daten aus TVPs/UDTTs werden in **tempdb** materialisiert (ähnlich Tabellenvariablen). |
| **Constraints/Indizes** | In UDTTs sind **PRIMARY KEY/UNIQUE/CHECK** erlaubt (→ unterstützende Indizes). **Keine** separaten `CREATE INDEX`-Statements. |
| **Statistiken** | **Keine Auto-Statistiken** auf TVPs; oft konservative Kardinalitätsschätzung → ggf. `OPTION(RECOMPILE)`/Materialisierung in `#temp`. |
| **Reihenfolge** | TVPs sind **ungeordnet** – falls Reihenfolge benötigt wird, **Ordinalspalte** im UDTT vorsehen. |
| **Kompatibilität** | TVPs sind in **Stored Procedures** und **ad-hoc Batches** nutzbar; **nicht** als UDF-Parameter. |
| **Sicherheit** | UDTT ist Schemaobjekt → Berechtigung via `GRANT EXECUTE ON TYPE::schema.Typ TO Rolle`. |
| **Client-API** | .NET `SqlParameter.SqlDbType = Structured` (DataTable/`IEnumerable<SqlDataRecord>`); andere Treiber analog. |
| **Memory-Optimized UDTT** | `CREATE TYPE … AS TABLE (…) WITH (MEMORY_OPTIMIZED = ON)` für native Procs/In-Memory-Workloads (mit HASH/NC-Indexdefinitionen). |
| **Use Cases** | Batch-Upserts, Filterlisten, komplexe Parametersets, Bulk-Validierung, Massenzuordnung (Mapping-Tabellen). |

---

## 2 | Struktur

### 2.1 | Grundlagen: UDTT & TVP – Motivation & Syntax
> **Kurzbeschreibung:** Warum TVPs? Roundtrips sparen, Set-based arbeiten, saubere Typsicherheit statt CSV/XML/JSON.

- 📓 **Notebook:**  
  [`08_01_udtt_tvp_grundlagen.ipynb`](08_01_udtt_tvp_grundlagen.ipynb)
- 🎥 **YouTube:**  
  - [Table-Valued Parameters – Basics](https://www.youtube.com/results?search_query=sql+server+table+valued+parameters+tutorial)
- 📘 **Docs:**  
  - [Using Table-Valued Parameters](https://learn.microsoft.com/en-us/sql/relational-databases/tables/use-table-valued-parameters-database-engine)  
  - [`CREATE TYPE` (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-type-transact-sql)

---

### 2.2 | UDTT designen: Schlüssel, Checks, Ordinalspalte
> **Kurzbeschreibung:** Schlanke Typen, `PRIMARY KEY`/`UNIQUE` für Joins, optionale `SeqNo` für stabile Reihenfolge.

- 📓 **Notebook:**  
  [`08_02_udtt_design_keys_checks.ipynb`](08_02_udtt_design_keys_checks.ipynb)
- 🎥 **YouTube:**  
  - [Designing Table Types](https://www.youtube.com/results?search_query=sql+server+user+defined+table+type+design)
- 📘 **Docs:**  
  - [Table Type – Einschränkungen/Features](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-type-transact-sql#table)

---

### 2.3 | TVP in Stored Procedures & Batches
> **Kurzbeschreibung:** Parameterdeklaration `@p Typ READONLY`, Join/Apply-Muster, Validierung.

- 📓 **Notebook:**  
  [`08_03_tvp_in_procs_batches.ipynb`](08_03_tvp_in_procs_batches.ipynb)
- 🎥 **YouTube:**  
  - [TVP in Stored Procedures](https://www.youtube.com/results?search_query=sql+server+tvp+stored+procedure)
- 📘 **Docs:**  
  - [Use TVPs in Procedures](https://learn.microsoft.com/en-us/sql/relational-databases/tables/use-table-valued-parameters-database-engine#use-table-valued-parameters)

---

### 2.4 | Client-Code (.NET/ODBC): `SqlDbType.Structured`
> **Kurzbeschreibung:** Übergabe via `DataTable`/`SqlDataRecord`; Performance-Tipps (Batchgröße, `SqlBulkCopy`-Vergleich).

- 📓 **Notebook:**  
  [`08_04_client_apis_dotnet_odbc.ipynb`](08_04_client_apis_dotnet_odbc.ipynb)
- 🎥 **YouTube:**  
  - [.NET TVP Demo](https://www.youtube.com/results?search_query=table+valued+parameters+c%23)
- 📘 **Docs:**  
  - [.NET: Table-Valued Parameters](https://learn.microsoft.com/en-us/dotnet/framework/data/adonet/sql/table-valued-parameters)

---

### 2.5 | Kardinalität & Pläne: Schätzungen verbessern
> **Kurzbeschreibung:** Keine Auto-Stats → oft zu geringe Row-Estimates; Optionen: `OPTION(RECOMPILE)`, Vor-Materialisierung in `#temp` + Index/Stats.

- 📓 **Notebook:**  
  [`08_05_cardinality_plans_tvp.ipynb`](08_05_cardinality_plans_tvp.ipynb)
- 🎥 **YouTube:**  
  - [TVP Cardinality & Performance](https://www.youtube.com/results?search_query=sql+server+tvp+cardinality)
- 📘 **Docs:**  
  - [Cardinality Estimation – Überblick](https://learn.microsoft.com/en-us/sql/relational-databases/performance/cardinality-estimation)

---

### 2.6 | Upsert-Muster: TVP + `MERGE` / `UPDATE FROM`
> **Kurzbeschreibung:** Differenzen aus TVP anwenden (INSERT/UPDATE/DELETE), Output-Auditing.

- 📓 **Notebook:**  
  [`08_06_upsert_patterns_tvp.ipynb`](08_06_upsert_patterns_tvp.ipynb)
- 🎥 **YouTube:**  
  - [UPSERT with TVPs](https://www.youtube.com/results?search_query=sql+server+upsert+table+valued+parameter)
- 📘 **Docs:**  
  - [`UPDATE … FROM` / `MERGE` Referenz](https://learn.microsoft.com/en-us/sql/t-sql/statements/merge-transact-sql)

---

### 2.7 | Validierung & Fehlerrückgabe
> **Kurzbeschreibung:** Datenregeln (CHECKs im UDTT, referentielle Checks per Join), Sammelfehler/Reject-Berichte via `OUTPUT`.

- 📓 **Notebook:**  
  [`08_07_validation_patterns_tvp.ipynb`](08_07_validation_patterns_tvp.ipynb)
- 🎥 **YouTube:**  
  - [Validating TVP Data](https://www.youtube.com/results?search_query=sql+server+validate+table+valued+parameter)
- 📘 **Docs:**  
  - [OUTPUT-Clause](https://learn.microsoft.com/en-us/sql/t-sql/queries/output-clause-transact-sql)

---

### 2.8 | Sicherheit: Rechte auf Typ & Proc
> **Kurzbeschreibung:** `GRANT EXECUTE ON TYPE::…`/Rollen, Least-Privilege, Schema-Isolation.

- 📓 **Notebook:**  
  [`08_08_security_grants_types_procs.ipynb`](08_08_security_grants_types_procs.ipynb)
- 🎥 **YouTube:**  
  - [Grant Permissions on Types](https://www.youtube.com/results?search_query=grant+execute+on+type+sql+server)
- 📘 **Docs:**  
  - [`GRANT` (Objektrechte, TYPE)](https://learn.microsoft.com/en-us/sql/t-sql/statements/grant-transact-sql)

---

### 2.9 | TVP vs. Alternativen: CSV/XML/JSON, `STRING_SPLIT`, `OPENJSON`
> **Kurzbeschreibung:** Vor-/Nachteile; wann TVP, wann `OPENJSON`/`STRING_SPLIT`, wann `SqlBulkCopy` geeigneter ist.

- 📓 **Notebook:**  
  [`08_09_tvp_vs_csv_xml_json.ipynb`](08_09_tvp_vs_csv_xml_json.ipynb)
- 🎥 **YouTube:**  
  - [TVP vs JSON/XML](https://www.youtube.com/results?search_query=sql+server+tvp+vs+json)
- 📘 **Docs:**  
  - [`OPENJSON`](https://learn.microsoft.com/en-us/sql/t-sql/functions/openjson-transact-sql) ・ [`STRING_SPLIT`](https://learn.microsoft.com/en-us/sql/t-sql/functions/string-split-transact-sql)

---

### 2.10 | Performance-Tipps: Batching, Joins, Indizes im UDTT
> **Kurzbeschreibung:** Schmale Schemata, passende Schlüssel, Joins auf indizierten Spalten, kleiner halten (nur benötigte Spalten).

- 📓 **Notebook:**  
  [`08_10_performance_tips_tvp.ipynb`](08_10_performance_tips_tvp.ipynb)
- 🎥 **YouTube:**  
  - [TVP Performance Tips](https://www.youtube.com/results?search_query=sql+server+table+valued+parameter+performance)
- 📘 **Docs:**  
  - [Performance Guidelines (TVPs/Tempdb)](https://learn.microsoft.com/en-us/sql/relational-databases/tempdb-database/tempdb-database)

---

### 2.11 | Memory-Optimized Table Types (In-Memory OLTP)
> **Kurzbeschreibung:** UDTT mit `MEMORY_OPTIMIZED = ON`, HASH/NONCLUSTERED Indexe, Einsatz in nativ kompilierten Procs.

- 📓 **Notebook:**  
  [`08_11_memory_optimized_table_types.ipynb`](08_11_memory_optimized_table_types.ipynb)
- 🎥 **YouTube:**  
  - [Memory-Optimized Table Types](https://www.youtube.com/results?search_query=memory+optimized+table+types+sql+server)
- 📘 **Docs:**  
  - [Memory-Optimized Table Types](https://learn.microsoft.com/en-us/sql/relational-databases/in-memory-oltp/memory-optimized-table-types)

---

### 2.12 | Versionierung & Deployment von UDTTs
> **Kurzbeschreibung:** UDTT ist hart gebunden – Änderungen via **DROP/CREATE**; Versionierte Typen (`Typ_v2`) + Parallelbetrieb.

- 📓 **Notebook:**  
  [`08_12_udtt_versioning_deployment.ipynb`](08_12_udtt_versioning_deployment.ipynb)
- 🎥 **YouTube:**  
  - [Deploying Changes to Table Types](https://www.youtube.com/results?search_query=sql+server+change+user+defined+table+type)
- 📘 **Docs:**  
  - [Abhängigkeiten (`sys.sql_expression_dependencies`)](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-sql-expression-dependencies-transact-sql)

---

### 2.13 | Fehlersuche & DMVs/Kataloge
> **Kurzbeschreibung:** UDTTs & Spalten in `sys.table_types`/`sys.columns`, TVP-Nutzung in Procs ermitteln.

- 📓 **Notebook:**  
  [`08_13_dmvs_table_types_usage.ipynb`](08_13_dmvs_table_types_usage.ipynb)
- 🎥 **YouTube:**  
  - [Find UDTTs in a Database](https://www.youtube.com/results?search_query=sql+server+list+user+defined+table+types)
- 📘 **Docs:**  
  - [`sys.table_types` / `sys.types` / `sys.columns`](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-table-types-transact-sql)

---

### 2.14 | Sicherheit & Signing (modulare Rechte)
> **Kurzbeschreibung:** Module-Signing/`EXECUTE AS` für geschützte Operationen trotz TVP; Typrechte separat managen.

- 📓 **Notebook:**  
  [`08_14_security_module_signing_tvp.ipynb`](08_14_security_module_signing_tvp.ipynb)
- 🎥 **YouTube:**  
  - [Module Signing + Types](https://www.youtube.com/results?search_query=sql+server+module+signing+type+permission)
- 📘 **Docs:**  
  - [Sign Stored Procedures](https://learn.microsoft.com/en-us/sql/relational-databases/security/authentication-access/signing-stored-procedures)

---

### 2.15 | Patterns: Filterliste, Mapping, Pivot-ähnliche Strukturen
> **Kurzbeschreibung:** TVP als semantische Liste (IDs/Keys), Many-to-Many-Zuordnungen, Aggregat-/Reporting-Inputs.

- 📓 **Notebook:**  
  [`08_15_patterns_filter_mapping.ipynb`](08_15_patterns_filter_mapping.ipynb)
- 🎥 **YouTube:**  
  - [Real-World TVP Patterns](https://www.youtube.com/results?search_query=sql+server+table+valued+parameter+patterns)
- 📘 **Docs:**  
  - [Join-/Apply-Beispiele mit TVP](https://learn.microsoft.com/en-us/sql/relational-databases/tables/use-table-valued-parameters-database-engine#example)

---

### 2.16 | Anti-Patterns & Checkliste
> **Kurzbeschreibung:** TVP ohne Schlüssel/Index, fehlende Ordinalspalte bei benötigter Reihenfolge, Megabyte-breite UDTTs, plan-sensitive Queries ohne `RECOMPILE`, UDTT zur **Dauerpersistenz** missbrauchen, UDF-Einsatz erwarten, Typänderungen „in-place“ ohne Downtime.

- 📓 **Notebook:**  
  [`08_16_tvp_antipatterns_checkliste.ipynb`](08_16_tvp_antipatterns_checkliste.ipynb)
- 🎥 **YouTube:**  
  - [Common TVP Mistakes](https://www.youtube.com/results?search_query=common+table+valued+parameter+mistakes)
- 📘 **Docs/Blog:**  
  - [Best Practices TVPs (Übersicht)](https://learn.microsoft.com/en-us/sql/relational-databases/tables/use-table-valued-parameters-database-engine)

---

## 3 | Weiterführende Informationen

- 📘 Microsoft Learn: [Using Table-Valued Parameters (DB Engine)](https://learn.microsoft.com/en-us/sql/relational-databases/tables/use-table-valued-parameters-database-engine)  
- 📘 Microsoft Learn: [`CREATE TYPE … AS TABLE`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-type-transact-sql)  
- 📘 Microsoft Learn: [Memory-Optimized Table Types](https://learn.microsoft.com/en-us/sql/relational-databases/in-memory-oltp/memory-optimized-table-types)  
- 📘 Microsoft Learn: [Cardinality Estimation – Guide](https://learn.microsoft.com/en-us/sql/relational-databases/performance/cardinality-estimation)  
- 📘 Microsoft Learn: [`sys.table_types` / `sys.types` / `sys.columns`](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-table-types-transact-sql)  
- 📘 Microsoft Learn: [Granting Permissions on Types (`GRANT`)](https://learn.microsoft.com/en-us/sql/t-sql/statements/grant-transact-sql)  
- 📘 .NET Guide: [Table-Valued Parameters in ADO.NET](https://learn.microsoft.com/en-us/dotnet/framework/data/adonet/sql/table-valued-parameters)  
- 📝 Simple Talk (Redgate): *Working with Table-Valued Parameters*  
- 📝 Erik Darling: *TVPs, Estimates & Recompile Patterns* – https://www.erikdarlingdata.com/  
- 📝 Brent Ozar: *Passing Lists to SQL Server – TVPs vs. Alternatives* – https://www.brentozar.com/  
- 📝 SQLPerformance: *TVP Performance & tempdb Considerations* – https://www.sqlperformance.com/?s=table+valued+parameter  
- 🎥 YouTube (Data Exposed): *Table-Valued Parameters – Deep Dive* – Suchlink  
- 🎥 YouTube: *.NET + TVP End-to-End Demo* – Suchlink  
