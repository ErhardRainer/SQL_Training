# T-SQL JSON für ETL – Übersicht  
*Verarbeitung von JSON-Daten, Validierung, Fehlertoleranz, Performance*

## 1 | Begriffsdefinition

| SQL-Term | Beschreibung |
|---|---|
| JSON in SQL Server | **Kein** eigener `JSON`-Datentyp – JSON wird in `NVARCHAR` (meist `NVARCHAR(MAX)`) gespeichert/verarbeitet. |
| `ISJSON` | Prüft, ob ein Ausdruck gültiges JSON ist (`CHECK (ISJSON(JsonCol)=1)`); nützlich für **Constraints**/Filter. |
| `JSON_VALUE` | Extrahiert **skalare** Werte (bis `NVARCHAR(4000)`); liefert `NULL` bei fehlendem Pfad (lax). |
| `JSON_QUERY` | Extrahiert **Objekt/Array** als JSON-Fragment (`NVARCHAR(MAX)`). |
| `JSON_MODIFY` | Aktualisiert/fügt JSON-Pfade inline (Rückgabe ist geänderter JSON-Text). |
| `OPENJSON` | **Shreddern** von JSON zu Zeilen/Spalten; ohne `WITH` (Key/Value/Type) oder mit `WITH` (stark typisiert, schneller). *(Erfordert Kompat.-Level ≥ 130).* |
| JSON Path | `$` als Wurzel, `$.a.b[0]`; **lax** (Standard) → `NULL` bei fehlendem Pfad; **strict** (`strict $.a`) → Fehler bei fehlendem Pfad. |
| `FOR JSON` | Generiert JSON aus Resultsets (`AUTO`/`PATH`, `WITHOUT_ARRAY_WRAPPER`, `INCLUDE_NULL_VALUES`, `ROOT`). |
| Line-Delimited JSON | Eine JSON-Zeile pro Datensatz (JSONL); oft via `OPENROWSET(BULK … SINGLE_CLOB)` + Split verarbeitet. |
| Validierung | Formale (`ISJSON`) + fachliche Validierung (Pflichtfelder/Datentypen via `OPENJSON WITH` + `TRY_CONVERT`). |
| Fehlertoleranz | **LAX-Pfade**, `TRY_CAST/TRY_CONVERT`, Quarantäne-Tabellen, `TRY…CATCH` & Zählwerte im **Run-Log**. |
| Indizierung | **Persistierte** berechnete Spalten aus `JSON_VALUE(...)` + **Indizes** (auch **Filtered** auf `ISJSON=1`). |
| Größen/Encoding | JSON ist Unicode (`NVARCHAR`) – Dateilast i. d. R. UTF-8; beim Import passende **CODEPAGE** wählen. |
| ETL-Formate | Arrays/Nesting via `CROSS APPLY OPENJSON(@json, '$.items')`; Rekursion durch weitere `OPENJSON` auf Unterobjekten. |

---

## 2 | Struktur

### 2.1 | Grundlagen & Funktionen (ISJSON, JSON_VALUE/QUERY/MODIFY, OPENJSON)
> **Kurzbeschreibung:** Überblick über JSON-Stack in T-SQL, Einsatzfelder im ETL und typische Stolperfallen.

- 📓 **Notebook:**  
  [`08_01_json_grundlagen_overview.ipynb`](08_01_json_grundlagen_overview.ipynb)
- 🎥 **YouTube:**  
  - [JSON in SQL Server – Basics](https://www.youtube.com/results?search_query=sql+server+json+basics)
- 📘 **Docs:**  
  - [JSON-Daten in SQL Server](https://learn.microsoft.com/en-us/sql/relational-databases/json/json-data-sql-server)

---

### 2.2 | Import: Dateien/Streams laden (OPENROWSET BULK, UTF-8, JSONL)
> **Kurzbeschreibung:** JSON-Dateien per `OPENROWSET(BULK)`/`BULK INSERT` laden; *SINGLE_CLOB*/*SINGLE_NCLOB*, Codepages, große Dateien.

- 📓 **Notebook:**  
  [`08_02_import_openrowset_bulk_json.ipynb`](08_02_import_openrowset_bulk_json.ipynb)
- 🎥 **YouTube:**  
  - [Load JSON Files with OPENROWSET](https://www.youtube.com/results?search_query=sql+server+openrowset+json)
- 📘 **Docs:**  
  - [`OPENROWSET(BULK)`](https://learn.microsoft.com/en-us/sql/t-sql/functions/openrowset-transact-sql) ・ [`BULK INSERT`](https://learn.microsoft.com/en-us/sql/t-sql/statements/bulk-insert-transact-sql)

---

### 2.3 | Shreddern mit `OPENJSON` – Key/Value vs. `WITH`-Schema
> **Kurzbeschreibung:** Unterschied „ungeschematisiert“ (Key/Value/Type) vs. **typisiertes** `WITH` (schneller, sicherer).

- 📓 **Notebook:**  
  [`08_03_openjson_with_schema.ipynb`](08_03_openjson_with_schema.ipynb)
- 🎥 **YouTube:**  
  - [OPENJSON WITH Explained](https://www.youtube.com/results?search_query=sql+server+openjson+with)
- 📘 **Docs:**  
  - [`OPENJSON` – Referenz & Beispiele](https://learn.microsoft.com/en-us/sql/relational-databases/json/openjson-transact-sql)

---

### 2.4 | Arrays & Nested Objects (CROSS APPLY, `AS JSON`)
> **Kurzbeschreibung:** Arrays über `CROSS APPLY OPENJSON('$..')` iterieren; Unterobjekte mit `AS JSON` weiter verarbeiten.

- 📓 **Notebook:**  
  [`08_04_arrays_nested_crossapply.ipynb`](08_04_arrays_nested_crossapply.ipynb)
- 🎥 **YouTube:**  
  - [Parse Nested JSON Arrays](https://www.youtube.com/results?search_query=sql+server+parse+nested+json)
- 📘 **Docs:**  
  - [`OPENJSON … WITH (col type '$.path' **AS JSON**)`](https://learn.microsoft.com/en-us/sql/relational-databases/json/openjson-transact-sql#examples)

---

### 2.5 | Validierung: **Formale** + **Fachliche** Checks
> **Kurzbeschreibung:** `ISJSON` + Pflichtpfade (**strict**), Datentypprüfungen (`TRY_CONVERT`), Regelverletzungen in **Reject**-Tabellen.

- 📓 **Notebook:**  
  [`08_05_validation_isjson_strict_rules.ipynb`](08_05_validation_isjson_strict_rules.ipynb)
- 🎥 **YouTube:**  
  - [Validate JSON in ETL](https://www.youtube.com/results?search_query=sql+server+validate+json)
- 📘 **Docs:**  
  - [`ISJSON`](https://learn.microsoft.com/en-us/sql/t-sql/functions/isjson-transact-sql) ・ [JSON-Pfade (lax/strict)](https://learn.microsoft.com/en-us/sql/relational-databases/json/json-path-expressions-sql-server)

---

### 2.6 | Fehlertoleranz: LAX-Pfade, TRY_CONVERT, Quarantäne
> **Kurzbeschreibung:** Robuste Pipelines mit `TRY…CATCH`, `TRY_CAST/TRY_CONVERT`, Zählwerten & **Run-Log**.

- 📓 **Notebook:**  
  [`08_06_fault_tolerance_try_convert_quarantine.ipynb`](08_06_fault_tolerance_try_convert_quarantine.ipynb)
- 🎥 **YouTube:**  
  - [Error Handling for JSON ETL](https://www.youtube.com/results?search_query=sql+server+json+error+handling)
- 📘 **Docs:**  
  - [`TRY_CONVERT`](https://learn.microsoft.com/en-us/sql/t-sql/functions/try-convert-transact-sql) ・ [`TRY…CATCH`](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/try-catch-transact-sql)

---

### 2.7 | Idempotenz & Wasserzeichen mit JSON-Quellen
> **Kurzbeschreibung:** High-Water-Mark (z. B. `LastModified`/`rowversion`) + Hashdiff aus JSON-Feldern; Upsert-Muster.

- 📓 **Notebook:**  
  [`08_07_idempotenz_wasserzeichen_json.ipynb`](08_07_idempotenz_wasserzeichen_json.ipynb)
- 🎥 **YouTube:**  
  - [Incremental Loads from JSON](https://www.youtube.com/results?search_query=incremental+load+json+sql+server)
- 📘 **Docs:**  
  - [`HASHBYTES` (SHA2_256)](https://learn.microsoft.com/en-us/sql/t-sql/functions/hashbytes-transact-sql)

---

### 2.8 | Aufbereitung & Normalisierung (Staging → Core)
> **Kurzbeschreibung:** JSON shapen, Normalformen befüllen (Parent/Child), Schlüsselzuordnung, referentielle Checks.

- 📓 **Notebook:**  
  [`08_08_normalisierung_parent_child.ipynb`](08_08_normalisierung_parent_child.ipynb)
- 🎥 **YouTube:**  
  - [Normalize JSON to Relational](https://www.youtube.com/results?search_query=normalize+json+to+sql+server)
- 📘 **Docs:**  
  - [Beispiele für `OPENJSON` → Relationen](https://learn.microsoft.com/en-us/sql/relational-databases/json/convert-json-data-to-rows-and-columns-with-openjson)

---

### 2.9 | Indizes & SARGability: **Computed Columns** aus JSON
> **Kurzbeschreibung:** Persistierte Spalten auf `JSON_VALUE(...)` + **(Filtered) Index**; Performance/Plan-Stabilität.

- 📓 **Notebook:**  
  [`08_09_computed_columns_json_indexing.ipynb`](08_09_computed_columns_json_indexing.ipynb)
- 🎥 **YouTube:**  
  - [Index JSON Fields via Computed Columns](https://www.youtube.com/results?search_query=sql+server+json+index+computed+column)
- 📘 **Docs:**  
  - [Indexing JSON data](https://learn.microsoft.com/en-us/sql/relational-databases/json/index-json-data)

---

### 2.10 | `FOR JSON` – saubere JSON-Ausgabe für APIs
> **Kurzbeschreibung:** `AUTO` vs. `PATH`, `WITHOUT_ARRAY_WRAPPER`, `INCLUDE_NULL_VALUES`, Steuerung von Feldnamen/Struktur.

- 📓 **Notebook:**  
  [`08_10_for_json_output_patterns.ipynb`](08_10_for_json_output_patterns.ipynb)
- 🎥 **YouTube:**  
  - [FOR JSON PATH Deep Dive](https://www.youtube.com/results?search_query=sql+server+for+json+path)
- 📘 **Docs:**  
  - [`FOR JSON` – Referenz](https://learn.microsoft.com/en-us/sql/relational-databases/json/format-query-results-as-json-with-for-json-sql-server)

---

### 2.11 | Updates im JSON (`JSON_MODIFY`) & Patch-Strategien
> **Kurzbeschreibung:** Felder setzen/entfernen/array-append; Vorsicht bei großen JSONs (Neuschreiben des Strings).

- 📓 **Notebook:**  
  [`08_11_json_modify_patch_patterns.ipynb`](08_11_json_modify_patch_patterns.ipynb)
- 🎥 **YouTube:**  
  - [JSON_MODIFY Examples](https://www.youtube.com/results?search_query=json_modify+sql+server)
- 📘 **Docs:**  
  - [`JSON_MODIFY`](https://learn.microsoft.com/en-us/sql/relational-databases/json/json-modify-transact-sql)

---

### 2.12 | Qualitätssicherung: Constraints, Schemas & Tests
> **Kurzbeschreibung:** `CHECK (ISJSON(...)=1)`, Pflichtfelder via **strict**-Pfade testen, Testdaten/Golden Files.

- 📓 **Notebook:**  
  [`08_12_quality_checks_constraints_schema.ipynb`](08_12_quality_checks_constraints_schema.ipynb)
- 🎥 **YouTube:**  
  - [JSON Constraints & Testing](https://www.youtube.com/results?search_query=sql+server+json+constraints)
- 📘 **Docs:**  
  - [JSON-Validierung mit Pfaden](https://learn.microsoft.com/en-us/sql/relational-databases/json/json-path-expressions-sql-server)

---

### 2.13 | Große Datenmengen: Batching, Minimal Logging, Parallelisierung
> **Kurzbeschreibung:** *Landing* in Heap/`#temp`, Batch-Loops (`TOP (N)`), minimal geloggte Loads, Partitionierung.

- 📓 **Notebook:**  
  [`08_13_large_scale_batched_json_etl.ipynb`](08_13_large_scale_batched_json_etl.ipynb)
- 🎥 **YouTube:**  
  - [Batch Process JSON at Scale](https://www.youtube.com/results?search_query=batch+process+json+sql+server)
- 📘 **Docs:**  
  - [Performancehinweise JSON](https://learn.microsoft.com/en-us/sql/relational-databases/json/optimize-json-processing-with-in-memory-oltp) *(allg. Hinweise)*

---

### 2.14 | Sicherheit & Governance (Least Privilege, Secrets)
> **Kurzbeschreibung:** Trennung `landing/stg/core`, Rollen für JSON-Tabellen, Module-Signing, Secrets (z. B. Pfade) nicht hardcoden.

- 📓 **Notebook:**  
  [`08_14_security_governance_json_etl.ipynb`](08_14_security_governance_json_etl.ipynb)
- 🎥 **YouTube:**  
  - [Secure JSON Pipelines](https://www.youtube.com/results?search_query=secure+json+etl+sql+server)
- 📘 **Docs:**  
  - [Permissions & Securables – Überblick](https://learn.microsoft.com/en-us/sql/relational-databases/security/permissions-database-engine)

---

### 2.15 | Monitoring & Betrieb (Zählwerte, Run-Log, Alerts)
> **Kurzbeschreibung:** Läufe protokollieren (gelesen/valid/invalid/geschrieben), Alerting via SQL Agent/DB Mail, Trendberichte.

- 📓 **Notebook:**  
  [`08_15_monitoring_runlog_alerts.ipynb`](08_15_monitoring_runlog_alerts.ipynb)
- 🎥 **YouTube:**  
  - [ETL Run Logging Patterns](https://www.youtube.com/results?search_query=etl+run+logging+sql+server)
- 📘 **Docs:**  
  - [SQL Server Agent – Benachrichtigungen](https://learn.microsoft.com/en-us/sql/ssms/agent/alerts)

---

### 2.16 | Anti-Patterns & Checkliste
> **Kurzbeschreibung:** `LIKE` zum Parsen, `JSON_VALUE` für große Fragmente statt `JSON_QUERY`, fehlende `ISJSON`-Checks, nicht persistierte berechnete Spalten, blindes `MERGE`, fehlende Fehlertoleranz/Quarantäne, `NVARCHAR(4000)`-Truncation.

- 📓 **Notebook:**  
  [`08_16_antipatterns_checkliste_json_etl.ipynb`](08_16_antipatterns_checkliste_json_etl.ipynb)
- 🎥 **YouTube:**  
  - [Common JSON ETL Mistakes](https://www.youtube.com/results?search_query=common+json+mistakes+sql+server)
- 📘 **Docs/Blog:**  
  - [Best Practices – JSON in SQL Server](https://learn.microsoft.com/en-us/sql/relational-databases/json/json-data-sql-server#best-practices)

---

## 3 | Weiterführende Informationen

- 📘 Microsoft Learn: [JSON – Überblick & Beispiele](https://learn.microsoft.com/en-us/sql/relational-databases/json/json-data-sql-server)  
- 📘 Microsoft Learn: [`OPENJSON` – Referenz](https://learn.microsoft.com/en-us/sql/relational-databases/json/openjson-transact-sql)  
- 📘 Microsoft Learn: [`JSON_VALUE` / `JSON_QUERY` / `JSON_MODIFY`](https://learn.microsoft.com/en-us/sql/relational-databases/json/json-functions-transact-sql)  
- 📘 Microsoft Learn: [`FOR JSON` – Ausgabe formatieren](https://learn.microsoft.com/en-us/sql/relational-databases/json/format-query-results-as-json-with-for-json-sql-server)  
- 📘 Microsoft Learn: [JSON-Pfad-Ausdrücke (lax/strict)](https://learn.microsoft.com/en-us/sql/relational-databases/json/json-path-expressions-sql-server)  
- 📘 Microsoft Learn: [JSON indizieren (Computed Columns)](https://learn.microsoft.com/en-us/sql/relational-databases/json/index-json-data)  
- 📘 Microsoft Learn: [`OPENROWSET(BULK)` – Files laden](https://learn.microsoft.com/en-us/sql/t-sql/functions/openrowset-transact-sql)  
- 📘 Microsoft Learn: [`TRY_CONVERT` / `TRY_CAST`](https://learn.microsoft.com/en-us/sql/t-sql/functions/try-convert-transact-sql)  
- 📝 Simple Talk (Redgate): *Working with JSON in SQL Server*  
- 📝 SQLPerformance: *Indexing & Tuning JSON Workloads* – https://www.sqlperformance.com/?s=json  
- 📝 Erik Darling: *Computed Columns on JSON_VALUE – Pros & Cons* – https://www.erikdarlingdata.com/  
- 📝 Brent Ozar: *Stop Shredding JSON the Slow Way* – https://www.brentozar.com/  
- 📝 Itzik Ben-Gan (Blog/Artikel): *OPENJSON Patterns & Strict Paths*  
- 🎥 YouTube (Data Exposed): *JSON in SQL Server – Deep Dive* – Suchlink  
- 🎥 YouTube: *OPENJSON WITH + Arrays – Demo* – Suchlink  
