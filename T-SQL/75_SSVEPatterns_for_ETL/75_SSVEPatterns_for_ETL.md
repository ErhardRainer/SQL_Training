# T-SQL SSVE-Patterns für ETL – Übersicht  
*Best Practices für ETL-Prozesse: Idempotenz, Wasserzeichen, Checksummen*

> **SSVE** = **S**et-based, **S**afe, **V**ersion-aware, **E**fficient – robuste T-SQL-Muster für wiederholbare, performante ETL-Jobs.

## 1 | Begriffsdefinition

| SQL-Term | Beschreibung |
|---|---|
| ETL vs. ELT | **ETL** (Extract–Transform–Load) in Staging, **ELT** (Load → Transform) set-basiert im Ziel. |
| Staging-Zonen | *Landing* (roh), *Staging* (bereinigt), *Core*/*DimFact* (modelliert). |
| Idempotenz | Mehrfaches Ausführen führt zum **gleichen Endzustand** (z. B. Upsert nach Schlüssel + Änderungsdetektion). |
| Wasserzeichen (High-Water-Mark) | Letzter erfolgreich verarbeiteter **Zeit-/Schlüsselstand** (z. B. `LastModified >= :wm`), gespeichert in **Run-Log**. |
| Delta-/Inkrementalladung | Nur seit dem Wasserzeichen geänderte/neu hinzugefügte Datensätze laden. |
| Checksummen/Hash | **Zeilenhash** (z. B. `HASHBYTES('SHA2_256', …)`) zum schnellen Erkennen inhaltlicher Änderungen. |
| Upsert | *UPDATE* vorhandener + *INSERT* neuer Schlüssel (robust), optional *DELETE* veralteter (Synchronisation). |
| SCD (Type 1/2) | Slowly Changing Dimensions: **Type 1** überschreibt, **Type 2** historisiert mit Gültigkeitsintervallen. |
| Change Tracking (CT) | Lightweight Änderungsmarkierung pro Tabelle (Schlüssel + Operation), gut für Delta-Ladungen. |
| Change Data Capture (CDC) | Log-basierte Erfassung mit **Before/After**-Werten; vollständige Historie für ETL. |
| Rowversion/Timestamp | Monotone Versionsspalte zur Delta-Erkennung (optimistic concurrency). |
| Batching | Verarbeitung in **Teilmenge** (z. B. `TOP (N)`), reduziert Log-/Lock-Druck. |
| Quarantäne/Rejects | Ungültige Zeilen (Typ-/FK-/Geschäftsregeln) in **Reject-Tabellen** speichern, nicht verlieren. |
| Run-Log/Audit | Metadaten je Lauf: Start/Ende, Zählwerte, Wasserzeichen, Checksummen, Fehler. |
| SWITCH/Sliding | **Partition Switch** für schnelles Ein-/Ausspielen ganzer Datenmengen. |
| Governance | Namenskonventionen, Wiederholbarkeit, **Least Privilege**, getrennte Schemata (`landing`, `stg`, `core`). |

---

## 2 | Struktur

### 2.1 | Architektur & Zonen (Landing → Staging → Core)
> **Kurzbeschreibung:** Saubere Layering-Strategie, Trennung von Rohdaten, Bereinigung und Modellierung.

- 📓 **Notebook:**  
  [`08_01_architektur_zonen.ipynb`](08_01_architektur_zonen.ipynb)
- 🎥 **YouTube:**  
  - [ETL Architecture Layers](https://www.youtube.com/results?search_query=etl+architecture+staging+core+sql+server)
- 📘 **Docs:**  
  - [Best Practices – Datenmodellierung & Layering (Übersicht)](https://learn.microsoft.com/en-us/sql/sql-server) *(Einstiegspunkt)*

---

### 2.2 | Idempotenz-Pattern: Schlüssel + Hash + Run-Log
> **Kurzbeschreibung:** Exakte Wiederholbarkeit mithilfe von Business Key, Zeilenhash und Run-Log/RUN_ID.

- 📓 **Notebook:**  
  [`08_02_idempotenz_runlog_hash.ipynb`](08_02_idempotenz_runlog_hash.ipynb)
- 🎥 **YouTube:**  
  - [Idempotent ETL Patterns](https://www.youtube.com/results?search_query=idempotent+etl+pattern+sql+server)
- 📘 **Docs:**  
  - [`HASHBYTES` (SHA2_256 u. a.)](https://learn.microsoft.com/en-us/sql/t-sql/functions/hashbytes-transact-sql)  
  - [OUTPUT-Klausel (Auditing/Delta)](https://learn.microsoft.com/en-us/sql/t-sql/queries/output-clause-transact-sql)

---

### 2.3 | Wasserzeichen verwalten (CT/CDC/Rowversion/Datum)
> **Kurzbeschreibung:** Wahl der Quelle fürs High-Water-Mark und sichere Persistenz im Run-Log.

- 📓 **Notebook:**  
  [`08_03_wasserzeichen_delta.ipynb`](08_03_wasserzeichen_delta.ipynb)
- 🎥 **YouTube:**  
  - [High Water Mark Incremental Load](https://www.youtube.com/results?search_query=high+watermark+incremental+load+sql+server)
- 📘 **Docs:**  
  - [Change Tracking (CT) – Überblick](https://learn.microsoft.com/en-us/sql/relational-databases/track-changes/about-change-tracking-sql-server)  
  - [Change Data Capture (CDC) – Überblick](https://learn.microsoft.com/en-us/sql/relational-databases/track-changes/about-change-data-capture-sql-server)

---

### 2.4 | Deduplizierung & Schlüsselstrategie
> **Kurzbeschreibung:** Eindeutigkeit in Staging erzwingen (PK/UNIQUE) und Duplikate in Quarantäne ablegen.

- 📓 **Notebook:**  
  [`08_04_dedupe_keys_staging.ipynb`](08_04_dedupe_keys_staging.ipynb)
- 🎥 **YouTube:**  
  - [Deduplicate Staging Data](https://www.youtube.com/results?search_query=sql+server+deduplicate+staging)
- 📘 **Docs:**  
  - [Constraints (PRIMARY/UNIQUE/CHECK)](https://learn.microsoft.com/en-us/sql/relational-databases/tables/create-unique-constraints)

---

### 2.5 | Checksummen & Änderungsdetektion (Hashdiff)
> **Kurzbeschreibung:** Stabiler Spaltenzuschnitt + `HASHBYTES`/`CHECKSUM` vs. Null- und Reihenfolgefallen.

- 📓 **Notebook:**  
  [`08_05_checksum_hashdiff.ipynb`](08_05_checksum_hashdiff.ipynb)
- 🎥 **YouTube:**  
  - [Row Hash for Change Detection](https://www.youtube.com/results?search_query=row+hash+change+detection+sql+server)
- 📘 **Docs:**  
  - [`HASHBYTES` Referenz](https://learn.microsoft.com/en-us/sql/t-sql/functions/hashbytes-transact-sql) ・ [`CHECKSUM`/`BINARY_CHECKSUM`](https://learn.microsoft.com/en-us/sql/t-sql/functions/checksum-transact-sql)

---

### 2.6 | Upsert ohne MERGE (robust)
> **Kurzbeschreibung:** `UPDATE … FROM` + `INSERT` fehlender Schlüssel, optional `DELETE` verwaister – mit Sperrhints für Korrektheit.

- 📓 **Notebook:**  
  [`08_06_upsert_ohne_merge.ipynb`](08_06_upsert_ohne_merge.ipynb)
- 🎥 **YouTube:**  
  - [Robust UPSERT Patterns](https://www.youtube.com/results?search_query=sql+server+upsert+pattern+without+merge)
- 📘 **Docs:**  
  - [`UPDATE` (JOIN) & `INSERT` Referenz](https://learn.microsoft.com/en-us/sql/t-sql/queries/update-transact-sql)  
  - [Table Hints (`UPDLOCK`/`HOLDLOCK`)](https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-table)

---

### 2.7 | SCD Type 1 & 2 in T-SQL
> **Kurzbeschreibung:** Überschreiben vs. Historisieren mit `ValidFrom/ValidTo/IsCurrent` und Hashvergleich.

- 📓 **Notebook:**  
  [`08_07_scd_type1_type2.ipynb`](08_07_scd_type1_type2.ipynb)
- 🎥 **YouTube:**  
  - [Implement SCD Type 2 (T-SQL)](https://www.youtube.com/results?search_query=scd+type+2+sql+server+t-sql)
- 📘 **Docs:**  
  - [Temporal Tables (Alternative)](https://learn.microsoft.com/en-us/sql/relational-databases/tables/temporal-tables)

---

### 2.8 | Bulk Load & Staging (BULK INSERT/BCP/OPENROWSET)
> **Kurzbeschreibung:** Schnelles Laden in *landing* mit Formatdateien, `ERRORFILE`, Minimal Logging.

- 📓 **Notebook:**  
  [`08_08_bulkload_staging.ipynb`](08_08_bulkload_staging.ipynb)
- 🎥 **YouTube:**  
  - [BULK INSERT Tutorial](https://www.youtube.com/results?search_query=bulk+insert+sql+server+tutorial)
- 📘 **Docs:**  
  - [`BULK INSERT`](https://learn.microsoft.com/en-us/sql/t-sql/statements/bulk-insert-transact-sql) ・ [`OPENROWSET(BULK)`](https://learn.microsoft.com/en-us/sql/t-sql/functions/openrowset-transact-sql)

---

### 2.9 | Validierung & Quarantäne (Rejects)
> **Kurzbeschreibung:** Typ-/Bereichs-/FK-Prüfungen, fehlerhafte Zeilen erfassen (`OUTPUT INTO rejects`).

- 📓 **Notebook:**  
  [`08_09_validation_rejects.ipynb`](08_09_validation_rejects.ipynb)
- 🎥 **YouTube:**  
  - [ETL Data Validation Patterns](https://www.youtube.com/results?search_query=sql+server+etl+data+validation)
- 📘 **Docs:**  
  - [OUTPUT-Klausel – in Tabellen schreiben](https://learn.microsoft.com/en-us/sql/t-sql/queries/output-clause-transact-sql)

---

### 2.10 | Transaktionen, Batching & XACT_ABORT
> **Kurzbeschreibung:** Log-/Lock-Steuerung mit Teilmengen (`TOP (N)`-Loop), `XACT_ABORT ON`, Wiederaufsetzbarkeit.

- 📓 **Notebook:**  
  [`08_10_transactions_batching_xactabort.ipynb`](08_10_transactions_batching_xactabort.ipynb)
- 🎥 **YouTube:**  
  - [Batching Large Updates/Inserts](https://www.youtube.com/results?search_query=sql+server+batching+large+updates)
- 📘 **Docs:**  
  - [`XACT_ABORT`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-xact-abort-transact-sql) ・ [`TRY…CATCH`](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/try-catch-transact-sql)

---

### 2.11 | Partition Switch & Sliding Window
> **Kurzbeschreibung:** Daten atomar ins Core schieben/entfernen; Anforderungen (aligned Indexe, CHECKs).

- 📓 **Notebook:**  
  [`08_11_partition_switch_sliding.ipynb`](08_11_partition_switch_sliding.ipynb)
- 🎥 **YouTube:**  
  - [Partition SWITCH for ETL](https://www.youtube.com/results?search_query=sql+server+partition+switch+etl)
- 📘 **Docs:**  
  - [Switching Partitions – Anforderungen](https://learn.microsoft.com/en-us/sql/relational-databases/partitions/switching-partitions#requirements)

---

### 2.12 | Performance: SARGability, Indizes & Set-basiert
> **Kurzbeschreibung:** Prädikate sargierbar halten, *Staging*-Indizes gezielt, große Logik **set-basiert** statt RBAR.

- 📓 **Notebook:**  
  [`08_12_perf_sargability_setbased.ipynb`](08_12_perf_sargability_setbased.ipynb)
- 🎥 **YouTube:**  
  - [Set-Based ETL in T-SQL](https://www.youtube.com/results?search_query=set+based+etl+t-sql)
- 📘 **Docs:**  
  - [Query Processing Architecture](https://learn.microsoft.com/en-us/sql/relational-databases/query-processing-architecture-guide)

---

### 2.13 | Audit & Run-Log-Design
> **Kurzbeschreibung:** Struktur für Läufe/Schritte, Zählwerte (reads/inserts/updates/deletes), Wasserzeichen, Hashsummen, Checks.

- 📓 **Notebook:**  
  [`08_13_audit_runlog_design.ipynb`](08_13_audit_runlog_design.ipynb)
- 🎥 **YouTube:**  
  - [Build ETL Audit Tables](https://www.youtube.com/results?search_query=etl+audit+table+sql+server)
- 📘 **Docs:**  
  - [SQL Agent – Jobs/Steps (für Ausführungsmetadaten)](https://learn.microsoft.com/en-us/sql/ssms/agent/sql-server-agent)

---

### 2.14 | Fehlerbehandlung & Retry/Dead-Letter
> **Kurzbeschreibung:** Retries für temporäre Fehler, Dead-Letter-Queues/Tabellen, idempotente Wiederaufnahme.

- 📓 **Notebook:**  
  [`08_14_error_handling_retry_deadletter.ipynb`](08_14_error_handling_retry_deadletter.ipynb)
- 🎥 **YouTube:**  
  - [Retry Patterns for ETL](https://www.youtube.com/results?search_query=retry+pattern+sql+server+etl)
- 📘 **Docs:**  
  - [`THROW`/`RAISERROR`](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/throw-transact-sql)

---

### 2.15 | Sicherheit, Least Privilege & Signing
> **Kurzbeschreibung:** Getrennte Schemata, `EXECUTE AS`/Module-Signing, nur notwendige Rechte für ETL-Accounts.

- 📓 **Notebook:**  
  [`08_15_security_least_privilege_signing.ipynb`](08_15_security_least_privilege_signing.ipynb)
- 🎥 **YouTube:**  
  - [Module Signing for ETL](https://www.youtube.com/results?search_query=sql+server+module+signing)
- 📘 **Docs:**  
  - [Module Signing](https://learn.microsoft.com/en-us/sql/relational-databases/security/authentication-access/signing-stored-procedures)  
  - [Permissions & Securables – Überblick](https://learn.microsoft.com/en-us/sql/relational-databases/security/permissions-database-engine)

---

### 2.16 | Anti-Patterns & Checkliste
> **Kurzbeschreibung:** MERGE blind einsetzen, keine Wasserzeichen/Run-Logs, Hash ohne Null-Normalisierung, RBAR-Schleifen, fehlende Quarantäne, „Alles in einer Transaktion“, ohne Indizes/SARGability, keine Wiederanlauffähigkeit.

- 📓 **Notebook:**  
  [`08_16_antipatterns_checkliste_etl.ipynb`](08_16_antipatterns_checkliste_etl.ipynb)
- 🎥 **YouTube:**  
  - [Common ETL Mistakes (SQL Server)](https://www.youtube.com/results?search_query=common+etl+mistakes+sql+server)
- 📘 **Docs/Blog:**  
  - [Best Practices – ETL/Loading (Sammlung)](https://learn.microsoft.com/en-us/sql/sql-server) *(Einstiegspunkt)*

---

## 3 | Weiterführende Informationen

- 📘 Microsoft Learn: [Change Tracking (CT)](https://learn.microsoft.com/en-us/sql/relational-databases/track-changes/about-change-tracking-sql-server)  
- 📘 Microsoft Learn: [Change Data Capture (CDC)](https://learn.microsoft.com/en-us/sql/relational-databases/track-changes/about-change-data-capture-sql-server)  
- 📘 Microsoft Learn: [`HASHBYTES` (SHA2_256 u. a.)](https://learn.microsoft.com/en-us/sql/t-sql/functions/hashbytes-transact-sql) ・ [`CHECKSUM`](https://learn.microsoft.com/en-us/sql/t-sql/functions/checksum-transact-sql)  
- 📘 Microsoft Learn: [`BULK INSERT` / `OPENROWSET(BULK)`](https://learn.microsoft.com/en-us/sql/t-sql/functions/openrowset-transact-sql)  
- 📘 Microsoft Learn: [Temporal Tables – Historisierung & Delta](https://learn.microsoft.com/en-us/sql/relational-databases/tables/temporal-tables)  
- 📘 Microsoft Learn: [Partition Switching – Sliding Window](https://learn.microsoft.com/en-us/sql/relational-databases/partitions/switching-partitions)  
- 📘 Microsoft Learn: [Table Hints (`UPDLOCK`, `HOLDLOCK`)](https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-table)  
- 📘 Microsoft Learn: [`TRY…CATCH` / `THROW` / `XACT_ABORT`](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/throw-transact-sql)  
- 📘 Microsoft Learn: [SQL Server Agent – Automatisierung](https://learn.microsoft.com/en-us/sql/ssms/agent/sql-server-agent)  
- 📝 SQLPerformance: *Batching Techniques & Minimal Logging* – https://www.sqlperformance.com/?s=batching  
- 📝 Redgate Simple Talk: *Idempotent ETL & Hash Diff* – https://www.red-gate.com/simple-talk/  
- 📝 Brent Ozar: *Why I Avoid MERGE for UPSERTs* – https://www.brentozar.com/  
- 📝 Erik Darling: *SARGability & ETL Patterns* – https://www.erikdarlingdata.com/  
- 📝 Paul White (SQL Kiwi): *Query Plans & Set-Based Loads* – https://www.sql.kiwi/  
- 🎥 YouTube (Data Exposed): *Change Tracking/CDC & Incremental Loads* – Suchlink  
- 🎥 YouTube: *Partition Switch for Fast Loads* – Suchlink  
