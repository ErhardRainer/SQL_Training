# 02_04_top_offset_fetch.ipynb

**Quelle:** `T-SQL\02_Select\02_04_top_offset_fetch.ipynb.ipynb`  
**Generiert:** 2026-04-18 21:13:30  
**Markdown-Zellen:** 31  
**SQL-Zellen:** 22  

---

# T-SQL SELECT – TOP, WITH TIES, PERCENT & Pagination mit OFFSET/FETCH

**Themengebiet:** SELECT

**Kapitel:** TOP, WITH TIES, PERCENT & Pagination mit OFFSET/FETCH

**Kurzbeschreibung:** Zeilenlimitierung korrekt einsetzen und stabil sortieren; Unterschiede zwischen Limitierung und Pagination.

**Stand:** 6. September 2025


Dieses Notebook zeigt, wie Sie in T‑SQL Ergebniszeilen begrenzen (`TOP`, `WITH TIES`, `PERCENT`) und wie Sie **Pagination** mit `ORDER BY … OFFSET … FETCH` korrekt und stabil implementieren. Wir beleuchten deterministische Sortierung (Tiebreaker), Unterschiede zwischen **Limitierung** (nur "erste N") und **Pagination** (beliebige Seiten), sowie Einflüsse auf Ausführungspläne und Performance.

**Typische Fragestellungen:**
- Wie erhalte ich die **Top‑N** Zeilen korrekt und reproduzierbar?
- Wann ist `WITH TIES` sinnvoll und wie wirkt es?
- Warum ist `TOP (… ) PERCENT` heikel?
- Wie implementiere ich Pagination mit `OFFSET/FETCH` **stabil**, ohne Duplikate/
  Lücken zwischen Seiten?
- Welche Alternativen gibt es (Keyset/Seek‑Pagination) und wann sind sie schneller?


**Inhalt dieses Notebooks ist:**

- Setup & Demo‑Daten
- Logische Auswertungsreihenfolge (SELECT)
- `TOP` – Grundsyntax & deterministische Sortierung
- `WITH TIES` – Grenzwerte korrekt behandeln
- `TOP (… ) PERCENT` – Risiken & Rundung
- `OFFSET … FETCH` – Pagination Grundlagen
- Stabile Sortierung mit Tiebreaker
- Keyset (Seek)‑Pagination als Alternative
- Limitierung vs Pagination – Gegenüberstellung
- Query Optimizer/Analyzer & Ausführungsplan
- Typische Fallstricke
- Best Practices & Performance
- Übungen
- Lösungen
- Querverweise
- Cleanup (optional)


Hinweis: Dieses Notebook nutzt einen **SQL‑Kernel**. **Alle Codezellen enthalten T‑SQL** (SQL Server).


## Setup & Demo‑Daten
Wir verwenden eine Beispiel‑Datenbank **BITest** und eine Tabelle **dbo.SalesOrders** mit Beträgen und absichtlichen **Ties** (gleiche `Amount`) zur Demonstration stabiler Sortierung und Pagination.


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
  OrderDate    date        NOT NULL,
  CustomerID   int         NOT NULL,
  Region       nvarchar(10) NOT NULL,
  Amount       decimal(10,2) NOT NULL
);
INSERT INTO dbo.SalesOrders (OrderDate, CustomerID, Region, Amount) VALUES
('2025-01-05',101,N'West',  49.99),
('2025-01-06',102,N'West',  99.99),
('2025-01-07',103,N'West',  99.99),
('2025-01-08',104,N'Nord', 199.00),
('2025-01-09',105,N'Nord', 199.00),
('2025-01-10',106,N'Nord', 199.00),
('2025-01-11',107,N'Nord', 199.00),
('2025-01-12',108,N'Ost',  299.00),
('2025-01-13',109,N'Ost',  299.00),
('2025-01-14',110,N'Ost',  299.00),
('2025-01-15',111,N'Sued',  79.00),
('2025-01-16',112,N'Sued',  79.00),
('2025-01-17',113,N'Sued',  79.00),
('2025-02-01',114,N'West',  49.99),
('2025-02-02',115,N'West',  49.99),
('2025-02-03',116,N'West',  49.99),
('2025-02-04',117,N'West', 499.00),
('2025-02-05',118,N'Nord', 499.00),
('2025-02-06',119,N'Ost',  499.00),
('2025-02-07',120,N'Sued', 499.00),
('2025-02-08',121,N'West', 149.00),
('2025-02-09',122,N'Nord', 149.00),
('2025-02-10',123,N'Ost',  149.00),
('2025-02-11',124,N'Sued', 149.00);

-- Hilfsindex unterstützt Sortierung & Seek-Pagination
CREATE INDEX IX_SalesOrders_Amount_ID ON dbo.SalesOrders(Amount DESC, SalesOrderID ASC);
```

### Daten sichten


```sql
USE [BITest];
SELECT TOP (10) *
FROM dbo.SalesOrders
ORDER BY SalesOrderID;
```

## Logische Auswertungsreihenfolge
1. FROM / JOIN
2. WHERE
3. GROUP BY
4. HAVING
5. SELECT
6. ORDER BY (optional, **für deterministische Ausgabe und für OFFSET/FETCH erforderlich**)

`TOP` wird nach der Sortierung angewandt (physisch via **Top/Top N Sort**). Ohne `ORDER BY` ist die Auswahl **nicht deterministisch**.


## `TOP` – Grundsyntax & deterministische Sortierung


*Fragestellung:* Wie hole ich die 5 höchsten Beträge reproduzierbar?


```sql
USE [BITest];
SELECT TOP (5) SalesOrderID, Amount, OrderDate
FROM dbo.SalesOrders
ORDER BY Amount DESC, SalesOrderID ASC;  -- Tiebreaker für stabile Reihenfolge
```

## `WITH TIES` – Grenzwerte korrekt behandeln


*Fragestellung:* Wie nehme ich **alle** Zeilen mit, die am Cut‑off denselben Sortwert haben?


```sql
USE [BITest];
-- Liefert mindestens 5 Zeilen; bei Gleichstand mehr (alle mit dem 5.-größten Amount)
SELECT TOP (5) WITH TIES SalesOrderID, Amount, OrderDate
FROM dbo.SalesOrders
ORDER BY Amount DESC;  -- Ties werden am letzten Sortwert festgemacht
```

## `TOP (… ) PERCENT` – Risiken & Rundung


*Fragestellung:* Was bewirkt `TOP PERCENT` und warum ist es oft ungeeignet?


```sql
USE [BITest];
-- Prozentangaben werden auf ganze Zeilen gerundet; Ergebnisgröße hängt von Gesamtanzahl ab
SELECT TOP (10) PERCENT SalesOrderID, Amount
FROM dbo.SalesOrders
ORDER BY Amount DESC, SalesOrderID ASC;
```

## `OFFSET … FETCH` – Pagination Grundlagen


*Fragestellung:* Wie blättere ich seitenweise – Seite 1 mit 5 Zeilen? (ORDER BY ist Pflicht)


```sql
USE [BITest];
-- Seite 1 (0-basiert): OFFSET 0, FETCH 5
SELECT SalesOrderID, Amount, OrderDate
FROM dbo.SalesOrders
ORDER BY Amount DESC, SalesOrderID ASC
OFFSET 0 ROWS FETCH NEXT 5 ROWS ONLY;
```

## Stabile Sortierung mit Tiebreaker


*Fragestellung:* Wie vermeide ich Duplikate/Lücken zwischen Seiten bei Gleichständen?


```sql
USE [BITest];
-- Seite 2: dieselbe Sortierung + eindeutiger Tiebreaker (SalesOrderID)
SELECT SalesOrderID, Amount, OrderDate
FROM dbo.SalesOrders
ORDER BY Amount DESC, SalesOrderID ASC
OFFSET 5 ROWS FETCH NEXT 5 ROWS ONLY;
```

## Keyset (Seek)‑Pagination als Alternative


*Fragestellung:* Wie lade ich **die nächsten 5** nach dem letzten Eintrag effizient (ohne große Offsets)?


```sql
USE [BITest];
DECLARE @afterAmount decimal(10,2) = 299.00;
DECLARE @afterID     int           = 10;
SELECT TOP (5) SalesOrderID, Amount, OrderDate
FROM dbo.SalesOrders
WHERE (Amount < @afterAmount)
   OR (Amount = @afterAmount AND SalesOrderID > @afterID)
ORDER BY Amount DESC, SalesOrderID ASC;
```

## Limitierung vs Pagination – Gegenüberstellung


*Fragestellung:* Worin unterscheiden sich `TOP` und `OFFSET/FETCH` praktisch?


```sql
USE [BITest];
-- Limitierung: exakt die ersten 5 (nach Sortierung)
SELECT TOP (5) SalesOrderID, Amount
FROM dbo.SalesOrders
ORDER BY Amount DESC, SalesOrderID;

-- Pagination: beliebige Seite (hier Seite 3 à 5 Zeilen)
SELECT SalesOrderID, Amount
FROM dbo.SalesOrders
ORDER BY Amount DESC, SalesOrderID
OFFSET 10 ROWS FETCH NEXT 5 ROWS ONLY;
```

## Query Optimizer/Analyzer & Ausführungsplan
**Pipeline:** Parsing → Binder → Optimizer → Plan‑Cache → Executor

**Typische Operatoren & Effekte:**
- **Top** / **Top N Sort**: sortiert und schneidet auf N; bei passendem Index oft **Index Seek + Top** ohne Sort.
- **Sort**: teuer bei großen Daten; `OFFSET` erhöht die Kosten linear mit der Übersprungen‑Menge.
- **Parallelism**: Sort/Top können parallelisiert werden; Final Merge erforderlich.
- **Memory Grants**: Sort/Top N Sort benötigen Speicher; Ties können N > erwartet machen.

**Erwartete Pläne (sprachlich):**
- `TOP` mit geeignetem Index → `Index Seek` → `Top`.
- `OFFSET/FETCH` → meist `Sort` + `Top` (mit Offset) oder Seek‑Pattern bei Keyset‑Pagination.

**Snippets (nicht ausführen):**
```sql
SET SHOWPLAN_XML ON;
SELECT TOP (5) * FROM dbo.SalesOrders ORDER BY Amount DESC, SalesOrderID;
SET SHOWPLAN_XML OFF;

SET STATISTICS IO, TIME ON;
SELECT SalesOrderID FROM dbo.SalesOrders ORDER BY Amount DESC, SalesOrderID OFFSET 50000 ROWS FETCH NEXT 50 ROWS ONLY;
SET STATISTICS IO, TIME OFF;
```


```sql
USE [BITest];
-- Messbeispiel 1: Top N
SELECT TOP (5) SalesOrderID, Amount
FROM dbo.SalesOrders
ORDER BY Amount DESC, SalesOrderID;

-- Messbeispiel 2: OFFSET/FETCH
SELECT SalesOrderID, Amount
FROM dbo.SalesOrders
ORDER BY Amount DESC, SalesOrderID
OFFSET 5 ROWS FETCH NEXT 5 ROWS ONLY;
```

## Typische Fallstricke


**Fall 1 – `TOP` ohne `ORDER BY` ist nicht deterministisch**
*Fragestellung:* Warum erhalte ich wechselnde Zeilen?


```sql
USE [BITest];
-- Fehlerhaft / heikel (keine definierte Reihenfolge)
SELECT TOP (5) SalesOrderID, Amount FROM dbo.SalesOrders;
```

```sql
USE [BITest];
-- Korrektur: explizite Sortierung + Tiebreaker
SELECT TOP (5) SalesOrderID, Amount
FROM dbo.SalesOrders
ORDER BY Amount DESC, SalesOrderID ASC;
```

**Fall 2 – `OFFSET/FETCH` ohne `ORDER BY`**
*Fragestellung:* Warum kompiliert das nicht?


```sql
USE [BITest];
-- Fehlerhaft: ORDER BY ist Pflicht für OFFSET/FETCH
-- SELECT SalesOrderID FROM dbo.SalesOrders OFFSET 0 ROWS FETCH NEXT 5 ROWS ONLY;
```

**Fall 3 – Nichtstabile Sortierung**
*Fragestellung:* Warum tauchen zwischen Seite 1 und 2 Duplikate/Lücken auf?


```sql
USE [BITest];
-- Fehlerhaft: kein eindeutiger Tiebreaker
SELECT SalesOrderID, Amount
FROM dbo.SalesOrders
ORDER BY Amount DESC
OFFSET 0 ROWS FETCH NEXT 5 ROWS ONLY;

-- Korrektur: Tiebreaker hinzufügen
SELECT SalesOrderID, Amount
FROM dbo.SalesOrders
ORDER BY Amount DESC, SalesOrderID ASC
OFFSET 0 ROWS FETCH NEXT 5 ROWS ONLY;
```

**Fall 4 – `SET ROWCOUNT` für SELECT**
*Fragestellung:* Warum ist das ungünstig und für DML riskant?


```sql
USE [BITest];
-- Fehleranfällig: beeinflusst auch DML, veraltet für DML
SET ROWCOUNT 5;
SELECT SalesOrderID, Amount FROM dbo.SalesOrders ORDER BY Amount DESC, SalesOrderID;
SET ROWCOUNT 0;

-- Besser: explizites TOP/OFFSET in der Abfrage verwenden
```

**Fall 5 – Große Offsets sind langsam**
*Fragestellung:* Warum wird Seite 200 (OFFSET 995) langsam?


```sql
USE [BITest];
-- Problematisch: Engine muss oft OFFSET Zeilen sortieren/überspringen
SELECT SalesOrderID, Amount
FROM dbo.SalesOrders
ORDER BY Amount DESC, SalesOrderID
OFFSET 995 ROWS FETCH NEXT 5 ROWS ONLY;

-- Alternative: Keyset/Seek-Pagination (siehe oben)
```

## Best Practices & Performance
- **Immer** mit `ORDER BY` arbeiten; für Stabilität **eindeutigen Tiebreaker** ergänzen (z. B. `(Sortschlüssel, PK)`).
- `WITH TIES` nutzen, wenn alle Grenzwerte einbezogen werden sollen.
- `TOP PERCENT` vermeiden (schlecht steuerbar, rundet auf Zeilen).
- Für große Seitenzahlen: **Keyset/Seek‑Pagination** statt großer Offsets.
- Passende **Indizes** in Sortreihenfolge (z. B. `Amount DESC, SalesOrderID ASC`) vermeiden Sort‑Kosten.
- Messbar machen mit **STATISTICS IO/TIME** und Ausführungsplänen (Top/Sort/Memory Grant beobachten).


## Übungen
1. Ermitteln Sie die **Top 5** Aufträge nach `Amount` (stabil sortiert).
2. Geben Sie **Seite 3** mit **5 Zeilen/Seite** per `OFFSET/FETCH` aus (stabile Sortierung).
3. Implementieren Sie eine **Keyset‑Pagination**: Laden Sie die nächsten 5 nach (`@afterAmount=199.00`, `@afterID=11`).
4. Zeigen Sie die **Top 10 %** nach `Amount` und diskutieren Sie die Auswirkung auf die Zeilenzahl.
5. Zeigen Sie mit `WITH TIES`, dass alle Zeilen am Grenzwert einbezogen werden.


```sql
-- Lösung zu Frage 1: Top 5 stabil sortiert
USE [BITest];
SELECT TOP (5) SalesOrderID, Amount, OrderDate
FROM dbo.SalesOrders
ORDER BY Amount DESC, SalesOrderID ASC;
```

```sql
-- Lösung zu Frage 2: Seite 3 à 5 Zeilen (OFFSET 10)
USE [BITest];
SELECT SalesOrderID, Amount, OrderDate
FROM dbo.SalesOrders
ORDER BY Amount DESC, SalesOrderID ASC
OFFSET 10 ROWS FETCH NEXT 5 ROWS ONLY;
```

```sql
-- Lösung zu Frage 3: Keyset-Pagination ab (199.00, ID 11)
USE [BITest];
DECLARE @afterAmount decimal(10,2) = 199.00;
DECLARE @afterID     int           = 11;
SELECT TOP (5) SalesOrderID, Amount, OrderDate
FROM dbo.SalesOrders
WHERE (Amount < @afterAmount)
   OR (Amount = @afterAmount AND SalesOrderID > @afterID)
ORDER BY Amount DESC, SalesOrderID ASC;
```

```sql
-- Lösung zu Frage 4: Top 10 Prozent (mit Rundung)
USE [BITest];
SELECT TOP (10) PERCENT SalesOrderID, Amount
FROM dbo.SalesOrders
ORDER BY Amount DESC, SalesOrderID ASC;
```

```sql
-- Lösung zu Frage 5: WITH TIES am Grenzwert
USE [BITest];
SELECT TOP (5) WITH TIES SalesOrderID, Amount, OrderDate
FROM dbo.SalesOrders
ORDER BY Amount DESC;
```

## Querverweise
- Querverweis: 05_Funktionen\Aggregatfunktionen & Textaggrega...& verdichten, Distinct-Aggregate, Textlisten stabil sortieren.
- Querverweis: 03_JOIN\APPLY (CROSS/OUTER) – Lateral Joins — ...uster wie JSON/XML-Parsing, Top-N-pro-Gruppe, „per row Top 1“.
- Querverweis: 03_JOIN\Joins mit JSON/XML/TVFs — > **Kurzbesc...OPENJSON`, `CROSS APPLY … nodes()` und Table-Valued Functions.
- Querverweis: 06_Delete\`DELETE … FROM` (Join-Delete) — Lösc...le (Join/CTE) – Duplikate und Eindeutigkeit korrekt behandeln.
- Querverweis: 04_Where\`WHERE` vs. `ON` bei JOINs — Untersch...um `WHERE` einen `LEFT JOIN` faktisch zum `INNER` machen kann.


```sql
USE [master];
IF DB_ID(N'BITest') IS NOT NULL
BEGIN
    ALTER DATABASE BITest SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE BITest;
END;
```
