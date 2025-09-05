# T-SQL Funktionen – Übersicht

## 1 | Begriffsdefinition

| SQL-Term | Beschreibung |
|---|---|
| Built-in Funktionen | Von SQL Server bereitgestellte Funktionen (skalare, Aggregat-, Ranking-/Window-, System-, JSON-, Konvertierungs- u. a.). |
| Skalare Funktionen | Geben pro Eingabezeile genau **einen** Wert zurück (z. B. `ABS`, `SUBSTRING`, `GETDATE`). |
| Aggregatfunktionen | Verdichten mehrere Zeilen zu einem Wert (z. B. `SUM`, `AVG`, `COUNT`, `STRING_AGG`). |
| Ranking-/Window-Funktionen | Arbeiten mit `OVER(...)` über Fenster/Partitionen (z. B. `ROW_NUMBER`, `LAG`, `SUM() OVER`). |
| Deterministisch vs. nicht-deterministisch | Deterministische liefern bei gleichen Inputs stets gleiche Outputs; relevant für **indizierte berechnete Spalten**. |
| NULL-Propagation | Viele Funktionen geben bei `NULL`-Input `NULL` zurück; Ausnahmen beachten (`ISNULL`, `COALESCE` usw.). |
| Kollation & Unicode | Zeichenfunktionen unterliegen Kollationsregeln (`COLLATE`); `N'…'` für Unicode-Literale. |
| Datentyp-Priorität & implizite Konvertierung | Funktionen können Konvertierungen erzwingen → Performance/Präzision; `TRY_CONVERT` bevorzugen. |
| SARGability | Funktionen **auf Spalten** in `WHERE/JOIN` verhindern oft Index-Seeks; Alternativen: berechnete Spalten, Vorberechnung. |
| `FORMAT` vs. `CONVERT/CAST` | `FORMAT()` ist bequem, aber langsam und lokalisationsabhängig; für Berichte okay, nicht für Massendaten. |
| `DATEFIRST`, Spracheinstellungen | Beeinflussen Datumsfunktionen wie `DATEPART(WEEKDAY)` sowie Texte von `DATENAME`. |
| Fehler-/Sicherheitsfunktionen | `ERROR_NUMBER()`, `ERROR_MESSAGE()`, `ISJSON`, `TRY_PARSE` u. a. für robuste Logik. |

---

## 2 | Struktur

### 2.1 | Überblick & Kategorien
> **Kurzbeschreibung:** Große Landkarte der T-SQL-Funktionen, Kategorien, Determinismus, Einsatzgebiete.

- 📓 **Notebook:**  
  [`08_01_funktionen_ueberblick.ipynb`](08_01_funktionen_ueberblick.ipynb)

- 🎥 **YouTube:**  
  - [T-SQL Functions – Overview](https://www.youtube.com/results?search_query=sql+server+functions+overview)  
  - [Deterministic vs Non-Deterministic Functions](https://www.youtube.com/results?search_query=sql+server+deterministic+functions)

- 📘 **Docs:**  
  - [Functions (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/functions/functions)  
  - [Deterministic and Nondeterministic Functions](https://learn.microsoft.com/en-us/sql/relational-databases/user-defined-functions/deterministic-and-nondeterministic-functions)

---

### 2.2 | Numerische Grundfunktionen (`ABS`, `SIGN`, `ROUND`, `CEILING`, `FLOOR`)
> **Kurzbeschreibung:** Häufige Rechenhelfer, Rundung/Skalierung und Präzisionsfallen bei `decimal`/`float`.

- 📓 **Notebook (rename aus „EH04-01-00 …“):**  
  [`08_02_numerische_funktionen.ipynb`](08_02_numerische_funktionen.ipynb)

- 🎥 **YouTube:**  
  - [SQL Server Math Functions – Basics](https://www.youtube.com/results?search_query=sql+server+math+functions+abs+round)

- 📘 **Docs:**  
  - [Mathematical Functions (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/functions/mathematical-functions-transact-sql)

---

### 2.3 | Grad ↔ Bogenmaß (`RADIANS`, `DEGREES`)
> **Kurzbeschreibung:** Sichere Umrechnung Winkelmaße für trigonometrische Berechnungen.

- 📓 **Notebook (rename aus „EH04-01-01 …“):**  
  [`08_03_grad_bogenmass.ipynb`](08_03_grad_bogenmass.ipynb)

- 🎥 **YouTube:**  
  - [RADIANS & DEGREES in T-SQL](https://www.youtube.com/results?search_query=sql+server+radians+degrees)

- 📘 **Docs:**  
  - [`RADIANS`](https://learn.microsoft.com/en-us/sql/t-sql/functions/radians-transact-sql) · [`DEGREES`](https://learn.microsoft.com/en-us/sql/t-sql/functions/degrees-transact-sql)

---

### 2.4 | Winkel-Funktionen (`SIN`, `COS`, `TAN`, `ASIN`…)
> **Kurzbeschreibung:** Trigonometrie in T-SQL – Wertebereiche, Rückgabewinkel, typische Muster.

- 📓 **Notebook (rename aus „EH04-01-02 …“):**  
  [`08_04_winkel_funktionen.ipynb`](08_04_winkel_funktionen.ipynb)

- 🎥 **YouTube:**  
  - [Trigonometric Functions in SQL Server](https://www.youtube.com/results?search_query=sql+server+trigonometric+functions)

- 📘 **Docs:**  
  - [Mathematical Functions (Trig)](https://learn.microsoft.com/en-us/sql/t-sql/functions/mathematical-functions-transact-sql)

---

### 2.5 | Logarithmus & Exponential (`LOG`, `LOG10`, `EXP`, `POWER`, `SQRT`)
> **Kurzbeschreibung:** Wachstum, Normalisierung, Skalenwechsel; Basiswahl und Präzision.

- 📓 **Notebook (rename aus „EH04-01-03 …“):**  
  [`08_05_log_exp_funktionen.ipynb`](08_05_log_exp_funktionen.ipynb)

- 🎥 **YouTube:**  
  - [LOG/EXP/POWER – Beispiele](https://www.youtube.com/results?search_query=sql+server+log+exp+power)

- 📘 **Docs:**  
  - [Mathematical Functions – LOG/EXP](https://learn.microsoft.com/en-us/sql/t-sql/functions/mathematical-functions-transact-sql)

---

### 2.6 | Textfunktionen (`SUBSTRING`, `LEN`, `LEFT/RIGHT`, `REPLACE`, `CONCAT`, `STRING_SPLIT`)
> **Kurzbeschreibung:** Strings schneiden/suchen/ersetzen, Tokenisieren, Längenmessung; Unicode & Collation.

- 📓 **Notebook (rename aus „Textfunktionen.ipynb“):**  
  [`08_06_textfunktionen.ipynb`](08_06_textfunktionen.ipynb)

- 🎥 **YouTube:**  
  - [SQL Server String Functions](https://www.youtube.com/results?search_query=sql+server+string+functions)

- 📘 **Docs:**  
  - [String Functions (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/functions/string-functions-transact-sql)  
  - [`STRING_SPLIT`](https://learn.microsoft.com/en-us/sql/t-sql/functions/string-split-transact-sql)

---

### 2.7 | Konvertierung & Typen (`CAST`, `CONVERT`, `TRY_CONVERT`, `PARSE`, `TRY_PARSE`)
> **Kurzbeschreibung:** Sichere Typwechsel, Kulturabhängigkeit von `PARSE`, Performance-Hinweise & Data-Type-Precedence.

- 📓 **Notebook:**  
  [`08_07_konvertierung_datentypen.ipynb`](08_07_konvertierung_datentypen.ipynb)

- 🖼️ **Cheatsheet:**  
  ![Conversion Chart](SQL%20Server%20Data%20Type%20Conversion%20Chart.png)

- 🎥 **YouTube:**  
  - [CAST vs CONVERT vs TRY_CONVERT](https://www.youtube.com/results?search_query=sql+server+cast+convert+try_convert)

- 📘 **Docs:**  
  - [`CAST` and `CONVERT`](https://learn.microsoft.com/en-us/sql/t-sql/functions/cast-and-convert-transact-sql) · [`TRY_CONVERT`](https://learn.microsoft.com/en-us/sql/t-sql/functions/try-convert-transact-sql)  
  - [`PARSE` / `TRY_PARSE`](https://learn.microsoft.com/en-us/sql/t-sql/functions/parse-transact-sql) · [Data Type Precedence](https://learn.microsoft.com/en-us/sql/t-sql/data-types/data-type-precedence-transact-sql)

---

### 2.8 | Datum & Zeit (`GETDATE`, `SYSDATETIME`, `DATEADD`, `DATEDIFF`, `EOMONTH`, `FORMAT`)
> **Kurzbeschreibung:** Zeitarithmetik, Monats-/Kalenderlogik, Wochenstart (`DATEFIRST`) und `FORMAT`-Fallstricke.

- 📓 **Notebook:**  
  [`08_08_datum_zeit_funktionen.ipynb`](08_08_datum_zeit_funktionen.ipynb)

- 🎥 **YouTube:**  
  - [Date & Time Functions – Guide](https://www.youtube.com/results?search_query=sql+server+date+time+functions)

- 📘 **Docs:**  
  - [Date and Time Functions (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/functions/date-and-time-data-types-and-functions-transact-sql)  
  - [`EOMONTH`](https://learn.microsoft.com/en-us/sql/t-sql/functions/eomonth-transact-sql)

---

### 2.9 | Bedingte & NULL-Handling (`CASE`, `IIF`, `CHOOSE`, `COALESCE`, `ISNULL`, `NULLIF`)
> **Kurzbeschreibung:** Kontrollfluss in Ausdrücken, Standardwerte, Division-durch-Null vermeiden mit `NULLIF`.

- 📓 **Notebook:**  
  [`08_09_bedingte_funktionen_nullhandling.ipynb`](08_09_bedingte_funktionen_nullhandling.ipynb)

- 🎥 **YouTube:**  
  - [CASE / IIF / COALESCE – Patterns](https://www.youtube.com/results?search_query=sql+server+case+iif+coalesce)

- 📘 **Docs:**  
  - [`CASE`](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/case-transact-sql) · [`IIF`](https://learn.microsoft.com/en-us/sql/t-sql/functions/logical-functions-iif-transact-sql)  
  - [`COALESCE`](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/coalesce-transact-sql) · [`ISNULL`](https://learn.microsoft.com/en-us/sql/t-sql/functions/isnull-transact-sql)

---

### 2.10 | Aggregatfunktionen & Textaggregation (`SUM`, `AVG`, `COUNT`, `MIN/MAX`, `STRING_AGG`)
> **Kurzbeschreibung:** Gruppieren & verdichten, Distinct-Aggregate, Textlisten stabil sortieren.

- 📓 **Notebook:**  
  [`08_10_aggregate_und_string_agg.ipynb`](08_10_aggregate_und_string_agg.ipynb)

- 🎥 **YouTube:**  
  - [Aggregate Functions in T-SQL](https://www.youtube.com/results?search_query=sql+server+aggregate+functions)  
  - [`STRING_AGG` mit ORDER BY](https://www.youtube.com/results?search_query=sql+server+string_agg+order+by)

- 📘 **Docs:**  
  - [Aggregate Functions (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/functions/aggregate-functions-transact-sql)  
  - [`STRING_AGG`](https://learn.microsoft.com/en-us/sql/t-sql/functions/string-agg-transact-sql)

---

### 2.11 | Fenster- & Ranking-Funktionen (`ROW_NUMBER`, `LAG/LEAD`, `FIRST_VALUE`…)
> **Kurzbeschreibung:** Reihenfolgen & gleitende Berechnungen mit `OVER(PARTITION BY … ORDER BY …)` und Frames.

- 📓 **Notebook:**  
  [`08_11_window_und_ranking.ipynb`](08_11_window_und_ranking.ipynb)

- 🎥 **YouTube:**  
  - [Window Functions Deep Dive](https://www.youtube.com/results?search_query=sql+server+window+functions+over)

- 📘 **Docs:**  
  - [Ranking Functions](https://learn.microsoft.com/en-us/sql/t-sql/functions/ranking-functions-transact-sql)  
  - [`OVER`-Klausel](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-over-clause-transact-sql)

---

### 2.12 | JSON-Funktionen (`ISJSON`, `JSON_VALUE`, `JSON_QUERY`, `JSON_MODIFY`, `OPENJSON`)
> **Kurzbeschreibung:** JSON validieren, extrahieren, verändern; mit `OPENJSON` + `APPLY` zu Zeilen shreddern.

- 📓 **Notebook:**  
  [`08_12_json_funktionen.ipynb`](08_12_json_funktionen.ipynb)

- 🎥 **YouTube:**  
  - [T-SQL JSON – Praxis](https://www.youtube.com/results?search_query=sql+server+json+functions+openjson)

- 📘 **Docs:**  
  - [JSON (SQL Server)](https://learn.microsoft.com/en-us/sql/relational-databases/json/json-data-sql-server)  
  - [`OPENJSON`](https://learn.microsoft.com/en-us/sql/t-sql/functions/openjson-transact-sql)

---

### 2.13 | System- & Metadatenfunktionen (`@@ROWCOUNT`, `ERROR_*`, `CONNECTIONPROPERTY`, `COLLATIONPROPERTY`)
> **Kurzbeschreibung:** Laufzeitinfos, Fehlerdiagnose, Kollationsdetails, Server-/DB-Status abfragen.

- 📓 **Notebook:**  
  [`08_13_system_metadaten_funktionen.ipynb`](08_13_system_metadaten_funktionen.ipynb)

- 🎥 **YouTube:**  
  - [System Functions – Tour](https://www.youtube.com/results?search_query=sql+server+system+functions)

- 📘 **Docs:**  
  - [System Functions (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/functions/system-functions-transact-sql)  
  - [Error Functions (`ERROR_NUMBER`…)](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/error-functions-transact-sql)

---

### 2.14 | Performance & SARGability mit Funktionen
> **Kurzbeschreibung:** Funktionen vermeiden in `WHERE/JOIN` (Index-Nutzung), Alternativen mit **persistierten berechneten Spalten**, Inline-Logik, UDF-Inlining (ab SQL 2019).

- 📓 **Notebook:**  
  [`08_14_performance_sargability_funktionen.ipynb`](08_14_performance_sargability_funktionen.ipynb)

- 🎥 **YouTube:**  
  - [SARGable vs Non-SARGable](https://www.youtube.com/results?search_query=sql+server+sargable)  

- 📘 **Docs:**  
  - [Indexes on Computed Columns](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/indexes-on-computed-columns)  
  - [Scalar UDF Inlining (SQL 2019+)](https://learn.microsoft.com/en-us/sql/relational-databases/user-defined-functions/scalar-udf-inlining)

---

### 2.15 | Anti-Patterns & Best Practices
> **Kurzbeschreibung:** `FORMAT()` in OLTP, `WHERE LEFT(col,…)` statt sargierbarer Muster, Kulturabhängigkeiten, `TRY_*` bevorzugen.

- 📓 **Notebook:**  
  [`08_15_best_practices_anti_patterns.ipynb`](08_15_best_practices_anti_patterns.ipynb)

- 🎥 **YouTube:**  
  - [T-SQL Function Pitfalls](https://www.youtube.com/results?search_query=sql+server+function+performance+pitfalls)

- 📘 **Docs/Blog:**  
  - [`FORMAT` (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/functions/format-transact-sql)  
  - [SARGability – Grundlagen](https://www.brentozar.com/archive/2018/02/sargable-queries/)

---

## 3 | Weiterführende Informationen

- 📘 Microsoft Learn: [Functions (Transact-SQL) – Übersicht](https://learn.microsoft.com/en-us/sql/t-sql/functions/functions)  
- 📘 Microsoft Learn: [String Functions](https://learn.microsoft.com/en-us/sql/t-sql/functions/string-functions-transact-sql)  
- 📘 Microsoft Learn: [Mathematical Functions](https://learn.microsoft.com/en-us/sql/t-sql/functions/mathematical-functions-transact-sql)  
- 📘 Microsoft Learn: [Date and Time Functions](https://learn.microsoft.com/en-us/sql/t-sql/functions/date-and-time-data-types-and-functions-transact-sql)  
- 📘 Microsoft Learn: [Aggregate Functions](https://learn.microsoft.com/en-us/sql/t-sql/functions/aggregate-functions-transact-sql)  
- 📘 Microsoft Learn: [Ranking Functions](https://learn.microsoft.com/en-us/sql/t-sql/functions/ranking-functions-transact-sql)  
- 📘 Microsoft Learn: [JSON in SQL Server – Leitfaden](https://learn.microsoft.com/en-us/sql/relational-databases/json/json-data-sql-server)  
- 📘 Microsoft Learn: [`CAST`/`CONVERT`/`TRY_CONVERT`](https://learn.microsoft.com/en-us/sql/t-sql/functions/cast-and-convert-transact-sql)  
- 📘 Microsoft Learn: [Data Type Precedence](https://learn.microsoft.com/en-us/sql/t-sql/data-types/data-type-precedence-transact-sql)  
- 📘 Microsoft Learn: [Deterministic vs Non-Deterministic Functions](https://learn.microsoft.com/en-us/sql/relational-databases/user-defined-functions/deterministic-and-nondeterministic-functions)  
- 📘 Microsoft Learn: [Indexes on Computed Columns](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/indexes-on-computed-columns)  
- 📝 Blog (SQLPerformance): [Scalar UDFs & Performance](https://www.sqlperformance.com/?s=scalar+udf)  
- 📝 Blog (Brent Ozar): [SARGable Queries – Primer](https://www.brentozar.com/archive/2018/02/sargable-queries/)  
- 📝 Blog (Itzik Ben-Gan): [Windowing Patterns](https://tsql.solidq.com/)  
- 🎥 YouTube Playlist: [SQL Server Functions – Tutorials](https://www.youtube.com/results?search_query=sql+server+functions+tutorial)  

