/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "ProcedureOutputContractReview.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "23_StoredProcedures"

purpose: >
  Baut in tempdb mehrere Demo-Prozeduren mit unterschiedlichen Rueckgabe-
  und Output-Vertraegen auf und erstellt ein kompaktes Review ueber
  Output-Parameter, Returncode-Nutzung und das erste Resultset.

parameters:
  - name: "@ProcedureNamePattern"
    sql_type: "NVARCHAR(128)"
    direction: "IN"
    required: false
    description: "LIKE-Filter fuer die zu reviewenden Demo-Prozeduren"
  - name: "@IncludeSystemShipped"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = auch system_shipped-Prozeduren in die Review-Menge aufnehmen"
  - name: "@DropDemoObjects"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = Demo-Prozeduren und Demo-Tabelle am Ende wieder aus tempdb entfernen"

result_sets:
  - name: "ProcedureContractReview"
    description: "Verdichtetes Review je Procedure mit Output-Anzahl, Returncode-Hinweis und Resultset-Profil"
  - name: "OutputParameterInventory"
    description: "Inventar aller Output-Parameter der beruecksichtigten Demo-Prozeduren"
  - name: "FirstResultSetMetadata"
    description: "Spaltenprofil des ersten Resultsets ueber sys.dm_exec_describe_first_result_set_for_object"
  - name: "ReviewChecklist"
    description: "Didaktische Checkliste fuer stabile Rueckgabe- und Output-Kontrakte"

dependencies:
  - "tempdb"
  - "sys.schemas"
  - "sys.procedures"
  - "sys.parameters"
  - "sys.sql_modules"
  - "sys.dm_exec_describe_first_result_set_for_object"
  - "CREATE OR ALTER PROCEDURE"
  - "STRING_AGG"

safety:
  level: "demo-write-tempdb"
  writes_data: true

documentation:
  markdown_file: "T-SQL/23_StoredProcedures/SQLScripts/ProcedureOutputContractReview.md"
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
    description: "Erstversion des didaktischen Reviews fuer Procedure-Output- und Rueckgabevertraege"

notes:
  - "Alle Demo-Objekte werden ausschliesslich in tempdb angelegt"
  - "Das Review kombiniert Katalogsicht, Output-Parameter-Inventar und Resultset-Metadaten"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @ProcedureNamePattern NVARCHAR(128) = N'usp_Contract%';
DECLARE @IncludeSystemShipped BIT = 0;
DECLARE @DropDemoObjects BIT = 1;

IF NULLIF(LTRIM(RTRIM(@ProcedureNamePattern)), N'') IS NULL
BEGIN
    THROW 50000, '@ProcedureNamePattern darf nicht leer sein.', 1;
END;

IF @IncludeSystemShipped NOT IN (0, 1)
BEGIN
    THROW 50001, '@IncludeSystemShipped muss 0 oder 1 sein.', 1;
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

DROP PROCEDURE IF EXISTS demo.usp_ContractEnrollmentStatus;
DROP PROCEDURE IF EXISTS demo.usp_ContractLateChangeSummary;
DROP PROCEDURE IF EXISTS demo.usp_ContractRosterReadonly;
DROP TABLE IF EXISTS demo.ProcedureContractSample;

CREATE TABLE demo.ProcedureContractSample
(
    EnrollmentID        INT           NOT NULL PRIMARY KEY,
    CourseCode          NVARCHAR(20)  NOT NULL,
    TermCode            NVARCHAR(20)  NOT NULL,
    RegisteredCount     INT           NOT NULL,
    HasLateChanges      BIT           NOT NULL,
    LastContractReview  DATE          NOT NULL
);

INSERT INTO demo.ProcedureContractSample
(
    EnrollmentID,
    CourseCode,
    TermCode,
    RegisteredCount,
    HasLateChanges,
    LastContractReview
)
VALUES
    (101, N'DB100',  N'2026Q1', 28, 0, '2026-03-12'),
    (102, N'DB100',  N'2026Q2', 31, 1, '2026-04-02'),
    (201, N'ETL200', N'2026Q1', 19, 0, '2026-03-18'),
    (202, N'ETL200', N'2026Q2', 22, 1, '2026-04-09'),
    (301, N'API310', N'2026Q1', 24, 0, '2026-03-25');

EXEC sys.sp_executesql
N'
CREATE OR ALTER PROCEDURE demo.usp_ContractEnrollmentStatus
    @CourseCode NVARCHAR(20),
    @RowsReturned INT OUTPUT,
    @ContractState NVARCHAR(20) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF NULLIF(LTRIM(RTRIM(@CourseCode)), N'''') IS NULL
    BEGIN
        THROW 51000, N''@CourseCode darf nicht leer sein.'', 1;
    END;

    SELECT
        sample.EnrollmentID,
        sample.CourseCode,
        sample.TermCode,
        sample.RegisteredCount,
        sample.LastContractReview
    FROM demo.ProcedureContractSample AS sample
    WHERE sample.CourseCode = @CourseCode
    ORDER BY
        sample.TermCode,
        sample.EnrollmentID;

    SET @RowsReturned = @@ROWCOUNT;
    SET @ContractState =
        CASE
            WHEN @RowsReturned = 0 THEN N''NoData''
            ELSE N''Success''
        END;

    RETURN CASE WHEN @RowsReturned = 0 THEN 10 ELSE 0 END;
END;
';

EXEC sys.sp_executesql
N'
CREATE OR ALTER PROCEDURE demo.usp_ContractLateChangeSummary
    @TermCode NVARCHAR(20),
    @HasWarnings BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF NULLIF(LTRIM(RTRIM(@TermCode)), N'''') IS NULL
    BEGIN
        THROW 51010, N''@TermCode darf nicht leer sein.'', 1;
    END;

    SELECT
        sample.TermCode,
        ProceduresReviewed = COUNT(*),
        CoursesWithLateChanges = SUM(CASE WHEN sample.HasLateChanges = 1 THEN 1 ELSE 0 END),
        LastReviewDate = MAX(sample.LastContractReview)
    FROM demo.ProcedureContractSample AS sample
    WHERE sample.TermCode = @TermCode
    GROUP BY
        sample.TermCode;

    SELECT
        @HasWarnings =
            CAST
            (
                CASE
                    WHEN EXISTS
                    (
                        SELECT 1
                        FROM demo.ProcedureContractSample AS sample
                        WHERE sample.TermCode = @TermCode
                          AND sample.HasLateChanges = 1
                    ) THEN 1
                    ELSE 0
                END
                AS BIT
            );

    RETURN 0;
END;
';

EXEC sys.sp_executesql
N'
CREATE OR ALTER PROCEDURE demo.usp_ContractRosterReadonly
    @CourseCode NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        sample.CourseCode,
        sample.TermCode,
        sample.RegisteredCount,
        sample.HasLateChanges
    FROM demo.ProcedureContractSample AS sample
    WHERE @CourseCode IS NULL
       OR sample.CourseCode = @CourseCode
    ORDER BY
        sample.CourseCode,
        sample.TermCode;
END;
';

DROP TABLE IF EXISTS #TargetProcedures;

CREATE TABLE #TargetProcedures
(
    object_id         INT            NOT NULL PRIMARY KEY,
    ProcedureName     NVARCHAR(256)  NOT NULL,
    schema_name       SYSNAME        NOT NULL,
    procedure_name    SYSNAME        NOT NULL,
    is_ms_shipped     BIT            NOT NULL,
    module_definition NVARCHAR(MAX)  NULL
);

INSERT INTO #TargetProcedures
(
    object_id,
    ProcedureName,
    schema_name,
    procedure_name,
    is_ms_shipped,
    module_definition
)
SELECT
    proc.object_id,
    CONCAT(sch.name, N'.', proc.name) AS ProcedureName,
    sch.name AS schema_name,
    proc.name AS procedure_name,
    proc.is_ms_shipped,
    module.definition
FROM sys.procedures AS proc
INNER JOIN sys.schemas AS sch
    ON proc.schema_id = sch.schema_id
LEFT JOIN sys.sql_modules AS module
    ON proc.object_id = module.object_id
WHERE proc.name LIKE @ProcedureNamePattern
  AND (@IncludeSystemShipped = 1 OR proc.is_ms_shipped = 0)
  AND sch.name = N'demo';

;WITH OutputParameters AS
(
    SELECT
        tp.object_id,
        OutputParameterCount = COUNT(*),
        OutputParameterList = STRING_AGG(p.name + N' (' + TYPE_NAME(p.user_type_id) + N')', N', ')
    FROM #TargetProcedures AS tp
    INNER JOIN sys.parameters AS p
        ON tp.object_id = p.object_id
    WHERE p.is_output = 1
    GROUP BY
        tp.object_id
),
ResultSetProfile AS
(
    SELECT
        tp.object_id,
        FirstResultSetColumns = COUNT(CASE WHEN metadata.column_ordinal IS NOT NULL THEN 1 END),
        NullableColumns = SUM(CASE WHEN metadata.is_nullable = 1 THEN 1 ELSE 0 END),
        ResultSetError = MAX(metadata.error_type_desc)
    FROM #TargetProcedures AS tp
    OUTER APPLY sys.dm_exec_describe_first_result_set_for_object(tp.object_id, 0) AS metadata
    GROUP BY
        tp.object_id
)
SELECT
    tp.ProcedureName,
    OutputParameterCount = COALESCE(op.OutputParameterCount, 0),
    OutputParameters = COALESCE(op.OutputParameterList, N'<none>'),
    UsesReturnKeyword =
        CAST
        (
            CASE
                WHEN tp.module_definition LIKE N'%RETURN %' THEN 1
                ELSE 0
            END
            AS BIT
        ),
    FirstResultSetColumns = COALESCE(rsp.FirstResultSetColumns, 0),
    NullableColumns = COALESCE(rsp.NullableColumns, 0),
    ResultSetError = COALESCE(rsp.ResultSetError, N'<none>'),
    ReviewStatus =
        CASE
            WHEN COALESCE(op.OutputParameterCount, 0) = 0
             AND tp.module_definition NOT LIKE N'%RETURN %'
                THEN N'resultset-only'
            WHEN COALESCE(op.OutputParameterCount, 0) = 0
             AND tp.module_definition LIKE N'%RETURN %'
                THEN N'returncode-without-output'
            WHEN COALESCE(op.OutputParameterCount, 0) > 0
             AND tp.module_definition LIKE N'%RETURN %'
                THEN N'output-and-returncode'
            ELSE N'output-focused'
        END,
    ReviewNote =
        CASE
            WHEN COALESCE(op.OutputParameterCount, 0) = 0
                THEN N'Keine Output-Parameter sichtbar. Konsumenten muessen sich auf Resultset oder impliziten Erfolg verlassen.'
            WHEN tp.module_definition LIKE N'%RETURN %'
                THEN N'Procedure bietet sowohl Output-Parameter als auch einen expliziten Returncode.'
            ELSE N'Procedure setzt auf Output-Parameter als zusaetzlichen Statuskanal.'
        END
FROM #TargetProcedures AS tp
LEFT JOIN OutputParameters AS op
    ON tp.object_id = op.object_id
LEFT JOIN ResultSetProfile AS rsp
    ON tp.object_id = rsp.object_id
ORDER BY
    tp.ProcedureName;

SELECT
    tp.ProcedureName,
    p.parameter_id,
    p.name AS ParameterName,
    ParameterType = TYPE_NAME(p.user_type_id),
    p.max_length,
    p.is_output,
    p.has_default_value,
    SuggestedUsage =
        CASE
            WHEN p.name LIKE N'%State%' OR p.name LIKE N'%Status%'
                THEN N'Geeignet fuer kompakten Statuskanal neben dem Resultset'
            WHEN p.name LIKE N'%Rows%' OR p.name LIKE N'%Count%'
                THEN N'Geeignet fuer Kennzahlen oder Rueckmeldungen an Batch-Aufrufer'
            WHEN p.name LIKE N'%Warning%'
                THEN N'Geeignet fuer Warnflags oder Review-Hinweise'
            ELSE N'Allgemeiner Output-Parameter fuer Zusatzinformationen'
        END
FROM #TargetProcedures AS tp
INNER JOIN sys.parameters AS p
    ON tp.object_id = p.object_id
WHERE p.is_output = 1
ORDER BY
    tp.ProcedureName,
    p.parameter_id;

SELECT
    tp.ProcedureName,
    metadata.column_ordinal,
    metadata.name AS column_name,
    metadata.system_type_name,
    metadata.is_nullable,
    metadata.error_type_desc
FROM #TargetProcedures AS tp
OUTER APPLY sys.dm_exec_describe_first_result_set_for_object(tp.object_id, 0) AS metadata
ORDER BY
    tp.ProcedureName,
    metadata.column_ordinal;

SELECT
    ChecklistOrder,
    ChecklistItem,
    WhyItMatters
FROM
(
    VALUES
        (1, N'Output-Parameter klar benennen', N'Namen wie @Status oder @RowsReturned machen den Vertrag fuer Konsumenten lesbarer.'),
        (2, N'Returncodes sparsam und stabil halten', N'Numerische Rueckgabewerte eignen sich fuer kompakte Erfolg- oder Fehlerklassen.'),
        (3, N'Erstes Resultset schema-stabil halten', N'Clients und ETL-Schritte profitieren von fester Spaltenreihenfolge und Datentypen.'),
        (4, N'Output und Resultset nicht gegeneinander ausspielen', N'Resultset transportiert Fachdaten, Output-Parameter transportieren kompakten Status.'),
        (5, N'Review ueber Katalogmetadaten automatisieren', N'sys.parameters und sys.dm_exec_describe_first_result_set_for_object decken Vertragsaenderungen frueh auf.')
) AS checklist(ChecklistOrder, ChecklistItem, WhyItMatters)
ORDER BY
    ChecklistOrder;

IF @DropDemoObjects = 1
BEGIN
    DROP PROCEDURE IF EXISTS demo.usp_ContractEnrollmentStatus;
    DROP PROCEDURE IF EXISTS demo.usp_ContractLateChangeSummary;
    DROP PROCEDURE IF EXISTS demo.usp_ContractRosterReadonly;
    DROP TABLE IF EXISTS demo.ProcedureContractSample;
END;
