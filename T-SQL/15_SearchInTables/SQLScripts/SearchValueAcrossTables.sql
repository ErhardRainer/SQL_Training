/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "SearchValueAcrossTables.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "15_SearchInTables"

purpose: >
  Durchsucht viele Tabellen der aktuell verbundenen Datenbank dynamisch nach
  einem konkreten Wert oder Suchmuster und liefert Treffer, Tabellenabdeckung
  sowie eine Spaltenzusammenfassung.

parameters:
  - name: "@SearchValue"
    sql_type: "NVARCHAR(4000)"
    direction: "IN"
    required: false
    description: "Konkreter Suchwert oder Muster; NULL verwendet ein didaktisches Standardmuster."
  - name: "@MatchMode"
    sql_type: "NVARCHAR(10)"
    direction: "IN"
    required: false
    description: "contains, exact, starts_with oder ends_with fuer den Suchvergleich."
  - name: "@SchemaPattern"
    sql_type: "NVARCHAR(256)"
    direction: "IN"
    required: false
    description: "Optionales LIKE-Muster fuer Schemas wie dbo oder sales%."
  - name: "@TablePattern"
    sql_type: "NVARCHAR(256)"
    direction: "IN"
    required: false
    description: "Optionales LIKE-Muster fuer Tabellen wie Customer% oder %Audit."
  - name: "@ColumnNamePattern"
    sql_type: "NVARCHAR(256)"
    direction: "IN"
    required: false
    description: "Optionales LIKE-Muster fuer Spaltennamen wie %Name% oder %Code%."
  - name: "@MaxTables"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Begrenzt die Anzahl der geprueften Tabellen fuer kontrollierte Reviews."
  - name: "@MaxHitsPerColumn"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Begrenzt die Zahl der Treffer pro Spalte, damit grosse Datenbestaende diagnostisch beherrschbar bleiben."

result_sets:
  - name: "ValueHits"
    description: "Detailtreffer je Tabelle und Spalte inklusive Schluesselvorschau, Matchmodus und Wertauszug."
  - name: "TableCoverage"
    description: "Verdichtete Sicht pro gepruefter Tabelle mit Status, geprueften Spalten und Trefferanzahl."
  - name: "ColumnSummary"
    description: "Zusammenfassung je gepruefter Spalte mit Trefferstatus und Beispielwert."

dependencies:
  - "sys.tables"
  - "sys.schemas"
  - "sys.columns"
  - "sys.types"
  - "STRING_AGG()"
  - "sp_executesql"
  - "ROW_NUMBER()"
  - "LIKE"
  - "TRY_CONVERT()"
  - "QUOTENAME()"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/15_SearchInTables/SQLScripts/SearchValueAcrossTables.md"
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
    description: "Erstversion eines diagnostischen Suchskripts fuer Werte ueber viele Tabellen."

notes:
  - "Die Erstversion arbeitet rein lesend auf der aktuell verbundenen Datenbank."
  - "Es werden nur character-castbare Spalten aus Basis-Tabellen durchsucht."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @SearchValue NVARCHAR(4000) = NULL;
DECLARE @MatchMode NVARCHAR(10) = N'contains';
DECLARE @SchemaPattern NVARCHAR(256) = NULL;
DECLARE @TablePattern NVARCHAR(256) = NULL;
DECLARE @ColumnNamePattern NVARCHAR(256) = NULL;
DECLARE @MaxTables INT = 25;
DECLARE @MaxHitsPerColumn INT = 5;

DECLARE @SearchPattern NVARCHAR(4000);
DECLARE @CurrentColumnId INT;
DECLARE @CurrentSchemaName SYSNAME;
DECLARE @CurrentTableName SYSNAME;
DECLARE @CurrentColumnName SYSNAME;
DECLARE @CurrentDataType SYSNAME;
DECLARE @CurrentQualifiedTable NVARCHAR(517);
DECLARE @CurrentQualifiedColumn NVARCHAR(600);
DECLARE @KeyExpression NVARCHAR(MAX);
DECLARE @SearchExpression NVARCHAR(MAX);
DECLARE @Sql NVARCHAR(MAX);

SET @MatchMode = LOWER(COALESCE(@MatchMode, N'contains'));
SET @SearchValue = COALESCE(@SearchValue, N'customer');
SET @MaxTables = COALESCE(@MaxTables, 25);
SET @MaxHitsPerColumn = COALESCE(@MaxHitsPerColumn, 5);

IF @MatchMode NOT IN (N'contains', N'exact', N'starts_with', N'ends_with')
BEGIN
    THROW 50000, '@MatchMode muss contains, exact, starts_with oder ends_with sein.', 1;
END;

IF NULLIF(LTRIM(RTRIM(@SearchValue)), N'') IS NULL
BEGIN
    THROW 50001, '@SearchValue darf nicht leer sein.', 1;
END;

IF @MaxTables < 1 OR @MaxTables > 200
BEGIN
    THROW 50002, '@MaxTables muss zwischen 1 und 200 liegen.', 1;
END;

IF @MaxHitsPerColumn < 1 OR @MaxHitsPerColumn > 100
BEGIN
    THROW 50003, '@MaxHitsPerColumn muss zwischen 1 und 100 liegen.', 1;
END;

SET @SearchPattern =
    CASE @MatchMode
        WHEN N'contains' THEN N'%' + @SearchValue + N'%'
        WHEN N'exact' THEN @SearchValue
        WHEN N'starts_with' THEN @SearchValue + N'%'
        WHEN N'ends_with' THEN N'%' + @SearchValue
    END;

DROP TABLE IF EXISTS #TargetColumns;
CREATE TABLE #TargetColumns
(
    TargetColumnId INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    ObjectId INT NOT NULL,
    SchemaName SYSNAME NOT NULL,
    TableName SYSNAME NOT NULL,
    ColumnId INT NOT NULL,
    ColumnName SYSNAME NOT NULL,
    DataTypeName SYSNAME NOT NULL,
    SearchExpression NVARCHAR(MAX) NOT NULL,
    KeyExpression NVARCHAR(MAX) NOT NULL
);

;WITH CandidateTables AS
(
    SELECT TOP (@MaxTables)
        t.object_id AS ObjectId,
        s.name AS SchemaName,
        t.name AS TableName,
        ROW_NUMBER() OVER (ORDER BY s.name, t.name) AS TableRank
    FROM sys.tables AS t
    INNER JOIN sys.schemas AS s
        ON s.schema_id = t.schema_id
    WHERE t.is_ms_shipped = 0
      AND (@SchemaPattern IS NULL OR s.name LIKE @SchemaPattern)
      AND (@TablePattern IS NULL OR t.name LIKE @TablePattern)
    ORDER BY
        s.name,
        t.name
),
CandidateColumns AS
(
    SELECT
        ct.ObjectId,
        ct.SchemaName,
        ct.TableName,
        c.column_id AS ColumnId,
        c.name AS ColumnName,
        ty.name AS DataTypeName
    FROM CandidateTables AS ct
    INNER JOIN sys.columns AS c
        ON c.object_id = ct.ObjectId
    INNER JOIN sys.types AS ty
        ON ty.user_type_id = c.user_type_id
    WHERE c.is_computed = 0
      AND (@ColumnNamePattern IS NULL OR c.name LIKE @ColumnNamePattern)
      AND ty.name IN
      (
          N'char', N'nchar', N'varchar', N'nvarchar',
          N'text', N'ntext', N'uniqueidentifier',
          N'int', N'bigint', N'smallint', N'tinyint',
          N'decimal', N'numeric', N'money', N'smallmoney',
          N'float', N'real', N'date', N'datetime', N'datetime2',
          N'datetimeoffset', N'smalldatetime', N'time'
      )
)
INSERT INTO #TargetColumns
(
    ObjectId,
    SchemaName,
    TableName,
    ColumnId,
    ColumnName,
    DataTypeName,
    SearchExpression,
    KeyExpression
)
SELECT
    cc.ObjectId,
    cc.SchemaName,
    cc.TableName,
    cc.ColumnId,
    cc.ColumnName,
    cc.DataTypeName,
    N'TRY_CONVERT(NVARCHAR(4000), src.' + QUOTENAME(cc.ColumnName) + N')' AS SearchExpression,
    COALESCE(pk.KeyExpression, N'NULL') AS KeyExpression
FROM CandidateColumns AS cc
OUTER APPLY
(
    SELECT
        N'CONCAT(' +
        STRING_AGG(
            N'''' + REPLACE(idxCol.ColumnName, '''', '''''') + N'='' , COALESCE(CONVERT(NVARCHAR(4000), src.' + QUOTENAME(idxCol.ColumnName) + N'), N''<NULL>'')',
            N', N'' | '', '
        ) WITHIN GROUP (ORDER BY idxCol.key_ordinal)
        + N')' AS KeyExpression
    FROM
    (
        SELECT
            ic.key_ordinal,
            cpk.name AS ColumnName
        FROM sys.indexes AS i
        INNER JOIN sys.index_columns AS ic
            ON ic.object_id = i.object_id
           AND ic.index_id = i.index_id
        INNER JOIN sys.columns AS cpk
            ON cpk.object_id = ic.object_id
           AND cpk.column_id = ic.column_id
        WHERE i.object_id = cc.ObjectId
          AND i.is_primary_key = 1
    ) AS idxCol
) AS pk;

IF NOT EXISTS (SELECT 1 FROM #TargetColumns)
BEGIN
    THROW 50004, 'Es wurden keine durchsuchbaren Spalten fuer die aktuelle Filterung gefunden.', 1;
END;

DROP TABLE IF EXISTS #ValueHits;
CREATE TABLE #ValueHits
(
    SchemaName SYSNAME NOT NULL,
    TableName SYSNAME NOT NULL,
    ColumnName SYSNAME NOT NULL,
    DataTypeName SYSNAME NOT NULL,
    MatchMode NVARCHAR(10) NOT NULL,
    SearchValue NVARCHAR(4000) NOT NULL,
    MatchedValue NVARCHAR(4000) NULL,
    RowLocator NVARCHAR(4000) NULL
);

DROP TABLE IF EXISTS #ColumnSummary;
CREATE TABLE #ColumnSummary
(
    SchemaName SYSNAME NOT NULL,
    TableName SYSNAME NOT NULL,
    ColumnName SYSNAME NOT NULL,
    DataTypeName SYSNAME NOT NULL,
    MatchStatus NVARCHAR(20) NOT NULL,
    HitCount INT NOT NULL,
    ExampleValue NVARCHAR(4000) NULL
);

WHILE EXISTS (SELECT 1 FROM #TargetColumns)
BEGIN
    SELECT TOP (1)
        @CurrentColumnId = tc.TargetColumnId,
        @CurrentSchemaName = tc.SchemaName,
        @CurrentTableName = tc.TableName,
        @CurrentColumnName = tc.ColumnName,
        @CurrentDataType = tc.DataTypeName,
        @CurrentQualifiedTable = QUOTENAME(tc.SchemaName) + N'.' + QUOTENAME(tc.TableName),
        @CurrentQualifiedColumn = QUOTENAME(tc.ColumnName),
        @SearchExpression = tc.SearchExpression,
        @KeyExpression = tc.KeyExpression
    FROM #TargetColumns AS tc
    ORDER BY
        tc.SchemaName,
        tc.TableName,
        tc.ColumnId;

    SET @Sql = N'
;WITH SourceRows AS
(
    SELECT
        MatchValue = ' + @SearchExpression + N',
        RowLocator = ' + @KeyExpression + N'
    FROM ' + @CurrentQualifiedTable + N' AS src
),
MatchedRows AS
(
    SELECT
        ROW_NUMBER() OVER
        (
            ORDER BY
                COALESCE(RowLocator, MatchValue, N''''),
                MatchValue
        ) AS HitRowNumber,
        MatchValue,
        RowLocator
    FROM SourceRows
    WHERE MatchValue IS NOT NULL
      AND MatchValue LIKE @SearchPattern
)
INSERT INTO #ValueHits
(
    SchemaName,
    TableName,
    ColumnName,
    DataTypeName,
    MatchMode,
    SearchValue,
    MatchedValue,
    RowLocator
)
SELECT
    @SchemaName,
    @TableName,
    @ColumnName,
    @DataTypeName,
    @MatchMode,
    @SearchValue,
    mr.MatchValue,
    mr.RowLocator
FROM MatchedRows AS mr
WHERE mr.HitRowNumber <= @MaxHitsPerColumn;

INSERT INTO #ColumnSummary
(
    SchemaName,
    TableName,
    ColumnName,
    DataTypeName,
    MatchStatus,
    HitCount,
    ExampleValue
)
SELECT
    @SchemaName,
    @TableName,
    @ColumnName,
    @DataTypeName,
    CASE WHEN COUNT(1) > 0 THEN N''match_found'' ELSE N''no_match'' END,
    COUNT(1),
    MIN(MatchValue)
FROM MatchedRows;';

    EXEC sys.sp_executesql
        @Sql,
        N'@SearchPattern NVARCHAR(4000), @MaxHitsPerColumn INT, @SchemaName SYSNAME, @TableName SYSNAME, @ColumnName SYSNAME, @DataTypeName SYSNAME, @MatchMode NVARCHAR(10), @SearchValue NVARCHAR(4000)',
        @SearchPattern = @SearchPattern,
        @MaxHitsPerColumn = @MaxHitsPerColumn,
        @SchemaName = @CurrentSchemaName,
        @TableName = @CurrentTableName,
        @ColumnName = @CurrentColumnName,
        @DataTypeName = @CurrentDataType,
        @MatchMode = @MatchMode,
        @SearchValue = @SearchValue;

    DELETE FROM #TargetColumns
    WHERE TargetColumnId = @CurrentColumnId;
END;

SELECT
    vh.SchemaName,
    vh.TableName,
    vh.ColumnName,
    vh.DataTypeName,
    vh.MatchMode,
    vh.SearchValue,
    vh.RowLocator,
    vh.MatchedValue
FROM #ValueHits AS vh
ORDER BY
    vh.SchemaName,
    vh.TableName,
    vh.ColumnName,
    vh.RowLocator,
    vh.MatchedValue;

WITH TableCoverage AS
(
    SELECT
        cs.SchemaName,
        cs.TableName,
        COUNT(1) AS CheckedColumns,
        SUM(CASE WHEN cs.MatchStatus = N'match_found' THEN 1 ELSE 0 END) AS MatchingColumns,
        SUM(cs.HitCount) AS TotalHits,
        MIN(CASE WHEN cs.MatchStatus = N'match_found' THEN cs.ColumnName END) AS FirstMatchingColumn
    FROM #ColumnSummary AS cs
    GROUP BY
        cs.SchemaName,
        cs.TableName
)
SELECT
    tc.SchemaName,
    tc.TableName,
    tc.CheckedColumns,
    tc.MatchingColumns,
    tc.TotalHits,
    CASE WHEN tc.MatchingColumns > 0 THEN N'match_found' ELSE N'no_match' END AS CoverageStatus,
    tc.FirstMatchingColumn
FROM TableCoverage AS tc
ORDER BY
    tc.TotalHits DESC,
    tc.MatchingColumns DESC,
    tc.SchemaName,
    tc.TableName;

SELECT
    cs.SchemaName,
    cs.TableName,
    cs.ColumnName,
    cs.DataTypeName,
    cs.MatchStatus,
    cs.HitCount,
    cs.ExampleValue
FROM #ColumnSummary AS cs
ORDER BY
    cs.HitCount DESC,
    cs.SchemaName,
    cs.TableName,
    cs.ColumnName;

DROP TABLE IF EXISTS #ColumnSummary;
DROP TABLE IF EXISTS #ValueHits;
DROP TABLE IF EXISTS #TargetColumns;
