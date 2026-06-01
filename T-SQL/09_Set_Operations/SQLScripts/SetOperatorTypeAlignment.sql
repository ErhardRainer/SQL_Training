/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "SetOperatorTypeAlignment.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "09_Set_Operations"

purpose: >
  Prueft vor Set-Operationen, ob fachlich gleiche Spalten beider
  Eingangsprojektionen auf gemeinsame Zieltypen ausgerichtet werden koennen
  und zeigt eine didaktische Alignmentschicht mit TRY_CONVERT.

parameters:
  - name: "@OnlyShowMismatches"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zeigt im Detailresultset nur Spalten mit Ausrichtungsbedarf oder Konvertierungsrisiko"
  - name: "@IncludeAlignedProjection"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = gibt eine beispielhafte, bereits typausgerichtete UNION ALL-Projektion aus"

result_sets:
  - name: "AlignmentSummary"
    description: "Verdichtete Aussage, ob die Beispielquellen fuer Set-Operationen typseitig vorbereitet sind"
  - name: "ColumnAlignmentDetails"
    description: "Spaltenweiser Vergleich von Ausgangstypen, Zieltyp und Konvertierbarkeit"
  - name: "AlignedProjectionPreview"
    description: "Optionale Beispielprojektion mit einheitlichen Zieltypen fuer beide Quellen"

dependencies:
  - "tempdb"
  - "TRY_CONVERT"
  - "UNION ALL"
  - "CASE"
  - "VALUES"
  - "DROP TABLE IF EXISTS"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/09_Set_Operations/SQLScripts/SetOperatorTypeAlignment.md"
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
    description: "Erstversion fuer Typ-Ausrichtungschecks vor Set-Operationen"

notes:
  - "Die Erstversion verwendet zwei lokale Temp-Quellen mit bewusst unterschiedlich typisierten Spalten"
  - "Die optionale Vorschau zeigt UNION ALL nur nach expliziter Ausrichtung auf gemeinsame Zieltypen"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @OnlyShowMismatches BIT = 0;
DECLARE @IncludeAlignedProjection BIT = 1;

IF @OnlyShowMismatches NOT IN (0, 1)
BEGIN
    THROW 50000, '@OnlyShowMismatches muss 0 oder 1 sein.', 1;
END;

IF @IncludeAlignedProjection NOT IN (0, 1)
BEGIN
    THROW 50001, '@IncludeAlignedProjection muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #CurrentOrders;
DROP TABLE IF EXISTS #ImportedOrders;

CREATE TABLE #CurrentOrders
(
    OrderID         INT             NOT NULL,
    CustomerCode    NVARCHAR(12)    NOT NULL,
    GrossAmount     DECIMAL(12,2)   NOT NULL,
    RequestedShip   DATE            NOT NULL,
    PriorityFlag    BIT             NOT NULL
);

CREATE TABLE #ImportedOrders
(
    OrderIDText         NVARCHAR(20)    NOT NULL,
    CustomerCodeText    VARCHAR(12)     NOT NULL,
    GrossAmountText     NVARCHAR(30)    NOT NULL,
    RequestedShipText   NVARCHAR(20)    NOT NULL,
    PriorityFlagText    CHAR(1)         NOT NULL
);

INSERT INTO #CurrentOrders
(
    OrderID,
    CustomerCode,
    GrossAmount,
    RequestedShip,
    PriorityFlag
)
VALUES
    (1001, N'CUST-ALPHA', 1250.50, DATEFROMPARTS(2026, 4, 18), 1),
    (1002, N'CUST-BRAVO', 980.00, DATEFROMPARTS(2026, 4, 19), 0),
    (1003, N'CUST-CHARLIE', 1430.75, DATEFROMPARTS(2026, 4, 21), 1);

INSERT INTO #ImportedOrders
(
    OrderIDText,
    CustomerCodeText,
    GrossAmountText,
    RequestedShipText,
    PriorityFlagText
)
VALUES
    (N'1001', N'CUST-ALPHA', N'1250.50', N'2026-04-18', N'1'),
    (N'1002', N'CUST-BRAVO', N'980.00', N'2026-04-19', N'0'),
    (N'100X', N'CUST-DELTA', N'1499,95', N'2026-04-22', N'Y');

;WITH ColumnAlignmentDetails AS
(
    SELECT
        alignment.LogicalColumn,
        alignment.CurrentSourceType,
        alignment.ImportSourceType,
        alignment.CanonicalTargetType,
        alignment.CurrentExample,
        alignment.ImportExample,
        alignment.ImportValueConvertible,
        CASE
            WHEN alignment.CurrentSourceType = alignment.CanonicalTargetType
             AND alignment.ImportValueConvertible = 1
                THEN CAST(1 AS BIT)
            ELSE CAST(0 AS BIT)
        END AS IsSetOperatorReady,
        CASE
            WHEN alignment.ImportValueConvertible = 0
                THEN N'conversion-risk'
            WHEN alignment.CurrentSourceType <> alignment.CanonicalTargetType
              OR alignment.ImportSourceType <> alignment.CanonicalTargetType
                THEN N'explicit-cast-recommended'
            ELSE N'aligned'
        END AS AlignmentStatus,
        alignment.RecommendedExpressionCurrent,
        alignment.RecommendedExpressionImport
    FROM
    (
        VALUES
            (
                N'OrderID',
                N'INT',
                N'NVARCHAR(20)',
                N'INT',
                N'1001',
                N'100X',
                CAST(CASE WHEN TRY_CONVERT(INT, N'100X') IS NOT NULL THEN 1 ELSE 0 END AS BIT),
                N'CAST(cur.OrderID AS INT)',
                N'TRY_CONVERT(INT, imp.OrderIDText)'
            ),
            (
                N'CustomerCode',
                N'NVARCHAR(12)',
                N'VARCHAR(12)',
                N'NVARCHAR(12)',
                N'CUST-ALPHA',
                N'CUST-DELTA',
                CAST(1 AS BIT),
                N'CAST(cur.CustomerCode AS NVARCHAR(12))',
                N'CAST(imp.CustomerCodeText AS NVARCHAR(12))'
            ),
            (
                N'GrossAmount',
                N'DECIMAL(12,2)',
                N'NVARCHAR(30)',
                N'DECIMAL(12,2)',
                N'1250.50',
                N'1499,95',
                CAST(CASE WHEN TRY_CONVERT(DECIMAL(12,2), N'1499,95') IS NOT NULL THEN 1 ELSE 0 END AS BIT),
                N'CAST(cur.GrossAmount AS DECIMAL(12,2))',
                N'TRY_CONVERT(DECIMAL(12,2), imp.GrossAmountText)'
            ),
            (
                N'RequestedShip',
                N'DATE',
                N'NVARCHAR(20)',
                N'DATE',
                N'2026-04-18',
                N'2026-04-22',
                CAST(CASE WHEN TRY_CONVERT(DATE, N'2026-04-22') IS NOT NULL THEN 1 ELSE 0 END AS BIT),
                N'CAST(cur.RequestedShip AS DATE)',
                N'TRY_CONVERT(DATE, imp.RequestedShipText)'
            ),
            (
                N'PriorityFlag',
                N'BIT',
                N'CHAR(1)',
                N'BIT',
                N'1',
                N'Y',
                CAST(CASE WHEN TRY_CONVERT(BIT, N'Y') IS NOT NULL THEN 1 ELSE 0 END AS BIT),
                N'CAST(cur.PriorityFlag AS BIT)',
                N'TRY_CONVERT(BIT, imp.PriorityFlagText)'
            )
    ) AS alignment
    (
        LogicalColumn,
        CurrentSourceType,
        ImportSourceType,
        CanonicalTargetType,
        CurrentExample,
        ImportExample,
        ImportValueConvertible,
        RecommendedExpressionCurrent,
        RecommendedExpressionImport
    )
),
AlignmentSummary AS
(
    SELECT
        COUNT(*) AS ComparedColumns,
        SUM(CASE WHEN detail.IsSetOperatorReady = 1 THEN 1 ELSE 0 END) AS ReadyColumns,
        SUM(CASE WHEN detail.AlignmentStatus = N'explicit-cast-recommended' THEN 1 ELSE 0 END) AS CastRecommendedColumns,
        SUM(CASE WHEN detail.AlignmentStatus = N'conversion-risk' THEN 1 ELSE 0 END) AS ConversionRiskColumns
    FROM ColumnAlignmentDetails AS detail
),
AlignedCurrent AS
(
    SELECT
        CAST(cur.OrderID AS INT) AS OrderID,
        CAST(cur.CustomerCode AS NVARCHAR(12)) AS CustomerCode,
        CAST(cur.GrossAmount AS DECIMAL(12,2)) AS GrossAmount,
        CAST(cur.RequestedShip AS DATE) AS RequestedShip,
        CAST(cur.PriorityFlag AS BIT) AS PriorityFlag,
        N'current' AS SourceSet
    FROM #CurrentOrders AS cur
),
AlignedImport AS
(
    SELECT
        TRY_CONVERT(INT, imp.OrderIDText) AS OrderID,
        CAST(imp.CustomerCodeText AS NVARCHAR(12)) AS CustomerCode,
        TRY_CONVERT(DECIMAL(12,2), imp.GrossAmountText) AS GrossAmount,
        TRY_CONVERT(DATE, imp.RequestedShipText) AS RequestedShip,
        TRY_CONVERT(BIT, imp.PriorityFlagText) AS PriorityFlag,
        N'import' AS SourceSet
    FROM #ImportedOrders AS imp
)
SELECT
    summary.ComparedColumns,
    summary.ReadyColumns,
    summary.CastRecommendedColumns,
    summary.ConversionRiskColumns,
    CASE
        WHEN summary.ConversionRiskColumns > 0
            THEN N'not-ready'
        WHEN summary.CastRecommendedColumns > 0
            THEN N'ready-after-explicit-alignment'
        ELSE N'ready'
    END AS SetOperationReadiness,
    CASE
        WHEN summary.ConversionRiskColumns > 0
            THEN N'Vor UNION, EXCEPT oder INTERSECT muessen fehlerhafte Importwerte bereinigt oder verworfen werden.'
        WHEN summary.CastRecommendedColumns > 0
            THEN N'Die Quellen sind fachlich kompatibel, sollten aber vor der Set-Operation auf gemeinsame Zieltypen projiziert werden.'
        ELSE N'Beide Quellen sind fuer die betrachteten Spalten bereits sauber ausgerichtet.'
    END AS RecommendedNextStep
FROM AlignmentSummary AS summary;

SELECT
    detail.LogicalColumn,
    detail.CurrentSourceType,
    detail.ImportSourceType,
    detail.CanonicalTargetType,
    detail.CurrentExample,
    detail.ImportExample,
    detail.ImportValueConvertible,
    detail.IsSetOperatorReady,
    detail.AlignmentStatus,
    detail.RecommendedExpressionCurrent,
    detail.RecommendedExpressionImport
FROM ColumnAlignmentDetails AS detail
WHERE @OnlyShowMismatches = 0
   OR detail.AlignmentStatus <> N'aligned'
ORDER BY
    detail.LogicalColumn;

IF @IncludeAlignedProjection = 1
BEGIN
    SELECT
        aligned.SourceSet,
        aligned.OrderID,
        aligned.CustomerCode,
        aligned.GrossAmount,
        aligned.RequestedShip,
        aligned.PriorityFlag,
        CASE
            WHEN aligned.OrderID IS NULL
              OR aligned.GrossAmount IS NULL
              OR aligned.RequestedShip IS NULL
              OR aligned.PriorityFlag IS NULL
                THEN N'requires-cleanup-before-set-operator'
            ELSE N'aligned-row'
        END AS RowAlignmentStatus
    FROM
    (
        SELECT
            currentSet.SourceSet,
            currentSet.OrderID,
            currentSet.CustomerCode,
            currentSet.GrossAmount,
            currentSet.RequestedShip,
            currentSet.PriorityFlag
        FROM AlignedCurrent AS currentSet

        UNION ALL

        SELECT
            importSet.SourceSet,
            importSet.OrderID,
            importSet.CustomerCode,
            importSet.GrossAmount,
            importSet.RequestedShip,
            importSet.PriorityFlag
        FROM AlignedImport AS importSet
    ) AS aligned
    ORDER BY
        aligned.SourceSet,
        aligned.CustomerCode,
        aligned.OrderID;
END;
