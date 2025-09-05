# T-SQL Set Operations – Übersicht

## 1 | Begriffsdefinition

| SQL-Term | Beschreibung |
|---|---|
| Mengenoperatoren (Set Operations) | Kombinieren Resultsets **zeilenweise**: `UNION [ALL]`, `EXCEPT`, `INTERSECT`. |
| `UNION ALL` | Konkatenation ohne Duplikateliminierung („Bag/Sack“-Semantik). Schnell, kein Sort/Hash-Distinct nötig. |
| `UNION` | Wie `UNION ALL`, aber **DISTINCT** auf dem Gesamtergebnis (Duplikate werden entfernt). |
| `EXCEPT` | Linke Menge **minus** rechte Menge (nur Zeilen, die links vorkommen und rechts nicht). |
| `INTERSECT` | Schnittmenge beider Mengen (nur Zeilen, die in **beiden** vorkommen). |
| Kompatibilitätsregeln | Jede Seite muss **gleiche Spaltenanzahl** liefern; Datentypen je Position müssen kompatibel sein. Spaltennamen des Gesamtergebnisses stammen i. d. R. von der **ersten** Abfrage. |
| `NULL`-Vergleich in Set-Ops | Für Duplikate/Übereinstimmung gelten `NULL`-Werte als **gleich** (anders als bei `=` im Prädikat). |
| Kollation & Typ-Priorität | Unterschiedliche Kollationen/Datentypen je Spaltenposition führen zu **impliziten Konvertierungen**; ggf. `COLLATE`/`CAST` erzwingen. |
| Auswertungsreihenfolge | Kombination mehrerer Operatoren kann überraschend sein – **Klammern** verwenden; `ORDER BY` gilt nur **für das Gesamtergebnis**. |
| Ordnung & Pagination | Reihenfolge ist **ohne globales `ORDER BY` nicht garantiert**; `ORDER BY` innerhalb eines Teil-SELECTs wird ignoriert (außer in Verbindung mit `TOP`). |
| Performance | `UNION`/`EXCEPT`/`INTERSECT` benötigen für Distinct/Abgleich Sort/Hash; `UNION ALL` ist meist günstiger. |
| Alternativen | `EXISTS`/`NOT EXISTS` oder `LEFT JOIN … IS NULL` als semantische Alternativen; Wahl nach Lesbarkeit/Performance. |

---

## 2 | Struktur

### 2.1 | Set-Operatoren: Überblick & Syntax
> **Kurzbeschreibung:** Grundsyntax, wann welche Operation sinnvoll ist, typische Einsatzfälle.

- 📓 **Notebook:**  
  [`08_01_setops_grundlagen.ipynb`](08_01_setops_grundlagen.ipynb)

- 🎥 **YouTube:**  
  - [UNION / EXCEPT / INTERSECT – Basics](https://www.youtube.com/results?search_query=sql+server+union+except+intersect)  
  - [Set Operators vs Joins (Kurzüberblick)](https://www.youtube.com/results?search_query=sql+server+set+operators+vs+joins)

- 📘 **Docs:**  
  - [`UNION` (T-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/set-operators-union-transact-sql)  
  - [`EXCEPT` & `INTERSECT` (T-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/set-operators-except-and-intersect-transact-sql)

---

### 2.2 | `UNION ALL` vs. `UNION`
> **Kurzbeschreibung:** Duplikate behalten oder entfernen; Auswirkungen auf Pläne, Speicher und Laufzeit.

- 📓 **Notebook:**  
  [`08_02_union_all_vs_union.ipynb`](08_02_union_all_vs_union.ipynb)

- 🎥 **YouTube:**  
  - [UNION vs UNION ALL – Performance](https://www.youtube.com/results?search_query=sql+server+union+vs+union+all)

- 📘 **Docs:**  
  - [`UNION` – Details & Beispiele](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/set-operators-union-transact-sql)

---

### 2.3 | `EXCEPT` – Differenzmengen
> **Kurzbeschreibung:** Records in A, die **nicht** in B sind; Dublettenverhalten, Vergleich mit `NOT EXISTS`.

- 📓 **Notebook:**  
  [`08_03_except_patterns.ipynb`](08_03_except_patterns.ipynb)

- 🎥 **YouTube:**  
  - [EXCEPT vs NOT EXISTS](https://www.youtube.com/results?search_query=sql+server+except+vs+not+exists)

- 📘 **Docs:**  
  - [`EXCEPT` (T-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/set-operators-except-and-intersect-transact-sql#except)

---

### 2.4 | `INTERSECT` – Schnittmengen
> **Kurzbeschreibung:** Überschneidungen zwischen Resultsets; Vergleich mit `INNER JOIN` + `DISTINCT`.

- 📓 **Notebook:**  
  [`08_04_intersect_patterns.ipynb`](08_04_intersect_patterns.ipynb)

- 🎥 **YouTube:**  
  - [INTERSECT – Beispiele](https://www.youtube.com/results?search_query=sql+server+intersect+tutorial)

- 📘 **Docs:**  
  - [`INTERSECT` (T-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/set-operators-except-and-intersect-transact-sql#intersect)

---

### 2.5 | Kompatibilitätsregeln & Spaltenableitung
> **Kurzbeschreibung:** Spaltenanzahl/-reihenfolge, Typkompatibilität, Namensableitung aus dem ersten SELECT.

- 📓 **Notebook:**  
  [`08_05_kompatibilitaet_spaltenableitung.ipynb`](08_05_kompatibilitaet_spaltenableitung.ipynb)

- 🎥 **YouTube:**  
  - [Set Operator Rules](https://www.youtube.com/results?search_query=sql+server+set+operators+rules)

- 📘 **Docs:**  
  - [Data Type Precedence](https://learn.microsoft.com/en-us/sql/t-sql/data-types/data-type-precedence-transact-sql)  
  - [Implicit Conversions](https://learn.microsoft.com/en-us/sql/t-sql/functions/cast-and-convert-transact-sql)

---

### 2.6 | `ORDER BY`, `TOP`, `OFFSET/FETCH` in Set-Abfragen
> **Kurzbeschreibung:** Ordnung für das **Gesamtergebnis**; `TOP` pro Zweig mit Klammern, Pagination richtig platzieren.

- 📓 **Notebook:**  
  [`08_06_order_by_top_offset_in_setops.ipynb`](08_06_order_by_top_offset_in_setops.ipynb)

- 🎥 **YouTube:**  
  - [ORDER BY with UNION – Do’s & Don’ts](https://www.youtube.com/results?search_query=order+by+with+union+sql+server)

- 📘 **Docs:**  
  - [`ORDER BY` (T-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-order-by-clause-transact-sql)  
  - [`TOP` (T-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/queries/top-transact-sql)

---

### 2.7 | Klammerung & Auswertungsreihenfolge
> **Kurzbeschreibung:** Gemischte Operatoren sicher kombinieren; Klammern erzwingen die intendierte Logik.

- 📓 **Notebook:**  
  [`08_07_klammerung_auswertungsreihenfolge.ipynb`](08_07_klammerung_auswertungsreihenfolge.ipynb)

- 🎥 **YouTube:**  
  - [Operator Precedence in Set Operations](https://www.youtube.com/results?search_query=sql+server+intersect+except+union+precedence)

- 📘 **Docs:**  
  - [Set Operators – Remarks/Precedence](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/set-operators-except-and-intersect-transact-sql#remarks)

---

### 2.8 | `NULL`-Semantik & Duplikatelogik
> **Kurzbeschreibung:** Warum zwei `NULL`-Zeilen als gleich gelten; Auswirkungen auf `UNION`/`EXCEPT`/`INTERSECT`.

- 📓 **Notebook:**  
  [`08_08_null_semantik_setops.ipynb`](08_08_null_semantik_setops.ipynb)

- 🎥 **YouTube:**  
  - [NULLs in Set Operators](https://www.youtube.com/results?search_query=sql+server+null+set+operators)

- 📘 **Docs:**  
  - [NULL (T-SQL) – Verhalten](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/null-transact-sql)

---

### 2.9 | Typkonvertierung & Kollation
> **Kurzbeschreibung:** Probleme mit `varchar`/`nvarchar`, Zahlenpräzision; `COLLATE` explizit setzen, wenn nötig.

- 📓 **Notebook:**  
  [`08_09_typkonvertierung_kollation.ipynb`](08_09_typkonvertierung_kollation.ipynb)

- 🎥 **YouTube:**  
  - [Collation Conflicts – Fix with COLLATE](https://www.youtube.com/results?search_query=sql+server+collation+conflict+collate)

- 📘 **Docs:**  
  - [Collation Precedence](https://learn.microsoft.com/en-us/sql/t-sql/statements/collation-precedence-transact-sql)  
  - [`CAST`/`CONVERT`/`TRY_CONVERT`](https://learn.microsoft.com/en-us/sql/t-sql/functions/cast-and-convert-transact-sql)

---

### 2.10 | Performance: Sort/Hash, Pläne & CE
> **Kurzbeschreibung:** Wie SQL Server Duplikate eliminiert/abgleicht (Sort/Hash Match), CE-Auswirkungen & Indexnutzung.

- 📓 **Notebook:**  
  [`08_10_performance_plaene_setops.ipynb`](08_10_performance_plaene_setops.ipynb)

- 🎥 **YouTube:**  
  - [UNION vs UNION ALL – Plan Analysis](https://www.youtube.com/results?search_query=sql+server+union+execution+plan)

- 📘 **Docs:**  
  - [Query Processing Architecture](https://learn.microsoft.com/en-us/sql/relational-databases/query-processing-architecture-guide)  
  - [Cardinality Estimation – Overview](https://learn.microsoft.com/en-us/sql/relational-databases/performance/cardinality-estimation-overview)

---

### 2.11 | Deduplizierung: `UNION` vs. `GROUP BY`/`DISTINCT`
> **Kurzbeschreibung:** Wann `UNION` genügt, wann `UNION ALL` + `GROUP BY`/`DISTINCT` sinnvoller ist (z. B. späteres Aggregat).

- 📓 **Notebook:**  
  [`08_11_deduplizierung_mit_setops.ipynb`](08_11_deduplizierung_mit_setops.ipynb)

- 🎥 **YouTube:**  
  - [Removing Duplicates in SQL Server](https://www.youtube.com/results?search_query=sql+server+remove+duplicates+distinct+group+by)

- 📘 **Docs:**  
  - [`DISTINCT` in `SELECT`](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-transact-sql#use-distinct)  
  - [`GROUP BY`](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-group-by-transact-sql)

---

### 2.12 | `EXCEPT` vs. `NOT EXISTS` / Anti-Join
> **Kurzbeschreibung:** Unterschiedliche Lesbarkeit & Planformen; NULL-Sonderfälle und Duplikate beachten.

- 📓 **Notebook:**  
  [`08_12_except_vs_notexists.ipynb`](08_12_except_vs_notexists.ipynb)

- 🎥 **YouTube:**  
  - [Anti-Join Patterns](https://www.youtube.com/results?search_query=sql+server+anti+join+not+exists+except)

- 📘 **Docs/Blog:**  
  - [`EXISTS` (T-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/exists-transact-sql)  
  - [Left Join / Anti-Join – Konzeptartikel](https://learn.microsoft.com/en-us/sql/relational-databases/performance/joins)

---

### 2.13 | `INTERSECT` vs. `INNER JOIN`
> **Kurzbeschreibung:** Schnittmenge als Distinct-Join; Mehrspalten-Schnitt vs. Join auf Schlüssel.

- 📓 **Notebook:**  
  [`08_13_intersect_vs_join.ipynb`](08_13_intersect_vs_join.ipynb)

- 🎥 **YouTube:**  
  - [INTERSECT vs INNER JOIN](https://www.youtube.com/results?search_query=sql+server+intersect+vs+join)

- 📘 **Docs:**  
  - [`INTERSECT` – Referenz](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/set-operators-except-and-intersect-transact-sql#intersect)  
  - [JOINs – Überblick](https://learn.microsoft.com/en-us/sql/relational-databases/performance/joins)

---

### 2.14 | Set-Ops mit Aggregation & Fensterfunktionen
> **Kurzbeschreibung:** Ergebnisse aus unterschiedlichen Aggregationen kombinieren; Window-Berechnungen je Zweig.

- 📓 **Notebook:**  
  [`08_14_setops_mit_aggregation_window.ipynb`](08_14_setops_mit_aggregation_window.ipynb)

- 🎥 **YouTube:**  
  - [Unioning Aggregates & Windows](https://www.youtube.com/results?search_query=sql+server+union+window+functions)

- 📘 **Docs:**  
  - [`OVER`-Klausel](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-over-clause-transact-sql)  
  - [Aggregate Functions](https://learn.microsoft.com/en-us/sql/t-sql/functions/aggregate-functions-transact-sql)

---

### 2.15 | Praktische Patterns: Staging, Historisierung, Multi-Quelle
> **Kurzbeschreibung:** Berichte aus heterogenen Quellen, Staging-Tabellen **vereinheitlichen** (Spalten ausrichten & casten).

- 📓 **Notebook:**  
  [`08_15_praktische_patterns_setops.ipynb`](08_15_praktische_patterns_setops.ipynb)

- 🎥 **YouTube:**  
  - [Union Multiple Tables – Tips](https://www.youtube.com/results?search_query=sql+server+union+multiple+tables)

- 📘 **Docs:**  
  - [SELECT – Spaltenalias & Typen](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-transact-sql)

---

### 2.16 | Anti-Patterns & Fallstricke
> **Kurzbeschreibung:** `ORDER BY` in Teil-SELECTs erwarten, falsche Typausrichtung, fehlende Klammern, `UNION` statt `UNION ALL` aus Gewohnheit.

- 📓 **Notebook:**  
  [`08_16_setops_anti_patterns.ipynb`](08_16_setops_anti_patterns.ipynb)

- 🎥 **YouTube:**  
  - [Set Operator Pitfalls](https://www.youtube.com/results?search_query=sql+server+set+operators+pitfalls)

- 📘 **Docs/Blog:**  
  - [Collation Precedence](https://learn.microsoft.com/en-us/sql/t-sql/statements/collation-precedence-transact-sql)  
  - [Type Precedence & Implicit Conversion](https://learn.microsoft.com/en-us/sql/t-sql/data-types/data-type-precedence-transact-sql)

---

## 3 | Weiterführende Informationen

- 📘 Microsoft Learn: [`UNION` (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/set-operators-union-transact-sql)  
- 📘 Microsoft Learn: [`EXCEPT` & `INTERSECT` (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/set-operators-except-and-intersect-transact-sql)  
- 📘 Microsoft Learn: [`SELECT … ORDER BY` – Hinweise für Set-Ops](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-order-by-clause-transact-sql)  
- 📘 Microsoft Learn: [Data Type Precedence](https://learn.microsoft.com/en-us/sql/t-sql/data-types/data-type-precedence-transact-sql)  
- 📘 Microsoft Learn: [Collation Precedence & `COLLATE`](https://learn.microsoft.com/en-us/sql/t-sql/statements/collation-precedence-transact-sql)  
- 📘 Microsoft Learn: [Query Processing Architecture Guide](https://learn.microsoft.com/en-us/sql/relational-databases/query-processing-architecture-guide)  
- 📘 Microsoft Learn: [Cardinality Estimation – Overview](https://learn.microsoft.com/en-us/sql/relational-databases/performance/cardinality-estimation-overview)  
- 📝 Simple Talk (Redgate): [EXCEPT and INTERSECT in SQL Server](https://www.red-gate.com/simple-talk/databases/sql-server/t-sql-programming-sql-server/except-and-intersect-in-sql-server/)  
- 📝 SQLShack: [Using SQL Server `UNION` vs `UNION ALL`](https://www.sqlshack.com/sql-union-vs-union-all/)  
- 📝 SQLPerformance: [When `UNION` Hurts (Distinct Cost)](https://www.sqlperformance.com/?s=union)  
- 📝 Itzik Ben-Gan: [Set Operators – Patterns & Alternatives](https://tsql.solidq.com/)  
- 📝 Brent Ozar: [SARGability & Casting before Set-Ops](https://www.brentozar.com/archive/2018/02/sargable-queries/)  
- 🎥 YouTube: [UNION vs UNION ALL – Performance Demo](https://www.youtube.com/results?search_query=sql+server+union+vs+union+all+performance)  
- 🎥 YouTube: [EXCEPT vs NOT EXISTS – Anti-Join](https://www.youtube.com/results?search_query=sql+server+except+vs+not+exists)  

