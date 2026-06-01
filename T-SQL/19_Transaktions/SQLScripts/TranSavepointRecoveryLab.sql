/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "TranSavepointRecoveryLab.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "19_Transaktions"

purpose: >
  Zeigt ein didaktisches Recovery-Muster mit SAVE TRANSACTION, indem
  vorbereitende, riskante und nachgelagerte Schritte innerhalb einer
  Demo-Transaktion getrennt beobachtet werden. Das Skript modelliert,
  wie ein Ruecksprung zum Savepoint einen begrenzten Wiederanlauf
  erlaubt, ohne den stabilen Vorlauf der Transaktion zu verlieren.

parameters:
  - name: "@TriggerValidationFailure"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = simuliert einen fachlichen Fehler im riskanten Abschnitt und aktiviert den Recovery-Pfad"
  - name: "@ReplayAfterRecovery"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = fuehrt nach dem Rollback eine kontrollierte Ersatzverarbeitung aus"
  - name: "@ShowRecoveryGuide"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = gibt zusaetzlich einen kompakten Leitfaden fuer Recovery mit Savepoints aus"

result_sets:
  - name: "RecoveryTimeline"
    description: "Chronologische Sicht auf Savepoint, Validierungsfehler, Teilrollback und Wiederanlauf"
  - name: "UnitState"
    description: "Finaler Zustand der modellierten Verarbeitungseinheiten nach Savepoint-Recovery"
  - name: "RecoveryGuide"
    description: "Leitet Guardrails fuer Savepoints, Wiederanlauf und Commit-Entscheidungen ab"

dependencies:
  - "tempdb temporary tables"
  - "@@TRANCOUNT"
  - "XACT_STATE"
  - "TRY...CATCH"
  - "SAVE TRANSACTION"
  - "ROLLBACK TRANSACTION"
  - "CASE"
  - "ORDER BY"

safety:
  level: "demo-write-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/19_Transaktions/SQLScripts/TranSavepointRecoveryLab.md"
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
    description: "Erstversion des didaktischen Labs fuer Savepoint-basierte Recovery"

notes:
  - "Das Skript verwendet nur temporaere Tabellen und modelliert Recovery-Verhalten ohne produktive Datenbankaenderungen."
  - "Der Fehlerpfad ist didaktisch simuliert, damit der Unterschied zwischen Teilrollback, Wiederanlauf und Commit nachvollziehbar bleibt."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;
SET XACT_ABORT OFF;

-- 1. Parameter vorbereiten
DECLARE @TriggerValidationFailure BIT = 1;
DECLARE @ReplayAfterRecovery BIT = 1;
DECLARE @ShowRecoveryGuide BIT = 1;

IF @TriggerValidationFailure NOT IN (0, 1)
BEGIN
    THROW 50000, '@TriggerValidationFailure muss 0 oder 1 sein.', 1;
END;

IF @ReplayAfterRecovery NOT IN (0, 1)
BEGIN
    THROW 50001, '@ReplayAfterRecovery muss 0 oder 1 sein.', 1;
END;

IF @ShowRecoveryGuide NOT IN (0, 1)
BEGIN
    THROW 50002, '@ShowRecoveryGuide muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #RecoveryUnits;
DROP TABLE IF EXISTS #RecoveryTimeline;
DROP TABLE IF EXISTS #RecoveryGuide;

CREATE TABLE #RecoveryUnits
(
    UnitID                   INT            NOT NULL PRIMARY KEY,
    PhaseGroup               VARCHAR(20)    NOT NULL,
    UnitName                 VARCHAR(90)    NOT NULL,
    ProcessingState          VARCHAR(30)    NOT NULL,
    LastAttempt              TINYINT        NOT NULL,
    AfterSavepointChange     BIT            NOT NULL,
    RecoveryDecision         VARCHAR(40)    NOT NULL,
    Notes                    VARCHAR(220)   NOT NULL
);

CREATE TABLE #RecoveryTimeline
(
    TimelineStep             INT            NOT NULL IDENTITY(1,1) PRIMARY KEY,
    StepLabel                VARCHAR(90)    NOT NULL,
    TranCountObserved        INT            NOT NULL,
    XactStateObserved        SMALLINT       NOT NULL,
    RecoveryAction           VARCHAR(40)    NOT NULL,
    AffectedRows             INT            NOT NULL,
    Explanation              VARCHAR(220)   NOT NULL
);

CREATE TABLE #RecoveryGuide
(
    GuideOrder               TINYINT        NOT NULL,
    Concern                  VARCHAR(100)   NOT NULL,
    WithoutSavepoint         VARCHAR(170)   NOT NULL,
    WithSavepointRecovery    VARCHAR(170)   NOT NULL,
    ReviewFocus              VARCHAR(220)   NOT NULL
);

-- 2. Demo-Einheiten vorbereiten
INSERT INTO #RecoveryUnits
(
    UnitID,
    PhaseGroup,
    UnitName,
    ProcessingState,
    LastAttempt,
    AfterSavepointChange,
    RecoveryDecision,
    Notes
)
VALUES
    (1, 'stable', 'Stage import manifest', 'pending', 0, 0, 'keep', 'Vorbereitender Schritt vor dem Savepoint.'),
    (2, 'stable', 'Validate source envelope', 'pending', 0, 0, 'keep', 'Guardrail, der vor dem riskanten Teil bestehen bleiben soll.'),
    (3, 'risky', 'Apply accounting postings', 'pending', 0, 0, 'rollback-if-needed', 'Kann bei fachlicher Inkonsistenz bis zum Savepoint zurueckgesetzt werden.'),
    (4, 'risky', 'Publish balance snapshot', 'pending', 0, 0, 'rollback-if-needed', 'Haengt direkt vom riskanten Abschnitt ab.'),
    (5, 'stable', 'Write recovery note', 'pending', 0, 0, 'commit-after-recovery', 'Soll nach Teilrollback und Wiederanlauf bewusst committed werden.');

INSERT INTO #RecoveryTimeline
(
    StepLabel,
    TranCountObserved,
    XactStateObserved,
    RecoveryAction,
    AffectedRows,
    Explanation
)
VALUES
    (
        'Prepare recovery lab',
        @@TRANCOUNT,
        XACT_STATE(),
        'none',
        5,
        'Die Demo-Einheiten werden ausserhalb einer Benutzertansaktion vorbereitet.'
    );

BEGIN TRANSACTION TranSavepointRecoveryLab;

INSERT INTO #RecoveryTimeline
(
    StepLabel,
    TranCountObserved,
    XactStateObserved,
    RecoveryAction,
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
        'Die uebergeordnete Demo-Transaktion umfasst stabile Vorbereitung, riskanten Abschnitt und Recovery-Pfad.'
    );

-- 3. Stabilen Vorlauf ausfuehren
UPDATE #RecoveryUnits
SET
    ProcessingState = 'prepared',
    LastAttempt = LastAttempt + 1,
    Notes = CASE UnitID
        WHEN 1 THEN 'Manifest wurde vor dem Savepoint vorbereitet und soll erhalten bleiben.'
        WHEN 2 THEN 'Vorabvalidierung wurde vor dem Savepoint bestaetigt.'
        ELSE Notes
    END
WHERE UnitID IN (1, 2);

INSERT INTO #RecoveryTimeline
(
    StepLabel,
    TranCountObserved,
    XactStateObserved,
    RecoveryAction,
    AffectedRows,
    Explanation
)
VALUES
    (
        'Stable preparation completed',
        @@TRANCOUNT,
        XACT_STATE(),
        'none',
        @@ROWCOUNT,
        'Diese Aenderungen liegen vor dem Savepoint und bleiben daher trotz spaeterem Teilrollback erhalten.'
    );

SAVE TRANSACTION RecoveryCheckpoint;

INSERT INTO #RecoveryTimeline
(
    StepLabel,
    TranCountObserved,
    XactStateObserved,
    RecoveryAction,
    AffectedRows,
    Explanation
)
VALUES
    (
        'Savepoint created',
        @@TRANCOUNT,
        XACT_STATE(),
        'save tran',
        0,
        'Der Savepoint markiert den Ruecksprungpunkt vor dem riskanten Verarbeitungsteil.'
    );

-- 4. Riskanten Abschnitt mit optionalem Recovery-Pfad ausfuehren
BEGIN TRY
    UPDATE #RecoveryUnits
    SET
        ProcessingState = CASE WHEN UnitID = 3 THEN 'posted' ELSE 'published' END,
        LastAttempt = LastAttempt + 1,
        AfterSavepointChange = 1,
        Notes = CASE UnitID
            WHEN 3 THEN 'Riskanter Buchungsschritt nach dem Savepoint ausgefuehrt.'
            WHEN 4 THEN 'Abgeleitete Sicht nach dem Savepoint erzeugt.'
            ELSE Notes
        END
    WHERE UnitID IN (3, 4);

    INSERT INTO #RecoveryTimeline
    (
        StepLabel,
        TranCountObserved,
        XactStateObserved,
        RecoveryAction,
        AffectedRows,
        Explanation
    )
    VALUES
        (
            'Risky section executed',
            @@TRANCOUNT,
            XACT_STATE(),
            'none',
            @@ROWCOUNT,
            'Die riskanten Demo-Aenderungen liegen hinter dem Savepoint und sind damit gezielt ruecksetzbar.'
        );

    IF @TriggerValidationFailure = 1
    BEGIN
        THROW 50010, 'Didaktische Validierung nach dem Savepoint fehlgeschlagen.', 1;
    END;

    INSERT INTO #RecoveryTimeline
    (
        StepLabel,
        TranCountObserved,
        XactStateObserved,
        RecoveryAction,
        AffectedRows,
        Explanation
    )
    VALUES
        (
            'Risky section accepted',
            @@TRANCOUNT,
            XACT_STATE(),
            'none',
            0,
            'Es trat kein Validierungsfehler auf; die riskanten Aenderungen koennen in der Transaktion verbleiben.'
        );
END TRY
BEGIN CATCH
    INSERT INTO #RecoveryTimeline
    (
        StepLabel,
        TranCountObserved,
        XactStateObserved,
        RecoveryAction,
        AffectedRows,
        Explanation
    )
    VALUES
        (
            'Validation failure caught',
            @@TRANCOUNT,
            XACT_STATE(),
            'catch',
            0,
            'Der didaktische Fehler wird abgefangen, damit Recovery bis zum Savepoint demonstriert werden kann.'
        );

    ROLLBACK TRANSACTION RecoveryCheckpoint;

    INSERT INTO #RecoveryTimeline
    (
        StepLabel,
        TranCountObserved,
        XactStateObserved,
        RecoveryAction,
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
            'Nur die Aenderungen hinter dem Savepoint werden verworfen; der stabile Vorlauf bleibt erhalten.'
        );

    IF @ReplayAfterRecovery = 1
    BEGIN
        UPDATE #RecoveryUnits
        SET
            ProcessingState = CASE WHEN UnitID = 3 THEN 'replayed-safe' ELSE 'deferred' END,
            LastAttempt = LastAttempt + 1,
            AfterSavepointChange = CASE WHEN UnitID = 3 THEN 1 ELSE 0 END,
            RecoveryDecision = CASE WHEN UnitID = 3 THEN 'replay-safe' ELSE 'defer' END,
            Notes = CASE UnitID
                WHEN 3 THEN 'Nach Teilrollback kontrolliert und mit reduziertem Umfang erneut ausgefuehrt.'
                WHEN 4 THEN 'Abhaengiger Schritt wird nach dem Rollback bewusst zurueckgestellt.'
                ELSE Notes
            END
        WHERE UnitID IN (3, 4);

        INSERT INTO #RecoveryTimeline
        (
            StepLabel,
            TranCountObserved,
            XactStateObserved,
            RecoveryAction,
            AffectedRows,
            Explanation
        )
        VALUES
            (
                'Controlled recovery replay',
                @@TRANCOUNT,
                XACT_STATE(),
                'replay',
                @@ROWCOUNT,
                'Nach dem Ruecksprung werden nur die fachlich vertretbaren Einheiten erneut angestossen.'
            );
    END;
    ELSE
    BEGIN
        UPDATE #RecoveryUnits
        SET
            ProcessingState = 'rolled-back',
            RecoveryDecision = 'manual-review',
            AfterSavepointChange = 0,
            Notes = CASE UnitID
                WHEN 3 THEN 'Nach Teilrollback nicht erneut ausgefuehrt; wartet auf Review.'
                WHEN 4 THEN 'Abhaengige Ausgabe bleibt nach Teilrollback verworfen.'
                ELSE Notes
            END
        WHERE UnitID IN (3, 4);

        INSERT INTO #RecoveryTimeline
        (
            StepLabel,
            TranCountObserved,
            XactStateObserved,
            RecoveryAction,
            AffectedRows,
            Explanation
        )
        VALUES
            (
                'Recovery deferred',
                @@TRANCOUNT,
                XACT_STATE(),
                'defer',
                @@ROWCOUNT,
                'Der Recovery-Pfad endet nach dem Teilrollback und uebergibt an einen manuellen Review-Schritt.'
            );
    END;
END CATCH;

-- 5. Stabilen Abschlussschritt bewusst committen
UPDATE #RecoveryUnits
SET
    ProcessingState = 'committed',
    LastAttempt = LastAttempt + 1,
    Notes = 'Abschlussschritt wurde nach Savepoint-Entscheidung und Recovery bewusst committed.'
WHERE UnitID = 5;

INSERT INTO #RecoveryTimeline
(
    StepLabel,
    TranCountObserved,
    XactStateObserved,
    RecoveryAction,
    AffectedRows,
    Explanation
)
VALUES
    (
        'Finalize stable closure',
        @@TRANCOUNT,
        XACT_STATE(),
        'none',
        @@ROWCOUNT,
        'Auch nach einem Teilrollback kann ein spaeterer stabiler Schritt innerhalb derselben Transaktion bestaetigt werden.'
    );

COMMIT TRANSACTION TranSavepointRecoveryLab;

INSERT INTO #RecoveryTimeline
(
    StepLabel,
    TranCountObserved,
    XactStateObserved,
    RecoveryAction,
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
        'Die verbleibenden Demo-Aenderungen werden am Ende des Skriptlaufs bestaetigt.'
    );

-- 6. Recovery-Leitfaden formulieren
INSERT INTO #RecoveryGuide
(
    GuideOrder,
    Concern,
    WithoutSavepoint,
    WithSavepointRecovery,
    ReviewFocus
)
VALUES
    (
        1,
        'Validation after partial work',
        'Ein Fehler fuehrt oft zum Vollrollback der gesamten Transaktion.',
        'Der Ruecksprungpunkt begrenzt den Schaden auf den riskanten Abschnitt.',
        'Savepoint nur setzen, wenn der Vorlauf fachlich bewusst erhalten bleiben darf.'
    ),
    (
        2,
        'Replay strategy',
        'Ohne Savepoint fehlt ein sauberer Einstieg fuer kontrollierten Wiederanlauf.',
        'Nach Teilrollback kann eine reduzierte oder sichere Ersatzverarbeitung gezielt neu gestartet werden.',
        'Definieren, welche Schritte nach Recovery erneut laufen duerfen und welche bewusst ausgesetzt bleiben.'
    ),
    (
        3,
        'Auditability',
        'Es bleibt unklar, welche Teilarbeit verworfen oder doch behalten wurde.',
        'Timeline und Savepoint machen den Ruecksprungpunkt fuer Reviews und Runbooks sichtbar.',
        'Savepoint-Name, Recovery-Entscheidung und Commit-Folgen klar protokollieren.'
    ),
    (
        4,
        'Commit decision',
        'Ein Vollrollback verhindert auch spaetere, weiterhin gueltige Abschlussschritte.',
        'Nach erfolgreicher Recovery kann der verbleibende stabile Abschluss trotzdem committed werden.',
        'Nur solche Folgeschritte committen, die nach dem Teilrollback fachlich weiterhin gueltig sind.'
    );

-- 7. Resultsets ausgeben
SELECT
    rt.TimelineStep,
    rt.StepLabel,
    rt.TranCountObserved,
    rt.XactStateObserved,
    rt.RecoveryAction,
    rt.AffectedRows,
    rt.Explanation
FROM #RecoveryTimeline AS rt
ORDER BY
    rt.TimelineStep;

SELECT
    ru.UnitID,
    ru.PhaseGroup,
    ru.UnitName,
    ru.ProcessingState,
    ru.LastAttempt,
    ru.AfterSavepointChange,
    ru.RecoveryDecision,
    ru.Notes
FROM #RecoveryUnits AS ru
ORDER BY
    ru.UnitID;

IF @ShowRecoveryGuide = 1
BEGIN
    SELECT
        rg.GuideOrder,
        rg.Concern,
        rg.WithoutSavepoint,
        rg.WithSavepointRecovery,
        rg.ReviewFocus
    FROM #RecoveryGuide AS rg
    ORDER BY
        rg.GuideOrder;
END;
