/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "NumericRoundingLab.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "05_Funktionen"

purpose: >
  Zeigt auf einer kleinen Demo-Datenbasis, wie sich ROUND, CEILING, FLOOR
  sowie Datentypwechsel nach DECIMAL und INT auf positive und negative
  Zahlenwerte auswirken.

parameters:
  - name: "@DisplayScale"
    sql_type: "TINYINT"
    direction: "IN"
    required: false
    description: "Anzahl der Nachkommastellen fuer ROUND und DECIMAL-Konvertierungen"
  - name: "@LeftRoundDigits"
    sql_type: "SMALLINT"
    direction: "IN"
    required: false
    description: "Negative Rundungsstelle fuer Vergleiche links vom Dezimalpunkt"
  - name: "@ShowNegativeScaleComparison"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 blendet den Vergleich fuer negative ROUND-Stellen ein"

result_sets:
  - name: "RoundingMatrix"
    description: "Zeigt pro Demo-Fall Rundung, Abschneiden, Auf- und Abrunden sowie Typkonvertierungen"
  - name: "FunctionSummary"
    description: "Aggregiert die Unterschiede zwischen ROUND, CEILING, FLOOR und Typwechseln je Kategorie"
  - name: "GuidanceNotes"
    description: "Leitet didaktische Einsatzhinweise fuer typische Rundungssituationen ab"

dependencies:
  - "tempdb temporary tables"
  - "ROUND"
  - "CEILING"
  - "FLOOR"
  - "CAST"
  - "CONVERT"
  - "CTE"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/05_Funktionen/SQLScripts/NumericRoundingLab.md"
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
    date: "2026-04-17"
    user: "ER"
    description: "Erstversion fuer ein didaktisches Lab zu Rundungsfunktionen und Typkonvertierungen"

notes:
  - "Das Skript nutzt nur eine temporaere Demo-Tabelle."
  - "Positive und negative Werte sind bewusst gemischt, damit ROUND, CEILING und FLOOR klar unterscheidbar bleiben."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @DisplayScale TINYINT = 2;
DECLARE @LeftRoundDigits SMALLINT = -1;
DECLARE @ShowNegativeScaleComparison BIT = 1;

IF @DisplayScale > 4
BEGIN
    THROW 50840, '@DisplayScale darf nur Werte zwischen 0 und 4 annehmen.', 1;
END;

IF @LeftRoundDigits NOT BETWEEN -3 AND 0
BEGIN
    THROW 50841, '@LeftRoundDigits muss zwischen -3 und 0 liegen.', 1;
END;

IF @ShowNegativeScaleComparison NOT IN (0, 1)
BEGIN
    THROW 50842, '@ShowNegativeScaleComparison muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #NumericSamples;

CREATE TABLE #NumericSamples
(
    SampleID INT NOT NULL PRIMARY KEY,
    SampleCategory VARCHAR(20) NOT NULL,
    ScenarioName VARCHAR(80) NOT NULL,
    RawValue DECIMAL(12, 4) NOT NULL,
    CommentText VARCHAR(120) NOT NULL
);

INSERT INTO #NumericSamples
(
    SampleID,
    SampleCategory,
    ScenarioName,
    RawValue,
    CommentText
)
VALUES
    (1, 'prices', 'Invoice amount with half-up edge', 12.3450, 'Shows midpoint rounding at two decimals'),
    (2, 'prices', 'Discounted price below integer boundary', 19.9940, 'Contrasts DECIMAL rounding against INT truncation'),
    (3, 'ratios', 'Small positive ratio', 0.4449, 'Highlights CEILING and FLOOR near zero'),
    (4, 'ratios', 'Small negative variance', -0.4449, 'Shows that CEILING moves toward zero while FLOOR moves away'),
    (5, 'batches', 'Units close to next pack size', 27.5000, 'Useful for pack or seat planning examples'),
    (6, 'batches', 'Negative correction value', -27.5000, 'Makes sign-sensitive rounding differences explicit');

;WITH PreparedSamples AS
(
    SELECT
        ns.SampleID,
        ns.SampleCategory,
        ns.ScenarioName,
        ns.RawValue,
        ns.CommentText,
        CAST(ns.RawValue AS DECIMAL(12, 2)) AS CastDecimal2,
        CONVERT(DECIMAL(12, 2), ns.RawValue) AS ConvertDecimal2,
        CAST(ns.RawValue AS INT) AS CastInt,
        CONVERT(INT, ns.RawValue) AS ConvertInt
    FROM #NumericSamples AS ns
),
RoundingMatrix AS
(
    SELECT
        ps.SampleID,
        ps.SampleCategory,
        ps.ScenarioName,
        ps.RawValue,
        ROUND(ps.RawValue, @DisplayScale) AS RoundAtScale,
        ROUND(ps.RawValue, @DisplayScale, 1) AS TruncateAtScale,
        CEILING(ps.RawValue) AS CeilingValue,
        FLOOR(ps.RawValue) AS FloorValue,
        CASE
            WHEN @ShowNegativeScaleComparison = 1 THEN ROUND(ps.RawValue, @LeftRoundDigits)
            ELSE NULL
        END AS RoundAtLeftDigits,
        ps.CastDecimal2,
        ps.ConvertDecimal2,
        ps.CastInt,
        ps.ConvertInt,
        CASE
            WHEN ROUND(ps.RawValue, @DisplayScale) = ROUND(ps.RawValue, @DisplayScale, 1) THEN 'same-at-scale'
            ELSE 'round-vs-truncate-different'
        END AS ScaleDifference,
        CASE
            WHEN CEILING(ps.RawValue) = FLOOR(ps.RawValue) THEN 'already-whole-number'
            WHEN ps.RawValue >= 0 THEN 'positive-direction-gap'
            ELSE 'negative-direction-gap'
        END AS IntegerDirectionProfile,
        CASE
            WHEN CAST(ps.RawValue AS DECIMAL(12, 2)) = ROUND(ps.RawValue, 2) THEN 'cast-matches-round-2'
            ELSE 'cast-differs-from-round-2'
        END AS DecimalCastProfile
    FROM PreparedSamples AS ps
),
GuidanceBase AS
(
    SELECT
        rm.SampleCategory,
        COUNT(*) AS ScenarioCount,
        SUM(CASE WHEN rm.ScaleDifference = 'round-vs-truncate-different' THEN 1 ELSE 0 END) AS ScaleDifferenceCount,
        SUM(CASE WHEN rm.RawValue < 0 THEN 1 ELSE 0 END) AS NegativeScenarioCount,
        SUM(CASE WHEN rm.CastInt <> rm.CeilingValue THEN 1 ELSE 0 END) AS CastVsCeilingDifferenceCount,
        SUM(CASE WHEN rm.CastInt <> rm.FloorValue THEN 1 ELSE 0 END) AS CastVsFloorDifferenceCount
    FROM RoundingMatrix AS rm
    GROUP BY
        rm.SampleCategory
)
SELECT
    rm.SampleID,
    rm.SampleCategory,
    rm.ScenarioName,
    rm.RawValue,
    rm.RoundAtScale,
    rm.TruncateAtScale,
    rm.CeilingValue,
    rm.FloorValue,
    rm.RoundAtLeftDigits,
    rm.CastDecimal2,
    rm.ConvertDecimal2,
    rm.CastInt,
    rm.ConvertInt,
    rm.ScaleDifference,
    rm.IntegerDirectionProfile,
    rm.DecimalCastProfile,
    rm.CommentText
FROM RoundingMatrix AS rm
ORDER BY
    CASE rm.SampleCategory
        WHEN 'prices' THEN 1
        WHEN 'ratios' THEN 2
        ELSE 3
    END,
    rm.SampleID;

SELECT
    rm.SampleCategory,
    COUNT(*) AS ScenarioCount,
    SUM(CASE WHEN rm.ScaleDifference = 'round-vs-truncate-different' THEN 1 ELSE 0 END) AS RoundVsTruncateDifferences,
    SUM(CASE WHEN rm.IntegerDirectionProfile = 'positive-direction-gap' THEN 1 ELSE 0 END) AS PositiveDirectionCases,
    SUM(CASE WHEN rm.IntegerDirectionProfile = 'negative-direction-gap' THEN 1 ELSE 0 END) AS NegativeDirectionCases,
    SUM(CASE WHEN rm.DecimalCastProfile = 'cast-matches-round-2' THEN 1 ELSE 0 END) AS CastMatchesRound2Cases,
    SUM(CASE WHEN rm.DecimalCastProfile = 'cast-differs-from-round-2' THEN 1 ELSE 0 END) AS CastDiffersFromRound2Cases
FROM RoundingMatrix AS rm
GROUP BY
    rm.SampleCategory
ORDER BY
    rm.SampleCategory;

SELECT
    gb.SampleCategory,
    gb.ScenarioCount,
    gb.ScaleDifferenceCount,
    gb.NegativeScenarioCount,
    gb.CastVsCeilingDifferenceCount,
    gb.CastVsFloorDifferenceCount,
    CASE
        WHEN gb.ScaleDifferenceCount > 0 AND gb.NegativeScenarioCount > 0 THEN 'ROUND fuer kaufmaennische Werte, CEILING und FLOOR immer mit Vorzeichenwirkung erklaeren.'
        WHEN gb.ScaleDifferenceCount > 0 THEN 'ROUND und Truncate-Variante bewusst trennen, wenn Nachkommastellen fachlich relevant bleiben.'
        ELSE 'Direkte Integerfunktionen reichen nur, wenn keine Skalen- oder Vorzeichenfrage offen ist.'
    END AS TeachingRecommendation
FROM GuidanceBase AS gb
ORDER BY
    gb.SampleCategory;
