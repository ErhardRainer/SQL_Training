/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "KillDecisionChecklist.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "19_Transaktions"

purpose: >
  Baut eine didaktische Entscheidungscheckliste fuer moegliche KILL-
  Situationen bei blockierenden oder lang laufenden Sessions auf und
  zeigt vor einer Eskalation die wichtigsten Guardrails, Risiken und
  Alternativen.

parameters:
  - name: "@MinimumBlockedSessions"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Filtert auf modellierte Vorfaelle ab dieser Anzahl blockierter Sessions"
  - name: "@IncludeEscalationMatrix"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zusaetzlich eine Eskalationsmatrix mit Alternativen und Kommunikationspflichten ausgeben"

result_sets:
  - name: "IncidentInventory"
    description: "Beschreibt modellierte Vorfaelle mit Root-Session, Dauer, Blockierungsbreite und Rollback-Risiko"
  - name: "KillDecisionChecklist"
    description: "Leitet fuer jeden Vorfall konkrete Review-Schritte, Kill-Empfehlung und sichere Alternativen ab"
  - name: "EscalationMatrix"
    description: "Fasst Eskalationsstufe, Kommunikationsbedarf und naechste Schritte fuer Incident-Reviews zusammen"

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
  markdown_file: "T-SQL/19_Transaktions/SQLScripts/KillDecisionChecklist.md"
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
    description: "Erstversion des didaktischen Labs fuer Kill-Entscheidungschecklisten"

notes:
  - "Das Skript modelliert Incident-Faelle in tempdb und fuehrt kein KILL aus"
  - "Checkliste, Rollback-Risiko und Alternativen sind fuer Unterricht, Review und Troubleshooting gedacht"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

-- 1. Parameter vorbereiten
DECLARE @MinimumBlockedSessions INT = 1;
DECLARE @IncludeEscalationMatrix BIT = 1;

IF @MinimumBlockedSessions < 0
BEGIN
    THROW 50000, '@MinimumBlockedSessions darf nicht negativ sein.', 1;
END;

IF @IncludeEscalationMatrix NOT IN (0, 1)
BEGIN
    THROW 50001, '@IncludeEscalationMatrix muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #IncidentInventory;
DROP TABLE IF EXISTS #KillDecisionChecklist;
DROP TABLE IF EXISTS #EscalationMatrix;

-- 2. Modellierte Vorfaelle fuer Kill-Reviews aufbauen
CREATE TABLE #IncidentInventory
(
    IncidentID                 INT             NOT NULL,
    RootSessionID              SMALLINT        NOT NULL,
    DatabaseName               SYSNAME         NOT NULL,
    TransactionName            VARCHAR(90)     NOT NULL,
    BlockingDurationMinutes    INT             NOT NULL,
    BlockedSessionCount        INT             NOT NULL,
    ApproxRollbackMB           DECIMAL(18,2)   NOT NULL,
    IsBusinessCritical         BIT             NOT NULL,
    WaitProfile                VARCHAR(80)     NOT NULL,
    ImmediateAlternative       VARCHAR(220)    NOT NULL,
    WhyRelevant                VARCHAR(220)    NOT NULL
);

INSERT INTO #IncidentInventory
(
    IncidentID,
    RootSessionID,
    DatabaseName,
    TransactionName,
    BlockingDurationMinutes,
    BlockedSessionCount,
    ApproxRollbackMB,
    IsBusinessCritical,
    WaitProfile,
    ImmediateAlternative,
    WhyRelevant
)
VALUES
    (
        1,
        57,
        'SalesLab',
        'Batch price update',
        42,
        5,
        180.00,
        1,
        'Wartende OLTP-Updates und ein Reporting-Job',
        'Owner kontaktieren und Commit-Grenzen fuer den Batch pruefen',
        'Mehrere betroffene Sessions und spuerbarer Rollback-Aufwand machen eine geordnete Kill-Pruefung noetig.'
    ),
    (
        2,
        63,
        'WarehouseLab',
        'Inventory sync',
        17,
        2,
        24.00,
        0,
        'Kurze Queue von Nachschub-Requests',
        'Kurz auf Batch-Ende warten und parallele Last pruefen',
        'Begrenzte Opferzahl mit moderatem Rollback-Risiko eignet sich als ruhiger Vergleichsfall.'
    ),
    (
        3,
        88,
        'FinanceLab',
        'Year-end correction',
        61,
        8,
        420.00,
        1,
        'Stark blockierte Monatsabschluss- und Freigabeprozesse',
        'Incident-Eskalation und Rollback-Fenster vorab kommunizieren',
        'Hohe Blockierungsbreite und grosses Rueckabwicklungsfenster verlangen Eskalation vor jeder Kill-Entscheidung.'
    ),
    (
        4,
        91,
        'SupportLab',
        'Case export snapshot',
        9,
        1,
        9.50,
        0,
        'Einzelner wartender Export',
        'Session-Ende abwarten oder Last kurz umleiten',
        'Didaktischer Baseline-Fall fuer Situationen, in denen ein Kill meist nicht die erste Wahl ist.'
    );

-- 3. Priorisierte Kill-Checkliste je Vorfall ableiten
CREATE TABLE #KillDecisionChecklist
(
    IncidentID                 INT             NOT NULL,
    RootSessionID              SMALLINT        NOT NULL,
    DatabaseName               SYSNAME         NOT NULL,
    ReviewStep                 TINYINT         NOT NULL,
    CheckpointName             VARCHAR(80)     NOT NULL,
    ChecklistQuestion          VARCHAR(220)    NOT NULL,
    DecisionSignal             VARCHAR(30)     NOT NULL,
    RecommendedAction          VARCHAR(220)    NOT NULL,
    Reasoning                  VARCHAR(220)    NOT NULL
);

INSERT INTO #KillDecisionChecklist
(
    IncidentID,
    RootSessionID,
    DatabaseName,
    ReviewStep,
    CheckpointName,
    ChecklistQuestion,
    DecisionSignal,
    RecommendedAction,
    Reasoning
)
SELECT
    ii.IncidentID,
    ii.RootSessionID,
    ii.DatabaseName,
    checklist.ReviewStep,
    checklist.CheckpointName,
    checklist.ChecklistQuestion,
    checklist.DecisionSignal,
    checklist.RecommendedAction,
    checklist.Reasoning
FROM #IncidentInventory AS ii
CROSS APPLY
(
    VALUES
        (
            CAST(1 AS TINYINT),
            'Root blocker verification',
            'Ist wirklich die root Session identifiziert und nicht nur ein wartender Folgeprozess?',
            'mandatory',
            'Vor jeder Eskalation Session, Statement und Transaktionsbesitzer gemeinsam bestaetigen.',
            'Ein Kill gegen das falsche Ziel loest die Blockade nicht und erzeugt einen zusaetzlichen Vorfall.'
        ),
        (
            CAST(2 AS TINYINT),
            'Rollback estimate',
            'Ist das erwartete Rollback-Fenster gegen die aktuelle Blockierungsdauer abgewogen?',
            CASE
                WHEN ii.ApproxRollbackMB >= 256 THEN 'escalate'
                WHEN ii.ApproxRollbackMB >= 96 THEN 'review'
                ELSE 'watch'
            END,
            CASE
                WHEN ii.ApproxRollbackMB >= 256 THEN 'Rollback-Zeitfenster und Monitoring vorab mit Incident-Owner abstimmen.'
                WHEN ii.ApproxRollbackMB >= 96 THEN 'Rollback grob einschaetzen und mit dem Nutzen eines Kill vergleichen.'
                ELSE 'Rollback-Risiko dokumentieren, aber zunaechst Alternativen pruefen.'
            END,
            'Die Rueckabwicklung kann laenger dauern als das aktuelle Warten und bestimmt die operative Tragweite.'
        ),
        (
            CAST(3 AS TINYINT),
            'Business impact',
            'Wie breit ist die Blockierung und trifft sie kritische Prozesse oder Servicefenster?',
            CASE
                WHEN ii.BlockedSessionCount >= 6 OR ii.IsBusinessCritical = 1 THEN 'high'
                WHEN ii.BlockedSessionCount >= 3 THEN 'review'
                ELSE 'low'
            END,
            CASE
                WHEN ii.BlockedSessionCount >= 6 OR ii.IsBusinessCritical = 1 THEN 'Betroffene Teams informieren und Kill nur mit abgestimmtem Kommunikationsfenster betrachten.'
                WHEN ii.BlockedSessionCount >= 3 THEN 'Auswirkungen dokumentieren und Alternativen gegen den Kill gegeneinander stellen.'
                ELSE 'Fall als lokale Stoerung behandeln und bevorzugt auf Ende oder Batch-Anpassung setzen.'
            END,
            'Nicht jede blockierte Session rechtfertigt einen Kill; Breite und Kritikalitaet sind die eigentliche Priorisierungsbasis.'
        ),
        (
            CAST(4 AS TINYINT),
            'Safer alternative',
            'Gibt es vor dem Kill eine sicherere Alternative mit geringerem Schaden?',
            CASE
                WHEN ii.BlockedSessionCount <= 2 AND ii.ApproxRollbackMB < 64 THEN 'prefer-alternative'
                ELSE 'compare'
            END,
            ii.ImmediateAlternative,
            'Kurzes Warten, Owner-Kontakt oder Batch-Grenzen sind oft risikoaermer als ein harter Session-Abbruch.'
        ),
        (
            CAST(5 AS TINYINT),
            'Decision outcome',
            'Welche Arbeitsentscheidung ergibt sich nach den Guardrails fuer diesen Vorfall?',
            CASE
                WHEN ii.BlockedSessionCount >= 6 AND ii.ApproxRollbackMB >= 256 THEN 'kill-only-after-escalation'
                WHEN ii.BlockedSessionCount >= 4 THEN 'review-now'
                ELSE 'do-not-rush'
            END,
            CASE
                WHEN ii.BlockedSessionCount >= 6 AND ii.ApproxRollbackMB >= 256 THEN 'Kill nur nach Eskalation, Root-Cause-Bestaetigung und klarer Rollback-Kommunikation erwaegen.'
                WHEN ii.BlockedSessionCount >= 4 THEN 'Kill erst nach Root-Cause-Pruefung und dokumentierter Alternativenabwaegung bewerten.'
                ELSE 'Kill nicht forcieren; zunaechst beobachten, Owner einbinden oder Batch-Ende abwarten.'
            END,
            'Die Abschlussentscheidung fasst Blockierungsbreite, Rollback-Risiko und Alternativen in einer operativen Empfehlung zusammen.'
        )
) AS checklist
(
    ReviewStep,
    CheckpointName,
    ChecklistQuestion,
    DecisionSignal,
    RecommendedAction,
    Reasoning
)
WHERE ii.BlockedSessionCount >= @MinimumBlockedSessions;

-- 4. Eskalationsmatrix fuer Kommunikation und naechste Schritte aufbauen
CREATE TABLE #EscalationMatrix
(
    IncidentID                 INT             NOT NULL,
    RootSessionID              SMALLINT        NOT NULL,
    DatabaseName               SYSNAME         NOT NULL,
    EscalationLevel            VARCHAR(24)     NOT NULL,
    CommunicationNeed          VARCHAR(220)    NOT NULL,
    NextStep                   VARCHAR(220)    NOT NULL,
    WhyItHelps                 VARCHAR(220)    NOT NULL
);

INSERT INTO #EscalationMatrix
(
    IncidentID,
    RootSessionID,
    DatabaseName,
    EscalationLevel,
    CommunicationNeed,
    NextStep,
    WhyItHelps
)
SELECT
    ii.IncidentID,
    ii.RootSessionID,
    ii.DatabaseName,
    CASE
        WHEN ii.BlockedSessionCount >= 6 AND ii.ApproxRollbackMB >= 256 THEN 'incident-bridge'
        WHEN ii.BlockedSessionCount >= 4 OR ii.IsBusinessCritical = 1 THEN 'team-review'
        ELSE 'local-review'
    END AS EscalationLevel,
    CASE
        WHEN ii.BlockedSessionCount >= 6 AND ii.ApproxRollbackMB >= 256 THEN 'Explizites Rollback-Fenster, betroffene Fachprozesse und Owner-Verfuegbarkeit vorab kommunizieren.'
        WHEN ii.BlockedSessionCount >= 4 OR ii.IsBusinessCritical = 1 THEN 'Betrieb, Application-Owner und betroffene Batch-Verantwortliche kurz synchronisieren.'
        ELSE 'Lokales Review im Betrieb reicht meist aus.'
    END AS CommunicationNeed,
    CASE
        WHEN ii.BlockedSessionCount >= 6 AND ii.ApproxRollbackMB >= 256 THEN 'Root blocker bestaetigen, Rollback-Monitoring vorbereiten und Kill nur mit freigegebenem Zeitfenster betrachten.'
        WHEN ii.BlockedSessionCount >= 4 OR ii.IsBusinessCritical = 1 THEN 'Alternativen pruefen, Owner kontaktieren und Kill-Option dokumentiert gegen Warten vergleichen.'
        ELSE 'Blockierung beobachten, Alternative nutzen oder Batch-Ende abwarten.'
    END AS NextStep,
    CASE
        WHEN ii.BlockedSessionCount >= 6 AND ii.ApproxRollbackMB >= 256 THEN 'Hohe Last und grosses Rollback-Risiko verlangen einen abgestimmten Incident-Rahmen.'
        WHEN ii.BlockedSessionCount >= 4 OR ii.IsBusinessCritical = 1 THEN 'Koordinierte Bewertung verhindert vorschnelle Session-Abbrueche mit Nebenwirkungen.'
        ELSE 'Kleine Faelle koennen didaktisch als Beispiel fuer Zurueckhaltung vor KILL dienen.'
    END AS WhyItHelps
FROM #IncidentInventory AS ii
WHERE ii.BlockedSessionCount >= @MinimumBlockedSessions;

-- 5. Resultsets ausgeben
SELECT
    ii.IncidentID,
    ii.RootSessionID,
    ii.DatabaseName,
    ii.TransactionName,
    ii.BlockingDurationMinutes,
    ii.BlockedSessionCount,
    ii.ApproxRollbackMB,
    ii.IsBusinessCritical,
    ii.WaitProfile,
    ii.ImmediateAlternative,
    ii.WhyRelevant
FROM #IncidentInventory AS ii
WHERE ii.BlockedSessionCount >= @MinimumBlockedSessions
ORDER BY
    ii.BlockedSessionCount DESC,
    ii.ApproxRollbackMB DESC,
    ii.IncidentID;

SELECT
    kdc.IncidentID,
    kdc.RootSessionID,
    kdc.DatabaseName,
    kdc.ReviewStep,
    kdc.CheckpointName,
    kdc.ChecklistQuestion,
    kdc.DecisionSignal,
    kdc.RecommendedAction,
    kdc.Reasoning
FROM #KillDecisionChecklist AS kdc
ORDER BY
    kdc.IncidentID,
    kdc.ReviewStep;

IF @IncludeEscalationMatrix = 1
BEGIN
    SELECT
        em.IncidentID,
        em.RootSessionID,
        em.DatabaseName,
        em.EscalationLevel,
        em.CommunicationNeed,
        em.NextStep,
        em.WhyItHelps
    FROM #EscalationMatrix AS em
    ORDER BY
        CASE em.EscalationLevel
            WHEN 'incident-bridge' THEN 1
            WHEN 'team-review' THEN 2
            ELSE 3
        END,
        em.IncidentID;
END;
