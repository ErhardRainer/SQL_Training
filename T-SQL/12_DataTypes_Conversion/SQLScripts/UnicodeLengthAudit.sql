/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "UnicodeLengthAudit.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "12_DataTypes_Conversion"

purpose: >
  Vergleicht pro Textspalte Zeichenlaenge, Bytebedarf und moegliche
  Unicode-Risiken. Das Skript unterscheidet dabei insbesondere zwischen
  non-Unicode-Spalten, UTF-8-varchar und nchar/nvarchar-Szenarien.

parameters:
  - name: "@SchemaName"
    sql_type: "sysname"
    direction: "IN"
    required: false
    description: "Optionaler Schemafilter; NULL = alle Schemas"
  - name: "@TableName"
    sql_type: "sysname"
    direction: "IN"
    required: false
    description: "Optionaler Tabellenfilter; NULL = alle Tabellen"
  - name: "@OnlyRiskColumns"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = nur Spalten mit mittleren oder hohen Unicode-Risiken ausgeben"

result_sets:
  - name: "UnicodeLengthAudit"
    description: "Spaltenweiser Vergleich von LEN-, DATALENGTH- und Unicode-Risikoindikatoren"

dependencies:
  - "sys.schemas"
  - "sys.tables"
  - "sys.columns"
  - "sys.types"
  - "LEN()"
  - "DATALENGTH()"
  - "PATINDEX()"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/12_DataTypes_Conversion/SQLScripts/UnicodeLengthAudit.md"
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
    date: "2026-04-16"
    user: "ER"
    description: "Erstversion des Unicode-Length-Audits fuer Textspalten"

notes:
  - "LEN() ignoriert abschliessende Leerzeichen, DATALENGTH() misst die tatsaechlich belegten Bytes"
  - "Nicht-ASCII-Werte werden heuristisch ueber Zeichen ausserhalb des Bereichs 32 bis 126 erkannt"
  - "Bei varchar/char mit UTF-8-Kollation ist Nicht-ASCII nicht automatisch ein Datenverlust-Risiko, wohl aber ein Bytebedarfs-Thema"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @SchemaName      SYSNAME = NULL;
DECLARE @TableName       SYSNAME = NULL;
DECLARE @OnlyRiskColumns BIT     = 0;

IF @SchemaName IS NOT NULL AND LTRIM(RTRIM(@SchemaName)) = ''
BEGIN
    THROW 50000, '@SchemaName darf nicht leer sein.', 1;
END;

IF @TableName IS NOT NULL AND LTRIM(RTRIM(@TableName)) = ''
BEGIN
    THROW 50001, '@TableName darf nicht leer sein.', 1;
END;

DROP TABLE IF EXISTS #TargetColumns;
DROP TABLE IF EXISTS #UnicodeAudit;

CREATE TABLE #TargetColumns
(
    SchemaName            SYSNAME        NOT NULL,
    TableName             SYSNAME        NOT NULL,
    ColumnName            SYSNAME        NOT NULL,
    DataType              SYSNAME        NOT NULL,
    TypeDefinition        NVARCHAR(128)  NOT NULL,
    CollationName         SYSNAME        NULL,
    IsUtf8Collation       BIT            NOT NULL,
    DeclaredLengthArgument INT           NULL,
    DeclaredLengthUnit     VARCHAR(20)   NOT NULL,
    DeclaredMaxBytes      INT            NULL
);

CREATE TABLE #UnicodeAudit
(
    SchemaName                   SYSNAME         NOT NULL,
    TableName                    SYSNAME         NOT NULL,
    ColumnName                   SYSNAME         NOT NULL,
    DataType                     SYSNAME         NOT NULL,
    TypeDefinition               NVARCHAR(128)   NOT NULL,
    CollationName                SYSNAME         NULL,
    IsUtf8Collation              BIT             NOT NULL,
    DeclaredLengthArgument       INT             NULL,
    DeclaredLengthUnit           VARCHAR(20)     NOT NULL,
    DeclaredMaxBytes             INT             NULL,
    NonNullValueCount            BIGINT          NOT NULL,
    MaxCharacterLength           INT             NULL,
    MaxStoredBytes               INT             NULL,
    MaxBytesPerCharacter         DECIMAL(19,2)   NULL,
    MaxByteMinusCharacterGap     INT             NULL,
    NonAsciiValueCount           BIGINT          NOT NULL,
    SupplementaryCharValueCount  BIGINT          NOT NULL,
    UnicodeRiskLevel             VARCHAR(20)     NULL,
    UnicodeRiskReason            NVARCHAR(400)   NULL
);

INSERT INTO #TargetColumns
(
    SchemaName,
    TableName,
    ColumnName,
    DataType,
    TypeDefinition,
    CollationName,
    IsUtf8Collation,
    DeclaredLengthArgument,
    DeclaredLengthUnit,
    DeclaredMaxBytes
)
SELECT
    s.name AS SchemaName,
    t.name AS TableName,
    c.name AS ColumnName,
    ty.name AS DataType,
    ty.name
        + N'('
        + CASE
            WHEN c.max_length = -1 THEN N'max'
            WHEN ty.name IN (N'nchar', N'nvarchar') THEN CONVERT(NVARCHAR(10), c.max_length / 2)
            ELSE CONVERT(NVARCHAR(10), c.max_length)
          END
        + N')' AS TypeDefinition,
    c.collation_name AS CollationName,
    CASE
        WHEN c.collation_name LIKE N'%UTF8' THEN 1
        ELSE 0
    END AS IsUtf8Collation,
    CASE
        WHEN c.max_length = -1 THEN NULL
        WHEN ty.name IN (N'nchar', N'nvarchar') THEN c.max_length / 2
        ELSE c.max_length
    END AS DeclaredLengthArgument,
    CASE
        WHEN ty.name IN (N'nchar', N'nvarchar') THEN 'characters'
        ELSE 'bytes'
    END AS DeclaredLengthUnit,
    CASE
        WHEN c.max_length = -1 THEN NULL
        ELSE c.max_length
    END AS DeclaredMaxBytes
FROM sys.tables AS t
INNER JOIN sys.schemas AS s
    ON s.schema_id = t.schema_id
INNER JOIN sys.columns AS c
    ON c.object_id = t.object_id
INNER JOIN sys.types AS ty
    ON ty.user_type_id = c.user_type_id
WHERE t.is_ms_shipped = 0
  AND ty.name IN (N'char', N'varchar', N'nchar', N'nvarchar')
  AND (@SchemaName IS NULL OR s.name = @SchemaName)
  AND (@TableName  IS NULL OR t.name = @TableName);

IF NOT EXISTS (SELECT 1 FROM #TargetColumns)
BEGIN
    THROW 50002, 'Keine passenden Textspalten fuer den angegebenen Filter gefunden.', 1;
END;

DECLARE
    @CurrentSchemaName      SYSNAME,
    @CurrentTableName       SYSNAME,
    @CurrentColumnName      SYSNAME,
    @CurrentDataType        SYSNAME,
    @CurrentTypeDefinition  NVARCHAR(128),
    @CurrentCollationName   SYSNAME,
    @CurrentIsUtf8Collation BIT,
    @CurrentLengthArgument  INT,
    @CurrentLengthUnit      VARCHAR(20),
    @CurrentMaxBytes        INT,
    @Sql                    NVARCHAR(MAX);

DECLARE column_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT
    tc.SchemaName,
    tc.TableName,
    tc.ColumnName,
    tc.DataType,
    tc.TypeDefinition,
    tc.CollationName,
    tc.IsUtf8Collation,
    tc.DeclaredLengthArgument,
    tc.DeclaredLengthUnit,
    tc.DeclaredMaxBytes
FROM #TargetColumns AS tc
ORDER BY
    tc.SchemaName,
    tc.TableName,
    tc.ColumnName;

OPEN column_cursor;

FETCH NEXT FROM column_cursor
INTO
    @CurrentSchemaName,
    @CurrentTableName,
    @CurrentColumnName,
    @CurrentDataType,
    @CurrentTypeDefinition,
    @CurrentCollationName,
    @CurrentIsUtf8Collation,
    @CurrentLengthArgument,
    @CurrentLengthUnit,
    @CurrentMaxBytes;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @Sql =
        N'
INSERT INTO #UnicodeAudit
(
    SchemaName,
    TableName,
    ColumnName,
    DataType,
    TypeDefinition,
    CollationName,
    IsUtf8Collation,
    DeclaredLengthArgument,
    DeclaredLengthUnit,
    DeclaredMaxBytes,
    NonNullValueCount,
    MaxCharacterLength,
    MaxStoredBytes,
    MaxBytesPerCharacter,
    MaxByteMinusCharacterGap,
    NonAsciiValueCount,
    SupplementaryCharValueCount,
    UnicodeRiskLevel,
    UnicodeRiskReason
)
SELECT
    @SchemaNameParam,
    @TableNameParam,
    @ColumnNameParam,
    @DataTypeParam,
    @TypeDefinitionParam,
    @CollationNameParam,
    @IsUtf8CollationParam,
    @DeclaredLengthArgumentParam,
    @DeclaredLengthUnitParam,
    @DeclaredMaxBytesParam,
    COALESCE(SUM(CASE WHEN src.' + QUOTENAME(@CurrentColumnName) + N' IS NOT NULL THEN CONVERT(BIGINT, 1) ELSE CONVERT(BIGINT, 0) END), 0),
    MAX(CASE WHEN src.' + QUOTENAME(@CurrentColumnName) + N' IS NULL THEN NULL ELSE LEN(CONVERT(NVARCHAR(MAX), src.' + QUOTENAME(@CurrentColumnName) + N')) END),
    MAX(DATALENGTH(src.' + QUOTENAME(@CurrentColumnName) + N')),
    MAX
    (
        CASE
            WHEN src.' + QUOTENAME(@CurrentColumnName) + N' IS NULL THEN NULL
            WHEN LEN(CONVERT(NVARCHAR(MAX), src.' + QUOTENAME(@CurrentColumnName) + N')) = 0 THEN NULL
            ELSE CONVERT(DECIMAL(19,2), 1.0 * DATALENGTH(src.' + QUOTENAME(@CurrentColumnName) + N') / NULLIF(LEN(CONVERT(NVARCHAR(MAX), src.' + QUOTENAME(@CurrentColumnName) + N')), 0))
        END
    ),
    MAX
    (
        CASE
            WHEN src.' + QUOTENAME(@CurrentColumnName) + N' IS NULL THEN NULL
            ELSE DATALENGTH(src.' + QUOTENAME(@CurrentColumnName) + N') - LEN(CONVERT(NVARCHAR(MAX), src.' + QUOTENAME(@CurrentColumnName) + N'))
        END
    ),
    COALESCE
    (
        SUM
        (
            CASE
                WHEN src.' + QUOTENAME(@CurrentColumnName) + N' IS NOT NULL
                 AND PATINDEX(N''%[^ -~]%'', CONVERT(NVARCHAR(MAX), src.' + QUOTENAME(@CurrentColumnName) + N') COLLATE Latin1_General_100_BIN2) > 0
                    THEN CONVERT(BIGINT, 1)
                ELSE CONVERT(BIGINT, 0)
            END
        ),
        0
    ),
    COALESCE
    (
        SUM
        (
            CASE
                WHEN src.' + QUOTENAME(@CurrentColumnName) + N' IS NOT NULL
                 AND DATALENGTH(CONVERT(NVARCHAR(MAX), src.' + QUOTENAME(@CurrentColumnName) + N')) > LEN(CONVERT(NVARCHAR(MAX), src.' + QUOTENAME(@CurrentColumnName) + N')) * 2
                    THEN CONVERT(BIGINT, 1)
                ELSE CONVERT(BIGINT, 0)
            END
        ),
        0
    ),
    NULL,
    NULL
FROM ' + QUOTENAME(@CurrentSchemaName) + N'.' + QUOTENAME(@CurrentTableName) + N' AS src;';

    EXEC sys.sp_executesql
        @Sql,
        N'@SchemaNameParam SYSNAME,
          @TableNameParam SYSNAME,
          @ColumnNameParam SYSNAME,
          @DataTypeParam SYSNAME,
          @TypeDefinitionParam NVARCHAR(128),
          @CollationNameParam SYSNAME,
          @IsUtf8CollationParam BIT,
          @DeclaredLengthArgumentParam INT,
          @DeclaredLengthUnitParam VARCHAR(20),
          @DeclaredMaxBytesParam INT',
        @SchemaNameParam = @CurrentSchemaName,
        @TableNameParam = @CurrentTableName,
        @ColumnNameParam = @CurrentColumnName,
        @DataTypeParam = @CurrentDataType,
        @TypeDefinitionParam = @CurrentTypeDefinition,
        @CollationNameParam = @CurrentCollationName,
        @IsUtf8CollationParam = @CurrentIsUtf8Collation,
        @DeclaredLengthArgumentParam = @CurrentLengthArgument,
        @DeclaredLengthUnitParam = @CurrentLengthUnit,
        @DeclaredMaxBytesParam = @CurrentMaxBytes;

    FETCH NEXT FROM column_cursor
    INTO
        @CurrentSchemaName,
        @CurrentTableName,
        @CurrentColumnName,
        @CurrentDataType,
        @CurrentTypeDefinition,
        @CurrentCollationName,
        @CurrentIsUtf8Collation,
        @CurrentLengthArgument,
        @CurrentLengthUnit,
        @CurrentMaxBytes;
END;

CLOSE column_cursor;
DEALLOCATE column_cursor;

UPDATE ua
SET
    ua.UnicodeRiskLevel =
        CASE
            WHEN ua.NonNullValueCount = 0 THEN 'info'
            WHEN ua.DataType IN ('char', 'varchar')
             AND ua.NonAsciiValueCount > 0
             AND ua.IsUtf8Collation = 0 THEN 'high'
            WHEN ua.DataType IN ('nchar', 'nvarchar')
             AND ua.SupplementaryCharValueCount > 0 THEN 'medium'
            WHEN ua.DataType IN ('char', 'varchar')
             AND ua.NonAsciiValueCount > 0
             AND ua.IsUtf8Collation = 1 THEN 'medium'
            ELSE 'low'
        END,
    ua.UnicodeRiskReason =
        CASE
            WHEN ua.NonNullValueCount = 0 THEN N'Spalte enthaelt im aktuellen Datenbestand nur NULL-Werte.'
            WHEN ua.DataType IN ('char', 'varchar')
             AND ua.NonAsciiValueCount > 0
             AND ua.IsUtf8Collation = 0 THEN N'Nicht-Unicode-Spalte mit Nicht-ASCII-Inhalten; Speicherung ist codepage- bzw. kollationsabhaengig.'
            WHEN ua.DataType IN ('char', 'varchar')
             AND ua.NonAsciiValueCount > 0
             AND ua.IsUtf8Collation = 1 THEN N'UTF-8-varchar mit Nicht-ASCII-Inhalten; kein klassischer Unicode-Verlust, aber variabler Bytebedarf pro Zeichen.'
            WHEN ua.DataType IN ('nchar', 'nvarchar')
             AND ua.SupplementaryCharValueCount > 0 THEN N'Supplementary Unicode-Zeichen erkannt; einzelne Zeichen koennen mehr als 2 Bytes in UTF-16 benoetigen.'
            WHEN ua.DataType IN ('nchar', 'nvarchar') THEN N'Unicode-Spalte ohne auffaellige Supplementary-Zeichen im aktuellen Datenbestand.'
            ELSE N'Keine offensichtlichen Unicode-Risiken im aktuellen Datenbestand.'
        END
FROM #UnicodeAudit AS ua;

SELECT
    ua.SchemaName,
    ua.TableName,
    ua.ColumnName,
    ua.TypeDefinition,
    ua.CollationName,
    ua.IsUtf8Collation,
    ua.DeclaredLengthArgument,
    ua.DeclaredLengthUnit,
    ua.DeclaredMaxBytes,
    ua.NonNullValueCount,
    ua.MaxCharacterLength,
    ua.MaxStoredBytes,
    ua.MaxBytesPerCharacter,
    ua.MaxByteMinusCharacterGap,
    ua.NonAsciiValueCount,
    ua.SupplementaryCharValueCount,
    ua.UnicodeRiskLevel,
    ua.UnicodeRiskReason
FROM #UnicodeAudit AS ua
WHERE @OnlyRiskColumns = 0
   OR ua.UnicodeRiskLevel IN ('high', 'medium')
ORDER BY
    CASE ua.UnicodeRiskLevel
        WHEN 'high' THEN 1
        WHEN 'medium' THEN 2
        WHEN 'info' THEN 3
        ELSE 4
    END,
    ua.SchemaName,
    ua.TableName,
    ua.ColumnName;
