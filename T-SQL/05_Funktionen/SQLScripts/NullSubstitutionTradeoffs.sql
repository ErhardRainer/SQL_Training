/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "NullSubstitutionTradeoffs.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "05_Funktionen"

purpose: >
  Vergleicht ISNULL, COALESCE und NULLIF auf einer gemeinsamen
  Demo-Datenbasis, damit Rueckfallketten, Typbreiten,
  Sentinel-Unterdrueckung und fachliche Einsatzgrenzen sichtbar
  werden.

parameters:
  - name: "@StringFallback"
    sql_type: "VARCHAR(12)"
    direction: "IN"
    required: false
    description: "Textlicher Rueckfallwert fuer fehlende oder bereinigte Codes"
  - name: "@NumericFallback"
    sql_type: "DECIMAL(10,2)"
    direction: "IN"
    required: false
    description: "Numerischer Rueckfallwert fuer NULL- oder Sentinel-Faelle"
  - name: "@ShowTypeDetails"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 zeigt die Typ- und Laengenbeobachtungen, 0 liefert nur Vergleich und Empfehlungen"

result_sets:
  - name: "TradeoffRows"
    description: "Vergleicht pro Demo-Szenario direkte Ersetzung, Kettenlogik und NULLIF-basierte Bereinigung"
  - name: "TypeLengthObservations"
    description: "Zeigt, wie sich Basistyp, MaxLength, Precision und Scale je Ausdruck unterscheiden"
  - name: "RecommendationMatrix"
    description: "Leitet kompakte Einsatzempfehlungen aus den beobachteten Tradeoffs ab"

dependencies:
  - "tempdb temporary tables"
  - "ISNULL"
  - "COALESCE"
  - "NULLIF"
  - "SQL_VARIANT_PROPERTY"
  - "common table expressions"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/05_Funktionen/SQLScripts/NullSubstitutionTradeoffs.md"
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
    description: "Erstversion fuer ein didaktisches Lab zu Null-Substitution und Tradeoffs"

notes:
  - "Die Demo arbeitet ausschliesslich mit tempdb-nahen Beispieldaten."
  - "String-Vergleiche zeigen bewusst den Unterschied zwischen direkter Ersetzung und mehrstufiger Fallback-Kette."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @StringFallback VARCHAR(12) = 'fallback-std';
DECLARE @NumericFallback DECIMAL(10, 2) = 999.99;
DECLARE @ShowTypeDetails BIT = 1;

IF NULLIF(LTRIM(RTRIM(@StringFallback)), '') IS NULL
BEGIN
    THROW 50640, '@StringFallback darf nicht leer sein.', 1;
END;

IF LEN(@StringFallback) > 12
BEGIN
    THROW 50641, '@StringFallback darf hoechstens 12 Zeichen haben.', 1;
END;

IF @NumericFallback < 0
BEGIN
    THROW 50642, '@NumericFallback muss groesser oder gleich 0 sein.', 1;
END;

IF @ShowTypeDetails NOT IN (0, 1)
BEGIN
    THROW 50643, '@ShowTypeDetails muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #NullTradeoffSamples;

CREATE TABLE #NullTradeoffSamples
(
    ScenarioID INT NOT NULL PRIMARY KEY,
    ScenarioName VARCHAR(90) NOT NULL,
    ShortCode VARCHAR(6) NULL,
    BackupCode VARCHAR(18) NULL,
    DisplayLabel VARCHAR(30) NULL,
    MetricValue DECIMAL(10, 2) NULL,
    BackupMetric DECIMAL(10, 2) NULL,
    SentinelMetric DECIMAL(10, 2) NULL,
    CommentText VARCHAR(25) NULL
);

INSERT INTO #NullTradeoffSamples
(
    ScenarioID,
    ScenarioName,
    ShortCode,
    BackupCode,
    DisplayLabel,
    MetricValue,
    BackupMetric,
    SentinelMetric,
    CommentText
)
VALUES
    (1, 'Primary string available', 'AB12', 'ALPHA-LONG-CODE', 'Alpha Retail', 15.50, 90.00, 0.00, 'native code wins'),
    (2, 'Primary string missing', NULL, 'BETA-LONG-CODE', 'Beta Foods', NULL, 55.75, 0.00, ''),
    (3, 'Primary and backup identical', 'SAME', 'SAME', 'Gamma Parts', 44.00, 44.00, 44.00, 'duplicate source'),
    (4, 'Numeric fallback chain needed', 'N-44', NULL, NULL, NULL, 12.50, 0.00, 'backup metric'),
    (5, 'Sentinel numeric should vanish', 'Z-09', 'ZETA-ALT', 'Zeta Services', 0.00, 63.25, 0.00, '0 means unknown'),
    (6, 'All optional text missing', NULL, NULL, 'Epsilon Labs', 7.00, NULL, 0.00, NULL);

;WITH PreparedTradeoffs AS
(
    SELECT
        nts.ScenarioID,
        nts.ScenarioName,
        nts.ShortCode,
        nts.BackupCode,
        nts.DisplayLabel,
        nts.MetricValue,
        nts.BackupMetric,
        nts.SentinelMetric,
        nts.CommentText,
        ISNULL(nts.ShortCode, @StringFallback) AS IsNullCode,
        COALESCE(CAST(nts.ShortCode AS VARCHAR(18)), nts.BackupCode, @StringFallback) AS CoalesceCode,
        NULLIF(CAST(nts.ShortCode AS VARCHAR(18)), nts.BackupCode) AS NullIfCode,
        COALESCE(NULLIF(CAST(nts.ShortCode AS VARCHAR(18)), nts.BackupCode), nts.BackupCode, @StringFallback) AS EffectiveCode,
        COALESCE(NULLIF(LTRIM(RTRIM(nts.CommentText)), ''), 'comment-missing') AS SanitizedComment,
        ISNULL(nts.MetricValue, @NumericFallback) AS IsNullMetric,
        COALESCE(nts.MetricValue, nts.BackupMetric, @NumericFallback) AS CoalesceMetric,
        NULLIF(nts.MetricValue, nts.SentinelMetric) AS NullIfMetric,
        COALESCE(NULLIF(nts.MetricValue, nts.SentinelMetric), nts.BackupMetric, @NumericFallback) AS EffectiveMetric,
        CASE
            WHEN nts.ShortCode IS NULL AND nts.BackupCode IS NOT NULL THEN 'backup-code-used'
            WHEN nts.ShortCode IS NULL THEN 'parameter-fallback-used'
            WHEN nts.ShortCode = nts.BackupCode AND nts.ShortCode IS NOT NULL THEN 'duplicate-value-suppressed'
            ELSE 'primary-code-kept'
        END AS StringTradeoff,
        CASE
            WHEN nts.MetricValue IS NULL AND nts.BackupMetric IS NOT NULL THEN 'backup-metric-used'
            WHEN nts.MetricValue = nts.SentinelMetric AND nts.MetricValue IS NOT NULL THEN 'sentinel-cleared-before-fallback'
            WHEN nts.MetricValue IS NULL THEN 'parameter-numeric-fallback'
            ELSE 'primary-metric-kept'
        END AS NumericTradeoff
    FROM #NullTradeoffSamples AS nts
),
TradeoffRows AS
(
    SELECT
        pt.ScenarioID,
        pt.ScenarioName,
        pt.ShortCode,
        pt.BackupCode,
        pt.IsNullCode,
        pt.CoalesceCode,
        pt.NullIfCode,
        pt.EffectiveCode,
        LEN(pt.IsNullCode) AS IsNullCodeLength,
        LEN(pt.CoalesceCode) AS CoalesceCodeLength,
        pt.MetricValue,
        pt.BackupMetric,
        pt.IsNullMetric,
        pt.CoalesceMetric,
        pt.NullIfMetric,
        pt.EffectiveMetric,
        pt.SanitizedComment,
        pt.StringTradeoff,
        pt.NumericTradeoff,
        CASE
            WHEN pt.IsNullCode <> pt.CoalesceCode THEN 'string-width-or-fallback-difference'
            WHEN pt.IsNullMetric <> pt.CoalesceMetric THEN 'numeric-fallback-difference'
            WHEN pt.NullIfMetric IS NULL AND pt.MetricValue IS NOT NULL THEN 'sentinel-suppressed'
            WHEN pt.NullIfCode IS NULL AND pt.ShortCode IS NOT NULL THEN 'duplicate-string-suppressed'
            ELSE 'same-observable-result'
        END AS MainObservation
    FROM PreparedTradeoffs AS pt
)
SELECT
    tr.ScenarioID,
    tr.ScenarioName,
    tr.ShortCode,
    tr.BackupCode,
    tr.IsNullCode,
    tr.CoalesceCode,
    tr.NullIfCode,
    tr.EffectiveCode,
    tr.IsNullCodeLength,
    tr.CoalesceCodeLength,
    tr.MetricValue,
    tr.BackupMetric,
    tr.IsNullMetric,
    tr.CoalesceMetric,
    tr.NullIfMetric,
    tr.EffectiveMetric,
    tr.SanitizedComment,
    tr.StringTradeoff,
    tr.NumericTradeoff,
    tr.MainObservation
FROM TradeoffRows AS tr
ORDER BY
    tr.ScenarioID;

IF @ShowTypeDetails = 1
BEGIN
    SELECT
        'ISNULL short code with parameter fallback' AS ObservationName,
        SQL_VARIANT_PROPERTY(CAST(ISNULL(CAST(NULL AS VARCHAR(6)), @StringFallback) AS sql_variant), 'BaseType') AS BaseType,
        SQL_VARIANT_PROPERTY(CAST(ISNULL(CAST(NULL AS VARCHAR(6)), @StringFallback) AS sql_variant), 'MaxLength') AS MaxLength,
        SQL_VARIANT_PROPERTY(CAST(ISNULL(CAST(NULL AS VARCHAR(6)), @StringFallback) AS sql_variant), 'Precision') AS PrecisionValue,
        SQL_VARIANT_PROPERTY(CAST(ISNULL(CAST(NULL AS VARCHAR(6)), @StringFallback) AS sql_variant), 'Scale') AS ScaleValue,
        CAST(ISNULL(CAST(NULL AS VARCHAR(6)), @StringFallback) AS VARCHAR(30)) AS SampleValue

    UNION ALL

    SELECT
        'COALESCE casted short code and backup chain',
        SQL_VARIANT_PROPERTY(CAST(COALESCE(CAST(CAST(NULL AS VARCHAR(6)) AS VARCHAR(18)), CAST('BETA-LONG-CODE' AS VARCHAR(18)), @StringFallback) AS sql_variant), 'BaseType'),
        SQL_VARIANT_PROPERTY(CAST(COALESCE(CAST(CAST(NULL AS VARCHAR(6)) AS VARCHAR(18)), CAST('BETA-LONG-CODE' AS VARCHAR(18)), @StringFallback) AS sql_variant), 'MaxLength'),
        SQL_VARIANT_PROPERTY(CAST(COALESCE(CAST(CAST(NULL AS VARCHAR(6)) AS VARCHAR(18)), CAST('BETA-LONG-CODE' AS VARCHAR(18)), @StringFallback) AS sql_variant), 'Precision'),
        SQL_VARIANT_PROPERTY(CAST(COALESCE(CAST(CAST(NULL AS VARCHAR(6)) AS VARCHAR(18)), CAST('BETA-LONG-CODE' AS VARCHAR(18)), @StringFallback) AS sql_variant), 'Scale'),
        CAST(COALESCE(CAST(CAST(NULL AS VARCHAR(6)) AS VARCHAR(18)), CAST('BETA-LONG-CODE' AS VARCHAR(18)), @StringFallback) AS VARCHAR(30))

    UNION ALL

    SELECT
        'NULLIF on duplicate code',
        SQL_VARIANT_PROPERTY(CAST(NULLIF(CAST('SAME' AS VARCHAR(18)), CAST('SAME' AS VARCHAR(18))) AS sql_variant), 'BaseType'),
        SQL_VARIANT_PROPERTY(CAST(NULLIF(CAST('SAME' AS VARCHAR(18)), CAST('SAME' AS VARCHAR(18))) AS sql_variant), 'MaxLength'),
        SQL_VARIANT_PROPERTY(CAST(NULLIF(CAST('SAME' AS VARCHAR(18)), CAST('SAME' AS VARCHAR(18))) AS sql_variant), 'Precision'),
        SQL_VARIANT_PROPERTY(CAST(NULLIF(CAST('SAME' AS VARCHAR(18)), CAST('SAME' AS VARCHAR(18))) AS sql_variant), 'Scale'),
        CAST(COALESCE(NULLIF(CAST('SAME' AS VARCHAR(18)), CAST('SAME' AS VARCHAR(18))), '(null)') AS VARCHAR(30))

    UNION ALL

    SELECT
        'COALESCE decimal chain after NULLIF sentinel',
        SQL_VARIANT_PROPERTY(CAST(COALESCE(NULLIF(CAST(0.00 AS DECIMAL(10,2)), CAST(0.00 AS DECIMAL(10,2))), CAST(63.25 AS DECIMAL(10,2)), @NumericFallback) AS sql_variant), 'BaseType'),
        SQL_VARIANT_PROPERTY(CAST(COALESCE(NULLIF(CAST(0.00 AS DECIMAL(10,2)), CAST(0.00 AS DECIMAL(10,2))), CAST(63.25 AS DECIMAL(10,2)), @NumericFallback) AS sql_variant), 'MaxLength'),
        SQL_VARIANT_PROPERTY(CAST(COALESCE(NULLIF(CAST(0.00 AS DECIMAL(10,2)), CAST(0.00 AS DECIMAL(10,2))), CAST(63.25 AS DECIMAL(10,2)), @NumericFallback) AS sql_variant), 'Precision'),
        SQL_VARIANT_PROPERTY(CAST(COALESCE(NULLIF(CAST(0.00 AS DECIMAL(10,2)), CAST(0.00 AS DECIMAL(10,2))), CAST(63.25 AS DECIMAL(10,2)), @NumericFallback) AS sql_variant), 'Scale'),
        CAST(COALESCE(NULLIF(CAST(0.00 AS DECIMAL(10,2)), CAST(0.00 AS DECIMAL(10,2))), CAST(63.25 AS DECIMAL(10,2)), @NumericFallback) AS VARCHAR(30));
END;

SELECT
    rm.FunctionName,
    rm.WhenToUse,
    rm.TradeoffFocus,
    rm.ExampleScenarios
FROM
(
    SELECT
        'ISNULL' AS FunctionName,
        'Sinnvoll bei genau einem Rueckfallwert und wenn Typbreite des ersten Arguments bewusst beibehalten werden soll.' AS WhenToUse,
        'Direkte Ersetzung ist kompakt, kann bei schmalem erstem Argument aber Stringbreite kuerzen.' AS TradeoffFocus,
        STRING_AGG(CASE WHEN tr.StringTradeoff IN ('parameter-fallback-used', 'backup-code-used') THEN tr.ScenarioName END, ', ') WITHIN GROUP (ORDER BY tr.ScenarioID) AS ExampleScenarios
    FROM TradeoffRows AS tr

    UNION ALL

    SELECT
        'COALESCE',
        'Sinnvoll fuer mehrere Fallback-Stufen oder wenn eine breitere Rueckgabetyp-Kette erwuenscht ist.',
        'COALESCE macht mehr Quellen sichtbar, verlangt aber eine bewusste Typsteuerung fuer klare Ergebnisse.',
        STRING_AGG(CASE WHEN tr.MainObservation IN ('string-width-or-fallback-difference', 'numeric-fallback-difference') THEN tr.ScenarioName END, ', ') WITHIN GROUP (ORDER BY tr.ScenarioID)
    FROM TradeoffRows AS tr

    UNION ALL

    SELECT
        'NULLIF',
        'Sinnvoll, wenn Gleichstaende, Leerstrings oder Sentinel-Werte zuerst in NULL ueberfuehrt werden sollen.',
        'NULLIF ersetzt nichts selbst, sondern bereitet den Ausdruck fuer eine nachfolgende Fallback-Regel vor.',
        STRING_AGG(CASE WHEN tr.MainObservation IN ('sentinel-suppressed', 'duplicate-string-suppressed') THEN tr.ScenarioName END, ', ') WITHIN GROUP (ORDER BY tr.ScenarioID)
    FROM TradeoffRows AS tr

    UNION ALL

    SELECT
        'NULLIF plus COALESCE',
        'Sinnvoll fuer bereinigte Fallback-Ketten mit Sentinel- oder Dublettenunterdrueckung.',
        'Die Kombination ist laenger, zeigt aber die fachliche Absicht meist expliziter als ein einzelner Ersatzoperator.',
        STRING_AGG(CASE WHEN tr.EffectiveCode IS NOT NULL OR tr.EffectiveMetric IS NOT NULL THEN tr.ScenarioName END, ', ') WITHIN GROUP (ORDER BY tr.ScenarioID)
    FROM TradeoffRows AS tr
) AS rm
ORDER BY
    CASE rm.FunctionName
        WHEN 'ISNULL' THEN 1
        WHEN 'COALESCE' THEN 2
        WHEN 'NULLIF' THEN 3
        ELSE 4
    END;
