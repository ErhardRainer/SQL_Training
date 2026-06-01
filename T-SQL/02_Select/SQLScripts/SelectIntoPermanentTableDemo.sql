/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "SelectIntoPermanentTableDemo.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "02_Select"

purpose: >
  Demonstriert SELECT INTO fuer eine schnelle Tabellenkopie in tempdb als
  didaktischen Startpunkt fuer einfache Staging-Strukturen.

parameters:
  - name: "@AsOfDate"
    sql_type: "DATE"
    direction: "IN"
    required: false
    description: "Stichtag fuer reproduzierbare Status- und Altersableitungen"
  - name: "@StageTableName"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Name der in tempdb.dbo zu erzeugenden permanenten Demo-Staging-Tabelle"
  - name: "@DropExisting"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = vorhandene Demo-Staging-Tabelle vor SELECT INTO loeschen"
  - name: "@KeepStageTable"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = erzeugte Tabelle nach der Demonstration stehen lassen"
  - name: "@ShowSourcePreview"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = Quelldaten vor der Tabellenkopie zusaetzlich anzeigen"

result_sets:
  - name: "SourcePreview"
    description: "Optionale Vorschau des didaktischen Quelldatensatzes"
  - name: "StageTableSummary"
    description: "Metadaten und Zeilenanzahl der per SELECT INTO erzeugten Demo-Tabelle"
  - name: "StageTableRows"
    description: "Inhalt der erzeugten permanenten Demo-Staging-Tabelle"

dependencies:
  - "CTE"
  - "VALUES constructor"
  - "CASE"
  - "CONCAT"
  - "DATEDIFF"
  - "DROP TABLE IF EXISTS"
  - "sys.sp_executesql"
  - "tempdb"

safety:
  level: "demo-write-tempdb"
  writes_data: true

documentation:
  markdown_file: "T-SQL/02_Select/SQLScripts/SelectIntoPermanentTableDemo.md"
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
    description: "Erstversion des Labs fuer SELECT INTO in eine permanente tempdb-Staging-Tabelle"

notes:
  - "Die Demo schreibt nur nach tempdb.dbo und vermeidet produktive Fachtabellen"
  - "Cleanup ist optional, damit SELECT INTO und Nachkontrolle nacheinander gezeigt werden koennen"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @AsOfDate DATE = '2026-04-17';
DECLARE @StageTableName SYSNAME = N'SelectIntoPermanentTableDemoStage';
DECLARE @DropExisting BIT = 1;
DECLARE @KeepStageTable BIT = 0;
DECLARE @ShowSourcePreview BIT = 1;

IF @AsOfDate IS NULL
BEGIN
    THROW 50000, '@AsOfDate darf nicht NULL sein.', 1;
END;

IF @DropExisting NOT IN (0, 1)
BEGIN
    THROW 50001, '@DropExisting muss 0 oder 1 sein.', 1;
END;

IF @KeepStageTable NOT IN (0, 1)
BEGIN
    THROW 50002, '@KeepStageTable muss 0 oder 1 sein.', 1;
END;

IF @ShowSourcePreview NOT IN (0, 1)
BEGIN
    THROW 50003, '@ShowSourcePreview muss 0 oder 1 sein.', 1;
END;

IF @StageTableName IS NULL OR LTRIM(RTRIM(@StageTableName)) = ''
BEGIN
    THROW 50004, '@StageTableName darf nicht leer sein.', 1;
END;

IF @StageTableName LIKE '%[^a-zA-Z0-9_]%'
BEGIN
    THROW 50005, '@StageTableName darf nur Buchstaben, Ziffern und Unterstriche enthalten.', 1;
END;

DECLARE @QualifiedStageTable NVARCHAR(400) = N'tempdb.dbo.' + QUOTENAME(@StageTableName);
DECLARE @CreateStageSql NVARCHAR(MAX);
DECLARE @PreviewStageSql NVARCHAR(MAX);
DECLARE @SummarySql NVARCHAR(MAX);
DECLARE @DropStageSql NVARCHAR(MAX);

IF OBJECT_ID(@QualifiedStageTable, 'U') IS NOT NULL
BEGIN
    IF @DropExisting = 1
    BEGIN
        SET @DropStageSql = N'DROP TABLE ' + @QualifiedStageTable + N';';
        EXEC sys.sp_executesql @DropStageSql;
    END;
    ELSE
    BEGIN
        THROW 50006, 'Die Ziel-Staging-Tabelle existiert bereits. Nutze @DropExisting = 1 oder einen anderen @StageTableName.', 1;
    END;
END;

IF @ShowSourcePreview = 1
BEGIN
    ;WITH DemoOrders AS
    (
        SELECT
            sample.OrderID,
            sample.CustomerName,
            sample.RegionCode,
            sample.OrderDate,
            sample.RequiredDate,
            sample.Quantity,
            sample.UnitPrice,
            sample.DiscountRate,
            sample.PriorityCode,
            sample.LoadBatch
        FROM
        (
            VALUES
                (4101, 'Alpenmarkt GmbH', 'DE-NORTH', CAST('2026-04-09' AS DATE), CAST('2026-04-18' AS DATE), 12, CAST(29.90 AS DECIMAL(10,2)), CAST(0.05 AS DECIMAL(5,2)), 'A', 'morning-load'),
                (4102, 'Bergwerk AG', 'AT-WEST', CAST('2026-04-10' AS DATE), CAST('2026-04-20' AS DATE), 4, CAST(180.00 AS DECIMAL(10,2)), CAST(0.10 AS DECIMAL(5,2)), 'B', 'morning-load'),
                (4103, 'City Clinic', 'CH-CENTRAL', CAST('2026-04-12' AS DATE), CAST('2026-04-16' AS DATE), 2, CAST(520.00 AS DECIMAL(10,2)), CAST(0.02 AS DECIMAL(5,2)), 'A', 'afternoon-load'),
                (4104, 'Delta Stores', 'DE-SOUTH', CAST('2026-04-13' AS DATE), CAST('2026-04-25' AS DATE), 30, CAST(15.50 AS DECIMAL(10,2)), CAST(0.00 AS DECIMAL(5,2)), 'C', 'afternoon-load'),
                (4105, 'Eiger Systems', 'DE-NORTH', CAST('2026-04-14' AS DATE), CAST('2026-04-19' AS DATE), 1, CAST(1290.00 AS DECIMAL(10,2)), CAST(0.08 AS DECIMAL(5,2)), 'A', 'priority-load')
        ) AS sample
        (
            OrderID,
            CustomerName,
            RegionCode,
            OrderDate,
            RequiredDate,
            Quantity,
            UnitPrice,
            DiscountRate,
            PriorityCode,
            LoadBatch
        )
    )
    SELECT
        d.OrderID,
        d.CustomerName,
        d.RegionCode,
        d.OrderDate,
        d.RequiredDate,
        d.Quantity,
        d.UnitPrice,
        d.DiscountRate,
        d.PriorityCode,
        d.LoadBatch
    FROM DemoOrders AS d
    ORDER BY
        d.OrderID;
END;

SET @CreateStageSql = N'
;WITH DemoOrders AS
(
    SELECT
        sample.OrderID,
        sample.CustomerName,
        sample.RegionCode,
        sample.OrderDate,
        sample.RequiredDate,
        sample.Quantity,
        sample.UnitPrice,
        sample.DiscountRate,
        sample.PriorityCode,
        sample.LoadBatch
    FROM
    (
        VALUES
            (4101, ''Alpenmarkt GmbH'', ''DE-NORTH'', CAST(''2026-04-09'' AS DATE), CAST(''2026-04-18'' AS DATE), 12, CAST(29.90 AS DECIMAL(10,2)), CAST(0.05 AS DECIMAL(5,2)), ''A'', ''morning-load''),
            (4102, ''Bergwerk AG'', ''AT-WEST'', CAST(''2026-04-10'' AS DATE), CAST(''2026-04-20'' AS DATE), 4, CAST(180.00 AS DECIMAL(10,2)), CAST(0.10 AS DECIMAL(5,2)), ''B'', ''morning-load''),
            (4103, ''City Clinic'', ''CH-CENTRAL'', CAST(''2026-04-12'' AS DATE), CAST(''2026-04-16'' AS DATE), 2, CAST(520.00 AS DECIMAL(10,2)), CAST(0.02 AS DECIMAL(5,2)), ''A'', ''afternoon-load''),
            (4104, ''Delta Stores'', ''DE-SOUTH'', CAST(''2026-04-13'' AS DATE), CAST(''2026-04-25'' AS DATE), 30, CAST(15.50 AS DECIMAL(10,2)), CAST(0.00 AS DECIMAL(5,2)), ''C'', ''afternoon-load''),
            (4105, ''Eiger Systems'', ''DE-NORTH'', CAST(''2026-04-14'' AS DATE), CAST(''2026-04-19'' AS DATE), 1, CAST(1290.00 AS DECIMAL(10,2)), CAST(0.08 AS DECIMAL(5,2)), ''A'', ''priority-load'')
    ) AS sample
    (
        OrderID,
        CustomerName,
        RegionCode,
        OrderDate,
        RequiredDate,
        Quantity,
        UnitPrice,
        DiscountRate,
        PriorityCode,
        LoadBatch
    )
),
PreparedSource AS
(
    SELECT
        d.OrderID,
        d.CustomerName,
        d.RegionCode,
        d.OrderDate,
        d.RequiredDate,
        d.Quantity,
        d.UnitPrice,
        d.DiscountRate,
        CAST(d.Quantity * d.UnitPrice AS DECIMAL(12,2)) AS GrossAmount,
        CAST((d.Quantity * d.UnitPrice) * (1 - d.DiscountRate) AS DECIMAL(12,2)) AS NetAmount,
        DATEDIFF(DAY, d.OrderDate, d.RequiredDate) AS LeadTimeDays,
        DATEDIFF(DAY, @AsOfDate, d.RequiredDate) AS DaysUntilRequired,
        CASE d.PriorityCode
            WHEN ''A'' THEN ''priority''
            WHEN ''B'' THEN ''planned''
            ELSE ''standard''
        END AS PriorityLabel,
        d.LoadBatch,
        CAST(SYSDATETIME() AS DATETIME2(0)) AS StageLoadedAt
    FROM DemoOrders AS d
)
SELECT
    p.OrderID,
    p.CustomerName,
    p.RegionCode,
    p.OrderDate,
    p.RequiredDate,
    p.Quantity,
    p.UnitPrice,
    p.DiscountRate,
    p.GrossAmount,
    p.NetAmount,
    p.LeadTimeDays,
    p.DaysUntilRequired,
    p.PriorityLabel,
    p.LoadBatch,
    p.StageLoadedAt
INTO ' + @QualifiedStageTable + N'
FROM PreparedSource AS p;';

EXEC sys.sp_executesql
    @CreateStageSql,
    N'@AsOfDate DATE',
    @AsOfDate = @AsOfDate;

SET @SummarySql = N'
SELECT
    DB_NAME(DB_ID(''tempdb'')) AS StageDatabase,
    ''dbo'' AS StageSchema,
    @StageTableName AS StageTableName,
    COUNT(*) AS StageRowCount,
    MIN(StageLoadedAt) AS FirstStageLoadedAt,
    MAX(StageLoadedAt) AS LastStageLoadedAt
FROM ' + @QualifiedStageTable + N';';

EXEC sys.sp_executesql
    @SummarySql,
    N'@StageTableName SYSNAME',
    @StageTableName = @StageTableName;

SET @PreviewStageSql = N'
SELECT
    s.OrderID,
    s.CustomerName,
    s.RegionCode,
    s.OrderDate,
    s.RequiredDate,
    s.Quantity,
    s.GrossAmount,
    s.NetAmount,
    s.DaysUntilRequired,
    s.PriorityLabel,
    s.LoadBatch,
    s.StageLoadedAt
FROM ' + @QualifiedStageTable + N' AS s
ORDER BY
    s.OrderID;';

EXEC sys.sp_executesql @PreviewStageSql;

IF @KeepStageTable = 0
BEGIN
    SET @DropStageSql = N'DROP TABLE ' + @QualifiedStageTable + N';';
    EXEC sys.sp_executesql @DropStageSql;
END;
