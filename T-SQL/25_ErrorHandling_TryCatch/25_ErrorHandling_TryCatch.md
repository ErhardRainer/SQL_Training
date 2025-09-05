# T-SQL Fehlerbehandlung (TRY…CATCH, THROW/RAISERROR) – Übersicht

## 1 | Begriffsdefinition

| SQL-Term | Beschreibung |
|---|---|
| `TRY…CATCH` | Strukturiertes Fehlerhandling in T-SQL; Laufzeitfehler springen in den `CATCH`-Block. |
| `THROW` | Moderne Fehlerauslösung (SQL 2012+). Entweder **rethrow** ohne Parameter im `CATCH` (bewahrt Originalfehler) oder `THROW error_number(≥50000), message, state;` (Severity fix **16**). |
| `RAISERROR` | Älteres Pendant mit Formatierung/Optionen (`NOWAIT`,`LOG`,`SETERROR`), **Severity/State** frei wählbar; empfohlen: bevorzugt `THROW` für neue Entwicklung. |
| Severity/State | Fehler-Schwere (0–25) & Status (0–255). `RAISERROR` ≥11 sind Fehler; ≥20 beendet i. d. R. die Verbindung. `THROW` mit Parametern erzeugt Severity 16. |
| `ERROR_*()` | Im `CATCH` verfügbar: `ERROR_NUMBER()`, `ERROR_SEVERITY()`, `ERROR_STATE()`, `ERROR_PROCEDURE()`, `ERROR_LINE()`, `ERROR_MESSAGE()`. |
| `XACT_STATE()` | **1** = commitbar, **-1** = nicht commitbar (nur Rollback), **0** = keine Transaktion. |
| `@@TRANCOUNT` | Tiefe verschachtelter Transaktionen. Nur äußerster `COMMIT` persistiert; `ROLLBACK` setzt auf 0. |
| `SET XACT_ABORT ON` | Laufzeitfehler führen zu **automatischem Rollback** der ganzen Transaktion → weniger „teil-kommittierte“ Zustände. |
| Savepoint | `SAVE TRAN` + `ROLLBACK TRAN savepoint` für Teil-Rollbacks in laufender Transaktion. |
| Benutzerdefinierte Meldungen | `sp_addmessage` + `RAISERROR(msg_id,…)` für lokalisierte/formatierte Texte (Platzhalter). |
| Logging | Zentrales Fehlerlog (Tabelle/XEvents/Eventlog) mit Kontext (`SUSER_SNAME()`, `HOST_NAME()`, `APP_NAME()`, `SESSION_CONTEXT`). |
| Nicht fangbare Fehler | Kompilierfehler, Verbindungsabbruch, einige schwere Fehler (Severity ≥20) landen **nicht** im `CATCH`. |
| Deadlock (1205) | Spezieller Fehler; typisches **Retry**-Pattern mit Backoff. |
| Anti-Pattern | `@@ERROR` nach jeder Anweisung, Fehler **verschlucken**, „Commit trotz Fehler“, unparametrisiertes `RAISERROR`. |

---

## 2 | Struktur

### 2.1 | TRY…CATCH – Grundlagen & Ablauf
> **Kurzbeschreibung:** Steuerfluss, was fangbar ist, typische Minimalmuster.

- 📓 **Notebook:**  
  [`08_01_try_catch_grundlagen.ipynb`](08_01_try_catch_grundlagen.ipynb)
- 🎥 **YouTube:**  
  - [TRY…CATCH Basics](https://www.youtube.com/results?search_query=sql+server+try+catch+tutorial)
- 📘 **Docs:**  
  - [`TRY…CATCH` (T-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/try-catch-transact-sql)

---

### 2.2 | `THROW` vs. `RAISERROR`
> **Kurzbeschreibung:** Unterschiede, wann `THROW` (modern) vs. `RAISERROR` (Optionen/Format) sinnvoll ist.

- 📓 **Notebook:**  
  [`08_02_throw_vs_raiserror.ipynb`](08_02_throw_vs_raiserror.ipynb)
- 🎥 **YouTube:**  
  - [THROW vs RAISERROR](https://www.youtube.com/results?search_query=sql+server+throw+vs+raiserror)
- 📘 **Docs:**  
  - [`THROW`](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/throw-transact-sql) · [`RAISERROR`](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/raiserror-transact-sql)

---

### 2.3 | Fehlerdetails im `CATCH`: `ERROR_*()` richtig nutzen
> **Kurzbeschreibung:** Alle Metadaten erfassen, rethrow preserving, strukturierte Ausgabe.

- 📓 **Notebook:**  
  [`08_03_error_functions_patterns.ipynb`](08_03_error_functions_patterns.ipynb)
- 🎥 **YouTube:**  
  - [ERROR_MESSAGE() & Co.](https://www.youtube.com/results?search_query=sql+server+error_message+error_number)
- 📘 **Docs:**  
  - [`ERROR_*`-Funktionen](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/error-functions-transact-sql)

---

### 2.4 | Transaktionssicher: `XACT_STATE()`, `@@TRANCOUNT`, `XACT_ABORT`
> **Kurzbeschreibung:** Commit/Rollback korrekt entscheiden, Auto-Rollback verstehen.

- 📓 **Notebook:**  
  [`08_04_xact_state_xact_abort_patterns.ipynb`](08_04_xact_state_xact_abort_patterns.ipynb)
- 🎥 **YouTube:**  
  - [XACT_STATE & XACT_ABORT](https://www.youtube.com/results?search_query=sql+server+xact_state+xact_abort)
- 📘 **Docs:**  
  - [`XACT_STATE()`](https://learn.microsoft.com/en-us/sql/t-sql/functions/xact-state-transact-sql) · [`SET XACT_ABORT`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-xact-abort-transact-sql)

---

### 2.5 | Zentrales Fehler-Logging (Tabelle & Eventlog)
> **Kurzbeschreibung:** Logtabelle designen, Kontext anreichern, optional `RAISERROR … WITH LOG`.

- 📓 **Notebook:**  
  [`08_05_error_logging_design.ipynb`](08_05_error_logging_design.ipynb)
- 🎥 **YouTube:**  
  - [Build an Error Log Table](https://www.youtube.com/results?search_query=sql+server+error+logging+table)
- 📘 **Docs:**  
  - [`RAISERROR` – Optionen (`LOG`,`NOWAIT`)](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/raiserror-transact-sql)  
  - [`sp_set_session_context` / `SESSION_CONTEXT`](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-set-session-context-transact-sql)

---

### 2.6 | Benutzerdefinierte Meldungen: `sp_addmessage` & Formatstrings
> **Kurzbeschreibung:** Lokalisierbare Texte, Platzhalter `%d/%s`, Versionsverwaltung.

- 📓 **Notebook:**  
  [`08_06_sp_addmessage_format.ipynb`](08_06_sp_addmessage_format.ipynb)
- 🎥 **YouTube:**  
  - [sp_addmessage Demo](https://www.youtube.com/results?search_query=sql+server+sp_addmessage)
- 📘 **Docs:**  
  - [`sp_addmessage` / `sys.messages`](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-addmessage-transact-sql)

---

### 2.7 | Savepoints & verschachtelte Transaktionen
> **Kurzbeschreibung:** Teil-Rollbacks mit `SAVE TRAN`, Outer-Transaction respektieren.

- 📓 **Notebook:**  
  [`08_07_savepoints_nested_txn.ipynb`](08_07_savepoints_nested_txn.ipynb)
- 🎥 **YouTube:**  
  - [SAVE TRAN Patterns](https://www.youtube.com/results?search_query=sql+server+savepoint+transaction)
- 📘 **Docs:**  
  - [`SAVE TRANSACTION`](https://learn.microsoft.com/en-us/sql/t-sql/statements/save-transaction-transact-sql)

---

### 2.8 | Deadlocks (1205) – erkennen & Retry-Pattern
> **Kurzbeschreibung:** Fehlerbild, Exponential-Backoff, Idempotenz.

- 📓 **Notebook:**  
  [`08_08_deadlock_retry_pattern.ipynb`](08_08_deadlock_retry_pattern.ipynb)
- 🎥 **YouTube:**  
  - [Handle Deadlocks in T-SQL](https://www.youtube.com/results?search_query=sql+server+deadlock+retry)
- 📘 **Docs:**  
  - [Deadlocks – Monitoring & Troubleshooting](https://learn.microsoft.com/en-us/sql/relational-databases/performance/monitor-deadlocks)

---

### 2.9 | Timeouts, Kompilierfehler & Uncatchables
> **Kurzbeschreibung:** Client-Timeouts/Attention und Compile-Time-Errors – Grenzen von TRY…CATCH.

- 📓 **Notebook:**  
  [`08_09_uncatchable_errors.ipynb`](08_09_uncatchable_errors.ipynb)
- 🎥 **YouTube:**  
  - [Why some errors aren’t caught](https://www.youtube.com/results?search_query=sql+server+try+catch+compile+error)
- 📘 **Docs:**  
  - [`TRY…CATCH` – Hinweise/Einschränkungen](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/try-catch-transact-sql#remarks)

---

### 2.10 | API-Pattern: Fehlervertrag, Codes & sauberes Rethrow
> **Kurzbeschreibung:** Einheitliche Rückgabecodes, Maskierung interner Details, Konsumentenfreundlichkeit.

- 📓 **Notebook:**  
  [`08_10_api_error_contracts.ipynb`](08_10_api_error_contracts.ipynb)
- 🎥 **YouTube:**  
  - [Designing Error Contracts](https://www.youtube.com/results?search_query=sql+server+error+handling+best+practices)
- 📘 **Docs:**  
  - [`THROW` – Rethrow im CATCH](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/throw-transact-sql#rethrowing-a-caught-exception)

---

### 2.11 | Dynamisches SQL in TRY…CATCH
> **Kurzbeschreibung:** `sp_executesql` im TRY, Fehler im CATCH behandeln/weiterreichen.

- 📓 **Notebook:**  
  [`08_11_try_catch_dynamic_sql.ipynb`](08_11_try_catch_dynamic_sql.ipynb)
- 🎥 **YouTube:**  
  - [TRY/CATCH with sp_executesql](https://www.youtube.com/results?search_query=sql+server+try+catch+sp_executesql)
- 📘 **Docs:**  
  - [`sp_executesql`](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-executesql-transact-sql)

---

### 2.12 | Logging-Kontext: `SESSION_CONTEXT`, `CONTEXT_INFO`, Korrelation
> **Kurzbeschreibung:** Correlation-IDs propagieren & im Fehlerlog speichern.

- 📓 **Notebook:**  
  [`08_12_session_context_logging.ipynb`](08_12_session_context_logging.ipynb)
- 🎥 **YouTube:**  
  - [SESSION_CONTEXT Use Cases](https://www.youtube.com/results?search_query=sql+server+session_context)
- 📘 **Docs:**  
  - [`sp_set_session_context` / `SESSION_CONTEXT`](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-set-session-context-transact-sql)

---

### 2.13 | Auditing & Eventlog
> **Kurzbeschreibung:** `RAISERROR … WITH LOG`, Extended Events, minimal-invasive Audits.

- 📓 **Notebook:**  
  [`08_13_eventlog_xevents.ipynb`](08_13_eventlog_xevents.ipynb)
- 🎥 **YouTube:**  
  - [Extended Events for Errors](https://www.youtube.com/results?search_query=sql+server+extended+events+errors)
- 📘 **Docs:**  
  - [Extended Events – Überblick](https://learn.microsoft.com/en-us/sql/relational-databases/extended-events/extended-events)

---

### 2.14 | Testen: Fehler gezielt auslösen & abprüfen
> **Kurzbeschreibung:** Unit-Tests, `THROW 50000,'Test',1;`, Verifikation von Logeinträgen.

- 📓 **Notebook:**  
  [`08_14_testing_errorhandling.ipynb`](08_14_testing_errorhandling.ipynb)
- 🎥 **YouTube:**  
  - [Testable Error Handling](https://www.youtube.com/results?search_query=tsql+unit+testing+error+handling)
- 📘 **Docs:**  
  - [`THROW` – Syntax/Beispiele](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/throw-transact-sql)

---

### 2.15 | Prozedur-Template: Robust mit Transaktionen & Logging
> **Kurzbeschreibung:** Fertiges Muster inkl. `XACT_ABORT`, `TRY…CATCH`, Logging & `THROW`.

- 📓 **Notebook:**  
  [`08_15_sp_template_errorhandling.ipynb`](08_15_sp_template_errorhandling.ipynb)
- 🎥 **YouTube:**  
  - [Stored Proc Error Template](https://www.youtube.com/results?search_query=sql+server+stored+procedure+error+handling+template)
- 📘 **Docs:**  
  - [`XACT_STATE()` / `@@TRANCOUNT`](https://learn.microsoft.com/en-us/sql/t-sql/functions/xact-state-transact-sql)

---

### 2.16 | Anti-Patterns & Checkliste
> **Kurzbeschreibung:** Fehler unterdrücken, „Commit trotz Fehler“, fehlendes Rethrow/Logging, Severity-Missbrauch, `@@ERROR`-Legacy.

- 📓 **Notebook:**  
  [`08_16_errorhandling_anti_patterns.ipynb`](08_16_errorhandling_anti_patterns.ipynb)
- 🎥 **YouTube:**  
  - [Common Error Handling Mistakes](https://www.youtube.com/results?search_query=sql+server+error+handling+mistakes)
- 📘 **Docs/Blog:**  
  - [`TRY…CATCH` Hinweise](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/try-catch-transact-sql#remarks)

---

## 3 | Weiterführende Informationen

- 📘 Microsoft Learn: [`TRY…CATCH` (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/try-catch-transact-sql)  
- 📘 Microsoft Learn: [`THROW` – moderne Fehlerauslösung](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/throw-transact-sql)  
- 📘 Microsoft Learn: [`RAISERROR` – Optionen & Severity](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/raiserror-transact-sql)  
- 📘 Microsoft Learn: [`ERROR_*()` – Fehlerfunktionen](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/error-functions-transact-sql)  
- 📘 Microsoft Learn: [`XACT_STATE()` / `@@TRANCOUNT`](https://learn.microsoft.com/en-us/sql/t-sql/functions/xact-state-transact-sql) · [`SET XACT_ABORT`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-xact-abort-transact-sql)  
- 📘 Microsoft Learn: [`sp_addmessage` / `sys.messages`](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-addmessage-transact-sql)  
- 📘 Microsoft Learn: [`sp_set_session_context` & `SESSION_CONTEXT`](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-set-session-context-transact-sql)  
- 📘 Microsoft Learn: [Deadlocks – Überblick & Analyse](https://learn.microsoft.com/en-us/sql/relational-databases/performance/monitor-deadlocks)  
- 📘 Microsoft Learn: [Extended Events für Fehlerszenarien](https://learn.microsoft.com/en-us/sql/relational-databases/extended-events/extended-events)  
- 📝 SQLSkills (Paul Randal): *XACT_ABORT & Fehlerverhalten* – https://www.sqlskills.com/  
- 📝 Erland Sommarskog: *Error and Transaction Handling in T-SQL* – https://www.sommarskog.se/  
- 📝 SQLPerformance: *Error Handling Patterns* – https://www.sqlperformance.com/?s=error+handling  
- 📝 Brent Ozar: *Deadlocks & Retry* – https://www.brentozar.com/  
- 📝 Erik Darling: *THROW vs RAISERROR – Praxis* – https://www.erikdarlingdata.com/  
- 🎥 YouTube Playlist: *T-SQL Error Handling* (Suche)  
