/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "CollationCastImpactDemo.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "12_DataTypes_Conversion"

purpose: >
  Demonstriert Seiteneffekte von Kollations- und Typwechseln auf Vergleiche
  und Sortierung. Das Skript stellt dieselben Beispielwerte unter einer
  accent-insensitiven Unicode-Kollation, einer binaeren Kollation und nach
  einem Cast nach VARCHAR gegenueber.

parameters: []

result_sets:
  - name: "ComparisonMatrix"
    description: "Paarweiser Vergleich derselben Texte unter drei Vergleichsstrategien"
  - name: "SortPreview"
    description: "Sortiervorschau fuer Unicode, binaere Kollation und VARCHAR-Cast"
  - name: "CastPreview"
    description: "Zeigt Unicode-, VARCHAR- und Hex-Darstellung der Beispielwerte"

dependencies:
  - "COLLATE"
  - "CONVERT()"
  - "UNICODE()"
  - "ROW_NUMBER()"
  - "sys.fn_varbintohexstr()"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/12_DataTypes_Conversion/SQLScripts/CollationCastImpactDemo.md"
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
    description: "Erstversion des Kollations- und Cast-Impact-Demos"

notes:
  - "Die Demo nutzt nur eingebaute Beispielwerte und keine produktiven Tabellen."
  - "Die accent-insensitive Sicht verwendet Latin1_General_100_CI_AI."
  - "Der VARCHAR-Cast nutzt SQL_Latin1_General_CP1_CI_AS als codepage-basierte Vergleichssicht."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DROP TABLE IF EXISTS #Samples;

CREATE TABLE #Samples
(
    SampleId   INT            NOT NULL PRIMARY KEY,
    SampleLabel VARCHAR(30)   NOT NULL,
    SampleText NVARCHAR(100)  NOT NULL,
    Notes      VARCHAR(200)   NOT NULL
);

INSERT INTO #Samples
(
    SampleId,
    SampleLabel,
    SampleText,
    Notes
)
VALUES
    (1, 'CafePlain',     N'Cafe',   'ASCII-Basiswert ohne Akzent oder Gross-/Kleinschreibungseffekt.'),
    (2, 'CafeAccent',    N'Caf' + NCHAR(233),   'Akzentvariante fuer accent-sensitive und accent-insensitive Vergleiche.'),
    (3, 'CafeLower',     N'cafe',   'Kleinschreibungsvariante fuer case-insensitive Kollationen.'),
    (4, 'AlphaGerman',   N'Apfel',  'Einfacher Referenzwert fuer Sortiervergleiche.'),
    (5, 'AlphaUmlaut',   NCHAR(196) + N'pfel',  'Umlautbeispiel fuer sprachliche Sortierung und Codepage-Cast.'),
    (6, 'EmojiSuffix',   N'Data' + NCHAR(55357) + NCHAR(56832), 'Supplementary-Zeichen, das beim VARCHAR-Cast typischerweise ersetzt wird.');

WITH SampleVariants AS
(
    SELECT
        s.SampleId,
        s.SampleLabel,
        s.SampleText,
        s.SampleText COLLATE Latin1_General_100_CI_AI AS UnicodeCiAiText,
        s.SampleText COLLATE Latin1_General_100_BIN2 AS BinaryText,
        CONVERT(VARCHAR(100), s.SampleText) COLLATE SQL_Latin1_General_CP1_CI_AS AS CastVarcharText,
        sys.fn_varbintohexstr(CONVERT(VARBINARY(200), s.SampleText)) AS UnicodeHex,
        sys.fn_varbintohexstr(CONVERT(VARBINARY(200), CONVERT(VARCHAR(100), s.SampleText))) AS VarcharHex,
        s.Notes
    FROM #Samples AS s
),
ComparisonPairs AS
(
    SELECT
        left_sample.SampleLabel AS LeftLabel,
        left_sample.SampleText AS LeftText,
        right_sample.SampleLabel AS RightLabel,
        right_sample.SampleText AS RightText,
        CASE
            WHEN left_sample.UnicodeCiAiText = right_sample.UnicodeCiAiText THEN 1
            ELSE 0
        END AS EqualsUnderCiAi,
        CASE
            WHEN left_sample.BinaryText = right_sample.BinaryText THEN 1
            ELSE 0
        END AS EqualsUnderBin2,
        CASE
            WHEN left_sample.CastVarcharText = right_sample.CastVarcharText THEN 1
            ELSE 0
        END AS EqualsAfterVarcharCast,
        left_sample.CastVarcharText AS LeftAfterCast,
        right_sample.CastVarcharText AS RightAfterCast
    FROM SampleVariants AS left_sample
    INNER JOIN SampleVariants AS right_sample
        ON left_sample.SampleId < right_sample.SampleId
),
SortScenarios AS
(
    SELECT
        'Unicode_CI_AI' AS SortScenario,
        sv.SampleLabel,
        sv.SampleText,
        sv.SampleText COLLATE Latin1_General_100_CI_AI AS SortText,
        sv.Notes
    FROM SampleVariants AS sv

    UNION ALL

    SELECT
        'Unicode_BIN2' AS SortScenario,
        sv.SampleLabel,
        sv.SampleText,
        sv.SampleText COLLATE Latin1_General_100_BIN2 AS SortText,
        sv.Notes
    FROM SampleVariants AS sv

    UNION ALL

    SELECT
        'Cast_to_VARCHAR_CP1_CI_AS' AS SortScenario,
        sv.SampleLabel,
        sv.SampleText,
        CONVERT(NVARCHAR(100), sv.CastVarcharText) COLLATE SQL_Latin1_General_CP1_CI_AS AS SortText,
        sv.Notes
    FROM SampleVariants AS sv
)
SELECT
    cp.LeftLabel,
    cp.LeftText,
    cp.RightLabel,
    cp.RightText,
    cp.EqualsUnderCiAi,
    cp.EqualsUnderBin2,
    cp.EqualsAfterVarcharCast,
    cp.LeftAfterCast,
    cp.RightAfterCast
FROM ComparisonPairs AS cp
ORDER BY
    cp.LeftLabel,
    cp.RightLabel;

SELECT
    ss.SortScenario,
    ROW_NUMBER() OVER
    (
        PARTITION BY ss.SortScenario
        ORDER BY
            ss.SortText,
            ss.SampleLabel
    ) AS SortPosition,
    ss.SampleLabel,
    ss.SampleText,
    ss.SortText,
    ss.Notes
FROM SortScenarios AS ss
ORDER BY
    ss.SortScenario,
    SortPosition;

SELECT
    sv.SampleLabel,
    sv.SampleText,
    sv.CastVarcharText,
    sv.UnicodeHex,
    sv.VarcharHex,
    UNICODE(LEFT(sv.SampleText, 1)) AS FirstCodePoint,
    sv.Notes
FROM SampleVariants AS sv
ORDER BY
    sv.SampleId;
