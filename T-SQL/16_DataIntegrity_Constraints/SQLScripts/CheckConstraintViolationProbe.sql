/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "CheckConstraintViolationProbe.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "16_DataIntegrity_Constraints"

purpose: >
  Bewertet einen didaktischen Staging-Datensatz gegen geplante CHECK-Constraint-
  Regeln, zeigt konkrete Verletzungen pro Zeile und verdichtet, welche
  Wertebereiche vor dem Aktivieren eines Constraints bereinigt werden sollten.

parameters:
  - name: "@OnlyViolations"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 zeigt nur verletzende Regelzeilen; 0 zeigt alle geprueften Regelbewertungen."
  - name: "@SeverityFloor"
    sql_type: "TINYINT"
    direction: "IN"
    required: false
    description: "Mindestschwere 1 bis 3 fuer die Ausgabe geplanter Regeln und Verletzungen."
  - name: "@ConstraintNamePattern"
    sql_type: "NVARCHAR(128)"
    direction: "IN"
    required: false
    description: "Optionales LIKE-Muster zur Auswahl bestimmter geplanter CHECK-Constraint-Namen."

result_sets:
  - name: "ViolationDetails"
    description: "Detailansicht je Datensatz und geplanter Regel mit Ist-Wert, Sollbereich und Verletzungsflag."
  - name: "ConstraintReadiness"
    description: "Verdichtete Bewertung pro geplanter CHECK-Regel mit Trefferzahl, Risikostufe und Beispielschluesseln."
  - name: "ColumnHotspots"
    description: "Spaltenbezogene Hotspot-Sicht mit beobachteten Bereichen und zugeordneten Regelverletzungen."

dependencies:
  - "tempdb"
  - "DROP TABLE IF EXISTS"
  - "STRING_AGG()"
  - "CASE"
  - "TRY_CONVERT()"
  - "LIKE"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/16_DataIntegrity_Constraints/SQLScripts/CheckConstraintViolationProbe.md"
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
    description: "Erstversion eines didaktischen Probeskripts fuer geplante CHECK-Constraints."

notes:
  - "Die Erstversion verwendet ausschliesslich einen lokalen Demo-Datensatz in Temp-Tabellen."
  - "Geplante Regeln werden explizit als didaktische Kandidaten modelliert und nicht aus vorhandenen Metadaten gelesen."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @OnlyViolations BIT = 1;
DECLARE @SeverityFloor TINYINT = 1;
DECLARE @ConstraintNamePattern NVARCHAR(128) = NULL;

IF @OnlyViolations NOT IN (0, 1)
BEGIN
    THROW 50000, '@OnlyViolations muss 0 oder 1 sein.', 1;
END;

IF @SeverityFloor NOT BETWEEN 1 AND 3
BEGIN
    THROW 50001, '@SeverityFloor muss zwischen 1 und 3 liegen.', 1;
END;

DROP TABLE IF EXISTS #StagingOrderLine;
CREATE TABLE #StagingOrderLine
(
    OrderLineID INT NOT NULL PRIMARY KEY,
    CustomerID INT NOT NULL,
    Quantity INT NOT NULL,
    UnitPrice DECIMAL(10, 2) NOT NULL,
    DiscountPct DECIMAL(5, 4) NOT NULL,
    CurrencyCode CHAR(3) NOT NULL,
    OrderDate DATE NOT NULL,
    ShipDate DATE NULL,
    FulfillmentStatus NVARCHAR(20) NOT NULL
);

INSERT INTO #StagingOrderLine
(
    OrderLineID,
    CustomerID,
    Quantity,
    UnitPrice,
    DiscountPct,
    CurrencyCode,
    OrderDate,
    ShipDate,
    FulfillmentStatus
)
VALUES
    (1001, 501, 4, 125.00, 0.0500, 'EUR', '2026-04-01', '2026-04-03', N'Shipped'),
    (1002, 501, 0, 85.00, 0.1000, 'EUR', '2026-04-01', NULL, N'Open'),
    (1003, 502, 8, -12.50, 0.0000, 'EUR', '2026-04-02', NULL, N'Open'),
    (1004, 503, 12, 199.00, 0.5500, 'USD', '2026-04-03', '2026-04-02', N'Shipped'),
    (1005, 504, 3, 89.90, 0.1500, 'EU1', '2026-04-04', NULL, N'Open'),
    (1006, 505, 2, 45.00, 0.2000, 'CHF', '2026-04-04', NULL, N'Shipped'),
    (1007, 506, 600, 12.00, 0.0000, 'GBP', '2026-04-05', NULL, N'Open'),
    (1008, 507, 5, 99999.99, 0.0200, 'USD', '2026-04-05', NULL, N'Open'),
    (1009, 508, 9, 249.00, 0.3500, 'JPY', '2026-04-06', '2026-04-10', N'Shipped'),
    (1010, 509, 1, 15.50, 0.0000, 'USD', '2026-04-07', NULL, N'Open');

DROP TABLE IF EXISTS #PlannedChecks;
CREATE TABLE #PlannedChecks
(
    ConstraintName SYSNAME NOT NULL PRIMARY KEY,
    SeverityRank TINYINT NOT NULL,
    TargetColumn SYSNAME NOT NULL,
    PlannedPredicate NVARCHAR(300) NOT NULL,
    RuleDescription NVARCHAR(300) NOT NULL
);

INSERT INTO #PlannedChecks
(
    ConstraintName,
    SeverityRank,
    TargetColumn,
    PlannedPredicate,
    RuleDescription
)
VALUES
    (N'CK_OrderLine_Quantity_Range', 3, N'Quantity', N'Quantity BETWEEN 1 AND 500', N'Menge muss im didaktischen Zielbereich zwischen 1 und 500 liegen.'),
    (N'CK_OrderLine_UnitPrice_Range', 3, N'UnitPrice', N'UnitPrice BETWEEN 0.00 AND 10000.00', N'Einzelpreis darf weder negativ noch unplausibel hoch sein.'),
    (N'CK_OrderLine_Discount_Range', 2, N'DiscountPct', N'DiscountPct BETWEEN 0.00 AND 0.40', N'Rabatt bleibt im freigegebenen Korridor bis 40 Prozent.'),
    (N'CK_OrderLine_CurrencyCode_Format', 2, N'CurrencyCode', N'CurrencyCode LIKE ''[A-Z][A-Z][A-Z]''', N'Waehrungscode soll aus genau drei Grossbuchstaben bestehen.'),
    (N'CK_OrderLine_ShipDate_NotBeforeOrderDate', 3, N'ShipDate', N'ShipDate IS NULL OR ShipDate >= OrderDate', N'Versanddatum darf nicht vor dem Bestelldatum liegen.'),
    (N'CK_OrderLine_StatusShipDate_Consistency', 2, N'FulfillmentStatus', N'FulfillmentStatus <> ''Shipped'' OR ShipDate IS NOT NULL', N'Fuer den Status Shipped muss ein Versanddatum vorhanden sein.');

DROP TABLE IF EXISTS #RuleEvaluation;
WITH RuleEvaluation AS
(
    SELECT
        s.OrderLineID,
        s.CustomerID,
        s.Quantity,
        s.UnitPrice,
        s.DiscountPct,
        s.CurrencyCode,
        s.OrderDate,
        s.ShipDate,
        s.FulfillmentStatus,
        pc.ConstraintName,
        pc.SeverityRank,
        pc.TargetColumn,
        pc.PlannedPredicate,
        pc.RuleDescription,
        CAST(CASE WHEN s.Quantity BETWEEN 1 AND 500 THEN 0 ELSE 1 END AS BIT) AS IsViolation,
        CAST(s.Quantity AS NVARCHAR(100)) AS ActualValue,
        N'1..500' AS ExpectedRange,
        CASE
            WHEN s.Quantity < 1 THEN N'Wert liegt unter dem Mindestbereich.'
            WHEN s.Quantity > 500 THEN N'Wert liegt ueber dem didaktischen Batch-Limit.'
            ELSE N'Regel erfuellt.'
        END AS DiagnosticNote
    FROM #StagingOrderLine AS s
    INNER JOIN #PlannedChecks AS pc
        ON pc.ConstraintName = N'CK_OrderLine_Quantity_Range'

    UNION ALL

    SELECT
        s.OrderLineID,
        s.CustomerID,
        s.Quantity,
        s.UnitPrice,
        s.DiscountPct,
        s.CurrencyCode,
        s.OrderDate,
        s.ShipDate,
        s.FulfillmentStatus,
        pc.ConstraintName,
        pc.SeverityRank,
        pc.TargetColumn,
        pc.PlannedPredicate,
        pc.RuleDescription,
        CAST(CASE WHEN s.UnitPrice BETWEEN 0.00 AND 10000.00 THEN 0 ELSE 1 END AS BIT) AS IsViolation,
        CONVERT(NVARCHAR(100), s.UnitPrice) AS ActualValue,
        N'0.00..10000.00' AS ExpectedRange,
        CASE
            WHEN s.UnitPrice < 0 THEN N'Negativer Preis wuerde den Constraint sofort verletzen.'
            WHEN s.UnitPrice > 10000.00 THEN N'Preis liegt ueber dem geplanten Oberlimit.'
            ELSE N'Regel erfuellt.'
        END AS DiagnosticNote
    FROM #StagingOrderLine AS s
    INNER JOIN #PlannedChecks AS pc
        ON pc.ConstraintName = N'CK_OrderLine_UnitPrice_Range'

    UNION ALL

    SELECT
        s.OrderLineID,
        s.CustomerID,
        s.Quantity,
        s.UnitPrice,
        s.DiscountPct,
        s.CurrencyCode,
        s.OrderDate,
        s.ShipDate,
        s.FulfillmentStatus,
        pc.ConstraintName,
        pc.SeverityRank,
        pc.TargetColumn,
        pc.PlannedPredicate,
        pc.RuleDescription,
        CAST(CASE WHEN s.DiscountPct BETWEEN 0.00 AND 0.40 THEN 0 ELSE 1 END AS BIT) AS IsViolation,
        CONVERT(NVARCHAR(100), s.DiscountPct) AS ActualValue,
        N'0.00..0.40' AS ExpectedRange,
        CASE
            WHEN s.DiscountPct < 0 THEN N'Rabatt ist negativ und damit fachlich ungueltig.'
            WHEN s.DiscountPct > 0.40 THEN N'Rabatt uebersteigt den vorgesehenen Freigabekorridor.'
            ELSE N'Regel erfuellt.'
        END AS DiagnosticNote
    FROM #StagingOrderLine AS s
    INNER JOIN #PlannedChecks AS pc
        ON pc.ConstraintName = N'CK_OrderLine_Discount_Range'

    UNION ALL

    SELECT
        s.OrderLineID,
        s.CustomerID,
        s.Quantity,
        s.UnitPrice,
        s.DiscountPct,
        s.CurrencyCode,
        s.OrderDate,
        s.ShipDate,
        s.FulfillmentStatus,
        pc.ConstraintName,
        pc.SeverityRank,
        pc.TargetColumn,
        pc.PlannedPredicate,
        pc.RuleDescription,
        CAST(CASE WHEN s.CurrencyCode LIKE '[A-Z][A-Z][A-Z]' THEN 0 ELSE 1 END AS BIT) AS IsViolation,
        s.CurrencyCode AS ActualValue,
        N'[A-Z][A-Z][A-Z]' AS ExpectedRange,
        CASE
            WHEN TRY_CONVERT(INT, RIGHT(s.CurrencyCode, 1)) IS NOT NULL THEN N'Der Code enthaelt numerische Zeichen.'
            WHEN s.CurrencyCode COLLATE Latin1_General_BIN2 <> UPPER(s.CurrencyCode) COLLATE Latin1_General_BIN2 THEN N'Der Code ist nicht komplett in Grossbuchstaben.'
            ELSE N'Regel erfuellt.'
        END AS DiagnosticNote
    FROM #StagingOrderLine AS s
    INNER JOIN #PlannedChecks AS pc
        ON pc.ConstraintName = N'CK_OrderLine_CurrencyCode_Format'

    UNION ALL

    SELECT
        s.OrderLineID,
        s.CustomerID,
        s.Quantity,
        s.UnitPrice,
        s.DiscountPct,
        s.CurrencyCode,
        s.OrderDate,
        s.ShipDate,
        s.FulfillmentStatus,
        pc.ConstraintName,
        pc.SeverityRank,
        pc.TargetColumn,
        pc.PlannedPredicate,
        pc.RuleDescription,
        CAST(CASE WHEN s.ShipDate IS NULL OR s.ShipDate >= s.OrderDate THEN 0 ELSE 1 END AS BIT) AS IsViolation,
        COALESCE(CONVERT(NVARCHAR(30), s.ShipDate, 23), N'NULL') AS ActualValue,
        N'ShipDate >= OrderDate oder NULL' AS ExpectedRange,
        CASE
            WHEN s.ShipDate IS NOT NULL AND s.ShipDate < s.OrderDate THEN N'Versanddatum liegt vor dem Bestelldatum.'
            ELSE N'Regel erfuellt.'
        END AS DiagnosticNote
    FROM #StagingOrderLine AS s
    INNER JOIN #PlannedChecks AS pc
        ON pc.ConstraintName = N'CK_OrderLine_ShipDate_NotBeforeOrderDate'

    UNION ALL

    SELECT
        s.OrderLineID,
        s.CustomerID,
        s.Quantity,
        s.UnitPrice,
        s.DiscountPct,
        s.CurrencyCode,
        s.OrderDate,
        s.ShipDate,
        s.FulfillmentStatus,
        pc.ConstraintName,
        pc.SeverityRank,
        pc.TargetColumn,
        pc.PlannedPredicate,
        pc.RuleDescription,
        CAST(CASE WHEN s.FulfillmentStatus <> N'Shipped' OR s.ShipDate IS NOT NULL THEN 0 ELSE 1 END AS BIT) AS IsViolation,
        s.FulfillmentStatus + N' / ' + COALESCE(CONVERT(NVARCHAR(30), s.ShipDate, 23), N'NULL') AS ActualValue,
        N'Shipped setzt ShipDate voraus' AS ExpectedRange,
        CASE
            WHEN s.FulfillmentStatus = N'Shipped' AND s.ShipDate IS NULL THEN N'Status Shipped ohne Versanddatum.'
            ELSE N'Regel erfuellt.'
        END AS DiagnosticNote
    FROM #StagingOrderLine AS s
    INNER JOIN #PlannedChecks AS pc
        ON pc.ConstraintName = N'CK_OrderLine_StatusShipDate_Consistency'
)
SELECT
    re.OrderLineID,
    re.CustomerID,
    re.Quantity,
    re.UnitPrice,
    re.DiscountPct,
    re.CurrencyCode,
    re.OrderDate,
    re.ShipDate,
    re.FulfillmentStatus,
    re.ConstraintName,
    re.SeverityRank,
    re.TargetColumn,
    re.PlannedPredicate,
    re.RuleDescription,
    re.IsViolation,
    re.ActualValue,
    re.ExpectedRange,
    re.DiagnosticNote
INTO #RuleEvaluation
FROM RuleEvaluation AS re
WHERE re.SeverityRank >= @SeverityFloor
  AND (@ConstraintNamePattern IS NULL OR re.ConstraintName LIKE @ConstraintNamePattern);

SELECT
    re.OrderLineID,
    re.CustomerID,
    re.ConstraintName,
    re.SeverityRank,
    re.TargetColumn,
    re.PlannedPredicate,
    re.ActualValue,
    re.ExpectedRange,
    re.DiagnosticNote,
    re.Quantity,
    re.UnitPrice,
    re.DiscountPct,
    re.CurrencyCode,
    re.OrderDate,
    re.ShipDate,
    re.FulfillmentStatus
FROM #RuleEvaluation AS re
WHERE @OnlyViolations = 0
   OR re.IsViolation = 1
ORDER BY
    re.IsViolation DESC,
    re.SeverityRank DESC,
    re.ConstraintName,
    re.OrderLineID;

;WITH ConstraintSummary AS
(
    SELECT
        re.ConstraintName,
        MAX(re.SeverityRank) AS SeverityRank,
        MAX(re.TargetColumn) AS TargetColumn,
        MAX(re.PlannedPredicate) AS PlannedPredicate,
        COUNT(*) AS EvaluatedRows,
        SUM(CASE WHEN re.IsViolation = 1 THEN 1 ELSE 0 END) AS ViolatingRows
    FROM #RuleEvaluation AS re
    GROUP BY
        re.ConstraintName
)
SELECT
    cs.ConstraintName,
    cs.SeverityRank,
    cs.TargetColumn,
    cs.PlannedPredicate,
    cs.EvaluatedRows,
    cs.ViolatingRows,
    CAST(100.0 * cs.ViolatingRows / NULLIF(cs.EvaluatedRows, 0) AS DECIMAL(5, 2)) AS ViolationPct,
    CASE
        WHEN cs.ViolatingRows = 0 THEN N'ready_for_enablement'
        WHEN cs.ViolatingRows <= 2 THEN N'cleanup_small_batch'
        ELSE N'cleanup_required'
    END AS ReadinessStatus,
    (
        SELECT STRING_AGG(CONVERT(NVARCHAR(20), sample.OrderLineID), N', ')
        FROM
        (
            SELECT TOP (3)
                re2.OrderLineID
            FROM #RuleEvaluation AS re2
            WHERE re2.ConstraintName = cs.ConstraintName
              AND re2.IsViolation = 1
            ORDER BY re2.OrderLineID
        ) AS sample
    ) AS SampleViolatingOrderLines
FROM ConstraintSummary AS cs
ORDER BY
    cs.ViolatingRows DESC,
    cs.SeverityRank DESC,
    cs.ConstraintName;

;WITH HotspotBase AS
(
    SELECT
        pc.TargetColumn,
        pc.ConstraintName,
        s.OrderLineID,
        CAST(CASE
            WHEN pc.TargetColumn = N'Quantity' THEN CONVERT(NVARCHAR(100), s.Quantity)
            WHEN pc.TargetColumn = N'UnitPrice' THEN CONVERT(NVARCHAR(100), s.UnitPrice)
            WHEN pc.TargetColumn = N'DiscountPct' THEN CONVERT(NVARCHAR(100), s.DiscountPct)
            WHEN pc.TargetColumn = N'CurrencyCode' THEN s.CurrencyCode
            WHEN pc.TargetColumn = N'ShipDate' THEN COALESCE(CONVERT(NVARCHAR(30), s.ShipDate, 23), N'NULL')
            WHEN pc.TargetColumn = N'FulfillmentStatus' THEN s.FulfillmentStatus
        END AS NVARCHAR(100)) AS ObservedValue,
        re.IsViolation
    FROM #PlannedChecks AS pc
    INNER JOIN #RuleEvaluation AS re
        ON re.ConstraintName = pc.ConstraintName
    INNER JOIN #StagingOrderLine AS s
        ON s.OrderLineID = re.OrderLineID
)
SELECT
    hb.TargetColumn,
    COUNT(*) AS Evaluations,
    SUM(CASE WHEN hb.IsViolation = 1 THEN 1 ELSE 0 END) AS Violations,
    MIN(hb.ObservedValue) AS MinObservedValue,
    MAX(hb.ObservedValue) AS MaxObservedValue,
    (
        SELECT STRING_AGG(example.ConstraintName, N', ')
        FROM
        (
            SELECT DISTINCT
                hb2.ConstraintName
            FROM HotspotBase AS hb2
            WHERE hb2.TargetColumn = hb.TargetColumn
              AND hb2.IsViolation = 1
        ) AS example
    ) AS RelatedConstraints
FROM HotspotBase AS hb
GROUP BY
    hb.TargetColumn
ORDER BY
    Violations DESC,
    hb.TargetColumn;

DROP TABLE IF EXISTS #RuleEvaluation;
DROP TABLE IF EXISTS #PlannedChecks;
DROP TABLE IF EXISTS #StagingOrderLine;
