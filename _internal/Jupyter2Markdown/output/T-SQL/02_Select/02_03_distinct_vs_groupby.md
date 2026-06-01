# 02_03_distinct_vs_groupby

**Quelle:** `T-SQL\02_Select\02_03_distinct_vs_groupby.ipynb`  
**Generiert:** 2026-04-18 21:13:30  
**Markdown-Zellen:** 34  
**SQL-Zellen:** 26  

---

# T-SQL SELECT – DISTINCT vs. GROUP BY zum Dedupen

**Themengebiet:** SELECT

**Kapitel:** DISTINCT vs. GROUP BY zum Dedupen

**Kurzbeschreibung:** Wann DISTINCT genügt und wann Aggregation sinnvoller ist; Einfluss auf Pläne & Performance.

**Stand:** 6. September 2025


Dieses Notebook zeigt, wie man Duplikate in T‑SQL entfernt und eindeutige Zeilen/Schlüssel ermittelt – wann `SELECT DISTINCT` genügt und wann `GROUP BY` mit/ohne Aggregaten vorzuziehen ist. Wir vergleichen zu erwartende Ausführungspläne (z. B. **Hash Match (Aggregate)** vs. **Stream Aggregate**) und beleuchten Performance‑Implikationen.

**Typische Fragestellungen:**
- Ich brauche eine Liste **einzigartiger** Werte/Kombinationen – `DISTINCT` oder `GROUP BY`?
- Ich will **gleichzeitig zählen/summieren** – wie kombiniere ich Deduplizierung mit Aggregaten?
- Warum erzeugen **JOINs** plötzlich mehr Zeilen, und wie verhindere ich Vervielfachungen?
- Wie wirkt sich die Wahl auf **Sortierung, Parallelität, Speicher** und Plan‑Operatoren aus?


**Inhalt dieses Notebooks ist:**

- Setup & Demo‑Daten
- Logische Auswertungsreihenfolge (SELECT)
- GROUP BY – Grundsyntax (Dedupen über Gruppierung)
- Mehrfach gruppieren (z. B. Region & Kategorie)
- Gruppieren über Ausdrücke (z. B. YEAR(OrderDate))
- Aggregatfunktionen & NULL‑Semantik (COUNT(*) vs COUNT(col))
- WHERE vs HAVING
- DISTINCT & bedingte Aggregation (COUNT(DISTINCT…), SUM(CASE WHEN …))
- Window‑Funktionen vs GROUP BY (Dedupen mit ROW_NUMBER())
- Optional: ROLLUP/GROUPING SETS – übergreifende Eindeutigkeiten
- Query Optimizer/Analyzer & Ausführungsplan
- Typische Fallstricke
- Best Practices & Performance
- Übungen
- Lösungen
- Querverweise
- Cleanup (optional)


Hinweis: Dieses Notebook nutzt einen **SQL‑Kernel**. **Alle Codezellen enthalten T‑SQL** (SQL Server).


## Setup & Demo‑Daten

Wir verwenden die Beispiel‑Datenbank **BITest** und eine Tabelle **dbo.SalesOrders** mit absichtlich eingebauten Duplikaten (gleiche Kombinationen aus Region/Category/CustomerID).


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
  OrderNo      int        NOT NULL,
  OrderDate    date       NOT NULL,
  Region       nvarchar(20) NOT NULL,
  Category     nvarchar(20) NOT NULL,
  CustomerID   int        NOT NULL,
  Quantity     int        NOT NULL,
  UnitPrice    decimal(10,2) NOT NULL
);
INSERT INTO dbo.SalesOrders (OrderNo,OrderDate,Region,Category,CustomerID,Quantity,UnitPrice)
VALUES
(1001,'2025-01-05',N'West',N'Hardware',101,2,19.99),
(1002,'2025-01-05',N'West',N'Hardware',101,2,19.99), -- Duplikat bzgl. (Region,Category,Customer)
(1003,'2025-01-05',N'West',N'Hardware',102,1,199.00),
(1004,'2025-02-14',N'Nord',N'Software',103,5,49.50),
(1005,'2025-03-01',N'Sued',N'Hardware',104,2,999.90),
(1006,'2025-03-18',N'Ost', N'Hardware',105,10,5.00),
(1007,'2025-03-18',N'Ost', N'Hardware',105,10,5.00), -- exakte Duplikatzeile
(1008,'2025-04-02',N'West',N'Software',106,0,49.50),
(1009,'2025-05-20',N'Nord',N'Hardware',107,7,12.30)
;
```

### Daten sichten


```sql
USE [BITest];
SELECT TOP (20) * FROM dbo.SalesOrders ORDER BY SalesOrderID;
```

## Logische Auswertungsreihenfolge
1. FROM / JOIN → **Duplikate können hier entstehen** (z. B. 1:n‑JOIN)
2. WHERE (Zeilenfilter)
3. GROUP BY (Gruppiert → erzeugt eindeutige Schlüssel pro Gruppe)
4. HAVING (Gruppenfilter)
5. SELECT (Ausgabe; `DISTINCT` entfernt Duplikate **nach** SELECT)
6. ORDER BY


## GROUP BY – Grundsyntax


*Fragestellung:* Wie erhalte ich **unique** Regionen?


```sql
USE [BITest];
-- GROUP BY ohne Aggregate: dedupliziert die Gruppierungsspalte(n)
SELECT Region
FROM dbo.SalesOrders
GROUP BY Region
ORDER BY Region;
```

## Mehrfach gruppieren (z. B. Region & Kategorie)


*Fragestellung:* Eindeutige Kombinationen von Region **und** Kategorie?


```sql
USE [BITest];
SELECT Region, Category
FROM dbo.SalesOrders
GROUP BY Region, Category
ORDER BY Region, Category;
```

## Gruppieren über Ausdrücke (z. B. YEAR(OrderDate))


*Fragestellung:* Unique Bestellmonate (YYYY‑MM)?


```sql
USE [BITest];
SELECT CONVERT(char(7), OrderDate, 23) AS yyyy_mm
FROM dbo.SalesOrders
GROUP BY CONVERT(char(7), OrderDate, 23)
ORDER BY yyyy_mm;
```

## Aggregatfunktionen & NULL‑Semantik (COUNT(*) vs COUNT(col), SUM/AVG/MIN/MAX)


*Fragestellung:* Wie viele **einzigartige** Kunden pro Region?


```sql
USE [BITest];
SELECT Region, COUNT(DISTINCT CustomerID) AS DistinctCustomers
FROM dbo.SalesOrders
GROUP BY Region
ORDER BY Region;
```

## WHERE vs HAVING


*Fragestellung 1:* Nur Zeilen aus `Hardware` **vor** der Gruppierung berücksichtigen.


```sql
USE [BITest];
SELECT Region, COUNT(*) AS Cnt
FROM dbo.SalesOrders
WHERE Category = N'Hardware'
GROUP BY Region
ORDER BY Region;
```

*Fragestellung 2:* Nur Regionen mit **mindestens 2** unterschiedlichen Kunden (Gruppenfilter).


```sql
USE [BITest];
SELECT Region, COUNT(DISTINCT CustomerID) AS DistinctCustomers
FROM dbo.SalesOrders
GROUP BY Region
HAVING COUNT(DISTINCT CustomerID) >= 2
ORDER BY Region;
```

## DISTINCT & bedingte Aggregation


*Fragestellung:* Wann genügt `DISTINCT` zum Dedupen, wann ist `GROUP BY` besser?


```sql
USE [BITest];
-- Reine Deduplizierung: DISTINCT und GROUP BY sind äquivalent (ohne Aggregate)
SELECT DISTINCT Region, Category
FROM dbo.SalesOrders
ORDER BY Region, Category;

-- Mit Aggregat braucht es GROUP BY bzw. Aggregatfunktionen
SELECT Region, COUNT(*) AS RowsPerRegion
FROM dbo.SalesOrders
GROUP BY Region
ORDER BY Region;

-- Bedingte Aggregation: gezielt zählen innerhalb der Gruppe
SELECT Region,
       SUM(CASE WHEN Category = N'Hardware' THEN 1 ELSE 0 END) AS CntHardware,
       COUNT(DISTINCT CASE WHEN Category = N'Hardware' THEN CustomerID END) AS DistinctCustomersHardware
FROM dbo.SalesOrders
GROUP BY Region
ORDER BY Region;
```

## Window‑Funktionen vs GROUP BY


*Fragestellung:* Ich möchte je (Region,Category,Customer) **eine** repräsentative Zeile behalten (z. B. die früheste Bestellung).


```sql
USE [BITest];
WITH Ranked AS (
  SELECT *,
         ROW_NUMBER() OVER (PARTITION BY Region, Category, CustomerID ORDER BY OrderDate, SalesOrderID) AS rn
  FROM dbo.SalesOrders
)
SELECT SalesOrderID, OrderNo, OrderDate, Region, Category, CustomerID, Quantity, UnitPrice
FROM Ranked
WHERE rn = 1
ORDER BY Region, Category, CustomerID, SalesOrderID;
```

## Optional: ROLLUP/GROUPING/GROUPING_ID/GROUPING SETS/CUBE


*Fragestellung:* Einzigartige Schlüssel inkl. **Zwischensummen** (hier nur demonstrativ).


```sql
USE [BITest];
SELECT Region, Category
FROM dbo.SalesOrders
GROUP BY GROUPING SETS ((Region, Category), (Region), ())
ORDER BY Region, Category;
```

## Query Optimizer/Analyzer & Ausführungsplan
**Pipeline:** Parsing → Binder → Optimizer → Plan‑Cache → Executor

**Operatoren (relevant fürs Dedupen):**
- **Hash Match (Aggregate)**: gut bei unsortierten, größeren Daten; benötigt Speicher (Spill‑Risiko).
- **Stream Aggregate**: sehr effizient, benötigt **vorsortierte** Eingabe (z. B. per Index/Sort).
- **Sort**: oft vor `Stream Aggregate`, kostenintensiv bei großen Datenmengen.
- **Parallelism**: DISTINCT/GROUP BY sind häufig parallelisierbar; Final‑Aggregate vereinigt Teilmengen.

**Erwartete Pläne (sprachlich):**
- `SELECT DISTINCT col` ↔ `SELECT col GROUP BY col`: meist gleicher Plan (Aggregate + optional Sort).
- `GROUP BY` mit Aggregaten erzeugt Aggregate‑Operatoren; `DISTINCT` kann nicht aggregieren.
- Window‑Dedupe (`ROW_NUMBER()`) zeigt **Window Spool/Segment/Sort** statt Aggregate.

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
-- Vergleich: DISTINCT vs GROUP BY (äquivalente Ausgabe, potenziell identischer Plan)
SELECT DISTINCT Region, Category FROM dbo.SalesOrders;
SELECT Region, Category FROM dbo.SalesOrders GROUP BY Region, Category;
```

## Typische Fallstricke


**Fall 1 – `DISTINCT` mit zusätzlichen Spalten verhindert Dedupe**
*Fragestellung:* Warum ändert eine zusätzliche Spalte die Kardinalität?


```sql
USE [BITest];
-- Falsch (DISTINCT über zu viele Spalten → kaum Dedupe)
SELECT DISTINCT Region, Category, SalesOrderID
FROM dbo.SalesOrders;
```

```sql
USE [BITest];
-- Korrektur: Nur Schlüsselspalten zur Deduplizierung auswählen
SELECT DISTINCT Region, Category
FROM dbo.SalesOrders;
```

**Fall 2 – COUNT(DISTINCT col1, col2) wird in T‑SQL nicht unterstützt**
*Fragestellung:* Wie zähle ich einzigartige Kombinationen?


```sql
USE [BITest];
-- Fehlerhaft (Syntax nicht unterstützt)
-- SELECT COUNT(DISTINCT Region, Category) FROM dbo.SalesOrders;
```

```sql
USE [BITest];
-- Korrekt: Subquery oder GROUP BY
SELECT COUNT(*) AS DistinctPairs
FROM (
  SELECT DISTINCT Region, Category FROM dbo.SalesOrders
) d;
```

**Fall 3 – Doppelte durch JOIN‑Vervielfachung**
*Fragestellung:* Warum stimmt meine Anzahl nicht nach einem 1:n‑JOIN?


```sql
USE [BITest];
-- Beispiel: DISTINCT nach dem JOIN nötig ODER Semi‑Join mit EXISTS verwenden
-- (hier nur Pattern; zweite Tabelle wird angedeutet)
-- SELECT DISTINCT c.CustomerID
-- FROM dbo.Customers AS c
-- JOIN dbo.Orders AS o ON o.CustomerID = c.CustomerID;  -- 1:n → Vervielfachung

-- Besser (Semi‑Join):
-- SELECT c.CustomerID
-- FROM dbo.Customers AS c
-- WHERE EXISTS (SELECT 1 FROM dbo.Orders AS o WHERE o.CustomerID = c.CustomerID);
```

**Fall 4 – ORDER BY mit DISTINCT**
*Fragestellung:* Warum lässt sich nicht nach Spalten sortieren, die **nicht** in SELECT stehen?


```sql
USE [BITest];
-- Fehlerhaft: ORDER BY Spalte muss Teil der DISTINCT‑Ausgabe sein
-- SELECT DISTINCT Region FROM dbo.SalesOrders ORDER BY Category;
```

```sql
USE [BITest];
-- Korrekt:
SELECT DISTINCT Region FROM dbo.SalesOrders ORDER BY Region;
```

**Fall 5 – `TOP` mit `DISTINCT` erzeugt missverständliche Ergebnisse**
*Fragestellung:* Ist es die Top‑N **vor** oder **nach** Deduplizierung?


```sql
USE [BITest];
-- Empfehlung: Klarstellen per Subquery
SELECT TOP (3) *
FROM (
  SELECT DISTINCT Region FROM dbo.SalesOrders
) d
ORDER BY Region;
```

## Best Practices & Performance
- Für reine Deduplizierung: `SELECT DISTINCT` **oder** `GROUP BY` – wähle die **lesbarere** Form.
- Mit Aggregaten (COUNT/SUM/…): `GROUP BY`.
- Für „erste Zeile pro Schlüssel“: Window‑Funktion (`ROW_NUMBER()`) statt `DISTINCT`.
- Für hohe Performance: **passende Indizes** auf den Dedupe‑Schlüsseln ermöglichen `Stream Aggregate` ohne Sort.
- `JOIN`‑Vervielfachung vermeiden: Semi‑Joins (`EXISTS`) oder vorherige Deduplizierung im Unterselect.
- `COUNT(DISTINCT col)` ist ok; für mehrere Spalten: Subquery/`GROUP BY`.
- Messbar machen: `SET STATISTICS IO, TIME ON` und Pläne vergleichen.


## Übungen
1. Listen Sie alle **einzigartigen** `(Region, Category)`‑Kombinationen.
2. Ermitteln Sie die Anzahl Zeilen pro Region.
3. Zählen Sie die Anzahl **unterschiedlicher Kunden** pro Region.
4. Behalten Sie je `(Region, Category, CustomerID)` nur die **früheste** Bestellung.
5. Ermitteln Sie die Anzahl **einzigartiger (Region, Category)**‑Paare (ohne `COUNT(DISTINCT col1, col2)`).


```sql
-- Lösung zu Frage 1: Distinct Paare
USE [BITest];
SELECT DISTINCT Region, Category
FROM dbo.SalesOrders
ORDER BY Region, Category;
```

```sql
-- Lösung zu Frage 2: Zeilen pro Region
USE [BITest];
SELECT Region, COUNT(*) AS RowsPerRegion
FROM dbo.SalesOrders
GROUP BY Region
ORDER BY Region;
```

```sql
-- Lösung zu Frage 3: Unterschiedliche Kunden pro Region
USE [BITest];
SELECT Region, COUNT(DISTINCT CustomerID) AS DistinctCustomers
FROM dbo.SalesOrders
GROUP BY Region
ORDER BY Region;
```

```sql
-- Lösung zu Frage 4: Erste Bestellung je Schlüssel
USE [BITest];
WITH R AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY Region, Category, CustomerID ORDER BY OrderDate, SalesOrderID) AS rn
  FROM dbo.SalesOrders
)
SELECT Region, Category, CustomerID, SalesOrderID, OrderDate
FROM R
WHERE rn = 1
ORDER BY Region, Category, CustomerID;
```

```sql
-- Lösung zu Frage 5: Anzahl einzigartiger (Region, Category)
USE [BITest];
SELECT COUNT(*) AS DistinctPairs
FROM (
  SELECT DISTINCT Region, Category FROM dbo.SalesOrders
) d;
```

## Querverweise
- Querverweis: 05_Funktionen\Aggregatfunktionen & Textaggrega...& verdichten, Distinct-Aggregate, Textlisten stabil sortieren.
- Querverweis: 04_Where\Filtern nach Fensterfunktionen (`ROW_.../abgeleiteter Tabelle, um auf Rang/Window-Ergebnis zu filtern.
- Querverweis: 03_JOIN\Physische Join-Algorithmen & Hints — N... Operator; gezielte Nutzung von Join-/Query-Hints und Risiken.
- Querverweis: 03_JOIN\Semi-/Anti-Joins: EXISTS — IN, NOT EXI...likatsvervielfältigung; typische Fehlerbilder und Performance.
- Querverweis: 03_JOIN\Set-Operatoren vs JOIN — Wann `UNION/U...RSECT/EXCEPT` statt Join sinnvoll ist; kombinierte Strategien.


```sql
USE [master];
IF DB_ID(N'BITest') IS NOT NULL
BEGIN
    ALTER DATABASE BITest SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE BITest;
END;
```
