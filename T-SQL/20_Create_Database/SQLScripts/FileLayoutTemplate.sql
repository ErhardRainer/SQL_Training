/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "FileLayoutTemplate.sql"
script_version: "1.0"
script_type: "template"
chapter: "20_Create_Database"
purpose: >
  Erzeugt eine didaktische Vorlage fuer saubere Datei-, Filegroup- und
  Growth-Konfigurationen beim Anlegen einer Datenbank. Das Skript
  leitet Pfad-Fallbacks aus Instanzdefaults oder model ab, baut einen
  konsistenten Dateiplan auf und generiert daraus wiederverwendbare
  CREATE-DATABASE-Bausteine.

parameters:
  - name: "@TargetDatabaseName"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Name der geplanten Zieldatenbank fuer die Vorlage"
  - name: "@PrimaryDataDirectory"
    sql_type: "NVARCHAR(260)"
    direction: "IN"
    required: false
    description: "Optionales Verzeichnis fuer die PRIMARY-Datei"
  - name: "@SecondaryDataDirectory"
    sql_type: "NVARCHAR(260)"
    direction: "IN"
    required: false
    description: "Optionales Verzeichnis fuer weitere Datenfiles und optionale Reporting-Dateien"
  - name: "@LogDirectory"
    sql_type: "NVARCHAR(260)"
    direction: "IN"
    required: false
    description: "Optionales Verzeichnis fuer die Logdatei"
  - name: "@PrimaryDataSizeMB"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Didaktische Startgroesse der PRIMARY-Datei in MB"
  - name: "@SecondaryDataFileCount"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Anzahl zusaetzlicher Datenfiles in der DATA-Filegroup"
  - name: "@SecondaryDataFileSizeMB"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Didaktische Startgroesse je Datei in der DATA-Filegroup"
  - name: "@PrimaryGrowthMB"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Fixer Growth-Wert fuer die PRIMARY-Datei in MB"
  - name: "@SecondaryGrowthMB"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Fixer Growth-Wert je Datei in der DATA-Filegroup in MB"
  - name: "@LogSizeMB"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Didaktische Startgroesse der Logdatei in MB"
  - name: "@LogGrowthMB"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Fixer Growth-Wert der Logdatei in MB"
  - name: "@CreateReportingFilegroup"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zusaetzliche REPORTING-Filegroup mit einer NDF-Datei erzeugen"

result_sets:
  - name: "LayoutChecklist"
    description: "Leitplanken fuer Pfade, Filegroup-Rollen, Dateianzahl und Growth-Konventionen"
  - name: "FileLayoutPlan"
    description: "Konkreter didaktischer Dateiplan fuer PRIMARY, DATA, optional REPORTING und LOG"
  - name: "CreateDatabaseTemplate"
    description: "Generierte CREATE-DATABASE- und Verifikationsbausteine"

dependencies:
  - "sys.master_files"
  - "SERVERPROPERTY"
  - "tempdb temporary tables"
  - "CASE"
  - "CONCAT"
  - "QUOTENAME"
  - "STRING_AGG"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/20_Create_Database/SQLScripts/FileLayoutTemplate.md"
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
    description: "Erstversion der didaktischen Datei- und Growth-Vorlage fuer CREATE DATABASE"

notes:
  - "Das Skript fuehrt kein CREATE DATABASE aus, sondern liefert nur lesbare Planungs- und Template-Resultsets."
  - "Growth-Werte bleiben bewusst fix in MB, damit die Vorlage planbar und mit Kapitel-Standards konsistent bleibt."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

-- 1. Parameter vorbereiten
DECLARE @TargetDatabaseName SYSNAME = N'TrainingFileLayoutDemo';
DECLARE @PrimaryDataDirectory NVARCHAR(260) = NULL;
DECLARE @SecondaryDataDirectory NVARCHAR(260) = NULL;
DECLARE @LogDirectory NVARCHAR(260) = NULL;
DECLARE @PrimaryDataSizeMB INT = 256;
DECLARE @SecondaryDataFileCount INT = 2;
DECLARE @SecondaryDataFileSizeMB INT = 256;
DECLARE @PrimaryGrowthMB INT = 128;
DECLARE @SecondaryGrowthMB INT = 128;
DECLARE @LogSizeMB INT = 128;
DECLARE @LogGrowthMB INT = 64;
DECLARE @CreateReportingFilegroup BIT = 1;

IF @TargetDatabaseName IS NULL OR LTRIM(RTRIM(@TargetDatabaseName)) = N''
BEGIN
    THROW 50000, '@TargetDatabaseName darf nicht leer sein.', 1;
END;

IF @PrimaryDataSizeMB <= 0
BEGIN
    THROW 50001, '@PrimaryDataSizeMB muss groesser als 0 sein.', 1;
END;

IF @SecondaryDataFileCount < 1 OR @SecondaryDataFileCount > 8
BEGIN
    THROW 50002, '@SecondaryDataFileCount muss zwischen 1 und 8 liegen.', 1;
END;

IF @SecondaryDataFileSizeMB <= 0
BEGIN
    THROW 50003, '@SecondaryDataFileSizeMB muss groesser als 0 sein.', 1;
END;

IF @PrimaryGrowthMB <= 0 OR @SecondaryGrowthMB <= 0 OR @LogSizeMB <= 0 OR @LogGrowthMB <= 0
BEGIN
    THROW 50004, 'Growth- und Log-Parameter muessen groesser als 0 sein.', 1;
END;

IF @CreateReportingFilegroup NOT IN (0, 1)
BEGIN
    THROW 50005, '@CreateReportingFilegroup muss 0 oder 1 sein.', 1;
END;

DECLARE @InstanceDefaultDataPath NVARCHAR(260) = CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(260));
DECLARE @InstanceDefaultLogPath NVARCHAR(260) = CAST(SERVERPROPERTY('InstanceDefaultLogPath') AS NVARCHAR(260));
DECLARE @ModelDataPath NVARCHAR(260);
DECLARE @ModelLogPath NVARCHAR(260);
DECLARE @ResolvedPrimaryDirectory NVARCHAR(260);
DECLARE @ResolvedSecondaryDirectory NVARCHAR(260);
DECLARE @ResolvedLogDirectory NVARCHAR(260);
DECLARE @PrimaryLogicalName SYSNAME = CONCAT(@TargetDatabaseName, N'_Primary');
DECLARE @LogLogicalName SYSNAME = CONCAT(@TargetDatabaseName, N'_log');
DECLARE @ReportingLogicalName SYSNAME = CONCAT(@TargetDatabaseName, N'_Reporting01');

SELECT TOP (1)
    @ModelDataPath = LEFT(mf.physical_name, LEN(mf.physical_name) - CHARINDEX('\', REVERSE(mf.physical_name)))
FROM sys.master_files AS mf
WHERE mf.database_id = DB_ID(N'model')
  AND mf.type_desc = 'ROWS'
ORDER BY
    mf.file_id;

SELECT TOP (1)
    @ModelLogPath = LEFT(mf.physical_name, LEN(mf.physical_name) - CHARINDEX('\', REVERSE(mf.physical_name)))
FROM sys.master_files AS mf
WHERE mf.database_id = DB_ID(N'model')
  AND mf.type_desc = 'LOG'
ORDER BY
    mf.file_id;

SET @ResolvedPrimaryDirectory =
    COALESCE(NULLIF(@PrimaryDataDirectory, N''), NULLIF(@InstanceDefaultDataPath, N''), @ModelDataPath);
SET @ResolvedSecondaryDirectory =
    COALESCE(NULLIF(@SecondaryDataDirectory, N''), @ResolvedPrimaryDirectory);
SET @ResolvedLogDirectory =
    COALESCE(NULLIF(@LogDirectory, N''), NULLIF(@InstanceDefaultLogPath, N''), @ModelLogPath);

IF @ResolvedPrimaryDirectory IS NULL OR @ResolvedSecondaryDirectory IS NULL OR @ResolvedLogDirectory IS NULL
BEGIN
    THROW 50006, 'Mindestens ein benoetigtes Verzeichnis konnte nicht aus Parametern, Instanzdefaults oder model abgeleitet werden.', 1;
END;

DROP TABLE IF EXISTS #LayoutChecklist;
DROP TABLE IF EXISTS #FileLayoutPlan;
DROP TABLE IF EXISTS #CreateDatabaseTemplate;

-- 2. Leitplanken fuer ein sauberes Datei-Layout sammeln
CREATE TABLE #LayoutChecklist
(
    ChecklistOrder INT NOT NULL,
    ChecklistArea VARCHAR(40) NOT NULL,
    CheckItem VARCHAR(120) NOT NULL,
    Recommendation NVARCHAR(320) NOT NULL,
    WhyItMatters NVARCHAR(320) NOT NULL,
    CurrentBaseline NVARCHAR(320) NOT NULL
);

INSERT INTO #LayoutChecklist
(
    ChecklistOrder,
    ChecklistArea,
    CheckItem,
    Recommendation,
    WhyItMatters,
    CurrentBaseline
)
VALUES
    (
        1,
        'Paths',
        'Separate data and log directories',
        N'Daten- und Logdateien getrennt dokumentieren; weitere Datenfiles duerfen in ein eigenes Verzeichnis.',
        N'Pfadtrennung macht Storage-Entscheidungen und spaetere Reviews klar nachvollziehbar.',
        CONCAT(N'PRIMARY: ', @ResolvedPrimaryDirectory, N'; DATA: ', @ResolvedSecondaryDirectory, N'; LOG: ', @ResolvedLogDirectory)
    ),
    (
        2,
        'Growth',
        'Prefer fixed MB growth',
        N'Growth-Werte fuer Daten- und Logdateien als feste MB-Schritte dokumentieren und Prozentwachstum vermeiden.',
        N'Feste Growth-Werte sind planbarer und passen besser zu wiederverwendbaren CREATE-DATABASE-Vorlagen.',
        CONCAT(N'PRIMARY growth: ', @PrimaryGrowthMB, N'MB; DATA growth: ', @SecondaryGrowthMB, N'MB; LOG growth: ', @LogGrowthMB, N'MB')
    ),
    (
        3,
        'Naming',
        'Use role-based names',
        N'Logische und physische Namen mit Rollenkennzeichen wie Primary, DataNN, ReportingNN und log versehen.',
        N'Konsistente Namen erleichtern spaetere ALTER DATABASE-, Monitoring- und Restore-Aufgaben.',
        CONCAT(N'Basisnamen: ', @PrimaryLogicalName, N', ', @TargetDatabaseName, N'_DataNN, ', @ReportingLogicalName, N', ', @LogLogicalName)
    ),
    (
        4,
        'Files',
        'Keep file count intentional',
        N'Zusaetzliche Datenfiles nur bei erkennbarem Parallelisierungs- oder Verwaltungsbedarf vorsehen.',
        N'Zu viele Dateien ohne Grund machen das Layout unnoetig komplex, zu wenige koennen Wachstum und Verteilung verdecken.',
        CONCAT(N'Didaktische Startanzahl fuer DATA-Dateien: ', @SecondaryDataFileCount)
    ),
    (
        5,
        'Filegroups',
        'Use dedicated filegroup roles',
        N'PRIMARY klein halten, regulare Nutzdaten in DATA legen und REPORTING nur bei bewusst getrennter Last aufnehmen.',
        N'Getrennte Filegroup-Rollen helfen bei Layout-Reviews, spaeterer Platzierung und Wachstumskontrolle.',
        CASE
            WHEN @CreateReportingFilegroup = 1 THEN N'PRIMARY, DATA, REPORTING und LOG werden als Vorlage aufgebaut.'
            ELSE N'PRIMARY, DATA und LOG werden als Vorlage aufgebaut; REPORTING bleibt deaktiviert.'
        END
    );

-- 3. Konkreten Dateiplan fuer CREATE DATABASE ableiten
CREATE TABLE #FileLayoutPlan
(
    PlanOrder INT NOT NULL,
    FilegroupName SYSNAME NOT NULL,
    FileRole VARCHAR(20) NOT NULL,
    LogicalFileName SYSNAME NOT NULL,
    PhysicalFileName NVARCHAR(400) NOT NULL,
    InitialSizeMB INT NOT NULL,
    GrowthMB INT NOT NULL,
    ClauseOrder INT NOT NULL,
    ReviewNote NVARCHAR(260) NOT NULL
);

INSERT INTO #FileLayoutPlan
(
    PlanOrder,
    FilegroupName,
    FileRole,
    LogicalFileName,
    PhysicalFileName,
    InitialSizeMB,
    GrowthMB,
    ClauseOrder,
    ReviewNote
)
VALUES
    (
        10,
        N'PRIMARY',
        'DATA',
        @PrimaryLogicalName,
        CONCAT(@ResolvedPrimaryDirectory, CASE WHEN RIGHT(@ResolvedPrimaryDirectory, 1) = '\' THEN N'' ELSE N'\' END, @TargetDatabaseName, N'_Primary.mdf'),
        @PrimaryDataSizeMB,
        @PrimaryGrowthMB,
        10,
        N'PRIMARY bleibt bewusst klein und dient nur als Startdatei fuer Kernobjekte.'
    );

;WITH Numbers AS
(
    SELECT 1 AS FileNumber
    UNION ALL
    SELECT FileNumber + 1
    FROM Numbers
    WHERE FileNumber < @SecondaryDataFileCount
)
INSERT INTO #FileLayoutPlan
(
    PlanOrder,
    FilegroupName,
    FileRole,
    LogicalFileName,
    PhysicalFileName,
    InitialSizeMB,
    GrowthMB,
    ClauseOrder,
    ReviewNote
)
SELECT
    20 + n.FileNumber AS PlanOrder,
    N'DATA' AS FilegroupName,
    'DATA' AS FileRole,
    CONCAT(@TargetDatabaseName, N'_Data', RIGHT(CONCAT(N'0', CONVERT(NVARCHAR(10), n.FileNumber)), 2)) AS LogicalFileName,
    CONCAT(@ResolvedSecondaryDirectory, CASE WHEN RIGHT(@ResolvedSecondaryDirectory, 1) = '\' THEN N'' ELSE N'\' END, @TargetDatabaseName, N'_Data', RIGHT(CONCAT(N'0', CONVERT(NVARCHAR(10), n.FileNumber)), 2), N'.ndf') AS PhysicalFileName,
    @SecondaryDataFileSizeMB AS InitialSizeMB,
    @SecondaryGrowthMB AS GrowthMB,
    20 + n.FileNumber AS ClauseOrder,
    N'DATA-Dateien tragen die regulare Nutzlast und nutzen eine einheitliche Growth-Konvention.' AS ReviewNote
FROM Numbers AS n
OPTION (MAXRECURSION 8);

IF @CreateReportingFilegroup = 1
BEGIN
    INSERT INTO #FileLayoutPlan
    (
        PlanOrder,
        FilegroupName,
        FileRole,
        LogicalFileName,
        PhysicalFileName,
        InitialSizeMB,
        GrowthMB,
        ClauseOrder,
        ReviewNote
    )
    VALUES
        (
            80,
            N'REPORTING',
            'DATA',
            @ReportingLogicalName,
            CONCAT(@ResolvedSecondaryDirectory, CASE WHEN RIGHT(@ResolvedSecondaryDirectory, 1) = '\' THEN N'' ELSE N'\' END, @TargetDatabaseName, N'_Reporting01.ndf'),
            @SecondaryDataFileSizeMB,
            @SecondaryGrowthMB,
            80,
            N'REPORTING bleibt optional und dient als didaktisches Beispiel fuer getrennte leseorientierte Lasten.'
        );
END;

INSERT INTO #FileLayoutPlan
(
    PlanOrder,
    FilegroupName,
    FileRole,
    LogicalFileName,
    PhysicalFileName,
    InitialSizeMB,
    GrowthMB,
    ClauseOrder,
    ReviewNote
)
VALUES
    (
        90,
        N'LOG',
        'LOG',
        @LogLogicalName,
        CONCAT(@ResolvedLogDirectory, CASE WHEN RIGHT(@ResolvedLogDirectory, 1) = '\' THEN N'' ELSE N'\' END, @TargetDatabaseName, N'_log.ldf'),
        @LogSizeMB,
        @LogGrowthMB,
        90,
        N'Logdatei bleibt getrennt von Datenfiles und wird mit eigenem Growth-Wert geplant.'
    );

-- 4. CREATE DATABASE- und Verifikationsbausteine generieren
CREATE TABLE #CreateDatabaseTemplate
(
    TemplateOrder INT NOT NULL,
    TemplateName VARCHAR(100) NOT NULL,
    GeneratedCommand NVARCHAR(MAX) NOT NULL,
    ReviewHint NVARCHAR(320) NOT NULL
);

DECLARE @PrimaryClause NVARCHAR(MAX);
DECLARE @DataClause NVARCHAR(MAX);
DECLARE @ReportingClause NVARCHAR(MAX);
DECLARE @LogClause NVARCHAR(MAX);
DECLARE @VerificationCommand NVARCHAR(MAX);

SELECT TOP (1)
    @PrimaryClause = CONCAT(
        N'ON PRIMARY',
        NCHAR(13) + NCHAR(10),
        N'(',
        NCHAR(13) + NCHAR(10),
        N'    NAME = N''', flp.LogicalFileName, N''',',
        NCHAR(13) + NCHAR(10),
        N'    FILENAME = N''', flp.PhysicalFileName, N''',',
        NCHAR(13) + NCHAR(10),
        N'    SIZE = ', CONVERT(NVARCHAR(10), flp.InitialSizeMB), N'MB,',
        NCHAR(13) + NCHAR(10),
        N'    FILEGROWTH = ', CONVERT(NVARCHAR(10), flp.GrowthMB), N'MB',
        NCHAR(13) + NCHAR(10),
        N')'
    )
FROM #FileLayoutPlan AS flp
WHERE flp.FilegroupName = N'PRIMARY';

SELECT
    @DataClause =
        STRING_AGG(
            CONCAT(
                N'(',
                NCHAR(13) + NCHAR(10),
                N'    NAME = N''', flp.LogicalFileName, N''',',
                NCHAR(13) + NCHAR(10),
                N'    FILENAME = N''', flp.PhysicalFileName, N''',',
                NCHAR(13) + NCHAR(10),
                N'    SIZE = ', CONVERT(NVARCHAR(10), flp.InitialSizeMB), N'MB,',
                NCHAR(13) + NCHAR(10),
                N'    FILEGROWTH = ', CONVERT(NVARCHAR(10), flp.GrowthMB), N'MB',
                NCHAR(13) + NCHAR(10),
                N')'
            ),
            N',' + NCHAR(13) + NCHAR(10)
        ) WITHIN GROUP (ORDER BY flp.ClauseOrder)
FROM #FileLayoutPlan AS flp
WHERE flp.FilegroupName = N'DATA';

SELECT
    @ReportingClause =
        STRING_AGG(
            CONCAT(
                N'(',
                NCHAR(13) + NCHAR(10),
                N'    NAME = N''', flp.LogicalFileName, N''',',
                NCHAR(13) + NCHAR(10),
                N'    FILENAME = N''', flp.PhysicalFileName, N''',',
                NCHAR(13) + NCHAR(10),
                N'    SIZE = ', CONVERT(NVARCHAR(10), flp.InitialSizeMB), N'MB,',
                NCHAR(13) + NCHAR(10),
                N'    FILEGROWTH = ', CONVERT(NVARCHAR(10), flp.GrowthMB), N'MB',
                NCHAR(13) + NCHAR(10),
                N')'
            ),
            N',' + NCHAR(13) + NCHAR(10)
        ) WITHIN GROUP (ORDER BY flp.ClauseOrder)
FROM #FileLayoutPlan AS flp
WHERE flp.FilegroupName = N'REPORTING';

SELECT TOP (1)
    @LogClause = CONCAT(
        N'LOG ON',
        NCHAR(13) + NCHAR(10),
        N'(',
        NCHAR(13) + NCHAR(10),
        N'    NAME = N''', flp.LogicalFileName, N''',',
        NCHAR(13) + NCHAR(10),
        N'    FILENAME = N''', flp.PhysicalFileName, N''',',
        NCHAR(13) + NCHAR(10),
        N'    SIZE = ', CONVERT(NVARCHAR(10), flp.InitialSizeMB), N'MB,',
        NCHAR(13) + NCHAR(10),
        N'    FILEGROWTH = ', CONVERT(NVARCHAR(10), flp.GrowthMB), N'MB',
        NCHAR(13) + NCHAR(10),
        N')'
    )
FROM #FileLayoutPlan AS flp
WHERE flp.FilegroupName = N'LOG';

SET @VerificationCommand =
    CONCAT(
        N'ALTER DATABASE ',
        QUOTENAME(@TargetDatabaseName),
        N' MODIFY FILEGROUP [DATA] DEFAULT;',
        NCHAR(13) + NCHAR(10),
        CASE
            WHEN @CreateReportingFilegroup = 1 THEN
                CONCAT(
                    N'-- Optional: REPORTING nur dann aktiv nutzen, wenn leseorientierte Objekte bewusst getrennt werden sollen.',
                    NCHAR(13) + NCHAR(10)
                )
            ELSE
                N''
        END,
        N'SELECT fg.name AS filegroup_name,',
        NCHAR(13) + NCHAR(10),
        N'       df.name AS logical_file_name,',
        NCHAR(13) + NCHAR(10),
        N'       df.physical_name,',
        NCHAR(13) + NCHAR(10),
        N'       CAST(df.size / 128.0 AS DECIMAL(18, 2)) AS size_mb,',
        NCHAR(13) + NCHAR(10),
        N'       CASE WHEN df.is_percent_growth = 1 THEN CONCAT(df.growth, ''%'')',
        NCHAR(13) + NCHAR(10),
        N'            ELSE CONCAT(CAST(df.growth / 128.0 AS DECIMAL(18, 2)), '' MB'') END AS growth_display',
        NCHAR(13) + NCHAR(10),
        N'FROM ',
        QUOTENAME(@TargetDatabaseName),
        N'.sys.database_files AS df',
        NCHAR(13) + NCHAR(10),
        N'LEFT JOIN ',
        QUOTENAME(@TargetDatabaseName),
        N'.sys.filegroups AS fg',
        NCHAR(13) + NCHAR(10),
        N'    ON df.data_space_id = fg.data_space_id',
        NCHAR(13) + NCHAR(10),
        N'ORDER BY df.file_id;'
    );

INSERT INTO #CreateDatabaseTemplate
(
    TemplateOrder,
    TemplateName,
    GeneratedCommand,
    ReviewHint
)
VALUES
    (
        1,
        'Create database statement',
        CONCAT(
            N'CREATE DATABASE ',
            QUOTENAME(@TargetDatabaseName),
            NCHAR(13) + NCHAR(10),
            @PrimaryClause,
            N',' + NCHAR(13) + NCHAR(10) +
            N'FILEGROUP [DATA]' + NCHAR(13) + NCHAR(10) +
            @DataClause,
            CASE
                WHEN @ReportingClause IS NOT NULL THEN
                    N',' + NCHAR(13) + NCHAR(10) +
                    N'FILEGROUP [REPORTING]' + NCHAR(13) + NCHAR(10) +
                    @ReportingClause
                ELSE N''
            END,
            NCHAR(13) + NCHAR(10),
            @LogClause,
            N';'
        ),
        N'Die Vorlage bleibt bewusst konservativ und sollte vor produktiver Nutzung um reale Groessen, Laufwerke und Lifecycle-Regeln erweitert werden.'
    ),
    (
        2,
        'Post-create verification',
        @VerificationCommand,
        N'Der Nachlauf setzt DATA als Default-Filegroup und prueft anschliessend Datei- sowie Growth-Konfigurationen.'
    );

-- 5. Resultsets ausgeben
SELECT
    lc.ChecklistOrder,
    lc.ChecklistArea,
    lc.CheckItem,
    lc.Recommendation,
    lc.WhyItMatters,
    lc.CurrentBaseline
FROM #LayoutChecklist AS lc
ORDER BY
    lc.ChecklistOrder;

SELECT
    flp.PlanOrder,
    flp.FilegroupName,
    flp.FileRole,
    flp.LogicalFileName,
    flp.PhysicalFileName,
    flp.InitialSizeMB,
    flp.GrowthMB,
    flp.ReviewNote
FROM #FileLayoutPlan AS flp
ORDER BY
    flp.PlanOrder;

SELECT
    cdt.TemplateOrder,
    cdt.TemplateName,
    cdt.GeneratedCommand,
    cdt.ReviewHint
FROM #CreateDatabaseTemplate AS cdt
ORDER BY
    cdt.TemplateOrder;
