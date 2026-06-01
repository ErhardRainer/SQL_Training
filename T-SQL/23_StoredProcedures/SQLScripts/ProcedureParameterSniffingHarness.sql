/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "ProcedureParameterSniffingHarness.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "23_StoredProcedures"

purpose: >
  Baut in tempdb eine didaktische Stored-Procedure-Harness mit stark
  ungleich verteilter Demo-Datenbasis auf und vergleicht pro Szenario
  wiederverwendete Plaene gegen frisch recompilierte Ausfuehrungen, um
  moegliche Parameter-Sniffing-Effekte sichtbar zu machen.

parameters:
  - name: "@SelectiveRegionCode"
    sql_type: "NVARCHAR(20)"
    direction: "IN"
    required: false
    description: "Selten vorkommender Parameterwert fuer die selektive Compile-Phase"
  - name: "@BroadRegionCode"
    sql_type: "NVARCHAR(20)"
    direction: "IN"
    required: false
    description: "Haeufig vorkommender Parameterwert fuer die breite Reuse-Phase"
  - name: "@MinimumSeats"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Untergrenze fuer die beruecksichtigten Demo-Zeilen"
  - name: "@DropDemoObjects"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = Demo-Tabelle und Demo-Procedure am Ende wieder aus tempdb entfernen"

result_sets:
  - name: "ScenarioMetrics"
    description: "Metriken je Harness-Szenario inklusive DMV-Deltas und Ergebnisgroessen"
  - name: "ProcedureStatsSnapshot"
    description: "Aktuelle DMV-Sicht auf die Demo-Procedure nach allen Szenarien"
  - name: "SniffingAssessment"
    description: "Didaktische Einordnung, ob Reuse oder Recompile im Lab auffaellige Unterschiede zeigt"

dependencies:
  - "tempdb"
  - "sys.schemas"
  - "sys.all_objects"
  - "sys.objects"
  - "sys.dm_exec_procedure_stats"
  - "sp_recompile"
  - "CREATE OR ALTER PROCEDURE"

safety:
  level: "demo-write-tempdb"
  writes_data: true

documentation:
  markdown_file: "T-SQL/23_StoredProcedures/SQLScripts/ProcedureParameterSniffingHarness.md"
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
    description: "Erstversion des didaktischen Harness fuer moegliche Parameter-Sniffing-Effekte"

notes:
  - "Alle Demo-Objekte werden ausschliesslich in tempdb angelegt"
  - "Die DMV-Werte dienen als Diagnose fuer den Cache-Effekt und nicht als vollstaendiger Benchmark"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @SelectiveRegionCode NVARCHAR(20) = N'RAREX';
DECLARE @BroadRegionCode NVARCHAR(20) = N'DB100';
DECLARE @MinimumSeats INT = 20;
DECLARE @DropDemoObjects BIT = 1;

IF NULLIF(LTRIM(RTRIM(@SelectiveRegionCode)), N'') IS NULL
BEGIN
    THROW 50000, '@SelectiveRegionCode darf nicht leer sein.', 1;
END;

IF NULLIF(LTRIM(RTRIM(@BroadRegionCode)), N'') IS NULL
BEGIN
    THROW 50001, '@BroadRegionCode darf nicht leer sein.', 1;
END;

IF @MinimumSeats IS NULL OR @MinimumSeats < 0
BEGIN
    THROW 50002, '@MinimumSeats darf nicht negativ sein.', 1;
END;

IF @DropDemoObjects NOT IN (0, 1)
BEGIN
    THROW 50003, '@DropDemoObjects muss 0 oder 1 sein.', 1;
END;

IF @SelectiveRegionCode = @BroadRegionCode
BEGIN
    THROW 50004, '@SelectiveRegionCode und @BroadRegionCode muessen unterschiedliche Werte sein.', 1;
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

DROP PROCEDURE IF EXISTS demo.usp_ProcedureSniffingHarness;
DROP TABLE IF EXISTS demo.ProcedureSniffingSample;

CREATE TABLE demo.ProcedureSniffingSample
(
    SampleID        INT            NOT NULL IDENTITY(1,1) PRIMARY KEY,
    RegionCode      NVARCHAR(20)   NOT NULL,
    CourseCode      NVARCHAR(20)   NOT NULL,
    StudentCount    INT            NOT NULL,
    CompletionRate  DECIMAL(5,2)   NOT NULL,
    IsArchived      BIT            NOT NULL,
    SnapshotDate    DATE           NOT NULL
);

CREATE INDEX IX_ProcedureSniffingSample_Region
ON demo.ProcedureSniffingSample (RegionCode, IsArchived, StudentCount)
INCLUDE (CourseCode, CompletionRate, SnapshotDate);

;WITH SeedRows AS
(
    SELECT TOP (12000)
        ROW_NUMBER() OVER (ORDER BY a.object_id, b.object_id) AS RowNo
    FROM sys.all_objects AS a
    CROSS JOIN sys.all_objects AS b
)
INSERT INTO demo.ProcedureSniffingSample
(
    RegionCode,
    CourseCode,
    StudentCount,
    CompletionRate,
    IsArchived,
    SnapshotDate
)
SELECT
    RegionCode =
        CASE
            WHEN RowNo <= 9000 THEN N'DB100'
            WHEN RowNo <= 10800 THEN N'ETL200'
            WHEN RowNo <= 11880 THEN N'API310'
            ELSE N'RAREX'
        END,
    CourseCode =
        CASE RowNo % 4
            WHEN 0 THEN N'PROC-A'
            WHEN 1 THEN N'PROC-B'
            WHEN 2 THEN N'PROC-C'
            ELSE N'PROC-D'
        END,
    StudentCount = 8 + (RowNo % 45),
    CompletionRate = CAST(55 + ((RowNo * 11) % 45) + ((RowNo % 5) * 0.10) AS DECIMAL(5,2)),
    IsArchived = CASE WHEN RowNo % 13 = 0 THEN 1 ELSE 0 END,
    SnapshotDate = DATEADD(DAY, -(RowNo % 120), CAST('2026-04-19' AS DATE))
FROM SeedRows;

EXEC sys.sp_executesql
N'
CREATE OR ALTER PROCEDURE demo.usp_ProcedureSniffingHarness
    @RegionCode NVARCHAR(20),
    @MinimumSeats INT,
    @IncludeArchived BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ScenarioName = CAST(NULL AS NVARCHAR(80)),
        RegionCode = @RegionCode,
        ForceRecompile = CAST(NULL AS BIT),
        MatchingRows = COUNT_BIG(*),
        AvgCompletionRate = CAST(AVG(CAST(sample.CompletionRate AS DECIMAL(9,4))) AS DECIMAL(9,2)),
        TotalStudents = SUM(sample.StudentCount),
        MostRecentSnapshot = MAX(sample.SnapshotDate),
        ExecDelta = CAST(NULL AS BIGINT),
        ElapsedMsDelta = CAST(NULL AS DECIMAL(18,3)),
        WorkerMsDelta = CAST(NULL AS DECIMAL(18,3)),
        LogicalReadsDelta = CAST(NULL AS DECIMAL(18,2)),
        CachedTimeAfter = CAST(NULL AS DATETIME2(3)),
        LastExecutionAfter = CAST(NULL AS DATETIME2(3))
    FROM demo.ProcedureSniffingSample AS sample
    WHERE sample.RegionCode = @RegionCode
      AND sample.StudentCount >= @MinimumSeats
      AND (@IncludeArchived = 1 OR sample.IsArchived = 0);
END;
';

DROP TABLE IF EXISTS #ScenarioDefinition;
DROP TABLE IF EXISTS #ProcedureStatsBefore;
DROP TABLE IF EXISTS #ProcedureStatsAfter;
DROP TABLE IF EXISTS #ScenarioResult;

CREATE TABLE #ScenarioDefinition
(
    ScenarioOrder     INT            NOT NULL PRIMARY KEY,
    ScenarioName      NVARCHAR(80)   NOT NULL,
    RegionCode        NVARCHAR(20)   NOT NULL,
    ForceRecompile    BIT            NOT NULL
);

INSERT INTO #ScenarioDefinition
(
    ScenarioOrder,
    ScenarioName,
    RegionCode,
    ForceRecompile
)
VALUES
    (1, N'SelectiveCompile', @SelectiveRegionCode, 1),
    (2, N'BroadReuse', @BroadRegionCode, 0),
    (3, N'BroadRecompile', @BroadRegionCode, 1),
    (4, N'SelectiveReuseAfterBroad', @SelectiveRegionCode, 0);

CREATE TABLE #ProcedureStatsBefore
(
    execution_count      BIGINT        NULL,
    total_elapsed_time   BIGINT        NULL,
    total_worker_time    BIGINT        NULL,
    total_logical_reads  BIGINT        NULL,
    cached_time          DATETIME2(3)  NULL,
    last_execution_time  DATETIME2(3)  NULL
);

CREATE TABLE #ProcedureStatsAfter
(
    execution_count      BIGINT        NULL,
    total_elapsed_time   BIGINT        NULL,
    total_worker_time    BIGINT        NULL,
    total_logical_reads  BIGINT        NULL,
    cached_time          DATETIME2(3)  NULL,
    last_execution_time  DATETIME2(3)  NULL
);

CREATE TABLE #ScenarioResult
(
    ScenarioOrder         INT             NOT NULL PRIMARY KEY,
    ScenarioName          NVARCHAR(80)    NOT NULL,
    RegionCode            NVARCHAR(20)    NOT NULL,
    ForceRecompile        BIT             NOT NULL,
    MatchingRows          BIGINT          NULL,
    AvgCompletionRate     DECIMAL(9,2)    NULL,
    TotalStudents         BIGINT          NULL,
    MostRecentSnapshot    DATE            NULL,
    ExecDelta             BIGINT          NULL,
    ElapsedMsDelta        DECIMAL(18,3)   NULL,
    WorkerMsDelta         DECIMAL(18,3)   NULL,
    LogicalReadsDelta     DECIMAL(18,2)   NULL,
    CachedTimeAfter       DATETIME2(3)    NULL,
    LastExecutionAfter    DATETIME2(3)    NULL
);

DECLARE
    @ScenarioOrder INT,
    @ScenarioName NVARCHAR(80),
    @ScenarioRegionCode NVARCHAR(20),
    @ForceRecompile BIT;

DECLARE ScenarioCursor CURSOR LOCAL FAST_FORWARD FOR
SELECT
    sd.ScenarioOrder,
    sd.ScenarioName,
    sd.RegionCode,
    sd.ForceRecompile
FROM #ScenarioDefinition AS sd
ORDER BY
    sd.ScenarioOrder;

OPEN ScenarioCursor;

FETCH NEXT FROM ScenarioCursor
INTO
    @ScenarioOrder,
    @ScenarioName,
    @ScenarioRegionCode,
    @ForceRecompile;

WHILE @@FETCH_STATUS = 0
BEGIN
    DELETE FROM #ProcedureStatsBefore;
    DELETE FROM #ProcedureStatsAfter;

    IF @ForceRecompile = 1
    BEGIN
        EXEC sys.sp_recompile N''demo.usp_ProcedureSniffingHarness'';
    END;

    INSERT INTO #ProcedureStatsBefore
    (
        execution_count,
        total_elapsed_time,
        total_worker_time,
        total_logical_reads,
        cached_time,
        last_execution_time
    )
    SELECT
        ps.execution_count,
        ps.total_elapsed_time,
        ps.total_worker_time,
        ps.total_logical_reads,
        ps.cached_time,
        ps.last_execution_time
    FROM sys.dm_exec_procedure_stats AS ps
    WHERE ps.database_id = DB_ID(N''tempdb'')
      AND ps.object_id = OBJECT_ID(N''demo.usp_ProcedureSniffingHarness'');

    INSERT INTO #ScenarioResult
    (
        ScenarioOrder,
        ScenarioName,
        RegionCode,
        ForceRecompile,
        MatchingRows,
        AvgCompletionRate,
        TotalStudents,
        MostRecentSnapshot,
        ExecDelta,
        ElapsedMsDelta,
        WorkerMsDelta,
        LogicalReadsDelta,
        CachedTimeAfter,
        LastExecutionAfter
    )
    EXEC demo.usp_ProcedureSniffingHarness
        @RegionCode = @ScenarioRegionCode,
        @MinimumSeats = @MinimumSeats,
        @IncludeArchived = 0;

    INSERT INTO #ProcedureStatsAfter
    (
        execution_count,
        total_elapsed_time,
        total_worker_time,
        total_logical_reads,
        cached_time,
        last_execution_time
    )
    SELECT
        ps.execution_count,
        ps.total_elapsed_time,
        ps.total_worker_time,
        ps.total_logical_reads,
        ps.cached_time,
        ps.last_execution_time
    FROM sys.dm_exec_procedure_stats AS ps
    WHERE ps.database_id = DB_ID(N''tempdb'')
      AND ps.object_id = OBJECT_ID(N''demo.usp_ProcedureSniffingHarness'');

    UPDATE result
    SET
        result.ScenarioName = @ScenarioName,
        result.ForceRecompile = @ForceRecompile,
        result.ExecDelta = COALESCE(after_stats.execution_count, 0) - COALESCE(before_stats.execution_count, 0),
        result.ElapsedMsDelta =
            CAST((COALESCE(after_stats.total_elapsed_time, 0) - COALESCE(before_stats.total_elapsed_time, 0)) / 1000.0 AS DECIMAL(18,3)),
        result.WorkerMsDelta =
            CAST((COALESCE(after_stats.total_worker_time, 0) - COALESCE(before_stats.total_worker_time, 0)) / 1000.0 AS DECIMAL(18,3)),
        result.LogicalReadsDelta =
            CAST(COALESCE(after_stats.total_logical_reads, 0) - COALESCE(before_stats.total_logical_reads, 0) AS DECIMAL(18,2)),
        result.CachedTimeAfter = after_stats.cached_time,
        result.LastExecutionAfter = after_stats.last_execution_time
    FROM #ScenarioResult AS result
    OUTER APPLY
    (
        SELECT TOP (1)
            before_row.execution_count,
            before_row.total_elapsed_time,
            before_row.total_worker_time,
            before_row.total_logical_reads
        FROM #ProcedureStatsBefore AS before_row
    ) AS before_stats
    OUTER APPLY
    (
        SELECT TOP (1)
            after_row.execution_count,
            after_row.total_elapsed_time,
            after_row.total_worker_time,
            after_row.total_logical_reads,
            after_row.cached_time,
            after_row.last_execution_time
        FROM #ProcedureStatsAfter AS after_row
    ) AS after_stats
    WHERE result.ScenarioOrder = @ScenarioOrder;

    FETCH NEXT FROM ScenarioCursor
    INTO
        @ScenarioOrder,
        @ScenarioName,
        @ScenarioRegionCode,
        @ForceRecompile;
END;

CLOSE ScenarioCursor;
DEALLOCATE ScenarioCursor;

SELECT
    ScenarioName,
    RegionCode,
    ForceRecompile,
    MatchingRows,
    AvgCompletionRate,
    TotalStudents,
    MostRecentSnapshot,
    ExecDelta,
    ElapsedMsDelta,
    WorkerMsDelta,
    LogicalReadsDelta,
    CachedTimeAfter,
    LastExecutionAfter
FROM #ScenarioResult
ORDER BY
    ScenarioOrder;

SELECT
    ProcedureName = CONCAT(SCHEMA_NAME(obj.schema_id), N'.', obj.name),
    ps.execution_count,
    avg_elapsed_ms = CAST((ps.total_elapsed_time * 1.0 / NULLIF(ps.execution_count, 0)) / 1000.0 AS DECIMAL(18,3)),
    avg_worker_ms = CAST((ps.total_worker_time * 1.0 / NULLIF(ps.execution_count, 0)) / 1000.0 AS DECIMAL(18,3)),
    avg_logical_reads = CAST(ps.total_logical_reads * 1.0 / NULLIF(ps.execution_count, 0) AS DECIMAL(18,2)),
    ps.cached_time,
    ps.last_execution_time
FROM sys.dm_exec_procedure_stats AS ps
INNER JOIN sys.objects AS obj
    ON ps.object_id = obj.object_id
WHERE ps.database_id = DB_ID(N'tempdb')
  AND obj.object_id = OBJECT_ID(N'demo.usp_ProcedureSniffingHarness');

;WITH ScenarioPairs AS
(
    SELECT
        selective.ElapsedMsDelta AS SelectiveCompileElapsedMs,
        selective.LogicalReadsDelta AS SelectiveCompileReads,
        broad_reuse.ElapsedMsDelta AS BroadReuseElapsedMs,
        broad_reuse.LogicalReadsDelta AS BroadReuseReads,
        broad_recompile.ElapsedMsDelta AS BroadRecompileElapsedMs,
        broad_recompile.LogicalReadsDelta AS BroadRecompileReads,
        selective_reuse.ElapsedMsDelta AS SelectiveReuseElapsedMs,
        selective_reuse.LogicalReadsDelta AS SelectiveReuseReads
    FROM #ScenarioResult AS selective
    CROSS JOIN #ScenarioResult AS broad_reuse
    CROSS JOIN #ScenarioResult AS broad_recompile
    CROSS JOIN #ScenarioResult AS selective_reuse
    WHERE selective.ScenarioName = N'SelectiveCompile'
      AND broad_reuse.ScenarioName = N'BroadReuse'
      AND broad_recompile.ScenarioName = N'BroadRecompile'
      AND selective_reuse.ScenarioName = N'SelectiveReuseAfterBroad'
)
SELECT
    Observation = N'BroadReuseVsBroadRecompile',
    Assessment =
        CASE
            WHEN sp.BroadReuseReads > sp.BroadRecompileReads OR sp.BroadReuseElapsedMs > sp.BroadRecompileElapsedMs
                THEN N'Broad parameter wirkt unter Plan-Reuse auffaelliger als nach Recompile.'
            ELSE N'Broad parameter zeigt im Lab keine staerkere Belastung unter Plan-Reuse.'
        END,
    ReferenceMetric =
        CONCAT
        (
            N'Reads reuse/recompile = ',
            CONVERT(NVARCHAR(40), sp.BroadReuseReads),
            N'/',
            CONVERT(NVARCHAR(40), sp.BroadRecompileReads),
            N'; elapsed ms reuse/recompile = ',
            CONVERT(NVARCHAR(40), sp.BroadReuseElapsedMs),
            N'/',
            CONVERT(NVARCHAR(40), sp.BroadRecompileElapsedMs)
        )
FROM ScenarioPairs AS sp

UNION ALL

SELECT
    Observation = N'SelectiveReuseAfterBroad',
    Assessment =
        CASE
            WHEN sp.SelectiveReuseReads > sp.SelectiveCompileReads OR sp.SelectiveReuseElapsedMs > sp.SelectiveCompileElapsedMs
                THEN N'Selektiver Parameter wirkt nach breiter Compile-Phase auffaelliger als in der selektiven Erstkompilierung.'
            ELSE N'Selektiver Parameter bleibt im Lab auch nach breiter Compile-Phase unauffaellig.'
        END,
    ReferenceMetric =
        CONCAT
        (
            N'Reads selective compile/reuse = ',
            CONVERT(NVARCHAR(40), sp.SelectiveCompileReads),
            N'/',
            CONVERT(NVARCHAR(40), sp.SelectiveReuseReads),
            N'; elapsed ms compile/reuse = ',
            CONVERT(NVARCHAR(40), sp.SelectiveCompileElapsedMs),
            N'/',
            CONVERT(NVARCHAR(40), sp.SelectiveReuseElapsedMs)
        )
FROM ScenarioPairs AS sp;

IF @DropDemoObjects = 1
BEGIN
    DROP PROCEDURE IF EXISTS demo.usp_ProcedureSniffingHarness;
    DROP TABLE IF EXISTS demo.ProcedureSniffingSample;
END;

DROP TABLE IF EXISTS #ScenarioDefinition;
DROP TABLE IF EXISTS #ProcedureStatsBefore;
DROP TABLE IF EXISTS #ProcedureStatsAfter;
DROP TABLE IF EXISTS #ScenarioResult;