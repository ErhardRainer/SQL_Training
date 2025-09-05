# T-SQL Bulk Load & Export – Übersicht  
*Import/Export von Daten: `BULK INSERT`, `bcp`, `OPENROWSET(BULK)`, Performance-Aspekte*

## 1 | Begriffsdefinition

| SQL-Term | Beschreibung |
|---|---|
| `BULK INSERT` | T-SQL-Befehl zum **schnellen Import** aus Dateien in eine Tabelle; vielfältige Optionen (Trennzeichen, Codepage, Fehlerdatei, Batches). |
| `bcp` (Bulk Copy Program) | **Kommandozeilen-Tool** zum Export (`out`), Import (`in`) und Query-Export (`queryout`); unterstützt Formatdateien & Hints. |
| `OPENROWSET(BULK …)` | Liest Datei-Inhalte in T-SQL (z. B. `SINGLE_CLOB/BLOB/NCLOB` oder tabellarisch ab SQL 2022 `FORMAT='CSV'`). |
| Formatdatei | **Nicht-XML** (`.fmt`) oder **XML** (`.xml`) Beschreibung der Dateistruktur ↔ Tabellenspalten (Mapping, Datentypen, Reihenfolge). |
| Trenn-/Zeilenende | `FIELDTERMINATOR`, `ROWTERMINATOR`, **CSV-Optionen** (SQL 2022: `FORMAT='CSV'`, `FIELDQUOTE`, `PARSER_VERSION='2.0'`). |
| Zeichensatz | `CODEPAGE` (z. B. `65001` = UTF-8), `DATAFILETYPE` (`char|native|widechar|widenative`). |
| Steuerung | `FIRSTROW`/`LASTROW`, `KEEPIDENTITY`, `KEEPNULLS`, `FIRE_TRIGGERS`, `CHECK_CONSTRAINTS`, `TABLOCK`, `ERRORFILE`, `MAXERRORS`. |
| Batching | `BATCHSIZE`, `ROWS_PER_BATCH` – teilt Ladevorgang in kleinere Transaktionen für Durchsatz/Log-Kontrolle. |
| Minimal Logging | Mit `TABLOCK`, Heaps/leere Clustered Indizes, **Recovery Model** `SIMPLE`/`BULK_LOGGED` (in `FULL` nur eingeschränkt). |
| ORDER-Hint | `ORDER (Spalte [ASC|DESC] …)` – teilt SQL Server sortierte Eingabe mit → effizienter CI/NCI-Aufbau (wenn Sortierung **passt**). |
| Azure/Cloud | `BULK INSERT … WITH (DATA_SOURCE = …)` aus **Azure Blob Storage**; `bcp` via Netzwerk. |
| Sicherheit | Rechte: `bulkadmin` (Serverrolle) bzw. `ADMINISTER BULK OPERATIONS`; Dateisystem-/Blob-Zugriff beachten. |
| Fehlerhandling | `ERRORFILE` mit fehlerhaften Zeilen, `MAXERRORS`-Schwelle, **Wiederanläufe** via Batches/Offsets. |
| Export | `bcp … out`, `FOR JSON`/`FOR XML` (formatierte Exporte), `SELECT … INTO OUTFILE` **(T-SQL: via bcp/SSIS, kein OUTFILE)**. |
| Performance-Grundsatz | Staging-Tabellen, Indizes/Trigger minimieren, passende Codepage/Trenner, große Batches + `TABLOCK`, parallele Streams. |

---

## 2 | Struktur

### 2.1 | Überblick: Werkzeuge & Anwendungsfälle
> **Kurzbeschreibung:** Wann `BULK INSERT`, `bcp` oder `OPENROWSET(BULK)`? Export vs. Import, Offline-/Online-Szenarien.

- 📓 **Notebook:**  
  [`08_01_bulk_tools_overview.ipynb`](08_01_bulk_tools_overview.ipynb)
- 🎥 **YouTube:**  
  - [SQL Server Bulk Insert vs bcp – Überblick](https://www.youtube.com/results?search_query=sql+server+bulk+insert+bcp+overview)
- 📘 **Docs:**  
  - [`BULK INSERT` (T-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/statements/bulk-insert-transact-sql)  
  - [`bcp` Utility](https://learn.microsoft.com/en-us/sql/tools/bcp-utility)

---

### 2.2 | `BULK INSERT` – Syntax & Optionen
> **Kurzbeschreibung:** Kernsyntax mit Trenner/Zeilenende/Codepage, Batching, Fehlerdatei, Identitäten/NULLs/Trigger.

- 📓 **Notebook:**  
  [`08_02_bulk_insert_syntax.ipynb`](08_02_bulk_insert_syntax.ipynb)
- 🎥 **YouTube:**  
  - [BULK INSERT Tutorial](https://www.youtube.com/results?search_query=sql+server+bulk+insert+tutorial)
- 📘 **Docs:**  
  - [`BULK INSERT` – Argumente](https://learn.microsoft.com/en-us/sql/t-sql/statements/bulk-insert-transact-sql#arguments)

---

### 2.3 | CSV & moderne Parser (SQL Server 2022+)
> **Kurzbeschreibung:** `FORMAT='CSV'`, `FIELDQUOTE='"'`, `PARSER_VERSION='2.0'`, UTF-8 (`CODEPAGE=65001`).

- 📓 **Notebook:**  
  [`08_03_bulk_insert_csv_sql2022.ipynb`](08_03_bulk_insert_csv_sql2022.ipynb)
- 🎥 **YouTube:**  
  - [SQL 2022 CSV Bulk Load](https://www.youtube.com/results?search_query=sql+server+2022+csv+bulk+insert)
- 📘 **Docs:**  
  - [`BULK INSERT` – CSV/Parser v2.0](https://learn.microsoft.com/en-us/sql/t-sql/statements/bulk-insert-transact-sql#csv-format)

---

### 2.4 | `OPENROWSET(BULK …)` – Dateien lesen
> **Kurzbeschreibung:** `SINGLE_CLOB/BLOB/NCLOB` vs. tabellarisch (CSV, SQL 2022), Staging via `CROSS APPLY`.

- 📓 **Notebook:**  
  [`08_04_openrowset_bulk_patterns.ipynb`](08_04_openrowset_bulk_patterns.ipynb)
- 🎥 **YouTube:**  
  - [OPENROWSET(BULK) Basics](https://www.youtube.com/results?search_query=openrowset+bulk+sql+server)
- 📘 **Docs:**  
  - [`OPENROWSET(BULK…)`](https://learn.microsoft.com/en-us/sql/t-sql/functions/openrowset-transact-sql)

---

### 2.5 | Formatdateien (XML / nicht-XML)
> **Kurzbeschreibung:** Spaltenmapping, Datentypen, optionale Felder; wann Formatdateien Vorteile bringen.

- 📓 **Notebook:**  
  [`08_05_format_files_xml_nonxml.ipynb`](08_05_format_files_xml_nonxml.ipynb)
- 🎥 **YouTube:**  
  - [bcp Format Files](https://www.youtube.com/results?search_query=sql+server+bcp+format+file)
- 📘 **Docs:**  
  - [Create a Format File](https://learn.microsoft.com/en-us/sql/relational-databases/import-export/create-a-format-file-sql-server)

---

### 2.6 | `bcp` – Import/Export von der Kommandozeile
> **Kurzbeschreibung:** `in/out/queryout`, `-c/-w/-n`, `-t/-r`, `-S/-d/-U/-P`/`-E/-k`, `-b` Batchgröße, `-a` Paketgröße, `-h` Hints.

- 📓 **Notebook:**  
  [`08_06_bcp_cli_grundlagen.ipynb`](08_06_bcp_cli_grundlagen.ipynb)
- 🎥 **YouTube:**  
  - [bcp Utility Tutorial](https://www.youtube.com/results?search_query=sql+server+bcp+utility+tutorial)
- 📘 **Docs:**  
  - [`bcp`-Syntax & Beispiele](https://learn.microsoft.com/en-us/sql/tools/bcp-utility#syntax)

---

### 2.7 | Azure Blob & externe Datenquellen
> **Kurzbeschreibung:** `CREATE EXTERNAL DATA SOURCE` + `BULK INSERT … WITH (DATA_SOURCE=…)`, SAS/Managed Identity.

- 📓 **Notebook:**  
  [`08_07_bulk_azure_blob_datasource.ipynb`](08_07_bulk_azure_blob_datasource.ipynb)
- 🎥 **YouTube:**  
  - [Bulk Insert from Azure Blob](https://www.youtube.com/results?search_query=sql+server+bulk+insert+azure+blob)
- 📘 **Docs:**  
  - [Load files from Azure Blob](https://learn.microsoft.com/en-us/sql/relational-databases/import-export/import-bulk-data-by-using-bulk-insert-or-openrowset-bulk-sql-server#azure-blob-storage)

---

### 2.8 | Minimal Logging & Recovery Model
> **Kurzbeschreibung:** Bedingungen für minimal geloggte Bulk Loads (`TABLOCK`, Heaps/leere CIs, `SIMPLE`/`BULK_LOGGED`).

- 📓 **Notebook:**  
  [`08_08_minimal_logging_patterns.ipynb`](08_08_minimal_logging_patterns.ipynb)
- 🎥 **YouTube:**  
  - [Minimal Logging Explained](https://www.youtube.com/results?search_query=sql+server+minimal+logging+bulk)
- 📘 **Docs:**  
  - [Bulk Import and Minimal Logging](https://learn.microsoft.com/en-us/sql/relational-databases/import-export/prerequisites-for-minimal-logging-in-bulk-import)

---

### 2.9 | Performance-Tuning: Batching, `TABLOCK`, ORDER-Hint
> **Kurzbeschreibung:** Große Batches (`BATCHSIZE`), `ROWS_PER_BATCH`, `TABLOCK`, sortierte Eingabe (`ORDER(...)`) für Indizes.

- 📓 **Notebook:**  
  [`08_09_bulk_performance_tuning.ipynb`](08_09_bulk_performance_tuning.ipynb)
- 🎥 **YouTube:**  
  - [Bulk Load Performance Tips](https://www.youtube.com/results?search_query=sql+server+bulk+insert+performance)
- 📘 **Docs:**  
  - [Performance Considerations for Bulk Import](https://learn.microsoft.com/en-us/sql/relational-databases/import-export/performance-guidelines-for-sql-server-bulk-import)

---

### 2.10 | Staging, Constraints, Trigger
> **Kurzbeschreibung:** In **Staging-Tabellen** laden, danach validieren; `CHECK_CONSTRAINTS`/`FIRE_TRIGGERS` bewusst steuern.

- 📓 **Notebook:**  
  [`08_10_staging_constraints_triggers.ipynb`](08_10_staging_constraints_triggers.ipynb)
- 🎥 **YouTube:**  
  - [Staging Table Strategy](https://www.youtube.com/results?search_query=sql+server+staging+tables+bulk+load)
- 📘 **Docs:**  
  - [`BULK INSERT` – Constraints/Triggers](https://learn.microsoft.com/en-us/sql/t-sql/statements/bulk-insert-transact-sql#arguments)

---

### 2.11 | Codepages, Typen & Skipping
> **Kurzbeschreibung:** `CODEPAGE`, `DATAFILETYPE`, `KEEPNULLS`, `FIRSTROW`/`LASTROW`; sichere Typkonvertierung.

- 📓 **Notebook:**  
  [`08_11_codepage_types_skiprows.ipynb`](08_11_codepage_types_skiprows.ipynb)
- 🎥 **YouTube:**  
  - [UTF-8 & Codepage in Bulk Load](https://www.youtube.com/results?search_query=sql+server+bulk+insert+utf8)
- 📘 **Docs:**  
  - [`CODEPAGE`/`DATAFILETYPE`](https://learn.microsoft.com/en-us/sql/t-sql/statements/bulk-insert-transact-sql#codepage)  

---

### 2.12 | Fehleranalyse: `ERRORFILE`, `MAXERRORS`, Wiederanlauf
> **Kurzbeschreibung:** Schmutzige Daten isolieren, Logs lesen, Resume-Strategien (Datei splitten, Offsets/Batches).

- 📓 **Notebook:**  
  [`08_12_errorfile_maxerrors_retry.ipynb`](08_12_errorfile_maxerrors_retry.ipynb)
- 🎥 **YouTube:**  
  - [Handling Bad Rows in Bulk Loads](https://www.youtube.com/results?search_query=sql+server+bulk+insert+errorfile)
- 📘 **Docs:**  
  - [`ERRORFILE`/`MAXERRORS`](https://learn.microsoft.com/en-us/sql/t-sql/statements/bulk-insert-transact-sql#errorfile)

---

### 2.13 | Parallelisierung & Skalierung
> **Kurzbeschreibung:** Mehrere **Datei-Splits**/Streams parallel laden, Dateigröße/IO, TempDB/Log beobachten.

- 📓 **Notebook:**  
  [`08_13_parallel_bulk_streams.ipynb`](08_13_parallel_bulk_streams.ipynb)
- 🎥 **YouTube:**  
  - [Parallel Bulk Loading](https://www.youtube.com/results?search_query=sql+server+parallel+bulk+load)
- 📘 **Docs:**  
  - [Performance Guidelines (Parallel IO)](https://learn.microsoft.com/en-us/sql/relational-databases/import-export/performance-guidelines-for-sql-server-bulk-import)

---

### 2.14 | Sicherheit & Rechte
> **Kurzbeschreibung:** `bulkadmin`/`ADMINISTER BULK OPERATIONS`, Dateifreigaben, Protokolle (SAS), `EXECUTE AS`, Audit.

- 📓 **Notebook:**  
  [`08_14_security_permissions_bulk.ipynb`](08_14_security_permissions_bulk.ipynb)
- 🎥 **YouTube:**  
  - [Bulk Admin Permissions](https://www.youtube.com/results?search_query=sql+server+bulkadmin+permissions)
- 📘 **Docs:**  
  - [Serverrollen & Berechtigungen (bulkadmin)](https://learn.microsoft.com/en-us/sql/relational-databases/security/authentication-access/server-level-roles#fixed-server-level-roles)

---

### 2.15 | Exportpatterns: `bcp queryout`, JSON/XML
> **Kurzbeschreibung:** Große Exporte effizient; `bcp queryout`, `FOR JSON`/`FOR XML`, Kompression per OS.

- 📓 **Notebook:**  
  [`08_15_export_patterns_bcp_json_xml.ipynb`](08_15_export_patterns_bcp_json_xml.ipynb)
- 🎥 **YouTube:**  
  - [bcp queryout Examples](https://www.youtube.com/results?search_query=sql+server+bcp+queryout)
- 📘 **Docs:**  
  - [`bcp` – `queryout`](https://learn.microsoft.com/en-us/sql/tools/bcp-utility#bcp-commands)

---

### 2.16 | Anti-Patterns & Checkliste
> **Kurzbeschreibung:** Falsche Codepage, Funktionen auf Zielspalten (Konvertierung), ohne Batches/`TABLOCK`, mit aktiven Triggern/Indizes in OLTP, fehlendes `ERRORFILE`, Log-Explosion im `FULL`-Model.

- 📓 **Notebook:**  
  [`08_16_bulk_anti_patterns_checkliste.ipynb`](08_16_bulk_anti_patterns_checkliste.ipynb)
- 🎥 **YouTube:**  
  - [Common Bulk Load Mistakes](https://www.youtube.com/results?search_query=sql+server+bulk+insert+mistakes)
- 📘 **Docs/Blog:**  
  - [Bulk Import – Best Practices](https://learn.microsoft.com/en-us/sql/relational-databases/import-export/performance-guidelines-for-sql-server-bulk-import)

---

## 3 | Weiterführende Informationen

- 📘 Microsoft Learn: [`BULK INSERT` (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/statements/bulk-insert-transact-sql)  
- 📘 Microsoft Learn: [`OPENROWSET(BULK…)` – Referenz & Beispiele](https://learn.microsoft.com/en-us/sql/t-sql/functions/openrowset-transact-sql)  
- 📘 Microsoft Learn: [`bcp` Utility – Handbuch](https://learn.microsoft.com/en-us/sql/tools/bcp-utility)  
- 📘 Microsoft Learn: [Formatdateien (XML/nicht-XML)](https://learn.microsoft.com/en-us/sql/relational-databases/import-export/create-a-format-file-sql-server)  
- 📘 Microsoft Learn: [Voraussetzungen für **Minimal Logging**](https://learn.microsoft.com/en-us/sql/relational-databases/import-export/prerequisites-for-minimal-logging-in-bulk-import)  
- 📘 Microsoft Learn: [**Performance-Guidelines** für Bulk Import](https://learn.microsoft.com/en-us/sql/relational-databases/import-export/performance-guidelines-for-sql-server-bulk-import)  
- 📘 Microsoft Learn: [BULK aus **Azure Blob** (`DATA_SOURCE`)](https://learn.microsoft.com/en-us/sql/relational-databases/import-export/import-bulk-data-by-using-bulk-insert-or-openrowset-bulk-sql-server#azure-blob-storage)  
- 📘 Microsoft Learn: [Fehlerdateien/Fehlergrenzen (`ERRORFILE`, `MAXERRORS`)](https://learn.microsoft.com/en-us/sql/t-sql/statements/bulk-insert-transact-sql#errorfile)  
- 📘 Microsoft Learn: [Codepage/UTF-8 (`CODEPAGE=65001`)](https://learn.microsoft.com/en-us/sql/t-sql/statements/bulk-insert-transact-sql#codepage)  
- 📘 Microsoft Learn: [Sicherheit & Rollen (`bulkadmin`)](https://learn.microsoft.com/en-us/sql/relational-databases/security/authentication-access/server-level-roles#fixed-server-level-roles)  
- 📝 SQLPerformance: *Bulk Load Tuning (Batches, Tablock, Parallelism)* – https://www.sqlperformance.com/?s=bulk+insert  
- 📝 Simple Talk (Redgate): *bcp & Format Files – Deep Dive*  
- 📝 Brent Ozar: *How to Load Data Fast in SQL Server* – https://www.brentozar.com/  
- 📝 Erik Darling: *CSV Quirks & BULK INSERT Pitfalls* – https://www.erikdarlingdata.com/  
- 🎥 YouTube (Data Exposed): *High-Throughput Bulk Loading* – Suchlink  
- 🎥 YouTube: *bcp & BULK INSERT – End-to-End Demo* – Suchlink  
