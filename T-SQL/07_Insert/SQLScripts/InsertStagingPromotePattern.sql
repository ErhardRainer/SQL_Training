/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "InsertStagingPromotePattern.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "07_Insert"

purpose: >
  Zeigt an einer tempdb-basierten Stage-to-target-Demo, wie gepruefte
  Staging-Zeilen gefiltert, mit Ablehnungsgruenden versehen und anschliessend
  kontrolliert per INSERT in das Zielschema promotet werden.

parameters:
  - name: "@BatchLabel"
    sql_type: "VARCHAR(20)"
    direction: "IN"
    required: false
    description: "Begrenzt die Promotion auf eine Stage-Charge innerhalb der Demo"
  - name: "@PromoteOnlyValidated"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = promotet nur Zeilen ohne Ablehnungsgrund; 0 = zeigt nur die Vorpruefung"
  - name: "@DropDemoObjects"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = entfernt die Demo-Objekte am Ende wieder aus tempdb"

result_sets:
  - name: "StageValidationReview"
    description: "Zeigt pro Stage-Zeile den Promotionsstatus und den Ablehnungsgrund"
  - name: "PromotionAudit"
    description: "Protokolliert die erfolgreich promoteten Zeilen mit Stage- und Zielschluesseln"
  - name: "CurrentTargetRows"
    description: "Zeigt den Zielzustand nach dem Promote-Lauf"

dependencies:
  - "tempdb"
  - "sys.schemas"
  - "SYSUTCDATETIME"
  - "ROW_NUMBER"
  - "OUTPUT clause"

safety:
  level: "demo-write-tempdb"
  writes_data: true

documentation:
  markdown_file: "T-SQL/07_Insert/SQLScripts/InsertStagingPromotePattern.md"
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
    description: "Erstversion des didaktischen Stage-to-target-Promote-Musters"

notes:
  - "Die Demo verwendet nur Objekte in tempdb und keine produktiven Tabellen"
  - "Bereits vorhandene Zielkombinationen werden vor dem Insert als Duplikate markiert"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @BatchLabel VARCHAR(20) = 'batch-2026-04';
DECLARE @PromoteOnlyValidated BIT = 1;
DECLARE @DropDemoObjects BIT = 1;

IF NULLIF(LTRIM(RTRIM(@BatchLabel)), '') IS NULL
BEGIN
    THROW 50060, '@BatchLabel darf nicht leer sein.', 1;
END;

IF @PromoteOnlyValidated NOT IN (0, 1)
BEGIN
    THROW 50061, '@PromoteOnlyValidated muss 0 oder 1 sein.', 1;
END;

IF @DropDemoObjects NOT IN (0, 1)
BEGIN
    THROW 50062, '@DropDemoObjects muss 0 oder 1 sein.', 1;
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

DROP TABLE IF EXISTS demo.InsertStagePromotionAudit;
DROP TABLE IF EXISTS demo.InsertStagePromotionTarget;
DROP TABLE IF EXISTS demo.InsertStagePromotionStage;
DROP TABLE IF EXISTS #StageReview;

CREATE TABLE demo.InsertStagePromotionTarget
(
    EnrollmentID    INT IDENTITY(5000, 1) NOT NULL PRIMARY KEY,
    LearnerCode     VARCHAR(20)           NOT NULL,
    CourseCode      VARCHAR(20)           NOT NULL,
    DeliveryMonth   DATE                  NOT NULL,
    SeatCount       TINYINT               NOT NULL,
    SourceBatchLabel VARCHAR(20)          NOT NULL,
    PromotedAtUtc   DATETIME2(0)          NOT NULL CONSTRAINT DF_InsertStagePromotionTarget_PromotedAtUtc DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_InsertStagePromotionTarget UNIQUE (LearnerCode, CourseCode, DeliveryMonth)
);

CREATE TABLE demo.InsertStagePromotionStage
(
    StageRowID          INT IDENTITY(1, 1) NOT NULL PRIMARY KEY,
    BatchLabel          VARCHAR(20)        NOT NULL,
    LearnerCode         VARCHAR(20)        NOT NULL,
    CourseCode          VARCHAR(20)        NOT NULL,
    DeliveryMonth       DATE               NULL,
    SeatCount           TINYINT            NOT NULL,
    ValidationStatus    VARCHAR(12)        NOT NULL,
    QualityGatePassed   BIT                NOT NULL,
    SourceExtractedAtUtc DATETIME2(0)      NOT NULL
);

CREATE TABLE demo.InsertStagePromotionAudit
(
    AuditID             INT IDENTITY(1, 1) NOT NULL PRIMARY KEY,
    PromotionBatchLabel VARCHAR(20)        NOT NULL,
    StageRowID          INT                NOT NULL,
    EnrollmentID        INT                NOT NULL,
    LearnerCode         VARCHAR(20)        NOT NULL,
    CourseCode          VARCHAR(20)        NOT NULL,
    DeliveryMonth       DATE               NOT NULL,
    SeatCount           TINYINT            NOT NULL,
    PromotedAtUtc       DATETIME2(0)       NOT NULL,
    PromotedBy          SYSNAME            NOT NULL
);

INSERT INTO demo.InsertStagePromotionTarget
(
    LearnerCode,
    CourseCode,
    DeliveryMonth,
    SeatCount,
    SourceBatchLabel
)
VALUES
    ('LRN-100', 'SQL-INS-101', '2026-03-01', 1, 'existing-load');

INSERT INTO demo.InsertStagePromotionStage
(
    BatchLabel,
    LearnerCode,
    CourseCode,
    DeliveryMonth,
    SeatCount,
    ValidationStatus,
    QualityGatePassed,
    SourceExtractedAtUtc
)
VALUES
    ('batch-2026-04', 'LRN-100', 'SQL-INS-101', '2026-03-01', 1, 'validated', 1, DATEADD(MINUTE, -40, SYSUTCDATETIME())),
    ('batch-2026-04', 'LRN-101', 'SQL-INS-101', '2026-04-01', 2, 'validated', 1, DATEADD(MINUTE, -38, SYSUTCDATETIME())),
    ('batch-2026-04', 'LRN-102', 'SQL-INS-201', NULL,         1, 'validated', 1, DATEADD(MINUTE, -37, SYSUTCDATETIME())),
    ('batch-2026-04', 'LRN-103', 'SQL-INS-201', '2026-04-01', 0, 'validated', 1, DATEADD(MINUTE, -36, SYSUTCDATETIME())),
    ('batch-2026-04', 'LRN-104', 'SQL-INS-301', '2026-04-01', 1, 'rejected',  0, DATEADD(MINUTE, -35, SYSUTCDATETIME())),
    ('batch-2026-05', 'LRN-105', 'SQL-INS-401', '2026-05-01', 1, 'validated', 1, DATEADD(MINUTE, -10, SYSUTCDATETIME()));

CREATE TABLE #StageReview
(
    StageRowID         INT           NOT NULL PRIMARY KEY,
    BatchLabel         VARCHAR(20)   NOT NULL,
    LearnerCode        VARCHAR(20)   NOT NULL,
    CourseCode         VARCHAR(20)   NOT NULL,
    DeliveryMonth      DATE          NULL,
    SeatCount          TINYINT       NOT NULL,
    ValidationStatus   VARCHAR(12)   NOT NULL,
    QualityGatePassed  BIT           NOT NULL,
    PromotionStatus    VARCHAR(12)   NOT NULL,
    RejectionReason    NVARCHAR(160) NULL
);

WITH BatchRows AS
(
    SELECT
        stg.StageRowID,
        stg.BatchLabel,
        stg.LearnerCode,
        stg.CourseCode,
        stg.DeliveryMonth,
        stg.SeatCount,
        stg.ValidationStatus,
        stg.QualityGatePassed
    FROM demo.InsertStagePromotionStage AS stg
    WHERE stg.BatchLabel = @BatchLabel
),
DuplicateCandidates AS
(
    SELECT
        br.StageRowID,
        ROW_NUMBER() OVER
        (
            PARTITION BY br.LearnerCode, br.CourseCode, br.DeliveryMonth
            ORDER BY br.StageRowID
        ) AS BatchDuplicateRank
    FROM BatchRows AS br
)
INSERT INTO #StageReview
(
    StageRowID,
    BatchLabel,
    LearnerCode,
    CourseCode,
    DeliveryMonth,
    SeatCount,
    ValidationStatus,
    QualityGatePassed,
    PromotionStatus,
    RejectionReason
)
SELECT
    br.StageRowID,
    br.BatchLabel,
    br.LearnerCode,
    br.CourseCode,
    br.DeliveryMonth,
    br.SeatCount,
    br.ValidationStatus,
    br.QualityGatePassed,
    CASE
        WHEN br.ValidationStatus <> 'validated' THEN 'rejected'
        WHEN br.QualityGatePassed = 0 THEN 'rejected'
        WHEN br.DeliveryMonth IS NULL THEN 'rejected'
        WHEN br.SeatCount < 1 THEN 'rejected'
        WHEN EXISTS
        (
            SELECT 1
            FROM demo.InsertStagePromotionTarget AS tgt
            WHERE tgt.LearnerCode = br.LearnerCode
              AND tgt.CourseCode = br.CourseCode
              AND tgt.DeliveryMonth = br.DeliveryMonth
        ) THEN 'rejected'
        WHEN dc.BatchDuplicateRank > 1 THEN 'rejected'
        ELSE 'ready'
    END AS PromotionStatus,
    CASE
        WHEN br.ValidationStatus <> 'validated' THEN N'Stage-Zeile ist fachlich noch nicht freigegeben.'
        WHEN br.QualityGatePassed = 0 THEN N'Die Quality-Gate-Pruefung ist fehlgeschlagen.'
        WHEN br.DeliveryMonth IS NULL THEN N'DeliveryMonth fehlt fuer die Zielzeile.'
        WHEN br.SeatCount < 1 THEN N'SeatCount muss mindestens 1 sein.'
        WHEN EXISTS
        (
            SELECT 1
            FROM demo.InsertStagePromotionTarget AS tgt
            WHERE tgt.LearnerCode = br.LearnerCode
              AND tgt.CourseCode = br.CourseCode
              AND tgt.DeliveryMonth = br.DeliveryMonth
        ) THEN N'Die natuerliche Zielkombination ist bereits vorhanden.'
        WHEN dc.BatchDuplicateRank > 1 THEN N'Die Batch enthaelt eine doppelte natuerliche Schluesselkombination.'
        ELSE NULL
    END AS RejectionReason
FROM BatchRows AS br
INNER JOIN DuplicateCandidates AS dc
    ON dc.StageRowID = br.StageRowID;

SELECT
    sr.StageRowID,
    sr.BatchLabel,
    sr.LearnerCode,
    sr.CourseCode,
    sr.DeliveryMonth,
    sr.SeatCount,
    sr.ValidationStatus,
    sr.QualityGatePassed,
    sr.PromotionStatus,
    sr.RejectionReason
FROM #StageReview AS sr
ORDER BY
    sr.StageRowID;

IF @PromoteOnlyValidated = 1
BEGIN
    INSERT INTO demo.InsertStagePromotionTarget
    (
        LearnerCode,
        CourseCode,
        DeliveryMonth,
        SeatCount,
        SourceBatchLabel
    )
    OUTPUT
        inserted.SourceBatchLabel,
        src.StageRowID,
        inserted.EnrollmentID,
        inserted.LearnerCode,
        inserted.CourseCode,
        inserted.DeliveryMonth,
        inserted.SeatCount,
        inserted.PromotedAtUtc,
        SUSER_SNAME()
    INTO demo.InsertStagePromotionAudit
    (
        PromotionBatchLabel,
        StageRowID,
        EnrollmentID,
        LearnerCode,
        CourseCode,
        DeliveryMonth,
        SeatCount,
        PromotedAtUtc,
        PromotedBy
    )
    SELECT
        src.LearnerCode,
        src.CourseCode,
        src.DeliveryMonth,
        src.SeatCount,
        src.BatchLabel
    FROM #StageReview AS src
    WHERE src.PromotionStatus = 'ready'
    ORDER BY
        src.StageRowID;
END;

SELECT
    aud.AuditID,
    aud.PromotionBatchLabel,
    aud.StageRowID,
    aud.EnrollmentID,
    aud.LearnerCode,
    aud.CourseCode,
    aud.DeliveryMonth,
    aud.SeatCount,
    aud.PromotedAtUtc,
    aud.PromotedBy
FROM demo.InsertStagePromotionAudit AS aud
ORDER BY
    aud.AuditID;

SELECT
    tgt.EnrollmentID,
    tgt.LearnerCode,
    tgt.CourseCode,
    tgt.DeliveryMonth,
    tgt.SeatCount,
    tgt.SourceBatchLabel,
    tgt.PromotedAtUtc
FROM demo.InsertStagePromotionTarget AS tgt
ORDER BY
    tgt.EnrollmentID;

IF @DropDemoObjects = 1
BEGIN
    DROP TABLE IF EXISTS demo.InsertStagePromotionAudit;
    DROP TABLE IF EXISTS demo.InsertStagePromotionTarget;
    DROP TABLE IF EXISTS demo.InsertStagePromotionStage;
END;
