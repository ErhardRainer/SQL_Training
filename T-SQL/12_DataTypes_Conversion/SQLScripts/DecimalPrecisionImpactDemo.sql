/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "DecimalPrecisionImpactDemo.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "12_DataTypes_Conversion"

purpose: >
  Zeigt anhand eines kleinen Demo-Datensatzes, wie sich unterschiedliche
  DECIMAL-Praezisionen und -Skalen auf Rundung, abgeschnittene Nachkommastellen
  und Overflow-Risiken auswirken.

parameters:
  - name: "@ShowOnlyRiskRows"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = nur Zeilen mit Rundung oder Overflow ausgeben"
  - name: "@IncludeTargetSummary"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zweite Ergebnismenge mit aggregierter Zieltyp-Zusammenfassung ausgeben"

result_sets:
  - name: "DecimalPrecisionImpactDetail"
    description: "Detailansicht pro Demo-Wert und Ziel-DECIMAL-Definition"
  - name: "DecimalPrecisionImpactSummary"
    description: "Aggregierte Uebersicht pro Ziel-DECIMAL ueber Fits, Rundungen und Overflows"

dependencies:
  - "TRY_CONVERT()"
  - "temporary tables"
  - "sp_executesql"
  - "ROW_NUMBER()"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/12_DataTypes_Conversion/SQLScripts/DecimalPrecisionImpactDemo.md"
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
    description: "Erstversion des didaktischen Labs fuer DECIMAL-Praezision, Skala, Rundung und Overflow"

notes:
  - "Alle Beispiele laufen mit Demo-Werten in Temp-Tabellen und schreiben keine persistenten Daten."
  - "Overflow wird ueber TRY_CONVERT() auf die jeweilige Ziel-DECIMAL-Definition ermittelt."
  - "Rundung wird erkannt, indem der erfolgreiche Zielwert wieder nach DECIMAL(38,18) zurueckkonvertiert wird."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @ShowOnlyRiskRows    BIT = 0;
DECLARE @IncludeTargetSummary BIT = 1;

IF @ShowOnlyRiskRows NOT IN (0, 1)
BEGIN
    THROW 50000, '@ShowOnlyRiskRows muss 0 oder 1 sein.', 1;
END;

IF @IncludeTargetSummary NOT IN (0, 1)
BEGIN
    THROW 50001, '@IncludeTargetSummary muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #Samples;
DROP TABLE IF EXISTS #Targets;
DROP TABLE IF EXISTS #PrecisionAudit;

CREATE TABLE #Samples
(
    SampleId         INT             NOT NULL PRIMARY KEY,
    ScenarioGroup    VARCHAR(40)     NOT NULL,
    ScenarioLabel    VARCHAR(120)    NOT NULL,
    RawValue         VARCHAR(40)     NOT NULL,
    ExpectedFocus    VARCHAR(40)     NOT NULL,
    TeachingNote     NVARCHAR(300)   NOT NULL
);

CREATE TABLE #Targets
(
    TargetOrder      INT             NOT NULL PRIMARY KEY,
    TargetType       VARCHAR(20)     NOT NULL,
    PrecisionValue   TINYINT         NOT NULL,
    ScaleValue       TINYINT         NOT NULL,
    MaxAbsValueHint  VARCHAR(50)     NOT NULL,
    TeachingFocus    NVARCHAR(200)   NOT NULL
);

CREATE TABLE #PrecisionAudit
(
    SampleId                 INT             NOT NULL,
    ScenarioGroup            VARCHAR(40)     NOT NULL,
    ScenarioLabel            VARCHAR(120)    NOT NULL,
    RawValue                 VARCHAR(40)     NOT NULL,
    TargetType               VARCHAR(20)     NOT NULL,
    PrecisionValue           TINYINT         NOT NULL,
    ScaleValue               TINYINT         NOT NULL,
    ExactValue               DECIMAL(38,18)  NULL,
    ConvertedValue           DECIMAL(38,18)  NULL,
    StatusLabel              VARCHAR(30)     NOT NULL,
    RoundedFlag              BIT             NOT NULL,
    LostScaleDigits          INT             NOT NULL,
    IntegerDigitBudget       INT             NOT NULL,
    MaxAbsValueHint          VARCHAR(50)     NOT NULL,
    TeachingNote             NVARCHAR(300)   NOT NULL,
    TeachingFocus            NVARCHAR(200)   NOT NULL
);

INSERT INTO #Samples
(
    SampleId,
    ScenarioGroup,
    ScenarioLabel,
    RawValue,
    ExpectedFocus,
    TeachingNote
)
VALUES
    (1, 'fits_exactly', 'small amount with two decimals', '12.34', 'exact-fit', N'Passt exakt in Ziele mit mindestens zwei Nachkommastellen.'),
    (2, 'scale_pressure', 'three decimals near rounding border', '12.345', 'rounding', N'Zeigt klassische Rundung beim Wechsel von Scale 3 auf Scale 2.'),
    (3, 'scale_pressure', 'micro amount with four decimals', '0.0049', 'rounding', N'Macht sichtbar, dass kleine Werte bei groberer Scale zu 0.00 werden koennen.'),
    (4, 'precision_pressure', 'large amount with safe scale', '999.99', 'overflow', N'Passt nicht mehr in kleine DECIMAL-Ziele mit wenig Integer-Spielraum.'),
    (5, 'precision_pressure', 'many integer digits', '12345.67', 'overflow', N'Demonstriert, dass Praezision nicht nur Nachkommastellen, sondern auch Stellen vor dem Komma begrenzt.'),
    (6, 'negative_values', 'negative value with three decimals', '-45.555', 'rounding', N'Negativwerte werden bei der Rundung analog behandelt.'),
    (7, 'edge_case', 'half-up discussion sample', '1.005', 'rounding', N'Dieser Wert ist didaktisch hilfreich, um Rundung auf zwei Dezimalstellen zu diskutieren.'),
    (8, 'wide_fit', 'large value that still fits wide target', '123456.7891', 'fit-vs-overflow', N'Passt nur in breitere Zieldefinitionen und illustriert den Nutzen groesserer Praezision.');

INSERT INTO #Targets
(
    TargetOrder,
    TargetType,
    PrecisionValue,
    ScaleValue,
    MaxAbsValueHint,
    TeachingFocus
)
VALUES
    (1, 'DECIMAL(5,2)', 5, 2, '999.99', N'Kleines Ziel fuer Geld- oder Demo-Werte mit nur drei Integer-Stellen.'),
    (2, 'DECIMAL(6,3)', 6, 3, '999.999', N'Gibt einer zusaetzlichen Nachkommastelle Raum, aber kaum mehr Integer-Kapazitaet.'),
    (3, 'DECIMAL(9,2)', 9, 2, '9999999.99', N'Groessere Praezision reduziert Overflow-Risiken, skaliert aber weiterhin auf zwei Nachkommastellen.'),
    (4, 'DECIMAL(12,4)', 12, 4, '99999999.9999', N'Breites Ziel, das viele Demo-Werte ohne Verlust aufnehmen kann.');

DECLARE @TargetType VARCHAR(20);
DECLARE @Sql NVARCHAR(MAX);

DECLARE target_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT t.TargetType
FROM #Targets AS t
ORDER BY t.TargetOrder;

OPEN target_cursor;

FETCH NEXT FROM target_cursor INTO @TargetType;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @Sql = N'
INSERT INTO #PrecisionAudit
(
    SampleId,
    ScenarioGroup,
    ScenarioLabel,
    RawValue,
    TargetType,
    PrecisionValue,
    ScaleValue,
    ExactValue,
    ConvertedValue,
    StatusLabel,
    RoundedFlag,
    LostScaleDigits,
    IntegerDigitBudget,
    MaxAbsValueHint,
    TeachingNote,
    TeachingFocus
)
SELECT
    s.SampleId,
    s.ScenarioGroup,
    s.ScenarioLabel,
    s.RawValue,
    t.TargetType,
    t.PrecisionValue,
    t.ScaleValue,
    TRY_CONVERT(DECIMAL(38,18), s.RawValue) AS ExactValue,
    TRY_CONVERT(DECIMAL(38,18), TRY_CONVERT(' + @TargetType + N', s.RawValue)) AS ConvertedValue,
    CASE
        WHEN TRY_CONVERT(DECIMAL(38,18), s.RawValue) IS NULL THEN ''invalid_input''
        WHEN TRY_CONVERT(' + @TargetType + N', s.RawValue) IS NULL THEN ''overflow''
        WHEN TRY_CONVERT(DECIMAL(38,18), TRY_CONVERT(' + @TargetType + N', s.RawValue)) <> TRY_CONVERT(DECIMAL(38,18), s.RawValue) THEN ''rounded''
        ELSE ''exact_fit''
    END AS StatusLabel,
    CASE
        WHEN TRY_CONVERT(DECIMAL(38,18), s.RawValue) IS NOT NULL
         AND TRY_CONVERT(' + @TargetType + N', s.RawValue) IS NOT NULL
         AND TRY_CONVERT(DECIMAL(38,18), TRY_CONVERT(' + @TargetType + N', s.RawValue)) <> TRY_CONVERT(DECIMAL(38,18), s.RawValue)
            THEN 1
        ELSE 0
    END AS RoundedFlag,
    CASE
        WHEN TRY_CONVERT(' + @TargetType + N', s.RawValue) IS NULL THEN 0
        WHEN CHARINDEX(''.'', s.RawValue) = 0 THEN 0
        ELSE
            COALESCE(LEN(PARSENAME(REPLACE(REPLACE(s.RawValue, ''-'', ''''), ''+'', ''''), 1)), 0)
            - COALESCE(LEN(PARSENAME(REPLACE(REPLACE(CONVERT(VARCHAR(50), TRY_CONVERT(' + @TargetType + N', s.RawValue)), ''-'', ''''), ''+'', ''''), 1)), 0)
    END AS LostScaleDigits,
    t.PrecisionValue - t.ScaleValue AS IntegerDigitBudget,
    t.MaxAbsValueHint,
    s.TeachingNote,
    t.TeachingFocus
FROM #Samples AS s
CROSS JOIN #Targets AS t
WHERE t.TargetType = @TargetTypeParam;';

    EXEC sys.sp_executesql
        @Sql,
        N'@TargetTypeParam VARCHAR(20)',
        @TargetTypeParam = @TargetType;

    FETCH NEXT FROM target_cursor INTO @TargetType;
END;

CLOSE target_cursor;
DEALLOCATE target_cursor;

UPDATE pa
SET pa.LostScaleDigits =
    CASE
        WHEN pa.StatusLabel <> 'rounded' THEN 0
        WHEN pa.LostScaleDigits < 0 THEN 0
        ELSE pa.LostScaleDigits
    END
FROM #PrecisionAudit AS pa;

SELECT
    pa.SampleId,
    pa.ScenarioGroup,
    pa.ScenarioLabel,
    pa.RawValue,
    pa.TargetType,
    pa.PrecisionValue,
    pa.ScaleValue,
    pa.ExactValue,
    pa.ConvertedValue,
    pa.StatusLabel,
    pa.RoundedFlag,
    pa.LostScaleDigits,
    pa.IntegerDigitBudget,
    pa.MaxAbsValueHint,
    pa.TeachingNote,
    pa.TeachingFocus
FROM #PrecisionAudit AS pa
WHERE @ShowOnlyRiskRows = 0
   OR pa.StatusLabel IN ('rounded', 'overflow')
ORDER BY
    pa.SampleId,
    pa.PrecisionValue,
    pa.ScaleValue;

IF @IncludeTargetSummary = 1
BEGIN
    SELECT
        pa.TargetType,
        pa.PrecisionValue,
        pa.ScaleValue,
        COUNT(*) AS TestedSamples,
        SUM(CASE WHEN pa.StatusLabel = 'exact_fit' THEN 1 ELSE 0 END) AS ExactFits,
        SUM(CASE WHEN pa.StatusLabel = 'rounded' THEN 1 ELSE 0 END) AS RoundedRows,
        SUM(CASE WHEN pa.StatusLabel = 'overflow' THEN 1 ELSE 0 END) AS OverflowRows,
        MAX(pa.IntegerDigitBudget) AS IntegerDigitBudget,
        MAX(pa.MaxAbsValueHint) AS MaxAbsValueHint,
        MAX(pa.TeachingFocus) AS TeachingFocus
    FROM #PrecisionAudit AS pa
    GROUP BY
        pa.TargetType,
        pa.PrecisionValue,
        pa.ScaleValue
    ORDER BY
        pa.PrecisionValue,
        pa.ScaleValue;
END;
