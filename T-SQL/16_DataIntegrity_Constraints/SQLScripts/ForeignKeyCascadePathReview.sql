/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "ForeignKeyCascadePathReview.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "16_DataIntegrity_Constraints"

purpose: >
  Analysiert Foreign-Key-Kaskadenpfade der aktuellen Datenbank, listet
  erreichbare Pfade je Starttabelle und markiert Ziele, die ueber mehrere
  unterschiedliche Kaskadenwege erreicht werden koennen.

parameters:
  - name: "@SchemaName"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Optionales Schema fuer referenzierende oder referenzierte Tabellen."
  - name: "@TableNamePattern"
    sql_type: "NVARCHAR(128)"
    direction: "IN"
    required: false
    description: "Optionales LIKE-Muster fuer beteiligte Tabellennamen."
  - name: "@IncludeSetActions"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 bewertet SET_NULL und SET_DEFAULT als Folgepfade; 0 fokussiert nur auf CASCADE."
  - name: "@MaxDepth"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Begrenzt die rekursive Pfadexpansion fuer die Diagnose."

result_sets:
  - name: "ForeignKeyEdgeInventory"
    description: "Inventar relevanter Foreign Keys mit Delete-/Update-Regeln und Kaskadenmarkierung."
  - name: "CascadePathReview"
    description: "Rekursive Pfadliste pro Root, Ziel und Modus inklusive Flag fuer Mehrfachpfade."
  - name: "MultiplePathRiskSummary"
    description: "Verdichtung je Root, Ziel und Modus fuer Ziele mit mehr als einem Kaskadenpfad."

dependencies:
  - "sys.schemas"
  - "sys.tables"
  - "sys.foreign_keys"
  - "sys.foreign_key_columns"
  - "sys.columns"
  - "DB_NAME()"
  - "STRING_AGG()"
  - "DROP TABLE IF EXISTS"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/16_DataIntegrity_Constraints/SQLScripts/ForeignKeyCascadePathReview.md"
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
    description: "Erstversion einer Pfadpruefung fuer potenzielle Mehrfachpfade bei FK-Kaskaden."

notes:
  - "Die Analyse arbeitet nur mit Metadaten der aktuellen Datenbank und fuehrt keine DELETE- oder UPDATE-Operationen aus."
  - "Mehrfachpfade sind Review-Signale fuer Design und Betriebsrisiken, nicht automatisch ein fachlicher Fehler."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @SchemaName SYSNAME = NULL;
DECLARE @TableNamePattern NVARCHAR(128) = NULL;
DECLARE @IncludeSetActions BIT = 1;
DECLARE @MaxDepth INT = 8;

IF @IncludeSetActions NOT IN (0, 1)
BEGIN
    THROW 50000, '@IncludeSetActions muss 0 oder 1 sein.', 1;
END;

IF @MaxDepth < 1
BEGIN
    THROW 50001, '@MaxDepth muss groesser oder gleich 1 sein.', 1;
END;

DROP TABLE IF EXISTS #ForeignKeyEdges;

WITH ForeignKeyColumnMap AS
(
    SELECT
        fk.object_id AS ForeignKeyObjectID,
        STRING_AGG(child_col.name, N', ') WITHIN GROUP (ORDER BY fkc.constraint_column_id) AS ReferencingColumns,
        STRING_AGG(parent_col.name, N', ') WITHIN GROUP (ORDER BY fkc.constraint_column_id) AS ReferencedColumns
    FROM sys.foreign_keys AS fk
    INNER JOIN sys.foreign_key_columns AS fkc
        ON fkc.constraint_object_id = fk.object_id
    INNER JOIN sys.columns AS child_col
        ON child_col.object_id = fkc.parent_object_id
       AND child_col.column_id = fkc.parent_column_id
    INNER JOIN sys.columns AS parent_col
        ON parent_col.object_id = fkc.referenced_object_id
       AND parent_col.column_id = fkc.referenced_column_id
    GROUP BY
        fk.object_id
)
SELECT
    DB_NAME() AS DatabaseName,
    fk.object_id AS ForeignKeyObjectID,
    fk.name AS ForeignKeyName,
    child_schema.name AS ReferencingSchemaName,
    child_table.name AS ReferencingTableName,
    fk.parent_object_id AS ReferencingObjectID,
    parent_schema.name AS ReferencedSchemaName,
    parent_table.name AS ReferencedTableName,
    fk.referenced_object_id AS ReferencedObjectID,
    colmap.ReferencingColumns,
    colmap.ReferencedColumns,
    fk.delete_referential_action_desc AS DeleteActionDesc,
    fk.update_referential_action_desc AS UpdateActionDesc,
    fk.is_disabled AS IsDisabled,
    fk.is_not_trusted AS IsNotTrusted,
    CAST
    (
        CASE
            WHEN fk.delete_referential_action_desc = N'CASCADE'
                THEN 1
            WHEN @IncludeSetActions = 1 AND fk.delete_referential_action_desc IN (N'SET_NULL', N'SET_DEFAULT')
                THEN 1
            ELSE 0
        END AS BIT
    ) AS TracksDeletePath,
    CAST
    (
        CASE
            WHEN fk.update_referential_action_desc = N'CASCADE'
                THEN 1
            WHEN @IncludeSetActions = 1 AND fk.update_referential_action_desc IN (N'SET_NULL', N'SET_DEFAULT')
                THEN 1
            ELSE 0
        END AS BIT
    ) AS TracksUpdatePath,
    CONCAT(parent_schema.name, N'.', parent_table.name) AS ReferencedTable,
    CONCAT(child_schema.name, N'.', child_table.name) AS ReferencingTable
INTO #ForeignKeyEdges
FROM sys.foreign_keys AS fk
INNER JOIN sys.tables AS child_table
    ON child_table.object_id = fk.parent_object_id
INNER JOIN sys.schemas AS child_schema
    ON child_schema.schema_id = child_table.schema_id
INNER JOIN sys.tables AS parent_table
    ON parent_table.object_id = fk.referenced_object_id
INNER JOIN sys.schemas AS parent_schema
    ON parent_schema.schema_id = parent_table.schema_id
INNER JOIN ForeignKeyColumnMap AS colmap
    ON colmap.ForeignKeyObjectID = fk.object_id
WHERE (@SchemaName IS NULL OR child_schema.name = @SchemaName OR parent_schema.name = @SchemaName)
  AND (
        @TableNamePattern IS NULL
        OR child_table.name LIKE @TableNamePattern
        OR parent_table.name LIKE @TableNamePattern
      );

SELECT
    DatabaseName,
    ReferencedSchemaName,
    ReferencedTableName,
    ReferencingSchemaName,
    ReferencingTableName,
    ForeignKeyName,
    ReferencedColumns,
    ReferencingColumns,
    DeleteActionDesc,
    UpdateActionDesc,
    TracksDeletePath,
    TracksUpdatePath,
    IsDisabled,
    IsNotTrusted
FROM #ForeignKeyEdges
ORDER BY
    ReferencedSchemaName,
    ReferencedTableName,
    ReferencingSchemaName,
    ReferencingTableName,
    ForeignKeyName;

DROP TABLE IF EXISTS #CascadePaths;

WITH CascadeSeedEdges AS
(
    SELECT
        ForeignKeyObjectID,
        ForeignKeyName,
        ReferencedObjectID,
        ReferencingObjectID,
        ReferencedTable,
        ReferencingTable,
        CAST(N'DELETE' AS NVARCHAR(10)) AS CascadeMode,
        DeleteActionDesc AS CascadeAction
    FROM #ForeignKeyEdges
    WHERE TracksDeletePath = 1

    UNION ALL

    SELECT
        ForeignKeyObjectID,
        ForeignKeyName,
        ReferencedObjectID,
        ReferencingObjectID,
        ReferencedTable,
        ReferencingTable,
        CAST(N'UPDATE' AS NVARCHAR(10)),
        UpdateActionDesc
    FROM #ForeignKeyEdges
    WHERE TracksUpdatePath = 1
),
CascadePaths AS
(
    SELECT
        seed.CascadeMode,
        seed.CascadeAction,
        seed.ForeignKeyObjectID,
        seed.ForeignKeyName,
        seed.ReferencedObjectID AS RootObjectID,
        seed.ReferencedTable AS RootTable,
        seed.ReferencingObjectID AS CurrentObjectID,
        seed.ReferencingTable AS CurrentTable,
        CAST(1 AS INT) AS CascadeDepth,
        CAST(seed.ReferencedTable + N' -> ' + seed.ReferencingTable AS NVARCHAR(MAX)) AS TablePath,
        CAST(seed.ForeignKeyName AS NVARCHAR(MAX)) AS ForeignKeyPath,
        CAST(seed.CascadeMode + N'|' + seed.ForeignKeyName AS NVARCHAR(MAX)) AS PathSignature,
        CAST(N'|' + CAST(seed.ReferencedObjectID AS NVARCHAR(20)) + N'|' + CAST(seed.ReferencingObjectID AS NVARCHAR(20)) + N'|' AS NVARCHAR(MAX)) AS VisitedObjectIDs
    FROM CascadeSeedEdges AS seed

    UNION ALL

    SELECT
        path.CascadeMode,
        next_edge.CascadeAction,
        next_edge.ForeignKeyObjectID,
        next_edge.ForeignKeyName,
        path.RootObjectID,
        path.RootTable,
        next_edge.ReferencingObjectID,
        next_edge.ReferencingTable,
        path.CascadeDepth + 1,
        CAST(path.TablePath + N' -> ' + next_edge.ReferencingTable AS NVARCHAR(MAX)),
        CAST(path.ForeignKeyPath + N' -> ' + next_edge.ForeignKeyName AS NVARCHAR(MAX)),
        CAST(path.PathSignature + N'|' + next_edge.ForeignKeyName AS NVARCHAR(MAX)),
        CAST(path.VisitedObjectIDs + CAST(next_edge.ReferencingObjectID AS NVARCHAR(20)) + N'|' AS NVARCHAR(MAX))
    FROM CascadePaths AS path
    INNER JOIN CascadeSeedEdges AS next_edge
        ON next_edge.ReferencedObjectID = path.CurrentObjectID
       AND next_edge.CascadeMode = path.CascadeMode
    WHERE path.CascadeDepth < @MaxDepth
      AND path.VisitedObjectIDs NOT LIKE N'%|' + CAST(next_edge.ReferencingObjectID AS NVARCHAR(20)) + N'|%'
)
SELECT
    CascadeMode,
    RootObjectID,
    RootTable,
    CurrentObjectID AS TargetObjectID,
    CurrentTable AS TargetTable,
    CascadeDepth,
    CascadeAction,
    TablePath,
    ForeignKeyPath,
    PathSignature
INTO #CascadePaths
FROM CascadePaths
OPTION (MAXRECURSION 100);

WITH MultiPathTargets AS
(
    SELECT
        CascadeMode,
        RootObjectID,
        TargetObjectID,
        COUNT(*) AS PathCount
    FROM #CascadePaths
    GROUP BY
        CascadeMode,
        RootObjectID,
        TargetObjectID
    HAVING COUNT(*) > 1
)
SELECT
    cp.CascadeMode,
    cp.RootTable,
    cp.TargetTable,
    cp.CascadeDepth,
    cp.CascadeAction,
    cp.TablePath,
    cp.ForeignKeyPath,
    cp.PathSignature,
    CAST(CASE WHEN mpt.PathCount IS NULL THEN 0 ELSE 1 END AS BIT) AS HasMultiplePathsToTarget,
    COALESCE(mpt.PathCount, 1) AS PathCountToTarget
FROM #CascadePaths AS cp
LEFT JOIN MultiPathTargets AS mpt
    ON mpt.CascadeMode = cp.CascadeMode
   AND mpt.RootObjectID = cp.RootObjectID
   AND mpt.TargetObjectID = cp.TargetObjectID
ORDER BY
    cp.CascadeMode,
    cp.RootTable,
    cp.TargetTable,
    cp.CascadeDepth,
    cp.TablePath;

WITH MultiPathTargets AS
(
    SELECT
        CascadeMode,
        RootObjectID,
        RootTable,
        TargetObjectID,
        TargetTable,
        COUNT(*) AS PathCount,
        MAX(CascadeDepth) AS DeepestPath,
        STRING_AGG(TablePath, N' || ') WITHIN GROUP (ORDER BY CascadeDepth, TablePath) AS SampleTablePaths,
        STRING_AGG(ForeignKeyPath, N' || ') WITHIN GROUP (ORDER BY CascadeDepth, ForeignKeyPath) AS SampleForeignKeyPaths
    FROM #CascadePaths
    GROUP BY
        CascadeMode,
        RootObjectID,
        RootTable,
        TargetObjectID,
        TargetTable
    HAVING COUNT(*) > 1
)
SELECT
    CascadeMode,
    RootTable,
    TargetTable,
    PathCount,
    DeepestPath,
    CASE
        WHEN PathCount >= 3 THEN N'REVIEW_MULTIPLE_PATHS_HIGH'
        ELSE N'REVIEW_MULTIPLE_PATHS'
    END AS ReviewLevel,
    SampleTablePaths,
    SampleForeignKeyPaths
FROM MultiPathTargets
ORDER BY
    PathCount DESC,
    DeepestPath DESC,
    CascadeMode,
    RootTable,
    TargetTable;

DROP TABLE IF EXISTS #CascadePaths;
DROP TABLE IF EXISTS #ForeignKeyEdges;
