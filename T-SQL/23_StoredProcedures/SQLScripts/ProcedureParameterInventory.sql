/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "ProcedureParameterInventory.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "23_StoredProcedures"

purpose: >
  Baut in tempdb mehrere Demo-Prozeduren mit unterschiedlichen Parameterlisten
  auf und erstellt daraus ein Inventar ueber Datentypen, Richtungen,
  Katalogmerkmale und textuell erkannte Default-Ausdruecke.

parameters:
  - name: "@ProcedureNamePattern"
    sql_type: "NVARCHAR(128)"
    direction: "IN"
    required: false
    description: "LIKE-Filter fuer die zu inventarisierenden Demo-Prozeduren"
  - name: "@IncludeDemoOnly"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = nur Demo-Prozeduren im Schema demo beruecksichtigen"
  - name: "@DropDemoObjects"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = Demo-Prozeduren und Demo-Tabelle am Ende wieder aus tempdb entfernen"

result_sets:
  - name: "ProcedureInventorySummary"
    description: "Verdichtete Kennzahlen je inventarisierter Procedure"
  - name: "ProcedureParameterInventory"
    description: "Detailliertes Parameterinventar inklusive Richtung, Typ und Default-Hinweisen"
  - name: "InventoryNotes"
    description: "Didaktische Hinweise zur Interpretation von Parameter-Metadaten"

dependencies:
  - "tempdb"
  - "sys.schemas"
  - "sys.procedures"
  - "sys.parameters"
  - "sys.types"
  - "sys.sql_modules"
  - "CREATE OR ALTER PROCEDURE"

safety:
  level: "demo-write-tempdb"
  writes_data: true

documentation:
  markdown_file: "T-SQL/23_StoredProcedures/SQLScripts/ProcedureParameterInventory.md"
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
    description: "Erstversion des didaktischen Parameter-Inventars fuer Stored Procedures"

notes:
  - "Alle Demo-Objekte werden ausschliesslich in tempdb angelegt"
  - "Default-Ausdruecke werden aus dem Procedure-Text abgeleitet, damit T-SQL-Defaults sichtbar bleiben"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @ProcedureNamePattern NVARCHAR(128) = N'usp_Param%';
DECLARE @IncludeDemoOnly BIT = 1;
DECLARE @DropDemoObjects BIT = 1;

IF NULLIF(LTRIM(RTRIM(@ProcedureNamePattern)), N'') IS NULL
BEGIN
    THROW 50000, '@ProcedureNamePattern darf nicht leer sein.', 1;
END;

IF @IncludeDemoOnly NOT IN (0, 1)
BEGIN
    THROW 50001, '@IncludeDemoOnly muss 0 oder 1 sein.', 1;
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

DROP PROCEDURE IF EXISTS demo.usp_ParamEnrollmentWindow;
DROP PROCEDURE IF EXISTS demo.usp_ParamRetentionAlert;
DROP PROCEDURE IF EXISTS demo.usp_ParamRosterSlice;
DROP TABLE IF EXISTS demo.ProcedureParameterSample;

CREATE TABLE demo.ProcedureParameterSample
(
    EnrollmentID        INT           NOT NULL PRIMARY KEY,
    CourseCode          NVARCHAR(20)  NOT NULL,
    TermCode            NVARCHAR(20)  NOT NULL,
    StudentCount        INT           NOT NULL,
    CompletionRate      DECIMAL(5,2)  NOT NULL,
    IsArchived          BIT           NOT NULL,
    LastReviewDate      DATE          NOT NULL
);

INSERT INTO demo.ProcedureParameterSample
(
    EnrollmentID,
    CourseCode,
    TermCode,
    StudentCount,
    CompletionRate,
    IsArchived,
    LastReviewDate
)
VALUES
    (101, N'DB100',  N'2026Q1', 28, 92.50, 0, '2026-03-05'),
    (102, N'DB100',  N'2026Q2', 31, 88.10, 0, '2026-04-12'),
    (103, N'DB100',  N'2025Q4', 26, 81.40, 1, '2025-12-18'),
    (201, N'ETL200', N'2026Q1', 19, 86.75, 0, '2026-03-20'),
    (202, N'ETL200', N'2026Q2', 22, 79.20, 0, '2026-04-10'),
    (301, N'API310', N'2026Q1', 24, 95.00, 0, '2026-03-28');

EXEC sys.sp_executesql
N'
CREATE OR ALTER PROCEDURE demo.usp_ParamEnrollmentWindow
    @CourseCode NVARCHAR(20) = N''DB100'',
    @TermCode NVARCHAR(20) = N''2026Q2'',
    @IncludeArchived BIT = 0,
    @RowsReturned INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        sample.EnrollmentID,
        sample.CourseCode,
        sample.TermCode,
        sample.StudentCount,
        sample.LastReviewDate
    FROM demo.ProcedureParameterSample AS sample
    WHERE sample.CourseCode = @CourseCode
      AND sample.TermCode = @TermCode
      AND (@IncludeArchived = 1 OR sample.IsArchived = 0)
    ORDER BY
        sample.LastReviewDate DESC,
        sample.EnrollmentID;

    SET @RowsReturned = @@ROWCOUNT;
END;
';

EXEC sys.sp_executesql
N'
CREATE OR ALTER PROCEDURE demo.usp_ParamRetentionAlert
    @MinimumCompletionRate DECIMAL(5,2) = 85.00,
    @SinceDate DATE = ''2026-01-01'',
    @Reviewer SYSNAME = N''quality-bot'',
    @AlertCount INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        sample.CourseCode,
        sample.TermCode,
        sample.CompletionRate,
        sample.LastReviewDate,
        Reviewer = @Reviewer
    FROM demo.ProcedureParameterSample AS sample
    WHERE sample.CompletionRate < @MinimumCompletionRate
      AND sample.LastReviewDate >= @SinceDate
    ORDER BY
        sample.CompletionRate,
        sample.LastReviewDate DESC;

    SET @AlertCount = @@ROWCOUNT;
END;
';

EXEC sys.sp_executesql
N'
CREATE OR ALTER PROCEDURE demo.usp_ParamRosterSlice
    @CourseCode NVARCHAR(20),
    @OffsetRows INT = 0,
    @FetchRows INT = 5,
    @SortDirection NVARCHAR(4) = N''ASC''
AS
BEGIN
    SET NOCOUNT ON;

    IF @SortDirection = N''DESC''
    BEGIN
        SELECT
            sample.EnrollmentID,
            sample.CourseCode,
            sample.TermCode,
            sample.StudentCount
        FROM demo.ProcedureParameterSample AS sample
        WHERE sample.CourseCode = @CourseCode
        ORDER BY
            sample.StudentCount DESC,
            sample.EnrollmentID DESC
        OFFSET @OffsetRows ROWS
        FETCH NEXT @FetchRows ROWS ONLY;

        RETURN;
    END;

    SELECT
        sample.EnrollmentID,
        sample.CourseCode,
        sample.TermCode,
        sample.StudentCount
    FROM demo.ProcedureParameterSample AS sample
    WHERE sample.CourseCode = @CourseCode
    ORDER BY
        sample.StudentCount ASC,
        sample.EnrollmentID ASC
    OFFSET @OffsetRows ROWS
    FETCH NEXT @FetchRows ROWS ONLY;
END;
';

DROP TABLE IF EXISTS #TargetProcedures;
DROP TABLE IF EXISTS #ProcedureParameterInventory;

CREATE TABLE #TargetProcedures
(
    object_id          INT            NOT NULL PRIMARY KEY,
    ProcedureName      NVARCHAR(256)  NOT NULL,
    schema_name        SYSNAME        NOT NULL,
    procedure_name     SYSNAME        NOT NULL,
    module_definition  NVARCHAR(MAX)  NULL
);

INSERT INTO #TargetProcedures
(
    object_id,
    ProcedureName,
    schema_name,
    procedure_name,
    module_definition
)
SELECT
    proc.object_id,
    CONCAT(sch.name, N'.', proc.name) AS ProcedureName,
    sch.name AS schema_name,
    proc.name AS procedure_name,
    module.definition
FROM sys.procedures AS proc
INNER JOIN sys.schemas AS sch
    ON proc.schema_id = sch.schema_id
LEFT JOIN sys.sql_modules AS module
    ON proc.object_id = module.object_id
WHERE proc.name LIKE @ProcedureNamePattern
  AND (@IncludeDemoOnly = 0 OR sch.name = N'demo');

CREATE TABLE #ProcedureParameterInventory
(
    ProcedureName            NVARCHAR(256)  NOT NULL,
    parameter_id             INT            NOT NULL,
    ParameterName            SYSNAME        NOT NULL,
    ParameterDirection       NVARCHAR(10)   NOT NULL,
    ParameterType            NVARCHAR(128)  NOT NULL,
    TypeDetail               NVARCHAR(128)  NOT NULL,
    max_length               SMALLINT       NOT NULL,
    precision_value          TINYINT        NOT NULL,
    scale_value              TINYINT        NOT NULL,
    IsOutput                 BIT            NOT NULL,
    CatalogHasDefault        BIT            NOT NULL,
    HasDefaultExpression     BIT            NOT NULL,
    DefaultExpression        NVARCHAR(200)  NULL,
    ParameterDeclaration     NVARCHAR(300)  NULL
);

INSERT INTO #ProcedureParameterInventory
(
    ProcedureName,
    parameter_id,
    ParameterName,
    ParameterDirection,
    ParameterType,
    TypeDetail,
    max_length,
    precision_value,
    scale_value,
    IsOutput,
    CatalogHasDefault,
    HasDefaultExpression,
    DefaultExpression,
    ParameterDeclaration
)
SELECT
    tp.ProcedureName,
    p.parameter_id,
    p.name AS ParameterName,
    CASE
        WHEN p.is_output = 1 THEN N'INOUT'
        ELSE N'IN'
    END AS ParameterDirection,
    type_name = TYPE_NAME(p.user_type_id),
    TypeDetail =
        CASE
            WHEN TYPE_NAME(p.user_type_id) IN (N'nchar', N'nvarchar')
                THEN CONCAT(TYPE_NAME(p.user_type_id), N'(', CASE WHEN p.max_length = -1 THEN N'MAX' ELSE CONVERT(NVARCHAR(10), p.max_length / 2) END, N')')
            WHEN TYPE_NAME(p.user_type_id) IN (N'char', N'varchar', N'binary', N'varbinary')
                THEN CONCAT(TYPE_NAME(p.user_type_id), N'(', CASE WHEN p.max_length = -1 THEN N'MAX' ELSE CONVERT(NVARCHAR(10), p.max_length) END, N')')
            WHEN TYPE_NAME(p.user_type_id) IN (N'decimal', N'numeric')
                THEN CONCAT(TYPE_NAME(p.user_type_id), N'(', CONVERT(NVARCHAR(10), p.precision), N',', CONVERT(NVARCHAR(10), p.scale), N')')
            WHEN TYPE_NAME(p.user_type_id) IN (N'datetime2', N'datetimeoffset', N'time')
                THEN CONCAT(TYPE_NAME(p.user_type_id), N'(', CONVERT(NVARCHAR(10), p.scale), N')')
            ELSE TYPE_NAME(p.user_type_id)
        END,
    p.max_length,
    p.precision,
    p.scale,
    p.is_output,
    p.has_default_value,
    HasDefaultExpression =
        CAST
        (
            CASE
                WHEN decl.ParameterDeclaration LIKE N'%=%' THEN 1
                ELSE 0
            END
            AS BIT
        ),
    DefaultExpression =
        CASE
            WHEN decl.ParameterDeclaration LIKE N'%=%'
                THEN NULLIF
                (
                    LTRIM(RTRIM(REPLACE(SUBSTRING(decl.ParameterDeclaration, CHARINDEX(N'=', decl.ParameterDeclaration) + 1, 200), N' OUTPUT', N''))),
                    N''
                )
            ELSE NULL
        END,
    decl.ParameterDeclaration
FROM #TargetProcedures AS tp
INNER JOIN sys.parameters AS p
    ON tp.object_id = p.object_id
OUTER APPLY
(
    SELECT ParameterStart = NULLIF(CHARINDEX(p.name, tp.module_definition), 0)
) AS pos
OUTER APPLY
(
    SELECT ParameterDeclaration =
        CASE
            WHEN pos.ParameterStart IS NULL THEN NULL
            ELSE LTRIM(RTRIM(REPLACE(REPLACE(
                SUBSTRING
                (
                    tp.module_definition,
                    pos.ParameterStart,
                    CASE
                        WHEN CHARINDEX(CHAR(10), tp.module_definition + CHAR(10), pos.ParameterStart) > pos.ParameterStart
                            THEN CHARINDEX(CHAR(10), tp.module_definition + CHAR(10), pos.ParameterStart) - pos.ParameterStart
                        ELSE 200
                    END
                ),
                CHAR(13),
                N''
            ), N',', N'')))
        END
) AS decl;

SELECT
    inventory.ProcedureName,
    TotalParameters = COUNT(*),
    InputParameters = SUM(CASE WHEN inventory.IsOutput = 0 THEN 1 ELSE 0 END),
    OutputParameters = SUM(CASE WHEN inventory.IsOutput = 1 THEN 1 ELSE 0 END),
    ParametersWithDefaults = SUM(CASE WHEN inventory.HasDefaultExpression = 1 THEN 1 ELSE 0 END),
    FirstParameter = MIN(CASE WHEN inventory.parameter_id = 1 THEN inventory.ParameterName END)
FROM #ProcedureParameterInventory AS inventory
GROUP BY
    inventory.ProcedureName
ORDER BY
    inventory.ProcedureName;

SELECT
    inventory.ProcedureName,
    inventory.parameter_id,
    inventory.ParameterName,
    inventory.ParameterDirection,
    inventory.ParameterType,
    inventory.TypeDetail,
    inventory.max_length,
    inventory.precision_value,
    inventory.scale_value,
    inventory.IsOutput,
    inventory.CatalogHasDefault,
    inventory.HasDefaultExpression,
    inventory.DefaultExpression,
    inventory.ParameterDeclaration
FROM #ProcedureParameterInventory AS inventory
ORDER BY
    inventory.ProcedureName,
    inventory.parameter_id;

SELECT
    NoteOrder,
    NoteTitle,
    NoteText
FROM
(
    VALUES
        (1, N'Katalogsicht zuerst', N'sys.parameters und sys.types liefern Richtung, Typ und technische Kennzahlen direkt aus dem Katalog.'),
        (2, N'Defaults textuell pruefen', N'Das Skript liest zusaetzlich die Parameterdeklaration aus sys.sql_modules, damit T-SQL-Defaults im Inventar sichtbar bleiben.'),
        (3, N'Output-Parameter markieren', N'INOUT kennzeichnet Parameter, die neben Eingaben auch Rueckmeldungen fuer den Aufrufer transportieren.'),
        (4, N'Demo-Scope begrenzen', N'Mit @IncludeDemoOnly = 1 bleibt die Inventarisierung auf das didaktische demo-Schema fokussiert.')
) AS notes(NoteOrder, NoteTitle, NoteText)
ORDER BY
    NoteOrder;

IF @DropDemoObjects = 1
BEGIN
    DROP PROCEDURE IF EXISTS demo.usp_ParamEnrollmentWindow;
    DROP PROCEDURE IF EXISTS demo.usp_ParamRetentionAlert;
    DROP PROCEDURE IF EXISTS demo.usp_ParamRosterSlice;
    DROP TABLE IF EXISTS demo.ProcedureParameterSample;
END;
