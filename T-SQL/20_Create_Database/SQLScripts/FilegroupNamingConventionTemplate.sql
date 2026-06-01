/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "FilegroupNamingConventionTemplate.sql"
script_version: "1.0"
script_type: "template"
chapter: "20_Create_Database"
purpose: >
  Leitet eine didaktische Benennungskonvention fuer Filegroups sowie
  logische und physische Dateien ab, prueft Beispielnamen gegen diese
  Baseline und erzeugt daraus wiederverwendbare CREATE-DATABASE- und
  ALTER-DATABASE-Vorlagen ohne selbst DDL auszufuehren.

parameters:
  - name: "@TargetDatabaseName"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Zieldatenbankname fuer die Namensvorlage"
  - name: "@PrimaryPrefix"
    sql_type: "NVARCHAR(30)"
    direction: "IN"
    required: false
    description: "Rollenkuerzel fuer die primaere Datendatei und Filegroup"
  - name: "@DataPrefix"
    sql_type: "NVARCHAR(30)"
    direction: "IN"
    required: false
    description: "Rollenkuerzel fuer weitere Datenfiles in der DATA-Filegroup"
  - name: "@ArchivePrefix"
    sql_type: "NVARCHAR(30)"
    direction: "IN"
    required: false
    description: "Rollenkuerzel fuer optionale Archiv-Filegroups und Dateien"
  - name: "@LogPrefix"
    sql_type: "NVARCHAR(30)"
    direction: "IN"
    required: false
    description: "Rollenkuerzel fuer Logdateien"
  - name: "@DataFileCount"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Anzahl geplanter Datenfiles fuer die DATA-Filegroup"
  - name: "@IncludeArchiveGroup"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zusaetzliche ARCHIVE-Benennung und Vorlage anzeigen"
  - name: "@SampleDatabaseName"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Optionale Referenzdatenbank fuer bestehende Dateinamen; NULL nutzt nur Demo-Kandidaten"

result_sets:
  - name: "NamingConventionChecklist"
    description: "Leitplanken fuer stabile Filegroup-, Logical-File- und Physical-File-Namen"
  - name: "NamingPlan"
    description: "Konkreter Namensplan fuer PRIMARY, DATA, ARCHIVE und LOG"
  - name: "NamingReview"
    description: "Vergleicht bestehende oder didaktische Kandidaten mit der Zielkonvention"
  - name: "CommandTemplate"
    description: "Erzeugt CREATE-DATABASE- und Rename-Vorlagen auf Basis der Benennungsregeln"

dependencies:
  - "sys.databases"
  - "sys.master_files"
  - "tempdb temporary tables"
  - "CASE"
  - "CONCAT"
  - "QUOTENAME"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/20_Create_Database/SQLScripts/FilegroupNamingConventionTemplate.md"
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
    description: "Erstversion der didaktischen Benennungsvorlage fuer Filegroups und Dateien"

notes:
  - "Das Skript fuehrt keine Umbenennungen aus, sondern erzeugt nur Review- und Vorlagenresultsets."
  - "Ohne Referenzdatenbank nutzt die NamingReview didaktische Demo-Kandidaten mit typischen Benennungsfehlern."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

-- 1. Parameter vorbereiten
DECLARE @TargetDatabaseName SYSNAME = N'TrainingNamingDemo';
DECLARE @PrimaryPrefix NVARCHAR(30) = N'PRIMARY';
DECLARE @DataPrefix NVARCHAR(30) = N'DATA';
DECLARE @ArchivePrefix NVARCHAR(30) = N'ARCHIVE';
DECLARE @LogPrefix NVARCHAR(30) = N'LOG';
DECLARE @DataFileCount INT = 2;
DECLARE @IncludeArchiveGroup BIT = 1;
DECLARE @SampleDatabaseName SYSNAME = N'model';

IF @TargetDatabaseName IS NULL OR LTRIM(RTRIM(@TargetDatabaseName)) = N''
BEGIN
    THROW 50000, '@TargetDatabaseName darf nicht leer sein.', 1;
END;

IF @PrimaryPrefix IS NULL OR LTRIM(RTRIM(@PrimaryPrefix)) = N''
BEGIN
    THROW 50001, '@PrimaryPrefix darf nicht leer sein.', 1;
END;

IF @DataPrefix IS NULL OR LTRIM(RTRIM(@DataPrefix)) = N''
BEGIN
    THROW 50002, '@DataPrefix darf nicht leer sein.', 1;
END;

IF @ArchivePrefix IS NULL OR LTRIM(RTRIM(@ArchivePrefix)) = N''
BEGIN
    THROW 50003, '@ArchivePrefix darf nicht leer sein.', 1;
END;

IF @LogPrefix IS NULL OR LTRIM(RTRIM(@LogPrefix)) = N''
BEGIN
    THROW 50004, '@LogPrefix darf nicht leer sein.', 1;
END;

IF @DataFileCount < 1 OR @DataFileCount > 8
BEGIN
    THROW 50005, '@DataFileCount muss zwischen 1 und 8 liegen.', 1;
END;

IF @IncludeArchiveGroup NOT IN (0, 1)
BEGIN
    THROW 50006, '@IncludeArchiveGroup muss 0 oder 1 sein.', 1;
END;

IF @SampleDatabaseName IS NOT NULL AND DB_ID(@SampleDatabaseName) IS NULL
BEGIN
    THROW 50007, '@SampleDatabaseName verweist auf keine vorhandene Datenbank.', 1;
END;

DROP TABLE IF EXISTS #NamingConventionChecklist;
DROP TABLE IF EXISTS #NamingPlan;
DROP TABLE IF EXISTS #CandidateNames;
DROP TABLE IF EXISTS #NamingReview;
DROP TABLE IF EXISTS #CommandTemplate;

-- 2. Leitplanken fuer Benennungskonventionen aufbauen
CREATE TABLE #NamingConventionChecklist
(
    ChecklistOrder INT NOT NULL,
    NamingArea VARCHAR(40) NOT NULL,
    RuleName VARCHAR(80) NOT NULL,
    RecommendedPattern NVARCHAR(220) NOT NULL,
    WhyItMatters NVARCHAR(260) NOT NULL,
    ExampleValue NVARCHAR(220) NOT NULL
);

INSERT INTO #NamingConventionChecklist
(
    ChecklistOrder,
    NamingArea,
    RuleName,
    RecommendedPattern,
    WhyItMatters,
    ExampleValue
)
VALUES
    (
        1,
        'Database prefix',
        'Stable database stem',
        N'Jeder Name beginnt mit dem Datenbankstamm und fuegt danach nur Rollen- oder Sequenzteile an.',
        N'Der gemeinsame Stamm erleichtert Monitoring, Restore, ALTER DATABASE und automatisierte Reviews.',
        CONCAT(@TargetDatabaseName, N'_PRIMARY')
    ),
    (
        2,
        'Filegroup role',
        'Uppercase role token',
        N'Filegroups nutzen kurze Rollen-Tokens wie PRIMARY, DATA oder ARCHIVE in Grossbuchstaben.',
        N'Rollen-Tokens machen die fachliche Absicht sichtbar und bleiben in Skriptlisten gut scanbar.',
        CONCAT(@TargetDatabaseName, N'_', @DataPrefix)
    ),
    (
        3,
        'Sequence',
        'Two-digit numbering',
        N'Mehrere Dateien erhalten fortlaufende zweistellige Nummern wie 01, 02 oder 03.',
        N'Feste Breite sortiert stabil, vermeidet spaetere Mischformen und passt zu Inventory-Reports.',
        CONCAT(@TargetDatabaseName, N'_', @DataPrefix, N'_01')
    ),
    (
        4,
        'Physical file',
        'Extension matches role',
        N'PRIMARY-Dateien enden auf .mdf, weitere Datenfiles auf .ndf und Logs auf .ldf.',
        N'Die Erweiterung macht den Dateityp sofort sichtbar und reduziert Review-Fehler bei Vorlagen.',
        CONCAT(@TargetDatabaseName, N'_', @LogPrefix, N'.ldf')
    ),
    (
        5,
        'Separators',
        'Use underscore only',
        N'Zwischen Stamm, Rolle und Sequenz werden nur Unterstriche verwendet; Leerzeichen und Bindestriche entfallen.',
        N'Einheitliche Trennzeichen vereinfachen Copy/Paste, Dateisysteme und automatisierte Pattern-Pruefungen.',
        CONCAT(@TargetDatabaseName, N'_', @ArchivePrefix, N'_01')
    );

-- 3. Ziel-Namensplan fuer Filegroups und Dateien erzeugen
CREATE TABLE #NamingPlan
(
    PlanOrder INT NOT NULL,
    FilegroupName SYSNAME NOT NULL,
    FileRole VARCHAR(20) NOT NULL,
    LogicalName SYSNAME NOT NULL,
    PhysicalFileName NVARCHAR(260) NOT NULL,
    ExampleClause NVARCHAR(300) NOT NULL,
    ReviewNote NVARCHAR(220) NOT NULL
);

INSERT INTO #NamingPlan
(
    PlanOrder,
    FilegroupName,
    FileRole,
    LogicalName,
    PhysicalFileName,
    ExampleClause,
    ReviewNote
)
VALUES
    (
        1,
        N'PRIMARY',
        'DATA',
        CONCAT(@TargetDatabaseName, N'_', @PrimaryPrefix),
        CONCAT(@TargetDatabaseName, N'_', @PrimaryPrefix, N'.mdf'),
        CONCAT(N'NAME = N''', @TargetDatabaseName, N'_', @PrimaryPrefix, N''', FILENAME = N''', @TargetDatabaseName, N'_', @PrimaryPrefix, N'.mdf'''),
        N'Die primaere Datei bleibt knapp benannt und traegt nur Rolle statt zusaetzlicher Sequenz.'
    );

;WITH Numbers AS
(
    SELECT 1 AS FileNumber
    UNION ALL
    SELECT FileNumber + 1
    FROM Numbers
    WHERE FileNumber < @DataFileCount
)
INSERT INTO #NamingPlan
(
    PlanOrder,
    FilegroupName,
    FileRole,
    LogicalName,
    PhysicalFileName,
    ExampleClause,
    ReviewNote
)
SELECT
    10 + n.FileNumber AS PlanOrder,
    N'DATA' AS FilegroupName,
    'DATA' AS FileRole,
    CONCAT(@TargetDatabaseName, N'_', @DataPrefix, N'_', RIGHT(CONCAT(N'0', CONVERT(NVARCHAR(10), n.FileNumber)), 2)) AS LogicalName,
    CONCAT(@TargetDatabaseName, N'_', @DataPrefix, N'_', RIGHT(CONCAT(N'0', CONVERT(NVARCHAR(10), n.FileNumber)), 2), N'.ndf') AS PhysicalFileName,
    CONCAT(
        N'NAME = N''',
        @TargetDatabaseName,
        N'_',
        @DataPrefix,
        N'_',
        RIGHT(CONCAT(N'0', CONVERT(NVARCHAR(10), n.FileNumber)), 2),
        N''', FILENAME = N''',
        @TargetDatabaseName,
        N'_',
        @DataPrefix,
        N'_',
        RIGHT(CONCAT(N'0', CONVERT(NVARCHAR(10), n.FileNumber)), 2),
        N'.ndf'''
    ) AS ExampleClause,
    N'Die DATA-Dateien verwenden zweistellige Nummern fuer stabile Sortierung.' AS ReviewNote
FROM Numbers AS n
OPTION (MAXRECURSION 8);

IF @IncludeArchiveGroup = 1
BEGIN
    INSERT INTO #NamingPlan
    (
        PlanOrder,
        FilegroupName,
        FileRole,
        LogicalName,
        PhysicalFileName,
        ExampleClause,
        ReviewNote
    )
    VALUES
        (
            80,
            N'ARCHIVE',
            'DATA',
            CONCAT(@TargetDatabaseName, N'_', @ArchivePrefix, N'_01'),
            CONCAT(@TargetDatabaseName, N'_', @ArchivePrefix, N'_01.ndf'),
            CONCAT(N'NAME = N''', @TargetDatabaseName, N'_', @ArchivePrefix, N'_01'', FILENAME = N''', @TargetDatabaseName, N'_', @ArchivePrefix, N'_01.ndf'''),
            N'ARCHIVE bleibt optional und nutzt dieselbe Unterstrich- und Nummernkonvention wie DATA.'
        );
END;

INSERT INTO #NamingPlan
(
    PlanOrder,
    FilegroupName,
    FileRole,
    LogicalName,
    PhysicalFileName,
    ExampleClause,
    ReviewNote
)
VALUES
    (
        90,
        N'LOG',
        'LOG',
        CONCAT(@TargetDatabaseName, N'_', @LogPrefix),
        CONCAT(@TargetDatabaseName, N'_', @LogPrefix, N'.ldf'),
        CONCAT(N'NAME = N''', @TargetDatabaseName, N'_', @LogPrefix, N''', FILENAME = N''', @TargetDatabaseName, N'_', @LogPrefix, N'.ldf'''),
        N'Die Logdatei verwendet keine Sequenz, solange nur eine Datei geplant ist.'
    );

-- 4. Bestehende oder didaktische Kandidaten gegen die Baseline pruefen
CREATE TABLE #CandidateNames
(
    CandidateOrder INT NOT NULL,
    CandidateSource VARCHAR(20) NOT NULL,
    CandidateType VARCHAR(20) NOT NULL,
    CandidateName NVARCHAR(260) NOT NULL,
    ExpectedRole VARCHAR(20) NOT NULL
);

IF @SampleDatabaseName IS NOT NULL
BEGIN
    INSERT INTO #CandidateNames
    (
        CandidateOrder,
        CandidateSource,
        CandidateType,
        CandidateName,
        ExpectedRole
    )
    SELECT
        ROW_NUMBER() OVER (ORDER BY mf.file_id),
        'catalog' AS CandidateSource,
        mf.type_desc AS CandidateType,
        mf.name AS CandidateName,
        CASE WHEN mf.type_desc = 'LOG' THEN 'LOG' ELSE 'DATA' END AS ExpectedRole
    FROM sys.master_files AS mf
    WHERE mf.database_id = DB_ID(@SampleDatabaseName);
END;
ELSE
BEGIN
    INSERT INTO #CandidateNames
    (
        CandidateOrder,
        CandidateSource,
        CandidateType,
        CandidateName,
        ExpectedRole
    )
    VALUES
        (1, 'demo', 'ROWS', N'TrainingNamingDemoData1', 'DATA'),
        (2, 'demo', 'ROWS', N'TrainingNamingDemo-DATA-02', 'DATA'),
        (3, 'demo', 'ROWS', N'TrainingNamingDemo_archive_1', 'DATA'),
        (4, 'demo', 'LOG', N'TrainingNamingDemo Log', 'LOG');
END;

CREATE TABLE #NamingReview
(
    ReviewOrder INT NOT NULL,
    CandidateSource VARCHAR(20) NOT NULL,
    CandidateType VARCHAR(20) NOT NULL,
    CandidateName NVARCHAR(260) NOT NULL,
    ReviewSeverity VARCHAR(12) NOT NULL,
    ExpectedPattern NVARCHAR(220) NOT NULL,
    Findings NVARCHAR(260) NOT NULL,
    Recommendation NVARCHAR(260) NOT NULL
);

INSERT INTO #NamingReview
(
    ReviewOrder,
    CandidateSource,
    CandidateType,
    CandidateName,
    ReviewSeverity,
    ExpectedPattern,
    Findings,
    Recommendation
)
SELECT
    cn.CandidateOrder,
    cn.CandidateSource,
    cn.CandidateType,
    cn.CandidateName,
    CASE
        WHEN cn.ExpectedRole = 'LOG' AND cn.CandidateName = CONCAT(@TargetDatabaseName, N'_', @LogPrefix) THEN 'low'
        WHEN cn.ExpectedRole = 'DATA' AND cn.CandidateName LIKE CONCAT(@TargetDatabaseName, N'_', @DataPrefix, N'[_]__') THEN 'low'
        WHEN cn.ExpectedRole = 'DATA' AND cn.CandidateName = CONCAT(@TargetDatabaseName, N'_', @PrimaryPrefix) THEN 'low'
        WHEN cn.CandidateName LIKE N'% %' OR cn.CandidateName LIKE N'%-%' THEN 'high'
        WHEN cn.CandidateName NOT LIKE CONCAT(@TargetDatabaseName, N'[_]%') THEN 'high'
        WHEN cn.CandidateName NOT LIKE N'%[_]__' AND cn.ExpectedRole = 'DATA' THEN 'medium'
        ELSE 'medium'
    END AS ReviewSeverity,
    CASE
        WHEN cn.ExpectedRole = 'LOG' THEN CONCAT(@TargetDatabaseName, N'_', @LogPrefix)
        WHEN cn.CandidateOrder = 1 THEN CONCAT(@TargetDatabaseName, N'_', @PrimaryPrefix)
        ELSE CONCAT(@TargetDatabaseName, N'_', @DataPrefix, N'_NN')
    END AS ExpectedPattern,
    CASE
        WHEN cn.ExpectedRole = 'LOG' AND cn.CandidateName = CONCAT(@TargetDatabaseName, N'_', @LogPrefix) THEN N'Logname entspricht der Zielkonvention.'
        WHEN cn.ExpectedRole = 'DATA' AND cn.CandidateName LIKE CONCAT(@TargetDatabaseName, N'_', @DataPrefix, N'[_]__') THEN N'Datenfile folgt bereits Datenbankstamm, Rollenkuerzel und zweistelliger Sequenz.'
        WHEN cn.ExpectedRole = 'DATA' AND cn.CandidateName = CONCAT(@TargetDatabaseName, N'_', @PrimaryPrefix) THEN N'Primaere Datei folgt der knappen PRIMARY-Konvention.'
        WHEN cn.CandidateName LIKE N'% %' THEN N'Der Name enthaelt Leerzeichen und ist fuer Skriptvorlagen unnoetig fehleranfaellig.'
        WHEN cn.CandidateName LIKE N'%-%' THEN N'Der Name nutzt Bindestriche statt Unterstriche und mischt damit Trennzeichen.'
        WHEN cn.CandidateName NOT LIKE CONCAT(@TargetDatabaseName, N'[_]%') THEN N'Der gemeinsame Datenbankstamm fehlt oder weicht von der Zielbenennung ab.'
        WHEN cn.CandidateName NOT LIKE N'%[_]__' AND cn.ExpectedRole = 'DATA' THEN N'Bei mehreren Datenfiles fehlt die zweistellige Sequenz am Ende.'
        ELSE N'Der Name ist teilweise nah an der Baseline, aber Rolle oder Sequenz bleiben uneinheitlich.'
    END AS Findings,
    CASE
        WHEN cn.ExpectedRole = 'LOG' THEN CONCAT(N'Bevorzuge ', @TargetDatabaseName, N'_', @LogPrefix, N' fuer die Logdatei.')
        WHEN cn.CandidateOrder = 1 THEN CONCAT(N'Nutze ', @TargetDatabaseName, N'_', @PrimaryPrefix, N' fuer die primaere Datei.')
        ELSE CONCAT(N'Nutze ', @TargetDatabaseName, N'_', @DataPrefix, N'_', RIGHT(CONCAT(N'0', CONVERT(NVARCHAR(10), cn.CandidateOrder)), 2), N' fuer nummerierte Datenfiles.')
    END AS Recommendation
FROM #CandidateNames AS cn;

-- 5. Vorlagen fuer CREATE DATABASE und Rename-Reviews erzeugen
CREATE TABLE #CommandTemplate
(
    CommandOrder INT NOT NULL,
    CommandName VARCHAR(100) NOT NULL,
    GeneratedCommand NVARCHAR(MAX) NOT NULL,
    ReviewHint NVARCHAR(260) NOT NULL
);

DECLARE @PrimaryClause NVARCHAR(MAX);
DECLARE @DataClause NVARCHAR(MAX);
DECLARE @ArchiveClause NVARCHAR(MAX);
DECLARE @LogClause NVARCHAR(MAX);

SELECT TOP (1)
    @PrimaryClause = CONCAT(
        N'ON PRIMARY (',
        np.ExampleClause,
        N')'
    )
FROM #NamingPlan AS np
WHERE np.FilegroupName = N'PRIMARY';

SELECT
    @DataClause =
        STRING_AGG(np.ExampleClause, N', ')
FROM #NamingPlan AS np
WHERE np.FilegroupName = N'DATA';

SELECT TOP (1)
    @ArchiveClause = np.ExampleClause
FROM #NamingPlan AS np
WHERE np.FilegroupName = N'ARCHIVE';

SELECT TOP (1)
    @LogClause = CONCAT(N'LOG ON (', np.ExampleClause, N')')
FROM #NamingPlan AS np
WHERE np.FilegroupName = N'LOG';

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
        'Create database naming template',
        CONCAT(
            N'CREATE DATABASE ',
            QUOTENAME(@TargetDatabaseName),
            NCHAR(13) + NCHAR(10),
            @PrimaryClause,
            NCHAR(13) + NCHAR(10),
            N', FILEGROUP [DATA] (',
            @DataClause,
            N')',
            CASE
                WHEN @IncludeArchiveGroup = 1 AND @ArchiveClause IS NOT NULL THEN
                    CONCAT(
                        NCHAR(13) + NCHAR(10),
                        N', FILEGROUP [ARCHIVE] (',
                        @ArchiveClause,
                        N')'
                    )
                ELSE N''
            END,
            NCHAR(13) + NCHAR(10),
            @LogClause,
            N';'
        ),
        N'Nutze die Vorlage als Namensbaseline; reale Pfade und Groessen werden bewusst separat gepflegt.'
    ),
    (
        2,
        'Rename review template',
        CONCAT(
            N'-- Beispiel fuer die Review-Nacharbeit von Logical Names',
            NCHAR(13) + NCHAR(10),
            N'ALTER DATABASE ',
            QUOTENAME(@TargetDatabaseName),
            N' MODIFY FILE ( NAME = N''OldLogicalName'', NEWNAME = N''',
            @TargetDatabaseName,
            N'_',
            @DataPrefix,
            N'_01'' );'
        ),
        N'Die zweite Vorlage bleibt absichtlich generisch, damit Reviews erst nach Bestandspruefung umsetzen.'
    );

-- 6. Resultsets ausgeben
SELECT
    ncc.ChecklistOrder,
    ncc.NamingArea,
    ncc.RuleName,
    ncc.RecommendedPattern,
    ncc.WhyItMatters,
    ncc.ExampleValue
FROM #NamingConventionChecklist AS ncc
ORDER BY
    ncc.ChecklistOrder;

SELECT
    np.PlanOrder,
    np.FilegroupName,
    np.FileRole,
    np.LogicalName,
    np.PhysicalFileName,
    np.ExampleClause,
    np.ReviewNote
FROM #NamingPlan AS np
ORDER BY
    np.PlanOrder;

SELECT
    nr.ReviewOrder,
    nr.CandidateSource,
    nr.CandidateType,
    nr.CandidateName,
    nr.ReviewSeverity,
    nr.ExpectedPattern,
    nr.Findings,
    nr.Recommendation
FROM #NamingReview AS nr
ORDER BY
    nr.ReviewOrder;

SELECT
    ct.CommandOrder,
    ct.CommandName,
    ct.GeneratedCommand,
    ct.ReviewHint
FROM #CommandTemplate AS ct
ORDER BY
    ct.CommandOrder;
