/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "SoftDeleteFlagMigration.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "06_Delete"

purpose: >
  Demonstriert die Umstellung von einem harten Delete-Kandidatenmodell auf
  Soft-Delete-Flags inklusive Vorschau, Auditierung und Rueckfalloption auf
  Basis eines didaktischen Ruecksetz-Ledgers.

parameters:
  - name: "@RetentionCutoffDate"
    sql_type: "DATE"
    direction: "IN"
    required: false
    description: "Datensaetze mit LastActivityDate vor diesem Datum gelten als Legacy-Delete-Kandidaten"
  - name: "@OnlyClosedRows"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 beschraenkt die Migration auf fachlich abgeschlossene Datensaetze"
  - name: "@ApplyMigration"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 fuehrt die Soft-Delete-Migration in der Demo aus, 0 bleibt im Vorschau-Modus"
  - name: "@RollbackMigration"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 setzt die letzte Demo-Migration anhand des Rollback-Ledgers zurueck"
  - name: "@DeleteReason"
    sql_type: "NVARCHAR(120)"
    direction: "IN"
    required: false
    description: "Begruendung fuer das Soft-Delete-Flag nach der Migration"

result_sets:
  - name: "MigrationCandidates"
    description: "Zeigt den Demo-Bestand mit Legacy-Delete-Queue und Soft-Delete-Eignung"
  - name: "MigrationAudit"
    description: "Protokolliert migrierte oder zurueckgesetzte Zeilen inklusive Batch und Aktion"
  - name: "CurrentRows"
    description: "Zeigt den Bestand nach Preview, Migration oder Rollback"
  - name: "ExecutionGuide"
    description: "Fasst Modus, Kandidaten, migrierte Zeilen und Rueckfallhinweise zusammen"

dependencies:
  - "tempdb temporary tables"
  - "explicit transactions"
  - "TRY...CATCH"
  - "UPDATE"
  - "OUTPUT"
  - "SYSUTCDATETIME"

safety:
  level: "destructive-demo-tempdb"
  writes_data: true

documentation:
  markdown_file: "T-SQL/06_Delete/SQLScripts/SoftDeleteFlagMigration.md"
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
    description: "Erstversion fuer didaktische Soft-Delete-Migration mit Rollback-Ledger"

notes:
  - "Die Demo nutzt nur temporaere Tabellen in tempdb."
  - "Rollback ist nur fuer den zuletzt ausgefuehrten Migrationsbatch der Demo vorgesehen."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @RetentionCutoffDate DATE = '2026-01-15';
DECLARE @OnlyClosedRows BIT = 1;
DECLARE @ApplyMigration BIT = 0;
DECLARE @RollbackMigration BIT = 0;
DECLARE @DeleteReason NVARCHAR(120) = N'Migration von hartem Delete auf Soft Delete';

IF @RetentionCutoffDate IS NULL
BEGIN
    THROW 50670, '@RetentionCutoffDate darf nicht NULL sein.', 1;
END;

IF @OnlyClosedRows NOT IN (0, 1)
BEGIN
    THROW 50671, '@OnlyClosedRows muss 0 oder 1 sein.', 1;
END;

IF @ApplyMigration NOT IN (0, 1)
BEGIN
    THROW 50672, '@ApplyMigration muss 0 oder 1 sein.', 1;
END;

IF @RollbackMigration NOT IN (0, 1)
BEGIN
    THROW 50673, '@RollbackMigration muss 0 oder 1 sein.', 1;
END;

IF @ApplyMigration = 1 AND @RollbackMigration = 1
BEGIN
    THROW 50674, '@ApplyMigration und @RollbackMigration duerfen nicht gleichzeitig aktiv sein.', 1;
END;

IF NULLIF(LTRIM(RTRIM(@DeleteReason)), N'') IS NULL
BEGIN
    THROW 50675, '@DeleteReason darf nicht leer sein.', 1;
END;

DROP TABLE IF EXISTS #TicketStore;
DROP TABLE IF EXISTS #LegacyDeleteQueue;
DROP TABLE IF EXISTS #RollbackLedger;
DROP TABLE IF EXISTS #MigrationAudit;

CREATE TABLE #TicketStore
(
    TicketID INT NOT NULL PRIMARY KEY,
    CustomerCode VARCHAR(12) NOT NULL,
    TicketStatus VARCHAR(20) NOT NULL,
    LastActivityDate DATE NOT NULL,
    Severity VARCHAR(10) NOT NULL,
    SubjectLine VARCHAR(120) NOT NULL,
    IsDeleted BIT NOT NULL,
    DeletedAtUtc DATETIME2(0) NULL,
    DeletedBy SYSNAME NULL,
    DeleteReason NVARCHAR(120) NULL,
    LegacyDeleteRequestedAt DATETIME2(0) NULL,
    MigrationBatchID UNIQUEIDENTIFIER NULL
);

CREATE TABLE #LegacyDeleteQueue
(
    TicketID INT NOT NULL PRIMARY KEY,
    RequestedAtUtc DATETIME2(0) NOT NULL,
    RequestedBy SYSNAME NOT NULL,
    QueueReason NVARCHAR(120) NOT NULL
);

CREATE TABLE #RollbackLedger
(
    LedgerID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    BatchID UNIQUEIDENTIFIER NOT NULL,
    TicketID INT NOT NULL,
    PriorIsDeleted BIT NOT NULL,
    PriorDeletedAtUtc DATETIME2(0) NULL,
    PriorDeletedBy SYSNAME NULL,
    PriorDeleteReason NVARCHAR(120) NULL,
    PriorMigrationBatchID UNIQUEIDENTIFIER NULL,
    CapturedAtUtc DATETIME2(0) NOT NULL
);

CREATE TABLE #MigrationAudit
(
    AuditID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    BatchID UNIQUEIDENTIFIER NULL,
    ActionName VARCHAR(20) NOT NULL,
    TicketID INT NOT NULL,
    TicketStatus VARCHAR(20) NOT NULL,
    LastActivityDate DATE NOT NULL,
    OldIsDeleted BIT NOT NULL,
    NewIsDeleted BIT NOT NULL,
    EffectiveDeleteReason NVARCHAR(120) NULL,
    ChangedAtUtc DATETIME2(0) NOT NULL
);
INSERT INTO #TicketStore
(
    TicketID,
    CustomerCode,
    TicketStatus,
    LastActivityDate,
    Severity,
    SubjectLine,
    IsDeleted,
    DeletedAtUtc,
    DeletedBy,
    DeleteReason,
    LegacyDeleteRequestedAt,
    MigrationBatchID
)
VALUES
    (8101, 'C-100', 'closed',    '2025-12-20', 'low',    'Invoice copy request',          0, NULL, NULL, NULL, '2026-01-03T08:30:00', NULL),
    (8102, 'C-100', 'cancelled', '2025-12-22', 'medium', 'Duplicate onboarding case',     0, NULL, NULL, NULL, '2026-01-04T10:15:00', NULL),
    (8103, 'C-205', 'resolved',  '2026-01-05', 'low',    'Address correction finished',   0, NULL, NULL, NULL, '2026-01-06T09:00:00', NULL),
    (8104, 'C-205', 'open',      '2026-01-07', 'high',   'Payment escalation',            0, NULL, NULL, NULL, NULL,                   NULL),
    (8105, 'C-330', 'closed',    '2026-01-10', 'low',    'Product return archived',       0, NULL, NULL, NULL, '2026-01-11T12:45:00', NULL),
    (8106, 'C-330', 'review',    '2026-01-13', 'medium', 'Warranty clarification',        0, NULL, NULL, NULL, '2026-01-13T15:00:00', NULL),
    (8107, 'C-411', 'closed',    '2026-01-18', 'low',    'Campaign feedback stored',      0, NULL, NULL, NULL, '2026-01-18T16:10:00', NULL),
    (8108, 'C-411', 'deleted',   '2025-12-12', 'low',    'Old migrated archive marker',   1, '2026-01-02T07:30:00', SUSER_SNAME(), N'Bereits soft geloescht', '2025-12-30T08:00:00', '11111111-1111-1111-1111-111111111111');

INSERT INTO #LegacyDeleteQueue
(
    TicketID,
    RequestedAtUtc,
    RequestedBy,
    QueueReason
)
VALUES
    (8101, '2026-01-03T08:30:00', SUSER_SNAME(), N'Retention-Fenster erreicht'),
    (8102, '2026-01-04T10:15:00', SUSER_SNAME(), N'Dublettenfall abgeschlossen'),
    (8103, '2026-01-06T09:00:00', SUSER_SNAME(), N'Fall ist final dokumentiert'),
    (8105, '2026-01-11T12:45:00', SUSER_SNAME(), N'Ruecksendung abgeschlossen'),
    (8106, '2026-01-13T15:00:00', SUSER_SNAME(), N'Manual review fuer Delete vorgesehen'),
    (8107, '2026-01-18T16:10:00', SUSER_SNAME(), N'Frist noch nicht erreicht');

INSERT INTO #RollbackLedger
(
    BatchID,
    TicketID,
    PriorIsDeleted,
    PriorDeletedAtUtc,
    PriorDeletedBy,
    PriorDeleteReason,
    PriorMigrationBatchID,
    CapturedAtUtc
)
VALUES
    (
        '11111111-1111-1111-1111-111111111111',
        8108,
        0,
        NULL,
        NULL,
        NULL,
        NULL,
        '2026-01-02T07:29:00'
    );

SELECT
    ts.TicketID,
    ts.CustomerCode,
    ts.TicketStatus,
    ts.LastActivityDate,
    ts.Severity,
    ts.SubjectLine,
    ts.IsDeleted,
    ldq.RequestedAtUtc AS LegacyDeleteRequestedAtUtc,
    ldq.QueueReason,
    CASE
        WHEN ldq.TicketID IS NOT NULL
         AND ts.IsDeleted = 0
         AND ts.LastActivityDate < @RetentionCutoffDate
         AND (
                @OnlyClosedRows = 0
                OR ts.TicketStatus IN ('closed', 'cancelled', 'resolved')
             )
            THEN 1
        ELSE 0
    END AS IsMigrationCandidate
FROM #TicketStore AS ts
LEFT JOIN #LegacyDeleteQueue AS ldq
    ON ldq.TicketID = ts.TicketID
ORDER BY
    ts.LastActivityDate,
    ts.TicketID;

DECLARE @BatchID UNIQUEIDENTIFIER = NEWID();
DECLARE @LatestBatchID UNIQUEIDENTIFIER = NULL;

IF @RollbackMigration = 1
BEGIN
    SELECT TOP (1)
        @LatestBatchID = rl.BatchID
    FROM #RollbackLedger AS rl
    ORDER BY
        rl.LedgerID DESC;

    IF @LatestBatchID IS NULL
    BEGIN
        THROW 50676, 'Rollback angefordert, aber kein Ruecksetz-Ledger vorhanden.', 1;
    END;
END;

IF @ApplyMigration = 1
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO #RollbackLedger
        (
            BatchID,
            TicketID,
            PriorIsDeleted,
            PriorDeletedAtUtc,
            PriorDeletedBy,
            PriorDeleteReason,
            PriorMigrationBatchID,
            CapturedAtUtc
        )
        SELECT
            @BatchID,
            ts.TicketID,
            ts.IsDeleted,
            ts.DeletedAtUtc,
            ts.DeletedBy,
            ts.DeleteReason,
            ts.MigrationBatchID,
            SYSUTCDATETIME()
        FROM #TicketStore AS ts
        INNER JOIN #LegacyDeleteQueue AS ldq
            ON ldq.TicketID = ts.TicketID
        WHERE ts.IsDeleted = 0
          AND ts.LastActivityDate < @RetentionCutoffDate
          AND (
                @OnlyClosedRows = 0
                OR ts.TicketStatus IN ('closed', 'cancelled', 'resolved')
              );

        UPDATE ts
        SET
            ts.IsDeleted = 1,
            ts.DeletedAtUtc = SYSUTCDATETIME(),
            ts.DeletedBy = SUSER_SNAME(),
            ts.DeleteReason = @DeleteReason,
            ts.MigrationBatchID = @BatchID
        OUTPUT
            @BatchID,
            'migrate',
            inserted.TicketID,
            inserted.TicketStatus,
            inserted.LastActivityDate,
            deleted.IsDeleted,
            inserted.IsDeleted,
            inserted.DeleteReason,
            inserted.DeletedAtUtc
        INTO #MigrationAudit
        (
            BatchID,
            ActionName,
            TicketID,
            TicketStatus,
            LastActivityDate,
            OldIsDeleted,
            NewIsDeleted,
            EffectiveDeleteReason,
            ChangedAtUtc
        )
        FROM #TicketStore AS ts
        INNER JOIN #LegacyDeleteQueue AS ldq
            ON ldq.TicketID = ts.TicketID
        WHERE ts.IsDeleted = 0
          AND ts.LastActivityDate < @RetentionCutoffDate
          AND (
                @OnlyClosedRows = 0
                OR ts.TicketStatus IN ('closed', 'cancelled', 'resolved')
              );

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
        BEGIN
            ROLLBACK TRANSACTION;
        END;

        THROW;
    END CATCH;
END;
ELSE IF @RollbackMigration = 1
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE ts
        SET
            ts.IsDeleted = rl.PriorIsDeleted,
            ts.DeletedAtUtc = rl.PriorDeletedAtUtc,
            ts.DeletedBy = rl.PriorDeletedBy,
            ts.DeleteReason = rl.PriorDeleteReason,
            ts.MigrationBatchID = rl.PriorMigrationBatchID
        OUTPUT
            @LatestBatchID,
            'rollback',
            inserted.TicketID,
            inserted.TicketStatus,
            inserted.LastActivityDate,
            deleted.IsDeleted,
            inserted.IsDeleted,
            inserted.DeleteReason,
            SYSUTCDATETIME()
        INTO #MigrationAudit
        (
            BatchID,
            ActionName,
            TicketID,
            TicketStatus,
            LastActivityDate,
            OldIsDeleted,
            NewIsDeleted,
            EffectiveDeleteReason,
            ChangedAtUtc
        )
        FROM #TicketStore AS ts
        INNER JOIN #RollbackLedger AS rl
            ON rl.TicketID = ts.TicketID
           AND rl.BatchID = @LatestBatchID;

        DELETE rl
        FROM #RollbackLedger AS rl
        WHERE rl.BatchID = @LatestBatchID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
        BEGIN
            ROLLBACK TRANSACTION;
        END;

        THROW;
    END CATCH;
END;

SELECT
    ma.AuditID,
    ma.BatchID,
    ma.ActionName,
    ma.TicketID,
    ma.TicketStatus,
    ma.LastActivityDate,
    ma.OldIsDeleted,
    ma.NewIsDeleted,
    ma.EffectiveDeleteReason,
    ma.ChangedAtUtc
FROM #MigrationAudit AS ma
ORDER BY
    ma.AuditID;

SELECT
    ts.TicketID,
    ts.CustomerCode,
    ts.TicketStatus,
    ts.LastActivityDate,
    ts.Severity,
    ts.SubjectLine,
    ts.IsDeleted,
    ts.DeletedAtUtc,
    ts.DeletedBy,
    ts.DeleteReason,
    ts.LegacyDeleteRequestedAt,
    ts.MigrationBatchID
FROM #TicketStore AS ts
ORDER BY
    ts.LastActivityDate,
    ts.TicketID;

SELECT
    @RetentionCutoffDate AS RetentionCutoffDate,
    @OnlyClosedRows AS OnlyClosedRows,
    @ApplyMigration AS ApplyMigration,
    @RollbackMigration AS RollbackMigration,
    @DeleteReason AS DeleteReason,
    (
        SELECT COUNT(*)
        FROM #TicketStore AS ts
        INNER JOIN #LegacyDeleteQueue AS ldq
            ON ldq.TicketID = ts.TicketID
        WHERE ts.IsDeleted = 0
          AND ts.LastActivityDate < @RetentionCutoffDate
          AND (
                @OnlyClosedRows = 0
                OR ts.TicketStatus IN ('closed', 'cancelled', 'resolved')
              )
    ) AS RemainingLegacyDeleteCandidates,
    (
        SELECT COUNT(*)
        FROM #MigrationAudit AS ma
        WHERE ma.ActionName = 'migrate'
    ) AS MigratedRows,
    (
        SELECT COUNT(*)
        FROM #MigrationAudit AS ma
        WHERE ma.ActionName = 'rollback'
    ) AS RolledBackRows,
    CASE
        WHEN @ApplyMigration = 1 THEN 'Migration fuehrt Legacy-Delete-Kandidaten als Soft Delete mit Audit und Batch-ID weiter.'
        WHEN @RollbackMigration = 1 THEN 'Rollback setzt den zuletzt migrierten Demo-Batch auf den vorherigen Zustand zurueck.'
        ELSE 'PreviewOnly zeigt Kandidaten fuer die Umstellung ohne Datenmutation.'
    END AS ExecutionModeNote,
    'Fuer produktive Systeme muessen Filterregeln, Indexstrategie, Sichtbarkeit geloeschter Zeilen und Wiederherstellungsprozesse vorab abgestimmt werden.' AS SafetyNote;
