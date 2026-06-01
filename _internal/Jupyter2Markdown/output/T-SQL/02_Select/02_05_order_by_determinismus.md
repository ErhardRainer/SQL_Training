# 02_05_order_by_determinismus

**Quelle:** `T-SQL\02_Select\02_05_order_by_determinismus.ipynb`  
**Generiert:** 2026-04-18 21:13:30  
**Markdown-Zellen:** 31  
**SQL-Zellen:** 25  

---

# T-SQL SELECT – Sortierung mit ORDER BY & Determinismus

**Themengebiet:** SELECT

**Kapitel:** Sortierung mit ORDER BY & Determinismus

**Kurzbeschreibung:** Stabile Sortierkriterien, Kollisionen durch NULL/Kollation, zufällige Reihenfolge (ORDER BY NEWID()).

**Stand:** 6. September 2025


Dieses Notebook behandelt die **Sortierung mit `ORDER BY`** in T‑SQL und wie Sie **deterministische, stabile** Ergebnisse sicherstellen. Wir betrachten Kollisionen durch `NULL`‑Werte und **Kollation** (Groß‑/Kleinschreibung, Akzente), den Unterschied zwischen **angeforderter** und **physischer** Ordnung sowie Muster für **zufällige Reihenfolge** (`ORDER BY NEWID()`).

**Typische Fragestellungen:**
- Warum ändert sich die Reihenfolge zwischen Ausführungen ohne offensichtliche Änderungen?
- Wie mache ich Sortierung **stabil** (Tiebreaker, z. B. Primärschlüssel)?
- Wie sortiere ich `NULL` explizit nach oben/unten?
- Wieso sortieren Strings mit Umlauten/ß anders – und wie steuere ich das via **COLLATE**?
- Wie erhalte ich eine **zufällige Reihenfolge** – und welche Kosten/Nebenwirkungen hat `ORDER BY NEWID()`?


**Inhalt dieses Notebooks ist:**

- Setup & Demo‑Daten
- Logische Auswertungsreihenfolge (SELECT)
- Deterministische Sortierung & Tiebreaker
- `NULL`‑Sortierung explizit steuern
- Sortierung & **Kollation** (CI/CS, AI/AS)
- `ORDER BY` mit Ausdrücken, Alias & Ordinals
- Pagination: `ORDER BY` mit `OFFSET/FETCH` (stabile Seiten)
- Zufällige Reihenfolge: `ORDER BY NEWID()` (Einsatz & Alternativen)
- `ORDER BY` in Views/CTEs/Subqueries – Fallen
- Query Optimizer/Analyzer & Ausführungsplan
- Typische Fallstricke
- Best Practices & Performance
- Übungen
- Lösungen
- Querverweise
- Cleanup (optional)


Hinweis: Dieses Notebook nutzt einen **SQL‑Kernel**. **Alle Codezellen enthalten T‑SQL** (SQL Server).


## Setup & Demo‑Daten
Wir verwenden die Beispiel‑Datenbank **BITest** und eine Tabelle **dbo.People** mit Namen (inkl. Umlauten), optionalen Werten (`NULL`) und weiteren Spalten für Sortierbeispiele.


```sql
IF DB_ID(N'BITest') IS NULL
BEGIN
    CREATE DATABASE BITest;
END;
GO
USE [BITest];
GO
IF OBJECT_ID(N'dbo.People','U') IS NOT NULL DROP TABLE dbo.People;
CREATE TABLE dbo.People
(
  PersonID   int IDENTITY(1,1) CONSTRAINT PK_People PRIMARY KEY,
  LastName   nvarchar(50) NULL,
  FirstName  nvarchar(50) NOT NULL,
  City       nvarchar(50) NULL,
  Score      decimal(9,2) NULL,
  BirthDate  date NULL
);
INSERT INTO dbo.People (LastName, FirstName, City, Score, BirthDate) VALUES
(N'Ärztin', N'Anna',  N'München',  88.50, '1990-05-01'),
(N'Azubi',  N'Berta', N'Muenchen', 88.50, '1992-06-10'),
(N'Aepler', N'Carla', N'Zürich',   72.10, '1985-02-11'),
(N'Äpfel',  N'Dora',  N'Zuerich',  72.10, '1985-02-11'),
(N'Straße', N'Erik',  N'Köln',     95.00, '1979-09-09'),
(N'Strasse',N'Fritz', N'Koeln',    95.00, '1979-09-09'),
(NULL,      N'Gina',  NULL,        70.00, NULL),
(N'Maier',  N'Hans',  N'Wien',     88.50, '1990-05-01'),
(N'Mayer',  N'Ida',   N'Wien',     88.50, '1990-05-01'),
(N'Meier',  N'Jan',   N'Wien',     NULL,  '1990-05-01'),
(N'Zoë',    N'Kai',   N'Graz',     88.50, '1993-01-23'),
(N'Zoe',    N'Lia',   N'Graz',     88.50, '1993-01-23');
-- Hilfsindex zur Demonstration (Sortierung über LastName, PersonID)
CREATE INDEX IX_People_LastName_ID ON dbo.People(LastName ASC, PersonID ASC);
```

### Daten sichten


```sql
USE [BITest];
SELECT TOP (20) * FROM dbo.People ORDER BY PersonID;
```

## Logische Auswertungsreihenfolge
1. FROM / JOIN
2. WHERE
3. GROUP BY
4. HAVING
5. SELECT
6. ORDER BY (optional; bestimmt **Ausgabe**‐Reihenfolge, nicht die Verarbeitung)

Ohne `ORDER BY` ist die Reihenfolge **nicht garantiert** – auch dann nicht, wenn ein Index existiert.


## Deterministische Sortierung & Tiebreaker


*Fragestellung:* Wie stelle ich stabile Reihenfolgen sicher, insbesondere bei **Gleichständen**?


```sql
USE [BITest];
-- Stabil: Primärsortierung + eindeutiger Tiebreaker (z. B. PersonID)
SELECT PersonID, LastName, FirstName, Score
FROM dbo.People
ORDER BY Score DESC, LastName ASC, PersonID ASC;
```

## `NULL`‑Sortierung explizit steuern


*Fragestellung:* Wie sortiere ich `NULL` **zuletzt** (bzw. zuerst), obwohl SQL Server keine `NULLS LAST/FIRST` Syntax hat?


```sql
USE [BITest];
-- NULLS LAST bei ASC: erst Nicht‑NULL (0), dann NULL (1)
SELECT PersonID, LastName, Score
FROM dbo.People
ORDER BY CASE WHEN Score IS NULL THEN 1 ELSE 0 END, Score ASC, PersonID ASC;

-- NULLS FIRST bei DESC (analoge Technik)
SELECT PersonID, LastName, Score
FROM dbo.People
ORDER BY CASE WHEN Score IS NULL THEN 0 ELSE 1 END, Score DESC, PersonID ASC;
```

## Sortierung & **Kollation** (CI/CS, AI/AS)


*Fragestellung:* Warum unterscheiden sich Reihenfolgen bei Umlauten/ß – und wie steuere ich das für **eine Abfrage**?


```sql
USE [BITest];
-- Akzent‑insensitiv (CI_AI): 'Ä' ~ 'Ae', 'ö' ~ 'oe' werden ähnlich eingeordnet
SELECT PersonID, LastName
FROM dbo.People
ORDER BY LastName COLLATE Latin1_General_CI_AI ASC, PersonID ASC;

-- Akzent‑sensitiv (CI_AS): 'Ä' kommt typ. nach 'A' / vor 'B' je Sortregeln; 'Zoë' ≠ 'Zoe'
SELECT PersonID, LastName
FROM dbo.People
ORDER BY LastName COLLATE Latin1_General_CI_AS ASC, PersonID ASC;

-- **Case‑sensitiv** (CS_AS): Groß/Klein beeinflusst Reihenfolge
SELECT PersonID, LastName
FROM dbo.People
ORDER BY LastName COLLATE Latin1_General_CS_AS ASC, PersonID ASC;
```

## `ORDER BY` mit Ausdrücken, Alias & Ordinals


*Fragestellung:* Darf ich Aliase im `ORDER BY` verwenden und was sind Risiken mit **Spalten‑Ordinals**?


```sql
USE [BITest];
-- Alias in ORDER BY ist erlaubt (im Gegensatz zu WHERE)
SELECT LastName AS LN, FirstName, Score
FROM dbo.People
ORDER BY LN ASC, PersonID ASC;

-- Ordinal (2 = Zweite Ausgabespalte) funktioniert, ist aber fragil bei späteren Änderungen
SELECT LastName AS LN, FirstName, Score
FROM dbo.People
ORDER BY 2, PersonID;  -- vermeidbar, besser Spaltennamen/Alias verwenden
```

## Pagination: `ORDER BY` mit `OFFSET/FETCH` (stabile Seiten)


*Fragestellung:* Wie vermeide ich **Duplikate/Lücken** zwischen Seiten bei Gleichständen?


```sql
USE [BITest];
-- Seite 1 (0‑basiert): OFFSET 0, FETCH 5
SELECT PersonID, LastName, Score
FROM dbo.People
ORDER BY Score DESC, LastName ASC, PersonID ASC
OFFSET 0 ROWS FETCH NEXT 5 ROWS ONLY;

-- Seite 2: gleiches Sortkriterium + Tiebreaker
SELECT PersonID, LastName, Score
FROM dbo.People
ORDER BY Score DESC, LastName ASC, PersonID ASC
OFFSET 5 ROWS FETCH NEXT 5 ROWS ONLY;
```

## Zufällige Reihenfolge: `ORDER BY NEWID()` (Einsatz & Alternativen)


*Fragestellung:* Wie erhalte ich Zufallsreihenfolgen – und wann ist das zu teuer?


```sql
USE [BITest];
-- Vollständig zufällige Reihenfolge (pro Zeile NEWID): kann teuer sein (Sort auf GUID)
SELECT TOP (5) PersonID, LastName
FROM dbo.People
ORDER BY NEWID();

-- Alternative für Stichprobe (nicht gleichverteilt!): TABLESAMPLE (Seitenbasiert)
SELECT TOP (5) PersonID, LastName
FROM dbo.People TABLESAMPLE (50 PERCENT);  -- Hinweis: unpräzise, Seiten‑basiert
```

## `ORDER BY` in Views/CTEs/Subqueries – Fallen


*Fragestellung:* Warum ignoriert SQL Server das `ORDER BY` im Unterselect/View – und wie mache ich die Ausgabe **deterministisch**?


```sql
USE [BITest];
-- Anti‑Pattern: TOP 100 PERCENT ORDER BY in View/Subquery – der Optimizer darf die Sortierung entfernen
-- (Demonstration als Inline‑View)
SELECT PersonID, LastName
FROM (
  SELECT TOP (100) PERCENT PersonID, LastName
  FROM dbo.People
  ORDER BY LastName
) AS v
ORDER BY LastName;  -- Nur das **äußere** ORDER BY garantiert die Ausgabe‑Reihenfolge

```

## Query Optimizer/Analyzer & Ausführungsplan
**Pipeline:** Parsing → Binder → Optimizer → Plan‑Cache → Executor

**Relevante Operatoren:**
- **Sort**: ordnet Eingaben; benötigt Speicher (**Memory Grant**); kann teuer/parallel sein.
- **Top / Top N Sort**: kombiniert Sortierung + Limit; nutzt Indizes ggf. effizient.
- **Index Seek/Scan**: physische Indexreihenfolge ≠ garantierte Ausgabe ohne `ORDER BY`.
- **Parallelism (Distribute/Repartition/Gather)**: kann Reihenfolge zerstören; finaler Sort/Gather ordnet neu.

**Erwartete Pläne (sprachlich):**
- `ORDER BY` ohne passenden Index → `Sort`.
- Passender Index (z. B. `(Score DESC, LastName, PersonID)`) → ggf. `Index Seek/Scan` ohne expliziten `Sort`.
- `ORDER BY NEWID()` → `Sort` auf GUID‑Ausdruck (kostspielig).

**Snippets (nicht ausführen):**
```sql
SET SHOWPLAN_XML ON;
SELECT PersonID, LastName FROM dbo.People ORDER BY Score DESC, LastName, PersonID;
SET SHOWPLAN_XML OFF;

SET STATISTICS IO, TIME ON;
SELECT TOP (5) PersonID FROM dbo.People ORDER BY NEWID();
SET STATISTICS IO, TIME OFF;
```


## Typische Fallstricke


**Fall 1 – Indexreihenfolge ≠ garantierte Ausgabe**
*Fragestellung:* Warum wechselt die Reihenfolge trotz Index?


```sql
USE [BITest];
-- Fehlerhaft: keine Garantie ohne ORDER BY (selbst wenn Index existiert)
SELECT PersonID, LastName FROM dbo.People;
```

```sql
USE [BITest];
-- Korrekt: explizite Sortierung
SELECT PersonID, LastName FROM dbo.People ORDER BY LastName, PersonID;
```

**Fall 2 – Unstabile Pagination (fehlender Tiebreaker)**
*Fragestellung:* Warum sehe ich Duplikate/Lücken zwischen Seiten?


```sql
USE [BITest];
-- Fehlerhaft: kein eindeutiger Tiebreaker bei Gleichstand
SELECT PersonID, LastName, Score
FROM dbo.People
ORDER BY Score DESC
OFFSET 0 ROWS FETCH NEXT 5 ROWS ONLY;
```

```sql
USE [BITest];
-- Korrektur: Tiebreaker ergänzen
SELECT PersonID, LastName, Score
FROM dbo.People
ORDER BY Score DESC, PersonID ASC
OFFSET 0 ROWS FETCH NEXT 5 ROWS ONLY;
```

**Fall 3 – Kollation führt zu unerwarteter Reihenfolge**
*Fragestellung:* Warum steht 'Ärztin' nicht da, wo ich es erwarte?


```sql
USE [BITest];
-- Überraschung je nach DB‑Kollation
SELECT LastName FROM dbo.People ORDER BY LastName;
```

```sql
USE [BITest];
-- Korrektur: kollationsspezifisch sortieren
SELECT LastName FROM dbo.People ORDER BY LastName COLLATE Latin1_General_CI_AS, PersonID;
```

**Fall 4 – Zahlen in Textspalten werden lexikographisch sortiert**
*Fragestellung:* Warum kommt '100' vor '20'?


```sql
USE [BITest];
-- Fehlerhaft: Textsortierung
SELECT CAST(PersonID AS varchar(10)) AS PersonIDText FROM dbo.People ORDER BY PersonIDText;
```

```sql
USE [BITest];
-- Korrektur: numerische Sortierung
SELECT CAST(PersonID AS varchar(10)) AS PersonIDText FROM dbo.People ORDER BY CAST(PersonIDText AS int);
```

**Fall 5 – `ORDER BY RAND()` liefert keine echte Zeilenpermutation**
*Fragestellung:* Wieso ändert sich die Reihenfolge kaum?


```sql
USE [BITest];
-- Fehler: RAND() wird pro Abfrage einmal evaluiert → gleicher Wert für alle Zeilen
-- (je nach Kontext kann SQL Server ORDER BY RAND() sogar ablehnen)
-- SELECT PersonID FROM dbo.People ORDER BY RAND();
```

```sql
USE [BITest];
-- Korrektur: NEWID() pro Zeile
SELECT TOP (5) PersonID FROM dbo.People ORDER BY NEWID();
```

## Best Practices & Performance
- **Immer** explizit `ORDER BY` angeben, wenn Reihenfolge relevant ist.
- Für Stabilität bei Gleichständen: **eindeutigen Tiebreaker** (z. B. Primärschlüssel) ergänzen.
- `NULL`‑Reihenfolge per `CASE`/`ISNULL` erzwingen; SQL Server kennt kein `NULLS FIRST/LAST`.
- Kollation bewusst setzen (`… COLLATE …`) für gewünschte sprachliche Sortierung.
- Zahlen als Text? Vor dem Sortieren **typisieren/casten**.
- Für Pagination große Offsets vermeiden; ggf. **Keyset/Seek‑Pagination** nutzen.
- `ORDER BY NEWID()` nur für kleine Mengen; alternativ vorab **RandomKey** speichern und darauf sortieren.
- Pläne/Messwerte prüfen: `Sort`, `Top N Sort`, **Memory Grants**, Parallelismus.


## Übungen
1. Sortieren Sie Personen **deterministisch** nach `Score DESC`, dann `LastName ASC` und `PersonID` als Tiebreaker.
2. Geben Sie `Score`‑Sortierung mit **NULLS LAST** aus (ASC).
3. Sortieren Sie `LastName` **akzent‑sensitiv** und **case‑sensitiv**.
4. Erzeugen Sie eine **zufällige Reihenfolge** und geben Sie die **Top 3** aus.
5. Zeigen Sie Seite 2 (5 je Seite) stabil mit `OFFSET/FETCH`.


```sql
-- Lösung zu Frage 1: Stabil nach Score/LastName/ID
USE [BITest];
SELECT PersonID, LastName, FirstName, Score
FROM dbo.People
ORDER BY Score DESC, LastName ASC, PersonID ASC;
```

```sql
-- Lösung zu Frage 2: NULLS LAST (ASC)
USE [BITest];
SELECT PersonID, LastName, Score
FROM dbo.People
ORDER BY CASE WHEN Score IS NULL THEN 1 ELSE 0 END, Score ASC, PersonID ASC;
```

```sql
-- Lösung zu Frage 3: CS_AS & AS (case/akzent‑sensitiv)
USE [BITest];
SELECT PersonID, LastName
FROM dbo.People
ORDER BY LastName COLLATE Latin1_General_CS_AS ASC, PersonID ASC;
```

```sql
-- Lösung zu Frage 4: Zufällige Top 3
USE [BITest];
SELECT TOP (3) PersonID, LastName
FROM dbo.People
ORDER BY NEWID();
```

```sql
-- Lösung zu Frage 5: Seite 2 à 5
USE [BITest];
SELECT PersonID, LastName, Score
FROM dbo.People
ORDER BY Score DESC, LastName ASC, PersonID ASC
OFFSET 5 ROWS FETCH NEXT 5 ROWS ONLY;
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
