/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "SearchColumnNamePattern.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "15_SearchInTables"

purpose: >
  Durchsucht Spaltennamen in Tabellen- und optional View-Metadaten nach frei
  definierbaren Fachbegriffen, ID-Hinweisen und Auditmustern.

parameters:
  - name: "@SearchTerms"
    sql_type: "NVARCHAR(MAX)"
    direction: "IN"
    required: false
    description: "Pipe-separierte Suchbegriffe wie customer|id|created; NULL verwendet ein didaktisches Standardset."
  - name: "@SchemaName"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Optionaler Schemafilter; NULL durchsucht alle Schemas."
  - name: "@IncludeViews"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = Views einbeziehen, 0 = nur Benutzertabellen."
  - name: "@MatchMode"
    sql_type: "NVARCHAR(10)"
    direction: "IN"
    required: false
    description: "contains, prefix oder exact fuer die Pattern-Pruefung auf normalisierten Spaltennamen."

result_sets:
  - name: "ColumnPatternMatches"
    description: "Detailtreffer je Spalte mit Trefferart, Pattern-Kategorie und Konfidenz."
  - name: "ObjectPatternCoverage"
    description: "Verdichtete Sicht je Objekt auf Pattern-Abdeckung und dominante Pattern-Kategorien."
  - name: "PatternUsageSummary"
    description: "Zusammenfassung der verwendeten Suchterme und der betroffenen Objekte."

dependencies:
  - "sys.objects"
  - "sys.schemas"
  - "sys.columns"
  - "sys.types"
  - "STRING_SPLIT()"
  - "ROW_NUMBER()"
  - "CASE"
  - "LIKE"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/15_SearchInTables/SQLScripts/SearchColumnNamePattern.md"
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
    description: "Erstversion eines diagnostischen Metadaten-Skripts fuer Pattern-Suche in Spaltennamen."

notes:
  - "Die Erstversion arbeitet rein lesend auf Katalogsichten der aktuell verbundenen Datenbank."
  - "Spaltennamen werden fuer die Suche ohne Leerzeichen, Bindestriche und Unterstriche normalisiert."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @SearchTerms NVARCHAR(MAX) = NULL;
DECLARE @SchemaName SYSNAME = NULL;
DECLARE @IncludeViews BIT = 0;
DECLARE @MatchMode NVARCHAR(10) = N'contains';

SET @MatchMode = LOWER(COALESCE(@MatchMode, N'contains'));

IF @IncludeViews NOT IN (0, 1)
BEGIN
    THROW 50000, '@IncludeViews muss 0 oder 1 sein.', 1;
END;

IF @MatchMode NOT IN (N'contains', N'prefix', N'exact')
BEGIN
    THROW 50001, '@MatchMode muss contains, prefix oder exact sein.', 1;
END;

IF @SchemaName IS NOT NULL AND NOT EXISTS
(
    SELECT 1
    FROM sys.schemas AS s
    WHERE s.name = @SchemaName
)
BEGIN
    THROW 50002, '@SchemaName wurde in der aktuellen Datenbank nicht gefunden.', 1;
END;

DROP TABLE IF EXISTS #SearchPatterns;
CREATE TABLE #SearchPatterns
(
    PatternTerm NVARCHAR(128) NOT NULL PRIMARY KEY,
    PatternCategory NVARCHAR(30) NOT NULL,
    PriorityRank INT NOT NULL
);

IF NULLIF(LTRIM(RTRIM(COALESCE(@SearchTerms, N''))), N'') IS NULL
BEGIN
    INSERT INTO #SearchPatterns (PatternTerm, PatternCategory, PriorityRank)
    VALUES
        (N'id', N'id_hint', 10),
        (N'code', N'id_hint', 11),
        (N'key', N'id_hint', 12),
        (N'number', N'id_hint', 13),
        (N'customer', N'business_term', 20),
        (N'order', N'business_term', 21),
        (N'product', N'business_term', 22),
        (N'status', N'business_term', 23),
        (N'created', N'audit_field', 30),
        (N'modified', N'audit_field', 31),
        (N'updated', N'audit_field', 32),
        (N'deleted', N'audit_field', 33);
END;
ELSE
BEGIN
    INSERT INTO #SearchPatterns (PatternTerm, PatternCategory, PriorityRank)
    SELECT
        NormalizedTerm,
        CASE
            WHEN NormalizedTerm IN (N'id', N'code', N'key', N'number', N'no', N'nr') THEN N'id_hint'
            WHEN NormalizedTerm IN (N'created', N'modified', N'updated', N'deleted', N'audit', N'approved') THEN N'audit_field'
            ELSE N'business_term'
        END AS PatternCategory,
        100 + ROW_NUMBER() OVER (ORDER BY NormalizedTerm) AS PriorityRank
    FROM
    (
        SELECT DISTINCT
            LOWER(LTRIM(RTRIM(value))) AS NormalizedTerm
        FROM STRING_SPLIT(@SearchTerms, N'|')
        WHERE NULLIF(LTRIM(RTRIM(value)), N'') IS NOT NULL
    ) AS src;
END;

IF NOT EXISTS (SELECT 1 FROM #SearchPatterns)
BEGIN
    THROW 50003, 'Es wurde kein gueltiger Suchbegriff fuer @SearchTerms ermittelt.', 1;
END;

WITH SearchableObjects AS
(
    SELECT
        o.object_id,
        s.name AS SchemaName,
        o.name AS ObjectName,
        o.type AS ObjectTypeCode,
        o.type_desc AS ObjectTypeDesc
    FROM sys.objects AS o
    INNER JOIN sys.schemas AS s
        ON s.schema_id = o.schema_id
    WHERE o.type IN (N'U', N'V')
      AND (@IncludeViews = 1 OR o.type = N'U')
      AND (@SchemaName IS NULL OR s.name = @SchemaName)
      AND OBJECTPROPERTY(o.object_id, 'IsMsShipped') = 0
),
CandidateColumns AS
(
    SELECT
        so.SchemaName,
        so.ObjectName,
        so.ObjectTypeCode,
        so.ObjectTypeDesc,
        c.column_id AS ColumnOrdinal,
        c.name AS ColumnName,
        t.name AS DataTypeName,
        c.max_length,
        c.precision,
        c.scale,
        c.is_nullable,
        c.is_identity,
        c.is_computed,
        LOWER(REPLACE(REPLACE(REPLACE(c.name, N' ', N''), N'-', N''), N'_', N'')) AS NormalizedColumnName
    FROM SearchableObjects AS so
    INNER JOIN sys.columns AS c
        ON c.object_id = so.object_id
    INNER JOIN sys.types AS t
        ON t.user_type_id = c.user_type_id
),
PatternMatches AS
(
    SELECT
        cc.SchemaName,
        cc.ObjectName,
        cc.ObjectTypeCode,
        cc.ObjectTypeDesc,
        cc.ColumnOrdinal,
        cc.ColumnName,
        cc.DataTypeName,
        cc.max_length,
        cc.precision,
        cc.scale,
        cc.is_nullable,
        cc.is_identity,
        cc.is_computed,
        sp.PatternTerm,
        sp.PatternCategory,
        sp.PriorityRank,
        CASE
            WHEN cc.NormalizedColumnName = sp.PatternTerm THEN N'exact'
            WHEN cc.NormalizedColumnName LIKE sp.PatternTerm + N'%' THEN N'prefix'
            WHEN cc.NormalizedColumnName LIKE N'%' + sp.PatternTerm + N'%' THEN N'contains'
        END AS MatchType
    FROM CandidateColumns AS cc
    INNER JOIN #SearchPatterns AS sp
        ON
            (@MatchMode = N'exact' AND cc.NormalizedColumnName = sp.PatternTerm)
            OR (@MatchMode = N'prefix' AND cc.NormalizedColumnName LIKE sp.PatternTerm + N'%')
            OR (@MatchMode = N'contains' AND cc.NormalizedColumnName LIKE N'%' + sp.PatternTerm + N'%')
),
RankedMatches AS
(
    SELECT
        pm.*,
        ROW_NUMBER() OVER
        (
            PARTITION BY pm.SchemaName, pm.ObjectName, pm.ColumnName
            ORDER BY
                CASE pm.MatchType WHEN N'exact' THEN 0 WHEN N'prefix' THEN 1 ELSE 2 END,
                pm.PriorityRank,
                LEN(pm.PatternTerm) DESC
        ) AS MatchRank
    FROM PatternMatches AS pm
)
SELECT
    rm.SchemaName,
    rm.ObjectName,
    rm.ObjectTypeCode,
    rm.ObjectTypeDesc,
    rm.ColumnOrdinal,
    rm.ColumnName,
    CASE
        WHEN rm.DataTypeName IN (N'nvarchar', N'varchar', N'nchar', N'char')
            THEN CONCAT(rm.DataTypeName, N'(', CASE WHEN rm.max_length = -1 THEN N'max' ELSE CONVERT(NVARCHAR(10), rm.max_length / CASE WHEN rm.DataTypeName LIKE N'n%' THEN 2 ELSE 1 END) END, N')')
        WHEN rm.DataTypeName IN (N'decimal', N'numeric')
            THEN CONCAT(rm.DataTypeName, N'(', CONVERT(NVARCHAR(10), rm.precision), N',', CONVERT(NVARCHAR(10), rm.scale), N')')
        WHEN rm.DataTypeName IN (N'datetime2', N'datetimeoffset', N'time')
            THEN CONCAT(rm.DataTypeName, N'(', CONVERT(NVARCHAR(10), rm.scale), N')')
        ELSE rm.DataTypeName
    END AS DataTypeDisplay,
    rm.is_nullable AS IsNullable,
    rm.is_identity AS IsIdentity,
    rm.is_computed AS IsComputed,
    rm.PatternTerm,
    rm.PatternCategory,
    rm.MatchType,
    CASE
        WHEN rm.MatchType = N'exact' THEN N'high'
        WHEN rm.MatchType = N'prefix' THEN N'medium'
        ELSE N'low'
    END AS ConfidenceLevel
INTO #BestMatches
FROM RankedMatches AS rm
WHERE rm.MatchRank = 1;

SELECT
    bm.SchemaName,
    bm.ObjectName,
    bm.ObjectTypeCode,
    bm.ObjectTypeDesc,
    bm.ColumnOrdinal,
    bm.ColumnName,
    bm.DataTypeDisplay,
    bm.IsNullable,
    bm.IsIdentity,
    bm.IsComputed,
    bm.PatternTerm,
    bm.PatternCategory,
    bm.MatchType,
    bm.ConfidenceLevel
FROM #BestMatches AS bm
ORDER BY
    bm.SchemaName,
    bm.ObjectName,
    bm.ColumnOrdinal;

SELECT
    bm.SchemaName,
    bm.ObjectName,
    bm.ObjectTypeDesc,
    COUNT(*) AS MatchedColumnCount,
    SUM(CASE WHEN bm.PatternCategory = N'id_hint' THEN 1 ELSE 0 END) AS IdHintColumns,
    SUM(CASE WHEN bm.PatternCategory = N'business_term' THEN 1 ELSE 0 END) AS BusinessTermColumns,
    SUM(CASE WHEN bm.PatternCategory = N'audit_field' THEN 1 ELSE 0 END) AS AuditFieldColumns,
    MIN(bm.PatternTerm) AS FirstMatchedPattern,
    CASE
        WHEN SUM(CASE WHEN bm.PatternCategory = N'id_hint' THEN 1 ELSE 0 END) > 0
         AND SUM(CASE WHEN bm.PatternCategory = N'audit_field' THEN 1 ELSE 0 END) > 0
            THEN N'mixed_identifier_and_audit'
        WHEN COUNT(*) >= 3
            THEN N'wide_pattern_coverage'
        ELSE N'focused_pattern_coverage'
    END AS CoverageLevel
FROM #BestMatches AS bm
GROUP BY
    bm.SchemaName,
    bm.ObjectName,
    bm.ObjectTypeDesc
ORDER BY
    MatchedColumnCount DESC,
    bm.SchemaName,
    bm.ObjectName;

SELECT
    sp.PatternTerm,
    sp.PatternCategory,
    COUNT(bm.ColumnName) AS MatchedColumns,
    COUNT(DISTINCT CONCAT(bm.SchemaName, N'.', bm.ObjectName)) AS DistinctObjects,
    MIN(CONCAT(bm.SchemaName, N'.', bm.ObjectName, N'.', bm.ColumnName)) AS ExampleMatch
FROM #SearchPatterns AS sp
LEFT JOIN #BestMatches AS bm
    ON bm.PatternTerm = sp.PatternTerm
GROUP BY
    sp.PatternTerm,
    sp.PatternCategory,
    sp.PriorityRank
ORDER BY
    sp.PriorityRank,
    sp.PatternTerm;

DROP TABLE IF EXISTS #BestMatches;
DROP TABLE IF EXISTS #SearchPatterns;
