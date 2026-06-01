/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "OptionalFilterPatternDemo.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "04_Where"

purpose: >
  Zeigt typische Muster fuer optionale Parameterfilter in WHERE-Klauseln
  und stellt deren didaktische Planwirkungen fuer statisches OR,
  verzweigtes Branching und OPTION(RECOMPILE) gegenueber.

parameters:
  - name: "@RegionCode"
    sql_type: "CHAR(2)"
    direction: "IN"
    required: false
    description: "Optionaler Regionsfilter; NULL deaktiviert den Regionsteil"
  - name: "@MinNetAmount"
    sql_type: "DECIMAL(10,2)"
    direction: "IN"
    required: false
    description: "Optionale Untergrenze fuer den Nettobetrag; NULL deaktiviert den Betragsfilter"
  - name: "@PriorityOnly"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 beschraenkt die Ergebnisse auf High-Priority-Auftraege"
  - name: "@Mode"
    sql_type: "VARCHAR(20)"
    direction: "IN"
    required: false
    description: "Filtert all, static-or, branching oder recompile"

result_sets:
  - name: "FilterParameterSnapshot"
    description: "Zeigt aktive und inaktive optionale Filter fuer den aktuellen Lauf"
  - name: "StrategyRows"
    description: "Zeigt die Treffermenge je Filterstrategie auf derselben Demo-Datenbasis"
  - name: "StrategyAssessment"
    description: "Verdichtet pro Strategie die didaktische Einschaetzung zu Query-Shape und Planwirkung"

dependencies:
  - "tempdb temporary tables"
  - "IF branching"
  - "CASE"
  - "OPTION(RECOMPILE)"
  - "ROW_NUMBER"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/04_Where/SQLScripts/OptionalFilterPatternDemo.md"
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
    description: "Erstversion fuer didaktische Muster zu optionalen Parameterfiltern"

notes:
  - "Das Skript arbeitet ausschliesslich mit tempdb-Objekten und Demo-Auftragsdaten."
  - "Planwirkungen werden didaktisch eingeordnet und nicht ueber echte Ausfuehrungsplaene vermessen."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @RegionCode CHAR(2) = 'DE';
DECLARE @MinNetAmount DECIMAL(10, 2) = 120.00;
DECLARE @PriorityOnly BIT = 0;
DECLARE @Mode VARCHAR(20) = 'all';

IF @Mode NOT IN ('all', 'static-or', 'branching', 'recompile')
BEGIN
    THROW 50460, '@Mode muss all, static-or, branching oder recompile sein.', 1;
END;

IF @PriorityOnly NOT IN (0, 1)
BEGIN
    THROW 50461, '@PriorityOnly muss 0 oder 1 sein.', 1;
END;

IF @MinNetAmount IS NOT NULL AND @MinNetAmount < 0
BEGIN
    THROW 50462, '@MinNetAmount darf nicht negativ sein.', 1;
END;

IF @RegionCode IS NOT NULL AND @RegionCode NOT IN ('DE', 'AT', 'CH')
BEGIN
    THROW 50463, '@RegionCode muss DE, AT, CH oder NULL sein.', 1;
END;

DROP TABLE IF EXISTS #SalesOrders;
DROP TABLE IF EXISTS #StrategyResults;

CREATE TABLE #SalesOrders
(
    OrderID INT NOT NULL PRIMARY KEY,
    CustomerName NVARCHAR(80) NOT NULL,
    RegionCode CHAR(2) NOT NULL,
    SalesChannel VARCHAR(20) NOT NULL,
    NetAmount DECIMAL(10, 2) NOT NULL,
    PriorityCode CHAR(1) NOT NULL,
    OrderDate DATE NOT NULL
);

CREATE TABLE #StrategyResults
(
    StrategyName VARCHAR(20) NOT NULL,
    OrderID INT NOT NULL,
    CustomerName NVARCHAR(80) NOT NULL,
    RegionCode CHAR(2) NOT NULL,
    SalesChannel VARCHAR(20) NOT NULL,
    NetAmount DECIMAL(10, 2) NOT NULL,
    PriorityCode CHAR(1) NOT NULL,
    ActiveFilterCount INT NOT NULL,
    QueryShapeHint NVARCHAR(160) NOT NULL,
    PlanEffectHint NVARCHAR(220) NOT NULL
);

INSERT INTO #SalesOrders
(
    OrderID,
    CustomerName,
    RegionCode,
    SalesChannel,
    NetAmount,
    PriorityCode,
    OrderDate
)
VALUES
    (2001, N'Alpenmarkt GmbH', 'DE', 'online', 95.00, 'N', '2026-01-08'),
    (2002, N'Bergblick AG', 'AT', 'partner', 180.00, 'H', '2026-01-14'),
    (2003, N'City Retail GmbH', 'DE', 'online', 220.00, 'H', '2026-01-19'),
    (2004, N'Delta Service SA', 'CH', 'field', 130.00, 'N', '2026-01-25'),
    (2005, N'Elbe Office KG', 'DE', 'partner', 145.00, 'N', '2026-02-02'),
    (2006, N'Fjord Handel AG', 'AT', 'online', 310.00, 'H', '2026-02-06'),
    (2007, N'Gipfel Tech GmbH', 'CH', 'field', 85.00, 'N', '2026-02-11'),
    (2008, N'Hafenbedarf GmbH', 'DE', 'field', 410.00, 'H', '2026-02-17'),
    (2009, N'Insel Logistik AG', 'AT', 'partner', 118.00, 'N', '2026-02-24'),
    (2010, N'Jura Consulting SA', 'CH', 'online', 260.00, 'H', '2026-03-03'),
    (2011, N'Kuestenbau GmbH', 'DE', 'partner', 175.00, 'N', '2026-03-09'),
    (2012, N'Limmat Retail AG', 'CH', 'online', 205.00, 'H', '2026-03-14');

;WITH FilterParameterSnapshot AS
(
    SELECT
        'RegionCode' AS FilterName,
        COALESCE(@RegionCode, 'NULL') AS FilterValue,
        CASE
            WHEN @RegionCode IS NULL THEN 'inactive'
            ELSE 'active'
        END AS FilterState,
        'Optionaler Gleichheitsfilter auf RegionCode.' AS TeachingNote

    UNION ALL

    SELECT
        'MinNetAmount',
        COALESCE(CONVERT(VARCHAR(30), @MinNetAmount), 'NULL'),
        CASE
            WHEN @MinNetAmount IS NULL THEN 'inactive'
            ELSE 'active'
        END,
        'Optionaler Range-Filter auf NetAmount.'

    UNION ALL

    SELECT
        'PriorityOnly',
        CONVERT(VARCHAR(5), @PriorityOnly),
        CASE
            WHEN @PriorityOnly = 1 THEN 'active'
            ELSE 'inactive'
        END,
        'Optionaler Bool-Filter fuer High-Priority-Auftraege.'
)
SELECT
    fps.FilterName,
    fps.FilterValue,
    fps.FilterState,
    fps.TeachingNote
FROM FilterParameterSnapshot AS fps
ORDER BY
    fps.FilterName;

IF @Mode IN ('all', 'static-or')
BEGIN
    INSERT INTO #StrategyResults
    (
        StrategyName,
        OrderID,
        CustomerName,
        RegionCode,
        SalesChannel,
        NetAmount,
        PriorityCode,
        ActiveFilterCount,
        QueryShapeHint,
        PlanEffectHint
    )
    SELECT
        'static-or' AS StrategyName,
        so.OrderID,
        so.CustomerName,
        so.RegionCode,
        so.SalesChannel,
        so.NetAmount,
        so.PriorityCode,
        CASE WHEN @RegionCode IS NULL THEN 0 ELSE 1 END
        + CASE WHEN @MinNetAmount IS NULL THEN 0 ELSE 1 END
        + CASE WHEN @PriorityOnly = 1 THEN 1 ELSE 0 END AS ActiveFilterCount,
        N'Ein einziges Statement mit OR-Checks fuer deaktivierte Parameter.' AS QueryShapeHint,
        N'Stabiler Query-Shape, aber bei vielen optionalen Praedikaten oft hoehere Scan-Gefahr.' AS PlanEffectHint
    FROM #SalesOrders AS so
    WHERE (@RegionCode IS NULL OR so.RegionCode = @RegionCode)
      AND (@MinNetAmount IS NULL OR so.NetAmount >= @MinNetAmount)
      AND (@PriorityOnly = 0 OR so.PriorityCode = 'H');
END;

IF @Mode IN ('all', 'branching')
BEGIN
    IF @RegionCode IS NULL AND @MinNetAmount IS NULL AND @PriorityOnly = 0
    BEGIN
        INSERT INTO #StrategyResults
        SELECT
            'branching',
            so.OrderID,
            so.CustomerName,
            so.RegionCode,
            so.SalesChannel,
            so.NetAmount,
            so.PriorityCode,
            0,
            N'Gezielt vereinfachter Pfad ohne WHERE-Filter.',
            N'Branching reduziert unnoetige Praedikate, erhoeht aber die Anzahl gepflegter Query-Pfade.'
        FROM #SalesOrders AS so;
    END;
    ELSE IF @RegionCode IS NOT NULL AND @MinNetAmount IS NULL AND @PriorityOnly = 0
    BEGIN
        INSERT INTO #StrategyResults
        SELECT
            'branching',
            so.OrderID,
            so.CustomerName,
            so.RegionCode,
            so.SalesChannel,
            so.NetAmount,
            so.PriorityCode,
            1,
            N'Spezifischer Pfad nur fuer den RegionCode-Filter.',
            N'Branching kann gezieltere Plaene beguenstigen, wenn haeufig einzelne Filter dominieren.'
        FROM #SalesOrders AS so
        WHERE so.RegionCode = @RegionCode;
    END;
    ELSE IF @RegionCode IS NULL AND @MinNetAmount IS NOT NULL AND @PriorityOnly = 0
    BEGIN
        INSERT INTO #StrategyResults
        SELECT
            'branching',
            so.OrderID,
            so.CustomerName,
            so.RegionCode,
            so.SalesChannel,
            so.NetAmount,
            so.PriorityCode,
            1,
            N'Spezifischer Pfad nur fuer den Range-Filter.',
            N'Branching vermeidet deaktivierte OR-Zweige und macht die Bedingung lesbarer.'
        FROM #SalesOrders AS so
        WHERE so.NetAmount >= @MinNetAmount;
    END;
    ELSE
    BEGIN
        INSERT INTO #StrategyResults
        SELECT
            'branching',
            so.OrderID,
            so.CustomerName,
            so.RegionCode,
            so.SalesChannel,
            so.NetAmount,
            so.PriorityCode,
            CASE WHEN @RegionCode IS NULL THEN 0 ELSE 1 END
            + CASE WHEN @MinNetAmount IS NULL THEN 0 ELSE 1 END
            + CASE WHEN @PriorityOnly = 1 THEN 1 ELSE 0 END,
            N'Gezielter Kombinationspfad fuer die aktuell aktiven Filter.',
            N'Gezieltere Praedikate als static-or, dafuer mehr Verzweigungslogik im Code.'
        FROM #SalesOrders AS so
        WHERE (@RegionCode IS NULL OR so.RegionCode = @RegionCode)
          AND (@MinNetAmount IS NULL OR so.NetAmount >= @MinNetAmount)
          AND (@PriorityOnly = 0 OR so.PriorityCode = 'H');
    END;
END;

IF @Mode IN ('all', 'recompile')
BEGIN
    INSERT INTO #StrategyResults
    (
        StrategyName,
        OrderID,
        CustomerName,
        RegionCode,
        SalesChannel,
        NetAmount,
        PriorityCode,
        ActiveFilterCount,
        QueryShapeHint,
        PlanEffectHint
    )
    SELECT
        'recompile' AS StrategyName,
        so.OrderID,
        so.CustomerName,
        so.RegionCode,
        so.SalesChannel,
        so.NetAmount,
        so.PriorityCode,
        CASE WHEN @RegionCode IS NULL THEN 0 ELSE 1 END
        + CASE WHEN @MinNetAmount IS NULL THEN 0 ELSE 1 END
        + CASE WHEN @PriorityOnly = 1 THEN 1 ELSE 0 END,
        N'Ein Statement mit denselben Filtern, aber frischer Kompilierung pro Lauf.',
        N'OPTION(RECOMPILE) kann bei stark schwankender Selektivitaet helfen, kostet aber zusaetzliche Kompilierung.'
    FROM #SalesOrders AS so
    WHERE (@RegionCode IS NULL OR so.RegionCode = @RegionCode)
      AND (@MinNetAmount IS NULL OR so.NetAmount >= @MinNetAmount)
      AND (@PriorityOnly = 0 OR so.PriorityCode = 'H')
    OPTION (RECOMPILE);
END;

SELECT
    ROW_NUMBER() OVER (ORDER BY sr.StrategyName, sr.OrderID) AS StrategyRowID,
    sr.StrategyName,
    sr.OrderID,
    sr.CustomerName,
    sr.RegionCode,
    sr.SalesChannel,
    sr.NetAmount,
    sr.PriorityCode,
    sr.ActiveFilterCount,
    sr.QueryShapeHint,
    sr.PlanEffectHint
FROM #StrategyResults AS sr
ORDER BY
    sr.StrategyName,
    sr.OrderID;

;WITH StrategyAssessment AS
(
    SELECT
        sr.StrategyName,
        COUNT(*) AS MatchingRows,
        MAX(sr.ActiveFilterCount) AS ActiveFilterCount,
        MIN(sr.QueryShapeHint) AS QueryShapeHint,
        MIN(sr.PlanEffectHint) AS PlanEffectHint
    FROM #StrategyResults AS sr
    GROUP BY
        sr.StrategyName
)
SELECT
    sa.StrategyName,
    sa.MatchingRows,
    sa.ActiveFilterCount,
    sa.QueryShapeHint,
    sa.PlanEffectHint,
    CASE sa.StrategyName
        WHEN 'static-or' THEN 'Guter Startpunkt fuer einfache UIs, aber haeufig erster Kandidat fuer Review.'
        WHEN 'branching' THEN 'Sinnvoll, wenn wenige dominante Filterkombinationen immer wiederkehren.'
        ELSE 'Nuetzlich, wenn Parameterwerte stark streuen und gelegentliche Neukompilierung akzeptabel ist.'
    END AS TeachingRecommendation
FROM StrategyAssessment AS sa
ORDER BY
    CASE sa.StrategyName
        WHEN 'static-or' THEN 1
        WHEN 'branching' THEN 2
        ELSE 3
    END;
