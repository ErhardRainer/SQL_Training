/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "DeleteWithOutputAudit.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "06_Delete"

purpose: >
  Demonstriert DELETE ... OUTPUT an einer Demo-Retention-Queue, damit
  geloeschte Zeilen einmalig erfasst und anschliessend sowohl fuer ein
  Audit-Protokoll als auch fuer eine Undo-Vorschau weiterverwendet werden
  koennen.

parameters:
  - name: "@DeleteBeforeDate"
    sql_type: "DATE"
    direction: "IN"
    required: false
    description: "Demo-Zeilen mit RetentionUntil vor diesem Stichtag kommen fuer die Loeschung in Frage"
  - name: "@ExecuteDelete"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 fuehrt die Demo-Loeschung aus, 0 zeigt nur Kandidaten und geplante Audit-/Undo-Daten"
  - name: "@MaxBatchSize"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Begrenzt die Anzahl der in einem Lauf geloeschten Demo-Zeilen"
  - name: "@DeleteReason"
    sql_type: "NVARCHAR(100)"
    direction: "IN"
    required: false
    description: "Audit-Grund fuer die Loeschung und die Undo-Dokumentation"

result_sets:
  - name: "DeleteCandidates"
    description: "Zeigt alle Demo-Zeilen mit Kennzeichnung fuer Batch-Auswahl und Blocker"
  - name: "DeleteAudit"
    description: "Audit-Protokoll aus den per OUTPUT erfassten geloeschten Zeilen"
  - name: "UndoPlan"
    description: "Vorschau auf eine moegliche Wiederherstellung der geloeschten Demo-Zeilen"
  - name: "RemainingRetentionQueue"
    description: "Verbleibender Bestand nach der Demo-Loeschung"
  - name: "ExecutionGuide"
    description: "Fasst Modus, Batch-Groesse und Anzahl geloeschter Demo-Zeilen zusammen"

dependencies:
  - "tempdb temporary tables"
  - "DELETE"
  - "OUTPUT INTO"
  - "CTE"
  - "ROW_NUMBER"
  - "SYSUTCDATETIME"
  - "SUSER_SNAME"

safety:
  level: "demo-write-tempdb"
  writes_data: true

documentation:
  markdown_file: "T-SQL/06_Delete/SQLScripts/DeleteWithOutputAudit.md"
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
    description: "Erstversion fuer DELETE OUTPUT mit Audit- und Undo-Ableitung"

notes:
  - "Das Skript arbeitet ausschliesslich mit Demo-Tabellen in tempdb."
  - "Die geloeschten Zeilen werden einmalig per OUTPUT erfasst und danach fuer Audit und Undo wiederverwendet."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @DeleteBeforeDate DATE = '2026-02-15';
DECLARE @ExecuteDelete BIT = 0;
DECLARE @MaxBatchSize INT = 2;
DECLARE @DeleteReason NVARCHAR(100) = N'Retention cleanup demo';

IF @DeleteBeforeDate IS NULL
BEGIN
    THROW 50650, '@DeleteBeforeDate darf nicht NULL sein.', 1;
END;

IF @ExecuteDelete NOT IN (0, 1)
BEGIN
    THROW 50651, '@ExecuteDelete muss 0 oder 1 sein.', 1;
END;

IF @MaxBatchSize IS NULL OR @MaxBatchSize < 1
BEGIN
    THROW 50652, '@MaxBatchSize muss mindestens 1 sein.', 1;
END;

IF NULLIF(LTRIM(RTRIM(@DeleteReason)), N'') IS NULL
BEGIN
    THROW 50653, '@DeleteReason darf nicht leer sein.', 1;
END;

DROP TABLE IF EXISTS #RetentionQueue;
DROP TABLE IF EXISTS #DeletedCapture;
DROP TABLE IF EXISTS #DeleteAudit;

CREATE TABLE #RetentionQueue
(
    QueueID                 INT            NOT NULL PRIMARY KEY,
    TenantCode              VARCHAR(10)    NOT NULL,
    RecordCategory          VARCHAR(20)    NOT NULL,
    BusinessKey             VARCHAR(20)    NOT NULL,
    RetentionUntil          DATE           NOT NULL,
    ExportPending           BIT            NOT NULL,
    IsLegalHold             BIT            NOT NULL,
    CreatedAtUtc            DATETIME2(0)   NOT NULL
);

CREATE TABLE #DeletedCapture
(
    QueueID                 INT            NOT NULL,
    TenantCode              VARCHAR(10)    NOT NULL,
    RecordCategory          VARCHAR(20)    NOT NULL,
    BusinessKey             VARCHAR(20)    NOT NULL,
    RetentionUntil          DATE           NOT NULL,
    ExportPending           BIT            NOT NULL,
    IsLegalHold             BIT            NOT NULL,
    CreatedAtUtc            DATETIME2(0)   NOT NULL,
    DeletedAtUtc            DATETIME2(0)   NOT NULL,
    DeletedBy               SYSNAME        NOT NULL,
    DeleteReason            NVARCHAR(100)  NOT NULL
);

CREATE TABLE #DeleteAudit
(
    AuditEntryID            INT            IDENTITY(1,1) NOT NULL PRIMARY KEY,
    QueueID                 INT            NOT NULL,
    TenantCode              VARCHAR(10)    NOT NULL,
    RecordCategory          VARCHAR(20)    NOT NULL,
    BusinessKey             VARCHAR(20)    NOT NULL,
    RetentionUntil          DATE           NOT NULL,
    DeletedAtUtc            DATETIME2(0)   NOT NULL,
    DeletedBy               SYSNAME        NOT NULL,
    DeleteReason            NVARCHAR(100)  NOT NULL,
    UndoRecommendation      NVARCHAR(200)  NOT NULL
);

INSERT INTO #RetentionQueue
(
    QueueID,
    TenantCode,
    RecordCategory,
    BusinessKey,
    RetentionUntil,
    ExportPending,
    IsLegalHold,
    CreatedAtUtc
)
VALUES
    (2001, 'TEN-01', 'invoice-pdf', 'INV-2025-0001', '2026-01-10', 0, 0, '2025-02-14T08:00:00'),
    (2002, 'TEN-01', 'invoice-pdf', 'INV-2025-0002', '2026-01-25', 1, 0, '2025-03-01T08:00:00'),
    (2003, 'TEN-02', 'mail-archive', 'MSG-8841',     '2026-02-05', 0, 0, '2025-04-11T10:30:00'),
    (2004, 'TEN-02', 'mail-archive', 'MSG-8842',     '2026-03-10', 0, 0, '2025-05-18T11:10:00'),
    (2005, 'TEN-03', 'ticket-log',   'TCK-4420',     '2026-01-19', 0, 1, '2025-02-22T07:45:00'),
    (2006, 'TEN-03', 'ticket-log',   'TCK-4421',     '2026-01-16', 0, 0, '2025-02-23T07:45:00');

;WITH DeleteCandidates AS
(
    SELECT
        rq.QueueID,
        rq.TenantCode,
        rq.RecordCategory,
        rq.BusinessKey,
        rq.RetentionUntil,
        rq.ExportPending,
        rq.IsLegalHold,
        rq.CreatedAtUtc,
        DeleteEligibility =
            CASE
                WHEN rq.RetentionUntil >= @DeleteBeforeDate THEN 'not-due'
                WHEN rq.ExportPending = 1 THEN 'export-pending'
                WHEN rq.IsLegalHold = 1 THEN 'legal-hold'
                ELSE 'delete-ready'
            END,
        CandidateRank =
            CASE
                WHEN rq.RetentionUntil < @DeleteBeforeDate
                     AND rq.ExportPending = 0
                     AND rq.IsLegalHold = 0 THEN
                    ROW_NUMBER() OVER
                    (
                        ORDER BY
                            rq.RetentionUntil,
                            rq.CreatedAtUtc,
                            rq.QueueID
                    )
            END
    FROM #RetentionQueue AS rq
)
SELECT
    dc.QueueID,
    dc.TenantCode,
    dc.RecordCategory,
    dc.BusinessKey,
    dc.RetentionUntil,
    dc.ExportPending,
    dc.IsLegalHold,
    dc.CreatedAtUtc,
    dc.DeleteEligibility,
    CAST(CASE WHEN dc.CandidateRank IS NOT NULL AND dc.CandidateRank <= @MaxBatchSize THEN 1 ELSE 0 END AS BIT) AS SelectedForBatch,
    dc.CandidateRank
FROM DeleteCandidates AS dc
ORDER BY
    dc.RetentionUntil,
    dc.QueueID;

IF @ExecuteDelete = 1
BEGIN
    ;WITH DeleteBatch AS
    (
        SELECT
            rq.QueueID,
            BatchRank =
                ROW_NUMBER() OVER
                (
                    ORDER BY
                        rq.RetentionUntil,
                        rq.CreatedAtUtc,
                        rq.QueueID
                )
        FROM #RetentionQueue AS rq
        WHERE rq.RetentionUntil < @DeleteBeforeDate
          AND rq.ExportPending = 0
          AND rq.IsLegalHold = 0
    )
    DELETE rq
    OUTPUT
        DELETED.QueueID,
        DELETED.TenantCode,
        DELETED.RecordCategory,
        DELETED.BusinessKey,
        DELETED.RetentionUntil,
        DELETED.ExportPending,
        DELETED.IsLegalHold,
        DELETED.CreatedAtUtc,
        SYSUTCDATETIME(),
        SUSER_SNAME(),
        @DeleteReason
    INTO #DeletedCapture
    (
        QueueID,
        TenantCode,
        RecordCategory,
        BusinessKey,
        RetentionUntil,
        ExportPending,
        IsLegalHold,
        CreatedAtUtc,
        DeletedAtUtc,
        DeletedBy,
        DeleteReason
    )
    FROM #RetentionQueue AS rq
    INNER JOIN DeleteBatch AS db
        ON db.QueueID = rq.QueueID
    WHERE db.BatchRank <= @MaxBatchSize;

    INSERT INTO #DeleteAudit
    (
        QueueID,
        TenantCode,
        RecordCategory,
        BusinessKey,
        RetentionUntil,
        DeletedAtUtc,
        DeletedBy,
        DeleteReason,
        UndoRecommendation
    )
    SELECT
        dc.QueueID,
        dc.TenantCode,
        dc.RecordCategory,
        dc.BusinessKey,
        dc.RetentionUntil,
        dc.DeletedAtUtc,
        dc.DeletedBy,
        dc.DeleteReason,
        N'Reinsert aus OUTPUT-Capture nur nach Review von Retention und Exportstatus.'
    FROM #DeletedCapture AS dc;
END;

SELECT
    da.AuditEntryID,
    da.QueueID,
    da.TenantCode,
    da.RecordCategory,
    da.BusinessKey,
    da.RetentionUntil,
    da.DeletedAtUtc,
    da.DeletedBy,
    da.DeleteReason,
    da.UndoRecommendation
FROM #DeleteAudit AS da
ORDER BY
    da.AuditEntryID;

SELECT
    dc.QueueID,
    dc.TenantCode,
    dc.RecordCategory,
    dc.BusinessKey,
    dc.RetentionUntil,
    dc.DeletedAtUtc,
    dc.DeletedBy,
    dc.DeleteReason,
    CONCAT(
        'INSERT INTO RetentionQueue (QueueID, TenantCode, RecordCategory, BusinessKey, RetentionUntil, ExportPending, IsLegalHold, CreatedAtUtc) VALUES (',
        dc.QueueID,
        ', ''',
        dc.TenantCode,
        ''', ''',
        dc.RecordCategory,
        ''', ''',
        dc.BusinessKey,
        ''', ''',
        CONVERT(CHAR(10), dc.RetentionUntil, 23),
        ''', ',
        CAST(dc.ExportPending AS VARCHAR(1)),
        ', ',
        CAST(dc.IsLegalHold AS VARCHAR(1)),
        ', ''',
        CONVERT(CHAR(19), dc.CreatedAtUtc, 126),
        ''');'
    ) AS UndoStatementPreview
FROM #DeletedCapture AS dc
ORDER BY
    dc.QueueID;

SELECT
    rq.QueueID,
    rq.TenantCode,
    rq.RecordCategory,
    rq.BusinessKey,
    rq.RetentionUntil,
    rq.ExportPending,
    rq.IsLegalHold,
    rq.CreatedAtUtc
FROM #RetentionQueue AS rq
ORDER BY
    rq.RetentionUntil,
    rq.QueueID;

SELECT
    @ExecuteDelete AS ExecuteDelete,
    @DeleteBeforeDate AS DeleteBeforeDate,
    @MaxBatchSize AS MaxBatchSize,
    @DeleteReason AS DeleteReason,
    (SELECT COUNT(*) FROM #DeletedCapture) AS DeletedRowCount,
    (SELECT COUNT(*) FROM #DeleteAudit) AS AuditRowCount,
    CASE
        WHEN @ExecuteDelete = 0 THEN 'Preview-Modus: Kandidaten sind sichtbar, Delete und Audit wurden nicht ausgefuehrt.'
        ELSE 'DELETE ... OUTPUT hat Demo-Zeilen geloescht und fuer Audit sowie Undo-Vorschau festgehalten.'
    END AS ExecutionMode;
