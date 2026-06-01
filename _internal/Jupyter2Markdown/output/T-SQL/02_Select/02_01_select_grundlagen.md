# 02_01_select_grundlagen

**Quelle:** `T-SQL\02_Select\02_01_select_grundlagen.ipynb`  
**Generiert:** 2026-04-18 21:13:30  
**Markdown-Zellen:** 24  
**SQL-Zellen:** 12  

---

# T-SQL SELECT-Grundlagen & Syntax – SELECT-Grundlagen & Syntax

**Themengebiet:** SELECT-Grundlagen & Syntax  
**Kapitel:** SELECT-Grundlagen & Syntax  
**Kurzbeschreibung:** Minimale Syntax, Projektion, Alias, logische Verarbeitungsreihenfolge und deterministische Ausgabe.  
**Stand:** 2025-09-06



In diesem Notebook geht es um die **Grundlagen von `SELECT` in T-SQL**: minimale Syntax, Projektion (welche Spalten erscheinen), sinnvolle **Alias-Namen**, die **logische Auswertungsreihenfolge** einer Abfrage sowie die Bedeutung einer **deterministischen Ausgabe** mit `ORDER BY`.

**Typische Fragestellungen:**
- Wie sieht die kleinste gültige `SELECT`-Abfrage aus?
- Wie vergebe ich Aliasse für Spalten bzw. Ausdrücke?
- Warum ist die Ausgabe ohne `ORDER BY` nicht deterministisch?
- Wie filtere ich mit `WHERE` und wie paginiere ich Ergebnisse (`TOP`, `OFFSET/FETCH`)?
- Wann brauche ich `DISTINCT` und wann besser nicht?



### Inhalt dieses Notebooks ist
- Hinweis zum Kernel
- Setup & Demo-Daten (`BITest` + `dbo.SalesOrders`)
- Logische Auswertungsreihenfolge (FROM→WHERE→GROUP BY→HAVING→SELECT→ORDER BY)
- Minimaler SELECT & Projektion
- Spaltenalias & Ausdrücke
- Filtern mit WHERE
- Deterministische Ausgabe mit ORDER BY
- DISTINCT
- TOP & OFFSET/FETCH (Paginierung)
- CASE-Ausdrücke (abgeleitete Spalten)
- (Optional) Window-Funktionen für laufende Werte
- Query Optimizer/Analyzer & Ausführungsplan
- Typische Fallstricke
- Best Practices & Performance
- Übungen & Lösungen
- Querverweise
- Cleanup



> **Hinweis:** Dieses Notebook verwendet einen **SQL-Kernel**. **Alle Codezellen sind T-SQL** (SQL Server).



## Setup & Demo-Daten

Wir verwenden optional die Datenbank **`BITest`** und eine durchgängige Tabelle **`dbo.SalesOrders`** mit einigen `NULL`-Werten.



```sql
IF DB_ID(N'BITest') IS NULL
BEGIN
  CREATE DATABASE [BITest];
END
GO
USE [BITest];
GO

IF OBJECT_ID(N'dbo.SalesOrders', N'U') IS NOT NULL
  DROP TABLE dbo.SalesOrders;
GO

CREATE TABLE dbo.SalesOrders
(
  SalesOrderID int IDENTITY(1,1) PRIMARY KEY,
  OrderDate    date         NOT NULL,
  CustomerID   int          NOT NULL,
  Region       nvarchar(50) NULL,
  Category     nvarchar(50) NULL,
  Quantity     int          NOT NULL,
  UnitPrice    decimal(10,2) NOT NULL,
  Discount     decimal(10,2) NULL -- Rabattbetrag je Zeile
);
GO

INSERT INTO dbo.SalesOrders (OrderDate, CustomerID, Region, Category, Quantity, UnitPrice, Discount) VALUES
('2024-12-28', 101, N'West', N'Electronics', 2, 399.99, NULL),
('2024-12-29', 102, N'East', N'Home',       1,  89.50,  5.00),
('2025-01-03', 101, N'West', N'Home',       3,  15.00,  0.00),
('2025-02-10', 103, NULL,    N'Garden',     5,   9.99, NULL),
('2025-03-05', 104, N'South',N'Electronics',1, 999.00,100.00),
('2025-03-20', 105, N'North',N'Home',       2,  50.00, NULL),
('2025-04-02', 106, N'West', NULL,          4,  20.00,  2.00);
GO

```

### Daten sichten (TOP)
Erster Blick in die Tabelle:


```sql
USE [BITest];
GO
SELECT TOP (10) *
FROM dbo.SalesOrders
ORDER BY SalesOrderID;

```

## Logische Auswertungsreihenfolge

`FROM` → `WHERE` → `GROUP BY` → `HAVING` → `SELECT` → `ORDER BY`

> Wichtig: **`ORDER BY` kommt logisch zuletzt** und ist der einzige garantierte Weg zu einer **deterministischen Ausgabe-Reihenfolge**.



## Minimaler SELECT & Projektion
*Fragestellung:* Wie selektiere ich bestimmte Spalten ohne weitere Klauseln?



```sql
USE [BITest];
GO
SELECT SalesOrderID, OrderDate, CustomerID
FROM dbo.SalesOrders;

```

## Spaltenalias & Ausdrücke
*Fragestellung:* Wie vergebe ich Aliasse und berechne Ausdrucksspalten?



```sql
USE [BITest];
GO
SELECT 
  SalesOrderID AS ID,
  Quantity * UnitPrice AS LineTotal,       -- Ausdruck mit Alias
  ISNULL(Discount, 0.00) AS DiscountAmount -- Umgang mit NULL
FROM dbo.SalesOrders;

```

## Filtern mit WHERE
*Fragestellung:* Wie filtere ich Datenzeilen?



```sql
USE [BITest];
GO
SELECT *
FROM dbo.SalesOrders
WHERE Region = N'West'
  AND OrderDate >= '2025-01-01';

```

## Deterministische Ausgabe mit ORDER BY
*Fragestellung:* Wie stelle ich eine reproduzierbare Reihenfolge sicher?



```sql
USE [BITest];
GO
SELECT TOP (5)
  SalesOrderID, OrderDate, CustomerID,
  Quantity * UnitPrice - ISNULL(Discount,0.00) AS NetAmount
FROM dbo.SalesOrders
ORDER BY OrderDate DESC, SalesOrderID DESC; -- Ties durch zweite Sortierspalte auflösen

```

## DISTINCT
*Fragestellung:* Wie erhalte ich einzigartige Werte?



```sql
USE [BITest];
GO
SELECT DISTINCT Category
FROM dbo.SalesOrders
WHERE Category IS NOT NULL
ORDER BY Category;

```

## TOP & OFFSET/FETCH (Paginierung)
*Fragestellung:* Wie liefere ich nur einen Ausschnitt der Daten?



```sql
USE [BITest];
GO
-- TOP-Variante (mit deterministischem ORDER BY!)
SELECT TOP (3) SalesOrderID, OrderDate, CustomerID
FROM dbo.SalesOrders
ORDER BY OrderDate DESC, SalesOrderID DESC;
GO

-- OFFSET/FETCH-Variante: Seite 2 mit je 2 Zeilen
SELECT SalesOrderID, OrderDate, CustomerID
FROM dbo.SalesOrders
ORDER BY OrderDate DESC, SalesOrderID DESC
OFFSET 2 ROWS FETCH NEXT 2 ROWS ONLY;

```

## CASE-Ausdrücke (abgeleitete Spalten)
*Fragestellung:* Wie bilde ich Kategorien aus Werten?



```sql
USE [BITest];
GO
SELECT 
  SalesOrderID,
  Discount,
  CASE 
    WHEN Discount IS NULL OR Discount = 0 THEN N'No/Zero Discount'
    WHEN Discount >= 50 THEN N'High Discount'
    ELSE N'Low Discount'
  END AS DiscountBucket
FROM dbo.SalesOrders
ORDER BY SalesOrderID;

```

## (Optional) Window-Funktionen – laufende Summe
*Fragestellung:* Wie vergleiche ich Zeilen, ohne sie zu gruppieren?



```sql
USE [BITest];
GO
SELECT
  SalesOrderID, OrderDate,
  Quantity * UnitPrice - ISNULL(Discount,0.00) AS NetAmount,
  SUM(Quantity * UnitPrice - ISNULL(Discount,0.00)) 
    OVER (ORDER BY OrderDate, SalesOrderID) AS RunningRevenue
FROM dbo.SalesOrders
ORDER BY OrderDate, SalesOrderID;

```

## Query Optimizer/Analyzer & Ausführungsplan

**Pipeline:** Parsing → Binder → Optimizer → Plan-Cache → Executor

**Häufige Operatoren:** *Stream Aggregate*, *Hash Match (Aggregate)*, *Sort*, *Parallelism*, *Memory Grants*, *Cardinality Estimator (CE)*.

**Snippets:**
```sql
SET SHOWPLAN_XML ON; -- geschätzter Plan
-- Abfrage
SET SHOWPLAN_XML OFF;

SET STATISTICS IO, TIME, XML ON; -- tatsächliche Ausführung
-- Abfrage
SET STATISTICS IO, TIME, XML OFF;
```

**Erwartete Pläne (sprachlich):**
- Einfache `SELECT` ohne Indexfilter: *Table Scan* oder *Index Scan*.
- `ORDER BY` auf nicht indizierter Spalte: *Sort*-Operator mit entsprechendem Speicherbedarf.
- `OFFSET/FETCH`: oft zusätzlicher *Sort*, ggf. *Top N Sort*.



```sql
USE [BITest];
GO
SET SHOWPLAN_XML ON;
SELECT TOP (5)
  SalesOrderID, OrderDate, CustomerID
FROM dbo.SalesOrders
ORDER BY OrderDate DESC, SalesOrderID DESC;
SET SHOWPLAN_XML OFF;

```

```sql
USE [BITest];
GO
SET STATISTICS IO, TIME, XML ON;
SELECT
  SalesOrderID, OrderDate, CustomerID
FROM dbo.SalesOrders
WHERE Region = N'West';
SET STATISTICS IO, TIME, XML OFF;

```

## Typische Fallstricke

Jeder Fall zeigt die Fragestellung, eine **fehlerhafte** Abfrage (absichtlich) und die **korrekte** Variante.



### Fall 1: TOP ohne `ORDER BY` → nichtdeterministische Ausgabe
*Fragestellung:* Warum variiert die Reihenfolge oder Zusammensetzung bei wiederholten Läufen?



### Fall 2: Spaltenalias in `WHERE` verwenden
*Fragestellung:* Warum meldet SQL Server einen Fehler, wenn ich einen Alias in `WHERE` benutze?



### Fall 3: Integer-Division führt zu unerwarteten Nullen
*Fragestellung:* Warum ist `1/2 = 0` und wie verhindere ich das?



## Best Practices & Performance

- **Determinismus:** Niemals auf implizite Reihenfolgen verlassen – immer `ORDER BY` mit tie-breaker.
- **SARGability:** Filterausdrücke so formulieren, dass Indizes genutzt werden können (z. B. keine Funktion auf der Spalte in `WHERE`).
- **Indizes:** Häufige Filter- und Sortierspalten indexieren (z. B. `OrderDate`, `CustomerID`). Für reine Reporting-Workloads kann **Columnstore** sinnvoll sein.
- **Pagination:** `OFFSET/FETCH` mit stabiler Sortierung verwenden; bei großen Datenmengen **Keyset Pagination** erwägen.
- **Plananalyse:** `SET STATISTICS IO, TIME, XML` und *Estimated/Actual Plans* zur Diagnose nutzen.



## Übungen

1. **West 2025:** Selektieren Sie alle Bestellungen im Jahr 2025 aus der Region *West* mit `SalesOrderID`, `OrderDate`, `CustomerID`. Sortieren Sie absteigend nach `OrderDate`, anschließend `SalesOrderID`.
2. **Top-Umsätze:** Ermitteln Sie pro Zeile den Nettobetrag `NetAmount = Quantity*UnitPrice - ISNULL(Discount,0)` und geben Sie die **Top 3** Zeilen nach `NetAmount` aus (deterministisch sortiert).
3. **Distinct Kategorien:** Listen Sie alle verschiedenen Kategorien (`Category`) auf, ohne `NULL`, alphabetisch sortiert.
4. **Seite 2:** Geben Sie eine Seite mit **2 Zeilen** aus, sortiert nach `OrderDate DESC, SalesOrderID DESC` – verwenden Sie `OFFSET/FETCH`.
5. **CASE Bucket:** Geben Sie je Zeile `SalesOrderID`, `Discount` und einen `CASE`-Bucket (`No/Zero`, `Low`, `High` ≥ 50) aus.



## Querverweise
Keine Querverweise gefunden.



## Cleanup (optional)
Zum Aufräumen (optional) die Demo-Objekte entfernen.


