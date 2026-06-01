/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "WhereBooleanPrecedenceLab.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "04_Where"

purpose: >
  Demonstriert anhand einer kleinen Demo-Menge, wie SQL Server AND vor
  OR auswertet und warum Klammern bei gemischten Filterketten die
  fachliche Lesart und die resultierende Treffermenge veraendern koennen.

parameters:
  - name: "@RegionCode"
    sql_type: "CHAR(2)"
    direction: "IN"
    required: false
    description: "Region, die als linker Pflichtfilter in den Vergleichspraedikaten dient"
  - name: "@PriorityStage"
    sql_type: "VARCHAR(20)"
    direction: "IN"
    required: false
    description: "Stage-Wert fuer den linken AND-Zweig"
  - name: "@VipOverride"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = VIP-Leads duerfen ueber den OR-Zweig als Override wirken"

result_sets:
  - name: "PredicateCatalog"
    description: "Zeigt die drei verglichenen Filterformen samt Lesart und aktiven Vergleichswerten"
  - name: "LeadEvaluation"
    description: "Bewertet jede Demo-Zeile gegen die drei Filterformen und zeigt die atomaren Wahrheitswerte"
  - name: "PredicateSummary"
    description: "Verdichtet Treffermengen, Unterschiede und Lead-Signaturen pro Filterform"

dependencies:
  - "tempdb temporary tables"
  - "CASE"
  - "ROW_NUMBER"
  - "STRING_AGG"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/04_Where/SQLScripts/WhereBooleanPrecedenceLab.md"
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
    date: "2026-04-19"
    user: "ER"
    description: "Erstversion fuer ein didaktisches Lab zur AND/OR-Praezedenz in WHERE-Ketten"

notes:
  - "Das Skript arbeitet ausschliesslich mit einer tempdb-nahen Temp-Tabelle."
  - "Unparenthesized ist absichtlich gleich zu GroupedDefault, weil SQL Server AND vor OR bindet."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @RegionCode CHAR(2) = 'DE';
DECLARE @PriorityStage VARCHAR(20) = 'Open';
DECLARE @VipOverride BIT = 1;

IF @RegionCode IS NOT NULL AND @RegionCode NOT IN ('DE', 'AT', 'CH')
BEGIN
    THROW 50470, '@RegionCode muss NULL, DE, AT oder CH sein.', 1;
END;

IF @PriorityStage IS NOT NULL AND @PriorityStage NOT IN ('Open', 'Qualified', 'Closed')
BEGIN
    THROW 50471, '@PriorityStage muss NULL, Open, Qualified oder Closed sein.', 1;
END;

IF @VipOverride NOT IN (0, 1)
BEGIN
    THROW 50472, '@VipOverride muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #LeadPipeline;
DROP TABLE IF EXISTS #PredicateCatalog;
DROP TABLE IF EXISTS #LeadEvaluation;

CREATE TABLE #LeadPipeline
(
    LeadID INT NOT NULL PRIMARY KEY,
    CompanyName NVARCHAR(80) NOT NULL,
    RegionCode CHAR(2) NOT NULL,
    LeadStage VARCHAR(20) NOT NULL,
    IsVip BIT NOT NULL,
    EstimatedValue DECIMAL(10, 2) NOT NULL,
    OwnerName NVARCHAR(80) NOT NULL
);

CREATE TABLE #PredicateCatalog
(
    PredicateName VARCHAR(30) NOT NULL PRIMARY KEY,
    PredicateExpression NVARCHAR(160) NOT NULL,
    TeachingReading NVARCHAR(220) NOT NULL,
    ActiveRegion CHAR(2) NULL,
    ActiveStage VARCHAR(20) NULL,
    ActiveVipOverride VARCHAR(10) NOT NULL
);

CREATE TABLE #LeadEvaluation
(
    PredicateName VARCHAR(30) NOT NULL,
    MatchRank INT NOT NULL,
    LeadID INT NOT NULL,
    CompanyName NVARCHAR(80) NOT NULL,
    RegionCode CHAR(2) NOT NULL,
    LeadStage VARCHAR(20) NOT NULL,
    IsVip BIT NOT NULL,
    EstimatedValue DECIMAL(10, 2) NOT NULL,
    RegionMatches BIT NOT NULL,
    StageMatches BIT NOT NULL,
    VipMatches BIT NOT NULL,
    PredicateMatched BIT NOT NULL,
    ReadingHint NVARCHAR(220) NOT NULL
);

INSERT INTO #LeadPipeline
(
    LeadID,
    CompanyName,
    RegionCode,
    LeadStage,
    IsVip,
    EstimatedValue,
    OwnerName
)
VALUES
    (4101, N'Alpenmarkt GmbH', 'DE', 'Open', 0, 180.00, N'Lea Sommer'),
    (4102, N'Bergblick AG', 'AT', 'Open', 1, 240.00, N'Mark Weber'),
    (4103, N'City Office KG', 'DE', 'Qualified', 1, 510.00, N'Sarah Klein'),
    (4104, N'Delta Handel SA', 'CH', 'Qualified', 0, 320.00, N'Lea Sommer'),
    (4105, N'Elbe Service GmbH', 'DE', 'Closed', 0, 95.00, N'Mark Weber'),
    (4106, N'Foxtrot Stores AG', 'AT', 'Closed', 1, 130.00, N'Sarah Klein'),
    (4107, N'Gipfel Technik AG', 'DE', 'Open', 1, 640.00, N'Lea Sommer'),
    (4108, N'Hafenbedarf GmbH', 'CH', 'Open', 0, 275.00, N'Mark Weber');

INSERT INTO #PredicateCatalog
(
    PredicateName,
    PredicateExpression,
    TeachingReading,
    ActiveRegion,
    ActiveStage,
    ActiveVipOverride
)
VALUES
    (
        'Unparenthesized',
        N'RegionCode = @RegionCode AND LeadStage = @PriorityStage OR IsVip = 1',
        N'Ohne Klammern bindet SQL zuerst AND und behandelt VIP danach als separaten OR-Override.',
        @RegionCode,
        @PriorityStage,
        CASE WHEN @VipOverride = 1 THEN 'enabled' ELSE 'disabled' END
    ),
    (
        'GroupedDefault',
        N'(RegionCode = @RegionCode AND LeadStage = @PriorityStage) OR IsVip = 1',
        N'Diese Form macht die Standardpraezedenz sichtbar und ist logisch identisch zur ungeklammerten Variante.',
        @RegionCode,
        @PriorityStage,
        CASE WHEN @VipOverride = 1 THEN 'enabled' ELSE 'disabled' END
    ),
    (
        'RegionScoped',
        N'RegionCode = @RegionCode AND (LeadStage = @PriorityStage OR IsVip = 1)',
        N'Diese Klammerung zwingt den Region-Filter fuer beide rechten Alternativen und liefert daher meist weniger Treffer.',
        @RegionCode,
        @PriorityStage,
        CASE WHEN @VipOverride = 1 THEN 'enabled' ELSE 'disabled' END
    );

;WITH LeadTruth AS
(
    SELECT
        lp.LeadID,
        lp.CompanyName,
        lp.RegionCode,
        lp.LeadStage,
        lp.IsVip,
        lp.EstimatedValue,
        RegionMatches =
            CAST
            (
                CASE
                    WHEN @RegionCode IS NULL OR lp.RegionCode = @RegionCode THEN 1
                    ELSE 0
                END
                AS BIT
            ),
        StageMatches =
            CAST
            (
                CASE
                    WHEN @PriorityStage IS NULL OR lp.LeadStage = @PriorityStage THEN 1
                    ELSE 0
                END
                AS BIT
            ),
        VipMatches =
            CAST
            (
                CASE
                    WHEN @VipOverride = 1 AND lp.IsVip = 1 THEN 1
                    ELSE 0
                END
                AS BIT
            )
    FROM #LeadPipeline AS lp
),
PredicateEvaluation AS
(
    SELECT
        PredicateName = 'Unparenthesized',
        lt.LeadID,
        lt.CompanyName,
        lt.RegionCode,
        lt.LeadStage,
        lt.IsVip,
        lt.EstimatedValue,
        lt.RegionMatches,
        lt.StageMatches,
        lt.VipMatches,
        PredicateMatched =
            CAST
            (
                CASE
                    WHEN (lt.RegionMatches = 1 AND lt.StageMatches = 1) OR lt.VipMatches = 1 THEN 1
                    ELSE 0
                END
                AS BIT
            ),
        ReadingHint = N'Entspricht der echten SQL-Standardpraezedenz: AND vor OR.'
    FROM LeadTruth AS lt

    UNION ALL

    SELECT
        'GroupedDefault',
        lt.LeadID,
        lt.CompanyName,
        lt.RegionCode,
        lt.LeadStage,
        lt.IsVip,
        lt.EstimatedValue,
        lt.RegionMatches,
        lt.StageMatches,
        lt.VipMatches,
        CAST
        (
            CASE
                WHEN (lt.RegionMatches = 1 AND lt.StageMatches = 1) OR lt.VipMatches = 1 THEN 1
                ELSE 0
            END
            AS BIT
        ),
        N'Macht dieselbe Bindung mit Klammern explizit und ist daher die Kontrollvariante.'
    FROM LeadTruth AS lt

    UNION ALL

    SELECT
        'RegionScoped',
        lt.LeadID,
        lt.CompanyName,
        lt.RegionCode,
        lt.LeadStage,
        lt.IsVip,
        lt.EstimatedValue,
        lt.RegionMatches,
        lt.StageMatches,
        lt.VipMatches,
        CAST
        (
            CASE
                WHEN lt.RegionMatches = 1 AND (lt.StageMatches = 1 OR lt.VipMatches = 1) THEN 1
                ELSE 0
            END
            AS BIT
        ),
        N'Zwingt den Region-Filter auch fuer VIP-Leads und grenzt den Override damit enger ein.'
    FROM LeadTruth AS lt
)
INSERT INTO #LeadEvaluation
(
    PredicateName,
    MatchRank,
    LeadID,
    CompanyName,
    RegionCode,
    LeadStage,
    IsVip,
    EstimatedValue,
    RegionMatches,
    StageMatches,
    VipMatches,
    PredicateMatched,
    ReadingHint
)
SELECT
    pe.PredicateName,
    ROW_NUMBER() OVER
    (
        PARTITION BY pe.PredicateName
        ORDER BY
            pe.PredicateMatched DESC,
            pe.LeadID
    ) AS MatchRank,
    pe.LeadID,
    pe.CompanyName,
    pe.RegionCode,
    pe.LeadStage,
    pe.IsVip,
    pe.EstimatedValue,
    pe.RegionMatches,
    pe.StageMatches,
    pe.VipMatches,
    pe.PredicateMatched,
    pe.ReadingHint
FROM PredicateEvaluation AS pe;

SELECT
    pc.PredicateName,
    pc.PredicateExpression,
    pc.TeachingReading,
    ActiveRegion = COALESCE(pc.ActiveRegion, 'ALL'),
    ActiveStage = COALESCE(pc.ActiveStage, 'ALL'),
    pc.ActiveVipOverride
FROM #PredicateCatalog AS pc
ORDER BY
    CASE pc.PredicateName
        WHEN 'Unparenthesized' THEN 1
        WHEN 'GroupedDefault' THEN 2
        ELSE 3
    END;

SELECT
    le.PredicateName,
    le.MatchRank,
    le.LeadID,
    le.CompanyName,
    le.RegionCode,
    le.LeadStage,
    le.IsVip,
    le.EstimatedValue,
    le.RegionMatches,
    le.StageMatches,
    le.VipMatches,
    le.PredicateMatched,
    le.ReadingHint
FROM #LeadEvaluation AS le
ORDER BY
    CASE le.PredicateName
        WHEN 'Unparenthesized' THEN 1
        WHEN 'GroupedDefault' THEN 2
        ELSE 3
    END,
    le.MatchRank,
    le.LeadID;

WITH MatchSummary AS
(
    SELECT
        le.PredicateName,
        MatchCount = SUM(CASE WHEN le.PredicateMatched = 1 THEN 1 ELSE 0 END),
        VipMatchesIncluded = SUM(CASE WHEN le.PredicateMatched = 1 AND le.IsVip = 1 THEN 1 ELSE 0 END),
        NonRegionOverrides =
            SUM
            (
                CASE
                    WHEN le.PredicateMatched = 1 AND le.RegionMatches = 0 AND le.VipMatches = 1 THEN 1
                    ELSE 0
                END
            ),
        LeadSignature =
            STRING_AGG
            (
                CASE
                    WHEN le.PredicateMatched = 1 THEN CONVERT(VARCHAR(12), le.LeadID)
                    ELSE NULL
                END,
                ','
            ) WITHIN GROUP (ORDER BY le.LeadID)
    FROM #LeadEvaluation AS le
    GROUP BY
        le.PredicateName
)
SELECT
    ms.PredicateName,
    ms.MatchCount,
    ms.VipMatchesIncluded,
    ms.NonRegionOverrides,
    ms.LeadSignature,
    ComparisonToDefault =
        CASE
            WHEN ms.PredicateName = 'GroupedDefault' THEN 'default-signature'
            WHEN ms.LeadSignature =
                 MAX(CASE WHEN ms.PredicateName = 'GroupedDefault' THEN ms.LeadSignature END) OVER ()
                THEN 'same-as-default'
            ELSE 'different-from-default'
        END
FROM MatchSummary AS ms
ORDER BY
    CASE ms.PredicateName
        WHEN 'Unparenthesized' THEN 1
        WHEN 'GroupedDefault' THEN 2
        ELSE 3
    END;
