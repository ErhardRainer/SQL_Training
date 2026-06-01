# HavingThresholdPatterns.sql

Dieses Skript zeigt typische `HAVING`-Filter fuer gruppierte Auswertungen. Die Demo verwendet kompakte Order-Daten und kontrastiert Umsatzschwellen, Mindestanzahl pro Gruppe sowie einen Ausreisserfilter ueber besonders hohe Einzelorders.

## Uebersicht

<!-- SQLDOC:SUMMARY_TABLE:BEGIN -->
| Feld | Wert |
|---|---|
| Script | [HavingThresholdPatterns.sql](HavingThresholdPatterns.sql) |
| Version | `1.0` |
| Typ | `didactic-lab` |
| Kapitel | `10_GroupBy_Aggregate` |
| Sicherheit | `read-only-tempdb` |
| Zweck | Demonstriert typische `HAVING`-Muster fuer Mindestumsatz, Mindestanzahl und gruppenbezogene Ausreisserfilter. |
<!-- SQLDOC:SUMMARY_TABLE:END -->

## Einordnung

`HAVING` filtert nicht einzelne Zeilen, sondern bereits verdichtete Gruppen. Genau deshalb eignet sich das Muster fuer Reporting- und Review-Fragen wie:

- Welche Regionen und Kanaele erreichen einen Zielumsatz?
- Welche Gruppen haben genug Beobachtungen fuer einen belastbaren Vergleich?
- In welchen Gruppen taucht mindestens eine auffaellig hohe Einzeltransaktion auf?

Das Skript zeigt erst die Basiskennzahlen aller Gruppen und danach vier Varianten von `HAVING`: Umsatzschwelle, Mindestanzahl, Ausreisserfilter und eine kombinierte Regel.

## Annahmen

- Die Erstversion nutzt lokale Temp-Tabellen mit Demo-Orders statt produktiver Sales-Fakten.
- Gruppiert wird bewusst nur nach `SalesRegion` und `SalesChannel`, damit der Effekt der `HAVING`-Filter direkt sichtbar bleibt.
- Der Ausreisserfilter verwendet `MAX(OrderAmount) >= @OutlierOrderAmount` als leicht nachvollziehbares Schwellenmuster.
- `@MinRevenue = 3000.00`, `@MinOrderCount = 3` und `@OutlierOrderAmount = 1800.00` dienen als didaktische Startwerte und koennen fuer andere Szenarien angepasst werden.

## Anwendungsfall

Das Artefakt passt zu Trainings, Review-Sessions und diagnostischen Reportabfragen, bei denen Gruppen erst nach der Aggregation bewertet werden sollen. Das Muster laesst sich spaeter auf echte Faktentabellen uebertragen, indem die Temp-Tabelle durch reale Quellen ersetzt und die Gruppierungsattribute sowie Schwellenwerte fachlich konkretisiert werden.

## Parameter

<!-- SQLDOC:PARAMETERS_TABLE:BEGIN -->
| Parameter | SQL-Typ | Pflicht | Beschreibung |
|---|---|---|---|
| `@MinRevenue` | `DECIMAL(12,2)` | Ja | Mindestumsatz, den eine Gruppe im `SUM`-basierten `HAVING`-Filter erreichen muss. |
| `@MinOrderCount` | `INT` | Ja | Mindestanzahl an Orders pro Gruppe fuer `COUNT(*)`-basierte Filter. |
| `@OutlierOrderAmount` | `DECIMAL(12,2)` | Ja | Grenzwert fuer Gruppen mit mindestens einer auffaellig hohen Einzelorder. |
| `@IncludeSourceData` | `BIT` | Nein | Gibt bei `1` die Demo-Quelldaten vor den Aggregationen aus. |
<!-- SQLDOC:PARAMETERS_TABLE:END -->

## Abhaengigkeiten

<!-- SQLDOC:DEPENDENCIES_LIST:BEGIN -->
- `tempdb`
- `GROUP BY`
- `HAVING`
- `SUM()`
- `COUNT()`
- `AVG()`
- `MAX()`
- `UNION ALL`
- `DROP TABLE IF EXISTS`
<!-- SQLDOC:DEPENDENCIES_LIST:END -->

## Hinweise

- `#GroupAggregate` liefert die Baseline aller Gruppen, bevor eine Schwelle angewendet wird.
- `minimum_revenue` zeigt das Standardmuster `HAVING SUM(...) >= ...`.
- `minimum_order_count` isoliert Gruppen, die gross genug fuer Folgerechnungen oder Vergleiche sind.
- `outlier_order_filter` markiert Gruppen mit mindestens einer auffaellig hohen Order ueber `MAX(...)`.
- `combined_thresholds` zeigt, wie mehrere Gruppenkriterien direkt in einer einzigen `HAVING`-Klausel kombiniert werden koennen.

## Versionshistorie

<!-- SQLDOC:VERSION_HISTORY_TABLE:BEGIN -->
| Version | Datum | User | Beschreibung |
|---|---|---|---|
| `1.0` | `2026-04-18` | `ER` | Erstversion fuer typische HAVING-Schwellenmuster in Gruppenauswertungen |
<!-- SQLDOC:VERSION_HISTORY_TABLE:END -->

## Ablauf

<!-- SQLDOC:MERMAID:BEGIN -->
```mermaid
flowchart TD
    A[Parameter validieren] --> B[Temp-Tabellen zuruecksetzen und neu anlegen]
    B --> C[Demo-Orders in #SalesOrders laden]
    C --> D{IncludeSourceData = 1?}
    D -->|Ja| E[SourceData ausgeben]
    D -->|Nein| F[Direkt zur Gruppierung wechseln]
    E --> F
    F --> G[#GroupAggregate je SalesRegion und SalesChannel erzeugen]
    G --> H[GroupAggregateBaseline ausgeben]
    H --> I[minimum_revenue per HAVING SUM(OrderAmount) >= @MinRevenue einfuegen]
    I --> J[minimum_order_count per HAVING COUNT(*) >= @MinOrderCount einfuegen]
    J --> K[outlier_order_filter per HAVING MAX(OrderAmount) >= @OutlierOrderAmount einfuegen]
    K --> L[combined_thresholds mit allen drei Bedingungen einfuegen]
    L --> M[HavingPatternResults ausgeben]
    M --> N[HavingPatternGuide mit UseCase und Predicate ausgeben]
```
<!-- SQLDOC:MERMAID:END -->

## SQL-Code

<!-- SQLDOC:SQL_CODE:BEGIN -->
```sql
/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "HavingThresholdPatterns.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "10_GroupBy_Aggregate"

purpose: >
  Demonstriert typische HAVING-Muster fuer Mindestumsatz,
  Mindestanzahl von Bestellungen und gruppenbezogene Ausreisserfilter
  auf Basis einer kompakten Demo-Sales-Tabelle.

parameters:
  - name: "@MinRevenue"
    sql_type: "DECIMAL(12,2)"
    direction: "IN"
    required: true
    description: "Mindestumsatz, den eine Gruppe in einem HAVING-SUM-Filter erreichen muss"
  - name: "@MinOrderCount"
    sql_type: "INT"
    direction: "IN"
    required: true
    description: "Mindestanzahl an Orders pro Gruppe fuer COUNT-basierte HAVING-Filter"
  - name: "@OutlierOrderAmount"
    sql_type: "DECIMAL(12,2)"
    direction: "IN"
    required: true
    description: "Grenzwert fuer Gruppen, die mindestens eine auffaellig hohe Einzelorder enthalten"
  - name: "@IncludeSourceData"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 gibt die Demo-Quelldaten vor den Aggregationen aus"

result_sets:
  - name: "SourceData"
    description: "Optionale Vorschau auf die Demo-Orders je Region und Kanal"
  - name: "GroupAggregateBaseline"
    description: "Basiskennzahlen aller Gruppen vor jeder HAVING-Filterung"
  - name: "HavingPatternResults"
    description: "Ergebnis der drei typischen HAVING-Muster plus einer kombinierten Variante"
  - name: "HavingPatternGuide"
    description: "Kurze Einordnung, welcher HAVING-Typ welche fachliche Frage beantwortet"

dependencies:
  - "tempdb"
  - "GROUP BY"
  - "HAVING"
  - "SUM()"
  - "COUNT()"
  - "AVG()"
  - "MAX()"
  - "UNION ALL"
  - "DROP TABLE IF EXISTS"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/10_GroupBy_Aggregate/SQLScripts/HavingThresholdPatterns.md"
  sync_blocks:
    - "SUMMARY_TABLE"
    - "PARAMETERS_TABLE"
    - "DEPENDENCIES_LIST"
    - "VERSION_HISTORY_TABLE"
    - "SQL_CODE"
  mermaid:
    mode: "ai-agent-from-sql"
    source: "script-body"

main_responsible:
  name: "Erhard Rainer"
  initials: "ER"

version_history:
  - version: "1.0"
    date: "2026-04-18"
    user: "ER"
    description: "Erstversion fuer typische HAVING-Schwellenmuster in Gruppenauswertungen"

notes:
  - "Die Erstversion nutzt lokale Temp-Tabellen statt produktiver Faktentabellen."
  - "Die HAVING-Beispiele kontrastieren Umsatz-, Mengen- und Ausreisser-Schwellen auf derselben Gruppierung."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @MinRevenue DECIMAL(12,2) = 3000.00;
DECLARE @MinOrderCount INT = 3;
DECLARE @OutlierOrderAmount DECIMAL(12,2) = 1800.00;
DECLARE @IncludeSourceData BIT = 1;

IF @MinRevenue IS NULL OR @MinRevenue <= 0
BEGIN
    THROW 50040, '@MinRevenue muss groesser als 0 sein.', 1;
END;

IF @MinOrderCount IS NULL OR @MinOrderCount <= 0
BEGIN
    THROW 50041, '@MinOrderCount muss groesser als 0 sein.', 1;
END;

IF @OutlierOrderAmount IS NULL OR @OutlierOrderAmount <= 0
BEGIN
    THROW 50042, '@OutlierOrderAmount muss groesser als 0 sein.', 1;
END;

IF @IncludeSourceData NOT IN (0, 1)
BEGIN
    THROW 50043, '@IncludeSourceData muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #SalesOrders;
DROP TABLE IF EXISTS #GroupAggregate;
DROP TABLE IF EXISTS #HavingPatternResult;

CREATE TABLE #SalesOrders
(
    OrderID INT NOT NULL,
    SalesRegion VARCHAR(20) NOT NULL,
    SalesChannel VARCHAR(20) NOT NULL,
    AccountName VARCHAR(40) NOT NULL,
    OrderDate DATE NOT NULL,
    OrderAmount DECIMAL(12,2) NOT NULL
);

CREATE TABLE #HavingPatternResult
(
    PatternName VARCHAR(40) NOT NULL,
    SalesRegion VARCHAR(20) NOT NULL,
    SalesChannel VARCHAR(20) NOT NULL,
    OrderCount INT NOT NULL,
    TotalRevenue DECIMAL(12,2) NOT NULL,
    AverageOrderAmount DECIMAL(12,2) NOT NULL,
    MaxOrderAmount DECIMAL(12,2) NOT NULL,
    ThresholdNote VARCHAR(200) NOT NULL
);

INSERT INTO #SalesOrders
(
    OrderID,
    SalesRegion,
    SalesChannel,
    AccountName,
    OrderDate,
    OrderAmount
)
VALUES
    (4001, 'North', 'Online', 'Aster Retail', '2026-03-02',  720.00),
    (4002, 'North', 'Online', 'Aster Retail', '2026-03-08', 1180.00),
    (4003, 'North', 'Online', 'Blue Harbor',  '2026-03-14', 1640.00),
    (4004, 'North', 'Retail', 'City Health',  '2026-03-05',  680.00),
    (4005, 'North', 'Retail', 'City Health',  '2026-03-19',  910.00),
    (4006, 'South', 'Online', 'Delta Works',  '2026-03-01',  540.00),
    (4007, 'South', 'Online', 'Delta Works',  '2026-03-12',  690.00),
    (4008, 'South', 'Online', 'Eon Energy',   '2026-03-27', 2050.00),
    (4009, 'South', 'Retail', 'Eon Energy',   '2026-03-04',  430.00),
    (4010, 'South', 'Retail', 'Futura Labs',  '2026-03-11',  510.00),
    (4011, 'South', 'Retail', 'Futura Labs',  '2026-03-22',  560.00),
    (4012, 'West',  'Online', 'Green Foods',  '2026-03-03',  980.00),
    (4013, 'West',  'Online', 'Green Foods',  '2026-03-16', 1020.00),
    (4014, 'West',  'Online', 'Harbor Care',  '2026-03-28', 1110.00),
    (4015, 'West',  'Retail', 'Harbor Care',  '2026-03-09',  350.00),
    (4016, 'West',  'Retail', 'Iota Systems', '2026-03-18',  370.00),
    (4017, 'East',  'Online', 'Juno Trade',   '2026-03-07', 1450.00),
    (4018, 'East',  'Online', 'Juno Trade',   '2026-03-20', 1520.00),
    (4019, 'East',  'Retail', 'Kappa Med',    '2026-03-10',  610.00),
    (4020, 'East',  'Retail', 'Kappa Med',    '2026-03-24',  640.00);

IF @IncludeSourceData = 1
BEGIN
    SELECT
        so.OrderID,
        so.SalesRegion,
        so.SalesChannel,
        so.AccountName,
        so.OrderDate,
        so.OrderAmount
    FROM #SalesOrders AS so
    ORDER BY
        so.SalesRegion,
        so.SalesChannel,
        so.OrderDate,
        so.OrderID;
END;

SELECT
    so.SalesRegion,
    so.SalesChannel,
    COUNT(*) AS OrderCount,
    SUM(so.OrderAmount) AS TotalRevenue,
    CAST(AVG(so.OrderAmount) AS DECIMAL(12,2)) AS AverageOrderAmount,
    MAX(so.OrderAmount) AS MaxOrderAmount
INTO #GroupAggregate
FROM #SalesOrders AS so
GROUP BY
    so.SalesRegion,
    so.SalesChannel;

SELECT
    ga.SalesRegion,
    ga.SalesChannel,
    ga.OrderCount,
    ga.TotalRevenue,
    ga.AverageOrderAmount,
    ga.MaxOrderAmount
FROM #GroupAggregate AS ga
ORDER BY
    ga.TotalRevenue DESC,
    ga.SalesRegion,
    ga.SalesChannel;

INSERT INTO #HavingPatternResult
(
    PatternName,
    SalesRegion,
    SalesChannel,
    OrderCount,
    TotalRevenue,
    AverageOrderAmount,
    MaxOrderAmount,
    ThresholdNote
)
SELECT
    'minimum_revenue' AS PatternName,
    so.SalesRegion,
    so.SalesChannel,
    COUNT(*) AS OrderCount,
    SUM(so.OrderAmount) AS TotalRevenue,
    CAST(AVG(so.OrderAmount) AS DECIMAL(12,2)) AS AverageOrderAmount,
    MAX(so.OrderAmount) AS MaxOrderAmount,
    CONCAT('SUM(OrderAmount) >= ', CONVERT(VARCHAR(30), CAST(@MinRevenue AS DECIMAL(12,2)))) AS ThresholdNote
FROM #SalesOrders AS so
GROUP BY
    so.SalesRegion,
    so.SalesChannel
HAVING
    SUM(so.OrderAmount) >= @MinRevenue;

INSERT INTO #HavingPatternResult
(
    PatternName,
    SalesRegion,
    SalesChannel,
    OrderCount,
    TotalRevenue,
    AverageOrderAmount,
    MaxOrderAmount,
    ThresholdNote
)
SELECT
    'minimum_order_count' AS PatternName,
    so.SalesRegion,
    so.SalesChannel,
    COUNT(*) AS OrderCount,
    SUM(so.OrderAmount) AS TotalRevenue,
    CAST(AVG(so.OrderAmount) AS DECIMAL(12,2)) AS AverageOrderAmount,
    MAX(so.OrderAmount) AS MaxOrderAmount,
    CONCAT('COUNT(*) >= ', CONVERT(VARCHAR(20), @MinOrderCount)) AS ThresholdNote
FROM #SalesOrders AS so
GROUP BY
    so.SalesRegion,
    so.SalesChannel
HAVING
    COUNT(*) >= @MinOrderCount;

INSERT INTO #HavingPatternResult
(
    PatternName,
    SalesRegion,
    SalesChannel,
    OrderCount,
    TotalRevenue,
    AverageOrderAmount,
    MaxOrderAmount,
    ThresholdNote
)
SELECT
    'outlier_order_filter' AS PatternName,
    so.SalesRegion,
    so.SalesChannel,
    COUNT(*) AS OrderCount,
    SUM(so.OrderAmount) AS TotalRevenue,
    CAST(AVG(so.OrderAmount) AS DECIMAL(12,2)) AS AverageOrderAmount,
    MAX(so.OrderAmount) AS MaxOrderAmount,
    CONCAT('MAX(OrderAmount) >= ', CONVERT(VARCHAR(30), CAST(@OutlierOrderAmount AS DECIMAL(12,2)))) AS ThresholdNote
FROM #SalesOrders AS so
GROUP BY
    so.SalesRegion,
    so.SalesChannel
HAVING
    MAX(so.OrderAmount) >= @OutlierOrderAmount;

INSERT INTO #HavingPatternResult
(
    PatternName,
    SalesRegion,
    SalesChannel,
    OrderCount,
    TotalRevenue,
    AverageOrderAmount,
    MaxOrderAmount,
    ThresholdNote
)
SELECT
    'combined_thresholds' AS PatternName,
    so.SalesRegion,
    so.SalesChannel,
    COUNT(*) AS OrderCount,
    SUM(so.OrderAmount) AS TotalRevenue,
    CAST(AVG(so.OrderAmount) AS DECIMAL(12,2)) AS AverageOrderAmount,
    MAX(so.OrderAmount) AS MaxOrderAmount,
    CONCAT(
        'SUM >= ', CONVERT(VARCHAR(30), CAST(@MinRevenue AS DECIMAL(12,2))),
        '; COUNT >= ', CONVERT(VARCHAR(20), @MinOrderCount),
        '; MAX >= ', CONVERT(VARCHAR(30), CAST(@OutlierOrderAmount AS DECIMAL(12,2)))
    ) AS ThresholdNote
FROM #SalesOrders AS so
GROUP BY
    so.SalesRegion,
    so.SalesChannel
HAVING
    SUM(so.OrderAmount) >= @MinRevenue
    AND COUNT(*) >= @MinOrderCount
    AND MAX(so.OrderAmount) >= @OutlierOrderAmount;

SELECT
    hpr.PatternName,
    hpr.SalesRegion,
    hpr.SalesChannel,
    hpr.OrderCount,
    hpr.TotalRevenue,
    hpr.AverageOrderAmount,
    hpr.MaxOrderAmount,
    hpr.ThresholdNote
FROM #HavingPatternResult AS hpr
ORDER BY
    hpr.PatternName,
    hpr.TotalRevenue DESC,
    hpr.SalesRegion,
    hpr.SalesChannel;

SELECT
    'minimum_revenue' AS PatternName,
    'Hebt Gruppen hervor, deren Gesamtumsatz einen Zielwert erreicht oder uebertrifft.' AS UseCase,
    'SUM(OrderAmount) >= @MinRevenue' AS HavingPredicate
UNION ALL
SELECT
    'minimum_order_count' AS PatternName,
    'Filtert Gruppen mit ausreichend vielen Einzelvorgaengen fuer belastbare Auswertungen.' AS UseCase,
    'COUNT(*) >= @MinOrderCount' AS HavingPredicate
UNION ALL
SELECT
    'outlier_order_filter' AS PatternName,
    'Markiert Gruppen, in denen mindestens eine aussergewoehnlich hohe Einzelorder vorkommt.' AS UseCase,
    'MAX(OrderAmount) >= @OutlierOrderAmount' AS HavingPredicate
UNION ALL
SELECT
    'combined_thresholds' AS PatternName,
    'Kombiniert Mindestumsatz, Mindestanzahl und Ausreisserkriterium fuer engere Review-Listen.' AS UseCase,
    'SUM(...) AND COUNT(*) AND MAX(...)' AS HavingPredicate;
```
<!-- SQLDOC:SQL_CODE:END -->
