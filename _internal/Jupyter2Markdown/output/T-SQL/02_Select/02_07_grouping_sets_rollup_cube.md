# 02_07_grouping_sets_rollup_cube

**Quelle:** `T-SQL\02_Select\02_07_grouping_sets_rollup_cube.ipynb`  
**Generiert:** 2026-04-18 21:13:30  
**Markdown-Zellen:** 42  
**SQL-Zellen:** 30  

---

# T-SQL SELECT – Erweiterte Aggregation: GROUPING SETS, ROLLUP, CUBE

**Themengebiet:** SELECT

**Kapitel:** Erweiterte Aggregation: GROUPING SETS, ROLLUP, CUBE

**Kurzbeschreibung:** Mehrdimensionale Summen in einer Abfrage; `GROUPING_ID` zur Unterscheidung der Ebenen.

**Stand:** 6. September 2025


Dieses Notebook vertieft Aggregation über mehrere Ebenen in **einer** Abfrage: `GROUPING SETS`, `ROLLUP`, `CUBE` und die Funktionen `GROUPING`/`GROUPING_ID` zur sicheren Unterscheidung echter `NULL`‑Werte von Aggregationsebenen (Totals/Subtotals). Es baut auf grundlegender Aggregation auf.


**Inhalt dieses Notebooks ist:**

- Setup & Demo‑Daten
- Logische Auswertungsreihenfolge
- GROUP BY – Grundsyntax
- Mehrfach gruppieren (Region & Kategorie)
- Gruppieren über Ausdrücke (z. B. YEAR(OrderDate))
- Aggregatfunktionen & NULL‑Semantik
- WHERE vs HAVING (2 Beispiele)
- DISTINCT & bedingte Aggregation
- Window‑Funktionen vs GROUP BY
- **Erweitert:** `ROLLUP`, `GROUPING`, `GROUPING_ID`, `GROUPING SETS`, `CUBE`
- Query Optimizer/Analyzer & Ausführungsplan
- Typische Fallstricke
- Best Practices & Performance
- Übungen
- Lösungen
- Querverweise
- Cleanup (optional)


Hinweis: Dieses Notebook nutzt einen **SQL‑Kernel**. **Alle Codezellen enthalten T‑SQL** (SQL Server).


## Setup & Demo‑Daten
Wir verwenden eine Beispiel‑Datenbank **BITest** und eine Tabelle **dbo.SalesOrders** mit Regionen/Kategorien. Für Umsätze nutzen wir `Quantity * UnitPrice * (1-COALESCE(Discount,0))`.


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
  OrderDate    date           NOT NULL,
  Region       nvarchar(20)  NOT NULL,
  Category     nvarchar(20)  NOT NULL,
  CustomerID   int           NOT NULL,
  Quantity     int           NOT NULL,
  UnitPrice    decimal(10,2) NOT NULL,
  Discount     decimal(4,2)  NULL
);
INSERT INTO dbo.SalesOrders (OrderDate,Region,Category,CustomerID,Quantity,UnitPrice,Discount) VALUES
('2025-01-05',N'West',N'Hardware',101,3, 19.99,0.10),
('2025-01-05',N'West',N'Hardware',102,1,199.00,NULL),
('2025-02-14',N'Nord',N'Software',103,5, 49.50,0.00),
('2025-03-01',N'Sued',N'Hardware',104,2,999.90,0.15),
('2025-03-18',N'Ost', N'Hardware',105,10, 5.00,0.05),
('2025-04-02',N'West',N'Software',106,0, 49.50,NULL),
('2025-05-20',N'Nord',N'Hardware',107,7, 12.30,NULL),
('2025-05-21',N'Ost', N'Software',108,4,149.00,0.05),
('2025-05-22',N'Sued',N'Software',109,6, 79.00,NULL);
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

`GROUPING SETS`/`ROLLUP`/`CUBE` erweitern **Schritt 3** um zusätzliche Aggregationsebenen. `HAVING` filtert **Gruppen** (auch Totals).


## GROUP BY – Grundsyntax


*Fragestellung:* Anzahl Zeilen pro Region.


```sql
USE [BITest];
SELECT Region, COUNT(*) AS RowsPerRegion
FROM dbo.SalesOrders
GROUP BY Region
ORDER BY Region;
```

## Mehrfach gruppieren (Region & Kategorie)


*Fragestellung:* Umsatz je Region & Kategorie.


```sql
USE [BITest];
SELECT Region, Category,
       SUM(Quantity*UnitPrice*(1-COALESCE(Discount,0))) AS Revenue
FROM dbo.SalesOrders
GROUP BY Region, Category
ORDER BY Region, Category;
```

## Gruppieren über Ausdrücke (z. B. YEAR(OrderDate))


*Fragestellung:* Zeilen je Jahr.


```sql
USE [BITest];
SELECT YEAR(OrderDate) AS OrderYear, COUNT(*) AS Cnt
FROM dbo.SalesOrders
GROUP BY YEAR(OrderDate)
ORDER BY OrderYear;
```

## Aggregatfunktionen & NULL‑Semantik


*Fragestellung:* Unterschied `COUNT(*)` vs. `COUNT(col)`; Summen/Min/Max.


```sql
USE [BITest];
SELECT COUNT(*) AS CntRows, COUNT(Discount) AS CntDiscountNotNull,
       SUM(Quantity) AS SumQty, MIN(UnitPrice) AS MinPrice, MAX(UnitPrice) AS MaxPrice
FROM dbo.SalesOrders;
```

## WHERE vs HAVING – Beispiel 1


*Fragestellung:* Nur `Hardware` **vor** der Gruppierung berücksichtigen (Zeilenfilter).


```sql
USE [BITest];
SELECT Region, COUNT(*) AS Cnt
FROM dbo.SalesOrders
WHERE Category = N'Hardware'
GROUP BY Region
ORDER BY Region;
```

## WHERE vs HAVING – Beispiel 2


*Fragestellung:* Nur Gruppen mit **Revenue ≥ 500** behalten (Gruppenfilter).


```sql
USE [BITest];
SELECT Region, SUM(Quantity*UnitPrice*(1-COALESCE(Discount,0))) AS Revenue
FROM dbo.SalesOrders
GROUP BY Region
HAVING SUM(Quantity*UnitPrice*(1-COALESCE(Discount,0))) >= 500
ORDER BY Region;
```

## DISTINCT & bedingte Aggregation


*Fragestellung:* Unterschiedliche Kunden je Region & Anteil Hardware‑Zeilen.


```sql
USE [BITest];
SELECT Region,
       COUNT(DISTINCT CustomerID) AS DistinctCustomers,
       SUM(CASE WHEN Category = N'Hardware' THEN 1 ELSE 0 END) AS CntHW
FROM dbo.SalesOrders
GROUP BY Region
ORDER BY Region;
```

## Window‑Funktionen vs GROUP BY


*Fragestellung:* Regionsumsatz pro Zeile anzeigen (ohne Verdichtung).


```sql
USE [BITest];
SELECT SalesOrderID, Region,
       SUM(Quantity*UnitPrice*(1-COALESCE(Discount,0))) OVER (PARTITION BY Region) AS RegionRevenue
FROM dbo.SalesOrders
ORDER BY Region, SalesOrderID;
```

## ROLLUP – Zwischensummen & Gesamtsumme


*Fragestellung:* Region/Kategorie summieren **inkl.** Regionstotals **und** Gesamttotal.


```sql
USE [BITest];
SELECT Region, Category,
       SUM(Quantity*UnitPrice*(1-COALESCE(Discount,0))) AS Revenue
FROM dbo.SalesOrders
GROUP BY ROLLUP (Region, Category)
ORDER BY Region, Category;
```

## GROUPING & GROUPING_ID – Ebenen unterscheiden


*Fragestellung:* Wie erkenne ich, ob `NULL` aus Daten stammt oder von `ROLLUP` kommt?


```sql
USE [BITest];
SELECT
  Region,
  Category,
  SUM(Quantity*UnitPrice*(1-COALESCE(Discount,0))) AS Revenue,
  GROUPING(Region)   AS G_Region,
  GROUPING(Category) AS G_Category,
  GROUPING_ID(Region, Category) AS GID,
  CASE GROUPING_ID(Region, Category)
    WHEN 0 THEN N'Detail (Region,Category)'
    WHEN 1 THEN N'Subtotal: Region, alle Kategorien'
    WHEN 3 THEN N'Grand Total'
    ELSE N'Andere Ebene'
  END AS LevelLabel
FROM dbo.SalesOrders
GROUP BY ROLLUP (Region, Category)
ORDER BY GID, Region, Category;
```

## GROUPING SETS – Auswahl beliebiger Ebenen in einer Abfrage


*Fragestellung:* Brauche ich Summen je Region **und** je Kategorie **und** Gesamtsumme – aber **keine** (Region,Category)‑Details.


```sql
USE [BITest];
SELECT Region, Category,
       SUM(Quantity*UnitPrice*(1-COALESCE(Discount,0))) AS Revenue,
       GROUPING_ID(Region, Category) AS GID
FROM dbo.SalesOrders
GROUP BY GROUPING SETS ( (Region), (Category), () )
ORDER BY GID, Region, Category;
```

## CUBE – Alle Kombinationen (inkl. Kreuzsummen)


*Fragestellung:* Über **Region × Kategorie** sämtliche Ebenen (Detail, Subtotals pro Achse, Grand Total).


```sql
USE [BITest];
SELECT Region, Category,
       SUM(Quantity*UnitPrice*(1-COALESCE(Discount,0))) AS Revenue,
       GROUPING_ID(Region, Category) AS GID
FROM dbo.SalesOrders
GROUP BY CUBE (Region, Category)
ORDER BY GID, Region, Category;
```

## Query Optimizer/Analyzer & Ausführungsplan
**Pipeline:** Parsing → Binder → Optimizer → Plan‑Cache → Executor

**Relevante Operatoren:** Hash Match (Aggregate), Stream Aggregate, Sort (für `DISTINCT`/`GROUPING SETS`‑Konsolidierung), Parallelism, Memory Grants, Cardinality Estimator (CE).

**Erwartete Pläne (sprachlich):**
- `ROLLUP`/`CUBE` werden als Aggregat + zusätzliche **Rollup‑Phasen** umgesetzt; oft `Sort` für korrekte Gruppierungsreihenfolge.
- `GROUPING SETS` kann mehrere Teilaggregate berechnen und zusammenführen.
- `GROUPING_ID` ist ein Compute‑Scalar über der Aggregation.

**Snippets (nicht ausführen):**
```sql
SET SHOWPLAN_XML ON;
SELECT Region, Category, SUM(Quantity*UnitPrice) FROM dbo.SalesOrders GROUP BY ROLLUP(Region,Category);
SET SHOWPLAN_XML OFF;

SET STATISTICS IO, TIME ON;
SELECT Region, Category, SUM(Quantity*UnitPrice) FROM dbo.SalesOrders GROUP BY GROUPING SETS ((Region),(Category),());
SET STATISTICS IO, TIME OFF;
```


## Typische Fallstricke


**Fall 1 – Fehlende GROUP BY‑Spalten**
*Fragestellung:* Warum meldet SQL Server einen Fehler?


```sql
USE [BITest];
-- Fehlerhaft: Category nicht aggregiert und nicht gruppiert
-- SELECT Region, Category, SUM(Quantity) FROM dbo.SalesOrders GROUP BY Region;
```

```sql
USE [BITest];
-- Korrekt
SELECT Region, Category, SUM(Quantity)
FROM dbo.SalesOrders
GROUP BY Region, Category;
```

**Fall 2 – Aggregat in WHERE statt HAVING**
*Fragestellung:* Warum funktioniert `WHERE SUM(...) > ...` nicht?


```sql
USE [BITest];
-- Fehlerhaft:
-- SELECT Region FROM dbo.SalesOrders GROUP BY Region WHERE SUM(Quantity) > 5;
```

```sql
USE [BITest];
-- Korrekt
SELECT Region FROM dbo.SalesOrders GROUP BY Region HAVING SUM(Quantity) > 5;
```

**Fall 3 – `NULL` aus Daten vs. Rollup‑Totals verwechseln**
*Fragestellung:* Wie unterscheide ich echte `NULL`‑Kategorien von `ROLLUP`‑Totals?


```sql
USE [BITest];
-- Fehlerhaft: blindes COALESCE führt echte NULLs und Totals zusammen
SELECT COALESCE(Category,N'Total') AS Cat, SUM(Quantity) AS Qty
FROM dbo.SalesOrders
GROUP BY ROLLUP(Category);
```

```sql
USE [BITest];
-- Korrekt: erst mit GROUPING() unterscheiden
SELECT CASE WHEN GROUPING(Category)=1 THEN N'Total' ELSE Category END AS Cat,
       SUM(Quantity) AS Qty
FROM dbo.SalesOrders
GROUP BY ROLLUP(Category);
```

**Fall 4 – `COUNT(DISTINCT col1, col2)` nicht unterstützt**
*Fragestellung:* Wie zähle ich eindeutige Paare?


```sql
USE [BITest];
-- Fehlerhaft:
-- SELECT COUNT(DISTINCT Region, Category) FROM dbo.SalesOrders;
```

```sql
USE [BITest];
-- Korrekt: Subquery oder GROUP BY
SELECT COUNT(*) AS DistinctPairs
FROM (SELECT DISTINCT Region, Category FROM dbo.SalesOrders) d;
```

**Fall 5 – Unerwartete Sortierung bei Totals**
*Fragestellung:* Warum stehen Totals mittendrin? (Sortierung nach `GROUPING_ID`).


```sql
USE [BITest];
-- Heikel: ORDER BY Region, Category (Totals mischen sich)
SELECT Region, Category, SUM(Quantity) AS Qty, GROUPING_ID(Region,Category) AS GID
FROM dbo.SalesOrders
GROUP BY ROLLUP (Region, Category)
ORDER BY Region, Category;

-- Besser: Totals am Ende
SELECT Region, Category, SUM(Quantity) AS Qty, GROUPING_ID(Region,Category) AS GID
FROM dbo.SalesOrders
GROUP BY ROLLUP (Region, Category)
ORDER BY GID, Region, Category;
```

**Fall 6 – JOIN‑Duplikate verfälschen Summen**
*Fragestellung:* 1:n‑JOIN verdoppelt Mengen – wie vermeiden?


```sql
USE [BITest];
-- Pattern (zweite Tabelle hypothetisch): voraggregieren oder Semi‑Join
-- SELECT r.Region, SUM(o.Amount)
-- FROM dbo.Regions r
-- JOIN dbo.Orders o ON o.RegionID = r.RegionID
-- GROUP BY r.Region;
-- Besser: Voraggregation von o **oder** EXISTS (Semi‑Join)
```

## Best Practices & Performance
- Für Berichte: `GROUPING SETS` gezielt auf benötigte Ebenen beschränken – spart Arbeit ggü. `CUBE`.
- `ROLLUP` für hierarchische Summen (Detail → Subtotal → Grand Total) in **definierter Reihenfolge**.
- `GROUPING()`/`GROUPING_ID()` nutzen, um echte `NULL` von Total‑Zeilen sicher zu unterscheiden.
- Totals konsistent sortieren (`ORDER BY GROUPING_ID(...), ...`).
- Indizes auf Gruppier‑/Filterspalten fördern `Stream Aggregate`; sonst Hash‑Aggregate + Sort.
- Für Zählungen über Paare `COUNT(*)` über `SELECT DISTINCT` Subquery verwenden.
- Messbar machen: `STATISTICS IO/TIME`, Ausführungsplan prüfen (Sort/Memory‑Grant/Spills).


## Übungen
1. Bilden Sie eine `ROLLUP`‑Auswertung über `(Region, Category)` mit Umsatz (`Revenue`) und sortieren Sie Totals ans Ende.
2. Erzeugen Sie eine `GROUPING SETS`‑Auswertung für **(Region)**, **(Category)** und **()** mit `GROUPING_ID`.
3. Nutzen Sie `CUBE (Region, Category)` und filtern Sie per `HAVING` nur Ebenen mit `SUM(Quantity) >= 10`.
4. Ersetzen Sie `NULL`‑Kategorien in einer `ROLLUP`‑Abfrage **korrekt** durch Labels mittels `GROUPING()`.
5. Ermitteln Sie die Anzahl **einzigartiger (Region, Category)**‑Paare (ohne `COUNT(DISTINCT col1,col2)`).


```sql
-- Lösung zu Frage 1: ROLLUP mit Revenue, Totals am Ende
USE [BITest];
SELECT Region, Category,
       SUM(Quantity*UnitPrice*(1-COALESCE(Discount,0))) AS Revenue,
       GROUPING_ID(Region,Category) AS GID
FROM dbo.SalesOrders
GROUP BY ROLLUP (Region, Category)
ORDER BY GID, Region, Category;
```

```sql
-- Lösung zu Frage 2: GROUPING SETS (Region), (Category), ()
USE [BITest];
SELECT Region, Category,
       SUM(Quantity) AS Qty, GROUPING_ID(Region,Category) AS GID
FROM dbo.SalesOrders
GROUP BY GROUPING SETS ((Region), (Category), ())
ORDER BY GID, Region, Category;
```

```sql
-- Lösung zu Frage 3: CUBE + HAVING
USE [BITest];
SELECT Region, Category, SUM(Quantity) AS Qty, GROUPING_ID(Region,Category) AS GID
FROM dbo.SalesOrders
GROUP BY CUBE (Region, Category)
HAVING SUM(Quantity) >= 10
ORDER BY GID, Region, Category;
```

```sql
-- Lösung zu Frage 4: Korrekte Label via GROUPING()
USE [BITest];
SELECT CASE WHEN GROUPING(Region)=1 THEN N'Alle Regionen' ELSE Region END AS RegionLabel,
       CASE WHEN GROUPING(Category)=1 THEN N'Alle Kategorien' ELSE Category END AS CategoryLabel,
       SUM(Quantity) AS Qty
FROM dbo.SalesOrders
GROUP BY ROLLUP (Region, Category)
ORDER BY GROUPING_ID(Region,Category), Region, Category;
```

```sql
-- Lösung zu Frage 5: Einzigartige (Region, Category)
USE [BITest];
SELECT COUNT(*) AS DistinctPairs
FROM (SELECT DISTINCT Region, Category FROM dbo.SalesOrders) d;
```

## Querverweise
- Querverweis: 05_Funktionen\Aggregatfunktionen & Textaggregation (`SUM` — > **Kurzbeschreibung:** …
- Querverweis: 02_Select\Aggregation mit `GROUP BY` & `HAVING` — > **Kurzbeschreibung:** …
- Querverweis: 02_Select\Fensterfunktionen (`OVER`): Ranking — > **Kurzbeschreibung:** …
- Querverweis: 02_Select\`DISTINCT` vs. `GROUP BY` zum Dedupen — > **Kurzbeschreibung:** …
- Querverweis: 02_Select\Ausgabe als JSON/XML: `FOR JSON` / `FOR XML` — > **Kurzbeschreibung:** …


```sql
USE [master];
IF DB_ID(N'BITest') IS NOT NULL
BEGIN
    ALTER DATABASE BITest SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE BITest;
END;
```
