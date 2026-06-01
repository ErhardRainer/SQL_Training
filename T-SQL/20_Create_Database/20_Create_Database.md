# T-SQL CREATE DATABASE & grundlegende DDL – Übersicht

## 1 | Begriffsdefinition

| SQL-Term | Beschreibung |
|---|---|
| `CREATE DATABASE` | Legt eine neue Datenbank an; steuert Dateien (`.mdf`/`.ndf`) und Log (`.ldf`), Filegroups, Größen & Autogrowth. |
| Primär-/Sekundärdatei | Primärdatei (`PRIMARY`-Filegroup, `.mdf`) enthält Katalog; zusätzliche Datendateien (`.ndf`) optional. |
| Filegroup | Logische Gruppierung von Datendateien (z. B. `PRIMARY`, `FG_Facts`). Index-/Tabellenplatzierung steuerbar. |
| Logdatei | Transaktionslog (`.ldf`) – **eine oder mehrere** möglich; kontrolliert Dauerhaftigkeit/Recovery. |
| Autogrowth | Automatische Größenerweiterung (in MB/%) – sinnvoll dimensionieren, um Fragmentierung zu vermeiden. |
| Modellvorlage (`model`) | Neue DB erbt viele Einstellungen von `model` (z. B. Standard-Objekte, Optionen). |
| Recovery Model | `FULL` / `SIMPLE` / `BULK_LOGGED` – bestimmt Log-Verhalten & Backup-Strategie. |
| Kompatibilitätslevel | `ALTER DATABASE … SET COMPATIBILITY_LEVEL = 1xx` – Query-Engine-Verhalten/Features. |
| Containment | `CONTAINMENT = NONE | PARTIAL` – z. B. contained users ohne Server-Login. |
| Datenbankbesitzer (Owner) | `dbo`/`sp_changedbowner` (veraltet) bzw. `ALTER AUTHORIZATION` – Sicherheitskontext der DB. |
| Schema | Namensraum innerhalb einer DB (z. B. `Sales`, `Ref`) – trennt **Besitz** von **Sicherheit**. |
| Grundlegende DDL | Tabellen/Constraints/Indizes/Sequenzen/Sichten/Prozeduren anlegen (`CREATE TABLE`, `CREATE INDEX`, …). |
| Datenbank-Optionen | `ALTER DATABASE … SET …` (z. B. `READ_COMMITTED_SNAPSHOT`, `AUTO_SHRINK`, `PAGE_VERIFY`). |
| DB-scoped Config | `ALTER DATABASE SCOPED CONFIGURATION` – z. B. `LEGACY_CARDINALITY_ESTIMATION`, UDF-Inlining. |
| Collation | Sortier-/Vergleichsregeln; auf DB-, Spalten- oder Ausdrucksebene (`COLLATE`). |

---

## 2 | Struktur

### 2.1 | `CREATE DATABASE` – Minimal & sicher
> **Kurzbeschreibung:** Minimale Syntax, Standards aus `model`, Owner setzen, sinnvolle Start-/Maxgrößen.

- 📓 **Notebook:**  
  [`08_01_create_database_grundlagen.ipynb`](08_01_create_database_grundlagen.ipynb)

- 🎥 **YouTube:**  
  - [Create Database – Basics](https://www.youtube.com/results?search_query=sql+server+create+database+tutorial)

- 📘 **Docs:**  
  - [`CREATE DATABASE` (T-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-database-transact-sql)

---

### 2.2 | Dateien & Filegroups planen
> **Kurzbeschreibung:** Mehrere Datendateien, eigene Filegroups, platzieren von großen Objekten/Indizes.

- 📓 **Notebook:**  
  [`08_02_files_filegroups_planung.ipynb`](08_02_files_filegroups_planung.ipynb)

- 🎥 **YouTube:**  
  - [Filegroups Explained](https://www.youtube.com/results?search_query=sql+server+filegroups)

- 📘 **Docs:**  
  - [Database Files and Filegroups](https://learn.microsoft.com/en-us/sql/relational-databases/databases/database-files-and-filegroups)

---

### 2.3 | Autogrowth, Größen & I/O-Layout
> **Kurzbeschreibung:** Startgröße/Autogrowth passend wählen, Fragmentierung vermeiden, getrennte Volumes (Daten/Log/TempDB).

- 📓 **Notebook:**  
  [`08_03_autogrowth_sizes_layout.ipynb`](08_03_autogrowth_sizes_layout.ipynb)

- 🎥 **YouTube:**  
  - [Autogrowth Best Practices](https://www.youtube.com/results?search_query=sql+server+autogrowth+best+practices)

- 📘 **Docs:**  
  - [Manage File Size & Growth](https://learn.microsoft.com/en-us/sql/relational-databases/databases/change-the-size-of-a-database)

- **Vertiefung:**  
  - [Shrink einer SQL-Server-Datenbank](Shrink_Database.md) - technische Details, Risiken, sinnvolle Ausnahmen und Nacharbeiten.

- **Praxisloesung:**  
  - [DatabaseSizeGrowthMonitor](../72_SQLAgent_Jobs_Alerts/Solutions/DatabaseSizeGrowthMonitor/README.md) - taegliche Snapshots von Datenbank-, Datei- und Tabellengroessen mit Growth-Reports.

---

### 2.4 | Recovery Model & Backup-Strategie
> **Kurzbeschreibung:** `FULL`/`SIMPLE`/`BULK_LOGGED` wählen, Auswirkungen auf Log & Backups.

- 📓 **Notebook:**  
  [`08_04_recovery_model_backup.ipynb`](08_04_recovery_model_backup.ipynb)

- 🎥 **YouTube:**  
  - [Recovery Models Overview](https://www.youtube.com/results?search_query=sql+server+recovery+model+explained)

- 📘 **Docs:**  
  - [View or Change the Recovery Model](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/view-or-change-the-recovery-model-of-a-database)

---

### 2.5 | Kompatibilitätslevel & DB-scoped Configs
> **Kurzbeschreibung:** Feature-/Planverhalten per `COMPATIBILITY_LEVEL` & `ALTER DATABASE SCOPED CONFIGURATION`.

- 📓 **Notebook:**  
  [`08_05_compat_level_scoped_config.ipynb`](08_05_compat_level_scoped_config.ipynb)

- 🎥 **YouTube:**  
  - [Compatibility Level & CE](https://www.youtube.com/results?search_query=sql+server+compatibility+level)

- 📘 **Docs:**  
  - [`ALTER DATABASE` – Compatibility Level](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-database-transact-sql-compatibility-level)  
  - [Database Scoped Configurations](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-database-scoped-configuration-transact-sql)

---

### 2.6 | Collation & Sprach-/Sortierregeln
> **Kurzbeschreibung:** DB-Collation festlegen/ändern, Konflikte lösen (`COLLATE`), Case Sensitivity.

- 📓 **Notebook:**  
  [`08_06_collation_einrichten.ipynb`](08_06_collation_einrichten.ipynb)

- 🎥 **YouTube:**  
  - [SQL Server Collation Basics](https://www.youtube.com/results?search_query=sql+server+collation)

- 📘 **Docs:**  
  - [Set or Change the Database Collation](https://learn.microsoft.com/en-us/sql/relational-databases/collations/set-or-change-the-database-collation)

---

### 2.7 | Owner, Berechtigungen & `ALTER AUTHORIZATION`
> **Kurzbeschreibung:** DB-Besitz korrekt setzen, Prinzipale/Benutzer anlegen, Standard-Schema definieren.

- 📓 **Notebook:**  
  [`08_07_owner_security_basics.ipynb`](08_07_owner_security_basics.ipynb)

- 🎥 **YouTube:**  
  - [Database Owner & Security](https://www.youtube.com/results?search_query=sql+server+database+owner+alter+authorization)

- 📘 **Docs:**  
  - [`ALTER AUTHORIZATION`](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-authorization-transact-sql)  
  - [Database Users – Create](https://learn.microsoft.com/en-us/sql/relational-databases/security/authentication-access/create-a-database-user)

---

### 2.8 | `CREATE SCHEMA` & Schema-Design
> **Kurzbeschreibung:** Objekte logisch trennen, Berechtigungen pro Schema, Objekte verschieben (`ALTER SCHEMA`).

- 📓 **Notebook:**  
  [`08_08_create_schema_design.ipynb`](08_08_create_schema_design.ipynb)

- 🎥 **YouTube:**  
  - [Create/Use Schemas](https://www.youtube.com/results?search_query=sql+server+create+schema)

- 📘 **Docs:**  
  - [`CREATE SCHEMA`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-schema-transact-sql)  
  - [`ALTER SCHEMA`](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-schema-transact-sql)

---

### 2.9 | `CREATE TABLE` – Basics & Standards
> **Kurzbeschreibung:** Datentypen, `NULL/NOT NULL`, `IDENTITY`/`SEQUENCE`, Default-Constraints, PK.

- 📓 **Notebook:**  
  [`08_09_create_table_basics.ipynb`](08_09_create_table_basics.ipynb)

- 🎥 **YouTube:**  
  - [Create Table – Tutorial](https://www.youtube.com/results?search_query=sql+server+create+table+tutorial)

- 📘 **Docs:**  
  - [`CREATE TABLE`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-table-transact-sql)

---

### 2.10 | Constraints: `PRIMARY KEY`, `UNIQUE`, `CHECK`, `FOREIGN KEY`
> **Kurzbeschreibung:** Inline vs. `ALTER TABLE ADD`, Benennung, ON DELETE/UPDATE-Regeln.

- 📓 **Notebook:**  
  [`08_10_constraints_grundlagen.ipynb`](08_10_constraints_grundlagen.ipynb)

- 🎥 **YouTube:**  
  - [SQL Server Constraints](https://www.youtube.com/results?search_query=sql+server+constraints+primary+key+foreign+key)

- 📘 **Docs:**  
  - [Create Unique Constraints](https://learn.microsoft.com/en-us/sql/relational-databases/tables/create-unique-constraints)  
  - [FOREIGN KEY – Referenz](https://learn.microsoft.com/en-us/sql/relational-databases/tables/create-foreign-key-relationships)

---

### 2.11 | Indizes beim Anlegen
> **Kurzbeschreibung:** Clustered/Nonclustered, `INCLUDE`, gefilterte Indizes, Fillfactor, Filegroup-Ziel.

- 📓 **Notebook:**  
  [`08_11_create_index_basics.ipynb`](08_11_create_index_basics.ipynb)

- 🎥 **YouTube:**  
  - [Create Index – Basics](https://www.youtube.com/results?search_query=sql+server+create+index)

- 📘 **Docs:**  
  - [`CREATE INDEX`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-index-transact-sql)

---

### 2.12 | Sequenzen & Identity-Design
> **Kurzbeschreibung:** `CREATE SEQUENCE`, `NEXT VALUE FOR` vs. `IDENTITY`; Lückenverhalten, Standardwerte.

- 📓 **Notebook:**  
  [`08_12_sequences_identity.ipynb`](08_12_sequences_identity.ipynb)

- 🎥 **YouTube:**  
  - [Sequences vs Identity](https://www.youtube.com/results?search_query=sql+server+sequence+vs+identity)

- 📘 **Docs:**  
  - [`CREATE SEQUENCE`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-sequence-transact-sql)

---

### 2.13 | Wichtige DB-Optionen: RCSI/Snapshot, PAGE_VERIFY, AUTO_SHRINK
> **Kurzbeschreibung:** `READ_COMMITTED_SNAPSHOT`, `ALLOW_SNAPSHOT_ISOLATION`, `PAGE_VERIFY CHECKSUM`; Anti-Pattern: `AUTO_SHRINK`.

- 📓 **Notebook:**  
  [`08_13_db_optionen_wichtig.ipynb`](08_13_db_optionen_wichtig.ipynb)

- 🎥 **YouTube:**  
  - [RCSI & Snapshot Isolation](https://www.youtube.com/results?search_query=sql+server+read+committed+snapshot)

- 📘 **Docs:**  
  - [Row Versioning Isolation Levels](https://learn.microsoft.com/en-us/sql/relational-databases/tempdb/row-versioning-isolation-levels)  
  - [`ALTER DATABASE SET` – Optionen](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-database-transact-sql-set-options)

---

### 2.14 | Azure SQL vs. SQL Server (on-prem)
> **Kurzbeschreibung:** Unterschiede bei Dateien/Filegroups, `CREATE DATABASE … AS COPY OF`, Service-Einstellungen.

- 📓 **Notebook:**  
  [`08_14_azure_sql_unterschiede.ipynb`](08_14_azure_sql_unterschiede.ipynb)

- 🎥 **YouTube:**  
  - [Azure SQL – Create DB](https://www.youtube.com/results?search_query=azure+sql+create+database+t-sql)

- 📘 **Docs:**  
  - [Create a single database (Azure SQL)](https://learn.microsoft.com/en-us/azure/azure-sql/database/single-database-create-quickstart)

---

### 2.15 | Deployment & Versionierung (SSDT/DACPAC, `CREATE OR ALTER`)
> **Kurzbeschreibung:** Skripte idempotent bauen (`IF NOT EXISTS`), Objekte versionieren, `CREATE OR ALTER` für Procs/Views/Functions.

- 📓 **Notebook:**  
  [`08_15_deployment_versionierung.ipynb`](08_15_deployment_versionierung.ipynb)

- 🎥 **YouTube:**  
  - [SSDT/DACPAC Overview](https://www.youtube.com/results?search_query=ssdt+dacpac+sql+server)

- 📘 **Docs:**  
  - [`CREATE OR ALTER` (Programmobjekte)](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-or-alter-transact-sql)  
  - [SqlPackage / DACPAC](https://learn.microsoft.com/en-us/sql/tools/sqlpackage/sqlpackage)

---

### 2.16 | Anti-Patterns & Checkliste beim Anlegen
> **Kurzbeschreibung:** `AUTO_SHRINK ON`, Mini-Autogrowth (1 MB), keine Filegroups/Backups geplant, falsches Recovery Model, alle Objekte im `dbo`-Schema, fehlende PKs.

- 📓 **Notebook:**  
  [`08_16_create_database_anti_patterns.ipynb`](08_16_create_database_anti_patterns.ipynb)

- 🎥 **YouTube:**  
  - [Common DBA Setup Mistakes](https://www.youtube.com/results?search_query=sql+server+database+setup+mistakes)

- 📘 **Docs/Blog:**  
  - [SQL Server Best Practices – Storage & Files](https://learn.microsoft.com/en-us/sql/relational-databases/databases/database-files-and-filegroups)  

---

## 3 | Weiterführende Informationen

- 📘 Microsoft Learn: [`CREATE DATABASE`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-database-transact-sql)  
- 📘 Microsoft Learn: [Database Files & Filegroups](https://learn.microsoft.com/en-us/sql/relational-databases/databases/database-files-and-filegroups)  
- 📘 Microsoft Learn: [Change Database File Size & Growth](https://learn.microsoft.com/en-us/sql/relational-databases/databases/change-the-size-of-a-database)  
- 📘 Microsoft Learn: [Recovery Models](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/recovery-models-sql-server)  
- 📘 Microsoft Learn: [`ALTER DATABASE` – SET Options](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-database-transact-sql-set-options)  
- 📘 Microsoft Learn: [Database Scoped Configurations](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-database-scoped-configuration-transact-sql)  
- 📘 Microsoft Learn: [Set/Change Database Collation](https://learn.microsoft.com/en-us/sql/relational-databases/collations/set-or-change-the-database-collation)  
- 📘 Microsoft Learn: [`CREATE SCHEMA`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-schema-transact-sql)  
- 📘 Microsoft Learn: [`CREATE TABLE`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-table-transact-sql)  
- 📘 Microsoft Learn: [`CREATE INDEX`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-index-transact-sql)  
- 📘 Microsoft Learn: [`CREATE SEQUENCE`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-sequence-transact-sql)  
- 📘 Microsoft Learn: [Read Committed Snapshot / Snapshot Isolation](https://learn.microsoft.com/en-us/sql/relational-databases/tempdb/row-versioning-isolation-levels)  
- 📘 Microsoft Learn: [`CREATE OR ALTER` (Programmobjekte)](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-or-alter-transact-sql)  
- 📝 SQLPerformance: *Autogrowth & File Management* – https://www.sqlperformance.com/?s=autogrowth  
- 📝 Brent Ozar: *RCSI/Snapshot & Setup Notes* – https://www.brentozar.com/  
- 📝 Erik Darling: *Index/Filegroup & DDL Tipps* – https://www.erikdarlingdata.com/  
- 🎥 YouTube (Data Exposed): *Best Practices for New Databases* – Suchlink  
