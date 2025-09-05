# T-SQL ANSI-Optionen (ANSI_NULLS & Co.) – Übersicht

## 1 | Begriffsdefinition

| SQL-Term | Beschreibung |
|---|---|
| `SET ANSI_NULLS` | Steuert Vergleichslogik mit `NULL`: Bei **ON** ergibt `= NULL`/`<> NULL` immer `UNKNOWN` → `IS [NOT] NULL` verwenden. Für viele Features **Pflicht: ON**. |
| `SET ANSI_NULL_DEFAULT {ON|OFF}` | Legt die **Standard-Nullability** für neu angelegte Spalten fest, wenn `NULL/NOT NULL` nicht explizit angegeben ist (`ON` → standardmäßig `NULL`). |
| `SET ANSI_PADDING` | Beeinflusst das **Speichern/Trimmen** von nachgestellten Leerzeichen (`char/varchar`) bzw. Nullen (`binary/varbinary`). Seit vielen Versionen ist **ON** empfohlen/Standard. |
| `SET ANSI_WARNINGS` | Bei **ON** werden u. a. Überlauf/Divide-by-zero als **Fehler**, „Null value eliminated in aggregate“ als **Warnung** behandelt. |
| `SET QUOTED_IDENTIFIER` | Doppeltes Anführungszeichen `"Name"` interpretiert als **Bezeichner** (nicht String). Erforderlich **ON** für mehrere Features (z. B. indizierte Sichten). |
| `SET CONCAT_NULL_YIELDS_NULL` | `NULL`-Konkatenation: Bei **ON** ist `NULL + 'x'` → `NULL`. (Empfohlen/Standard.) |
| `SET ANSI_DEFAULTS` | Schaltet ein Bündel von ANSI-Optionen auf **ON** (u. a. `ANSI_NULLS`, `ANSI_WARNINGS`, `ANSI_PADDING`, `QUOTED_IDENTIFIER`, `CONCAT_NULL_YIELDS_NULL`, `CURSOR_CLOSE_ON_COMMIT`, `IMPLICIT_TRANSACTIONS OFF`). |
| `ARITHABORT` / `ARITHIGNORE` | Verhalten bei arithmetischen Fehlern. Für einige Features ist **`ARITHABORT ON`** notwendig. |
| `NUMERIC_ROUNDABORT` | Rundung löst Fehler aus (bei **ON**). Für indizierte Sichten/indizierte berechnete Spalten muss **OFF** sein. |
| Erforderliche SET-Optionen | Für **indizierte Sichten**, **indizierte berechnete Spalten** und **gefilterte Indizes** müssen mehrere Optionen **ON** sein (u. a. `ANSI_NULLS`, `ANSI_WARNINGS`, `ANSI_PADDING`, `QUOTED_IDENTIFIER`, `CONCAT_NULL_YIELDS_NULL`, `ARITHABORT ON`, `NUMERIC_ROUNDABORT OFF`). |
| Geltungsbereich | `SET …` wirkt **sessionspezifisch**. Es gibt auch **Datenbank-Optionen** (`ALTER DATABASE … SET …`), die die Defaults für neue Verbindungen vorgeben. |
| Tool-/Treiber-Defaults | Viele Treiber/Tools (ODBC/OLE DB/SSMS) setzen ANSI-Optionen standardmäßig auf **ON**. Konsistent halten! |

---

## 2 | Struktur

### 2.1 | `ANSI_NULLS` – NULL-Vergleiche korrekt
> **Kurzbeschreibung:** Warum `= NULL` nie `TRUE` ist; praktische Muster mit `IS [NOT] NULL`, `NULL` in Set-Operatoren und 3-Werte-Logik.

- 📓 **Notebook (aus `EH3_ANSI_NULL.ipynb`):**  
  [`08_01_ansi_nulls.ipynb`](08_01_ansi_nulls.ipynb)

- 🎥 **YouTube:**  
  - [ANSI_NULLS explained](https://www.youtube.com/results?search_query=sql+server+ansi_nulls)  
  - [NULL logic in T-SQL](https://www.youtube.com/results?search_query=sql+server+null+three+valued+logic)

- 📘 **Docs:**  
  - [`SET ANSI_NULLS` (T-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-ansi-nulls-transact-sql)  
  - [`NULL` und dreiwertige Logik](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/null-transact-sql)

---

### 2.2 | `ANSI_NULL_DEFAULT` – Standard-Nullability
> **Kurzbeschreibung:** Wie die Default-Nullability neuer Spalten gesteuert wird; Auswirkungen bei `CREATE/ALTER TABLE`.

- 📓 **Notebook (aus `EH3_ANSI_NULL_DEFAULT.ipynb`):**  
  [`08_02_ansi_null_default.ipynb`](08_02_ansi_null_default.ipynb)

- 🎥 **YouTube:**  
  - [Default NULLability in SQL Server](https://www.youtube.com/results?search_query=sql+server+ansi_null_default)

- 📘 **Docs:**  
  - [`SET ANSI_NULL_DFLT_ON|OFF`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-ansi-null-dflt-on-transact-sql)

---

### 2.3 | `ANSI_PADDING` – Leerzeichen & Binaries
> **Kurzbeschreibung:** Trimmen/Padden beim Speichern in `char/varchar` und `binary/varbinary`; historische Besonderheiten.

- 📓 **Notebook (aus `EH3_ANSI_PADDING.ipynb`):**  
  [`08_03_ansi_padding.ipynb`](08_03_ansi_padding.ipynb)

- 🎥 **YouTube:**  
  - [ANSI_PADDING demo](https://www.youtube.com/results?search_query=sql+server+ansi_padding)

- 📘 **Docs:**  
  - [`SET ANSI_PADDING`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-ansi-padding-transact-sql)

---

### 2.4 | `ANSI_WARNINGS` – Fehler & Warnungen
> **Kurzbeschreibung:** Verhalten bei Überläufen, Division durch 0, Aggregaten über `NULL`; warum **ON** die sichere Wahl ist.

- 📓 **Notebook (aus `EH3_ANSI_WARNINGS.ipynb`):**  
  [`08_04_ansi_warnings.ipynb`](08_04_ansi_warnings.ipynb)

- 🎥 **YouTube:**  
  - [ANSI_WARNINGS in Practice](https://www.youtube.com/results?search_query=sql+server+ansi_warnings)

- 📘 **Docs:**  
  - [`SET ANSI_WARNINGS`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-ansi-warnings-transact-sql)

---

### 2.5 | `QUOTED_IDENTIFIER` & Bezeichner in Anführungszeichen
> **Kurzbeschreibung:** `"Spalte"` als Bezeichner vs. Stringliteral; Auswirkungen auf Parser, Views und Prozeduren.

- 📓 **Notebook:**  
  [`08_05_quoted_identifier.ipynb`](08_05_quoted_identifier.ipynb)

- 🎥 **YouTube:**  
  - [QUOTED_IDENTIFIER – Why it matters](https://www.youtube.com/results?search_query=sql+server+quoted_identifier)

- 📘 **Docs:**  
  - [`SET QUOTED_IDENTIFIER`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-quoted-identifier-transact-sql)

---

### 2.6 | `CONCAT_NULL_YIELDS_NULL` – String-Logik
> **Kurzbeschreibung:** Konsistente Stringverkettung mit `NULL`; Unterschiede zu `CONCAT()`.

- 📓 **Notebook:**  
  [`08_06_concatenate_nulls.ipynb`](08_06_concatenate_nulls.ipynb)

- 🎥 **YouTube:**  
  - [CONCAT NULL Yields NULL](https://www.youtube.com/results?search_query=sql+server+concat_null_yields_null)

- 📘 **Docs:**  
  - [`SET CONCAT_NULL_YIELDS_NULL`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-concat-null-yields-null-transact-sql)

---

### 2.7 | Paket: `ANSI_DEFAULTS` & Treiber-Defaults
> **Kurzbeschreibung:** Alle relevanten ANSI-Optionen gebündelt aktivieren; Verhalten von SSMS/ODBC/OLE DB.

- 📓 **Notebook:**  
  [`08_07_ansi_defaults.ipynb`](08_07_ansi_defaults.ipynb)

- 🎥 **YouTube:**  
  - [SET ANSI_DEFAULTS overview](https://www.youtube.com/results?search_query=sql+server+ansi_defaults)

- 📘 **Docs:**  
  - [`SET ANSI_DEFAULTS`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-ansi-defaults-transact-sql)

---

### 2.8 | Voraussetzungen für indizierte Sichten & berechnete Spalten
> **Kurzbeschreibung:** Welche `SET`-Optionen **zwingend** sind, um diese Features zu erstellen/nutzen; Prüf-Skripte.

- 📓 **Notebook:**  
  [`08_08_required_setoptions_for_indexed_views.ipynb`](08_08_required_setoptions_for_indexed_views.ipynb)

- 🎥 **YouTube:**  
  - [Requirements for Indexed Views](https://www.youtube.com/results?search_query=sql+server+indexed+views+set+options)

- 📘 **Docs:**  
  - [Indexed Views – Requirements](https://learn.microsoft.com/en-us/sql/relational-databases/views/create-indexed-views)  
  - [Computed Columns – Indexing](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/indexes-on-computed-columns)

---

### 2.9 | Arithmetik-Optionen: `ARITHABORT`, `ARITHIGNORE`, `NUMERIC_ROUNDABORT`
> **Kurzbeschreibung:** Fehlerbehandlung bei arithmetischen Ausnahmen; empfohlene Kombinationen.

- 📓 **Notebook:**  
  [`08_09_arithabort_numeric_roundabort.ipynb`](08_09_arithabort_numeric_roundabort.ipynb)

- 🎥 **YouTube:**  
  - [ARITHABORT vs ARITHIGNORE](https://www.youtube.com/results?search_query=sql+server+arithabort)

- 📘 **Docs:**  
  - [`SET ARITHABORT`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-arithabort-transact-sql) · [`SET ARITHIGNORE`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-arithignore-transact-sql)  
  - [`SET NUMERIC_ROUNDABORT`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-numeric-roundabort-transact-sql)

---

### 2.10 | Session vs. Datenbank-Defaults & Deployment
> **Kurzbeschreibung:** `ALTER DATABASE … SET …` vs. `SET …` pro Session; sichere Default-Strategien im Projekt.

- 📓 **Notebook:**  
  [`08_10_session_vs_db_defaults.ipynb`](08_10_session_vs_db_defaults.ipynb)

- 🎥 **YouTube:**  
  - [Session & Database Options](https://www.youtube.com/results?search_query=sql+server+database+set+options)

- 📘 **Docs:**  
  - [ALTER DATABASE – SET Options](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-database-transact-sql-set-options)  
  - [sys.dm_exec_sessions – SET-Status prüfen](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-sessions-transact-sql)

---

### 2.11 | Typische Fehlermeldungen & Troubleshooting
> **Kurzbeschreibung:** „Null value eliminated in aggregate“, „Divide by zero“ u. a.; reproduzieren, verstehen, beheben.

- 📓 **Notebook:**  
  [`08_11_troubleshooting_ansi_options.ipynb`](08_11_troubleshooting_ansi_options.ipynb)

- 🎥 **YouTube:**  
  - [Divide by Zero / Null in Aggregates](https://www.youtube.com/results?search_query=sql+server+divide+by+zero+ansi_warnings)

- 📘 **Docs:**  
  - [`TRY_CONVERT`/`NULLIF`/`COALESCE` – Hilfsfunktionen](https://learn.microsoft.com/en-us/sql/t-sql/functions/try-convert-transact-sql)

---

### 2.12 | Anti-Patterns & Migrations-Fallen
> **Kurzbeschreibung:** Option-Mischmasch zwischen Tools, Set-Optionen nur teilweise einschalten, „schweigende“ Fehler bei `ANSI_WARNINGS OFF`.

- 📓 **Notebook:**  
  [`08_12_ansi_options_anti_patterns.ipynb`](08_12_ansi_options_anti_patterns.ipynb)

- 🎥 **YouTube:**  
  - [Common SET Option Pitfalls](https://www.youtube.com/results?search_query=sql+server+set+options+pitfalls)

- 📘 **Docs/Blog:**  
  - [Best Practices – SET Options konsistent halten](https://learn.microsoft.com/en-us/sql/relational-databases/troubleshoot/troubleshoot-set-options)

---

## 3 | Weiterführende Informationen

- 📘 Microsoft Learn: [`SET ANSI_NULLS`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-ansi-nulls-transact-sql)  
- 📘 Microsoft Learn: [`SET ANSI_NULL_DFLT_ON|OFF`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-ansi-null-dflt-on-transact-sql)  
- 📘 Microsoft Learn: [`SET ANSI_PADDING`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-ansi-padding-transact-sql)  
- 📘 Microsoft Learn: [`SET ANSI_WARNINGS`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-ansi-warnings-transact-sql)  
- 📘 Microsoft Learn: [`SET QUOTED_IDENTIFIER`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-quoted-identifier-transact-sql)  
- 📘 Microsoft Learn: [`SET CONCAT_NULL_YIELDS_NULL`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-concat-null-yields-null-transact-sql)  
- 📘 Microsoft Learn: [`SET ANSI_DEFAULTS`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-ansi-defaults-transact-sql)  
- 📘 Microsoft Learn: [`SET ARITHABORT` / `ARITHIGNORE` / `NUMERIC_ROUNDABORT`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-arithabort-transact-sql)  
- 📘 Microsoft Learn: [Indexed Views – erforderliche SET-Optionen](https://learn.microsoft.com/en-us/sql/relational-databases/views/create-indexed-views)  
- 📘 Microsoft Learn: [Computed Columns – Index-Anforderungen](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/indexes-on-computed-columns)  
- 📘 Microsoft Learn: [ALTER DATABASE – SET Options](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-database-transact-sql-set-options)  
- 📝 Blog (Erland Sommarskog): *The Curse and Blessings of SET Options* (Suchlink) – https://www.sommarskog.se/  
- 📝 Blog (SQLPerformance): *SET Options & Planwahl* – https://www.sqlperformance.com/?s=set+options  
- 📝 Blog (Brent Ozar): *Why your indexed view won’t create* – https://www.brentozar.com/  
- 🎥 YouTube (Data Exposed): *ANSI & Compatibility Settings* – Suche auf YouTube  
