/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "DatabaseScopedConfigBaseline.sql"
script_version: "1.0"
script_type: "template"
chapter: "20_Create_Database"
purpose: >
  Leitet eine Baseline typischer DATABASE SCOPED CONFIGURATION-
  Einstellungen fuer neue Datenbanken ab, vergleicht Parameterwerte mit
  optionalen Referenzwerten der aktuellen Datenbank und erzeugt
  passende ALTER DATABASE SCOPED CONFIGURATION Vorlagen.

parameters:
  - name: "@TargetDatabaseName"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Name der Ziel-Datenbank fuer generierte Baseline- und Befehlsvorlagen"
  - name: "@UseCurrentDatabaseAsReference"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = fehlende Sollwerte aus sys.database_scoped_configurations der aktuellen Datenbank ableiten"
  - name: "@LegacyCardinalityEstimation"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "Optionaler Sollwert fuer LEGACY_CARDINALITY_ESTIMATION"
  - name: "@QueryOptimizerHotfixes"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "Optionaler Sollwert fuer QUERY_OPTIMIZER_HOTFIXES"
  - name: "@MaxDop"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Optionaler Sollwert fuer MAXDOP; NULL nutzt Referenz oder den dokumentierten Default 0"
  - name: "@ParameterSniffing"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "Optionaler Sollwert fuer PARAMETER_SNIFFING"

result_sets:
  - name: "ScopedConfigBaseline"
    description: "Zeigt Referenz, aufgeloesten Zielwert und Review-Hinweise fuer typische Scoped Configs"
  - name: "BootstrapChecklist"
    description: "Priorisierte Checkliste fuer das Setzen und Testen der Scoped Configuration Baseline"
  - name: "ScopedConfigCommandTemplate"
    description: "Generiert USE- plus ALTER DATABASE SCOPED CONFIGURATION Vorlagen fuer die Ziel-Datenbank"

dependencies:
  - "sys.database_scoped_configurations"
  - "DB_NAME"
  - "tempdb temporary tables"
  - "CASE"
  - "CONCAT"
  - "QUOTENAME"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/20_Create_Database/SQLScripts/DatabaseScopedConfigBaseline.md"
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
    description: "Erstversion der lesenden Baseline fuer typische database scoped configurations"

notes:
  - "Das Skript erzeugt nur Review-Resultsets und Befehlsvorlagen; es fuehrt keine ALTER DATABASE SCOPED CONFIGURATION Befehle aus."
  - "Fehlende Sollwerte werden konservativ aus der aktuellen Datenbank oder aus dokumentierten Trainingsdefaults abgeleitet."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

-- 1. Parameter vorbereiten
DECLARE @TargetDatabaseName SYSNAME = N'TrainingScopedConfigDemo';
DECLARE @UseCurrentDatabaseAsReference BIT = 1;
DECLARE @LegacyCardinalityEstimation BIT = NULL;
DECLARE @QueryOptimizerHotfixes BIT = NULL;
DECLARE @MaxDop INT = NULL;
DECLARE @ParameterSniffing BIT = NULL;

IF @TargetDatabaseName IS NULL OR LTRIM(RTRIM(@TargetDatabaseName)) = N''
BEGIN
    THROW 50000, '@TargetDatabaseName darf nicht leer sein.', 1;
END;

IF @UseCurrentDatabaseAsReference NOT IN (0, 1)
BEGIN
    THROW 50001, '@UseCurrentDatabaseAsReference muss 0 oder 1 sein.', 1;
END;

IF @LegacyCardinalityEstimation IS NOT NULL
   AND @LegacyCardinalityEstimation NOT IN (0, 1)
BEGIN
    THROW 50002, '@LegacyCardinalityEstimation muss NULL, 0 oder 1 sein.', 1;
END;

IF @QueryOptimizerHotfixes IS NOT NULL
   AND @QueryOptimizerHotfixes NOT IN (0, 1)
BEGIN
    THROW 50003, '@QueryOptimizerHotfixes muss NULL, 0 oder 1 sein.', 1;
END;

IF @MaxDop IS NOT NULL
   AND @MaxDop NOT BETWEEN 0 AND 64
BEGIN
    THROW 50004, '@MaxDop muss zwischen 0 und 64 liegen.', 1;
END;

IF @ParameterSniffing IS NOT NULL
   AND @ParameterSniffing NOT IN (0, 1)
BEGIN
    THROW 50005, '@ParameterSniffing muss NULL, 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #ReferenceScopedConfig;
DROP TABLE IF EXISTS #ScopedConfigBaseline;
DROP TABLE IF EXISTS #BootstrapChecklist;
DROP TABLE IF EXISTS #ScopedConfigCommandTemplate;

-- 2. Optionale Referenzbasis aus der aktuellen Datenbank lesen
CREATE TABLE #ReferenceScopedConfig
(
    ConfigName SYSNAME NOT NULL,
    PrimaryValue SQL_VARIANT NULL,
    SecondaryValue SQL_VARIANT NULL
);

IF @UseCurrentDatabaseAsReference = 1
BEGIN
    INSERT INTO #ReferenceScopedConfig
    (
        ConfigName,
        PrimaryValue,
        SecondaryValue
    )
    SELECT
        dsc.name,
        dsc.value,
        dsc.value_for_secondary
    FROM sys.database_scoped_configurations AS dsc
    WHERE dsc.name IN
    (
        N'LEGACY_CARDINALITY_ESTIMATION',
        N'QUERY_OPTIMIZER_HOTFIXES',
        N'MAXDOP',
        N'PARAMETER_SNIFFING'
    );
END;

-- 3. Baseline-Matrix fuer neue Datenbanken aufbauen
CREATE TABLE #ScopedConfigBaseline
(
    ConfigOrder INT NOT NULL,
    ConfigName VARCHAR(80) NOT NULL,
    ReferenceSource VARCHAR(80) NOT NULL,
    ReferenceValue VARCHAR(30) NOT NULL,
    TargetValue VARCHAR(30) NOT NULL,
    WhyRelevant VARCHAR(260) NOT NULL,
    ReviewFocus VARCHAR(260) NOT NULL
);

INSERT INTO #ScopedConfigBaseline
(
    ConfigOrder,
    ConfigName,
    ReferenceSource,
    ReferenceValue,
    TargetValue,
    WhyRelevant,
    ReviewFocus
)
VALUES
    (
        1,
        'LEGACY_CARDINALITY_ESTIMATION',
        CASE
            WHEN @LegacyCardinalityEstimation IS NOT NULL THEN 'explicit parameter'
            WHEN EXISTS (SELECT 1 FROM #ReferenceScopedConfig AS r WHERE r.ConfigName = N'LEGACY_CARDINALITY_ESTIMATION') THEN CONCAT('current database ', DB_NAME())
            ELSE 'documented training default'
        END,
        CASE
            WHEN EXISTS (SELECT 1 FROM #ReferenceScopedConfig AS r WHERE r.ConfigName = N'LEGACY_CARDINALITY_ESTIMATION' AND TRY_CONVERT(INT, r.PrimaryValue) = 1) THEN 'ON'
            WHEN EXISTS (SELECT 1 FROM #ReferenceScopedConfig AS r WHERE r.ConfigName = N'LEGACY_CARDINALITY_ESTIMATION') THEN 'OFF'
            ELSE 'OFF'
        END,
        CASE
            WHEN COALESCE(@LegacyCardinalityEstimation, TRY_CONVERT(INT, (SELECT TOP (1) r.PrimaryValue FROM #ReferenceScopedConfig AS r WHERE r.ConfigName = N'LEGACY_CARDINALITY_ESTIMATION')), 0) = 1 THEN 'ON'
            ELSE 'OFF'
        END,
        'Die Einstellung beeinflusst das Optimizer-Verhalten und kann Planaenderungen zwischen Legacy- und aktuellem CE ausloesen.',
        'Nur bei begruendetem Workload-Bedarf aktivieren und gegen Query Store oder Regressionsmessungen absichern.'
    ),
    (
        2,
        'QUERY_OPTIMIZER_HOTFIXES',
        CASE
            WHEN @QueryOptimizerHotfixes IS NOT NULL THEN 'explicit parameter'
            WHEN EXISTS (SELECT 1 FROM #ReferenceScopedConfig AS r WHERE r.ConfigName = N'QUERY_OPTIMIZER_HOTFIXES') THEN CONCAT('current database ', DB_NAME())
            ELSE 'documented training default'
        END,
        CASE
            WHEN EXISTS (SELECT 1 FROM #ReferenceScopedConfig AS r WHERE r.ConfigName = N'QUERY_OPTIMIZER_HOTFIXES' AND TRY_CONVERT(INT, r.PrimaryValue) = 1) THEN 'ON'
            WHEN EXISTS (SELECT 1 FROM #ReferenceScopedConfig AS r WHERE r.ConfigName = N'QUERY_OPTIMIZER_HOTFIXES') THEN 'OFF'
            ELSE 'OFF'
        END,
        CASE
            WHEN COALESCE(@QueryOptimizerHotfixes, TRY_CONVERT(INT, (SELECT TOP (1) r.PrimaryValue FROM #ReferenceScopedConfig AS r WHERE r.ConfigName = N'QUERY_OPTIMIZER_HOTFIXES')), 0) = 1 THEN 'ON'
            ELSE 'OFF'
        END,
        'Optimizer Hotfixes koennen Planwahl und Upgrade-Verhalten beeinflussen, ohne dass T-SQL-Code geaendert wird.',
        'Mit Kompatibilitaetslevel, Teststrategie und Rollout-Fenster gemeinsam entscheiden.'
    ),
    (
        3,
        'MAXDOP',
        CASE
            WHEN @MaxDop IS NOT NULL THEN 'explicit parameter'
            WHEN EXISTS (SELECT 1 FROM #ReferenceScopedConfig AS r WHERE r.ConfigName = N'MAXDOP') THEN CONCAT('current database ', DB_NAME())
            ELSE 'documented training default'
        END,
        COALESCE(
            CONVERT(VARCHAR(30), TRY_CONVERT(INT, (SELECT TOP (1) r.PrimaryValue FROM #ReferenceScopedConfig AS r WHERE r.ConfigName = N'MAXDOP'))),
            '0'
        ),
        CONVERT
        (
            VARCHAR(30),
            COALESCE
            (
                @MaxDop,
                TRY_CONVERT(INT, (SELECT TOP (1) r.PrimaryValue FROM #ReferenceScopedConfig AS r WHERE r.ConfigName = N'MAXDOP')),
                0
            )
        ),
        'MAXDOP auf Datenbankebene ist ein gezielter Override fuer Parallelism-Strategien einzelner Workloads.',
        'Nur als Ausnahme gegen Serverstandard verwenden und mit CPU-Topologie sowie Workload-Tests begruenden.'
    ),
    (
        4,
        'PARAMETER_SNIFFING',
        CASE
            WHEN @ParameterSniffing IS NOT NULL THEN 'explicit parameter'
            WHEN EXISTS (SELECT 1 FROM #ReferenceScopedConfig AS r WHERE r.ConfigName = N'PARAMETER_SNIFFING') THEN CONCAT('current database ', DB_NAME())
            ELSE 'documented training default'
        END,
        CASE
            WHEN EXISTS (SELECT 1 FROM #ReferenceScopedConfig AS r WHERE r.ConfigName = N'PARAMETER_SNIFFING' AND TRY_CONVERT(INT, r.PrimaryValue) = 0) THEN 'OFF'
            WHEN EXISTS (SELECT 1 FROM #ReferenceScopedConfig AS r WHERE r.ConfigName = N'PARAMETER_SNIFFING') THEN 'ON'
            ELSE 'ON'
        END,
        CASE
            WHEN COALESCE(@ParameterSniffing, TRY_CONVERT(INT, (SELECT TOP (1) r.PrimaryValue FROM #ReferenceScopedConfig AS r WHERE r.ConfigName = N'PARAMETER_SNIFFING')), 1) = 1 THEN 'ON'
            ELSE 'OFF'
        END,
        'Die Einstellung beeinflusst, ob der Optimizer Parameterwerte fuer die Planerstellung auswertet.',
        'Nur bei reproduzierbaren Sniffing-Problemen global abschalten; sonst Query- oder Prozedurebene bevorzugen.'
    );

-- 4. Priorisierte Bootstrap-Checkliste ableiten
CREATE TABLE #BootstrapChecklist
(
    ChecklistOrder INT NOT NULL,
    ChecklistArea VARCHAR(50) NOT NULL,
    CheckItem VARCHAR(120) NOT NULL,
    RecommendationText VARCHAR(320) NOT NULL,
    WhyItMatters VARCHAR(280) NOT NULL
);

INSERT INTO #BootstrapChecklist
(
    ChecklistOrder,
    ChecklistArea,
    CheckItem,
    RecommendationText,
    WhyItMatters
)
VALUES
    (
        1,
        'Baseline source',
        'Reference strategy',
        CASE
            WHEN @UseCurrentDatabaseAsReference = 1 THEN CONCAT('Referenzwerte der aktuellen Datenbank ', QUOTENAME(DB_NAME()), ' gegen den Zielkontext pruefen, bevor sie auf ', QUOTENAME(@TargetDatabaseName), ' uebertragen werden.')
            ELSE CONCAT('Dokumentierte Trainingsdefaults fuer ', QUOTENAME(@TargetDatabaseName), ' bewusst gegen Teamstandard oder Workloadprofil reviewen.')
        END,
        'Scoped Configurations wirken still auf Planwahl und Laufzeitverhalten; unreflektierte Uebernahme fuehrt leicht zu schwer erklaerbaren Abweichungen.'
    ),
    (
        2,
        'Optimizer',
        'Legacy CE and hotfixes',
        'LEGACY_CARDINALITY_ESTIMATION und QUERY_OPTIMIZER_HOTFIXES nur gemeinsam mit Regressionstests, Query Store oder reproduzierbaren Problemabfragen freigeben.',
        'Beide Schalter beeinflussen den Optimizer breit und sollten kein reflexartiger Bootstrap-Default sein.'
    ),
    (
        3,
        'Parallelism',
        'MAXDOP override',
        'MAXDOP als Datenbank-Override nur setzen, wenn ein einzelner Workload bewusst vom Serverstandard abweichen soll.',
        'Ein unpassender MAXDOP-Default kann CPU-Verhalten, Durchsatz und Concurrency unerwartet verschieben.'
    ),
    (
        4,
        'Plan stability',
        'Parameter sniffing',
        'PARAMETER_SNIFFING nur bei wiederkehrenden Planinstabilitaeten global abschalten; sonst zielgerichtete Query-Tuning-Massnahmen bevorzugen.',
        'Die globale Deaktivierung vereinfacht manche Problemfaelle, kann aber auch gute Plaene verschlechtern.'
    ),
    (
        5,
        'Verification',
        'Post-create validation',
        CONCAT('Nach dem Setzen der Baseline die Werte in ', QUOTENAME(@TargetDatabaseName), '.sys.database_scoped_configurations oder ueber den erzeugten ALTER-Output gegenpruefen.'),
        'Eine kurze Verifikation verhindert, dass erwartete Defaults oder Rollout-Schritte still vom Plan abweichen.'
    );

-- 5. USE- plus ALTER DATABASE SCOPED CONFIGURATION Vorlagen erzeugen
CREATE TABLE #ScopedConfigCommandTemplate
(
    CommandOrder INT NOT NULL,
    ConfigName VARCHAR(80) NOT NULL,
    GeneratedCommand NVARCHAR(MAX) NOT NULL,
    CommandNote VARCHAR(280) NOT NULL
);

INSERT INTO #ScopedConfigCommandTemplate
(
    CommandOrder,
    ConfigName,
    GeneratedCommand,
    CommandNote
)
SELECT
    scb.ConfigOrder,
    scb.ConfigName,
    CASE
        WHEN scb.ConfigName = 'MAXDOP' THEN
            CONCAT
            (
                N'USE ',
                QUOTENAME(@TargetDatabaseName),
                N';',
                NCHAR(13) + NCHAR(10),
                N'ALTER DATABASE SCOPED CONFIGURATION SET ',
                scb.ConfigName,
                N' = ',
                scb.TargetValue,
                N';'
            )
        ELSE
            CONCAT
            (
                N'USE ',
                QUOTENAME(@TargetDatabaseName),
                N';',
                NCHAR(13) + NCHAR(10),
                N'ALTER DATABASE SCOPED CONFIGURATION SET ',
                scb.ConfigName,
                N' = ',
                CASE WHEN scb.TargetValue = 'ON' THEN 'ON' ELSE 'OFF' END,
                N';'
            )
    END,
    CASE
        WHEN scb.ConfigName IN ('LEGACY_CARDINALITY_ESTIMATION', 'QUERY_OPTIMIZER_HOTFIXES') THEN 'Vor Umsetzung mit Query Store, Regressionsmessungen und Kompatibilitaetsstrategie abstimmen.'
        WHEN scb.ConfigName = 'MAXDOP' THEN 'MAXDOP als Datenbank-Override nur setzen, wenn der Serverstandard bewusst verlassen werden soll.'
        ELSE 'Globale Deaktivierung nur bei wiederkehrenden und belegten Sniffing-Problemen nutzen.'
    END
FROM #ScopedConfigBaseline AS scb
ORDER BY
    scb.ConfigOrder;

-- 6. Resultsets ausgeben
SELECT
    scb.ConfigOrder,
    scb.ConfigName,
    scb.ReferenceSource,
    scb.ReferenceValue,
    scb.TargetValue,
    scb.WhyRelevant,
    scb.ReviewFocus
FROM #ScopedConfigBaseline AS scb
ORDER BY
    scb.ConfigOrder;

SELECT
    bc.ChecklistOrder,
    bc.ChecklistArea,
    bc.CheckItem,
    bc.RecommendationText,
    bc.WhyItMatters
FROM #BootstrapChecklist AS bc
ORDER BY
    bc.ChecklistOrder;

SELECT
    sct.CommandOrder,
    sct.ConfigName,
    sct.GeneratedCommand,
    sct.CommandNote
FROM #ScopedConfigCommandTemplate AS sct
ORDER BY
    sct.CommandOrder;
