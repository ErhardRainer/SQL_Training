/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "ForeignKeyCascadeMap.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "16_DataIntegrity_Constraints"

purpose: >
  Liest die Foreign-Key-Metadaten der aktuellen Datenbank aus und erzeugt
  daraus eine Kaskadenkarte, die Delete- und Update-Regeln, beteiligte
  Tabellenseiten sowie eine Mermaid-taugliche Edge-Liste zusammenfasst.

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
  - name: "@IncludeNoAction"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 zeigt auch Foreign Keys ohne Folgeaktion; 0 fokussiert auf Cascade- oder Set-Regeln."
  - name: "@IncludeDisabled"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 laesst deaktivierte Foreign Keys in der Karte stehen; 0 blendet sie aus."

result_sets:
  - name: "ForeignKeyCascadeMap"
    description: "Detailkarte je Foreign Key mit Richtungsbezug, Spaltenabbildung und Delete-/Update-Regeln."
  - name: "CascadeActionSummary"
    description: "Verdichtung je referenzierter Tabelle und Aktionsart mit Anzahl und Zieltabellen."
  - name: "CascadeMermaidEdges"
    description: "Mermaid-taugliche Kantenliste mit Aktionstext und Statushinweisen."

dependencies:
  - "sys.schemas"
  - "sys.tables"
  - "sys.foreign_keys"
  - "sys.foreign_key_columns"
  - "sys.columns"
  - "DB_NAME()"
  - "STRING_AGG()"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/16_DataIntegrity_Constraints/SQLScripts/ForeignKeyCascadeMap.md"
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
    description: "Erstversion einer Kaskadenkarte fuer Foreign-Key-Regeln."

notes:
  - "Die Analyse liest ausschliesslich Katalogsichten der aktuellen Datenbank."
  - "Als Kaskadenregeln zaehlen CASCADE, SET_NULL und SET_DEFAULT, da diese Folgeaktionen auf der Kindtabelle ausloesen."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @SchemaName SYSNAME = NULL;
DECLARE @TableNamePattern NVARCHAR(128) = NULL;
DECLARE @IncludeNoAction BIT = 0;
DECLARE @IncludeDisabled BIT = 1;

IF @IncludeNoAction NOT IN (0, 1)
BEGIN
    THROW 50000, '@IncludeNoAction muss 0 oder 1 sein.', 1;
END;

IF @IncludeDisabled NOT IN (0, 1)
BEGIN
    THROW 50001, '@IncludeDisabled muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #ForeignKeyCascadeMap;

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
    parent_schema.name AS ReferencedSchemaName,
    parent_table.name AS ReferencedTableName,
    child_schema.name AS ReferencingSchemaName,
    child_table.name AS ReferencingTableName,
    colmap.ReferencedColumns,
    colmap.ReferencingColumns,
    fk.delete_referential_action_desc AS DeleteActionDesc,
    fk.update_referential_action_desc AS UpdateActionDesc,
    CAST(CASE WHEN fk.delete_referential_action_desc <> N'NO_ACTION' THEN 1 ELSE 0 END AS BIT) AS HasDeleteCascadeBehavior,
    CAST(CASE WHEN fk.update_referential_action_desc <> N'NO_ACTION' THEN 1 ELSE 0 END AS BIT) AS HasUpdateCascadeBehavior,
    CAST(CASE WHEN fk.delete_referential_action_desc <> N'NO_ACTION' OR fk.update_referential_action_desc <> N'NO_ACTION' THEN 1 ELSE 0 END AS BIT) AS HasAnyCascadeBehavior,
    fk.is_disabled AS IsDisabled,
    fk.is_not_trusted AS IsNotTrusted,
    CASE
        WHEN fk.is_disabled = 1 THEN N'disabled'
        WHEN fk.is_not_trusted = 1 THEN N'untrusted'
        ELSE N'active'
    END AS IntegrityStatus,
    CONCAT(parent_schema.name, N'.', parent_table.name) AS ReferencedTable,
    CONCAT(child_schema.name, N'.', child_table.name) AS ReferencingTable
INTO #ForeignKeyCascadeMap
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
      )
  AND (
        @IncludeDisabled = 1
        OR fk.is_disabled = 0
      )
  AND (
        @IncludeNoAction = 1
        OR fk.delete_referential_action_desc <> N'NO_ACTION'
        OR fk.update_referential_action_desc <> N'NO_ACTION'
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
    HasDeleteCascadeBehavior,
    HasUpdateCascadeBehavior,
    HasAnyCascadeBehavior,
    IntegrityStatus,
    IsDisabled,
    IsNotTrusted
FROM #ForeignKeyCascadeMap
ORDER BY
    ReferencedSchemaName,
    ReferencedTableName,
    ReferencingSchemaName,
    ReferencingTableName,
    ForeignKeyName;

WITH ActionRows AS
(
    SELECT
        ReferencedTable,
        ReferencingTable,
        CAST(N'DELETE' AS NVARCHAR(10)) AS CascadeMode,
        DeleteActionDesc AS CascadeAction,
        IntegrityStatus,
        ForeignKeyName
    FROM #ForeignKeyCascadeMap

    UNION ALL

    SELECT
        ReferencedTable,
        ReferencingTable,
        CAST(N'UPDATE' AS NVARCHAR(10)),
        UpdateActionDesc,
        IntegrityStatus,
        ForeignKeyName
    FROM #ForeignKeyCascadeMap
)
SELECT
    ReferencedTable,
    CascadeMode,
    CascadeAction,
    COUNT(*) AS ForeignKeyCount,
    COUNT(DISTINCT ReferencingTable) AS DistinctTargetTables,
    STRING_AGG(CONCAT(ReferencingTable, N' [', ForeignKeyName, N']'), N' || ')
        WITHIN GROUP (ORDER BY ReferencingTable, ForeignKeyName) AS TargetMap
FROM ActionRows
WHERE @IncludeNoAction = 1
   OR CascadeAction <> N'NO_ACTION'
GROUP BY
    ReferencedTable,
    CascadeMode,
    CascadeAction
ORDER BY
    ReferencedTable,
    CascadeMode,
    CASE
        WHEN CascadeAction = N'CASCADE' THEN 1
        WHEN CascadeAction = N'SET_NULL' THEN 2
        WHEN CascadeAction = N'SET_DEFAULT' THEN 3
        ELSE 4
    END,
    CascadeAction;

WITH MermaidEdges AS
(
    SELECT
        ReferencedTable,
        ReferencingTable,
        ForeignKeyName,
        CAST(N'DELETE' AS NVARCHAR(10)) AS CascadeMode,
        DeleteActionDesc AS CascadeAction,
        IntegrityStatus
    FROM #ForeignKeyCascadeMap

    UNION ALL

    SELECT
        ReferencedTable,
        ReferencingTable,
        ForeignKeyName,
        CAST(N'UPDATE' AS NVARCHAR(10)),
        UpdateActionDesc,
        IntegrityStatus
    FROM #ForeignKeyCascadeMap
)
SELECT
    CONCAT(N'[', ReferencedTable, N'] -->|', CascadeMode, N': ', CascadeAction, N'| [', ReferencingTable, N']') AS MermaidEdge,
    ReferencedTable AS SourceTable,
    ReferencingTable AS TargetTable,
    CascadeMode,
    CascadeAction,
    ForeignKeyName,
    IntegrityStatus
FROM MermaidEdges
WHERE @IncludeNoAction = 1
   OR CascadeAction <> N'NO_ACTION'
ORDER BY
    SourceTable,
    TargetTable,
    CascadeMode,
    ForeignKeyName;

DROP TABLE IF EXISTS #ForeignKeyCascadeMap;
