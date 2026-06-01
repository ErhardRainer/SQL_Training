/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "TempdbFileLayoutCheck.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "20_Create_Database"
purpose: >
  Inventarisiert die aktuelle TempDB-Dateikonfiguration, bewertet
  Groessen-, Growth- und Pfad-Ungleichgewichte und erzeugt daraus
  konkrete Review-Hinweise fuer eine stabilere TempDB-Baseline.

parameters:
  - name: "@SizeVarianceTolerancePct"
    sql_type: "DECIMAL(5,2)"
    direction: "IN"
    required: false
    description: "Zulaessige prozentuale Abweichung einer Data-Datei von der durchschnittlichen Data-Dateigroesse"
  - name: "@GrowthDeltaToleranceMB"
    sql_type: "DECIMAL(10,2)"
    direction: "IN"
    required: false
    description: "Zulaessige absolute Growth-Abweichung in MB zwischen Data-Dateien mit MB-basiertem Wachstum"
  - name: "@ExpectedDataFileCount"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Optionaler Sollwert fuer die Anzahl von TempDB-Data-Dateien; NULL nutzt nur die Ist-Sicht"
  - name: "@FlagMixedDirectories"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = unterschiedliche Verzeichnisse der TempDB-Dateien als Review-Finding markieren"

result_sets:
  - name: "TempdbFileInventory"
    description: "Zeigt TempDB-Dateien mit Typ, Pfad, Groesse, Growth und abgeleiteten Balance-Kennzahlen"
  - name: "DataFileBalanceSummary"
    description: "Verdichtet Data-Dateien auf Durchschnitt, Varianz, Growth-Muster und Verzeichnisverteilung"
  - name: "DirectoryLayout"
    description: "Gruppiert TempDB-Dateien nach Verzeichnis und Dateityp"
  - name: "Findings"
    description: "Listet konkrete Review-Findings fuer Groessen-, Growth- und Layout-Ungleichgewichte"

dependencies:
  - "sys.master_files"
  - "sys.databases"
  - "SERVERPROPERTY"
  - "tempdb temporary tables"
  - "CASE"
  - "CONCAT"
  - "STRING_AGG"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/20_Create_Database/SQLScripts/TempdbFileLayoutCheck.md"
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
    description: "Erstversion des lesenden TempDB-Datei-Checks"

notes:
  - "Das Skript liest nur Katalogmetadaten zu TempDB-Dateien und fuehrt keine Aenderungen an TempDB aus."
  - "Ungleichgewichte werden als Review-Hinweise aufbereitet, nicht als automatischer Reparaturplan."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

-- 1. Parameter vorbereiten
DECLARE @SizeVarianceTolerancePct DECIMAL(5, 2) = 20.00;
DECLARE @GrowthDeltaToleranceMB DECIMAL(10, 2) = 64.00;
DECLARE @ExpectedDataFileCount INT = NULL;
DECLARE @FlagMixedDirectories BIT = 1;

IF @SizeVarianceTolerancePct < 0
BEGIN
    THROW 50000, '@SizeVarianceTolerancePct darf nicht negativ sein.', 1;
END;

IF @GrowthDeltaToleranceMB < 0
BEGIN
    THROW 50001, '@GrowthDeltaToleranceMB darf nicht negativ sein.', 1;
END;

IF @ExpectedDataFileCount IS NOT NULL
   AND @ExpectedDataFileCount < 1
BEGIN
    THROW 50002, '@ExpectedDataFileCount muss NULL oder mindestens 1 sein.', 1;
END;

IF @FlagMixedDirectories NOT IN (0, 1)
BEGIN
    THROW 50003, '@FlagMixedDirectories muss 0 oder 1 sein.', 1;
END;

IF DB_ID(N'tempdb') IS NULL
BEGIN
    THROW 50004, 'TempDB konnte auf dieser Instanz nicht ermittelt werden.', 1;
END;

DROP TABLE IF EXISTS #TempdbFiles;
DROP TABLE IF EXISTS #DataFileBalanceSummary;
DROP TABLE IF EXISTS #DirectoryLayout;
DROP TABLE IF EXISTS #Findings;

-- 2. TempDB-Dateien inventarisieren
CREATE TABLE #TempdbFiles
(
    FileId INT NOT NULL,
    LogicalFileName SYSNAME NOT NULL,
    FileTypeDesc NVARCHAR(20) NOT NULL,
    PhysicalFileName NVARCHAR(260) NOT NULL,
    DirectoryPath NVARCHAR(260) NOT NULL,
    FileExtension VARCHAR(10) NOT NULL,
    SizeMB DECIMAL(18, 2) NOT NULL,
    GrowthValue NVARCHAR(40) NOT NULL,
    GrowthMB DECIMAL(18, 2) NULL,
    IsPercentGrowth BIT NOT NULL,
    IsDataFile BIT NOT NULL,
    DataFileOrdinal INT NULL
);

INSERT INTO #TempdbFiles
(
    FileId,
    LogicalFileName,
    FileTypeDesc,
    PhysicalFileName,
    DirectoryPath,
    FileExtension,
    SizeMB,
    GrowthValue,
    GrowthMB,
    IsPercentGrowth,
    IsDataFile,
    DataFileOrdinal
)
SELECT
    mf.file_id,
    mf.name AS LogicalFileName,
    mf.type_desc,
    mf.physical_name,
    LEFT(mf.physical_name, LEN(mf.physical_name) - CHARINDEX('\', REVERSE(mf.physical_name))) AS DirectoryPath,
    RIGHT(mf.physical_name, CHARINDEX('.', REVERSE(mf.physical_name))) AS FileExtension,
    CAST(mf.size / 128.0 AS DECIMAL(18, 2)) AS SizeMB,
    CASE
        WHEN mf.is_percent_growth = 1 THEN CONCAT(CONVERT(VARCHAR(20), mf.growth), '%')
        ELSE CONCAT(CONVERT(VARCHAR(30), CAST(mf.growth / 128.0 AS DECIMAL(18, 2))), ' MB')
    END AS GrowthValue,
    CASE
        WHEN mf.is_percent_growth = 1 THEN NULL
        ELSE CAST(mf.growth / 128.0 AS DECIMAL(18, 2))
    END AS GrowthMB,
    mf.is_percent_growth,
    CASE WHEN mf.type_desc = 'ROWS' THEN 1 ELSE 0 END AS IsDataFile,
    CASE
        WHEN mf.type_desc = 'ROWS' THEN ROW_NUMBER() OVER (PARTITION BY mf.type_desc ORDER BY mf.file_id)
        ELSE NULL
    END AS DataFileOrdinal
FROM sys.master_files AS mf
WHERE mf.database_id = DB_ID(N'tempdb');

IF NOT EXISTS
(
    SELECT 1
    FROM #TempdbFiles AS tf
)
BEGIN
    THROW 50005, 'Fuer TempDB wurden keine Dateien in sys.master_files gefunden.', 1;
END;

-- 3. Balance-Metriken fuer Data-Dateien berechnen
DECLARE @DataFileCount INT;
DECLARE @AverageDataFileSizeMB DECIMAL(18, 2);
DECLARE @MinDataFileSizeMB DECIMAL(18, 2);
DECLARE @MaxDataFileSizeMB DECIMAL(18, 2);
DECLARE @MinDataGrowthMB DECIMAL(18, 2);
DECLARE @MaxDataGrowthMB DECIMAL(18, 2);
DECLARE @DistinctDataGrowthPatterns INT;
DECLARE @DistinctDataDirectories INT;
DECLARE @ExpectedOrActualDataFileCount INT;
DECLARE @InstanceCpuCount INT = TRY_CAST(SERVERPROPERTY('CpuCount') AS INT);

SELECT
    @DataFileCount = COUNT(*),
    @AverageDataFileSizeMB = CAST(AVG(CAST(tf.SizeMB AS DECIMAL(18, 4))) AS DECIMAL(18, 2)),
    @MinDataFileSizeMB = MIN(tf.SizeMB),
    @MaxDataFileSizeMB = MAX(tf.SizeMB),
    @MinDataGrowthMB = MIN(tf.GrowthMB),
    @MaxDataGrowthMB = MAX(tf.GrowthMB),
    @DistinctDataGrowthPatterns = COUNT(DISTINCT CONCAT(tf.GrowthValue, '|', tf.IsPercentGrowth)),
    @DistinctDataDirectories = COUNT(DISTINCT tf.DirectoryPath)
FROM #TempdbFiles AS tf
WHERE tf.IsDataFile = 1;

SET @ExpectedOrActualDataFileCount = COALESCE(@ExpectedDataFileCount, @DataFileCount);

CREATE TABLE #DataFileBalanceSummary
(
    SummaryArea VARCHAR(60) NOT NULL,
    ObservedValue NVARCHAR(120) NOT NULL,
    Evaluation NVARCHAR(260) NOT NULL,
    RecommendedAction NVARCHAR(320) NOT NULL
);

INSERT INTO #DataFileBalanceSummary
(
    SummaryArea,
    ObservedValue,
    Evaluation,
    RecommendedAction
)
VALUES
    (
        'data file count',
        CONVERT(NVARCHAR(40), @DataFileCount),
        CASE
            WHEN @ExpectedDataFileCount IS NULL THEN N'Kein Sollwert vorgegeben; die Ist-Anzahl wird nur dokumentiert.'
            WHEN @DataFileCount = @ExpectedDataFileCount THEN N'Die Anzahl der TempDB-Data-Dateien entspricht dem vorgegebenen Sollwert.'
            ELSE N'Die Anzahl der TempDB-Data-Dateien weicht vom vorgegebenen Sollwert ab.'
        END,
        CASE
            WHEN @ExpectedDataFileCount IS NULL THEN N'Falls ein Betriebsstandard existiert, kann er ueber @ExpectedDataFileCount explizit gegengeprueft werden.'
            WHEN @DataFileCount = @ExpectedDataFileCount THEN N'Den Sollwert beibehalten und nur bei CPU-, I/O- oder Warteproblemen neu bewerten.'
            ELSE N'Den Sollwert gegen CPU-Anzahl, Wait-Profile und Herstellerempfehlungen pruefen und danach die Data-Dateien angleichen.'
        END
    ),
    (
        'data file size spread',
        CONCAT(CONVERT(NVARCHAR(30), @MinDataFileSizeMB), N' MB .. ', CONVERT(NVARCHAR(30), @MaxDataFileSizeMB), N' MB'),
        CASE
            WHEN @AverageDataFileSizeMB = 0 THEN N'Es konnte keine sinnvolle Durchschnittsgroesse fuer Data-Dateien berechnet werden.'
            WHEN ((@MaxDataFileSizeMB - @MinDataFileSizeMB) / NULLIF(@AverageDataFileSizeMB, 0)) * 100.0 > @SizeVarianceTolerancePct THEN N'Die Groessenstreuung der Data-Dateien ueberschreitet die definierte Toleranz.'
            ELSE N'Die Groessen der Data-Dateien liegen innerhalb der definierten Toleranz.'
        END,
        N'Data-Dateien moeglichst symmetrisch halten, damit Proportional Fill keine dauerhaften Hotspots erzeugt.'
    ),
    (
        'data growth pattern',
        CONVERT(NVARCHAR(40), @DistinctDataGrowthPatterns),
        CASE
            WHEN @DistinctDataGrowthPatterns > 1 THEN N'Die Data-Dateien verwenden unterschiedliche Growth-Muster.'
            ELSE N'Die Data-Dateien verwenden ein konsistentes Growth-Muster.'
        END,
        N'Growth-Einstellungen fuer Data-Dateien vereinheitlichen und vorzugsweise feste MB-Werte statt Prozentwachstum nutzen.'
    ),
    (
        'data growth delta mb',
        CASE
            WHEN @MinDataGrowthMB IS NULL OR @MaxDataGrowthMB IS NULL THEN N'n/a'
            ELSE CONCAT(CONVERT(NVARCHAR(30), @MinDataGrowthMB), N' MB .. ', CONVERT(NVARCHAR(30), @MaxDataGrowthMB), N' MB')
        END,
        CASE
            WHEN @DistinctDataGrowthPatterns = 1 THEN N'Die Data-Dateien haben keinen Growth-Delta-Konflikt.'
            WHEN @MinDataGrowthMB IS NULL OR @MaxDataGrowthMB IS NULL THEN N'Mindestens eine Data-Datei nutzt Prozentwachstum; der MB-Vergleich ist daher nur eingeschraenkt aussagekraeftig.'
            WHEN @MaxDataGrowthMB - @MinDataGrowthMB > @GrowthDeltaToleranceMB THEN N'Die MB-basierten Growth-Werte der Data-Dateien weichen staerker voneinander ab als erlaubt.'
            ELSE N'Die MB-basierten Growth-Werte der Data-Dateien liegen innerhalb der Toleranz.'
        END,
        N'Bei MB-basiertem Growth sollten die Data-Dateien moeglichst denselben Schritt verwenden.'
    ),
    (
        'data directories',
        CONVERT(NVARCHAR(40), @DistinctDataDirectories),
        CASE
            WHEN @DistinctDataDirectories > 1 THEN N'Die Data-Dateien liegen in mehreren Verzeichnissen.'
            ELSE N'Die Data-Dateien liegen in einem einheitlichen Verzeichnis.'
        END,
        N'Verzeichnislayout gegen Storage-Architektur und Monitoring-Konventionen abgleichen.'
    ),
    (
        'cpu reference',
        COALESCE(CONVERT(NVARCHAR(40), @InstanceCpuCount), N'unavailable'),
        N'Die CPU-Anzahl wird nur als didaktischer Referenzwert gezeigt; daraus folgt keine automatische Soll-Anzahl fuer TempDB-Dateien.',
        N'CPU-Zahl nur zusammen mit Wait-Analyse, Herstellerguidance und realem Lastprofil verwenden.'
    );

-- 4. Verzeichnislayout und Findings aufbauen
CREATE TABLE #DirectoryLayout
(
    DirectoryPath NVARCHAR(260) NOT NULL,
    FileTypeGroup VARCHAR(20) NOT NULL,
    FileCount INT NOT NULL,
    TotalSizeMB DECIMAL(18, 2) NOT NULL,
    LogicalFiles NVARCHAR(MAX) NOT NULL
);

INSERT INTO #DirectoryLayout
(
    DirectoryPath,
    FileTypeGroup,
    FileCount,
    TotalSizeMB,
    LogicalFiles
)
SELECT
    tf.DirectoryPath,
    CASE WHEN tf.IsDataFile = 1 THEN 'data-files' ELSE 'log-files' END AS FileTypeGroup,
    COUNT(*) AS FileCount,
    CAST(SUM(tf.SizeMB) AS DECIMAL(18, 2)) AS TotalSizeMB,
    STRING_AGG(CONVERT(NVARCHAR(MAX), tf.LogicalFileName), N', ') WITHIN GROUP (ORDER BY tf.FileId) AS LogicalFiles
FROM #TempdbFiles AS tf
GROUP BY
    tf.DirectoryPath,
    CASE WHEN tf.IsDataFile = 1 THEN 'data-files' ELSE 'log-files' END;

CREATE TABLE #Findings
(
    FindingOrder INT NOT NULL,
    Severity VARCHAR(10) NOT NULL,
    FindingCategory VARCHAR(40) NOT NULL,
    FindingTitle NVARCHAR(140) NOT NULL,
    Observation NVARCHAR(320) NOT NULL,
    RecommendedAction NVARCHAR(320) NOT NULL
);

INSERT INTO #Findings
(
    FindingOrder,
    Severity,
    FindingCategory,
    FindingTitle,
    Observation,
    RecommendedAction
)
SELECT
    1,
    CASE
        WHEN @ExpectedDataFileCount IS NOT NULL AND @DataFileCount <> @ExpectedDataFileCount THEN 'medium'
        ELSE 'info'
    END,
    'file-count',
    N'Data-Datei-Anzahl fuer TempDB pruefen',
    CONCAT(
        N'Ist-Anzahl: ',
        CONVERT(NVARCHAR(20), @DataFileCount),
        N'; Referenzwert: ',
        CONVERT(NVARCHAR(20), @ExpectedOrActualDataFileCount),
        N'.'
    ),
    CASE
        WHEN @ExpectedDataFileCount IS NULL THEN N'Bei Bedarf einen betrieblichen Sollwert definieren und mit CPU-/Wait-Sicht abgleichen.'
        WHEN @DataFileCount = @ExpectedDataFileCount THEN N'Keine Mengenanpassung notwendig; Fokus kann auf Growth und Layout bleiben.'
        ELSE N'Die Data-Datei-Anzahl gegen den Sollwert und das aktuelle Lastbild abgleichen.'
    END
UNION ALL
SELECT
    2,
    CASE
        WHEN @AverageDataFileSizeMB = 0 THEN 'info'
        WHEN ((@MaxDataFileSizeMB - @MinDataFileSizeMB) / NULLIF(@AverageDataFileSizeMB, 0)) * 100.0 > (@SizeVarianceTolerancePct * 1.5) THEN 'high'
        WHEN ((@MaxDataFileSizeMB - @MinDataFileSizeMB) / NULLIF(@AverageDataFileSizeMB, 0)) * 100.0 > @SizeVarianceTolerancePct THEN 'medium'
        ELSE 'info'
    END,
    'size-balance',
    N'Data-Dateigroessen auf Symmetrie pruefen',
    CONCAT(
        N'Min/Avg/Max: ',
        CONVERT(NVARCHAR(30), @MinDataFileSizeMB), N' / ',
        CONVERT(NVARCHAR(30), @AverageDataFileSizeMB), N' / ',
        CONVERT(NVARCHAR(30), @MaxDataFileSizeMB), N' MB.'
    ),
    N'Data-Dateien mit deutlicher Groessenabweichung angleichen, damit TempDB-Allokationen gleichmaessiger verteilt bleiben.'
UNION ALL
SELECT
    3,
    CASE
        WHEN @DistinctDataGrowthPatterns > 1 THEN 'medium'
        ELSE 'info'
    END,
    'growth',
    N'Growth-Einstellungen der Data-Dateien pruefen',
    CONCAT(
        N'Unterschiedliche Growth-Muster: ',
        CONVERT(NVARCHAR(20), @DistinctDataGrowthPatterns),
        N'.'
    ),
    CASE
        WHEN @MinDataGrowthMB IS NULL OR @MaxDataGrowthMB IS NULL THEN N'Growth-Werte vereinheitlichen und Prozentwachstum in TempDB moeglichst vermeiden.'
        WHEN @MaxDataGrowthMB - @MinDataGrowthMB > @GrowthDeltaToleranceMB THEN N'MB-basiertes Growth vereinheitlichen; die aktuelle Spreizung ist groesser als die definierte Toleranz.'
        ELSE N'Growth-Werte sind dokumentiert; Prozentwachstum sollte dennoch fuer TempDB kritisch hinterfragt werden.'
    END
UNION ALL
SELECT
    4,
    CASE
        WHEN @FlagMixedDirectories = 1 AND @DistinctDataDirectories > 1 THEN 'medium'
        ELSE 'info'
    END,
    'directories',
    N'Verzeichnislayout der Data-Dateien pruefen',
    CONCAT(
        N'Unterschiedliche Data-Verzeichnisse: ',
        CONVERT(NVARCHAR(20), @DistinctDataDirectories),
        N'.'
    ),
    CASE
        WHEN @FlagMixedDirectories = 1 AND @DistinctDataDirectories > 1 THEN N'Pfadverteilung gegen Storage-Design, Failover-Strategie und Monitoring-Konventionen reviewen.'
        ELSE N'Das Verzeichnislayout ist dokumentiert; nur bei Betriebs- oder Storage-Aenderungen neu bewerten.'
    END;

INSERT INTO #Findings
(
    FindingOrder,
    Severity,
    FindingCategory,
    FindingTitle,
    Observation,
    RecommendedAction
)
SELECT
    10 + tf.FileId,
    CASE
        WHEN @AverageDataFileSizeMB = 0 THEN 'info'
        WHEN ABS(tf.SizeMB - @AverageDataFileSizeMB) / NULLIF(@AverageDataFileSizeMB, 0) * 100.0 > (@SizeVarianceTolerancePct * 1.5) THEN 'high'
        WHEN ABS(tf.SizeMB - @AverageDataFileSizeMB) / NULLIF(@AverageDataFileSizeMB, 0) * 100.0 > @SizeVarianceTolerancePct THEN 'medium'
        ELSE 'info'
    END AS Severity,
    'per-file-size',
    CONCAT(N'Data-Datei ', tf.LogicalFileName, N' gegen Durchschnitt pruefen'),
    CONCAT(
        N'Dateigroesse ',
        CONVERT(NVARCHAR(30), tf.SizeMB),
        N' MB bei Durchschnitt ',
        CONVERT(NVARCHAR(30), @AverageDataFileSizeMB),
        N' MB.'
    ),
    N'Nur wenn echte Lastprobleme oder deutliche Groessenunterschiede vorliegen, eine kontrollierte Nachgroesse oder Angleichung planen.'
FROM #TempdbFiles AS tf
WHERE tf.IsDataFile = 1;

-- 5. Inventar mit Balance-Kennzahlen anreichern und ausgeben
SELECT
    tf.FileId,
    tf.LogicalFileName,
    tf.FileTypeDesc,
    tf.PhysicalFileName,
    tf.DirectoryPath,
    tf.FileExtension,
    tf.SizeMB,
    tf.GrowthValue,
    tf.GrowthMB,
    tf.IsPercentGrowth,
    tf.DataFileOrdinal,
    CASE
        WHEN tf.IsDataFile = 1 AND @AverageDataFileSizeMB > 0 THEN CAST((tf.SizeMB / @AverageDataFileSizeMB) * 100.0 AS DECIMAL(10, 2))
        ELSE NULL
    END AS SizeVsAveragePct,
    CASE
        WHEN tf.IsDataFile = 1 AND @AverageDataFileSizeMB > 0
             AND ABS(tf.SizeMB - @AverageDataFileSizeMB) / @AverageDataFileSizeMB * 100.0 > @SizeVarianceTolerancePct
            THEN 'review'
        WHEN tf.IsDataFile = 1 THEN 'balanced'
        ELSE 'reference'
    END AS BalanceFlag
FROM #TempdbFiles AS tf
ORDER BY
    tf.IsDataFile DESC,
    tf.FileId;

SELECT
    dfs.SummaryArea,
    dfs.ObservedValue,
    dfs.Evaluation,
    dfs.RecommendedAction
FROM #DataFileBalanceSummary AS dfs
ORDER BY
    dfs.SummaryArea;

SELECT
    dl.DirectoryPath,
    dl.FileTypeGroup,
    dl.FileCount,
    dl.TotalSizeMB,
    dl.LogicalFiles
FROM #DirectoryLayout AS dl
ORDER BY
    dl.DirectoryPath,
    dl.FileTypeGroup;

SELECT
    f.FindingOrder,
    f.Severity,
    f.FindingCategory,
    f.FindingTitle,
    f.Observation,
    f.RecommendedAction
FROM #Findings AS f
ORDER BY
    f.FindingOrder;
