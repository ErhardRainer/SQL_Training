/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "DatabaseOwnerAndOptionsBaseline.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "20_Create_Database"
purpose: >
  Liefert eine Basispruefung fuer Datenbank-Owner, Kompatibilitaetslevel
  und zentrale Datenbankoptionen. Das Skript arbeitet lesend gegen
  sys.databases, vergleicht den Ist-Zustand mit model und optionalen
  Zielvorgaben und erzeugt daraus Review- sowie Remediation-Vorlagen.

parameters:
  - name: "@TargetDatabaseName"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Name der zu pruefenden oder zu bootstrapenden Datenbank"
  - name: "@DesiredOwner"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Optionaler Ziel-Owner fuer die Review; NULL markiert nur den Ist-Zustand"
  - name: "@DesiredCompatibilityLevel"
    sql_type: "SMALLINT"
    direction: "IN"
    required: false
    description: "Optionales Ziel fuer das Compatibility Level; NULL uebernimmt die model-Baseline"
  - name: "@DesiredRecoveryModel"
    sql_type: "NVARCHAR(20)"
    direction: "IN"
    required: false
    description: "Optionales Ziel fuer das Recovery Model; NULL uebernimmt die model-Baseline"
  - name: "@RequireChecksumPageVerify"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = PAGE_VERIFY CHECKSUM als Guardrail bevorzugen"
  - name: "@IncludeCommandTemplates"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zusaetzlich ALTER-DATABASE- und AUTHORIZATION-Vorlagen ausgeben"

result_sets:
  - name: "DatabaseBaseline"
    description: "Vergleicht Ist-Zustand, model-Baseline und Zielwert fuer Owner, Kompatibilitaet und Optionen"
  - name: "ReviewMatrix"
    description: "Leitet priorisierte Review-Hinweise fuer Bootstrap oder Nachschaerfung ab"
  - name: "CommandTemplate"
    description: "Erzeugt optionale Befehlsvorlagen fuer Owner- und Optionsanpassungen"

dependencies:
  - "sys.databases"
  - "SUSER_SNAME"
  - "tempdb temporary tables"
  - "CASE"
  - "CONCAT"
  - "QUOTENAME"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/20_Create_Database/SQLScripts/DatabaseOwnerAndOptionsBaseline.md"
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
    description: "Erstversion der lesenden Baseline fuer Owner, Kompatibilitaet und Kernoptionen"

notes:
  - "Das Skript fuehrt keine ALTER-DATABASE- oder AUTHORIZATION-Befehle aus, sondern erzeugt nur Review- und Befehlsvorlagen."
  - "Falls die Zieldatenbank noch nicht existiert, wird mit model als konservativer Bootstrap-Basis gearbeitet."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

-- 1. Parameter vorbereiten
DECLARE @TargetDatabaseName SYSNAME = N'TrainingOwnerBaselineDemo';
DECLARE @DesiredOwner SYSNAME = NULL;
DECLARE @DesiredCompatibilityLevel SMALLINT = NULL;
DECLARE @DesiredRecoveryModel NVARCHAR(20) = NULL;
DECLARE @RequireChecksumPageVerify BIT = 1;
DECLARE @IncludeCommandTemplates BIT = 1;

IF @TargetDatabaseName IS NULL OR LTRIM(RTRIM(@TargetDatabaseName)) = N''
BEGIN
    THROW 50000, '@TargetDatabaseName darf nicht leer sein.', 1;
END;

IF @DesiredCompatibilityLevel IS NOT NULL
   AND @DesiredCompatibilityLevel NOT BETWEEN 80 AND 180
BEGIN
    THROW 50001, '@DesiredCompatibilityLevel muss zwischen 80 und 180 liegen.', 1;
END;

IF @DesiredRecoveryModel IS NOT NULL
   AND UPPER(LTRIM(RTRIM(@DesiredRecoveryModel))) NOT IN (N'FULL', N'SIMPLE', N'BULK_LOGGED')
BEGIN
    THROW 50002, '@DesiredRecoveryModel muss FULL, SIMPLE oder BULK_LOGGED sein.', 1;
END;

IF @RequireChecksumPageVerify NOT IN (0, 1)
BEGIN
    THROW 50003, '@RequireChecksumPageVerify muss 0 oder 1 sein.', 1;
END;

IF @IncludeCommandTemplates NOT IN (0, 1)
BEGIN
    THROW 50004, '@IncludeCommandTemplates muss 0 oder 1 sein.', 1;
END;

DECLARE @TargetDatabaseId INT;
DECLARE @DatabaseExists BIT = 0;
DECLARE @CurrentOwner SYSNAME;
DECLARE @CurrentCompatibilityLevel SMALLINT;
DECLARE @CurrentRecoveryModel NVARCHAR(20);
DECLARE @CurrentPageVerify NVARCHAR(30);
DECLARE @CurrentAutoClose BIT;
DECLARE @CurrentAutoShrink BIT;
DECLARE @CurrentContainment TINYINT;

DECLARE @ModelOwner SYSNAME;
DECLARE @ModelCompatibilityLevel SMALLINT;
DECLARE @ModelRecoveryModel NVARCHAR(20);
DECLARE @ModelPageVerify NVARCHAR(30);
DECLARE @ModelAutoClose BIT;
DECLARE @ModelAutoShrink BIT;
DECLARE @ModelContainment TINYINT;

SELECT
    @ModelOwner = SUSER_SNAME(d.owner_sid),
    @ModelCompatibilityLevel = d.compatibility_level,
    @ModelRecoveryModel = d.recovery_model_desc,
    @ModelPageVerify = d.page_verify_option_desc,
    @ModelAutoClose = d.is_auto_close_on,
    @ModelAutoShrink = d.is_auto_shrink_on,
    @ModelContainment = d.containment
FROM sys.databases AS d
WHERE d.name = N'model';

IF @ModelCompatibilityLevel IS NULL
BEGIN
    THROW 50005, 'Die model-Datenbank konnte nicht gelesen werden.', 1;
END;

SELECT
    @TargetDatabaseId = d.database_id,
    @DatabaseExists = 1,
    @CurrentOwner = SUSER_SNAME(d.owner_sid),
    @CurrentCompatibilityLevel = d.compatibility_level,
    @CurrentRecoveryModel = d.recovery_model_desc,
    @CurrentPageVerify = d.page_verify_option_desc,
    @CurrentAutoClose = d.is_auto_close_on,
    @CurrentAutoShrink = d.is_auto_shrink_on,
    @CurrentContainment = d.containment
FROM sys.databases AS d
WHERE d.name = @TargetDatabaseName;

DROP TABLE IF EXISTS #DatabaseBaseline;
DROP TABLE IF EXISTS #ReviewMatrix;
DROP TABLE IF EXISTS #CommandTemplate;

-- 2. Baseline fuer Owner, Kompatibilitaet und Kernoptionen ableiten
CREATE TABLE #DatabaseBaseline
(
    CheckOrder INT NOT NULL,
    CheckArea VARCHAR(50) NOT NULL,
    CurrentState VARCHAR(60) NOT NULL,
    ModelBaseline VARCHAR(60) NOT NULL,
    TargetState VARCHAR(60) NOT NULL,
    StatusLabel VARCHAR(20) NOT NULL,
    ReviewFocus VARCHAR(260) NOT NULL,
    RecommendedAction VARCHAR(260) NOT NULL
);

INSERT INTO #DatabaseBaseline
(
    CheckOrder,
    CheckArea,
    CurrentState,
    ModelBaseline,
    TargetState,
    StatusLabel,
    ReviewFocus,
    RecommendedAction
)
VALUES
    (
        1,
        'Database owner',
        COALESCE(@CurrentOwner, 'not created'),
        COALESCE(@ModelOwner, 'unknown'),
        COALESCE(@DesiredOwner, COALESCE(@CurrentOwner, @ModelOwner, 'review explicitly')),
        CASE
            WHEN @DatabaseExists = 0 THEN 'bootstrap'
            WHEN @DesiredOwner IS NULL THEN 'review'
            WHEN @CurrentOwner = @DesiredOwner THEN 'aligned'
            ELSE 'change'
        END,
        'Der Owner beeinflusst Betriebsverantwortung, Sicherheitskontext und spaetere Skriptvorlagen.',
        'Owner bewusst festlegen und nicht implizit aus historischen Defaults uebernehmen.'
    ),
    (
        2,
        'Compatibility level',
        COALESCE(CONVERT(VARCHAR(10), @CurrentCompatibilityLevel), 'not created'),
        CONVERT(VARCHAR(10), @ModelCompatibilityLevel),
        CONVERT(VARCHAR(10), COALESCE(@DesiredCompatibilityLevel, @CurrentCompatibilityLevel, @ModelCompatibilityLevel)),
        CASE
            WHEN @DatabaseExists = 0 THEN 'bootstrap'
            WHEN COALESCE(@DesiredCompatibilityLevel, @CurrentCompatibilityLevel, @ModelCompatibilityLevel) = @CurrentCompatibilityLevel THEN 'aligned'
            ELSE 'change'
        END,
        'Kompatibilitaetslevel steuert Optimizer-Verhalten und Feature-Semantik fuer neue Datenbanken.',
        'Level mit Zielplattform, Tests und Query-Verhalten gemeinsam reviewen.'
    ),
    (
        3,
        'Recovery model',
        COALESCE(@CurrentRecoveryModel, 'not created'),
        @ModelRecoveryModel,
        COALESCE(UPPER(LTRIM(RTRIM(@DesiredRecoveryModel))), @CurrentRecoveryModel, @ModelRecoveryModel),
        CASE
            WHEN @DatabaseExists = 0 THEN 'bootstrap'
            WHEN COALESCE(UPPER(LTRIM(RTRIM(@DesiredRecoveryModel))), @CurrentRecoveryModel, @ModelRecoveryModel) = @CurrentRecoveryModel THEN 'aligned'
            ELSE 'change'
        END,
        'Recovery Model wirkt direkt auf Backup-Pflichten, Log-Wachstum und Restore-Fenster.',
        'Nicht nur nach Gewohnheit setzen, sondern gegen Betriebs- und Backup-Konzept pruefen.'
    ),
    (
        4,
        'PAGE_VERIFY',
        COALESCE(@CurrentPageVerify, 'not created'),
        @ModelPageVerify,
        CASE
            WHEN @RequireChecksumPageVerify = 1 THEN 'CHECKSUM'
            ELSE COALESCE(@CurrentPageVerify, @ModelPageVerify)
        END,
        CASE
            WHEN @DatabaseExists = 0 THEN 'bootstrap'
            WHEN @RequireChecksumPageVerify = 1 AND @CurrentPageVerify <> 'CHECKSUM' THEN 'change'
            ELSE 'aligned'
        END,
        'PAGE_VERIFY ist ein frueher Integritaets-Guardrail und sollte fuer neue Datenbanken selten dem Zufall ueberlassen werden.',
        'Konservativ CHECKSUM bevorzugen und Abweichungen aktiv begruenden.'
    ),
    (
        5,
        'AUTO_CLOSE',
        COALESCE(CASE WHEN @CurrentAutoClose = 1 THEN 'ON' WHEN @CurrentAutoClose = 0 THEN 'OFF' END, 'not created'),
        CASE WHEN @ModelAutoClose = 1 THEN 'ON' ELSE 'OFF' END,
        CASE WHEN COALESCE(@CurrentAutoClose, @ModelAutoClose) = 1 THEN 'ON' ELSE 'OFF' END,
        CASE
            WHEN @DatabaseExists = 0 THEN 'bootstrap'
            WHEN @CurrentAutoClose = 1 THEN 'change'
            ELSE 'aligned'
        END,
        'AUTO_CLOSE ist fuer normale Server- und Trainingsdatenbanken meist ein vermeidbarer Reibungspunkt.',
        'Fuer Standard-Bootstrap OFF erwarten und nur Ausnahmefaelle dokumentieren.'
    ),
    (
        6,
        'AUTO_SHRINK',
        COALESCE(CASE WHEN @CurrentAutoShrink = 1 THEN 'ON' WHEN @CurrentAutoShrink = 0 THEN 'OFF' END, 'not created'),
        CASE WHEN @ModelAutoShrink = 1 THEN 'ON' ELSE 'OFF' END,
        CASE WHEN COALESCE(@CurrentAutoShrink, @ModelAutoShrink) = 1 THEN 'ON' ELSE 'OFF' END,
        CASE
            WHEN @DatabaseExists = 0 THEN 'bootstrap'
            WHEN @CurrentAutoShrink = 1 THEN 'change'
            ELSE 'aligned'
        END,
        'AUTO_SHRINK wirkt oft gegen stabile Datei- und Performance-Planung.',
        'Im Normalfall OFF belassen und Logik fuer Dateiwachstum stattdessen explizit planen.'
    ),
    (
        7,
        'Containment',
        COALESCE(
            CASE @CurrentContainment
                WHEN 0 THEN 'NONE'
                WHEN 1 THEN 'PARTIAL'
            END,
            'not created'
        ),
        CASE @ModelContainment
            WHEN 0 THEN 'NONE'
            WHEN 1 THEN 'PARTIAL'
            ELSE 'UNKNOWN'
        END,
        COALESCE(
            CASE @CurrentContainment
                WHEN 0 THEN 'NONE'
                WHEN 1 THEN 'PARTIAL'
            END,
            CASE @ModelContainment
                WHEN 0 THEN 'NONE'
                WHEN 1 THEN 'PARTIAL'
                ELSE 'UNKNOWN'
            END
        ),
        CASE
            WHEN @DatabaseExists = 0 THEN 'bootstrap'
            ELSE 'review'
        END,
        'Containment sollte als bewusste Architekturentscheidung statt als stiller Nebeneffekt behandelt werden.',
        'Nur dann aendern, wenn Login-, Collation- und Deployment-Auswirkungen bewusst geklaert sind.'
    );

-- 3. Priorisierte Review-Matrix aufbauen
CREATE TABLE #ReviewMatrix
(
    ReviewOrder INT NOT NULL,
    PriorityLevel VARCHAR(10) NOT NULL,
    CheckArea VARCHAR(50) NOT NULL,
    StatusLabel VARCHAR(20) NOT NULL,
    WhyItMatters VARCHAR(260) NOT NULL,
    NextStep VARCHAR(260) NOT NULL
);

INSERT INTO #ReviewMatrix
(
    ReviewOrder,
    PriorityLevel,
    CheckArea,
    StatusLabel,
    WhyItMatters,
    NextStep
)
SELECT
    db.CheckOrder,
    CASE
        WHEN db.CheckArea IN ('Database owner', 'Compatibility level', 'Recovery model', 'PAGE_VERIFY') THEN 'high'
        ELSE 'medium'
    END,
    db.CheckArea,
    db.StatusLabel,
    db.ReviewFocus,
    CASE
        WHEN db.StatusLabel = 'change' THEN CONCAT('Abweichung pruefen und Zielzustand fuer ', db.CheckArea, ' festschreiben.')
        WHEN db.StatusLabel = 'bootstrap' THEN CONCAT('Bootstrap-Vorgabe fuer ', db.CheckArea, ' vor CREATE DATABASE dokumentieren.')
        ELSE CONCAT('Ist-Zustand fuer ', db.CheckArea, ' als Referenz behalten und bei Bedarf periodisch reviewen.')
    END
FROM #DatabaseBaseline AS db;

-- 4. Optionale Befehlsvorlagen ableiten
CREATE TABLE #CommandTemplate
(
    CommandOrder INT NOT NULL,
    CommandName VARCHAR(80) NOT NULL,
    AppliesWhen VARCHAR(120) NOT NULL,
    GeneratedCommand NVARCHAR(MAX) NOT NULL
);

INSERT INTO #CommandTemplate
(
    CommandOrder,
    CommandName,
    AppliesWhen,
    GeneratedCommand
)
VALUES
    (
        1,
        'Set database owner',
        'Nur wenn ein Ziel-Owner festgelegt wurde',
        CONCAT(
            N'ALTER AUTHORIZATION ON DATABASE::',
            QUOTENAME(@TargetDatabaseName),
            N' TO ',
            QUOTENAME(COALESCE(@DesiredOwner, COALESCE(@CurrentOwner, @ModelOwner, N'sa'))),
            N';'
        )
    ),
    (
        2,
        'Set compatibility level',
        'Wenn das Ziel-Level vom Ist-Zustand abweicht',
        CONCAT(
            N'ALTER DATABASE ',
            QUOTENAME(@TargetDatabaseName),
            N' SET COMPATIBILITY_LEVEL = ',
            CONVERT(NVARCHAR(10), COALESCE(@DesiredCompatibilityLevel, @CurrentCompatibilityLevel, @ModelCompatibilityLevel)),
            N';'
        )
    ),
    (
        3,
        'Set recovery model',
        'Wenn das Recovery Model angepasst werden soll',
        CONCAT(
            N'ALTER DATABASE ',
            QUOTENAME(@TargetDatabaseName),
            N' SET RECOVERY ',
            COALESCE(UPPER(LTRIM(RTRIM(@DesiredRecoveryModel))), @CurrentRecoveryModel, @ModelRecoveryModel),
            N';'
        )
    ),
    (
        4,
        'Set page verify',
        'Wenn CHECKSUM als Guardrail gelten soll',
        CONCAT(
            N'ALTER DATABASE ',
            QUOTENAME(@TargetDatabaseName),
            N' SET PAGE_VERIFY ',
            CASE
                WHEN @RequireChecksumPageVerify = 1 THEN N'CHECKSUM'
                ELSE CONVERT(NVARCHAR(30), COALESCE(@CurrentPageVerify, @ModelPageVerify))
            END,
            N';'
        )
    ),
    (
        5,
        'Set auto close',
        'Wenn AUTO_CLOSE deaktiviert bleiben soll',
        CONCAT(
            N'ALTER DATABASE ',
            QUOTENAME(@TargetDatabaseName),
            N' SET AUTO_CLOSE OFF;'
        )
    ),
    (
        6,
        'Set auto shrink',
        'Wenn AUTO_SHRINK deaktiviert bleiben soll',
        CONCAT(
            N'ALTER DATABASE ',
            QUOTENAME(@TargetDatabaseName),
            N' SET AUTO_SHRINK OFF;'
        )
    );

-- 5. Ergebnisse ausgeben
SELECT
    db.CheckOrder,
    db.CheckArea,
    db.CurrentState,
    db.ModelBaseline,
    db.TargetState,
    db.StatusLabel,
    db.ReviewFocus,
    db.RecommendedAction
FROM #DatabaseBaseline AS db
ORDER BY
    db.CheckOrder;

SELECT
    rm.ReviewOrder,
    rm.PriorityLevel,
    rm.CheckArea,
    rm.StatusLabel,
    rm.WhyItMatters,
    rm.NextStep
FROM #ReviewMatrix AS rm
ORDER BY
    rm.ReviewOrder;

IF @IncludeCommandTemplates = 1
BEGIN
    SELECT
        ct.CommandOrder,
        ct.CommandName,
        ct.AppliesWhen,
        ct.GeneratedCommand
    FROM #CommandTemplate AS ct
    ORDER BY
        ct.CommandOrder;
END;
