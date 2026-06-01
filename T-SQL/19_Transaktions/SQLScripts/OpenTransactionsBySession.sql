/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "OpenTransactionsBySession.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "19_Transaktions"

purpose: >
  Zeigt offene Transaktionen pro Session inklusive Alter, Login, Host,
  ProgramName, Blocking-Kontext und einer didaktischen Impact-Einschaetzung
  fuer das operative Review.

parameters:
  - name: "@MinimumAgeMinutes"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Beruecksichtigt nur Transaktionen ab dieser Mindestdauer in Minuten"
  - name: "@OnlyUserSessions"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = nur Benutzer-Sessions, 0 = auch System-Sessions zeigen"
  - name: "@IncludeGuide"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zusaetzlich einen kompakten Leitfaden fuer das Review ausgeben"

result_sets:
  - name: "OpenTransactionsBySession"
    description: "Zeigt offene Transaktionen mit Session-, Login-, Host-, Request- und Impact-Kontext"
  - name: "SessionImpactSummary"
    description: "Verdichtet offene Transaktionen pro Session zu Alter, Anzahl, Logverbrauch und Impact-Stufe"
  - name: "ReviewGuide"
    description: "Leitet naechste Diagnose- und Kommunikationsschritte aus dem Session-Bild ab"

dependencies:
  - "sys.dm_tran_active_transactions"
  - "sys.dm_tran_session_transactions"
  - "sys.dm_tran_database_transactions"
  - "sys.dm_exec_sessions"
  - "sys.dm_exec_requests"
  - "sys.dm_exec_connections"
  - "sys.dm_exec_sql_text"
  - "sys.databases"
  - "SYSUTCDATETIME"
  - "DATEDIFF"
  - "CASE"
  - "ORDER BY"
  - "tempdb temporary tables"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/19_Transaktions/SQLScripts/OpenTransactionsBySession.md"
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
    description: "Erstversion des Diagnose-Skripts fuer offene Transaktionen pro Session"

notes:
  - "Das Skript liest nur aktuelle DMV-Daten und fuehrt keine KILL-, COMMIT- oder ROLLBACK-Aktionen aus."
  - "Die Impact-Einschaetzung ist eine didaktische Priorisierungshilfe und ersetzt keine betriebliche Freigabeentscheidung."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

-- 1. Parameter vorbereiten
DECLARE @MinimumAgeMinutes INT = 0;
DECLARE @OnlyUserSessions BIT = 1;
DECLARE @IncludeGuide BIT = 1;

IF @MinimumAgeMinutes < 0
BEGIN
    THROW 50000, '@MinimumAgeMinutes darf nicht negativ sein.', 1;
END;

IF @OnlyUserSessions NOT IN (0, 1)
BEGIN
    THROW 50001, '@OnlyUserSessions muss 0 oder 1 sein.', 1;
END;

IF @IncludeGuide NOT IN (0, 1)
BEGIN
    THROW 50002, '@IncludeGuide muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #OpenTransactionsBySession;
DROP TABLE IF EXISTS #SessionImpactSummary;
DROP TABLE IF EXISTS #ReviewGuide;

-- 2. Offene Transaktionen mit Session-, Login-, Host- und Request-Kontext sammeln
CREATE TABLE #OpenTransactionsBySession
(
    SessionId                    SMALLINT         NULL,
    TransactionId                BIGINT           NOT NULL,
    DatabaseName                 SYSNAME          NULL,
    TransactionName              NVARCHAR(64)     NULL,
    TransactionType              NVARCHAR(40)     NOT NULL,
    TransactionState             NVARCHAR(40)     NOT NULL,
    TransactionBeginTimeUtc      DATETIME2(0)     NOT NULL,
    AgeMinutes                   INT              NOT NULL,
    OpenTransactionCount         INT              NULL,
    DatabaseLogUsedMB            DECIMAL(18,2)    NOT NULL,
    DatabaseLogReservedMB        DECIMAL(18,2)    NOT NULL,
    SessionStatus                NVARCHAR(30)     NULL,
    RequestStatus                NVARCHAR(30)     NULL,
    LoginName                    NVARCHAR(128)    NULL,
    HostName                     NVARCHAR(128)    NULL,
    ProgramName                  NVARCHAR(128)    NULL,
    ClientNetAddress             VARCHAR(48)      NULL,
    BlockingSessionId            SMALLINT         NULL,
    WaitType                     NVARCHAR(120)    NULL,
    WaitTimeMs                   INT              NULL,
    RequestCommand               NVARCHAR(32)     NULL,
    StatementSnippet             NVARCHAR(4000)   NULL,
    ImpactLevel                  VARCHAR(12)      NOT NULL,
    EstimatedImpact              VARCHAR(220)     NOT NULL
);

INSERT INTO #OpenTransactionsBySession
(
    SessionId,
    TransactionId,
    DatabaseName,
    TransactionName,
    TransactionType,
    TransactionState,
    TransactionBeginTimeUtc,
    AgeMinutes,
    OpenTransactionCount,
    DatabaseLogUsedMB,
    DatabaseLogReservedMB,
    SessionStatus,
    RequestStatus,
    LoginName,
    HostName,
    ProgramName,
    ClientNetAddress,
    BlockingSessionId,
    WaitType,
    WaitTimeMs,
    RequestCommand,
    StatementSnippet,
    ImpactLevel,
    EstimatedImpact
)
SELECT
    tst.session_id AS SessionId,
    at.transaction_id AS TransactionId,
    DB_NAME(COALESCE(dt.database_id, r.database_id, s.database_id)) AS DatabaseName,
    at.name AS TransactionName,
    CASE at.transaction_type
        WHEN 1 THEN N'read/write'
        WHEN 2 THEN N'read-only'
        WHEN 3 THEN N'system'
        WHEN 4 THEN N'distributed'
        ELSE CONCAT(N'other(', at.transaction_type, N')')
    END AS TransactionType,
    CASE at.transaction_state
        WHEN 0 THEN N'not initialized'
        WHEN 1 THEN N'initialized'
        WHEN 2 THEN N'active'
        WHEN 3 THEN N'ended read-only'
        WHEN 4 THEN N'commit started'
        WHEN 5 THEN N'prepared'
        WHEN 6 THEN N'committed'
        WHEN 7 THEN N'rolling back'
        WHEN 8 THEN N'rolled back'
        ELSE CONCAT(N'state(', at.transaction_state, N')')
    END AS TransactionState,
    CAST(at.transaction_begin_time AS DATETIME2(0)) AS TransactionBeginTimeUtc,
    DATEDIFF(MINUTE, at.transaction_begin_time, SYSUTCDATETIME()) AS AgeMinutes,
    s.open_transaction_count AS OpenTransactionCount,
    CAST(COALESCE(dt.database_transaction_log_bytes_used, 0) / 1048576.0 AS DECIMAL(18,2)) AS DatabaseLogUsedMB,
    CAST(COALESCE(dt.database_transaction_log_bytes_reserved, 0) / 1048576.0 AS DECIMAL(18,2)) AS DatabaseLogReservedMB,
    s.status AS SessionStatus,
    r.status AS RequestStatus,
    s.login_name AS LoginName,
    s.host_name AS HostName,
    s.program_name AS ProgramName,
    c.client_net_address AS ClientNetAddress,
    NULLIF(r.blocking_session_id, 0) AS BlockingSessionId,
    r.wait_type AS WaitType,
    r.wait_time AS WaitTimeMs,
    r.command AS RequestCommand,
    CASE
        WHEN r.sql_handle IS NULL OR txt.text IS NULL THEN NULL
        ELSE LTRIM(RTRIM(
            SUBSTRING(
                txt.text,
                (r.statement_start_offset / 2) + 1,
                CASE
                    WHEN r.statement_end_offset IS NULL OR r.statement_end_offset < 0
                        THEN LEN(CONVERT(NVARCHAR(MAX), txt.text))
                    ELSE ((r.statement_end_offset - r.statement_start_offset) / 2) + 1
                END
            )
        ))
    END AS StatementSnippet,
    CASE
        WHEN DATEDIFF(MINUTE, at.transaction_begin_time, SYSUTCDATETIME()) >= 60 THEN 'high'
        WHEN COALESCE(dt.database_transaction_log_bytes_used, 0) >= 268435456 THEN 'high'
        WHEN NULLIF(r.blocking_session_id, 0) IS NOT NULL THEN 'high'
        WHEN s.status = N'sleeping' AND COALESCE(s.open_transaction_count, 0) > 0 THEN 'medium'
        WHEN DATEDIFF(MINUTE, at.transaction_begin_time, SYSUTCDATETIME()) >= 15 THEN 'medium'
        ELSE 'observe'
    END AS ImpactLevel,
    CASE
        WHEN NULLIF(r.blocking_session_id, 0) IS NOT NULL
            THEN 'Die Session ist Teil eines Blocking-Kontexts; Root-Blocker, Statement und fachlichen Besitzer zuerst abstimmen.'
        WHEN DATEDIFF(MINUTE, at.transaction_begin_time, SYSUTCDATETIME()) >= 60
            THEN 'Sehr alte offene Transaktion; Commit-Grenzen, Batch-Groesse und moegliche Rollback-Kosten priorisiert reviewen.'
        WHEN COALESCE(dt.database_transaction_log_bytes_used, 0) >= 268435456
            THEN 'Auffaelliges Logvolumen; Backup-Kette, Logreuse und Dauer gemeinsam einordnen.'
        WHEN s.status = N'sleeping' AND COALESCE(s.open_transaction_count, 0) > 0
            THEN 'Sleeping Session mit offener Transaktion; Anwendungspfad auf fehlendes COMMIT oder lange Idle-Phasen pruefen.'
        WHEN tst.session_id IS NULL
            THEN 'Keine direkte Session-Zuordnung sichtbar; Hintergrundarbeit oder verwaiste Zuordnung in die Review aufnehmen.'
        ELSE 'Kompakter Session-Befund fuer Login-, Host- und Programm-Review ohne akuten Eskalationshinweis.'
    END AS EstimatedImpact
FROM sys.dm_tran_active_transactions AS at
LEFT JOIN sys.dm_tran_session_transactions AS tst
    ON tst.transaction_id = at.transaction_id
LEFT JOIN sys.dm_exec_sessions AS s
    ON s.session_id = tst.session_id
LEFT JOIN sys.dm_exec_requests AS r
    ON r.session_id = s.session_id
LEFT JOIN sys.dm_exec_connections AS c
    ON c.session_id = s.session_id
LEFT JOIN sys.dm_tran_database_transactions AS dt
    ON dt.transaction_id = at.transaction_id
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) AS txt
WHERE at.transaction_state NOT IN (3, 6, 8)
  AND at.transaction_begin_time IS NOT NULL
  AND DATEDIFF(MINUTE, at.transaction_begin_time, SYSUTCDATETIME()) >= @MinimumAgeMinutes
  AND (@OnlyUserSessions = 0 OR COALESCE(s.is_user_process, 0) = 1);

-- 3. Session-Sicht verdichten
CREATE TABLE #SessionImpactSummary
(
    SessionId                    SMALLINT         NULL,
    LoginName                    NVARCHAR(128)    NULL,
    HostName                     NVARCHAR(128)    NULL,
    ProgramName                  NVARCHAR(128)    NULL,
    TransactionsInScope          INT              NOT NULL,
    OldestTransactionBeginUtc    DATETIME2(0)     NOT NULL,
    MaxAgeMinutes                INT              NOT NULL,
    TotalLogUsedMB               DECIMAL(18,2)    NOT NULL,
    TotalLogReservedMB           DECIMAL(18,2)    NOT NULL,
    BlockingHits                 INT              NOT NULL,
    HighestImpactLevel           VARCHAR(12)      NOT NULL,
    SessionRecommendation        VARCHAR(220)     NOT NULL
);

INSERT INTO #SessionImpactSummary
(
    SessionId,
    LoginName,
    HostName,
    ProgramName,
    TransactionsInScope,
    OldestTransactionBeginUtc,
    MaxAgeMinutes,
    TotalLogUsedMB,
    TotalLogReservedMB,
    BlockingHits,
    HighestImpactLevel,
    SessionRecommendation
)
SELECT
    ot.SessionId,
    MAX(ot.LoginName) AS LoginName,
    MAX(ot.HostName) AS HostName,
    MAX(ot.ProgramName) AS ProgramName,
    COUNT(DISTINCT ot.TransactionId) AS TransactionsInScope,
    MIN(ot.TransactionBeginTimeUtc) AS OldestTransactionBeginUtc,
    MAX(ot.AgeMinutes) AS MaxAgeMinutes,
    CAST(SUM(ot.DatabaseLogUsedMB) AS DECIMAL(18,2)) AS TotalLogUsedMB,
    CAST(SUM(ot.DatabaseLogReservedMB) AS DECIMAL(18,2)) AS TotalLogReservedMB,
    SUM(CASE WHEN ot.BlockingSessionId IS NOT NULL THEN 1 ELSE 0 END) AS BlockingHits,
    CASE
        WHEN MAX(CASE ot.ImpactLevel WHEN 'high' THEN 3 WHEN 'medium' THEN 2 ELSE 1 END) >= 3 THEN 'high'
        WHEN MAX(CASE ot.ImpactLevel WHEN 'high' THEN 3 WHEN 'medium' THEN 2 ELSE 1 END) >= 2 THEN 'medium'
        ELSE 'observe'
    END AS HighestImpactLevel,
    CASE
        WHEN SUM(CASE WHEN ot.BlockingSessionId IS NOT NULL THEN 1 ELSE 0 END) > 0
            THEN 'Session verursacht oder erlebt Blocking; Owner und Root-Blocker gemeinsam betrachten.'
        WHEN MAX(ot.AgeMinutes) >= 60
            THEN 'Session haelt mindestens eine sehr alte Transaktion; Commit-Logik und Rueckbaukosten priorisieren.'
        WHEN SUM(ot.DatabaseLogUsedMB) >= 256.00
            THEN 'Session bindet auffaelliges Logvolumen; Backup- und Batch-Kontext vor Eingriffen klaeren.'
        WHEN MAX(COALESCE(ot.OpenTransactionCount, 0)) > 1
            THEN 'Mehrere offene Transaktionen auf derselben Session; Ownership und Fehlerpfade ueberpruefen.'
        ELSE 'Session ist im Scope, aktuell aber eher fuer Beobachtung und Verlauf geeignet.'
    END AS SessionRecommendation
FROM #OpenTransactionsBySession AS ot
GROUP BY
    ot.SessionId;

-- 4. Review-Guide aufbauen
CREATE TABLE #ReviewGuide
(
    GuideStep                    TINYINT          NOT NULL,
    FocusArea                    VARCHAR(80)      NOT NULL,
    TriggerDescription           VARCHAR(220)     NOT NULL,
    RecommendedNextStep          VARCHAR(220)     NOT NULL,
    WhyItHelps                   VARCHAR(220)     NOT NULL
);

INSERT INTO #ReviewGuide
(
    GuideStep,
    FocusArea,
    TriggerDescription,
    RecommendedNextStep,
    WhyItHelps
)
VALUES
    (
        1,
        'Session priority',
        'Sessions mit hohem Impact-Level, hohem Alter oder Blocking-Hits stehen zuerst im Review.',
        'Zuerst Owner, Login, Host und ProgramName klaeren, bevor technische Eingriffe erwogen werden.',
        'So wird die Session-Sicht direkt mit Verantwortlichkeit und Kommunikationsweg verbunden.'
    ),
    (
        2,
        'Blocking context',
        'Blocking-Hits oder Waits zeigen, dass die offene Transaktion bereits andere Arbeit beeinflusst.',
        'Root-Blocker, WaitResource und StatementSnippet zusammen mit Sperrketten analysieren.',
        'Die Kombination verhindert, dass nur Symptome statt der eigentlichen Ursache bearbeitet werden.'
    ),
    (
        3,
        'Log pressure',
        'Hohes genutztes oder reserviertes Logvolumen muss zusammen mit Dauer und Recovery-Kontext bewertet werden.',
        'Logbackup-Frequenz, Reuse-Waits und Batch-Grenzen gegen den Session-Befund spiegeln.',
        'So bleibt die Einschaetzung operativ nutzbar und vermeidet vorschnelle KILL-Entscheidungen.'
    ),
    (
        4,
        'Sleeping owners',
        'Sleeping Sessions mit offenen Transaktionen wirken oft harmlos, blockieren aber weiterhin Fortschritt.',
        'Connection-Pooling, explizite COMMIT-Pfade und Fehlerbehandlung der Anwendung pruefen.',
        'Viele reale Faelle entstehen nicht durch hohe CPU-Last, sondern durch vergessene Transaktionsenden.'
    );

-- 5. Resultsets ausgeben
SELECT
    ot.SessionId,
    ot.TransactionId,
    ot.DatabaseName,
    ot.TransactionName,
    ot.TransactionType,
    ot.TransactionState,
    ot.TransactionBeginTimeUtc,
    ot.AgeMinutes,
    ot.OpenTransactionCount,
    ot.DatabaseLogUsedMB,
    ot.DatabaseLogReservedMB,
    ot.SessionStatus,
    ot.RequestStatus,
    ot.LoginName,
    ot.HostName,
    ot.ProgramName,
    ot.ClientNetAddress,
    ot.BlockingSessionId,
    ot.WaitType,
    ot.WaitTimeMs,
    ot.RequestCommand,
    ot.StatementSnippet,
    ot.ImpactLevel,
    ot.EstimatedImpact
FROM #OpenTransactionsBySession AS ot
ORDER BY
    CASE ot.ImpactLevel
        WHEN 'high' THEN 1
        WHEN 'medium' THEN 2
        ELSE 3
    END,
    ot.AgeMinutes DESC,
    ot.DatabaseLogUsedMB DESC,
    ot.SessionId,
    ot.TransactionId;

SELECT
    sis.SessionId,
    sis.LoginName,
    sis.HostName,
    sis.ProgramName,
    sis.TransactionsInScope,
    sis.OldestTransactionBeginUtc,
    sis.MaxAgeMinutes,
    sis.TotalLogUsedMB,
    sis.TotalLogReservedMB,
    sis.BlockingHits,
    sis.HighestImpactLevel,
    sis.SessionRecommendation
FROM #SessionImpactSummary AS sis
ORDER BY
    CASE sis.HighestImpactLevel
        WHEN 'high' THEN 1
        WHEN 'medium' THEN 2
        ELSE 3
    END,
    sis.MaxAgeMinutes DESC,
    sis.TotalLogUsedMB DESC,
    sis.SessionId;

IF @IncludeGuide = 1
BEGIN
    SELECT
        rg.GuideStep,
        rg.FocusArea,
        rg.TriggerDescription,
        rg.RecommendedNextStep,
        rg.WhyItHelps
    FROM #ReviewGuide AS rg
    ORDER BY
        rg.GuideStep;
END;
