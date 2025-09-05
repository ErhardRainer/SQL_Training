# T-SQL JSON & XML – Übersicht  
*Grundlagen zu JSON und XML in SQL Server*

## 1 | Begriffsdefinition

| SQL-Term | Beschreibung |
|---|---|
| JSON-Speicherung | SQL Server hat **keinen** JSON-Datentyp – JSON wird in `nvarchar(...)`/`nvarchar(max)` gespeichert. |
| `ISJSON` | Prüft, ob ein String gültiges JSON ist (`1`/`0`). |
| `JSON_VALUE` / `JSON_QUERY` | Extrahiert **skalare** (`JSON_VALUE`) bzw. **Objekt/Array**-Fragmente (`JSON_QUERY`) via Pfad (`$.a.b[0]`). |
| `OPENJSON` | Zerlegt JSON in **Zeilen** (key, value, type) oder per `WITH`-Schema in **typisierte Spalten** (meist mit `CROSS APPLY`). |
| `JSON_MODIFY` | Aktualisiert JSON-Dokumente (ersetzen/hinzufügen/entfernen) – Ergebnis ist `nvarchar(...)`. |
| `FOR JSON` | Erzeugt JSON aus Abfrageergebnissen (`AUTO`/`PATH`, Optionen `ROOT`, `INCLUDE_NULL_VALUES`, `WITHOUT_ARRAY_WRAPPER`). |
| JSON-Indizierung | Über **berechnete Spalten** (`JSON_VALUE(...)`) + **persistiert** + **Index** sargierbar machen. |
| XML-Datentyp | Native Spalten-/Variablentyp `xml` mit XQuery-Unterstützung; **typisiert** via **XML-Schema-Collection** oder **untypisiert**. |
| XQuery-Methoden | `nodes()` (Shred), `value()` (Skalar), `query()` (Fragment), `exist()` (Bool), `modify()` (DML für XML). |
| `FOR XML` | Erzeugt XML (`RAW`/`AUTO`/`PATH`) – mit `TYPE` als `xml` zurückgeben statt `nvarchar`. |
| XML-Indizes | **Primärer** XML-Index + **sekundäre** (PATH/VALUE/PROPERTY) für schnellere XQuerys. |
| Namespaces | XML-Namespace-Deklaration im XQuery (`WITH XMLNAMESPACES`) notwendig für präzise Pfade. |
| Kompatibilitätslevel | JSON-Funktionen ab **SQL Server 2016** (Compat **130+**), XQuery seit SQL 2005. |
| Performance-Grundsatz | JSON für leichte flexible Strukturen/Interop, XML für strikte Typisierung/XQuery; beide nicht als „Mülleimer“ für OLTP-Kerne nutzen. |

---

## 2 | Struktur

### 2.1 | JSON vs. XML – Wann was?
> **Kurzbeschreibung:** Einsatzkriterien, Tooling, Typisierung/Validierung, Interop mit Apps/Services.

- 📓 **Notebook:**  
  [`08_01_json_vs_xml_overview.ipynb`](08_01_json_vs_xml_overview.ipynb)

- 🎥 **YouTube:**  
  - [JSON vs XML in SQL Server (Overview)](https://www.youtube.com/results?search_query=sql+server+json+vs+xml)

- 📘 **Docs:**  
  - [JSON in SQL Server – Überblick](https://learn.microsoft.com/en-us/sql/relational-databases/json/json-data-sql-server)  
  - [`xml`-Datentyp – Überblick](https://learn.microsoft.com/en-us/sql/relational-databases/xml/xml-data-type-and-columns-sql-server)

---

### 2.2 | JSON speichern & validieren
> **Kurzbeschreibung:** Spaltentypen, Größen, `ISJSON`, Constraints & Default-Validierung.

- 📓 **Notebook:**  
  [`08_02_json_store_validate.ipynb`](08_02_json_store_validate.ipynb)

- 🎥 **YouTube:**  
  - [ISJSON & Constraints](https://www.youtube.com/results?search_query=sql+server+isjson+constraint)

- 📘 **Docs:**  
  - [`ISJSON`](https://learn.microsoft.com/en-us/sql/t-sql/functions/isjson-transact-sql)

---

### 2.3 | JSON lesen: `JSON_VALUE`/`JSON_QUERY`
> **Kurzbeschreibung:** Pfadsyntax, Skalare vs. Fragmente, NULL/Fehler, `STRICT`-Modus.

- 📓 **Notebook:**  
  [`08_03_json_value_vs_query.ipynb`](08_03_json_value_vs_query.ipynb)

- 🎥 **YouTube:**  
  - [JSON_VALUE & JSON_QUERY Basics](https://www.youtube.com/results?search_query=sql+server+json_value+json_query)

- 📘 **Docs:**  
  - [`JSON_VALUE`](https://learn.microsoft.com/en-us/sql/t-sql/functions/json-value-transact-sql) · [`JSON_QUERY`](https://learn.microsoft.com/en-us/sql/t-sql/functions/json-query-transact-sql)

---

### 2.4 | JSON shredden: `OPENJSON` + `CROSS APPLY`
> **Kurzbeschreibung:** Arrays/Objekte zeilenweise zerlegen; `WITH`-Schema für typisierte Spalten.

- 📓 **Notebook:**  
  [`08_04_openjson_with_schema.ipynb`](08_04_openjson_with_schema.ipynb)

- 🎥 **YouTube:**  
  - [OPENJSON Tutorial](https://www.youtube.com/results?search_query=sql+server+openjson+tutorial)

- 📘 **Docs:**  
  - [`OPENJSON`](https://learn.microsoft.com/en-us/sql/t-sql/functions/openjson-transact-sql)

---

### 2.5 | JSON erzeugen: `FOR JSON` (AUTO/PATH)
> **Kurzbeschreibung:** Flach vs. verschachtelt, Spaltenalias als JSON-Pfad, Optionen (`ROOT`, `INCLUDE_NULL_VALUES`, `WITHOUT_ARRAY_WRAPPER`).

- 📓 **Notebook:**  
  [`08_05_for_json_auto_path.ipynb`](08_05_for_json_auto_path.ipynb)

- 🎥 **YouTube:**  
  - [FOR JSON Explained](https://www.youtube.com/results?search_query=sql+server+for+json)

- 📘 **Docs:**  
  - [`FOR JSON` (AUTO/PATH)](https://learn.microsoft.com/en-us/sql/relational-databases/json/format-query-results-as-json-with-for-json-sql-server)

---

### 2.6 | JSON ändern: `JSON_MODIFY`
> **Kurzbeschreibung:** Werte setzen/entfernen, Arrays erweitern, verschachtelte Updates.

- 📓 **Notebook:**  
  [`08_06_json_modify_update.ipynb`](08_06_json_modify_update.ipynb)

- 🎥 **YouTube:**  
  - [JSON_MODIFY Demo](https://www.youtube.com/results?search_query=sql+server+json_modify)

- 📘 **Docs:**  
  - [`JSON_MODIFY`](https://learn.microsoft.com/en-us/sql/t-sql/functions/json-modify-transact-sql)

---

### 2.7 | JSON & Indizes: computed columns
> **Kurzbeschreibung:** `JSON_VALUE(...)` als **persistierte** berechnete Spalte + Index für Suchen/Joins.

- 📓 **Notebook:**  
  [`08_07_json_indexing_computed_columns.ipynb`](08_07_json_indexing_computed_columns.ipynb)

- 🎥 **YouTube:**  
  - [Indexing JSON Columns](https://www.youtube.com/results?search_query=sql+server+index+json+computed+column)

- 📘 **Docs:**  
  - [Indizes für JSON-Daten](https://learn.microsoft.com/en-us/sql/relational-databases/json/indexes-json-data-sql-server)

---

### 2.8 | XML speichern: typisiert vs. untypisiert
> **Kurzbeschreibung:** `xml`-Spalten, **XML Schema Collections** für Typprüfung & IntelliSense.

- 📓 **Notebook:**  
  [`08_08_xml_typed_vs_untyped.ipynb`](08_08_xml_typed_vs_untyped.ipynb)

- 🎥 **YouTube:**  
  - [XML Data Type Basics](https://www.youtube.com/results?search_query=sql+server+xml+data+type)

- 📘 **Docs:**  
  - [XML Schema Collections](https://learn.microsoft.com/en-us/sql/relational-databases/xml/xml-schema-collections-sql-server)

---

### 2.9 | XQuery-Methoden: `nodes()/value()/query()/exist()/modify()`
> **Kurzbeschreibung:** Shredding, Extraktion, Bool-Prüfung und In-Place-Änderungen; Namespaces verwenden.

- 📓 **Notebook:**  
  [`08_09_xquery_methods.ipynb`](08_09_xquery_methods.ipynb)

- 🎥 **YouTube:**  
  - [XQuery Methods in SQL Server](https://www.youtube.com/results?search_query=sql+server+xquery+nodes+value+exist+modify)

- 📘 **Docs:**  
  - [`xml`-Datentyp – Methodenreferenz](https://learn.microsoft.com/en-us/sql/relational-databases/xml/xml-data-type-methods-reference)

---

### 2.10 | XML erzeugen: `FOR XML` (RAW/AUTO/PATH) & `TYPE`
> **Kurzbeschreibung:** Strukturiertes XML aus SELECT; `TYPE` für `xml`-Rückgabe und korrekte Escapes.

- 📓 **Notebook:**  
  [`08_10_for_xml_path_type.ipynb`](08_10_for_xml_path_type.ipynb)

- 🎥 **YouTube:**  
  - [FOR XML PATH Tutorial](https://www.youtube.com/results?search_query=sql+server+for+xml+path)

- 📘 **Docs:**  
  - [`FOR XML` – Optionen](https://learn.microsoft.com/en-us/sql/relational-databases/xml/for-xml-sql-server)

---

### 2.11 | XML-Indizes: Primary & Secondary
> **Kurzbeschreibung:** Primärer XML-Index + sekundäre (PATH/VALUE/PROPERTY); Speicher-/Wartungs-Trade-offs.

- 📓 **Notebook:**  
  [`08_11_xml_indexes.ipynb`](08_11_xml_indexes.ipynb)

- 🎥 **YouTube:**  
  - [XML Indexes Explained](https://www.youtube.com/results?search_query=sql+server+xml+indexes)

- 📘 **Docs:**  
  - [XML Indexes](https://learn.microsoft.com/en-us/sql/relational-databases/xml/xml-indexes-sql-server)

---

### 2.12 | Validierung: XML Schema & Fehlermeldungen
> **Kurzbeschreibung:** Inhalt gegen XSD prüfen, `TRY...CATCH` für saubere Fehlerberichte.

- 📓 **Notebook:**  
  [`08_12_xml_schema_validation.ipynb`](08_12_xml_schema_validation.ipynb)

- 🎥 **YouTube:**  
  - [XML Schema Validation](https://www.youtube.com/results?search_query=sql+server+xml+schema+collection+validation)

- 📘 **Docs:**  
  - [XML Schema Collections – Arbeiten mit XSD](https://learn.microsoft.com/en-us/sql/relational-databases/xml/xml-schema-collections-sql-server)

---

### 2.13 | Performance & SARGability
> **Kurzbeschreibung:** Funktionen in Prädikaten vermeiden, JSON/ XML-Ausdrücke indizierbar machen, Row/LOB-Auswirkungen.

- 📓 **Notebook:**  
  [`08_13_perf_sarg_json_xml.ipynb`](08_13_perf_sarg_json_xml.ipynb)

- 🎥 **YouTube:**  
  - [Performance JSON vs XML](https://www.youtube.com/results?search_query=sql+server+json+xml+performance)

- 📘 **Docs:**  
  - [Indexdesign – JSON & computed columns](https://learn.microsoft.com/en-us/sql/relational-databases/json/indexes-json-data-sql-server)  
  - [XML Index – Performancehinweise](https://learn.microsoft.com/en-us/sql/relational-databases/xml/xml-indexes-sql-server)

---

### 2.14 | Sicherheit & Robustheit
> **Kurzbeschreibung:** Escaping, Größenlimits, Eingabekontrolle (`ISJSON`, XSD), `QUOTENAME`/Parametrisierung in dynamischem SQL.

- 📓 **Notebook:**  
  [`08_14_security_robustness_json_xml.ipynb`](08_14_security_robustness_json_xml.ipynb)

- 🎥 **YouTube:**  
  - [Securing JSON/XML in SQL](https://www.youtube.com/results?search_query=sql+server+json+xml+security)

- 📘 **Docs:**  
  - [SQL Injection – Übersicht](https://learn.microsoft.com/en-us/sql/relational-databases/security/sql-injection)

---

### 2.15 | Versionen & Kompatibilität (Compat-Level)
> **Kurzbeschreibung:** JSON-Funktionen erfordern i. d. R. Compat **130+**; Verhalten in Azure SQL/SQL Server.

- 📓 **Notebook:**  
  [`08_15_versions_compat_json_xml.ipynb`](08_15_versions_compat_json_xml.ipynb)

- 🎥 **YouTube:**  
  - [Compatibility Level & JSON](https://www.youtube.com/results?search_query=sql+server+json+compatibility+level)

- 📘 **Docs:**  
  - [Kompatibilitätslevel – Setzen/Prüfen](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-database-transact-sql-compatibility-level)

---

### 2.16 | Anti-Patterns & Checkliste
> **Kurzbeschreibung:** `LIKE`-Suche in JSON-Strings, Riesen-Dokumente in OLTP, fehlende Validierung, `SELECT *` → `FOR JSON`, XQuery ohne XML-Index, `FOR XML PATH` als String-Concatenation (statt `STRING_AGG`).

- 📓 **Notebook:**  
  [`08_16_json_xml_anti_patterns.ipynb`](08_16_json_xml_anti_patterns.ipynb)

- 🎥 **YouTube:**  
  - [Common JSON/XML Mistakes](https://www.youtube.com/results?search_query=sql+server+json+xml+mistakes)

- 📘 **Docs/Blog:**  
  - [`STRING_AGG` (statt FOR XML PATH concat)](https://learn.microsoft.com/en-us/sql/t-sql/functions/string-agg-transact-sql)

---

## 3 | Weiterführende Informationen

- 📘 Microsoft Learn: [JSON in SQL Server – Einstieg & Beispiele](https://learn.microsoft.com/en-us/sql/relational-databases/json/json-data-sql-server)  
- 📘 Microsoft Learn: [`OPENJSON`](https://learn.microsoft.com/en-us/sql/t-sql/functions/openjson-transact-sql) · [`ISJSON`](https://learn.microsoft.com/en-us/sql/t-sql/functions/isjson-transact-sql) · [`JSON_VALUE`](https://learn.microsoft.com/en-us/sql/t-sql/functions/json-value-transact-sql) · [`JSON_QUERY`](https://learn.microsoft.com/en-us/sql/t-sql/functions/json-query-transact-sql) · [`JSON_MODIFY`](https://learn.microsoft.com/en-us/sql/t-sql/functions/json-modify-transact-sql)  
- 📘 Microsoft Learn: [`FOR JSON` – AUTO/PATH/ROOT/Options](https://learn.microsoft.com/en-us/sql/relational-databases/json/format-query-results-as-json-with-for-json-sql-server)  
- 📘 Microsoft Learn: [JSON indizierbar machen (computed columns)](https://learn.microsoft.com/en-us/sql/relational-databases/json/indexes-json-data-sql-server)  
- 📘 Microsoft Learn: [`xml`-Datentyp & XQuery-Methoden](https://learn.microsoft.com/en-us/sql/relational-databases/xml/xml-data-type-methods-reference)  
- 📘 Microsoft Learn: [`FOR XML` – RAW/AUTO/PATH/TYPE](https://learn.microsoft.com/en-us/sql/relational-databases/xml/for-xml-sql-server)  
- 📘 Microsoft Learn: [XML Schema Collections & Typed XML](https://learn.microsoft.com/en-us/sql/relational-databases/xml/xml-schema-collections-sql-server)  
- 📘 Microsoft Learn: [XML Indexes (Primary/Secondary)](https://learn.microsoft.com/en-us/sql/relational-databases/xml/xml-indexes-sql-server)  
- 📘 Microsoft Learn: [`STRING_AGG`](https://learn.microsoft.com/en-us/sql/t-sql/functions/string-agg-transact-sql)  
- 📝 Simple Talk (Redgate): *Working with JSON in SQL Server* (Artikelserie)  
- 📝 SQLShack: *OPENJSON & FOR JSON – Praxisbeispiele*  
- 📝 SQLPerformance: *Indexing JSON via Computed Columns*  
- 📝 Itzik Ben-Gan: *XQuery & FOR XML PATH Patterns* – Sammlung  
- 📝 Erik Darling: *JSON Performance & Pitfalls* – https://www.erikdarlingdata.com/  
- 📝 Brent Ozar: *When to use JSON vs Tables* – https://www.brentozar.com/  
- 🎥 YouTube: *SQL Server JSON* – Tutorials/Playlists (Suche)  
- 🎥 YouTube: *XML & XQuery in SQL Server* – Tutorials/Playlists (Suche)  
