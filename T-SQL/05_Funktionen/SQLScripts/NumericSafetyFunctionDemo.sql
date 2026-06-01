/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "NumericSafetyFunctionDemo.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "05_Funktionen"

purpose: >
  Demonstriert auf einer kleinen Demo-Datenbasis, wie Division durch Null
  und Ueberlaeufe in numerischen Ausdruecken mit NULLIF, CASE,
  DECIMAL-Promotion und TRY_CONVERT defensiv abgefedert werden koennen.

parameters:
  - name: "@FallbackRatio"
    sql_type: "DECIMAL(12, 4)"
    direction: "IN"
    required: false
    description: "Ersatzwert fuer Quotienten, wenn der Nenner 0 ist"
  - name: "@TargetScale"
    sql_type: "TINYINT"
    direction: "IN"
    required: false
    description: "Anzahl der Nachkommastellen fuer die Quotientenanzeige"
  - name: "@ShowOnlyRiskCases"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 filtert das Detail-Resultset auf Divide-by-zero- oder Overflow-Risiken"

result_sets:
  - name: "NumericSafetyMatrix"
    description: "Vergleicht rohe Risiken mit defensiven Quotienten- und Konvertierungsmustern je Demo-Fall"
  - name: "RiskSummary"
    description: "Aggregiert Divide-by-zero- und Overflow-Risiken nach Szenariotyp"
  - name: "GuidanceNotes"
    description: "Leitet kompakte Einsatzhinweise fuer defensive Rechenmuster ab"

dependencies:
  - "tempdb temporary tables"
  - "NULLIF"
  - "CASE"
  - "TRY_CONVERT"
  - "DECIMAL"
  - "CTE"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/05_Funktionen/SQLScripts/NumericSafetyFunctionDemo.md"
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
    description: "Erstversion fuer defensive Numerikmuster gegen Divide-by-zero und Overflow"

notes:
  - "Das Skript nutzt nur eine temporaere Demo-Tabelle."
  - "Rohe riskante Ausdruecke werden absichtlich nicht direkt ausgefuehrt, sondern als Risiko markiert."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @FallbackRatio DECIMAL(12, 4) = 0.0000;
DECLARE @TargetScale TINYINT = 4;
DECLARE @ShowOnlyRiskCases BIT = 0;

IF @TargetScale NOT BETWEEN 2 AND 6
BEGIN
    THROW 50850, '@TargetScale muss zwischen 2 und 6 liegen.', 1;
END;

IF @ShowOnlyRiskCases NOT IN (0, 1)
BEGIN
    THROW 50851, '@ShowOnlyRiskCases muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #NumericCases;

CREATE TABLE #NumericCases
(
    CaseID INT NOT NULL PRIMARY KEY,
    ScenarioGroup VARCHAR(20) NOT NULL,
    ScenarioName VARCHAR(100) NOT NULL,
    NumeratorValue DECIMAL(19, 4) NOT NULL,
    DenominatorValue DECIMAL(19, 4) NOT NULL,
    ScaleMultiplier DECIMAL(19, 4) NOT NULL,
    CommentText VARCHAR(140) NOT NULL
);

INSERT INTO #NumericCases
(
    CaseID,
    ScenarioGroup,
    ScenarioName,
    NumeratorValue,
    DenominatorValue,
    ScaleMultiplier,
    CommentText
)
VALUES
    (1, 'ratios', 'Return rate with healthy denominator', 42.0000, 84.0000, 100.0000, 'Baseline fuer eine sichere Prozentberechnung'),
    (2, 'ratios', 'Incident ratio with zero denominator', 5.0000, 0.0000, 100.0000, 'Zeigt den Schutz gegen Division durch Null'),
    (3, 'pricing', 'Margin percentage with tiny denominator', 1250.0000, 0.5000, 100.0000, 'Groesserer Quotient bleibt mit DECIMAL-Promotion kontrollierbar'),
    (4, 'telemetry', 'Counter normalization with negative denominator', -36.0000, -12.0000, 1000.0000, 'Negative Werte bleiben fuer Vorzeichenfragen sichtbar'),
    (5, 'overflow', 'Large quantity close to INT upper bound', 21474830.0000, 2.0000, 100.0000, 'Skalierung wuerde als INT den Grenzwert ueberschreiten'),
    (6, 'overflow', 'Small correction below overflow threshold', 12500.0000, 4.0000, 10.0000, 'Kontrollfall ohne Overflow-Risiko');

;WITH PreparedCases AS
(
    SELECT
        nc.CaseID,
        nc.ScenarioGroup,
        nc.ScenarioName,
        nc.NumeratorValue,
        nc.DenominatorValue,
        nc.ScaleMultiplier,
        nc.CommentText,
        CAST(CASE WHEN nc.DenominatorValue = 0 THEN 1 ELSE 0 END AS BIT) AS DivideByZeroRisk,
        CAST(CASE WHEN ABS(nc.NumeratorValue * nc.ScaleMultiplier) > 2147483647.0 THEN 1 ELSE 0 END AS BIT) AS IntOverflowRisk
    FROM #NumericCases AS nc
),
SafetyMatrix AS
(
    SELECT
        pc.CaseID,
        pc.ScenarioGroup,
        pc.ScenarioName,
        pc.NumeratorValue,
        pc.DenominatorValue,
        pc.ScaleMultiplier,
        pc.DivideByZeroRisk,
        pc.IntOverflowRisk,
        CAST(pc.NumeratorValue / NULLIF(pc.DenominatorValue, 0) AS DECIMAL(19, 6)) AS SafeRatio,
        CAST(
            COALESCE(pc.NumeratorValue / NULLIF(pc.DenominatorValue, 0), @FallbackRatio) AS DECIMAL(19, 6)
        ) AS RatioWithFallback,
        CAST(
            COALESCE(pc.NumeratorValue / NULLIF(pc.DenominatorValue, 0), @FallbackRatio) * pc.ScaleMultiplier AS DECIMAL(38, 6)
        ) AS SafeScaledRatioWide,
        TRY_CONVERT(
            INT,
            COALESCE(pc.NumeratorValue / NULLIF(pc.DenominatorValue, 0), @FallbackRatio) * pc.ScaleMultiplier
        ) AS TryConvertScaledInt,
        CASE
            WHEN ABS(
                COALESCE(pc.NumeratorValue / NULLIF(pc.DenominatorValue, 0), @FallbackRatio) * pc.ScaleMultiplier
            ) <= 2147483647.0
            THEN CONVERT(
                INT,
                COALESCE(pc.NumeratorValue / NULLIF(pc.DenominatorValue, 0), @FallbackRatio) * pc.ScaleMultiplier
            )
            ELSE NULL
        END AS GuardedScaledInt,
        CASE
            WHEN pc.DenominatorValue = 0 THEN 'fallback-applied'
            ELSE 'ratio-computed'
        END AS DivideSafetyProfile,
        CASE
            WHEN ABS(
                COALESCE(pc.NumeratorValue / NULLIF(pc.DenominatorValue, 0), @FallbackRatio) * pc.ScaleMultiplier
            ) > 2147483647.0 THEN 'overflow-blocked'
            WHEN TRY_CONVERT(
                INT,
                COALESCE(pc.NumeratorValue / NULLIF(pc.DenominatorValue, 0), @FallbackRatio) * pc.ScaleMultiplier
            ) IS NULL THEN 'conversion-null'
            ELSE 'fits-int'
        END AS OverflowProfile,
        pc.CommentText
    FROM PreparedCases AS pc
),
GuidanceBase AS
(
    SELECT
        sm.ScenarioGroup,
        COUNT(*) AS ScenarioCount,
        SUM(CASE WHEN sm.DivideByZeroRisk = 1 THEN 1 ELSE 0 END) AS DivideByZeroRiskCount,
        SUM(CASE WHEN sm.IntOverflowRisk = 1 THEN 1 ELSE 0 END) AS IntOverflowRiskCount,
        SUM(CASE WHEN sm.DivideSafetyProfile = 'fallback-applied' THEN 1 ELSE 0 END) AS FallbackAppliedCount,
        SUM(CASE WHEN sm.OverflowProfile = 'overflow-blocked' THEN 1 ELSE 0 END) AS OverflowBlockedCount
    FROM SafetyMatrix AS sm
    GROUP BY
        sm.ScenarioGroup
)
SELECT
    sm.CaseID,
    sm.ScenarioGroup,
    sm.ScenarioName,
    sm.NumeratorValue,
    sm.DenominatorValue,
    sm.ScaleMultiplier,
    ROUND(sm.SafeRatio, @TargetScale) AS SafeRatioRounded,
    ROUND(sm.RatioWithFallback, @TargetScale) AS RatioWithFallbackRounded,
    ROUND(sm.SafeScaledRatioWide, @TargetScale) AS SafeScaledRatioRounded,
    sm.TryConvertScaledInt,
    sm.GuardedScaledInt,
    sm.DivideByZeroRisk,
    sm.IntOverflowRisk,
    sm.DivideSafetyProfile,
    sm.OverflowProfile,
    sm.CommentText
FROM SafetyMatrix AS sm
WHERE
    @ShowOnlyRiskCases = 0
    OR sm.DivideByZeroRisk = 1
    OR sm.IntOverflowRisk = 1
ORDER BY
    CASE sm.ScenarioGroup
        WHEN 'ratios' THEN 1
        WHEN 'pricing' THEN 2
        WHEN 'telemetry' THEN 3
        ELSE 4
    END,
    sm.CaseID;

SELECT
    sm.ScenarioGroup,
    COUNT(*) AS ScenarioCount,
    SUM(CASE WHEN sm.DivideByZeroRisk = 1 THEN 1 ELSE 0 END) AS DivideByZeroRiskCount,
    SUM(CASE WHEN sm.IntOverflowRisk = 1 THEN 1 ELSE 0 END) AS IntOverflowRiskCount,
    SUM(CASE WHEN sm.DivideSafetyProfile = 'fallback-applied' THEN 1 ELSE 0 END) AS FallbackAppliedCount,
    SUM(CASE WHEN sm.OverflowProfile = 'overflow-blocked' THEN 1 ELSE 0 END) AS OverflowBlockedCount,
    SUM(CASE WHEN sm.OverflowProfile = 'fits-int' THEN 1 ELSE 0 END) AS FitsIntCount
FROM SafetyMatrix AS sm
GROUP BY
    sm.ScenarioGroup
ORDER BY
    sm.ScenarioGroup;

SELECT
    gb.ScenarioGroup,
    gb.ScenarioCount,
    gb.DivideByZeroRiskCount,
    gb.IntOverflowRiskCount,
    gb.FallbackAppliedCount,
    gb.OverflowBlockedCount,
    CASE
        WHEN gb.DivideByZeroRiskCount > 0 AND gb.IntOverflowRiskCount > 0 THEN 'NULLIF fuer Quotienten einsetzen und skalierte Folgewerte vor INT-Konvertierungen explizit pruefen.'
        WHEN gb.DivideByZeroRiskCount > 0 THEN 'Quotienten mit NULLIF oder CASE absichern und einen fachlich passenden Fallback dokumentieren.'
        WHEN gb.IntOverflowRiskCount > 0 THEN 'Vor engen Zieltypen zuerst breit rechnen und Grenzwerte mit TRY_CONVERT oder CASE absichern.'
        ELSE 'Breite DECIMAL-Typen und klar benannte Guardrails halten numerische Ausdruecke nachvollziehbar.'
    END AS TeachingRecommendation
FROM GuidanceBase AS gb
ORDER BY
    gb.ScenarioGroup;
