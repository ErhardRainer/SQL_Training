# T-SQL PIVOT / UNPIVOT – Übersicht

## 1 | Begriffsdefinition

| SQL-Term | Beschreibung |
|---|---|
| `PIVOT` | Dreht **Zeilenwerte** einer Spalte in **Spaltenüberschriften** und berechnet je Spalte ein Aggregat (`SUM`, `COUNT`, …). |
| `UNPIVOT` | Dreht **Spalten** in **Zeilen** (entnormalisiert → normalisiert); erzeugt zwei Spalten: *Attributname* und *Wert*. |
| Maß (Measure) | Aggregierte Zielspalte im `PIVOT` (z. B. `SUM(Amount)`); pro Pivot-Vorgang genau **ein** Aggregat. |
| Dimension(en) | Gruppierungsspalten, die in den **Zeilen** verbleiben (z. B. `Year`, `CustomerId`). |
| Pivot-Schlüssel | Spalte, deren **distinct**-Werte zu Spalten werden (z. B. `MonthName` → `Jan`, `Feb`, …). |
| Statisches vs. dynamisches PIVOT | Statisch: Spaltenliste ist **fest** im SQL kodiert; dynamisch: Spaltenliste wird per **dynamischem SQL** zur Laufzeit erzeugt. |
| Fehlende Werte | Wenn keine passende Quellzeile existiert, liefert `PIVOT` **`NULL`**; oft mit `ISNULL/COALESCE` post-processen. |
| Doppelte Pivot-Schlüssel | Mehrere Quellzeilen pro (Dimension, Pivot-Schlüssel) werden durch das Aggregat zusammengefasst (z. B. `SUM`). |
| Mehrere Measures | Pro `PIVOT` nur **ein** Aggregat; mehrere Measures über mehrere `PIVOT`s joinen oder bedingte Aggregation (`GROUP BY + CASE`) verwenden. |
| Alternativen | Kreuztabellen via `GROUP BY` + `CASE` (oft performanter und flexibler); `UNPIVOT`-Alternative: `CROSS APPLY (VALUES …)`. |
| SARGability | `PIVOT/UNPIVOT` sind **Formattierung/Transformation**; Filter möglichst **vorher** anwenden, um Datenmenge zu reduzieren. |
| Namensbehandlung | Spalten, die aus Werten entstehen, mit `QUOTENAME()` korrekt quoten (Sonderzeichen/Leerzeichen). |
| Typ-/Kollationskonflikte | `UNPIVOT` erwartet **typkompatible** Spalten; bei gemischten Typen explizit casten/konvertieren. |

---

## 2 | Struktur

### 2.1 | Grundlagen: `PIVOT` & `UNPIVOT` – Syntax & Ablauf
> **Kurzbeschreibung:** Minimale Beispiele, erforderliche Clauses, logische Reihenfolge (`FROM` → `PIVOT/UNPIVOT` → Projektion).

- 📓 **Notebook:**  
  [`08_01_pivot_unpivot_grundlagen.ipynb`](08_01_pivot_unpivot_grundlagen.ipynb)

- 🎥 **YouTube:**  
  - [PIVOT / UNPIVOT – Basics](https://www.youtube.com/results?search_query=sql+server+pivot+unpivot+tutorial)

- 📘 **Docs:**  
  - [Using `PIVOT` and `UNPIVOT` (T-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/queries/from-using-pivot-and-unpivot)

---

### 2.2 | PIVOT vs. `GROUP BY` + `CASE`
> **Kurzbeschreibung:** Wann Kreuztabellen mit `GROUP BY`+`CASE` vorzuziehen sind (mehrere Measures, bessere Kontrolle).

- 📓 **Notebook:**  
  [`08_02_pivot_vs_groupby_case.ipynb`](08_02_pivot_vs_groupby_case.ipynb)

- 🎥 **YouTube:**  
  - [Cross Tab with CASE](https://www.youtube.com/results?search_query=sql+server+group+by+case+cross+tab)

- 📘 **Docs:**  
  - [`CASE` Expression](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/case-transact-sql)

---

### 2.3 | UNPIVOT vs. `CROSS APPLY (VALUES …)`
> **Kurzbeschreibung:** Flexibles Entzivieren von Spalten mit `VALUES`; Vorteile ggü. `UNPIVOT` (Typkontrolle, mehrere Datentypen).

- 📓 **Notebook:**  
  [`08_03_unpivot_vs_cross_apply_values.ipynb`](08_03_unpivot_vs_cross_apply_values.ipynb)

- 🎥 **YouTube:**  
  - [UNPIVOT Alternatives](https://www.youtube.com/results?search_query=sql+server+unpivot+cross+apply+values)

- 📘 **Docs:**  
  - [`APPLY`-Operator](https://learn.microsoft.com/en-us/sql/t-sql/queries/from-transact-sql#apply-operator)

---

### 2.4 | Dynamisches PIVOT mit `STRING_AGG` + `QUOTENAME` + `sp_executesql`
> **Kurzbeschreibung:** Spaltenliste zur Laufzeit erzeugen, sicher quoten, Parameterisierung & SQL-Injection vermeiden.

- 📓 **Notebook:**  
  [`08_04_dynamisches_pivot.ipynb`](08_04_dynamisches_pivot.ipynb)

- 🎥 **YouTube:**  
  - [Dynamic PIVOT in SQL Server](https://www.youtube.com/results?search_query=sql+server+dynamic+pivot)

- 📘 **Docs:**  
  - [`STRING_AGG`](https://learn.microsoft.com/en-us/sql/t-sql/functions/string-agg-transact-sql) · [`QUOTENAME`](https://learn.microsoft.com/en-us/sql/t-sql/functions/quotename-transact-sql)  
  - [`sp_executesql`](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-executesql-transact-sql)

---

### 2.5 | Mehrere Measures pivotieren
> **Kurzbeschreibung:** Techniken für mehrere Kennzahlen: mehrere `PIVOT`s joinen, `GROUP BY`+`CASE`, Common Table Expressions.

- 📓 **Notebook:**  
  [`08_05_pivot_mehrere_measures.ipynb`](08_05_pivot_mehrere_measures.ipynb)

- 🎥 **YouTube:**  
  - [Pivot Multiple Aggregates](https://www.youtube.com/results?search_query=sql+server+pivot+multiple+aggregates)

- 📘 **Docs:**  
  - [`PIVOT` – Remarks & Examples](https://learn.microsoft.com/en-us/sql/t-sql/queries/from-using-pivot-and-unpivot#examples)

---

### 2.6 | Null-Handling, Default-Werte & Formatierung
> **Kurzbeschreibung:** Fehlende Zellen mit `ISNULL/COALESCE` füllen, Spalten sortieren/benennen, Ausgabe fürs Reporting aufbereiten.

- 📓 **Notebook:**  
  [`08_06_pivot_nulls_defaults_format.ipynb`](08_06_pivot_nulls_defaults_format.ipynb)

- 🎥 **YouTube:**  
  - [Handling NULLs in PIVOT](https://www.youtube.com/results?search_query=sql+server+pivot+null+isnull)

- 📘 **Docs:**  
  - [`ISNULL` / `COALESCE`](https://learn.microsoft.com/en-us/sql/t-sql/functions/isnull-transact-sql)

---

### 2.7 | Typen, Kollation & Spaltennamen
> **Kurzbeschreibung:** Typvereinheitlichung für `UNPIVOT`, Kollation bei Zeichenfeldern, `QUOTENAME` gegen problematische Namen.

- 📓 **Notebook:**  
  [`08_07_typen_kollation_spaltennamen.ipynb`](08_07_typen_kollation_spaltennamen.ipynb)

- 🎥 **YouTube:**  
  - [Collation & Pivot Gotchas](https://www.youtube.com/results?search_query=sql+server+pivot+collation)

- 📘 **Docs:**  
  - [Data Type Precedence](https://learn.microsoft.com/en-us/sql/t-sql/data-types/data-type-precedence-transact-sql)  
  - [Collation Precedence](https://learn.microsoft.com/en-us/sql/t-sql/statements/collation-precedence-transact-sql)

---

### 2.8 | Performance: Pläne, Sort/Hash & Prädikat-Pushdown
> **Kurzbeschreibung:** Warum `PIVOT` oft als `GROUP BY`+`CASE` kompiliert, Einfluss von Indizes/Statistiken, Prädikate früh anwenden.

- 📓 **Notebook:**  
  [`08_08_performance_pivot_plans.ipynb`](08_08_performance_pivot_plans.ipynb)

- 🎥 **YouTube:**  
  - [PIVOT Performance Analysis](https://www.youtube.com/results?search_query=sql+server+pivot+performance)

- 📘 **Docs:**  
  - [Query Processing Architecture Guide](https://learn.microsoft.com/en-us/sql/relational-databases/query-processing-architecture-guide)  
  - [Cardinality Estimation – Overview](https://learn.microsoft.com/en-us/sql/relational-databases/performance/cardinality-estimation-overview)

---

### 2.9 | Columnstore & große Kreuztabellen
> **Kurzbeschreibung:** PIVOT/UNPIVOT auf großen, spaltenbasierten Tabellen (Segment-/Batchmode), Worktable-Verhalten verstehen.

- 📓 **Notebook:**  
  [`08_09_pivot_columnstore.ipynb`](08_09_pivot_columnstore.ipynb)

- 🎥 **YouTube:**  
  - [Columnstore & Aggregations](https://www.youtube.com/results?search_query=sql+server+columnstore+aggregation)

- 📘 **Docs:**  
  - [Columnstore Indexes – Query Performance](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/columnstore-indexes-query-performance)

---

### 2.10 | JSON & halbstrukturierte Daten: `OPENJSON` → PIVOT
> **Kurzbeschreibung:** JSON auf Zeilen shreddern und anschließend pivotieren; robust mit `CROSS APPLY OPENJSON`.

- 📓 **Notebook:**  
  [`08_10_json_openjson_pivot.ipynb`](08_10_json_openjson_pivot.ipynb)

- 🎥 **YouTube:**  
  - [OPENJSON + PIVOT](https://www.youtube.com/results?search_query=sql+server+openjson+pivot)

- 📘 **Docs:**  
  - [`OPENJSON`](https://learn.microsoft.com/en-us/sql/t-sql/functions/openjson-transact-sql)  
  - [JSON in SQL Server](https://learn.microsoft.com/en-us/sql/relational-databases/json/json-data-sql-server)

---

### 2.11 | Zeitliche Pivotierungen (Monat/Quartal/Jahr)
> **Kurzbeschreibung:** Kalenderdimensionen verwenden, Lücken füllen, `EOMONTH`/`DATEADD`/`FORMAT` gezielt einsetzen.

- 📓 **Notebook:**  
  [`08_11_zeitliche_pivotierungen.ipynb`](08_11_zeitliche_pivotierungen.ipynb)

- 🎥 **YouTube:**  
  - [Pivot by Month/Quarter](https://www.youtube.com/results?search_query=sql+server+pivot+by+month)

- 📘 **Docs:**  
  - [Date & Time Functions](https://learn.microsoft.com/en-us/sql/t-sql/functions/date-and-time-data-types-and-functions-transact-sql)

---

### 2.12 | Geordnete Ausgabe & Spaltenreihenfolge
> **Kurzbeschreibung:** Spalten in gewünschter Reihenfolge ausgeben (explizite Liste), Ergebniszeilen mit `ORDER BY` sortieren.

- 📓 **Notebook:**  
  [`08_12_spaltenreihenfolge_sortierung.ipynb`](08_12_spaltenreihenfolge_sortierung.ipynb)

- 🎥 **YouTube:**  
  - [Order Pivot Columns](https://www.youtube.com/results?search_query=sql+server+order+pivot+columns)

- 📘 **Docs:**  
  - [`ORDER BY` – Gesamtergebnis](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-order-by-clause-transact-sql)

---

### 2.13 | Sicherheit, RLS & Berechtigungen
> **Kurzbeschreibung:** `SELECT`-Rechte, Spaltensichtbarkeit, RLS-Filter/Block-Predicates beeinflussen Quellmenge.

- 📓 **Notebook:**  
  [`08_13_sicherheit_rls_pivot.ipynb`](08_13_sicherheit_rls_pivot.ipynb)

- 🎥 **YouTube:**  
  - [Row-Level Security – Overview](https://www.youtube.com/results?search_query=sql+server+row+level+security)

- 📘 **Docs:**  
  - [Row-Level Security](https://learn.microsoft.com/en-us/sql/relational-databases/security/row-level-security)

---

### 2.14 | Tests & Qualität: Vergleich mit Erwartungsraster
> **Kurzbeschreibung:** Pivot-Ergebnis gegen Soll-Schema prüfen (z. B. erwartete Spaltenmenge, `EXCEPT`/`INTERSECT` für Delta).

- 📓 **Notebook:**  
  [`08_14_tests_qualitaet_pivot.ipynb`](08_14_tests_qualitaet_pivot.ipynb)

- 🎥 **YouTube:**  
  - [Validate Pivot Results](https://www.youtube.com/results?search_query=sql+server+validate+pivot)

- 📘 **Docs:**  
  - [`EXCEPT` / `INTERSECT`](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/set-operators-except-and-intersect-transact-sql)

---

### 2.15 | Praxis-Patterns (EAV → Cross-Tab, Metrikmatrizen)
> **Kurzbeschreibung:** Entity-Attribute-Value in Reporting-Form bringen; Datenbereinigung vor dem Pivot.

- 📓 **Notebook:**  
  [`08_15_praxis_patterns_eav_crosstab.ipynb`](08_15_praxis_patterns_eav_crosstab.ipynb)

- 🎥 **YouTube:**  
  - [EAV to Crosstab](https://www.youtube.com/results?search_query=sql+server+eav+pivot)

- 📘 **Docs:**  
  - [Using `PIVOT` – Examples](https://learn.microsoft.com/en-us/sql/t-sql/queries/from-using-pivot-and-unpivot#examples)

---

### 2.16 | Anti-Patterns & Fallstricke
> **Kurzbeschreibung:** Dynamisches Pivot ohne Whitelisting, ungecastete gemischte Typen beim `UNPIVOT`, Aggregat-Duplikate durch unscharfe Dimensionen.

- 📓 **Notebook:**  
  [`08_16_pivot_unpivot_anti_patterns.ipynb`](08_16_pivot_unpivot_anti_patterns.ipynb)

- 🎥 **YouTube:**  
  - [Common PIVOT Mistakes](https://www.youtube.com/results?search_query=sql+server+pivot+mistakes)

- 📘 **Docs/Blog:**  
  - [Implicit Conversions & Precedence](https://learn.microsoft.com/en-us/sql/t-sql/functions/cast-and-convert-transact-sql)  
  - [Security & Injection (Dynamic SQL)](https://learn.microsoft.com/en-us/sql/relational-databases/stored-procedures/execute-dynamic-sql)

---

## 3 | Weiterführende Informationen

- 📘 Microsoft Learn: [Using `PIVOT` and `UNPIVOT` (T-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/queries/from-using-pivot-and-unpivot)  
- 📘 Microsoft Learn: [`CASE` Expression](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/case-transact-sql)  
- 📘 Microsoft Learn: [`APPLY`-Operator (`CROSS/OUTER`)](https://learn.microsoft.com/en-us/sql/t-sql/queries/from-transact-sql#apply-operator)  
- 📘 Microsoft Learn: [`STRING_AGG`](https://learn.microsoft.com/en-us/sql/t-sql/functions/string-agg-transact-sql) · [`QUOTENAME`](https://learn.microsoft.com/en-us/sql/t-sql/functions/quotename-transact-sql) · [`sp_executesql`](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-executesql-transact-sql)  
- 📘 Microsoft Learn: [Date & Time Functions](https://learn.microsoft.com/en-us/sql/t-sql/functions/date-and-time-data-types-and-functions-transact-sql)  
- 📘 Microsoft Learn: [Data Type / Collation Precedence](https://learn.microsoft.com/en-us/sql/t-sql/data-types/data-type-precedence-transact-sql) · (Collation) (siehe *Collation Precedence*)  
- 📘 Microsoft Learn: [Columnstore Indexes – Performance](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/columnstore-indexes-query-performance)  
- 📘 Microsoft Learn: [Query Processing Architecture Guide](https://learn.microsoft.com/en-us/sql/relational-databases/query-processing-architecture-guide)  
- 📝 Simple Talk (Redgate): [PIVOT and UNPIVOT in SQL Server](https://www.red-gate.com/simple-talk/databases/sql-server/t-sql-programming-sql-server/using-pivot-and-unpivot/)  
- 📝 SQLShack: [Dynamic PIVOT in SQL Server](https://www.sqlshack.com/dynamic-sql-pivoting-in-sql-server/)  
- 📝 SQLPerformance: [Conditional Aggregation vs. PIVOT](https://www.sqlperformance.com/?s=pivot)  
- 📝 Erik Darling: [UNPIVOT with CROSS APPLY VALUES](https://www.erikdarlingdata.com/)  
- 🎥 YouTube Playlist: [PIVOT/UNPIVOT Tutorials](https://www.youtube.com/results?search_query=sql+server+pivot+unpivot+tutorial)  
