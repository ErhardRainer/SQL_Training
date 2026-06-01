/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "DatabaseCreationChecklist.sql"
script_version: "1.0"
script_type: "template"
chapter: "20_Create_Database"
purpose: >
  Erstellt eine lesende Checkliste fuer das Anlegen neuer Datenbanken,
  inklusive Optionen, Dateiplaenen und generierter CREATE-DATABASE-
  Vorlage auf Basis von model- und Instanzmetadaten.

parameters:
  - name: "@TargetDatabaseName"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Name der neu anzulegenden Datenbank fuer die Checkliste und Befehlsvorlage"
  - name: "@TargetCollation"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Optionale Ziel-Collation; NULL uebernimmt die model-Collation"
  - name: "@DataFileDirectory"
    sql_type: "NVARCHAR(260)"
    direction: "IN"
    required: false
    description: "Optionales Zielverzeichnis fuer Datendateien; NULL nutzt den Instanz-Default oder model-Fallback"
  - name: "@LogFileDirectory"
    sql_type: "NVARCHAR(260)"
    direction: "IN"
    required: false
    description: "Optionales Zielverzeichnis fuer Logdateien; NULL nutzt den Instanz-Default oder model-Fallback"
  - name: "@IncludeModelFileBaseline"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = Datei- und Growth-Baseline aus model in die Ausgabe aufnehmen"

result_sets:
  - name: "CreationChecklist"
    description: "Priorisierte Checkliste fuer Namen, Optionen, Dateipfade und Review-Schritte vor CREATE DATABASE"
  - name: "ModelFileBaseline"
    description: "Abgeleitete Daten- und Logdatei-Baseline aus der model-Datenbank"
  - name: "CreateDatabaseTemplate"
    description: "Generierte CREATE DATABASE-Vorlage mit Datei- und Collation-Empfehlungen"

dependencies:
  - "sys.databases"
  - "sys.master_files"
  - "sys.fn_helpcollations"
  - "SERVERPROPERTY"
  - "tempdb temporary tables"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/20_Create_Database/SQLScripts/DatabaseCreationChecklist.md"
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
    description: "Erstversion der lesenden Checkliste fuer CREATE DATABASE inklusive Datei- und Optionsvorlage"

notes:
  - "Das Skript fuehrt kein CREATE DATABASE aus, sondern erzeugt nur Review- und Vorlagenresultsets."
  - "Wenn keine Pfade angegeben werden, arbeitet die Vorlage mit Instanz-Defaults oder model-basierten Fallbacks."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

-- 1. Parameter vorbereiten
DECLARE @TargetDatabaseName SYSNAME = N'TrainingCreateDatabaseDemo';
DECLARE @TargetCollation SYSNAME = NULL;
DECLARE @DataFileDirectory NVARCHAR(260) = NULL;
DECLARE @LogFileDirectory NVARCHAR(260) = NULL;
DECLARE @IncludeModelFileBaseline BIT = 1;

IF @TargetDatabaseName IS NULL OR LTRIM(RTRIM(@TargetDatabaseName)) = N''
BEGIN
    THROW 50000, '@TargetDatabaseName darf nicht leer sein.', 1;
END;

IF @IncludeModelFileBaseline NOT IN (0, 1)
BEGIN
    THROW 50001, '@IncludeModelFileBaseline muss 0 oder 1 sein.', 1;
END;

DECLARE @ModelCollation SYSNAME;
DECLARE @ResolvedTargetCollation SYSNAME;
DECLARE @InstanceDefaultDataPath NVARCHAR(260) = CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(260));
DECLARE @InstanceDefaultLogPath NVARCHAR(260) = CAST(SERVERPROPERTY('InstanceDefaultLogPath') AS NVARCHAR(260));

SELECT
    @ModelCollation = d.collation_name
FROM sys.databases AS d
WHERE d.name = N'model';

IF @ModelCollation IS NULL
BEGIN
    THROW 50002, 'Die model-Datenbank konnte nicht aufgeloest werden.', 1;
END;

SET @ResolvedTargetCollation = COALESCE(NULLIF(LTRIM(RTRIM(@TargetCollation)), N''), @ModelCollation);

IF NOT EXISTS
(
    SELECT 1
    FROM sys.fn_helpcollations() AS hc
    WHERE hc.name = @ResolvedTargetCollation
)
BEGIN
    THROW 50003, '@TargetCollation ist auf dieser Instanz nicht verfuegbar.', 1;
END;

DROP TABLE IF EXISTS #ModelFileBaseline;
DROP TABLE IF EXISTS #CreationChecklist;
DROP TABLE IF EXISTS #CreateDatabaseTemplate;

-- 2. Baseline fuer model-Dateien und Standardpfade ermitteln
CREATE TABLE #ModelFileBaseline
(
    FileOrder INT NOT NULL,
    FileType VARCHAR(20) NOT NULL,
    LogicalFileName SYSNAME NOT NULL,
    SuggestedFileName NVARCHAR(260) NOT NULL,
    SuggestedDirectory NVARCHAR(260) NOT NULL,
    SuggestedGrowth NVARCHAR(40) NOT NULL,
    CurrentSizeMB DECIMAL(18, 2) NOT NULL,
    BaselineSource VARCHAR(120) NOT NULL
);

INSERT INTO #ModelFileBaseline
(
    FileOrder,
    FileType,
    LogicalFileName,
    SuggestedFileName,
    SuggestedDirectory,
    SuggestedGrowth,
    CurrentSizeMB,
    BaselineSource
)
SELECT
    ROW_NUMBER() OVER
    (
        ORDER BY
            CASE mf.type_desc WHEN 'ROWS' THEN 1 ELSE 2 END,
            mf.file_id
    ) AS FileOrder,
    CASE mf.type_desc WHEN 'ROWS' THEN 'DATA' ELSE 'LOG' END AS FileType,
    mf.name AS LogicalFileName,
    CASE
        WHEN mf.type_desc = 'ROWS' THEN CONCAT(@TargetDatabaseName, N'.mdf')
        ELSE CONCAT(@TargetDatabaseName, N'_log.ldf')
    END AS SuggestedFileName,
    CASE
        WHEN mf.type_desc = 'ROWS' THEN
            COALESCE(NULLIF(@DataFileDirectory, N''), NULLIF(@InstanceDefaultDataPath, N''), LEFT(mf.physical_name, LEN(mf.physical_name) - CHARINDEX('\', REVERSE(mf.physical_name))))
        ELSE
            COALESCE(NULLIF(@LogFileDirectory, N''), NULLIF(@InstanceDefaultLogPath, N''), LEFT(mf.physical_name, LEN(mf.physical_name) - CHARINDEX('\', REVERSE(mf.physical_name))))
    END AS SuggestedDirectory,
    CASE
        WHEN mf.is_percent_growth = 1 THEN CONCAT(CONVERT(VARCHAR(20), mf.growth), '%')
        ELSE CONCAT(CONVERT(VARCHAR(30), CAST(mf.growth / 128.0 AS DECIMAL(18, 2))), ' MB')
    END AS SuggestedGrowth,
    CAST(mf.size / 128.0 AS DECIMAL(18, 2)) AS CurrentSizeMB,
    CASE
        WHEN mf.type_desc = 'ROWS' AND NULLIF(@InstanceDefaultDataPath, N'') IS NOT NULL THEN 'InstanceDefaultDataPath'
        WHEN mf.type_desc = 'LOG' AND NULLIF(@InstanceDefaultLogPath, N'') IS NOT NULL THEN 'InstanceDefaultLogPath'
        ELSE 'model master_files fallback'
    END AS BaselineSource
FROM sys.master_files AS mf
WHERE mf.database_id = DB_ID(N'model');

IF NOT EXISTS (SELECT 1 FROM #ModelFileBaseline)
BEGIN
    THROW 50004, 'Fuer model konnten keine Dateibasisinformationen aus sys.master_files gelesen werden.', 1;
END;

-- 3. Priorisierte Checkliste erzeugen
CREATE TABLE #CreationChecklist
(
    ChecklistOrder INT NOT NULL,
    ChecklistArea VARCHAR(40) NOT NULL,
    CheckItem VARCHAR(120) NOT NULL,
    RecommendedAction NVARCHAR(400) NOT NULL,
    WhyItMatters NVARCHAR(320) NOT NULL,
    CurrentBaseline NVARCHAR(320) NOT NULL
);

INSERT INTO #CreationChecklist
(
    ChecklistOrder,
    ChecklistArea,
    CheckItem,
    RecommendedAction,
    WhyItMatters,
    CurrentBaseline
)
VALUES
    (
        1,
        'Naming',
        'Database name',
        CONCAT(N'Den Namen ', QUOTENAME(@TargetDatabaseName), N' gegen Namenskonventionen, Umgebungskennzeichen und Backup-/Monitoring-Regeln pruefen.'),
        N'Konsistente Namen vereinfachen Deployment, Zugriffsteuerung und Betrieb.',
        CONCAT(N'Vorlagenname fuer diesen Run: ', @TargetDatabaseName)
    ),
    (
        2,
        'Collation',
        'Target collation',
        CONCAT(N'CREATE DATABASE mit COLLATE ', @ResolvedTargetCollation, N' nur dann auslassen, wenn Server- und model-Baseline bereits bewusst dem Ziel entsprechen.'),
        N'Explizite Collation verhindert stille Vererbung unpassender Standards.',
        CONCAT(N'model-Collation: ', @ModelCollation, N'; aufgeloestes Ziel: ', @ResolvedTargetCollation)
    ),
    (
        3,
        'Files',
        'Data and log paths',
        N'Data- und Logdateien getrennt planen und mit Instanz-Defaults oder dedizierten Verzeichnissen dokumentieren.',
        N'Dateipfade und Trennung von Daten und Log sind wichtig fuer Betrieb, Wachstum und Wiederherstellung.',
        CONCAT(
            N'Data-Default: ',
            COALESCE(NULLIF(@DataFileDirectory, N''), NULLIF(@InstanceDefaultDataPath, N''), N'model fallback'),
            N'; Log-Default: ',
            COALESCE(NULLIF(@LogFileDirectory, N''), NULLIF(@InstanceDefaultLogPath, N''), N'model fallback')
        )
    ),
    (
        4,
        'Files',
        'Initial size and growth',
        N'Model-Dateigroessen und Autogrowth nur als Startwert betrachten und fuer erwartete Daten- und Loglast anpassen.',
        N'Unpassende Initialgroessen fuehren zu unnoetigem Wachstum und fragmentierten Provisionierungen.',
        N'Aktuelle model-Dateigroessen und Growth-Werte werden im zweiten Resultset bereitgestellt.'
    ),
    (
        5,
        'Options',
        'Recovery and compatibility',
        N'Recovery Model, Compatibility Level und PAGE_VERIFY direkt nach der Anlage gegen die Zielplattform pruefen.',
        N'Diese Optionen beeinflussen Sicherungskonzepte, Optimizer-Verhalten und Fehlererkennung.',
        N'Model dient als Baseline; Detailwerte lassen sich mit ModelDatabaseOptionSnapshot.sql vergleichen.'
    ),
    (
        6,
        'Ownership',
        'Owner and security bootstrap',
        N'DB-Owner, Rollenbootstrap und Zugriffsmodell unmittelbar nach CREATE DATABASE festlegen.',
        N'Ownership und Sicherheitskonventionen sollten nicht implizit offen bleiben.',
        N'Dieses Skript liefert nur die Checkliste; fachliche Rollen werden nicht erfunden.'
    ),
    (
        7,
        'Verification',
        'Post-create verification',
        N'Direkt nach CREATE DATABASE Eigenschaften, Dateien und Optionen mit sys.databases und sys.database_files rueckpruefen.',
        N'Eine kurze Verifikation verhindert, dass Defaults oder Pfade unbemerkt vom Plan abweichen.',
        N'Das dritte Resultset enthaelt dafuer bereits einen Startbefehl und eine Verifikationsabfrage.'
    );

-- 4. CREATE DATABASE-Vorlage generieren
CREATE TABLE #CreateDatabaseTemplate
(
    TemplateOrder INT NOT NULL,
    TemplateName VARCHAR(60) NOT NULL,
    GeneratedCommand NVARCHAR(MAX) NOT NULL,
    ReviewHint NVARCHAR(300) NOT NULL
);

DECLARE @DataDirectory NVARCHAR(260);
DECLARE @LogDirectory NVARCHAR(260);
DECLARE @DataGrowth NVARCHAR(40);
DECLARE @LogGrowth NVARCHAR(40);

SELECT TOP (1)
    @DataDirectory = mfb.SuggestedDirectory,
    @DataGrowth = mfb.SuggestedGrowth
FROM #ModelFileBaseline AS mfb
WHERE mfb.FileType = 'DATA'
ORDER BY
    mfb.FileOrder;

SELECT TOP (1)
    @LogDirectory = mfb.SuggestedDirectory,
    @LogGrowth = mfb.SuggestedGrowth
FROM #ModelFileBaseline AS mfb
WHERE mfb.FileType = 'LOG'
ORDER BY
    mfb.FileOrder;

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
        'Create database template',
        CONCAT(
            N'CREATE DATABASE ',
            QUOTENAME(@TargetDatabaseName),
            NCHAR(13) + NCHAR(10),
            N'ON PRIMARY',
            NCHAR(13) + NCHAR(10),
            N'(',
            NCHAR(13) + NCHAR(10),
            N'    NAME = N''', @TargetDatabaseName, N''',',
            NCHAR(13) + NCHAR(10),
            N'    FILENAME = N''', @DataDirectory, CASE WHEN RIGHT(@DataDirectory, 1) = '\' THEN N'' ELSE N'\' END, @TargetDatabaseName, N'.mdf'',',
            NCHAR(13) + NCHAR(10),
            N'    SIZE = 64MB,',
            NCHAR(13) + NCHAR(10),
            N'    FILEGROWTH = ', @DataGrowth,
            NCHAR(13) + NCHAR(10),
            N')',
            NCHAR(13) + NCHAR(10),
            N'LOG ON',
            NCHAR(13) + NCHAR(10),
            N'(',
            NCHAR(13) + NCHAR(10),
            N'    NAME = N''', @TargetDatabaseName, N'_log'',',
            NCHAR(13) + NCHAR(10),
            N'    FILENAME = N''', @LogDirectory, CASE WHEN RIGHT(@LogDirectory, 1) = '\' THEN N'' ELSE N'\' END, @TargetDatabaseName, N'_log.ldf'',',
            NCHAR(13) + NCHAR(10),
            N'    SIZE = 32MB,',
            NCHAR(13) + NCHAR(10),
            N'    FILEGROWTH = ', @LogGrowth,
            NCHAR(13) + NCHAR(10),
            N')',
            NCHAR(13) + NCHAR(10),
            N'COLLATE ',
            @ResolvedTargetCollation,
            N';'
        ),
        N'Groessen, Filegroups und Pfade bleiben bewusst konservativ und sollen vor produktiver Nutzung angepasst werden.'
    ),
    (
        2,
        'Verification query',
        CONCAT(
            N'SELECT d.name, d.collation_name, d.compatibility_level, d.recovery_model_desc',
            NCHAR(13) + NCHAR(10),
            N'FROM sys.databases AS d',
            NCHAR(13) + NCHAR(10),
            N'WHERE d.name = N''', REPLACE(@TargetDatabaseName, '''', ''''''), N''';',
            NCHAR(13) + NCHAR(10),
            NCHAR(13) + NCHAR(10),
            N'SELECT df.name, df.type_desc, df.physical_name',
            NCHAR(13) + NCHAR(10),
            N'FROM ', QUOTENAME(@TargetDatabaseName), N'.sys.database_files AS df',
            NCHAR(13) + NCHAR(10),
            N'ORDER BY df.file_id;'
        ),
        N'Die Verifikation prueft unmittelbar nach dem Anlegen Collation, zentrale Optionen und Dateizuordnung.'
    );

-- 5. Resultsets ausgeben
SELECT
    cc.ChecklistOrder,
    cc.ChecklistArea,
    cc.CheckItem,
    cc.RecommendedAction,
    cc.WhyItMatters,
    cc.CurrentBaseline
FROM #CreationChecklist AS cc
ORDER BY
    cc.ChecklistOrder;

IF @IncludeModelFileBaseline = 1
BEGIN
    SELECT
        mfb.FileOrder,
        mfb.FileType,
        mfb.LogicalFileName,
        mfb.SuggestedFileName,
        mfb.SuggestedDirectory,
        mfb.SuggestedGrowth,
        mfb.CurrentSizeMB,
        mfb.BaselineSource
    FROM #ModelFileBaseline AS mfb
    ORDER BY
        mfb.FileOrder;
END;

SELECT
    cdt.TemplateOrder,
    cdt.TemplateName,
    cdt.GeneratedCommand,
    cdt.ReviewHint
FROM #CreateDatabaseTemplate AS cdt
ORDER BY
    cdt.TemplateOrder;
