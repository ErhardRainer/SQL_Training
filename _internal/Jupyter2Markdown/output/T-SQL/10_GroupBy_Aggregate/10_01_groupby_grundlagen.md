# 10_01_groupby_grundlagen

**Quelle:** `T-SQL\10_GroupBy_Aggregate\10_01_groupby_grundlagen.ipynb`  
**Generiert:** 2026-04-18 21:13:31  
**Markdown-Zellen:** 30  
**SQL-Zellen:** 15  

---

# T‑SQL **GROUP BY & Aggregate** – Grundlagen  
**Themengebiet:** T‑SQL GROUP BY & Aggregate · **Kapitel:** Grundlagen: `GROUP BY`, Aggregatfunktionen, `HAVING`  
**Kurzbeschreibung:** Syntax, logische Auswertungsreihenfolge, Unterschiede `WHERE` vs. `HAVING`, `COUNT(*)` vs. `COUNT(col)`

*Stand:* 2025-09-05



## Einleitung

In diesem Kapitel geht es um das **Gruppieren und Aggregieren** von Daten mit T‑SQL. Typische Fragestellungen sind zum Beispiel:
- *„Wie hoch ist der Umsatz pro Region?“*
- *„Wie viele eindeutige Kunden hatte eine Region im Zeitraum X?“*
- *„Welche Kunden überschreiten eine bestimmte Umsatzschwelle?“*
- *„Wie erhalte ich Zwischensummen und Gesamtsummen?“*

**Einsatzgebiete:** Reporting, KPI‑Berechnungen, Data Warehousing, Analysen im Controlling/Vertrieb/Produktion – überall dort, wo Daten **verdichtet** werden müssen.

**Technische Hintergründe (vereinfacht):**
- SQL verarbeitet Abfragen in einer **logischen Auswertungsreihenfolge** (FROM → WHERE → GROUP BY → HAVING → SELECT → ORDER BY).
- `GROUP BY` fasst Zeilen zu **Gruppen** zusammen; auf Gruppen werden **Aggregatfunktionen** (z. B. `SUM`, `COUNT`, `AVG`) angewendet.
- Der **Query Optimizer** wählt eine Aggregationsstrategie:
  - **Hash Match (Aggregate):** Für unsortierte Eingaben; erzeugt Hash‑Tabellen im Speicher/TempDB.
  - **Stream Aggregate:** Sehr effizient, wenn die Eingabe bereits **sortiert nach den Gruppierungsspalten** ist (z. B. passender Index).
  - **Sort:** Stellt Ordnung her, wenn erforderlich (z. B. für `ORDER BY` oder als Voraussetzung für Stream Aggregate).
- **NULL‑Semantik:** `COUNT(*)` zählt alle Zeilen, `COUNT(spalte)` ignoriert `NULL`. `SUM/AVG/MIN/MAX` ignorieren `NULL` ebenfalls (Ergebnis kann `NULL` sein, wenn alle Werte `NULL` sind).



## Inhalt dieses Notebooks ist:

- Logische Auswertungsreihenfolge (FROM → WHERE → GROUP BY → HAVING → SELECT → ORDER BY)
- `GROUP BY`‑Grundlagen: einfach, mehrfach, über Ausdrücke (jeweils mit **Fragestellung** direkt unter der Überschrift)
- Aggregatfunktionen & NULL‑Semantik (`COUNT`, `SUM`, `AVG`, `MIN`, `MAX`)
- `WHERE` vs. `HAVING` inkl. präziser **Fragestellungen** und Gegenüberstellungen
- `COUNT(*)` vs. `COUNT(col)` und `COUNT(DISTINCT)`
- Bedingte Aggregation (`SUM(CASE WHEN … THEN … END)`)
- Window‑Funktionen vs. `GROUP BY`
- (Optional) `ROLLUP` & `GROUPING()`/`GROUPING_ID()`
- **Was macht der Query Optimizer/Analyzer & wie sieht der Ausführungsplan aus?** (ausführlich)
- Typische Fallstricke mit **beabsichtigten Fehlerbeispielen**
- Performance‑Hinweise, Übungen & **Lösungen**, Cleanup



> **Hinweis zum Kernel:**  
> Dieses Notebook ist für einen **SQL‑Kernel** gedacht (z. B. in Azure Data Studio).  
> Setze den Kernel auf **SQL**. Alle Codezellen enthalten **T‑SQL**.



## Setup: Demo‑Datenbank **[BITest]** & Beispieltabelle

Die Demo nutzt `dbo.SalesOrders` in der Datenbank **BITest**.



```sql
IF DB_ID(N'BITest') IS NULL
    CREATE DATABASE [BITest];
GO
USE [BITest];
GO

IF OBJECT_ID(N'dbo.SalesOrders', N'U') IS NOT NULL
    DROP TABLE dbo.SalesOrders;
GO

CREATE TABLE dbo.SalesOrders
(
    OrderID         INT IDENTITY(1,1) PRIMARY KEY,
    OrderDate       DATE          NOT NULL,
    CustomerID      INT           NOT NULL,
    Region          NVARCHAR(50)  NOT NULL,
    ProductCategory NVARCHAR(50)  NOT NULL,
    PaymentMethod   NVARCHAR(20)  NOT NULL,
    Quantity        INT           NOT NULL,
    Amount          DECIMAL(12,2) NULL   -- NULLs für COUNT/AVG‑Demonstration
);
GO

INSERT INTO dbo.SalesOrders (OrderDate, CustomerID, Region, ProductCategory, PaymentMethod, Quantity, Amount)
VALUES
('2025-01-03', 101, N'AT', N'Frames',   N'Card',  2,  199.90),
('2025-01-05', 101, N'AT', N'Lenses',   N'Card',  1,   89.90),
('2025-01-06', 102, N'AT', N'Lenses',   N'Cash',  3,  219.00),
('2025-01-07', 103, N'DE', N'Frames',   N'Card',  1,  129.00),
('2025-01-10', 103, N'DE', N'Lenses',   N'Card',  4,  360.00),
('2025-01-12', 104, N'DE', N'Care',     N'Card',  5,   75.00),
('2025-01-15', 105, N'AT', N'Care',     N'Cash',  2,   28.00),
('2025-01-16', 106, N'AT', N'Frames',   N'Card',  1,  149.00),
('2025-01-20', 101, N'CH', N'Lenses',   N'Card',  2,  180.00),
('2025-01-22', 107, N'CH', N'Frames',   N'Cash',  2,  260.00),
('2025-01-25', 108, N'CH', N'Care',     N'Card',  6,   90.00),
('2025-02-01', 101, N'AT', N'Lenses',   N'Card',  2,  179.80),
('2025-02-03', 109, N'AT', N'Frames',   N'Card',  1,  139.00),
('2025-02-04', 102, N'AT', N'Lenses',   N'Cash',  2,  159.00),
('2025-02-05', 103, N'DE', N'Frames',   N'Card',  1,  119.00),
('2025-02-06', 110, N'DE', N'Lenses',   N'Card',  5,  450.00),
('2025-02-07', 111, N'DE', N'Care',     N'Card',  3,   45.00),
('2025-02-10', 112, N'AT', N'Care',     N'Cash',  4,   56.00),
('2025-02-12', 113, N'AT', N'Frames',   N'Card',  1,  159.00),
('2025-02-14', 114, N'CH', N'Lenses',   N'Card',  3,  285.00),
('2025-02-17', 115, N'CH', N'Frames',   N'Cash',  1,  149.00),
('2025-02-20', 116, N'CH', N'Care',     N'Card',  7,  105.00),
('2025-03-01', 101, N'AT', N'Lenses',   N'Card',  2,  169.80),
('2025-03-02', 117, N'AT', N'Frames',   N'Card',  1,  129.00),
('2025-03-03', 118, N'AT', N'Lenses',   N'Cash',  1,   79.50),
('2025-03-05', 119, N'DE', N'Frames',   N'Card',  2,  238.00),
('2025-03-07', 120, N'DE', N'Lenses',   N'Card',  2,  180.00),
('2025-03-08', 121, N'DE', N'Care',     N'Card',  2,   30.00),
('2025-03-10', 122, N'CH', N'Frames',   N'Cash',  1,  169.00),
('2025-03-12', 123, N'CH', N'Lenses',   N'Card',  2,  190.00),
('2025-03-15', 124, N'CH', N'Care',     N'Card',  5,   75.00),
-- NULL-Beträge
('2025-03-16', 125, N'AT', N'Care',     N'Card',  1,   NULL),
('2025-03-17', 125, N'AT', N'Care',     N'Card',  1,   NULL),
('2025-03-18', 126, N'DE', N'Lenses',   N'Card',  1,   NULL),
('2025-03-19', 127, N'CH', N'Frames',   N'Cash',  1,   NULL);
GO

```

### Daten sichten


```sql
USE [BITest];
SELECT TOP (10) *
FROM dbo.SalesOrders
ORDER BY OrderID;

```

## Logische Auswertungsreihenfolge

1. `FROM` (+ `JOIN`)  
2. `WHERE` – Zeilenfilter **vor** Aggregation  
3. `GROUP BY` – bildet Gruppen  
4. Aggregatfunktionen werden je Gruppe berechnet  
5. `HAVING` – Gruppenfilter **nach** Aggregation  
6. `SELECT` – Spalten/Aggregate/Aliasse  
7. `ORDER BY` – Sortierung



## `GROUP BY` – Grundsyntax: Umsatz pro Region

**Fragestellung:** *„Wie hoch ist die **Summe** von `Amount` (**Revenue**) pro **Region**, absteigend nach Revenue sortiert?“*



```sql
USE [BITest];
SELECT
    Region,
    SUM(Amount) AS Revenue
FROM dbo.SalesOrders
GROUP BY Region
ORDER BY Revenue DESC;

```

## Mehrfach gruppieren (Region **und** ProductCategory)

**Fragestellung:** *„Wie hoch ist die **Summe** von `Amount` (**Revenue**) pro **Region und ProductCategory**, sortiert nach **Region** und danach **Revenue** absteigend?“*



```sql
USE [BITest];
SELECT
    Region,
    ProductCategory,
    SUM(Amount) AS Revenue
FROM dbo.SalesOrders
GROUP BY Region, ProductCategory
ORDER BY Region, Revenue DESC;

```

## Gruppieren über Ausdrücke (z. B. `YEAR(OrderDate)`)

**Fragestellung:** *„Wie hoch ist die **Summe** von `Amount` (**Revenue**) pro **Jahr** der Bestellung (`YEAR(OrderDate)`), aufsteigend nach Jahr sortiert?“*



```sql
USE [BITest];
SELECT
    YEAR(OrderDate) AS OrderYear,
    SUM(Amount)     AS Revenue
FROM dbo.SalesOrders
GROUP BY YEAR(OrderDate)
ORDER BY OrderYear;

```

## Aggregatfunktionen & NULL‑Semantik

**Fragestellung:** *„Vergleiche pro **Region** die Zählungen via `COUNT(*)` (alle Zeilen) vs. `COUNT(Amount)` (nur `Amount IS NOT NULL`) und stelle Summen/Min/Max/Avg gegenüber.“*



```sql
USE [BITest];
SELECT
    Region,
    COUNT(*)      AS RowsTotal,        -- zählt alle Zeilen
    COUNT(Amount) AS RowsWithAmount,   -- zählt nur Zeilen mit Amount IS NOT NULL
    SUM(Amount)   AS SumAmount,
    AVG(Amount)   AS AvgAmount,        -- ignoriert NULLs
    MIN(Amount)   AS MinAmount,
    MAX(Amount)   AS MaxAmount
FROM dbo.SalesOrders
GROUP BY Region
ORDER BY Region;

```

## `WHERE` vs. `HAVING` (Teil 1: Summenfilter je Gruppe)

**Fragestellung:** *„Welche **Kunden** haben einen **Gesamtumsatz > 300 EUR** (d. h. Summe aller Beträge pro Kunde > 300)?“ — **Nach** der Aggregation filtern → `HAVING`.*



```sql
USE [BITest];
SELECT
    CustomerID,
    SUM(Amount) AS Revenue
FROM dbo.SalesOrders
GROUP BY CustomerID
HAVING SUM(Amount) > 300
ORDER BY Revenue DESC;

```

## `WHERE` vs. `HAVING` (Teil 2: Zeilenfilter vor Aggregation)

**Fragestellung:** *„Welche **Kunden** haben **mindestens eine** Bestellung mit **Amount > 300** (nicht Gesamtsumme > 300)?“ — **Vor** der Aggregation filtern → `WHERE`.*



```sql
USE [BITest];
SELECT
    CustomerID,
    SUM(Amount) AS Revenue
FROM dbo.SalesOrders
WHERE Amount > 300
GROUP BY CustomerID
ORDER BY Revenue DESC;

```

## DISTINCT‑Zählungen (eindeutige Kunden)

**Fragestellung:** *„Wie viele **eindeutige Kunden** gibt es pro **Region**?“*



```sql
USE [BITest];
SELECT
    Region,
    COUNT(DISTINCT CustomerID) AS CustomersDistinct
FROM dbo.SalesOrders
GROUP BY Region
ORDER BY Region;

```

## Bedingte Aggregation (Zahlarten je Region)

**Fragestellung:** *„Wie viele **Bar‑** und **Kartenzahlungen** pro **Region**, zusätzlich der **Revenue** je Region?“*



```sql
USE [BITest];
SELECT
    Region,
    SUM(CASE WHEN PaymentMethod = N'Cash' THEN 1 ELSE 0 END) AS CashCount,
    SUM(CASE WHEN PaymentMethod = N'Card' THEN 1 ELSE 0 END) AS CardCount,
    SUM(Amount) AS Revenue
FROM dbo.SalesOrders
GROUP BY Region
ORDER BY Region;

```

## Window‑Funktionen vs. `GROUP BY` (Granularität bleibt erhalten)

**Fragestellung:** *„Zeige für **jede Bestellung** den zugehörigen **Region‑Revenue** (Summe `Amount` pro Region) **als zusätzliche Spalte**, ohne die Zeilengranularität zu reduzieren.“*



```sql
USE [BITest];
SELECT
    OrderID,
    Region,
    Amount,
    SUM(Amount) OVER (PARTITION BY Region) AS RegionRevenue
FROM dbo.SalesOrders
ORDER BY Region, OrderID;

```

## (Optional) `ROLLUP` – Zwischensummen & Gesamtsumme erkennen

**Fragestellung:** *„Zeige **Revenue pro Region & ProductCategory** sowie **Region‑Summen** und eine **Gesamtsumme**. Markiere Total‑Zeilen mit `GROUPING()`/`GROUPING_ID()`.“*



```sql
USE [BITest];
SELECT
    Region,
    ProductCategory,
    SUM(Amount) AS Revenue,
    GROUPING(Region)          AS G_Region,
    GROUPING(ProductCategory) AS G_Category,
    GROUPING_ID(Region, ProductCategory) AS GID
FROM dbo.SalesOrders
GROUP BY ROLLUP (Region, ProductCategory)
ORDER BY
    GROUPING(Region), Region,
    GROUPING(ProductCategory), ProductCategory;

```

## Was macht der Query Optimizer/Analyzer genau? Wie sieht der Ausführungsplan aus?

### Pipeline des Abfrageprozesses (hochverdichtet)
1. **Parsing** → Syntaxprüfung, Erstellung eines Parse‑Baums.  
2. **Algebrizer/Binder** → Auflösung von Objektnamen/Spalten, Typableitung, Umformung in relationale Algebra.  
3. **Optimizer (kostenbasiert)** → Generiert alternative *Plan‑Kandidaten* (Join‑Reihenfolge/Operatoren, Aggregationsstrategie, Parallelisierung), schätzt **Kardinalitäten** und wählt den **günstigsten** Plan (geringste geschätzte Kosten).  
4. **Plan‑Cache** → Wiederverwendung kompatibler Pläne (Parameter‑Sniffing beachten).  
5. **Ausführung (Executor)** → Operators ausführen, ggf. **Speicherzuteilungen (Memory Grants)**, **Parallelism** (Exchange‑Operatoren), **Spools**, **Sorts**, **Hash/Stream Aggregates**, **Compute Scalar**, **Filter**, **Top**, etc.

### Typische Operatoren für Aggregationen
- **Hash Match (Aggregate):** Unabhängig von Sortierung; gut für große, unsortierte Eingaben. Benötigt Arbeitsspeicher für Hash‑Tabellen.  
- **Stream Aggregate:** Sehr effizient, wenn der Eingabestream bereits **nach den Gruppierungsspalten sortiert** ist (z. B. via Index).  
- **Sort:** Erzeugt Ordnung für `ORDER BY` oder als Voraussetzung für `Stream Aggregate`.  
- **Parallelism (Distribute/Gather/Redistribute Streams):** Aufteilung/Zusammenführung von Zeilen über mehrere Threads.  
- **Index/Clustered Scan vs. Seek:** Hängt von Prädikaten (`WHERE`) und passenden Indizes ab.

### Erwartete Pläne für unsere Beispiele
- **Revenue pro Region (kein passender Index):**  
  `Clustered Index Scan` auf `SalesOrders` → `Hash Match (Aggregate)` (GROUP BY Region) → `Sort` (ORDER BY Revenue DESC) → ggf. `Parallelism` (Gather Streams).  
- **Revenue pro Region & ProductCategory mit passendem Index (Region, ProductCategory INCLUDE (Amount)):**  
  `Index Scan (ordered)` → `Stream Aggregate` (profitierend von der Ordnung) → `Sort` nach Revenue ggf. nötig → weniger Speicher, oft niedrigere Kosten.

> **Cardinality Estimation (CE):** Schätzt Zeilenanzahlen pro Operator (unterliegt ggf. Korrelationen/Skews). Falsche Schätzungen führen zu suboptimalen Operator‑Wahlen (z. B. Hash statt Stream, unerwartete Sorts/Spools, zu kleine/zu große Memory Grants).

### Pläne anzeigen (geschätzt vs. tatsächlich)
- **Geschätzter Plan (ohne Ausführung):**
  ```sql
  SET SHOWPLAN_XML ON;
  -- Ihre Abfrage hier
  SET SHOWPLAN_XML OFF;
  ```
- **Tatsächlicher Plan (mit Ausführung & Laufzeitstatistiken):**
  ```sql
  SET STATISTICS XML ON;   -- optional auch: SET STATISTICS IO, TIME ON
  -- Ihre Abfrage hier
  SET STATISTICS XML OFF;
  ```
- **GUI (SSMS/Azure Data Studio):** *Include Actual Execution Plan* aktivieren (SSMS: **Ctrl+M**) und Abfrage ausführen.



### Index‑Einfluss demonstrieren

Wir legen einen **nicht gruppierten Index** auf `(Region, ProductCategory)` an und inkludieren `Amount`, so dass ein **Stream Aggregate** wahrscheinlicher wird. Danach führen wir die Mehrfach‑Gruppierung erneut aus.



```sql
USE [BITest];
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_SalesOrders_RegionCategory_IncAmount' AND object_id = OBJECT_ID(N'dbo.SalesOrders'))
    DROP INDEX IX_SalesOrders_RegionCategory_IncAmount ON dbo.SalesOrders;
GO
CREATE INDEX IX_SalesOrders_RegionCategory_IncAmount
ON dbo.SalesOrders (Region, ProductCategory)
INCLUDE (Amount);
GO

-- Messung (optional): tatsächlicher Plan & IO/Time
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
SET STATISTICS XML ON;
SELECT
    Region,
    ProductCategory,
    SUM(Amount) AS Revenue
FROM dbo.SalesOrders
GROUP BY Region, ProductCategory
ORDER BY Region, Revenue DESC;
SET STATISTICS XML OFF;
SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;

```

## Typische Fallstricke (inkl. **bewusst fehlerhafter** Beispiele)

Die folgenden Beispiele demonstrieren häufige Probleme. Einige Abfragen sind **absichtlich fehlerhaft** und erzeugen Fehler – genau das ist gewollt, um das Verhalten zu zeigen.



### 1) Nicht aggregierte Spalten fehlen im `GROUP BY`

**Fragestellung:** *„Warum scheitert die Abfrage, wenn `ProductCategory` in der SELECT‑Liste steht, aber nicht im `GROUP BY`?“*



### 2) Aggregat in `WHERE` statt in `HAVING`

**Fragestellung:** *„Wieso ist `SUM(Amount)` in `WHERE` unzulässig und muss nach `GROUP BY` in `HAVING` stehen?“*



### 3) Alias in `HAVING` verwenden

**Fragestellung:** *„Weshalb kann ich den SELECT‑Alias `Revenue` nicht direkt in `HAVING` referenzieren?“*



### 4) `COUNT(DISTINCT col1, col2)` in SQL Server

**Fragestellung:** *„Warum kann ich in SQL Server nicht mehrere Spalten in `COUNT(DISTINCT ...)` angeben – und wie umgehe ich das sauber?“*



### 5) Integer‑Division in Aggregationen

**Fragestellung:** *„Warum entsteht bei Quotienten wie `SUM(Amount)/COUNT(*)` eine unerwartete Rundung/Trunkierung – und wie verhindere ich das?“*



### 6) Duplikate durch `JOIN` (Summen „explodieren“)

**Fragestellung:** *„Warum erhöht ein Join auf eine Dimension mit Duplikaten meine Summen – und wie stabilisiere ich das?“*



```sql
USE [BITest];
IF OBJECT_ID(N'dbo.DimRegion', N'U') IS NOT NULL DROP TABLE dbo.DimRegion;
CREATE TABLE dbo.DimRegion (Region NVARCHAR(50), Attr NVARCHAR(50));
INSERT INTO dbo.DimRegion VALUES (N'AT', N'A'), (N'AT', N'B'), (N'DE', N'A'), (N'CH', N'A');

-- ❌ Summe doppelt für AT (2 Dim-Zeilen):
SELECT s.Region, SUM(s.Amount) AS Revenue
FROM dbo.SalesOrders s
JOIN dbo.DimRegion d ON d.Region = s.Region
GROUP BY s.Region;

-- ✅ Voraggregation oder DISTINCT im Join-Pfad:
WITH DimRegionDistinct AS (
  SELECT DISTINCT Region FROM dbo.DimRegion
)
SELECT s.Region, SUM(s.Amount) AS Revenue
FROM dbo.SalesOrders s
JOIN DimRegionDistinct d ON d.Region = s.Region
GROUP BY s.Region;

DROP TABLE dbo.DimRegion;

```

### 7) Alias aus SELECT in `GROUP BY`

**Fragestellung:** *„Weshalb kann ich `OrderYear` als Alias nicht im `GROUP BY` verwenden?“*



## Best Practices & Performance (kompakt)

- **Vorfilter in `WHERE`** setzen, um Aggregationsmenge zu reduzieren.  
- Geeignete **Indizes** (z. B. `(Region, ProductCategory) INCLUDE (Amount)` für Stream Aggregate).  
- Große, analytische Tabellen: **Clustered Columnstore Index** in DWH‑Szenarien erwägen.  
- **Parallelism** verstehen (DOP, Exchange‑Operatoren), **Memory Grants** beobachten (tats. Plan).  
- Bei JOINs Duplikate vermeiden (Voraggregation/Distinct), **SARGability** beachten.



## Übungen

1. Pro **ProductCategory**: **Anzahl Bestellungen**, **Gesamtumsatz**, **Durchschnittsumsatz** (absteigend nach Umsatz).  
2. Für **Februar 2025**: Kunden mit **Gesamtumsatz > 400 EUR** (Hinweis: `WHERE` für Zeitraum + `HAVING` für Summenfilter).  
3. Pro **Region**: **eindeutige Kunden**, **Anzahl Barzahlungen** (bedingte Aggregation).  
4. Mit `ROLLUP`: Summen pro **Region, Kategorie** inkl. Region‑ und Gesamtsumme; markiere Total‑Zeilen via `GROUPING()`.



## Cleanup (optional)


```sql
USE [BITest];
IF OBJECT_ID(N'dbo.SalesOrders', N'U') IS NOT NULL
    DROP TABLE dbo.SalesOrders;

```
