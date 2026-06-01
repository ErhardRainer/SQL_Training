/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "ColumnOrderMismatchDetector.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "09_Set_Operations"

purpose: >
  Stellt in tempdb zwei Projektionen fuer Set-Operationen gegenueber und
  markiert Unterschiede in Spaltenreihenfolge, Datentypen und
  Kompatibilitaetsrisiken vor UNION, EXCEPT oder INTERSECT.

parameters:
  - name: "@SetOperator"
    sql_type: "NVARCHAR(20)"
    direction: "IN"
    required: false
    description: "Nur fuer die didaktische Beschriftung des Berichts, zum Beispiel UNION oder EXCEPT"
  - name: "@IncludeSampleData"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zeigt zusaetzlich Beispielzeilen der linken und rechten Projektion an"

result_sets:
  - name: "ColumnAlignmentReport"
    description: "Vergleicht die Spaltenpositionen, Namen und Datentypen beider Projektionen"
  - name: "CompatibilitySummary"
    description: "Verdichtet die wichtigsten Risiken fuer die geplante Set-Operation"
  - name: "LeftProjectionSample"
    description: "Optionale Beispielzeilen der linken Projektion"
  - name: "RightProjectionSample"
    description: "Optionale Beispielzeilen der rechten Projektion"

dependencies:
  - "tempdb"
  - "sys.columns"
  - "sys.types"
  - "OBJECT_ID()"
  - "ROW_NUMBER()"
  - "CASE"
  - "DROP TABLE IF EXISTS"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/09_Set_Operations/SQLScripts/ColumnOrderMismatchDetector.md"
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
    description: "Erstversion eines Diagnose-Skripts fuer Spaltenreihenfolge und Typkonflikte vor Set-Operationen"

notes:
  - "Die Demo verwendet lokale Temp-Tabellen statt produktiver Quelltabellen"
  - "Der Bericht bewertet Positionsgleichheit getrennt von Namens- und Typkompatibilitaet"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @SetOperator NVARCHAR(20) = N'UNION';
DECLARE @IncludeSampleData BIT = 1;

IF NULLIF(LTRIM(RTRIM(@SetOperator)), N'') IS NULL
BEGIN
    THROW 50000, '@SetOperator darf nicht leer sein.', 1;
END;

IF UPPER(@SetOperator) NOT IN (N'UNION', N'UNION ALL', N'EXCEPT', N'INTERSECT')
BEGIN
    THROW 50001, '@SetOperator muss UNION, UNION ALL, EXCEPT oder INTERSECT sein.', 1;
END;

IF @IncludeSampleData NOT IN (0, 1)
BEGIN
    THROW 50002, '@IncludeSampleData muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #LeftProjection;
DROP TABLE IF EXISTS #RightProjection;
DROP TABLE IF EXISTS #ColumnPairs;

CREATE TABLE #LeftProjection
(
    CustomerCode    INT             NOT NULL,
    RegionCode      CHAR(2)         NOT NULL,
    OrderAmount     DECIMAL(12,2)   NOT NULL
);

CREATE TABLE #RightProjection
(
    RegionCode      NVARCHAR(20)    NOT NULL,
    CustomerCode    INT             NOT NULL,
    OrderAmount     NVARCHAR(30)    NOT NULL
);

INSERT INTO #LeftProjection
(
    CustomerCode,
    RegionCode,
    OrderAmount
)
VALUES
    (1001, 'DE', 1250.00),
    (1002, 'AT', 980.50),
    (1003, 'CH', 1475.25);

INSERT INTO #RightProjection
(
    RegionCode,
    CustomerCode,
    OrderAmount
)
VALUES
    (N'DE', 1001, N'1250.00'),
    (N'AT', 1002, N'980.50'),
    (N'CH-NORD', 1003, N'unbekannt');

;WITH LeftMeta AS
(
    SELECT
        c.column_id,
        c.name AS column_name,
        t.name AS type_name,
        c.max_length,
        c.precision,
        c.scale,
        CASE
            WHEN t.name IN (N'nvarchar', N'nchar') AND c.max_length > 0 THEN c.max_length / 2
            ELSE c.max_length
        END AS display_length
    FROM tempdb.sys.columns AS c
    INNER JOIN tempdb.sys.types AS t
        ON c.user_type_id = t.user_type_id
    WHERE c.object_id = OBJECT_ID(N'tempdb..#LeftProjection')
),
RightMeta AS
(
    SELECT
        c.column_id,
        c.name AS column_name,
        t.name AS type_name,
        c.max_length,
        c.precision,
        c.scale,
        CASE
            WHEN t.name IN (N'nvarchar', N'nchar') AND c.max_length > 0 THEN c.max_length / 2
            ELSE c.max_length
        END AS display_length
    FROM tempdb.sys.columns AS c
    INNER JOIN tempdb.sys.types AS t
        ON c.user_type_id = t.user_type_id
    WHERE c.object_id = OBJECT_ID(N'tempdb..#RightProjection')
)
SELECT
    COALESCE(l.column_id, r.column_id) AS column_ordinal,
    l.column_name AS left_column_name,
    r.column_name AS right_column_name,
    l.type_name AS left_type_name,
    r.type_name AS right_type_name,
    l.display_length AS left_length,
    r.display_length AS right_length,
    l.precision AS left_precision,
    r.precision AS right_precision,
    l.scale AS left_scale,
    r.scale AS right_scale
INTO #ColumnPairs
FROM LeftMeta AS l
FULL OUTER JOIN RightMeta AS r
    ON l.column_id = r.column_id;

;WITH EvaluatedPairs AS
(
    SELECT
        pair.column_ordinal,
        pair.left_column_name,
        pair.right_column_name,
        CONCAT(
            pair.left_type_name,
            CASE
                WHEN pair.left_type_name IN (N'char', N'varchar', N'nchar', N'nvarchar')
                    THEN CONCAT(N'(', pair.left_length, N')')
                WHEN pair.left_type_name IN (N'decimal', N'numeric')
                    THEN CONCAT(N'(', pair.left_precision, N',', pair.left_scale, N')')
                ELSE N''
            END
        ) AS left_declared_type,
        CONCAT(
            pair.right_type_name,
            CASE
                WHEN pair.right_type_name IN (N'char', N'varchar', N'nchar', N'nvarchar')
                    THEN CONCAT(N'(', pair.right_length, N')')
                WHEN pair.right_type_name IN (N'decimal', N'numeric')
                    THEN CONCAT(N'(', pair.right_precision, N',', pair.right_scale, N')')
                ELSE N''
            END
        ) AS right_declared_type,
        CASE
            WHEN pair.left_column_name IS NULL OR pair.right_column_name IS NULL THEN N'missing-column'
            WHEN pair.left_column_name = pair.right_column_name THEN N'aligned'
            ELSE N'name-order-mismatch'
        END AS column_alignment,
        CASE
            WHEN pair.left_type_name IS NULL OR pair.right_type_name IS NULL THEN N'missing-type'
            WHEN pair.left_type_name = pair.right_type_name
                 AND ISNULL(pair.left_length, -1) = ISNULL(pair.right_length, -1)
                 AND ISNULL(pair.left_precision, -1) = ISNULL(pair.right_precision, -1)
                 AND ISNULL(pair.left_scale, -1) = ISNULL(pair.right_scale, -1)
                THEN N'exact-match'
            WHEN pair.left_type_name IN (N'decimal', N'numeric')
                 AND pair.right_type_name IN (N'decimal', N'numeric')
                THEN N'numeric-convertible'
            WHEN pair.left_type_name IN (N'char', N'varchar', N'nchar', N'nvarchar')
                 AND pair.right_type_name IN (N'char', N'varchar', N'nchar', N'nvarchar')
                THEN N'string-convertible'
            WHEN pair.left_type_name IN (N'int', N'bigint', N'smallint', N'tinyint')
                 AND pair.right_type_name IN (N'int', N'bigint', N'smallint', N'tinyint')
                THEN N'integer-convertible'
            ELSE N'conversion-risk'
        END AS type_alignment,
        CASE
            WHEN pair.left_column_name IS NULL OR pair.right_column_name IS NULL
                THEN N'Projektionen liefern nicht dieselbe Spaltenanzahl.'
            WHEN pair.left_column_name <> pair.right_column_name
                THEN N'Dieselbe Position beschreibt unterschiedliche Fachattribute.'
            WHEN pair.left_type_name <> pair.right_type_name
                THEN N'Spaltennamen passen, aber SQL Server muesste implizit konvertieren.'
            ELSE N'Position, Name und Typ sind konsistent.'
        END AS finding
    FROM #ColumnPairs AS pair
)
SELECT
    evaluation.column_ordinal,
    evaluation.left_column_name,
    evaluation.left_declared_type,
    evaluation.right_column_name,
    evaluation.right_declared_type,
    evaluation.column_alignment,
    evaluation.type_alignment,
    evaluation.finding,
    CASE
        WHEN evaluation.column_alignment = N'aligned'
             AND evaluation.type_alignment = N'exact-match'
            THEN N'ok'
        WHEN evaluation.column_alignment = N'aligned'
             AND evaluation.type_alignment IN (N'numeric-convertible', N'string-convertible', N'integer-convertible')
            THEN N'review-cast'
        ELSE N'fix-before-set-operation'
    END AS recommended_action
FROM EvaluatedPairs AS evaluation
ORDER BY
    evaluation.column_ordinal;

;WITH Risks AS
(
    SELECT
        SUM(CASE WHEN column_alignment <> N'aligned' THEN 1 ELSE 0 END) AS order_issues,
        SUM(CASE WHEN type_alignment IN (N'conversion-risk', N'missing-type') THEN 1 ELSE 0 END) AS hard_type_issues,
        SUM(CASE WHEN type_alignment IN (N'numeric-convertible', N'string-convertible', N'integer-convertible') THEN 1 ELSE 0 END) AS soft_type_issues
    FROM
    (
        SELECT
            CASE
                WHEN pair.left_column_name IS NULL OR pair.right_column_name IS NULL THEN N'missing-column'
                WHEN pair.left_column_name = pair.right_column_name THEN N'aligned'
                ELSE N'name-order-mismatch'
            END AS column_alignment,
            CASE
                WHEN pair.left_type_name IS NULL OR pair.right_type_name IS NULL THEN N'missing-type'
                WHEN pair.left_type_name = pair.right_type_name
                     AND ISNULL(pair.left_length, -1) = ISNULL(pair.right_length, -1)
                     AND ISNULL(pair.left_precision, -1) = ISNULL(pair.right_precision, -1)
                     AND ISNULL(pair.left_scale, -1) = ISNULL(pair.right_scale, -1)
                    THEN N'exact-match'
                WHEN pair.left_type_name IN (N'decimal', N'numeric')
                     AND pair.right_type_name IN (N'decimal', N'numeric')
                    THEN N'numeric-convertible'
                WHEN pair.left_type_name IN (N'char', N'varchar', N'nchar', N'nvarchar')
                     AND pair.right_type_name IN (N'char', N'varchar', N'nchar', N'nvarchar')
                    THEN N'string-convertible'
                WHEN pair.left_type_name IN (N'int', N'bigint', N'smallint', N'tinyint')
                     AND pair.right_type_name IN (N'int', N'bigint', N'smallint', N'tinyint')
                    THEN N'integer-convertible'
                ELSE N'conversion-risk'
            END AS type_alignment
        FROM #ColumnPairs AS pair
    ) AS classified
)
SELECT
    @SetOperator AS planned_set_operator,
    CASE
        WHEN order_issues > 0 OR hard_type_issues > 0 THEN N'not-ready'
        WHEN soft_type_issues > 0 THEN N'ready-after-explicit-cast'
        ELSE N'ready'
    END AS compatibility_state,
    order_issues,
    hard_type_issues,
    soft_type_issues,
    CASE
        WHEN order_issues > 0
            THEN N'Spaltenreihenfolge zuerst angleichen oder in beiden Teilabfragen explizit dieselbe Projektion schreiben.'
        WHEN hard_type_issues > 0
            THEN N'Konfliktspalten vor der Set-Operation mit CAST oder TRY_CONVERT vereinheitlichen.'
        WHEN soft_type_issues > 0
            THEN N'Explizite CASTs dokumentieren, damit keine stillen Typableitungen ueberraschen.'
        ELSE N'Die Projektionen sind fuer die gewaehlt beschriftete Set-Operation konsistent vorbereitet.'
    END AS next_step
FROM Risks;

IF @IncludeSampleData = 1
BEGIN
    SELECT
        ROW_NUMBER() OVER (ORDER BY left_row.CustomerCode) AS sample_row,
        left_row.CustomerCode,
        left_row.RegionCode,
        left_row.OrderAmount
    FROM #LeftProjection AS left_row
    ORDER BY
        left_row.CustomerCode;

    SELECT
        ROW_NUMBER() OVER (ORDER BY right_row.CustomerCode) AS sample_row,
        right_row.RegionCode,
        right_row.CustomerCode,
        right_row.OrderAmount
    FROM #RightProjection AS right_row
    ORDER BY
        right_row.CustomerCode;
END;
