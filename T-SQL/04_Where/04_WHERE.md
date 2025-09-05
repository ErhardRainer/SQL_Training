# T-SQL WHERE – Übersicht

## 1 | Begriffsdefinition

| SQL-Term | Beschreibung |
|---|---|
| `WHERE`-Klausel | Filtert Zeilen anhand von Suchbedingungen vor der Projektion (`SELECT`-Liste) und Aggregation; wirkt auf die einzelnen Quellzeilen. |
| Suchbedingung (*search condition*) | Boolescher Ausdruck aus Prädikaten und Operatoren (`=`, `<>`, `>`, `<`, `IN`, `BETWEEN`, `LIKE`, `EXISTS`, `AND/OR/NOT`). |
| Dreiwertige Logik | Ergebnisse von Prädikaten sind `TRUE`, `FALSE` oder `UNKNOWN` (insb. bei `NULL`); nur `TRUE`-Zeilen passieren `WHERE`. |
| `NULL`-Semantik | Vergleiche mit `NULL` liefern `UNKNOWN`; nutze `IS [NOT] NULL` statt `= NULL`. |
| SARGability (sargierbar) | Prädikate, die Indexnutzung erlauben (z. B. `Col LIKE 'abc%'`); Funktionen auf der Spalte verhindern oft Seeks. |
| Index Seek/Scan & Residual Predicate | Seek nutzt Indexschlüsselbereiche; nicht abbildbare Teile bleiben als Residual-Filter im Ausführungsplan. |
| Prädikat-Pushdown | Filter werden (wenn möglich) in tiefe Plan-Operatoren/Storage (z. B. Columnstore) geschoben. |
| Logische Verarbeitungsreihenfolge | `FROM` → `WHERE` → `GROUP BY` → `HAVING` → `SELECT` → `ORDER BY`; beeinflusst, worauf `WHERE` zugreifen kann. |
| `LIKE` + `ESCAPE` | Mustervergleiche mit `%`, `_` und optionalem Escape-Zeichen; Kollation bestimmt Groß-/Akzentsensitivität. |
| `IN` / `NOT IN` vs. `EXISTS` | Mengen-/Existenztests; `NOT IN` mit `NULL`-Werten kann überraschend `UNKNOWN` ergeben. |
| `BETWEEN` (inklusive) | Enthält die Grenzen: `x BETWEEN a AND b` entspricht `x >= a AND x <= b`. |
| Implizite Konvertierung | Unterschiedliche Datentypen erzwingen Konvertierungen, können Seeks verhindern und Pläne verlangsamen. |
| Datentyp-Priorität | Bestimmt, in welchen Typ konvertiert wird (z. B. `varchar` ↔ `nvarchar`); beeinflusst SARGability. |
| Kollation (`COLLATE`) | Steuert Vergleichsregeln bei Zeichenketten; Mischkollationen im Prädikat können Konvertierungen auslösen. |
| Parameter Sniffing | Der erste Parameterwert beeinflusst den Plan; mit `OPTIMIZE FOR`/`RECOMPILE` steuerbar. |
| Cardinality Estimation (CE) | Schätzung der Zeilenanzahlen für Prädikate; wichtig für Planqualität. |
| Gefilterter Index | Index mit `WHERE`-Prädikat zur gezielten Abdeckung einer Datenmenge. |
| Partition Elimination | Passende Bereichsprädikate ermöglichen das Überspringen nicht relevanter Partitionen. |
| Row-Level Security (RLS) | Filter- und Block-Prädikate erzwingen Zeilenfilterung über Sicherheitsrichtlinien. |
| UDF/Expressions im `WHERE` | Skalar-UDFs/Funktionen auf Spalten können nicht sargierbar sein; Inline-Logik/Computed Columns bevorzugen. |

---

## 2 | Struktur

### 2.1 | WHERE-Grundlagen & Suchbedingungen
> **Kurzbeschreibung:** Syntax, logische Auswertung und typische Operatoren in `WHERE`; TRUE/FALSE/UNKNOWN und Kurzschlusslogik.

- 📓 **Notebook:**  
  [`08_01_where_grundlagen.ipynb`](08_01_where_grundlagen.ipynb)

- 🎥 **YouTube:**  
  - [SQL WHERE Clause (Einführung)](https://www.youtube.com/results?search_query=sql+server+where+clause)

- 📘 **Docs:**  
  - [WHERE (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/queries/where-transact-sql)  
  - [Search Condition (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/search-condition-transact-sql)

---

### 2.2 | Operatoren: `IN`/`BETWEEN`/`LIKE`/`AND`/`OR`/`NOT`
> **Kurzbeschreibung:** Ausdrucksstarke Filter mit Bereichs-, Mengen- und Musteroperatoren; Klammerung und Prioritäten.

- 📓 **Notebook:**  
  [`08_02_operatoren_in_between_like.ipynb`](08_02_operatoren_in_between_like.ipynb)

- 🎥 **YouTube:**  
  - [SQL LIKE, IN, BETWEEN](https://www.youtube.com/results?search_query=sql+server+like+in+between)

- 📘 **Docs:**  
  - [`LIKE` (T-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/like-transact-sql)  
  - [`IN` / `BETWEEN` (T-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/in-transact-sql)

---

### 2.3 | `NULL` & dreiwertige Logik
> **Kurzbeschreibung:** `IS NULL` vs. `= NULL`, `NOT IN`-Fallstricke, `COALESCE`/`ISNULL` als Muster und korrekte Negation.

- 📓 **Notebook:**  
  [`08_03_null_logik.ipynb`](08_03_null_logik.ipynb)

- 🎥 **YouTube:**  
  - [SQL NULLs Explained](https://www.youtube.com/results?search_query=sql+server+null+three+valued+logic)

- 📘 **Docs:**  
  - [`IS NULL` (T-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/is-null-transact-sql)  
  - [NULL und `UNKNOWN`](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/null-transact-sql)

---

### 2.4 | `WHERE` vs. `ON` bei JOINs
> **Kurzbeschreibung:** Unterschied zwischen Join-Bedingungen (`ON`) und Zeilenfiltern (`WHERE`); warum `WHERE` einen `LEFT JOIN` faktisch zum `INNER` machen kann.

- 📓 **Notebook:**  
  [`08_04_where_vs_on_outer_join.ipynb`](08_04_where_vs_on_outer_join.ipynb)

- 🎥 **YouTube:**  
  - [LEFT JOIN Fallen: Filter richtig platzieren](https://www.youtube.com/results?search_query=sql+server+left+join+where+on)

- 📘 **Docs:**  
  - [`FROM` + `JOIN` (T-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/queries/from-transact-sql)  
  - [SELECT – logische Verarbeitungsreihenfolge](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-transact-sql)

---

### 2.5 | SARGability & Funktionen im Prädikat
> **Kurzbeschreibung:** Warum `WHERE LEFT(Col,3)='ABC'` schlecht ist, aber `Col LIKE 'ABC%'` sargierbar; Alternativen mit berechneten Spalten/Indizes.

- 📓 **Notebook:**  
  [`08_05_sargability_muster.ipynb`](08_05_sargability_muster.ipynb)

- 🎥 **YouTube:**  
  - [SARGable Predicates (Performance)](https://www.youtube.com/results?search_query=sargable+predicates+sql+server)

- 📘 **Docs:**  
  - [Index-Entwurfsrichtlinien](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-index-design-guide)  
  - [Abfrageverarbeitungsarchitektur](https://learn.microsoft.com/en-us/sql/relational-databases/query-processing-architecture-guide)

---

### 2.6 | Datentypen, implizite Konvertierungen & Kollation
> **Kurzbeschreibung:** Wie Typumwandlungen und Kollationen Filter und Indexzugriffe beeinflussen; `N'…'` für Unicode, `COLLATE` gezielt einsetzen.

- 📓 **Notebook:**  
  [`08_06_datentypen_implizite_konvertierung.ipynb`](08_06_datentypen_implizite_konvertierung.ipynb)

- 🎥 **YouTube:**  
  - [Implicit Conversions in SQL Server](https://www.youtube.com/results?search_query=sql+server+implicit+conversion+performance)

- 📘 **Docs:**  
  - [Datentyp-Priorität (T-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/data-types/data-type-precedence-transact-sql)  
  - [Collation & Unicode](https://learn.microsoft.com/en-us/sql/relational-databases/collations/collation-and-unicode-support)

---

### 2.7 | Unterabfragen: `EXISTS`, `IN`, `ANY`/`ALL`
> **Kurzbeschreibung:** Existenzprüfungen, Mengenvergleiche und korrelierte Unterabfragen als flexible Filterbausteine.

- 📓 **Notebook:**  
  [`08_07_exists_in_any_all.ipynb`](08_07_exists_in_any_all.ipynb)

- 🎥 **YouTube:**  
  - [IN vs EXISTS in SQL Server](https://www.youtube.com/results?search_query=sql+server+in+vs+exists)

- 📘 **Docs:**  
  - [`EXISTS` (T-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/exists-transact-sql)  
  - [`ANY | SOME | ALL` (T-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/any-some-all-transact-sql)

---

### 2.8 | Filtern nach Fensterfunktionen (`ROW_NUMBER`, `SUM OVER`)
> **Kurzbeschreibung:** Warum `WHERE` keine Window-Ausdrücke sieht; Muster mit CTE/abgeleiteter Tabelle, um auf Rang/Window-Ergebnis zu filtern.

- 📓 **Notebook:**  
  [`08_08_window_filtering_cte.ipynb`](08_08_window_filtering_cte.ipynb)

- 🎥 **YouTube:**  
  - [ROW_NUMBER() Top-N pro Gruppe filtern](https://www.youtube.com/results?search_query=sql+server+row_number+per+group+top+n)

- 📘 **Docs:**  
  - [`OVER`-Klausel](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-over-clause-transact-sql)  
  - [`ROW_NUMBER` (T-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/functions/row_number-transact-sql)

---

### 2.9 | Gefilterte Indizes & ausrichtbare Prädikate
> **Kurzbeschreibung:** Filterbedingungen im Indexdesign, Kardinalität und Parameterisierung; Beispiel: `WHERE IsActive = 1`.

- 📓 **Notebook:**  
  [`08_09_gefilterte_indizes.ipynb`](08_09_gefilterte_indizes.ipynb)

- 🎥 **YouTube:**  
  - [Filtered Indexes – Praxis](https://www.youtube.com/results?search_query=sql+server+filtered+index)

- 📘 **Docs:**  
  - [Gefilterte Indizes erstellen](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/create-filtered-indexes)  
  - [Statistiken (Überblick)](https://learn.microsoft.com/en-us/sql/relational-databases/statistics/statistics)

---

### 2.10 | Partition Elimination & Bereichsprädikate
> **Kurzbeschreibung:** Partitionsbewusste Filter (`WHERE DateCol >= … AND < …`) für effiziente Bereichszugriffe ohne implizite Konvertierungen.

- 📓 **Notebook:**  
  [`08_10_partition_elimination.ipynb`](08_10_partition_elimination.ipynb)

- 🎥 **YouTube:**  
  - [Partitioned Tables – Elimination](https://www.youtube.com/results?search_query=sql+server+partition+elimination)

- 📘 **Docs:**  
  - [Partitionierte Tabellen & Indizes](https://learn.microsoft.com/en-us/sql/relational-databases/partitions/partitioned-tables-and-indexes)  
  - [CHECK-Einschränkungen & Partitionierung](https://learn.microsoft.com/en-us/sql/relational-databases/tables/create-check-constraints)

---

### 2.11 | Columnstore & Prädikat-Pushdown
> **Kurzbeschreibung:** Wie Batch-/Segment-Elimination und Prädikat-Pushdown bei Columnstore-Indexen Filter stark beschleunigen.

- 📓 **Notebook:**  
  [`08_11_columnstore_predicate_pushdown.ipynb`](08_11_columnstore_predicate_pushdown.ipynb)

- 🎥 **YouTube:**  
  - [Columnstore Predicate Pushdown](https://www.youtube.com/results?search_query=sql+server+columnstore+predicate+pushdown)

- 📘 **Docs:**  
  - [Columnstore – Abfrageleistung](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/columnstore-indexes-query-performance)  
  - [Batch Mode (Überblick)](https://learn.microsoft.com/en-us/sql/relational-databases/columnstore-indexes/batch-mode-processing)

---

### 2.12 | Parameter Sniffing & Query Hints für `WHERE`
> **Kurzbeschreibung:** Stabilere Pläne für variable Selektivität (`OPTIMIZE FOR`, `RECOMPILE`, lokale Variablen) und deren Trade-offs.

- 📓 **Notebook:**  
  [`08_12_parameter_sniffing_hints.ipynb`](08_12_parameter_sniffing_hints.ipynb)

- 🎥 **YouTube:**  
  - [Parameter Sniffing erklärt](https://www.youtube.com/results?search_query=sql+server+parameter+sniffing)

- 📘 **Docs:**  
  - [Parameter Sniffing (Leitfaden)](https://learn.microsoft.com/en-us/sql/relational-databases/performance/parameter-sniffing)  
  - [Query Hints (`OPTIMIZE FOR`, `RECOMPILE`)](https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-query)

---

### 2.13 | Sicherheit: Row-Level Security (RLS)
> **Kurzbeschreibung:** Filter- und Block-Prädikate durch Sicherheitsrichtlinien; Anwendung in Views, Direct-Table-Access und Joins.

- 📓 **Notebook:**  
  [`08_13_row_level_security_where.ipynb`](08_13_row_level_security_where.ipynb)

- 🎥 **YouTube:**  
  - [Row-Level Security in SQL Server](https://www.youtube.com/results?search_query=sql+server+row+level+security)

- 📘 **Docs:**  
  - [Row-Level Security (SQL Server)](https://learn.microsoft.com/en-us/sql/relational-databases/security/row-level-security)  
  - [CREATE SECURITY POLICY](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-security-policy-transact-sql)

---

## 3 | Weiterführende Informationen

- 📘 Microsoft Learn: [WHERE (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/queries/where-transact-sql)  
- 📘 Microsoft Learn: [Search Condition – Übersicht](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/search-condition-transact-sql)  
- 📘 Microsoft Learn: [SELECT (Transact-SQL) – Logik & Beispiele](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-transact-sql)  
- 📘 Microsoft Learn: [Operators (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/operators-transact-sql)  
- 📘 Microsoft Learn: [Data Type Precedence](https://learn.microsoft.com/en-us/sql/t-sql/data-types/data-type-precedence-transact-sql)  
- 📘 Microsoft Learn: [CAST und CONVERT](https://learn.microsoft.com/en-us/sql/t-sql/functions/cast-and-convert-transact-sql)  
- 📘 Microsoft Learn: [Index Design Guide](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-index-design-guide)  
- 📘 Microsoft Learn: [Cardinality Estimation – Überblick](https://learn.microsoft.com/en-us/sql/relational-databases/performance/cardinality-estimation-overview)  
- 📘 Microsoft Learn: [Gefilterte Indizes](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/create-filtered-indexes)  
- 🎥 YouTube Playlist: [SQL Server – WHERE, JOIN & Filtering (Suchergebnisse)](https://www.youtube.com/results?search_query=sql+server+where+joins+filter)  
