/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "IncludedColumnBloatReview.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "26_Indexes_Basics"

purpose: >
  Markiert Nichtclustered-Indizes mit potenziell zu breiten Include-Listen
  anhand von Include-Anzahl, geschaetzter Byte-Breite und MAX- oder
  LOB-aehnlichen Include-Spalten.

parameters:
  - name: "@SchemaName"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Optionaler Filter auf ein Schema"
  - name: "@TableName"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Optionaler Filter auf einen Tabellennamen"
  - name: "@MinIncludedColumnCount"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Untergrenze fuer die Anzahl der Include-Spalten, ab der ein Index markiert wird"
  - name: "@MinEstimatedIncludeBytes"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Untergrenze fuer die geschaetzte feste Include-Byte-Breite, ab der ein Index markiert wird"
  - name: "@ShowOnlyFlagged"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = nur markierte Indizes zeigen, 0 = alle geprueften Indizes zeigen"

result_sets:
  - name: "IndexIncludeBloatSummary"
    description: "Uebersicht je Nichtclustered-Index mit Include-Anzahl, Breitenheuristik und Review-Markierung"
  - name: "IncludedColumnDetail"
    description: "Detailansicht je Include-Spalte mit Typ, Breitenannahme und Beitrag zur Gesamtmarkierung"

dependencies:
  - "sys.tables"
  - "sys.schemas"
  - "sys.indexes"
  - "sys.index_columns"
  - "sys.columns"
  - "sys.types"
  - "CTE"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/26_Indexes_Basics/SQLScripts/IncludedColumnBloatReview.md"
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
    description: "Erstversion fuer die Review potenziell zu breiter Include-Listen"

notes:
  - "Die Breitenheuristik dient nur als Review-Signal und ersetzt keine Workload- oder Plananalyse"
  - "MAX- und LOB-aehnliche Typen werden gesondert markiert, weil ihre reale Blattwirkung vom konkreten Design abhaengt"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @SchemaName SYSNAME = NULL;
DECLARE @TableName SYSNAME = NULL;
DECLARE @MinIncludedColumnCount INT = 4;
DECLARE @MinEstimatedIncludeBytes INT = 128;
DECLARE @ShowOnlyFlagged BIT = 1;

IF @MinIncludedColumnCount < 1
BEGIN
    THROW 50000, '@MinIncludedColumnCount muss groesser oder gleich 1 sein.', 1;
END;

IF @MinEstimatedIncludeBytes < 0
BEGIN
    THROW 50000, '@MinEstimatedIncludeBytes darf nicht negativ sein.', 1;
END;

IF @ShowOnlyFlagged NOT IN (0, 1)
BEGIN
    THROW 50000, '@ShowOnlyFlagged muss 0 oder 1 sein.', 1;
END;

;WITH TargetIndexes AS
(
    SELECT
        s.name AS SchemaName,
        t.name AS TableName,
        t.object_id,
        i.index_id,
        i.name AS IndexName,
        i.type_desc,
        i.fill_factor,
        i.has_filter,
        i.filter_definition
    FROM sys.tables AS t
    INNER JOIN sys.schemas AS s
        ON s.schema_id = t.schema_id
    INNER JOIN sys.indexes AS i
        ON i.object_id = t.object_id
    WHERE t.is_ms_shipped = 0
      AND i.type = 2
      AND i.is_hypothetical = 0
      AND i.is_disabled = 0
      AND (@SchemaName IS NULL OR s.name = @SchemaName)
      AND (@TableName IS NULL OR t.name = @TableName)
),
IncludedColumns AS
(
    SELECT
        ti.SchemaName,
        ti.TableName,
        ti.object_id,
        ti.index_id,
        ti.IndexName,
        ti.type_desc,
        ti.fill_factor,
        ti.has_filter,
        ti.filter_definition,
        ic.index_column_id AS IncludedColumnOrder,
        c.column_id,
        c.name AS IncludedColumnName,
        bt.name AS BaseTypeName,
        CASE
            WHEN c.max_length = -1 THEN CONCAT(bt.name, '(max)')
            WHEN bt.name IN ('nchar', 'nvarchar') THEN CONCAT(bt.name, '(', c.max_length / 2, ')')
            WHEN bt.name IN ('char', 'varchar', 'binary', 'varbinary') THEN CONCAT(bt.name, '(', c.max_length, ')')
            WHEN bt.name IN ('decimal', 'numeric') THEN CONCAT(bt.name, '(', c.precision, ',', c.scale, ')')
            WHEN bt.name IN ('datetime2', 'datetimeoffset', 'time') THEN CONCAT(bt.name, '(', c.scale, ')')
            ELSE bt.name
        END AS DataTypeDisplay,
        CASE
            WHEN c.max_length = -1 THEN NULL
            WHEN bt.name IN ('xml', 'text', 'ntext', 'image', 'sql_variant') THEN NULL
            ELSE c.max_length
        END AS EstimatedMaxBytes,
        CASE
            WHEN c.max_length = -1 THEN 'max-or-row-overflow'
            WHEN bt.name IN ('xml', 'text', 'ntext', 'image', 'sql_variant') THEN 'lob-or-variable'
            WHEN bt.name IN ('varchar', 'nvarchar', 'varbinary') THEN 'variable'
            ELSE 'fixed'
        END AS WidthCategory
    FROM TargetIndexes AS ti
    INNER JOIN sys.index_columns AS ic
        ON ic.object_id = ti.object_id
       AND ic.index_id = ti.index_id
    INNER JOIN sys.columns AS c
        ON c.object_id = ic.object_id
       AND c.column_id = ic.column_id
    INNER JOIN sys.types AS bt
        ON bt.user_type_id = c.system_type_id
       AND bt.user_type_id = bt.system_type_id
    WHERE ic.is_included_column = 1
),
IndexAssessment AS
(
    SELECT
        DB_NAME() AS DatabaseName,
        ic.SchemaName,
        ic.TableName,
        ic.IndexName,
        ic.type_desc AS IndexType,
        ic.fill_factor,
        ic.has_filter,
        ic.filter_definition,
        COUNT(*) AS IncludedColumnCount,
        SUM(CASE WHEN ic.EstimatedMaxBytes IS NOT NULL THEN ic.EstimatedMaxBytes ELSE 0 END) AS EstimatedFixedIncludeBytes,
        SUM(CASE WHEN ic.WidthCategory IN ('max-or-row-overflow', 'lob-or-variable') THEN 1 ELSE 0 END) AS LargeValueColumnCount,
        SUM(CASE WHEN ic.WidthCategory = 'variable' THEN 1 ELSE 0 END) AS VariableLengthColumnCount
    FROM IncludedColumns AS ic
    GROUP BY
        ic.SchemaName,
        ic.TableName,
        ic.IndexName,
        ic.type_desc,
        ic.fill_factor,
        ic.has_filter,
        ic.filter_definition
),
FlaggedIndexes AS
(
    SELECT
        ia.DatabaseName,
        ia.SchemaName,
        ia.TableName,
        ia.IndexName,
        ia.IndexType,
        ia.fill_factor AS FillFactor,
        CAST(ia.has_filter AS BIT) AS HasFilter,
        ia.filter_definition AS FilterDefinition,
        ia.IncludedColumnCount,
        ia.EstimatedFixedIncludeBytes,
        ia.LargeValueColumnCount,
        ia.VariableLengthColumnCount,
        CAST(
            CASE
                WHEN ia.IncludedColumnCount >= @MinIncludedColumnCount
                  OR ia.EstimatedFixedIncludeBytes >= @MinEstimatedIncludeBytes
                  OR ia.LargeValueColumnCount > 0
                THEN 1
                ELSE 0
            END AS BIT
        ) AS IsPotentiallyBloated,
        CASE
            WHEN ia.LargeValueColumnCount > 0 THEN 'Review index first because at least one include column uses a MAX or LOB-like type.'
            WHEN ia.EstimatedFixedIncludeBytes >= @MinEstimatedIncludeBytes THEN 'Review index because the estimated fixed include width exceeds the configured threshold.'
            WHEN ia.IncludedColumnCount >= @MinIncludedColumnCount THEN 'Review index because the number of include columns exceeds the configured threshold.'
            ELSE 'No threshold reached by the configured include-count and width heuristics.'
        END AS ReviewReason,
        CASE
            WHEN ia.LargeValueColumnCount > 0 THEN 'Validate whether large-value attributes are really needed for coverage or should move to another design.'
            WHEN ia.EstimatedFixedIncludeBytes >= @MinEstimatedIncludeBytes THEN 'Check whether all included attributes are required in the leaf level or can be reduced.'
            WHEN ia.IncludedColumnCount >= @MinIncludedColumnCount THEN 'Review the covering strategy and prune low-value include columns if possible.'
            ELSE 'Keep for baseline reference or compare against usage and plans.'
        END AS SuggestedAction
    FROM IndexAssessment AS ia
)
SELECT
    fi.DatabaseName,
    fi.SchemaName,
    fi.TableName,
    fi.IndexName,
    fi.IndexType,
    fi.IncludedColumnCount,
    fi.EstimatedFixedIncludeBytes,
    fi.VariableLengthColumnCount,
    fi.LargeValueColumnCount,
    fi.FillFactor,
    fi.HasFilter,
    fi.FilterDefinition,
    fi.IsPotentiallyBloated,
    fi.ReviewReason,
    fi.SuggestedAction
FROM FlaggedIndexes AS fi
WHERE @ShowOnlyFlagged = 0
   OR fi.IsPotentiallyBloated = 1
ORDER BY
    fi.IsPotentiallyBloated DESC,
    fi.EstimatedFixedIncludeBytes DESC,
    fi.IncludedColumnCount DESC,
    fi.SchemaName,
    fi.TableName,
    fi.IndexName;

SELECT
    fi.DatabaseName,
    fi.SchemaName,
    fi.TableName,
    fi.IndexName,
    fi.IndexType,
    ic.IncludedColumnOrder,
    ic.IncludedColumnName,
    ic.DataTypeDisplay,
    ic.WidthCategory,
    ic.EstimatedMaxBytes,
    fi.IncludedColumnCount,
    fi.EstimatedFixedIncludeBytes,
    fi.LargeValueColumnCount,
    fi.IsPotentiallyBloated,
    CASE
        WHEN ic.WidthCategory IN ('max-or-row-overflow', 'lob-or-variable') THEN 'Large-value include column participates in the review signal.'
        WHEN fi.EstimatedFixedIncludeBytes >= @MinEstimatedIncludeBytes THEN 'Column contributes to a high estimated fixed include width.'
        WHEN fi.IncludedColumnCount >= @MinIncludedColumnCount THEN 'Column contributes to a broad include list.'
        ELSE 'Column remains visible for baseline comparison.'
    END AS ColumnReviewContribution
FROM FlaggedIndexes AS fi
INNER JOIN IncludedColumns AS ic
    ON ic.SchemaName = fi.SchemaName
   AND ic.TableName = fi.TableName
   AND ic.IndexName = fi.IndexName
WHERE @ShowOnlyFlagged = 0
   OR fi.IsPotentiallyBloated = 1
ORDER BY
    fi.IsPotentiallyBloated DESC,
    fi.SchemaName,
    fi.TableName,
    fi.IndexName,
    ic.IncludedColumnOrder;
