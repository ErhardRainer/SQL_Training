/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "ConstraintValidationQueue.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "16_DataIntegrity_Constraints"

purpose: >
  Modelliert in tempdb eine kleine Queue fuer nachgelagerte
  Constraint-Validierungen. Das Skript erzeugt Demo-Constraints mit
  unterschiedlichen Vertrauens- und Aktivierungszustaenden, schreibt daraus
  Queue-Eintraege und claimt den naechsten Arbeitsbatch fuer eine spaetere
  Revalidierung.

parameters:
  - name: "@WorkBatchSize"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Anzahl der Queue-Eintraege, die in diesem Lauf auf claimed gesetzt werden."
  - name: "@IncludeTrusted"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 fuegt auch bereits trusted Constraints mit niedriger Prioritaet in die Queue ein."
  - name: "@ResetDemoObjects"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 baut das Demo-Modell in tempdb vor der Analyse neu auf."
  - name: "@DropDemoObjects"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 entfernt die Demo-Objekte am Ende wieder aus tempdb."

result_sets:
  - name: "ConstraintQueueInventory"
    description: "Alle erzeugten Queue-Eintraege inklusive Prioritaet, Grund und vorgeschlagenem Validierungsbefehl."
  - name: "ClaimedValidationBatch"
    description: "Der fuer diesen Lauf reservierte Batch mit Worker, Claim-Zeitpunkt und Reihenfolge."
  - name: "ValidationRunbook"
    description: "Kompakte Runbook-Sicht mit den empfohlenen ALTER TABLE-Befehlen je geclaimtem Queue-Eintrag."
  - name: "QueueStatusSummary"
    description: "Verdichtung der Queue nach Status und Prioritaetsklasse."

dependencies:
  - "tempdb"
  - "sys.schemas"
  - "sys.tables"
  - "sys.check_constraints"
  - "sys.foreign_keys"
  - "ROW_NUMBER()"
  - "SYSUTCDATETIME()"
  - "QUOTENAME()"
  - "DROP TABLE IF EXISTS"

safety:
  level: "demo-write-tempdb"
  writes_data: true

documentation:
  markdown_file: "T-SQL/16_DataIntegrity_Constraints/SQLScripts/ConstraintValidationQueue.md"
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
    date: "2026-04-18"
    user: "ER"
    description: "Erstversion einer didaktischen Queue fuer nachgelagerte Constraint-Validierungen."

notes:
  - "Die Queue wird nur als Demo-Modell in tempdb aufgebaut und nicht persistent gespeichert."
  - "Die vorgeschlagenen Revalidierungsbefehle werden als Resultset ausgegeben, aber nicht automatisch ausgefuehrt."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @WorkBatchSize INT = 3;
DECLARE @IncludeTrusted BIT = 0;
DECLARE @ResetDemoObjects BIT = 1;
DECLARE @DropDemoObjects BIT = 1;
DECLARE @WorkerName SYSNAME = N'validation-worker-01';
DECLARE @ClaimedAt DATETIME2(0) = SYSUTCDATETIME();

IF @WorkBatchSize < 1
BEGIN
    THROW 50000, '@WorkBatchSize muss mindestens 1 sein.', 1;
END;

IF @IncludeTrusted NOT IN (0, 1)
BEGIN
    THROW 50001, '@IncludeTrusted muss 0 oder 1 sein.', 1;
END;

IF @ResetDemoObjects NOT IN (0, 1)
BEGIN
    THROW 50002, '@ResetDemoObjects muss 0 oder 1 sein.', 1;
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

IF @ResetDemoObjects = 1
BEGIN
    DROP TABLE IF EXISTS demo.ConstraintValidationChild;
    DROP TABLE IF EXISTS demo.ConstraintValidationParent;

    CREATE TABLE demo.ConstraintValidationParent
    (
        ParentID INT NOT NULL,
        ParentCode NVARCHAR(20) NOT NULL,
        ParentState NVARCHAR(20) NOT NULL,
        CONSTRAINT PK_ConstraintValidationParent PRIMARY KEY CLUSTERED (ParentID),
        CONSTRAINT UQ_ConstraintValidationParent_Code UNIQUE (ParentCode),
        CONSTRAINT CK_ConstraintValidationParent_State CHECK (ParentState IN (N'active', N'paused'))
    );

    CREATE TABLE demo.ConstraintValidationChild
    (
        ChildID INT NOT NULL,
        ParentID INT NOT NULL,
        ValidationQueueCode NVARCHAR(20) NOT NULL,
        QueueState NVARCHAR(20) NOT NULL,
        RetryCount TINYINT NOT NULL,
        LastValidatedAt DATETIME2(0) NULL,
        CONSTRAINT PK_ConstraintValidationChild PRIMARY KEY CLUSTERED (ChildID),
        CONSTRAINT FK_ConstraintValidationChild_Parent FOREIGN KEY (ParentID)
            REFERENCES demo.ConstraintValidationParent (ParentID),
        CONSTRAINT UQ_ConstraintValidationChild_Code UNIQUE (ValidationQueueCode),
        CONSTRAINT CK_ConstraintValidationChild_QueueState CHECK (QueueState IN (N'queued', N'running', N'done', N'error')),
        CONSTRAINT CK_ConstraintValidationChild_RetryCount CHECK (RetryCount BETWEEN 0 AND 5)
    );

    INSERT INTO demo.ConstraintValidationParent
    (
        ParentID,
        ParentCode,
        ParentState
    )
    VALUES
        (1, N'P-100', N'active'),
        (2, N'P-200', N'paused'),
        (3, N'P-300', N'active');

    INSERT INTO demo.ConstraintValidationChild
    (
        ChildID,
        ParentID,
        ValidationQueueCode,
        QueueState,
        RetryCount,
        LastValidatedAt
    )
    VALUES
        (101, 1, N'VQ-101', N'done', 0, DATEADD(DAY, -2, SYSUTCDATETIME())),
        (102, 1, N'VQ-102', N'queued', 1, DATEADD(HOUR, -20, SYSUTCDATETIME())),
        (103, 2, N'VQ-103', N'error', 2, DATEADD(HOUR, -10, SYSUTCDATETIME())),
        (104, 3, N'VQ-104', N'running', 0, DATEADD(HOUR, -1, SYSUTCDATETIME()));

    ALTER TABLE demo.ConstraintValidationChild NOCHECK CONSTRAINT FK_ConstraintValidationChild_Parent;

    ALTER TABLE demo.ConstraintValidationChild NOCHECK CONSTRAINT CK_ConstraintValidationChild_RetryCount;
    ALTER TABLE demo.ConstraintValidationChild CHECK CONSTRAINT CK_ConstraintValidationChild_RetryCount;
END;

DROP TABLE IF EXISTS #ConstraintInventory;
WITH ConstraintInventory AS
(
    SELECT
        s.name AS SchemaName,
        t.name AS TableName,
        cc.name AS ConstraintName,
        CAST(N'CHECK' AS NVARCHAR(20)) AS ConstraintType,
        cc.is_disabled AS IsDisabled,
        cc.is_not_trusted AS IsNotTrusted
    FROM sys.check_constraints AS cc
    INNER JOIN sys.tables AS t
        ON t.object_id = cc.parent_object_id
    INNER JOIN sys.schemas AS s
        ON s.schema_id = t.schema_id
    WHERE t.object_id IN
    (
        OBJECT_ID(N'demo.ConstraintValidationParent', N'U'),
        OBJECT_ID(N'demo.ConstraintValidationChild', N'U')
    )

    UNION ALL

    SELECT
        s.name AS SchemaName,
        t.name AS TableName,
        fk.name AS ConstraintName,
        CAST(N'FOREIGN KEY' AS NVARCHAR(20)) AS ConstraintType,
        fk.is_disabled AS IsDisabled,
        fk.is_not_trusted AS IsNotTrusted
    FROM sys.foreign_keys AS fk
    INNER JOIN sys.tables AS t
        ON t.object_id = fk.parent_object_id
    INNER JOIN sys.schemas AS s
        ON s.schema_id = t.schema_id
    WHERE t.object_id IN
    (
        OBJECT_ID(N'demo.ConstraintValidationParent', N'U'),
        OBJECT_ID(N'demo.ConstraintValidationChild', N'U')
    )
)
SELECT
    ci.SchemaName,
    ci.TableName,
    ci.ConstraintName,
    ci.ConstraintType,
    ci.IsDisabled,
    ci.IsNotTrusted,
    CASE
        WHEN ci.IsDisabled = 1 THEN 300
        WHEN ci.IsNotTrusted = 1 THEN 200
        ELSE 50
    END AS QueuePriority,
    CASE
        WHEN ci.IsDisabled = 1 THEN N'disabled_constraint'
        WHEN ci.IsNotTrusted = 1 THEN N'enabled_not_trusted'
        ELSE N'trusted_review'
    END AS ValidationReason,
    CASE
        WHEN ci.IsDisabled = 1 THEN N'high'
        WHEN ci.IsNotTrusted = 1 THEN N'medium'
        ELSE N'low'
    END AS PriorityBucket,
    CAST
    (
        N'ALTER TABLE '
        + QUOTENAME(ci.SchemaName)
        + N'.'
        + QUOTENAME(ci.TableName)
        + N' WITH CHECK CHECK CONSTRAINT '
        + QUOTENAME(ci.ConstraintName)
        + N';'
        AS NVARCHAR(4000)
    ) AS SuggestedCommand
INTO #ConstraintInventory
FROM ConstraintInventory AS ci
WHERE @IncludeTrusted = 1
   OR ci.IsDisabled = 1
   OR ci.IsNotTrusted = 1;

DROP TABLE IF EXISTS #ValidationQueue;
CREATE TABLE #ValidationQueue
(
    QueueID INT IDENTITY(1, 1) NOT NULL PRIMARY KEY,
    ConstraintName SYSNAME NOT NULL,
    ConstraintType NVARCHAR(20) NOT NULL,
    SchemaName SYSNAME NOT NULL,
    TableName SYSNAME NOT NULL,
    QueuePriority INT NOT NULL,
    PriorityBucket NVARCHAR(20) NOT NULL,
    ValidationReason NVARCHAR(40) NOT NULL,
    QueueStatus NVARCHAR(20) NOT NULL,
    SuggestedCommand NVARCHAR(4000) NOT NULL,
    ClaimedBy SYSNAME NULL,
    ClaimedAt DATETIME2(0) NULL
);

INSERT INTO #ValidationQueue
(
    ConstraintName,
    ConstraintType,
    SchemaName,
    TableName,
    QueuePriority,
    PriorityBucket,
    ValidationReason,
    QueueStatus,
    SuggestedCommand,
    ClaimedBy,
    ClaimedAt
)
SELECT
    ci.ConstraintName,
    ci.ConstraintType,
    ci.SchemaName,
    ci.TableName,
    ci.QueuePriority,
    ci.PriorityBucket,
    ci.ValidationReason,
    CAST(N'pending' AS NVARCHAR(20)) AS QueueStatus,
    ci.SuggestedCommand,
    CAST(NULL AS SYSNAME) AS ClaimedBy,
    CAST(NULL AS DATETIME2(0)) AS ClaimedAt
FROM #ConstraintInventory AS ci;

WITH QueueCandidates AS
(
    SELECT
        q.QueueID,
        ROW_NUMBER() OVER
        (
            ORDER BY
                q.QueuePriority DESC,
                q.SchemaName ASC,
                q.TableName ASC,
                q.ConstraintName ASC
        ) AS QueueOrder
    FROM #ValidationQueue AS q
    WHERE q.QueueStatus = N'pending'
)
UPDATE q
SET
    q.QueueStatus = N'claimed',
    q.ClaimedBy = @WorkerName,
    q.ClaimedAt = @ClaimedAt
FROM #ValidationQueue AS q
INNER JOIN QueueCandidates AS qc
    ON qc.QueueID = q.QueueID
WHERE qc.QueueOrder <= @WorkBatchSize;

SELECT
    q.QueueID,
    q.ConstraintName,
    q.ConstraintType,
    q.SchemaName,
    q.TableName,
    q.QueuePriority,
    q.PriorityBucket,
    q.ValidationReason,
    q.QueueStatus,
    q.SuggestedCommand,
    q.ClaimedBy,
    q.ClaimedAt
FROM #ValidationQueue AS q
ORDER BY
    q.QueuePriority DESC,
    q.SchemaName ASC,
    q.TableName ASC,
    q.ConstraintName ASC;

SELECT
    q.QueueID,
    q.ConstraintName,
    q.ConstraintType,
    q.SchemaName,
    q.TableName,
    q.QueuePriority,
    q.ValidationReason,
    q.ClaimedBy,
    q.ClaimedAt
FROM #ValidationQueue AS q
WHERE q.QueueStatus = N'claimed'
ORDER BY
    q.QueuePriority DESC,
    q.SchemaName ASC,
    q.TableName ASC,
    q.ConstraintName ASC;

SELECT
    q.QueueID,
    q.ConstraintName,
    q.PriorityBucket,
    q.ValidationReason,
    q.SuggestedCommand,
    CASE
        WHEN q.PriorityBucket = N'high' THEN N'Vor dem naechsten Load-Fenster pruefen.'
        WHEN q.PriorityBucket = N'medium' THEN N'Im naechsten Wartungsfenster mit Vollpruefung revalidieren.'
        ELSE N'Nur fuer turnusmaessige Reviews einplanen.'
    END AS RunbookNote
FROM #ValidationQueue AS q
WHERE q.QueueStatus = N'claimed'
ORDER BY
    q.QueuePriority DESC,
    q.ConstraintName ASC;

SELECT
    q.QueueStatus,
    q.PriorityBucket,
    COUNT(*) AS QueueItemCount
FROM #ValidationQueue AS q
GROUP BY
    q.QueueStatus,
    q.PriorityBucket
ORDER BY
    CASE q.QueueStatus
        WHEN N'claimed' THEN 1
        ELSE 2
    END,
    CASE q.PriorityBucket
        WHEN N'high' THEN 1
        WHEN N'medium' THEN 2
        ELSE 3
    END;

IF @DropDemoObjects = 1
BEGIN
    DROP TABLE IF EXISTS demo.ConstraintValidationChild;
    DROP TABLE IF EXISTS demo.ConstraintValidationParent;
END;
