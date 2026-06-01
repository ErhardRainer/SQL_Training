/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "UpsertInsertNotExists.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "07_Insert"

purpose: >
  Demonstriert in tempdb ein robustes Insert-Muster mit NOT EXISTS als
  Alternative zu MERGE. Der Ablauf dedupliziert einen Eingangsbatch,
  prueft vorhandene Zielschluessel und fuegt nur noch neue Zeilen unter
  kontrollierten Sperren in die Zieltabelle ein.

parameters:
  - name: "@ApplyInsert"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = fuehrt den NOT-EXISTS-Insert aus, 0 = zeigt nur die Kandidatenbewertung"
  - name: "@UseSerializableKeyProtection"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = verwendet UPDLOCK und HOLDLOCK in der NOT-EXISTS-Pruefung"
  - name: "@DropDemoObjects"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = entfernt die Demo-Zieltabelle am Ende wieder aus tempdb"

result_sets:
  - name: "CandidateAssessment"
    description: "Bewertet Batch-Zeilen als vorhandenen Schluessel, Batch-Dublette oder Insert-Kandidat"
  - name: "InsertAudit"
    description: "Zeigt die tatsaechlich eingefuegten Zeilen des NOT-EXISTS-Musters"
  - name: "CurrentTargetRows"
    description: "Zeigt den Zielzustand nach der optionalen Insert-Phase"
  - name: "InsertDecisionSummary"
    description: "Verdichtet Kandidaten und tatsaechlich eingefuegte Zeilen fuer das Review"

dependencies:
  - "tempdb"
  - "sys.schemas"
  - "common table expressions"
  - "ROW_NUMBER"
  - "NOT EXISTS"
  - "UPDLOCK"
  - "HOLDLOCK"
  - "OUTPUT clause"

safety:
  level: "demo-write-tempdb"
  writes_data: true

documentation:
  markdown_file: "T-SQL/07_Insert/SQLScripts/UpsertInsertNotExists.md"
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
    description: "Erstversion des didaktischen NOT-EXISTS-Upsert-Musters fuer Insert-Strecken"

notes:
  - "Die Demo fuehrt ausschliesslich Inserts aus und aktualisiert keine bestehenden Zielzeilen"
  - "Die Lock-Hints dienen der didaktischen Einordnung eines robusten Patterns und ersetzen kein vollstaendiges Lasttest-Design"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @ApplyInsert BIT = 1;
DECLARE @UseSerializableKeyProtection BIT = 1;
DECLARE @DropDemoObjects BIT = 1;

IF @ApplyInsert NOT IN (0, 1)
BEGIN
    THROW 50080, '@ApplyInsert muss 0 oder 1 sein.', 1;
END;

IF @UseSerializableKeyProtection NOT IN (0, 1)
BEGIN
    THROW 50081, '@UseSerializableKeyProtection muss 0 oder 1 sein.', 1;
END;

IF @DropDemoObjects NOT IN (0, 1)
BEGIN
    THROW 50082, '@DropDemoObjects muss 0 oder 1 sein.', 1;
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

DROP TABLE IF EXISTS demo.UpsertInsertNotExistsTarget;
DROP TABLE IF EXISTS #IncomingBatch;
DROP TABLE IF EXISTS #CandidateAssessment;
DROP TABLE IF EXISTS #InsertAudit;

CREATE TABLE demo.UpsertInsertNotExistsTarget
(
    EnrollmentID        INT IDENTITY(1, 1) NOT NULL PRIMARY KEY,
    LearnerCode         VARCHAR(20)        NOT NULL,
    CourseCode          VARCHAR(20)        NOT NULL,
    TermCode            VARCHAR(20)        NOT NULL,
    DeliveryMode        VARCHAR(20)        NOT NULL,
    SourcePriority      TINYINT            NOT NULL,
    LastSourceLabel     VARCHAR(30)        NOT NULL,
    InsertedAtUtc       DATETIME2(0)       NOT NULL CONSTRAINT DF_UpsertInsertNotExistsTarget_InsertedAtUtc DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT UQ_UpsertInsertNotExistsTarget UNIQUE (LearnerCode, CourseCode, TermCode)
);

CREATE TABLE #IncomingBatch
(
    BatchRowID          INT IDENTITY(1, 1) NOT NULL PRIMARY KEY,
    LearnerCode         VARCHAR(20)        NOT NULL,
    CourseCode          VARCHAR(20)        NOT NULL,
    TermCode            VARCHAR(20)        NOT NULL,
    DeliveryMode        VARCHAR(20)        NOT NULL,
    SourcePriority      TINYINT            NOT NULL,
    SourceLabel         VARCHAR(30)        NOT NULL,
    PayloadNote         VARCHAR(180)       NOT NULL
);

CREATE TABLE #CandidateAssessment
(
    BatchRowID              INT           NOT NULL PRIMARY KEY,
    LearnerCode             VARCHAR(20)   NOT NULL,
    CourseCode              VARCHAR(20)   NOT NULL,
    TermCode                VARCHAR(20)   NOT NULL,
    DeliveryMode            VARCHAR(20)   NOT NULL,
    SourcePriority          TINYINT       NOT NULL,
    SourceLabel             VARCHAR(30)   NOT NULL,
    BatchRank               INT           NOT NULL,
    DecisionLabel           VARCHAR(40)   NOT NULL,
    DecisionReason          VARCHAR(220)  NOT NULL,
    ExistingEnrollmentID    INT           NULL,
    WasInserted             BIT           NOT NULL CONSTRAINT DF_CandidateAssessment_WasInserted DEFAULT ((0))
);

CREATE TABLE #InsertAudit
(
    AuditID                 INT           NOT NULL IDENTITY(1, 1) PRIMARY KEY,
    EnrollmentID            INT           NOT NULL,
    LearnerCode             VARCHAR(20)   NOT NULL,
    CourseCode              VARCHAR(20)   NOT NULL,
    TermCode                VARCHAR(20)   NOT NULL,
    DeliveryMode            VARCHAR(20)   NOT NULL,
    SourcePriority          TINYINT       NOT NULL,
    SourceLabel             VARCHAR(30)   NOT NULL,
    InsertedAtUtc           DATETIME2(0)  NOT NULL
);

INSERT INTO demo.UpsertInsertNotExistsTarget
(
    LearnerCode,
    CourseCode,
    TermCode,
    DeliveryMode,
    SourcePriority,
    LastSourceLabel
)
VALUES
    ('LRN-001', 'SQL-101', '2026-Q2', 'onsite', 2, 'seed_target'),
    ('LRN-004', 'SQL-401', '2026-Q2', 'remote', 1, 'seed_target');

INSERT INTO #IncomingBatch
(
    LearnerCode,
    CourseCode,
    TermCode,
    DeliveryMode,
    SourcePriority,
    SourceLabel,
    PayloadNote
)
VALUES
    ('LRN-001', 'SQL-101', '2026-Q2', 'onsite', 3, 'crm_refresh', 'Bereits vorhandene Einschreibung im Ziel.'),
    ('LRN-002', 'SQL-201', '2026-Q2', 'remote', 3, 'crm_refresh', 'Neue Einschreibung aus dem CRM.'),
    ('LRN-002', 'SQL-201', '2026-Q2', 'hybrid', 1, 'erp_override', 'Doppelte Batch-Zeile mit hoeherer Prioritaet.'),
    ('LRN-003', 'SQL-301', '2026-Q2', 'onsite', 2, 'web_portal', 'Neue Einschreibung ohne Konflikt.'),
    ('LRN-004', 'SQL-401', '2026-Q2', 'remote', 1, 'erp_override', 'Bereits vorhandener Schluessel im Ziel.'),
    ('LRN-005', 'SQL-501', '2026-Q2', 'hybrid', 2, 'partner_feed', 'Neue Einschreibung aus einer dritten Quelle.');

;WITH RankedBatch AS
(
    SELECT
        ib.BatchRowID,
        ib.LearnerCode,
        ib.CourseCode,
        ib.TermCode,
        ib.DeliveryMode,
        ib.SourcePriority,
        ib.SourceLabel,
        ROW_NUMBER() OVER
        (
            PARTITION BY ib.LearnerCode, ib.CourseCode, ib.TermCode
            ORDER BY
                ib.SourcePriority ASC,
                ib.BatchRowID ASC
        ) AS BatchRank
    FROM #IncomingBatch AS ib
)
INSERT INTO #CandidateAssessment
(
    BatchRowID,
    LearnerCode,
    CourseCode,
    TermCode,
    DeliveryMode,
    SourcePriority,
    SourceLabel,
    BatchRank,
    DecisionLabel,
    DecisionReason,
    ExistingEnrollmentID
)
SELECT
    rb.BatchRowID,
    rb.LearnerCode,
    rb.CourseCode,
    rb.TermCode,
    rb.DeliveryMode,
    rb.SourcePriority,
    rb.SourceLabel,
    rb.BatchRank,
    CASE
        WHEN tgt.EnrollmentID IS NOT NULL THEN 'exists_in_target'
        WHEN rb.BatchRank > 1 THEN 'duplicate_in_batch'
        ELSE 'insert_candidate'
    END AS DecisionLabel,
    CASE
        WHEN tgt.EnrollmentID IS NOT NULL
            THEN 'LearnerCode + CourseCode + TermCode existiert bereits in der Zieltabelle.'
        WHEN rb.BatchRank > 1
            THEN 'Mehrere Batch-Zeilen teilen denselben Schluessel; nur Rang 1 bleibt als Kandidat erhalten.'
        ELSE 'Kein Zieltreffer und beste Batch-Variante; Zeile bleibt fuer NOT EXISTS erhalten.'
    END AS DecisionReason,
    tgt.EnrollmentID
FROM RankedBatch AS rb
LEFT JOIN demo.UpsertInsertNotExistsTarget AS tgt
    ON tgt.LearnerCode = rb.LearnerCode
   AND tgt.CourseCode = rb.CourseCode
   AND tgt.TermCode = rb.TermCode;

IF @ApplyInsert = 1
BEGIN
    BEGIN TRANSACTION;

    IF @UseSerializableKeyProtection = 1
    BEGIN
        INSERT INTO demo.UpsertInsertNotExistsTarget
        (
            LearnerCode,
            CourseCode,
            TermCode,
            DeliveryMode,
            SourcePriority,
            LastSourceLabel
        )
        OUTPUT
            inserted.EnrollmentID,
            inserted.LearnerCode,
            inserted.CourseCode,
            inserted.TermCode,
            inserted.DeliveryMode,
            inserted.SourcePriority,
            inserted.LastSourceLabel,
            inserted.InsertedAtUtc
        INTO #InsertAudit
        (
            EnrollmentID,
            LearnerCode,
            CourseCode,
            TermCode,
            DeliveryMode,
            SourcePriority,
            SourceLabel,
            InsertedAtUtc
        )
        SELECT
            ca.LearnerCode,
            ca.CourseCode,
            ca.TermCode,
            ca.DeliveryMode,
            ca.SourcePriority,
            ca.SourceLabel
        FROM #CandidateAssessment AS ca
        WHERE ca.DecisionLabel = 'insert_candidate'
          AND NOT EXISTS
          (
              SELECT 1
              FROM demo.UpsertInsertNotExistsTarget AS tgt WITH (UPDLOCK, HOLDLOCK)
              WHERE tgt.LearnerCode = ca.LearnerCode
                AND tgt.CourseCode = ca.CourseCode
                AND tgt.TermCode = ca.TermCode
          );
    END;
    ELSE
    BEGIN
        INSERT INTO demo.UpsertInsertNotExistsTarget
        (
            LearnerCode,
            CourseCode,
            TermCode,
            DeliveryMode,
            SourcePriority,
            LastSourceLabel
        )
        OUTPUT
            inserted.EnrollmentID,
            inserted.LearnerCode,
            inserted.CourseCode,
            inserted.TermCode,
            inserted.DeliveryMode,
            inserted.SourcePriority,
            inserted.LastSourceLabel,
            inserted.InsertedAtUtc
        INTO #InsertAudit
        (
            EnrollmentID,
            LearnerCode,
            CourseCode,
            TermCode,
            DeliveryMode,
            SourcePriority,
            SourceLabel,
            InsertedAtUtc
        )
        SELECT
            ca.LearnerCode,
            ca.CourseCode,
            ca.TermCode,
            ca.DeliveryMode,
            ca.SourcePriority,
            ca.SourceLabel
        FROM #CandidateAssessment AS ca
        WHERE ca.DecisionLabel = 'insert_candidate'
          AND NOT EXISTS
          (
              SELECT 1
              FROM demo.UpsertInsertNotExistsTarget AS tgt
              WHERE tgt.LearnerCode = ca.LearnerCode
                AND tgt.CourseCode = ca.CourseCode
                AND tgt.TermCode = ca.TermCode
          );
    END;

    UPDATE ca
    SET ca.WasInserted = 1
    FROM #CandidateAssessment AS ca
    WHERE EXISTS
    (
        SELECT 1
        FROM #InsertAudit AS ia
        WHERE ia.LearnerCode = ca.LearnerCode
          AND ia.CourseCode = ca.CourseCode
          AND ia.TermCode = ca.TermCode
          AND ia.SourceLabel = ca.SourceLabel
    );

    COMMIT TRANSACTION;
END;

SELECT
    ca.BatchRowID,
    ca.LearnerCode,
    ca.CourseCode,
    ca.TermCode,
    ca.DeliveryMode,
    ca.SourcePriority,
    ca.SourceLabel,
    ca.BatchRank,
    ca.DecisionLabel,
    ca.DecisionReason,
    ca.ExistingEnrollmentID,
    ca.WasInserted
FROM #CandidateAssessment AS ca
ORDER BY
    ca.BatchRowID;

SELECT
    ia.EnrollmentID,
    ia.LearnerCode,
    ia.CourseCode,
    ia.TermCode,
    ia.DeliveryMode,
    ia.SourcePriority,
    ia.SourceLabel,
    ia.InsertedAtUtc
FROM #InsertAudit AS ia
ORDER BY
    ia.AuditID;

SELECT
    tgt.EnrollmentID,
    tgt.LearnerCode,
    tgt.CourseCode,
    tgt.TermCode,
    tgt.DeliveryMode,
    tgt.SourcePriority,
    tgt.LastSourceLabel,
    tgt.InsertedAtUtc
FROM demo.UpsertInsertNotExistsTarget AS tgt
ORDER BY
    tgt.EnrollmentID;

SELECT
    ca.DecisionLabel,
    COUNT(*) AS CandidateCount,
    SUM(CASE WHEN ca.WasInserted = 1 THEN 1 ELSE 0 END) AS InsertedCount
FROM #CandidateAssessment AS ca
GROUP BY
    ca.DecisionLabel
ORDER BY
    ca.DecisionLabel;

IF @DropDemoObjects = 1
BEGIN
    DROP TABLE IF EXISTS demo.UpsertInsertNotExistsTarget;
END;
