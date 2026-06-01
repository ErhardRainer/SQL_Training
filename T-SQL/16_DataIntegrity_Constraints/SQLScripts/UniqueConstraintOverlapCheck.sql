/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "UniqueConstraintOverlapCheck.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "16_DataIntegrity_Constraints"

purpose: >
  Findet UNIQUE-Constraints und optional eigenstaendige eindeutige Indizes
  mit identischen oder links-praefixartigen Schluesseldefinitionen. Das
  Skript markiert moegliche Redundanzen, zeigt die beteiligten Spalten in
  Reihenfolge und leitet einen konservativen Review-Backlog ab.

parameters:
  - name: "@SchemaName"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Optionales Schema fuer die Auswertung."
  - name: "@TableNamePattern"
    sql_type: "NVARCHAR(128)"
    direction: "IN"
    required: false
    description: "Optionales LIKE-Muster fuer Tabellennamen."
  - name: "@IncludeUniqueIndexes"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 bezieht eigenstaendige eindeutige Indizes ohne UNIQUE-Constraint ein."
  - name: "@IncludeExactMatches"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 zeigt auch exakt gleiche Schluesselsignaturen in den Paarergebnissen."
  - name: "@MinSharedLeadingColumns"
    sql_type: "TINYINT"
    direction: "IN"
    required: false
    description: "Minimale Zahl gemeinsamer fuehrender Schluesselspalten fuer eine gemeldete Ueberlappung."

result_sets:
  - name: "UniqueDefinitionInventory"
    description: "Inventar aller betrachteten UNIQUE-Definitionen mit Schluesselsignatur und Indexeigenschaften."
  - name: "UniqueOverlapPairs"
    description: "Paarweise Sicht auf identische oder praefixartige UNIQUE-Ueberlappungen je Tabelle."
  - name: "UniqueRedundancyBacklog"
    description: "Konservative Review-Liste mit moeglich redundanten UNIQUE-Definitionen und naechstem Schritt."

dependencies:
  - "sys.tables"
  - "sys.schemas"
  - "sys.indexes"
  - "sys.index_columns"
  - "sys.columns"
  - "sys.key_constraints"
  - "sys.types"
  - "DB_NAME()"
  - "STRING_AGG()"
  - "DROP TABLE IF EXISTS"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/16_DataIntegrity_Constraints/SQLScripts/UniqueConstraintOverlapCheck.md"
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
    description: "Erstversion eines read-only Checks fuer ueberlappende UNIQUE-Definitionen."

notes:
  - "Die Auswertung arbeitet ausschliesslich gegen SQL-Server-Katalogsichten der aktuellen Datenbank."
  - "Eine gemeldete Ueberlappung ist ein Review-Signal und keine automatische Loesch-Empfehlung."
  - "Praefixartige UNIQUE-Indizes koennen trotz Redundanzverdacht fuer Query-Planauswahl oder Governance bewusst erhalten bleiben."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @SchemaName SYSNAME = NULL;
DECLARE @TableNamePattern NVARCHAR(128) = NULL;
DECLARE @IncludeUniqueIndexes BIT = 1;
DECLARE @IncludeExactMatches BIT = 1;
DECLARE @MinSharedLeadingColumns TINYINT = 1;

IF @IncludeUniqueIndexes NOT IN (0, 1)
BEGIN
    THROW 50000, '@IncludeUniqueIndexes muss 0 oder 1 sein.', 1;
END;

IF @IncludeExactMatches NOT IN (0, 1)
BEGIN
    THROW 50001, '@IncludeExactMatches muss 0 oder 1 sein.', 1;
END;

IF @MinSharedLeadingColumns < 1 OR @MinSharedLeadingColumns > 16
BEGIN
    THROW 50002, '@MinSharedLeadingColumns muss zwischen 1 und 16 liegen.', 1;
END;

DROP TABLE IF EXISTS #UniqueDefinitionInventory;
DROP TABLE IF EXISTS #UniqueOverlapPairs;

WITH TableBase AS
(
    SELECT
        t.object_id AS TableObjectID,
        s.name AS SchemaName,
        t.name AS TableName
    FROM sys.tables AS t
    INNER JOIN sys.schemas AS s
        ON s.schema_id = t.schema_id
    WHERE (@SchemaName IS NULL OR s.name = @SchemaName)
      AND (@TableNamePattern IS NULL OR t.name LIKE @TableNamePattern)
      AND t.is_ms_shipped = 0
),
UniqueDefinitions AS
(
    SELECT
        tb.TableObjectID,
        tb.SchemaName,
        tb.TableName,
        idx.index_id AS UniqueIndexID,
        idx.name AS UniqueName,
        idx.type_desc AS UniqueIndexType,
        CAST(CASE WHEN idx.type = 1 THEN 1 ELSE 0 END AS BIT) AS IsClustered,
        CAST(idx.is_unique_constraint AS BIT) AS IsUniqueConstraint,
        CAST(CASE WHEN kc.object_id IS NOT NULL THEN 1 ELSE 0 END AS BIT) AS HasConstraintObject,
        kc.name AS ConstraintName,
        CAST(idx.has_filter AS BIT) AS HasFilter,
        idx.filter_definition AS FilterDefinition,
        idx.fill_factor AS FillFactor,
        idx.ignore_dup_key AS IgnoreDupKey
    FROM TableBase AS tb
    INNER JOIN sys.indexes AS idx
        ON idx.object_id = tb.TableObjectID
    LEFT JOIN sys.key_constraints AS kc
        ON kc.parent_object_id = idx.object_id
       AND kc.unique_index_id = idx.index_id
       AND kc.type = 'UQ'
    WHERE idx.is_unique = 1
      AND idx.is_primary_key = 0
      AND idx.is_hypothetical = 0
      AND
      (
          idx.is_unique_constraint = 1
          OR (@IncludeUniqueIndexes = 1 AND idx.is_unique_constraint = 0)
      )
),
UniqueKeyColumns AS
(
    SELECT
        ud.TableObjectID,
        ud.SchemaName,
        ud.TableName,
        ud.UniqueIndexID,
        ud.UniqueName,
        ud.UniqueIndexType,
        ud.IsClustered,
        ud.IsUniqueConstraint,
        ud.HasConstraintObject,
        ud.ConstraintName,
        ud.HasFilter,
        ud.FilterDefinition,
        ud.FillFactor,
        ud.IgnoreDupKey,
        ic.key_ordinal AS KeyOrdinal,
        col.name AS ColumnName,
        type_info.name AS DataTypeName,
        CASE
            WHEN col.max_length = -1 THEN 8000
            ELSE col.max_length
        END AS DeclaredMaxLengthBytes,
        col.is_nullable AS IsNullable
    FROM UniqueDefinitions AS ud
    INNER JOIN sys.index_columns AS ic
        ON ic.object_id = ud.TableObjectID
       AND ic.index_id = ud.UniqueIndexID
       AND ic.key_ordinal > 0
    INNER JOIN sys.columns AS col
        ON col.object_id = ic.object_id
       AND col.column_id = ic.column_id
    INNER JOIN sys.types AS type_info
        ON type_info.user_type_id = col.user_type_id
    WHERE type_info.is_user_defined = 0
       OR type_info.system_type_id = type_info.user_type_id
),
UniqueColumnStats AS
(
    SELECT
        ukc.TableObjectID,
        ukc.SchemaName,
        ukc.TableName,
        ukc.UniqueIndexID,
        ukc.UniqueName,
        ukc.UniqueIndexType,
        ukc.IsClustered,
        ukc.IsUniqueConstraint,
        ukc.HasConstraintObject,
        ukc.ConstraintName,
        ukc.HasFilter,
        ukc.FilterDefinition,
        ukc.FillFactor,
        ukc.IgnoreDupKey,
        COUNT(*) AS KeyColumnCount,
        SUM(ukc.DeclaredMaxLengthBytes) AS EstimatedKeyWidthBytes,
        SUM(CASE WHEN ukc.IsNullable = 1 THEN 1 ELSE 0 END) AS NullableColumnCount,
        STRING_AGG(ukc.ColumnName, N', ') WITHIN GROUP (ORDER BY ukc.KeyOrdinal) AS KeyColumns,
        STRING_AGG(CONCAT(N'|', ukc.ColumnName, N'|'), N'') WITHIN GROUP (ORDER BY ukc.KeyOrdinal) AS KeyTokenSignature,
        STRING_AGG(
            CONCAT(
                ukc.ColumnName,
                N' ',
                UPPER(ukc.DataTypeName),
                CASE
                    WHEN ukc.DataTypeName IN (N'char', N'varchar', N'binary', N'varbinary')
                        THEN CONCAT(N'(', CASE WHEN ukc.DeclaredMaxLengthBytes = 8000 THEN N'max' ELSE CONVERT(NVARCHAR(10), ukc.DeclaredMaxLengthBytes) END, N')')
                    WHEN ukc.DataTypeName IN (N'nchar', N'nvarchar')
                        THEN CONCAT(N'(', CASE WHEN ukc.DeclaredMaxLengthBytes = 8000 THEN N'max' ELSE CONVERT(NVARCHAR(10), ukc.DeclaredMaxLengthBytes / 2) END, N')')
                    ELSE N''
                END
            ),
            N' | '
        ) WITHIN GROUP (ORDER BY ukc.KeyOrdinal) AS KeyColumnSignature
    FROM UniqueKeyColumns AS ukc
    GROUP BY
        ukc.TableObjectID,
        ukc.SchemaName,
        ukc.TableName,
        ukc.UniqueIndexID,
        ukc.UniqueName,
        ukc.UniqueIndexType,
        ukc.IsClustered,
        ukc.IsUniqueConstraint,
        ukc.HasConstraintObject,
        ukc.ConstraintName,
        ukc.HasFilter,
        ukc.FilterDefinition,
        ukc.FillFactor,
        ukc.IgnoreDupKey
),
DefinitionsWithIdentity AS
(
    SELECT
        ROW_NUMBER() OVER
        (
            ORDER BY
                ucs.SchemaName,
                ucs.TableName,
                ucs.UniqueName,
                ucs.UniqueIndexID
        ) AS UniqueDefinitionID,
        DB_NAME() AS DatabaseName,
        ucs.TableObjectID,
        ucs.SchemaName,
        ucs.TableName,
        CONCAT(ucs.SchemaName, N'.', ucs.TableName) AS FullTableName,
        ucs.UniqueIndexID,
        ucs.UniqueName,
        ucs.UniqueIndexType,
        ucs.IsClustered,
        ucs.IsUniqueConstraint,
        ucs.HasConstraintObject,
        ISNULL(ucs.ConstraintName, ucs.UniqueName) AS ConstraintOrIndexName,
        ucs.HasFilter,
        ucs.FilterDefinition,
        ucs.FillFactor,
        ucs.IgnoreDupKey,
        ucs.KeyColumnCount,
        ucs.EstimatedKeyWidthBytes,
        ucs.NullableColumnCount,
        ucs.KeyColumns,
        ucs.KeyTokenSignature,
        ucs.KeyColumnSignature,
        CASE
            WHEN ucs.IsUniqueConstraint = 1 THEN N'UNIQUE_CONSTRAINT'
            ELSE N'UNIQUE_INDEX'
        END AS DefinitionType
    FROM UniqueColumnStats AS ucs
)
SELECT
    dwi.UniqueDefinitionID,
    dwi.DatabaseName,
    dwi.SchemaName,
    dwi.TableName,
    dwi.FullTableName,
    dwi.DefinitionType,
    dwi.ConstraintOrIndexName,
    dwi.UniqueName,
    dwi.UniqueIndexType,
    dwi.IsClustered,
    dwi.HasFilter,
    dwi.FilterDefinition,
    dwi.FillFactor,
    dwi.IgnoreDupKey,
    dwi.KeyColumnCount,
    dwi.EstimatedKeyWidthBytes,
    dwi.NullableColumnCount,
    dwi.KeyColumns,
    dwi.KeyColumnSignature,
    dwi.KeyTokenSignature
INTO #UniqueDefinitionInventory
FROM DefinitionsWithIdentity AS dwi;

WITH PairBase AS
(
    SELECT
        left_def.UniqueDefinitionID AS LeftDefinitionID,
        right_def.UniqueDefinitionID AS RightDefinitionID,
        left_def.DatabaseName,
        left_def.SchemaName,
        left_def.TableName,
        left_def.FullTableName,
        left_def.DefinitionType AS LeftDefinitionType,
        left_def.ConstraintOrIndexName AS LeftDefinitionName,
        left_def.UniqueIndexType AS LeftIndexType,
        left_def.IsClustered AS LeftIsClustered,
        left_def.HasFilter AS LeftHasFilter,
        left_def.FilterDefinition AS LeftFilterDefinition,
        left_def.KeyColumnCount AS LeftKeyColumnCount,
        left_def.EstimatedKeyWidthBytes AS LeftEstimatedKeyWidthBytes,
        left_def.KeyColumns AS LeftKeyColumns,
        left_def.KeyTokenSignature AS LeftTokenSignature,
        right_def.DefinitionType AS RightDefinitionType,
        right_def.ConstraintOrIndexName AS RightDefinitionName,
        right_def.UniqueIndexType AS RightIndexType,
        right_def.IsClustered AS RightIsClustered,
        right_def.HasFilter AS RightHasFilter,
        right_def.FilterDefinition AS RightFilterDefinition,
        right_def.KeyColumnCount AS RightKeyColumnCount,
        right_def.EstimatedKeyWidthBytes AS RightEstimatedKeyWidthBytes,
        right_def.KeyColumns AS RightKeyColumns,
        right_def.KeyTokenSignature AS RightTokenSignature
    FROM #UniqueDefinitionInventory AS left_def
    INNER JOIN #UniqueDefinitionInventory AS right_def
        ON right_def.FullTableName = left_def.FullTableName
       AND right_def.UniqueDefinitionID > left_def.UniqueDefinitionID
),
PairAnalysis AS
(
    SELECT
        pb.*,
        CASE
            WHEN pb.LeftTokenSignature = pb.RightTokenSignature THEN N'exact_match'
            WHEN LEFT(pb.RightTokenSignature, LEN(pb.LeftTokenSignature)) = pb.LeftTokenSignature THEN N'left_is_prefix_of_right'
            WHEN LEFT(pb.LeftTokenSignature, LEN(pb.RightTokenSignature)) = pb.RightTokenSignature THEN N'right_is_prefix_of_left'
            ELSE N'leading_overlap_only'
        END AS OverlapClass,
        CASE
            WHEN pb.LeftTokenSignature = pb.RightTokenSignature THEN pb.LeftKeyColumnCount
            WHEN LEFT(pb.RightTokenSignature, LEN(pb.LeftTokenSignature)) = pb.LeftTokenSignature THEN pb.LeftKeyColumnCount
            WHEN LEFT(pb.LeftTokenSignature, LEN(pb.RightTokenSignature)) = pb.RightTokenSignature THEN pb.RightKeyColumnCount
            ELSE 0
        END AS SharedLeadingColumnCount
    FROM PairBase AS pb
),
FilteredPairs AS
(
    SELECT
        pa.*,
        CASE
            WHEN pa.OverlapClass = N'exact_match' THEN N'DOPPELDEFINITION_PRUEFEN'
            WHEN pa.OverlapClass IN (N'left_is_prefix_of_right', N'right_is_prefix_of_left') THEN N'PRAEFIX_REDUNDANZ_PRUEFEN'
            ELSE N'ABGRENZUNG_DOKUMENTIEREN'
        END AS SuggestedNextStep,
        CASE
            WHEN pa.OverlapClass = N'exact_match' THEN N'high'
            WHEN pa.OverlapClass IN (N'left_is_prefix_of_right', N'right_is_prefix_of_left')
                 AND (pa.LeftHasFilter = 0 AND pa.RightHasFilter = 0) THEN N'medium'
            ELSE N'low'
        END AS ReviewPriority
    FROM PairAnalysis AS pa
    WHERE
        (
            @IncludeExactMatches = 1
            OR pa.OverlapClass <> N'exact_match'
        )
      AND
        (
            pa.OverlapClass IN (N'exact_match', N'left_is_prefix_of_right', N'right_is_prefix_of_left')
            OR pa.SharedLeadingColumnCount >= @MinSharedLeadingColumns
        )
)
SELECT
    fp.DatabaseName,
    fp.SchemaName,
    fp.TableName,
    fp.FullTableName,
    fp.OverlapClass,
    fp.SharedLeadingColumnCount,
    fp.LeftDefinitionType,
    fp.LeftDefinitionName,
    fp.LeftIndexType,
    fp.LeftIsClustered,
    fp.LeftHasFilter,
    fp.LeftFilterDefinition,
    fp.LeftKeyColumnCount,
    fp.LeftEstimatedKeyWidthBytes,
    fp.LeftKeyColumns,
    fp.RightDefinitionType,
    fp.RightDefinitionName,
    fp.RightIndexType,
    fp.RightIsClustered,
    fp.RightHasFilter,
    fp.RightFilterDefinition,
    fp.RightKeyColumnCount,
    fp.RightEstimatedKeyWidthBytes,
    fp.RightKeyColumns,
    fp.ReviewPriority,
    fp.SuggestedNextStep
INTO #UniqueOverlapPairs
FROM FilteredPairs AS fp;

SELECT
    udi.DatabaseName,
    udi.SchemaName,
    udi.TableName,
    udi.FullTableName,
    udi.DefinitionType,
    udi.ConstraintOrIndexName,
    udi.UniqueName,
    udi.UniqueIndexType,
    udi.IsClustered,
    udi.HasFilter,
    udi.FilterDefinition,
    udi.FillFactor,
    udi.IgnoreDupKey,
    udi.KeyColumnCount,
    udi.EstimatedKeyWidthBytes,
    udi.NullableColumnCount,
    udi.KeyColumns,
    udi.KeyColumnSignature
FROM #UniqueDefinitionInventory AS udi
ORDER BY
    udi.SchemaName,
    udi.TableName,
    udi.DefinitionType,
    udi.ConstraintOrIndexName;

SELECT
    uop.DatabaseName,
    uop.SchemaName,
    uop.TableName,
    uop.FullTableName,
    uop.OverlapClass,
    uop.SharedLeadingColumnCount,
    uop.LeftDefinitionType,
    uop.LeftDefinitionName,
    uop.LeftKeyColumns,
    uop.RightDefinitionType,
    uop.RightDefinitionName,
    uop.RightKeyColumns,
    uop.LeftHasFilter,
    uop.RightHasFilter,
    uop.ReviewPriority,
    uop.SuggestedNextStep
FROM #UniqueOverlapPairs AS uop
ORDER BY
    CASE uop.ReviewPriority
        WHEN N'high' THEN 1
        WHEN N'medium' THEN 2
        ELSE 3
    END,
    uop.SchemaName,
    uop.TableName,
    uop.LeftDefinitionName,
    uop.RightDefinitionName;

SELECT
    uop.SchemaName,
    uop.TableName,
    uop.FullTableName,
    CASE
        WHEN uop.OverlapClass = N'exact_match' THEN uop.LeftDefinitionName
        WHEN uop.OverlapClass = N'left_is_prefix_of_right' THEN uop.RightDefinitionName
        WHEN uop.OverlapClass = N'right_is_prefix_of_left' THEN uop.LeftDefinitionName
        ELSE uop.RightDefinitionName
    END AS CandidateDefinitionToReview,
    uop.OverlapClass,
    uop.ReviewPriority,
    uop.SuggestedNextStep,
    CASE
        WHEN uop.OverlapClass = N'exact_match'
            THEN N'Identische UNIQUE-Signatur auf derselben Tabelle; Ownership und DDL-Historie pruefen.'
        WHEN uop.OverlapClass = N'left_is_prefix_of_right'
            THEN N'Die linke Definition macht die Eindeutigkeit des rechten Praefixteils bereits sichtbar; Query-Nutzen separat pruefen.'
        WHEN uop.OverlapClass = N'right_is_prefix_of_left'
            THEN N'Die rechte Definition deckt das fuehrende Schluesselmuster der linken bereits ab; Query-Nutzen separat pruefen.'
        ELSE N'Fuehrende Ueberschneidung dokumentieren und fachlich gegen Zugriffsmuster abgrenzen.'
    END AS ReviewReason,
    CONCAT(uop.LeftDefinitionName, N' <-> ', uop.RightDefinitionName) AS RelatedDefinitions
FROM #UniqueOverlapPairs AS uop
ORDER BY
    CASE uop.ReviewPriority
        WHEN N'high' THEN 1
        WHEN N'medium' THEN 2
        ELSE 3
    END,
    uop.SchemaName,
    uop.TableName,
    CandidateDefinitionToReview;

DROP TABLE IF EXISTS #UniqueOverlapPairs;
DROP TABLE IF EXISTS #UniqueDefinitionInventory;
