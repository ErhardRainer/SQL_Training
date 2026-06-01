/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "ProcedureRecompileDecisionAid.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "23_StoredProcedures"

purpose: >
  Bewertet Stored Procedures der aktuellen Datenbank mit einer
  didaktischen Entscheidungslogik, um zu zeigen, wann WITH RECOMPILE
  eher hilfreich, eher riskant oder zunaechst weiter zu messen ist.

parameters:
  - name: "@SchemaLike"
    sql_type: "NVARCHAR(128)"
    direction: "IN"
    required: false
    description: "LIKE-Filter fuer Schemanamen"
  - name: "@ProcedureLike"
    sql_type: "NVARCHAR(128)"
    direction: "IN"
    required: false
    description: "LIKE-Filter fuer Procedure-Namen"
  - name: "@MinExecutionCount"
    sql_type: "BIGINT"
    direction: "IN"
    required: false
    description: "Mindestanzahl an Ausfuehrungen fuer eine belastbarere Empfehlung"
  - name: "@HighAvgWorkerMs"
    sql_type: "DECIMAL(18,3)"
    direction: "IN"
    required: false
    description: "Schwellwert fuer durchschnittlich hohe Worker-Zeit je Ausfuehrung"
  - name: "@TopN"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Maximalzahl der priorisierten Procedures in der Hauptausgabe"

result_sets:
  - name: "RecompileDecisionAid"
    description: "Priorisierte Entscheidungshilfe mit Empfehlung, Nutzen- und Risikosignalen"
  - name: "DecisionSignalBreakdown"
    description: "Detailansicht aller verwendeten Signale pro Procedure"
  - name: "DecisionAidNotes"
    description: "Didaktische Hinweise zur Einordnung von WITH RECOMPILE"

dependencies:
  - "sys.schemas"
  - "sys.procedures"
  - "sys.parameters"
  - "sys.sql_modules"
  - "sys.dm_exec_procedure_stats"
  - "DB_NAME"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/23_StoredProcedures/SQLScripts/ProcedureRecompileDecisionAid.md"
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
    description: "Erstversion der didaktischen Entscheidungshilfe fuer WITH RECOMPILE"

notes:
  - "Das Skript arbeitet rein lesend in der aktuellen Datenbank"
  - "Die Empfehlung ist eine Diagnosehilfe und ersetzt keine belastbare Messung mit Plaenen oder Query Store"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @SchemaLike NVARCHAR(128) = N'%';
DECLARE @ProcedureLike NVARCHAR(128) = N'%';
DECLARE @MinExecutionCount BIGINT = 5;
DECLARE @HighAvgWorkerMs DECIMAL(18,3) = 15.000;
DECLARE @TopN INT = 25;

IF NULLIF(LTRIM(RTRIM(@SchemaLike)), N'') IS NULL
BEGIN
    THROW 50000, '@SchemaLike darf nicht leer sein.', 1;
END;

IF NULLIF(LTRIM(RTRIM(@ProcedureLike)), N'') IS NULL
BEGIN
    THROW 50001, '@ProcedureLike darf nicht leer sein.', 1;
END;

IF @MinExecutionCount IS NULL OR @MinExecutionCount < 0
BEGIN
    THROW 50002, '@MinExecutionCount darf nicht negativ sein.', 1;
END;

IF @HighAvgWorkerMs IS NULL OR @HighAvgWorkerMs < 0
BEGIN
    THROW 50003, '@HighAvgWorkerMs darf nicht negativ sein.', 1;
END;

IF @TopN IS NULL OR @TopN <= 0
BEGIN
    THROW 50004, '@TopN muss groesser als 0 sein.', 1;
END;

;WITH ProcedureCatalog AS
(
    SELECT
        proc.object_id,
        SchemaName = sch.name,
        ProcedureName = proc.name,
        QualifiedName = CONCAT(QUOTENAME(sch.name), N'.', QUOTENAME(proc.name)),
        DefinitionText = CAST(sm.definition AS NVARCHAR(MAX))
    FROM sys.procedures AS proc
    INNER JOIN sys.schemas AS sch
        ON proc.schema_id = sch.schema_id
    LEFT JOIN sys.sql_modules AS sm
        ON proc.object_id = sm.object_id
    WHERE sch.name LIKE @SchemaLike
      AND proc.name LIKE @ProcedureLike
),
ParameterStats AS
(
    SELECT
        p.object_id,
        ParameterCount = COUNT(*),
        OutputParameterCount = SUM(CASE WHEN p.is_output = 1 THEN 1 ELSE 0 END)
    FROM sys.parameters AS p
    GROUP BY
        p.object_id
),
ModuleSignals AS
(
    SELECT
        pc.object_id,
        HasDynamicSql =
            CAST
            (
                CASE
                    WHEN pc.DefinitionText LIKE N'%sp_executesql%'
                      OR pc.DefinitionText LIKE N'%EXEC (%'
                      OR pc.DefinitionText LIKE N'%EXEC(%'
                        THEN 1
                    ELSE 0
                END
                AS BIT
            ),
        HasControlFlow =
            CAST
            (
                CASE
                    WHEN pc.DefinitionText LIKE N'%IF %'
                      OR pc.DefinitionText LIKE N'%WHILE %'
                      OR pc.DefinitionText LIKE N'%CASE %'
                        THEN 1
                    ELSE 0
                END
                AS BIT
            ),
        UsesTempObjects =
            CAST
            (
                CASE
                    WHEN pc.DefinitionText LIKE N'%#%'
                        THEN 1
                    ELSE 0
                END
                AS BIT
            ),
        HasOptionalParameterHint =
            CAST
            (
                CASE
                    WHEN pc.DefinitionText LIKE N'%@%=%'
                        THEN 1
                    ELSE 0
                END
                AS BIT
            ),
        HasExistingRecompileHint =
            CAST
            (
                CASE
                    WHEN pc.DefinitionText LIKE N'%WITH RECOMPILE%'
                      OR pc.DefinitionText LIKE N'%OPTION (RECOMPILE)%'
                        THEN 1
                    ELSE 0
                END
                AS BIT
            )
    FROM ProcedureCatalog AS pc
),
CachedStats AS
(
    SELECT
        ps.object_id,
        ps.execution_count,
        total_worker_ms = CAST(ps.total_worker_time / 1000.0 AS DECIMAL(18,3)),
        total_elapsed_ms = CAST(ps.total_elapsed_time / 1000.0 AS DECIMAL(18,3)),
        avg_worker_ms = CAST((ps.total_worker_time * 1.0 / NULLIF(ps.execution_count, 0)) / 1000.0 AS DECIMAL(18,3)),
        avg_elapsed_ms = CAST((ps.total_elapsed_time * 1.0 / NULLIF(ps.execution_count, 0)) / 1000.0 AS DECIMAL(18,3)),
        avg_logical_reads = CAST(ps.total_logical_reads * 1.0 / NULLIF(ps.execution_count, 0) AS DECIMAL(18,2)),
        ps.cached_time,
        ps.last_execution_time
    FROM sys.dm_exec_procedure_stats AS ps
    WHERE ps.database_id = DB_ID()
),
Evidence AS
(
    SELECT
        DatabaseName = DB_NAME(),
        pc.SchemaName,
        pc.ProcedureName,
        pc.QualifiedName,
        ParameterCount = COALESCE(par.ParameterCount, 0),
        OutputParameterCount = COALESCE(par.OutputParameterCount, 0),
        execution_count = COALESCE(cs.execution_count, 0),
        cs.total_worker_ms,
        cs.total_elapsed_ms,
        cs.avg_worker_ms,
        cs.avg_elapsed_ms,
        cs.avg_logical_reads,
        cs.cached_time,
        cs.last_execution_time,
        ms.HasDynamicSql,
        ms.HasControlFlow,
        ms.UsesTempObjects,
        ms.HasOptionalParameterHint,
        ms.HasExistingRecompileHint,
        HelpfulScore =
              CASE WHEN COALESCE(par.ParameterCount, 0) >= 4 THEN 2 ELSE 0 END
            + CASE WHEN COALESCE(par.OutputParameterCount, 0) > 0 THEN 1 ELSE 0 END
            + CASE WHEN ms.HasOptionalParameterHint = 1 THEN 2 ELSE 0 END
            + CASE WHEN ms.HasControlFlow = 1 THEN 2 ELSE 0 END
            + CASE WHEN ms.UsesTempObjects = 1 THEN 1 ELSE 0 END
            + CASE WHEN COALESCE(cs.execution_count, 0) >= @MinExecutionCount THEN 1 ELSE 0 END
            + CASE WHEN COALESCE(cs.avg_worker_ms, 0.000) >= @HighAvgWorkerMs THEN 2 ELSE 0 END
            + CASE WHEN COALESCE(cs.avg_logical_reads, 0.00) >= 5000.00 THEN 1 ELSE 0 END,
        RiskScore =
              CASE WHEN ms.HasExistingRecompileHint = 1 THEN 3 ELSE 0 END
            + CASE WHEN ms.HasDynamicSql = 1 THEN 2 ELSE 0 END
            + CASE WHEN COALESCE(cs.execution_count, 0) >= (@MinExecutionCount * 20) AND COALESCE(cs.avg_worker_ms, 0.000) < 2.000 THEN 3 ELSE 0 END
            + CASE WHEN COALESCE(cs.execution_count, 0) >= (@MinExecutionCount * 5) AND COALESCE(cs.avg_worker_ms, 0.000) < 5.000 THEN 1 ELSE 0 END
            + CASE WHEN COALESCE(cs.execution_count, 0) = 0 THEN 2 ELSE 0 END
            + CASE WHEN COALESCE(par.ParameterCount, 0) <= 1 AND ms.HasControlFlow = 0 AND ms.HasOptionalParameterHint = 0 THEN 1 ELSE 0 END
    FROM ProcedureCatalog AS pc
    LEFT JOIN ParameterStats AS par
        ON pc.object_id = par.object_id
    LEFT JOIN ModuleSignals AS ms
        ON pc.object_id = ms.object_id
    LEFT JOIN CachedStats AS cs
        ON pc.object_id = cs.object_id
),
DecisionMatrix AS
(
    SELECT
        e.*,
        NetScore = e.HelpfulScore - e.RiskScore,
        Recommendation =
            CASE
                WHEN e.HelpfulScore >= 6 AND e.RiskScore <= 3 THEN N'helpful'
                WHEN e.RiskScore >= 6 AND e.HelpfulScore <= 4 THEN N'risky'
                ELSE N'balanced'
            END
    FROM Evidence AS e
)
SELECT TOP (@TopN)
    dm.DatabaseName,
    dm.SchemaName,
    dm.ProcedureName,
    dm.QualifiedName,
    dm.Recommendation,
    dm.HelpfulScore,
    dm.RiskScore,
    dm.NetScore,
    dm.ParameterCount,
    dm.OutputParameterCount,
    dm.execution_count,
    dm.avg_worker_ms,
    dm.avg_elapsed_ms,
    dm.avg_logical_reads,
    dm.HasOptionalParameterHint,
    dm.HasControlFlow,
    dm.HasDynamicSql,
    dm.HasExistingRecompileHint,
    DecisionText =
        CASE
            WHEN dm.Recommendation = N'helpful'
                THEN N'WITH RECOMPILE kann hier als gezielte Test- oder Entlastungsstrategie sinnvoll sein, wenn planabhaengige Unterschiede reproduzierbar sind.'
            WHEN dm.Recommendation = N'risky'
                THEN N'WITH RECOMPILE wirkt hier eher riskant oder vorschnell; zuerst Compile-Kosten, Dynamic-SQL-Alternativen oder vorhandene Hinweise pruefen.'
            ELSE N'Gemischtes Bild: erst messen, Plaene vergleichen und nur bei klaren Abweichungen gezielt recompilieren.'
        END,
    PrimaryHelpfulReason =
        CASE
            WHEN dm.HasOptionalParameterHint = 1 AND dm.HasControlFlow = 1
                THEN N'Optionale Parameter kombiniert mit Verzweigungslogik'
            WHEN dm.avg_worker_ms >= @HighAvgWorkerMs
                THEN N'Hoehere durchschnittliche Worker-Zeit pro Ausfuehrung'
            WHEN dm.ParameterCount >= 4
                THEN N'Viele Parameter mit moeglich unterschiedlichen Pfaden'
            ELSE N'Kombination mehrerer Indizien fuer planabhaengige Ausfuehrungen'
        END,
    PrimaryRiskReason =
        CASE
            WHEN dm.HasExistingRecompileHint = 1
                THEN N'Procedure nutzt bereits einen Recompile-Hinweis'
            WHEN dm.HasDynamicSql = 1
                THEN N'Dynamic SQL kann eine alternative Planstabilisierungsstrategie sein'
            WHEN dm.execution_count = 0
                THEN N'Keine Cache-Daten vorhanden; Empfehlung waere derzeit spekulativ'
            WHEN dm.execution_count >= (@MinExecutionCount * 20) AND COALESCE(dm.avg_worker_ms, 0.000) < 2.000
                THEN N'Hohe Ausfuehrungszahl bei niedriger Laufzeit deutet auf Compile-Overhead-Risiko'
            ELSE N'Kein dominanter Einzelfaktor; Nutzen und Risiko liegen nah beieinander'
        END,
    dm.cached_time,
    dm.last_execution_time
FROM DecisionMatrix AS dm
ORDER BY
    CASE dm.Recommendation
        WHEN N'helpful' THEN 1
        WHEN N'balanced' THEN 2
        ELSE 3
    END,
    dm.NetScore DESC,
    dm.avg_worker_ms DESC,
    dm.execution_count DESC,
    dm.QualifiedName;

SELECT
    dm.DatabaseName,
    dm.SchemaName,
    dm.ProcedureName,
    dm.QualifiedName,
    dm.Recommendation,
    dm.HelpfulScore,
    dm.RiskScore,
    dm.NetScore,
    ParameterComplexitySignal = CASE WHEN dm.ParameterCount >= 4 THEN N'yes' ELSE N'no' END,
    OutputParameterSignal = CASE WHEN dm.OutputParameterCount > 0 THEN N'yes' ELSE N'no' END,
    OptionalParameterSignal = CASE WHEN dm.HasOptionalParameterHint = 1 THEN N'yes' ELSE N'no' END,
    ControlFlowSignal = CASE WHEN dm.HasControlFlow = 1 THEN N'yes' ELSE N'no' END,
    TempObjectSignal = CASE WHEN dm.UsesTempObjects = 1 THEN N'yes' ELSE N'no' END,
    DynamicSqlSignal = CASE WHEN dm.HasDynamicSql = 1 THEN N'yes' ELSE N'no' END,
    ExistingRecompileSignal = CASE WHEN dm.HasExistingRecompileHint = 1 THEN N'yes' ELSE N'no' END,
    EnoughExecutionHistorySignal = CASE WHEN dm.execution_count >= @MinExecutionCount THEN N'yes' ELSE N'no' END,
    HighWorkerTimeSignal = CASE WHEN COALESCE(dm.avg_worker_ms, 0.000) >= @HighAvgWorkerMs THEN N'yes' ELSE N'no' END,
    CompileOverheadRiskSignal =
        CASE
            WHEN dm.execution_count >= (@MinExecutionCount * 20) AND COALESCE(dm.avg_worker_ms, 0.000) < 2.000
                THEN N'yes'
            ELSE N'no'
        END,
    dm.execution_count,
    dm.total_worker_ms,
    dm.total_elapsed_ms,
    dm.avg_worker_ms,
    dm.avg_elapsed_ms,
    dm.avg_logical_reads,
    dm.cached_time,
    dm.last_execution_time
FROM DecisionMatrix AS dm
ORDER BY
    dm.NetScore DESC,
    dm.QualifiedName;

SELECT
    NoteOrder,
    NoteTitle,
    NoteText
FROM
(
    VALUES
        (1, N'Recompile ist ein Werkzeug, kein Default', N'WITH RECOMPILE ist vor allem dann interessant, wenn dieselbe Procedure unter verschiedenen Parametern deutlich verschiedene Planformen braucht.'),
        (2, N'Risiko fuer haeufige leichte Procedures', N'Bei sehr oft ausgefuehrten und zugleich billigen Procedures kann die wiederholte Kompilierung teurer sein als der eigentliche Lauf.'),
        (3, N'Dynamic SQL gesondert beurteilen', N'Wenn die Procedure bereits Dynamic SQL einsetzt, kann dies selbst schon eine Strategie fuer parameterabhaengige Plantrennung sein.'),
        (4, N'Vorhandene Hinweise bestaetigen', N'Bestehende WITH RECOMPILE- oder OPTION (RECOMPILE)-Hinweise sollten erst fachlich bestaetigt werden, bevor weitere Recompile-Strategien aufgebaut werden.'),
        (5, N'Ohne Metriken keine starke Aussage', N'Fehlende DMV-Daten bedeuten nicht, dass Recompile falsch oder richtig ist. In diesem Fall sollte zuerst beobachtet oder gezielt getestet werden.')
) AS notes(NoteOrder, NoteTitle, NoteText)
ORDER BY
    NoteOrder;
