/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "ProcedureResultMetadataContract.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "23_StoredProcedures"

purpose: >
  Baut in tempdb eine didaktische Stored-Procedure samt Vertragsmetadaten auf
  und zeigt, wie Resultset-Shape, Output-Parameter und Returncodes als
  stabiler Procedure-Vertrag dokumentiert und geprueft werden koennen.

parameters:
  - name: "@CourseCode"
    sql_type: "NVARCHAR(20)"
    direction: "IN"
    required: false
    description: "Filtert die Demo-Prozedur auf einen Kurscode"
  - name: "@IncludeArchived"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = auch archivierte Demo-Laufprotokolle einbeziehen"
  - name: "@DropDemoObjects"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = Demo-Objekte am Ende wieder aus tempdb entfernen"

result_sets:
  - name: "ContractCatalog"
    description: "Didaktische Vertragsbeschreibung fuer Resultsets, Output-Parameter und Returncodes"
  - name: "ParameterMetadata"
    description: "Aus sys.parameters gelesene Parameter-Metadaten der Demo-Prozedur"
  - name: "FirstResultSetMetadata"
    description: "Ermitteltes Schema des ersten Resultsets via sys.dm_exec_describe_first_result_set"
  - name: "ExecutionPreview"
    description: "Beispielausfuehrung der Demo-Prozedur inklusive Output-Parameter und Returncode"

dependencies:
  - "tempdb"
  - "sys.schemas"
  - "sys.parameters"
  - "sys.types"
  - "sys.dm_exec_describe_first_result_set"
  - "CREATE OR ALTER PROCEDURE"

safety:
  level: "demo-write-tempdb"
  writes_data: true

documentation:
  markdown_file: "T-SQL/23_StoredProcedures/SQLScripts/ProcedureResultMetadataContract.md"
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
    description: "Erstversion des didaktischen Procedure-Contract-Labs fuer Resultset-Metadaten"

notes:
  - "Alle Demo-Objekte werden ausschliesslich in tempdb angelegt"
  - "Das Skript zeigt einen stabilen Procedure-Vertrag fuer ein erstes Resultset plus Output-Parameter und Returncode"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @CourseCode NVARCHAR(20) = N'DB100';
DECLARE @IncludeArchived BIT = 0;
DECLARE @DropDemoObjects BIT = 1;

IF NULLIF(LTRIM(RTRIM(@CourseCode)), N'') IS NULL
BEGIN
    THROW 50000, '@CourseCode darf nicht leer sein.', 1;
END;

IF @IncludeArchived NOT IN (0, 1)
BEGIN
    THROW 50001, '@IncludeArchived muss 0 oder 1 sein.', 1;
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

DROP PROCEDURE IF EXISTS demo.usp_ResultMetadataContractDemo;
DROP TABLE IF EXISTS demo.ProcedureContractCatalog;
DROP TABLE IF EXISTS demo.ProcedureExecutionLog;

CREATE TABLE demo.ProcedureContractCatalog
(
    ContractArea        NVARCHAR(40)  NOT NULL,
    ContractName        NVARCHAR(80)  NOT NULL,
    StabilityRule       NVARCHAR(200) NOT NULL,
    ConsumerExpectation NVARCHAR(200) NOT NULL
);

INSERT INTO demo.ProcedureContractCatalog
(
    ContractArea,
    ContractName,
    StabilityRule,
    ConsumerExpectation
)
VALUES
    (N'ResultSet', N'ExecutionRows', N'Spaltenreihenfolge und Datentypen bleiben stabil.', N'Clients koennen ein festes Mapping verwenden.'),
    (N'OutputParameter', N'@ExecutionState', N'Gibt Success, NoData oder ArchivedOnly zurueck.', N'Aufrufer koennen die Auswertung ohne zusaetzliches Parsen steuern.'),
    (N'ReturnCode', N'ReturnValue', N'0 bedeutet Erfolg, 10 signalisiert keine Treffer.', N'Batch-Aufrufer erhalten einen kompakten Statuscode.'),
    (N'Filter', N'@IncludeArchived', N'Archivierte Demo-Zeilen werden nur bei 1 zugelassen.', N'Das erste Resultset bleibt auch bei erweitertem Filter schema-stabil.');

CREATE TABLE demo.ProcedureExecutionLog
(
    ExecutionID    INT           NOT NULL PRIMARY KEY,
    CourseCode     NVARCHAR(20)  NOT NULL,
    StudentCount   INT           NOT NULL,
    ExecutionState NVARCHAR(30)  NOT NULL,
    IsArchived     BIT           NOT NULL,
    SnapshotDate   DATE          NOT NULL
);

INSERT INTO demo.ProcedureExecutionLog
(
    ExecutionID,
    CourseCode,
    StudentCount,
    ExecutionState,
    IsArchived,
    SnapshotDate
)
VALUES
    (101, N'DB100', 28, N'Published', 0, '2026-02-10'),
    (102, N'DB100', 27, N'Published', 0, '2026-03-05'),
    (103, N'DB100', 26, N'Archived',  1, '2025-11-20'),
    (201, N'ETL200', 19, N'Published', 0, '2026-02-15'),
    (202, N'ETL200', 18, N'Archived',  1, '2025-10-01'),
    (301, N'API310', 24, N'Published', 0, '2026-03-18');

EXEC sys.sp_executesql
N'
CREATE OR ALTER PROCEDURE demo.usp_ResultMetadataContractDemo
    @CourseCode NVARCHAR(20),
    @IncludeArchived BIT = 0,
    @ExecutionState NVARCHAR(30) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF NULLIF(LTRIM(RTRIM(@CourseCode)), N'''') IS NULL
    BEGIN
        THROW 51000, N''@CourseCode darf nicht leer sein.'', 1;
    END;

    IF @IncludeArchived NOT IN (0, 1)
    BEGIN
        THROW 51001, N''@IncludeArchived muss 0 oder 1 sein.'', 1;
    END;

    SELECT
        elog.ExecutionID,
        elog.CourseCode,
        elog.StudentCount,
        elog.ExecutionState,
        elog.IsArchived,
        elog.SnapshotDate
    FROM demo.ProcedureExecutionLog AS elog
    WHERE elog.CourseCode = @CourseCode
      AND (@IncludeArchived = 1 OR elog.IsArchived = 0)
    ORDER BY
        elog.SnapshotDate DESC,
        elog.ExecutionID DESC;

    IF EXISTS
    (
        SELECT 1
        FROM demo.ProcedureExecutionLog AS elog
        WHERE elog.CourseCode = @CourseCode
          AND (@IncludeArchived = 1 OR elog.IsArchived = 0)
    )
    BEGIN
        SELECT TOP (1)
            @ExecutionState =
                CASE
                    WHEN @IncludeArchived = 1 AND elog.IsArchived = 1 THEN N''ArchivedOnly''
                    ELSE N''Success''
                END
        FROM demo.ProcedureExecutionLog AS elog
        WHERE elog.CourseCode = @CourseCode
          AND (@IncludeArchived = 1 OR elog.IsArchived = 0)
        ORDER BY
            elog.SnapshotDate DESC,
            elog.ExecutionID DESC;

        RETURN 0;
    END;

    SET @ExecutionState = N''NoData'';
    RETURN 10;
END;
';

SELECT
    c.ContractArea,
    c.ContractName,
    c.StabilityRule,
    c.ConsumerExpectation
FROM demo.ProcedureContractCatalog AS c
ORDER BY
    c.ContractArea,
    c.ContractName;

SELECT
    p.parameter_id,
    p.name AS parameter_name,
    TYPE_NAME(p.user_type_id) AS parameter_type,
    p.max_length,
    p.is_output,
    p.has_default_value
FROM sys.parameters AS p
WHERE p.object_id = OBJECT_ID(N'demo.usp_ResultMetadataContractDemo')
ORDER BY
    p.parameter_id;

SELECT
    metadata.column_ordinal,
    metadata.name AS column_name,
    metadata.system_type_name,
    metadata.is_nullable,
    metadata.error_type_desc
FROM sys.dm_exec_describe_first_result_set
(
    N'EXEC demo.usp_ResultMetadataContractDemo @CourseCode = N''DB100'', @IncludeArchived = 0, @ExecutionState = NULL OUTPUT;',
    NULL,
    0
) AS metadata
ORDER BY
    metadata.column_ordinal;

DROP TABLE IF EXISTS #ExecutionPreview;

CREATE TABLE #ExecutionPreview
(
    ExecutionID    INT          NOT NULL,
    CourseCode     NVARCHAR(20) NOT NULL,
    StudentCount   INT          NOT NULL,
    ExecutionState NVARCHAR(30) NOT NULL,
    IsArchived     BIT          NOT NULL,
    SnapshotDate   DATE         NOT NULL
);

DECLARE @ExecutionState NVARCHAR(30);
DECLARE @ReturnCode INT;

INSERT INTO #ExecutionPreview
(
    ExecutionID,
    CourseCode,
    StudentCount,
    ExecutionState,
    IsArchived,
    SnapshotDate
)
EXEC @ReturnCode = demo.usp_ResultMetadataContractDemo
    @CourseCode = @CourseCode,
    @IncludeArchived = @IncludeArchived,
    @ExecutionState = @ExecutionState OUTPUT;

SELECT
    preview.ExecutionID,
    preview.CourseCode,
    preview.StudentCount,
    preview.ExecutionState,
    preview.IsArchived,
    preview.SnapshotDate,
    @ExecutionState AS OutputParameterState,
    @ReturnCode AS ReturnCode
FROM #ExecutionPreview AS preview
ORDER BY
    preview.SnapshotDate DESC,
    preview.ExecutionID DESC;

IF @DropDemoObjects = 1
BEGIN
    DROP PROCEDURE IF EXISTS demo.usp_ResultMetadataContractDemo;
    DROP TABLE IF EXISTS demo.ProcedureExecutionLog;
    DROP TABLE IF EXISTS demo.ProcedureContractCatalog;
END;
