/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "NullHandlingFunctionMatrix.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "05_Funktionen"

purpose: >
  Vergleicht ISNULL, COALESCE, NULLIF und angrenzende
  Null-Behandlungsmuster auf einer gemeinsamen Demo-Datenbasis
  fuer Strings, Zahlen und zusammengesetzte Ausgabeausdruecke.

parameters:
  - name: "@StringFallback"
    sql_type: "VARCHAR(20)"
    direction: "IN"
    required: false
    description: "Textlicher Rueckgabewert fuer fehlende Codes"
  - name: "@NumericFallback"
    sql_type: "DECIMAL(10,2)"
    direction: "IN"
    required: false
    description: "Numerischer Rueckgabewert fuer fehlende Werte"
  - name: "@ShowOnlyDifferences"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 zeigt nur Szenarien mit unterschiedlichem Funktionsverhalten"

result_sets:
  - name: "FunctionMatrixRows"
    description: "Zeigt pro Demo-Szenario die Ergebnisse von ISNULL, COALESCE, NULLIF und Folgeausdruecken"
  - name: "DifferenceSummary"
    description: "Aggregiert, in welchen Szenarien sich die verglichenen Null-Muster unterschiedlich verhalten"
  - name: "GuidanceMatrix"
    description: "Leitet kompakte Einsatzempfehlungen aus den beobachteten Demo-Faellen ab"

dependencies:
  - "tempdb temporary tables"
  - "ISNULL"
  - "COALESCE"
  - "NULLIF"
  - "CONCAT"
  - "CTE"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/05_Funktionen/SQLScripts/NullHandlingFunctionMatrix.md"
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
    description: "Erstversion fuer die didaktische Matrix zu Null-Behandlungsfunktionen"

notes:
  - "Das Skript verwendet nur tempdb-nahe Demo-Daten."
  - "COALESCE castet String-Eingaenge bewusst auf VARCHAR(20), damit Ketten und Laengenvergleich sichtbar bleiben."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @StringFallback VARCHAR(20) = 'missing-code';
DECLARE @NumericFallback DECIMAL(10, 2) = 999.99;
DECLARE @ShowOnlyDifferences BIT = 0;

IF NULLIF(LTRIM(RTRIM(@StringFallback)), '') IS NULL
BEGIN
    THROW 50620, '@StringFallback darf nicht leer sein.', 1;
END;

IF @NumericFallback < 0
BEGIN
    THROW 50621, '@NumericFallback muss groesser oder gleich 0 sein.', 1;
END;

IF @ShowOnlyDifferences NOT IN (0, 1)
BEGIN
    THROW 50622, '@ShowOnlyDifferences muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #NullSamples;

CREATE TABLE #NullSamples
(
    ScenarioID INT NOT NULL PRIMARY KEY,
    ScenarioName VARCHAR(80) NOT NULL,
    ShortCode VARCHAR(8) NULL,
    AlternateCode VARCHAR(20) NULL,
    DisplayName VARCHAR(40) NULL,
    NumericValue DECIMAL(10, 2) NULL,
    BackupValue DECIMAL(10, 2) NULL,
    SuppressionValue DECIMAL(10, 2) NULL,
    CommentText VARCHAR(40) NULL
);

INSERT INTO #NullSamples
(
    ScenarioID,
    ScenarioName,
    ShortCode,
    AlternateCode,
    DisplayName,
    NumericValue,
    BackupValue,
    SuppressionValue,
    CommentText
)
VALUES
    (1, 'Primary value present', 'AB12', 'ALT-AB12', 'Alpha Retail', 42.50, 100.00, 0.00, 'short code wins'),
    (2, 'Primary string missing', NULL, 'ALT-LONG-CODE', 'Beta Foods', NULL, 75.00, 0.00, NULL),
    (3, 'Primary equals alternate', 'SAME', 'SAME', 'Gamma Parts', 15.00, 20.00, 15.00, 'NULLIF clears duplicates'),
    (4, 'Numeric chain needed', 'N-44', NULL, NULL, NULL, 12.50, 0.00, 'backup numeric value'),
    (5, 'All string inputs missing', NULL, NULL, 'Epsilon Labs', 0.00, NULL, 0.00, 'falls back to parameter'),
    (6, 'Suppressed numeric sentinel', 'Z-09', 'ALT-Z-09', 'Zeta Services', 0.00, 55.00, 0.00, '0 should become NULL');

;WITH PreparedMatrix AS
(
    SELECT
        ns.ScenarioID,
        ns.ScenarioName,
        ns.ShortCode,
        ns.AlternateCode,
        ns.DisplayName,
        ns.NumericValue,
        ns.BackupValue,
        ns.SuppressionValue,
        ns.CommentText,
        ISNULL(ns.ShortCode, @StringFallback) AS IsNullCode,
        COALESCE(CAST(ns.ShortCode AS VARCHAR(20)), ns.AlternateCode, @StringFallback) AS CoalesceCode,
        NULLIF(ns.ShortCode, ns.AlternateCode) AS NullIfCode,
        COALESCE(NULLIF(CAST(ns.ShortCode AS VARCHAR(20)), ns.AlternateCode), ns.AlternateCode, @StringFallback) AS EffectiveCode,
        ISNULL(ns.NumericValue, @NumericFallback) AS IsNullNumeric,
        COALESCE(ns.NumericValue, ns.BackupValue, @NumericFallback) AS CoalesceNumeric,
        NULLIF(ns.NumericValue, ns.SuppressionValue) AS NullIfNumeric,
        COALESCE(NULLIF(ns.NumericValue, ns.SuppressionValue), ns.BackupValue, @NumericFallback) AS EffectiveNumeric,
        CONCAT(COALESCE(ns.DisplayName, '(no name)'), ' | ', COALESCE(ns.CommentText, 'no comment')) AS ConcatPreview,
        CASE
            WHEN ISNULL(ns.ShortCode, @StringFallback) <> COALESCE(CAST(ns.ShortCode AS VARCHAR(20)), ns.AlternateCode, @StringFallback) THEN 1
            ELSE 0
        END AS StringDifferenceFlag,
        CASE
            WHEN ISNULL(ns.NumericValue, @NumericFallback) <> COALESCE(ns.NumericValue, ns.BackupValue, @NumericFallback) THEN 1
            ELSE 0
        END AS NumericDifferenceFlag,
        CASE
            WHEN NULLIF(ns.NumericValue, ns.SuppressionValue) IS NULL AND ns.NumericValue IS NOT NULL THEN 1
            ELSE 0
        END AS NullIfSuppressedFlag
    FROM #NullSamples AS ns
),
FilteredMatrix AS
(
    SELECT
        pm.ScenarioID,
        pm.ScenarioName,
        pm.ShortCode,
        pm.AlternateCode,
        pm.DisplayName,
        pm.NumericValue,
        pm.BackupValue,
        pm.SuppressionValue,
        pm.CommentText,
        pm.IsNullCode,
        pm.CoalesceCode,
        pm.NullIfCode,
        pm.EffectiveCode,
        pm.IsNullNumeric,
        pm.CoalesceNumeric,
        pm.NullIfNumeric,
        pm.EffectiveNumeric,
        pm.ConcatPreview,
        pm.StringDifferenceFlag,
        pm.NumericDifferenceFlag,
        pm.NullIfSuppressedFlag,
        CASE
            WHEN pm.StringDifferenceFlag = 1 AND pm.NumericDifferenceFlag = 1 THEN 'string-and-numeric-difference'
            WHEN pm.StringDifferenceFlag = 1 THEN 'string-difference'
            WHEN pm.NumericDifferenceFlag = 1 THEN 'numeric-difference'
            WHEN pm.NullIfSuppressedFlag = 1 THEN 'nullif-suppression'
            ELSE 'same-result'
        END AS DifferenceProfile
    FROM PreparedMatrix AS pm
    WHERE
        @ShowOnlyDifferences = 0
        OR pm.StringDifferenceFlag = 1
        OR pm.NumericDifferenceFlag = 1
        OR pm.NullIfSuppressedFlag = 1
)
SELECT
    fm.ScenarioID,
    fm.ScenarioName,
    fm.ShortCode,
    fm.AlternateCode,
    fm.IsNullCode,
    fm.CoalesceCode,
    fm.NullIfCode,
    fm.EffectiveCode,
    LEN(fm.IsNullCode) AS IsNullCodeLength,
    LEN(fm.CoalesceCode) AS CoalesceCodeLength,
    fm.NumericValue,
    fm.BackupValue,
    fm.IsNullNumeric,
    fm.CoalesceNumeric,
    fm.NullIfNumeric,
    fm.EffectiveNumeric,
    fm.ConcatPreview,
    fm.DifferenceProfile
FROM FilteredMatrix AS fm
ORDER BY
    fm.ScenarioID;

SELECT
    fm.DifferenceProfile,
    COUNT(*) AS ScenarioCount,
    SUM(fm.StringDifferenceFlag) AS StringDifferenceCases,
    SUM(fm.NumericDifferenceFlag) AS NumericDifferenceCases,
    SUM(fm.NullIfSuppressedFlag) AS NullIfSuppressionCases,
    STRING_AGG(fm.ScenarioName, ', ') WITHIN GROUP (ORDER BY fm.ScenarioID) AS ScenarioList
FROM FilteredMatrix AS fm
GROUP BY
    fm.DifferenceProfile
ORDER BY
    CASE fm.DifferenceProfile
        WHEN 'string-and-numeric-difference' THEN 1
        WHEN 'string-difference' THEN 2
        WHEN 'numeric-difference' THEN 3
        WHEN 'nullif-suppression' THEN 4
        ELSE 5
    END;

SELECT
    gm.FunctionName,
    gm.WhenToUse,
    gm.ObservedPattern,
    gm.ExampleScenarios
FROM
(
    SELECT
        'ISNULL' AS FunctionName,
        'Sinnvoll fuer genau einen Rueckfallwert mit stabiler Rueckgabetyp-Erwartung.' AS WhenToUse,
        CONCAT(
            'Rueckgabe nutzte in ',
            SUM(CASE WHEN fm.ShortCode IS NULL THEN 1 ELSE 0 END),
            ' Szenarien den direkten Ersatzwert und blieb dabei an die Typbreite des ersten Arguments gebunden.'
        ) AS ObservedPattern,
        STRING_AGG(CASE WHEN fm.ShortCode IS NULL THEN fm.ScenarioName END, ', ') WITHIN GROUP (ORDER BY fm.ScenarioID) AS ExampleScenarios
    FROM FilteredMatrix AS fm

    UNION ALL

    SELECT
        'COALESCE' AS FunctionName,
        'Sinnvoll fuer mehrere Fallback-Stufen oder gemischte Quellenketten.' AS WhenToUse,
        CONCAT(
            'COALESCE zog in ',
            SUM(CASE WHEN fm.CoalesceCode <> fm.IsNullCode OR fm.CoalesceNumeric <> fm.IsNullNumeric THEN 1 ELSE 0 END),
            ' Szenarien eine spaetere Alternative der einfachen ISNULL-Variante vor.'
        ) AS ObservedPattern,
        STRING_AGG(
            CASE
                WHEN fm.CoalesceCode <> fm.IsNullCode OR fm.CoalesceNumeric <> fm.IsNullNumeric THEN fm.ScenarioName
            END,
            ', '
        ) WITHIN GROUP (ORDER BY fm.ScenarioID) AS ExampleScenarios
    FROM FilteredMatrix AS fm

    UNION ALL

    SELECT
        'NULLIF' AS FunctionName,
        'Sinnvoll, wenn ein Gleichstand oder Sentinel-Wert zunaechst auf NULL zurueckgefuehrt werden soll.' AS WhenToUse,
        CONCAT(
            'NULLIF neutralisierte in ',
            SUM(CASE WHEN fm.NullIfCode IS NULL OR fm.NullIfNumeric IS NULL THEN 1 ELSE 0 END),
            ' Szenarien einen Match oder Suppressionswert, bevor ein weiterer Fallback greifen konnte.'
        ) AS ObservedPattern,
        STRING_AGG(
            CASE
                WHEN fm.NullIfCode IS NULL OR fm.NullIfNumeric IS NULL THEN fm.ScenarioName
            END,
            ', '
        ) WITHIN GROUP (ORDER BY fm.ScenarioID) AS ExampleScenarios
    FROM FilteredMatrix AS fm

    UNION ALL

    SELECT
        'CONCAT plus COALESCE' AS FunctionName,
        'Sinnvoll fuer lesbare Ausgabestrings, wenn einzelne Textteile NULL sein duerfen.' AS WhenToUse,
        CONCAT(
            'Alle ',
            COUNT(*),
            ' Demo-Zeilen erzeugten trotz fehlender Teilwerte einen lesbaren Anzeige-String.'
        ) AS ObservedPattern,
        STRING_AGG(fm.ScenarioName, ', ') WITHIN GROUP (ORDER BY fm.ScenarioID) AS ExampleScenarios
    FROM FilteredMatrix AS fm
) AS gm
ORDER BY
    CASE gm.FunctionName
        WHEN 'ISNULL' THEN 1
        WHEN 'COALESCE' THEN 2
        WHEN 'NULLIF' THEN 3
        ELSE 4
    END;
