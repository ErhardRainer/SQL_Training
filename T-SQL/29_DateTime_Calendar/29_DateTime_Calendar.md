# T-SQL DateTime & Kalender – Übersicht  
*Datumslogik: Zeiträume, Kalenderfunktionen, dynamische Zeitfilter*

## 1 | Begriffsdefinition

| SQL-Term | Beschreibung |
|---|---|
| Datums-/Zeittypen | `date`, `time(n)`, `datetime2(n)` (empfohlen), `datetime`, `smalldatetime`, `datetimeoffset(n)`. |
| Aktuelle Zeit | `SYSDATETIME()`, `SYSUTCDATETIME()`, `SYSDATETIMEOFFSET()`, `CURRENT_TIMESTAMP` (= `GETDATE()`). |
| Teile/Komponenten | `DATEPART`, `DATENAME`, `DATEFROMPARTS`/`TIMEFROMPARTS`/`DATETIME2FROMPARTS`. |
| Arithmetik | `DATEADD`, `DATEDIFF`/`DATEDIFF_BIG`, `EOMONTH`, **SQL 2022+:** `DATETRUNC`, `DATE_BUCKET`. |
| ISO-Kalender | `DATEPART(ISO_WEEK)`/`ISOWEEK`, `SET DATEFIRST` (erster Wochentag). |
| Zeiträume (Ranges) | Halboffene Intervalle **[start, end)**: `col >= @start AND col < @endExclusive` – **sargierbar & robust**. |
| SARGability | Funktionen **auf Spalten** (z. B. `CONVERT(date, Col)`) verhindern Index-Seeks → besser Literale/Variablen konvertieren. |
| Zeitzonen | `AT TIME ZONE`, `SWITCHOFFSET`; Speicherung oft **UTC** (`datetime2`) + Anzeige in Lokalzeit. |
| Dynamische Filter | „Heute“, „Gestern“, „letzte 7/30 Tage“, MTD/QTD/YTD – sauber per `DATEADD`/`DATETRUNC`/`EOMONTH`. |
| Kalenderdimension | Kalendertabelle mit Spalten (DateKey, Year/Quarter/Month/ISOWeek, IsBusinessDay, Holiday, …); erzeugbar via `GENERATE_SERIES` (SQL 2022+). |
| Formatierung | `FORMAT()` ist bequem aber **teuer** → nur Präsentation, nicht in großen Abfragen; besser `CONVERT`/Client. |
| Datenqualität | Strings → `TRY_CONVERT(datetime2, ...)`/`TRY_PARSE` (langsam/kulturabhängig). |

---

## 2 | Struktur

### 2.1 | Datums-/Zeittypen & Empfehlungen
> **Kurzbeschreibung:** Überblick über Typen, Präzision, Speicher; warum `datetime2`/`datetimeoffset` heutigen Standards entsprechen.

- 📓 **Notebook:**  
  [`08_01_datetypes_ueberblick.ipynb`](08_01_datetypes_ueberblick.ipynb)
- 🎥 **YouTube:**  
  - [SQL Server Date & Time Data Types](https://www.youtube.com/results?search_query=sql+server+date+and+time+data+types)
- 📘 **Docs:**  
  - [Date and Time types & functions](https://learn.microsoft.com/en-us/sql/t-sql/functions/date-and-time-data-types-and-functions-transact-sql)

---

### 2.2 | Aktuelle Zeitpunkte korrekt beziehen
> **Kurzbeschreibung:** Serverzeit vs. UTC, Offset-Varianten; wann welche Funktion.

- 📓 **Notebook:**  
  [`08_02_now_sysdatetime_varianten.ipynb`](08_02_now_sysdatetime_varianten.ipynb)
- 🎥 **YouTube:**  
  - [GETDATE vs SYSDATETIME](https://www.youtube.com/results?search_query=sql+server+getdate+sysdatetime)
- 📘 **Docs:**  
  - [`SYSDATETIME`, `SYSUTCDATETIME`, `SYSDATETIMEOFFSET`](https://learn.microsoft.com/en-us/sql/t-sql/functions/sysdatetime-transact-sql)

---

### 2.3 | Datumsteile & Trunkierung: `DATEPART`, `DATENAME`, `DATETRUNC` (SQL 2022+)
> **Kurzbeschreibung:** Komponenten lesen & auf Tag/Monat/Quartal/Jahr truncaten.

- 📓 **Notebook:**  
  [`08_03_datepart_datename_datetrunc.ipynb`](08_03_datepart_datename_datetrunc.ipynb)
- 🎥 **YouTube:**  
  - [DATETRUNC in SQL Server 2022](https://www.youtube.com/results?search_query=sql+server+datetrunc)
- 📘 **Docs:**  
  - [`DATEPART` / `DATENAME`](https://learn.microsoft.com/en-us/sql/t-sql/functions/datepart-transact-sql) ・ [`DATETRUNC`](https://learn.microsoft.com/en-us/sql/t-sql/functions/datetrunc-transact-sql)

---

### 2.4 | Datumsarithmetik: `DATEADD`, `DATEDIFF`, `EOMONTH`
> **Kurzbeschreibung:** Sicher addieren/subtrahieren, Monatsenden & Perioden berechnen.

- 📓 **Notebook:**  
  [`08_04_dateadd_datediff_eomonth.ipynb`](08_04_dateadd_datediff_eomonth.ipynb)
- 🎥 **YouTube:**  
  - [DATEADD / DATEDIFF / EOMONTH](https://www.youtube.com/results?search_query=sql+server+dateadd+datediff+eomonth)
- 📘 **Docs:**  
  - [`DATEADD`](https://learn.microsoft.com/en-us/sql/t-sql/functions/dateadd-transact-sql) ・ [`DATEDIFF` / `_BIG`](https://learn.microsoft.com/en-us/sql/t-sql/functions/datediff-transact-sql) ・ [`EOMONTH`](https://learn.microsoft.com/en-us/sql/t-sql/functions/eomonth-transact-sql)

---

### 2.5 | Wochen & ISO-Kalender: `SET DATEFIRST`, `ISOWEEK`
> **Kurzbeschreibung:** Lokale Woche vs. ISO-Woche; Auswirkungen auf Berichte/Filter.

- 📓 **Notebook:**  
  [`08_05_iso_week_datefirst.ipynb`](08_05_iso_week_datefirst.ipynb)
- 🎥 **YouTube:**  
  - [ISO Week in T-SQL](https://www.youtube.com/results?search_query=sql+server+iso+week)
- 📘 **Docs:**  
  - [`DATEPART(ISO_WEEK)`](https://learn.microsoft.com/en-us/sql/t-sql/functions/datepart-transact-sql#week-and-weekday-dateparts) ・ [`SET DATEFIRST`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-datefirst-transact-sql)

---

### 2.6 | Sargierbare Zeitfilter & halboffene Intervalle
> **Kurzbeschreibung:** Warum `col >= @start AND col < @endExclusive` überlegen ist; `BETWEEN`-Fallstricke mit `datetime`.

- 📓 **Notebook:**  
  [`08_06_sargierbare_zeitfilter.ipynb`](08_06_sargierbare_zeitfilter.ipynb)
- 🎥 **YouTube:**  
  - [SARGable Date Filters](https://www.youtube.com/results?search_query=sargable+date+filters+sql+server)
- 📘 **Docs:**  
  - [Index Design – SARGability](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-index-design-guide#search-arguments-sargability)

---

### 2.7 | Dynamische Zeiträume: Heute/Gestern/Letzte 7/30 Tage
> **Kurzbeschreibung:** Robust gegen Uhrzeitanteile; Beispiele mit `DATETRUNC`/`CONVERT(date, …)`.

- 📓 **Notebook:**  
  [`08_07_dynamische_zeitraeume_basis.ipynb`](08_07_dynamische_zeitraeume_basis.ipynb)
- 🎥 **YouTube:**  
  - [Common Date Ranges in T-SQL](https://www.youtube.com/results?search_query=sql+server+date+range+last+7+days)
- 📘 **Docs:**  
  - [`DATETRUNC`](https://learn.microsoft.com/en-us/sql/t-sql/functions/datetrunc-transact-sql)

---

### 2.8 | MTD/QTD/YTD & Vorperioden (PMTD/PQTD/PYTD)
> **Kurzbeschreibung:** Monats-/Quartals-/Jahres-bis-Datum und Vorjahresvergleiche mit `EOMONTH`/`DATEFROMPARTS`.

- 📓 **Notebook:**  
  [`08_08_mtd_qtd_ytd_patterns.ipynb`](08_08_mtd_qtd_ytd_patterns.ipynb)
- 🎥 **YouTube:**  
  - [MTD/QTD/YTD in SQL](https://www.youtube.com/results?search_query=sql+server+ytd+mtd+qtd)
- 📘 **Docs:**  
  - [`EOMONTH`](https://learn.microsoft.com/en-us/sql/t-sql/functions/eomonth-transact-sql) ・ [`DATEFROMPARTS`](https://learn.microsoft.com/en-us/sql/t-sql/functions/datefromparts-transact-sql)

---

### 2.9 | Bucketing & Zeitreihen: `DATE_BUCKET` (SQL 2022+)
> **Kurzbeschreibung:** Werte in 5-Min-/Stunden-/Tages-Buckets gruppieren – ideal für Telemetrie/Zeitreihen.

- 📓 **Notebook:**  
  [`08_09_date_bucket_zeitreihen.ipynb`](08_09_date_bucket_zeitreihen.ipynb)
- 🎥 **YouTube:**  
  - [DATE_BUCKET Overview](https://www.youtube.com/results?search_query=sql+server+date_bucket)
- 📘 **Docs:**  
  - [`DATE_BUCKET`](https://learn.microsoft.com/en-us/sql/t-sql/functions/date-bucket-transact-sql)

---

### 2.10 | Zeitzonen & DST: `AT TIME ZONE`, `SWITCHOFFSET`
> **Kurzbeschreibung:** UTC speichern, lokal anzeigen; Sommerzeit-Kanten & doppelte/fehlende Zeiten handhaben.

- 📓 **Notebook:**  
  [`08_10_zeitzonen_at_time_zone.ipynb`](08_10_zeitzonen_at_time_zone.ipynb)
- 🎥 **YouTube:**  
  - [AT TIME ZONE Examples](https://www.youtube.com/results?search_query=sql+server+at+time+zone)
- 📘 **Docs:**  
  - [`AT TIME ZONE`](https://learn.microsoft.com/en-us/sql/t-sql/queries/at-time-zone-transact-sql) ・ [`SWITCHOFFSET`](https://learn.microsoft.com/en-us/sql/t-sql/functions/switchoffset-transact-sql)

---

### 2.11 | Kalenderdimension bauen (inkl. Feiertage)
> **Kurzbeschreibung:** Kalenderzeilen generieren, Attribute befüllen, deutsche/ISO-Wochen, Feiertagslogik.

- 📓 **Notebook:**  
  [`08_11_kalenderdimension_generate.ipynb`](08_11_kalenderdimension_generate.ipynb)
- 🎥 **YouTube:**  
  - [Build a Calendar Table](https://www.youtube.com/results?search_query=sql+server+calendar+table)
- 📘 **Docs:**  
  - [`GENERATE_SERIES`](https://learn.microsoft.com/en-us/sql/t-sql/functions/generate-series-transact-sql)

---

### 2.12 | Performance: Indizes, Persisted Columns, Partitionierung
> **Kurzbeschreibung:** `date`/`datetime2` als Schlüssel, berechnete Spalten (z. B. `DateOnly`) **persistiert** + Index, Partitionierung nach Datum.

- 📓 **Notebook:**  
  [`08_12_perf_index_partition_date.ipynb`](08_12_perf_index_partition_date.ipynb)
- 🎥 **YouTube:**  
  - [Indexing Date Columns](https://www.youtube.com/results?search_query=sql+server+indexing+date+columns)
- 📘 **Docs:**  
  - [Partitioned Tables and Indexes](https://learn.microsoft.com/en-us/sql/relational-databases/partitions/partitioned-tables-and-indexes)

---

### 2.13 | Strings → Datum sicher: `TRY_CONVERT`/`TRY_PARSE`
> **Kurzbeschreibung:** Fehlerrobuste Konvertierung; Kulturabhängigkeit von `PARSE`; ISO-Formate bevorzugen.

- 📓 **Notebook:**  
  [`08_13_try_convert_parse_dates.ipynb`](08_13_try_convert_parse_dates.ipynb)
- 🎥 **YouTube:**  
  - [TRY_CONVERT for Dates](https://www.youtube.com/results?search_query=sql+server+try_convert+date)
- 📘 **Docs:**  
  - [`TRY_CONVERT` / `TRY_CAST`](https://learn.microsoft.com/en-us/sql/t-sql/functions/try-convert-transact-sql)

---

### 2.14 | Ausgabe & Formatierung – Kosten & Alternativen
> **Kurzbeschreibung:** `FORMAT()` vermeiden in Massendaten; besser `CONVERT(style)`/Clientformatierung.

- 📓 **Notebook:**  
  [`08_14_formatierung_output_dates.ipynb`](08_14_formatierung_output_dates.ipynb)
- 🎥 **YouTube:**  
  - [Why FORMAT() is slow](https://www.youtube.com/results?search_query=sql+server+format+function+performance)
- 📘 **Docs:**  
  - [`FORMAT`](https://learn.microsoft.com/en-us/sql/t-sql/functions/format-transact-sql) ・ [`CAST/CONVERT` Styles](https://learn.microsoft.com/en-us/sql/t-sql/functions/cast-and-convert-transact-sql#date-and-time-styles)

---

### 2.15 | Typische Reporting-Muster (Rolling Windows, Cohorts)
> **Kurzbeschreibung:** Rollierende 12 Monate, Wochenkohorten, „letzte vollständige Periode“.

- 📓 **Notebook:**  
  [`08_15_reporting_zeitfenster.ipynb`](08_15_reporting_zeitfenster.ipynb)
- 🎥 **YouTube:**  
  - [Rolling 12 Months SQL](https://www.youtube.com/results?search_query=sql+server+rolling+12+months)
- 📘 **Docs:**  
  - [Window Functions (für Datums-Cohorts nützlich)](https://learn.microsoft.com/en-us/sql/t-sql/queries/select-over-clause-transact-sql)

---

### 2.16 | Anti-Patterns & Checkliste
> **Kurzbeschreibung:** `WHERE CONVERT(date, Col)=…`, `BETWEEN` bei `datetime`, lokale Zeiten speichern, `FORMAT()` in OLTP, falsche `DATEFIRST`-Annahmen, nicht-deterministische Kalenderberechnungen in großen Scans.

- 📓 **Notebook:**  
  [`08_16_datetime_anti_patterns.ipynb`](08_16_datetime_anti_patterns.ipynb)
- 🎥 **YouTube:**  
  - [Date/Time Anti-Patterns](https://www.youtube.com/results?search_query=sql+server+date+time+anti+patterns)
- 📘 **Docs/Blog:**  
  - [Index Design Guide – SARGability](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-index-design-guide#search-arguments-sargability)

---

## 3 | Weiterführende Informationen

- 📘 Microsoft Learn: [Date/Time Types & Functions (Übersicht)](https://learn.microsoft.com/en-us/sql/t-sql/functions/date-and-time-data-types-and-functions-transact-sql)  
- 📘 Microsoft Learn: [`DATEADD`](https://learn.microsoft.com/en-us/sql/t-sql/functions/dateadd-transact-sql) ・ [`DATEDIFF`/`_BIG`](https://learn.microsoft.com/en-us/sql/t-sql/functions/datediff-transact-sql) ・ [`EOMONTH`](https://learn.microsoft.com/en-us/sql/t-sql/functions/eomonth-transact-sql)  
- 📘 Microsoft Learn: [`DATETRUNC` (SQL Server 2022+)](https://learn.microsoft.com/en-us/sql/t-sql/functions/datetrunc-transact-sql) ・ [`DATE_BUCKET` (SQL Server 2022+)](https://learn.microsoft.com/en-us/sql/t-sql/functions/date-bucket-transact-sql)  
- 📘 Microsoft Learn: [`AT TIME ZONE`](https://learn.microsoft.com/en-us/sql/t-sql/queries/at-time-zone-transact-sql) ・ [`SWITCHOFFSET`](https://learn.microsoft.com/en-us/sql/t-sql/functions/switchoffset-transact-sql) ・ [`SYSUTCDATETIME`](https://learn.microsoft.com/en-us/sql/t-sql/functions/sysdatetime-transact-sql)  
- 📘 Microsoft Learn: [`DATEPART`/`DATENAME` (inkl. ISO_WEEK)](https://learn.microsoft.com/en-us/sql/t-sql/functions/datepart-transact-sql) ・ [`SET DATEFIRST`](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-datefirst-transact-sql)  
- 📘 Microsoft Learn: [`DATEFROMPARTS`/`TIMEFROMPARTS`/`DATETIME2FROMPARTS`](https://learn.microsoft.com/en-us/sql/t-sql/functions/datefromparts-transact-sql)  
- 📘 Microsoft Learn: [`GENERATE_SERIES` (Kalenderzeilen)](https://learn.microsoft.com/en-us/sql/t-sql/functions/generate-series-transact-sql)  
- 📘 Microsoft Learn: [Partitioned Tables & Indexes](https://learn.microsoft.com/en-us/sql/relational-databases/partitions/partitioned-tables-and-indexes)  
- 📘 Microsoft Learn: [`FORMAT` – Hinweise & Kosten](https://learn.microsoft.com/en-us/sql/t-sql/functions/format-transact-sql) ・ [`CAST`/`CONVERT` Styles](https://learn.microsoft.com/en-us/sql/t-sql/functions/cast-and-convert-transact-sql#date-and-time-styles)  
- 📝 Itzik Ben-Gan: *Date and Time Intelligence in T-SQL* – Artikel/Beispiele (Suche)  
- 📝 Paul White (SQL Kiwi): *SARGability & Predicates on Dates* – https://www.sql.kiwi/  
- 📝 SQLPerformance: *Date Range Filtering & Indexes* – https://www.sqlperformance.com/?s=date+range  
- 📝 Erik Darling: *Why BETWEEN and datetime don’t mix* – https://www.erikdarlingdata.com/  
- 📝 Brent Ozar: *Storing Dates & Times (UTC!)* – https://www.brentozar.com/  
- 📝 Redgate Simple Talk: *Calendar Tables & Time Intelligence in SQL Server* – https://www.red-gate.com/simple-talk/  
- 🎥 YouTube Playlist: *T-SQL Date/Time Tips & Tricks* – (Suche)  
