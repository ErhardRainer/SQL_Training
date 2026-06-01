/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "PrimaryKeyCoverageReport.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "16_DataIntegrity_Constraints"

purpose: >
  Listet Tabellen ohne Primary Key sowie Tabellen mit auffaelligen
  Schluesselmustern und verdichtet die wichtigsten Review-Signale fuer
  Integritaets- und Designpruefungen.

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
  - name: "@IncludeMsShipped"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 bezieht systemnahe Tabellen ein; 0 fokussiert auf benutzerdefinierte Tabellen."
  - name: "@IncludeHealthyTables"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 zeigt alle Tabellen; 0 fokussiert auf fehlende oder auffaellige Primary-Key-Muster."
  - name: "@CompositeKeyThreshold"
    sql_type: "TINYINT"
    direction: "IN"
    required: false
    description: "Ab wie vielen Schluesselspalten ein zusammengesetzter Primary Key als Review-Signal markiert wird."
  - name: "@WideKeyBytesThreshold"
    sql_type: "SMALLINT"
    direction: "IN"
    required: false
    description: "Ab welcher geschaetzten Byte-Breite ein Primary Key als breit markiert wird."

result_sets:
  - name: "PrimaryKeyCoverageReport"
    description: "Tabellenweise Sicht mit PK-Status, Spaltenprofil, Pattern-Flags und Review-Kategorie."
  - name: "PrimaryKeyPatternSummary"
    description: "Verdichtung ueber alle betrachteten Tabellen und die wichtigsten Key-Muster."
  - name: "PrimaryKeyReviewBacklog"
    description: "Priorisierte Liste der Tabellen ohne PK oder mit auffaelligen PK-Mustern."

dependencies:
  - "sys.tables"
  - "sys.schemas"
  - "sys.key_constraints"
  - "sys.indexes"
  - "sys.index_columns"
  - "sys.columns"
  - "sys.types"
  - "DB_NAME()"
  - "STRING_AGG()"
  - "DROP TABLE IF EXISTS"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/16_DataIntegrity_Constraints/SQLScripts/PrimaryKeyCoverageReport.md"
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
    description: "Erstversion eines read-only Reports fuer fehlende und auffaellige Primary-Key-Muster."

notes:
  - "Die Auswertung liest nur die Katalogsichten der aktuellen SQL-Server-Datenbank."
  - "Auffaellige Muster sind Review-Hinweise und keine automatische Fehlklassifikation."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @SchemaName SYSNAME = NULL;
DECLARE @TableNamePattern NVARCHAR(128) = NULL;
DECLARE @IncludeMsShipped BIT = 0;
DECLARE @IncludeHealthyTables BIT = 0;
DECLARE @CompositeKeyThreshold TINYINT = 3;
DECLARE @WideKeyBytesThreshold SMALLINT = 64;

IF @IncludeMsShipped NOT IN (0, 1)
BEGIN
    THROW 50000, '@IncludeMsShipped muss 0 oder 1 sein.', 1;
END;

IF @IncludeHealthyTables NOT IN (0, 1)
BEGIN
    THROW 50001, '@IncludeHealthyTables muss 0 oder 1 sein.', 1;
END;

IF @CompositeKeyThreshold < 2
BEGIN
    THROW 50002, '@CompositeKeyThreshold muss mindestens 2 sein.', 1;
END;

IF @WideKeyBytesThreshold < 16
BEGIN
    THROW 50003, '@WideKeyBytesThreshold muss mindestens 16 sein.', 1;
END;

DROP TABLE IF EXISTS #PrimaryKeyCoverage;

WITH TableBase AS
(
    SELECT
        t.object_id AS TableObjectID,
        s.name AS SchemaName,
        t.name AS TableName,
        t.create_date AS TableCreateDate,
        t.modify_date AS TableModifyDate,
        t.is_ms_shipped
    FROM sys.tables AS t
    INNER JOIN sys.schemas AS s
        ON s.schema_id = t.schema_id
    WHERE (@SchemaName IS NULL OR s.name = @SchemaName)
      AND (@TableNamePattern IS NULL OR t.name LIKE @TableNamePattern)
      AND (@IncludeMsShipped = 1 OR t.is_ms_shipped = 0)
),
PrimaryKeyBase AS
(
    SELECT
        kc.parent_object_id AS TableObjectID,
        kc.name AS PrimaryKeyName,
        idx.name AS PrimaryKeyIndexName,
        idx.type_desc AS PrimaryKeyIndexType,
        idx.fill_factor AS FillFactor,
        idx.has_filter AS HasFilter,
        idx.filter_definition AS FilterDefinition,
        CASE WHEN idx.type = 1 THEN 1 ELSE 0 END AS IsClusteredPrimaryKey,
        idx.index_id AS PrimaryKeyIndexID
    FROM sys.key_constraints AS kc
    INNER JOIN sys.indexes AS idx
        ON idx.object_id = kc.parent_object_id
       AND idx.index_id = kc.unique_index_id
    WHERE kc.type = 'PK'
),
PrimaryKeyColumns AS
(
    SELECT
        pk.TableObjectID,
        pk.PrimaryKeyName,
        pk.PrimaryKeyIndexName,
        pk.PrimaryKeyIndexType,
        pk.IsClusteredPrimaryKey,
        pk.FillFactor,
        pk.HasFilter,
        pk.FilterDefinition,
        ic.key_ordinal AS KeyOrdinal,
        ic.is_descending_key AS IsDescendingKey,
        col.name AS ColumnName,
        type_info.name AS DataTypeName,
        CASE
            WHEN col.max_length = -1 THEN 8000
            ELSE col.max_length
        END AS DeclaredMaxLengthBytes,
        col.precision AS NumericPrecision,
        col.scale AS NumericScale
    FROM PrimaryKeyBase AS pk
    INNER JOIN sys.index_columns AS ic
        ON ic.object_id = pk.TableObjectID
       AND ic.index_id = pk.PrimaryKeyIndexID
       AND ic.key_ordinal > 0
    INNER JOIN sys.columns AS col
        ON col.object_id = ic.object_id
       AND col.column_id = ic.column_id
    INNER JOIN sys.types AS type_info
        ON type_info.user_type_id = col.user_type_id
    WHERE type_info.is_user_defined = 0
       OR type_info.system_type_id = type_info.user_type_id
),
PrimaryKeyStats AS
(
    SELECT
        pkc.TableObjectID,
        pkc.PrimaryKeyName,
        pkc.PrimaryKeyIndexName,
        pkc.PrimaryKeyIndexType,
        pkc.IsClusteredPrimaryKey,
        MAX(pkc.FillFactor) AS FillFactor,
        MAX(pkc.HasFilter) AS HasFilter,
        MAX(pkc.FilterDefinition) AS FilterDefinition,
        COUNT(*) AS PrimaryKeyColumnCount,
        SUM(CASE WHEN pkc.IsDescendingKey = 1 THEN 1 ELSE 0 END) AS DescendingColumnCount,
        SUM(pkc.DeclaredMaxLengthBytes) AS EstimatedKeyWidthBytes,
        STRING_AGG(pkc.ColumnName, N', ') WITHIN GROUP (ORDER BY pkc.KeyOrdinal) AS PrimaryKeyColumns,
        STRING_AGG(
            CONCAT(
                pkc.ColumnName,
                N' ',
                UPPER(pkc.DataTypeName),
                CASE
                    WHEN pkc.DataTypeName IN (N'char', N'varchar', N'binary', N'varbinary')
                        THEN CONCAT(N'(', CASE WHEN pkc.DeclaredMaxLengthBytes = 8000 THEN N'max' ELSE CONVERT(NVARCHAR(10), pkc.DeclaredMaxLengthBytes) END, N')')
                    WHEN pkc.DataTypeName IN (N'nchar', N'nvarchar')
                        THEN CONCAT(N'(', CASE WHEN pkc.DeclaredMaxLengthBytes = 8000 THEN N'max' ELSE CONVERT(NVARCHAR(10), pkc.DeclaredMaxLengthBytes / 2) END, N')')
                    WHEN pkc.DataTypeName IN (N'decimal', N'numeric')
                        THEN CONCAT(N'(', CONVERT(NVARCHAR(10), pkc.NumericPrecision), N',', CONVERT(NVARCHAR(10), pkc.NumericScale), N')')
                    ELSE N''
                END
            ),
            N' | '
        ) WITHIN GROUP (ORDER BY pkc.KeyOrdinal) AS PrimaryKeyColumnSignature,
        MAX(CASE WHEN pkc.KeyOrdinal = 1 THEN pkc.DataTypeName END) AS LeadingColumnDataType,
        MAX(CASE WHEN pkc.KeyOrdinal = 1 THEN pkc.ColumnName END) AS LeadingColumnName
    FROM PrimaryKeyColumns AS pkc
    GROUP BY
        pkc.TableObjectID,
        pkc.PrimaryKeyName,
        pkc.PrimaryKeyIndexName,
        pkc.PrimaryKeyIndexType,
        pkc.IsClusteredPrimaryKey
)
SELECT
    DB_NAME() AS DatabaseName,
    tb.SchemaName,
    tb.TableName,
    CONCAT(tb.SchemaName, N'.', tb.TableName) AS FullTableName,
    tb.TableCreateDate,
    tb.TableModifyDate,
    ISNULL(pks.PrimaryKeyName, N'(kein Primary Key)') AS PrimaryKeyName,
    ISNULL(pks.PrimaryKeyIndexName, N'(kein Primary Key)') AS PrimaryKeyIndexName,
    ISNULL(pks.PrimaryKeyIndexType, N'(none)') AS PrimaryKeyIndexType,
    CAST(CASE WHEN pks.TableObjectID IS NOT NULL THEN 1 ELSE 0 END AS BIT) AS HasPrimaryKey,
    CAST(ISNULL(pks.IsClusteredPrimaryKey, 0) AS BIT) AS IsClusteredPrimaryKey,
    ISNULL(pks.PrimaryKeyColumnCount, 0) AS PrimaryKeyColumnCount,
    ISNULL(pks.EstimatedKeyWidthBytes, 0) AS EstimatedKeyWidthBytes,
    ISNULL(pks.DescendingColumnCount, 0) AS DescendingColumnCount,
    ISNULL(pks.LeadingColumnName, N'(none)') AS LeadingColumnName,
    ISNULL(pks.LeadingColumnDataType, N'(none)') AS LeadingColumnDataType,
    ISNULL(pks.PrimaryKeyColumns, N'(none)') AS PrimaryKeyColumns,
    ISNULL(pks.PrimaryKeyColumnSignature, N'(none)') AS PrimaryKeyColumnSignature,
    pks.FillFactor,
    pks.HasFilter,
    pks.FilterDefinition,
    CAST(CASE WHEN pks.TableObjectID IS NULL THEN 1 ELSE 0 END AS BIT) AS FlagMissingPrimaryKey,
    CAST(CASE WHEN ISNULL(pks.PrimaryKeyColumnCount, 0) >= @CompositeKeyThreshold THEN 1 ELSE 0 END AS BIT) AS FlagCompositeThresholdReached,
    CAST(CASE WHEN ISNULL(pks.EstimatedKeyWidthBytes, 0) >= @WideKeyBytesThreshold THEN 1 ELSE 0 END AS BIT) AS FlagWideKey,
    CAST(CASE WHEN pks.TableObjectID IS NOT NULL AND ISNULL(pks.IsClusteredPrimaryKey, 0) = 0 THEN 1 ELSE 0 END AS BIT) AS FlagNonClusteredPrimaryKey,
    CAST(CASE WHEN ISNULL(pks.LeadingColumnDataType, N'') = N'uniqueidentifier' THEN 1 ELSE 0 END AS BIT) AS FlagGuidLeadingKey,
    CAST(CASE WHEN ISNULL(pks.LeadingColumnDataType, N'') IN (N'char', N'varchar', N'nchar', N'nvarchar') THEN 1 ELSE 0 END AS BIT) AS FlagStringLeadingKey,
    CAST(CASE WHEN ISNULL(pks.DescendingColumnCount, 0) > 0 THEN 1 ELSE 0 END AS BIT) AS FlagDescendingKeyColumns,
    CASE
        WHEN pks.TableObjectID IS NULL THEN N'MISSING_PRIMARY_KEY'
        WHEN ISNULL(pks.PrimaryKeyColumnCount, 0) >= @CompositeKeyThreshold
         AND ISNULL(pks.EstimatedKeyWidthBytes, 0) >= @WideKeyBytesThreshold THEN N'COMPOSITE_AND_WIDE'
        WHEN ISNULL(pks.PrimaryKeyColumnCount, 0) >= @CompositeKeyThreshold THEN N'COMPOSITE_KEY'
        WHEN ISNULL(pks.EstimatedKeyWidthBytes, 0) >= @WideKeyBytesThreshold THEN N'WIDE_KEY'
        WHEN pks.TableObjectID IS NOT NULL AND ISNULL(pks.IsClusteredPrimaryKey, 0) = 0 THEN N'NONCLUSTERED_PRIMARY_KEY'
        WHEN ISNULL(pks.LeadingColumnDataType, N'') = N'uniqueidentifier' THEN N'GUID_LEADING_KEY'
        WHEN ISNULL(pks.LeadingColumnDataType, N'') IN (N'char', N'varchar', N'nchar', N'nvarchar') THEN N'STRING_LEADING_KEY'
        WHEN ISNULL(pks.DescendingColumnCount, 0) > 0 THEN N'DESCENDING_KEY_COLUMNS'
        ELSE N'HEALTHY_OR_UNREMARKABLE'
    END AS ReviewCategory,
    LTRIM(
        STUFF(
            CASE WHEN pks.TableObjectID IS NULL THEN N', missing-primary-key' ELSE N'' END
            + CASE WHEN ISNULL(pks.PrimaryKeyColumnCount, 0) >= @CompositeKeyThreshold THEN N', composite-threshold' ELSE N'' END
            + CASE WHEN ISNULL(pks.EstimatedKeyWidthBytes, 0) >= @WideKeyBytesThreshold THEN N', wide-key' ELSE N'' END
            + CASE WHEN pks.TableObjectID IS NOT NULL AND ISNULL(pks.IsClusteredPrimaryKey, 0) = 0 THEN N', nonclustered-pk' ELSE N'' END
            + CASE WHEN ISNULL(pks.LeadingColumnDataType, N'') = N'uniqueidentifier' THEN N', guid-leading-key' ELSE N'' END
            + CASE WHEN ISNULL(pks.LeadingColumnDataType, N'') IN (N'char', N'varchar', N'nchar', N'nvarchar') THEN N', string-leading-key' ELSE N'' END
            + CASE WHEN ISNULL(pks.DescendingColumnCount, 0) > 0 THEN N', descending-key-columns' ELSE N'' END,
            1,
            1,
            N''
        )
    ) AS PatternFlags
INTO #PrimaryKeyCoverage
FROM TableBase AS tb
LEFT JOIN PrimaryKeyStats AS pks
    ON pks.TableObjectID = tb.TableObjectID;

SELECT
    DatabaseName,
    SchemaName,
    TableName,
    FullTableName,
    HasPrimaryKey,
    ReviewCategory,
    PatternFlags,
    PrimaryKeyName,
    PrimaryKeyIndexName,
    PrimaryKeyIndexType,
    IsClusteredPrimaryKey,
    PrimaryKeyColumnCount,
    EstimatedKeyWidthBytes,
    DescendingColumnCount,
    LeadingColumnName,
    LeadingColumnDataType,
    PrimaryKeyColumns,
    PrimaryKeyColumnSignature,
    FillFactor,
    HasFilter,
    FilterDefinition,
    TableCreateDate,
    TableModifyDate
FROM #PrimaryKeyCoverage
WHERE @IncludeHealthyTables = 1
   OR ReviewCategory <> N'HEALTHY_OR_UNREMARKABLE'
ORDER BY
    CASE ReviewCategory
        WHEN N'MISSING_PRIMARY_KEY' THEN 1
        WHEN N'COMPOSITE_AND_WIDE' THEN 2
        WHEN N'COMPOSITE_KEY' THEN 3
        WHEN N'WIDE_KEY' THEN 4
        WHEN N'NONCLUSTERED_PRIMARY_KEY' THEN 5
        WHEN N'GUID_LEADING_KEY' THEN 6
        WHEN N'STRING_LEADING_KEY' THEN 7
        WHEN N'DESCENDING_KEY_COLUMNS' THEN 8
        ELSE 9
    END,
    SchemaName,
    TableName;

SELECT
    COUNT(*) AS TableCount,
    SUM(CASE WHEN HasPrimaryKey = 1 THEN 1 ELSE 0 END) AS TablesWithPrimaryKey,
    SUM(CASE WHEN FlagMissingPrimaryKey = 1 THEN 1 ELSE 0 END) AS TablesWithoutPrimaryKey,
    SUM(CASE WHEN FlagCompositeThresholdReached = 1 THEN 1 ELSE 0 END) AS TablesAtOrAboveCompositeThreshold,
    SUM(CASE WHEN FlagWideKey = 1 THEN 1 ELSE 0 END) AS TablesWithWidePrimaryKey,
    SUM(CASE WHEN FlagNonClusteredPrimaryKey = 1 THEN 1 ELSE 0 END) AS TablesWithNonClusteredPrimaryKey,
    SUM(CASE WHEN FlagGuidLeadingKey = 1 THEN 1 ELSE 0 END) AS TablesWithGuidLeadingKey,
    SUM(CASE WHEN FlagStringLeadingKey = 1 THEN 1 ELSE 0 END) AS TablesWithStringLeadingKey,
    SUM(CASE WHEN FlagDescendingKeyColumns = 1 THEN 1 ELSE 0 END) AS TablesWithDescendingKeyColumns,
    CAST(AVG(CAST(PrimaryKeyColumnCount AS DECIMAL(10, 2))) AS DECIMAL(10, 2)) AS AveragePrimaryKeyColumnCount,
    CAST(AVG(CAST(EstimatedKeyWidthBytes AS DECIMAL(10, 2))) AS DECIMAL(10, 2)) AS AverageEstimatedKeyWidthBytes
FROM #PrimaryKeyCoverage;

SELECT
    SchemaName,
    TableName,
    FullTableName,
    ReviewCategory,
    PatternFlags,
    PrimaryKeyName,
    PrimaryKeyColumnCount,
    EstimatedKeyWidthBytes,
    LeadingColumnDataType,
    PrimaryKeyColumns,
    CASE
        WHEN ReviewCategory = N'MISSING_PRIMARY_KEY' THEN N'PRIMARY_KEY_ERGAENZEN'
        WHEN ReviewCategory IN (N'COMPOSITE_AND_WIDE', N'COMPOSITE_KEY', N'WIDE_KEY') THEN N'SCHLUESSELDESIGN_PRUEFEN'
        WHEN ReviewCategory = N'NONCLUSTERED_PRIMARY_KEY' THEN N'CLUSTERING_ENTSCHEIDUNG_PRUEFEN'
        WHEN ReviewCategory IN (N'GUID_LEADING_KEY', N'STRING_LEADING_KEY', N'DESCENDING_KEY_COLUMNS') THEN N'INDEXIERUNG_UND_ZUGRIFFSMUSTER_PRUEFEN'
        ELSE N'DOKUMENTIEREN'
    END AS SuggestedNextStep
FROM #PrimaryKeyCoverage
WHERE ReviewCategory <> N'HEALTHY_OR_UNREMARKABLE'
ORDER BY
    CASE ReviewCategory
        WHEN N'MISSING_PRIMARY_KEY' THEN 1
        WHEN N'COMPOSITE_AND_WIDE' THEN 2
        WHEN N'COMPOSITE_KEY' THEN 3
        WHEN N'WIDE_KEY' THEN 4
        WHEN N'NONCLUSTERED_PRIMARY_KEY' THEN 5
        WHEN N'GUID_LEADING_KEY' THEN 6
        WHEN N'STRING_LEADING_KEY' THEN 7
        WHEN N'DESCENDING_KEY_COLUMNS' THEN 8
        ELSE 9
    END,
    SchemaName,
    TableName;

DROP TABLE IF EXISTS #PrimaryKeyCoverage;
