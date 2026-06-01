/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "ProcedureResultShapeSmokeTest.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "23_StoredProcedures"

purpose: >
  Baut in tempdb mehrere Demo-Prozeduren auf und prueft ueber Metadaten,
  ob deren erstes Resultset die erwarteten Spalten, Datentypen und
  Nullable-Eigenschaften unveraendert liefert.

parameters:
  - name: "@ProcedureNameLike"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Optionales LIKE-Muster fuer die zu pruefenden Demo-Prozeduren"
  - name: "@IncludeDefinitionPreview"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zeigt zusaetzlich die registrierten Demo-Prozeduren mit Kurzbeschreibung"
  - name: "@DropDemoObjects"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = entfernt Demo-Tabellen und Demo-Prozeduren am Ende wieder aus tempdb"

result_sets:
  - name: "RegisteredProcedures"
    description: "Optionaler Ueberblick ueber die fuer den Smoke Test registrierten Demo-Prozeduren"
  - name: "ExpectedColumnCatalog"
    description: "Erwartete Resultset-Spalten je Demo-Prozedur"
  - name: "ActualColumnMetadata"
    description: "Tatsaechliche Metadaten des ersten Resultsets je Demo-Prozedur"
  - name: "SmokeSummary"
    description: "Verdichtetes Smoke-Test-Ergebnis je Demo-Prozedur"
  - name: "SmokeFindings"
    description: "Detaillierter Vergleich zwischen erwarteten und tatsaechlichen Spalten"

dependencies:
  - "tempdb"
  - "sys.schemas"
  - "sys.procedures"
  - "sys.dm_exec_describe_first_result_set_for_object"
  - "CREATE OR ALTER PROCEDURE"

safety:
  level: "demo-write-tempdb"
  writes_data: true

documentation:
  markdown_file: "T-SQL/23_StoredProcedures/SQLScripts/ProcedureResultShapeSmokeTest.md"
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
    description: "Erstversion des tempdb-Labs fuer Metadaten-basierte Resultset-Smoke-Tests"

notes:
  - "Alle Demo-Objekte werden ausschliesslich in tempdb angelegt"
  - "Geprueft wird bewusst nur das erste Resultset je Procedure"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @ProcedureNameLike SYSNAME = N'usp_ResultShapeSmoke%';
DECLARE @IncludeDefinitionPreview BIT = 1;
DECLARE @DropDemoObjects BIT = 1;

IF NULLIF(LTRIM(RTRIM(@ProcedureNameLike)), N'') IS NULL
BEGIN
    THROW 50000, '@ProcedureNameLike darf nicht leer sein.', 1;
END;

IF @IncludeDefinitionPreview NOT IN (0, 1)
BEGIN
    THROW 50001, '@IncludeDefinitionPreview muss 0 oder 1 sein.', 1;
END;

IF @DropDemoObjects NOT IN (0, 1)
BEGIN
    THROW 50002, '@DropDemoObjects muss 0 oder 1 sein.', 1;
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

DROP PROCEDURE IF EXISTS demo.usp_ResultShapeSmokeAtRisk;
DROP PROCEDURE IF EXISTS demo.usp_ResultShapeSmokeCertification;
DROP PROCEDURE IF EXISTS demo.usp_ResultShapeSmokeModuleSummary;

DROP TABLE IF EXISTS demo.ProcedureShapeSmokeLearners;
DROP TABLE IF EXISTS demo.ProcedureShapeSmokeModules;

CREATE TABLE demo.ProcedureShapeSmokeModules
(
    ModuleCode     NVARCHAR(20)  NOT NULL PRIMARY KEY,
    ModuleTitle    NVARCHAR(80)  NOT NULL,
    TrackName      NVARCHAR(60)  NOT NULL,
    DeliveryMode   NVARCHAR(20)  NOT NULL
);

CREATE TABLE demo.ProcedureShapeSmokeLearners
(
    LearnerID           INT            NOT NULL PRIMARY KEY,
    LearnerName         NVARCHAR(80)   NOT NULL,
    ModuleCode          NVARCHAR(20)   NOT NULL,
    CompletionPct       DECIMAL(5,2)   NOT NULL,
    IsCertified         BIT            NOT NULL,
    CertificationDate   DATE           NULL,
    SnapshotMonth       DATE           NOT NULL,
    RiskLevel           NVARCHAR(20)   NOT NULL,
    CONSTRAINT FK_ProcedureShapeSmokeLearners_Module
        FOREIGN KEY (ModuleCode) REFERENCES demo.ProcedureShapeSmokeModules (ModuleCode)
);

INSERT INTO demo.ProcedureShapeSmokeModules
(
    ModuleCode,
    ModuleTitle,
    TrackName,
    DeliveryMode
)
VALUES
    (N'DB100', N'Relationen und Normalisierung', N'Database Basics', N'Onsite'),
    (N'API210', N'Procedure Contracts', N'Backend APIs', N'Hybrid'),
    (N'ETL300', N'Batch Monitoring', N'Data Engineering', N'Remote');

INSERT INTO demo.ProcedureShapeSmokeLearners
(
    LearnerID,
    LearnerName,
    ModuleCode,
    CompletionPct,
    IsCertified,
    CertificationDate,
    SnapshotMonth,
    RiskLevel
)
VALUES
    (1001, N'Anna Berger',  N'DB100',  92.50, 1, '2026-03-10', '2026-03-01', N'low'),
    (1002, N'Boris Klein',  N'DB100',  61.00, 0, NULL,         '2026-03-01', N'medium'),
    (2001, N'Clara Nguyen', N'API210', 84.00, 1, '2026-03-12', '2026-03-01', N'low'),
    (2002, N'David Falk',   N'API210', 47.50, 0, NULL,         '2026-03-01', N'high'),
    (3001, N'Elena Maurer', N'ETL300', 73.00, 0, NULL,         '2026-03-01', N'medium'),
    (3002, N'Farid Osman',  N'ETL300', 38.00, 0, NULL,         '2026-03-01', N'high');

EXEC(N'
CREATE OR ALTER PROCEDURE demo.usp_ResultShapeSmokeModuleSummary
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        m.ModuleCode,
        m.ModuleTitle,
        ParticipantCount = COUNT_BIG(*),
        AverageCompletionPct = ISNULL(CAST(AVG(l.CompletionPct) AS DECIMAL(5,2)), CONVERT(DECIMAL(5,2), 0.00)),
        CertifiedCount = ISNULL(SUM(CASE WHEN l.IsCertified = 1 THEN 1 ELSE 0 END), 0)
    FROM demo.ProcedureShapeSmokeModules AS m
    INNER JOIN demo.ProcedureShapeSmokeLearners AS l
        ON l.ModuleCode = m.ModuleCode
    GROUP BY
        m.ModuleCode,
        m.ModuleTitle
    ORDER BY
        m.ModuleCode;
END;');

EXEC(N'
CREATE OR ALTER PROCEDURE demo.usp_ResultShapeSmokeCertification
    @CertifiedOnly BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF @CertifiedOnly NOT IN (0, 1)
    BEGIN
        THROW 51010, N''@CertifiedOnly muss 0 oder 1 sein.'', 1;
    END;

    SELECT
        l.LearnerID,
        l.LearnerName,
        l.ModuleCode,
        l.IsCertified,
        l.CertificationDate
    FROM demo.ProcedureShapeSmokeLearners AS l
    WHERE @CertifiedOnly = 0
       OR l.IsCertified = 1
    ORDER BY
        l.ModuleCode,
        l.LearnerID;
END;');

EXEC(N'
CREATE OR ALTER PROCEDURE demo.usp_ResultShapeSmokeAtRisk
    @MinimumCompletionPct DECIMAL(5,2) = 60.00
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        l.LearnerID,
        l.LearnerName,
        l.ModuleCode,
        l.CompletionPct,
        l.RiskLevel,
        l.SnapshotMonth
    FROM demo.ProcedureShapeSmokeLearners AS l
    WHERE l.CompletionPct < @MinimumCompletionPct
    ORDER BY
        l.CompletionPct,
        l.LearnerID;
END;');

DROP TABLE IF EXISTS #ProcedureCatalog;
DROP TABLE IF EXISTS #ExpectedColumns;
DROP TABLE IF EXISTS #ActualColumns;
DROP TABLE IF EXISTS #SmokeFindings;

CREATE TABLE #ProcedureCatalog
(
    ProcedureName        SYSNAME        NOT NULL PRIMARY KEY,
    ObjectID             INT            NOT NULL,
    ProcedureDescription NVARCHAR(200)  NOT NULL
);

CREATE TABLE #ExpectedColumns
(
    ProcedureName      SYSNAME         NOT NULL,
    ColumnOrdinal      INT             NOT NULL,
    ColumnName         SYSNAME         NOT NULL,
    ExpectedType       NVARCHAR(128)   NOT NULL,
    ExpectedNullable   BIT             NOT NULL,
    WhyItMatters       NVARCHAR(200)   NOT NULL
);

CREATE TABLE #ActualColumns
(
    ProcedureName      SYSNAME         NOT NULL,
    ColumnOrdinal      INT             NULL,
    ColumnName         SYSNAME         NULL,
    ActualType         NVARCHAR(256)   NULL,
    ActualNullable     BIT             NULL,
    ErrorTypeDesc      NVARCHAR(60)    NULL,
    ErrorMessage       NVARCHAR(4000)  NULL
);

CREATE TABLE #SmokeFindings
(
    ProcedureName      SYSNAME         NOT NULL,
    ColumnOrdinal      INT             NOT NULL,
    ExpectedColumn     SYSNAME         NULL,
    ActualColumn       SYSNAME         NULL,
    ExpectedType       NVARCHAR(128)   NULL,
    ActualType         NVARCHAR(256)   NULL,
    ExpectedNullable   BIT             NULL,
    ActualNullable     BIT             NULL,
    FindingStatus      NVARCHAR(40)    NOT NULL,
    FindingDetail      NVARCHAR(240)   NOT NULL
);

INSERT INTO #ProcedureCatalog
(
    ProcedureName,
    ObjectID,
    ProcedureDescription
)
SELECT
    p.name,
    p.object_id,
    CASE p.name
        WHEN N'usp_ResultShapeSmokeModuleSummary' THEN N'Aggregiert Module zu einer kompakten Summary-Form.'
        WHEN N'usp_ResultShapeSmokeCertification' THEN N'Liefert einen stabilen Zertifizierungs-Status pro Lernenden.'
        WHEN N'usp_ResultShapeSmokeAtRisk' THEN N'Kennzeichnet Teilnehmer unterhalb einer Schwellwert-Completion.'
        ELSE N'Demo-Procedure fuer den Resultset-Smoke-Test.'
    END AS ProcedureDescription
FROM sys.procedures AS p
INNER JOIN sys.schemas AS s
    ON s.schema_id = p.schema_id
WHERE s.name = N'demo'
  AND p.name LIKE @ProcedureNameLike
ORDER BY
    p.name;

IF NOT EXISTS
(
    SELECT 1
    FROM #ProcedureCatalog
)
BEGIN
    THROW 50003, 'Keine Demo-Prozeduren fuer das angegebene Muster gefunden.', 1;
END;

INSERT INTO #ExpectedColumns
(
    ProcedureName,
    ColumnOrdinal,
    ColumnName,
    ExpectedType,
    ExpectedNullable,
    WhyItMatters
)
VALUES
    (N'usp_ResultShapeSmokeAtRisk',         1, N'LearnerID',            N'int',            0, N'Primarschluessel fuer den Teilnehmer bleibt an Position 1.'),
    (N'usp_ResultShapeSmokeAtRisk',         2, N'LearnerName',          N'nvarchar(80)',   0, N'Lesbarer Teilnehmername bleibt fuer Reviews sichtbar.'),
    (N'usp_ResultShapeSmokeAtRisk',         3, N'ModuleCode',           N'nvarchar(20)',   0, N'Modulbezug bleibt fuer Eskalationen erhalten.'),
    (N'usp_ResultShapeSmokeAtRisk',         4, N'CompletionPct',        N'decimal(5,2)',   0, N'Der kritische Kennwert muss numerisch stabil bleiben.'),
    (N'usp_ResultShapeSmokeAtRisk',         5, N'RiskLevel',            N'nvarchar(20)',   0, N'Risikostufe soll als lesbares Signal erhalten bleiben.'),
    (N'usp_ResultShapeSmokeAtRisk',         6, N'SnapshotMonth',        N'date',           0, N'Die Bezugsperiode ist Teil des operativen Kontextes.'),
    (N'usp_ResultShapeSmokeCertification',  1, N'LearnerID',            N'int',            0, N'Teilnehmerkennung muss fuer Folgeschritte stabil bleiben.'),
    (N'usp_ResultShapeSmokeCertification',  2, N'LearnerName',          N'nvarchar(80)',   0, N'Der Name bleibt fuer Lesbarkeit und Freigaben enthalten.'),
    (N'usp_ResultShapeSmokeCertification',  3, N'ModuleCode',           N'nvarchar(20)',   0, N'Modulkontext darf im Resultset nicht verloren gehen.'),
    (N'usp_ResultShapeSmokeCertification',  4, N'IsCertified',          N'bit',            0, N'Der Zertifizierungsstatus ist das zentrale Ja/Nein-Signal.'),
    (N'usp_ResultShapeSmokeCertification',  5, N'CertificationDate',    N'date',           1, N'Das Datum bleibt nullable, weil nicht alle Lernenden zertifiziert sind.'),
    (N'usp_ResultShapeSmokeModuleSummary',  1, N'ModuleCode',           N'nvarchar(20)',   0, N'Der Aggregatkontext beginnt mit dem Modulcode.'),
    (N'usp_ResultShapeSmokeModuleSummary',  2, N'ModuleTitle',          N'nvarchar(80)',   0, N'Der lesbare Modultitel bleibt fuer Reports sichtbar.'),
    (N'usp_ResultShapeSmokeModuleSummary',  3, N'ParticipantCount',     N'bigint',         0, N'COUNT_BIG liefert absichtlich bigint statt int.'),
    (N'usp_ResultShapeSmokeModuleSummary',  4, N'AverageCompletionPct', N'decimal(5,2)',   0, N'Durchschnittswerte sollen als decimal dokumentiert bleiben.'),
    (N'usp_ResultShapeSmokeModuleSummary',  5, N'CertifiedCount',       N'int',            0, N'Die Anzahl zertifizierter Teilnehmer bleibt als numerischer Zaehlwert erhalten.');

INSERT INTO #ActualColumns
(
    ProcedureName,
    ColumnOrdinal,
    ColumnName,
    ActualType,
    ActualNullable,
    ErrorTypeDesc,
    ErrorMessage
)
SELECT
    pc.ProcedureName,
    rs.column_ordinal,
    rs.name,
    rs.system_type_name,
    rs.is_nullable,
    rs.error_type_desc,
    rs.error_message
FROM #ProcedureCatalog AS pc
CROSS APPLY sys.dm_exec_describe_first_result_set_for_object(pc.ObjectID, 0) AS rs;

INSERT INTO #SmokeFindings
(
    ProcedureName,
    ColumnOrdinal,
    ExpectedColumn,
    ActualColumn,
    ExpectedType,
    ActualType,
    ExpectedNullable,
    ActualNullable,
    FindingStatus,
    FindingDetail
)
SELECT
    COALESCE(ec.ProcedureName, ac.ProcedureName) AS ProcedureName,
    COALESCE(ec.ColumnOrdinal, ac.ColumnOrdinal, 0) AS ColumnOrdinal,
    ec.ColumnName AS ExpectedColumn,
    ac.ColumnName AS ActualColumn,
    ec.ExpectedType,
    ac.ActualType,
    ec.ExpectedNullable,
    ac.ActualNullable,
    CASE
        WHEN ac.ErrorTypeDesc IS NOT NULL THEN N'metadata_error'
        WHEN ec.ColumnName IS NULL THEN N'unexpected_column'
        WHEN ac.ColumnName IS NULL THEN N'missing_column'
        WHEN ec.ColumnName <> ac.ColumnName THEN N'column_name_mismatch'
        WHEN LOWER(ec.ExpectedType) <> LOWER(ac.ActualType) THEN N'type_mismatch'
        WHEN ec.ExpectedNullable <> ac.ActualNullable THEN N'nullability_mismatch'
        ELSE N'match'
    END AS FindingStatus,
    CASE
        WHEN ac.ErrorTypeDesc IS NOT NULL THEN N'Die Metadatenfunktion meldet einen Fehler fuer diese Procedure.'
        WHEN ec.ColumnName IS NULL THEN N'Die Procedure liefert eine unerwartete Zusatzspalte.'
        WHEN ac.ColumnName IS NULL THEN N'Eine erwartete Spalte fehlt im ersten Resultset.'
        WHEN ec.ColumnName <> ac.ColumnName THEN N'Der Spaltenname an dieser Position weicht vom Vertrag ab.'
        WHEN LOWER(ec.ExpectedType) <> LOWER(ac.ActualType) THEN N'Der Datentyp stimmt nicht mit dem dokumentierten Vertrag ueberein.'
        WHEN ec.ExpectedNullable <> ac.ActualNullable THEN N'Die Nullable-Eigenschaft weicht vom Vertrag ab.'
        ELSE N'Die Spalte entspricht dem erwarteten Resultset-Vertrag.'
    END AS FindingDetail
FROM #ExpectedColumns AS ec
FULL OUTER JOIN #ActualColumns AS ac
    ON ac.ProcedureName = ec.ProcedureName
   AND ac.ColumnOrdinal = ec.ColumnOrdinal;

IF @IncludeDefinitionPreview = 1
BEGIN
    SELECT
        pc.ProcedureName,
        pc.ObjectID,
        pc.ProcedureDescription
    FROM #ProcedureCatalog AS pc
    ORDER BY
        pc.ProcedureName;
END;

SELECT
    ec.ProcedureName,
    ec.ColumnOrdinal,
    ec.ColumnName,
    ec.ExpectedType,
    ec.ExpectedNullable,
    ec.WhyItMatters
FROM #ExpectedColumns AS ec
ORDER BY
    ec.ProcedureName,
    ec.ColumnOrdinal;

SELECT
    ac.ProcedureName,
    ac.ColumnOrdinal,
    ac.ColumnName,
    ac.ActualType,
    ac.ActualNullable,
    ac.ErrorTypeDesc,
    ac.ErrorMessage
FROM #ActualColumns AS ac
ORDER BY
    ac.ProcedureName,
    ac.ColumnOrdinal;

SELECT
    sf.ProcedureName,
    CheckedColumns = COUNT(*),
    MatchingColumns = SUM(CASE WHEN sf.FindingStatus = N'match' THEN 1 ELSE 0 END),
    NonMatchingColumns = SUM(CASE WHEN sf.FindingStatus <> N'match' THEN 1 ELSE 0 END),
    SmokeStatus =
        CASE
            WHEN SUM(CASE WHEN sf.FindingStatus = N'metadata_error' THEN 1 ELSE 0 END) > 0 THEN N'metadata_error'
            WHEN SUM(CASE WHEN sf.FindingStatus <> N'match' THEN 1 ELSE 0 END) > 0 THEN N'needs_review'
            ELSE N'pass'
        END
FROM #SmokeFindings AS sf
GROUP BY
    sf.ProcedureName
ORDER BY
    sf.ProcedureName;

SELECT
    sf.ProcedureName,
    sf.ColumnOrdinal,
    sf.ExpectedColumn,
    sf.ActualColumn,
    sf.ExpectedType,
    sf.ActualType,
    sf.ExpectedNullable,
    sf.ActualNullable,
    sf.FindingStatus,
    sf.FindingDetail
FROM #SmokeFindings AS sf
ORDER BY
    sf.ProcedureName,
    sf.ColumnOrdinal;

IF @DropDemoObjects = 1
BEGIN
    DROP PROCEDURE IF EXISTS demo.usp_ResultShapeSmokeAtRisk;
    DROP PROCEDURE IF EXISTS demo.usp_ResultShapeSmokeCertification;
    DROP PROCEDURE IF EXISTS demo.usp_ResultShapeSmokeModuleSummary;
    DROP TABLE IF EXISTS demo.ProcedureShapeSmokeLearners;
    DROP TABLE IF EXISTS demo.ProcedureShapeSmokeModules;
END;
