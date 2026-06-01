/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "DecimalScaleDriftAudit.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "12_DataTypes_Conversion"

purpose: >
  Audit fuer Drift bei Dezimalstellen und Skalierung. Das Skript vergleicht
  Demo-Werte mit mehreren Ziel-Skalen, zeigt den gerundeten Zielwert, die
  numerische Abweichung und klassifiziert, ob keine Drift, Aufrundung,
  Abrundung oder ein Effekt nahe Null vorliegt.

parameters:
  - name: "@OnlyDriftRows"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = nur Zeilen mit numerischer Drift ausgeben"
  - name: "@IncludeScaleSummary"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zweite Ergebnismenge mit Aggregation pro Ziel-Skala ausgeben"

result_sets:
  - name: "DecimalScaleDriftDetail"
    description: "Detailansicht pro Demo-Wert und Ziel-Skala mit Driftbetrag und Klassifikation"
  - name: "DecimalScaleDriftSummary"
    description: "Aggregierte Uebersicht pro Ziel-Skala ueber Drift, Nullrundung und exakte Treffer"

dependencies:
  - "ROUND()"
  - "TRY_CONVERT()"
  - "temporary tables"
  - "CROSS JOIN"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/12_DataTypes_Conversion/SQLScripts/DecimalScaleDriftAudit.md"
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
    description: "Erstversion des didaktischen Audits fuer Drift durch reduzierte DECIMAL-Skalen"

notes:
  - "Das Skript nutzt nur Demo-Werte in Temp-Tabellen und setzt keine produktiven Tabellen voraus."
  - "Drift entsteht hier durch ROUND() auf die jeweilige Ziel-Skala und wird als Delta zum exakten Ausgangswert gezeigt."
  - "SourceScaleDigits basiert auf den Nachkommastellen der Eingabezeichenkette und dient der didaktischen Einordnung."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @OnlyDriftRows      BIT = 0;
DECLARE @IncludeScaleSummary BIT = 1;

IF @OnlyDriftRows NOT IN (0, 1)
BEGIN
    THROW 50000, '@OnlyDriftRows muss 0 oder 1 sein.', 1;
END;

IF @IncludeScaleSummary NOT IN (0, 1)
BEGIN
    THROW 50001, '@IncludeScaleSummary muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #Samples;
DROP TABLE IF EXISTS #ScalePolicies;
DROP TABLE IF EXISTS #ScaleAudit;

CREATE TABLE #Samples
(
    SampleId             INT             NOT NULL PRIMARY KEY,
    ScenarioGroup        VARCHAR(40)     NOT NULL,
    ScenarioLabel        VARCHAR(120)    NOT NULL,
    RawValue             VARCHAR(40)     NOT NULL,
    SourceScaleDigits    INT             NOT NULL,
    TeachingNote         NVARCHAR(300)   NOT NULL
);

CREATE TABLE #ScalePolicies
(
    PolicyOrder          INT             NOT NULL PRIMARY KEY,
    TargetScaleDigits    TINYINT         NOT NULL,
    PolicyLabel          VARCHAR(30)     NOT NULL,
    TeachingFocus        NVARCHAR(200)   NOT NULL
);

CREATE TABLE #ScaleAudit
(
    SampleId                 INT             NOT NULL,
    ScenarioGroup            VARCHAR(40)     NOT NULL,
    ScenarioLabel            VARCHAR(120)    NOT NULL,
    RawValue                 VARCHAR(40)     NOT NULL,
    ExactValue               DECIMAL(38,12)  NULL,
    SourceScaleDigits        INT             NOT NULL,
    TargetScaleDigits        TINYINT         NOT NULL,
    RoundedValue             DECIMAL(38,12)  NULL,
    DriftValue               DECIMAL(38,12)  NULL,
    AbsoluteDriftValue       DECIMAL(38,12)  NULL,
    LostScaleDigits          INT             NOT NULL,
    DriftDirection           VARCHAR(20)     NOT NULL,
    DriftClass               VARCHAR(30)     NOT NULL,
    IsScaleReduction         BIT             NOT NULL,
    IsDriftRow               BIT             NOT NULL,
    PolicyLabel              VARCHAR(30)     NOT NULL,
    TeachingNote             NVARCHAR(300)   NOT NULL,
    TeachingFocus            NVARCHAR(200)   NOT NULL
);

INSERT INTO #Samples
(
    SampleId,
    ScenarioGroup,
    ScenarioLabel,
    RawValue,
    SourceScaleDigits,
    TeachingNote
)
VALUES
    (1, 'currency_like', 'two decimal amount already aligned', '18.40', 2, N'Kontrollfall fuer Werte, die bereits exakt zu einer Geld-Skala passen.'),
    (2, 'currency_like', 'three decimals above half cent', '18.405', 3, N'Zeigt Aufrundung von drei auf zwei Nachkommastellen.'),
    (3, 'currency_like', 'three decimals below half cent', '18.404', 3, N'Zeigt Abrundung von drei auf zwei Nachkommastellen.'),
    (4, 'micro_values', 'tiny amount that collapses at scale 2', '0.0049', 4, N'Macht sichtbar, dass kleine Werte bei groberer Ziel-Skala zu 0.00 werden koennen.'),
    (5, 'micro_values', 'tiny negative amount', '-0.0049', 4, N'Demonstriert dieselbe Drift-Logik fuer negative Kleinwerte.'),
    (6, 'sensor_like', 'five-decimal measurement', '12.34567', 5, N'Praezisionsstarker Messwert fuer den Vergleich mehrerer Ziel-Skalen.'),
    (7, 'sensor_like', 'midpoint rounding example', '1.0050', 4, N'Didaktischer Beispielwert fuer die Diskussion ueber kaufmaennische Rundung.'),
    (8, 'whole_number_bias', 'integer-like value with trailing decimals', '250.0004', 4, N'Zeigt eine sehr kleine Drift hinter einem scheinbar ganzzahligen Betrag.');

INSERT INTO #ScalePolicies
(
    PolicyOrder,
    TargetScaleDigits,
    PolicyLabel,
    TeachingFocus
)
VALUES
    (1, 0, 'scale_0', N'Simuliert ganzzahlige Zielspalten oder harte Verdichtung auf ganze Werte.'),
    (2, 2, 'scale_2', N'Simuliert typische Geld- und Reporting-Ziele mit zwei Nachkommastellen.'),
    (3, 3, 'scale_3', N'Bietet etwas mehr Puffer fuer Mess- oder Kurswerte.'),
    (4, 4, 'scale_4', N'Dient als breiteres Ziel fuer fast alle Demo-Werte ohne oder mit wenig Drift.');

INSERT INTO #ScaleAudit
(
    SampleId,
    ScenarioGroup,
    ScenarioLabel,
    RawValue,
    ExactValue,
    SourceScaleDigits,
    TargetScaleDigits,
    RoundedValue,
    DriftValue,
    AbsoluteDriftValue,
    LostScaleDigits,
    DriftDirection,
    DriftClass,
    IsScaleReduction,
    IsDriftRow,
    PolicyLabel,
    TeachingNote,
    TeachingFocus
)
SELECT
    s.SampleId,
    s.ScenarioGroup,
    s.ScenarioLabel,
    s.RawValue,
    TRY_CONVERT(DECIMAL(38,12), s.RawValue) AS ExactValue,
    s.SourceScaleDigits,
    p.TargetScaleDigits,
    ROUND(TRY_CONVERT(DECIMAL(38,12), s.RawValue), p.TargetScaleDigits) AS RoundedValue,
    ROUND(TRY_CONVERT(DECIMAL(38,12), s.RawValue), p.TargetScaleDigits) - TRY_CONVERT(DECIMAL(38,12), s.RawValue) AS DriftValue,
    ABS(ROUND(TRY_CONVERT(DECIMAL(38,12), s.RawValue), p.TargetScaleDigits) - TRY_CONVERT(DECIMAL(38,12), s.RawValue)) AS AbsoluteDriftValue,
    CASE
        WHEN s.SourceScaleDigits > p.TargetScaleDigits THEN s.SourceScaleDigits - p.TargetScaleDigits
        ELSE 0
    END AS LostScaleDigits,
    CASE
        WHEN ROUND(TRY_CONVERT(DECIMAL(38,12), s.RawValue), p.TargetScaleDigits) > TRY_CONVERT(DECIMAL(38,12), s.RawValue) THEN 'rounded_up'
        WHEN ROUND(TRY_CONVERT(DECIMAL(38,12), s.RawValue), p.TargetScaleDigits) < TRY_CONVERT(DECIMAL(38,12), s.RawValue) THEN 'rounded_down'
        ELSE 'no_change'
    END AS DriftDirection,
    CASE
        WHEN TRY_CONVERT(DECIMAL(38,12), s.RawValue) IS NULL THEN 'invalid_input'
        WHEN ROUND(TRY_CONVERT(DECIMAL(38,12), s.RawValue), p.TargetScaleDigits) = TRY_CONVERT(DECIMAL(38,12), s.RawValue) THEN 'exact_fit'
        WHEN ROUND(TRY_CONVERT(DECIMAL(38,12), s.RawValue), p.TargetScaleDigits) = 0
         AND TRY_CONVERT(DECIMAL(38,12), s.RawValue) <> 0 THEN 'rounded_to_zero'
        WHEN ABS(ROUND(TRY_CONVERT(DECIMAL(38,12), s.RawValue), p.TargetScaleDigits) - TRY_CONVERT(DECIMAL(38,12), s.RawValue)) < 0.01 THEN 'minor_drift'
        ELSE 'material_drift'
    END AS DriftClass,
    CASE
        WHEN s.SourceScaleDigits > p.TargetScaleDigits THEN 1
        ELSE 0
    END AS IsScaleReduction,
    CASE
        WHEN ROUND(TRY_CONVERT(DECIMAL(38,12), s.RawValue), p.TargetScaleDigits) <> TRY_CONVERT(DECIMAL(38,12), s.RawValue) THEN 1
        ELSE 0
    END AS IsDriftRow,
    p.PolicyLabel,
    s.TeachingNote,
    p.TeachingFocus
FROM #Samples AS s
CROSS JOIN #ScalePolicies AS p;

SELECT
    sa.SampleId,
    sa.ScenarioGroup,
    sa.ScenarioLabel,
    sa.RawValue,
    sa.ExactValue,
    sa.SourceScaleDigits,
    sa.TargetScaleDigits,
    sa.RoundedValue,
    sa.DriftValue,
    sa.AbsoluteDriftValue,
    sa.LostScaleDigits,
    sa.DriftDirection,
    sa.DriftClass,
    sa.IsScaleReduction,
    sa.PolicyLabel,
    sa.TeachingNote,
    sa.TeachingFocus
FROM #ScaleAudit AS sa
WHERE @OnlyDriftRows = 0
   OR sa.IsDriftRow = 1
ORDER BY
    sa.SampleId,
    sa.TargetScaleDigits;

IF @IncludeScaleSummary = 1
BEGIN
    SELECT
        sa.TargetScaleDigits,
        COUNT(*) AS TestedSamples,
        SUM(CASE WHEN sa.DriftClass = 'exact_fit' THEN 1 ELSE 0 END) AS ExactFits,
        SUM(CASE WHEN sa.IsDriftRow = 1 THEN 1 ELSE 0 END) AS DriftRows,
        SUM(CASE WHEN sa.DriftClass = 'minor_drift' THEN 1 ELSE 0 END) AS MinorDriftRows,
        SUM(CASE WHEN sa.DriftClass = 'material_drift' THEN 1 ELSE 0 END) AS MaterialDriftRows,
        SUM(CASE WHEN sa.DriftClass = 'rounded_to_zero' THEN 1 ELSE 0 END) AS RoundedToZeroRows,
        MAX(sa.LostScaleDigits) AS MaxLostScaleDigits,
        MAX(sa.TeachingFocus) AS TeachingFocus
    FROM #ScaleAudit AS sa
    GROUP BY
        sa.TargetScaleDigits
    ORDER BY
        sa.TargetScaleDigits;
END;
