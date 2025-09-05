# T-SQL QUOTED_IDENTIFIER – Übersicht  
*Wirkung von `SET QUOTED_IDENTIFIER` auf Identifikatoren und Anweisungen*

## 1 | Begriffsdefinition

| SQL-Term | Beschreibung |
|---|---|
| `SET QUOTED_IDENTIFIER { ON | OFF }` | Steuert die Bedeutung **doppelter Anführungszeichen** (`"..."`). **ON:** `"` kennzeichnet **Bezeichner** (Objekt-/Spaltennamen). **OFF:** `"` kennzeichnet **Stringliterale** (wie `'...'`). |
| Single Quotes `'...'` | **Immer** Stringliteral – unabhängig von `QUOTED_IDENTIFIER`. |
| Brackets `[...]` | Bezeichner-Quoting **immer** möglich, unabhängig von `QUOTED_IDENTIFIER`. |
| Persistierung im Objekt | Bei Erstellung von Prozeduren/Views/Triggern wird der `QUOTED_IDENTIFIER`-Status **im Objekt gespeichert** und bei Kompilierung/Ausführung verwendet. |
| Erforderliche SET-Optionen | Für bestimmte Features (z. B. **indizierte Sichten**, **indizierte berechnete Spalten**, oft **gefilterte Indizes**) muss `QUOTED_IDENTIFIER` **ON** sein (neben weiteren ANSI-Optionen). |
| ANSI-Paket | `SET ANSI_DEFAULTS ON` schaltet u. a. `QUOTED_IDENTIFIER ON` für die Session. |
| Tools/Driver-Defaults | Moderne Treiber/SSMS arbeiten standardmäßig mit `QUOTED_IDENTIFIER ON`. |
| Prüfung | Session: `DBCC USEROPTIONS`, `SELECT set_options FROM sys.dm_exec_sessions WHERE session_id=@@SPID`. Objekte: `SELECT is_quoted_ident_on FROM sys.sql_modules WHERE object_id=OBJECT_ID('dbo.Proc');` |
| Best Practice | Stringliterale **immer** mit `'...'`, Bezeichner **ohne** Sonderzeichen wählen oder `[]`/`QUOTENAME()` nutzen; `QUOTED_IDENTIFIER ON` als Standard. |

---

## 2 | Struktur

### 2.1 | Grundlagen & Syntax
> **Kurzbeschreibung:** Was `QUOTED_IDENTIFIER` tut, warum `'...'` immer Strings sind und `"` je nach Einstellung Bezeichner oder String.

- 📓 **Notebook:**  
  [`08_01_qi_grundlagen.ipynb`](08_01_qi_grundlagen.ipynb)

- 🎥 **YouTube:**  
  - [QUOTED_IDENTIFIER Basics](https://www.youtube.com/results?search_query=sql+server+quoted_identifier)  

- 📘 **Docs:**  
  - [`SET QUOTED_IDENTIFIER`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-quoted-identifier-transact-sql)

---

### 2.2 | Bezeichner quoten: `"` vs. `[]` vs. `QUOTENAME()`
> **Kurzbeschreibung:** Reservierte Wörter/Raum im Namen; robuster mit `[]` oder `QUOTENAME()` (Default: `[]`) – unabhängig von `QUOTED_IDENTIFIER`.

- 📓 **Notebook:**  
  [`08_02_identifiers_quotename.ipynb`](08_02_identifiers_quotename.ipynb)

- 🎥 **YouTube:**  
  - [QUOTENAME for Safe Identifiers](https://www.youtube.com/results?search_query=sql+server+quotename)

- 📘 **Docs:**  
  - [`QUOTENAME`](https://learn.microsoft.com/en-us/sql/t-sql/functions/quotename-transact-sql)

---

### 2.3 | Persistierte Einstellung in Modulen (Procs/Views/Trigger)
> **Kurzbeschreibung:** `QUOTED_IDENTIFIER` wird beim **CREATE**-Zeitpunkt gespeichert und beeinflusst Parsing/Kompatibilität des Objektcodes.

- 📓 **Notebook:**  
  [`08_03_persistenz_in_modulen.ipynb`](08_03_persistenz_in_modulen.ipynb)

- 🎥 **YouTube:**  
  - [Stored Setting in Modules](https://www.youtube.com/results?search_query=sql+server+quoted_identifier+stored+in+objects)

- 📘 **Docs:**  
  - [`sys.sql_modules.is_quoted_ident_on`](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-sql-modules-transact-sql)

---

### 2.4 | Zusammenspiel mit `ANSI_DEFAULTS` & Session-Optionen
> **Kurzbeschreibung:** Wie `ANSI_DEFAULTS` viele Optionen – inkl. `QUOTED_IDENTIFIER` – auf **ON** setzt; Prüfung mit `DBCC USEROPTIONS`.

- 📓 **Notebook:**  
  [`08_04_ansi_defaults_und_session.ipynb`](08_04_ansi_defaults_und_session.ipynb)

- 🎥 **YouTube:**  
  - [ANSI_DEFAULTS & Session Options](https://www.youtube.com/results?search_query=sql+server+ansi_defaults)

- 📘 **Docs:**  
  - [`SET ANSI_DEFAULTS`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-ansi-defaults-transact-sql)  
  - [`DBCC USEROPTIONS`](https://learn.microsoft.com/en-us/sql/t-sql/database-console-commands/dbcc-useroptions-transact-sql)

---

### 2.5 | Voraussetzungen für spezielle Features
> **Kurzbeschreibung:** `QUOTED_IDENTIFIER ON` ist u. a. Pflicht für **indizierte Sichten** und **indizierte berechnete Spalten**; häufig auch bei **gefilterten Indizes** erforderlich (mit weiteren ANSI-Optionen).

- 📓 **Notebook:**  
  [`08_05_required_set_options_features.ipynb`](08_05_required_set_options_features.ipynb)

- 🎥 **YouTube:**  
  - [Indexed Views Requirements](https://www.youtube.com/results?search_query=sql+server+indexed+view+requirements)

- 📘 **Docs:**  
  - [Indexed Views – Requirements](https://learn.microsoft.com/en-us/sql/relational-databases/views/create-indexed-views)  
  - [Indexes on Computed Columns](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/indexes-on-computed-columns)

---

### 2.6 | Dynamisches SQL richtig quoten
> **Kurzbeschreibung:** Objekt-/Spaltennamen sicher zusammensetzen mit `QUOTENAME()`, Werte **parametrisieren** (nicht konkatenieren).

- 📓 **Notebook:**  
  [`08_06_dynamic_sql_quoting_patterns.ipynb`](08_06_dynamic_sql_quoting_patterns.ipynb)

- 🎥 **YouTube:**  
  - [Dynamic SQL – QUOTENAME & Params](https://www.youtube.com/results?search_query=sql+server+dynamic+sql+quotename+sp_executesql)

- 📘 **Docs:**  
  - [`sp_executesql` (Parameterisierung)](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-executesql-transact-sql)

---

### 2.7 | Migration: Altskripte mit `QUOTED_IDENTIFIER OFF`
> **Kurzbeschreibung:** Risiken (z. B. `"text"` als String), Re-Create von Modulen mit `ON`, vereinheitlichte Script-Header.

- 📓 **Notebook:**  
  [`08_07_migration_off_to_on.ipynb`](08_07_migration_off_to_on.ipynb)

- 🎥 **YouTube:**  
  - [Modernizing Old Scripts](https://www.youtube.com/results?search_query=sql+server+quoted_identifier+off+migration)

- 📘 **Docs:**  
  - [`SET QUOTED_IDENTIFIER` – Hinweise](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-quoted-identifier-transact-sql#remarks)

---

### 2.8 | Parsing-Fallstricke & Tests
> **Kurzbeschreibung:** Doppelquotes in Strings vs. Bezeichnern; Testroutinen mit `TRY…CATCH`/`sys.sql_modules` zur Verifikation.

- 📓 **Notebook:**  
  [`08_08_parsing_fallstricke_tests.ipynb`](08_08_parsing_fallstricke_tests.ipynb)

- 🎥 **YouTube:**  
  - [Quoted Identifier Pitfalls](https://www.youtube.com/results?search_query=sql+server+quoted+identifier+pitfalls)

- 📘 **Docs:**  
  - [`TRY…CATCH` & `THROW`](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/try-catch-transact-sql)

---

### 2.9 | Tooling & Scripting (SSMS, DACPAC)
> **Kurzbeschreibung:** SSMS generiert meist Script-Header mit `SET QUOTED_IDENTIFIER ON`; in Build/Deploy-Pipelines konsistent halten.

- 📓 **Notebook:**  
  [`08_09_tooling_script_header.ipynb`](08_09_tooling_script_header.ipynb)

- 🎥 **YouTube:**  
  - [SSDT/DACPAC & SET Options](https://www.youtube.com/results?search_query=ssdt+dacpac+set+options)

- 📘 **Docs:**  
  - [`CREATE OR ALTER` – Module neu erstellen](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-or-alter-transact-sql)

---

### 2.10 | Prüfung & Monitoring der Session-Optionen
> **Kurzbeschreibung:** Aktuelle Optionen je Verbindung auslesen (`sys.dm_exec_sessions`, `sys.dm_exec_requests`) und in Audits validieren.

- 📓 **Notebook:**  
  [`08_10_monitoring_setoptions.ipynb`](08_10_monitoring_setoptions.ipynb)

- 🎥 **YouTube:**  
  - [Check Session SET Options](https://www.youtube.com/results?search_query=sql+server+check+session+set+options)

- 📘 **Docs:**  
  - [`sys.dm_exec_sessions`](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-sessions-transact-sql)

---

### 2.11 | Namenskonventionen & Design
> **Kurzbeschreibung:** Bezeichner so wählen, dass Quoting selten nötig ist (keine Leerzeichen/Reservierten Wörter); wo nötig, `[]` standardisieren.

- 📓 **Notebook:**  
  [`08_11_namenskonventionen.ipynb`](08_11_namenskonventionen.ipynb)

- 🎥 **YouTube:**  
  - [SQL Naming Conventions](https://www.youtube.com/results?search_query=sql+server+naming+conventions)

- 📘 **Docs:**  
  - [Database Identifiers – Rules](https://learn.microsoft.com/en-us/sql/relational-databases/databases/database-identifiers)

---

### 2.12 | Anti-Patterns & Checkliste
> **Kurzbeschreibung:** `QUOTED_IDENTIFIER OFF` in neuen Modulen, gemischte Standards pro DB, Strings mit `"..."`, dynamisches SQL ohne `QUOTENAME()`.

- 📓 **Notebook:**  
  [`08_12_qi_anti_patterns.ipynb`](08_12_qi_anti_patterns.ipynb)

- 🎥 **YouTube:**  
  - [Common QUOTED_IDENTIFIER Mistakes](https://www.youtube.com/results?search_query=quoted+identifier+mistakes+sql+server)

- 📘 **Docs/Blog:**  
  - [Best Practices – SET Options konsistent halten](https://learn.microsoft.com/en-us/sql/relational-databases/troubleshoot/troubleshoot-set-options)

---

## 3 | Weiterführende Informationen

- 📘 Microsoft Learn: [`SET QUOTED_IDENTIFIER`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-quoted-identifier-transact-sql)  
- 📘 Microsoft Learn: [`SET ANSI_DEFAULTS`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-ansi-defaults-transact-sql)  
- 📘 Microsoft Learn: [Database Identifiers – Regeln & Beispiele](https://learn.microsoft.com/en-us/sql/relational-databases/databases/database-identifiers)  
- 📘 Microsoft Learn: [`QUOTENAME`](https://learn.microsoft.com/en-us/sql/t-sql/functions/quotename-transact-sql)  
- 📘 Microsoft Learn: [Indexed Views – erforderliche SET-Optionen](https://learn.microsoft.com/en-us/sql/relational-databases/views/create-indexed-views)  
- 📘 Microsoft Learn: [Indexes on Computed Columns – Voraussetzungen](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/indexes-on-computed-columns)  
- 📘 Microsoft Learn: [`sys.sql_modules` – `is_quoted_ident_on`](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-sql-modules-transact-sql)  
- 📘 Microsoft Learn: [`sys.dm_exec_sessions` – SET-Bitmaske](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-sessions-transact-sql)  
- 📝 Simple Talk (Redgate): *QUOTED_IDENTIFIER & Safe Quoting* (Suche)  
- 📝 SQLPerformance: *SET Options & Plan/Features* (Suchsammlung) – https://www.sqlperformance.com/?s=set+options  
- 📝 Brent Ozar: *Warum `[]`/`QUOTENAME()`?* – https://www.brentozar.com/  
- 📝 Erik Darling: *Dynamic SQL: QUOTENAME & Parameterization* – https://www.erikdarlingdata.com/  
- 🎥 YouTube: *QUOTED_IDENTIFIER erklärt* (diverse Channels)  
