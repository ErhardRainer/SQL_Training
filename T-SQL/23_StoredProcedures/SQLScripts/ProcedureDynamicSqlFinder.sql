/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "ProcedureDynamicSqlFinder.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "23_StoredProcedures"

purpose: >
  Baut in tempdb mehrere Demo-Prozeduren mit statischem und dynamischem SQL
  auf und analysiert ueber sys.sql_modules, welche Stored Procedures typische
  Muster fuer dynamisches SQL wie sp_executesql, EXEC(@sql), QUOTENAME und
  SQL-String-Verkettung verwenden.

parameters:
  - name: "@ProcedureNamePattern"
    sql_type: "NVARCHAR(128)"
    direction: "IN"
    required: false
    description: "LIKE-Filter fuer die zu analysierenden Stored Procedures"
  - name: "@IncludeDemoSetup"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = Demo-Tabelle und Demo-Prozeduren in tempdb aufbauen"
  - name: "@DropDemoObjects"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = Demo-Objekte nach der Analyse wieder aus tempdb entfernen"

result_sets:
  - name: "ProcedureDynamicSqlSignals"
    description: "Heuristische Signale je Procedure fuer dynamisches SQL inklusive Musterklassifikation"
  - name: "ProcedureDynamicSqlSummary"
    description: "Verdichtete Uebersicht ueber statische und dynamische Procedure-Muster innerhalb des Filters"
  - name: "ProcedureDynamicSqlChecklist"
    description: "Didaktische Hinweise zur Bewertung von dynamischem SQL in Stored Procedures"

dependencies:
  - "tempdb"
  - "sys.schemas"
  - "sys.procedures"
  - "sys.sql_modules"
  - "CREATE OR ALTER PROCEDURE"
  - "sys.sp_executesql"

safety:
  level: "demo-write-tempdb"
  writes_data: true

documentation:
  markdown_file: "T-SQL/23_StoredProcedures/SQLScripts/ProcedureDynamicSqlFinder.md"
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
    description: "Erstversion des didaktischen Labs zur Erkennung von dynamischem SQL in Stored Procedures"

notes:
  - "Die Analyse arbeitet heuristisch ueber sys.sql_modules und ersetzt keinen vollstaendigen SQL-Parser"
  - "Alle Demo-Objekte werden ausschliesslich in tempdb angelegt"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @ProcedureNamePattern NVARCHAR(128) = N'usp_DynamicSql%';
DECLARE @IncludeDemoSetup BIT = 1;
DECLARE @DropDemoObjects BIT = 1;

IF NULLIF(LTRIM(RTRIM(@ProcedureNamePattern)), N'') IS NULL
BEGIN
    THROW 50000, '@ProcedureNamePattern darf nicht leer sein.', 1;
END;

IF @IncludeDemoSetup NOT IN (0, 1)
BEGIN
    THROW 50001, '@IncludeDemoSetup muss 0 oder 1 sein.', 1;
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

IF @IncludeDemoSetup = 1
BEGIN
    DROP PROCEDURE IF EXISTS demo.usp_DynamicSqlStaticRoster;
    DROP PROCEDURE IF EXISTS demo.usp_DynamicSqlParameterizedSearch;
    DROP PROCEDURE IF EXISTS demo.usp_DynamicSqlUnsafeSearch;
    DROP PROCEDURE IF EXISTS demo.usp_DynamicSqlOrderByPreview;
    DROP TABLE IF EXISTS demo.DynamicSqlCourseCatalog;

    CREATE TABLE demo.DynamicSqlCourseCatalog
    (
        CourseCode        NVARCHAR(20)  NOT NULL PRIMARY KEY,
        CourseName        NVARCHAR(100) NOT NULL,
        DeliveryMode      NVARCHAR(20)  NOT NULL,
        StudentCount      INT           NOT NULL,
        ModifiedDate      DATE          NOT NULL
    );

    INSERT INTO demo.DynamicSqlCourseCatalog
    (
        CourseCode,
        CourseName,
        DeliveryMode,
        StudentCount,
        ModifiedDate
    )
    VALUES
        (N'DB100', N'Database Foundations', N'on_site', 28, CAST('2026-04-17' AS DATE)),
        (N'API310', N'API Integration', N'online', 17, CAST('2026-04-14' AS DATE)),
        (N'BI420', N'Business Intelligence Studio', N'hybrid', 31, CAST('2026-04-12' AS DATE)),
        (N'ETL200', N'ETL Operations', N'on_site', 22, CAST('2026-04-10' AS DATE));

    EXEC sys.sp_executesql
    N'
    CREATE OR ALTER PROCEDURE demo.usp_DynamicSqlStaticRoster
        @MinimumStudents INT
    AS
    BEGIN
        SET NOCOUNT ON;

        SELECT
            c.CourseCode,
            c.CourseName,
            c.StudentCount
        FROM demo.DynamicSqlCourseCatalog AS c
        WHERE c.StudentCount >= @MinimumStudents
        ORDER BY
            c.StudentCount DESC,
            c.CourseCode;
    END;
    ';

    EXEC sys.sp_executesql
    N'
    CREATE OR ALTER PROCEDURE demo.usp_DynamicSqlParameterizedSearch
        @DeliveryMode NVARCHAR(20)
    AS
    BEGIN
        SET NOCOUNT ON;

        DECLARE @Sql NVARCHAR(MAX) = N''
            SELECT
                c.CourseCode,
                c.CourseName,
                c.DeliveryMode,
                c.StudentCount
            FROM demo.DynamicSqlCourseCatalog AS c
            WHERE c.DeliveryMode = @DeliveryMode
            ORDER BY
                c.StudentCount DESC,
                c.CourseCode;'';

        DECLARE @Params NVARCHAR(200) = N''@DeliveryMode NVARCHAR(20)'';

        EXEC sys.sp_executesql
            @stmt = @Sql,
            @params = @Params,
            @DeliveryMode = @DeliveryMode;
    END;
    ';

    EXEC sys.sp_executesql
    N'
    CREATE OR ALTER PROCEDURE demo.usp_DynamicSqlUnsafeSearch
        @FreeText NVARCHAR(100)
    AS
    BEGIN
        SET NOCOUNT ON;

        DECLARE @Sql NVARCHAR(MAX) = N''
            SELECT
                c.CourseCode,
                c.CourseName,
                c.DeliveryMode
            FROM demo.DynamicSqlCourseCatalog AS c
            WHERE c.CourseName LIKE N''''%'' + @FreeText + N''%'''';'';

        SET @Sql = REPLACE(@Sql, N''@FreeText'', QUOTENAME(@FreeText, N''''''''));

        EXEC(@Sql);
    END;
    ';

    EXEC sys.sp_executesql
    N'
    CREATE OR ALTER PROCEDURE demo.usp_DynamicSqlOrderByPreview
        @SortColumn SYSNAME
    AS
    BEGIN
        SET NOCOUNT ON;

        DECLARE @Sql NVARCHAR(MAX) = N''
            SELECT
                c.CourseCode,
                c.CourseName,
                c.StudentCount,
                c.ModifiedDate
            FROM demo.DynamicSqlCourseCatalog AS c
            ORDER BY '' + QUOTENAME(@SortColumn) + N'' DESC, c.CourseCode;'';

        EXEC sys.sp_executesql
            @stmt = @Sql;
    END;
    ';
END;

;WITH CandidateProcedures AS
(
    SELECT
        ProcedureName = QUOTENAME(s.name) + N'.' + QUOTENAME(p.name),
        p.object_id,
        ModuleDefinition = sm.definition
    FROM sys.procedures AS p
    INNER JOIN sys.schemas AS s
        ON s.schema_id = p.schema_id
    INNER JOIN sys.sql_modules AS sm
        ON sm.object_id = p.object_id
    WHERE p.name LIKE @ProcedureNamePattern
),
NormalizedModules AS
(
    SELECT
        cp.ProcedureName,
        cp.object_id,
        cp.ModuleDefinition,
        ModuleDefinitionLower = LOWER(cp.ModuleDefinition)
    FROM CandidateProcedures AS cp
),
Signals AS
(
    SELECT
        nm.ProcedureName,
        UsesSpExecuteSql = CASE WHEN nm.ModuleDefinitionLower LIKE N'%sp_executesql%' THEN 1 ELSE 0 END,
        UsesExecString = CASE
            WHEN nm.ModuleDefinitionLower LIKE N'%exec(@sql%' THEN 1
            WHEN nm.ModuleDefinitionLower LIKE N'%exec (@sql%' THEN 1
            WHEN nm.ModuleDefinitionLower LIKE N'%execute(@sql%' THEN 1
            WHEN nm.ModuleDefinitionLower LIKE N'%execute (@sql%' THEN 1
            ELSE 0
        END,
        UsesQuoteName = CASE WHEN nm.ModuleDefinitionLower LIKE N'%quotename(%' THEN 1 ELSE 0 END,
        BuildsSqlText = CASE
            WHEN nm.ModuleDefinitionLower LIKE N'%declare @sql nvarchar%' THEN 1
            WHEN nm.ModuleDefinitionLower LIKE N'%set @sql =%' THEN 1
            WHEN nm.ModuleDefinitionLower LIKE N'%select @sql =%' THEN 1
            WHEN nm.ModuleDefinitionLower LIKE N'%concat(%' THEN 1
            ELSE 0
        END,
        UsesParameterizedExec = CASE
            WHEN nm.ModuleDefinitionLower LIKE N'%sp_executesql%'
             AND nm.ModuleDefinitionLower LIKE N'%@params%'
            THEN 1
            ELSE 0
        END,
        UsesStringReplacement = CASE WHEN nm.ModuleDefinitionLower LIKE N'%replace(@sql%' THEN 1 ELSE 0 END,
        EvidenceToken = CASE
            WHEN nm.ModuleDefinitionLower LIKE N'%sp_executesql%' THEN N'sp_executesql'
            WHEN nm.ModuleDefinitionLower LIKE N'%exec(@sql%' OR nm.ModuleDefinitionLower LIKE N'%exec (@sql%' THEN N'EXEC(@Sql)'
            WHEN nm.ModuleDefinitionLower LIKE N'%quotename(%' THEN N'QUOTENAME'
            ELSE N'none'
        END
    FROM NormalizedModules AS nm
)
SELECT
    ProcedureName,
    UsesSpExecuteSql,
    UsesExecString,
    UsesQuoteName,
    BuildsSqlText,
    UsesParameterizedExec,
    UsesStringReplacement,
    DynamicSqlCategory =
        CASE
            WHEN UsesSpExecuteSql = 0 AND UsesExecString = 0 AND BuildsSqlText = 0 THEN N'static_sql'
            WHEN UsesParameterizedExec = 1 AND UsesExecString = 0 THEN N'parameterized_dynamic_sql'
            WHEN UsesExecString = 1 AND UsesStringReplacement = 1 THEN N'dynamic_sql_with_literal_injection_pattern'
            WHEN UsesExecString = 1 THEN N'dynamic_sql_exec_string'
            ELSE N'dynamic_sql_review'
        END,
    ReviewPriority =
        CASE
            WHEN UsesExecString = 1 AND UsesStringReplacement = 1 THEN N'high'
            WHEN UsesExecString = 1 THEN N'high'
            WHEN UsesSpExecuteSql = 1 AND UsesParameterizedExec = 0 THEN N'medium'
            WHEN UsesSpExecuteSql = 1 OR UsesQuoteName = 1 THEN N'low'
            ELSE N'info'
        END,
    EvidenceToken
FROM Signals
ORDER BY
    CASE
        WHEN UsesExecString = 1 THEN 1
        WHEN UsesSpExecuteSql = 1 THEN 2
        ELSE 3
    END,
    ProcedureName;

;WITH CandidateProcedures AS
(
    SELECT
        ProcedureName = QUOTENAME(s.name) + N'.' + QUOTENAME(p.name),
        p.object_id,
        ModuleDefinition = sm.definition
    FROM sys.procedures AS p
    INNER JOIN sys.schemas AS s
        ON s.schema_id = p.schema_id
    INNER JOIN sys.sql_modules AS sm
        ON sm.object_id = p.object_id
    WHERE p.name LIKE @ProcedureNamePattern
),
NormalizedModules AS
(
    SELECT
        cp.ProcedureName,
        ModuleDefinitionLower = LOWER(cp.ModuleDefinition)
    FROM CandidateProcedures AS cp
),
Signals AS
(
    SELECT
        ProcedureName,
        UsesSpExecuteSql = CASE WHEN ModuleDefinitionLower LIKE N'%sp_executesql%' THEN 1 ELSE 0 END,
        UsesExecString = CASE
            WHEN ModuleDefinitionLower LIKE N'%exec(@sql%' THEN 1
            WHEN ModuleDefinitionLower LIKE N'%exec (@sql%' THEN 1
            WHEN ModuleDefinitionLower LIKE N'%execute(@sql%' THEN 1
            WHEN ModuleDefinitionLower LIKE N'%execute (@sql%' THEN 1
            ELSE 0
        END,
        BuildsSqlText = CASE
            WHEN ModuleDefinitionLower LIKE N'%declare @sql nvarchar%' THEN 1
            WHEN ModuleDefinitionLower LIKE N'%set @sql =%' THEN 1
            WHEN ModuleDefinitionLower LIKE N'%select @sql =%' THEN 1
            WHEN ModuleDefinitionLower LIKE N'%concat(%' THEN 1
            ELSE 0
        END,
        UsesParameterizedExec = CASE
            WHEN ModuleDefinitionLower LIKE N'%sp_executesql%'
             AND ModuleDefinitionLower LIKE N'%@params%'
            THEN 1
            ELSE 0
        END
    FROM NormalizedModules
),
CategorizedSignals AS
(
    SELECT
        ProcedureName,
        DynamicSqlCategory =
            CASE
                WHEN UsesSpExecuteSql = 0 AND UsesExecString = 0 AND BuildsSqlText = 0 THEN N'static_sql'
                WHEN UsesParameterizedExec = 1 AND UsesExecString = 0 THEN N'parameterized_dynamic_sql'
                WHEN UsesExecString = 1 AND BuildsSqlText = 1 THEN N'dynamic_sql_with_literal_injection_pattern'
                WHEN UsesExecString = 1 THEN N'dynamic_sql_exec_string'
                ELSE N'dynamic_sql_review'
            END
    FROM Signals
)
SELECT
    DynamicSqlCategory,
    ProcedureCount = COUNT(*)
FROM CategorizedSignals
GROUP BY
    DynamicSqlCategory
ORDER BY
    CASE DynamicSqlCategory
        WHEN N'dynamic_sql_with_literal_injection_pattern' THEN 1
        WHEN N'dynamic_sql_exec_string' THEN 1
        WHEN N'dynamic_sql_review' THEN 2
        WHEN N'parameterized_dynamic_sql' THEN 3
        ELSE 4
    END;

SELECT
    StepNo,
    ChecklistItem,
    WhyItMatters
FROM
(
    VALUES
        (1, N'sp_executesql und EXEC(@sql) getrennt bewerten.', N'Parameterisiertes dynamisches SQL ist meist kontrollierbarer als frei zusammengesetzte EXEC-Strings.'),
        (2, N'QUOTENAME nicht mit vollstaendiger Sicherheit verwechseln.', N'QUOTENAME hilft bei dynamischen Objektbezeichnern, ersetzt aber keine Parameterisierung fuer Wertefilter.'),
        (3, N'Heuristische Treffer immer gegen den Modultext pruefen.', N'Die Suche ueber sys.sql_modules ist bewusst leichtgewichtig und kann Sonderfaelle uebersehen oder ueberschaetzen.'),
        (4, N'Demo-Pattern fuer spaetere Review-Regeln wiederverwenden.', N'Die erkannten Signale lassen sich gut in Governance-Checks oder Code-Review-Checklisten ueberfuehren.')
) AS checklist(StepNo, ChecklistItem, WhyItMatters)
ORDER BY
    StepNo;

IF @IncludeDemoSetup = 1 AND @DropDemoObjects = 1
BEGIN
    DROP PROCEDURE IF EXISTS demo.usp_DynamicSqlOrderByPreview;
    DROP PROCEDURE IF EXISTS demo.usp_DynamicSqlUnsafeSearch;
    DROP PROCEDURE IF EXISTS demo.usp_DynamicSqlParameterizedSearch;
    DROP PROCEDURE IF EXISTS demo.usp_DynamicSqlStaticRoster;
    DROP TABLE IF EXISTS demo.DynamicSqlCourseCatalog;
END;
