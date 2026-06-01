/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "SetChangeWindowCompare.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "09_Set_Operations"

purpose: >
  Vergleicht die Menge aktiver Customer-Product-Kombinationen zwischen
  zwei Zeitfenstern und zeigt Zugaenge, Abgaenge sowie stabile
  Schnittmengen mit EXCEPT und INTERSECT.

parameters:
  - name: "@WindowAStart"
    sql_type: "DATETIME2(0)"
    direction: "IN"
    required: false
    description: "Start des ersten Vergleichsfensters"
  - name: "@WindowAEnd"
    sql_type: "DATETIME2(0)"
    direction: "IN"
    required: false
    description: "Ende des ersten Vergleichsfensters"
  - name: "@WindowBStart"
    sql_type: "DATETIME2(0)"
    direction: "IN"
    required: false
    description: "Start des zweiten Vergleichsfensters"
  - name: "@WindowBEnd"
    sql_type: "DATETIME2(0)"
    direction: "IN"
    required: false
    description: "Ende des zweiten Vergleichsfensters"
  - name: "@IncludeStableOverlap"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = gibt die in beiden Zeitfenstern vorhandenen Kombinationen zusaetzlich aus"

result_sets:
  - name: "WindowComparisonSummary"
    description: "Zaehlt Kombinationen je Zeitfenster und je Veraenderungskategorie"
  - name: "OnlyInWindowA"
    description: "Kombinationen, die nur im ersten Zeitfenster vorkommen"
  - name: "OnlyInWindowB"
    description: "Kombinationen, die nur im zweiten Zeitfenster vorkommen"
  - name: "InBothWindows"
    description: "Optionale Schnittmenge stabiler Kombinationen"

dependencies:
  - "tempdb"
  - "EXCEPT"
  - "INTERSECT"
  - "DROP TABLE IF EXISTS"
  - "SYSUTCDATETIME()"
  - "CASE"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/09_Set_Operations/SQLScripts/SetChangeWindowCompare.md"
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
    description: "Erstversion eines didaktischen Zeitfenstervergleichs fuer Set-Operationen"

notes:
  - "Die Demo arbeitet mit lokalen Temp-Tabellen und einer bewusst kleinen Bewegungsdatenbasis"
  - "Verglichen werden Customer-Product-Kombinationen, nicht Einzeltransaktionen"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @WindowAStart DATETIME2(0) = '2026-01-01 00:00:00';
DECLARE @WindowAEnd DATETIME2(0) = '2026-01-31 23:59:59';
DECLARE @WindowBStart DATETIME2(0) = '2026-02-01 00:00:00';
DECLARE @WindowBEnd DATETIME2(0) = '2026-02-28 23:59:59';
DECLARE @IncludeStableOverlap BIT = 1;

IF @WindowAStart IS NULL OR @WindowAEnd IS NULL OR @WindowBStart IS NULL OR @WindowBEnd IS NULL
BEGIN
    THROW 50010, 'Alle Zeitfensterparameter muessen gesetzt sein.', 1;
END;

IF @WindowAStart > @WindowAEnd
BEGIN
    THROW 50011, 'Das erste Zeitfenster ist ungueltig: Start liegt nach Ende.', 1;
END;

IF @WindowBStart > @WindowBEnd
BEGIN
    THROW 50012, 'Das zweite Zeitfenster ist ungueltig: Start liegt nach Ende.', 1;
END;

IF @IncludeStableOverlap NOT IN (0, 1)
BEGIN
    THROW 50013, '@IncludeStableOverlap muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #EnrollmentHistory;
DROP TABLE IF EXISTS #WindowASet;
DROP TABLE IF EXISTS #WindowBSet;

CREATE TABLE #EnrollmentHistory
(
    CustomerCode    NVARCHAR(20)    NOT NULL,
    ProductCode     NVARCHAR(20)    NOT NULL,
    ValidFrom       DATETIME2(0)    NOT NULL,
    ValidTo         DATETIME2(0)    NULL,
    SourceLabel     NVARCHAR(30)    NOT NULL
);

INSERT INTO #EnrollmentHistory
(
    CustomerCode,
    ProductCode,
    ValidFrom,
    ValidTo,
    SourceLabel
)
VALUES
    (N'C-100', N'P-ALPHA', '2025-12-20 00:00:00', '2026-02-10 00:00:00', N'InitialLoad'),
    (N'C-100', N'P-BETA',  '2026-01-10 00:00:00', NULL,                  N'CrossSell'),
    (N'C-101', N'P-ALPHA', '2025-11-15 00:00:00', NULL,                  N'InitialLoad'),
    (N'C-102', N'P-GAMMA', '2026-01-05 00:00:00', '2026-01-26 18:00:00', N'CampaignA'),
    (N'C-103', N'P-DELTA', '2026-02-03 09:00:00', NULL,                  N'CampaignB'),
    (N'C-104', N'P-BETA',  '2026-01-18 00:00:00', '2026-02-21 08:00:00', N'PartnerFeed'),
    (N'C-105', N'P-EPS',   '2026-02-11 00:00:00', NULL,                  N'PartnerFeed'),
    (N'C-106', N'P-GAMMA', '2025-12-28 00:00:00', NULL,                  N'InitialLoad'),
    (N'C-106', N'P-GAMMA', '2026-02-14 00:00:00', NULL,                  N'DuplicateSourceDemo');

SELECT DISTINCT
    eh.CustomerCode,
    eh.ProductCode
INTO #WindowASet
FROM #EnrollmentHistory AS eh
WHERE eh.ValidFrom <= @WindowAEnd
  AND COALESCE(eh.ValidTo, '9999-12-31 23:59:59') >= @WindowAStart;

SELECT DISTINCT
    eh.CustomerCode,
    eh.ProductCode
INTO #WindowBSet
FROM #EnrollmentHistory AS eh
WHERE eh.ValidFrom <= @WindowBEnd
  AND COALESCE(eh.ValidTo, '9999-12-31 23:59:59') >= @WindowBStart;

WITH OnlyInWindowA AS
(
    SELECT
        wa.CustomerCode,
        wa.ProductCode
    FROM #WindowASet AS wa

    EXCEPT

    SELECT
        wb.CustomerCode,
        wb.ProductCode
    FROM #WindowBSet AS wb
),
OnlyInWindowB AS
(
    SELECT
        wb.CustomerCode,
        wb.ProductCode
    FROM #WindowBSet AS wb

    EXCEPT

    SELECT
        wa.CustomerCode,
        wa.ProductCode
    FROM #WindowASet AS wa
),
InBothWindows AS
(
    SELECT
        wa.CustomerCode,
        wa.ProductCode
    FROM #WindowASet AS wa

    INTERSECT

    SELECT
        wb.CustomerCode,
        wb.ProductCode
    FROM #WindowBSet AS wb
)
SELECT
    Metric,
    MetricValue,
    WindowAStart = @WindowAStart,
    WindowAEnd = @WindowAEnd,
    WindowBStart = @WindowBStart,
    WindowBEnd = @WindowBEnd,
    GeneratedAtUtc = SYSUTCDATETIME()
FROM
(
    SELECT N'WindowA distinct combinations' AS Metric, COUNT(*) AS MetricValue FROM #WindowASet
    UNION ALL
    SELECT N'WindowB distinct combinations', COUNT(*) FROM #WindowBSet
    UNION ALL
    SELECT N'Only in WindowA', COUNT(*) FROM OnlyInWindowA
    UNION ALL
    SELECT N'Only in WindowB', COUNT(*) FROM OnlyInWindowB
    UNION ALL
    SELECT N'In both windows', COUNT(*) FROM InBothWindows
) AS summary_data
ORDER BY Metric;

WITH OnlyInWindowA AS
(
    SELECT
        wa.CustomerCode,
        wa.ProductCode
    FROM #WindowASet AS wa

    EXCEPT

    SELECT
        wb.CustomerCode,
        wb.ProductCode
    FROM #WindowBSet AS wb
)
SELECT
    ChangeClass = N'RemovedBeforeWindowB',
    owa.CustomerCode,
    owa.ProductCode
FROM OnlyInWindowA AS owa
ORDER BY
    owa.CustomerCode,
    owa.ProductCode;

WITH OnlyInWindowB AS
(
    SELECT
        wb.CustomerCode,
        wb.ProductCode
    FROM #WindowBSet AS wb

    EXCEPT

    SELECT
        wa.CustomerCode,
        wa.ProductCode
    FROM #WindowASet AS wa
)
SELECT
    ChangeClass = N'AddedByWindowB',
    owb.CustomerCode,
    owb.ProductCode
FROM OnlyInWindowB AS owb
ORDER BY
    owb.CustomerCode,
    owb.ProductCode;

IF @IncludeStableOverlap = 1
BEGIN
    WITH InBothWindows AS
    (
        SELECT
            wa.CustomerCode,
            wa.ProductCode
        FROM #WindowASet AS wa

        INTERSECT

        SELECT
            wb.CustomerCode,
            wb.ProductCode
        FROM #WindowBSet AS wb
    )
    SELECT
        ChangeClass = N'StableAcrossWindows',
        ibw.CustomerCode,
        ibw.ProductCode
    FROM InBothWindows AS ibw
    ORDER BY
        ibw.CustomerCode,
        ibw.ProductCode;
END;
