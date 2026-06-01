# 02_08_window_functions_over

**Quelle:** `T-SQL\02_Select\02_08_window_functions_over.ipynb`  
**Generiert:** 2026-04-18 21:13:30  
**Markdown-Zellen:** 25  
**SQL-Zellen:** 17  

---

# T-SQL SELECT – Fensterfunktionen (OVER): Ranking, Aggregate, Frames

**Themengebiet:** SELECT

**Kapitel:** Fensterfunktionen (OVER): Ranking, Aggregate, Frames

**Kurzbeschreibung:** Rangfolgen, laufende Summen, gleitende Fenster; richtige Frame-Definition für korrekte Ergebnisse.

**Stand:** 6. September 2025


Dieses Notebook zeigt den praktischen Einsatz von **Fensterfunktionen** in T‑SQL: Ranking (`ROW_NUMBER`/`RANK`/`DENSE_RANK`/`NTILE`), Aggregation als Fenster (`SUM/AVG/COUNT … OVER`), **Frames** (`ROWS` vs. `RANGE`) sowie typische Stolpersteine (z. B. `LAST_VALUE`‑Frame, Window in `WHERE`).


**Inhalt dieses Notebooks ist:**

- Setup & Demo‑Daten
- Logische Auswertungsreihenfolge (SELECT & OVER)
- Ranking‑Funktionen (ROW_NUMBER/RANK/DENSE_RANK/NTILE)
- Fensteraggregate (laufend & pro Partition)
- Frames: `ROWS` vs. `RANGE`, gleitende Fenster
- Navigationsfunktionen: `LAG/LEAD`, `FIRST_VALUE/LAST_VALUE`
- Query Optimizer/Analyzer & Ausführungsplan
- Typische Fallstricke
- Best Practices & Performance
- Übungen
- Lösungen
- Querverweise
- Cleanup (optional)


Hinweis: Dieses Notebook nutzt einen **SQL‑Kernel**. **Alle Codezellen enthalten T‑SQL** (SQL Server). Fensterfunktionen sind in `SELECT`/`ORDER BY` erlaubt, **nicht** in `WHERE`/`GROUP BY`.


## Setup & Demo‑Daten
Wir verwenden die Beispiel‑Datenbank **BITest** und eine Tabelle **dbo.SalesOrders** mit Beträgen und absichtlichen **Ties** (gleiche `Amount`) für Frame‑Demonstrationen.


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
  SalesOrderID int IDENTITY(1,1) CONSTRAINT PK_SalesOrders PRIMARY KEY,
  OrderDate    date           NOT NULL,
  CustomerID   int            NOT NULL,
  Region       nvarchar(20)   NOT NULL,
  Category     nvarchar(20)   NOT NULL,
  Amount       decimal(10,2)  NOT NULL
);
INSERT INTO dbo.SalesOrders (OrderDate, CustomerID, Region, Category, Amount) VALUES
('2025-01-05',101,N'West', N'Hardware',  99.00),
('2025-01-06',102,N'West', N'Hardware',  99.00),  -- Tie
('2025-01-07',103,N'West', N'Software', 199.00),
('2025-01-08',104,N'Nord', N'Hardware', 199.00),  -- Tie über Regionen
('2025-01-09',105,N'Nord', N'Software',  49.00),
('2025-01-10',106,N'Nord', N'Software',  49.00),  -- Tie
('2025-01-11',107,N'Ost',  N'Hardware', 299.00),
('2025-01-12',108,N'Ost',  N'Software', 149.00),
('2025-01-13',109,N'Sued', N'Hardware', 149.00),  -- Tie über Regionen
('2025-01-14',110,N'Sued', N'Software', 499.00),
('2025-01-15',111,N'West', N'Hardware',  49.00),
('2025-01-16',112,N'West', N'Software', 149.00),
('2025-01-17',113,N'Ost',  N'Hardware', 149.00),
('2025-01-18',114,N'Nord', N'Hardware', 299.00);

-- Hilfsindizes für Sortierungen
CREATE INDEX IX_SalesOrders_Region_Date_ID ON dbo.SalesOrders(Region, OrderDate, SalesOrderID);
CREATE INDEX IX_SalesOrders_Amount_ID      ON dbo.SalesOrders(Amount DESC, SalesOrderID ASC);
```

### Daten sichten


```sql
USE [BITest];
SELECT TOP (20) * FROM dbo.SalesOrders ORDER BY SalesOrderID;
```

## Logische Auswertungsreihenfolge (SELECT & OVER)
1. FROM / JOIN
2. WHERE
3. GROUP BY
4. HAVING
5. SELECT (hier werden **Window‑Ausdrücke** ausgewertet)
6. ORDER BY

**Merke:** Fensterfunktionen sind **nicht** in `WHERE`/`GROUP BY` erlaubt; nutze CTE/Derived Table, wenn du nach einem Window‑Ergebnis filtern willst.


## Ranking‑Funktionen (ROW_NUMBER/RANK/DENSE_RANK/NTILE)


*Fragestellung:* Wie vergebe ich stabile Ränge pro Region nach `Amount`?


```sql
USE [BITest];
SELECT SalesOrderID, Region, Amount, OrderDate,
       ROW_NUMBER() OVER (PARTITION BY Region ORDER BY Amount DESC, SalesOrderID)      AS RowNum,
       RANK()       OVER (PARTITION BY Region ORDER BY Amount DESC, SalesOrderID)      AS RankNum,
       DENSE_RANK() OVER (PARTITION BY Region ORDER BY Amount DESC, SalesOrderID)      AS DenseRankNum,
       NTILE(4)     OVER (PARTITION BY Region ORDER BY Amount DESC, SalesOrderID)      AS Quartile
FROM dbo.SalesOrders
ORDER BY Region, Amount DESC, SalesOrderID;
```

## Fensteraggregate (laufend & pro Partition)


*Fragestellung:* Wie berechne ich kumulative Umsätze pro Region sowie Gesamtumsatz je Region **pro Zeile**?


```sql
USE [BITest];
SELECT SalesOrderID, Region, Amount, OrderDate,
       -- Kumulativ (laufende Summe) über stabile Ordnung
       SUM(Amount) OVER (PARTITION BY Region ORDER BY OrderDate, SalesOrderID
                         ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS RunningAmount,
       -- Gesamtsumme der Partition (kein ORDER BY → ganze Partition)
       SUM(Amount) OVER (PARTITION BY Region) AS PartitionTotal
FROM dbo.SalesOrders
ORDER BY Region, OrderDate, SalesOrderID;
```

## Frames: `ROWS` vs. `RANGE`, gleitende Fenster


*Fragestellung:* Worin unterscheiden sich `ROWS` und das (implizite) `RANGE` – und wie bilde ich ein **gleitendes Fenster** (z. B. letzte 3 Zeilen)?

**Hinweis:** SQL Server unterstützt `RANGE` nur eingeschränkt. Für präzise Sliding‑Windows **`ROWS` verwenden**.


```sql
USE [BITest];
-- Unterschied bei Ties (gleicher Amount):
SELECT SalesOrderID, Amount,
       SUM(Amount) OVER (ORDER BY Amount
                         ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS Cum_ROWS,
       SUM(Amount) OVER (ORDER BY Amount) AS Cum_DEFAULT  -- implizit RANGE UNBOUNDED PRECEDING
FROM dbo.SalesOrders
ORDER BY Amount, SalesOrderID;
```

```sql
USE [BITest];
-- Gleitendes Fenster: letzte 3 Zeilen (inkl. aktueller) nach Datum
SELECT SalesOrderID, OrderDate, Amount,
       AVG(Amount) OVER (ORDER BY OrderDate, SalesOrderID
                         ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS MovingAvg_Last3
FROM dbo.SalesOrders
ORDER BY OrderDate, SalesOrderID;
```

## Navigationsfunktionen: `LAG/LEAD`, `FIRST_VALUE/LAST_VALUE`


*Fragestellung:* Vorheriger/nächster Wert und **korrekte Frames** für `LAST_VALUE`.


```sql
USE [BITest];
SELECT SalesOrderID, Region, OrderDate, Amount,
       LAG(Amount, 1)  OVER (PARTITION BY Region ORDER BY OrderDate, SalesOrderID) AS PrevAmount,
       LEAD(Amount, 1) OVER (PARTITION BY Region ORDER BY OrderDate, SalesOrderID) AS NextAmount,
       FIRST_VALUE(Amount) OVER (PARTITION BY Region ORDER BY OrderDate, SalesOrderID
                                 ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS FirstAmount,
       -- Achtung: default Frame liefert sonst oft **aktuellen** Wert statt letzten der Partition
       LAST_VALUE(Amount)  OVER (PARTITION BY Region ORDER BY OrderDate, SalesOrderID
                                 ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS LastAmount
FROM dbo.SalesOrders
ORDER BY Region, OrderDate, SalesOrderID;
```

## Query Optimizer/Analyzer & Ausführungsplan
**Pipeline:** Parsing → Binder → Optimizer → Plan‑Cache → Executor

**Typische Operatoren:** Sort, Segment, Sequence Project, Window Spool, Parallelism, Memory Grants.

**Erwartete Pläne (sprachlich):**
- Fensterfunktionen erzeugen meist **Segment + Sequence Project** (ggf. **Window Spool**).
- `ORDER BY` in `OVER` erfordert häufig einen **Sort** (teuer bei großen Daten). Passende Indizes können Sort vermeiden.
- Mehrere Fenster über **dieselbe** Partition/Sortierung lassen sich zusammenfassen – sonst mehrere Sorts.

**Snippets (nicht ausführen):**
```sql
SET SHOWPLAN_XML ON;
SELECT ROW_NUMBER() OVER (PARTITION BY Region ORDER BY OrderDate, SalesOrderID) FROM dbo.SalesOrders;
SET SHOWPLAN_XML OFF;

SET STATISTICS IO, TIME ON;
SELECT SUM(Amount) OVER (PARTITION BY Region ORDER BY OrderDate, SalesOrderID ROWS UNBOUNDED PRECEDING) FROM dbo.SalesOrders;
SET STATISTICS IO, TIME OFF;
```


## Typische Fallstricke


**Fall 1 – Window in `WHERE`**
*Problem:* `WHERE` sieht keine Window‑Ausdrücke.

**Korrektur:** In CTE/Unterabfrage projizieren und **außen** filtern.


```sql
USE [BITest];
-- Falsch
-- SELECT * FROM dbo.SalesOrders WHERE ROW_NUMBER() OVER (ORDER BY SalesOrderID) = 1;

-- Korrekt
WITH R AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY Region ORDER BY OrderDate, SalesOrderID) AS rn
  FROM dbo.SalesOrders
)
SELECT * FROM R WHERE rn = 1;
```

**Fall 2 – Fehlendes `ORDER BY` in `ROW_NUMBER()`**
*Problem:* Rangfolge ohne definierte Ordnung ist **nicht deterministisch**.

**Korrektur:** Immer stabilen Schlüssel (z. B. `(Sort, PK)`) angeben.


```sql
USE [BITest];
-- Fehlerhaft
-- SELECT ROW_NUMBER() OVER (PARTITION BY Region ORDER BY (SELECT 1)) AS rn FROM dbo.SalesOrders;

-- Korrekt
SELECT ROW_NUMBER() OVER (PARTITION BY Region ORDER BY OrderDate, SalesOrderID) AS rn
FROM dbo.SalesOrders;
```

**Fall 3 – `LAST_VALUE` liefert aktuellen Wert**
*Problem:* Default‑Frame endet bei `CURRENT ROW`.

**Korrektur:** `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING`.


```sql
USE [BITest];
SELECT SalesOrderID, Region, OrderDate, Amount,
       LAST_VALUE(Amount) OVER (PARTITION BY Region ORDER BY OrderDate, SalesOrderID) AS Last_Default,
       LAST_VALUE(Amount) OVER (PARTITION BY Region ORDER BY OrderDate, SalesOrderID
                                ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS Last_Correct
FROM dbo.SalesOrders
ORDER BY Region, OrderDate, SalesOrderID;
```

**Fall 4 – `RANGE` vs `ROWS` bei Ties**
*Problem:* `RANGE` (implizit) nimmt **alle Peers** am selben Sortwert in den Frame → Sprungstellen.

**Korrektur:** `ROWS`‑Frames verwenden, wenn Zeilen‑basiert inkrementell gerechnet werden soll.


```sql
USE [BITest];
SELECT Amount,
       SUM(Amount) OVER (ORDER BY Amount) AS Cum_DEFAULT,
       SUM(Amount) OVER (ORDER BY Amount ROWS UNBOUNDED PRECEDING) AS Cum_ROWS
FROM dbo.SalesOrders
ORDER BY Amount, SalesOrderID;
```

**Fall 5 – Mehrere Sorts durch uneinheitliche Fenster**
*Problem:* Unterschiedliche `PARTITION BY`/`ORDER BY` verursachen mehrere Sort‑Phasen.

**Korrektur:** Fenster konsolidieren (gleiche Partition+Order) oder Indizes passend anlegen.


## Best Practices & Performance
- Für stabile Ergebnisse **ORDER BY** in `OVER` mit eindeutigem Tiebreaker (z. B. PK).
- Für Sliding‑Windows **`ROWS`** verwenden; `RANGE` in SQL Server ist eingeschränkt und führt bei Ties zu Sprüngen.
- Window‑Ergebnisse filtern via CTE/Unterabfrage.
- Mehrere Fenster auf **gleiche** Partition/Sortierung zusammenfassen, um Sorts zu sparen.
- Passende **Indizes** (z. B. `(Region, OrderDate, SalesOrderID)`) reduzieren Sort‑Kosten.
- `COUNT(*) OVER()` liefert Zeilenanzahl des Resultsets ohne zusätzliche Abfrage.
- Messbar machen: `STATISTICS IO/TIME` und Ausführungspläne (Sort/Window Spool/Memory Grants/Spills).


## Übungen
1. Rangfolge pro `Region` nach `Amount DESC` mit `ROW_NUMBER` – geben Sie **Top 1 pro Region** aus.
2. Kumulativer Umsatz pro Region nach Datum (stabile Ordnung inkl. PK).
3. Gleitender **Durchschnitt der letzten 3 Zeilen** nach Datum.
4. `LAST_VALUE` korrekt verwenden: letzter Betrag pro Region.
5. Ermitteln Sie die Gesamtzeilenzahl per `COUNT(*) OVER()`.


```sql
-- Lösung zu Frage 1: Top 1 je Region
USE [BITest];
WITH R AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY Region ORDER BY Amount DESC, SalesOrderID) AS rn
  FROM dbo.SalesOrders
)
SELECT SalesOrderID, Region, Amount
FROM R
WHERE rn = 1
ORDER BY Region, SalesOrderID;
```

```sql
-- Lösung zu Frage 2: Laufender Umsatz pro Region
USE [BITest];
SELECT SalesOrderID, Region, OrderDate, Amount,
       SUM(Amount) OVER (PARTITION BY Region ORDER BY OrderDate, SalesOrderID
                         ROWS UNBOUNDED PRECEDING) AS RunningAmount
FROM dbo.SalesOrders
ORDER BY Region, OrderDate, SalesOrderID;
```

```sql
-- Lösung zu Frage 3: Moving Average (letzte 3 Zeilen)
USE [BITest];
SELECT SalesOrderID, OrderDate, Amount,
       AVG(Amount) OVER (ORDER BY OrderDate, SalesOrderID
                         ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS MovingAvg3
FROM dbo.SalesOrders
ORDER BY OrderDate, SalesOrderID;
```

```sql
-- Lösung zu Frage 4: LAST_VALUE korrekt (letzter Betrag pro Region)
USE [BITest];
SELECT SalesOrderID, Region, Amount,
       LAST_VALUE(Amount) OVER (PARTITION BY Region ORDER BY OrderDate, SalesOrderID
                                ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS LastAmountInRegion
FROM dbo.SalesOrders
ORDER BY Region, OrderDate, SalesOrderID;
```

```sql
-- Lösung zu Frage 5: Gesamtzeilenzahl
USE [BITest];
SELECT TOP (5) SalesOrderID, Region, Amount, COUNT(*) OVER() AS TotalRows
FROM dbo.SalesOrders
ORDER BY Amount DESC, SalesOrderID;
```

## Querverweise
- Querverweis: 05_Funktionen\Fenster- & Ranking-Funktionen (`ROW_NUMBER`, `LAG/LEAD`, `FIRST_VALUE`…) — Reihenfolgen & gleitende Berechnungen mit `OVER(PARTITION BY … ORDER BY …)` und Frames.
- Querverweis: 04_Where\Filtern nach Fensterfunktionen (`ROW_NUMBER`, `SUM OVER`) — Warum `WHERE` keine Window-Ausdrücke sieht; Muster mit CTE/abgeleiteter Tabelle, um auf Rang/Window-Ergebnis zu filtern.
- Querverweis: 06_Delete\Doppelte Zeilen löschen (CTE + `ROW_NUMBER`) — Duplikate per Window-Funktion markieren und gezielt entfernen.
- Querverweis: 05_Funktionen\Aggregatfunktionen & Textaggregation (`SUM`, `AVG`, `COUNT`, `MIN/MAX`, `STRING_AGG`) — Gruppieren & verdichten, Distinct-Aggregate, Textlisten stabil sortieren.
- Querverweis: 03_JOIN\ON vs WHERE bei OUTER JOINs — Warum Filter in `WHERE` nach dem Join wirken und einen OUTER Join faktisch zum INNER machen können; korrekte Platzierung von Filtern.


```sql
USE [master];
IF DB_ID(N'BITest') IS NOT NULL
BEGIN
    ALTER DATABASE BITest SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE BITest;
END;
```
