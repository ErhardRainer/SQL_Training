/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "FunctionWhitespaceCleanupDemo.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "05_Funktionen"

purpose: >
  Demonstriert, wie Leerzeichen, Tabs, Zeilenumbrueche und ausgewaehlte
  unsichtbare Unicode-Zeichen in T-SQL sichtbar gemacht, bereinigt und
  fuer spaetere Stringvergleiche vereinheitlicht werden koennen.

parameters:
  - name: "@CleanupMode"
    sql_type: "VARCHAR(20)"
    direction: "IN"
    required: false
    description: "Steuert all, trim-only oder normalize"
  - name: "@ReplaceTabsWithSpace"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 ersetzt Tabs und Zeilenumbrueche durch Leerzeichen, 0 laesst sie im Zwischenschritt stehen"
  - name: "@ShowOnlyChanged"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 zeigt nur Zeilen mit tatsaechlicher Bereinigung, 0 zeigt den gesamten Demo-Katalog"

result_sets:
  - name: "WhitespaceCleanupPreview"
    description: "Zeigt Rohtext, sichtbare Marker und bereinigte Varianten pro Demo-Zeile"
  - name: "WhitespaceIssueSummary"
    description: "Aggregiert die Demo-Zeilen nach gefundenen Problemtypen"
  - name: "FunctionEffectMatrix"
    description: "Vergleicht den Effekt einzelner Bereinigungsschritte fuer jede Zeile"

dependencies:
  - "tempdb temporary tables"
  - "CASE"
  - "CHAR"
  - "DATALENGTH"
  - "LEN"
  - "LTRIM"
  - "REPLACE"
  - "RTRIM"
  - "STRING_AGG"
  - "TRIM"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/05_Funktionen/SQLScripts/FunctionWhitespaceCleanupDemo.md"
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
    description: "Erstversion fuer eine didaktische Demo zur Bereinigung von Leerzeichen und unsichtbaren Zeichen"

notes:
  - "Das Skript arbeitet mit einem kleinen Demo-Katalog in einer temporaeren Tabelle."
  - "Die Unicode-Zeichen NCHAR(160) und NCHAR(8203) werden bewusst als typische Stolpersteine gezeigt."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @CleanupMode VARCHAR(20) = 'normalize';
DECLARE @ReplaceTabsWithSpace BIT = 1;
DECLARE @ShowOnlyChanged BIT = 0;

IF @CleanupMode NOT IN ('all', 'trim-only', 'normalize')
BEGIN
    THROW 50810, '@CleanupMode muss all, trim-only oder normalize sein.', 1;
END;

IF @ReplaceTabsWithSpace NOT IN (0, 1)
BEGIN
    THROW 50811, '@ReplaceTabsWithSpace muss 0 oder 1 sein.', 1;
END;

IF @ShowOnlyChanged NOT IN (0, 1)
BEGIN
    THROW 50812, '@ShowOnlyChanged muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #WhitespaceSamples;

CREATE TABLE #WhitespaceSamples
(
    SampleId INT NOT NULL PRIMARY KEY,
    SampleGroup VARCHAR(30) NOT NULL,
    RawValue NVARCHAR(200) NOT NULL,
    BusinessMeaning NVARCHAR(120) NOT NULL
);

INSERT INTO #WhitespaceSamples
(
    SampleId,
    SampleGroup,
    RawValue,
    BusinessMeaning
)
VALUES
    (1, 'leading-trailing', N'  Berlin HQ  ', N'Fuehrende und nachfolgende Leerzeichen'),
    (2, 'tabs', N'Order' + CHAR(9) + N'Import', N'Tabulator trennt zwei Wortteile'),
    (3, 'line-breaks', N'Alpha' + CHAR(13) + CHAR(10) + N'Beta', N'Zeilenumbruch innerhalb eines Textwerts'),
    (4, 'double-spaces', N'North  Region   Team', N'Mehrfache innere Leerzeichen'),
    (5, 'non-breaking-space', N'Client' + NCHAR(160) + N'Code', N'Geschuetztes Leerzeichen aus Copy and Paste'),
    (6, 'zero-width-space', N'Invoice' + NCHAR(8203) + N'ID', N'Unsichtbares Unicode-Zeichen ohne sichtbare Breite'),
    (7, 'mixed', N'  Sales' + CHAR(9) + N'Team' + NCHAR(160) + CHAR(13) + CHAR(10) + N'West  ', N'Kombination aus mehreren Problemtypen');

;WITH PreparedSamples AS
(
    SELECT
        src.SampleId,
        src.SampleGroup,
        src.RawValue,
        src.BusinessMeaning,
        REPLACE(
            REPLACE(
                REPLACE(
                    REPLACE(
                        REPLACE(src.RawValue, CHAR(13), '<CR>'),
                        CHAR(10), '<LF>'
                    ),
                    CHAR(9), '<TAB>'
                ),
                NCHAR(160), '<NBSP>'
            ),
            NCHAR(8203), '<ZWSP>'
        ) AS VisibleRawValue,
        LEN(src.RawValue) AS LogicalLength,
        DATALENGTH(src.RawValue) / 2 AS CharacterCount,
        CASE WHEN LEFT(src.RawValue, 1) = N' ' THEN 1 ELSE 0 END AS HasLeadingSpace,
        CASE WHEN RIGHT(src.RawValue, 1) = N' ' THEN 1 ELSE 0 END AS HasTrailingSpace,
        CASE WHEN src.RawValue LIKE N'%' + CHAR(9) + N'%' THEN 1 ELSE 0 END AS HasTab,
        CASE WHEN src.RawValue LIKE N'%' + CHAR(13) + N'%' OR src.RawValue LIKE N'%' + CHAR(10) + N'%' THEN 1 ELSE 0 END AS HasLineBreak,
        CASE WHEN src.RawValue LIKE N'%  %' THEN 1 ELSE 0 END AS HasDoubleSpace,
        CASE WHEN src.RawValue LIKE N'%' + NCHAR(160) + N'%' THEN 1 ELSE 0 END AS HasNbsp,
        CASE WHEN src.RawValue LIKE N'%' + NCHAR(8203) + N'%' THEN 1 ELSE 0 END AS HasZeroWidthSpace
    FROM #WhitespaceSamples AS src
),
NormalizedSteps AS
(
    SELECT
        ps.SampleId,
        ps.SampleGroup,
        ps.RawValue,
        ps.BusinessMeaning,
        ps.VisibleRawValue,
        ps.LogicalLength,
        ps.CharacterCount,
        ps.HasLeadingSpace,
        ps.HasTrailingSpace,
        ps.HasTab,
        ps.HasLineBreak,
        ps.HasDoubleSpace,
        ps.HasNbsp,
        ps.HasZeroWidthSpace,
        LTRIM(RTRIM(ps.RawValue)) AS LtrimRtrimValue,
        TRIM(ps.RawValue) AS TrimValue,
        REPLACE(
            REPLACE(
                REPLACE(ps.RawValue, NCHAR(160), N' '),
                NCHAR(8203), N''
            ),
            NCHAR(9), CASE WHEN @ReplaceTabsWithSpace = 1 THEN N' ' ELSE NCHAR(9) END
        ) AS VisibleWhitespaceNormalized
    FROM PreparedSamples AS ps
),
CollapsedWhitespace AS
(
    SELECT
        ns.SampleId,
        ns.SampleGroup,
        ns.RawValue,
        ns.BusinessMeaning,
        ns.VisibleRawValue,
        ns.LogicalLength,
        ns.CharacterCount,
        ns.HasLeadingSpace,
        ns.HasTrailingSpace,
        ns.HasTab,
        ns.HasLineBreak,
        ns.HasDoubleSpace,
        ns.HasNbsp,
        ns.HasZeroWidthSpace,
        ns.LtrimRtrimValue,
        ns.TrimValue,
        REPLACE(
            REPLACE(
                ns.VisibleWhitespaceNormalized,
                CHAR(13), CASE WHEN @ReplaceTabsWithSpace = 1 THEN N' ' ELSE N'' END
            ),
            CHAR(10), CASE WHEN @ReplaceTabsWithSpace = 1 THEN N' ' ELSE N'' END
        ) AS LinebreakNormalizedValue
    FROM NormalizedSteps AS ns
),
FinalCleanup AS
(
    SELECT
        cw.SampleId,
        cw.SampleGroup,
        cw.RawValue,
        cw.BusinessMeaning,
        cw.VisibleRawValue,
        cw.LogicalLength,
        cw.CharacterCount,
        cw.HasLeadingSpace,
        cw.HasTrailingSpace,
        cw.HasTab,
        cw.HasLineBreak,
        cw.HasDoubleSpace,
        cw.HasNbsp,
        cw.HasZeroWidthSpace,
        cw.LtrimRtrimValue,
        cw.TrimValue,
        cw.LinebreakNormalizedValue,
        TRIM(
            REPLACE(
                REPLACE(
                    REPLACE(
                        REPLACE(cw.LinebreakNormalizedValue, N'   ', N' '),
                        N'  ', N' '
                    ),
                    N'  ', N' '
                ),
                N'  ', N' '
            )
        ) AS FullyNormalizedValue
    FROM CollapsedWhitespace AS cw
),
PreviewRows AS
(
    SELECT
        fc.SampleId,
        fc.SampleGroup,
        fc.BusinessMeaning,
        fc.VisibleRawValue,
        fc.LogicalLength,
        fc.CharacterCount,
        fc.LtrimRtrimValue,
        fc.TrimValue,
        fc.FullyNormalizedValue,
        CASE @CleanupMode
            WHEN 'trim-only' THEN fc.TrimValue
            WHEN 'normalize' THEN fc.FullyNormalizedValue
            ELSE fc.FullyNormalizedValue
        END AS SelectedCleanupValue,
        CASE
            WHEN fc.RawValue <> fc.FullyNormalizedValue THEN 1
            ELSE 0
        END AS WasChanged,
        CONCAT(
            CASE WHEN fc.HasLeadingSpace = 1 THEN 'leading-space; ' ELSE '' END,
            CASE WHEN fc.HasTrailingSpace = 1 THEN 'trailing-space; ' ELSE '' END,
            CASE WHEN fc.HasTab = 1 THEN 'tab; ' ELSE '' END,
            CASE WHEN fc.HasLineBreak = 1 THEN 'line-break; ' ELSE '' END,
            CASE WHEN fc.HasDoubleSpace = 1 THEN 'double-space; ' ELSE '' END,
            CASE WHEN fc.HasNbsp = 1 THEN 'nbsp; ' ELSE '' END,
            CASE WHEN fc.HasZeroWidthSpace = 1 THEN 'zero-width-space; ' ELSE '' END
        ) AS IssueLabelDraft,
        fc.HasLeadingSpace,
        fc.HasTrailingSpace,
        fc.HasTab,
        fc.HasLineBreak,
        fc.HasDoubleSpace,
        fc.HasNbsp,
        fc.HasZeroWidthSpace
    FROM FinalCleanup AS fc
)
SELECT
    pr.SampleId,
    pr.SampleGroup,
    pr.BusinessMeaning,
    pr.VisibleRawValue,
    pr.LogicalLength,
    pr.CharacterCount,
    pr.TrimValue,
    pr.FullyNormalizedValue,
    pr.SelectedCleanupValue,
    CASE
        WHEN LEN(pr.IssueLabelDraft) = 0 THEN 'clean'
        ELSE LEFT(pr.IssueLabelDraft, LEN(pr.IssueLabelDraft) - 2)
    END AS IssueLabels,
    pr.WasChanged
FROM PreviewRows AS pr
WHERE @ShowOnlyChanged = 0
   OR pr.WasChanged = 1
ORDER BY
    pr.SampleId;

SELECT
    issue.IssueType,
    COUNT(*) AS SampleCount,
    STRING_AGG(CONVERT(VARCHAR(10), issue.SampleId), ', ') WITHIN GROUP (ORDER BY issue.SampleId) AS SampleIds
FROM
(
    SELECT pr.SampleId, 'leading-space' AS IssueType FROM PreviewRows AS pr WHERE pr.HasLeadingSpace = 1
    UNION ALL
    SELECT pr.SampleId, 'trailing-space' AS IssueType FROM PreviewRows AS pr WHERE pr.HasTrailingSpace = 1
    UNION ALL
    SELECT pr.SampleId, 'tab' AS IssueType FROM PreviewRows AS pr WHERE pr.HasTab = 1
    UNION ALL
    SELECT pr.SampleId, 'line-break' AS IssueType FROM PreviewRows AS pr WHERE pr.HasLineBreak = 1
    UNION ALL
    SELECT pr.SampleId, 'double-space' AS IssueType FROM PreviewRows AS pr WHERE pr.HasDoubleSpace = 1
    UNION ALL
    SELECT pr.SampleId, 'nbsp' AS IssueType FROM PreviewRows AS pr WHERE pr.HasNbsp = 1
    UNION ALL
    SELECT pr.SampleId, 'zero-width-space' AS IssueType FROM PreviewRows AS pr WHERE pr.HasZeroWidthSpace = 1
) AS issue
GROUP BY
    issue.IssueType
ORDER BY
    SampleCount DESC,
    issue.IssueType;

SELECT
    fc.SampleId,
    fc.SampleGroup,
    fc.VisibleRawValue,
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(fc.LtrimRtrimValue, CHAR(13), '<CR>'), CHAR(10), '<LF>'), CHAR(9), '<TAB>'), NCHAR(160), '<NBSP>'), NCHAR(8203), '<ZWSP>') AS LtrimRtrimVisible,
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(fc.TrimValue, CHAR(13), '<CR>'), CHAR(10), '<LF>'), CHAR(9), '<TAB>'), NCHAR(160), '<NBSP>'), NCHAR(8203), '<ZWSP>') AS TrimVisible,
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(fc.LinebreakNormalizedValue, CHAR(13), '<CR>'), CHAR(10), '<LF>'), CHAR(9), '<TAB>'), NCHAR(160), '<NBSP>'), NCHAR(8203), '<ZWSP>') AS LinebreakNormalizedVisible,
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(fc.FullyNormalizedValue, CHAR(13), '<CR>'), CHAR(10), '<LF>'), CHAR(9), '<TAB>'), NCHAR(160), '<NBSP>'), NCHAR(8203), '<ZWSP>') AS FullyNormalizedVisible
FROM FinalCleanup AS fc
ORDER BY
    fc.SampleId;
