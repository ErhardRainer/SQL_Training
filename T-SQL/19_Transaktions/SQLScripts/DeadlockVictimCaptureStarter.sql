/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "DeadlockVictimCaptureStarter.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "19_Transaktions"

purpose: >
  Zeigt anhand modellierter Deadlock-Ereignisse, wie moegliche Opfer,
  Rollback-Kosten, Prioritaeten und erste Capture-Aktionen fuer ein
  Review dokumentiert werden koennen, ohne produktive XE-Sessions oder
  echte Deadlocks auszuloesen.

parameters:
  - name: "@MinimumVictimCount"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Filtert auf modellierte Deadlock-Ereignisse ab dieser Anzahl betroffener Opfer-Sessions"
  - name: "@IncludeActionGuide"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zusaetzlich einen kompakten Guide fuer Capture und Nacharbeit ausgeben"

result_sets:
  - name: "DeadlockEventInventory"
    description: "Beschreibt modellierte Deadlock-Ereignisse mit Ressourcen, Session-Prioritaeten und Capture-Kontext"
  - name: "VictimAssessment"
    description: "Leitet Opferkandidaten, vermutete Auswahlgruende und erste Capture-Prioritaeten ab"
  - name: "CaptureActionGuide"
    description: "Fasst Guardrails fuer Event-Sammlung, Nachweise und Folgeanalyse zusammen"

dependencies:
  - "tempdb temporary tables"
  - "CASE"
  - "CONCAT"
  - "ORDER BY"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/19_Transaktions/SQLScripts/DeadlockVictimCaptureStarter.md"
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
    description: "Erstversion des didaktischen Labs fuer Deadlock-Opfer, Capture und Review"

notes:
  - "Das Skript arbeitet mit modellierten Deadlock-Faellen statt mit produktiven Extended Events oder System-Health-XML."
  - "Opferauswahl und Rollback-Kosten sind didaktische Heuristiken fuer Review und Incident-Kommunikation."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

-- 1. Parameter vorbereiten
DECLARE @MinimumVictimCount INT = 1;
DECLARE @IncludeActionGuide BIT = 1;

IF @MinimumVictimCount < 1
BEGIN
    THROW 50000, '@MinimumVictimCount muss mindestens 1 sein.', 1;
END;

IF @IncludeActionGuide NOT IN (0, 1)
BEGIN
    THROW 50001, '@IncludeActionGuide muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #DeadlockEventInventory;
DROP TABLE IF EXISTS #VictimAssessment;
DROP TABLE IF EXISTS #CaptureActionGuide;

-- 2. Modellierte Deadlock-Ereignisse fuer das Review aufbauen
CREATE TABLE #DeadlockEventInventory
(
    DeadlockEventID           INT             NOT NULL,
    DatabaseName              SYSNAME         NOT NULL,
    ResourceType              VARCHAR(40)     NOT NULL,
    ResourceDetail            VARCHAR(120)    NOT NULL,
    SurvivorSessionID         SMALLINT        NOT NULL,
    VictimSessionID           SMALLINT        NOT NULL,
    SurvivorDeadlockPriority  SMALLINT        NOT NULL,
    VictimDeadlockPriority    SMALLINT        NOT NULL,
    VictimApproxRollbackMB    DECIMAL(18,2)   NOT NULL,
    VictimTranAgeMinutes      INT             NOT NULL,
    VictimCount               INT             NOT NULL,
    SuggestedCaptureSource    VARCHAR(80)     NOT NULL,
    WhyRelevant               VARCHAR(220)    NOT NULL
);

INSERT INTO #DeadlockEventInventory
(
    DeadlockEventID,
    DatabaseName,
    ResourceType,
    ResourceDetail,
    SurvivorSessionID,
    VictimSessionID,
    SurvivorDeadlockPriority,
    VictimDeadlockPriority,
    VictimApproxRollbackMB,
    VictimTranAgeMinutes,
    VictimCount,
    SuggestedCaptureSource,
    WhyRelevant
)
VALUES
    (
        7001,
        'SalesLab',
        'KEYLOCK',
        'dbo.OrderLine IX_OrderLine_OrderID',
        57,
        63,
        5,
        0,
        14.50,
        9,
        1,
        'system_health XE',
        'Klassischer Schreib-Schreib-Konflikt mit moderaten Rollback-Kosten als Einstieg in die Opferanalyse.'
    ),
    (
        7002,
        'WarehouseLab',
        'PAGELOCK',
        'dbo.StockLedger page 1:232',
        72,
        81,
        0,
        -5,
        6.25,
        4,
        1,
        'custom deadlock XE session',
        'Das mutmassliche Opfer hat niedrigere Priority und ist daher ein guter Fall fuer Capture- und Policy-Diskussionen.'
    ),
    (
        7003,
        'FinanceLab',
        'OBJECTLOCK',
        'dbo.PeriodClose staging table',
        88,
        91,
        0,
        0,
        128.00,
        27,
        2,
        'system_health XE',
        'Mehrere betroffene Sessions und hoehere Rollback-Kosten machen Nachweise und Kommunikation wichtiger.'
    ),
    (
        7004,
        'SupportLab',
        'METADATA',
        'temp table schema stability',
        95,
        101,
        3,
        3,
        2.10,
        2,
        1,
        'custom deadlock XE session',
        'Gleiche Priority, daher ist die geschaetzte Rueckabwicklung ein plausibler Auswahlgrund fuer das Opfer.'
    );

-- 3. Opferbewertung und Capture-Prioritaet ableiten
CREATE TABLE #VictimAssessment
(
    DeadlockEventID           INT             NOT NULL,
    DatabaseName              SYSNAME         NOT NULL,
    VictimSessionID           SMALLINT        NOT NULL,
    VictimCount               INT             NOT NULL,
    VictimApproxRollbackMB    DECIMAL(18,2)   NOT NULL,
    VictimTranAgeMinutes      INT             NOT NULL,
    LikelySelectionDriver     VARCHAR(60)     NOT NULL,
    CaptureUrgency            VARCHAR(20)     NOT NULL,
    EvidenceToKeep            VARCHAR(220)    NOT NULL,
    ReviewSignal              VARCHAR(220)    NOT NULL
);

INSERT INTO #VictimAssessment
(
    DeadlockEventID,
    DatabaseName,
    VictimSessionID,
    VictimCount,
    VictimApproxRollbackMB,
    VictimTranAgeMinutes,
    LikelySelectionDriver,
    CaptureUrgency,
    EvidenceToKeep,
    ReviewSignal
)
SELECT
    dei.DeadlockEventID,
    dei.DatabaseName,
    dei.VictimSessionID,
    dei.VictimCount,
    dei.VictimApproxRollbackMB,
    dei.VictimTranAgeMinutes,
    CASE
        WHEN dei.VictimDeadlockPriority < dei.SurvivorDeadlockPriority THEN 'lower-deadlock-priority'
        WHEN dei.VictimApproxRollbackMB <= 8 THEN 'lower-rollback-cost'
        ELSE 'tie-needs-graph-review'
    END AS LikelySelectionDriver,
    CASE
        WHEN dei.VictimCount >= 2 OR dei.VictimApproxRollbackMB >= 64 THEN 'high'
        WHEN dei.VictimDeadlockPriority < dei.SurvivorDeadlockPriority THEN 'medium'
        ELSE 'normal'
    END AS CaptureUrgency,
    CONCAT(
        'Deadlock graph, input buffer, session owner, resource ',
        dei.ResourceType,
        ' und Quelle ',
        dei.SuggestedCaptureSource,
        ' sichern.'
    ) AS EvidenceToKeep,
    CASE
        WHEN dei.VictimCount >= 2
            THEN 'Mehrere Opfer-Sessions: Deadlock-Graph und Business-Kontext sofort sichern, bevor Folgeprobleme ueberdecken.'
        WHEN dei.VictimDeadlockPriority < dei.SurvivorDeadlockPriority
            THEN 'Niedrigere Priority erklaert das Opfer plausibel; pruefe, ob diese Einstellung bewusst oder versehentlich gesetzt wurde.'
        WHEN dei.VictimApproxRollbackMB <= 8
            THEN 'Geringe Rueckabwicklung spricht fuer Kosten-basierte Opferwahl; Code-Pfad und Sperrreihenfolge trotzdem dokumentieren.'
        ELSE 'Priority und Kosten reichen nicht fuer eine schnelle Erklaerung; Deadlock-Graph und Statement-Reihenfolge vertieft pruefen.'
    END AS ReviewSignal
FROM #DeadlockEventInventory AS dei
WHERE dei.VictimCount >= @MinimumVictimCount;

-- 4. Capture-Guide fuer Startmassnahmen formulieren
CREATE TABLE #CaptureActionGuide
(
    GuideStep                 TINYINT         NOT NULL,
    FocusArea                 VARCHAR(80)     NOT NULL,
    Recommendation            VARCHAR(220)    NOT NULL,
    WhyItHelps                VARCHAR(220)    NOT NULL
);

INSERT INTO #CaptureActionGuide
(
    GuideStep,
    FocusArea,
    Recommendation,
    WhyItHelps
)
VALUES
    (
        1,
        'Event source',
        'Zuerst pruefen, ob system_health oder eine eigene XE-Session den Deadlock-Graph bereits mitliefert.',
        'So werden vorhandene Nachweise genutzt, bevor hektisch weitere Diagnostik gestartet wird.'
    ),
    (
        2,
        'Victim context',
        'Victim-SPID, Statement, Deadlock-Priority und ungefaehre Rollback-Kosten gemeinsam dokumentieren.',
        'Damit bleibt nachvollziehbar, warum gerade diese Session verloren hat und wie teuer die Rueckabwicklung war.'
    ),
    (
        3,
        'Resource ordering',
        'Die gesperrten Ressourcen und die Statement-Reihenfolge der beteiligten Sessions als Paar betrachten.',
        'Deadlocks entstehen oft aus gegenlaeufiger Sperrreihenfolge, nicht nur aus hoher Last.'
    ),
    (
        4,
        'Follow-up',
        'Nach dem Capture Guardrails fuer Retry, Reihenfolge und kuerzere Transaktionen ableiten.',
        'Die nachhaltige Loesung liegt in robusterem Transaktionsdesign und nicht im blossen Einsammeln des Graphen.'
    );

-- 5. Resultsets ausgeben
SELECT
    dei.DeadlockEventID,
    dei.DatabaseName,
    dei.ResourceType,
    dei.ResourceDetail,
    dei.SurvivorSessionID,
    dei.VictimSessionID,
    dei.SurvivorDeadlockPriority,
    dei.VictimDeadlockPriority,
    dei.VictimApproxRollbackMB,
    dei.VictimTranAgeMinutes,
    dei.VictimCount,
    dei.SuggestedCaptureSource,
    dei.WhyRelevant
FROM #DeadlockEventInventory AS dei
WHERE dei.VictimCount >= @MinimumVictimCount
ORDER BY
    dei.VictimCount DESC,
    dei.VictimApproxRollbackMB DESC,
    dei.DeadlockEventID;

SELECT
    va.DeadlockEventID,
    va.DatabaseName,
    va.VictimSessionID,
    va.VictimCount,
    va.VictimApproxRollbackMB,
    va.VictimTranAgeMinutes,
    va.LikelySelectionDriver,
    va.CaptureUrgency,
    va.EvidenceToKeep,
    va.ReviewSignal
FROM #VictimAssessment AS va
ORDER BY
    CASE va.CaptureUrgency
        WHEN 'high' THEN 3
        WHEN 'medium' THEN 2
        ELSE 1
    END DESC,
    va.VictimApproxRollbackMB DESC,
    va.DeadlockEventID;

IF @IncludeActionGuide = 1
BEGIN
    SELECT
        cag.GuideStep,
        cag.FocusArea,
        cag.Recommendation,
        cag.WhyItHelps
    FROM #CaptureActionGuide AS cag
    ORDER BY
        cag.GuideStep;
END;
