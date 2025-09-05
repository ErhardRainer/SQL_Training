# T-SQL Row-Level Security (RLS) – Übersicht  
*Zeilenbasierte Sicherheit in SQL Server: Policies, Predicates, Performance*

## 1 | Begriffsdefinition

| SQL-Term | Beschreibung |
|---|---|
| Row-Level Security (RLS) | Engine-Feature, das auf **Zeilenebene** Zugriff einschränkt. SQL Server injiziert zur Laufzeit Prädikate in Abfragen. |
| Security Policy | Container für eine oder mehrere **Predicates** (Filter/Block), die auf Tabellen gebunden werden: `CREATE/ALTER/DROP SECURITY POLICY`. |
| Filter Predicate | **Lese-/Schreibfilter**: blendet nicht erlaubte Zeilen aus (`SELECT/UPDATE/DELETE`). Wird per **inline TVF** (schemagebunden) hinterlegt. |
| Block Predicate | **Schreibschutz**: verhindert `INSERT/UPDATE/DELETE`, die Policy umgehen würden (z. B. „hinüberwechseln“ zu fremdem Tenant). Varianten: `AFTER INSERT`, `BEFORE UPDATE`, `BEFORE DELETE`, `BEFORE UPDATE` (Spaltenliste optional). |
| Predicate Function | **Inline table-valued function** (iTVF) mit `WITH SCHEMABINDING`, die `1` Zeile zurückgibt, wenn Zugriff erlaubt. Parameter sind typischerweise **Spalten der Zieltabelle**. |
| Kontextquelle | Identität/Scope im Prädikat: `SESSION_CONTEXT('key')`, `SUSER_SNAME()`, `ORIGINAL_LOGIN()`, `IS_MEMBER('role')` etc. |
| Bypass-Pattern | Im Prädikat ein **Admin-Rollen-Check** (`IS_MEMBER('rls_bypass')=1`) zulassen; ansonsten sind auch `db_owner`-Abfragen **nicht** automatisch ausgenommen. |
| Testen | Mit `EXECUTE AS USER = '...'` testen; `REVERT` zurück. |
| SARGability | Predicate sollte **sargierbar** sein (Vergleich über Spalten → Literal/Sessionwert). Zielspalten **indizieren**. |
| Metadata | `sys.security_policies`, `sys.security_predicates` – zeigt Status, Zielobjekte, Predicate-Typen. |
| Reihenfolge/Scope | RLS wirkt **auf Tabellenebene** – auch durch Views/Procs hindurch (Ownership Chaining ändert das nicht). |
| Performancehinweis | Prädikat einfach halten (iTVF, deterministisch), Zielspalten indizieren, teure Lookups vermeiden. |

---

## 2 | Struktur

### 2.1 | Grundlagen & Architektur: Policy, Filter, Block
> **Kurzbeschreibung:** Wie RLS in den Plan integriert wird; Unterschiede Filter vs. Block Predicate; typische Bausteine.

- 📓 **Notebook:**  
  [`08_01_rls_grundlagen_architektur.ipynb`](08_01_rls_grundlagen_architektur.ipynb)
- 🎥 **YouTube:**  
  - [Row-Level Security – Überblick & Demo](https://www.youtube.com/results?search_query=sql+server+row+level+security+overview)
- 📘 **Docs:**  
  - [Row-Level Security – Übersicht](https://learn.microsoft.com/en-us/sql/relational-databases/security/row-level-security)  
  - [`CREATE SECURITY POLICY`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-security-policy-transact-sql)

---

### 2.2 | Predicate Function (iTVF) korrekt bauen
> **Kurzbeschreibung:** Inline-TVF mit `SCHEMABINDING`, Parameter = Zielspalten; Nutzung von `SESSION_CONTEXT`/Login-Infos.

- 📓 **Notebook:**  
  [`08_02_predicate_function_itvf.ipynb`](08_02_predicate_function_itvf.ipynb)
- 🎥 **YouTube:**  
  - [RLS Predicate Functions – How to](https://www.youtube.com/results?search_query=sql+server+rls+predicate+function)
- 📘 **Docs:**  
  - [`SESSION_CONTEXT` / `sp_set_session_context`](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-set-session-context-transact-sql)  
  - [Inline TVFs & `SCHEMABINDING`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-function-transact-sql)

---

### 2.3 | Filter Predicate – Lesen & Schreiben absichern
> **Kurzbeschreibung:** Sichtbare Zeilen einschränken; warum Filter allein `INSERT`/`UPDATE`-Umgehungen nicht verhindern.

- 📓 **Notebook:**  
  [`08_03_filter_predicate_patterns.ipynb`](08_03_filter_predicate_patterns.ipynb)
- 🎥 **YouTube:**  
  - [Filter Predicate in Action](https://www.youtube.com/results?search_query=sql+server+rls+filter+predicate)
- 📘 **Docs:**  
  - [`CREATE SECURITY POLICY` – `ADD FILTER PREDICATE`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-security-policy-transact-sql#add-filter-predicate)

---

### 2.4 | Block Predicate – Schreibzugriffe verhindern
> **Kurzbeschreibung:** `AFTER INSERT`, `BEFORE UPDATE/DELETE` einsetzen, um Cross-Tenant-Umgehungen zu unterbinden.

- 📓 **Notebook:**  
  [`08_04_block_predicate_patterns.ipynb`](08_04_block_predicate_patterns.ipynb)
- 🎥 **YouTube:**  
  - [Block Predicate – Demos](https://www.youtube.com/results?search_query=sql+server+rls+block+predicate)
- 📘 **Docs:**  
  - [`ADD BLOCK PREDICATE` – Varianten](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-security-policy-transact-sql#add-block-predicate)

---

### 2.5 | Multi-Tenant mit `SESSION_CONTEXT`
> **Kurzbeschreibung:** Tenant-ID im Sessionkontext setzen und im Prädikat matchen; sicher setzen in der App/Proc.

- 📓 **Notebook:**  
  [`08_05_multitenant_session_context.ipynb`](08_05_multitenant_session_context.ipynb)
- 🎥 **YouTube:**  
  - [RLS + SESSION_CONTEXT Pattern](https://www.youtube.com/results?search_query=sql+server+session_context+row+level+security)
- 📘 **Docs:**  
  - [`sp_set_session_context`](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-set-session-context-transact-sql)

---

### 2.6 | Admin-Bypass & Testen (`IS_MEMBER`, `EXECUTE AS`)
> **Kurzbeschreibung:** Sicheren Bypass per Rolle ins Prädikat integrieren; Tests mit `EXECUTE AS USER`/`REVERT`.

- 📓 **Notebook:**  
  [`08_06_bypass_and_testing.ipynb`](08_06_bypass_and_testing.ipynb)
- 🎥 **YouTube:**  
  - [Testing RLS with EXECUTE AS](https://www.youtube.com/results?search_query=sql+server+execute+as+row+level+security)
- 📘 **Docs:**  
  - [`EXECUTE AS` / `REVERT`](https://learn.microsoft.com/en-us/sql/t-sql/statements/execute-as-clause-transact-sql)  
  - [`IS_MEMBER`](https://learn.microsoft.com/en-us/sql/t-sql/functions/is-member-transact-sql)

---

### 2.7 | Performance & SARGability
> **Kurzbeschreibung:** Zielspalten indizieren, iTVF minimal halten, Vergleiche spaltenbasiert formulieren; Pläne prüfen.

- 📓 **Notebook:**  
  [`08_07_rls_performance_sargability.ipynb`](08_07_rls_performance_sargability.ipynb)
- 🎥 **YouTube:**  
  - [RLS Performance Tips](https://www.youtube.com/results?search_query=sql+server+row+level+security+performance)
- 📘 **Docs:**  
  - [RLS – Performancehinweise](https://learn.microsoft.com/en-us/sql/relational-databases/security/row-level-security#performance-considerations)

---

### 2.8 | Hierarchien & Mappingtabellen
> **Kurzbeschreibung:** Zugriff über Regionen/Teams: Prädikat gegen Mapping-/Hierarchy-Tabellen (schemagebunden) formulieren.

- 📓 **Notebook:**  
  [`08_08_hierarchies_mapping_predicates.ipynb`](08_08_hierarchies_mapping_predicates.ipynb)
- 🎥 **YouTube:**  
  - [RLS Hierarchical Access](https://www.youtube.com/results?search_query=sql+server+row+level+security+hierarchy)
- 📘 **Docs:**  
  - [RLS Beispiele – Organisationshierarchie](https://learn.microsoft.com/en-us/sql/relational-databases/security/row-level-security#examples)

---

### 2.9 | RLS mit Views/Stored Procedures/Dynamic SQL
> **Kurzbeschreibung:** RLS greift **auch** hinter Views/Procs; Kontext von `EXECUTE AS`/dyn. SQL beachten.

- 📓 **Notebook:**  
  [`08_09_rls_views_procs_dynamic_sql.ipynb`](08_09_rls_views_procs_dynamic_sql.ipynb)
- 🎥 **YouTube:**  
  - [RLS with Stored Procedures](https://www.youtube.com/results?search_query=sql+server+row+level+security+stored+procedure)
- 📘 **Docs:**  
  - [RLS – Interaktion mit Modulen](https://learn.microsoft.com/en-us/sql/relational-databases/security/row-level-security#security)

---

### 2.10 | ALTER/ROLLBACK: Policies sicher ein-/ausschalten
> **Kurzbeschreibung:** Deployment-Muster: Policy zuerst `STATE = OFF`, testen, dann `STATE = ON`; `ALTER SECURITY POLICY`.

- 📓 **Notebook:**  
  [`08_10_policy_state_on_off_deploy.ipynb`](08_10_policy_state_on_off_deploy.ipynb)
- 🎥 **YouTube:**  
  - [Deploying RLS Safely](https://www.youtube.com/results?search_query=sql+server+deploy+row+level+security)
- 📘 **Docs:**  
  - [`ALTER SECURITY POLICY`](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-security-policy-transact-sql)

---

### 2.11 | Metadaten & Monitoring
> **Kurzbeschreibung:** Policies/Predicates inventarisieren; Extended Events/Plans für Diagnose nutzen.

- 📓 **Notebook:**  
  [`08_11_metadata_sys_security_predicates.ipynb`](08_11_metadata_sys_security_predicates.ipynb)
- 🎥 **YouTube:**  
  - [Find RLS Policies in a DB](https://www.youtube.com/results?search_query=sql+server+find+row+level+security+policies)
- 📘 **Docs:**  
  - [`sys.security_policies`](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-security-policies-transact-sql)  
  - [`sys.security_predicates`](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-security-predicates-transact-sql)

---

### 2.12 | Schreibpfade sichern: Spaltenspezifische Updates
> **Kurzbeschreibung:** `BEFORE UPDATE OF (Spalten…)` gezielt nutzen, um riskante Attribut-Änderungen zu sperren.

- 📓 **Notebook:**  
  [`08_12_block_predicate_update_of.ipynb`](08_12_block_predicate_update_of.ipynb)
- 🎥 **YouTube:**  
  - [Block Predicate BEFORE UPDATE](https://www.youtube.com/results?search_query=sql+server+rls+before+update+block+predicate)
- 📘 **Docs:**  
  - [Block Predicate – Spaltenangaben](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-security-policy-transact-sql#arguments)

---

### 2.13 | RLS & Migrations/ETL
> **Kurzbeschreibung:** Massendatenladen über Staging; Policies temporär OFF? Alternativ **Bypass-Rolle** für ETL.

- 📓 **Notebook:**  
  [`08_13_rls_etl_bypass_patterns.ipynb`](08_13_rls_etl_bypass_patterns.ipynb)
- 🎥 **YouTube:**  
  - [ETL with RLS](https://www.youtube.com/results?search_query=sql+server+etl+row+level+security)
- 📘 **Docs:**  
  - [RLS – Verwaltung & Berechtigungen](https://learn.microsoft.com/en-us/sql/relational-databases/security/row-level-security#permissions)

---

### 2.14 | Sicherheit richtig modellieren (Least Privilege)
> **Kurzbeschreibung:** Nur notwendige Rechte; Bypass-Rolle restriktiv vergeben; Policy-Besitzer/Schema sauber wählen.

- 📓 **Notebook:**  
  [`08_14_rls_security_modeling.ipynb`](08_14_rls_security_modeling.ipynb)
- 🎥 **YouTube:**  
  - [RLS Security Design](https://www.youtube.com/results?search_query=sql+server+row+level+security+design)
- 📘 **Docs:**  
  - [Berechtigungen für Policies/Functions](https://learn.microsoft.com/en-us/sql/relational-databases/security/row-level-security#permissions)

---

### 2.15 | Edge Cases & Limitierungen
> **Kurzbeschreibung:** Prädikate müssen iTVF sein; kein Multi-Statement-TVF; Funktionen möglichst deterministisch/seiteneffektfrei.

- 📓 **Notebook:**  
  [`08_15_rls_edge_cases_limitations.ipynb`](08_15_rls_edge_cases_limitations.ipynb)
- 🎥 **YouTube:**  
  - [RLS Pitfalls](https://www.youtube.com/results?search_query=sql+server+row+level+security+pitfalls)
- 📘 **Docs:**  
  - [RLS – Grundlagen & Einschränkungen](https://learn.microsoft.com/en-us/sql/relational-databases/security/row-level-security#considerations)

---

### 2.16 | Anti-Patterns & Checkliste
> **Kurzbeschreibung:** Komplexe Prädikate (Skalar-UDF, dynamisches SQL), fehlende Indizes auf Predicate-Spalten, kein Block-Predicate, fehlender Admin-Bypass/Test, `STATE = OFF` vergessen, App setzt `SESSION_CONTEXT` nicht sauber.

- 📓 **Notebook:**  
  [`08_16_rls_anti_patterns_checkliste.ipynb`](08_16_rls_anti_patterns_checkliste.ipynb)
- 🎥 **YouTube:**  
  - [Common RLS Mistakes](https://www.youtube.com/results?search_query=sql+server+row+level+security+mistakes)
- 📘 **Docs/Blog:**  
  - [RLS – Best Practices & Performance](https://learn.microsoft.com/en-us/sql/relational-databases/security/row-level-security#best-practices)

---

## 3 | Weiterführende Informationen

- 📘 Microsoft Learn: [Row-Level Security (RLS) – Überblick & Beispiele](https://learn.microsoft.com/en-us/sql/relational-databases/security/row-level-security)  
- 📘 Microsoft Learn: [`CREATE SECURITY POLICY`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-security-policy-transact-sql) · [`ALTER SECURITY POLICY`](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-security-policy-transact-sql)  
- 📘 Microsoft Learn: [`sys.security_policies`](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-security-policies-transact-sql) · [`sys.security_predicates`](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-security-predicates-transact-sql)  
- 📘 Microsoft Learn: [`sp_set_session_context` / `SESSION_CONTEXT`](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-set-session-context-transact-sql)  
- 📘 Microsoft Learn: [`CREATE FUNCTION` – Inline TVF & `SCHEMABINDING`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-function-transact-sql)  
- 📘 Microsoft Learn: [Sicherheitskontexte: `EXECUTE AS`, `ORIGINAL_LOGIN()`](https://learn.microsoft.com/en-us/sql/t-sql/statements/execute-as-clause-transact-sql)  
- 📘 Microsoft Learn: [RLS – Performance Considerations](https://learn.microsoft.com/en-us/sql/relational-databases/security/row-level-security#performance-considerations)  
- 📝 Simple Talk (Redgate): *Implementing Row-Level Security in SQL Server*  
- 📝 SQLPerformance: *Row-Level Security – Internals & Performance* – Suchsammlung  
- 📝 Brent Ozar: *Row-Level Security: What You Need to Know* – https://www.brentozar.com/  
- 📝 Erik Darling: *RLS Predicates & SARGability* – https://www.erikdarlingdata.com/  
- 📝 Itzik Ben-Gan: *RLS Patterns for Multi-Tenant* – Artikelsammlung  
- 🎥 YouTube (Data Exposed): *Row-Level Security Deep Dive* – Playlist/Suche  
- 🎥 YouTube: *RLS – Filter vs Block Predicate* – Tutorials (Suche)  
