/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "PivotMeasureNameNormalizer.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "14_Pivot_Unpivot"

purpose: >
  Normalisiert uneinheitliche Kennzahlennamen aus einer Demo-Quelle fuer
  spaetere Pivot-Layouts. Das Skript vereinheitlicht Schreibweisen, markiert
  nicht freigegebene oder unklare Rohwerte und erzeugt eine pivot-taugliche
  Quellmenge mit stabilen Spaltennamen.

parameters:
  - name: "@ReportMonth"
    sql_type: "char(7)"
    direction: "IN"
    required: false
    description: "Filtert die Demo-Quelle auf einen Berichtsmonat im Format YYYY-MM."
  - name: "@AllowFallbackAlias"
    sql_type: "bit"
    direction: "IN"
    required: false
    description: "Erlaubt fuer nicht gemappte Rohwerte einen technischen Fallback-Alias, wenn der Wert 1 ist."

result_sets:
  - name: "RawMeasurePreview"
    description: "Zeigt die Demo-Quelle mit uneinheitlichen Kennzahlennamen vor der Normalisierung."
  - name: "NormalizationRules"
    description: "Dokumentiert die Regelbasis fuer kanonische Kennzahlnamen und Pivot-Spalten."
  - name: "NormalizedMeasureReview"
    description: "Zeigt pro Rohwert den Match-Status, den kanonischen Namen und den Pivot-Alias."
  - name: "PivotReadyColumnList"
    description: "Listet die freigegebenen Pivot-Spalten und eine zusammengesetzte IN-Liste fuer spaetere Pivot-Statements."
  - name: "PivotReadySource"
    description: "Gibt die fuer ein Pivot bereinigte Quellmenge mit stabilen MeasureName-Werten aus."

dependencies:
  - "CTEs"
  - "STRING_AGG"
  - "QUOTENAME"
  - "temporary tables"
  - "THROW"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/14_Pivot_Unpivot/SQLScripts/PivotMeasureNameNormalizer.md"
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
    description: "Erstversion eines didaktischen Normalisierers fuer Pivot-Kennzahlennamen."

notes:
  - "Die Erstversion arbeitet ausschliesslich mit temporaeren Demo-Tabellen."
  - "Mehrere Rohschreibweisen koennen bewusst auf dieselbe Pivot-Spalte zusammengefuehrt werden."
  - "Nicht freigegebene Kennzahlen bleiben sichtbar, werden aber aus der pivot-tauglichen Quellmenge ausgeschlossen."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @ReportMonth CHAR(7) = '2026-03';
DECLARE @AllowFallbackAlias BIT = 0;
DECLARE @PivotInList NVARCHAR(MAX);

DROP TABLE IF EXISTS #RawMeasureFeed;
DROP TABLE IF EXISTS #MeasureNormalizationRules;
DROP TABLE IF EXISTS #MatchedMeasures;
DROP TABLE IF EXISTS #ApprovedColumns;

CREATE TABLE #RawMeasureFeed
(
    ReportMonth     CHAR(7)         NOT NULL,
    RegionCode      VARCHAR(20)     NOT NULL,
    RawMeasureName  NVARCHAR(60)    NOT NULL,
    MeasureValue    DECIMAL(12,2)   NOT NULL
);

CREATE TABLE #MeasureNormalizationRules
(
    RawMeasureKey       NVARCHAR(60)    NOT NULL PRIMARY KEY,
    CanonicalMeasure    NVARCHAR(60)    NOT NULL,
    PivotColumnName     SYSNAME         NOT NULL,
    DisplayOrder        TINYINT         NOT NULL,
    IsApproved          BIT             NOT NULL,
    RuleNote            NVARCHAR(160)   NOT NULL
);

INSERT INTO #RawMeasureFeed
(
    ReportMonth,
    RegionCode,
    RawMeasureName,
    MeasureValue
)
VALUES
    ('2026-02', 'Central', N'Gross Sales',       18400.00),
    ('2026-02', 'Central', N'gross-sales',       18400.00),
    ('2026-02', 'Central', N'Units Sold',          420.00),
    ('2026-03', 'Central', N'Gross Sales',       19250.00),
    ('2026-03', 'Central', N'gross_sales',       19250.00),
    ('2026-03', 'Central', N'Units Sold',          455.00),
    ('2026-03', 'North',   N'Gross-Sales',       20540.00),
    ('2026-03', 'North',   N'Units sold',          488.00),
    ('2026-03', 'North',   N'Return Amount',      -340.00),
    ('2026-03', 'South',   N'Net Revenue',       17680.00),
    ('2026-03', 'South',   N'Unit Count',          401.00),
    ('2026-03', 'South',   N'Return amount',      -290.00),
    ('2026-03', 'West',    N'Gross Sales',       16840.00),
    ('2026-03', 'West',    N'Units-Sold',          372.00),
    ('2026-03', 'West',    N'Promo Credit',       -120.00),
    ('2026-03', 'West',    N'Unmapped Metric?',    999.00);

INSERT INTO #MeasureNormalizationRules
(
    RawMeasureKey,
    CanonicalMeasure,
    PivotColumnName,
    DisplayOrder,
    IsApproved,
    RuleNote
)
VALUES
    (N'GROSSSALES',  N'Gross Sales',  N'GrossSalesAmount', 1, 1, N'Fuehrt Leerzeichen, Bindestriche und Unterstriche zu einer Umsatzkennzahl zusammen.'),
    (N'NETREVENUE',  N'Net Revenue',  N'NetRevenueAmount', 2, 1, N'Behaelt eine zweite Umsatzsicht fuer separate Pivot-Spalten.'),
    (N'UNITSSOLD',   N'Units Sold',   N'UnitsSoldCount',   3, 1, N'Vereinheitlicht mehrere Schreibweisen fuer Mengenkennzahlen.'),
    (N'UNITCOUNT',   N'Units Sold',   N'UnitsSoldCount',   3, 1, N'Erlaubt fachlich gleichwertige Synonyme auf dieselbe Pivot-Spalte.'),
    (N'RETURNAMOUNT',N'Return Amount',N'ReturnAmount',     4, 1, N'Rueckgaben bleiben als eigene Kennzahl sichtbar.'),
    (N'PROMOCREDIT', N'Promo Credit', N'PromoCredit',      5, 0, N'Ist in dieser Erstversion nicht fuer das Pivot-Layout freigegeben.');

IF @ReportMonth IS NULL
   OR TRY_CONVERT(DATE, @ReportMonth + '-01') IS NULL
BEGIN
    THROW 50041, 'PivotMeasureNameNormalizer expects @ReportMonth in the format YYYY-MM.', 1;
END;

IF @AllowFallbackAlias NOT IN (0, 1)
BEGIN
    THROW 50042, 'PivotMeasureNameNormalizer expects @AllowFallbackAlias as 0 or 1.', 1;
END;

IF EXISTS
(
    SELECT
        rules.PivotColumnName
    FROM #MeasureNormalizationRules AS rules
    WHERE rules.IsApproved = 1
    GROUP BY
        rules.PivotColumnName
    HAVING COUNT(DISTINCT rules.CanonicalMeasure) > 1
)
BEGIN
    THROW 50043, 'PivotMeasureNameNormalizer found one approved pivot column mapped to multiple canonical measures.', 1;
END;

;WITH SourcePrepared AS
(
    SELECT
        feed.ReportMonth,
        feed.RegionCode,
        feed.RawMeasureName,
        feed.MeasureValue,
        UPPER
        (
            REPLACE
            (
                REPLACE
                (
                    REPLACE(feed.RawMeasureName, N' ', N''),
                    N'-',
                    N''
                ),
                N'_',
                N''
            )
        ) AS RawMeasureKey
    FROM #RawMeasureFeed AS feed
    WHERE feed.ReportMonth = @ReportMonth
),
RulePrepared AS
(
    SELECT
        rules.RawMeasureKey,
        rules.CanonicalMeasure,
        rules.PivotColumnName,
        rules.DisplayOrder,
        rules.IsApproved,
        rules.RuleNote
    FROM #MeasureNormalizationRules AS rules
),
MatchedMeasures AS
(
    SELECT
        src.ReportMonth,
        src.RegionCode,
        src.RawMeasureName,
        src.MeasureValue,
        src.RawMeasureKey,
        rules.CanonicalMeasure,
        rules.PivotColumnName,
        rules.DisplayOrder,
        rules.IsApproved,
        rules.RuleNote,
        CASE
            WHEN rules.RawMeasureKey IS NOT NULL AND rules.IsApproved = 1 THEN 'approved'
            WHEN rules.RawMeasureKey IS NOT NULL AND rules.IsApproved = 0 THEN 'not-approved'
            WHEN @AllowFallbackAlias = 1 THEN 'fallback-alias'
            ELSE 'unmapped'
        END AS MatchStatus,
        CASE
            WHEN rules.RawMeasureKey IS NOT NULL THEN rules.CanonicalMeasure
            WHEN @AllowFallbackAlias = 1 THEN src.RawMeasureName
            ELSE NULL
        END AS EffectiveCanonicalMeasure,
        CASE
            WHEN rules.RawMeasureKey IS NOT NULL AND rules.IsApproved = 1 THEN rules.PivotColumnName
            WHEN rules.RawMeasureKey IS NOT NULL AND rules.IsApproved = 0 THEN NULL
            WHEN @AllowFallbackAlias = 1 THEN LEFT(src.RawMeasureKey + N'Fallback', 128)
            ELSE NULL
        END AS EffectivePivotColumnName
    FROM SourcePrepared AS src
    LEFT JOIN RulePrepared AS rules
        ON rules.RawMeasureKey = src.RawMeasureKey
),
SELECT
    matched.ReportMonth,
    matched.RegionCode,
    matched.RawMeasureName,
    matched.MeasureValue,
    matched.RawMeasureKey,
    matched.CanonicalMeasure,
    matched.PivotColumnName,
    matched.DisplayOrder,
    matched.IsApproved,
    matched.RuleNote,
    matched.MatchStatus,
    matched.EffectiveCanonicalMeasure,
    matched.EffectivePivotColumnName
INTO #MatchedMeasures
FROM MatchedMeasures AS matched;

SELECT DISTINCT
    matched.DisplayOrder,
    matched.EffectiveCanonicalMeasure,
    matched.EffectivePivotColumnName
INTO #ApprovedColumns
FROM #MatchedMeasures AS matched
WHERE matched.MatchStatus IN ('approved', 'fallback-alias')
  AND matched.EffectivePivotColumnName IS NOT NULL;

SELECT
    @PivotInList = STRING_AGG(QUOTENAME(columns.EffectivePivotColumnName), N', ')
        WITHIN GROUP (ORDER BY columns.DisplayOrder, columns.EffectivePivotColumnName)
FROM #ApprovedColumns AS columns;

IF @PivotInList IS NULL
BEGIN
    THROW 50044, 'PivotMeasureNameNormalizer found no pivot-ready measures for the selected month.', 1;
END;

SELECT
    matched.ReportMonth,
    matched.RegionCode,
    matched.RawMeasureName,
    matched.MeasureValue
FROM #MatchedMeasures AS matched
ORDER BY
    matched.RegionCode,
    matched.RawMeasureName;

SELECT
    rules.DisplayOrder,
    rules.RawMeasureKey,
    rules.CanonicalMeasure,
    rules.PivotColumnName,
    rules.IsApproved,
    rules.RuleNote
FROM #MeasureNormalizationRules AS rules
ORDER BY
    rules.DisplayOrder,
    rules.RawMeasureKey;

SELECT
    matched.RegionCode,
    matched.RawMeasureName,
    matched.RawMeasureKey,
    matched.MatchStatus,
    matched.EffectiveCanonicalMeasure,
    matched.EffectivePivotColumnName,
    matched.RuleNote
FROM #MatchedMeasures AS matched
ORDER BY
    matched.RegionCode,
    matched.RawMeasureName;

SELECT
    columns.DisplayOrder,
    columns.EffectiveCanonicalMeasure AS CanonicalMeasure,
    columns.EffectivePivotColumnName AS PivotColumnName,
    QUOTENAME(columns.EffectivePivotColumnName) AS SafePivotColumnName,
    @PivotInList AS PivotInList
FROM #ApprovedColumns AS columns
ORDER BY
    columns.DisplayOrder,
    columns.EffectivePivotColumnName;

SELECT
    matched.ReportMonth,
    matched.RegionCode,
    matched.EffectiveCanonicalMeasure AS NormalizedMeasureName,
    matched.EffectivePivotColumnName AS PivotColumnName,
    matched.MeasureValue
FROM #MatchedMeasures AS matched
WHERE matched.MatchStatus IN ('approved', 'fallback-alias')
  AND matched.EffectiveCanonicalMeasure IS NOT NULL
  AND matched.EffectivePivotColumnName IS NOT NULL
ORDER BY
    matched.RegionCode,
    matched.EffectivePivotColumnName,
    matched.EffectiveCanonicalMeasure;
