# T-SQL Views & Schemata – Übersicht  
*Erstellung von Views, Einsatzbereiche, Sicherheitsaspekte*

## 1 | Begriffsdefinition

| SQL-Term | Beschreibung |
|---|---|
| View (`CREATE VIEW`) | Benannte Abfrage (logische Tabelle) zur Kapselung von Join/Filter/Projektionslogik; speichert **nur Definition**, nicht Daten (Ausnahme: **indizierte** Views mit materialisiertem Index). |
| Updatable View | View, die DML zulässt (i. d. R. 1 Basistabelle, keine Aggregation/Distinct/Top/Union). Komplexe Views via `INSTEAD OF`-Trigger aktualisierbar. |
| `WITH CHECK OPTION` | Erzwingt, dass DML durch die View die **View-Predicate** nicht verletzt (Zeilen müssen im View-Ergebnis liegen). |
| `WITH SCHEMABINDING` | Bindet View hart an zugrundeliegende Objekte/Spalten (z. B. verhindert `DROP/ALTER` der Basisobjekte ohne vorheriges Anpassen der View). Pflicht für **indizierte** Views. |
| Indizierte View (Materialized View) | View mit **eindeutigem, gruppiertem** Clustered Index; Anforderungen an Determinismus, `SCHEMABINDING`, Session-`SET`-Optionen u. a. |
| Partitionierte View | Horizontale Partitionierung über mehrere gleichartige Tabellen via `UNION ALL`; updatable bei erfüllten Check-Constraint-Regeln. |
| `WITH ENCRYPTION` | Verschleiert Sicht auf Quelltext der View (Metadatenzugriff), **nicht** als Sicherheitsgrenze verstehen. |
| `WITH VIEW_METADATA` | Liefert Metadaten auf Basis der View statt der zugrundeliegenden Tabellen (für bestimmte Clients/Provider). |
| Schema (`CREATE SCHEMA`) | Logischer **Namensraum & Besitzcontainer** innerhalb einer Datenbank. Rechte können auf Schemaebene vergeben werden. |
| `ALTER SCHEMA` | Verschiebt Objekte zwischen Schemata (Besitz/Namensraum); keine physische Datenbewegung. |
| Ownership Chaining | Berechtigungsprüfung kann über Besitzerkette „durchgereicht“ werden (z. B. `SELECT` auf View ohne direkte Tabellenrechte). |
| Schema-Rechte | `GRANT SELECT ON SCHEMA::Sales TO role;` – Rechte auf **alle Objekte** im Schema delegierbar. |
| Best Practices | Keine `SELECT *` in Views; Spalten **explizit** benennen, deterministische Ausdrücke, keine `ORDER BY` in View-Definition. |

---

## 2 | Struktur

### 2.1 | Grundlagen: Views & Schemata – wofür?
> **Kurzbeschreibung:** Kapselung, Wiederverwendbarkeit, Sicherheits‐ und Abstraktionsschicht; Schemata als Struktur- und Sicherheitsgrenze.

- 📓 **Notebook:**  
  [`22_01_views_schemata_grundlagen.ipynb`](22_01_views_schemata_grundlagen.ipynb)

- 🎥 **YouTube:**  
  - [SQL Server Views – Basics](https://www.youtube.com/results?search_query=sql+server+views+tutorial)  

- 📘 **Docs:**  
  - [`CREATE VIEW`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-view-transact-sql)  
  - [`CREATE SCHEMA`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-schema-transact-sql)

---

### 2.2 | `CREATE VIEW` – Syntax & Best Practices
> **Kurzbeschreibung:** Schema präfixieren, Spaltenliste explizit, deterministische Ausdrücke; kein `ORDER BY` (außer mit `TOP`, aber nicht zur Sortierung verwenden).

- 📓 **Notebook:**  
  [`22_02_create_view_best_practices.ipynb`](22_02_create_view_best_practices.ipynb)

- 🎥 **YouTube:**  
  - [Create View – Best Practices](https://www.youtube.com/results?search_query=sql+server+create+view+best+practices)

- 📘 **Docs:**  
  - [`CREATE VIEW` – Argumente/Optionen](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-view-transact-sql#syntax)

---

### 2.3 | Updatable Views & `INSTEAD OF`-Trigger
> **Kurzbeschreibung:** Regeln für DML-fähige Views (eine Basistabelle, keine Aggregation/Distinct/Union). Komplexere Fälle mit `INSTEAD OF`-Triggern.

- 📓 **Notebook:**  
  [`22_03_updatable_views_instead_of_trigger.ipynb`](22_03_updatable_views_instead_of_trigger.ipynb)

- 🎥 **YouTube:**  
  - [Updatable Views Explained](https://www.youtube.com/results?search_query=sql+server+updatable+views)

- 📘 **Docs:**  
  - [DML in Views – Hinweise](https://learn.microsoft.com/en-us/sql/relational-databases/views/create-views)  
  - [`CREATE TRIGGER` (INSTEAD OF)](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-trigger-transact-sql)

---

### 2.4 | `WITH CHECK OPTION` – Datenintegrität durch Views
> **Kurzbeschreibung:** Verhindert „Entfliehen“ aus View-Filter; Insert/Update muss die View-Bedingung erfüllen.

- 📓 **Notebook:**  
  [`22_04_with_check_option.ipynb`](22_04_with_check_option.ipynb)

- 🎥 **YouTube:**  
  - [WITH CHECK OPTION Demo](https://www.youtube.com/results?search_query=sql+server+with+check+option)

- 📘 **Docs:**  
  - [`CREATE VIEW` – `WITH CHECK OPTION`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-view-transact-sql#with-check-option)

---

### 2.5 | Sicherheit: Ownership Chaining & Schema-Rechte
> **Kurzbeschreibung:** Zugriff über View ohne Tabellenrechte; Rechte auf Schema-Ebene (`GRANT ON SCHEMA`) sauber gestalten.

- 📓 **Notebook:**  
  [`22_05_security_views_schema_permissions.ipynb`](22_05_security_views_schema_permissions.ipynb)

- 🎥 **YouTube:**  
  - [Ownership Chaining & Views](https://www.youtube.com/results?search_query=sql+server+ownership+chaining+views)

- 📘 **Docs:**  
  - [Ownership Chains](https://learn.microsoft.com/en-us/sql/relational-databases/security/ownership-chains)  
  - [GRANT auf Schema](https://learn.microsoft.com/en-us/sql/t-sql/statements/grant-schema-permissions-transact-sql)

---

### 2.6 | `SCHEMABINDING` – stabile Views
> **Kurzbeschreibung:** Schutz vor Breaking Changes an Basistabellen; 2-teilige Namen, explizite Spaltenlisten erforderlich.

- 📓 **Notebook:**  
  [`22_06_schemabinding_views.ipynb`](22_06_schemabinding_views.ipynb)

- 🎥 **YouTube:**  
  - [SCHEMABINDING Deep Dive](https://www.youtube.com/results?search_query=sql+server+schemabinding+view)

- 📘 **Docs:**  
  - [`SCHEMABINDING` in Views](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-view-transact-sql#schemabinding)

---

### 2.7 | Indizierte Views (Materialized) – Voraussetzungen & Nutzen
> **Kurzbeschreibung:** Eindeutiger Clustered Index, deterministische Ausdrücke, `COUNT_BIG`, Set-Optionen, gleiche Owner. Für OLAP/berichtsnahe Szenarien.

- 📓 **Notebook:**  
  [`22_07_indexed_views_requirements.ipynb`](22_07_indexed_views_requirements.ipynb)

- 🎥 **YouTube:**  
  - [Indexed Views – When & How](https://www.youtube.com/results?search_query=sql+server+indexed+views)

- 📘 **Docs:**  
  - [Indexed Views – Requirements](https://learn.microsoft.com/en-us/sql/relational-databases/views/create-indexed-views)  
  - [`CREATE INDEX` auf View](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-index-transact-sql)

---

### 2.8 | Partitionierte Views (`UNION ALL`)
> **Kurzbeschreibung:** Horizontales Partitionieren über Tabellen; Check-Constraints für Partition Elimination; DML-Regeln.

- 📓 **Notebook:**  
  [`22_08_partitionierte_views_union_all.ipynb`](22_08_partitionierte_views_union_all.ipynb)

- 🎥 **YouTube:**  
  - [Partitioned Views – Demo](https://www.youtube.com/results?search_query=sql+server+partitioned+views)

- 📘 **Docs:**  
  - [Partitioned Views – Overview](https://learn.microsoft.com/en-us/sql/relational-databases/partitions/partitioned-views)

---

### 2.9 | Performance & Wartung von Views
> **Kurzbeschreibung:** Plan-Caching, Statistiken der Basistabellen, Recompile-Muster; Verschachtelungstiefe von Views gering halten.

- 📓 **Notebook:**  
  [`22_09_performance_views_maintenance.ipynb`](22_09_performance_views_maintenance.ipynb)

- 🎥 **YouTube:**  
  - [View Performance Tips](https://www.youtube.com/results?search_query=sql+server+view+performance)

- 📘 **Docs:**  
  - [Query Processing Architecture Guide](https://learn.microsoft.com/en-us/sql/relational-databases/query-processing-architecture-guide)

---

### 2.10 | `ORDER BY` in Views, `TOP (100) PERCENT` – warum NICHT
> **Kurzbeschreibung:** `ORDER BY` ist in Views unzulässig (außer mit `TOP`), **garantiert aber keine Reihenfolge** – immer im äußeren Select sortieren.

- 📓 **Notebook:**  
  [`22_10_order_by_in_views_top100percent.ipynb`](22_10_order_by_in_views_top100percent.ipynb)

- 🎥 **YouTube:**  
  - [TOP 100 PERCENT myth](https://www.youtube.com/results?search_query=sql+server+top+100+percent+order+by+view)

- 📘 **Docs:**  
  - [`CREATE VIEW` – Einschränkungen](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-view-transact-sql#limitations-and-restrictions)

---

### 2.11 | Schemata entwerfen: Struktur & Besitz
> **Kurzbeschreibung:** Module/Fachdomänen trennen (z. B. `Sales`, `Ref`), Besitzer/Default-Schema definieren, Namenskonventionen.

- 📓 **Notebook:**  
  [`22_11_schema_design_basics.ipynb`](22_11_schema_design_basics.ipynb)

- 🎥 **YouTube:**  
  - [Schemas – Design & Security](https://www.youtube.com/results?search_query=sql+server+schemas+design)

- 📘 **Docs:**  
  - [Database Schemas – Overview](https://learn.microsoft.com/en-us/sql/relational-databases/security/authentication-access/database-schemas)

---

### 2.12 | `ALTER SCHEMA` & Objektverschiebung
> **Kurzbeschreibung:** Objekte sicher zwischen Schemata verschieben; Rechte/Abhängigkeiten berücksichtigen.

- 📓 **Notebook:**  
  [`22_12_alter_schema_move_objects.ipynb`](22_12_alter_schema_move_objects.ipynb)

- 🎥 **YouTube:**  
  - [ALTER SCHEMA – Move Objects](https://www.youtube.com/results?search_query=sql+server+alter+schema+move+object)

- 📘 **Docs:**  
  - [`ALTER SCHEMA`](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-schema-transact-sql)

---

### 2.13 | Rechteverwaltung: Schema- vs. Objekt-Ebene
> **Kurzbeschreibung:** Rollen & Grants auf Schemaebene (`SELECT`/`INSERT`/`UPDATE`/`EXECUTE`), Least-Privilege, Audits.

- 📓 **Notebook:**  
  [`22_13_schema_vs_object_permissions.ipynb`](22_13_schema_vs_object_permissions.ipynb)

- 🎥 **YouTube:**  
  - [Grant on SCHEMA – How it works](https://www.youtube.com/results?search_query=sql+server+grant+schema+permissions)

- 📘 **Docs:**  
  - [`GRANT` – Schema Permissions](https://learn.microsoft.com/en-us/sql/t-sql/statements/grant-schema-permissions-transact-sql)  
  - [Securables & Permissions](https://learn.microsoft.com/en-us/sql/relational-databases/security/securables)

---

### 2.14 | Metadaten & Abhängigkeiten
> **Kurzbeschreibung:** `sys.views`, `sys.sql_modules`, `sys.schemas`, Abhängigkeitsgraph via `sys.sql_expression_dependencies`/DMVs.

- 📓 **Notebook:**  
  [`22_14_metadata_dependencies_views_schema.ipynb`](22_14_metadata_dependencies_views_schema.ipynb)

- 🎥 **YouTube:**  
  - [Find View Dependencies](https://www.youtube.com/results?search_query=sql+server+view+dependencies)

- 📘 **Docs:**  
  - [`sys.views`](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-views-transact-sql) · [`sys.sql_modules`](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-sql-modules-transact-sql)  
  - [`sys.sql_expression_dependencies`](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-sql-expression-dependencies-transact-sql)

---

### 2.15 | Views vs. TVFs/Synonyme/Temporäre Objekte
> **Kurzbeschreibung:** Abwägen zwischen View, Inline-TVF (Parameter!), Synonym, temporären Tabellen/Ctes – Einsatzkriterien & Wartung.

- 📓 **Notebook:**  
  [`22_15_views_vs_tvf_synonym_temp.ipynb`](22_15_views_vs_tvf_synonym_temp.ipynb)

- 🎥 **YouTube:**  
  - [Views vs Inline TVF](https://www.youtube.com/results?search_query=sql+server+view+vs+inline+table+valued+function)

- 📘 **Docs:**  
  - [Inline TVFs (`CREATE FUNCTION`)](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-function-transact-sql)  
  - [Synonyms](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-synonym-transact-sql)

---

### 2.16 | Anti-Patterns & Fallstricke
> **Kurzbeschreibung:** `SELECT *`, `ORDER BY` in View, tiefe View-Verschachtelung, fehlendes `SCHEMABINDING`, „Views als Sicherheitsgrenze“ missverstehen, indizierte Views mit nicht-deterministischen Ausdrücken.

- 📓 **Notebook:**  
  [`22_16_views_schemata_anti_patterns.ipynb`](22_16_views_schemata_anti_patterns.ipynb)

- 🎥 **YouTube:**  
  - [Common View Mistakes](https://www.youtube.com/results?search_query=sql+server+view+mistakes)

- 📘 **Docs/Blog:**  
  - [`CREATE VIEW` – Einschränkungen](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-view-transact-sql#limitations-and-restrictions)  
  - [Indexed View – Determinism/Requirements](https://learn.microsoft.com/en-us/sql/relational-databases/views/create-indexed-views)

---

## 3 | Weiterführende Informationen

- 📘 Microsoft Learn: [`CREATE VIEW` (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-view-transact-sql)  
- 📘 Microsoft Learn: [Create Indexed Views – Voraussetzungen & Beispiele](https://learn.microsoft.com/en-us/sql/relational-databases/views/create-indexed-views)  
- 📘 Microsoft Learn: [Partitioned Views](https://learn.microsoft.com/en-us/sql/relational-databases/partitions/partitioned-views)  
- 📘 Microsoft Learn: [Create Views – Leitfaden & DML-Regeln](https://learn.microsoft.com/en-us/sql/relational-databases/views/create-views)  
- 📘 Microsoft Learn: [`CREATE SCHEMA` / `ALTER SCHEMA`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-schema-transact-sql)  
- 📘 Microsoft Learn: [Ownership Chains & Security](https://learn.microsoft.com/en-us/sql/relational-databases/security/ownership-chains)  
- 📘 Microsoft Learn: [Securables & Berechtigungen](https://learn.microsoft.com/en-us/sql/relational-databases/security/securables)  
- 📘 Microsoft Learn: [Systemkataloge: `sys.views`, `sys.schemas`, `sys.sql_modules`](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/catalog-views-transact-sql)  
- 📝 Simple Talk (Redgate): *Working with SQL Server Views*  
- 📝 SQLShack: *Indexed Views – Performance & Caveats*  
- 📝 SQLPerformance: *Nested Views & Plan Quality* – Suchsammlung  
- 📝 Brent Ozar: *Why SELECT * is bad (Views too)*  
- 📝 Erik Darling: *Views vs. Inline TVFs – Performance Notes*  
- 🎥 YouTube (Data Exposed): *Security & Ownership Chains* – Playlist/Suche  
- 🎥 YouTube: *Indexed Views – Demos & Tuning* – diverse Channels  
