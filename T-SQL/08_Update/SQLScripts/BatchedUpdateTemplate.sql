/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "BatchedUpdateTemplate.sql"
script_version: "1.0"
script_type: "template"
chapter: "08_Update"

purpose: >
  Zeigt in tempdb ein kontrolliertes Batch-Update-Muster mit klaren
  Transaktionsgrenzen, Audit-Ausgabe pro Batch und optionalem Dry-Run
  fuer groessere Update-Strecken.

parameters:
  - name: "@BatchSize"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Maximale Anzahl Zeilen, die pro Batch aktualisiert werden"
  - name: "@MaxBatches"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Obergrenze fuer die Anzahl auszufuehrender Batches"
  - name: "@DryRun"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = Batch-Updates nur simulieren und jede Batch-Transaktion wieder zurueckrollen"
  - name: "@ResetDemoData"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = Demo-Tabellen vor dem Lauf neu aufbauen und frisch befuellen"
  - name: "@DropDemoObjects"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = Demo-Objekte am Ende wieder aus tempdb entfernen"

result_sets:
  - name: "BatchExecutionLog"
    description: "Audit pro Batch mit Transaktionsentscheidung, Zeilenzahl und Restmenge"
  - name: "FinalWorkQueue"
    description: "Finaler Zustand der Demo-Zeilen nach dem Batchlauf"
  - name: "TemplateChecklist"
    description: "Checkliste fuer die Uebernahme des Musters in produktionsnahe Updates"

dependencies:
  - "tempdb"
  - "sys.schemas"
  - "sys.all_objects"
  - "ROW_NUMBER()"
  - "SYSUTCDATETIME()"
  - "WHILE"
  - "BEGIN TRANSACTION"
  - "COMMIT TRANSACTION"
  - "ROLLBACK TRANSACTION"

safety:
  level: "demo-write-tempdb"
  writes_data: true

documentation:
  markdown_file: "T-SQL/08_Update/SQLScripts/BatchedUpdateTemplate.md"
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
    description: "Erstversion eines didaktischen Batch-Update-Templates mit Transaktionsgrenzen"

notes:
  - "Alle Demo-Objekte werden ausschliesslich in tempdb angelegt"
  - "Das Muster kombiniert TOP-N-Selektion, Batch-Audit und optionalen Dry-Run"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @BatchSize INT = 4;
DECLARE @MaxBatches INT = 3;
DECLARE @DryRun BIT = 0;
DECLARE @ResetDemoData BIT = 1;
DECLARE @DropDemoObjects BIT = 1;

IF @BatchSize IS NULL OR @BatchSize < 1
BEGIN
    THROW 50000, '@BatchSize muss mindestens 1 sein.', 1;
END;

IF @MaxBatches IS NULL OR @MaxBatches < 1
BEGIN
    THROW 50001, '@MaxBatches muss mindestens 1 sein.', 1;
END;

IF @DryRun NOT IN (0, 1)
BEGIN
    THROW 50002, '@DryRun muss 0 oder 1 sein.', 1;
END;

IF @ResetDemoData NOT IN (0, 1)
BEGIN
    THROW 50003, '@ResetDemoData muss 0 oder 1 sein.', 1;
END;

IF @DropDemoObjects NOT IN (0, 1)
BEGIN
    THROW 50004, '@DropDemoObjects muss 0 oder 1 sein.', 1;
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

IF OBJECT_ID(N'demo.BatchUpdateQueue', N'U') IS NULL
BEGIN
    CREATE TABLE demo.BatchUpdateQueue
    (
        WorkItemID          INT             NOT NULL PRIMARY KEY,
        CustomerSegment     NVARCHAR(30)    NOT NULL,
        CurrentCreditLimit  DECIMAL(10,2)   NOT NULL,
        TargetCreditLimit   DECIMAL(10,2)   NOT NULL,
        NeedsUpdate         BIT             NOT NULL,
        BatchStatus         NVARCHAR(20)    NOT NULL,
        LastTouchedAt       DATETIME2(0)    NULL,
        LastBatchNumber     INT             NULL
    );
END;

IF OBJECT_ID(N'demo.BatchUpdateAudit', N'U') IS NULL
BEGIN
    CREATE TABLE demo.BatchUpdateAudit
    (
        AuditID             INT             NOT NULL IDENTITY(1,1) PRIMARY KEY,
        BatchNumber         INT             NOT NULL,
        WorkItemID          INT             NOT NULL,
        PreviousCreditLimit DECIMAL(10,2)   NOT NULL,
        NewCreditLimit      DECIMAL(10,2)   NOT NULL,
        DecisionLabel       NVARCHAR(20)    NOT NULL,
        RecordedAt          DATETIME2(0)    NOT NULL
            CONSTRAINT DF_BatchUpdateAudit_RecordedAt DEFAULT SYSUTCDATETIME()
    );
END;

IF @ResetDemoData = 1
BEGIN
    TRUNCATE TABLE demo.BatchUpdateAudit;
    TRUNCATE TABLE demo.BatchUpdateQueue;

    ;WITH SeedData AS
    (
        SELECT TOP (12)
            ROW_NUMBER() OVER (ORDER BY object_id) AS WorkItemID
        FROM sys.all_objects
    )
    INSERT INTO demo.BatchUpdateQueue
    (
        WorkItemID,
        CustomerSegment,
        CurrentCreditLimit,
        TargetCreditLimit,
        NeedsUpdate,
        BatchStatus,
        LastTouchedAt,
        LastBatchNumber
    )
    SELECT
        sd.WorkItemID,
        CASE
            WHEN sd.WorkItemID % 3 = 1 THEN N'Standard'
            WHEN sd.WorkItemID % 3 = 2 THEN N'Growth'
            ELSE N'Enterprise'
        END AS CustomerSegment,
        CAST(1000 + (sd.WorkItemID * 125) AS DECIMAL(10,2)) AS CurrentCreditLimit,
        CAST
        (
            CASE
                WHEN sd.WorkItemID IN (2, 5, 8, 11) THEN 1000 + (sd.WorkItemID * 125)
                ELSE 1150 + (sd.WorkItemID * 140)
            END
            AS DECIMAL(10,2)
        ) AS TargetCreditLimit,
        CAST
        (
            CASE
                WHEN sd.WorkItemID IN (2, 5, 8, 11) THEN 0
                ELSE 1
            END
            AS BIT
        ) AS NeedsUpdate,
        CASE
            WHEN sd.WorkItemID IN (2, 5, 8, 11) THEN N'already_current'
            ELSE N'queued'
        END AS BatchStatus,
        NULL AS LastTouchedAt,
        NULL AS LastBatchNumber
    FROM SeedData AS sd;
END;

DROP TABLE IF EXISTS #BatchLog;
CREATE TABLE #BatchLog
(
    BatchNumber      INT            NOT NULL,
    CandidateRows    INT            NOT NULL,
    UpdatedRows      INT            NOT NULL,
    DecisionLabel    NVARCHAR(20)   NOT NULL,
    RemainingRows    INT            NOT NULL,
    TransactionNote  NVARCHAR(200)  NOT NULL
);

DECLARE @BatchNumber INT = 0;
DECLARE @RowsInBatch INT = 0;
DECLARE @RemainingRows INT = 0;
DECLARE @DecisionLabel NVARCHAR(20);

SELECT
    @RemainingRows = COUNT(*)
FROM demo.BatchUpdateQueue AS queue_item
WHERE queue_item.NeedsUpdate = 1;

WHILE @RemainingRows > 0
  AND @BatchNumber < @MaxBatches
BEGIN
    SET @BatchNumber += 1;

    DECLARE @CurrentBatch TABLE
    (
        WorkItemID INT NOT NULL PRIMARY KEY
    );

    INSERT INTO @CurrentBatch
    (
        WorkItemID
    )
    SELECT TOP (@BatchSize)
        queue_item.WorkItemID
    FROM demo.BatchUpdateQueue AS queue_item
    WHERE queue_item.NeedsUpdate = 1
    ORDER BY
        queue_item.WorkItemID;

    SELECT
        @RowsInBatch = COUNT(*)
    FROM @CurrentBatch;

    IF @RowsInBatch = 0
    BEGIN
        BREAK;
    END;

    BEGIN TRANSACTION;

    UPDATE queue_item
    SET queue_item.CurrentCreditLimit = queue_item.TargetCreditLimit,
        queue_item.NeedsUpdate = 0,
        queue_item.BatchStatus = N'updated',
        queue_item.LastTouchedAt = SYSUTCDATETIME(),
        queue_item.LastBatchNumber = @BatchNumber
    OUTPUT
        @BatchNumber,
        inserted.WorkItemID,
        deleted.CurrentCreditLimit,
        inserted.CurrentCreditLimit,
        CASE WHEN @DryRun = 1 THEN N'rolled_back' ELSE N'committed' END,
        SYSUTCDATETIME()
    INTO demo.BatchUpdateAudit
    (
        BatchNumber,
        WorkItemID,
        PreviousCreditLimit,
        NewCreditLimit,
        DecisionLabel,
        RecordedAt
    )
    FROM demo.BatchUpdateQueue AS queue_item
    INNER JOIN @CurrentBatch AS batch_item
        ON queue_item.WorkItemID = batch_item.WorkItemID;

    SET @RowsInBatch = @@ROWCOUNT;
    SET @DecisionLabel = CASE WHEN @DryRun = 1 THEN N'rolled_back' ELSE N'committed' END;

    IF @DryRun = 1
    BEGIN
        ROLLBACK TRANSACTION;
    END;
    ELSE
    BEGIN
        COMMIT TRANSACTION;
    END;

    SELECT
        @RemainingRows = COUNT(*)
    FROM demo.BatchUpdateQueue AS queue_item
    WHERE queue_item.NeedsUpdate = 1;

    INSERT INTO #BatchLog
    (
        BatchNumber,
        CandidateRows,
        UpdatedRows,
        DecisionLabel,
        RemainingRows,
        TransactionNote
    )
    VALUES
    (
        @BatchNumber,
        @RowsInBatch,
        @RowsInBatch,
        @DecisionLabel,
        @RemainingRows,
        CASE
            WHEN @DryRun = 1
                THEN N'Batch wurde simuliert und anschliessend zurueckgerollt.'
            ELSE N'Batch wurde erfolgreich committet.'
        END
    );

    IF @DryRun = 1
    BEGIN
        BREAK;
    END;
END;

IF @BatchNumber >= @MaxBatches AND @RemainingRows > 0
BEGIN
    INSERT INTO #BatchLog
    (
        BatchNumber,
        CandidateRows,
        UpdatedRows,
        DecisionLabel,
        RemainingRows,
        TransactionNote
    )
    VALUES
    (
        @BatchNumber,
        0,
        0,
        N'stopped',
        @RemainingRows,
        N'Maximale Batch-Anzahl erreicht. Restmenge bleibt fuer einen Folgelauf stehen.'
    );
END;

SELECT
    log_entry.BatchNumber,
    log_entry.CandidateRows,
    log_entry.UpdatedRows,
    log_entry.DecisionLabel,
    log_entry.RemainingRows,
    log_entry.TransactionNote
FROM #BatchLog AS log_entry
ORDER BY
    log_entry.BatchNumber;

SELECT
    queue_item.WorkItemID,
    queue_item.CustomerSegment,
    queue_item.CurrentCreditLimit,
    queue_item.TargetCreditLimit,
    queue_item.NeedsUpdate,
    queue_item.BatchStatus,
    queue_item.LastTouchedAt,
    queue_item.LastBatchNumber
FROM demo.BatchUpdateQueue AS queue_item
ORDER BY
    queue_item.WorkItemID;

SELECT
    ChecklistOrder,
    ChecklistItem,
    WhyItMatters
FROM
(
    VALUES
        (1, N'Deterministische Batch-Selektion verwenden', N'TOP ohne stabile Sortierung kann Zeilen zwischen Laeufen verschieben.'),
        (2, N'Pro Batch eine klare Transaktionsgrenze setzen', N'Kleine Commits reduzieren Blocking und vereinfachen Wiederanlauf-Strategien.'),
        (3, N'Restmenge und Batch-Audit protokollieren', N'Fortschritt und Wiederaufsetzbarkeit werden dadurch nachvollziehbar.'),
        (4, N'Dry-Run fuer Rollback-Tests vorsehen', N'Das Muster laesst sich vor produktiven Aenderungen sicher pruefbar machen.'),
        (5, N'Produktiv Tabellen nur mit fachlicher WHERE-Klausel anbinden', N'Das Template zeigt bewusst nur tempdb-Demoobjekte statt produktiver Datenquellen.')
) AS checklist(ChecklistOrder, ChecklistItem, WhyItMatters)
ORDER BY
    ChecklistOrder;

IF @DropDemoObjects = 1
BEGIN
    DROP TABLE IF EXISTS demo.BatchUpdateAudit;
    DROP TABLE IF EXISTS demo.BatchUpdateQueue;
END;
