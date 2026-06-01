/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "PrimaryFileRelocationPlan.sql"
script_version: "1.0"
script_type: "template"
chapter: "20_Create_Database"
purpose: >
  Erstellt einen lesenden Relocation-Plan fuer Dateien im PRIMARY-
  Filegroup, leitet strukturierte Zielpfade ab, bewertet Risiken und
  generiert didaktische ALTER-DATABASE- sowie Betriebsvorlagen fuer
  einen spaeteren Dateiumzug.

parameters:
  - name: "@TargetDatabaseName"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Datenbank, deren PRIMARY-Dateien geplant oder aus Demo-Daten modelliert werden"
  - name: "@EnvironmentCode"
    sql_type: "NVARCHAR(20)"
    direction: "IN"
    required: false
    description: "Kurzes Umgebungskennzeichen wie DEV, TEST oder PROD fuer den Zielpfad"
  - name: "@ApplicationCode"
    sql_type: "NVARCHAR(30)"
    direction: "IN"
    required: false
    description: "Optionales Domain- oder Anwendungstoken fuer den Zielpfad"
  - name: "@PrimaryRootDirectory"
    sql_type: "NVARCHAR(260)"
    direction: "IN"
    required: false
    description: "Optionales Root-Verzeichnis fuer PRIMARY-Dateien; NULL nutzt Instanz-Defaults oder model-Fallback"
  - name: "@UseDemoBaseline"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = modellierte Demo-Dateien verwenden, 0 = vorhandene Katalogdaten der Zieldatenbank lesen"
  - name: "@IncludeSecondaryReference"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zusaetzlich vorhandene Nicht-PRIMARY-Dateien als Referenz im Baseline-Resultset anzeigen"

result_sets:
  - name: "PrimaryFileBaseline"
    description: "Zeigt PRIMARY-Dateien aus Katalog oder Demo-Baseline inklusive aktuellem Pfad und Umzugskontext"
  - name: "RelocationPlan"
    description: "Leitet strukturierte Zielpfade, erwartete Dateinamen und konkrete Relocation-Hinweise ab"
  - name: "PreflightChecklist"
    description: "Listet Guardrails fuer Backup, Wartungsfenster, Berechtigungen und Nachkontrolle vor einem Dateiumzug"
  - name: "CommandTemplate"
    description: "Erzeugt didaktische ALTER-DATABASE-, Offline- und Verifikationsvorlagen fuer die geplante Verlagerung"

dependencies:
  - "sys.databases"
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
  markdown_file: "T-SQL/20_Create_Database/SQLScripts/PrimaryFileRelocationPlan.md"
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
    description: "Erstversion der lesenden Planungs- und Vorlagenlogik fuer PRIMARY-Dateiverlagerungen"

notes:
  - "Das Skript fuehrt keinen Dateiumzug aus, sondern erzeugt nur Baseline, Checkliste und Befehlsvorlagen."
  - "Wenn keine produktive Zieldatenbank gelesen werden soll, arbeitet das Skript mit einer didaktischen Demo-Baseline."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

-- 1. Parameter vorbereiten
DECLARE @TargetDatabaseName SYSNAME = N'TrainingPrimaryRelocationDemo';
DECLARE @EnvironmentCode NVARCHAR(20) = N'DEV';
DECLARE @ApplicationCode NVARCHAR(30) = N'TRAINING';
DECLARE @PrimaryRootDirectory NVARCHAR(260) = NULL;
DECLARE @UseDemoBaseline BIT = 1;
DECLARE @IncludeSecondaryReference BIT = 1;

IF @TargetDatabaseName IS NULL OR LTRIM(RTRIM(@TargetDatabaseName)) = N''
BEGIN
    THROW 50000, '@TargetDatabaseName darf nicht leer sein.', 1;
END;

IF @EnvironmentCode IS NULL OR LTRIM(RTRIM(@EnvironmentCode)) = N''
BEGIN
    THROW 50001, '@EnvironmentCode darf nicht leer sein.', 1;
END;

IF @ApplicationCode IS NULL OR LTRIM(RTRIM(@ApplicationCode)) = N''
BEGIN
    THROW 50002, '@ApplicationCode darf nicht leer sein.', 1;
END;

IF @UseDemoBaseline NOT IN (0, 1)
BEGIN
    THROW 50003, '@UseDemoBaseline muss 0 oder 1 sein.', 1;
END;

IF @IncludeSecondaryReference NOT IN (0, 1)
BEGIN
    THROW 50004, '@IncludeSecondaryReference muss 0 oder 1 sein.', 1;
END;

IF @UseDemoBaseline = 0
   AND DB_ID(@TargetDatabaseName) IS NULL
BEGIN
    THROW 50005, 'Bei @UseDemoBaseline = 0 muss @TargetDatabaseName auf eine vorhandene Datenbank verweisen.', 1;
END;

DECLARE @InstanceDefaultDataPath NVARCHAR(260) = CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(260));
DECLARE @ModelDataPath NVARCHAR(260);
DECLARE @ResolvedPrimaryRoot NVARCHAR(260);
DECLARE @PathStem NVARCHAR(200);
DECLARE @TargetRoleDirectory NVARCHAR(320);

SELECT TOP (1)
    @ModelDataPath = LEFT(mf.physical_name, LEN(mf.physical_name) - CHARINDEX('\', REVERSE(mf.physical_name)))
FROM sys.master_files AS mf
WHERE mf.database_id = DB_ID(N'model')
  AND mf.type_desc = 'ROWS'
ORDER BY
    mf.file_id;

SET @ResolvedPrimaryRoot =
    COALESCE(NULLIF(@PrimaryRootDirectory, N''), NULLIF(@InstanceDefaultDataPath, N''), @ModelDataPath);
SET @PathStem = CONCAT(UPPER(@EnvironmentCode), N'\', UPPER(@ApplicationCode), N'\', @TargetDatabaseName);
SET @TargetRoleDirectory =
    CONCAT(
        @ResolvedPrimaryRoot,
        CASE WHEN RIGHT(@ResolvedPrimaryRoot, 1) = '\' THEN N'' ELSE N'\' END,
        @PathStem,
        N'\primary'
    );

IF @ResolvedPrimaryRoot IS NULL
BEGIN
    THROW 50006, 'Der Ziel-Root fuer PRIMARY-Dateien konnte nicht aus Parametern, Instanzdefaults oder model abgeleitet werden.', 1;
END;

DROP TABLE IF EXISTS #CurrentFiles;
DROP TABLE IF EXISTS #PrimaryFileBaseline;
DROP TABLE IF EXISTS #RelocationPlan;
DROP TABLE IF EXISTS #PreflightChecklist;
DROP TABLE IF EXISTS #CommandTemplate;

-- 2. Aktuelle Dateibasis aus Demo oder Katalog aufbauen
CREATE TABLE #CurrentFiles
(
    FileOrder INT NOT NULL,
    LogicalFileName SYSNAME NOT NULL,
    PhysicalFileName NVARCHAR(260) NOT NULL,
    FileTypeDesc NVARCHAR(20) NOT NULL,
    IsPrimaryFilegroup BIT NOT NULL,
    CurrentDirectory NVARCHAR(260) NOT NULL,
    CurrentExtension VARCHAR(10) NOT NULL,
    CurrentSizeMB DECIMAL(18, 2) NOT NULL,
    GrowthDisplay VARCHAR(40) NOT NULL,
    SourceDetail VARCHAR(40) NOT NULL
);

IF @UseDemoBaseline = 1
BEGIN
    INSERT INTO #CurrentFiles
    (
        FileOrder,
        LogicalFileName,
        PhysicalFileName,
        FileTypeDesc,
        IsPrimaryFilegroup,
        CurrentDirectory,
        CurrentExtension,
        CurrentSizeMB,
        GrowthDisplay,
        SourceDetail
    )
    VALUES
        (
            1,
            CONCAT(@TargetDatabaseName, N'_PRIMARY'),
            CONCAT(N'C:\LegacySql\', @TargetDatabaseName, N'\', @TargetDatabaseName, N'.mdf'),
            N'ROWS',
            1,
            CONCAT(N'C:\LegacySql\', @TargetDatabaseName),
            '.mdf',
            256.00,
            '64.00 MB',
            'demo primary'
        ),
        (
            2,
            CONCAT(@TargetDatabaseName, N'_DATA_01'),
            CONCAT(N'C:\LegacySql\', @TargetDatabaseName, N'\data\', @TargetDatabaseName, N'_DATA_01.ndf'),
            N'ROWS',
            0,
            CONCAT(N'C:\LegacySql\', @TargetDatabaseName, N'\data'),
            '.ndf',
            256.00,
            '64.00 MB',
            'demo secondary'
        ),
        (
            3,
            CONCAT(@TargetDatabaseName, N'_LOG'),
            CONCAT(N'C:\LegacySql\', @TargetDatabaseName, N'\log\', @TargetDatabaseName, N'_LOG.ldf'),
            N'LOG',
            0,
            CONCAT(N'C:\LegacySql\', @TargetDatabaseName, N'\log'),
            '.ldf',
            128.00,
            '64.00 MB',
            'demo log'
        );
END;
ELSE
BEGIN
    INSERT INTO #CurrentFiles
    (
        FileOrder,
        LogicalFileName,
        PhysicalFileName,
        FileTypeDesc,
        IsPrimaryFilegroup,
        CurrentDirectory,
        CurrentExtension,
        CurrentSizeMB,
        GrowthDisplay,
        SourceDetail
    )
    SELECT
        ROW_NUMBER() OVER
        (
            ORDER BY
                CASE WHEN mf.data_space_id = 1 AND mf.type_desc = 'ROWS' THEN 0 ELSE 1 END,
                mf.file_id
        ) AS FileOrder,
        mf.name AS LogicalFileName,
        mf.physical_name AS PhysicalFileName,
        mf.type_desc AS FileTypeDesc,
        CASE
            WHEN mf.type_desc = 'ROWS' AND mf.data_space_id = 1 THEN 1
            ELSE 0
        END AS IsPrimaryFilegroup,
        LEFT(mf.physical_name, LEN(mf.physical_name) - CHARINDEX('\', REVERSE(mf.physical_name))) AS CurrentDirectory,
        RIGHT(mf.physical_name, CHARINDEX('.', REVERSE(mf.physical_name))) AS CurrentExtension,
        CAST(mf.size / 128.0 AS DECIMAL(18, 2)) AS CurrentSizeMB,
        CASE
            WHEN mf.is_percent_growth = 1 THEN CONCAT(CONVERT(VARCHAR(20), mf.growth), '%')
            ELSE CONCAT(CONVERT(VARCHAR(30), CAST(mf.growth / 128.0 AS DECIMAL(18, 2))), ' MB')
        END AS GrowthDisplay,
        'catalog' AS SourceDetail
    FROM sys.master_files AS mf
    WHERE mf.database_id = DB_ID(@TargetDatabaseName)
      AND
      (
          (mf.type_desc = 'ROWS' AND mf.data_space_id = 1)
          OR @IncludeSecondaryReference = 1
      );
END;

IF NOT EXISTS
(
    SELECT 1
    FROM #CurrentFiles AS cf
    WHERE cf.IsPrimaryFilegroup = 1
)
BEGIN
    THROW 50007, 'Es konnten keine PRIMARY-Dateien fuer die Planung ermittelt werden.', 1;
END;

-- 3. PRIMARY-Dateien inventarisieren und Zielpfade ableiten
CREATE TABLE #PrimaryFileBaseline
(
    BaselineOrder INT NOT NULL,
    LogicalFileName SYSNAME NOT NULL,
    PhysicalFileName NVARCHAR(260) NOT NULL,
    CurrentDirectory NVARCHAR(260) NOT NULL,
    CurrentExtension VARCHAR(10) NOT NULL,
    CurrentSizeMB DECIMAL(18, 2) NOT NULL,
    GrowthDisplay VARCHAR(40) NOT NULL,
    SourceDetail VARCHAR(40) NOT NULL,
    PathObservation NVARCHAR(260) NOT NULL
);

INSERT INTO #PrimaryFileBaseline
(
    BaselineOrder,
    LogicalFileName,
    PhysicalFileName,
    CurrentDirectory,
    CurrentExtension,
    CurrentSizeMB,
    GrowthDisplay,
    SourceDetail,
    PathObservation
)
SELECT
    ROW_NUMBER() OVER (ORDER BY cf.FileOrder) AS BaselineOrder,
    cf.LogicalFileName,
    cf.PhysicalFileName,
    cf.CurrentDirectory,
    cf.CurrentExtension,
    cf.CurrentSizeMB,
    cf.GrowthDisplay,
    cf.SourceDetail,
    CASE
        WHEN cf.CurrentDirectory = @TargetRoleDirectory THEN N'Die PRIMARY-Datei liegt bereits im aufgeloesten Zielordner.'
        WHEN cf.CurrentDirectory LIKE N'%\primary%' THEN N'Der aktuelle Pfad nutzt bereits einen primary-Ordner, aber nicht den abgeleiteten Root oder Pfadstamm.'
        WHEN cf.CurrentDirectory LIKE N'%\data%' THEN N'Die PRIMARY-Datei liegt derzeit in einem allgemeinen data-Ordner und kann fuer Reviews staerker separiert werden.'
        ELSE N'Der aktuelle Pfad folgt keiner expliziten primary-Ordnerstruktur und eignet sich fuer eine geordnete Verlagerungsplanung.'
    END AS PathObservation
FROM #CurrentFiles AS cf
WHERE cf.IsPrimaryFilegroup = 1;

CREATE TABLE #RelocationPlan
(
    PlanOrder INT NOT NULL,
    LogicalFileName SYSNAME NOT NULL,
    CurrentPath NVARCHAR(260) NOT NULL,
    TargetDirectory NVARCHAR(320) NOT NULL,
    TargetPhysicalFileName NVARCHAR(400) NOT NULL,
    RelocationStatus VARCHAR(20) NOT NULL,
    FileMoveCommand NVARCHAR(420) NOT NULL,
    ReviewNote NVARCHAR(320) NOT NULL
);

INSERT INTO #RelocationPlan
(
    PlanOrder,
    LogicalFileName,
    CurrentPath,
    TargetDirectory,
    TargetPhysicalFileName,
    RelocationStatus,
    FileMoveCommand,
    ReviewNote
)
SELECT
    pfb.BaselineOrder,
    pfb.LogicalFileName,
    pfb.PhysicalFileName,
    @TargetRoleDirectory,
    CONCAT(
        @TargetRoleDirectory,
        CASE WHEN RIGHT(@TargetRoleDirectory, 1) = '\' THEN N'' ELSE N'\' END,
        @TargetDatabaseName,
        N'_PRIMARY_',
        RIGHT(CONCAT(N'0', CONVERT(NVARCHAR(10), pfb.BaselineOrder)), 2),
        CASE
            WHEN pfb.CurrentExtension IN ('.mdf', '.ndf') THEN pfb.CurrentExtension
            ELSE '.mdf'
        END
    ) AS TargetPhysicalFileName,
    CASE
        WHEN pfb.CurrentDirectory = @TargetRoleDirectory THEN 'already-aligned'
        ELSE 'planned'
    END AS RelocationStatus,
    CONCAT(
        N'Move-Item -LiteralPath ''',
        pfb.PhysicalFileName,
        N''' -Destination ''',
        @TargetRoleDirectory,
        N''''
    ) AS FileMoveCommand,
    CASE
        WHEN pfb.CurrentDirectory = @TargetRoleDirectory THEN N'Nur Namens- oder Verifikationsreview notwendig; der Zielordner passt bereits.'
        WHEN pfb.SourceDetail = 'demo primary' THEN N'Didaktischer Migrationspfad fuer eine Altstruktur ohne klaren primary-Unterordner.'
        ELSE N'Fuer den produktiven Umzug zuerst ALTER DATABASE ... MODIFY FILE planen, dann kontrolliertes Offline-Fenster und Nachverifikation vorsehen.'
    END AS ReviewNote
FROM #PrimaryFileBaseline AS pfb;

-- 4. Guardrails fuer die Verlagerung dokumentieren
CREATE TABLE #PreflightChecklist
(
    ChecklistOrder INT NOT NULL,
    ChecklistArea VARCHAR(40) NOT NULL,
    CheckItem VARCHAR(120) NOT NULL,
    WhyItMatters NVARCHAR(280) NOT NULL,
    RecommendedAction NVARCHAR(320) NOT NULL
);

INSERT INTO #PreflightChecklist
(
    ChecklistOrder,
    ChecklistArea,
    CheckItem,
    WhyItMatters,
    RecommendedAction
)
VALUES
    (
        1,
        'Backup',
        'Aktuelle Sicherung und Restore-Pfad',
        N'Ein Datei-Umzug auf PRIMARY-Ebene betrifft den Startpfad der Datenbank und sollte immer mit rueckpruefbarem Restore-Plan abgesichert sein.',
        N'Vor dem Umzug Vollbackup, aktuelles Logbackup und den getesteten Wiederanlaufpfad dokumentieren.'
    ),
    (
        2,
        'Downtime',
        'Wartungsfenster und exklusive Zugriffe',
        N'Der physische Move erfordert ein kontrolliertes Offline-Fenster oder einen gestoppten SQL-Server-Dienst fuer die betroffenen Dateien.',
        N'Verbindungsstop, Wartungsfenster und Rueckfallzeit explizit mit Betrieb und Fachseite abstimmen.'
    ),
    (
        3,
        'Filesystem',
        'Zielordner und Dienstkonto',
        N'Der Zielpfad muss vor dem Start existieren und vom SQL-Server-Dienstkonto les- und schreibbar sein.',
        CONCAT(N'Den Zielordner ', @TargetRoleDirectory, N' vorab anlegen und Berechtigungen pruefen.')
    ),
    (
        4,
        'Dependencies',
        'Startparameter, Monitoring und Jobs',
        N'Skripte, Monitoring-Regeln oder Betriebsdokumente koennen feste physische Dateipfade enthalten.',
        N'Pfadabhaengigkeiten in Monitoring, Inventar, Runbooks und Deployment-Checklisten vor dem Umzug erfassen.'
    ),
    (
        5,
        'Verification',
        'Nachkontrolle nach dem Wiederanlauf',
        N'Erst die Rueckpruefung von sys.master_files und sys.database_files bestaetigt, dass Metadaten und physischer Pfad wieder zusammenpassen.',
        N'Direkt nach dem Wiederanlauf die generierte Verifikationsabfrage ausfuehren und Pfade gegen den Plan vergleichen.'
    );

-- 5. Befehlsvorlagen fuer Relocation und Verifikation generieren
CREATE TABLE #CommandTemplate
(
    CommandOrder INT NOT NULL,
    CommandName VARCHAR(100) NOT NULL,
    GeneratedCommand NVARCHAR(MAX) NOT NULL,
    ReviewHint NVARCHAR(320) NOT NULL
);

DECLARE @ModifyFileCommands NVARCHAR(MAX);
DECLARE @OfflineTemplate NVARCHAR(MAX);
DECLARE @VerificationTemplate NVARCHAR(MAX);

SELECT
    @ModifyFileCommands =
        STRING_AGG(
            CONCAT(
                N'ALTER DATABASE ',
                QUOTENAME(@TargetDatabaseName),
                N' MODIFY FILE ( NAME = N''',
                rp.LogicalFileName,
                N''', FILENAME = N''',
                rp.TargetPhysicalFileName,
                N''' );'
            ),
            NCHAR(13) + NCHAR(10)
        ) WITHIN GROUP (ORDER BY rp.PlanOrder)
FROM #RelocationPlan AS rp;

SET @OfflineTemplate =
    CONCAT(
        N'ALTER DATABASE ',
        QUOTENAME(@TargetDatabaseName),
        N' SET SINGLE_USER WITH ROLLBACK IMMEDIATE;',
        NCHAR(13) + NCHAR(10),
        N'ALTER DATABASE ',
        QUOTENAME(@TargetDatabaseName),
        N' SET OFFLINE;',
        NCHAR(13) + NCHAR(10),
        N'-- Physische Dateien gemaess RelocationPlan verschieben.',
        NCHAR(13) + NCHAR(10),
        N'ALTER DATABASE ',
        QUOTENAME(@TargetDatabaseName),
        N' SET ONLINE;',
        NCHAR(13) + NCHAR(10),
        N'ALTER DATABASE ',
        QUOTENAME(@TargetDatabaseName),
        N' SET MULTI_USER;'
    );

SET @VerificationTemplate =
    CONCAT(
        N'SELECT mf.file_id,',
        NCHAR(13) + NCHAR(10),
        N'       mf.name AS logical_file_name,',
        NCHAR(13) + NCHAR(10),
        N'       mf.type_desc,',
        NCHAR(13) + NCHAR(10),
        N'       mf.physical_name,',
        NCHAR(13) + NCHAR(10),
        N'       CASE',
        NCHAR(13) + NCHAR(10),
        N'           WHEN mf.data_space_id = 1 AND mf.type_desc = ''ROWS'' AND mf.physical_name LIKE ''%\primary\%'' THEN ''aligned''',
        NCHAR(13) + NCHAR(10),
        N'           WHEN mf.data_space_id = 1 AND mf.type_desc = ''ROWS'' THEN ''review''',
        NCHAR(13) + NCHAR(10),
        N'           ELSE ''reference''',
        NCHAR(13) + NCHAR(10),
        N'       END AS relocation_status',
        NCHAR(13) + NCHAR(10),
        N'FROM sys.master_files AS mf',
        NCHAR(13) + NCHAR(10),
        N'WHERE mf.database_id = DB_ID(N''',
        REPLACE(@TargetDatabaseName, '''', ''''''),
        N''')',
        NCHAR(13) + NCHAR(10),
        N'ORDER BY mf.file_id;'
    );

INSERT INTO #CommandTemplate
(
    CommandOrder,
    CommandName,
    GeneratedCommand,
    ReviewHint
)
VALUES
    (
        1,
        'Modify file metadata template',
        @ModifyFileCommands,
        N'Die Metadatenanpassung wird vor dem physischen Move vorbereitet, aber von diesem Skript nicht ausgefuehrt.'
    ),
    (
        2,
        'Controlled offline move template',
        @OfflineTemplate,
        N'Der Ablauf bleibt didaktisch; Serviceabhaengigkeiten, Cluster- oder AG-Szenarien muessen separat bewertet werden.'
    ),
    (
        3,
        'Relocation verification query',
        @VerificationTemplate,
        N'Die Rueckpruefung zeigt, ob PRIMARY-Dateien nach dem Umzug im erwarteten primary-Ordner liegen.'
    );

-- 6. Resultsets ausgeben
SELECT
    pfb.BaselineOrder,
    pfb.LogicalFileName,
    pfb.PhysicalFileName,
    pfb.CurrentDirectory,
    pfb.CurrentExtension,
    pfb.CurrentSizeMB,
    pfb.GrowthDisplay,
    pfb.SourceDetail,
    pfb.PathObservation
FROM #PrimaryFileBaseline AS pfb
ORDER BY
    pfb.BaselineOrder;

SELECT
    rp.PlanOrder,
    rp.LogicalFileName,
    rp.CurrentPath,
    rp.TargetDirectory,
    rp.TargetPhysicalFileName,
    rp.RelocationStatus,
    rp.FileMoveCommand,
    rp.ReviewNote
FROM #RelocationPlan AS rp
ORDER BY
    rp.PlanOrder;

SELECT
    pfc.ChecklistOrder,
    pfc.ChecklistArea,
    pfc.CheckItem,
    pfc.WhyItMatters,
    pfc.RecommendedAction
FROM #PreflightChecklist AS pfc
ORDER BY
    pfc.ChecklistOrder;

SELECT
    ct.CommandOrder,
    ct.CommandName,
    ct.GeneratedCommand,
    ct.ReviewHint
FROM #CommandTemplate AS ct
ORDER BY
    ct.CommandOrder;
