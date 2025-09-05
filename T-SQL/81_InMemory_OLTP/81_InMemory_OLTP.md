# T-SQL – In-Memory OLTP (Memory-Optimized Tables & Natively Compiled Procedures) – Übersicht

## 1 | Begriffsdefinition

| SQL-Term | Beschreibung |
|---|---|
| In-Memory OLTP (Hekaton) | Spezialisierte In-Memory-Engine für OLTP in SQL Server/Azure SQL; setzt auf MVCC & lock-/latch-freie Strukturen für sehr hohe Parallelität. |
| Memory-Optimized Table (MOT) | Tabelle mit `MEMORY_OPTIMIZED = ON`; Daten liegen im Speicher, Persistenz abhängig von `DURABILITY`. |
| Durability (`SCHEMA_ONLY` / `SCHEMA_AND_DATA`) | `SCHEMA_ONLY`: nur Schema wird persistiert (keine Datenloggging, reboot = leer). `SCHEMA_AND_DATA`: Schema+Daten werden über Checkpoint-Dateien persistiert. |
| Memory-Optimized Filegroup | Spezielle Filegroup `CONTAINS MEMORY_OPTIMIZED_DATA`; hält Container mit **Checkpoint File Pairs**. |
| Checkpoint File Pair (CFP) | Daten- (`*.hkckp`) und Delta-Datei, die eingefügte bzw. gelöschte Zeilen persistieren; werden vom Merge-/GC-Prozess zusammengeführt. |
| Nativ kompilierte Prozedur | `CREATE PROCEDURE ... WITH NATIVE_COMPILATION, SCHEMABINDING ... BEGIN ATOMIC WITH (...) ... END`; erzeugt DLL, extrem geringe Ausführungs-Latenz. |
| ATOMIC-Block | Obligatorischer Block in nativ kompilierten Prozeduren: `BEGIN ATOMIC WITH (TRANSACTION ISOLATION LEVEL = ..., LANGUAGE = ...)`. |
| Interop vs. Native | Zugriff auf MOTs per „interpretiertem“ T-SQL (Interop) oder aus nativ kompilierten Modulen (maximale Performance). |
| Isolation & MVCC | Optimistische Mehrversionenkontrolle; u. a. `SNAPSHOT`, `REPEATABLE READ`, `SERIALIZABLE` für MOT-Transaktionen. |
| Hash-Index | In-Memory Hash-Tabelle; optimal für Punktabfragen mit Gleichheitsprädikaten; benötigt `BUCKET_COUNT` (idealerweise ~1–2× erwartete eindeutige Schlüssel). |
| (Memory-optimized) Nonclustered Index | In-Memory B-/Bw-Tree, unterstützt Range-Scans, Sortierung; kein `INCLUDE`-Konzept (alle Spalten sind „covered“). |
| Index-Anforderung | Jede MOT **muss** mindestens einen Index besitzen; für Standard-Persistenz (`SCHEMA_AND_DATA`) ist ein **PRIMARY KEY** erforderlich. |
| Spaltenstore auf MOT | Seit SQL Server 2016 möglich: **Clustered Columnstore Index** auf MOTs (nur bei `SCHEMA_AND_DATA`). |
| Statistik | Auto-Update von Statistiken wird unterstützt; bei Massendatenladen empfehlenswert: manuelles `UPDATE STATISTICS` vor Native Compile. |
| T-SQL-Einschränkungen | Nicht alle Sprachkonstrukte/Features sind für MOTs bzw. native Module erlaubt (z. B. `MERGE`-Target, bestimmte DM-Funktionen usw.). |
| Speicherbedarf | Daten **+** Indexversionen müssen in RAM passen; Größenkalkulation & Quoten (v. a. in Azure SQL) beachten. |
| Table Type (MOT) & TVP | `CREATE TYPE ... AS TABLE (...) WITH (MEMORY_OPTIMIZED = ON)`; ideal als schnelle TVPs/Table-Variablen. |
| DMV/Monitoring | Zentrale DMVs: `sys.dm_db_xtp_table_memory_stats`, `sys.dm_db_xtp_checkpoint_files`, `sys.dm_db_xtp_hash_index_stats`, `sys.dm_db_xtp_transactions` etc. |

---

## 2 | Struktur

### 2.1 | Architektur & Grundlagen (Hekaton)
> **Kurzbeschreibung:** Überblick über Engine, MVCC, Lock-/Latch-Freiheit, Logik von CFP (Data/Delta), Persistenz und Recovery.

- 📓 **Notebook:**  
  [`08_01_inmemory_grundlagen.ipynb`](08_01_inmemory_grundlagen.ipynb)

- 🎥 **YouTube:**  
  - [Inside SQL Server In-Memory OLTP – Bob Ward](https://www.youtube.com/watch?v=P9DnjQqE0Gc)  
  - [24 Hours of PASS: In-Memory OLTP Overview](https://www.youtube.com/watch?v=Aj0-p1JbW3E)

- 📘 **Docs:**  
  - [In-Memory OLTP – Überblick](https://learn.microsoft.com/en-us/sql/relational-databases/in-memory-oltp/in-memory-oltp-overview)  
  - [Einführung in Memory-optimierte Tabellen](https://learn.microsoft.com/en-us/sql/relational-databases/in-memory-oltp/introduction-to-memory-optimized-tables)

---

### 2.2 | Speicher & Persistenz (Filegroup, CFP, Backup/Restore)
> **Kurzbeschreibung:** Anlegen der `MEMORY_OPTIMIZED_DATA`-Filegroup/Container, Checkpoint-Dateien (Data/Delta), Backups & Merges.

- 📓 **Notebook:**  
  [`08_02_inmemory_storage_cfp.ipynb`](08_02_inmemory_storage_cfp.ipynb)

- 🎥 **YouTube:**  
  - [Getting Started with In-Memory OLTP (Setup/DB)](https://www.youtube.com/watch?v=SExtYPovtOk)  
  - [SQL Server internals memory (Bob Ward)](https://www.youtube.com/watch?v=CRAx73LiXTc)

- 📘 **Docs:**  
  - [Memory-optimized Filegroup erstellen & verwalten](https://learn.microsoft.com/en-us/sql/relational-databases/in-memory-oltp/the-memory-optimized-filegroup)  
  - [Durability für MOTs (CFP, Merge, GC)](https://learn.microsoft.com/en-us/sql/relational-databases/in-memory-oltp/durability-for-memory-optimized-tables)  
  - [DB-Backup mit MOTs](https://learn.microsoft.com/en-us/sql/relational-databases/in-memory-oltp/backing-up-a-database-with-memory-optimized-tables)

---

### 2.3 | Tabellen erstellen: Durability, Datentypen, LOBs, Größen
> **Kurzbeschreibung:** `CREATE TABLE ... WITH (MEMORY_OPTIMIZED=ON, DURABILITY=...)`; LOB-Support (max-Typen), Größenkalkulation.

- 📓 **Notebook:**  
  [`08_03_create_table_durability_lobs.ipynb`](08_03_create_table_durability_lobs.ipynb)

- 🎥 **YouTube:**  
  - [How to create an In-Memory OLTP-enabled DB](https://www.youtube.com/watch?v=K2gqHxoJ6yw)  
  - [SQL Server 2016 – It Just Runs Faster (In-Memory Highlights)](https://www.youtube.com/watch?v=pTEDfmQnpzA)

- 📘 **Docs:**  
  - [Unterstützte Datentypen für In-Memory OLTP](https://learn.microsoft.com/en-us/sql/relational-databases/in-memory-oltp/supported-data-types-for-in-memory-oltp)  
  - [Speicherbedarf schätzen (MOTs)](https://learn.microsoft.com/en-us/sql/relational-databases/in-memory-oltp/estimate-memory-requirements-for-memory-optimized-tables)  
  - [`CREATE TABLE` (Hinweise für MOTs)](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-table-transact-sql)

---

### 2.4 | Index-Design: Hash vs. Nonclustered (Range), Bucket-Count
> **Kurzbeschreibung:** Wahl des Index-Typs, Bucket-Count bestimmen/überwachen, Parallelität bei Scans, Limits bei Schlüssellängen.

- 📓 **Notebook:**  
  [`08_04_index_design_hash_vs_range.ipynb`](08_04_index_design_hash_vs_range.ipynb)

- 🎥 **YouTube:**  
  - [Hash vs. Range Indexes (Praxis)](https://www.youtube.com/watch?v=1lXfwnp-X2I)  
  - [Indexes on MOTs – Überblick (Playlist)](https://www.youtube.com/playlist?list=PLk6Brn6N09z0ybjmphas7AY1s_hGBCVIR)

- 📘 **Docs:**  
  - [Indexes für Memory-optimierte Tabellen (Typen/Anforderungen)](https://learn.microsoft.com/en-us/sql/relational-databases/in-memory-oltp/indexes-for-memory-optimized-tables)  
  - [Hash-Index: Bucket-Count überwachen](https://learn.microsoft.com/en-us/sql/relational-databases/in-memory-oltp/hash-indexes-for-memory-optimized-tables)  
  - [Max. Kapazitäten (Schlüsselgrößen, Index-Anzahl)](https://learn.microsoft.com/en-us/sql/sql-server/maximum-capacity-specifications-for-sql-server)

---

### 2.5 | Nativ kompilierte Prozeduren – Syntax, Patterns, Grenzen
> **Kurzbeschreibung:** ATOMIC-Block, `SCHEMABINDING`, erlaubte T-SQL-Features, Parallelismus/Join-Typen, Fehlerbilder & Troubleshooting.

- 📓 **Notebook:**  
  [`08_05_native_compiled_procs.ipynb`](08_05_native_compiled_procs.ipynb)

- 🎥 **YouTube:**  
  - [Inside In-Memory OLTP – Bob Ward (Internals)](https://www.youtube.com/watch?v=P9DnjQqE0Gc)  
  - [When to use Natively Compiled SPs (Erfahrungen)](https://www.youtube.com/watch?v=SExtYPovtOk)

- 📘 **Docs:**  
  - [Nativ kompilierte Prozeduren erstellen](https://learn.microsoft.com/en-us/sql/relational-databases/in-memory-oltp/creating-natively-compiled-stored-procedures)  
  - [Unterstützte Features in nativ kompilierten Modulen](https://learn.microsoft.com/en-us/sql/relational-databases/in-memory-oltp/supported-features-for-natively-compiled-t-sql-modules)

---

### 2.6 | Transaktionen, Isolation & Interop
> **Kurzbeschreibung:** MVCC-Details, zulässige Isolation Levels, Interop-Spezifika (u. a. `READ COMMITTED`/`RCSI`), typische Konflikte.

- 📓 **Notebook:**  
  [`08_06_transactions_isolation_interop.ipynb`](08_06_transactions_isolation_interop.ipynb)

- 🎥 **YouTube:**  
  - [Locks/Spinlocks & Lock-free Structures (K. Aschenbrenner)](https://www.youtube.com/watch?v=BLcdN-d59o0)  
  - [Understanding Memory (Bob Ward)](https://www.youtube.com/watch?v=CRAx73LiXTc)

- 📘 **Docs:**  
  - [Transaktionen mit MOTs (Isolation/MVCC)](https://learn.microsoft.com/en-us/sql/relational-databases/in-memory-oltp/transactions-with-memory-optimized-tables)  
  - [Nebenläufigkeits-Einschränkungen (Interop/RCSI)](https://learn.microsoft.com/en-us/sql/relational-databases/in-memory-oltp/concurrent-access-limitations)

---

### 2.7 | Columnstore auf MOTs (HTAP)
> **Kurzbeschreibung:** Clustered Columnstore Index auf MOTs (Hybrid-Szenarien), Einsatzgrenzen & DDL-Besonderheiten.

- 📓 **Notebook:**  
  [`08_07_mot_columnstore_htap.ipynb`](08_07_mot_columnstore_htap.ipynb)

- 🎥 **YouTube:**  
  - [Overview Columnstore (Allgemein)](https://www.youtube.com/watch?v=oFhl3IVo-Fs)  
  - [Praxis: CCI auf MOT (Demo/Guides)](https://www.youtube.com/watch?v=Aj0-p1JbW3E)

- 📘 **Docs:**  
  - [Columnstore – Überblick (mit MOT-Hinweis)](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/columnstore-indexes-overview)  

---

### 2.8 | Statistik & Recompiles
> **Kurzbeschreibung:** Auto-Statistiken, manuelles `UPDATE STATISTICS` (Zeitpunkte/Fullscan), Bedeutung vor Native-Compile.

- 📓 **Notebook:**  
  [`08_08_stats_on_mot.ipynb`](08_08_stats_on_mot.ipynb)

- 🎥 **YouTube:**  
  - [Performance Basics & Stats (variiert nach Kanal)](https://www.youtube.com/watch?v=SExtYPovtOk)  
  - [It Just Runs Faster – Stats/Plans Bits](https://www.youtube.com/watch?v=pTEDfmQnpzA)

- 📘 **Docs:**  
  - [Statistiken für MOTs](https://learn.microsoft.com/en-us/sql/relational-databases/in-memory-oltp/statistics-for-memory-optimized-tables)

---

### 2.9 | Table Types, TVPs & Temp-Szenarien
> **Kurzbeschreibung:** Memory-optimierte Table Types als TVP/Table-Variable; wann sinnvoll, worauf achten.

- 📓 **Notebook:**  
  [`08_09_mot_tabletypes_tvps.ipynb`](08_09_mot_tabletypes_tvps.ipynb)

- 🎥 **YouTube:**  
  - [Use Cases TVPs/MOT (Community)](https://www.youtube.com/watch?v=675AyXAiaG4)  
  - [Playlist: In-Memory OLTP – Basics](https://www.youtube.com/playlist?list=PLw4p5JNb-aY1A2dvV4hWmTv4Q7AKbWGXe)

- 📘 **Docs:**  
  - [`CREATE TYPE` (Table Type, `MEMORY_OPTIMIZED`)](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-type-transact-sql)  
  - [Schnellere Temp-Tabellen/Table-Variablen mit Memory-Optimierung](https://learn.microsoft.com/en-us/sql/relational-databases/in-memory-oltp/faster-temp-table-and-table-variable-by-using-memory-optimization)

---

### 2.10 | Migration & Tooling (Advisor/AMR)
> **Kurzbeschreibung:** Kandidaten finden (AMR/Reports), Tabellen migrieren (Memory Optimization Advisor), typische Blocker & Workarounds.

- 📓 **Notebook:**  
  [`08_10_migration_advisor_amr.ipynb`](08_10_migration_advisor_amr.ipynb)

- 🎥 **YouTube:**  
  - [Memory Optimization Advisor (Demo)](https://www.youtube.com/watch?v=rKmrNuGoXL4)  
  - [Inside In-Memory – Praxisberichte](https://www.youtube.com/watch?v=P9DnjQqE0Gc)

- 📘 **Docs:**  
  - [Memory Optimization Advisor](https://learn.microsoft.com/en-us/sql/relational-databases/in-memory-oltp/memory-optimization-advisor)

---

### 2.11 | Monitoring & Troubleshooting
> **Kurzbeschreibung:** Speicher-/Index-Nutzung, CFP-Status, Transaktionsstatistiken, typische Ursachen für OOM & Logwachstum.

- 📓 **Notebook:**  
  [`08_11_monitoring_dmvs_xevents.ipynb`](08_11_monitoring_dmvs_xevents.ipynb)

- 🎥 **YouTube:**  
  - [Understanding Memory (Bob Ward)](https://www.youtube.com/watch?v=CRAx73LiXTc)  
  - [Inside SQL Server Waits/Latches/Spinlocks](https://www.youtube.com/watch?v=BLcdN-d59o0)

- 📘 **Docs:**  
  - [`sys.dm_db_xtp_table_memory_stats`](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-xtp-table-memory-stats-transact-sql)  
  - [`sys.dm_db_xtp_checkpoint_files`](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-xtp-checkpoint-files-transact-sql)  
  - [`sys.dm_db_xtp_transactions`](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-xtp-transactions-transact-sql)

---

### 2.12 | Einschränkungen & Best Practices
> **Kurzbeschreibung:** Nicht unterstützte T-SQL-Konstrukte/Operationen, FK-Regeln, Interop-Tücken; Do’s & Don’ts in Produktion.

- 📓 **Notebook:**  
  [`08_12_limitations_bestpractices.ipynb`](08_12_limitations_bestpractices.ipynb)

- 🎥 **YouTube:**  
  - [Praxis: Fallstricke & Patterns (Community)](https://www.youtube.com/watch?v=SExtYPovtOk)  
  - [It Just Runs Faster – Lessons Learned](https://www.youtube.com/watch?v=pTEDfmQnpzA)

- 📘 **Docs:**  
  - [Nicht unterstützte T-SQL-Konstrukte (MOT)](https://learn.microsoft.com/en-us/sql/relational-databases/in-memory-oltp/transact-sql-constructs-not-supported-by-in-memory-oltp)  
  - [Nebenläufigkeits-Einschränkungen (Interop/RCSI)](https://learn.microsoft.com/en-us/sql/relational-databases/in-memory-oltp/concurrent-access-limitations)

---

### 2.13 | Azure SQL: Support, Quoten & Unterschiede
> **Kurzbeschreibung:** Verfügbarkeit in Azure SQL (DB/MI), Speicherquoten & Edition-Limits, Hyperscale/Serverless-Besonderheiten.

- 📓 **Notebook:**  
  [`08_13_azure_sql_inmemory.ipynb`](08_13_azure_sql_inmemory.ipynb)

- 🎥 **YouTube:**  
  - [Use Cases & Cloud-Insights (PASS/Demos)](https://www.youtube.com/playlist?list=PL4P6uoDMuOCbamt__CKLZ-Zzcd9hFvSKD)  
  - [Overview In-Memory (Microsoft/Community)](https://www.youtube.com/playlist?list=PLw4p5JNb-aY1A2dvV4hWmTv4Q7AKbWGXe)

- 📘 **Docs:**  
  - [In-Memory OLTP in Azure SQL Database (Quoten/Monitoring)](https://learn.microsoft.com/en-us/azure/azure-sql/database/in-memory-oltp-monitor-space)  
  - [Azure SQL Hyperscale – Featurematrix (Hinweis: kein MOT)](https://learn.microsoft.com/en-us/azure/azure-sql/database/service-tier-hyperscale)  

---

## 3 | Weiterführende Informationen

- 📘 Microsoft Learn: [In-Memory OLTP – Überblick](https://learn.microsoft.com/en-us/sql/relational-databases/in-memory-oltp/in-memory-oltp-overview)  
- 📘 Microsoft Learn: [Einführung in Memory-optimierte Tabellen](https://learn.microsoft.com/en-us/sql/relational-databases/in-memory-oltp/introduction-to-memory-optimized-tables)  
- 📘 Microsoft Learn: [Indexes für MOTs (Hash/Nonclustered, Anforderungen)](https://learn.microsoft.com/en-us/sql/relational-databases/in-memory-oltp/indexes-for-memory-optimized-tables)  
- 📘 Microsoft Learn: [Hash-Index – Bucket-Count & Monitoring](https://learn.microsoft.com/en-us/sql/relational-databases/in-memory-oltp/hash-indexes-for-memory-optimized-tables)  
- 📘 Microsoft Learn: [Statistiken für MOTs](https://learn.microsoft.com/en-us/sql/relational-databases/in-memory-oltp/statistics-for-memory-optimized-tables)  
- 📘 Microsoft Learn: [Transaktionen mit MOTs (Isolation/MVCC)](https://learn.microsoft.com/en-us/sql/relational-databases/in-memory-oltp/transactions-with-memory-optimized-tables)  
- 📘 Microsoft Learn: [Durability & Checkpoint File Pairs](https://learn.microsoft.com/en-us/sql/relational-databases/in-memory-oltp/durability-for-memory-optimized-tables)  
- 📘 Microsoft Learn: [Memory-optimierte Filegroup (Erstellung/Verwaltung)](https://learn.microsoft.com/en-us/sql/relational-databases/in-memory-oltp/the-memory-optimized-filegroup)  
- 📘 Microsoft Learn: [Nativ kompilierte Prozeduren – Erstellung](https://learn.microsoft.com/en-us/sql/relational-databases/in-memory-oltp/creating-natively-compiled-stored-procedures)  
- 📘 Microsoft Learn: [Unterstützte Features – Native Module](https://learn.microsoft.com/en-us/sql/relational-databases/in-memory-oltp/supported-features-for-natively-compiled-t-sql-modules)  
- 📘 Microsoft Learn: [Nebenläufigkeits-Einschränkungen (Interop/RCSI)](https://learn.microsoft.com/en-us/sql/relational-databases/in-memory-oltp/concurrent-access-limitations)  
- 📘 Microsoft Learn: [Max. Capacity Specs (u. a. Indexanzahl)](https://learn.microsoft.com/en-us/sql/sql-server/maximum-capacity-specifications-for-sql-server)  
- 📝 Simple Talk: [Beginner Guide to Memory-Optimized Tables](https://www.red-gate.com/simple-talk/databases/sql-server/t-sql-programming-sql-server/beginner-guide-to-in-memory-optimized-tables-in-sql-server/)  
- 📝 SQLShack: [Clustered Columnstore on MOT (How-To + Limits)](https://www.sqlshack.com/how-to-create-a-clustered-columnstore-index-on-a-memory-optimized-table/)  
- 🎥 YouTube: [Inside SQL Server In-Memory OLTP – Bob Ward](https://www.youtube.com/watch?v=P9DnjQqE0Gc)  
- 🎥 YouTube: [24 Hours of PASS: In-Memory OLTP Overview](https://www.youtube.com/watch?v=Aj0-p1JbW3E)  
