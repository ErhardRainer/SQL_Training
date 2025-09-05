# T-SQL Collation & Case Sensitivity – Übersicht  
*Sortierfolgen/Collations, CI vs. CS, Auswirkungen auf Vergleiche und Joins*

## 1 | Begriffsdefinition

| SQL-Term | Beschreibung |
|---|---|
| Collation | Regelsatz für **Sortierung** und **Vergleiche** von Zeichenfolgen (Groß-/Kleinschreibung, Akzente, Kana/Width, Sprache). |
| CI / CS | **Case-Insensitive** (CI) ignoriert Groß-/Kleinschreibung (`a=A`), **Case-Sensitive** (CS) unterscheidet (`a≠A`). |
| AI / AS | **Accent-Insensitive** (AI) ignoriert Akzente (`a=á`), **Accent-Sensitive** (AS) unterscheidet (`a≠á`). |
| KS / WS | **Kana-Sensitive** (KS) unterscheidet Katakana/Hiragana; **Width-Sensitive** (WS) unterscheidet Halb-/Vollbreite. |
| BIN / BIN2 | **Binäre** Collations: Vergleiche auf Codepunkt-/Sortierschlüsselbasis; `BIN2` ist modern/deterministischer. |
| Windows- vs. SQL-Collation | Windows-Collations (sprach-/kulturspezifisch, z. B. `Latin1_General_100_CI_AS`) vs. ältere SQL-Collations (`SQL_Latin1_General_CP1_CI_AS`). |
| UTF-8 Collation | Seit SQL Server 2019: `_UTF8`-Suffix erlaubt **UTF-8** in `varchar`/`char` (z. B. `Latin1_General_100_CI_AS_SC_UTF8`). |
| SC-Collation | **Supplementary Characters**: `_SC` unterstützt Unicode > BMP (Surrogates) korrekt in `nvarchar`. |
| Kollations-Ebene | Server-, Datenbank-, Spalten- und **Ausdrucksebene** (per `COLLATE` am Ausdruck übersteuerbar). |
| Kollationspräzedenz | Regel, welche Collation bei Ausdrücken gewinnt; Konflikte erfordern explizites `COLLATE`. |
| SARGability & Indexe | Collation beeinflusst **Vergleichslogik** und **Indexnutzung** (z. B. case-insensitive Seeks). |
| tempdb-Collation | `#temp` erbt **tempdb**-Collation → Cross-DB-Vergleiche können Konflikte werfen. |
| Typen & Codepages | `nvarchar` = Unicode (Collation steuert Ordnung/Regeln), `varchar` = Codepage der Collation; `_UTF8` erweitert `varchar`. |

---

## 2 | Struktur

### 2.1 | Collation-Grundlagen & Namenslogik
> **Kurzbeschreibung:** Bestandteile einer Collation (Sprache + Sensitivitäten), Beispiele und Auswirkungen.

- 📓 **Notebook:**  
  [`08_01_collation_grundlagen.ipynb`](08_01_collation_grundlagen.ipynb)

- 🎥 **YouTube:**  
  - [SQL Server Collation Basics](https://www.youtube.com/results?search_query=sql+server+collation+basics)  
  - [CI vs CS vs AS](https://www.youtube.com/results?search_query=sql+server+case+accent+sensitive+collation)

- 📘 **Docs:**  
  - [Collation and Unicode Support](https://learn.microsoft.com/en-us/sql/relational-databases/collations/collation-and-unicode-support)

---

### 2.2 | CI/CS & AI/AS praktisch verstehen
> **Kurzbeschreibung:** Vergleiche/Sortierung in CI/CS und AI/AS; Demo `LIKE`, `ORDER BY`, `JOIN`.

- 📓 **Notebook:**  
  [`08_02_ci_cs_ai_as_demos.ipynb`](08_02_ci_cs_ai_as_demos.ipynb)

- 🎥 **YouTube:**  
  - [Case/Accent Sensitivity Demo](https://www.youtube.com/results?search_query=sql+server+case+accent+sensitivity)

- 📘 **Docs:**  
  - [Windows Collations](https://learn.microsoft.com/en-us/sql/relational-databases/collations/windows-collation-designators)

---

### 2.3 | Windows- vs. SQL-Collations & Versionen (`_100`, `_140`, …)
> **Kurzbeschreibung:** Unterschiede, warum Windows- und neuere Versionen empfohlen sind; Stabilität/Regeln.

- 📓 **Notebook:**  
  [`08_03_windows_vs_sql_collations.ipynb`](08_03_windows_vs_sql_collations.ipynb)

- 🎥 **YouTube:**  
  - [Windows vs SQL Collations](https://www.youtube.com/results?search_query=sql+server+windows+vs+sql+collation)

- 📘 **Docs:**  
  - [Choose a Collation](https://learn.microsoft.com/en-us/sql/relational-databases/collations/choose-a-collation)

---

### 2.4 | Kollation setzen: Server/DB/Spalte/Ausdruck
> **Kurzbeschreibung:** Defaults, `CREATE/ALTER DATABASE … COLLATE`, Spalten mit abweichender Collation, Ausdrucksebene `COLLATE`.

- 📓 **Notebook:**  
  [`08_04_collation_scope_setzen.ipynb`](08_04_collation_scope_setzen.ipynb)

- 🎥 **YouTube:**  
  - [Set Database Collation](https://www.youtube.com/results?search_query=sql+server+alter+database+collate)

- 📘 **Docs:**  
  - [`COLLATE` clause](https://learn.microsoft.com/en-us/sql/t-sql/statements/collations-transact-sql)  
  - [Set or Change the Server Collation](https://learn.microsoft.com/en-us/sql/relational-databases/collations/set-or-change-the-server-collation)

---

### 2.5 | Kollationspräzedenz & Konflikte lösen
> **Kurzbeschreibung:** „Cannot resolve collation conflict…“ verstehen; `COLLATE DATABASE_DEFAULT` und gezielte Overrides.

- 📓 **Notebook:**  
  [`08_05_collation_praezedenz_konflikte.ipynb`](08_05_collation_praezedenz_konflikte.ipynb)

- 🎥 **YouTube:**  
  - [Resolve Collation Conflict](https://www.youtube.com/results?search_query=sql+server+resolve+collation+conflict)

- 📘 **Docs:**  
  - [Collation Precedence](https://learn.microsoft.com/en-us/sql/t-sql/statements/collation-precedence-transact-sql)

---

### 2.6 | UTF-8 & Unicode: `_UTF8`, `_SC`, `varchar` vs `nvarchar`
> **Kurzbeschreibung:** Wann UTF-8 nutzen, Speicher/Interop, `_SC` für Supplementary Characters, Migrationshinweise.

- 📓 **Notebook:**  
  [`08_06_utf8_unicode_sc.ipynb`](08_06_utf8_unicode_sc.ipynb)

- 🎥 **YouTube:**  
  - [UTF-8 in SQL Server](https://www.youtube.com/results?search_query=sql+server+utf8+collation)

- 📘 **Docs:**  
  - [UTF-8 Support](https://learn.microsoft.com/en-us/sql/relational-databases/collations/collation-and-unicode-support#utf-8-support)  
  - [Supplementary Characters (SC)](https://learn.microsoft.com/en-us/sql/relational-databases/collations/supplementary-characters)

---

### 2.7 | Binäre Collations (BIN/BIN2) & Performance
> **Kurzbeschreibung:** Deterministische Vergleiche, Sortierreihenfolge, wann BIN2 vorteilhaft ist.

- 📓 **Notebook:**  
  [`08_07_binary_collations_bin2.ipynb`](08_07_binary_collations_bin2.ipynb)

- 🎥 **YouTube:**  
  - [Binary Collations Explained](https://www.youtube.com/results?search_query=sql+server+binary+collation+bin2)

- 📘 **Docs:**  
  - [Binary Collations](https://learn.microsoft.com/en-us/sql/relational-databases/collations/binary-collations)

---

### 2.8 | tempdb-Collation & `#temp`-Fallstricke
> **Kurzbeschreibung:** `#temp` erbt `tempdb`-Collation; Cross-DB-Join/Compare mit `COLLATE` absichern.

- 📓 **Notebook:**  
  [`08_08_tempdb_collation_issues.ipynb`](08_08_tempdb_collation_issues.ipynb)

- 🎥 **YouTube:**  
  - [tempdb Collation Mismatch](https://www.youtube.com/results?search_query=sql+server+tempdb+collation+mismatch)

- 📘 **Docs:**  
  - [Resolve Collation Conflicts (tempdb)](https://learn.microsoft.com/en-us/sql/relational-databases/databases/tempdb-database#about-collations)

---

### 2.9 | Joins & Vergleiche über verschiedene Collations
> **Kurzbeschreibung:** `JOIN`/`UNION`/`EXCEPT`-Verhalten bei unterschiedlichen Collations; gezielt casten/collaten.

- 📓 **Notebook:**  
  [`08_09_joins_vergleiche_collations.ipynb`](08_09_joins_vergleiche_collations.ipynb)

- 🎥 **YouTube:**  
  - [Joins with Different Collations](https://www.youtube.com/results?search_query=sql+server+join+different+collations)

- 📘 **Docs:**  
  - [`COLLATE` in expressions](https://learn.microsoft.com/en-us/sql/t-sql/statements/collations-transact-sql#collation-in-expressions)

---

### 2.10 | Indexe, SARGability & Case-insensitive Suchen
> **Kurzbeschreibung:** Index-Seeks bei CI/CS; `WHERE Col LIKE 'abc%'` vs. Funktionen; ggf. **persistierte** berechnete Spalte mit gezielter Collation + Index.

- 📓 **Notebook:**  
  [`08_10_index_sargability_collation.ipynb`](08_10_index_sargability_collation.ipynb)

- 🎥 **YouTube:**  
  - [Indexing for Case-Insensitive Search](https://www.youtube.com/results?search_query=sql+server+index+case+insensitive)

- 📘 **Docs:**  
  - [Index Sort Order & Collation](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/create-indexes#sort-order)  
  - [Computed Columns & Indexes](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/indexes-on-computed-columns)

---

### 2.11 | `LIKE`, Muster & sprachspezifische Regeln
> **Kurzbeschreibung:** Einfluss der Collation auf `LIKE`-Vergleiche, Akzent-/Großschreibung, Escapes.

- 📓 **Notebook:**  
  [`08_11_like_patterns_collation.ipynb`](08_11_like_patterns_collation.ipynb)

- 🎥 **YouTube:**  
  - [LIKE and Collation](https://www.youtube.com/results?search_query=sql+server+like+collation)

- 📘 **Docs:**  
  - [`LIKE` (T-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/like-transact-sql)

---

### 2.12 | Sortierung & `ORDER BY … COLLATE`
> **Kurzbeschreibung:** Linguistische Sortierung vs. binär; abweichende Sortierreihenfolge pro Abfrage erzwingen.

- 📓 **Notebook:**  
  [`08_12_order_by_collate.ipynb`](08_12_order_by_collate.ipynb)

- 🎥 **YouTube:**  
  - [ORDER BY with Collation](https://www.youtube.com/results?search_query=sql+server+order+by+collate)

- 📘 **Docs:**  
  - [Sort Order & Collation](https://learn.microsoft.com/en-us/sql/relational-databases/collations/collation-and-unicode-support#sort-order)

---

### 2.13 | Funktionen & Collation (UPPER/LOWER, String-OPS)
> **Kurzbeschreibung:** Sprachabhängige Regeln (z. B. Türkisch „I/i“), deterministische Ergebnisse, Tests.

- 📓 **Notebook:**  
  [`08_13_functions_and_collation.ipynb`](08_13_functions_and_collation.ipynb)

- 🎥 **YouTube:**  
  - [Turkish I Problem](https://www.youtube.com/results?search_query=sql+server+turkish+i+collation)

- 📘 **Docs:**  
  - [Effects of Collation on Comparisons](https://learn.microsoft.com/en-us/sql/relational-databases/collations/set-or-change-the-server-collation#effects-of-collation)

---

### 2.14 | Internationalisierung: Sprachen & Spezialfälle
> **Kurzbeschreibung:** ß/SS, Ligaturen, Kana/Width, Culture-Tests; Auswahl einer passenden Collation.

- 📓 **Notebook:**  
  [`08_14_internationalisierung_collation.ipynb`](08_14_internationalisierung_collation.ipynb)

- 🎥 **YouTube:**  
  - [Choosing the Right Collation](https://www.youtube.com/results?search_query=sql+server+choose+collation)

- 📘 **Docs:**  
  - [Windows Collation Designators](https://learn.microsoft.com/en-us/sql/relational-databases/collations/windows-collation-name)

---

### 2.15 | Migration/Änderung der Collation (DB/Spalten)
> **Kurzbeschreibung:** Vorgehen, Risiken (Indizes, Persisted Computed Columns, Sortierregeln), Skripting & Tests.

- 📓 **Notebook:**  
  [`08_15_collation_migration_change.ipynb`](08_15_collation_migration_change.ipynb)

- 🎥 **YouTube:**  
  - [Change Database/Column Collation](https://www.youtube.com/results?search_query=sql+server+change+database+collation)

- 📘 **Docs:**  
  - [Set/Change Database Collation](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-database-transact-sql-collate)  
  - [Change Column Collation](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-table-alter-column-transact-sql)

---

### 2.16 | Anti-Patterns & Checkliste
> **Kurzbeschreibung:** Misch-Collations ohne `COLLATE`, `NOT` dokumentierte Kulturfeinheiten ignorieren, `SELECT *`-Vergleiche ohne explizite Collation in ETL, `@Temp`/`#Temp`-Mismatches, alte SQL-Collations weiterverwenden, `varchar` ohne UTF-8/Unicode für internationale Daten.

- 📓 **Notebook:**  
  [`08_16_collation_antipatterns_checkliste.ipynb`](08_16_collation_antipatterns_checkliste.ipynb)

- 🎥 **YouTube:**  
  - [Common Collation Mistakes](https://www.youtube.com/results?search_query=sql+server+collation+mistakes)

- 📘 **Docs/Blog:**  
  - [Best Practices & Collation Precedence](https://learn.microsoft.com/en-us/sql/t-sql/statements/collation-precedence-transact-sql)

---

## 3 | Weiterführende Informationen

- 📘 Microsoft Learn: [Collation & Unicode Support (Übersicht)](https://learn.microsoft.com/en-us/sql/relational-databases/collations/collation-and-unicode-support)  
- 📘 Microsoft Learn: [`COLLATE`-Klausel (Ausdruck/Spalte/DB)](https://learn.microsoft.com/en-us/sql/t-sql/statements/collations-transact-sql)  
- 📘 Microsoft Learn: [Collation Precedence (Regeln & Beispiele)](https://learn.microsoft.com/en-us/sql/t-sql/statements/collation-precedence-transact-sql)  
- 📘 Microsoft Learn: [Windows vs SQL Collations & Namensschema](https://learn.microsoft.com/en-us/sql/relational-databases/collations/windows-collation-designators)  
- 📘 Microsoft Learn: [UTF-8-Collations in SQL Server 2019+](https://learn.microsoft.com/en-us/sql/relational-databases/collations/collation-and-unicode-support#utf-8-support)  
- 📘 Microsoft Learn: [Supplementary Characters (`_SC`) – NVARCHAR](https://learn.microsoft.com/en-us/sql/relational-databases/collations/supplementary-characters)  
- 📘 Microsoft Learn: [Server/DB-Collation setzen/ändern](https://learn.microsoft.com/en-us/sql/relational-databases/collations/set-or-change-the-server-collation)  
- 📘 Microsoft Learn: [`ALTER DATABASE … COLLATE`](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-database-transact-sql-collate) · [`ALTER TABLE … ALTER COLUMN … COLLATE`](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-table-alter-column-transact-sql)  
- 📘 Microsoft Learn: [Binary Collations (BIN/BIN2)](https://learn.microsoft.com/en-us/sql/relational-databases/collations/binary-collations)  
- 📘 Microsoft Learn: [tempdb – Hinweise (Collation)](https://learn.microsoft.com/en-us/sql/relational-databases/databases/tempdb-database#about-collations)  
- 📝 SQLPerformance: *Collations, Indexes & SARGability* – https://www.sqlperformance.com/?s=collation  
- 📝 Brent Ozar: *Resolving Collation Conflicts* – https://www.brentozar.com/  
- 📝 Erik Darling: *CI vs CS in Joins & Searches* – https://www.erikdarlingdata.com/  
- 📝 Redgate Simple Talk: *Working with Collations in SQL Server* – https://www.red-gate.com/simple-talk/  
- 🎥 YouTube (Data Exposed): *Collation Deep Dive* – Suchlink  
- 🎥 YouTube: *UTF-8 & BIN2 in Practice* – Suchlink  
