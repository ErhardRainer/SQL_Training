/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "SearchConstraintDefinitions.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "15_SearchInTables"

purpose: >
  Durchsucht CHECK-, DEFAULT- und Fremdschluesseldefinitionen der aktuell
  verbundenen Datenbank nach frei definierbaren Suchbegriffen und zeigt sowohl
  Detailtreffer als auch eine verdichtete Constraint-Sicht.

parameters:
  - name: "@SearchTerms"
    sql_type: "NVARCHAR(MAX)"
    direction: "IN"
    required: false
    description: "Pipe-separierte Suchbegriffe wie status|isactive|archive; NULL verwendet ein didaktisches Standardset."
  - name: "@SchemaName"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Optionaler Schemafilter; NULL durchsucht alle Schemas."
  - name: "@ConstraintType"
    sql_type: "NVARCHAR(10)"
    direction: "IN"
    required: false
    description: "ALL, CHECK, DEFAULT oder FK zur Eingrenzung des Constraint-Typs."
  - name: "@MatchMode"
    sql_type: "NVARCHAR(10)"
    direction: "IN"
    required: false
    description: "contains oder exact fuer die Suche in Constraint-Namen und Definitionen."

result_sets:
  - name: "ConstraintDefinitionMatches"
    description: "Detailtreffer je Constraint inklusive Suchbegriff, Trefferort und Definitionsauszug."
  - name: "ConstraintCoverageByObject"
    description: "Verdichtete Sicht je Tabelle auf gefundene Constraint-Typen und Trefferanzahl."
  - name: "ConstraintPatternSummary"
    description: "Zusammenfassung der Suchbegriffe und der betroffenen Constraints."

dependencies:
  - "sys.check_constraints"
  - "sys.default_constraints"
  - "sys.foreign_keys"
  - "sys.foreign_key_columns"
  - "sys.tables"
  - "sys.schemas"
  - "sys.columns"
  - "STRING_SPLIT()"
  - "ROW_NUMBER()"
  - "CASE"
  - "LIKE"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/15_SearchInTables/SQLScripts/SearchConstraintDefinitions.md"
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
    description: "Erstversion eines diagnostischen Metadaten-Skripts fuer Constraint-Definitionen."

notes:
  - "Die Erstversion arbeitet rein lesend auf Constraint-Metadaten der aktuell verbundenen Datenbank."
  - "Definitionen werden fuer die Suche normalisiert, aber unverkuerzt im Kontextauszug dokumentiert."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @SearchTerms NVARCHAR(MAX) = NULL;
DECLARE @SchemaName SYSNAME = NULL;
DECLARE @ConstraintType NVARCHAR(10) = N'ALL';
DECLARE @MatchMode NVARCHAR(10) = N'contains';

SET @ConstraintType = UPPER(COALESCE(@ConstraintType, N'ALL'));
SET @MatchMode = LOWER(COALESCE(@MatchMode, N'contains'));

IF @ConstraintType NOT IN (N'ALL', N'CHECK', N'DEFAULT', N'FK')
BEGIN
    THROW 50000, '@ConstraintType muss ALL, CHECK, DEFAULT oder FK sein.', 1;
END;

IF @MatchMode NOT IN (N'contains', N'exact')
BEGIN
    THROW 50001, '@MatchMode muss contains oder exact sein.', 1;
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

DROP TABLE IF EXISTS #SearchTerms;
CREATE TABLE #SearchTerms
(
    SearchTerm NVARCHAR(128) NOT NULL PRIMARY KEY,
    SearchCategory NVARCHAR(30) NOT NULL,
    PriorityRank INT NOT NULL
);

IF NULLIF(LTRIM(RTRIM(COALESCE(@SearchTerms, N''))), N'') IS NULL
BEGIN
    INSERT INTO #SearchTerms (SearchTerm, SearchCategory, PriorityRank)
    VALUES
        (N'status', N'business_term', 10),
        (N'isactive', N'business_term', 11),
        (N'archive', N'lifecycle_term', 12),
        (N'deleted', N'lifecycle_term', 13),
        (N'created', N'audit_term', 14),
        (N'updated', N'audit_term', 15),
        (N'customer', N'reference_term', 16),
        (N'order', N'reference_term', 17);
END;
ELSE
BEGIN
    INSERT INTO #SearchTerms (SearchTerm, SearchCategory, PriorityRank)
    SELECT
        src.SearchTerm,
        CASE
            WHEN src.SearchTerm IN (N'created', N'updated', N'modified', N'audit') THEN N'audit_term'
            WHEN src.SearchTerm IN (N'archive', N'archived', N'deleted', N'inactive', N'isactive') THEN N'lifecycle_term'
            WHEN src.SearchTerm IN (N'customer', N'order', N'product', N'region', N'tenant') THEN N'reference_term'
            ELSE N'business_term'
        END AS SearchCategory,
        100 + ROW_NUMBER() OVER (ORDER BY src.SearchTerm) AS PriorityRank
    FROM
    (
        SELECT DISTINCT
            LOWER(LTRIM(RTRIM(value))) AS SearchTerm
        FROM STRING_SPLIT(@SearchTerms, N'|')
        WHERE NULLIF(LTRIM(RTRIM(value)), N'') IS NOT NULL
    ) AS src;
END;

IF NOT EXISTS (SELECT 1 FROM #SearchTerms)
BEGIN
    THROW 50003, 'Es wurde kein gueltiger Suchbegriff fuer @SearchTerms ermittelt.', 1;
END;

WITH ConstraintInventory AS
(
    SELECT
        s.name AS SchemaName,
        t.name AS TableName,
        cc.name AS ConstraintName,
        N'CHECK' AS ConstraintType,
        cc.definition AS ConstraintDefinition,
        CAST(NULL AS NVARCHAR(MAX)) AS ReferencedObject,
        CAST(NULL AS NVARCHAR(MAX)) AS ColumnList
    FROM sys.check_constraints AS cc
    INNER JOIN sys.tables AS t
        ON t.object_id = cc.parent_object_id
    INNER JOIN sys.schemas AS s
        ON s.schema_id = t.schema_id
    WHERE (@SchemaName IS NULL OR s.name = @SchemaName)
      AND (@ConstraintType IN (N'ALL', N'CHECK'))

    UNION ALL

    SELECT
        s.name AS SchemaName,
        t.name AS TableName,
        dc.name AS ConstraintName,
        N'DEFAULT' AS ConstraintType,
        dc.definition AS ConstraintDefinition,
        CAST(NULL AS NVARCHAR(MAX)) AS ReferencedObject,
        c.name AS ColumnList
    FROM sys.default_constraints AS dc
    INNER JOIN sys.tables AS t
        ON t.object_id = dc.parent_object_id
    INNER JOIN sys.schemas AS s
        ON s.schema_id = t.schema_id
    INNER JOIN sys.columns AS c
        ON c.object_id = dc.parent_object_id
       AND c.column_id = dc.parent_column_id
    WHERE (@SchemaName IS NULL OR s.name = @SchemaName)
      AND (@ConstraintType IN (N'ALL', N'DEFAULT'))

    UNION ALL

    SELECT
        s.name AS SchemaName,
        pt.name AS TableName,
        fk.name AS ConstraintName,
        N'FK' AS ConstraintType,
        CONCAT(
            N'References ',
            QUOTENAME(rs.name),
            N'.',
            QUOTENAME(rt.name),
            N' (',
            STRING_AGG(QUOTENAME(rc.name), N', ') WITHIN GROUP (ORDER BY fkc.constraint_column_id),
            N')'
        ) AS ConstraintDefinition,
        CONCAT(rs.name, N'.', rt.name) AS ReferencedObject,
        STRING_AGG(QUOTENAME(pc.name), N', ') WITHIN GROUP (ORDER BY fkc.constraint_column_id) AS ColumnList
    FROM sys.foreign_keys AS fk
    INNER JOIN sys.tables AS pt
        ON pt.object_id = fk.parent_object_id
    INNER JOIN sys.schemas AS s
        ON s.schema_id = pt.schema_id
    INNER JOIN sys.tables AS rt
        ON rt.object_id = fk.referenced_object_id
    INNER JOIN sys.schemas AS rs
        ON rs.schema_id = rt.schema_id
    INNER JOIN sys.foreign_key_columns AS fkc
        ON fkc.constraint_object_id = fk.object_id
    INNER JOIN sys.columns AS pc
        ON pc.object_id = fkc.parent_object_id
       AND pc.column_id = fkc.parent_column_id
    INNER JOIN sys.columns AS rc
        ON rc.object_id = fkc.referenced_object_id
       AND rc.column_id = fkc.referenced_column_id
    WHERE (@SchemaName IS NULL OR s.name = @SchemaName)
      AND (@ConstraintType IN (N'ALL', N'FK'))
    GROUP BY
        s.name,
        pt.name,
        fk.name,
        rs.name,
        rt.name
),
NormalizedConstraints AS
(
    SELECT
        ci.SchemaName,
        ci.TableName,
        ci.ConstraintName,
        ci.ConstraintType,
        ci.ConstraintDefinition,
        ci.ReferencedObject,
        ci.ColumnList,
        LOWER(REPLACE(REPLACE(REPLACE(ci.ConstraintName, N' ', N''), N'-', N''), N'_', N'')) AS NormalizedConstraintName,
        LOWER(REPLACE(REPLACE(REPLACE(COALESCE(ci.ConstraintDefinition, N''), N' ', N''), CHAR(9), N''), CHAR(13) + CHAR(10), N'')) AS NormalizedDefinition
    FROM ConstraintInventory AS ci
),
PatternMatches AS
(
    SELECT
        nc.SchemaName,
        nc.TableName,
        nc.ConstraintName,
        nc.ConstraintType,
        nc.ConstraintDefinition,
        nc.ReferencedObject,
        nc.ColumnList,
        st.SearchTerm,
        st.SearchCategory,
        st.PriorityRank,
        CASE
            WHEN @MatchMode = N'exact' AND nc.NormalizedConstraintName = st.SearchTerm THEN N'constraint_name'
            WHEN @MatchMode = N'exact' AND nc.NormalizedDefinition = st.SearchTerm THEN N'definition'
            WHEN @MatchMode = N'contains' AND nc.NormalizedConstraintName LIKE N'%' + st.SearchTerm + N'%' THEN N'constraint_name'
            WHEN @MatchMode = N'contains' AND nc.NormalizedDefinition LIKE N'%' + st.SearchTerm + N'%' THEN N'definition'
        END AS MatchLocation
    FROM NormalizedConstraints AS nc
    INNER JOIN #SearchTerms AS st
        ON
            (@MatchMode = N'exact' AND (nc.NormalizedConstraintName = st.SearchTerm OR nc.NormalizedDefinition = st.SearchTerm))
            OR
            (@MatchMode = N'contains' AND (nc.NormalizedConstraintName LIKE N'%' + st.SearchTerm + N'%' OR nc.NormalizedDefinition LIKE N'%' + st.SearchTerm + N'%'))
),
RankedMatches AS
(
    SELECT
        pm.*,
        ROW_NUMBER() OVER
        (
            PARTITION BY pm.SchemaName, pm.TableName, pm.ConstraintName, pm.SearchTerm
            ORDER BY
                CASE pm.MatchLocation WHEN N'constraint_name' THEN 0 ELSE 1 END,
                pm.PriorityRank
        ) AS MatchRank
    FROM PatternMatches AS pm
),
BestMatches AS
(
    SELECT
        rm.SchemaName,
        rm.TableName,
        rm.ConstraintName,
        rm.ConstraintType,
        rm.SearchTerm,
        rm.SearchCategory,
        rm.MatchLocation,
        rm.ReferencedObject,
        rm.ColumnList,
        rm.ConstraintDefinition,
        CASE
            WHEN rm.MatchLocation = N'constraint_name' THEN N'high'
            ELSE N'medium'
        END AS ConfidenceLevel
    FROM RankedMatches AS rm
    WHERE rm.MatchRank = 1
)
SELECT
    bm.SchemaName,
    bm.TableName,
    bm.ConstraintName,
    bm.ConstraintType,
    bm.SearchTerm,
    bm.SearchCategory,
    bm.MatchLocation,
    bm.ConfidenceLevel,
    bm.ColumnList,
    bm.ReferencedObject,
    LEFT(REPLACE(REPLACE(COALESCE(bm.ConstraintDefinition, N''), CHAR(13), N' '), CHAR(10), N' '), 240) AS DefinitionExcerpt
INTO #BestMatches
FROM BestMatches AS bm;

SELECT
    bm.SchemaName,
    bm.TableName,
    bm.ConstraintName,
    bm.ConstraintType,
    bm.SearchTerm,
    bm.SearchCategory,
    bm.MatchLocation,
    bm.ConfidenceLevel,
    bm.ColumnList,
    bm.ReferencedObject,
    bm.DefinitionExcerpt
FROM #BestMatches AS bm
ORDER BY
    bm.SchemaName,
    bm.TableName,
    bm.ConstraintType,
    bm.ConstraintName,
    bm.SearchTerm;

SELECT
    bm.SchemaName,
    bm.TableName,
    COUNT(DISTINCT bm.ConstraintName) AS MatchedConstraintCount,
    SUM(CASE WHEN bm.ConstraintType = N'CHECK' THEN 1 ELSE 0 END) AS CheckMatches,
    SUM(CASE WHEN bm.ConstraintType = N'DEFAULT' THEN 1 ELSE 0 END) AS DefaultMatches,
    SUM(CASE WHEN bm.ConstraintType = N'FK' THEN 1 ELSE 0 END) AS ForeignKeyMatches,
    MIN(bm.SearchTerm) AS FirstMatchedSearchTerm,
    CASE
        WHEN SUM(CASE WHEN bm.ConstraintType = N'CHECK' THEN 1 ELSE 0 END) > 0
         AND SUM(CASE WHEN bm.ConstraintType = N'FK' THEN 1 ELSE 0 END) > 0
            THEN N'mixed_validation_and_reference_rules'
        WHEN COUNT(DISTINCT bm.ConstraintName) >= 3
            THEN N'wide_constraint_coverage'
        ELSE N'focused_constraint_coverage'
    END AS CoverageLevel
FROM #BestMatches AS bm
GROUP BY
    bm.SchemaName,
    bm.TableName
ORDER BY
    MatchedConstraintCount DESC,
    bm.SchemaName,
    bm.TableName;

SELECT
    st.SearchTerm,
    st.SearchCategory,
    COUNT(DISTINCT bm.ConstraintName) AS MatchedConstraints,
    COUNT(DISTINCT CONCAT(bm.SchemaName, N'.', bm.TableName)) AS DistinctTables,
    MIN(CONCAT(bm.SchemaName, N'.', bm.TableName, N'.', bm.ConstraintName)) AS ExampleConstraint
FROM #SearchTerms AS st
LEFT JOIN #BestMatches AS bm
    ON bm.SearchTerm = st.SearchTerm
GROUP BY
    st.SearchTerm,
    st.SearchCategory,
    st.PriorityRank
ORDER BY
    st.PriorityRank,
    st.SearchTerm;

DROP TABLE IF EXISTS #BestMatches;
DROP TABLE IF EXISTS #SearchTerms;
