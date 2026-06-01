/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "UpdateConcurrencyRetryLab.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "08_Update"

purpose: >
  Demonstriert in tempdb ein Retry-Muster fuer konkurrierende Updates,
  indem rowversion-basierte Konflikte kontrolliert simuliert und pro
  Versuch protokolliert werden.

parameters:
  - name: "@MaxRetries"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Maximale Anzahl Retry-Versuche pro Work Item"
  - name: "@ApplyUpdate"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = Retry-Lauf mit Updates, 0 = nur Kandidaten und Konfliktplan anzeigen"
  - name: "@ResetDemoData"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = Demo-Daten vor dem Lauf neu aufbauen"
  - name: "@DropDemoObjects"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = Demo-Objekte am Ende wieder aus tempdb entfernen"

result_sets:
  - name: "RetryCandidates"
    description: "Arbeitsvorrat mit geplantem Konfliktbudget und Zielstatus"
  - name: "RetryAttemptLog"
    description: "Pro Versuch protokollierte Konflikte, Commits und Abbrueche"
  - name: "FinalTargetState"
    description: "Endzustand der Demo-Zieltabelle nach dem Retry-Lauf"
  - name: "RetrySummary"
    description: "Zusammenfassung zu Erfolgen, Konflikten und ausgeschopften Retries"

dependencies:
  - "tempdb"
  - "sys.schemas"
  - "rowversion"
  - "WHILE"
  - "TRY...CATCH"
  - "BEGIN TRANSACTION"
  - "COMMIT TRANSACTION"
  - "ROLLBACK TRANSACTION"
  - "@@ROWCOUNT"
  - "SYSUTCDATETIME()"

safety:
  level: "demo-write-tempdb"
  writes_data: true

documentation:
  markdown_file: "T-SQL/08_Update/SQLScripts/UpdateConcurrencyRetryLab.md"
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
    description: "Erstversion eines didaktischen Retry-Labors fuer konkurrierende Updates"

notes:
  - "Die Erstversion simuliert konkurrierende Writes kontrolliert innerhalb derselben Session"
  - "Konflikte werden ueber rowversion und ein verbleibendes Konfliktbudget sichtbar gemacht"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @MaxRetries INT = 3;
DECLARE @ApplyUpdate BIT = 1;
DECLARE @ResetDemoData BIT = 1;
DECLARE @DropDemoObjects BIT = 1;
DECLARE @RunStamp DATETIME2(0) = SYSUTCDATETIME();

IF @MaxRetries IS NULL OR @MaxRetries < 1
BEGIN
    THROW 50000, '@MaxRetries muss mindestens 1 sein.', 1;
END;

IF @ApplyUpdate NOT IN (0, 1)
BEGIN
    THROW 50001, '@ApplyUpdate muss 0 oder 1 sein.', 1;
END;

IF @ResetDemoData NOT IN (0, 1)
BEGIN
    THROW 50002, '@ResetDemoData muss 0 oder 1 sein.', 1;
END;

IF @DropDemoObjects NOT IN (0, 1)
BEGIN
    THROW 50003, '@DropDemoObjects muss 0 oder 1 sein.', 1;
END;

USE tempdb;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.schemas
    WHERE name = N'demo'
)
BEGIN
    EXEC(N'CREATE SCHEMA demo AUTHORIZATION dbo;');
END;

IF OBJECT_ID(N'demo.UpdateRetryTarget', N'U') IS NULL
BEGIN
    CREATE TABLE demo.UpdateRetryTarget
    (
        WorkItemID          INT             NOT NULL PRIMARY KEY,
        CustomerCode        NVARCHAR(20)    NOT NULL,
        CurrentStatus       NVARCHAR(20)    NOT NULL,
        RetryAttempts       INT             NOT NULL,
        LastTouchedAt       DATETIME2(0)    NULL,
        LastTouchedBy       NVARCHAR(40)    NULL,
        StatusNote          NVARCHAR(120)   NOT NULL,
        RowVersionToken     ROWVERSION      NOT NULL
    );
END;

IF OBJECT_ID(N'demo.UpdateRetryPlan', N'U') IS NULL
BEGIN
    CREATE TABLE demo.UpdateRetryPlan
    (
        WorkItemID              INT             NOT NULL PRIMARY KEY,
        TargetStatus            NVARCHAR(20)    NOT NULL,
        TargetNote              NVARCHAR(120)   NOT NULL,
        SimulatedConflictBudget INT             NOT NULL,
        ScenarioLabel           NVARCHAR(40)    NOT NULL
    );
END;

IF @ResetDemoData = 1
BEGIN
    TRUNCATE TABLE demo.UpdateRetryPlan;
    TRUNCATE TABLE demo.UpdateRetryTarget;

    INSERT INTO demo.UpdateRetryTarget
    (
        WorkItemID,
        CustomerCode,
        CurrentStatus,
        RetryAttempts,
        LastTouchedAt,
        LastTouchedBy,
        StatusNote
    )
    VALUES
        (301, N'CUST-ALPHA', N'queued', 0, DATEADD(MINUTE, -45, @RunStamp), N'seed', N'awaiting first retry'),
        (302, N'CUST-BRAVO', N'queued', 0, DATEADD(MINUTE, -35, @RunStamp), N'seed', N'expected one transient conflict'),
        (303, N'CUST-CHARLIE', N'hold', 0, DATEADD(MINUTE, -25, @RunStamp), N'seed', N'expected two transient conflicts'),
        (304, N'CUST-DELTA', N'queued', 0, DATEADD(MINUTE, -15, @RunStamp), N'seed', N'conflict budget exceeds retry budget');

    INSERT INTO demo.UpdateRetryPlan
    (
        WorkItemID,
        TargetStatus,
        TargetNote,
        SimulatedConflictBudget,
        ScenarioLabel
    )
    VALUES
        (301, N'ready', N'no conflict path', 0, N'no_conflict'),
        (302, N'ready', N'conflict resolved on second attempt', 1, N'one_retry'),
        (303, N'escalated', N'conflict resolved on third attempt', 2, N'two_retries'),
        (304, N'escalated', N'conflicts stay longer than retry budget', 4, N'exhausted');
END;

DROP TABLE IF EXISTS #RetryCandidates;
CREATE TABLE #RetryCandidates
(
    WorkItemID               INT             NOT NULL PRIMARY KEY,
    CustomerCode             NVARCHAR(20)    NOT NULL,
    CurrentStatus            NVARCHAR(20)    NOT NULL,
    TargetStatus             NVARCHAR(20)    NOT NULL,
    PlannedConflictBudget    INT             NOT NULL,
    ScenarioLabel            NVARCHAR(40)    NOT NULL,
    CurrentRetryAttempts     INT             NOT NULL
);

DROP TABLE IF EXISTS #RetryAttemptLog;
CREATE TABLE #RetryAttemptLog
(
    WorkItemID               INT             NOT NULL,
    AttemptNo                INT             NOT NULL,
    EventType                NVARCHAR(20)    NOT NULL,
    ExpectedConflictBudget   INT             NOT NULL,
    RemainingConflictBudget  INT             NOT NULL,
    MessageText              NVARCHAR(200)   NOT NULL,
    LoggedAtUtc              DATETIME2(0)    NOT NULL
);

INSERT INTO #RetryCandidates
(
    WorkItemID,
    CustomerCode,
    CurrentStatus,
    TargetStatus,
    PlannedConflictBudget,
    ScenarioLabel,
    CurrentRetryAttempts
)
SELECT
    tgt.WorkItemID,
    tgt.CustomerCode,
    tgt.CurrentStatus,
    plan.TargetStatus,
    plan.SimulatedConflictBudget,
    plan.ScenarioLabel,
    tgt.RetryAttempts
FROM demo.UpdateRetryTarget AS tgt
INNER JOIN demo.UpdateRetryPlan AS plan
    ON plan.WorkItemID = tgt.WorkItemID;

IF @ApplyUpdate = 1
BEGIN
    DECLARE @WorkItemID INT;
    DECLARE @AttemptNo INT;
    DECLARE @ExpectedRowVersion VARBINARY(8);
    DECLARE @RemainingBudget INT;
    DECLARE @TargetStatus NVARCHAR(20);
    DECLARE @TargetNote NVARCHAR(120);
    DECLARE @ScenarioLabel NVARCHAR(40);

    DECLARE retry_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            cand.WorkItemID
        FROM #RetryCandidates AS cand
        ORDER BY
            cand.WorkItemID;

    OPEN retry_cursor;

    FETCH NEXT FROM retry_cursor INTO @WorkItemID;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @AttemptNo = 0;

        WHILE @AttemptNo < @MaxRetries
        BEGIN
            SET @AttemptNo += 1;

            SELECT
                @ExpectedRowVersion = tgt.RowVersionToken,
                @RemainingBudget = plan.SimulatedConflictBudget,
                @TargetStatus = plan.TargetStatus,
                @TargetNote = plan.TargetNote,
                @ScenarioLabel = plan.ScenarioLabel
            FROM demo.UpdateRetryTarget AS tgt
            INNER JOIN demo.UpdateRetryPlan AS plan
                ON plan.WorkItemID = tgt.WorkItemID
            WHERE tgt.WorkItemID = @WorkItemID;

            IF @RemainingBudget > 0
            BEGIN
                UPDATE plan
                SET plan.SimulatedConflictBudget = plan.SimulatedConflictBudget - 1
                FROM demo.UpdateRetryPlan AS plan
                WHERE plan.WorkItemID = @WorkItemID;

                UPDATE tgt
                SET tgt.LastTouchedAt = DATEADD(SECOND, @AttemptNo, @RunStamp),
                    tgt.LastTouchedBy = N'conflict-simulator',
                    tgt.StatusNote = CONCAT(N'simulated concurrent touch before attempt ', @AttemptNo)
                FROM demo.UpdateRetryTarget AS tgt
                WHERE tgt.WorkItemID = @WorkItemID;
            END;

            BEGIN TRY
                BEGIN TRANSACTION;

                UPDATE tgt
                SET tgt.CurrentStatus = @TargetStatus,
                    tgt.RetryAttempts = @AttemptNo,
                    tgt.LastTouchedAt = @RunStamp,
                    tgt.LastTouchedBy = N'retry-worker',
                    tgt.StatusNote = @TargetNote
                FROM demo.UpdateRetryTarget AS tgt
                WHERE tgt.WorkItemID = @WorkItemID
                  AND tgt.RowVersionToken = @ExpectedRowVersion;

                IF @@ROWCOUNT = 0
                BEGIN
                    ROLLBACK TRANSACTION;

                    INSERT INTO #RetryAttemptLog
                    (
                        WorkItemID,
                        AttemptNo,
                        EventType,
                        ExpectedConflictBudget,
                        RemainingConflictBudget,
                        MessageText,
                        LoggedAtUtc
                    )
                    SELECT
                        @WorkItemID,
                        @AttemptNo,
                        N'conflict',
                        @RemainingBudget,
                        plan.SimulatedConflictBudget,
                        CONCAT(N'Rowversion-Konflikt in Szenario ', @ScenarioLabel, N'. Retry erforderlich.'),
                        SYSUTCDATETIME()
                    FROM demo.UpdateRetryPlan AS plan
                    WHERE plan.WorkItemID = @WorkItemID;

                    IF @AttemptNo = @MaxRetries
                    BEGIN
                        INSERT INTO #RetryAttemptLog
                        (
                            WorkItemID,
                            AttemptNo,
                            EventType,
                            ExpectedConflictBudget,
                            RemainingConflictBudget,
                            MessageText,
                            LoggedAtUtc
                        )
                        SELECT
                            @WorkItemID,
                            @AttemptNo,
                            N'give_up',
                            @RemainingBudget,
                            plan.SimulatedConflictBudget,
                            N'Maximale Retry-Anzahl erreicht; Work Item bleibt im Zwischenzustand.',
                            SYSUTCDATETIME()
                        FROM demo.UpdateRetryPlan AS plan
                        WHERE plan.WorkItemID = @WorkItemID;
                    END;
                END;
                ELSE
                BEGIN
                    COMMIT TRANSACTION;

                    INSERT INTO #RetryAttemptLog
                    (
                        WorkItemID,
                        AttemptNo,
                        EventType,
                        ExpectedConflictBudget,
                        RemainingConflictBudget,
                        MessageText,
                        LoggedAtUtc
                    )
                    SELECT
                        @WorkItemID,
                        @AttemptNo,
                        N'committed',
                        @RemainingBudget,
                        plan.SimulatedConflictBudget,
                        CONCAT(N'Update erfolgreich nach ', @AttemptNo, N' Versuch(en).'),
                        SYSUTCDATETIME()
                    FROM demo.UpdateRetryPlan AS plan
                    WHERE plan.WorkItemID = @WorkItemID;

                    BREAK;
                END;
            END TRY
            BEGIN CATCH
                IF XACT_STATE() <> 0
                BEGIN
                    ROLLBACK TRANSACTION;
                END;

                INSERT INTO #RetryAttemptLog
                (
                    WorkItemID,
                    AttemptNo,
                    EventType,
                    ExpectedConflictBudget,
                    RemainingConflictBudget,
                    MessageText,
                    LoggedAtUtc
                )
                SELECT
                    @WorkItemID,
                    @AttemptNo,
                    N'error',
                    @RemainingBudget,
                    plan.SimulatedConflictBudget,
                    ERROR_MESSAGE(),
                    SYSUTCDATETIME()
                FROM demo.UpdateRetryPlan AS plan
                WHERE plan.WorkItemID = @WorkItemID;

                THROW;
            END CATCH;
        END;

        FETCH NEXT FROM retry_cursor INTO @WorkItemID;
    END;

    CLOSE retry_cursor;
    DEALLOCATE retry_cursor;
END;

SELECT
    cand.WorkItemID,
    cand.CustomerCode,
    cand.CurrentStatus,
    cand.TargetStatus,
    cand.PlannedConflictBudget,
    cand.ScenarioLabel,
    cand.CurrentRetryAttempts
FROM #RetryCandidates AS cand
ORDER BY
    cand.WorkItemID;

SELECT
    log_entry.WorkItemID,
    log_entry.AttemptNo,
    log_entry.EventType,
    log_entry.ExpectedConflictBudget,
    log_entry.RemainingConflictBudget,
    log_entry.MessageText,
    log_entry.LoggedAtUtc
FROM #RetryAttemptLog AS log_entry
ORDER BY
    log_entry.WorkItemID,
    log_entry.AttemptNo,
    log_entry.LoggedAtUtc;

SELECT
    tgt.WorkItemID,
    tgt.CustomerCode,
    tgt.CurrentStatus,
    tgt.RetryAttempts,
    tgt.LastTouchedAt,
    tgt.LastTouchedBy,
    tgt.StatusNote
FROM demo.UpdateRetryTarget AS tgt
ORDER BY
    tgt.WorkItemID;

SELECT
    COUNT(*) AS ReviewedItems,
    SUM(CASE WHEN tgt.CurrentStatus = plan.TargetStatus THEN 1 ELSE 0 END) AS SuccessfulItems,
    SUM(CASE WHEN tgt.CurrentStatus <> plan.TargetStatus THEN 1 ELSE 0 END) AS UnresolvedItems,
    SUM(CASE WHEN log_entry.EventType = N'conflict' THEN 1 ELSE 0 END) AS ConflictEvents,
    MAX(tgt.RetryAttempts) AS HighestCommittedRetryCount,
    CASE
        WHEN @ApplyUpdate = 1
            THEN N'Konflikte wurden simuliert und ueber Retry-Loops ausgewertet.'
        ELSE N'Preview-Lauf ohne Retry-Ausfuehrung.'
    END AS ExecutionMode
FROM demo.UpdateRetryTarget AS tgt
INNER JOIN demo.UpdateRetryPlan AS plan
    ON plan.WorkItemID = tgt.WorkItemID
LEFT JOIN #RetryAttemptLog AS log_entry
    ON log_entry.WorkItemID = tgt.WorkItemID;

IF @DropDemoObjects = 1
BEGIN
    DROP TABLE IF EXISTS demo.UpdateRetryPlan;
    DROP TABLE IF EXISTS demo.UpdateRetryTarget;
END;
