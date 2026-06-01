/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "SearchForeignKeyNames.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "15_SearchInTables"

purpose: >
  Findet Fremdschluessel der aktuell verbundenen Datenbank nach Namen,
  Eltern- oder Referenztabellen sowie optionalen Begriffsfragmenten und zeigt
  dazu Detailtreffer und eine verdichtete Tabellen-Sicht.

parameters:
  - name: "@SearchTerms"
    sql_type: "NVARCHAR(MAX)"
    direction: "IN"
    required: false
    description: "Pipe-separierte Begriffe wie customer|order|address; NULL verwendet ein didaktisches Standardset."
  - name: "@SchemaName"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Optionaler Schemafilter fuer Eltern- und Referenztabellen; NULL durchsucht alle Schemas."
  - name: "@MatchMode"
    sql_type: "NVARCHAR(10)"
    direction: "IN"
    required: false
    description: "contains oder exact fuer die Suche in FK-Namen und Tabellennamen."
  - name: "@IncludeDisabled"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = deaktivierte Fremdschluessel einschliessen, 0 = nur aktive FK-Beziehungen."

result_sets:
  - name: "ForeignKeyMatches"
    description: "Detailtreffer je Fremdschluessel inklusive Match-Feld, Spaltenpaaren und Status."
  - name: "ForeignKeyCoverageByTable"
    description: "Verdichtete Sicht je Eltern-Tabelle mit Trefferanzahl, referenzierten Zielen und Statushinweisen."
  - name: "ForeignKeySearchTermSummary"
    description: "Zusammenfassung der Suchbegriffe inklusive Trefferanzahl und Beispiel-Fremdschluessel."

dependencies:
  - "sys.foreign_keys"
  - "sys.foreign_key_columns"
  - "sys.tables"
  - "sys.schemas"
  - "sys.columns"
  - "STRING_SPLIT()"
  - "STRING_AGG()"
  - "ROW_NUMBER()"
  - "CASE"
  - "LIKE"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/15_SearchInTables/SQLScripts/SearchForeignKeyNames.md"
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
    description: "Erstversion eines diagnostischen Metadaten-Skripts fuer Fremdschluessel-Namen."

notes:
  - "Die Erstversion arbeitet rein lesend auf FK-Metadaten der aktuell verbundenen Datenbank."
  - "Suche und Ergebnisfokus liegen auf FK-Namen sowie Eltern- und Referenzobjekten, nicht auf Dateninhalten."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @SearchTerms NVARCHAR(MAX) = NULL;
DECLARE @SchemaName SYSNAME = NULL;
DECLARE @MatchMode NVARCHAR(10) = N'contains';
DECLARE @IncludeDisabled BIT = 1;

SET @MatchMode = LOWER(COALESCE(@MatchMode, N'contains'));

IF @MatchMode NOT IN (N'contains', N'exact')
BEGIN
    THROW 50000, '@MatchMode muss contains oder exact sein.', 1;
END;

IF @IncludeDisabled NOT IN (0, 1)
BEGIN
    THROW 50001, '@IncludeDisabled muss 0 oder 1 sein.', 1;
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
        (N'customer', N'business_entity', 10),
        (N'order', N'business_entity', 11),
        (N'address', N'business_entity', 12),
        (N'line', N'child_entity', 20),
        (N'header', N'parent_entity', 21),
        (N'tenant', N'governance_term', 30),
        (N'region', N'governance_term', 31),
        (N'archive', N'lifecycle_term', 32);
END;
ELSE
BEGIN
    INSERT INTO #SearchTerms (SearchTerm, SearchCategory, PriorityRank)
    SELECT
        src.SearchTerm,
        CASE
            WHEN src.SearchTerm IN (N'customer', N'order', N'product', N'address', N'account') THEN N'business_entity'
            WHEN src.SearchTerm IN (N'line', N'item', N'detail', N'position') THEN N'child_entity'
            WHEN src.SearchTerm IN (N'header', N'master', N'parent', N'root') THEN N'parent_entity'
            WHEN src.SearchTerm IN (N'tenant', N'region', N'company', N'org') THEN N'governance_term'
            ELSE N'custom_pattern'
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

WITH ForeignKeyInventory AS
(
    SELECT
        ps.name AS ParentSchemaName,
        pt.name AS ParentTableName,
        fk.name AS ForeignKeyName,
        rs.name AS ReferencedSchemaName,
        rt.name AS ReferencedTableName,
        fk.is_disabled AS IsDisabled,
        fk.is_not_trusted AS IsNotTrusted,
        fk.delete_referential_action_desc AS DeleteAction,
        fk.update_referential_action_desc AS UpdateAction,
        STRING_AGG(
            CONCAT(QUOTENAME(pc.name), N' -> ', QUOTENAME(rc.name)),
            N', '
        ) WITHIN GROUP (ORDER BY fkc.constraint_column_id) AS ColumnMapping,
        LOWER(REPLACE(REPLACE(REPLACE(fk.name, N' ', N''), N'-', N''), N'_', N'')) AS NormalizedForeignKeyName,
        LOWER(REPLACE(REPLACE(REPLACE(pt.name, N' ', N''), N'-', N''), N'_', N'')) AS NormalizedParentTableName,
        LOWER(REPLACE(REPLACE(REPLACE(rt.name, N' ', N''), N'-', N''), N'_', N'')) AS NormalizedReferencedTableName
    FROM sys.foreign_keys AS fk
    INNER JOIN sys.tables AS pt
        ON pt.object_id = fk.parent_object_id
    INNER JOIN sys.schemas AS ps
        ON ps.schema_id = pt.schema_id
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
    WHERE (@SchemaName IS NULL OR ps.name = @SchemaName OR rs.name = @SchemaName)
      AND (@IncludeDisabled = 1 OR fk.is_disabled = 0)
    GROUP BY
        ps.name,
        pt.name,
        fk.name,
        rs.name,
        rt.name,
        fk.is_disabled,
        fk.is_not_trusted,
        fk.delete_referential_action_desc,
        fk.update_referential_action_desc
),
PatternMatches AS
(
    SELECT
        fki.ParentSchemaName,
        fki.ParentTableName,
        fki.ForeignKeyName,
        fki.ReferencedSchemaName,
        fki.ReferencedTableName,
        fki.IsDisabled,
        fki.IsNotTrusted,
        fki.DeleteAction,
        fki.UpdateAction,
        fki.ColumnMapping,
        st.SearchTerm,
        st.SearchCategory,
        st.PriorityRank,
        CASE
            WHEN @MatchMode = N'exact' AND fki.NormalizedForeignKeyName = st.SearchTerm THEN N'foreign_key_name'
            WHEN @MatchMode = N'exact' AND fki.NormalizedParentTableName = st.SearchTerm THEN N'parent_table'
            WHEN @MatchMode = N'exact' AND fki.NormalizedReferencedTableName = st.SearchTerm THEN N'referenced_table'
            WHEN @MatchMode = N'contains' AND fki.NormalizedForeignKeyName LIKE N'%' + st.SearchTerm + N'%' THEN N'foreign_key_name'
            WHEN @MatchMode = N'contains' AND fki.NormalizedParentTableName LIKE N'%' + st.SearchTerm + N'%' THEN N'parent_table'
            WHEN @MatchMode = N'contains' AND fki.NormalizedReferencedTableName LIKE N'%' + st.SearchTerm + N'%' THEN N'referenced_table'
        END AS MatchField
    FROM ForeignKeyInventory AS fki
    INNER JOIN #SearchTerms AS st
        ON
            (@MatchMode = N'exact' AND
                (
                    fki.NormalizedForeignKeyName = st.SearchTerm
                    OR fki.NormalizedParentTableName = st.SearchTerm
                    OR fki.NormalizedReferencedTableName = st.SearchTerm
                ))
            OR
            (@MatchMode = N'contains' AND
                (
                    fki.NormalizedForeignKeyName LIKE N'%' + st.SearchTerm + N'%'
                    OR fki.NormalizedParentTableName LIKE N'%' + st.SearchTerm + N'%'
                    OR fki.NormalizedReferencedTableName LIKE N'%' + st.SearchTerm + N'%'
                ))
),
RankedMatches AS
(
    SELECT
        pm.*,
        ROW_NUMBER() OVER
        (
            PARTITION BY
                pm.ParentSchemaName,
                pm.ParentTableName,
                pm.ForeignKeyName,
                pm.SearchTerm
            ORDER BY
                CASE pm.MatchField
                    WHEN N'foreign_key_name' THEN 0
                    WHEN N'parent_table' THEN 1
                    ELSE 2
                END,
                pm.PriorityRank
        ) AS MatchRank
    FROM PatternMatches AS pm
),
BestMatches AS
(
    SELECT
        rm.ParentSchemaName,
        rm.ParentTableName,
        rm.ForeignKeyName,
        rm.ReferencedSchemaName,
        rm.ReferencedTableName,
        rm.IsDisabled,
        rm.IsNotTrusted,
        rm.DeleteAction,
        rm.UpdateAction,
        rm.ColumnMapping,
        rm.SearchTerm,
        rm.SearchCategory,
        rm.MatchField,
        CASE
            WHEN rm.MatchField = N'foreign_key_name' THEN N'high'
            ELSE N'medium'
        END AS ConfidenceLevel
    FROM RankedMatches AS rm
    WHERE rm.MatchRank = 1
)
SELECT
    bm.ParentSchemaName,
    bm.ParentTableName,
    bm.ForeignKeyName,
    bm.ReferencedSchemaName,
    bm.ReferencedTableName,
    bm.SearchTerm,
    bm.SearchCategory,
    bm.MatchField,
    bm.ConfidenceLevel,
    bm.IsDisabled,
    bm.IsNotTrusted,
    bm.DeleteAction,
    bm.UpdateAction,
    bm.ColumnMapping
INTO #BestMatches
FROM BestMatches AS bm;

SELECT
    bm.ParentSchemaName,
    bm.ParentTableName,
    bm.ForeignKeyName,
    CONCAT(bm.ReferencedSchemaName, N'.', bm.ReferencedTableName) AS ReferencedObject,
    bm.SearchTerm,
    bm.SearchCategory,
    bm.MatchField,
    bm.ConfidenceLevel,
    bm.IsDisabled,
    bm.IsNotTrusted,
    bm.DeleteAction,
    bm.UpdateAction,
    bm.ColumnMapping
FROM #BestMatches AS bm
ORDER BY
    bm.ParentSchemaName,
    bm.ParentTableName,
    bm.ForeignKeyName,
    bm.SearchTerm;

SELECT
    bm.ParentSchemaName,
    bm.ParentTableName,
    COUNT(DISTINCT bm.ForeignKeyName) AS MatchedForeignKeys,
    COUNT(DISTINCT CONCAT(bm.ReferencedSchemaName, N'.', bm.ReferencedTableName)) AS DistinctReferencedTargets,
    SUM(CASE WHEN bm.IsDisabled = 1 THEN 1 ELSE 0 END) AS DisabledMatches,
    SUM(CASE WHEN bm.IsNotTrusted = 1 THEN 1 ELSE 0 END) AS NotTrustedMatches,
    MIN(bm.SearchTerm) AS FirstMatchedSearchTerm,
    CASE
        WHEN SUM(CASE WHEN bm.IsDisabled = 1 OR bm.IsNotTrusted = 1 THEN 1 ELSE 0 END) > 0
            THEN N'review_fk_health'
        WHEN COUNT(DISTINCT bm.ForeignKeyName) >= 3
            THEN N'wide_fk_coverage'
        ELSE N'focused_fk_lookup'
    END AS CoverageLevel
FROM #BestMatches AS bm
GROUP BY
    bm.ParentSchemaName,
    bm.ParentTableName
ORDER BY
    MatchedForeignKeys DESC,
    bm.ParentSchemaName,
    bm.ParentTableName;

SELECT
    st.SearchTerm,
    st.SearchCategory,
    COUNT(DISTINCT bm.ForeignKeyName) AS MatchedForeignKeys,
    COUNT(DISTINCT CONCAT(bm.ParentSchemaName, N'.', bm.ParentTableName)) AS DistinctParentTables,
    MIN(CONCAT(bm.ParentSchemaName, N'.', bm.ParentTableName, N'.', bm.ForeignKeyName)) AS ExampleForeignKey
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
