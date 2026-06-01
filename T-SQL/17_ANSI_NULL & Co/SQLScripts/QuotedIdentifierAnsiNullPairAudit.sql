/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "QuotedIdentifierAnsiNullPairAudit.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "17_ANSI_NULL & Co"

purpose: >
  Auditiert didaktisch gemeinsam auftretende Kombinationen aus ANSI_NULLS
  und QUOTED_IDENTIFIER in Legacy-Modulen. Das Skript verdichtet typische
  Paar-Profile, markiert riskante Mischungen und leitet pragmatische
  Review- und Remediation-Hinweise fuer Altmodule ab.

parameters:
  - name: "@FlagOnlyRiskPairs"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = nur Module und Paar-Profile mit erhoehtem Risiko ausgeben"
  - name: "@IncludePairSummary"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zusaetzlich eine Zusammenfassung pro Options-Paar ausgeben"

result_sets:
  - name: "ModulePairAudit"
    description: "Bewertet pro Legacy-Modul die Kombination aus ANSI_NULLS und QUOTED_IDENTIFIER"
  - name: "PairProfileSummary"
    description: "Verdichtet beobachtete Paar-Profile inklusive Modulanzahl und Review-Fokus"
  - name: "RemediationGuide"
    description: "Leitet Guardrails fuer Review, Modernisierung und Deployment ab"

dependencies:
  - "tempdb temporary tables"
  - "VALUES"
  - "CASE"
  - "CROSS APPLY"
  - "GROUP BY"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/17_ANSI_NULL & Co/SQLScripts/QuotedIdentifierAnsiNullPairAudit.md"
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
    description: "Erstversion des didaktischen Audits fuer ANSI_NULLS- und QUOTED_IDENTIFIER-Paare"

notes:
  - "Die Umsetzung verwendet ein didaktisches Inventar von Legacy-Modulen statt produktive sys.sql_modules-Abfragen vorauszusetzen"
  - "Im Fokus steht die gemeinsam auftretende Paarung von ANSI_NULLS und QUOTED_IDENTIFIER als Review- und Modernisierungssignal"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

-- 1. Parameter vorbereiten
DECLARE @FlagOnlyRiskPairs BIT = 0;
DECLARE @IncludePairSummary BIT = 1;

IF @FlagOnlyRiskPairs NOT IN (0, 1)
BEGIN
    THROW 50000, '@FlagOnlyRiskPairs muss 0 oder 1 sein.', 1;
END;

IF @IncludePairSummary NOT IN (0, 1)
BEGIN
    THROW 50001, '@IncludePairSummary muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #ExpectedPairPolicy;
DROP TABLE IF EXISTS #ObservedLegacyModules;
DROP TABLE IF EXISTS #ModulePairAudit;
DROP TABLE IF EXISTS #PairProfileSummary;
DROP TABLE IF EXISTS #RemediationGuide;

-- 2. Soll-Paare fuer Legacy-Reviews beschreiben
CREATE TABLE #ExpectedPairPolicy
(
    PairCode             VARCHAR(7)    NOT NULL PRIMARY KEY,
    AnsiNullsBit         BIT           NOT NULL,
    QuotedIdentifierBit  BIT           NOT NULL,
    PairLabel            VARCHAR(60)   NOT NULL,
    RiskLevel            VARCHAR(20)   NOT NULL,
    PolicyReason         VARCHAR(220)  NOT NULL
);

INSERT INTO #ExpectedPairPolicy
(
    PairCode,
    AnsiNullsBit,
    QuotedIdentifierBit,
    PairLabel,
    RiskLevel,
    PolicyReason
)
VALUES
    (
        'ON/ON',
        1,
        1,
        'standard baseline',
        'low',
        'Diese Kombination entspricht der bevorzugten Baseline fuer reproduzierbare Moduldefinitionen.'
    ),
    (
        'OFF/ON',
        0,
        1,
        'legacy null semantics',
        'high',
        'ANSI_NULLS OFF fuehrt zu Legacy-Vergleichsregeln, obwohl Identifier-Regeln bereits modern wirken.'
    ),
    (
        'ON/OFF',
        1,
        0,
        'legacy identifier quoting',
        'high',
        'QUOTED_IDENTIFIER OFF erschwert konsistente DDL und wirkt als Altlast trotz ANSI-konformer NULL-Semantik.'
    ),
    (
        'OFF/OFF',
        0,
        0,
        'double legacy pair',
        'critical',
        'Beide Optionen gleichzeitig auf OFF markieren typischen Modernisierungs- und Review-Bedarf.'
    );

-- 3. Beobachtete Altmodule als didaktisches Inventar aufbauen
CREATE TABLE #ObservedLegacyModules
(
    ModuleName           VARCHAR(128)  NOT NULL,
    ObjectType           VARCHAR(30)   NOT NULL,
    SchemaArea           VARCHAR(60)   NOT NULL,
    AnsiNullsBit         BIT           NOT NULL,
    QuotedIdentifierBit  BIT           NOT NULL,
    DeploymentSource     VARCHAR(60)   NOT NULL,
    LastTouchContext     VARCHAR(80)   NOT NULL,
    WhyObserved          VARCHAR(220)  NOT NULL
);

INSERT INTO #ObservedLegacyModules
(
    ModuleName,
    ObjectType,
    SchemaArea,
    AnsiNullsBit,
    QuotedIdentifierBit,
    DeploymentSource,
    LastTouchContext,
    WhyObserved
)
VALUES
    (
        'dbo.usp_LoadLegacyInvoices',
        'PROCEDURE',
        'Billing',
        0,
        1,
        'SSMS hotfix tab',
        'Support hotfix',
        'Die Prozedur wurde mehrfach kurzfristig angepasst; ANSI_NULLS OFF blieb aus dem Legacy-Skript erhalten.'
    ),
    (
        'dbo.vw_QuotedNameExtract',
        'VIEW',
        'Integration',
        1,
        0,
        'Old deployment template',
        'Migration prep',
        'Die View nutzt ein altes DDL-Template mit QUOTED_IDENTIFIER OFF.'
    ),
    (
        'dbo.ufn_NormalizeLegacyCode',
        'FUNCTION',
        'Core',
        0,
        0,
        'Vendor baseline',
        'Initial import',
        'Beide Optionen stammen aus einer uebernommenen Fremdvorlage.'
    ),
    (
        'dbo.usp_RebuildSemanticCache',
        'PROCEDURE',
        'Reporting',
        1,
        1,
        'CI pipeline',
        'Planned refactor',
        'Die Prozedur dient als positive Referenz fuer konsistente Moduloptionen.'
    ),
    (
        'dbo.vw_LegacySalesAlias',
        'VIEW',
        'Sales',
        0,
        1,
        'Manual publish script',
        'Emergency deployment',
        'Das Modul zeigt eine haeufige Mischlage: alte NULL-Semantik bei ansonsten modernen Anfuehrungsregeln.'
    ),
    (
        'dbo.usp_ImportPartnerNames',
        'PROCEDURE',
        'Integration',
        1,
        0,
        'Third-party package',
        'Package refresh',
        'Die Anfuehrungslogik wurde nicht an die Team-Baseline angepasst.'
    );

-- 4. Paar-Audit pro Modul ableiten
CREATE TABLE #ModulePairAudit
(
    ModuleName             VARCHAR(128)  NOT NULL,
    ObjectType             VARCHAR(30)   NOT NULL,
    SchemaArea             VARCHAR(60)   NOT NULL,
    PairCode               VARCHAR(7)    NOT NULL,
    PairLabel              VARCHAR(60)   NOT NULL,
    RiskLevel              VARCHAR(20)   NOT NULL,
    PairStatus             VARCHAR(20)   NOT NULL,
    DeploymentSource       VARCHAR(60)   NOT NULL,
    ReviewFocus            VARCHAR(220)  NOT NULL,
    RecommendedAction      VARCHAR(220)  NOT NULL
);

INSERT INTO #ModulePairAudit
(
    ModuleName,
    ObjectType,
    SchemaArea,
    PairCode,
    PairLabel,
    RiskLevel,
    PairStatus,
    DeploymentSource,
    ReviewFocus,
    RecommendedAction
)
SELECT
    olm.ModuleName,
    olm.ObjectType,
    olm.SchemaArea,
    pair.PairCode,
    policy.PairLabel,
    policy.RiskLevel,
    CASE
        WHEN pair.PairCode = 'ON/ON' THEN 'baseline'
        ELSE 'review'
    END AS PairStatus,
    olm.DeploymentSource,
    CASE
        WHEN pair.PairCode = 'OFF/OFF' THEN 'Doppelte Legacy-Kombination pruefen: Vergleichslogik und DDL-Anfuehrung gemeinsam modernisieren.'
        WHEN pair.PairCode = 'OFF/ON' THEN 'NULL-sensitive Vergleiche, Filter und optionale Parameter auf Legacy-Semantik pruefen.'
        WHEN pair.PairCode = 'ON/OFF' THEN 'Objektdefinitionen und quoted identifiers fuer DDL, Views und Imports gegen Teamstandard abgleichen.'
        ELSE 'Referenzfall fuer die bevorzugte Modulbaseline dokumentieren.'
    END AS ReviewFocus,
    CASE
        WHEN pair.PairCode = 'OFF/OFF' THEN 'Modul zuerst auf SET ANSI_NULLS ON und SET QUOTED_IDENTIFIER ON umstellen, danach Regressionstests einplanen.'
        WHEN pair.PairCode = 'OFF/ON' THEN 'Vergleichslogik explizit auf IS NULL oder IS NOT NULL und anschliessend ANSI_NULLS ON nachziehen.'
        WHEN pair.PairCode = 'ON/OFF' THEN 'DDL- und Deployment-Templates bereinigen und QUOTED_IDENTIFIER ON konsistent machen.'
        ELSE 'Das Modul als Baseline-Beispiel fuer Reviews und Vorlagen erhalten.'
    END AS RecommendedAction
FROM #ObservedLegacyModules AS olm
CROSS APPLY
(
    SELECT
        PairCode =
            CONCAT(
                CASE olm.AnsiNullsBit WHEN 1 THEN 'ON' ELSE 'OFF' END,
                '/',
                CASE olm.QuotedIdentifierBit WHEN 1 THEN 'ON' ELSE 'OFF' END
            )
) AS pair
INNER JOIN #ExpectedPairPolicy AS policy
    ON policy.PairCode = pair.PairCode
WHERE @FlagOnlyRiskPairs = 0
   OR pair.PairCode <> 'ON/ON';

-- 5. Paar-Profile ueber alle Module verdichten
CREATE TABLE #PairProfileSummary
(
    PairCode               VARCHAR(7)    NOT NULL,
    PairLabel              VARCHAR(60)   NOT NULL,
    RiskLevel              VARCHAR(20)   NOT NULL,
    ModuleCount            INT           NOT NULL,
    ProcedureCount         INT           NOT NULL,
    ViewCount              INT           NOT NULL,
    FunctionCount          INT           NOT NULL,
    RepresentativeModule   VARCHAR(128)  NOT NULL,
    SummaryFocus           VARCHAR(220)  NOT NULL
);

INSERT INTO #PairProfileSummary
(
    PairCode,
    PairLabel,
    RiskLevel,
    ModuleCount,
    ProcedureCount,
    ViewCount,
    FunctionCount,
    RepresentativeModule,
    SummaryFocus
)
SELECT
    mpa.PairCode,
    MIN(mpa.PairLabel) AS PairLabel,
    MIN(mpa.RiskLevel) AS RiskLevel,
    COUNT(*) AS ModuleCount,
    SUM(CASE WHEN mpa.ObjectType = 'PROCEDURE' THEN 1 ELSE 0 END) AS ProcedureCount,
    SUM(CASE WHEN mpa.ObjectType = 'VIEW' THEN 1 ELSE 0 END) AS ViewCount,
    SUM(CASE WHEN mpa.ObjectType = 'FUNCTION' THEN 1 ELSE 0 END) AS FunctionCount,
    MIN(mpa.ModuleName) AS RepresentativeModule,
    CASE
        WHEN mpa.PairCode = 'OFF/OFF' THEN 'Dieses Doppel-Legacy-Profil priorisiert kombinierte Modernisierung von Vergleichslogik und Objektdefinition.'
        WHEN mpa.PairCode = 'OFF/ON' THEN 'Hier dominiert Legacy-NULL-Semantik; Reviews sollten zuerst Filter und Parameterpfade absichern.'
        WHEN mpa.PairCode = 'ON/OFF' THEN 'Hier steht quoted identifier cleanup im Vordergrund, vor allem bei DDL-nahen Objekten.'
        ELSE 'Diese Paarung bildet die gewuenschte Referenz fuer neue oder bereinigte Module.'
    END AS SummaryFocus
FROM #ModulePairAudit AS mpa
GROUP BY
    mpa.PairCode
HAVING @FlagOnlyRiskPairs = 0
    OR mpa.PairCode <> 'ON/ON';

-- 6. Guardrails fuer Modernisierung und Review formulieren
CREATE TABLE #RemediationGuide
(
    StepNo                 TINYINT       NOT NULL,
    FocusArea              VARCHAR(50)   NOT NULL,
    Recommendation         VARCHAR(220)  NOT NULL,
    WhyItHelps             VARCHAR(220)  NOT NULL
);

INSERT INTO #RemediationGuide
(
    StepNo,
    FocusArea,
    Recommendation,
    WhyItHelps
)
VALUES
    (
        1,
        'Baseline',
        'Neue oder ueberarbeitete Module konsequent mit SET ANSI_NULLS ON und SET QUOTED_IDENTIFIER ON ausliefern.',
        'Damit bleibt die Moduldefinition unabhaengig vom aktuellen Tool- oder Fensterkontext.'
    ),
    (
        2,
        'Risk review',
        'OFF/ON-Paare zuerst auf NULL-sensitive Filter, CASE-Ausdruecke und optionale Parameter untersuchen.',
        'So wird die fachlich sichtbarste Legacy-Semantik vor der eigentlichen Umschaltung abgesichert.'
    ),
    (
        3,
        'DDL cleanup',
        'ON/OFF- und OFF/OFF-Paare in Deployment-Templates, Views und importierten Vendor-Skripten gezielt bereinigen.',
        'Quoted identifier Drift bleibt sonst als wiederkehrende Altlast in DDL und Review-Prozessen erhalten.'
    ),
    (
        4,
        'Migration order',
        'Doppel-Legacy-Module mit kleinen Regressionstests versehen und nach fachlichem Risiko schrittweise modernisieren.',
        'Die Paar-Sicht hilft, Module mit kumuliertem Modernisierungsbedarf zuerst zu priorisieren.'
    );

-- 7. Ergebnisse ausgeben
SELECT
    mpa.ModuleName,
    mpa.ObjectType,
    mpa.SchemaArea,
    mpa.PairCode,
    mpa.PairLabel,
    mpa.RiskLevel,
    mpa.PairStatus,
    mpa.DeploymentSource,
    mpa.ReviewFocus,
    mpa.RecommendedAction
FROM #ModulePairAudit AS mpa
ORDER BY
    CASE mpa.RiskLevel
        WHEN 'critical' THEN 1
        WHEN 'high' THEN 2
        ELSE 3
    END,
    mpa.ModuleName;

IF @IncludePairSummary = 1
BEGIN
    SELECT
        pps.PairCode,
        pps.PairLabel,
        pps.RiskLevel,
        pps.ModuleCount,
        pps.ProcedureCount,
        pps.ViewCount,
        pps.FunctionCount,
        pps.RepresentativeModule,
        pps.SummaryFocus
    FROM #PairProfileSummary AS pps
    ORDER BY
        CASE pps.RiskLevel
            WHEN 'critical' THEN 1
            WHEN 'high' THEN 2
            ELSE 3
        END,
        pps.PairCode;
END;

SELECT
    rg.StepNo,
    rg.FocusArea,
    rg.Recommendation,
    rg.WhyItHelps
FROM #RemediationGuide AS rg
ORDER BY
    rg.StepNo;
