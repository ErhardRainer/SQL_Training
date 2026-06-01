/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "TransactionAgeByDatabase.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "19_Transaktions"

purpose: >
  Zeigt pro Datenbank kompakt das Alter der aeltesten offenen Transaktion
  sowie begleitende Kennzahlen fuer eine schnelle Priorisierung im
  Transaktions-Review.

parameters:
  - name: "@MinimumAgeMinutes"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Filtert Datenbanken auf offene Transaktionen ab dieser Mindestdauer"
  - name: "@IncludeSystemDatabases"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = auch master, model, msdb und tempdb einbeziehen"
  - name: "@IncludeGuide"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zusaetzlich einen kompakten Leitfaden zur Einordnung ausgeben"

result_sets:
  - name: "DatabaseTransactionAgeSummary"
    description: "Zeigt pro Datenbank die aelteste offene Transaktion, Anzahl offener Transaktionen und ein Review-Signal"
  - name: "OldestTransactionSample"
    description: "Zeigt je Datenbank die aktuell aelteste offene Transaktion mit Session- und Logkontext"
  - name: "ReviewGuide"
    description: "Ordnet Alter, Session-Kontext und Logsignale typischen naechsten Schritten zu"

dependencies:
  - "sys.dm_tran_database_transactions"
  - "sys.dm_tran_active_transactions"
  - "sys.dm_tran_session_transactions"
  - "sys.dm_exec_sessions"
  - "sys.databases"
  - "SYSUTCDATETIME"
  - "DATEDIFF"
  - "ROW_NUMBER"
  - "CASE"
  - "COUNT"
  - "MAX"
  - "ORDER BY"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/19_Transaktions/SQLScripts/TransactionAgeByDatabase.md"
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
    description: "Erstversion des Diagnose-Skripts fuer das Alter offener Transaktionen je Datenbank"

notes:
  - "Das Skript liest nur DMVs und Katalogsichten; es fuehrt keine KILL-, COMMIT- oder Recovery-Aktionen aus."
  - "Die Verdichtung priorisiert das Alter der aeltesten offenen Transaktion je Datenbank und bleibt bewusst kompakt."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

-- 1. Parameter vorbereiten
DECLARE @MinimumAgeMinutes INT = 0;
DECLARE @IncludeSystemDatabases BIT = 0;
DECLARE @IncludeGuide BIT = 1;

IF @MinimumAgeMinutes < 0
BEGIN
    THROW 50000, '@MinimumAgeMinutes darf nicht negativ sein.', 1;
END;

IF @IncludeSystemDatabases NOT IN (0, 1)
BEGIN
    THROW 50001, '@IncludeSystemDatabases muss 0 oder 1 sein.', 1;
END;

IF @IncludeGuide NOT IN (0, 1)
BEGIN
    THROW 50002, '@IncludeGuide muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #TransactionInventory;
DROP TABLE IF EXISTS #DatabaseTransactionAgeSummary;
DROP TABLE IF EXISTS #OldestTransactionSample;
DROP TABLE IF EXISTS #ReviewGuide;

-- 2. Offene Transaktionen mit Datenbank-, Session- und Logkontext sammeln
CREATE TABLE #TransactionInventory
(
    DatabaseName                 SYSNAME         NOT NULL,
    DatabaseId                   INT             NOT NULL,
    TransactionId                BIGINT          NOT NULL,
    TransactionName              NVARCHAR(64)    NULL,
    TransactionType              NVARCHAR(40)    NOT NULL,
    TransactionState             NVARCHAR(60)    NOT NULL,
    TransactionBeginTimeUtc      DATETIME2(0)    NOT NULL,
    AgeMinutes                   INT             NOT NULL,
    DatabaseLogBytesUsed         BIGINT          NULL,
    DatabaseLogBytesReserved     BIGINT          NULL,
    SessionId                    SMALLINT        NULL,
    LoginName                    NVARCHAR(128)   NULL,
    HostName                     NVARCHAR(128)   NULL,
    ProgramName                  NVARCHAR(128)   NULL,
    IsUserProcess                BIT             NULL,
    TransactionRole              NVARCHAR(30)    NOT NULL,
    ReviewSignal                 VARCHAR(20)     NOT NULL,
    ReviewHint                   VARCHAR(220)    NOT NULL
);

INSERT INTO #TransactionInventory
(
    DatabaseName,
    DatabaseId,
    TransactionId,
    TransactionName,
    TransactionType,
    TransactionState,
    TransactionBeginTimeUtc,
    AgeMinutes,
    DatabaseLogBytesUsed,
    DatabaseLogBytesReserved,
    SessionId,
    LoginName,
    HostName,
    ProgramName,
    IsUserProcess,
    TransactionRole,
    ReviewSignal,
    ReviewHint
)
SELECT
    d.name AS DatabaseName,
    d.database_id AS DatabaseId,
    dt.database_transaction_id AS TransactionId,
    at.name AS TransactionName,
    CASE at.transaction_type
        WHEN 1 THEN 'read/write'
        WHEN 2 THEN 'read-only'
        WHEN 3 THEN 'system'
        WHEN 4 THEN 'distributed'
        ELSE CONCAT('other(', at.transaction_type, ')')
    END AS TransactionType,
    CASE at.transaction_state
        WHEN 0 THEN 'not initialized'
        WHEN 1 THEN 'not yet started'
        WHEN 2 THEN 'active'
        WHEN 3 THEN 'ended read-only'
        WHEN 4 THEN 'commit initiated'
        WHEN 5 THEN 'prepared'
        WHEN 6 THEN 'committed'
        WHEN 7 THEN 'rolling back'
        WHEN 8 THEN 'rolled back'
        ELSE CONCAT('state(', at.transaction_state, ')')
    END AS TransactionState,
    CAST(at.transaction_begin_time AS DATETIME2(0)) AS TransactionBeginTimeUtc,
    DATEDIFF(MINUTE, at.transaction_begin_time, SYSUTCDATETIME()) AS AgeMinutes,
    dt.database_transaction_log_bytes_used,
    dt.database_transaction_log_bytes_reserved,
    st.session_id AS SessionId,
    es.login_name,
    es.host_name,
    es.program_name,
    es.is_user_process,
    CASE
        WHEN st.is_enlisted = 1 THEN 'enlisted'
        WHEN st.is_bound = 1 THEN 'bound'
        WHEN st.session_id IS NULL THEN 'background-or-orphan'
        ELSE 'session-owned'
    END AS TransactionRole,
    CASE
        WHEN DATEDIFF(MINUTE, at.transaction_begin_time, SYSUTCDATETIME()) >= 120 THEN 'high'
        WHEN DATEDIFF(MINUTE, at.transaction_begin_time, SYSUTCDATETIME()) >= 30 THEN 'medium'
        ELSE 'observe'
    END AS ReviewSignal,
    CASE
        WHEN DATEDIFF(MINUTE, at.transaction_begin_time, SYSUTCDATETIME()) >= 120
            THEN 'Sehr alte offene Transaktion; Commit-Grenzen, Blocking und Rollback-Risiko priorisiert pruefen.'
        WHEN DATEDIFF(MINUTE, at.transaction_begin_time, SYSUTCDATETIME()) >= 30
            THEN 'Transaktion ist bereits laenger offen; Session-Kontext und Workload-Fenster pruefen.'
        WHEN st.session_id IS NULL
            THEN 'Ohne sichtbare Session moegliche Hintergrundarbeit oder bereits beendete Session mitdenken.'
        ELSE 'Kompakter Baseline-Hinweis fuer Datenbank- und Sessionreview.'
    END AS ReviewHint
FROM sys.dm_tran_database_transactions AS dt
INNER JOIN sys.dm_tran_active_transactions AS at
    ON at.transaction_id = dt.transaction_id
INNER JOIN sys.databases AS d
    ON d.database_id = dt.database_id
LEFT JOIN sys.dm_tran_session_transactions AS st
    ON st.transaction_id = dt.transaction_id
LEFT JOIN sys.dm_exec_sessions AS es
    ON es.session_id = st.session_id
WHERE at.transaction_state NOT IN (3, 6, 8)
  AND DATEDIFF(MINUTE, at.transaction_begin_time, SYSUTCDATETIME()) >= @MinimumAgeMinutes
  AND (@IncludeSystemDatabases = 1 OR d.database_id > 4);

-- 3. Verdichtung je Datenbank aufbauen
CREATE TABLE #DatabaseTransactionAgeSummary
(
    DatabaseName                 SYSNAME         NOT NULL,
    OpenTransactionCount         INT             NOT NULL,
    UserSessionCount             INT             NOT NULL,
    OldestTransactionBeginUtc    DATETIME2(0)    NOT NULL,
    OldestAgeMinutes             INT             NOT NULL,
    TotalLogUsedMB               DECIMAL(18,2)   NOT NULL,
    HighestReviewSignal          VARCHAR(20)     NOT NULL,
    ReviewHint                   VARCHAR(220)    NOT NULL
);

INSERT INTO #DatabaseTransactionAgeSummary
(
    DatabaseName,
    OpenTransactionCount,
    UserSessionCount,
    OldestTransactionBeginUtc,
    OldestAgeMinutes,
    TotalLogUsedMB,
    HighestReviewSignal,
    ReviewHint
)
SELECT
    ti.DatabaseName,
    COUNT(DISTINCT ti.TransactionId) AS OpenTransactionCount,
    COUNT(DISTINCT CASE WHEN ti.IsUserProcess = 1 THEN ti.SessionId END) AS UserSessionCount,
    MIN(ti.TransactionBeginTimeUtc) AS OldestTransactionBeginUtc,
    MAX(ti.AgeMinutes) AS OldestAgeMinutes,
    CAST(SUM(COALESCE(ti.DatabaseLogBytesUsed, 0)) / 1048576.0 AS DECIMAL(18,2)) AS TotalLogUsedMB,
    CASE
        WHEN MAX(CASE ti.ReviewSignal WHEN 'high' THEN 3 WHEN 'medium' THEN 2 ELSE 1 END) >= 3 THEN 'high'
        WHEN MAX(CASE ti.ReviewSignal WHEN 'high' THEN 3 WHEN 'medium' THEN 2 ELSE 1 END) >= 2 THEN 'medium'
        ELSE 'observe'
    END AS HighestReviewSignal,
    CASE
        WHEN MAX(ti.AgeMinutes) >= 120
            THEN 'Aelteste offene Transaktion ist deutlich ueberfaellig; Datenbank zuerst auf Root Cause und Rollback-Folgen pruefen.'
        WHEN MAX(ti.AgeMinutes) >= 30
            THEN 'Mindestens eine Transaktion ist laenger offen; Session-Drilldown und Betriebsfenster einordnen.'
        ELSE 'Kompakte Baseline fuer aktuell offene Transaktionen in dieser Datenbank.'
    END AS ReviewHint
FROM #TransactionInventory AS ti
GROUP BY
    ti.DatabaseName;

-- 4. Pro Datenbank die aelteste offene Transaktion herausziehen
CREATE TABLE #OldestTransactionSample
(
    DatabaseName                 SYSNAME         NOT NULL,
    TransactionId                BIGINT          NOT NULL,
    TransactionName              NVARCHAR(64)    NULL,
    TransactionType              NVARCHAR(40)    NOT NULL,
    TransactionState             NVARCHAR(60)    NOT NULL,
    TransactionBeginTimeUtc      DATETIME2(0)    NOT NULL,
    AgeMinutes                   INT             NOT NULL,
    SessionId                    SMALLINT        NULL,
    LoginName                    NVARCHAR(128)   NULL,
    HostName                     NVARCHAR(128)   NULL,
    ProgramName                  NVARCHAR(128)   NULL,
    TransactionRole              NVARCHAR(30)    NOT NULL,
    DatabaseLogUsedMB            DECIMAL(18,2)   NOT NULL,
    DatabaseLogReservedMB        DECIMAL(18,2)   NOT NULL,
    ReviewSignal                 VARCHAR(20)     NOT NULL,
    ReviewHint                   VARCHAR(220)    NOT NULL
);

WITH RankedTransactions AS
(
    SELECT
        ti.*,
        ROW_NUMBER() OVER
        (
            PARTITION BY ti.DatabaseName
            ORDER BY
                ti.AgeMinutes DESC,
                COALESCE(ti.DatabaseLogBytesUsed, 0) DESC,
                ti.TransactionId ASC
        ) AS RowInDatabase
    FROM #TransactionInventory AS ti
)
INSERT INTO #OldestTransactionSample
(
    DatabaseName,
    TransactionId,
    TransactionName,
    TransactionType,
    TransactionState,
    TransactionBeginTimeUtc,
    AgeMinutes,
    SessionId,
    LoginName,
    HostName,
    ProgramName,
    TransactionRole,
    DatabaseLogUsedMB,
    DatabaseLogReservedMB,
    ReviewSignal,
    ReviewHint
)
SELECT
    rt.DatabaseName,
    rt.TransactionId,
    rt.TransactionName,
    rt.TransactionType,
    rt.TransactionState,
    rt.TransactionBeginTimeUtc,
    rt.AgeMinutes,
    rt.SessionId,
    rt.LoginName,
    rt.HostName,
    rt.ProgramName,
    rt.TransactionRole,
    CAST(COALESCE(rt.DatabaseLogBytesUsed, 0) / 1048576.0 AS DECIMAL(18,2)) AS DatabaseLogUsedMB,
    CAST(COALESCE(rt.DatabaseLogBytesReserved, 0) / 1048576.0 AS DECIMAL(18,2)) AS DatabaseLogReservedMB,
    rt.ReviewSignal,
    rt.ReviewHint
FROM RankedTransactions AS rt
WHERE rt.RowInDatabase = 1;

-- 5. Leitfaden fuer die Einordnung bereitstellen
CREATE TABLE #ReviewGuide
(
    GuideStep                    TINYINT         NOT NULL,
    FocusArea                    VARCHAR(80)     NOT NULL,
    Recommendation               VARCHAR(220)    NOT NULL,
    WhyItHelps                   VARCHAR(220)    NOT NULL
);

INSERT INTO #ReviewGuide
(
    GuideStep,
    FocusArea,
    Recommendation,
    WhyItHelps
)
VALUES
    (
        1,
        'Database prioritization',
        'Zuerst Datenbanken mit hohem Alter der aeltesten offenen Transaktion pruefen.',
        'Das priorisiert Incident-Review nach moeglichem Blocking-, Rollback- und Logrisiko.'
    ),
    (
        2,
        'Session drilldown',
        'Danach Login, Host und ProgramName der aeltesten Transaktion mit Requests und Locks kombinieren.',
        'So wird aus der kompakten Datenbanksicht ein operativ nutzbarer Drilldown.'
    ),
    (
        3,
        'Background context',
        'Faelle ohne sichtbare Session als Hintergrundarbeit oder verwaiste Zuordnung markieren.',
        'Das verhindert voreilige Schluesse auf normale User-Sessions.'
    ),
    (
        4,
        'Log interpretation',
        'Logbytes immer gemeinsam mit Recovery-Modell und Backup-Kontext bewerten.',
        'Reines Alter ohne Betriebs- und Logkontext reicht fuer Priorisierungen oft nicht aus.'
    );

-- 6. Resultsets ausgeben
SELECT
    dts.DatabaseName,
    dts.OpenTransactionCount,
    dts.UserSessionCount,
    dts.OldestTransactionBeginUtc,
    dts.OldestAgeMinutes,
    dts.TotalLogUsedMB,
    dts.HighestReviewSignal,
    dts.ReviewHint
FROM #DatabaseTransactionAgeSummary AS dts
ORDER BY
    CASE dts.HighestReviewSignal
        WHEN 'high' THEN 1
        WHEN 'medium' THEN 2
        ELSE 3
    END,
    dts.OldestAgeMinutes DESC,
    dts.TotalLogUsedMB DESC,
    dts.DatabaseName;

SELECT
    ots.DatabaseName,
    ots.TransactionId,
    ots.TransactionName,
    ots.TransactionType,
    ots.TransactionState,
    ots.TransactionBeginTimeUtc,
    ots.AgeMinutes,
    ots.SessionId,
    ots.LoginName,
    ots.HostName,
    ots.ProgramName,
    ots.TransactionRole,
    ots.DatabaseLogUsedMB,
    ots.DatabaseLogReservedMB,
    ots.ReviewSignal,
    ots.ReviewHint
FROM #OldestTransactionSample AS ots
ORDER BY
    CASE ots.ReviewSignal
        WHEN 'high' THEN 1
        WHEN 'medium' THEN 2
        ELSE 3
    END,
    ots.AgeMinutes DESC,
    ots.DatabaseName;

IF @IncludeGuide = 1
BEGIN
    SELECT
        rg.GuideStep,
        rg.FocusArea,
        rg.Recommendation,
        rg.WhyItHelps
    FROM #ReviewGuide AS rg
    ORDER BY
        rg.GuideStep;
END;
