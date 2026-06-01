/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "BridgeTableCoverageAudit.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "03_JOIN"
purpose: >
  Prueft eine didaktische n:m-Zwischentabelle auf fehlende, doppelte und
  unerwartete Zuordnungen zwischen erwarteten Paaren und tatsaechlichen
  Bridge-Eintraegen.
parameters:
  - name: "@CohortFilter"
    sql_type: "NVARCHAR(20)"
    direction: "IN"
    required: false
    description: "Optionaler Filter auf einen Jahrgang oder Kursblock"
  - name: "@OnlyIssues"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = nur auffaellige Zuordnungen zeigen, 0 = auch gesunde Erwartungen ausgeben"
  - name: "@IncludeUnexpectedAssignments"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zusaetzliches Resultset fuer reale, aber nicht erwartete Bridge-Zuordnungen ausgeben"
result_sets:
  - name: "BridgeCoverageAudit"
    description: "Detailpruefung erwarteter Paare mit Status missing, duplicate oder covered"
  - name: "BridgeCoverageSummary"
    description: "Zusammenfassung der auffaelligen und gesunden Zuordnungen je Jahrgang"
  - name: "UnexpectedAssignments"
    description: "Optionaler Report fuer reale Bridge-Zuordnungen ohne erwartetes Referenzpaar"
dependencies:
  - "tempdb"
  - "temp tables"
  - "CTE"
  - "FULL OUTER style audit via LEFT JOIN patterns"
safety:
  level: "read-only-tempdb"
  writes_data: false
documentation:
  markdown_file: "T-SQL/03_JOIN/SQLScripts/BridgeTableCoverageAudit.md"
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
    description: "Erstversion fuer die didaktische Bridge-Table-Coverage-Pruefung"
notes:
  - "Das Skript arbeitet ausschliesslich mit temp-Objekten und modelliert eine Trainingssituation im Kapitel JOIN."
  - "Missing und duplicate werden gegen eine explizite Erwartungsmenge geprueft, nicht gegen erfundene Produktionsregeln."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @CohortFilter NVARCHAR(20) = NULL;
DECLARE @OnlyIssues BIT = 1;
DECLARE @IncludeUnexpectedAssignments BIT = 1;

IF @OnlyIssues NOT IN (0, 1)
BEGIN
    THROW 50000, '@OnlyIssues muss 0 oder 1 sein.', 1;
END;

IF @IncludeUnexpectedAssignments NOT IN (0, 1)
BEGIN
    THROW 50000, '@IncludeUnexpectedAssignments muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #Students;
DROP TABLE IF EXISTS #Modules;
DROP TABLE IF EXISTS #ExpectedBridge;
DROP TABLE IF EXISTS #StudentModuleBridge;
DROP TABLE IF EXISTS #FilteredExpectedBridge;

CREATE TABLE #Students
(
    StudentID INT NOT NULL PRIMARY KEY,
    StudentName NVARCHAR(100) NOT NULL,
    CohortCode NVARCHAR(20) NOT NULL
);

CREATE TABLE #Modules
(
    ModuleID INT NOT NULL PRIMARY KEY,
    ModuleCode NVARCHAR(20) NOT NULL,
    ModuleName NVARCHAR(100) NOT NULL
);

CREATE TABLE #ExpectedBridge
(
    StudentID INT NOT NULL,
    ModuleID INT NOT NULL,
    ExpectationSource NVARCHAR(50) NOT NULL,
    CONSTRAINT PK_ExpectedBridge PRIMARY KEY (StudentID, ModuleID)
);

CREATE TABLE #StudentModuleBridge
(
    BridgeID INT NOT NULL PRIMARY KEY,
    StudentID INT NOT NULL,
    ModuleID INT NOT NULL,
    EnrollmentStatus NVARCHAR(20) NOT NULL,
    AssignedAt DATE NOT NULL
);

INSERT INTO #Students (StudentID, StudentName, CohortCode)
VALUES
    (101, N'Anna Berger', N'2026-A'),
    (102, N'Ben Krueger', N'2026-A'),
    (103, N'Clara Stein', N'2026-A'),
    (104, N'Denis Wolf', N'2026-B'),
    (105, N'Eva Kurz', N'2026-B');

INSERT INTO #Modules (ModuleID, ModuleCode, ModuleName)
VALUES
    (201, N'JOIN-101', N'JOIN Grundlagen'),
    (202, N'JOIN-201', N'OUTER JOIN Analyse'),
    (203, N'JOIN-301', N'Bridge Table Praxis');

INSERT INTO #ExpectedBridge (StudentID, ModuleID, ExpectationSource)
VALUES
    (101, 201, N'core-plan'),
    (101, 202, N'core-plan'),
    (102, 201, N'core-plan'),
    (102, 202, N'core-plan'),
    (103, 202, N'advanced-track'),
    (103, 203, N'advanced-track'),
    (104, 203, N'project-track'),
    (105, 201, N'catch-up');

INSERT INTO #StudentModuleBridge (BridgeID, StudentID, ModuleID, EnrollmentStatus, AssignedAt)
VALUES
    (1, 101, 201, N'active', '2026-04-01'),
    (2, 101, 202, N'active', '2026-04-01'),
    (3, 101, 202, N'active', '2026-04-02'),
    (4, 102, 201, N'active', '2026-04-01'),
    (5, 103, 202, N'active', '2026-04-03'),
    (6, 103, 203, N'active', '2026-04-03'),
    (7, 104, 203, N'active', '2026-04-04'),
    (8, 104, 203, N'waitlist', '2026-04-05'),
    (9, 101, 203, N'active', '2026-04-06');

SELECT
    eb.StudentID,
    eb.ModuleID,
    eb.ExpectationSource
INTO #FilteredExpectedBridge
FROM #ExpectedBridge AS eb
INNER JOIN #Students AS s
    ON s.StudentID = eb.StudentID
WHERE @CohortFilter IS NULL
   OR s.CohortCode = @CohortFilter;

;WITH ActualBridge AS
(
    SELECT
        smb.StudentID,
        smb.ModuleID,
        COUNT(*) AS ActualAssignmentCount,
        MIN(smb.AssignedAt) AS FirstAssignedAt,
        MAX(smb.AssignedAt) AS LastAssignedAt,
        STRING_AGG(smb.EnrollmentStatus, ', ')
            WITHIN GROUP (ORDER BY smb.AssignedAt, smb.BridgeID) AS StatusList
    FROM #StudentModuleBridge AS smb
    INNER JOIN #Students AS s
        ON s.StudentID = smb.StudentID
    WHERE @CohortFilter IS NULL
       OR s.CohortCode = @CohortFilter
    GROUP BY
        smb.StudentID,
        smb.ModuleID
),
CoverageAudit AS
(
    SELECT
        s.CohortCode,
        feb.StudentID,
        s.StudentName,
        feb.ModuleID,
        m.ModuleCode,
        m.ModuleName,
        feb.ExpectationSource,
        COALESCE(ab.ActualAssignmentCount, 0) AS ActualAssignmentCount,
        ab.FirstAssignedAt,
        ab.LastAssignedAt,
        COALESCE(ab.StatusList, N'(no assignment)') AS StatusList,
        CASE
            WHEN ab.StudentID IS NULL THEN 'missing'
            WHEN ab.ActualAssignmentCount > 1 THEN 'duplicate'
            ELSE 'covered'
        END AS CoverageStatus,
        CASE
            WHEN ab.StudentID IS NULL
                THEN 'Erwartete Zuordnung fehlt komplett in der Bridge-Tabelle.'
            WHEN ab.ActualAssignmentCount > 1
                THEN 'Erwartete Zuordnung ist mehrfach vorhanden und vermehrt den Join.'
            ELSE 'Erwartete Zuordnung ist genau einmal vorhanden.'
        END AS AuditMessage
    FROM #FilteredExpectedBridge AS feb
    INNER JOIN #Students AS s
        ON s.StudentID = feb.StudentID
    INNER JOIN #Modules AS m
        ON m.ModuleID = feb.ModuleID
    LEFT JOIN ActualBridge AS ab
        ON ab.StudentID = feb.StudentID
       AND ab.ModuleID = feb.ModuleID
),
UnexpectedAssignments AS
(
    SELECT
        s.CohortCode,
        ab.StudentID,
        s.StudentName,
        ab.ModuleID,
        m.ModuleCode,
        m.ModuleName,
        ab.ActualAssignmentCount,
        ab.FirstAssignedAt,
        ab.LastAssignedAt,
        ab.StatusList,
        'unexpected' AS CoverageStatus,
        'Reale Bridge-Zuordnung ist nicht in der erwarteten Referenzmenge enthalten.' AS AuditMessage
    FROM ActualBridge AS ab
    INNER JOIN #Students AS s
        ON s.StudentID = ab.StudentID
    INNER JOIN #Modules AS m
        ON m.ModuleID = ab.ModuleID
    LEFT JOIN #FilteredExpectedBridge AS feb
        ON feb.StudentID = ab.StudentID
       AND feb.ModuleID = ab.ModuleID
    WHERE feb.StudentID IS NULL
)
SELECT
    ca.CohortCode,
    ca.StudentID,
    ca.StudentName,
    ca.ModuleID,
    ca.ModuleCode,
    ca.ModuleName,
    ca.ExpectationSource,
    ca.ActualAssignmentCount,
    ca.FirstAssignedAt,
    ca.LastAssignedAt,
    ca.StatusList,
    ca.CoverageStatus,
    ca.AuditMessage
FROM CoverageAudit AS ca
WHERE @OnlyIssues = 0
   OR ca.CoverageStatus <> 'covered'
ORDER BY
    CASE ca.CoverageStatus
        WHEN 'missing' THEN 1
        WHEN 'duplicate' THEN 2
        ELSE 3
    END,
    ca.CohortCode,
    ca.StudentID,
    ca.ModuleID;

SELECT
    ca.CohortCode,
    ca.CoverageStatus,
    COUNT(*) AS PairCount,
    SUM(ca.ActualAssignmentCount) AS TotalBridgeRows,
    SUM(CASE WHEN ca.CoverageStatus = 'duplicate' THEN ca.ActualAssignmentCount - 1 ELSE 0 END) AS ExtraRowsBeyondExpected
FROM CoverageAudit AS ca
GROUP BY
    ca.CohortCode,
    ca.CoverageStatus
ORDER BY
    ca.CohortCode,
    CASE ca.CoverageStatus
        WHEN 'missing' THEN 1
        WHEN 'duplicate' THEN 2
        ELSE 3
    END;

IF @IncludeUnexpectedAssignments = 1
BEGIN
    SELECT
        ua.CohortCode,
        ua.StudentID,
        ua.StudentName,
        ua.ModuleID,
        ua.ModuleCode,
        ua.ModuleName,
        ua.ActualAssignmentCount,
        ua.FirstAssignedAt,
        ua.LastAssignedAt,
        ua.StatusList,
        ua.CoverageStatus,
        ua.AuditMessage
    FROM UnexpectedAssignments AS ua
    ORDER BY
        ua.CohortCode,
        ua.StudentID,
        ua.ModuleID;
END;
