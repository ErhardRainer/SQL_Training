/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "ConstraintDependencyMap.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "16_DataIntegrity_Constraints"

purpose: >
  Baut in tempdb ein kleines Constraint-Demo-Modell auf und zeichnet danach
  ueber Katalogsichten nach, welche Constraints an welche Tabellen, Spalten
  und Referenzobjekte gebunden sind.

parameters:
  - name: "@IncludeSystemNamed"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 zeigt auch systembenannte Constraints; 0 fokussiert auf explizit benannte Regeln."
  - name: "@ResetDemoObjects"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 baut das Demo-Modell in tempdb vor der Analyse neu auf."
  - name: "@DropDemoObjects"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 entfernt die Demo-Objekte am Ende wieder aus tempdb."

result_sets:
  - name: "ConstraintDependencyMap"
    description: "Detailsicht je Constraint mit Elternobjekt, betroffenen Spalten und optionalem Referenzobjekt."
  - name: "ObjectDependencySummary"
    description: "Verdichtung pro Tabelle mit Anzahl und Typmix der zugeordneten Constraints."
  - name: "DependencyEdges"
    description: "Mermaid-taugliche Kantenliste zwischen Constraint-, Tabellen- und Spaltenknoten."

dependencies:
  - "tempdb"
  - "sys.objects"
  - "sys.schemas"
  - "sys.tables"
  - "sys.columns"
  - "sys.index_columns"
  - "sys.key_constraints"
  - "sys.foreign_keys"
  - "sys.foreign_key_columns"
  - "sys.check_constraints"
  - "sys.default_constraints"
  - "STRING_AGG()"
  - "DROP TABLE IF EXISTS"

safety:
  level: "demo-write-tempdb"
  writes_data: true

documentation:
  markdown_file: "T-SQL/16_DataIntegrity_Constraints/SQLScripts/ConstraintDependencyMap.md"
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
    date: "2026-04-18"
    user: "ER"
    description: "Erstversion eines didaktischen Constraint-Abhaengigkeitsreports auf Basis von tempdb-Metadaten."

notes:
  - "Die Erstversion erzeugt ein kleines Demo-Modell in tempdb, damit Constraint-Typen und Beziehungen reproduzierbar sichtbar werden."
  - "Die Abhaengigkeitskarte liest ausschliesslich Katalogsichten und schreibt nach dem Aufbau keine produktiven Daten um."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @IncludeSystemNamed BIT = 0;
DECLARE @ResetDemoObjects BIT = 1;
DECLARE @DropDemoObjects BIT = 1;

IF @IncludeSystemNamed NOT IN (0, 1)
BEGIN
    THROW 50000, '@IncludeSystemNamed muss 0 oder 1 sein.', 1;
END;

IF @ResetDemoObjects NOT IN (0, 1)
BEGIN
    THROW 50001, '@ResetDemoObjects muss 0 oder 1 sein.', 1;
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

IF @ResetDemoObjects = 1
BEGIN
    DROP TABLE IF EXISTS demo.ConstraintAuditLog;
    DROP TABLE IF EXISTS demo.ConstraintChild;
    DROP TABLE IF EXISTS demo.ConstraintParent;

    CREATE TABLE demo.ConstraintParent
    (
        ParentID INT NOT NULL,
        ParentCode NVARCHAR(20) NOT NULL,
        ParentStatus NVARCHAR(20) NOT NULL
            CONSTRAINT DF_ConstraintParent_ParentStatus DEFAULT (N'active'),
        CreditLimit DECIMAL(10, 2) NOT NULL,
        CreatedAtUtc DATETIME2(0) NOT NULL
            CONSTRAINT DF_ConstraintParent_CreatedAtUtc DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_ConstraintParent PRIMARY KEY CLUSTERED (ParentID),
        CONSTRAINT UQ_ConstraintParent_ParentCode UNIQUE (ParentCode),
        CONSTRAINT CK_ConstraintParent_CreditLimit CHECK (CreditLimit >= 0.00),
        CONSTRAINT CK_ConstraintParent_Status CHECK (ParentStatus IN (N'active', N'hold'))
    );

    CREATE TABLE demo.ConstraintChild
    (
        ChildID INT NOT NULL,
        ParentID INT NOT NULL,
        ChildCode NVARCHAR(20) NOT NULL,
        ApprovalState NVARCHAR(20) NOT NULL
            CONSTRAINT DF_ConstraintChild_ApprovalState DEFAULT (N'queued'),
        Quantity INT NOT NULL,
        ReviewNote NVARCHAR(100) NULL,
        CONSTRAINT PK_ConstraintChild PRIMARY KEY CLUSTERED (ChildID),
        CONSTRAINT FK_ConstraintChild_Parent FOREIGN KEY (ParentID)
            REFERENCES demo.ConstraintParent (ParentID),
        CONSTRAINT UQ_ConstraintChild_ChildCode UNIQUE (ChildCode),
        CONSTRAINT CK_ConstraintChild_Quantity CHECK (Quantity BETWEEN 1 AND 500),
        CONSTRAINT CK_ConstraintChild_ApprovalState CHECK (ApprovalState IN (N'queued', N'approved', N'rejected'))
    );

    CREATE TABLE demo.ConstraintAuditLog
    (
        AuditID INT NOT NULL PRIMARY KEY,
        ChildID INT NOT NULL,
        LoggedAtUtc DATETIME2(0) NOT NULL
            CONSTRAINT DF_ConstraintAuditLog_LoggedAtUtc DEFAULT (SYSUTCDATETIME()),
        ResultCode NVARCHAR(20) NOT NULL
            CONSTRAINT DF_ConstraintAuditLog_ResultCode DEFAULT (N'captured'),
        CONSTRAINT FK_ConstraintAuditLog_Child FOREIGN KEY (ChildID)
            REFERENCES demo.ConstraintChild (ChildID),
        CONSTRAINT CK_ConstraintAuditLog_ResultCode CHECK (ResultCode IN (N'captured', N'ignored', N'fixed'))
    );

    INSERT INTO demo.ConstraintParent
    (
        ParentID,
        ParentCode,
        ParentStatus,
        CreditLimit
    )
    VALUES
        (1, N'P-100', N'active', 1500.00),
        (2, N'P-200', N'hold', 250.00);

    INSERT INTO demo.ConstraintChild
    (
        ChildID,
        ParentID,
        ChildCode,
        ApprovalState,
        Quantity,
        ReviewNote
    )
    VALUES
        (10, 1, N'C-010', N'approved', 12, N'first batch'),
        (11, 1, N'C-011', N'queued', 4, NULL),
        (12, 2, N'C-012', N'rejected', 2, N'manual review');

    INSERT INTO demo.ConstraintAuditLog
    (
        AuditID,
        ChildID,
        ResultCode
    )
    VALUES
        (100, 10, N'captured'),
        (101, 11, N'fixed'),
        (102, 12, N'ignored');
END;

DROP TABLE IF EXISTS #ConstraintColumnMap;
CREATE TABLE #ConstraintColumnMap
(
    ConstraintObjectID INT NOT NULL,
    ParentColumnList NVARCHAR(400) NULL,
    ReferencedColumnList NVARCHAR(400) NULL
);

INSERT INTO #ConstraintColumnMap
(
    ConstraintObjectID,
    ParentColumnList,
    ReferencedColumnList
)
SELECT
    kc.object_id,
    STRING_AGG(parent_col.name, N', ') WITHIN GROUP (ORDER BY ic.key_ordinal),
    CAST(NULL AS NVARCHAR(400))
FROM sys.key_constraints AS kc
INNER JOIN sys.index_columns AS ic
    ON ic.object_id = kc.parent_object_id
   AND ic.index_id = kc.unique_index_id
INNER JOIN sys.columns AS parent_col
    ON parent_col.object_id = ic.object_id
   AND parent_col.column_id = ic.column_id
WHERE kc.parent_object_id IN
(
    OBJECT_ID(N'demo.ConstraintParent', N'U'),
    OBJECT_ID(N'demo.ConstraintChild', N'U'),
    OBJECT_ID(N'demo.ConstraintAuditLog', N'U')
)
GROUP BY
    kc.object_id;

INSERT INTO #ConstraintColumnMap
(
    ConstraintObjectID,
    ParentColumnList,
    ReferencedColumnList
)
SELECT
    fk.object_id,
    STRING_AGG(parent_col.name, N', ') WITHIN GROUP (ORDER BY fkc.constraint_column_id),
    STRING_AGG(ref_col.name, N', ') WITHIN GROUP (ORDER BY fkc.constraint_column_id)
FROM sys.foreign_keys AS fk
INNER JOIN sys.foreign_key_columns AS fkc
    ON fkc.constraint_object_id = fk.object_id
INNER JOIN sys.columns AS parent_col
    ON parent_col.object_id = fkc.parent_object_id
   AND parent_col.column_id = fkc.parent_column_id
INNER JOIN sys.columns AS ref_col
    ON ref_col.object_id = fkc.referenced_object_id
   AND ref_col.column_id = fkc.referenced_column_id
WHERE fk.parent_object_id IN
(
    OBJECT_ID(N'demo.ConstraintParent', N'U'),
    OBJECT_ID(N'demo.ConstraintChild', N'U'),
    OBJECT_ID(N'demo.ConstraintAuditLog', N'U')
)
GROUP BY
    fk.object_id;

INSERT INTO #ConstraintColumnMap
(
    ConstraintObjectID,
    ParentColumnList,
    ReferencedColumnList
)
SELECT
    cc.object_id,
    STRING_AGG(col.name, N', ') WITHIN GROUP (ORDER BY col.column_id),
    CAST(NULL AS NVARCHAR(400))
FROM sys.check_constraints AS cc
INNER JOIN sys.columns AS col
    ON col.object_id = cc.parent_object_id
   AND (cc.parent_column_id = 0 OR cc.parent_column_id = col.column_id)
WHERE cc.parent_object_id IN
(
    OBJECT_ID(N'demo.ConstraintParent', N'U'),
    OBJECT_ID(N'demo.ConstraintChild', N'U'),
    OBJECT_ID(N'demo.ConstraintAuditLog', N'U')
)
GROUP BY
    cc.object_id;

INSERT INTO #ConstraintColumnMap
(
    ConstraintObjectID,
    ParentColumnList,
    ReferencedColumnList
)
SELECT
    dc.object_id,
    col.name,
    CAST(NULL AS NVARCHAR(400))
FROM sys.default_constraints AS dc
INNER JOIN sys.columns AS col
    ON col.object_id = dc.parent_object_id
   AND col.column_id = dc.parent_column_id
WHERE dc.parent_object_id IN
(
    OBJECT_ID(N'demo.ConstraintParent', N'U'),
    OBJECT_ID(N'demo.ConstraintChild', N'U'),
    OBJECT_ID(N'demo.ConstraintAuditLog', N'U')
);

DROP TABLE IF EXISTS #ConstraintDependencyMap;
WITH ConstraintBase AS
(
    SELECT
        kc.object_id AS ConstraintObjectID,
        kc.name AS ConstraintName,
        N'KEY' AS ConstraintFamily,
        CASE kc.type
            WHEN 'PK' THEN N'PRIMARY_KEY'
            WHEN 'UQ' THEN N'UNIQUE'
            ELSE kc.type_desc
        END AS ConstraintType,
        kc.parent_object_id AS ParentObjectID,
        CAST(NULL AS INT) AS ReferencedObjectID,
        kc.is_system_named,
        CAST(0 AS BIT) AS IsDisabled,
        CAST(0 AS BIT) AS IsNotTrusted,
        CAST(NULL AS NVARCHAR(4000)) AS ConstraintDefinition
    FROM sys.key_constraints AS kc

    UNION ALL

    SELECT
        fk.object_id,
        fk.name,
        N'REFERENTIAL',
        N'FOREIGN_KEY',
        fk.parent_object_id,
        fk.referenced_object_id,
        fk.is_system_named,
        fk.is_disabled,
        fk.is_not_trusted,
        CAST(NULL AS NVARCHAR(4000))
    FROM sys.foreign_keys AS fk

    UNION ALL

    SELECT
        cc.object_id,
        cc.name,
        N'VALIDATION',
        N'CHECK',
        cc.parent_object_id,
        CAST(NULL AS INT),
        cc.is_system_named,
        cc.is_disabled,
        cc.is_not_trusted,
        cc.definition
    FROM sys.check_constraints AS cc

    UNION ALL

    SELECT
        dc.object_id,
        dc.name,
        N'VALUE_FILL',
        N'DEFAULT',
        dc.parent_object_id,
        CAST(NULL AS INT),
        dc.is_system_named,
        CAST(0 AS BIT),
        CAST(0 AS BIT),
        dc.definition
    FROM sys.default_constraints AS dc
)
SELECT
    cb.ConstraintName,
    cb.ConstraintFamily,
    cb.ConstraintType,
    parent_schema.name AS ParentSchemaName,
    parent_obj.name AS ParentObjectName,
    parent_obj.type_desc AS ParentObjectType,
    ISNULL(colmap.ParentColumnList, N'(table-scope)') AS ParentColumns,
    ref_schema.name AS ReferencedSchemaName,
    ref_obj.name AS ReferencedObjectName,
    ISNULL(colmap.ReferencedColumnList, N'(none)') AS ReferencedColumns,
    cb.is_system_named AS IsSystemNamed,
    cb.IsDisabled,
    cb.IsNotTrusted,
    cb.ConstraintDefinition,
    CASE
        WHEN cb.ConstraintType = N'FOREIGN_KEY' THEN N'constraint -> parent table -> referenced table'
        WHEN cb.ConstraintType IN (N'PRIMARY_KEY', N'UNIQUE') THEN N'constraint -> table -> key columns'
        WHEN cb.ConstraintType = N'CHECK' THEN N'constraint -> table -> guarded columns'
        WHEN cb.ConstraintType = N'DEFAULT' THEN N'constraint -> table -> defaulted column'
        ELSE N'constraint -> object'
    END AS DependencyNarrative
INTO #ConstraintDependencyMap
FROM ConstraintBase AS cb
INNER JOIN sys.objects AS parent_obj
    ON parent_obj.object_id = cb.ParentObjectID
INNER JOIN sys.schemas AS parent_schema
    ON parent_schema.schema_id = parent_obj.schema_id
LEFT JOIN sys.objects AS ref_obj
    ON ref_obj.object_id = cb.ReferencedObjectID
LEFT JOIN sys.schemas AS ref_schema
    ON ref_schema.schema_id = ref_obj.schema_id
LEFT JOIN #ConstraintColumnMap AS colmap
    ON colmap.ConstraintObjectID = cb.ConstraintObjectID
WHERE cb.ParentObjectID IN
(
    OBJECT_ID(N'demo.ConstraintParent', N'U'),
    OBJECT_ID(N'demo.ConstraintChild', N'U'),
    OBJECT_ID(N'demo.ConstraintAuditLog', N'U')
)
  AND (@IncludeSystemNamed = 1 OR cb.is_system_named = 0);

SELECT
    ConstraintName,
    ConstraintFamily,
    ConstraintType,
    ParentSchemaName,
    ParentObjectName,
    ParentObjectType,
    ParentColumns,
    ReferencedSchemaName,
    ReferencedObjectName,
    ReferencedColumns,
    IsSystemNamed,
    IsDisabled,
    IsNotTrusted,
    ConstraintDefinition,
    DependencyNarrative
FROM #ConstraintDependencyMap
ORDER BY
    ParentObjectName,
    ConstraintType,
    ConstraintName;

SELECT
    ParentSchemaName,
    ParentObjectName,
    COUNT(*) AS ConstraintCount,
    SUM(CASE WHEN ConstraintType = N'PRIMARY_KEY' THEN 1 ELSE 0 END) AS PrimaryKeyCount,
    SUM(CASE WHEN ConstraintType = N'UNIQUE' THEN 1 ELSE 0 END) AS UniqueCount,
    SUM(CASE WHEN ConstraintType = N'FOREIGN_KEY' THEN 1 ELSE 0 END) AS ForeignKeyCount,
    SUM(CASE WHEN ConstraintType = N'CHECK' THEN 1 ELSE 0 END) AS CheckCount,
    SUM(CASE WHEN ConstraintType = N'DEFAULT' THEN 1 ELSE 0 END) AS DefaultCount,
    STRING_AGG(ConstraintName, N', ') WITHIN GROUP (ORDER BY ConstraintName) AS ConstraintList
FROM #ConstraintDependencyMap
GROUP BY
    ParentSchemaName,
    ParentObjectName
ORDER BY
    ParentObjectName;

SELECT
    CONCAT(N'constraint:', ConstraintName) AS SourceNode,
    CONCAT(N'table:', ParentSchemaName, N'.', ParentObjectName) AS TargetNode,
    N'owned-by' AS EdgeType
FROM #ConstraintDependencyMap

UNION ALL

SELECT
    CONCAT(N'constraint:', ConstraintName),
    CONCAT(N'columns:', ParentSchemaName, N'.', ParentObjectName, N'(', ParentColumns, N')'),
    N'guards-columns'
FROM #ConstraintDependencyMap

UNION ALL

SELECT
    CONCAT(N'constraint:', ConstraintName),
    CONCAT(N'table:', ReferencedSchemaName, N'.', ReferencedObjectName),
    N'references-table'
FROM #ConstraintDependencyMap
WHERE ReferencedObjectName IS NOT NULL
ORDER BY
    SourceNode,
    EdgeType,
    TargetNode;

DROP TABLE IF EXISTS #ConstraintDependencyMap;
DROP TABLE IF EXISTS #ConstraintColumnMap;

IF @DropDemoObjects = 1
BEGIN
    DROP TABLE IF EXISTS demo.ConstraintAuditLog;
    DROP TABLE IF EXISTS demo.ConstraintChild;
    DROP TABLE IF EXISTS demo.ConstraintParent;
END;
