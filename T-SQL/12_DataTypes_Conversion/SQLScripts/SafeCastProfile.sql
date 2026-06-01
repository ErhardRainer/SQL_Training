/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "SafeCastProfile.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "12_DataTypes_Conversion"

purpose: >
  Profiliert eingebaute Beispielwerte gegen mehrere TRY_CAST- und
  TRY_CONVERT-Zieltypen. Das Skript zeigt pro Zielprofil, welche Tokens
  direkt lesbar sind, welche an typischen Formatmustern scheitern und
  welche Bereinigungsschritte sich fuer Import- oder Staging-Strecken
  anbieten.

parameters: []

result_sets:
  - name: "SafeCastProfileSummary"
    description: "Aggregiert Erfolgs-, Fehler- und Near-Miss-Raten pro Zielprofil"
  - name: "SafeCastProfileDetail"
    description: "Zeigt Beispielwerte mit Konvertierungsergebnis, Failure-Bucket und Empfehlung"
  - name: "SafeCastActionHints"
    description: "Verdichtet Failure-Buckets in konkrete Bereinigungshinweise"

dependencies:
  - "TRY_CAST()"
  - "TRY_CONVERT()"
  - "LEN()"
  - "DATALENGTH()"
  - "LIKE"
  - "PATINDEX()"
  - "temporary tables"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/12_DataTypes_Conversion/SQLScripts/SafeCastProfile.md"
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
    description: "Erstversion des Safe-Cast-Profils fuer typische Staging-Tokens"

notes:
  - "Die Erstversion arbeitet mit Demo-Werten statt mit produktiven Importtabellen."
  - "Near Misses markieren Werte, die fachlich nah am Zieltyp liegen, aber vor der Konvertierung bereinigt werden sollten."
  - "DATE-Profile unterscheiden bewusst ISO- und DACH-Stil, damit Formatentscheidungen sichtbar bleiben."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DROP TABLE IF EXISTS #SafeCastSamples;

CREATE TABLE #SafeCastSamples
(
    SampleId            INT            NOT NULL PRIMARY KEY,
    SampleLabel         VARCHAR(60)    NOT NULL,
    RawValue            NVARCHAR(100)  NULL,
    IntendedFamily      VARCHAR(30)    NOT NULL,
    Notes               VARCHAR(220)   NOT NULL
);

INSERT INTO #SafeCastSamples
(
    SampleId,
    SampleLabel,
    RawValue,
    IntendedFamily,
    Notes
)
VALUES
    (1,  'Integer_Valid',          N'42',                                  'integer',   'Stabile Ganzzahl ohne Formatballast.'),
    (2,  'Integer_WithSpaces',     N'   42   ',                            'integer',   'Fuehrt vor dem Cast nur Trim-Bedarf mit.'),
    (3,  'Integer_WithThousands',  N'1,234',                               'integer',   'Tausendertrennzeichen blockiert direkte Integer-Konvertierung.'),
    (4,  'Decimal_Dot',            N'15.75',                               'decimal',   'Invarianter Dezimalpunkt passt zu TRY_CAST auf DECIMAL.'),
    (5,  'Decimal_Comma',          N'15,75',                               'decimal',   'DACH-Dezimalkomma benoetigt Vorbereinigung oder Formatmapping.'),
    (6,  'IsoDate_Valid',          N'2026-04-18',                          'date',      'ISO-Datum ist fuer TRY_CONVERT mit Style 23 stabil.'),
    (7,  'GermanDate_Valid',       N'18.04.2026',                          'date',      'DACH-Datum ist fuer TRY_CONVERT mit Style 104 gedacht.'),
    (8,  'UsDate_Ambiguous',       N'04/05/2026',                          'date',      'Slash-Datum ist ohne expliziten Kulturpfad mehrdeutig.'),
    (9,  'IsoDateTime_Valid',      N'2026-04-18T09:30:00',                 'datetime',  'ISO-8601-Zeitstempel fuer DATETIME2.'),
    (10, 'DateTime_InvalidClock',  N'2026-04-18 25:61:00',                 'datetime',  'Ungueltiger Zeitanteil trotz plausibler Datumsform.'),
    (11, 'Guid_Valid',             N'6F9619FF-8B86-D011-B42D-00C04FC964FF','guid',      'Gueltige GUID als Referenzwert.'),
    (12, 'Guid_ShapeOnly',         N'6F9619FF-8B86-D011-B42D-00C04FC964FG','guid',      'Aehnliche Form, aber ungueltiges Hex-Zeichen.'),
    (13, 'Bit_One',                N'1',                                   'bit',       'Direkt konvertierbarer BIT-Token.'),
    (14, 'Bit_TrueText',           N'true',                                'bit',       'Semantisch plausibel, aber nicht direkt per TRY_CAST lesbar.'),
    (15, 'Currency_Symbol',        N'EUR 19.95',                           'decimal',   'Waehrungssymbol verhindert direkte numerische Konvertierung.'),
    (16, 'Blank_Value',            N'   ',                                 'unknown',   'Blank-Wert fuer Upstream-Qualitaetschecks.'),
    (17, 'Null_Value',             NULL,                                   'unknown',   'NULL-Wert fuer Staging- oder Mapping-Luecken.'),
    (18, 'Text_Noise',             N'forty-two',                           'unknown',   'Freitext statt technisch lesbarer Zielreprasentation.');

WITH Normalized AS
(
    SELECT
        s.SampleId,
        s.SampleLabel,
        s.RawValue,
        s.IntendedFamily,
        s.Notes,
        LTRIM(RTRIM(s.RawValue)) AS TrimmedValue,
        LEN(LTRIM(RTRIM(COALESCE(s.RawValue, N'')))) AS CharacterLength,
        DATALENGTH(s.RawValue) AS ByteLength,
        CASE WHEN s.RawValue IS NULL THEN 1 ELSE 0 END AS IsNullValue,
        CASE WHEN s.RawValue IS NOT NULL AND LTRIM(RTRIM(s.RawValue)) = N'' THEN 1 ELSE 0 END AS IsBlankValue,
        CASE WHEN s.RawValue IS NOT NULL AND LTRIM(RTRIM(s.RawValue)) LIKE N'%[0-9]%' THEN 1 ELSE 0 END AS ContainsDigits,
        CASE WHEN s.RawValue IS NOT NULL AND LTRIM(RTRIM(s.RawValue)) LIKE N'%,%' AND LTRIM(RTRIM(s.RawValue)) NOT LIKE N'%.%' THEN 1 ELSE 0 END AS LooksLikeDecimalComma,
        CASE WHEN s.RawValue IS NOT NULL AND LTRIM(RTRIM(s.RawValue)) LIKE N'%/%' THEN 1 ELSE 0 END AS UsesSlashDelimiter,
        CASE WHEN s.RawValue IS NOT NULL AND LTRIM(RTRIM(s.RawValue)) LIKE N'%[A-Za-z]%' THEN 1 ELSE 0 END AS ContainsLetters,
        CASE
            WHEN s.RawValue IS NOT NULL
             AND LTRIM(RTRIM(s.RawValue)) LIKE
                 N'[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]-[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]-[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]-[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]-[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]'
                THEN 1
            ELSE 0
        END AS LooksLikeGuidShape
    FROM #SafeCastSamples AS s
),
ConversionProfiles AS
(
    SELECT
        n.SampleId,
        n.SampleLabel,
        n.RawValue,
        n.TrimmedValue,
        n.IntendedFamily,
        n.Notes,
        n.CharacterLength,
        n.ByteLength,
        'BIGINT' AS TargetType,
        'TRY_CAST integer' AS ConversionMode,
        CASE WHEN n.IsNullValue = 0 AND n.IsBlankValue = 0 AND TRY_CAST(n.TrimmedValue AS BIGINT) IS NOT NULL THEN 1 ELSE 0 END AS IsConvertible,
        CASE WHEN n.IsNullValue = 0 AND n.IsBlankValue = 0 AND (n.TrimmedValue LIKE N'%,%' OR n.TrimmedValue LIKE N'%.%') THEN 1 ELSE 0 END AS IsNearMiss,
        CASE
            WHEN n.IsNullValue = 1 THEN 'null-value'
            WHEN n.IsBlankValue = 1 THEN 'blank-value'
            WHEN TRY_CAST(n.TrimmedValue AS BIGINT) IS NOT NULL THEN 'cast-ok'
            WHEN n.TrimmedValue LIKE N'%,%' THEN 'thousands-or-decimal-separator'
            WHEN PATINDEX(N'%[^0-9+-]%', n.TrimmedValue) > 0 THEN 'non-numeric-characters'
            ELSE 'overflow-or-unclassified'
        END AS FailureBucket,
        CASE
            WHEN n.IsNullValue = 1 THEN 'NULL vor dem Profiling getrennt behandeln.'
            WHEN n.IsBlankValue = 1 THEN 'Blank-Werte trimmen und auf NULL oder Fehlerstatus mappen.'
            WHEN TRY_CAST(n.TrimmedValue AS BIGINT) IS NOT NULL THEN 'Keine Bereinigung erforderlich.'
            WHEN n.TrimmedValue LIKE N'%,%' THEN 'Tausender- oder Dezimaltrennzeichen vor dem Integer-Cast entfernen.'
            ELSE 'Zeichen ausserhalb von Ziffern, Vorzeichen und Leerraum bereinigen.'
        END AS RecommendedAction
    FROM Normalized AS n

    UNION ALL

    SELECT
        n.SampleId,
        n.SampleLabel,
        n.RawValue,
        n.TrimmedValue,
        n.IntendedFamily,
        n.Notes,
        n.CharacterLength,
        n.ByteLength,
        'DECIMAL(18,4)',
        'TRY_CAST decimal',
        CASE WHEN n.IsNullValue = 0 AND n.IsBlankValue = 0 AND TRY_CAST(n.TrimmedValue AS DECIMAL(18,4)) IS NOT NULL THEN 1 ELSE 0 END,
        CASE WHEN n.IsNullValue = 0 AND n.IsBlankValue = 0 AND (n.LooksLikeDecimalComma = 1 OR n.TrimmedValue LIKE N'%EUR%') THEN 1 ELSE 0 END,
        CASE
            WHEN n.IsNullValue = 1 THEN 'null-value'
            WHEN n.IsBlankValue = 1 THEN 'blank-value'
            WHEN TRY_CAST(n.TrimmedValue AS DECIMAL(18,4)) IS NOT NULL THEN 'cast-ok'
            WHEN n.LooksLikeDecimalComma = 1 THEN 'decimal-comma-locale'
            WHEN n.TrimmedValue LIKE N'%EUR%' OR n.TrimmedValue LIKE N'%$%' THEN 'currency-symbol'
            WHEN PATINDEX(N'%[^0-9,.+-]%', n.TrimmedValue) > 0 THEN 'non-numeric-characters'
            ELSE 'precision-or-format-issue'
        END,
        CASE
            WHEN n.IsNullValue = 1 THEN 'NULL vor dem Profiling getrennt behandeln.'
            WHEN n.IsBlankValue = 1 THEN 'Blank-Werte trimmen und auf NULL oder Fehlerstatus mappen.'
            WHEN TRY_CAST(n.TrimmedValue AS DECIMAL(18,4)) IS NOT NULL THEN 'Keine Bereinigung erforderlich.'
            WHEN n.LooksLikeDecimalComma = 1 THEN 'Dezimalkomma vor invariantem DECIMAL-Cast in Dezimalpunkt ueberfuehren.'
            WHEN n.TrimmedValue LIKE N'%EUR%' OR n.TrimmedValue LIKE N'%$%' THEN 'Waehrungssymbole vor der Konvertierung entfernen oder separat speichern.'
            ELSE 'Numerische Tokens normalisieren und dann erneut pruefen.'
        END
    FROM Normalized AS n

    UNION ALL

    SELECT
        n.SampleId,
        n.SampleLabel,
        n.RawValue,
        n.TrimmedValue,
        n.IntendedFamily,
        n.Notes,
        n.CharacterLength,
        n.ByteLength,
        'DATE',
        'TRY_CONVERT style 23',
        CASE WHEN n.IsNullValue = 0 AND n.IsBlankValue = 0 AND TRY_CONVERT(DATE, n.TrimmedValue, 23) IS NOT NULL THEN 1 ELSE 0 END,
        CASE WHEN n.IsNullValue = 0 AND n.IsBlankValue = 0 AND (TRY_CONVERT(DATE, n.TrimmedValue, 104) IS NOT NULL OR n.UsesSlashDelimiter = 1) THEN 1 ELSE 0 END,
        CASE
            WHEN n.IsNullValue = 1 THEN 'null-value'
            WHEN n.IsBlankValue = 1 THEN 'blank-value'
            WHEN TRY_CONVERT(DATE, n.TrimmedValue, 23) IS NOT NULL THEN 'cast-ok'
            WHEN TRY_CONVERT(DATE, n.TrimmedValue, 104) IS NOT NULL THEN 'other-date-style-match'
            WHEN n.UsesSlashDelimiter = 1 THEN 'slash-date-ambiguous'
            ELSE 'invalid-iso-date'
        END,
        CASE
            WHEN n.IsNullValue = 1 THEN 'NULL vor dem Profiling getrennt behandeln.'
            WHEN n.IsBlankValue = 1 THEN 'Blank-Werte trimmen und auf NULL oder Fehlerstatus mappen.'
            WHEN TRY_CONVERT(DATE, n.TrimmedValue, 23) IS NOT NULL THEN 'Keine Bereinigung erforderlich.'
            WHEN TRY_CONVERT(DATE, n.TrimmedValue, 104) IS NOT NULL THEN 'Fuer ISO-Pipelines vorher in yyyy-mm-dd normalisieren.'
            WHEN n.UsesSlashDelimiter = 1 THEN 'Slash-Daten nur mit expliziter Formatentscheidung akzeptieren.'
            ELSE 'Datumsbestandteile validieren und in ISO-Format ueberfuehren.'
        END
    FROM Normalized AS n

    UNION ALL

    SELECT
        n.SampleId,
        n.SampleLabel,
        n.RawValue,
        n.TrimmedValue,
        n.IntendedFamily,
        n.Notes,
        n.CharacterLength,
        n.ByteLength,
        'DATE',
        'TRY_CONVERT style 104',
        CASE WHEN n.IsNullValue = 0 AND n.IsBlankValue = 0 AND TRY_CONVERT(DATE, n.TrimmedValue, 104) IS NOT NULL THEN 1 ELSE 0 END,
        CASE WHEN n.IsNullValue = 0 AND n.IsBlankValue = 0 AND (TRY_CONVERT(DATE, n.TrimmedValue, 23) IS NOT NULL OR n.UsesSlashDelimiter = 1) THEN 1 ELSE 0 END,
        CASE
            WHEN n.IsNullValue = 1 THEN 'null-value'
            WHEN n.IsBlankValue = 1 THEN 'blank-value'
            WHEN TRY_CONVERT(DATE, n.TrimmedValue, 104) IS NOT NULL THEN 'cast-ok'
            WHEN TRY_CONVERT(DATE, n.TrimmedValue, 23) IS NOT NULL THEN 'other-date-style-match'
            WHEN n.UsesSlashDelimiter = 1 THEN 'slash-date-ambiguous'
            ELSE 'invalid-german-date'
        END,
        CASE
            WHEN n.IsNullValue = 1 THEN 'NULL vor dem Profiling getrennt behandeln.'
            WHEN n.IsBlankValue = 1 THEN 'Blank-Werte trimmen und auf NULL oder Fehlerstatus mappen.'
            WHEN TRY_CONVERT(DATE, n.TrimmedValue, 104) IS NOT NULL THEN 'Keine Bereinigung erforderlich.'
            WHEN TRY_CONVERT(DATE, n.TrimmedValue, 23) IS NOT NULL THEN 'Fuer DACH-Pipelines gezielt auf dd.mm.yyyy abbilden oder ISO beibehalten.'
            WHEN n.UsesSlashDelimiter = 1 THEN 'Slash-Daten vor dem DACH-Cast in ein eindeutiges Zielmuster ueberfuehren.'
            ELSE 'Datumsbestandteile validieren und in das Zielkulturformat transformieren.'
        END
    FROM Normalized AS n

    UNION ALL

    SELECT
        n.SampleId,
        n.SampleLabel,
        n.RawValue,
        n.TrimmedValue,
        n.IntendedFamily,
        n.Notes,
        n.CharacterLength,
        n.ByteLength,
        'DATETIME2(0)',
        'TRY_CONVERT style 126',
        CASE WHEN n.IsNullValue = 0 AND n.IsBlankValue = 0 AND TRY_CONVERT(DATETIME2(0), n.TrimmedValue, 126) IS NOT NULL THEN 1 ELSE 0 END,
        CASE WHEN n.IsNullValue = 0 AND n.IsBlankValue = 0 AND TRY_CONVERT(DATE, n.TrimmedValue, 23) IS NOT NULL THEN 1 ELSE 0 END,
        CASE
            WHEN n.IsNullValue = 1 THEN 'null-value'
            WHEN n.IsBlankValue = 1 THEN 'blank-value'
            WHEN TRY_CONVERT(DATETIME2(0), n.TrimmedValue, 126) IS NOT NULL THEN 'cast-ok'
            WHEN TRY_CONVERT(DATE, n.TrimmedValue, 23) IS NOT NULL THEN 'date-without-time'
            WHEN n.TrimmedValue LIKE N'%:%' THEN 'invalid-time-component'
            ELSE 'invalid-datetime-token'
        END,
        CASE
            WHEN n.IsNullValue = 1 THEN 'NULL vor dem Profiling getrennt behandeln.'
            WHEN n.IsBlankValue = 1 THEN 'Blank-Werte trimmen und auf NULL oder Fehlerstatus mappen.'
            WHEN TRY_CONVERT(DATETIME2(0), n.TrimmedValue, 126) IS NOT NULL THEN 'Keine Bereinigung erforderlich.'
            WHEN TRY_CONVERT(DATE, n.TrimmedValue, 23) IS NOT NULL THEN 'Zeitanteil ergaenzen oder bewusst nur als DATE weiterverarbeiten.'
            WHEN n.TrimmedValue LIKE N'%:%' THEN 'Zeitkomponenten fachlich validieren und auf ISO-8601 normieren.'
            ELSE 'Nur ISO-8601-Zeitstempel oder klar dokumentierte Alternativen zulassen.'
        END
    FROM Normalized AS n

    UNION ALL

    SELECT
        n.SampleId,
        n.SampleLabel,
        n.RawValue,
        n.TrimmedValue,
        n.IntendedFamily,
        n.Notes,
        n.CharacterLength,
        n.ByteLength,
        'UNIQUEIDENTIFIER',
        'TRY_CAST guid',
        CASE WHEN n.IsNullValue = 0 AND n.IsBlankValue = 0 AND TRY_CAST(n.TrimmedValue AS UNIQUEIDENTIFIER) IS NOT NULL THEN 1 ELSE 0 END,
        CASE WHEN n.IsNullValue = 0 AND n.IsBlankValue = 0 AND n.LooksLikeGuidShape = 1 THEN 1 ELSE 0 END,
        CASE
            WHEN n.IsNullValue = 1 THEN 'null-value'
            WHEN n.IsBlankValue = 1 THEN 'blank-value'
            WHEN TRY_CAST(n.TrimmedValue AS UNIQUEIDENTIFIER) IS NOT NULL THEN 'cast-ok'
            WHEN n.LooksLikeGuidShape = 1 THEN 'guid-shape-but-invalid'
            ELSE 'not-a-guid-token'
        END,
        CASE
            WHEN n.IsNullValue = 1 THEN 'NULL vor dem Profiling getrennt behandeln.'
            WHEN n.IsBlankValue = 1 THEN 'Blank-Werte trimmen und auf NULL oder Fehlerstatus mappen.'
            WHEN TRY_CAST(n.TrimmedValue AS UNIQUEIDENTIFIER) IS NOT NULL THEN 'Keine Bereinigung erforderlich.'
            WHEN n.LooksLikeGuidShape = 1 THEN 'Hex-Zeichen und Bindestriche gegen ein valides GUID-Muster pruefen.'
            ELSE 'Nur echte GUIDs oder klar getrennte Fremdschluesselfelder zulassen.'
        END
    FROM Normalized AS n

    UNION ALL

    SELECT
        n.SampleId,
        n.SampleLabel,
        n.RawValue,
        n.TrimmedValue,
        n.IntendedFamily,
        n.Notes,
        n.CharacterLength,
        n.ByteLength,
        'BIT',
        'TRY_CAST bit',
        CASE WHEN n.IsNullValue = 0 AND n.IsBlankValue = 0 AND TRY_CAST(n.TrimmedValue AS BIT) IS NOT NULL THEN 1 ELSE 0 END,
        CASE WHEN n.IsNullValue = 0 AND n.IsBlankValue = 0 AND LOWER(n.TrimmedValue) IN (N'true', N'false', N'yes', N'no', N'ja', N'nein') THEN 1 ELSE 0 END,
        CASE
            WHEN n.IsNullValue = 1 THEN 'null-value'
            WHEN n.IsBlankValue = 1 THEN 'blank-value'
            WHEN TRY_CAST(n.TrimmedValue AS BIT) IS NOT NULL THEN 'cast-ok'
            WHEN LOWER(n.TrimmedValue) IN (N'true', N'false', N'yes', N'no', N'ja', N'nein') THEN 'semantic-boolean-text'
            ELSE 'not-a-bit-token'
        END,
        CASE
            WHEN n.IsNullValue = 1 THEN 'NULL vor dem Profiling getrennt behandeln.'
            WHEN n.IsBlankValue = 1 THEN 'Blank-Werte trimmen und auf NULL oder Fehlerstatus mappen.'
            WHEN TRY_CAST(n.TrimmedValue AS BIT) IS NOT NULL THEN 'Keine Bereinigung erforderlich.'
            WHEN LOWER(n.TrimmedValue) IN (N'true', N'false', N'yes', N'no', N'ja', N'nein') THEN 'Texttokens vor dem BIT-Cast auf 1 oder 0 mappen.'
            ELSE 'Nur dokumentierte Boolean-Tokens akzeptieren.'
        END
    FROM Normalized AS n
),
Summary AS
(
    SELECT
        cp.TargetType,
        cp.ConversionMode,
        COUNT(*) AS TotalRows,
        SUM(CASE WHEN cp.FailureBucket = 'null-value' THEN 1 ELSE 0 END) AS NullRows,
        SUM(CASE WHEN cp.FailureBucket = 'blank-value' THEN 1 ELSE 0 END) AS BlankRows,
        SUM(cp.IsConvertible) AS SuccessRows,
        SUM(CASE WHEN cp.IsConvertible = 0 AND cp.FailureBucket NOT IN ('null-value', 'blank-value') THEN 1 ELSE 0 END) AS FailureRows,
        SUM(CASE WHEN cp.IsConvertible = 0 AND cp.IsNearMiss = 1 THEN 1 ELSE 0 END) AS NearMissRows
    FROM ConversionProfiles AS cp
    GROUP BY
        cp.TargetType,
        cp.ConversionMode
)
SELECT
    s.TargetType,
    s.ConversionMode,
    s.TotalRows,
    s.NullRows,
    s.BlankRows,
    s.SuccessRows,
    s.FailureRows,
    s.NearMissRows,
    COALESCE(CONVERT(DECIMAL(5,2), 100.0 * s.SuccessRows / NULLIF(s.TotalRows - s.NullRows - s.BlankRows, 0)), 0) AS SuccessRatePct,
    COALESCE(CONVERT(DECIMAL(5,2), 100.0 * s.FailureRows / NULLIF(s.TotalRows - s.NullRows - s.BlankRows, 0)), 0) AS FailureRatePct,
    CASE
        WHEN s.FailureRows = 0 THEN 'none'
        WHEN 1.0 * s.FailureRows / NULLIF(s.TotalRows - s.NullRows - s.BlankRows, 0) >= 0.50 THEN 'high'
        WHEN 1.0 * s.FailureRows / NULLIF(s.TotalRows - s.NullRows - s.BlankRows, 0) >= 0.20 THEN 'medium'
        ELSE 'low'
    END AS Severity
FROM Summary AS s
ORDER BY
    CASE
        WHEN s.FailureRows = 0 THEN 4
        WHEN 1.0 * s.FailureRows / NULLIF(s.TotalRows - s.NullRows - s.BlankRows, 0) >= 0.50 THEN 1
        WHEN 1.0 * s.FailureRows / NULLIF(s.TotalRows - s.NullRows - s.BlankRows, 0) >= 0.20 THEN 2
        ELSE 3
    END,
    s.TargetType,
    s.ConversionMode;

SELECT
    cp.TargetType,
    cp.ConversionMode,
    cp.SampleId,
    cp.SampleLabel,
    cp.RawValue,
    cp.IntendedFamily,
    cp.IsConvertible,
    cp.IsNearMiss,
    cp.FailureBucket,
    cp.RecommendedAction,
    cp.CharacterLength,
    cp.ByteLength,
    cp.Notes
FROM ConversionProfiles AS cp
WHERE cp.IsConvertible = 0
ORDER BY
    cp.TargetType,
    cp.ConversionMode,
    cp.SampleId;

SELECT
    cp.TargetType,
    cp.ConversionMode,
    cp.FailureBucket,
    COUNT(*) AS BucketCount,
    MIN(cp.RecommendedAction) AS RecommendedAction,
    MIN(COALESCE(cp.TrimmedValue, N'<NULL>')) AS ExampleValue
FROM ConversionProfiles AS cp
WHERE cp.IsConvertible = 0
GROUP BY
    cp.TargetType,
    cp.ConversionMode,
    cp.FailureBucket
ORDER BY
    cp.TargetType,
    cp.ConversionMode,
    BucketCount DESC,
    cp.FailureBucket;

