/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "DataFileSizeBalanceReport.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "20_Create_Database"
purpose: >
  Bewertet die Groessenverteilung mehrerer Datenfiles einer Datenbank,
  berechnet die Abweichung von einer gleichmaessigen Verteilung und
  erzeugt lesende Rebalance-Hinweise fuer CREATE-DATABASE-nahe Reviews.

parameters:
  - name: "@DatabaseName"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Datenbank, deren Datenfiles verglichen werden; standardmaessig tempdb"
  - name: "@ImbalanceThresholdPct"
    sql_type: "DECIMAL(5,2)"
    direction: "IN"
    required: false
    description: "Schwelle in Prozentpunkten fuer eine auffaellige Abweichung vom Idealanteil"
  - name: "@ShowRebalanceTemplate"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = erzeugt zusaetzlich didaktische SIZE-Vorlagen pro Datenfile"
  - name: "@MinimumDataFileCount"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Mindestanzahl an Datenfiles, ab der ein echter Balance-Vergleich erwartet wird"

result_sets:
  - name: "DataFileDistribution"
    description: "Zeigt aktuelle Groesse, Anteil und Abweichung jedes Datenfiles vom Gleichverteilungsziel"
  - name: "BalanceSummary"
    description: "Verdichtet Dateianzahl, Gesamtgroesse und Risikoindikatoren fuer die Datenbank"
  - name: "RebalanceTemplate"
    description: "Erzeugt optionale ALTER DATABASE ... MODIFY FILE Vorlagen fuer grob unausgewogene Datenfiles"

dependencies:
  - "sys.databases"
  - "sys.master_files"
  - "tempdb temporary tables"
  - "CASE"
  - "CONCAT"
  - "QUOTENAME"
  - "window functions"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/20_Create_Database/SQLScripts/DataFileSizeBalanceReport.md"
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
    date: "2026-04-22"
    user: "ER"
    description: "Erstversion des Balance-Reports fuer mehrere Datenfiles"

notes:
  - "Die Analyse bleibt bewusst lesend und nutzt nur Metadaten aus sys.master_files."
  - "Die Rebalance-Vorlagen dienen der Review und fuehren keine Aenderungen aus."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

-- 1. Parameter vorbereiten
DECLARE @DatabaseName SYSNAME = N'tempdb';
DECLARE @ImbalanceThresholdPct DECIMAL(5, 2) = 20.00;
DECLARE @ShowRebalanceTemplate BIT = 1;
DECLARE @MinimumDataFileCount INT = 2;

IF DB_ID(@DatabaseName) IS NULL
BEGIN
    THROW 50000, '@DatabaseName verweist auf keine vorhandene Datenbank.', 1;
END;

IF @ImbalanceThresholdPct <= 0 OR @ImbalanceThresholdPct > 100
BEGIN
    THROW 50001, '@ImbalanceThresholdPct muss groesser als 0 und hoechstens 100 sein.', 1;
END;

IF @ShowRebalanceTemplate NOT IN (0, 1)
BEGIN
    THROW 50002, '@ShowRebalanceTemplate muss 0 oder 1 sein.', 1;
END;

IF @MinimumDataFileCount < 1
BEGIN
    THROW 50003, '@MinimumDataFileCount muss mindestens 1 sein.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.databases AS d
    WHERE d.name = @DatabaseName
      AND d.state_desc = 'ONLINE'
)
BEGIN
    THROW 50004, 'Die gewaehlte Datenbank muss ONLINE sein.', 1;
END;

DROP TABLE IF EXISTS #DataFileDistribution;
DROP TABLE IF EXISTS #BalanceSummary;
DROP TABLE IF EXISTS #RebalanceTemplate;

-- 2. Datenfiles inventarisieren und Idealverteilung berechnen
CREATE TABLE #DataFileDistribution
(
    FileOrder INT NOT NULL,
    DatabaseName SYSNAME NOT NULL,
    LogicalFileName SYSNAME NOT NULL,
    PhysicalFileName NVARCHAR(260) NOT NULL,
    FileId INT NOT NULL,
    CurrentSizeMB DECIMAL(18, 2) NOT NULL,
    GrowthDisplay VARCHAR(40) NOT NULL,
    TotalDataSizeMB DECIMAL(18, 2) NOT NULL,
    FileCount INT NOT NULL,
    ActualSharePct DECIMAL(9, 2) NOT NULL,
    IdealSharePct DECIMAL(9, 2) NOT NULL,
    ShareDeltaPct DECIMAL(9, 2) NOT NULL,
    RecommendedTargetSizeMB DECIMAL(18, 2) NOT NULL,
    ReviewSeverity VARCHAR(12) NOT NULL,
    ReviewFocus VARCHAR(260) NOT NULL
);

WITH DataFiles AS
(
    SELECT
        DB_NAME(mf.database_id) AS DatabaseName,
        mf.name AS LogicalFileName,
        mf.physical_name AS PhysicalFileName,
        mf.file_id AS FileId,
        CAST(mf.size / 128.0 AS DECIMAL(18, 2)) AS CurrentSizeMB,
        CASE
            WHEN mf.is_percent_growth = 1 THEN CONCAT(CONVERT(VARCHAR(20), mf.growth), '%')
            ELSE CONCAT(CONVERT(VARCHAR(30), CAST(mf.growth / 128.0 AS DECIMAL(18, 2))), ' MB')
        END AS GrowthDisplay
    FROM sys.master_files AS mf
    WHERE mf.database_id = DB_ID(@DatabaseName)
      AND mf.type_desc = 'ROWS'
),
BalancedView AS
(
    SELECT
        ROW_NUMBER() OVER (ORDER BY df.FileId) AS FileOrder,
        df.DatabaseName,
        df.LogicalFileName,
        df.PhysicalFileName,
        df.FileId,
        df.CurrentSizeMB,
        df.GrowthDisplay,
        SUM(df.CurrentSizeMB) OVER () AS TotalDataSizeMB,
        COUNT(*) OVER () AS FileCount
    FROM DataFiles AS df
)
INSERT INTO #DataFileDistribution
(
    FileOrder,
    DatabaseName,
    LogicalFileName,
    PhysicalFileName,
    FileId,
    CurrentSizeMB,
    GrowthDisplay,
    TotalDataSizeMB,
    FileCount,
    ActualSharePct,
    IdealSharePct,
    ShareDeltaPct,
    RecommendedTargetSizeMB,
    ReviewSeverity,
    ReviewFocus
)
SELECT
    bv.FileOrder,
    bv.DatabaseName,
    bv.LogicalFileName,
    bv.PhysicalFileName,
    bv.FileId,
    bv.CurrentSizeMB,
    bv.GrowthDisplay,
    bv.TotalDataSizeMB,
    bv.FileCount,
    CAST((bv.CurrentSizeMB / NULLIF(bv.TotalDataSizeMB, 0)) * 100.0 AS DECIMAL(9, 2)) AS ActualSharePct,
    CAST(100.0 / NULLIF(bv.FileCount, 0) AS DECIMAL(9, 2)) AS IdealSharePct,
    CAST(
        ABS(
            ((bv.CurrentSizeMB / NULLIF(bv.TotalDataSizeMB, 0)) * 100.0) -
            (100.0 / NULLIF(bv.FileCount, 0))
        ) AS DECIMAL(9, 2)
    ) AS ShareDeltaPct,
    CAST(bv.TotalDataSizeMB / NULLIF(bv.FileCount, 0) AS DECIMAL(18, 2)) AS RecommendedTargetSizeMB,
    CASE
        WHEN bv.FileCount < @MinimumDataFileCount THEN 'info'
        WHEN ABS(
                ((bv.CurrentSizeMB / NULLIF(bv.TotalDataSizeMB, 0)) * 100.0) -
                (100.0 / NULLIF(bv.FileCount, 0))
             ) >= (@ImbalanceThresholdPct * 1.5) THEN 'high'
        WHEN ABS(
                ((bv.CurrentSizeMB / NULLIF(bv.TotalDataSizeMB, 0)) * 100.0) -
                (100.0 / NULLIF(bv.FileCount, 0))
             ) >= @ImbalanceThresholdPct THEN 'medium'
        ELSE 'low'
    END AS ReviewSeverity,
    CASE
        WHEN bv.FileCount < @MinimumDataFileCount THEN 'Es liegen weniger Datenfiles vor als fuer einen echten Balance-Vergleich erwartet.'
        WHEN bv.TotalDataSizeMB = 0 THEN 'Die Datenfiles haben noch keine sinnvoll interpretierbare Groesse fuer eine Balance-Aussage.'
        WHEN bv.CurrentSizeMB > (bv.TotalDataSizeMB / NULLIF(bv.FileCount, 0)) THEN 'Dieses Datenfile ist groesser als der Gleichverteilungszielwert und sollte gegen Wachstumsverhalten und Autogrowth geprueft werden.'
        WHEN bv.CurrentSizeMB < (bv.TotalDataSizeMB / NULLIF(bv.FileCount, 0)) THEN 'Dieses Datenfile liegt unter dem Gleichverteilungsziel und kann auf unausgewogene Initialgroessen oder Wachstumsverteilung hinweisen.'
        ELSE 'Dieses Datenfile liegt nahe an der didaktischen Gleichverteilungsbaseline.'
    END AS ReviewFocus
FROM BalancedView AS bv;

-- 3. Datenbankweite Zusammenfassung und Risikoindikatoren verdichten
CREATE TABLE #BalanceSummary
(
    SummaryLabel VARCHAR(80) NOT NULL,
    SummaryValue VARCHAR(80) NOT NULL,
    Interpretation VARCHAR(260) NOT NULL
);

INSERT INTO #BalanceSummary
(
    SummaryLabel,
    SummaryValue,
    Interpretation
)
SELECT
    'Database name',
    MIN(dfd.DatabaseName),
    'Analysierte Datenbank fuer die Balance-Bewertung.'
FROM #DataFileDistribution AS dfd
UNION ALL
SELECT
    'Data file count',
    CONVERT(VARCHAR(20), MIN(dfd.FileCount)),
    CASE
        WHEN MIN(dfd.FileCount) < @MinimumDataFileCount THEN 'Unterhalb der erwarteten Dateianzahl; das Skript meldet eher Strukturhinweise als echte Lastverteilung.'
        ELSE 'Genug Datenfiles fuer einen Vergleich gegen eine Gleichverteilungsbaseline.'
    END
FROM #DataFileDistribution AS dfd
UNION ALL
SELECT
    'Total data size MB',
    CONVERT(VARCHAR(30), CAST(MIN(dfd.TotalDataSizeMB) AS DECIMAL(18, 2))),
    'Summierte Groesse aller ROWS-Datenfiles laut sys.master_files.'
FROM #DataFileDistribution AS dfd
UNION ALL
SELECT
    'Largest share delta pct',
    CONVERT(VARCHAR(30), CAST(MAX(dfd.ShareDeltaPct) AS DECIMAL(9, 2))),
    CASE
        WHEN MAX(dfd.ShareDeltaPct) >= (@ImbalanceThresholdPct * 1.5) THEN 'Mindestens ein Datenfile weicht deutlich von der Gleichverteilung ab.'
        WHEN MAX(dfd.ShareDeltaPct) >= @ImbalanceThresholdPct THEN 'Die Verteilung ist sichtbar unausgewogen und sollte fuer neue Datenbanken reviewt werden.'
        ELSE 'Die Verteilung liegt im tolerierten didaktischen Korridor.'
    END
FROM #DataFileDistribution AS dfd
UNION ALL
SELECT
    'Review threshold pct',
    CONVERT(VARCHAR(30), CAST(@ImbalanceThresholdPct AS DECIMAL(5, 2))),
    'Ab dieser Abweichung wird ein Datenfile als auffaellig markiert.'
;

-- 4. Optionale Rebalance-Vorlagen fuer auffaellige Datenfiles erzeugen
CREATE TABLE #RebalanceTemplate
(
    CommandOrder INT NOT NULL,
    LogicalFileName SYSNAME NOT NULL,
    PriorityLevel VARCHAR(12) NOT NULL,
    SuggestedSizeMB DECIMAL(18, 2) NOT NULL,
    GeneratedCommand NVARCHAR(MAX) NOT NULL,
    Rationale VARCHAR(260) NOT NULL
);

IF @ShowRebalanceTemplate = 1
BEGIN
    INSERT INTO #RebalanceTemplate
    (
        CommandOrder,
        LogicalFileName,
        PriorityLevel,
        SuggestedSizeMB,
        GeneratedCommand,
        Rationale
    )
    SELECT
        dfd.FileOrder,
        dfd.LogicalFileName,
        dfd.ReviewSeverity,
        dfd.RecommendedTargetSizeMB,
        CONCAT(
            N'ALTER DATABASE ',
            QUOTENAME(@DatabaseName),
            N' MODIFY FILE ( NAME = ',
            QUOTENAME(dfd.LogicalFileName, ''''),
            N', SIZE = ',
            CONVERT(NVARCHAR(30), CAST(dfd.RecommendedTargetSizeMB AS DECIMAL(18, 2))),
            N'MB );'
        ) AS GeneratedCommand,
        CASE
            WHEN dfd.FileCount < @MinimumDataFileCount THEN 'Nur Strukturhinweis: Fuer diese Datenbank liegt noch keine typische Mehrdatei-Verteilung vor.'
            WHEN dfd.ReviewSeverity IN ('high', 'medium') THEN 'Didaktische Vorlage, um die Dateigroesse in Richtung Gleichverteilung zu bringen.'
            ELSE 'Nur geringe Abweichung; Vorlage dient eher der Standardisierung als einer akuten Korrektur.'
        END AS Rationale
    FROM #DataFileDistribution AS dfd
    WHERE dfd.ReviewSeverity IN ('high', 'medium')
       OR dfd.FileCount < @MinimumDataFileCount;
END;

-- 5. Ergebnisse ausgeben
SELECT
    dfd.FileOrder,
    dfd.DatabaseName,
    dfd.LogicalFileName,
    dfd.PhysicalFileName,
    dfd.FileId,
    dfd.CurrentSizeMB,
    dfd.GrowthDisplay,
    dfd.TotalDataSizeMB,
    dfd.FileCount,
    dfd.ActualSharePct,
    dfd.IdealSharePct,
    dfd.ShareDeltaPct,
    dfd.RecommendedTargetSizeMB,
    dfd.ReviewSeverity,
    dfd.ReviewFocus
FROM #DataFileDistribution AS dfd
ORDER BY
    dfd.FileOrder;

SELECT
    bs.SummaryLabel,
    bs.SummaryValue,
    bs.Interpretation
FROM #BalanceSummary AS bs;

IF @ShowRebalanceTemplate = 1
BEGIN
    SELECT
        rt.CommandOrder,
        rt.LogicalFileName,
        rt.PriorityLevel,
        rt.SuggestedSizeMB,
        rt.GeneratedCommand,
        rt.Rationale
    FROM #RebalanceTemplate AS rt
    ORDER BY
        rt.CommandOrder;
END;
