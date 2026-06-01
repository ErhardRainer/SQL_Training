/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "ArithmeticAbortSettingReview.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "17_ANSI_NULL & Co"

purpose: >
  Reviewt die Session-Einstellung ARITHABORT anhand didaktischer
  Workload-Szenarien und zeigt, welche praktischen Folgen fuer
  Fehlersignale, Planvergleich und Feature-Voraussetzungen zu erwarten
  sind.

parameters:
  - name: "@OnlyRiskyScenarios"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = nur Szenarien mit hohem Review-Risiko ausgeben"
  - name: "@IncludeDecisionGuide"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zusaetzlich einen Entscheidungs- und Guardrail-Guide ausgeben"

result_sets:
  - name: "ScenarioInventory"
    description: "Inventarisiert didaktische ARITHABORT-Szenarien mit Risiko und Beobachtungsfokus"
  - name: "BehaviorReview"
    description: "Vergleicht ON- und OFF-Betrachtung fuer Troubleshooting, Performance und Features"
  - name: "DecisionGuide"
    description: "Leitet Guardrails fuer Tests, Deployments und Review-Entscheidungen ab"

dependencies:
  - "tempdb temporary tables"
  - "VALUES"
  - "CASE"
  - "ORDER BY"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/17_ANSI_NULL & Co/SQLScripts/ArithmeticAbortSettingReview.md"
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
    description: "Erstversion des didaktischen ARITHABORT-Review-Skripts"

notes:
  - "Die Umsetzung modelliert Review-Szenarien statt echte Session-Umschaltungen auf produktiven Systemen vorauszusetzen"
  - "ARITHABORT wird bewusst zusammen mit Fehlersignalen, Planvergleich und Feature-Voraussetzungen betrachtet"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

-- 1. Parameter vorbereiten
DECLARE @OnlyRiskyScenarios BIT = 0;
DECLARE @IncludeDecisionGuide BIT = 1;

IF @OnlyRiskyScenarios NOT IN (0, 1)
BEGIN
    THROW 50000, '@OnlyRiskyScenarios muss 0 oder 1 sein.', 1;
END;

IF @IncludeDecisionGuide NOT IN (0, 1)
BEGIN
    THROW 50001, '@IncludeDecisionGuide muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #ScenarioInventory;
DROP TABLE IF EXISTS #BehaviorReview;
DROP TABLE IF EXISTS #DecisionGuide;

-- 2. Typische ARITHABORT-Szenarien inventarisieren
CREATE TABLE #ScenarioInventory
(
    ScenarioStep                 TINYINT       NOT NULL,
    WorkloadArea                 VARCHAR(40)   NOT NULL,
    ExampleFocus                 VARCHAR(220)  NOT NULL,
    RiskLevel                    VARCHAR(20)   NOT NULL,
    PracticalConsequence         VARCHAR(220)  NOT NULL,
    ReviewQuestion               VARCHAR(220)  NOT NULL
);

INSERT INTO #ScenarioInventory
(
    ScenarioStep,
    WorkloadArea,
    ExampleFocus,
    RiskLevel,
    PracticalConsequence,
    ReviewQuestion
)
VALUES
    (
        1,
        'Error handling',
        'Division durch 0 in einer Query mit Demo-Daten',
        'high',
        'Unterschiedliche Sitzungen koennen Fehlersignale frueher oder spaeter sichtbar machen und Troubleshooting verfremden.',
        'Ist fuer Fehlerszenarien klar dokumentiert, unter welchen SET-Kombinationen getestet wurde?'
    ),
    (
        2,
        'Plan comparison',
        'Vergleich eines Query-Fensters mit Anwendung oder Job',
        'high',
        'Abweichende ARITHABORT-Werte koennen Planvergleich und Performance-Diagnose unnoetig unklar machen.',
        'Wird fuer Performance-Reviews dieselbe Session-Baseline wie in der Laufzeit verwendet?'
    ),
    (
        3,
        'Indexed features',
        'Vorbereitung fuer indizierte Views oder berechnete Spalten',
        'high',
        'Bestimmte Features erwarten ARITHABORT ON als Teil einer konsistenten SET-Kombination.',
        'Sind Feature-Voraussetzungen in Deployment- und Build-Skripten explizit abgesichert?'
    ),
    (
        4,
        'Teaching lab',
        'Didaktischer Vergleich von ON und OFF als Gegenbeispiel',
        'medium',
        'Der Lerneffekt steigt, wenn die Abweichung bewusst markiert wird und nicht wie ein Standard wirkt.',
        'Ist klar gekennzeichnet, dass OFF nur als Demonstration und nicht als Team-Default dient?'
    ),
    (
        5,
        'Support workflow',
        'Ad-hoc-Analyse in einer Legacy-Verbindung',
        'medium',
        'Support- oder Hotfix-Sitzungen liefern sonst Beobachtungen, die sich spaeter nicht reproduzieren lassen.',
        'Gibt es eine dokumentierte Referenzkombination fuer Diagnose- und Support-Sessions?'
    );

-- 3. Review-Matrix fuer ARITHABORT ON und OFF ableiten
CREATE TABLE #BehaviorReview
(
    ScenarioStep                 TINYINT       NOT NULL,
    WorkloadArea                 VARCHAR(40)   NOT NULL,
    FocusWhenOn                  VARCHAR(220)  NOT NULL,
    FocusWhenOff                 VARCHAR(220)  NOT NULL,
    ReviewAngle                  VARCHAR(220)  NOT NULL,
    RecommendedAction            VARCHAR(220)  NOT NULL
);

INSERT INTO #BehaviorReview
(
    ScenarioStep,
    WorkloadArea,
    FocusWhenOn,
    FocusWhenOff,
    ReviewAngle,
    RecommendedAction
)
SELECT
    si.ScenarioStep,
    si.WorkloadArea,
    FocusWhenOn =
        CASE si.WorkloadArea
            WHEN 'Error handling' THEN 'Arithmetic-Probleme werden in reproduzierbaren Tests frueher als bewusstes Fehlerverhalten besprochen.'
            WHEN 'Plan comparison' THEN 'Plan- und Laufzeitvergleiche bleiben naeher an dokumentierten Standardsitzungen.'
            WHEN 'Indexed features' THEN 'Feature-Voraussetzungen bleiben konsistent mit typischen Build- und Deployment-Guardrails.'
            WHEN 'Teaching lab' THEN 'Die ON-Variante bildet den konservativen Referenzfall fuer Unterricht und Review.'
            ELSE 'Diagnose-Sessions bleiben vergleichbarer mit produktionsnahen oder standardisierten Umgebungen.'
        END,
    FocusWhenOff =
        CASE si.WorkloadArea
            WHEN 'Error handling' THEN 'Fehleranalysen koennen schwerer auf den eigentlichen Session-Unterschied statt auf die Fachlogik zurueckzufuehren sein.'
            WHEN 'Plan comparison' THEN 'SSMS-, Tool- und Anwendungs-Sessions wirken unnoetig unterschiedlich und erschweren Performance-Reviews.'
            WHEN 'Indexed features' THEN 'Feature-nahe Skripte koennen trotz fachlich korrekter Idee an SET-Voraussetzungen scheitern.'
            WHEN 'Teaching lab' THEN 'Der Gegenbeispiel-Charakter muss sichtbar bleiben, damit OFF nicht als stiller Default missverstanden wird.'
            ELSE 'Support-Notizen verlieren an Wert, wenn die beobachtete Session-Kombination spaeter nicht reproduziert wird.'
        END,
    ReviewAngle =
        CASE
            WHEN si.RiskLevel = 'high' THEN 'Als Pflichtpunkt fuer Tests, Performance-Vergleich und Deployment-Checklisten behandeln.'
            ELSE 'Als Diagnose- und Schulungsaspekt markieren und mit Referenz-Sessions vergleichen.'
        END,
    RecommendedAction =
        CASE si.WorkloadArea
            WHEN 'Error handling' THEN 'Arithmetic-Grenzfaelle mit dokumentierter SET-Baseline und erwarteten Fehlersignalen testen.'
            WHEN 'Plan comparison' THEN 'Query-Fenster, Jobs und Anwendungen gegen dieselbe Session-Referenz pruefen.'
            WHEN 'Indexed features' THEN 'ARITHABORT zusammen mit den weiteren SET-Voraussetzungen explizit im Deployment absichern.'
            WHEN 'Teaching lab' THEN 'OFF nur als bewusst beschriftetes Gegenbeispiel in Labs und Dokumentation verwenden.'
            ELSE 'Support-Sessions mit Referenzprofil und kurzer Session-Notiz dokumentieren.'
        END
FROM #ScenarioInventory AS si
WHERE @OnlyRiskyScenarios = 0
   OR si.RiskLevel = 'high';

-- 4. Entscheidungs- und Guardrail-Guide formulieren
CREATE TABLE #DecisionGuide
(
    StepNo                       TINYINT       NOT NULL,
    FocusArea                    VARCHAR(40)   NOT NULL,
    Recommendation               VARCHAR(220)  NOT NULL,
    WhyItHelps                   VARCHAR(220)  NOT NULL
);

INSERT INTO #DecisionGuide
(
    StepNo,
    FocusArea,
    Recommendation,
    WhyItHelps
)
VALUES
    (
        1,
        'Session baseline',
        'Performance-, Deployment- und Troubleshooting-Sessions mit einer dokumentierten SET-Referenz starten.',
        'So bleiben Beobachtungen ueber Tools und Laufzeitkontexte hinweg vergleichbar.'
    ),
    (
        2,
        'Arithmetic tests',
        'Grenzfaelle wie Division durch 0 oder enge Numerik zusammen mit ARITHABORT explizit testen.',
        'Das Team trennt dadurch echte Fachfehler sauber von Session-bedingten Diagnoseunterschieden.'
    ),
    (
        3,
        'Feature readiness',
        'Vor indizierten Views und aehnlichen Features die gesamte benoetigte SET-Kombination im Skript sichtbar machen.',
        'Fehlende Voraussetzungen werden vor dem eigentlichen Deploy erkannt statt erst im Fehlerfall.'
    ),
    (
        4,
        'Teaching and review',
        'ARITHABORT OFF nur als klar markierte Vergleichsvariante und nie als stillen Team-Standard dokumentieren.',
        'Didaktische Kontraste bleiben nuetzlich, ohne Standardempfehlungen zu verwischen.'
    );

-- 5. Ergebnisse ausgeben
SELECT
    si.ScenarioStep,
    si.WorkloadArea,
    si.ExampleFocus,
    si.RiskLevel,
    si.PracticalConsequence,
    si.ReviewQuestion
FROM #ScenarioInventory AS si
WHERE @OnlyRiskyScenarios = 0
   OR si.RiskLevel = 'high'
ORDER BY
    si.ScenarioStep;

SELECT
    br.ScenarioStep,
    br.WorkloadArea,
    br.FocusWhenOn,
    br.FocusWhenOff,
    br.ReviewAngle,
    br.RecommendedAction
FROM #BehaviorReview AS br
ORDER BY
    br.ScenarioStep;

IF @IncludeDecisionGuide = 1
BEGIN
    SELECT
        dg.StepNo,
        dg.FocusArea,
        dg.Recommendation,
        dg.WhyItHelps
    FROM #DecisionGuide AS dg
    ORDER BY
        dg.StepNo;
END;
