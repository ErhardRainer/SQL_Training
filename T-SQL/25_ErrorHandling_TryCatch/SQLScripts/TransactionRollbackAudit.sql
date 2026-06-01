/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "TransactionRollbackAudit.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "25_ErrorHandling_TryCatch"

purpose: >
  Zeigt fuer erfolgreiche und fehlerhafte Transaktionspfade, welche
  Aenderungen und Audit-Spuren nach COMMIT oder ROLLBACK sichtbar bleiben
  und welche Fehlerdetails erst nach dem Rollback sicher protokolliert
  werden koennen.

parameters:
  - name: "@ScenarioFilter"
    sql_type: "VARCHAR(30)"
    direction: "IN"
    required: false
    description: "Waehlt success, duplicate-key, validation-stop oder all"

result_sets:
  - name: "TransactionAuditLog"
    description: "Zeigt pro Szenario Baseline, Commit- oder Rollback-Audit mit Fehler- und Sichtbarkeitsdaten"
  - name: "ScenarioSummary"
    description: "Verdichtet je Szenario, ob Daten und transaktionsinterne Audit-Spuren erhalten blieben"

dependencies:
  - "tempdb temporary tables"
  - "TRY...CATCH"
  - "THROW"
  - "XACT_STATE"
  - "primary key constraint"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/25_ErrorHandling_TryCatch/SQLScripts/TransactionRollbackAudit.md"
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
    date: "2026-04-17"
    user: "ER"
    description: "Erstversion fuer ein Lab zu Rollback-Pfaden und Post-Mortem-Audit"

notes:
  - "Das Lab arbeitet ausschliesslich mit tempdb-Objekten und simuliert Audit-Eintraege innerhalb und ausserhalb der Transaktion."
  - "Fehlerszenarien zeigen bewusst, dass transaktionsinterne Audit-Spuren mitgerollt werden und ein belastbares Audit oft erst nach dem ROLLBACK entsteht."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @ScenarioFilter VARCHAR(30) = 'all';

IF @ScenarioFilter NOT IN ('all', 'success', 'duplicate-key', 'validation-stop')
BEGIN
    THROW 51100, '@ScenarioFilter ist ungueltig.', 1;
END;

DROP TABLE IF EXISTS #ScenarioCatalog;
DROP TABLE IF EXISTS #WorkQueue;
DROP TABLE IF EXISTS #TxnAuditScratch;
DROP TABLE IF EXISTS #AuditTrail;

CREATE TABLE #ScenarioCatalog
(
    ScenarioName VARCHAR(30) NOT NULL PRIMARY KEY,
    ScenarioSort INT NOT NULL,
    CandidateWorkItemId INT NOT NULL,
    PlannedErrorKind VARCHAR(30) NOT NULL,
    ScenarioNote NVARCHAR(200) NOT NULL
);

CREATE TABLE #WorkQueue
(
    WorkItemId INT NOT NULL PRIMARY KEY,
    WorkLabel VARCHAR(80) NOT NULL,
    ProcessingState VARCHAR(20) NOT NULL
);

CREATE TABLE #TxnAuditScratch
(
    AuditId INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    ScenarioName VARCHAR(30) NOT NULL,
    AuditPhase VARCHAR(30) NOT NULL,
    AuditMessage NVARCHAR(200) NOT NULL
);

CREATE TABLE #AuditTrail
(
    AuditLogId INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    ScenarioName VARCHAR(30) NOT NULL,
    AuditStage VARCHAR(30) NOT NULL,
    OutcomeClass VARCHAR(40) NOT NULL,
    ErrorNumber INT NULL,
    ErrorSeverity INT NULL,
    ErrorState INT NULL,
    XactStateAtCatch INT NULL,
    TranCountAtCatch INT NULL,
    CandidateWorkItemId INT NOT NULL,
    WorkQueueCountVisible INT NOT NULL,
    TxnAuditRowsVisible INT NOT NULL,
    MessageText NVARCHAR(4000) NOT NULL
);

INSERT INTO #ScenarioCatalog
(
    ScenarioName,
    ScenarioSort,
    CandidateWorkItemId,
    PlannedErrorKind,
    ScenarioNote
)
VALUES
    ('success', 1, 2001, 'none', N'Fuehrt einen regulaeren Commit mit sichtbarer Demo-Auditspur aus.'),
    ('duplicate-key', 2, 1001, 'duplicate-key', N'Loest ueber einen vorhandenen Schluessel einen technischen Fehler aus.'),
    ('validation-stop', 3, 3001, 'validation-stop', N'Loest nach einer fachlichen Vorpruefung bewusst THROW aus.');

INSERT INTO #WorkQueue (WorkItemId, WorkLabel, ProcessingState)
VALUES
    (1001, 'Existing duplicate candidate', 'seeded'),
    (1002, 'Existing safe baseline', 'seeded');

DECLARE
    @CurrentScenario VARCHAR(30),
    @CandidateWorkItemId INT,
    @PlannedErrorKind VARCHAR(30),
    @ScenarioNote NVARCHAR(200),
    @ErrorNumber INT,
    @ErrorSeverity INT,
    @ErrorState INT,
    @XactStateAtCatch INT,
    @TranCountAtCatch INT,
    @VisibleWorkQueueCount INT,
    @VisibleTxnAuditRows INT;

DECLARE scenario_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT
    sc.ScenarioName,
    sc.CandidateWorkItemId,
    sc.PlannedErrorKind,
    sc.ScenarioNote
FROM #ScenarioCatalog AS sc
WHERE @ScenarioFilter = 'all'
   OR sc.ScenarioName = @ScenarioFilter
ORDER BY
    sc.ScenarioSort;

OPEN scenario_cursor;

FETCH NEXT FROM scenario_cursor INTO @CurrentScenario, @CandidateWorkItemId, @PlannedErrorKind, @ScenarioNote;

WHILE @@FETCH_STATUS = 0
BEGIN
    INSERT INTO #AuditTrail
    (
        ScenarioName,
        AuditStage,
        OutcomeClass,
        ErrorNumber,
        ErrorSeverity,
        ErrorState,
        XactStateAtCatch,
        TranCountAtCatch,
        CandidateWorkItemId,
        WorkQueueCountVisible,
        TxnAuditRowsVisible,
        MessageText
    )
    VALUES
    (
        @CurrentScenario,
        'baseline',
        'before-transaction',
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        @CandidateWorkItemId,
        (SELECT COUNT(*) FROM #WorkQueue),
        (SELECT COUNT(*) FROM #TxnAuditScratch WHERE ScenarioName = @CurrentScenario),
        N'Vor dem Start der Transaktion sind nur die Seed-Daten sichtbar. ' + @ScenarioNote
    );

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO #TxnAuditScratch (ScenarioName, AuditPhase, AuditMessage)
        VALUES
        (
            @CurrentScenario,
            'before-change',
            N'Transaktionsinterner Audit-Eintrag vor der fachlichen Aenderung.'
        );

        IF @PlannedErrorKind = 'duplicate-key'
        BEGIN
            INSERT INTO #WorkQueue (WorkItemId, WorkLabel, ProcessingState)
            VALUES
            (
                @CandidateWorkItemId,
                'Duplicate key demo row',
                'staged'
            );
        END
        ELSE
        BEGIN
            INSERT INTO #WorkQueue (WorkItemId, WorkLabel, ProcessingState)
            VALUES
            (
                @CandidateWorkItemId,
                CONCAT('Scenario ', @CurrentScenario),
                'staged'
            );
        END;

        INSERT INTO #TxnAuditScratch (ScenarioName, AuditPhase, AuditMessage)
        VALUES
        (
            @CurrentScenario,
            'after-change',
            N'Transaktionsinterner Audit-Eintrag nach der fachlichen Aenderung.'
        );

        IF @PlannedErrorKind = 'validation-stop'
        BEGIN
            THROW 51110, N'Fachliche Validierung verlangt einen Rollback vor dem Commit.', 1;
        END;

        COMMIT TRANSACTION;

        INSERT INTO #AuditTrail
        (
            ScenarioName,
            AuditStage,
            OutcomeClass,
            ErrorNumber,
            ErrorSeverity,
            ErrorState,
            XactStateAtCatch,
            TranCountAtCatch,
            CandidateWorkItemId,
            WorkQueueCountVisible,
            TxnAuditRowsVisible,
            MessageText
        )
        VALUES
        (
            @CurrentScenario,
            'after-commit',
            'committed',
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            @CandidateWorkItemId,
            (SELECT COUNT(*) FROM #WorkQueue),
            (SELECT COUNT(*) FROM #TxnAuditScratch WHERE ScenarioName = @CurrentScenario),
            N'Commit erfolgreich; sowohl die Datenzeile als auch die transaktionsinterne Auditspur bleiben sichtbar.'
        );
    END TRY
    BEGIN CATCH
        SELECT
            @ErrorNumber = ERROR_NUMBER(),
            @ErrorSeverity = ERROR_SEVERITY(),
            @ErrorState = ERROR_STATE(),
            @XactStateAtCatch = XACT_STATE(),
            @TranCountAtCatch = @@TRANCOUNT;

        IF XACT_STATE() <> 0
        BEGIN
            ROLLBACK TRANSACTION;
        END;

        SELECT
            @VisibleWorkQueueCount = COUNT(*)
        FROM #WorkQueue;

        SELECT
            @VisibleTxnAuditRows = COUNT(*)
        FROM #TxnAuditScratch
        WHERE ScenarioName = @CurrentScenario;

        INSERT INTO #AuditTrail
        (
            ScenarioName,
            AuditStage,
            OutcomeClass,
            ErrorNumber,
            ErrorSeverity,
            ErrorState,
            XactStateAtCatch,
            TranCountAtCatch,
            CandidateWorkItemId,
            WorkQueueCountVisible,
            TxnAuditRowsVisible,
            MessageText
        )
        VALUES
        (
            @CurrentScenario,
            'after-rollback',
            CASE @PlannedErrorKind
                WHEN 'duplicate-key' THEN 'rolled-back-constraint'
                ELSE 'rolled-back-validation'
            END,
            @ErrorNumber,
            @ErrorSeverity,
            @ErrorState,
            @XactStateAtCatch,
            @TranCountAtCatch,
            @CandidateWorkItemId,
            @VisibleWorkQueueCount,
            @VisibleTxnAuditRows,
            N'Nach dem Rollback wird das Audit ausserhalb der Transaktion geschrieben; die transaktionsinterne Auditspur ist nicht mehr sichtbar.'
        );
    END CATCH;

    FETCH NEXT FROM scenario_cursor INTO @CurrentScenario, @CandidateWorkItemId, @PlannedErrorKind, @ScenarioNote;
END;

CLOSE scenario_cursor;
DEALLOCATE scenario_cursor;

SELECT
    at.AuditLogId,
    at.ScenarioName,
    at.AuditStage,
    at.OutcomeClass,
    at.ErrorNumber,
    at.ErrorSeverity,
    at.ErrorState,
    at.XactStateAtCatch,
    at.TranCountAtCatch,
    at.CandidateWorkItemId,
    at.WorkQueueCountVisible,
    at.TxnAuditRowsVisible,
    at.MessageText
FROM #AuditTrail AS at
ORDER BY
    CASE at.ScenarioName
        WHEN 'success' THEN 1
        WHEN 'duplicate-key' THEN 2
        ELSE 3
    END,
    CASE at.AuditStage
        WHEN 'baseline' THEN 1
        WHEN 'after-commit' THEN 2
        ELSE 3
    END,
    at.AuditLogId;

WITH ScenarioSummary AS
(
    SELECT
        sc.ScenarioName,
        sc.PlannedErrorKind,
        sc.CandidateWorkItemId,
        MAX(CASE WHEN at.AuditStage = 'after-commit' THEN 1 ELSE 0 END) AS WasCommitted,
        MAX(CASE WHEN at.AuditStage = 'after-rollback' THEN 1 ELSE 0 END) AS WasRolledBack,
        MAX(CASE WHEN at.AuditStage = 'after-rollback' THEN at.ErrorNumber END) AS ErrorNumber,
        MAX(CASE WHEN at.AuditStage = 'after-rollback' THEN at.XactStateAtCatch END) AS XactStateAtCatch,
        MAX(CASE WHEN at.AuditStage IN ('after-commit', 'after-rollback') THEN at.TxnAuditRowsVisible END) AS FinalTxnAuditRowsVisible
    FROM #ScenarioCatalog AS sc
    LEFT JOIN #AuditTrail AS at
        ON at.ScenarioName = sc.ScenarioName
    WHERE @ScenarioFilter = 'all'
       OR sc.ScenarioName = @ScenarioFilter
    GROUP BY
        sc.ScenarioName,
        sc.PlannedErrorKind,
        sc.CandidateWorkItemId
)
SELECT
    ss.ScenarioName,
    ss.PlannedErrorKind,
    CAST(ss.WasCommitted AS BIT) AS WasCommitted,
    CAST(ss.WasRolledBack AS BIT) AS WasRolledBack,
    CAST(CASE WHEN wq.WorkItemId IS NOT NULL THEN 1 ELSE 0 END AS BIT) AS CandidateRowVisibleAfterRun,
    CAST(CASE WHEN ISNULL(ss.FinalTxnAuditRowsVisible, 0) > 0 THEN 1 ELSE 0 END AS BIT) AS TxnAuditStillVisible,
    ss.ErrorNumber,
    ss.XactStateAtCatch,
    CASE
        WHEN ss.WasCommitted = 1 THEN 'Commit behaelt Daten- und Auditspur.'
        WHEN ss.PlannedErrorKind = 'duplicate-key' THEN 'Constraint-Fehler erzwingt Rollback; Post-Mortem-Audit bleibt ausserhalb der Transaktion sichtbar.'
        ELSE 'Fachliche Validierung fuehrt zum Rollback; nur das Audit nach dem Rollback bleibt bestehen.'
    END AS TeachingNote
FROM ScenarioSummary AS ss
LEFT JOIN #WorkQueue AS wq
    ON wq.WorkItemId = ss.CandidateWorkItemId
ORDER BY
    CASE ss.ScenarioName
        WHEN 'success' THEN 1
        WHEN 'duplicate-key' THEN 2
        ELSE 3
    END;
