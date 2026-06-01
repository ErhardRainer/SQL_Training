/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "BlockedSessionKillPreview.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "19_Transaktions"

purpose: >
  Zeigt anhand einer modellierten Blocking-Kette, welche Folgen ein
  KILL des vermuteten Root-Blockers fuer Blockierungsdauer,
  Rollback-Fenster und betroffene Requests haben kann. Das Skript
  berechnet bewusst nur eine didaktische Vorschau und fuehrt kein
  KILL aus.

parameters:
  - name: "@MinimumBlockedSessions"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Filtert auf Blocking-Ketten ab dieser Anzahl direkt oder indirekt blockierter Sessions"
  - name: "@IncludeGuardrailGuide"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zusaetzlich einen Guardrail-Guide fuer Kill-Entscheidungen ausgeben"

result_sets:
  - name: "BlockingChainInventory"
    description: "Beschreibt modellierte Blocking-Ketten mit Root-Blocker, Dauer und Kontext"
  - name: "KillImpactPreview"
    description: "Leitet eine Vorschau fuer Rollback-Zeitfenster, betroffene Opfer und Freigabe-Effekt ab"
  - name: "GuardrailGuide"
    description: "Fasst Review-Regeln fuer Kill-Entscheidungen, Kommunikation und Nacharbeit zusammen"

dependencies:
  - "tempdb temporary tables"
  - "SYSUTCDATETIME"
  - "DATEDIFF"
  - "CASE"
  - "ORDER BY"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/19_Transaktions/SQLScripts/BlockedSessionKillPreview.md"
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
    description: "Erstversion des didaktischen Labs fuer Kill-Vorschau bei Blocking-Ketten"

notes:
  - "Das Skript arbeitet mit modellierten Blocking-Ketten statt mit produktiven DMVs oder echten KILL-Befehlen"
  - "Rollback-Zeit und Freigabe-Effekt sind didaktische Schaetzwerte fuer Review und Troubleshooting"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

-- 1. Parameter vorbereiten
DECLARE @MinimumBlockedSessions INT = 1;
DECLARE @IncludeGuardrailGuide BIT = 1;

IF @MinimumBlockedSessions < 0
BEGIN
    THROW 50000, '@MinimumBlockedSessions darf nicht negativ sein.', 1;
END;

IF @IncludeGuardrailGuide NOT IN (0, 1)
BEGIN
    THROW 50001, '@IncludeGuardrailGuide muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #BlockingChainInventory;
DROP TABLE IF EXISTS #KillImpactPreview;
DROP TABLE IF EXISTS #GuardrailGuide;

-- 2. Modellierte Blocking-Ketten aufbauen
CREATE TABLE #BlockingChainInventory
(
    ChainID                    INT             NOT NULL,
    RootBlockerSessionID       SMALLINT        NOT NULL,
    DatabaseName               SYSNAME         NOT NULL,
    RootTransactionName        VARCHAR(90)     NOT NULL,
    RootTransactionAgeMinutes  INT             NOT NULL,
    DirectlyBlockedSessions    INT             NOT NULL,
    IndirectlyBlockedSessions  INT             NOT NULL,
    ApproxRollbackMB           DECIMAL(18,2)   NOT NULL,
    RootCommandType            VARCHAR(40)     NOT NULL,
    WhyRelevant                VARCHAR(220)    NOT NULL
);

INSERT INTO #BlockingChainInventory
(
    ChainID,
    RootBlockerSessionID,
    DatabaseName,
    RootTransactionName,
    RootTransactionAgeMinutes,
    DirectlyBlockedSessions,
    IndirectlyBlockedSessions,
    ApproxRollbackMB,
    RootCommandType,
    WhyRelevant
)
VALUES
    (
        1,
        57,
        'SalesLab',
        'Batch price update',
        38,
        3,
        2,
        128.00,
        'UPDATE',
        'Lange Schreibtransaktion blockiert Folgearbeiten; Kill-Entscheidung muss gegen Rollback-Dauer abgewogen werden.'
    ),
    (
        2,
        72,
        'WarehouseLab',
        'Inventory sync',
        14,
        1,
        0,
        22.50,
        'MERGE',
        'Mittlere Kette mit ueberschaubarer Opferzahl, aber moeglicher Auswirkung auf ein Zeitfenster fuer Nachschubdaten.'
    ),
    (
        3,
        88,
        'FinanceLab',
        'Year-end correction',
        54,
        4,
        5,
        310.00,
        'DELETE',
        'Kritischer Demo-Fall mit grossem Rollback-Risiko und mehreren nachgelagerten Sessions.'
    ),
    (
        4,
        91,
        'SupportLab',
        'Case export snapshot',
        9,
        1,
        1,
        8.75,
        'SELECT INTO',
        'Kuerzere Demo-Kette mit eher kleinem Rollback-Fenster als Baseline fuer ruhigere Situationen.'
    );

-- 3. Kill-Auswirkung und Freigabe-Vorschau ableiten
CREATE TABLE #KillImpactPreview
(
    ChainID                    INT             NOT NULL,
    RootBlockerSessionID       SMALLINT        NOT NULL,
    DatabaseName               SYSNAME         NOT NULL,
    TotalBlockedSessions       INT             NOT NULL,
    ApproxRollbackMB           DECIMAL(18,2)   NOT NULL,
    EstimatedRollbackMinutes   DECIMAL(18,2)   NOT NULL,
    ReleasePriority            VARCHAR(20)     NOT NULL,
    KillReadiness              VARCHAR(30)     NOT NULL,
    PreviewNarrative           VARCHAR(220)    NOT NULL,
    SaferAlternative           VARCHAR(220)    NOT NULL
);

INSERT INTO #KillImpactPreview
(
    ChainID,
    RootBlockerSessionID,
    DatabaseName,
    TotalBlockedSessions,
    ApproxRollbackMB,
    EstimatedRollbackMinutes,
    ReleasePriority,
    KillReadiness,
    PreviewNarrative,
    SaferAlternative
)
SELECT
    bci.ChainID,
    bci.RootBlockerSessionID,
    bci.DatabaseName,
    bci.DirectlyBlockedSessions + bci.IndirectlyBlockedSessions AS TotalBlockedSessions,
    bci.ApproxRollbackMB,
    CAST(
        CASE
            WHEN bci.ApproxRollbackMB >= 256 THEN bci.ApproxRollbackMB / 6.5
            WHEN bci.ApproxRollbackMB >= 64 THEN bci.ApproxRollbackMB / 8.0
            ELSE bci.ApproxRollbackMB / 10.0
        END
        AS DECIMAL(18,2)
    ) AS EstimatedRollbackMinutes,
    CASE
        WHEN bci.DirectlyBlockedSessions + bci.IndirectlyBlockedSessions >= 7 THEN 'urgent'
        WHEN bci.DirectlyBlockedSessions + bci.IndirectlyBlockedSessions >= 3 THEN 'high'
        ELSE 'moderate'
    END AS ReleasePriority,
    CASE
        WHEN bci.ApproxRollbackMB >= 256 THEN 'needs-escalation'
        WHEN bci.DirectlyBlockedSessions + bci.IndirectlyBlockedSessions >= 4 THEN 'review-now'
        ELSE 'review'
    END AS KillReadiness,
    CASE
        WHEN bci.ApproxRollbackMB >= 256 THEN 'Kill koennte viele Sessions freigeben, erzeugt aber voraussichtlich ein langes Rollback-Fenster mit enger Kommunikationspflicht.'
        WHEN bci.DirectlyBlockedSessions + bci.IndirectlyBlockedSessions >= 4 THEN 'Kill wuerde mehrere Folge-Sessions entlasten; vorab muessen Root-Ursache, Besitzer und Rollback-Zeit klar sein.'
        ELSE 'Kill ist didaktisch denkbar, aber erst nach Pruefung von Commit- oder Batch-Alternativen sinnvoll.'
    END AS PreviewNarrative,
    CASE
        WHEN bci.RootCommandType IN ('UPDATE', 'DELETE', 'MERGE') THEN 'Transaktionsbesitzer kontaktieren, Batch grob einschaetzen und moegliche Commit-Grenze oder Wartestatus pruefen.'
        ELSE 'Laufende Session und Zielobjekte ueberpruefen, bevor ein Kill als Standardreaktion verwendet wird.'
    END AS SaferAlternative
FROM #BlockingChainInventory AS bci
WHERE (bci.DirectlyBlockedSessions + bci.IndirectlyBlockedSessions) >= @MinimumBlockedSessions;

-- 4. Guardrails fuer Kill-Entscheidungen aufbauen
CREATE TABLE #GuardrailGuide
(
    GuideStep                  TINYINT         NOT NULL,
    FocusArea                  VARCHAR(80)     NOT NULL,
    Recommendation             VARCHAR(220)    NOT NULL,
    WhyItHelps                 VARCHAR(220)    NOT NULL
);

INSERT INTO #GuardrailGuide
(
    GuideStep,
    FocusArea,
    Recommendation,
    WhyItHelps
)
VALUES
    (
        1,
        'Root blocker verification',
        'Vor jedem Kill pruefen, ob wirklich der Root-Blocker und nicht nur ein Opfer in der Mitte der Kette getroffen wird.',
        'Falsche Ziele loesen das Blocking nicht und vergroessern den Vorfall um eine weitere Session-Unterbrechung.'
    ),
    (
        2,
        'Rollback expectation',
        'Rollback-Fenster und Datenmenge vorab abschaetzen und im Incident offen kommunizieren.',
        'Ein Kill beendet die Session nicht sofort; die Rueckabwicklung kann laenger dauern als die Blockade selbst.'
    ),
    (
        3,
        'Business coordination',
        'Transaktionsbesitzer, betroffene Jobs und moegliche Folgeschritte vor dem Kill abstimmen.',
        'So werden doppelte Gegenmassnahmen, erneute Lastspitzen und unvollstaendige Nacharbeiten vermieden.'
    ),
    (
        4,
        'Post-incident review',
        'Nach einer Kill-Entscheidung immer Ursache, Batch-Design und Monitoring-Luecken dokumentieren.',
        'Die nachhaltige Verbesserung liegt meist in kleineren Transaktionen, klareren Timeouts und besserer Beobachtbarkeit.'
    );

-- 5. Resultsets ausgeben
SELECT
    bci.ChainID,
    bci.RootBlockerSessionID,
    bci.DatabaseName,
    bci.RootTransactionName,
    bci.RootTransactionAgeMinutes,
    bci.DirectlyBlockedSessions,
    bci.IndirectlyBlockedSessions,
    bci.ApproxRollbackMB,
    bci.RootCommandType,
    bci.WhyRelevant
FROM #BlockingChainInventory AS bci
WHERE (bci.DirectlyBlockedSessions + bci.IndirectlyBlockedSessions) >= @MinimumBlockedSessions
ORDER BY
    (bci.DirectlyBlockedSessions + bci.IndirectlyBlockedSessions) DESC,
    bci.ApproxRollbackMB DESC,
    bci.ChainID;

SELECT
    kip.ChainID,
    kip.RootBlockerSessionID,
    kip.DatabaseName,
    kip.TotalBlockedSessions,
    kip.ApproxRollbackMB,
    kip.EstimatedRollbackMinutes,
    kip.ReleasePriority,
    kip.KillReadiness,
    kip.PreviewNarrative,
    kip.SaferAlternative
FROM #KillImpactPreview AS kip
ORDER BY
    kip.TotalBlockedSessions DESC,
    kip.EstimatedRollbackMinutes DESC,
    kip.ChainID;

IF @IncludeGuardrailGuide = 1
BEGIN
    SELECT
        g.GuideStep,
        g.FocusArea,
        g.Recommendation,
        g.WhyItHelps
    FROM #GuardrailGuide AS g
    ORDER BY
        g.GuideStep;
END;
