/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "GapsAndIslandsStarter.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "11_WindowFunctions"

purpose: >
  Einstiegsskript fuer Gaps-and-Islands-Muster in T-SQL. Das Skript
  zeigt, wie zusammenhaengende Aktivitaetsinseln mit ROW_NUMBER() und
  einer Differenzlogik erkannt, gruppiert und pro Insel ausgewertet
  werden koennen.

parameters:
  - name: "@GapThresholdDays"
    sql_type: "INT"
    direction: "IN"
    required: true
    description: "Maximal erlaubte Tagesdifferenz innerhalb derselben Aktivitaetsinsel"
  - name: "@ShowSourceData"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = die sortierten Demo-Daten vor der Inselbildung zusaetzlich anzeigen"

result_sets:
  - name: "SourcePreview"
    description: "Optionale Vorschau auf die Demo-Aktivitaeten je Kunde und Datum"
  - name: "ActivityWithGapAnalysis"
    description: "Zeigt je Aktivitaet die Vorzeile, die Luecke und die markierten Inselstarts"
  - name: "IslandAssignment"
    description: "Ordnet jede Aktivitaet einer fortlaufenden Inselnummer je Kunde zu"
  - name: "IslandSummary"
    description: "Verdichtete Sicht mit Start, Ende, Dauer und Anzahl der Tage je Insel"
  - name: "LongestIslandPerCustomer"
    description: "Laengste erkannte Aktivitaetsinsel je Kunde"

dependencies:
  - "tempdb temporary tables"
  - "ROW_NUMBER()"
  - "LAG()"
  - "SUM() OVER(PARTITION BY ... ORDER BY ...)"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/11_WindowFunctions/SQLScripts/GapsAndIslandsStarter.md"
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
    description: "Erstversion des didaktischen Gaps-and-Islands-Labs fuer Kapitel Window Functions"

notes:
  - "Die Demo modelliert Kundenaktivitaeten als einzelne Datumspunkte ohne produktive Quelltabellen"
  - "Eine neue Insel beginnt, wenn die Distanz zum vorherigen Datum groesser als @GapThresholdDays ist"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @GapThresholdDays INT = 1;
DECLARE @ShowSourceData   BIT = 1;

IF @GapThresholdDays IS NULL OR @GapThresholdDays < 0
BEGIN
    THROW 50000, '@GapThresholdDays muss groesser oder gleich 0 sein.', 1;
END;

IF @ShowSourceData NOT IN (0, 1)
BEGIN
    THROW 50000, '@ShowSourceData muss als BIT-Wert 0 oder 1 gesetzt sein.', 1;
END;

DROP TABLE IF EXISTS #ActivityLog;
DROP TABLE IF EXISTS #ActivityWithLag;
DROP TABLE IF EXISTS #IslandAssignment;
DROP TABLE IF EXISTS #IslandSummary;

CREATE TABLE #ActivityLog
(
    CustomerCode  VARCHAR(20)  NOT NULL,
    ActivityDate  DATE         NOT NULL,
    ActivityLabel VARCHAR(40)  NOT NULL
);

INSERT INTO #ActivityLog
(
    CustomerCode,
    ActivityDate,
    ActivityLabel
)
VALUES
    ('CUST-100', '2026-01-03', 'PortalLogin'),
    ('CUST-100', '2026-01-04', 'PortalLogin'),
    ('CUST-100', '2026-01-05', 'OrderPlaced'),
    ('CUST-100', '2026-01-09', 'PortalLogin'),
    ('CUST-100', '2026-01-10', 'SupportTicket'),
    ('CUST-100', '2026-01-15', 'OrderPlaced'),
    ('CUST-200', '2026-02-01', 'PortalLogin'),
    ('CUST-200', '2026-02-02', 'PortalLogin'),
    ('CUST-200', '2026-02-06', 'OrderPlaced'),
    ('CUST-200', '2026-02-07', 'PortalLogin'),
    ('CUST-200', '2026-02-12', 'RenewalCheck'),
    ('CUST-300', '2026-03-11', 'PortalLogin'),
    ('CUST-300', '2026-03-14', 'PortalLogin'),
    ('CUST-300', '2026-03-15', 'OrderPlaced'),
    ('CUST-300', '2026-03-16', 'OrderPlaced'),
    ('CUST-300', '2026-03-25', 'SupportTicket');

IF @ShowSourceData = 1
BEGIN
    SELECT
        al.CustomerCode,
        al.ActivityDate,
        al.ActivityLabel
    FROM #ActivityLog AS al
    ORDER BY
        al.CustomerCode,
        al.ActivityDate,
        al.ActivityLabel;
END;

-- 1. Vorherige Aktivitaet je Kunde referenzieren und die Lueckengroesse bestimmen.
SELECT
    al.CustomerCode,
    al.ActivityDate,
    al.ActivityLabel,
    ROW_NUMBER() OVER
    (
        PARTITION BY al.CustomerCode
        ORDER BY al.ActivityDate, al.ActivityLabel
    ) AS ActivityRowNumber,
    LAG(al.ActivityDate) OVER
    (
        PARTITION BY al.CustomerCode
        ORDER BY al.ActivityDate, al.ActivityLabel
    ) AS PreviousActivityDate,
    DATEDIFF
    (
        DAY,
        LAG(al.ActivityDate) OVER
        (
            PARTITION BY al.CustomerCode
            ORDER BY al.ActivityDate, al.ActivityLabel
        ),
        al.ActivityDate
    ) AS GapFromPreviousDays,
    CASE
        WHEN LAG(al.ActivityDate) OVER
             (
                 PARTITION BY al.CustomerCode
                 ORDER BY al.ActivityDate, al.ActivityLabel
             ) IS NULL
            THEN 1
        WHEN DATEDIFF
             (
                 DAY,
                 LAG(al.ActivityDate) OVER
                 (
                     PARTITION BY al.CustomerCode
                     ORDER BY al.ActivityDate, al.ActivityLabel
                 ),
                 al.ActivityDate
             ) > @GapThresholdDays
            THEN 1
        ELSE 0
    END AS StartsNewIsland
INTO #ActivityWithLag
FROM #ActivityLog AS al;

SELECT
    awl.CustomerCode,
    awl.ActivityDate,
    awl.ActivityLabel,
    awl.ActivityRowNumber,
    awl.PreviousActivityDate,
    awl.GapFromPreviousDays,
    awl.StartsNewIsland
FROM #ActivityWithLag AS awl
ORDER BY
    awl.CustomerCode,
    awl.ActivityRowNumber;

-- 2. Fortlaufende Inselnummer je Kunde ueber kumulierte Startmarker bilden.
SELECT
    awl.CustomerCode,
    awl.ActivityDate,
    awl.ActivityLabel,
    awl.ActivityRowNumber,
    awl.PreviousActivityDate,
    awl.GapFromPreviousDays,
    awl.StartsNewIsland,
    SUM(awl.StartsNewIsland) OVER
    (
        PARTITION BY awl.CustomerCode
        ORDER BY awl.ActivityDate, awl.ActivityLabel
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS IslandNumber,
    DATEDIFF
    (
        DAY,
        CONVERT(date, '20000101'),
        awl.ActivityDate
    ) - ROW_NUMBER() OVER
    (
        PARTITION BY awl.CustomerCode
        ORDER BY awl.ActivityDate, awl.ActivityLabel
    ) AS ClassicGapKey
INTO #IslandAssignment
FROM #ActivityWithLag AS awl;

SELECT
    ia.CustomerCode,
    ia.ActivityDate,
    ia.ActivityLabel,
    ia.ActivityRowNumber,
    ia.PreviousActivityDate,
    ia.GapFromPreviousDays,
    ia.StartsNewIsland,
    ia.IslandNumber,
    ia.ClassicGapKey
FROM #IslandAssignment AS ia
ORDER BY
    ia.CustomerCode,
    ia.ActivityRowNumber;

-- 3. Pro Insel Beginn, Ende und Dichte zusammenfassen.
SELECT
    ia.CustomerCode,
    ia.IslandNumber,
    MIN(ia.ActivityDate) AS IslandStartDate,
    MAX(ia.ActivityDate) AS IslandEndDate,
    COUNT(*) AS ActivityDaysInIsland,
    DATEDIFF(DAY, MIN(ia.ActivityDate), MAX(ia.ActivityDate)) + 1 AS CalendarSpanDays,
    STRING_AGG(ia.ActivityLabel, ' -> ') WITHIN GROUP (ORDER BY ia.ActivityDate, ia.ActivityLabel) AS ActivityPath
INTO #IslandSummary
FROM #IslandAssignment AS ia
GROUP BY
    ia.CustomerCode,
    ia.IslandNumber;

SELECT
    s.CustomerCode,
    s.IslandNumber,
    s.IslandStartDate,
    s.IslandEndDate,
    s.ActivityDaysInIsland,
    s.CalendarSpanDays,
    s.ActivityPath
FROM #IslandSummary AS s
ORDER BY
    s.CustomerCode,
    s.IslandNumber;

-- 4. Laengste Insel je Kunde hervorheben.
WITH RankedIslands AS
(
    SELECT
        s.CustomerCode,
        s.IslandNumber,
        s.IslandStartDate,
        s.IslandEndDate,
        s.ActivityDaysInIsland,
        s.CalendarSpanDays,
        s.ActivityPath,
        ROW_NUMBER() OVER
        (
            PARTITION BY s.CustomerCode
            ORDER BY
                s.ActivityDaysInIsland DESC,
                s.CalendarSpanDays DESC,
                s.IslandStartDate ASC
        ) AS IslandRank
    FROM #IslandSummary AS s
)
SELECT
    ri.CustomerCode,
    ri.IslandNumber,
    ri.IslandStartDate,
    ri.IslandEndDate,
    ri.ActivityDaysInIsland,
    ri.CalendarSpanDays,
    ri.ActivityPath
FROM RankedIslands AS ri
WHERE ri.IslandRank = 1
ORDER BY
    ri.CustomerCode;
