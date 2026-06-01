/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "SavepointDemoHarness.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "19_Transaktions"

purpose: >
  Demonstriert SAVE TRANSACTION und partielles Rollback in einer
  didaktischen Beispielstrecke. Das Skript arbeitet nur mit temporaeren
  Tabellen, zeigt den Unterschied zwischen stabilen und riskanten
  Teilschritten und macht sichtbar, welche Aenderungen nach einem
  Rollback zum Savepoint erhalten bleiben.

parameters:
  - name: "@RollbackToSavepoint"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = riskanten Abschnitt bis zum Savepoint zurueckrollen, 0 = alle Demo-Schritte committen"
  - name: "@SimulateIssue"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = eine didaktische Stoerung im riskanten Abschnitt markieren"
  - name: "@IncludeGuide"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zusaetzlich einen kompakten Leitfaden fuer SAVE TRANSACTION und partielles Rollback ausgeben"

result_sets:
  - name: "ExecutionTimeline"
    description: "Zeigt die Demo-Schritte, Savepoint-Ereignisse und den beobachteten Transaktionszustand"
  - name: "WorkQueueState"
    description: "Zeigt den finalen Zustand der modellierten Arbeitspakete nach Commit mit oder ohne Savepoint-Rollback"
  - name: "SavepointGuide"
    description: "Leitet Guardrails und Review-Fragen fuer Savepoints, Teil-Rollbacks und Folge-Commit ab"

dependencies:
  - "tempdb temporary tables"
  - "@@TRANCOUNT"
  - "XACT_STATE"
  - "SAVE TRANSACTION"
  - "ROLLBACK TRANSACTION"
  - "CASE"
  - "ORDER BY"

safety:
  level: "demo-write-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/19_Transaktions/SQLScripts/SavepointDemoHarness.md"
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
    description: "Erstversion des didaktischen Labs fuer Savepoints und partielles Rollback"

notes:
  - "Das Skript schreibt nur in temporaere Tabellen und verwendet keinen produktiven Tabellenkontext."
  - "Die Stoerung im riskanten Abschnitt ist didaktisch modelliert; sie dient nur dazu, den Unterschied zwischen Savepoint-Rollback und Vollrollback sichtbar zu machen."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;
SET XACT_ABORT OFF;

-- 1. Parameter vorbereiten
DECLARE @RollbackToSavepoint BIT = 1;
DECLARE @SimulateIssue BIT = 1;
DECLARE @IncludeGuide BIT = 1;

IF @RollbackToSavepoint NOT IN (0, 1)
BEGIN
    THROW 50000, '@RollbackToSavepoint muss 0 oder 1 sein.', 1;
END;

IF @SimulateIssue NOT IN (0, 1)
BEGIN
    THROW 50001, '@SimulateIssue muss 0 oder 1 sein.', 1;
END;

IF @IncludeGuide NOT IN (0, 1)
BEGIN
    THROW 50002, '@IncludeGuide muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #WorkQueue;
DROP TABLE IF EXISTS #ExecutionTimeline;
DROP TABLE IF EXISTS #SavepointGuide;

CREATE TABLE #WorkQueue
(
    WorkItemID              INT            NOT NULL PRIMARY KEY,
    StepGroup               VARCHAR(20)    NOT NULL,
    TaskLabel               VARCHAR(80)    NOT NULL,
    ProcessingState         VARCHAR(20)    NOT NULL,
    AttemptNo               TINYINT        NOT NULL,
    ChangedAfterSavepoint   BIT            NOT NULL,
    Notes                   VARCHAR(220)   NOT NULL
);

CREATE TABLE #ExecutionTimeline
(
    TimelineOrder           INT            NOT NULL IDENTITY(1,1) PRIMARY KEY,
    StepLabel               VARCHAR(80)    NOT NULL,
    TranCountObserved       INT            NOT NULL,
    XactStateObserved       SMALLINT       NOT NULL,
    SavepointAction         VARCHAR(30)    NOT NULL,
    AffectedRows            INT            NOT NULL,
    Explanation             VARCHAR(220)   NOT NULL
);

CREATE TABLE #SavepointGuide
(
    GuideOrder              TINYINT        NOT NULL,
    Concern                 VARCHAR(90)    NOT NULL,
    WithoutSavepoint        VARCHAR(160)   NOT NULL,
    WithSavepoint           VARCHAR(160)   NOT NULL,
    ReviewFocus             VARCHAR(220)   NOT NULL
);

-- 2. Demo-Arbeitspakete vorbereiten
INSERT INTO #WorkQueue
(
    WorkItemID,
    StepGroup,
    TaskLabel,
    ProcessingState,
    AttemptNo,
    ChangedAfterSavepoint,
    Notes
)
VALUES
    (1, 'stable', 'Stage customer delta', 'pending', 0, 0, 'Vorbereitender Schritt vor dem Savepoint.'),
    (2, 'stable', 'Validate batch header', 'pending', 0, 0, 'Vorbereitender Guardrail vor dem riskanten Abschnitt.'),
    (3, 'risky', 'Apply invoice batch', 'pending', 0, 0, 'Kann bei einem Teilfehler separat rueckabgewickelt werden.'),
    (4, 'risky', 'Post allocation summary', 'pending', 0, 0, 'Haengt fachlich am riskanten Abschnitt.'),
    (5, 'stable', 'Finalize audit note', 'pending', 0, 0, 'Soll nach dem Teilrollback weiterhin committed werden koennen.');

INSERT INTO #ExecutionTimeline
(
    StepLabel,
    TranCountObserved,
    XactStateObserved,
    SavepointAction,
    AffectedRows,
    Explanation
)
VALUES
    (
        'Prepare demo queue',
        @@TRANCOUNT,
        XACT_STATE(),
        'none',
        5,
        'Die Demo startet ausserhalb einer aktiven Benutzertansaktion mit vorbereiteten Arbeitspaketen.'
    );

BEGIN TRANSACTION SavepointHarness;

INSERT INTO #ExecutionTimeline
(
    StepLabel,
    TranCountObserved,
    XactStateObserved,
    SavepointAction,
    AffectedRows,
    Explanation
)
VALUES
    (
        'Begin transaction',
        @@TRANCOUNT,
        XACT_STATE(),
        'begin tran',
        0,
        'Die uebergeordnete Demo-Transaktion startet und umschliesst stabile wie riskante Teilschritte.'
    );

-- 3. Stabile Vorbereitungsschritte vor dem Savepoint commit-faehig machen
UPDATE #WorkQueue
SET
    ProcessingState = 'prepared',
    AttemptNo = AttemptNo + 1,
    Notes = CASE WorkItemID
        WHEN 1 THEN 'Vorbereitende Aenderung bleibt auch nach Teilrollback erhalten.'
        WHEN 2 THEN 'Validierung bleibt vor dem riskanten Abschnitt dokumentiert.'
        ELSE Notes
    END
WHERE WorkItemID IN (1, 2);

INSERT INTO #ExecutionTimeline
(
    StepLabel,
    TranCountObserved,
    XactStateObserved,
    SavepointAction,
    AffectedRows,
    Explanation
)
VALUES
    (
        'Stable preparation',
        @@TRANCOUNT,
        XACT_STATE(),
        'none',
        @@ROWCOUNT,
        'Vorbereitende Updates laufen vor dem Savepoint und bleiben daher auch nach einem spaeteren Teilrollback sichtbar.'
    );

SAVE TRANSACTION RiskySectionStart;

INSERT INTO #ExecutionTimeline
(
    StepLabel,
    TranCountObserved,
    XactStateObserved,
    SavepointAction,
    AffectedRows,
    Explanation
)
VALUES
    (
        'Savepoint set',
        @@TRANCOUNT,
        XACT_STATE(),
        'save tran',
        0,
        'Der Savepoint markiert den Ruecksprungpunkt vor dem riskanten Abschnitt.'
    );

-- 4. Riskanten Abschnitt modellieren
UPDATE #WorkQueue
SET
    ProcessingState = CASE WHEN WorkItemID = 3 THEN 'posted' ELSE 'summarized' END,
    AttemptNo = AttemptNo + 1,
    ChangedAfterSavepoint = 1,
    Notes = CASE WorkItemID
        WHEN 3 THEN 'Riskanter Batcheschritt innerhalb des Savepoints.'
        WHEN 4 THEN 'Abgeleitete Folgeverarbeitung innerhalb des Savepoints.'
        ELSE Notes
    END
WHERE WorkItemID IN (3, 4);

INSERT INTO #ExecutionTimeline
(
    StepLabel,
    TranCountObserved,
    XactStateObserved,
    SavepointAction,
    AffectedRows,
    Explanation
)
VALUES
    (
        'Risky section changed',
        @@TRANCOUNT,
        XACT_STATE(),
        'none',
        @@ROWCOUNT,
        'Diese Aenderungen liegen hinter dem Savepoint und koennen isoliert rueckgaengig gemacht werden.'
    );

IF @SimulateIssue = 1
BEGIN
    UPDATE #WorkQueue
    SET Notes = 'Didaktisch markierte Stoerung: Summenpruefung oder Fachregel im riskanten Abschnitt fehlgeschlagen.'
    WHERE WorkItemID = 4;

    INSERT INTO #ExecutionTimeline
    (
        StepLabel,
        TranCountObserved,
        XactStateObserved,
        SavepointAction,
        AffectedRows,
        Explanation
    )
    VALUES
        (
            'Issue marked',
            @@TRANCOUNT,
            XACT_STATE(),
            'none',
            @@ROWCOUNT,
            'Die Stoerung wird absichtlich nur markiert, damit das Beispiel ohne Vollrollback weiter demonstrierbar bleibt.'
        );
END;

IF @RollbackToSavepoint = 1
BEGIN
    ROLLBACK TRANSACTION RiskySectionStart;

    INSERT INTO #ExecutionTimeline
    (
        StepLabel,
        TranCountObserved,
        XactStateObserved,
        SavepointAction,
        AffectedRows,
        Explanation
    )
    VALUES
        (
            'Rollback to savepoint',
            @@TRANCOUNT,
            XACT_STATE(),
            'rollback savepoint',
            2,
            'Nur die hinter dem Savepoint liegenden Demo-Aenderungen werden zurueckgenommen; die vorbereitenden Schritte bleiben aktiv.'
        );

    UPDATE #WorkQueue
    SET
        ProcessingState = 'retried',
        AttemptNo = AttemptNo + 1,
        ChangedAfterSavepoint = 0,
        Notes = 'Nach Teilrollback kontrolliert erneut ausgefuehrt.'
    WHERE WorkItemID = 3;

    INSERT INTO #ExecutionTimeline
    (
        StepLabel,
        TranCountObserved,
        XactStateObserved,
        SavepointAction,
        AffectedRows,
        Explanation
    )
    VALUES
        (
            'Safe retry after savepoint',
            @@TRANCOUNT,
            XACT_STATE(),
            'none',
            @@ROWCOUNT,
            'Nach dem Teilrollback wird nur der notwendige Teil erneut und kontrollierter ausgefuehrt.'
        );
END;
ELSE
BEGIN
    INSERT INTO #ExecutionTimeline
    (
        StepLabel,
        TranCountObserved,
        XactStateObserved,
        SavepointAction,
        AffectedRows,
        Explanation
    )
    VALUES
        (
            'No rollback path',
            @@TRANCOUNT,
            XACT_STATE(),
            'none',
            0,
            'Alle riskanten Demo-Aenderungen bleiben in der Transaktion und werden zusammen committed.'
        );
END;

-- 5. Stabilen Abschlussschritt nach dem Savepoint committen
UPDATE #WorkQueue
SET
    ProcessingState = 'committed',
    AttemptNo = AttemptNo + 1,
    Notes = 'Abschlussschritt nach Savepoint und optionalem Teilrollback erfolgreich markiert.'
WHERE WorkItemID = 5;

INSERT INTO #ExecutionTimeline
(
    StepLabel,
    TranCountObserved,
    XactStateObserved,
    SavepointAction,
    AffectedRows,
    Explanation
)
VALUES
    (
        'Finalize stable step',
        @@TRANCOUNT,
        XACT_STATE(),
        'none',
        @@ROWCOUNT,
        'Auch nach einem Ruecksprung zum Savepoint koennen spaetere, weiterhin gueltige Schritte committed werden.'
    );

COMMIT TRANSACTION SavepointHarness;

INSERT INTO #ExecutionTimeline
(
    StepLabel,
    TranCountObserved,
    XactStateObserved,
    SavepointAction,
    AffectedRows,
    Explanation
)
VALUES
    (
        'Commit transaction',
        @@TRANCOUNT,
        XACT_STATE(),
        'commit',
        0,
        'Die verbleibenden Demo-Aenderungen werden dauerhaft innerhalb dieses Skriptlaufs bestaetigt.'
    );

-- 6. Leitfaden fuer Savepoint-Reviews aufbauen
INSERT INTO #SavepointGuide
(
    GuideOrder,
    Concern,
    WithoutSavepoint,
    WithSavepoint,
    ReviewFocus
)
VALUES
    (
        1,
        'Risky substep fails',
        'Oft bleibt nur Vollrollback der gesamten Transaktion.',
        'Nur der riskante Abschnitt kann bis zum Savepoint zurueckgesetzt werden.',
        'Pruefen, welcher Teil wirklich separat rueckabwickelbar sein soll und welche Schritte davor erhalten bleiben muessen.'
    ),
    (
        2,
        'Follow-up processing',
        'Auch spaetere stabile Schritte werden bei Vollrollback verworfen.',
        'Nach Teilrollback kann die Transaktion kontrolliert fortgesetzt und committed werden.',
        'Die Abhaengigkeit zwischen riskanten und stabilen Teilschritten explizit dokumentieren.'
    ),
    (
        3,
        'Incident communication',
        'Es ist schwerer zu erklaeren, welche Aenderungen verworfen oder beibehalten wurden.',
        'Savepoints erlauben eine praezisere Aussage ueber den Ruecksprungpunkt.',
        'Transaktionsgrenzen, Savepoint-Namen und fachliche Auswirkungen im Runbook klar benennen.'
    ),
    (
        4,
        'Technical guardrail',
        'Ein Vollrollback loest zwar sauber auf, kann aber mehr Arbeit als noetig verlieren.',
        'Savepoints sind nur dann sinnvoll, wenn der Zwischenzustand fachlich und technisch bewusst gestaltet ist.',
        'Teilrollback nicht als Notbehelf nutzen, sondern nur bei sauber vorbereiteten Zwischenstufen.'
    );

-- 7. Resultsets ausgeben
SELECT
    et.TimelineOrder,
    et.StepLabel,
    et.TranCountObserved,
    et.XactStateObserved,
    et.SavepointAction,
    et.AffectedRows,
    et.Explanation
FROM #ExecutionTimeline AS et
ORDER BY
    et.TimelineOrder;

SELECT
    wq.WorkItemID,
    wq.StepGroup,
    wq.TaskLabel,
    wq.ProcessingState,
    wq.AttemptNo,
    wq.ChangedAfterSavepoint,
    wq.Notes
FROM #WorkQueue AS wq
ORDER BY
    wq.WorkItemID;

IF @IncludeGuide = 1
BEGIN
    SELECT
        sg.GuideOrder,
        sg.Concern,
        sg.WithoutSavepoint,
        sg.WithSavepoint,
        sg.ReviewFocus
    FROM #SavepointGuide AS sg
    ORDER BY
        sg.GuideOrder;
END;
