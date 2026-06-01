/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "AnsiNullDefaultInventory.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "17_ANSI_NULL & Co"

purpose: >
  Inventarisiert didaktisch die moeglichen Einstellungen rund um
  ANSI_NULL_DFLT_ON und ANSI_NULL_DFLT_OFF. Das Skript zeigt, wie sich
  weggelassene NULL-Definitionen in CREATE TABLE-Szenarien auswirken und
  welche Guardrails fuer konsistente Deployments sinnvoll sind.

parameters:
  - name: "@ShowOptionMatrix"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = das Inventar der relevanten ANSI_NULL_DFLT-Varianten ausgeben"
  - name: "@ShowExampleScenarios"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = didaktische CREATE-TABLE-Szenarien und ihre effektive Nullability ausgeben"

result_sets:
  - name: "OptionInventory"
    description: "Inventarisiert Varianten, typische Wirkung und empfohlene Guardrails"
  - name: "ExampleScenarioMatrix"
    description: "Zeigt beispielhafte CREATE-TABLE-Szenarien mit effektiver Nullability"
  - name: "DecisionGuide"
    description: "Leitet pragmatische Empfehlungen fuer stabile Deployments ab"

dependencies:
  - "tempdb temporary tables"
  - "VALUES"
  - "CASE"
  - "ORDER BY"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/17_ANSI_NULL & Co/SQLScripts/AnsiNullDefaultInventory.md"
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
    description: "Erstversion des didaktischen ANSI_NULL_DFLT-Inventars"

notes:
  - "Die Umsetzung arbeitet bewusst mit didaktischen Szenarien statt produktive Datenbanken zu veraendern"
  - "Explizite NULL oder NOT NULL Angaben werden als wichtigste Guardrail gegen SET-Options-Missverstaendnisse hervorgehoben"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

-- 1. Parameter vorbereiten
DECLARE @ShowOptionMatrix BIT = 1;
DECLARE @ShowExampleScenarios BIT = 1;

IF @ShowOptionMatrix NOT IN (0, 1)
BEGIN
    THROW 50000, '@ShowOptionMatrix muss 0 oder 1 sein.', 1;
END;

IF @ShowExampleScenarios NOT IN (0, 1)
BEGIN
    THROW 50001, '@ShowExampleScenarios muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #OptionInventory;
DROP TABLE IF EXISTS #ExampleScenarioMatrix;
DROP TABLE IF EXISTS #DecisionGuide;

-- 2. Inventar der relevanten Optionen aufbauen
CREATE TABLE #OptionInventory
(
    SortOrder                    TINYINT       NOT NULL,
    SettingFamily                VARCHAR(40)   NOT NULL,
    ActiveVariant                VARCHAR(80)   NOT NULL,
    OmittedColumnNullability     VARCHAR(20)   NOT NULL,
    ExampleDdl                   VARCHAR(200)  NOT NULL,
    ImpactSummary                VARCHAR(220)  NOT NULL,
    RiskProfile                  VARCHAR(30)   NOT NULL,
    Recommendation               VARCHAR(220)  NOT NULL
);

INSERT INTO #OptionInventory
(
    SortOrder,
    SettingFamily,
    ActiveVariant,
    OmittedColumnNullability,
    ExampleDdl,
    ImpactSummary,
    RiskProfile,
    Recommendation
)
VALUES
    (
        1,
        'Session default',
        'ANSI_NULL_DFLT_ON active',
        'NULL',
        'SET ANSI_NULL_DFLT_ON ON; CREATE TABLE dbo.Demo (CommentText VARCHAR(50));',
        'Ohne explizites NULL oder NOT NULL wird die Spalte als nullable gelesen.',
        'moderate',
        'In Lern- und Deploymentskripten trotzdem explizite Nullability angeben.'
    ),
    (
        2,
        'Session default',
        'ANSI_NULL_DFLT_OFF active',
        'NOT NULL',
        'SET ANSI_NULL_DFLT_OFF ON; CREATE TABLE dbo.Demo (CommentText VARCHAR(50));',
        'Ohne explizites NULL oder NOT NULL wird die Spalte als not nullable gelesen.',
        'high',
        'Omitted nullability vermeiden, weil dieselbe DDL je Session anders interpretiert werden kann.'
    ),
    (
        3,
        'Explicit column design',
        'Column declares NULL',
        'NULL',
        'CREATE TABLE dbo.Demo (CommentText VARCHAR(50) NULL);',
        'Die Spaltendefinition ueberstimmt die Session-Default-Frage eindeutig.',
        'low',
        'Bei dauerhaften Objekten explizite Spaltendefinitionen als Standard etablieren.'
    ),
    (
        4,
        'Explicit column design',
        'Column declares NOT NULL',
        'NOT NULL',
        'CREATE TABLE dbo.Demo (CommentText VARCHAR(50) NOT NULL);',
        'Die Spaltendefinition ist stabil und leicht reviewbar.',
        'low',
        'Explizite Pflichtfelder direkt in der DDL sichtbar machen.'
    ),
    (
        5,
        'Deployment guardrail',
        'Mixed tool defaults',
        'version-dependent',
        'CI, SSMS und ETL-Tools koennen unterschiedliche Session-Defaults starten.',
        'Skripte mit ausgelassener Nullability koennen je Verbindung inkonsistente Tabellen erzeugen.',
        'high',
        'Zusammen mit expliziter Nullability auch SET-Bloecke und Code-Reviews standardisieren.'
    );

-- 3. Beispiel-Szenarien fuer CREATE TABLE ableiten
CREATE TABLE #ExampleScenarioMatrix
(
    ScenarioStep                 TINYINT       NOT NULL,
    ScenarioName                 VARCHAR(100)  NOT NULL,
    SessionDefault               VARCHAR(80)   NOT NULL,
    ColumnDefinition             VARCHAR(100)  NOT NULL,
    EffectiveNullability         VARCHAR(20)   NOT NULL,
    WhyItMatters                 VARCHAR(220)  NOT NULL,
    PotentialSurprise            VARCHAR(220)  NOT NULL
);

INSERT INTO #ExampleScenarioMatrix
(
    ScenarioStep,
    ScenarioName,
    SessionDefault,
    ColumnDefinition,
    EffectiveNullability,
    WhyItMatters,
    PotentialSurprise
)
VALUES
    (
        1,
        'Implicit nullable column',
        'ANSI_NULL_DFLT_ON active',
        'CommentText VARCHAR(50)',
        'NULL',
        'Das Weglassen von NULL oder NOT NULL fuehrt hier zu einer nullable Spalte.',
        'Reviewer sehen in der DDL nicht sofort, dass die Nullable-Entscheidung nur aus der Session stammt.'
    ),
    (
        2,
        'Implicit mandatory column',
        'ANSI_NULL_DFLT_OFF active',
        'CommentText VARCHAR(50)',
        'NOT NULL',
        'Dieselbe Spaltendefinition kippt unter anderem Session-Default auf mandatory.',
        'Ein Deployment kann je Tool oder Verbindung unerwartet fehlschlagen oder andere Metadaten erzeugen.'
    ),
    (
        3,
        'Explicit NULL wins',
        'ANSI_NULL_DFLT_OFF active',
        'CommentText VARCHAR(50) NULL',
        'NULL',
        'Die explizite DDL macht die Session-Einstellung fuer diese Spalte irrelevant.',
        'Kaum Ueberraschung, weil die Intention direkt in der Tabelle steht.'
    ),
    (
        4,
        'Explicit NOT NULL wins',
        'ANSI_NULL_DFLT_ON active',
        'CommentText VARCHAR(50) NOT NULL',
        'NOT NULL',
        'Die Pflichtfeld-Intention bleibt stabil ueber unterschiedliche Sessions hinweg.',
        'Nur nachgelagerte Datenimporte muessen die NOT-NULL-Regel dann noch sauber bedienen.'
    ),
    (
        5,
        'Migration script without guardrail',
        'Tool defaults differ between environments',
        'Several columns omit NULL and NOT NULL',
        'mixed',
        'Schon kleine Unterschiede in Verbindungseinstellungen koennen zu abweichenden Schemas fuehren.',
        'Schema-Drift wird oft erst spaet entdeckt, wenn Inserts oder Vergleiche fehlschlagen.'
    );

-- 4. Entscheidungshilfe fuer Review und Betrieb
CREATE TABLE #DecisionGuide
(
    DecisionOrder                TINYINT       NOT NULL,
    Concern                      VARCHAR(100)  NOT NULL,
    Observation                  VARCHAR(220)  NOT NULL,
    Consequence                  VARCHAR(220)  NOT NULL,
    SuggestedAction              VARCHAR(220)  NOT NULL
);

INSERT INTO #DecisionGuide
(
    DecisionOrder,
    Concern,
    Observation,
    Consequence,
    SuggestedAction
)
VALUES
    (
        1,
        'Schema readability',
        'Omitted NULL or NOT NULL hides the actual design choice behind session state.',
        'Reviews und spaetere Aenderungen werden unnoetig interpretativ.',
        'Nullability immer explizit in jeder CREATE TABLE oder ALTER TABLE Anweisung notieren.'
    ),
    (
        2,
        'Deployment consistency',
        'Build-Agent, SSMS und Automationen koennen mit unterschiedlichen SET-Defaults starten.',
        'Dasselbe Skript kann in mehreren Umgebungen andere Metadaten erzeugen.',
        'SET-Bloecke dokumentieren und auf explizite Spaltendefinitionen als primaere Guardrail setzen.'
    ),
    (
        3,
        'Troubleshooting',
        'Unerwartete NOT-NULL-Fehler oder nullable Spalten entstehen oft durch implizite Defaults.',
        'Fehlersuche fokussiert sonst auf Daten statt auf DDL und Session-Kontext.',
        'Bei Vorfaellen zuerst die DDL auf ausgelassene Nullability und verwendete SET-Optionen pruefen.'
    ),
    (
        4,
        'Teaching value',
        'ANSI_NULL_DFLT_* ist leicht zu vergessen, zeigt aber anschaulich die Wirkung impliziter Defaults.',
        'Das Thema eignet sich gut fuer Code-Review- und Deployment-Diskussionen.',
        'Die Beispiele als Anlass nutzen, um explizite DDL-Konventionen im Team festzulegen.'
    );

-- 5. Ergebnisse ausgeben
IF @ShowOptionMatrix = 1
BEGIN
    SELECT
        oi.SettingFamily,
        oi.ActiveVariant,
        oi.OmittedColumnNullability,
        oi.ExampleDdl,
        oi.ImpactSummary,
        oi.RiskProfile,
        oi.Recommendation
    FROM #OptionInventory AS oi
    ORDER BY
        oi.SortOrder;
END;

IF @ShowExampleScenarios = 1
BEGIN
    SELECT
        esm.ScenarioStep,
        esm.ScenarioName,
        esm.SessionDefault,
        esm.ColumnDefinition,
        esm.EffectiveNullability,
        esm.WhyItMatters,
        esm.PotentialSurprise
    FROM #ExampleScenarioMatrix AS esm
    ORDER BY
        esm.ScenarioStep;
END;

SELECT
    dg.Concern,
    dg.Observation,
    dg.Consequence,
    dg.SuggestedAction
FROM #DecisionGuide AS dg
ORDER BY
    dg.DecisionOrder;
