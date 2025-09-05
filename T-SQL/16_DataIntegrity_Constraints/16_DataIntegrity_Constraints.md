# T-SQL Data Integrity & Constraints – Übersicht  
*Schlüssel und Constraints: PRIMARY KEY, FOREIGN KEY, CHECK, DEFAULT*

## 1 | Begriffsdefinition

| SQL-Term | Beschreibung |
|---|---|
| **PRIMARY KEY (PK)** | Erzwingt **Eindeutigkeit** und **NOT NULL** über Spalte(n); erzeugt automatisch **einen eindeutigen Index** (standardmäßig **clustered**, falls keiner existiert). |
| **UNIQUE** | Erzwingt Eindeutigkeit über Spalte(n); **NULL-Werte sind mehrfach zulässig** (SQL Server betrachtet `NULL` nicht als gleich). Erstellt einen eindeutigen Index. |
| **FOREIGN KEY (FK)** | Referenzielle Integrität: Kind-↔Eltern-Beziehung; verweist auf **PK** oder **eindeutigen** Index der Zieltabelle. Optionen: `ON DELETE/UPDATE { NO ACTION | CASCADE | SET NULL | SET DEFAULT }`. |
| **CHECK** | Prädikat auf Zeilenebene (boolescher Ausdruck), nur Spalten derselben Zeile; **deterministisch**; keine Abfragen auf andere Tabellen. |
| **DEFAULT** | Standardwert/Expression für eine Spalte, wenn **nicht** explizit ein Wert übergeben wird oder `DEFAULT` verwendet wird. |
| **NOT NULL** | Spalte muss einen Wert haben; oft gemeinsam mit PK/UNIQUE/CHECK. |
| **Constraint-Namen** | Schema-gescoped Objekte; benennen (`CONSTRAINT CK_T_Col_Positive`) für Wartbarkeit. |
| **Trusted vs. Untrusted** | Mit `WITH (NOCHECK)` hinzugefügte oder deaktivierte CHECK/FK können **untrusted** sein → Optimizer nutzt sie **nicht**. Mit `ALTER TABLE … WITH CHECK CHECK CONSTRAINT …` wieder **vertrauenswürdig** machen. |
| **Disable/Enable** | `ALTER TABLE … NOCHECK/CHECK CONSTRAINT` deaktiviert/aktiviert Durchsetzung (FK/CHECK). PK/UNIQUE lassen sich nur über **Index** deaktivieren (Drop/Recreate). |
| **Cascades & Multiple Paths** | `CASCADE/SET NULL/SET DEFAULT` möglich; **mehrere Kaskadenpfade** zu derselben Tabelle sind nicht erlaubt. |
| **NOT FOR REPLICATION** | Unterdrückt Constraint-Durchsetzung bei Replikationsvorgängen. |
| **Determinismus** | CHECK muss deterministisch sein; UDFs sollten `SCHEMABINDING` und deterministisches Verhalten aufweisen. |
| **Design-Hinweis** | FKs auf Kindspalten **indizieren**, um Validierung/Joins zu beschleunigen; bedingte Eindeutigkeit per **gefiltertem UNIQUE-Index**. |

---

## 2 | Struktur

### 2.1 | Überblick: Arten von Constraints & Einsatz
> **Kurzbeschreibung:** Wofür PK/UNIQUE/FK/CHECK/DEFAULT gedacht sind und wie sie zusammen Datenqualität sichern.

- 📓 **Notebook:**  
  [`08_01_constraints_overview.ipynb`](08_01_constraints_overview.ipynb)
- 🎥 **YouTube:**  
  - [SQL Server Constraints – Overview](https://www.youtube.com/results?search_query=sql+server+constraints+overview)  
  - [Keys & Constraints Explained](https://www.youtube.com/results?search_query=sql+server+primary+key+foreign+key+unique+check)
- 📘 **Docs:**  
  - [Unique Constraints and Indexes](https://learn.microsoft.com/en-us/sql/relational-databases/tables/create-unique-constraints)  
  - [FOREIGN KEY – Referenz](https://learn.microsoft.com/en-us/sql/relational-databases/tables/create-foreign-key-relationships)

---

### 2.2 | PRIMARY KEY – Design & Clustered/Nonclustered
> **Kurzbeschreibung:** Ein PK pro Tabelle; Clustered-Key sorgfältig wählen (schmal, stabil, monoton).

- 📓 **Notebook:**  
  [`08_02_primary_key_design.ipynb`](08_02_primary_key_design.ipynb)
- 🎥 **YouTube:**  
  - [Primary Key Best Practices](https://www.youtube.com/results?search_query=sql+server+primary+key+best+practices)  
  - [Clustered vs Nonclustered PK](https://www.youtube.com/results?search_query=sql+server+clustered+primary+key)
- 📘 **Docs:**  
  - [`PRIMARY KEY` – Syntax/Beispiele](https://learn.microsoft.com/en-us/sql/relational-databases/tables/create-primary-keys)

---

### 2.3 | UNIQUE – Eindeutigkeit & mehrfache NULLs
> **Kurzbeschreibung:** Wann UNIQUE statt PK; bedingte Eindeutigkeit via gefiltertem Index.

- 📓 **Notebook:**  
  [`08_03_unique_constraints_filtered_unique.ipynb`](08_03_unique_constraints_filtered_unique.ipynb)
- 🎥 **YouTube:**  
  - [UNIQUE Constraint vs UNIQUE Index](https://www.youtube.com/results?search_query=sql+server+unique+constraint+vs+index)  
  - [Filtered Unique Index Patterns](https://www.youtube.com/results?search_query=sql+server+filtered+unique+index)
- 📘 **Docs:**  
  - [Create Filtered Indexes](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/create-filtered-indexes)

---

### 2.4 | FOREIGN KEY – Referenzielle Integrität
> **Kurzbeschreibung:** Syntax, Elternschlüsselanforderungen, Performancehinweise (Index auf FK-Spalten!).

- 📓 **Notebook:**  
  [`08_04_foreign_key_basics.ipynb`](08_04_foreign_key_basics.ipynb)
- 🎥 **YouTube:**  
  - [Foreign Keys in SQL Server](https://www.youtube.com/results?search_query=sql+server+foreign+key+tutorial)  
  - [Indexing Foreign Keys](https://www.youtube.com/results?search_query=sql+server+index+foreign+keys)
- 📘 **Docs:**  
  - [FOREIGN KEY – Details](https://learn.microsoft.com/en-us/sql/relational-databases/tables/create-foreign-key-relationships)

---

### 2.5 | FK-Aktionen: CASCADE, SET NULL/DEFAULT, NO ACTION
> **Kurzbeschreibung:** Verhalten bei Lösch-/Updateereignissen; Randfälle (Multiple Cascade Paths, `NOT FOR REPLICATION`).

- 📓 **Notebook:**  
  [`08_05_fk_cascade_options.ipynb`](08_05_fk_cascade_options.ipynb)
- 🎥 **YouTube:**  
  - [ON DELETE/UPDATE CASCADE Demo](https://www.youtube.com/results?search_query=sql+server+on+delete+cascade)  
  - [SET NULL vs SET DEFAULT](https://www.youtube.com/results?search_query=sql+server+foreign+key+set+null+default)
- 📘 **Docs:**  
  - [Referenzaktionen – Übersicht](https://learn.microsoft.com/en-us/sql/relational-databases/tables/foreign-keys-referential-actions)

---

### 2.6 | CHECK – Regeln korrekt modellieren
> **Kurzbeschreibung:** Deterministische Prädikate, Mehrspalten-Checks, UDFs nur wenn deterministisch/schemagebunden.

- 📓 **Notebook:**  
  [`08_06_check_constraints_patterns.ipynb`](08_06_check_constraints_patterns.ipynb)
- 🎥 **YouTube:**  
  - [CHECK Constraints Tutorial](https://www.youtube.com/results?search_query=sql+server+check+constraint)  
  - [Business Rules with CHECK](https://www.youtube.com/results?search_query=sql+server+check+constraint+examples)
- 📘 **Docs:**  
  - [Create Check Constraints](https://learn.microsoft.com/en-us/sql/relational-databases/tables/create-check-constraints)

---

### 2.7 | DEFAULT – Standardwerte & Best Practices
> **Kurzbeschreibung:** Wann greift DEFAULT (Spalte weggelassen/`DEFAULT`-Keyword), typische Muster (`SYSUTCDATETIME()`, `SEQUENCE`, `NEWSEQUENTIALID()`).

- 📓 **Notebook:**  
  [`08_07_default_constraints_patterns.ipynb`](08_07_default_constraints_patterns.ipynb)
- 🎥 **YouTube:**  
  - [DEFAULT Constraints in Action](https://www.youtube.com/results?search_query=sql+server+default+constraint)  
  - [Sequences as Defaults](https://www.youtube.com/results?search_query=sql+server+sequence+default)
- 📘 **Docs:**  
  - [Create Default Constraints](https://learn.microsoft.com/en-us/sql/relational-databases/tables/create-default-constraints)  
  - [`CREATE SEQUENCE`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-sequence-transact-sql)

---

### 2.8 | Trusted Constraints: `WITH CHECK` vs `WITH NOCHECK`
> **Kurzbeschreibung:** Auswirkungen auf Optimizer & Datenqualität; wie man Constraints wieder „trusted“ macht.

- 📓 **Notebook:**  
  [`08_08_trusted_constraints_nocheck.ipynb`](08_08_trusted_constraints_nocheck.ipynb)
- 🎥 **YouTube:**  
  - [WITH CHECK vs NOCHECK](https://www.youtube.com/results?search_query=sql+server+with+nocheck+constraint)  
  - [Validate Existing Data](https://www.youtube.com/results?search_query=sql+server+validate+constraints)
- 📘 **Docs:**  
  - [Enable/Disable Constraints](https://learn.microsoft.com/en-us/sql/relational-databases/tables/enable-or-disable-constraints)

---

### 2.9 | Bulk Load & Constraints
> **Kurzbeschreibung:** Temporär deaktivieren? Reihenfolge, `CHECK CONSTRAINT ALL`, Datenvalidierung nach dem Load.

- 📓 **Notebook:**  
  [`08_09_bulkload_and_constraints.ipynb`](08_09_bulkload_and_constraints.ipynb)
- 🎥 **YouTube:**  
  - [Bulk Insert with Constraints](https://www.youtube.com/results?search_query=sql+server+bulk+insert+constraints)  
  - [Trusted Constraints after Bulk](https://www.youtube.com/results?search_query=sql+server+trusted+constraints+bulk)
- 📘 **Docs:**  
  - [BULK INSERT – Constraints/Triggers](https://learn.microsoft.com/en-us/sql/t-sql/statements/bulk-insert-transact-sql#arguments)

---

### 2.10 | Bedingte Eindeutigkeit: Gefilterte UNIQUE-Indizes
> **Kurzbeschreibung:** Z. B. eindeutige `Email` nur für `IsActive=1`; Alternativen zu Triggern.

- 📓 **Notebook:**  
  [`08_10_filtered_unique_patterns.ipynb`](08_10_filtered_unique_patterns.ipynb)
- 🎥 **YouTube:**  
  - [Conditional Uniqueness](https://www.youtube.com/results?search_query=sql+server+conditional+unique+index)  
  - [Filtered Index Demos](https://www.youtube.com/results?search_query=sql+server+filtered+index+demo)
- 📘 **Docs:**  
  - [Filtered Indexes – Doku](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/create-filtered-indexes)

---

### 2.11 | Fehlermeldungen & Handling (2601/2627/547)
> **Kurzbeschreibung:** PK/UNIQUE-Kollisionen (`2627/2601`), FK-Verletzungen (`547`) – Muster fürs Abfangen.

- 📓 **Notebook:**  
  [`08_11_constraint_errors_handling.ipynb`](08_11_constraint_errors_handling.ipynb)
- 🎥 **YouTube:**  
  - [Handle FK/Unique Violations](https://www.youtube.com/results?search_query=sql+server+error+2627+2601+547)  
  - [TRY/CATCH around DML](https://www.youtube.com/results?search_query=sql+server+try+catch+dml)
- 📘 **Docs:**  
  - [Database Engine Errors & Events](https://learn.microsoft.com/en-us/sql/relational-databases/errors-events/database-engine-events-and-errors)

---

### 2.12 | Metadaten & DMVs
> **Kurzbeschreibung:** `sys.key_constraints`, `sys.check_constraints`, `sys.default_constraints`, `sys.foreign_keys`, `sys.foreign_key_columns`.

- 📓 **Notebook:**  
  [`08_12_metadata_constraints_dmvs.ipynb`](08_12_metadata_constraints_dmvs.ipynb)
- 🎥 **YouTube:**  
  - [Find Constraints via Catalog Views](https://www.youtube.com/results?search_query=sql+server+sys.check_constraints+sys.foreign_keys)  
  - [Reverse Engineer Keys](https://www.youtube.com/results?search_query=sql+server+list+constraints+dmv)
- 📘 **Docs:**  
  - [Catalog Views – Constraints](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/catalog-views-transact-sql)

---

### 2.13 | Design: Surrogat vs. Natürlicher Schlüssel
> **Kurzbeschreibung:** Abwägungen (Stabilität, Breite, Business-Änderungen), `IDENTITY` vs. `SEQUENCE`.

- 📓 **Notebook:**  
  [`08_13_surrogate_vs_natural_keys.ipynb`](08_13_surrogate_vs_natural_keys.ipynb)
- 🎥 **YouTube:**  
  - [Surrogate vs Natural Keys](https://www.youtube.com/results?search_query=sql+server+surrogate+key+natural+key)  
  - [Identity vs Sequence](https://www.youtube.com/results?search_query=sql+server+identity+vs+sequence)
- 📘 **Docs:**  
  - [`CREATE SEQUENCE`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-sequence-transact-sql)

---

### 2.14 | Performance: Optimizer & Constraints
> **Kurzbeschreibung:** Wie **trusted** Constraints Pläne vereinfachen (Prädikatsableitung), Indexbedarf auf FK-Spalten.

- 📓 **Notebook:**  
  [`08_14_optimizer_and_constraints.ipynb`](08_14_optimizer_and_constraints.ipynb)
- 🎥 **YouTube:**  
  - [How Constraints Affect Plans](https://www.youtube.com/results?search_query=sql+server+constraints+optimizer)  
  - [Index FKs for Performance](https://www.youtube.com/results?search_query=sql+server+index+foreign+keys+performance)
- 📘 **Docs:**  
  - [Query Processing Architecture Guide](https://learn.microsoft.com/en-us/sql/relational-databases/query-processing-architecture-guide)

---

### 2.15 | Spezialfälle: Komposite, Self-Reference, Cross-DB
> **Kurzbeschreibung:** Komposit-PK/FK, Selbstbezüge, **keine** Cross-DB-FKs, aber Cross-Schema möglich.

- 📓 **Notebook:**  
  [`08_15_special_cases_keys.ipynb`](08_15_special_cases_keys.ipynb)
- 🎥 **YouTube:**  
  - [Composite Keys & FKs](https://www.youtube.com/results?search_query=sql+server+composite+primary+key+foreign+key)  
  - [Self-Referencing FKs](https://www.youtube.com/results?search_query=sql+server+self+referencing+foreign+key)
- 📘 **Docs:**  
  - [FOREIGN KEY – Einschränkungen](https://learn.microsoft.com/en-us/sql/relational-databases/tables/foreign-keys)

---

### 2.16 | Anti-Patterns & Checkliste
> **Kurzbeschreibung:** `WITH NOCHECK` vergessen → untrusted; FK ohne Index; CHECK mit nicht-deterministischen Funktionen; „Magische“ Default-Werte (z. B. `1900-01-01`) statt `NULL` + CHECK; Trigger statt Constraints; zu breite/volatile PKs.

- 📓 **Notebook:**  
  [`08_16_constraints_anti_patterns.ipynb`](08_16_constraints_anti_patterns.ipynb)
- 🎥 **YouTube:**  
  - [Common Constraint Mistakes](https://www.youtube.com/results?search_query=sql+server+constraint+mistakes)  
  - [Defaults & Checks Gone Wrong](https://www.youtube.com/results?search_query=sql+server+default+constraint+best+practices)
- 📘 **Docs/Blog:**  
  - [Best Practices – Keys & Constraints](https://learn.microsoft.com/en-us/sql/relational-databases/tables/create-foreign-key-relationships#best-practices)

---

## 3 | Weiterführende Informationen

- 📘 Microsoft Learn: [PRIMARY KEY erstellen](https://learn.microsoft.com/en-us/sql/relational-databases/tables/create-primary-keys)  
- 📘 Microsoft Learn: [UNIQUE Constraints & Indexe](https://learn.microsoft.com/en-us/sql/relational-databases/tables/create-unique-constraints)  
- 📘 Microsoft Learn: [FOREIGN KEY – Referenzaktionen & Beispiele](https://learn.microsoft.com/en-us/sql/relational-databases/tables/foreign-keys-referential-actions)  
- 📘 Microsoft Learn: [CHECK Constraints erstellen](https://learn.microsoft.com/en-us/sql/relational-databases/tables/create-check-constraints)  
- 📘 Microsoft Learn: [DEFAULT Constraints erstellen](https://learn.microsoft.com/en-us/sql/relational-databases/tables/create-default-constraints)  
- 📘 Microsoft Learn: [Enable/Disable/Validate Constraints](https://learn.microsoft.com/en-us/sql/relational-databases/tables/enable-or-disable-constraints)  
- 📘 Microsoft Learn: [Catalog Views (`sys.*_constraints`, `sys.foreign_keys`)](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/catalog-views-transact-sql)  
- 📘 Microsoft Learn: [Index Design Guide (FK-Indizierung/SARGability)](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-index-design-guide)  
- 📝 SQLPerformance: *Trusted vs. Untrusted Constraints & Optimizer* – https://www.sqlperformance.com/?s=constraint  
- 📝 Simple Talk (Redgate): *Foreign Keys & Cascades – Praxis*  
- 📝 Brent Ozar: *The Case for Indexing Foreign Keys* – https://www.brentozar.com/  
- 📝 Erik Darling: *Filtered Unique Indexes – Conditional Uniqueness* – https://www.erikdarlingdata.com/  
- 📝 Itzik Ben-Gan: *Constraints & Data Quality Patterns* – Sammlung  
- 🎥 YouTube (Data Exposed): *Keys & Constraints Best Practices* – Suchlink  
- 🎥 YouTube: *CHECK/DEFAULT – Tipps & Demos* – Suchlink  
