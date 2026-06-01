/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "WhereNullSafeOptionalFilter.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "04_Where"

purpose: >
  Zeigt null-sichere Muster fuer optionale Parameterfilter auf nullable
  Spalten und kontrastiert sie mit dem fehleranfaelligen Shortcut
  Spalte = COALESCE(@Parameter, Spalte).

parameters:
  - name: "@RegionCode"
    sql_type: "CHAR(2)"
    direction: "IN"
    required: false
    description: "Optionaler Regionsfilter; NULL deaktiviert die Regionseinschraenkung"
  - name: "@ManagerFilterMode"
    sql_type: "VARCHAR(20)"
    direction: "IN"
    required: false
    description: "Filtert all, exact oder unassigned fuer den AccountManager"
  - name: "@TargetManager"
    sql_type: "NVARCHAR(80)"
    direction: "IN"
    required: false
    description: "Gesuchter Managername fuer exact; NULL bleibt nur ausserhalb von exact zulaessig"
  - name: "@IncludeUnsafeDemo"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 zeigt zusaetzlich das unsichere Shortcut-Muster, 0 nur das sichere Ergebnis"

result_sets:
  - name: "FilterParameterSnapshot"
    description: "Zeigt aktive Parameter, Modus und die didaktische Bedeutung der NULL-Behandlung"
  - name: "StrategyRows"
    description: "Vergleicht Zeilen der unsicheren und der null-sicheren Filterstrategie auf derselben Demo-Menge"
  - name: "StrategyAssessment"
    description: "Verdichtet je Strategie Trefferzahl, NULL-Anteil und die zentrale Review-Aussage"

dependencies:
  - "tempdb temporary tables"
  - "CASE"
  - "COALESCE"
  - "ROW_NUMBER"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/04_Where/SQLScripts/WhereNullSafeOptionalFilter.md"
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
    description: "Erstversion fuer null-sichere optionale Filter auf nullable Spalten"

notes:
  - "Das Lab arbeitet nur mit tempdb-nahen Demo-Daten und nullable AccountManager-Werten."
  - "Der unsichere Shortcut blendet im all-Modus NULL-Zeilen aus, obwohl fachlich kein Managerfilter aktiv ist."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @RegionCode CHAR(2) = NULL;
DECLARE @ManagerFilterMode VARCHAR(20) = 'all';
DECLARE @TargetManager NVARCHAR(80) = NULL;
DECLARE @IncludeUnsafeDemo BIT = 1;

IF @RegionCode IS NOT NULL AND @RegionCode NOT IN ('DE', 'AT', 'CH')
BEGIN
    THROW 50470, '@RegionCode muss DE, AT, CH oder NULL sein.', 1;
END;

IF @ManagerFilterMode NOT IN ('all', 'exact', 'unassigned')
BEGIN
    THROW 50471, '@ManagerFilterMode muss all, exact oder unassigned sein.', 1;
END;

IF @ManagerFilterMode = 'exact' AND @TargetManager IS NULL
BEGIN
    THROW 50472, '@TargetManager ist fuer ManagerFilterMode = exact erforderlich.', 1;
END;

IF @ManagerFilterMode <> 'exact' AND @TargetManager IS NOT NULL
BEGIN
    THROW 50473, '@TargetManager darf nur zusammen mit ManagerFilterMode = exact gesetzt werden.', 1;
END;

IF @IncludeUnsafeDemo NOT IN (0, 1)
BEGIN
    THROW 50474, '@IncludeUnsafeDemo muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #CustomerPortfolio;
DROP TABLE IF EXISTS #StrategyResults;

CREATE TABLE #CustomerPortfolio
(
    PortfolioID INT NOT NULL PRIMARY KEY,
    CustomerName NVARCHAR(80) NOT NULL,
    RegionCode CHAR(2) NOT NULL,
    AccountManager NVARCHAR(80) NULL,
    RevenueBand VARCHAR(20) NOT NULL,
    RenewalMonth TINYINT NOT NULL
);

CREATE TABLE #StrategyResults
(
    StrategyName VARCHAR(20) NOT NULL,
    PortfolioID INT NOT NULL,
    CustomerName NVARCHAR(80) NOT NULL,
    RegionCode CHAR(2) NOT NULL,
    AccountManager NVARCHAR(80) NULL,
    ManagerState VARCHAR(20) NOT NULL,
    RevenueBand VARCHAR(20) NOT NULL,
    ActiveFilterCount INT NOT NULL,
    PredicateShape NVARCHAR(180) NOT NULL,
    TeachingNote NVARCHAR(220) NOT NULL
);

INSERT INTO #CustomerPortfolio
(
    PortfolioID,
    CustomerName,
    RegionCode,
    AccountManager,
    RevenueBand,
    RenewalMonth
)
VALUES
    (3001, N'Alpenfrost GmbH', 'DE', N'Clara Neumann', 'mid', 1),
    (3002, N'Bodensee Handel AG', 'DE', NULL, 'low', 2),
    (3003, N'City Print GmbH', 'DE', N'Denis Keller', 'high', 3),
    (3004, N'Donau Service GmbH', 'AT', N'Clara Neumann', 'mid', 4),
    (3005, N'Eisgrat Retail AG', 'AT', NULL, 'mid', 4),
    (3006, N'Felsenbau KG', 'AT', N'Emma Vogt', 'high', 5),
    (3007, N'Gletscher Consulting SA', 'CH', NULL, 'low', 6),
    (3008, N'Horizont Technik SA', 'CH', N'Emma Vogt', 'high', 7),
    (3009, N'Inselmarkt GmbH', 'DE', N'Emma Vogt', 'mid', 8),
    (3010, N'Jura Systeme AG', 'CH', N'Denis Keller', 'mid', 9),
    (3011, N'Kuestenlicht GmbH', 'DE', NULL, 'high', 10),
    (3012, N'Limmat Office AG', 'CH', N'Clara Neumann', 'low', 11);

;WITH FilterParameterSnapshot AS
(
    SELECT
        'RegionCode' AS FilterName,
        COALESCE(@RegionCode, 'NULL') AS FilterValue,
        CASE
            WHEN @RegionCode IS NULL THEN 'inactive'
            ELSE 'active'
        END AS FilterState,
        'Optionaler Regionsfilter mit klassischem NULL = kein Filter.' AS TeachingNote

    UNION ALL

    SELECT
        'ManagerFilterMode',
        @ManagerFilterMode,
        'active',
        'Trennt bewusst zwischen all, exact und unassigned.'

    UNION ALL

    SELECT
        'TargetManager',
        COALESCE(CONVERT(VARCHAR(80), @TargetManager), 'NULL'),
        CASE
            WHEN @TargetManager IS NULL THEN 'inactive'
            ELSE 'active'
        END,
        'Wird nur im exact-Modus verwendet, damit NULL nicht doppeldeutig wird.'

    UNION ALL

    SELECT
        'IncludeUnsafeDemo',
        CONVERT(VARCHAR(5), @IncludeUnsafeDemo),
        CASE
            WHEN @IncludeUnsafeDemo = 1 THEN 'active'
            ELSE 'inactive'
        END,
        'Blendet den Review-Gegenvergleich zum fehleranfaelligen Shortcut ein.'
)
SELECT
    fps.FilterName,
    fps.FilterValue,
    fps.FilterState,
    fps.TeachingNote
FROM FilterParameterSnapshot AS fps
ORDER BY
    fps.FilterName;

IF @IncludeUnsafeDemo = 1
BEGIN
    INSERT INTO #StrategyResults
    (
        StrategyName,
        PortfolioID,
        CustomerName,
        RegionCode,
        AccountManager,
        ManagerState,
        RevenueBand,
        ActiveFilterCount,
        PredicateShape,
        TeachingNote
    )
    SELECT
        'unsafe-shortcut' AS StrategyName,
        cp.PortfolioID,
        cp.CustomerName,
        cp.RegionCode,
        cp.AccountManager,
        CASE
            WHEN cp.AccountManager IS NULL THEN 'unassigned'
            ELSE 'assigned'
        END AS ManagerState,
        cp.RevenueBand,
        CASE
            WHEN @RegionCode IS NULL THEN 0 ELSE 1
        END
        + CASE
            WHEN @ManagerFilterMode = 'all' THEN 0 ELSE 1
        END AS ActiveFilterCount,
        N'AccountManager = COALESCE(@TargetManager, AccountManager)' AS PredicateShape,
        N'Im all-Modus gehen NULL-Manager verloren, weil NULL = NULL nicht TRUE wird.' AS TeachingNote
    FROM #CustomerPortfolio AS cp
    WHERE (@RegionCode IS NULL OR cp.RegionCode = @RegionCode)
      AND
      (
          (@ManagerFilterMode IN ('all', 'exact') AND cp.AccountManager = COALESCE(@TargetManager, cp.AccountManager))
          OR (@ManagerFilterMode = 'unassigned' AND cp.AccountManager IS NULL)
      );
END;

INSERT INTO #StrategyResults
(
    StrategyName,
    PortfolioID,
    CustomerName,
    RegionCode,
    AccountManager,
    ManagerState,
    RevenueBand,
    ActiveFilterCount,
    PredicateShape,
    TeachingNote
)
SELECT
    'null-safe' AS StrategyName,
    cp.PortfolioID,
    cp.CustomerName,
    cp.RegionCode,
    cp.AccountManager,
    CASE
        WHEN cp.AccountManager IS NULL THEN 'unassigned'
        ELSE 'assigned'
    END AS ManagerState,
    cp.RevenueBand,
    CASE
        WHEN @RegionCode IS NULL THEN 0 ELSE 1
    END
    + CASE
        WHEN @ManagerFilterMode = 'all' THEN 0 ELSE 1
    END AS ActiveFilterCount,
    N'Expliziter Modus mit all / exact / unassigned und eigener IS NULL-Behandlung' AS PredicateShape,
    N'Der Filter bleibt lesbar und behaelt NULL-Zeilen nur dann, wenn der Modus es vorsieht.' AS TeachingNote
FROM #CustomerPortfolio AS cp
WHERE (@RegionCode IS NULL OR cp.RegionCode = @RegionCode)
  AND
  (
      @ManagerFilterMode = 'all'
      OR (@ManagerFilterMode = 'exact' AND cp.AccountManager = @TargetManager)
      OR (@ManagerFilterMode = 'unassigned' AND cp.AccountManager IS NULL)
  );

SELECT
    ROW_NUMBER() OVER (ORDER BY sr.StrategyName, sr.PortfolioID) AS StrategyRowID,
    sr.StrategyName,
    sr.PortfolioID,
    sr.CustomerName,
    sr.RegionCode,
    sr.AccountManager,
    sr.ManagerState,
    sr.RevenueBand,
    sr.ActiveFilterCount,
    sr.PredicateShape,
    sr.TeachingNote
FROM #StrategyResults AS sr
ORDER BY
    sr.StrategyName,
    sr.PortfolioID;

;WITH StrategyAssessment AS
(
    SELECT
        sr.StrategyName,
        COUNT(*) AS MatchingRows,
        SUM(CASE WHEN sr.AccountManager IS NULL THEN 1 ELSE 0 END) AS NullManagerRows,
        MAX(sr.ActiveFilterCount) AS ActiveFilterCount,
        MIN(sr.PredicateShape) AS PredicateShape,
        MIN(sr.TeachingNote) AS TeachingNote
    FROM #StrategyResults AS sr
    GROUP BY
        sr.StrategyName
)
SELECT
    sa.StrategyName,
    sa.MatchingRows,
    sa.NullManagerRows,
    sa.ActiveFilterCount,
    sa.PredicateShape,
    sa.TeachingNote,
    CASE
        WHEN sa.StrategyName = 'unsafe-shortcut' AND @ManagerFilterMode = 'all' THEN 'Review-Fund: deaktivierter Managerfilter verliert dennoch NULL-Zeilen.'
        WHEN sa.StrategyName = 'unsafe-shortcut' THEN 'Wirkt hier nur zufaellig passend und bleibt fuer Reviews schwerer lesbar.'
        ELSE 'Empfohlenes Muster: Modus separat ausdruecken und NULL explizit ueber IS NULL behandeln.'
    END AS ReviewConclusion
FROM StrategyAssessment AS sa
ORDER BY
    CASE sa.StrategyName
        WHEN 'unsafe-shortcut' THEN 1
        ELSE 2
    END;
