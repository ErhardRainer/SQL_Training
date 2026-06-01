# StringLengthVsByteLengthDemo.sql

Dieses Skript zeigt an kleinen Demo-Werten, warum Zeichenlaenge und belegte Bytes in SQL Server nicht dasselbe messen. Der Schwerpunkt liegt auf `LEN()` versus `DATALENGTH()` sowie auf dem Unterschied zwischen `varchar`- und `nvarchar`-Speicherung.

## Uebersicht

<!-- SQLDOC:SUMMARY_TABLE:BEGIN -->
| Feld | Wert |
|---|---|
| Script | [StringLengthVsByteLengthDemo.sql](StringLengthVsByteLengthDemo.sql) |
| Version | `1.0` |
| Typ | `didactic-lab` |
| Kapitel | `12_DataTypes_Conversion` |
| Sicherheit | `read-only-tempdb` |
| Zweck | Zeigt den Unterschied zwischen Zeichenlaenge und Bytebedarf fuer `varchar` und `nvarchar`. |
<!-- SQLDOC:SUMMARY_TABLE:END -->

## Annahmen

Fuer diese Erstversion gelten folgende Annahmen:

- Die Demonstration soll ohne produktive Tabellen auskommen und nur mit eingebauten Beispielwerten arbeiten.
- Der direkte Vergleich von `varchar` und `nvarchar` wird bewusst nur fuer ASCII-sichere Inhalte gezeigt, damit keine codepage-abhaengigen Seiteneffekte die Kernbotschaft verdecken.
- Unicode-spezifische Beispiele wie Umlaut, CJK und Supplementary-Zeichen werden separat als `nvarchar` ausgewiesen.

## Anwendungsfall

Das Skript eignet sich fuer folgende Leitfragen:

- Warum liefert `LEN()` bei Text mit abschliessenden Leerzeichen einen kleineren Wert als `DATALENGTH()`?
- Weshalb kann derselbe sichtbare Inhalt in `nvarchar` mehr Bytes belegen als in `varchar`?
- Welche Hinweise liefern Unicode-Beispiele, wenn sichtbare Zeichenanzahl und Speicherbedarf auseinanderlaufen?

## Parameter

<!-- SQLDOC:PARAMETERS_TABLE:BEGIN -->
| Parameter | SQL-Typ | Pflicht | Beschreibung |
|---|---|---|---|
| `-` | `-` | `-` | Dieses Demoskript verwendet keine Laufzeitparameter. |
<!-- SQLDOC:PARAMETERS_TABLE:END -->

## Abhaengigkeiten

<!-- SQLDOC:DEPENDENCIES_LIST:BEGIN -->
- `LEN()`
- `DATALENGTH()`
- `RTRIM()`
- `UNICODE()`
- `NCHAR()`
<!-- SQLDOC:DEPENDENCIES_LIST:END -->

## Hinweise

- `LEN()` ignoriert abschliessende Leerzeichen, `DATALENGTH()` nicht.
- `varchar` ist fuer reine ASCII-Beispiele meist byte-identisch zur sichtbaren Zeichenlaenge.
- `nvarchar` kann schon bei ASCII-Inhalten mehr Bytes benoetigen, weil Unicode anders gespeichert wird.
- Supplementary-Zeichen werden bewusst separat gezeigt, weil ihre interne Darstellung mehrdeutige Kurzschluesse aus der sichtbaren Laenge vermeiden soll.

## Versionshistorie

<!-- SQLDOC:VERSION_HISTORY_TABLE:BEGIN -->
| Version | Datum | User | Beschreibung |
|---|---|---|---|
| `1.0` | `2026-04-18` | `ER` | Erstversion des Length-vs-ByteLength-Demos |
<!-- SQLDOC:VERSION_HISTORY_TABLE:END -->

## Ablauf

<!-- SQLDOC:MERMAID:BEGIN -->
```mermaid
flowchart TD
    A[Varchar- und Nvarchar-Beispielwerte definieren] --> B[Je Beispiel LEN(), DATALENGTH() und Trailing-Space-Bytes berechnen]
    B --> C{StorageType = nvarchar?}
    C -->|Ja| D[LeadingCodePoint und Unicode-Hinweis ergaenzen]
    C -->|Nein| E[Varchar-Hinweis fuer ASCII oder Trailing Spaces ergaenzen]
    D --> F[LengthMetrics ausgeben]
    E --> F
    A --> G[ASCII-sichere Paare aus varchar und nvarchar zusammenfuehren]
    G --> H[Zeichenlaenge und Bytebedarf direkt vergleichen]
    H --> I[PairwiseStorageComparison ausgeben]
```
<!-- SQLDOC:MERMAID:END -->

## SQL-Code

<!-- SQLDOC:SQL_CODE:BEGIN -->
```sql
/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "StringLengthVsByteLengthDemo.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "12_DataTypes_Conversion"

purpose: >
  Zeigt den Unterschied zwischen Zeichenlaenge und Bytebedarf fuer varchar-
  und nvarchar-Werte. Das Skript vergleicht LEN() und DATALENGTH() an kleinen
  Demo-Beispielen und stellt fuer sichere ASCII-Faelle denselben Inhalt in
  varchar und nvarchar direkt gegenueber.

parameters: []

result_sets:
  - name: "LengthMetrics"
    description: "Zeigt je Beispielwert Zeichenlaenge, Bytebedarf und Interpretation"
  - name: "PairwiseStorageComparison"
    description: "Vergleicht identische Inhalte in varchar und nvarchar fuer direkt vergleichbare Faelle"

dependencies:
  - "LEN()"
  - "DATALENGTH()"
  - "RTRIM()"
  - "UNICODE()"
  - "NCHAR()"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/12_DataTypes_Conversion/SQLScripts/StringLengthVsByteLengthDemo.md"
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
    description: "Erstversion des Length-vs-ByteLength-Demos"

notes:
  - "LEN() ignoriert abschliessende Leerzeichen, DATALENGTH() misst alle gespeicherten Bytes."
  - "Die Demo nutzt nur eingebaute Beispielwerte und keine produktiven Tabellen."
  - "Der direkte varchar-vs-nvarchar-Vergleich wird nur fuer ASCII-sichere Inhalte gezeigt."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

WITH VarcharSamples AS
(
    SELECT
        'ASCII_WORD' AS SampleKey,
        'AsciiWord' AS SampleLabel,
        CAST('DataLab' AS VARCHAR(40)) AS SampleValue,
        'ASCII-Beispiel ohne Sonderzeichen.' AS Notes

    UNION ALL

    SELECT
        'ASCII_SPACES' AS SampleKey,
        'AsciiWithTrailingSpaces' AS SampleLabel,
        CAST('DataLab   ' AS VARCHAR(40)) AS SampleValue,
        'Abschliessende Leerzeichen zaehlen fuer DATALENGTH(), aber nicht fuer LEN().' AS Notes

    UNION ALL

    SELECT
        'ASCII_CODE' AS SampleKey,
        'CodeLikeToken' AS SampleLabel,
        CAST('A1-B2-C3' AS VARCHAR(40)) AS SampleValue,
        'Typischer technischer Token mit gleicher Zeichen- und Byteanzahl in varchar.' AS Notes
),
NvarcharSamples AS
(
    SELECT
        'ASCII_WORD' AS SampleKey,
        'AsciiWord' AS SampleLabel,
        CAST(N'DataLab' AS NVARCHAR(40)) AS SampleValue,
        'ASCII-Inhalt in Unicode-Speicherung.' AS Notes

    UNION ALL

    SELECT
        'ASCII_SPACES' AS SampleKey,
        'AsciiWithTrailingSpaces' AS SampleLabel,
        CAST(N'DataLab   ' AS NVARCHAR(40)) AS SampleValue,
        'Dieselbe Leerzeichen-Situation wie in varchar, aber mit Unicode-Bytes.' AS Notes

    UNION ALL

    SELECT
        'UMLAUT_WORD' AS SampleKey,
        'UmlautWord' AS SampleLabel,
        N'Gr' + NCHAR(252) + NCHAR(223) + N'e' AS SampleValue,
        'Unicode-Beispiel mit Umlaut und Eszett.' AS Notes

    UNION ALL

    SELECT
        'CJK_WORD' AS SampleKey,
        'CjkWord' AS SampleLabel,
        NCHAR(28450) + NCHAR(23383) + NCHAR(36039) AS SampleValue,
        'Unicode-Beispiel mit ostasiatischen Zeichen.' AS Notes

    UNION ALL

    SELECT
        'EMOJI_SUFFIX' AS SampleKey,
        'SupplementaryGlyph' AS SampleLabel,
        N'Data' + NCHAR(55357) + NCHAR(56832) AS SampleValue,
        'Beispiel mit Supplementary-Zeichen in UTF-16-Darstellung.' AS Notes
),
LengthMetrics AS
(
    SELECT
        'varchar' AS StorageType,
        vs.SampleKey,
        vs.SampleLabel,
        CONVERT(NVARCHAR(100), vs.SampleValue) AS DisplayValue,
        LEN(vs.SampleValue) AS CharacterLength,
        DATALENGTH(vs.SampleValue) AS StoredBytes,
        DATALENGTH(vs.SampleValue) - DATALENGTH(RTRIM(vs.SampleValue)) AS TrailingSpaceBytes,
        CAST(
            CASE
                WHEN LEN(vs.SampleValue) = 0 THEN NULL
                ELSE 1.0 * DATALENGTH(vs.SampleValue) / LEN(vs.SampleValue)
            END AS DECIMAL(10,2)
        ) AS BytesPerVisibleCharacter,
        CAST(NULL AS INT) AS LeadingCodePoint,
        CASE
            WHEN DATALENGTH(vs.SampleValue) - DATALENGTH(RTRIM(vs.SampleValue)) > 0
                THEN 'Trailing spaces use bytes although LEN() ignores them.'
            ELSE 'ASCII varchar typically stores one byte per visible character.'
        END AS Observation,
        vs.Notes
    FROM VarcharSamples AS vs

    UNION ALL

    SELECT
        'nvarchar' AS StorageType,
        ns.SampleKey,
        ns.SampleLabel,
        ns.SampleValue AS DisplayValue,
        LEN(ns.SampleValue) AS CharacterLength,
        DATALENGTH(ns.SampleValue) AS StoredBytes,
        DATALENGTH(ns.SampleValue) - DATALENGTH(RTRIM(ns.SampleValue)) AS TrailingSpaceBytes,
        CAST(
            CASE
                WHEN LEN(ns.SampleValue) = 0 THEN NULL
                ELSE 1.0 * DATALENGTH(ns.SampleValue) / LEN(ns.SampleValue)
            END AS DECIMAL(10,2)
        ) AS BytesPerVisibleCharacter,
        UNICODE(LEFT(ns.SampleValue, 1)) AS LeadingCodePoint,
        CASE
            WHEN ns.SampleKey = 'EMOJI_SUFFIX'
                THEN 'Supplementary characters can require multiple UTF-16 code units.'
            WHEN DATALENGTH(ns.SampleValue) - DATALENGTH(RTRIM(ns.SampleValue)) > 0
                THEN 'Unicode stores the trailing spaces too; LEN() still trims them logically.'
            ELSE 'Unicode storage increases byte usage even when the visible length looks similar.'
        END AS Observation,
        ns.Notes
    FROM NvarcharSamples AS ns
),
PairwiseStorageComparison AS
(
    SELECT
        vs.SampleKey,
        vs.SampleLabel,
        vs.SampleValue AS VarcharValue,
        LEN(vs.SampleValue) AS VarcharLength,
        DATALENGTH(vs.SampleValue) AS VarcharBytes,
        ns.SampleValue AS NvarcharValue,
        LEN(ns.SampleValue) AS NvarcharLength,
        DATALENGTH(ns.SampleValue) AS NvarcharBytes,
        DATALENGTH(ns.SampleValue) - DATALENGTH(vs.SampleValue) AS ExtraBytesForUnicode,
        CASE
            WHEN LEN(vs.SampleValue) = LEN(ns.SampleValue)
                THEN 'Visible length is identical, but byte usage differs by storage type.'
            ELSE 'Visible length differs as well, so both metrics need interpretation.'
        END AS ComparisonNote
    FROM VarcharSamples AS vs
    INNER JOIN NvarcharSamples AS ns
        ON ns.SampleKey = vs.SampleKey
)
SELECT
    lm.StorageType,
    lm.SampleLabel,
    lm.DisplayValue,
    lm.CharacterLength,
    lm.StoredBytes,
    lm.TrailingSpaceBytes,
    lm.BytesPerVisibleCharacter,
    lm.LeadingCodePoint,
    lm.Observation,
    lm.Notes
FROM LengthMetrics AS lm
ORDER BY
    CASE lm.StorageType
        WHEN 'varchar' THEN 1
        ELSE 2
    END,
    lm.SampleLabel;

SELECT
    psc.SampleLabel,
    psc.VarcharValue,
    psc.VarcharLength,
    psc.VarcharBytes,
    psc.NvarcharValue,
    psc.NvarcharLength,
    psc.NvarcharBytes,
    psc.ExtraBytesForUnicode,
    psc.ComparisonNote
FROM PairwiseStorageComparison AS psc
ORDER BY psc.SampleLabel;
```
<!-- SQLDOC:SQL_CODE:END -->
