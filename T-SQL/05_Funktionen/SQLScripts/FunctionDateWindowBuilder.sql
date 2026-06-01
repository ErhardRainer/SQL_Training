/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "FunctionDateWindowBuilder.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "05_Funktionen"

purpose: >
  Baut aus einer Anchor-Date mehrere typische Reporting-Zeitfenster wie
  letzte 7 Tage, aktueller Monat, Vormonat und aktuelles Quartal auf und
  zeigt, welche Demo-Ereignisse in diese Fenster fallen.

parameters:
  - name: "@AnchorDate"
    sql_type: "DATE"
    direction: "IN"
    required: false
    description: "Stichtag, relativ zu dem die Reporting-Fenster aufgebaut werden"
  - name: "@WindowPreset"
    sql_type: "VARCHAR(20)"
    direction: "IN"
    required: false
    description: "Waehlt last7d, rolling30d, current_month, prior_month, current_quarter oder all"
  - name: "@IncludeComparisonWindow"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 fuegt ein direkt davor liegendes Vergleichsfenster fuer das aktive Zeitfenster hinzu"

result_sets:
  - name: "WindowCatalog"
    description: "Listet die aufgebauten Fenster mit Grenzen, Dauer und Vergleichsbezug"
  - name: "WindowMetrics"
    description: "Verdichtet Demo-Ereignisse je Fenster und markiert Fenster ohne Treffer"
  - name: "WindowGuidance"
    description: "Erlaeutert den didaktischen Nutzen der aktiven Fensterwahl fuer Reporting-Szenarien"

dependencies:
  - "tempdb temporary tables"
  - "DATEADD"
  - "DATEDIFF"
  - "DATEFROMPARTS"
  - "EOMONTH"
  - "DATEPART"
  - "DATENAME"
  - "CTE"
  - "CASE"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/05_Funktionen/SQLScripts/FunctionDateWindowBuilder.md"
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
    date: "2026-04-19"
    user: "ER"
    description: "Erstversion fuer didaktische Reporting-Zeitfenster mit Datumsfunktionen"

notes:
  - "Das Skript arbeitet ausschliesslich mit Demo-Ereignissen in einer temporaeren Tabelle."
  - "Vergleichsfenster werden direkt vor dem aktiven Hauptfenster positioniert, um Reporting-Deltas leichter zu erklaeren."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @AnchorDate DATE = '2026-04-15';
DECLARE @WindowPreset VARCHAR(20) = 'all';
DECLARE @IncludeComparisonWindow BIT = 1;

IF @WindowPreset NOT IN ('last7d', 'rolling30d', 'current_month', 'prior_month', 'current_quarter', 'all')
BEGIN
    THROW 50860, '@WindowPreset muss last7d, rolling30d, current_month, prior_month, current_quarter oder all sein.', 1;
END;

IF @IncludeComparisonWindow NOT IN (0, 1)
BEGIN
    THROW 50861, '@IncludeComparisonWindow muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #ReportSignals;

CREATE TABLE #ReportSignals
(
    SignalId INT NOT NULL PRIMARY KEY,
    SignalDate DATE NOT NULL,
    RegionCode CHAR(2) NOT NULL,
    RevenueAmount DECIMAL(12, 2) NOT NULL,
    TicketCount INT NOT NULL,
    ScenarioLabel VARCHAR(40) NOT NULL
);

INSERT INTO #ReportSignals
(
    SignalId,
    SignalDate,
    RegionCode,
    RevenueAmount,
    TicketCount,
    ScenarioLabel
)
VALUES
    (1,  '2026-01-07', 'DE',  820.00,  5, 'quarter-open'),
    (2,  '2026-01-16', 'AT',  910.00,  6, 'mid-month'),
    (3,  '2026-01-29', 'CH', 1035.00,  7, 'month-close'),
    (4,  '2026-02-03', 'DE', 1175.00,  8, 'month-open'),
    (5,  '2026-02-11', 'AT', 1320.00,  9, 'campaign-run'),
    (6,  '2026-02-24', 'CH',  980.00,  5, 'support-spike'),
    (7,  '2026-03-02', 'DE', 1450.00, 10, 'quarter-ramp'),
    (8,  '2026-03-14', 'AT', 1510.00, 11, 'mid-quarter'),
    (9,  '2026-03-28', 'CH', 1675.00, 12, 'month-close'),
    (10, '2026-04-01', 'DE', 1720.00, 12, 'new-month'),
    (11, '2026-04-05', 'AT', 1655.00, 10, 'weekend-promo'),
    (12, '2026-04-09', 'CH', 1815.00, 13, 'renewal-wave'),
    (13, '2026-04-12', 'DE', 1940.00, 14, 'peak-window'),
    (14, '2026-04-15', 'AT', 1885.00, 11, 'anchor-day'),
    (15, '2026-04-18', 'CH', 1765.00,  9, 'post-anchor'),
    (16, '2026-04-27', 'DE', 2050.00, 15, 'month-finish');

;WITH BaseWindows AS
(
    SELECT
        CAST('last7d' AS VARCHAR(20)) AS WindowCode,
        CAST('Letzte 7 Tage' AS VARCHAR(40)) AS WindowLabel,
        DATEADD(DAY, -6, @AnchorDate) AS WindowStartDate,
        @AnchorDate AS WindowEndDate,
        CAST('rolling-window' AS VARCHAR(30)) AS WindowFamily

    UNION ALL

    SELECT
        CAST('rolling30d' AS VARCHAR(20)) AS WindowCode,
        CAST('Rolling 30 Tage' AS VARCHAR(40)) AS WindowLabel,
        DATEADD(DAY, -29, @AnchorDate) AS WindowStartDate,
        @AnchorDate AS WindowEndDate,
        CAST('rolling-window' AS VARCHAR(30)) AS WindowFamily

    UNION ALL

    SELECT
        CAST('current_month' AS VARCHAR(20)) AS WindowCode,
        CAST('Aktueller Monat' AS VARCHAR(40)) AS WindowLabel,
        DATEFROMPARTS(YEAR(@AnchorDate), MONTH(@AnchorDate), 1) AS WindowStartDate,
        EOMONTH(@AnchorDate) AS WindowEndDate,
        CAST('calendar-window' AS VARCHAR(30)) AS WindowFamily

    UNION ALL

    SELECT
        CAST('prior_month' AS VARCHAR(20)) AS WindowCode,
        CAST('Vormonat' AS VARCHAR(40)) AS WindowLabel,
        DATEFROMPARTS(YEAR(DATEADD(MONTH, -1, @AnchorDate)), MONTH(DATEADD(MONTH, -1, @AnchorDate)), 1) AS WindowStartDate,
        EOMONTH(DATEADD(MONTH, -1, @AnchorDate)) AS WindowEndDate,
        CAST('calendar-window' AS VARCHAR(30)) AS WindowFamily

    UNION ALL

    SELECT
        CAST('current_quarter' AS VARCHAR(20)) AS WindowCode,
        CAST('Aktuelles Quartal' AS VARCHAR(40)) AS WindowLabel,
        DATEFROMPARTS(YEAR(@AnchorDate), ((DATEPART(QUARTER, @AnchorDate) - 1) * 3) + 1, 1) AS WindowStartDate,
        DATEADD(
            DAY,
            -1,
            DATEADD(
                QUARTER,
                1,
                DATEFROMPARTS(YEAR(@AnchorDate), ((DATEPART(QUARTER, @AnchorDate) - 1) * 3) + 1, 1)
            )
        ) AS WindowEndDate,
        CAST('calendar-window' AS VARCHAR(30)) AS WindowFamily
),
FilteredWindows AS
(
    SELECT
        bw.WindowCode,
        bw.WindowLabel,
        bw.WindowStartDate,
        bw.WindowEndDate,
        bw.WindowFamily
    FROM BaseWindows AS bw
    WHERE @WindowPreset = 'all'
       OR bw.WindowCode = @WindowPreset
),
WindowCatalog AS
(
    SELECT
        fw.WindowCode,
        fw.WindowLabel,
        fw.WindowFamily,
        CAST('primary' AS VARCHAR(20)) AS WindowRole,
        fw.WindowStartDate,
        fw.WindowEndDate,
        DATEDIFF(DAY, fw.WindowStartDate, fw.WindowEndDate) + 1 AS WindowDays
    FROM FilteredWindows AS fw

    UNION ALL

    SELECT
        fw.WindowCode,
        CONCAT(fw.WindowLabel, ' Vergleich') AS WindowLabel,
        fw.WindowFamily,
        CAST('comparison' AS VARCHAR(20)) AS WindowRole,
        DATEADD(DAY, -1 * (DATEDIFF(DAY, fw.WindowStartDate, fw.WindowEndDate) + 1), fw.WindowStartDate) AS WindowStartDate,
        DATEADD(DAY, -1, fw.WindowStartDate) AS WindowEndDate,
        DATEDIFF(DAY, fw.WindowStartDate, fw.WindowEndDate) + 1 AS WindowDays
    FROM FilteredWindows AS fw
    WHERE @IncludeComparisonWindow = 1
),
WindowMetrics AS
(
    SELECT
        wc.WindowCode,
        wc.WindowLabel,
        wc.WindowFamily,
        wc.WindowRole,
        wc.WindowStartDate,
        wc.WindowEndDate,
        wc.WindowDays,
        COUNT(rs.SignalId) AS SignalCount,
        SUM(ISNULL(rs.RevenueAmount, 0.00)) AS TotalRevenue,
        SUM(ISNULL(rs.TicketCount, 0)) AS TotalTickets,
        COUNT(DISTINCT rs.RegionCode) AS ActiveRegions,
        MIN(rs.SignalDate) AS FirstSignalDate,
        MAX(rs.SignalDate) AS LastSignalDate
    FROM WindowCatalog AS wc
    LEFT JOIN #ReportSignals AS rs
        ON rs.SignalDate >= wc.WindowStartDate
       AND rs.SignalDate <= wc.WindowEndDate
    GROUP BY
        wc.WindowCode,
        wc.WindowLabel,
        wc.WindowFamily,
        wc.WindowRole,
        wc.WindowStartDate,
        wc.WindowEndDate,
        wc.WindowDays
)
SELECT
    wc.WindowCode,
    wc.WindowLabel,
    wc.WindowRole,
    wc.WindowFamily,
    wc.WindowStartDate,
    wc.WindowEndDate,
    wc.WindowDays,
    CONVERT(VARCHAR(10), wc.WindowStartDate, 23) AS WindowStartIso,
    CONVERT(VARCHAR(10), wc.WindowEndDate, 23) AS WindowEndIso,
    CONCAT(
        DATENAME(MONTH, wc.WindowStartDate),
        ' ',
        DATEPART(DAY, wc.WindowStartDate),
        ' bis ',
        DATENAME(MONTH, wc.WindowEndDate),
        ' ',
        DATEPART(DAY, wc.WindowEndDate)
    ) AS TeachingLabel
FROM WindowCatalog AS wc
ORDER BY
    wc.WindowCode,
    CASE wc.WindowRole
        WHEN 'primary' THEN 1
        ELSE 2
    END;

SELECT
    wm.WindowCode,
    wm.WindowLabel,
    wm.WindowRole,
    wm.WindowFamily,
    wm.WindowStartDate,
    wm.WindowEndDate,
    wm.WindowDays,
    wm.SignalCount,
    wm.TotalRevenue,
    wm.TotalTickets,
    wm.ActiveRegions,
    wm.FirstSignalDate,
    wm.LastSignalDate,
    CASE
        WHEN wm.SignalCount = 0 THEN 'empty-window'
        WHEN wm.WindowRole = 'comparison' THEN 'comparison-window'
        WHEN wm.WindowFamily = 'rolling-window' THEN 'rolling-window'
        ELSE 'calendar-window'
    END AS WindowTeachingType
FROM WindowMetrics AS wm
ORDER BY
    wm.WindowCode,
    CASE wm.WindowRole
        WHEN 'primary' THEN 1
        ELSE 2
    END;

SELECT
    @AnchorDate AS AnchorDate,
    @WindowPreset AS RequestedPreset,
    @IncludeComparisonWindow AS IncludeComparisonWindow,
    CASE
        WHEN @WindowPreset = 'last7d' THEN 'Kurzfristiges Monitoring fuer die letzten sieben Tage rund um den Stichtag.'
        WHEN @WindowPreset = 'rolling30d' THEN 'Gleitendes Fenster fuer kompakte Trendbeobachtung ueber dreissig Tage.'
        WHEN @WindowPreset = 'current_month' THEN 'Kalenderfenster fuer Monatsreports mit offenem oder geschlossenem Monat.'
        WHEN @WindowPreset = 'prior_month' THEN 'Abgeschlossenes Monatsfenster fuer Rueckblicke oder Soll-Ist-Vergleiche.'
        WHEN @WindowPreset = 'current_quarter' THEN 'Quartalssicht fuer Management- oder Forecast-Reports.'
        ELSE 'Vergleicht mehrere typische Reporting-Fenster auf derselben Anchor-Date.'
    END AS TeachingFocus,
    CASE
        WHEN @IncludeComparisonWindow = 1 THEN 'Zusatzfenster direkt vor dem Hauptfenster ermoeglichen periodische Delta-Vergleiche.'
        ELSE 'Nur das Hauptfenster wird gezeigt, damit die Grundlogik der Datumsfunktionen isoliert sichtbar bleibt.'
    END AS ComparisonNote;
