# 02_02_select_ausdruecke_case_cast

**Quelle:** `T-SQL\02_Select\02_02_select_ausdruecke_case_cast.ipynb`  
**Generiert:** 2026-04-18 21:13:30  
**Markdown-Zellen:** 33  
**SQL-Zellen:** 27  

---

# T-SQL SELECT – Ausdrücke, CASE, CAST/CONVERT, ISNULL/COALESCE

**Themengebiet:** SELECT

**Kapitel:** Ausdrücke, CASE, CAST/CONVERT, ISNULL/COALESCE

**Kurzbeschreibung:** Werte berechnen, bedingt ableiten und sauber typisieren; Fallstricke mit FORMAT() vermeiden.

**Stand:** 6. September 2025


Dieses Notebook zeigt, wie in T‑SQL Ausdrücke aufgebaut werden, wie Sie mit `CASE` bedingt Werte ableiten, mit `CAST`/`CONVERT`/`TRY_CONVERT` sauber typisieren und mit `ISNULL`/`COALESCE` Nullwerte behandeln. Außerdem beleuchten wir die Risiken von `FORMAT()` (Performance, Sortierung, SARGability) und stellen bessere Alternativen vor.

**Typische Fragestellungen:**
- Wie berechne ich neue Spalten (z. B. Umsatz = Menge × Preis) und kontrolliere dabei Datentypen?
- Wann nehme ich `CASE` (simple vs. searched) und worauf muss ich achten?
- Was ist der Unterschied zwischen `ISNULL` und `COALESCE` – insbesondere beim Rückgabetyp?
- Wie formatiere ich Datum/Zahl in Text, ohne mir Indizes/Sortierung kaputt zu machen?
- Wie verhindere ich unerwünschte implizite Konvertierungen und Genauigkeitsverluste?


**Inhalt dieses Notebooks ist:**

- Setup & Demo‑Daten
- Logische Auswertungsreihenfolge (SELECT)
- Arithmetische & Zeichenketten‑Ausdrücke
- `CASE` – einfache vs. bedingte Form
- Nullbehandlung mit `ISNULL` vs. `COALESCE`
- Typisierung mit `CAST`/`CONVERT`/`TRY_CONVERT`
- Datum/Zahl formatiert ausgeben – Alternativen zu `FORMAT()`
- WHERE vs. SELECT‑Ausdruck (Auswertungsreihenfolge)
- Window‑Funktionen als Alternative zu `CASE` in Ausdrücken
- Query Optimizer/Analyzer & Ausführungsplan (Compute Scalar & implizite Konvertierungen)
- Typische Fallstricke
- Best Practices & Performance
- Übungen
- Lösungen
- Querverweise
- Cleanup (optional)


Hinweis: Dieses Notebook nutzt einen **SQL‑Kernel**. **Alle Codezellen enthalten T‑SQL** (SQL Server).


## Setup & Demo‑Daten

Wir verwenden eine Beispiel‑Datenbank **BITest** und eine durchgängige Tabelle **dbo.SalesOrders**.
Die Daten enthalten gezielt `NULL`‑Werte und unterschiedliche Datentypen für Demonstrationen.


```sql
IF DB_ID(N'BITest') IS NULL
BEGIN
    CREATE DATABASE BITest;
END;
GO
USE [BITest];
GO
IF OBJECT_ID(N'dbo.SalesOrders','U') IS NOT NULL DROP TABLE dbo.SalesOrders;
CREATE TABLE dbo.SalesOrders
(
    SalesOrderID int IDENTITY(1,1) PRIMARY KEY,
    OrderDate     date      NOT NULL,
    ShipDate      date      NULL,
    Region        nvarchar(20) NOT NULL,
    Category      nvarchar(20) NULL,
    CustomerID    int       NOT NULL,
    Quantity      int       NOT NULL,
    UnitPrice     decimal(10,2) NOT NULL,
    Discount      decimal(4,2)  NULL,
    CurrencyCode  char(3)   NOT NULL CONSTRAINT DF_SalesOrders_Currency DEFAULT('EUR'),
    Notes         nvarchar(100) NULL
);
INSERT INTO dbo.SalesOrders (OrderDate,ShipDate,Region,Category,CustomerID,Quantity,UnitPrice,Discount,CurrencyCode,Notes)
VALUES
('2025-01-05','2025-01-08',N'West', N'Hardware', 101, 3,  19.99, 0.10,'EUR', NULL),
('2025-01-05',NULL,        N'West', N'Hardware', 102, 1, 199.00, NULL,'EUR', N'Express?'),
('2025-02-14','2025-02-16',N'Nord', N'Software', 103, 5,  49.50, 0.00,'EUR', N'Valentins‑Promo'),
('2025-03-01','2025-03-04',N'Sued', NULL,        104, 2, 999.90, 0.15,'USD', N'Auslandsdeal'),
('2025-03-18','2025-03-20',N'Ost',  N'Hardware', 105, 10,  5.00, 0.05,'EUR', N'Bulk'),
('2025-04-02',NULL,        N'West', N'Software', 106, 0,  49.50, NULL,'EUR', N'Gratis‑Upgrade'),
('2025-05-20','2025-05-21',N'Nord', N'Hardware', 107, 7,  12.30, NULL,'EUR', NULL)
;

```

### Daten sichten


```sql
USE [BITest];
SELECT TOP (10) * FROM dbo.SalesOrders ORDER BY SalesOrderID;
```

## Logische Auswertungsreihenfolge
Die logische Verarbeitungsreihenfolge erinnert daran, **wo** Ausdrücke wirken:

1. FROM / JOIN
2. WHERE (Filter auf *Zeilenebene* – hier dürfen keine Alias aus SELECT verwendet werden)
3. GROUP BY
4. HAVING
5. SELECT (Spaltenausdrücke; Alias definiert)
6. ORDER BY

Häufige Folge: Ein Ausdruck, der in `SELECT` definiert ist, steht in `WHERE` **noch nicht** zur Verfügung.


## Arithmetische & Zeichenketten‑Ausdrücke


*Fragestellung:* Wie berechne ich Umsatz und erzeugte Texte sicher – inkl. NULL‑Behandlung?


```sql
USE [BITest];
-- Umsatz = Menge * Preis * (1 - COALESCE(Discount,0))
SELECT
  SalesOrderID,
  Quantity,
  UnitPrice,
  Discount,
  CAST(Quantity * UnitPrice * (1 - COALESCE(Discount,0)) AS decimal(12,2)) AS Revenue,
  CONCAT(N'Kunde ', CustomerID, N' in ', Region, N' | ', FORMAT(OrderDate,'yyyy-MM-dd')) AS InfoText
FROM dbo.SalesOrders;
```

## `CASE` – einfache vs. bedingte Form


*Fragestellung:* Wie klassifiziere ich Aufträge nach Status/Kategorie?


```sql
USE [BITest];
SELECT SalesOrderID, Category, ShipDate, OrderDate,
  -- Simple CASE (exakte Gleichheit)
  CASE Category
    WHEN N'Hardware' THEN N'HW'
    WHEN N'Software' THEN N'SW'
    ELSE N'Unbekannt'
  END AS CategoryCode,
  -- Searched CASE (beliebige Bedingungen)
  CASE
    WHEN ShipDate IS NULL THEN N'Offen'
    WHEN DATEDIFF(day, OrderDate, ShipDate) <= 2 THEN N'Schnell geliefert'
    ELSE N'Normal geliefert'
  END AS DeliveryStatus
FROM dbo.SalesOrders;
```

## Nullbehandlung mit `ISNULL` vs. `COALESCE`


*Fragestellung:* Welchen Typ liefert die Funktion – und hat das Auswirkungen auf Genauigkeit/Länge?


```sql
USE [BITest];
-- Unterschiedlicher Rückgabetyp: ISNULL nimmt Typ des 1. Arguments; COALESCE folgt Typpräzedenz
SELECT
  SalesOrderID,
  -- Decimal vs. int: hier kann ISNULL runden, COALESCE behält Skala
  ISNULL(Discount, 0)     AS Discount_ISNULL,
  COALESCE(Discount, 0.0) AS Discount_COALESCE,
  -- Länge mit Strings
  LEN(ISNULL(CAST(NULL AS varchar(5)), 'fallback'))     AS Len_ISNULL,
  LEN(COALESCE(CAST(NULL AS varchar(5)), CAST('fallback' AS varchar(50)))) AS Len_COALESCE
FROM dbo.SalesOrders;
```

## Typisierung mit `CAST`/`CONVERT`/`TRY_CONVERT`


*Fragestellung:* Wie stelle ich robust sicher, dass Ausdrücke den gewünschten Datentyp haben – inkl. Fehlerbehandlung?


```sql
USE [BITest];
SELECT SalesOrderID,
  CAST(UnitPrice AS money)                 AS UnitPrice_money,
  CONVERT(varchar(10), OrderDate, 23)      AS OrderDate_yyyy_mm_dd,
  TRY_CONVERT(int, Notes)                  AS Notes_as_int_or_null,
  TRY_CONVERT(decimal(10,2), Discount*100) AS DiscountPct
FROM dbo.SalesOrders;
```

## Datum/Zahl formatiert ausgeben – Alternativen zu `FORMAT()`


*Fragestellung:* Wie erzeuge ich `yyyy-MM` bzw. lokalisierte Texte ohne teures CLR‑`FORMAT()`?


```sql
USE [BITest];
SELECT SalesOrderID, OrderDate,
  -- ISO‑Datum (YYYY‑MM‑DD)
  CONVERT(char(10), OrderDate, 23)               AS ISO_Date,
  -- YYYY‑MM (ohne FORMAT): sicher über YEAR/MONTH zusammensetzen
  CONCAT(YEAR(OrderDate), '-', RIGHT('0'+CAST(MONTH(OrderDate) AS varchar(2)),2)) AS YYYY_MM,
  -- Währungsstring kontrolliert zusammenbauen
  CONCAT(CurrencyCode, ' ', CAST(UnitPrice AS varchar(20))) AS PriceText
FROM dbo.SalesOrders;
```

## WHERE vs. SELECT‑Ausdruck (Auswertungsreihenfolge)


*Fragestellung:* Warum kann ich einen in SELECT definierten Alias nicht in WHERE verwenden – und wie löse ich das?


```sql
USE [BITest];
WITH S AS (
  SELECT SalesOrderID,
         Quantity * UnitPrice AS Gross
  FROM dbo.SalesOrders
)
SELECT * FROM S WHERE Gross > 100;
```

## Window‑Funktionen vs. `CASE` in Ausdrücken


*Fragestellung:* Wie berechne ich laufende Summen/Anteile ohne zusätzliche Aggregationsabfragen?


```sql
USE [BITest];
SELECT SalesOrderID, Region,
  CAST(Quantity * UnitPrice * (1 - COALESCE(Discount,0)) AS decimal(12,2)) AS Revenue,
  SUM(CAST(Quantity * UnitPrice * (1 - COALESCE(Discount,0)) AS decimal(12,2)))
    OVER (PARTITION BY Region ORDER BY SalesOrderID ROWS UNBOUNDED PRECEDING) AS RunningRevenue_Region
FROM dbo.SalesOrders
ORDER BY Region, SalesOrderID;
```

## Implizite Konvertierungen & SARGability


*Fragestellung:* Wie vermeide ich Index‑Verhinderer durch Typmischungen in Ausdrücken?


```sql
USE [BITest];
-- Beispiel: Vergleich Zahl mit Text verursacht implizite Konvertierung
DECLARE @minRevenue decimal(12,2) = 100.00;
SELECT SalesOrderID, Quantity, UnitPrice
FROM dbo.SalesOrders
WHERE CAST(Quantity * UnitPrice AS decimal(12,2)) >= @minRevenue;
```

## Query Optimizer/Analyzer & Ausführungsplan
Bei Ausdrücken erscheinen häufig **Compute Scalar**‑Operatoren. Implizite Konvertierungen können zu **Index Scans** führen.

**Pipeline (vereinfacht):** Parsing → Binder → Optimizer → Plan‑Cache → Executor

**Typische Operatoren:** Compute Scalar, Filter, Hash Match, Stream Aggregate, Sort, Parallelism, Memory Grants, Cardinality Estimator (CE)

**Erwartete Pläne (sprachlich):**
- Berechnete Spalten erzeugen `Compute Scalar`.
- `TRY_CONVERT` kann Filter weniger selektiv machen (liefert `NULL` statt Fehler), ggf. separate Validierungsschritte einplanen.
- String‑Formatierung in `SELECT` beeinflusst Filter nicht, aber kann CPU kosten (`FORMAT()`).

**Snippets (nicht ausführen):**
```sql
SET SHOWPLAN_XML ON;  -- Plan nur anzeigen
SELECT ...;            
SET SHOWPLAN_XML OFF;

SET STATISTICS IO, TIME, XML ON;  -- Messwerte
SELECT ...;
SET STATISTICS IO, TIME, XML OFF;
```


```sql
USE [BITest];
-- Beispielabfrage mit Compute Scalar & TRY_CONVERT
SELECT SalesOrderID,
       TRY_CONVERT(decimal(12,2), Quantity * UnitPrice) AS Revenue
FROM dbo.SalesOrders
WHERE COALESCE(Discount,0) <= 0.1;
```

## Typische Fallstricke


**Fall 1 – `FORMAT()` ist bequem, aber teuer**
*Fragestellung:* Wie erzeuge ich `yyyy-MM` performant?


```sql
USE [BITest];
-- Falsch / ungünstig (CLR‑basiert, nicht SARGable)
SELECT SalesOrderID, FORMAT(OrderDate,'yyyy-MM') AS yyyy_mm
FROM dbo.SalesOrders;
```

```sql
USE [BITest];
-- Korrekt / besser: ohne FORMAT()
SELECT SalesOrderID,
       CONCAT(YEAR(OrderDate), '-', RIGHT('0'+CAST(MONTH(OrderDate) AS varchar(2)),2)) AS yyyy_mm
FROM dbo.SalesOrders;
```

**Fall 2 – `ISNULL` übernimmt den Typ des ersten Arguments**
*Fragestellung:* Warum wird `Discount` gerundet?


```sql
USE [BITest];
-- Fehlerhaft: 0 ist int → Ergebnis int (0/1)
SELECT SalesOrderID, ISNULL(Discount, 0) AS Discount_ISNULL
FROM dbo.SalesOrders;
```

```sql
USE [BITest];
-- Korrektur: Dezimalliteral verwenden oder COALESCE mit 0.0
SELECT SalesOrderID, COALESCE(Discount, 0.0) AS Discount_OK
FROM dbo.SalesOrders;
```

**Fall 3 – Integer‑Division**
*Fragestellung:* Warum ist der Anteil 0 statt 0,15?


```sql
USE [BITest];
-- Fehlerhaft: beide Operanden int → ganzzahlige Division
SELECT 3/20 AS Anteil;
```

```sql
USE [BITest];
-- Korrektur: Typ heben
SELECT 3.0/20 AS Anteil;
```

**Fall 4 – Alias in `WHERE`**
*Fragestellung:* Warum ist der Alias `Revenue` in `WHERE` unbekannt?


```sql
USE [BITest];
-- Fehlerhaft: Alias in WHERE nicht sichtbar
SELECT Quantity * UnitPrice AS Revenue
FROM dbo.SalesOrders
WHERE Revenue > 100;
```

```sql
USE [BITest];
-- Korrektur: CTE/Derived Table oder Ausdruck wiederholen
WITH S AS (
  SELECT Quantity * UnitPrice AS Revenue
  FROM dbo.SalesOrders
)
SELECT * FROM S WHERE Revenue > 100;
```

**Fall 5 – Implizite Konvertierung verhindert SARGability**
*Fragestellung:* Warum nutzt der Plan keinen Index mehr?


```sql
USE [BITest];
-- Fehlerhaftes Pattern
DECLARE @d nvarchar(10) = CONVERT(nvarchar(10), '2025-03-01');
SELECT * FROM dbo.SalesOrders WHERE OrderDate = @d;  -- implizite Konvertierung

```

```sql
USE [BITest];
-- Korrektur: passender Typ
DECLARE @d date = '2025-03-01';
SELECT * FROM dbo.SalesOrders WHERE OrderDate = @d;
```

## Best Practices & Performance
- Typisierung **explizit** mit `CAST`/`CONVERT`/`TRY_CONVERT` – keine stillen impliziten Konvertierungen.
- `COALESCE` bevorzugen, wenn Typpräzedenz gewünscht ist; bei `ISNULL` den **ersten Operand** sorgfältig wählen.
- `FORMAT()` nur für **kleine Ergebnis‑Mengen** verwenden; für Berichte/API i. d. R. Strings **außerhalb** der Datenbank bauen.
- In Filtern keine berechneten Ausdrücke über Spalten → besser in `WHERE` mit Parameter passender Typen arbeiten.
- Datumsstrings vermeiden – Date/Time‑Typen nutzen.
- Für reproduzierbare Ausgabeformate ISO‑Stile (`CONVERT(..., 23)` etc.) oder zusammengesetzte Strings verwenden.


## Übungen
1. Ermitteln Sie `Revenue` je Zeile als `decimal(12,2)` und klassifizieren Sie die Zeilen in `High` (≥ 200) bzw. `Low`.
2. Geben Sie `OrderDate` als `yyyy-MM` aus **ohne** `FORMAT()`.
3. Ersetzen Sie `NULL` in `Discount` sinnvoll und zeigen Sie den Unterschied zwischen `ISNULL` und `COALESCE`.
4. Bilden Sie eine laufende Summe `RunningRevenue` pro Region.
5. Filtern Sie alle Zeilen mit `OrderDate` = 2025‑03‑01 **ohne** implizite Konvertierung.


```sql
-- Lösung zu Frage 1: Revenue & Klassifikation
USE [BITest];
SELECT SalesOrderID,
       CAST(Quantity*UnitPrice*(1-COALESCE(Discount,0)) AS decimal(12,2)) AS Revenue,
       CASE WHEN CAST(Quantity*UnitPrice*(1-COALESCE(Discount,0)) AS decimal(12,2)) >= 200 THEN 'High' ELSE 'Low' END AS Class
FROM dbo.SalesOrders;
```

```sql
-- Lösung zu Frage 2: yyyy-MM ohne FORMAT()
USE [BITest];
SELECT SalesOrderID,
       CONCAT(YEAR(OrderDate), '-', RIGHT('0'+CAST(MONTH(OrderDate) AS varchar(2)),2)) AS yyyy_mm
FROM dbo.SalesOrders;
```

```sql
-- Lösung zu Frage 3: ISNULL vs COALESCE
USE [BITest];
SELECT SalesOrderID,
       ISNULL(Discount, 0.0)     AS Discount_ISNULL,
       COALESCE(Discount, 0.0)   AS Discount_COALESCE
FROM dbo.SalesOrders;
```

```sql
-- Lösung zu Frage 4: RunningRevenue pro Region
USE [BITest];
SELECT SalesOrderID, Region,
       CAST(Quantity*UnitPrice*(1-COALESCE(Discount,0)) AS decimal(12,2)) AS Revenue,
       SUM(CAST(Quantity*UnitPrice*(1-COALESCE(Discount,0)) AS decimal(12,2)))
         OVER (PARTITION BY Region ORDER BY SalesOrderID ROWS UNBOUNDED PRECEDING) AS RunningRevenue
FROM dbo.SalesOrders
ORDER BY Region, SalesOrderID;
```

```sql
-- Lösung zu Frage 5: Datum korrekt typisiert filtern
USE [BITest];
DECLARE @d date = '2025-03-01';
SELECT * FROM dbo.SalesOrders WHERE OrderDate = @d;
```

## Querverweise

- Querverweis: 05_Funktionen\Bedingte & NULL-Handling (`CASE`... Kontrollfluss in Ausdrücken, Standardwerte, Division-durch-Nu')


```sql
USE [master];
IF DB_ID(N'BITest') IS NOT NULL
BEGIN
    ALTER DATABASE BITest SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE BITest;
END;
```
