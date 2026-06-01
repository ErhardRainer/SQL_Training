/*
    Zweck:
    Ermittelt fuer eine Tabelle in MS Fabric die tatsaechlich verwendete maximale
    Zeichenlaenge pro Zeichenspalte und berechnet optional eine auf die naechste
    10er-Stufe aufgerundete Zielbreite.

    Parameter:
    @SchemaName - Schema der Tabelle
    @TableName  - Tabellenname
    @Round      - 1 = auf naechste 10er-Stufe aufrunden, 0 = exakte Maximalbreite

    Hinweise:
    - Bewertet nur Zeichenspalten: char, varchar, nchar, nvarchar
    - LEN() misst Zeichen, nicht Bytes
    - Bei leerem String wird als empfohlene Breite mindestens 1 verwendet

    Beispiel:
    DECLARE @SchemaName VARCHAR(128) = 'tmp';
    DECLARE @TableName  VARCHAR(128) = 'FIBU_JE_SAP';
    DECLARE @Round      BIT          = 1;
*/

DECLARE @SchemaName VARCHAR(128) = 'dbo';
DECLARE @TableName  VARCHAR(128) = 'FIBU_Accounting_SAP';
DECLARE @Round      BIT          = 1;

IF NOT EXISTS
(
    SELECT 1
    FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_SCHEMA = @SchemaName
      AND TABLE_NAME = @TableName
)
BEGIN
    THROW 50000, 'Die angegebene Tabelle wurde nicht gefunden.', 1;
END;

DROP TABLE IF EXISTS #ColumnLengths;

CREATE TABLE #ColumnLengths
(
    OrdinalPosition        INT            NOT NULL,
    ColumnName             VARCHAR(128)   NOT NULL,
    DataType               VARCHAR(128)   NOT NULL,
    IsNullable             VARCHAR(3)     NOT NULL,
    DefinedLength          INT            NULL,
    ActualMaxLength        INT            NULL,
    SuggestedLength        INT            NULL,
    LengthDifference       INT            NULL,
    SuggestedTypeDefinition VARCHAR(4000) NULL
);

INSERT INTO #ColumnLengths
(
    OrdinalPosition,
    ColumnName,
    DataType,
    IsNullable,
    DefinedLength
)
SELECT
    c.ORDINAL_POSITION,
    c.COLUMN_NAME,
    c.DATA_TYPE,
    c.IS_NULLABLE,
    c.CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS AS c
WHERE c.TABLE_SCHEMA = @SchemaName
  AND c.TABLE_NAME = @TableName
  AND c.DATA_TYPE IN ('char', 'varchar', 'nchar', 'nvarchar');

IF NOT EXISTS (SELECT 1 FROM #ColumnLengths)
BEGIN
    THROW 50001, 'Die Tabelle enthaelt keine Zeichenspalten.', 1;
END;

DECLARE @QualifiedTableName VARCHAR(300);
DECLARE @Sql NVARCHAR(MAX);

SET @QualifiedTableName = QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName);

SELECT
    @Sql =
        STRING_AGG(
            CAST(
                'UPDATE r
SET r.ActualMaxLength = src.ActualMaxLength,
    r.SuggestedLength =
        CASE
            WHEN src.ActualMaxLength IS NULL THEN NULL
            WHEN src.ActualMaxLength = 0 THEN 1
            WHEN @Round = 1 THEN CEILING(src.ActualMaxLength / 10.0) * 10
            ELSE src.ActualMaxLength
        END
FROM #ColumnLengths AS r
CROSS JOIN
(
    SELECT MAX(LEN(' + QUOTENAME(ColumnName) + ')) AS ActualMaxLength
    FROM ' + @QualifiedTableName + '
) AS src
WHERE r.ColumnName = ''' + REPLACE(ColumnName, '''', '''''') + ''';'
                AS NVARCHAR(MAX)
            ),
            CHAR(10) + CHAR(10)
        )
FROM #ColumnLengths;

EXEC sp_executesql
    @Sql,
    N'@Round BIT',
    @Round = @Round;

UPDATE cl
SET
    cl.LengthDifference =
        CASE
            WHEN cl.DefinedLength IS NULL OR cl.ActualMaxLength IS NULL THEN NULL
            ELSE cl.DefinedLength - cl.ActualMaxLength
        END,
    cl.SuggestedTypeDefinition =
        CASE
            WHEN cl.SuggestedLength IS NULL THEN NULL
            ELSE CONCAT(
                '[',
                cl.ColumnName,
                '] [',
                cl.DataType,
                '](',
                CAST(cl.SuggestedLength AS VARCHAR(20)),
                ') ',
                CASE WHEN cl.IsNullable = 'NO' THEN 'NOT NULL' ELSE 'NULL' END
            )
        END
FROM #ColumnLengths AS cl;

SELECT
    @SchemaName                  AS [SchemaName],
    @TableName                   AS [TableName],
    @Round                       AS [RoundToNext10],
    cl.OrdinalPosition,
    cl.ColumnName,
    cl.DataType,
    cl.IsNullable,
    cl.DefinedLength,
    cl.ActualMaxLength,
    cl.SuggestedLength,
    cl.LengthDifference,
    cl.SuggestedTypeDefinition
FROM #ColumnLengths AS cl
ORDER BY cl.OrdinalPosition;
