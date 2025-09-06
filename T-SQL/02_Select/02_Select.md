# T-SQL SELECT – Übersicht

## 1 | Begriffsdefinition

| SQL-Term | Beschreibung |
|---|---|
| `SELECT`-Liste (Projektion) | Bestimmt, welche Spalten/Ausdrücke zurückgegeben werden; Reihenfolge/Format nur mit `ORDER BY` garantiert. |
| `FROM`-Quelle(n) | Tabellen, Views, TVFs, abgeleitete Tabellen, CTEs als Eingabe für `SELECT`. |
| Alias (`AS`) | Benennt Spalten/Tabellen zur besseren Lesbarkeit; erforderlich für berechnete Spalten ohne Namen. |
| `*` (Stern) | Alle Spalten der Quelle; für stabile Schnittstellen explizite Spalten bevorzugen. |
| `DISTINCT` | Entfernt Dubletten in der Ergebnis-Projection; wirkt nach Berechnung der `SELECT`-Ausdrücke. |
| `TOP` (`PERCENT`, `WITH TIES`) | Begrenzt Zeilenanzahl; sinnvolle Reihenfolge nur in Kombination mit `ORDER BY`. |
| `ORDER BY` + `OFFSET … FETCH` | Sortierung & Pagination im Ergebnis; ohne `ORDER BY` ist Reihenfolge nicht determiniert. |
| `GROUP BY` | Aggregation über Gruppen; nur gruppierte oder aggregierte Ausdrücke sind erlaubt. |
| `HAVING` | Filtert Aggregatsgruppen nach `GROUP BY` (im Gegensatz zu `WHERE` vor Aggregation). |
| Fensterfunktionen (`OVER`) | `ROW_NUMBER`, `SUM() OVER`, Frames (`ROWS/RANGE`), `PARTITION BY`, `ORDER BY` innerhalb der Partition. |
| `CASE`-Ausdruck | Konditionale Projektion innerhalb der `SELECT`-Liste. |
| Skalar-/Tabellenfunktionen | In der Projektion nutzbar; skalar oft performancekritisch, Inline/TVF bevorzugen. |
| Abgeleitete Tabelle / CTE | Zwischenresultate für Strukturierung/Lesbarkeit; CTE v. a. für Window-Filter, Rekursion. |
| `APPLY` (CROSS/OUTER) | Führt zeilenweise korrelierte Unterabfragen/TVFs aus und projiziert deren Spalten. |
| `PIVOT` / `UNPIVOT` | Dreht Zeilen↔Spalten für Berichte; Alternativen: `GROUP BY` + Konditionalaggregation. |
| `SELECT INTO` | Erstellt & befüllt eine neue Tabelle aus einem `SELECT`-Ergebnis (i. d. R. minimal geloggt). |
| `INSERT … SELECT` | Schreibt `SELECT`-Ergebnis in bestehende Tabelle; mit Spaltenliste kontrollieren. |
| Variablenzuweisung via `SELECT` | `SELECT @v = Col …`; Mehrzeilenverhalten beachten (letzte/undefinierte Auswahl). |
| `FOR JSON` / `FOR XML` | Serialisiert das Resultset direkt als JSON/XML. |
| Kollation & implizite Konvertierung | Beeinflussen Vergleich/Sortierung in `ORDER BY` und Typen der Ausdrücke in der Projektion. |
| Berechnete/persistierte Spalten | Vermeiden wiederkehrender Ausdrücke; können indexiert werden. |
| Berechtigungen (`SELECT`) | Objekt-/Spaltenberechtigungen steuern Sichtbarkeit; RLS kann zusätzliche Filter erzwingen. |

---

## 2 | Struktur

### 2.1 | SELECT-Grundlagen & Syntax
> **Kurzbeschreibung:** Minimale Syntax, Projektion, Alias, logische Verarbeitungsreihenfolge und deterministische Ausgabe.

- 📓 **Notebook:**  
  [`02_01_select_grundlagen.ipynb`](02_01_select_grundlagen.ipynb)

- 🎥 **YouTube:**  
  - [SELECT Statement – Basics (SQL Server)](https://www.youtube.com/results?search_query=sql+server+select+statement+basics)

- 📘 **Docs:**  
  - [SELECT (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-transact-sql)

---

### 2.2 | Ausdrücke, `CASE`, `CAST/CONVERT`, `ISNULL/COALESCE`
> **Kurzbeschreibung:** Werte berechnen, bedingt ableiten und sauber typisieren; Fallstricke mit `FORMAT()` vermeiden.

- 📓 **Notebook:**  
  [`02_02_select_ausdruecke_case_cast.ipynb`](02_02_select_ausdruecke_case_cast.ipynb)

- 🎥 **YouTube:**  
  - [CASE Expression – Patterns](https://www.youtube.com/results?search_query=sql+server+case+expression+t-sql)

- 📘 **Docs:**  
  - [`CASE` (T-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/case-transact-sql)  
  - [`CAST` und `CONVERT`](https://learn.microsoft.com/en-us/sql/t-sql/functions/cast-and-convert-transact-sql)

---

### 2.3 | `DISTINCT` vs. `GROUP BY` zum Dedupen
> **Kurzbeschreibung:** Wann `DISTINCT` genügt und wann Aggregation sinnvoller ist; Einfluss auf Pläne & Performance.

- 📓 **Notebook:**  
  [`02_03_distinct_vs_groupby.ipynb`](02_03_distinct_vs_groupby.ipynb)

- 🎥 **YouTube:**  
  - [DISTINCT vs GROUP BY](https://www.youtube.com/results?search_query=sql+server+distinct+vs+group+by)

- 📘 **Docs:**  
  - [`DISTINCT` (T-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-transact-sql#use-distinct)

---

### 2.4 | `TOP`, `WITH TIES`, `PERCENT` & Pagination mit `OFFSET/FETCH`
> **Kurzbeschreibung:** Zeilenlimitierung korrekt einsetzen und stabil sortieren; Unterschiede zwischen Limitierung und Pagination.

- 📓 **Notebook:**  
  [`02_04_top_offset_fetch.ipynb`](02_04_top_offset_fetch.ipynb)

- 🎥 **YouTube:**  
  - [TOP & ORDER BY – Best Practices](https://www.youtube.com/results?search_query=sql+server+top+with+ties+offset+fetch)

- 📘 **Docs:**  
  - [`TOP` (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/queries/top-transact-sql)  
  - [`ORDER BY` mit `OFFSET/FETCH`](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-order-by-clause-transact-sql)

---

### 2.5 | Sortierung mit `ORDER BY` & Determinismus
> **Kurzbeschreibung:** Stabile Sortierkriterien, Kollisionen durch `NULL`/Kollation, zufällige Reihenfolge (`ORDER BY NEWID()`).

- 📓 **Notebook:**  
  [`02_05_order_by_determinismus.ipynb`](02_05_order_by_determinismus.ipynb)

- 🎥 **YouTube:**  
  - [ORDER BY – Do’s & Don’ts](https://www.youtube.com/results?search_query=sql+server+order+by+best+practices)

- 📘 **Docs:**  
  - [`ORDER BY` (T-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-order-by-clause-transact-sql)

---

### 2.6 | Aggregation mit `GROUP BY` & `HAVING`
> **Kurzbeschreibung:** Klassische Aggregation, Filterung nach Aggregaten und typische Fehlerquellen.

- 📓 **Notebook:**  
  [`02_06_groupby_having.ipynb`](02_06_groupby_having.ipynb)

- 🎥 **YouTube:**  
  - [GROUP BY & HAVING Tutorial](https://www.youtube.com/results?search_query=sql+server+group+by+having+tutorial)

- 📘 **Docs:**  
  - [`GROUP BY` (T-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-group-by-transact-sql)  
  - [`HAVING` (T-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-having-transact-sql)

---

### 2.7 | Erweiterte Aggregation: `GROUPING SETS`, `ROLLUP`, `CUBE`
> **Kurzbeschreibung:** Mehrdimensionale Summen in einer Abfrage; `GROUPING_ID` zur Unterscheidung der Ebenen.

- 📓 **Notebook:**  
  [`02_07_grouping_sets_rollup_cube.ipynb`](02_07_grouping_sets_rollup_cube.ipynb)

- 🎥 **YouTube:**  
  - [GROUPING SETS / ROLLUP / CUBE](https://www.youtube.com/results?search_query=sql+server+grouping+sets+rollup+cube)

- 📘 **Docs:**  
  - [`GROUP BY` – Erweiterungen](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-group-by-transact-sql#grouping-sets-cube-and-rollup)  
  - [`GROUPING_ID`](https://learn.microsoft.com/en-us/sql/t-sql/functions/grouping-id-transact-sql)

---

### 2.8 | Fensterfunktionen (`OVER`): Ranking, Aggregate, Frames
> **Kurzbeschreibung:** Rangfolgen, laufende Summen, gleitende Fenster; richtige Frame-Definition für korrekte Ergebnisse.

- 📓 **Notebook:**  
  [`02_08_window_functions_over.ipynb`](02_08_window_functions_over.ipynb)

- 🎥 **YouTube:**  
  - [Window Functions Deep Dive](https://www.youtube.com/results?search_query=sql+server+window+functions+over+clause)

- 📘 **Docs:**  
  - [`OVER`-Klausel](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-over-clause-transact-sql)  
  - [Ranking-Funktionen (`ROW_NUMBER`, `RANK`, …)](https://learn.microsoft.com/en-us/sql/t-sql/functions/ranking-functions-transact-sql)

---

### 2.9 | Unterabfragen & korrelierte Abfragen
> **Kurzbeschreibung:** Skalar-, Mehrzeilen- und existenzbasierte Unterabfragen in der Projektion und im `FROM`.

- 📓 **Notebook:**  
  [`02_09_subqueries_scalar_table.ipynb`](02_09_subqueries_scalar_table.ipynb)

- 🎥 **YouTube:**  
  - [Subqueries in SELECT](https://www.youtube.com/results?search_query=sql+server+subqueries+in+select)

- 📘 **Docs:**  
  - [Unterabfragen (T-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/queries/subqueries)

---

### 2.10 | `APPLY` mit TVFs & `OPENJSON`
> **Kurzbeschreibung:** Zeilenweise Ausdehnung/Transformation; `CROSS/OUTER APPLY` für TVFs und JSON-Shredding.

- 📓 **Notebook:**  
  [`02_10_apply_openjson.ipynb`](02_10_apply_openjson.ipynb)

- 🎥 **YouTube:**  
  - [CROSS APPLY Patterns](https://www.youtube.com/results?search_query=sql+server+cross+apply+openjson)

- 📘 **Docs:**  
  - [`APPLY` (T-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/queries/from-transact-sql#apply-operator)  
  - [`OPENJSON`](https://learn.microsoft.com/en-us/sql/t-sql/functions/openjson-transact-sql)

---

### 2.11 | `PIVOT`/`UNPIVOT` & Alternative Muster
> **Kurzbeschreibung:** Berichtsfreundliche Drehung von Daten sowie Alternativen mit `CASE`+Aggregation.

- 📓 **Notebook:**  
  [`02_11_pivot_unpivot.ipynb`](02_11_pivot_unpivot.ipynb)

- 🎥 **YouTube:**  
  - [PIVOT Explained](https://www.youtube.com/results?search_query=sql+server+pivot+unpivot)

- 📘 **Docs:**  
  - [`PIVOT` (T-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/queries/from-using-pivot-and-unpivot)  

---

### 2.12 | `SELECT INTO` vs. `INSERT … SELECT`
> **Kurzbeschreibung:** Tabellenanlage aus Abfrage, Minimal-Logging, Zielschemadefinition und Parallelität.

- 📓 **Notebook:**  
  [`02_12_select_into_insert_select.ipynb`](02_12_select_into_insert_select.ipynb)

- 🎥 **YouTube:**  
  - [SELECT INTO vs INSERT SELECT](https://www.youtube.com/results?search_query=sql+server+select+into+vs+insert+select)

- 📘 **Docs:**  
  - [`SELECT INTO`](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-into-clause-transact-sql)  
  - [`INSERT` (T-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/statements/insert-transact-sql)

---

### 2.13 | Variablenzuweisung mit `SELECT`
> **Kurzbeschreibung:** Ein-/Mehrzeilenverhalten, `SET` vs. `SELECT`, Umgang mit `NULL` und Mehrspaltenzuweisungen.

- 📓 **Notebook:**  
  [`02_13_select_variable_assignment.ipynb`](02_13_select_variable_assignment.ipynb)

- 🎥 **YouTube:**  
  - [SET vs SELECT (Variables)](https://www.youtube.com/results?search_query=sql+server+set+vs+select+variables)

- 📘 **Docs:**  
  - [`DECLARE`/`SET @local_variable`](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/set-local-variable-transact-sql)  
  - [Variablenzuweisung in `SELECT`](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-transact-sql#assigning-variables)

---

### 2.14 | Ausgabe als JSON/XML: `FOR JSON` / `FOR XML`
> **Kurzbeschreibung:** Direkte Serialisierung des Resultsets; Modi (`AUTO`/`PATH`) und Größen-/NVARCHAR-Limits.

- 📓 **Notebook:**  
  [`02_14_for_json_for_xml.ipynb`](02_14_for_json_for_xml.ipynb)

- 🎥 **YouTube:**  
  - [FOR JSON in SQL Server](https://www.youtube.com/results?search_query=sql+server+for+json)  

- 📘 **Docs:**  
  - [`FOR JSON`](https://learn.microsoft.com/en-us/sql/relational-databases/json/format-query-results-as-json-with-for-json-sql-server)  
  - [`FOR XML`](https://learn.microsoft.com/en-us/sql/relational-databases/xml/for-xml-sql-server)

---

### 2.15 | Isolation, Sperren & Hints bei `SELECT`
> **Kurzbeschreibung:** Lesesperren, `READ COMMITTED SNAPSHOT`, `NOLOCK`/`READUNCOMMITTED` Risiken, `READPAST`.

- 📓 **Notebook:**  
  [`02_15_select_isolation_hints.ipynb`](02_15_select_isolation_hints.ipynb)

- 🎥 **YouTube:**  
  - [NOLOCK Explained](https://www.youtube.com/results?search_query=sql+server+nolock+read+committed+snapshot)

- 📘 **Docs:**  
  - [Table Hints (`NOLOCK`, `READPAST`, …)](https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-table)  
  - [`SET TRANSACTION ISOLATION LEVEL`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-transaction-isolation-level-transact-sql)

---

## 3 | Weiterführende Informationen

- 📘 Microsoft Learn: [SELECT (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-transact-sql)  
- 📘 Microsoft Learn: [`ORDER BY` & Pagination](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-order-by-clause-transact-sql)  
- 📘 Microsoft Learn: [`TOP` (WITH TIES/PERCENT)](https://learn.microsoft.com/en-us/sql/t-sql/queries/top-transact-sql)  
- 📘 Microsoft Learn: [`GROUP BY` / `HAVING`](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-group-by-transact-sql)  
- 📘 Microsoft Learn: [Fensterfunktionen – Überblick](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-over-clause-transact-sql)  
- 📘 Microsoft Learn: [`APPLY`-Operator](https://learn.microsoft.com/en-us/sql/t-sql/queries/from-transact-sql#apply-operator)  
- 📘 Microsoft Learn: [`PIVOT`/`UNPIVOT`](https://learn.microsoft.com/en-us/sql/t-sql/queries/from-using-pivot-and-unpivot)  
- 📘 Microsoft Learn: [`SELECT INTO`](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-into-clause-transact-sql)  
- 📘 Microsoft Learn: [`FOR JSON` – Leitfaden](https://learn.microsoft.com/en-us/sql/relational-databases/json/format-query-results-as-json-with-for-json-sql-server)  
- 📘 Microsoft Learn: [Abfrageverarbeitungsarchitektur](https://learn.microsoft.com/en-us/sql/relational-databases/query-processing-architecture-guide)  
- 📝 Blog (Itzik Ben-Gan): [Window Functions & Querying Patterns](https://tsql.solidq.com/)  
- 📝 Blog (SQLPerformance): [Paul White – Execution Plans & Patterns](https://www.sqlperformance.com/tag/paul-white)  
- 📝 Blog (Erik Darling): [T-SQL Anti-Patterns](https://www.erikdarlingdata.com/)  
- 🎥 YouTube: [Itzik Ben-Gan – T-SQL Talks (Window Functions)](https://www.youtube.com/results?search_query=itzik+ben+gan+window+functions)  
- 🎥 YouTube: [Brent Ozar – SQL Server Playlists](https://www.youtube.com/c/BrentOzarUnlimited/playlists)  
