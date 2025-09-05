# T-SQL MERGE – Übersicht

## 1 | Begriffsdefinition

| SQL-Term | Beschreibung |
|---|---|
| `MERGE` | Kombiniert **INSERT**, **UPDATE** und **DELETE** in **einem** Statement, basierend auf einem Join zwischen **Zieltabelle** und **Quelle**. |
| Zieltabelle (`TARGET`) | Tabelle/View, auf der die Änderungen ausgeführt werden. |
| Quelle (`SOURCE`) | Tabelle/CTE/abgeleitete Tabelle, die Schlüssel/Werte zur Bestimmung der Aktion liefert. |
| `ON`-Bedingung | Join-/Abgleichslogik zwischen Target und Source; muss so formuliert sein, dass **max. ein** Source-Treffer je Target-Zeile entsteht. |
| `WHEN MATCHED THEN` | Aktion, wenn eine Übereinstimmung besteht: `UPDATE` **oder** `DELETE`. Mehrere `WHEN MATCHED` sind nur mit **zusätzlichen Prädikaten** erlaubt. |
| `WHEN NOT MATCHED [BY TARGET] THEN` | Aktion, wenn Source-Zeile **keinen** Treffer im Target hat: meist `INSERT`. |
| `WHEN NOT MATCHED BY SOURCE THEN` | Aktion, wenn Target-Zeile **keinen** Treffer in der Source hat: `UPDATE` **oder** `DELETE` (Synchronisationsszenario). |
| `OUTPUT $action` | Gibt pro betroffener Zeile die ausgeführte Aktion (`INSERT`, `UPDATE`, `DELETE`) zurück; Zugriff auf `inserted`/`deleted`. |
| `TOP (N)` in `MERGE` | Optional; begrenzt die Anzahl betroffener Zeilen (Reihenfolge ohne zusätzliche Technik nicht determiniert). |
| Eindeutigkeit der Quelle | Mehrfache Source-Treffer für dieselbe Target-Zeile führen zu **Fehler** (“row was updated/deleted multiple times”). Source **deduplizieren**! |
| Isolation & Sperren | Für rennbedingungssichere Upserts oft `SERIALIZABLE` oder `HOLDLOCK` auf Target nötig. |
| Trigger/Constraints | Lösen wie bei getrennten DML aus; `inserted`/`deleted` enthalten die Delta-Zeilen. |
| Nebenwirkungen | Temporal/CDC/CT/Replikation erfassen Änderungen; Plan-/Logging-Kosten können höher sein als bei 2-Phasen-Upsert. |
| Praxis-Hinweis | `MERGE` ist mächtig, hat aber bekannte Fallstricke. Viele Teams bevorzugen robustes **2-Phasen-Upsert** (UPDATE→INSERT) für OLTP. |

---

## 2 | Struktur

### 2.1 | MERGE – Grundlagen & Syntax
> **Kurzbeschreibung:** Aufbau eines minimalen `MERGE`, Schlüsselkonzept `TARGET`/`SOURCE`, `WHEN`-Zweige.

- 📓 **Notebook:**  
  [`08_01_merge_grundlagen.ipynb`](08_01_merge_grundlagen.ipynb)

- 🎥 **YouTube:**  
  - [SQL Server MERGE – Basics](https://www.youtube.com/results?search_query=sql+server+merge+statement+tutorial)

- 📘 **Docs:**  
  - [`MERGE` (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/statements/merge-transact-sql)

---

### 2.2 | Quelle formen: CTE & abgeleitete Tabellen
> **Kurzbeschreibung:** `SOURCE` per `WITH`-CTE/abgeleiteter Tabelle aufbereiten, Spalten ausrichten und casten.

- 📓 **Notebook:**  
  [`08_02_merge_source_shaping_cte.ipynb`](08_02_merge_source_shaping_cte.ipynb)

- 🎥 **YouTube:**  
  - [CTE + MERGE – Beispiel](https://www.youtube.com/results?search_query=sql+server+merge+cte)

- 📘 **Docs:**  
  - [CTE (`WITH`)](https://learn.microsoft.com/en-us/sql/t-sql/queries/with-common-table-expression-transact-sql)

---

### 2.3 | Upsert mit `WHEN MATCHED` & `WHEN NOT MATCHED BY TARGET`
> **Kurzbeschreibung:** Klassisches Upsert: vorhandene Zeilen `UPDATE`, neue Zeilen `INSERT`.

- 📓 **Notebook:**  
  [`08_03_merge_upsert_pattern.ipynb`](08_03_merge_upsert_pattern.ipynb)

- 🎥 **YouTube:**  
  - [MERGE for Upsert](https://www.youtube.com/results?search_query=sql+server+merge+upsert)

- 📘 **Docs:**  
  - [`MERGE` – Beispiele (Upsert)](https://learn.microsoft.com/en-us/sql/t-sql/statements/merge-transact-sql#examples)

---

### 2.4 | Synchronisieren mit `WHEN NOT MATCHED BY SOURCE`
> **Kurzbeschreibung:** Ziel auf Stand der Quelle bringen – fehlende Source-Zeilen im Target `DELETE` oder `UPDATE`n.

- 📓 **Notebook:**  
  [`08_04_merge_sync_not_matched_by_source.ipynb`](08_04_merge_sync_not_matched_by_source.ipynb)

- 🎥 **YouTube:**  
  - [MERGE Synchronization](https://www.youtube.com/results?search_query=sql+server+merge+not+matched+by+source)

- 📘 **Docs:**  
  - [`MERGE` – `NOT MATCHED BY SOURCE`](https://learn.microsoft.com/en-us/sql/t-sql/statements/merge-transact-sql#arguments)

---

### 2.5 | Zusätzliche Prädikate & mehrere `WHEN MATCHED`
> **Kurzbeschreibung:** Bedingte Aktionen (z. B. nur bestimmte Spalten ändern); Regeln, wann mehrere `WHEN MATCHED` zulässig sind.

- 📓 **Notebook:**  
  [`08_05_merge_conditionals.ipynb`](08_05_merge_conditionals.ipynb)

- 🎥 **YouTube:**  
  - [Conditional MERGE](https://www.youtube.com/results?search_query=sql+server+merge+when+matched+and)

- 📘 **Docs:**  
  - [`MERGE` – Suchbedingungen & Einschränkungen](https://learn.microsoft.com/en-us/sql/t-sql/statements/merge-transact-sql#limitations-and-restrictions)

---

### 2.6 | `OUTPUT $action` – Delta/Audit erfassen
> **Kurzbeschreibung:** Aktionstyp und alte/neue Werte mitschreiben; Audit/Staging per `OUTPUT INTO`.

- 📓 **Notebook:**  
  [`08_06_merge_output_audit.ipynb`](08_06_merge_output_audit.ipynb)

- 🎥 **YouTube:**  
  - [MERGE with OUTPUT](https://www.youtube.com/results?search_query=sql+server+merge+output+action)

- 📘 **Docs:**  
  - [`OUTPUT`-Klausel](https://learn.microsoft.com/en-us/sql/t-sql/queries/output-clause-transact-sql)

---

### 2.7 | Duplikate in der Quelle vermeiden
> **Kurzbeschreibung:** Warum Mehrfachtreffer Fehler erzeugen; Deduplikation mit `GROUP BY`, `ROW_NUMBER()` oder eindeutigen Indizes.

- 📓 **Notebook:**  
  [`08_07_merge_source_dedup_row_number.ipynb`](08_07_merge_source_dedup_row_number.ipynb)

- 🎥 **YouTube:**  
  - [ROW_NUMBER() zum Deduplizieren](https://www.youtube.com/results?search_query=sql+server+row_number+dedupe)

- 📘 **Docs:**  
  - [`ROW_NUMBER`](https://learn.microsoft.com/en-us/sql/t-sql/functions/row_number-transact-sql)

---

### 2.8 | Nebenläufigkeit: `SERIALIZABLE` & `HOLDLOCK`
> **Kurzbeschreibung:** Rennbedingungen beim Upsert verhindern; Target mit `WITH (HOLDLOCK)` oder Session-Isolation `SERIALIZABLE`.

- 📓 **Notebook:**  
  [`08_08_merge_concurrency_isolation.ipynb`](08_08_merge_concurrency_isolation.ipynb)

- 🎥 **YouTube:**  
  - [MERGE Concurrency Issues](https://www.youtube.com/results?search_query=sql+server+merge+concurrency+holdlock)

- 📘 **Docs:**  
  - [`SET TRANSACTION ISOLATION LEVEL`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-transaction-isolation-level-transact-sql)  
  - [Table Hints (`HOLDLOCK`, `UPDLOCK`, …)](https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-table)

---

### 2.9 | Fehlerbehandlung & Transaktionen
> **Kurzbeschreibung:** `TRY…CATCH`, `THROW`, `XACT_STATE()`, `XACT_ABORT ON` – Mehrfachfehler korrekt behandeln.

- 📓 **Notebook:**  
  [`08_09_merge_try_catch_xactabort.ipynb`](08_09_merge_try_catch_xactabort.ipynb)

- 🎥 **YouTube:**  
  - [TRY…CATCH & THROW – DML](https://www.youtube.com/results?search_query=sql+server+try+catch+throw)

- 📘 **Docs:**  
  - [`TRY…CATCH`](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/try-catch-transact-sql)  
  - [`SET XACT_ABORT`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-xact-abort-transact-sql)

---

### 2.10 | Performance & Pläne
> **Kurzbeschreibung:** Planformen (Hash/Merge/Loop Join), Memory Grants, Statistiken; wann `MERGE` teurer ist als 2-Phasen-Upsert.

- 📓 **Notebook:**  
  [`08_10_merge_performance_plans.ipynb`](08_10_merge_performance_plans.ipynb)

- 🎥 **YouTube:**  
  - [MERGE Execution Plans](https://www.youtube.com/results?search_query=sql+server+merge+execution+plan)

- 📘 **Docs:**  
  - [Query Processing Architecture](https://learn.microsoft.com/en-us/sql/relational-databases/query-processing-architecture-guide)  
  - [Cardinality Estimation – Overview](https://learn.microsoft.com/en-us/sql/relational-databases/performance/cardinality-estimation-overview)

---

### 2.11 | Identitäten & Sequenzen im MERGE
> **Kurzbeschreibung:** Neue Schlüssel sicher ermitteln (`OUTPUT inserted.Id`), `SEQUENCE`/`DEFAULT` nutzen.

- 📓 **Notebook:**  
  [`08_11_merge_identity_sequence.ipynb`](08_11_merge_identity_sequence.ipynb)

- 🎥 **YouTube:**  
  - [MERGE with Identity/Sequence](https://www.youtube.com/results?search_query=sql+server+merge+identity+sequence)

- 📘 **Docs:**  
  - [`CREATE SEQUENCE` / `NEXT VALUE FOR`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-sequence-transact-sql)  
  - [`DEFAULT`-Constraints](https://learn.microsoft.com/en-us/sql/relational-databases/tables/create-default-constraints)

---

### 2.12 | `TOP (N)` & geordnete Teilmengen
> **Kurzbeschreibung:** Portioniertes MERGE über eine **geordnete** Source-Teilmenge (z. B. per CTE + `ROW_NUMBER()`).

- 📓 **Notebook:**  
  [`08_12_merge_top_ordered_batches.ipynb`](08_12_merge_top_ordered_batches.ipynb)

- 🎥 **YouTube:**  
  - [Batching with MERGE](https://www.youtube.com/results?search_query=sql+server+merge+top+batch)

- 📘 **Docs:**  
  - [`TOP` in DML](https://learn.microsoft.com/en-us/sql/t-sql/queries/top-transact-sql)

---

### 2.13 | MERGE vs. 2-Phasen-Upsert (UPDATE→INSERT)
> **Kurzbeschreibung:** Vergleich in Bezug auf Robustheit, Lesbarkeit, Sperrverhalten und Fehlermeldungen.

- 📓 **Notebook:**  
  [`08_13_merge_vs_two_phase_upsert.ipynb`](08_13_merge_vs_two_phase_upsert.ipynb)

- 🎥 **YouTube:**  
  - [Upsert without MERGE](https://www.youtube.com/results?search_query=sql+server+upsert+without+merge)

- 📘 **Docs/Blog:**  
  - [`MERGE` – Referenz](https://learn.microsoft.com/en-us/sql/t-sql/statements/merge-transact-sql)  
  - *Best-Practice-Artikel zu Upserts* (siehe Weiterführende Infos)

---

### 2.14 | Trigger, Constraints & Validierung
> **Kurzbeschreibung:** Wie `AFTER/INSTEAD OF`-Trigger reagieren; CHECK/UNIQUE/FK-Fehler sauber behandeln.

- 📓 **Notebook:**  
  [`08_14_merge_trigger_constraints.ipynb`](08_14_merge_trigger_constraints.ipynb)

- 🎥 **YouTube:**  
  - [MERGE and Triggers](https://www.youtube.com/results?search_query=sql+server+merge+triggers)

- 📘 **Docs:**  
  - [CREATE TRIGGER](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-trigger-transact-sql)  
  - [FOREIGN KEY / CHECK / UNIQUE](https://learn.microsoft.com/en-us/sql/relational-databases/tables/tables)

---

### 2.15 | Temporal / CDC / Change Tracking
> **Kurzbeschreibung:** Was `MERGE` in Historien-/CT-Tabellen bewirkt; saubere Erfassung mit `OUTPUT`.

- 📓 **Notebook:**  
  [`08_15_merge_temporal_cdc_ct.ipynb`](08_15_merge_temporal_cdc_ct.ipynb)

- 🎥 **YouTube:**  
  - [MERGE with Temporal/CDC](https://www.youtube.com/results?search_query=sql+server+merge+temporal+cdc)

- 📘 **Docs:**  
  - [Temporal Tables – DML-Verhalten](https://learn.microsoft.com/en-us/sql/relational-databases/tables/temporal-table-considerations)  
  - [CDC / Change Tracking](https://learn.microsoft.com/en-us/sql/relational-databases/track-changes/track-data-changes-sql-server)

---

### 2.16 | Anti-Patterns & bekannte Fallstricke
> **Kurzbeschreibung:** Mehrfachtreffer in Source, fehlende Isolation, zu breite `ON`-Bedingungen, bedingungslose `NOT MATCHED BY SOURCE DELETE`, blinde Nutzung in OLTP.

- 📓 **Notebook:**  
  [`08_16_merge_anti_patterns.ipynb`](08_16_merge_anti_patterns.ipynb)

- 🎥 **YouTube:**  
  - [MERGE Problems & Alternatives](https://www.youtube.com/results?search_query=sql+server+merge+problems)

- 📘 **Docs/Blog:**  
  - [`MERGE` – Einschränkungen](https://learn.microsoft.com/en-us/sql/t-sql/statements/merge-transact-sql#limitations-and-restrictions)  
  - *Siehe Blogs unten (Bertrand, Hutmacher, u. a.)*

---

## 3 | Weiterführende Informationen

- 📘 Microsoft Learn: [`MERGE` (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/statements/merge-transact-sql)  
- 📘 Microsoft Learn: [`OUTPUT`-Klausel](https://learn.microsoft.com/en-us/sql/t-sql/queries/output-clause-transact-sql)  
- 📘 Microsoft Learn: [Table Hints (`HOLDLOCK`, `UPDLOCK`, …)](https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-table)  
- 📘 Microsoft Learn: [`SET TRANSACTION ISOLATION LEVEL`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-transaction-isolation-level-transact-sql)  
- 📘 Microsoft Learn: [Temporal Tables – DML-Hinweise](https://learn.microsoft.com/en-us/sql/relational-databases/tables/temporal-table-considerations)  
- 📝 Aaron Bertrand: [**MERGE** – What was I thinking?](https://sqlblog.org/2011/06/20/merge-what-was-i-thinking)  
- 📝 Daniel Hutmacher (SQL Server Fast): [The problems with `MERGE`](https://sqlserverfast.com/blog/hugo/2019/06/merge/) *(Serie)*  
- 📝 Itzik Ben-Gan: *Upsert Patterns & Alternatives* (Windowing/Apply) – Sammlung auf [tsql.solidq.com](https://tsql.solidq.com/)  
- 📝 SQLPerformance: *MERGE vs. separate DML* – Plan/Perf-Analysen (Suche: “merge performance”) – [sqlperformance.com](https://www.sqlperformance.com/?s=merge)  
- 📝 Kendra Little: *Why I avoid MERGE in OLTP* – Praxisnotizen (Video/Blog) – [kendralittle.com](https://kendralittle.com)  
- 📝 Erik Darling: *Upserts ohne MERGE & RBAR-Fallstricke* – [erikdarlingdata.com](https://www.erikdarlingdata.com/)  
- 🎥 YouTube: [MERGE Statement Tutorial](https://www.youtube.com/results?search_query=sql+server+merge+statement+tutorial)  
- 🎥 YouTube: [Upsert without MERGE (UPDATE+INSERT)](https://www.youtube.com/results?search_query=sql+server+upsert+without+merge)  
- 🎥 YouTube (Data Exposed): *Isolation & Concurrency* – hilfreich für MERGE-Szenarien – (Suche)  


