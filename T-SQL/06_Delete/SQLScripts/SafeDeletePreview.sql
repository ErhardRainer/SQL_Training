/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "SafeDeletePreview.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "06_Delete"

purpose: >
  Zeigt zu loeschende Zeilen zuerst als Preview, bevor ein didaktisches Delete
  gegen eine temporaere Demo-Tabelle optional ausgefuehrt wird.

parameters:
  - name: "@CutoffDate"
    sql_type: "DATE"
    direction: "IN"
    required: false
    description: "Zeilen mit DueDate vor diesem Stichtag gelten als Loeschkandidaten"
  - name: "@RegionFilter"
    sql_type: "VARCHAR(20)"
    direction: "IN"
    required: false
    description: "Optionaler Filter fuer eine Region; NULL zeigt alle Regionen"
  - name: "@MaxPreviewRows"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Begrenzt die Anzahl angezeigter Preview-Zeilen"
  - name: "@ExecuteDelete"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "0 zeigt nur die Vorschau, 1 fuehrt den didaktischen Delete in tempdb aus"
  - name: "@ProtectHighValue"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 schuetzt Faelle mit hohem OutstandingAmount vor der Ausfuehrung"

result_sets:
  - name: "DeletePreview"
    description: "Zeigt Kandidaten, Schutzregeln und die finale Delete-Empfehlung"
  - name: "DeleteSummary"
    description: "Verdichtet die Preview nach Region und Entscheidungsgrund"
  - name: "DeletedRows"
    description: "Listet im Execute-Modus die tatsaechlich entfernten Demo-Zeilen"
  - name: "ExecutionGuide"
    description: "Fasst Modus, Sicherheitsregeln und naechste Schritte zusammen"

dependencies:
  - "tempdb temporary tables"
  - "CTE"
  - "CASE"
  - "DELETE"
  - "OUTPUT"
  - "window aggregates"

safety:
  level: "destructive-demo-tempdb"
  writes_data: true

documentation:
  markdown_file: "T-SQL/06_Delete/SQLScripts/SafeDeletePreview.md"
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
    description: "Erstversion fuer sicheres Preview-vor-Delete-Labor"

notes:
  - "Das Skript arbeitet nur mit einer temporaeren Demo-Tabelle in tempdb."
  - "Preview und Ausfuehrung nutzen dieselbe Schutzlogik, damit die Vorschau belastbar bleibt."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @CutoffDate DATE = '2026-02-01';
DECLARE @RegionFilter VARCHAR(20) = NULL;
DECLARE @MaxPreviewRows INT = 25;
DECLARE @ExecuteDelete BIT = 0;
DECLARE @ProtectHighValue BIT = 1;

IF @CutoffDate IS NULL
BEGIN
    THROW 50650, '@CutoffDate darf nicht NULL sein.', 1;
END;

IF @RegionFilter IS NOT NULL
   AND NULLIF(LTRIM(RTRIM(@RegionFilter)), '') IS NULL
BEGIN
    THROW 50651, '@RegionFilter darf nicht nur aus Leerzeichen bestehen.', 1;
END;

IF @MaxPreviewRows IS NULL OR @MaxPreviewRows < 1 OR @MaxPreviewRows > 200
BEGIN
    THROW 50652, '@MaxPreviewRows muss zwischen 1 und 200 liegen.', 1;
END;

IF @ExecuteDelete NOT IN (0, 1)
BEGIN
    THROW 50653, '@ExecuteDelete muss 0 oder 1 sein.', 1;
END;

IF @ProtectHighValue NOT IN (0, 1)
BEGIN
    THROW 50654, '@ProtectHighValue muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #OpenCases;
DROP TABLE IF EXISTS #DeletedRows;

CREATE TABLE #OpenCases
(
    CaseID INT NOT NULL PRIMARY KEY,
    CustomerID INT NOT NULL,
    RegionCode VARCHAR(20) NOT NULL,
    DueDate DATE NOT NULL,
    CaseStatus VARCHAR(20) NOT NULL,
    OutstandingAmount DECIMAL(12,2) NOT NULL,
    HasActiveDispute BIT NOT NULL,
    LastContactDate DATE NOT NULL
);

CREATE TABLE #DeletedRows
(
    CaseID INT NOT NULL,
    RegionCode VARCHAR(20) NOT NULL,
    OutstandingAmount DECIMAL(12,2) NOT NULL,
    DeleteReason VARCHAR(60) NOT NULL
);

INSERT INTO #OpenCases
(
    CaseID,
    CustomerID,
    RegionCode,
    DueDate,
    CaseStatus,
    OutstandingAmount,
    HasActiveDispute,
    LastContactDate
)
VALUES
    (2001, 101, 'NORTH', '2025-11-15', 'closed', 0.00, 0, '2025-12-01'),
    (2002, 101, 'NORTH', '2025-12-10', 'closed', 40.00, 0, '2026-01-05'),
    (2003, 108, 'NORTH', '2026-01-08', 'closed', 1200.00, 0, '2026-01-10'),
    (2004, 120, 'WEST',  '2025-10-28', 'closed', 0.00, 1, '2025-11-03'),
    (2005, 121, 'WEST',  '2025-12-01', 'closed', 35.00, 0, '2026-01-18'),
    (2006, 130, 'SOUTH', '2026-01-12', 'open',   0.00, 0, '2026-02-02'),
    (2007, 131, 'SOUTH', '2025-11-30', 'closed', 0.00, 0, '2025-12-15'),
    (2008, 144, 'EAST',  '2025-12-20', 'closed', 980.00, 0, '2026-01-02'),
    (2009, 150, 'EAST',  '2026-01-18', 'closed', 0.00, 0, '2026-01-20'),
    (2010, 151, 'EAST',  '2025-09-14', 'closed', 0.00, 0, '2025-09-30'),
    (2011, 160, 'WEST',  '2026-02-03', 'closed', 0.00, 0, '2026-02-05'),
    (2012, 165, 'NORTH', '2025-11-02', 'closed', 150.00, 1, '2025-11-22');

;WITH CandidateBase AS
(
    SELECT
        oc.CaseID,
        oc.CustomerID,
        oc.RegionCode,
        oc.DueDate,
        oc.CaseStatus,
        oc.OutstandingAmount,
        oc.HasActiveDispute,
        oc.LastContactDate,
        CASE
            WHEN oc.CaseStatus = 'closed'
             AND oc.DueDate < @CutoffDate
             AND (@RegionFilter IS NULL OR oc.RegionCode = @RegionFilter)
            THEN 1
            ELSE 0
        END AS MatchesScope
    FROM #OpenCases AS oc
),
PreviewRows AS
(
    SELECT
        cb.CaseID,
        cb.CustomerID,
        cb.RegionCode,
        cb.DueDate,
        cb.CaseStatus,
        cb.OutstandingAmount,
        cb.HasActiveDispute,
        cb.LastContactDate,
        cb.MatchesScope,
        CASE
            WHEN cb.MatchesScope = 0 THEN 'outside-scope'
            WHEN cb.HasActiveDispute = 1 THEN 'protected-active-dispute'
            WHEN @ProtectHighValue = 1 AND cb.OutstandingAmount >= 500.00 THEN 'protected-high-value'
            ELSE 'delete-candidate'
        END AS DecisionReason,
        CASE
            WHEN cb.MatchesScope = 1
             AND cb.HasActiveDispute = 0
             AND (@ProtectHighValue = 0 OR cb.OutstandingAmount < 500.00)
            THEN 1
            ELSE 0
        END AS ApprovedForDelete
    FROM CandidateBase AS cb
)
SELECT TOP (@MaxPreviewRows)
    pr.CaseID,
    pr.CustomerID,
    pr.RegionCode,
    pr.DueDate,
    pr.CaseStatus,
    pr.OutstandingAmount,
    pr.HasActiveDispute,
    pr.LastContactDate,
    pr.MatchesScope,
    pr.DecisionReason,
    pr.ApprovedForDelete,
    COUNT(*) OVER () AS TotalPreviewRows,
    SUM(pr.ApprovedForDelete) OVER () AS TotalApprovedDeletes
FROM PreviewRows AS pr
ORDER BY
    pr.ApprovedForDelete DESC,
    pr.DueDate,
    pr.CaseID;

;WITH PreviewRows AS
(
    SELECT
        oc.RegionCode,
        CASE
            WHEN oc.CaseStatus = 'closed'
             AND oc.DueDate < @CutoffDate
             AND (@RegionFilter IS NULL OR oc.RegionCode = @RegionFilter)
             AND oc.HasActiveDispute = 0
             AND (@ProtectHighValue = 0 OR oc.OutstandingAmount < 500.00)
            THEN 'delete-candidate'
            WHEN oc.CaseStatus = 'closed'
             AND oc.DueDate < @CutoffDate
             AND (@RegionFilter IS NULL OR oc.RegionCode = @RegionFilter)
             AND oc.HasActiveDispute = 1
            THEN 'protected-active-dispute'
            WHEN oc.CaseStatus = 'closed'
             AND oc.DueDate < @CutoffDate
             AND (@RegionFilter IS NULL OR oc.RegionCode = @RegionFilter)
             AND @ProtectHighValue = 1
             AND oc.OutstandingAmount >= 500.00
            THEN 'protected-high-value'
            ELSE 'outside-scope'
        END AS DecisionReason
    FROM #OpenCases AS oc
)
SELECT
    pr.RegionCode,
    pr.DecisionReason,
    COUNT(*) AS RowCount
FROM PreviewRows AS pr
GROUP BY
    pr.RegionCode,
    pr.DecisionReason
ORDER BY
    pr.RegionCode,
    pr.DecisionReason;

IF @ExecuteDelete = 1
BEGIN
    ;WITH ApprovedRows AS
    (
        SELECT
            oc.CaseID,
            oc.RegionCode,
            oc.OutstandingAmount,
            CAST('preview-approved-delete' AS VARCHAR(60)) AS DeleteReason
        FROM #OpenCases AS oc
        WHERE oc.CaseStatus = 'closed'
          AND oc.DueDate < @CutoffDate
          AND (@RegionFilter IS NULL OR oc.RegionCode = @RegionFilter)
          AND oc.HasActiveDispute = 0
          AND (@ProtectHighValue = 0 OR oc.OutstandingAmount < 500.00)
    )
    DELETE oc
        OUTPUT
            deleted.CaseID,
            deleted.RegionCode,
            deleted.OutstandingAmount,
            ar.DeleteReason
        INTO #DeletedRows
    FROM #OpenCases AS oc
    INNER JOIN ApprovedRows AS ar
        ON ar.CaseID = oc.CaseID;
END;

SELECT
    dr.CaseID,
    dr.RegionCode,
    dr.OutstandingAmount,
    dr.DeleteReason
FROM #DeletedRows AS dr
ORDER BY
    dr.CaseID;

SELECT
    @CutoffDate AS CutoffDate,
    @RegionFilter AS RegionFilter,
    @MaxPreviewRows AS MaxPreviewRows,
    @ExecuteDelete AS ExecuteDelete,
    @ProtectHighValue AS ProtectHighValue,
    (
        SELECT COUNT(*)
        FROM #OpenCases AS oc
    ) AS RemainingRowsAfterExecution,
    (
        SELECT COUNT(*)
        FROM #DeletedRows AS dr
    ) AS DeletedRows,
    CASE
        WHEN @ExecuteDelete = 0 THEN 'PreviewOnly: keine Demo-Zeilen wurden geloescht.'
        ELSE 'ExecuteDelete = 1: nur zuvor freigegebene Demo-Zeilen wurden entfernt.'
    END AS ExecutionModeNote,
    'Produktive Deletes sollten dieselbe Preview-Logik plus Transaktion, Backup und Monitoring verwenden.' AS SafetyNote;
