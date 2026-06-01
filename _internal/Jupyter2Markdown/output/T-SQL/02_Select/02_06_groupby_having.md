# 02_06_groupby_having

**Quelle:** `T-SQL\02_Select\02_06_groupby_having.ipynb`  
**Generiert:** 2026-04-18 21:13:30  
**Markdown-Zellen:** 37  
**SQL-Zellen:** 31  

---

# T-SQL SELECT – Aggregation mit GROUP BY & HAVING

**Themengebiet:** SELECT

**Kapitel:** Aggregation mit GROUP BY & HAVING

**Kurzbeschreibung:** Klassische Aggregation, Filterung nach Aggregaten und typische Fehlerquellen. **Kurz & knapp** – für Details gibt es ein eigenes, erweitertes Kapitel.

**Stand:** 6. September 2025


Dieses kompakte Notebook behandelt das **Wesentliche** zu Aggregation mit `GROUP BY` und Gruppenfilterung mit `HAVING` in T‑SQL. Ideal als Schnellreferenz.


**Inhalt dieses Notebooks ist:**

- Setup & Demo‑Daten
- Logische Auswertungsreihenfolge
- GROUP BY – Grundsyntax
- Mehrfach gruppieren
- Gruppieren über Ausdrücke
- Aggregatfunktionen & NULL‑Semantik
- WHERE vs HAVING (zwei Beispiele)
- DISTINCT & bedingte Aggregation
- Window‑Funktionen vs GROUP BY
- Optional: ROLLUP/GROUPING SETS
- Query Optimizer/Analyzer & Ausführungsplan
- Typische Fallstricke (kurz)
- Best Practices
- Übungen & Lösungen
- Querverweise
- Cleanup (optional)


Hinweis: Dieses Notebook nutzt einen **SQL‑Kernel**. **Alle Codezellen enthalten T‑SQL** (SQL Server).


## Setup & Demo‑Daten
Wir verwenden die Beispiel‑Datenbank **BITest** und **dbo.SalesOrders**.


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
  OrderDate    date NOT NULL,
  Region       nvarchar(20) NOT NULL,
  Category     nvarchar(20) NOT NULL,
  CustomerID   int NOT NULL,
  Quantity     int NOT NULL,
  UnitPrice    decimal(10,2) NOT NULL,
  Discount     decimal(4,2) NULL
);
INSERT INTO dbo.SalesOrders (OrderDate,Region,Category,CustomerID,Quantity,UnitPrice,Discount) VALUES
('2025-01-05',N'West',N'Hardware',101,3,19.99,0.10),
('2025-01-05',N'West',N'Hardware',102,1,199.00,NULL),
('2025-02-14',N'Nord',N'Software',103,5,49.50,0.00),
('2025-03-01',N'Sued',N'Hardware',104,2,999.90,0.15),
('2025-03-18',N'Ost', N'Hardware',105,10,5.00,0.05),
('2025-04-02',N'West',N'Software',106,0,49.50,NULL),
('2025-05-20',N'Nord',N'Hardware',107,7,12.30,NULL);
```

### Daten sichten


```sql
USE [BITest];
SELECT TOP (10) * FROM dbo.SalesOrders ORDER BY SalesOrderID;
```

## Logische Auswertungsreihenfolge
1. FROM / JOIN
2. WHERE
3. GROUP BY
4. HAVING
5. SELECT
6. ORDER BY

`HAVING` filtert **Gruppen**, `WHERE` filtert **Zeilen vor** der Gruppierung.


## GROUP BY – Grundsyntax


*Fragestellung:* Wie viele Zeilen pro Region?


```sql
USE [BITest];
SELECT Region, COUNT(*) AS RowsPerRegion
FROM dbo.SalesOrders
GROUP BY Region
ORDER BY Region;
```

## Mehrfach gruppieren (z. B. Region & Kategorie)


*Fragestellung:* Wie viele Zeilen je Region & Kategorie?


```sql
USE [BITest];
SELECT Region, Category, COUNT(*) AS RowsPerGroup
FROM dbo.SalesOrders
GROUP BY Region, Category
ORDER BY Region, Category;
```

## Gruppieren über Ausdrücke


*Fragestellung:* Wie viele Bestellungen je Jahr?


```sql
USE [BITest];
SELECT YEAR(OrderDate) AS OrderYear, COUNT(*) AS Cnt
FROM dbo.SalesOrders
GROUP BY YEAR(OrderDate)
ORDER BY OrderYear;
```

## Aggregatfunktionen & NULL‑Semantik


*Fragestellung:* Was zählt `COUNT(col)` bei `NULL`?


```sql
USE [BITest];
SELECT
  COUNT(*)                         AS CntAll,
  COUNT(Discount)                  AS CntDiscountNotNull,
  SUM(Quantity)                    AS SumQty,
  AVG(UnitPrice)                   AS AvgPrice,
  MIN(UnitPrice)                   AS MinPrice,
  MAX(UnitPrice)                   AS MaxPrice
FROM dbo.SalesOrders;
```

## WHERE vs HAVING – Beispiel 1 (Zeilenfilter vor der Gruppierung)


*Fragestellung:* Nur `Hardware` zählen – Filter gehört in `WHERE`.


```sql
USE [BITest];
SELECT Region, COUNT(*) AS CntHardware
FROM dbo.SalesOrders
WHERE Category = N'Hardware'
GROUP BY Region
ORDER BY Region;
```

## WHERE vs HAVING – Beispiel 2 (Gruppenfilter nach Aggregation)


*Fragestellung:* Nur Gruppen mit **mindestens 2** Zeilen behalten.


```sql
USE [BITest];
SELECT Region, COUNT(*) AS Cnt
FROM dbo.SalesOrders
GROUP BY Region
HAVING COUNT(*) >= 2
ORDER BY Region;
```

## DISTINCT & bedingte Aggregation


*Fragestellung:* Unterschiedliche Kunden je Region und Hardware‑Anteil je Region?


```sql
USE [BITest];
SELECT Region,
       COUNT(DISTINCT CustomerID) AS DistinctCustomers,
       SUM(CASE WHEN Category = N'Hardware' THEN 1 ELSE 0 END) AS CntHardware
FROM dbo.SalesOrders
GROUP BY Region
ORDER BY Region;
```

## Window‑Funktionen vs GROUP BY


*Fragestellung:* Pro Zeile den Regionsumsatz anzeigen **ohne** Zeilen zu verdichten.


```sql
USE [BITest];
SELECT SalesOrderID, Region,
       SUM(Quantity * UnitPrice) OVER (PARTITION BY Region) AS RegionRevenue
FROM dbo.SalesOrders
ORDER BY Region, SalesOrderID;
```

## Optional: ROLLUP/GROUPING/GROUPING_ID/GROUPING SETS


*Fragestellung:* Ergänzend Regionssummen und Gesamtsumme in **einer** Abfrage.


```sql
USE [BITest];
SELECT Region,
       SUM(Quantity * UnitPrice) AS Revenue,
       GROUPING(Region)          AS IsTotal,
       GROUPING_ID(Region)       AS GroupingID
FROM dbo.SalesOrders
GROUP BY ROLLUP(Region)
ORDER BY IsTotal, Region;
```

## Query Optimizer/Analyzer & Ausführungsplan
**Pipeline:** Parsing → Binder → Optimizer → Plan‑Cache → Executor

**Operatoren:** Hash Match (Aggregate), Stream Aggregate, Sort, Parallelism, Memory Grants, Cardinality Estimator (CE)

**Kurz erwarten:**
- Gruppierung erzeugt **Hash Match (Aggregate)** (unsortiert) oder **Stream Aggregate** (vorsortiert).
- `COUNT(DISTINCT ...)` kann **Sort** erfordern.
- `HAVING` wird als **Filter** über der Aggregation implementiert.

**Snippets (nicht ausführen):**
```sql
SET SHOWPLAN_XML ON;
SELECT Region, COUNT(*) FROM dbo.SalesOrders GROUP BY Region;
SET SHOWPLAN_XML OFF;

SET STATISTICS IO, TIME ON;
SELECT Region, COUNT(DISTINCT CustomerID) FROM dbo.SalesOrders GROUP BY Region;
SET STATISTICS IO, TIME OFF;
```


```sql
USE [BITest];
-- Messabfragen (Beispiel)
SELECT Region, COUNT(*) AS Cnt
FROM dbo.SalesOrders
GROUP BY Region;

SELECT Region, COUNT(DISTINCT CustomerID) AS DistinctCustomers
FROM dbo.SalesOrders
GROUP BY Region;
```

## Typische Fallstricke (kurz)


**Fall 1 – Fehlende `GROUP BY`‑Spalten**
*Fragestellung:* Warum meldet SQL Server einen Fehler?


```sql
USE [BITest];
-- Fehlerhaft: Category nicht aggregiert und nicht in GROUP BY
-- SELECT Region, Category, COUNT(*) FROM dbo.SalesOrders GROUP BY Region;
```

```sql
USE [BITest];
-- Korrekt:
SELECT Region, Category, COUNT(*)
FROM dbo.SalesOrders
GROUP BY Region, Category;
```

**Fall 2 – Aggregat in `WHERE`**
*Fragestellung:* Warum funktioniert `WHERE COUNT(*) > 1` nicht?


```sql
USE [BITest];
-- Fehlerhaft:
-- SELECT Region FROM dbo.SalesOrders WHERE COUNT(*) > 1 GROUP BY Region;
```

```sql
USE [BITest];
-- Korrekt:
SELECT Region FROM dbo.SalesOrders GROUP BY Region HAVING COUNT(*) > 1;
```

**Fall 3 – Alias in `HAVING`**
*Fragestellung:* Warum ist der Alias im `HAVING` nicht bekannt?


```sql
USE [BITest];
-- Fehlerhaft:
-- SELECT Region, COUNT(*) AS C FROM dbo.SalesOrders GROUP BY Region HAVING C > 1;
```

```sql
USE [BITest];
-- Korrekt:
SELECT Region, COUNT(*) AS C FROM dbo.SalesOrders GROUP BY Region HAVING COUNT(*) > 1;
```

**Fall 4 – `COUNT(DISTINCT col1, col2)` nicht unterstützt**


```sql
USE [BITest];
-- Fehlerhaft:
-- SELECT COUNT(DISTINCT Region, Category) FROM dbo.SalesOrders;
```

```sql
USE [BITest];
-- Korrekt:
SELECT COUNT(*) AS DistinctPairs
FROM (SELECT DISTINCT Region, Category FROM dbo.SalesOrders) d;
```

**Fall 5 – Integer‑Division**
*Fragestellung:* Warum ist der Anteil 0 statt 0,15?


```sql
USE [BITest];
-- Fehlerhaft:
SELECT 3/20 AS Anteil;
```

```sql
USE [BITest];
-- Korrekt:
SELECT 3.0/20 AS Anteil;
```

**Fall 6 – JOIN‑Duplikate verfälschen Aggregat**


```sql
USE [BITest];
-- Pattern (zweite Tabelle hypothetisch): DISTINCT/Semi‑Join oder Voraggregation verwenden
-- SELECT c.Region, COUNT(*)
-- FROM dbo.Customers c JOIN dbo.Orders o ON o.CustomerID = c.CustomerID
-- GROUP BY c.Region;  -- 1:n‑JOIN vervielfacht
-- Besser: GROUP BY im Unterselect oder EXISTS

```

**Fall 7 – Alias im `GROUP BY`**
*Hinweis:* `GROUP BY` kennt **keine** SELECT‑Aliase (anders als `ORDER BY`).


```sql
USE [BITest];
-- Fehlerhaft:
-- SELECT YEAR(OrderDate) AS Y, COUNT(*) FROM dbo.SalesOrders GROUP BY Y;
```

```sql
USE [BITest];
-- Korrekt:
SELECT YEAR(OrderDate) AS Y, COUNT(*) FROM dbo.SalesOrders GROUP BY YEAR(OrderDate);
```

## Best Practices
- Nur benötigte Spalten gruppieren; Schlüssel bewusst wählen.
- `WHERE` für Zeilenfilter **vor** der Gruppierung; `HAVING` für Gruppenbedingungen.
- `COUNT(DISTINCT ...)` gezielt einsetzen; bei mehreren Spalten **Subquery** nutzen.
- Window‑Funktionen, wenn Gruppenwerte **pro Zeile** benötigt werden.
- Passende Indizes auf Gruppier‑/Filterspalten fördern **Stream Aggregate**.


## Übungen
1. Zeilen je Region zählen.
2. Unterschiedliche Kunden je (Region, Category) ermitteln.
3. Nur Regionen mit **mindestens 2** Hardware‑Zeilen ausgeben.
4. Regionsumsatz als Window‑Wert pro Zeile zeigen.
5. Anzahl **einzigartiger (Region, Category)**‑Paare bestimmen (ohne `COUNT(DISTINCT col1,col2)`).


```sql
-- Lösung zu Frage 1: Zeilen je Region
USE [BITest];
SELECT Region, COUNT(*) AS Cnt FROM dbo.SalesOrders GROUP BY Region ORDER BY Region;
```

```sql
-- Lösung zu Frage 2: Distinct Kunden je (Region, Category)
USE [BITest];
SELECT Region, Category, COUNT(DISTINCT CustomerID) AS DistinctCustomers
FROM dbo.SalesOrders
GROUP BY Region, Category
ORDER BY Region, Category;
```

```sql
-- Lösung zu Frage 3: Regionen mit >= 2 Hardware‑Zeilen
USE [BITest];
SELECT Region
FROM dbo.SalesOrders
WHERE Category = N'Hardware'
GROUP BY Region
HAVING COUNT(*) >= 2
ORDER BY Region;
```

```sql
-- Lösung zu Frage 4: Window‑Wert Regionsumsatz pro Zeile
USE [BITest];
SELECT SalesOrderID, Region,
       SUM(Quantity * UnitPrice) OVER (PARTITION BY Region) AS RegionRevenue
FROM dbo.SalesOrders
ORDER BY Region, SalesOrderID;
```

```sql
-- Lösung zu Frage 5: Einzigartige (Region, Category)
USE [BITest];
SELECT COUNT(*) AS DistinctPairs
FROM (SELECT DISTINCT Region, Category FROM dbo.SalesOrders) d;
```

## Querverweise
- Querverweis: 02_Select\Erweiterte Aggregation: `GROUPING SETS` — `ROLLUP`, `CUBE`", Mehrdimensionale Summen in einer Abfrage; `GROUPING_ID` zur Unterscheidung der Ebenen.
- Querverweis: 02_Select\`PIVOT`/`UNPIVOT` & Alternative Muster — Berichtsfreundliche Drehung von Daten sowie Alternativen mit `CASE`+Aggregation.
- Querverweis: 02_Select\Ausdrücke — `CASE`, `CAST/CONVERT`, `ISNULL/COALESCE`"


```sql
USE [master];
IF DB_ID(N'BITest') IS NOT NULL
BEGIN
    ALTER DATABASE BITest SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE BITest;
END;
```
