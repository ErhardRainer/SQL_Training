# T-SQL External Tables & PolyBase – Übersicht  
*Zugriff auf externe Datenquellen über PolyBase/External Tables*

## 1 | Begriffsdefinition

| SQL-Term | Beschreibung |
|---|---|
| **PolyBase** | In-Engine-Datenvirtualisierung: SQL Server kann **extern** liegende Daten (z. B. ADLS/Blob, HDFS, andere RDBMS) per T-SQL lesen/schreiben. |
| **External Table** | Tabellenobjekt, das auf **externen Speicher/Quelle** zeigt (Schema-on-read). Kein lokaler Datenspeicher. |
| **External Data Source** | Verbindungsdefinition zur Quelle (`CREATE EXTERNAL DATA SOURCE … WITH (LOCATION=…, TYPE=…, CREDENTIAL=…)`). |
| **External File Format** | Beschreibung des Dateiformats (`PARQUET`, `DELIMITEDTEXT`/CSV, ggf. `ORC` je Version), Feldtrenner, Quoting, Komprimierung. |
| **External Credential** | Zugriffsdaten für Quelle (z. B. SAS/Shared Key/MSI für Azure Storage, User/Pass/ODBC für RDBMS). |
| **LOCATION** | Pfad/Endpunkt der Daten (z. B. `abfss://container@account.dfs.core.windows.net/folder/…`). |
| **Predicate Pushdown** | Filter/Projektionen werden – falls möglich – zur Quelle **heruntergeschoben** (Performance, geringere Datenübertragung). |
| **Sharding/Parallel I/O** | Dateien/Partitionen können **parallel** gescannt werden; Dateiaufteilung beeinflusst Durchsatz. |
| **External Tables: Hadoop/Blob** | Externe Dateien (Parquet/CSV) lesen; meist auch **INSERT INTO External Table** (Export) möglich. |
| **External Tables: RDBMS** | Externe Tabellen auf andere SQL/ODB C-Quellen; primär **lesen** (Schreibunterstützung je Provider unterschiedlich). |
| **Statistics** | Auf External Tables **manuell** Statistiken anlegen, um Pläne zu verbessern (keine Auto-Stats). |
| **Security** | Least-Privilege auf Storage/Quelle, `CREATE DATABASE SCOPED CREDENTIAL`, Verschlüsselung der Secrets. |
| **Reject Options** | Toleranz für fehlerhafte Zeilen (`REJECT_TYPE`, `REJECT_VALUE`, `REJECTED_ROW_LOCATION`) bei Textformaten. |
| **Vergleich** | **Linked Server** = RPC/Row-by-Row; **PolyBase** = Batch/Scan-optimiert mit Pushdown → i. d. R. besser für Analytics/Files. |
| **Grenzen** | DDL auf externen Schemata eingeschränkt; Datentyp-Mapping/Collations beachten; Schreibfähigkeit abhängig von Quelle/Connector. |

---

## 2 | Struktur

### 2.1 | Architektur & Einsatzszenarien
> **Kurzbeschreibung:** Wann External Tables sinnvoll sind (Data Lake, Cross-DB, Data Hub), Abgrenzung zu Linked Server/ETL.

- 📓 **Notebook:**  
  [`08_01_architektur_use_cases.ipynb`](08_01_architektur_use_cases.ipynb)
- 🎥 **YouTube:**  
  - [PolyBase & External Tables – Overview](https://www.youtube.com/results?search_query=sql+server+polybase+external+tables+overview)
- 📘 **Docs:**  
  - [PolyBase – Überblick](https://learn.microsoft.com/en-us/sql/relational-databases/polybase/polybase-guide)

---

### 2.2 | Voraussetzungen & Installation
> **Kurzbeschreibung:** Features, Dienste und (falls nötig) Connector-/ODBC-Voraussetzungen; Rechte & Netzwerkanforderungen.

- 📓 **Notebook:**  
  [`08_02_prereqs_installation.ipynb`](08_02_prereqs_installation.ipynb)
- 🎥 **YouTube:**  
  - [Install/Enable PolyBase](https://www.youtube.com/results?search_query=install+polybase+sql+server)
- 📘 **Docs:**  
  - [Installationsvoraussetzungen](https://learn.microsoft.com/en-us/sql/relational-databases/polybase/polybase-installation)

---

### 2.3 | External Credentials & Secrets
> **Kurzbeschreibung:** `CREATE DATABASE SCOPED CREDENTIAL` für SAS/Keys/Benutzer; Secret-Pflege & Rotation.

- 📓 **Notebook:**  
  [`08_03_credentials_and_secrets.ipynb`](08_03_credentials_and_secrets.ipynb)
- 🎥 **YouTube:**  
  - [Database Scoped Credential – Tutorial](https://www.youtube.com/results?search_query=sql+server+database+scoped+credential)
- 📘 **Docs:**  
  - [`CREATE DATABASE SCOPED CREDENTIAL`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-database-scoped-credential-transact-sql)

---

### 2.4 | External Data Source – Objekt-/Dateispeicher (ADLS/Blob/HDFS)
> **Kurzbeschreibung:** Data Lake/Blob anbinden: Endpunkte, Auth (SAS/Key/MSI), Netzwerk.

- 📓 **Notebook:**  
  [`08_04_external_data_source_files.ipynb`](08_04_external_data_source_files.ipynb)
- 🎥 **YouTube:**  
  - [Create External Data Source (Blob/ADLS)](https://www.youtube.com/results?search_query=create+external+data+source+azure+blob+adls+sql+server)
- 📘 **Docs:**  
  - [`CREATE EXTERNAL DATA SOURCE` (Dateispeicher)](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-external-data-source-transact-sql)

---

### 2.5 | External Data Source – RDBMS/ODBC
> **Kurzbeschreibung:** Remote-SQL (Elastic Query)/andere RDBMS via ODBC definieren, Pushdown-Fähigkeiten verstehen.

- 📓 **Notebook:**  
  [`08_05_external_data_source_rdbms.ipynb`](08_05_external_data_source_rdbms.ipynb)
- 🎥 **YouTube:**  
  - [External Tables to RDBMS](https://www.youtube.com/results?search_query=sql+server+external+table+to+oracle+mysql)
- 📘 **Docs:**  
  - [`CREATE EXTERNAL DATA SOURCE` (RDBMS/ODBC)](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-external-data-source-transact-sql#rdbms)

---

### 2.6 | External File Format – PARQUET & CSV (DELIMITEDTEXT)
> **Kurzbeschreibung:** Formate anlegen, Spaltenzuordnung, Quoting, Komprimierung; wann Parquet überlegen ist.

- 📓 **Notebook:**  
  [`08_06_external_file_formats_parquet_csv.ipynb`](08_06_external_file_formats_parquet_csv.ipynb)
- 🎥 **YouTube:**  
  - [External File Format (Parquet/CSV)](https://www.youtube.com/results?search_query=sql+server+external+file+format+parquet+csv)
- 📘 **Docs:**  
  - [`CREATE EXTERNAL FILE FORMAT`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-external-file-format-transact-sql)

---

### 2.7 | External Table – auf Dateien (Data Lake)
> **Kurzbeschreibung:** `CREATE EXTERNAL TABLE … WITH (DATA_SOURCE=…, LOCATION=…, FILE_FORMAT=…)`; Schema-on-read in T-SQL.

- 📓 **Notebook:**  
  [`08_07_external_table_files.ipynb`](08_07_external_table_files.ipynb)
- 🎥 **YouTube:**  
  - [Create External Table on ADLS/Blob](https://www.youtube.com/results?search_query=create+external+table+sql+server+adls+blob)
- 📘 **Docs:**  
  - [External Tables – Hadoop/Azure Storage](https://learn.microsoft.com/en-us/sql/relational-databases/polybase/polybase-configure-hadoop)

---

### 2.8 | External Table – auf RDBMS
> **Kurzbeschreibung:** Externe Tabellen, die auf entfernte Tabellen zeigen; Namenszuordnung & Datentyp-Mapping.

- 📓 **Notebook:**  
  [`08_08_external_table_rdbms.ipynb`](08_08_external_table_rdbms.ipynb)
- 🎥 **YouTube:**  
  - [External Table to Remote SQL](https://www.youtube.com/results?search_query=sql+server+external+table+remote+sql)
- 📘 **Docs:**  
  - [External Tables – RDBMS](https://learn.microsoft.com/en-us/sql/relational-databases/linked-servers/elastic-query-overview) *(Elastic Query Überblick)*

---

### 2.9 | Lesen & (wo möglich) Schreiben
> **Kurzbeschreibung:** `SELECT` gegen External Table; **INSERT INTO External Table** bei File-Zielen (Export), Limitierungen beachten.

- 📓 **Notebook:**  
  [`08_09_read_write_patterns.ipynb`](08_09_read_write_patterns.ipynb)
- 🎥 **YouTube:**  
  - [Insert into External Tables (Files)](https://www.youtube.com/results?search_query=sql+server+insert+into+external+table+polybase)
- 📘 **Docs:**  
  - [PolyBase – Schreiben in externe Dateien](https://learn.microsoft.com/en-us/sql/relational-databases/polybase/polybase-import-export)

---

### 2.10 | Performance: Pushdown, Partitionierung, Parallel I/O
> **Kurzbeschreibung:** Predicate/Projection Pushdown, Dateischnitt (klein & viele vs. groß & wenige), Statistiken, Caching.

- 📓 **Notebook:**  
  [`08_10_performance_pushdown_parallel.ipynb`](08_10_performance_pushdown_parallel.ipynb)
- 🎥 **YouTube:**  
  - [PolyBase Performance Tips](https://www.youtube.com/results?search_query=polybase+performance+tips)
- 📘 **Docs:**  
  - [PolyBase Performance Guidelines](https://learn.microsoft.com/en-us/sql/relational-databases/polybase/polybase-guide#performance-considerations)

---

### 2.11 | Fehler-/Zeilenbehandlung & REJECT-Optionen
> **Kurzbeschreibung:** Schmutzige Daten, `REJECT_TYPE`/`REJECT_VALUE`, Probenahme/Logging, `ENCODING`.

- 📓 **Notebook:**  
  [`08_11_reject_rows_and_encoding.ipynb`](08_11_reject_rows_and_encoding.ipynb)
- 🎥 **YouTube:**  
  - [Handle Bad Rows (External Tables)](https://www.youtube.com/results?search_query=polybase+reject+value+sql+server)
- 📘 **Docs:**  
  - [Reject Options (Delimited Text)](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-external-table-transact-sql)

---

### 2.12 | Sicherheit: Rollen, Netzwerk & Secrets
> **Kurzbeschreibung:** Speicher-ACLs, begrenzte Rechte, Key-Management, verschlüsselte Verbindungen, Firewalls/Private Endpoints.

- 📓 **Notebook:**  
  [`08_12_security_roles_network.ipynb`](08_12_security_roles_network.ipynb)
- 🎥 **YouTube:**  
  - [Secure External Data Access](https://www.youtube.com/results?search_query=secure+polybase+external+tables)
- 📘 **Docs:**  
  - [Security Considerations](https://learn.microsoft.com/en-us/sql/relational-databases/polybase/polybase-guide#security-considerations)

---

### 2.13 | Typisches Data-Lake-Muster (Bronze/Silver/Gold)
> **Kurzbeschreibung:** Staging über External Tables, Validierung, Persistierung in interne Tabellen.

- 📓 **Notebook:**  
  [`08_13_datalake_patterns_with_external_tables.ipynb`](08_13_datalake_patterns_with_external_tables.ipynb)
- 🎥 **YouTube:**  
  - [PolyBase with Data Lake Patterns](https://www.youtube.com/results?search_query=polybase+data+lake+pattern)
- 📘 **Docs:**  
  - [Import/Export Workflows](https://learn.microsoft.com/en-us/sql/relational-databases/polybase/polybase-import-export)

---

### 2.14 | Troubleshooting & DMVs
> **Kurzbeschreibung:** Exeptions/Pushdown-Status, `sys.external_*`-Kataloge, XEvent/Fehlermeldungen.

- 📓 **Notebook:**  
  [`08_14_troubleshooting_dmvs.ipynb`](08_14_troubleshooting_dmvs.ipynb)
- 🎥 **YouTube:**  
  - [Troubleshoot External Tables](https://www.youtube.com/results?search_query=troubleshoot+polybase+external+tables)
- 📘 **Docs:**  
  - [Kataloge/DMVs für External Objects](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-external-tables-transact-sql)

---

### 2.15 | Governance & Kosten
> **Kurzbeschreibung:** Datenbewegung minimieren, Abfragekosten (Cloud-Egress), Retention, Zugriffsmuster optimieren.

- 📓 **Notebook:**  
  [`08_15_governance_costs.ipynb`](08_15_governance_costs.ipynb)
- 🎥 **YouTube:**  
  - [Cost-Aware External Queries](https://www.youtube.com/results?search_query=optimize+external+table+cost)
- 📘 **Docs:**  
  - [Best Practices – Data Movement](https://learn.microsoft.com/en-us/sql/relational-databases/polybase/polybase-guide#best-practices)

---

### 2.16 | Anti-Patterns & Checkliste
> **Kurzbeschreibung:** Riesige Einzeldateien, fehlende Stats, kein Pushdown (Funktionen auf Spalten), Secrets im Klartext, Linked Server für Files, unpassender Datentyp-Cast, fehlende Retry/Idempotenz bei Export.

- 📓 **Notebook:**  
  [`08_16_antipatterns_checkliste.ipynb`](08_16_antipatterns_checkliste.ipynb)
- 🎥 **YouTube:**  
  - [External Tables – Common Mistakes](https://www.youtube.com/results?search_query=external+tables+common+mistakes+sql+server)
- 📘 **Docs/Blog:**  
  - [Best Practices & Considerations](https://learn.microsoft.com/en-us/sql/relational-databases/polybase/polybase-guide#best-practices)

---

## 3 | Weiterführende Informationen

- 📘 Microsoft Learn: [PolyBase – Guide & Szenarien](https://learn.microsoft.com/en-us/sql/relational-databases/polybase/polybase-guide)  
- 📘 Microsoft Learn: [`CREATE EXTERNAL DATA SOURCE`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-external-data-source-transact-sql)  
- 📘 Microsoft Learn: [`CREATE EXTERNAL FILE FORMAT`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-external-file-format-transact-sql)  
- 📘 Microsoft Learn: [`CREATE EXTERNAL TABLE` – Referenz](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-external-table-transact-sql)  
- 📘 Microsoft Learn: [`CREATE DATABASE SCOPED CREDENTIAL`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-database-scoped-credential-transact-sql)  
- 📘 Microsoft Learn: [Konfiguration Hadoop/Blob/ADLS](https://learn.microsoft.com/en-us/sql/relational-databases/polybase/polybase-configure-hadoop)  
- 📘 Microsoft Learn: [Import/Export mit PolyBase](https://learn.microsoft.com/en-us/sql/relational-databases/polybase/polybase-import-export)  
- 📘 Microsoft Learn: [Systemobjekte: `sys.external_tables`/`external_data_sources`/`external_file_formats`](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-external-tables-transact-sql)  
- 📘 Microsoft Learn: [Elastic Query (RDBMS External Tables – Azure SQL)](https://learn.microsoft.com/en-us/sql/relational-databases/linked-servers/elastic-query-overview)  
- 📝 SQLPerformance: *PolyBase Performance & Pushdown* – https://www.sqlperformance.com/?s=polybase  
- 📝 Redgate Simple Talk: *Working with External Tables / Data Lakes* – https://www.red-gate.com/simple-talk/  
- 📝 Erik Darling / Brent Ozar: *Linked Server vs. External Table – Trade-offs* – Blogs  
- 🎥 YouTube (Data Exposed): *PolyBase & External Tables – Deep Dive* – Suchlink  
- 🎥 YouTube: *Parquet vs. CSV in External Tables* – Suchlink  
