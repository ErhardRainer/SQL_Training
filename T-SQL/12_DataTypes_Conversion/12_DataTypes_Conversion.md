# T-SQL Datentypen & Konvertierung – Übersicht  

## 1 | Begriffsdefinition

| SQL-Term | Beschreibung |
|---|---|
| Exakte numerische Typen | `bit`, `tinyint`/`smallint`/`int`/`bigint`, `decimal(p,s)`/`numeric(p,s)`; deterministische Rechenregeln. |
| Approximative Typen | `float(n)`/`real`; binäre Gleitkommawerte mit Rundungsfehlern – **nicht** für Geld/IDs. |
| Zeichen- & Unicode-Typen | `char(n)`/`varchar(n|max)`, `nchar(n)`/`nvarchar(n|max)`; Unicode benötigt `N'...'`-Literal. |
| Datum/Zeit | `date`, `time(n)`, `datetime`, `smalldatetime`, `datetime2(n)`, `datetimeoffset(n)`; `datetime2` bevorzugt. |
| Binär & LOB | `binary(n)`/`varbinary(n|max)`; ältere LOBs (`text`/`ntext`/`image`) sind veraltet. |
| Spezialtypen | `uniqueidentifier`, `rowversion`, `sql_variant`, `xml`, `hierarchyid`, `geography`/`geometry`. |
| Präzision/Skala | Bei `decimal(p,s)` gibt `p` die Gesamtstellen, `s` die Nachkommastellen an (max `p=38`). |
| Daten­typ­priorität | Bei Ausdrücken unterschiedlicher Typen bestimmt SQL Server den Zieltyp – kann implizite Konvertierungen erzwingen. |
| Implizite Konvertierung | Automatischer Typwechsel, z. B. `int`→`decimal`; kann **SARGability** und Indexnutzung zerstören. |
| `CAST` vs. `CONVERT` | Beide konvertieren explizit; `CONVERT` hat **Style-Codes** v. a. für Datum/Zeit/Text. |
| `TRY_CAST`/`TRY_CONVERT`/`TRY_PARSE` | Geben bei unzulässiger Konvertierung `NULL` statt Fehler. `PARSE`/`TRY_PARSE` sind kulturabhängig & langsamer. |
| Kollation (`COLLATE`) | Regeln für Vergleich/Sortierung von Zeichenketten; Kollisionsauflösung bei Mischkollationen. |
| Formatierung | `FORMAT()` ist bequem, aber **teuer**; für Berichte ok, nicht für Massendaten. |
| SARGability | Funktionen/Konvertierungen **auf Spalten** in `WHERE`/`JOIN` verhindern oft Index-Seeks. |
| Überlauf/Rundung | Konvertierungen können abschneiden/aufrunden; `CHECK`/Tests zur Absicherung. |

---

## 2 | Struktur

### 2.1 | Datentyp-Landkarte & Empfehlungen
> **Kurzbeschreibung:** Überblick über T-SQL-Datentypfamilien, moderne Alternativen (`datetime2`, `nvarchar`) und Einsatzrichtlinien.

- 📓 **Notebook:**  
  [`08_01_datentypen_ueberblick.ipynb`](08_01_datentypen_ueberblick.ipynb)

- 🎥 **YouTube:**  
  - [SQL Server Data Types – Overview](https://www.youtube.com/results?search_query=sql+server+data+types+overview)

- 📘 **Docs:**  
  - [Data types (Database Engine)](https://learn.microsoft.com/en-us/sql/t-sql/data-types/data-types-transact-sql)

---

### 2.2 | Daten­typ­priorität & implizite Konvertierung
> **Kurzbeschreibung:** Wie SQL Server Zielformate bestimmt; Kosten/Pläne, typische SARGability-Fallen.

- 📓 **Notebook:**  
  [`08_02_datentyp_prioritaet_implizit.ipynb`](08_02_datentyp_prioritaet_implizit.ipynb)

- 🎥 **YouTube:**  
  - [Implicit Conversions – Performance](https://www.youtube.com/results?search_query=sql+server+implicit+conversion+performance)

- 📘 **Docs:**  
  - [Data Type Precedence](https://learn.microsoft.com/en-us/sql/t-sql/data-types/data-type-precedence-transact-sql)  
  - [CAST and CONVERT – Remarks](https://learn.microsoft.com/en-us/sql/t-sql/functions/cast-and-convert-transact-sql)

---

### 2.3 | `CAST`/`CONVERT` vs. `TRY_*` & `PARSE`
> **Kurzbeschreibung:** Explizite vs. tolerante Konvertierung, Style-Codes, Kulturabhängigkeit.

- 📓 **Notebook:**  
  [`08_03_cast_convert_try_parse.ipynb`](08_03_cast_convert_try_parse.ipynb)

- 🎥 **YouTube:**  
  - [CAST vs CONVERT vs TRY_CONVERT](https://www.youtube.com/results?search_query=sql+server+cast+convert+try_convert)

- 📘 **Docs:**  
  - [`CAST`/`CONVERT`](https://learn.microsoft.com/en-us/sql/t-sql/functions/cast-and-convert-transact-sql)  
  - [`TRY_CONVERT` / `TRY_CAST` / `TRY_PARSE`](https://learn.microsoft.com/en-us/sql/t-sql/functions/try-convert-transact-sql)

---

### 2.4 | Dezimalpräzision & Skalen richtig wählen
> **Kurzbeschreibung:** `decimal(p,s)`-Arithmetik, Rundung/Überlauf, `ROUND`/`CEILING`/`FLOOR`, Geldwerte robust speichern.

- 📓 **Notebook:**  
  [`08_04_decimal_praezision_skalen.ipynb`](08_04_decimal_praezision_skalen.ipynb)

- 🎥 **YouTube:**  
  - [DECIMAL Precision & Scale](https://www.youtube.com/results?search_query=sql+server+decimal+precision+scale)

- 📘 **Docs:**  
  - [`decimal`/`numeric`](https://learn.microsoft.com/en-us/sql/t-sql/data-types/decimal-and-numeric-transact-sql)  
  - [`ROUND` (T-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/functions/round-transact-sql)

---

### 2.5 | `money`/`smallmoney` vs. `decimal`
> **Kurzbeschreibung:** Gründe für/gegen `money`, Rundungs- und Konvertierungsbesonderheiten; Empfehlung: i. d. R. `decimal`.

- 📓 **Notebook:**  
  [`08_05_money_vs_decimal.ipynb`](08_05_money_vs_decimal.ipynb)

- 🎥 **YouTube:**  
  - [Money vs Decimal – Pitfalls](https://www.youtube.com/results?search_query=sql+server+money+vs+decimal)

- 📘 **Docs/Blog:**  
  - [`money` (Datentyp)](https://learn.microsoft.com/en-us/sql/t-sql/data-types/money-and-smallmoney-transact-sql)

---

### 2.6 | `float`/`real` – Genauigkeit & Vergleich
> **Kurzbeschreibung:** Binäre Gleitkommaarithmetik, Toleranzvergleiche, Casting-Fallen.

- 📓 **Notebook:**  
  [`08_06_float_real_genauigkeit.ipynb`](08_06_float_real_genauigkeit.ipynb)

- 🎥 **YouTube:**  
  - [Floating Point in SQL Server](https://www.youtube.com/results?search_query=sql+server+float+precision)

- 📘 **Docs:**  
  - [`float`/`real`](https://learn.microsoft.com/en-us/sql/t-sql/data-types/float-and-real-transact-sql)

---

### 2.7 | Datums-/Zeittypen: `datetime2` bevorzugen
> **Kurzbeschreibung:** Unterschiede `datetime`/`smalldatetime`/`datetime2`/`datetimeoffset`, Zeitzonen, Styles.

- 📓 **Notebook:**  
  [`08_07_datetime2_datetimeoffset.ipynb`](08_07_datetime2_datetimeoffset.ipynb)

- 🎥 **YouTube:**  
  - [Date & Time Types – Guide](https://www.youtube.com/results?search_query=sql+server+datetime2+datetimeoffset)

- 📘 **Docs:**  
  - [Date and Time types](https://learn.microsoft.com/en-us/sql/t-sql/data-types/date-and-time-types-transact-sql)  
  - [`CONVERT` Styles (Date/Time)](https://learn.microsoft.com/en-us/sql/t-sql/functions/cast-and-convert-transact-sql#date-and-time-styles)

---

### 2.8 | Strings & Kollation: `varchar` vs. `nvarchar`
> **Kurzbeschreibung:** Unicode vs. Codepages, `N'...'`-Literale, Sortierung/Suche, Kollationskonflikte gezielt lösen.

- 📓 **Notebook:**  
  [`08_08_strings_kollation_unicode.ipynb`](08_08_strings_kollation_unicode.ipynb)

- 🎥 **YouTube:**  
  - [Collation & Unicode Basics](https://www.youtube.com/results?search_query=sql+server+collation+unicode)

- 📘 **Docs:**  
  - [Collation and Unicode support](https://learn.microsoft.com/en-us/sql/relational-databases/collations/collation-and-unicode-support)  
  - [Collation Precedence & `COLLATE`](https://learn.microsoft.com/en-us/sql/t-sql/statements/collation-precedence-transact-sql)

---

### 2.9 | SARGability & Konvertierungen in Prädikaten
> **Kurzbeschreibung:** Warum `WHERE CAST(Col AS …)=…` Seeks verhindert; Alternativen (konvertiere **Literal**, nicht Spalte).

- 📓 **Notebook:**  
  [`08_09_sargability_konvertierungen_where.ipynb`](08_09_sargability_konvertierungen_where.ipynb)

- 🎥 **YouTube:**  
  - [SARGable Predicates – How-To](https://www.youtube.com/results?search_query=sargable+predicates+sql+server)

- 📘 **Docs/Blog:**  
  - [Index Design Guide](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-index-design-guide)

---

### 2.10 | `sql_variant`, `uniqueidentifier`, `rowversion`
> **Kurzbeschreibung:** Einsatzgrenzen, Sortierung/Indexierung, Konvertierungsregeln dieser Spezialtypen.

- 📓 **Notebook:**  
  [`08_10_spezialtypen_variant_guid_rowversion.ipynb`](08_10_spezialtypen_variant_guid_rowversion.ipynb)

- 🎥 **YouTube:**  
  - [GUIDs & Rowversion – Praxis](https://www.youtube.com/results?search_query=sql+server+uniqueidentifier+rowversion)

- 📘 **Docs:**  
  - [`uniqueidentifier`](https://learn.microsoft.com/en-us/sql/t-sql/data-types/uniqueidentifier-transact-sql) · [`rowversion`](https://learn.microsoft.com/en-us/sql/t-sql/data-types/rowversion-transact-sql)  
  - [`sql_variant`](https://learn.microsoft.com/en-us/sql/t-sql/data-types/sql-variant-transact-sql)

---

### 2.11 | Binärdaten & Hex: `varbinary`, Konvertierung, Hashes
> **Kurzbeschreibung:** Bytes speichern, Hex-Literale/`CONVERT`-Styles, Hashfunktionen (`HASHBYTES`).

- 📓 **Notebook:**  
  [`08_11_varbinary_hex_hash.ipynb`](08_11_varbinary_hex_hash.ipynb)

- 🎥 **YouTube:**  
  - [Working with VARBINARY](https://www.youtube.com/results?search_query=sql+server+varbinary+convert+hex)

- 📘 **Docs:**  
  - [`varbinary`](https://learn.microsoft.com/en-us/sql/t-sql/data-types/binary-and-varbinary-transact-sql)  
  - [`HASHBYTES`](https://learn.microsoft.com/en-us/sql/t-sql/functions/hashbytes-transact-sql)

---

### 2.12 | XML/JSON & Typkonvertierung
> **Kurzbeschreibung:** `XML`-Typ, `value()`-Extraktion; JSON: `OPENJSON`, `JSON_VALUE` (Längen/Typen!), `TRY_CONVERT` nutzen.

- 📓 **Notebook:**  
  [`08_12_xml_json_conversion.ipynb`](08_12_xml_json_conversion.ipynb)

- 🎥 **YouTube:**  
  - [JSON/XML in T-SQL](https://www.youtube.com/results?search_query=sql+server+json+xml+t-sql)

- 📘 **Docs:**  
  - [`XML` (Datentyp)](https://learn.microsoft.com/en-us/sql/relational-databases/xml/xml-data-type-methods-reference)  
  - [JSON (SQL Server)](https://learn.microsoft.com/en-us/sql/relational-databases/json/json-data-sql-server)

---

### 2.13 | Länge, Kürzung & Kodierung
> **Kurzbeschreibung:** Abschneiden und Erweiterung bei `varchar(n)`/`nvarchar(n)`, `TRUNCATEONLY` gibt es nicht; defensive Tests.

- 📓 **Notebook:**  
  [`08_13_laenge_kuerzung_kodierung.ipynb`](08_13_laenge_kuerzung_kodierung.ipynb)

- 🎥 **YouTube:**  
  - [String Truncation – Avoid it](https://www.youtube.com/results?search_query=sql+server+string+truncation)

- 📘 **Docs:**  
  - [String/Unicode Datentypen](https://learn.microsoft.com/en-us/sql/t-sql/data-types/char-and-varchar-transact-sql)

---

### 2.14 | Style-Codes & Formatierung (Datum/Zahl/Text)
> **Kurzbeschreibung:** `CONVERT(style)`-Tabellen, ISO-Formate bevorzugen, `FORMAT()`-Kosten.

- 📓 **Notebook:**  
  [`08_14_convert_styles_format.ipynb`](08_14_convert_styles_format.ipynb)

- 🎥 **YouTube:**  
  - [CONVERT Styles Explained](https://www.youtube.com/results?search_query=sql+server+convert+style+codes)

- 📘 **Docs:**  
  - [`CONVERT` – Styles](https://learn.microsoft.com/en-us/sql/t-sql/functions/cast-and-convert-transact-sql#date-and-time-styles)  
  - [`FORMAT`](https://learn.microsoft.com/en-us/sql/t-sql/functions/format-transact-sql)

---

### 2.15 | Speicherlayout, Row-Size & LOBs
> **Kurzbeschreibung:** Seiten-/Zeilengrößen (8 KB), In-Row/Off-Row, `varchar(max)`/`varbinary(max)`, Auswirkungen auf IO/Pläne.

- 📓 **Notebook:**  
  [`08_15_speicherlayout_row_lob.ipynb`](08_15_speicherlayout_row_lob.ipynb)

- 🎥 **YouTube:**  
  - [Row Size & LOB Storage](https://www.youtube.com/results?search_query=sql+server+row+overflow+lob+storage)

- 📘 **Docs/Blog:**  
  - [Row-Overflow/LOB Storage](https://learn.microsoft.com/en-us/sql/relational-databases/tables/table-and-row-structures)  

---

### 2.16 | Anti-Patterns & Checkliste
> **Kurzbeschreibung:** `WHERE CAST(Col AS …)=…`, `float` für Geld/IDs, fehlende `N'…'`, `datetime` statt `datetime2`, `PARSE` im OLTP, `FORMAT` in Massenabfragen.

- 📓 **Notebook:**  
  [`08_16_datentypen_anti_patterns.ipynb`](08_16_datentypen_anti_patterns.ipynb)

- 🎥 **YouTube:**  
  - [Common Data Type Mistakes](https://www.youtube.com/results?search_query=sql+server+data+type+mistakes)

- 📘 **Docs/Blog:**  
  - [SARGability – Primer](https://www.brentozar.com/archive/2018/02/sargable-queries/)

---

## 3 | Weiterführende Informationen

- 📘 Microsoft Learn: [Data types (T-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/data-types/data-types-transact-sql)  
- 📘 Microsoft Learn: [`CAST` & `CONVERT`](https://learn.microsoft.com/en-us/sql/t-sql/functions/cast-and-convert-transact-sql) · [`TRY_CONVERT`/`TRY_CAST`/`TRY_PARSE`](https://learn.microsoft.com/en-us/sql/t-sql/functions/try-convert-transact-sql)  
- 📘 Microsoft Learn: [Data Type Precedence](https://learn.microsoft.com/en-us/sql/t-sql/data-types/data-type-precedence-transact-sql)  
- 📘 Microsoft Learn: [Date and Time types & functions](https://learn.microsoft.com/en-us/sql/t-sql/functions/date-and-time-data-types-and-functions-transact-sql)  
- 📘 Microsoft Learn: [Collation & Unicode Support](https://learn.microsoft.com/en-us/sql/relational-databases/collations/collation-and-unicode-support) · [Collation Precedence](https://learn.microsoft.com/en-us/sql/t-sql/statements/collation-precedence-transact-sql)  
- 📘 Microsoft Learn: [`decimal`/`numeric`](https://learn.microsoft.com/en-us/sql/t-sql/data-types/decimal-and-numeric-transact-sql) · [`money`](https://learn.microsoft.com/en-us/sql/t-sql/data-types/money-and-smallmoney-transact-sql)  
- 📘 Microsoft Learn: [`float`/`real`](https://learn.microsoft.com/en-us/sql/t-sql/data-types/float-and-real-transact-sql)  
- 📘 Microsoft Learn: [`uniqueidentifier`](https://learn.microsoft.com/en-us/sql/t-sql/data-types/uniqueidentifier-transact-sql) · [`rowversion`](https://learn.microsoft.com/en-us/sql/t-sql/data-types/rowversion-transact-sql)  
- 📘 Microsoft Learn: [XML Data Type](https://learn.microsoft.com/en-us/sql/relational-databases/xml/xml-data-type-methods-reference) · [JSON in SQL Server](https://learn.microsoft.com/en-us/sql/relational-databases/json/json-data-sql-server)  
- 📝 SQLPerformance: *Implicit Conversion & Plan Quality* – https://www.sqlperformance.com/?s=implicit+conversion  
- 📝 Simple Talk (Redgate): *Choosing the Right Data Types* – https://www.red-gate.com/simple-talk/?s=data+types  
- 📝 Itzik Ben-Gan: *Formatting vs Data Types (why FORMAT hurts)* – https://tsql.solidq.com/  
- 📝 Erik Darling: *SARGability & Casting Literals* – https://www.erikdarlingdata.com/  
- 🎥 YouTube Playlist: *SQL Server Data Types & Conversion* – https://www.youtube.com/results?search_query=sql+server+data+types+conversion  
