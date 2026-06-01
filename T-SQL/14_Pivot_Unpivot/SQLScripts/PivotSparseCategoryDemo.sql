/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "PivotSparseCategoryDemo.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "14_Pivot_Unpivot"

purpose: >
  Zeigt den Umgang mit duenn besetzten Pivot-Kategorien und fehlenden
  Spaltenwerten. Das Skript kombiniert eine kleine Demo-Quelle mit einer
  freigegebenen Kategorienachse, einer Densifizierung pro Team und Queue
  sowie einer stabilen Pivot-Ausgabe mit explizit als 0.00 sichtbaren
  Luecken.

parameters:
  - name: "@SnapshotMonth"
    sql_type: "tinyint"
    direction: "IN"
    required: false
    description: "Filtert die Demo-Quelle auf einen Berichtsmonat fuer die Sparse-Pivot-Demo."
  - name: "@OnlyRowsWithGaps"
    sql_type: "bit"
    direction: "IN"
    required: false
    description: "Beschraenkt die finale Matrix auf Team-Queue-Kombinationen mit mindestens einer unbelegten Kategorie."

result_sets:
  - name: "SparseSourcePreview"
    description: "Zeigt die gefilterte Demo-Quelle fuer den gewaehlten Berichtsmonat."
  - name: "ApprovedCategoryPreview"
    description: "Listet die freigegebenen Pivot-Kategorien in stabiler Reihenfolge."
  - name: "SparseCoverageReview"
    description: "Macht pro Team und Queue sichtbar, wie viele Kategorien belegt oder unbelegt sind."
  - name: "SparsePivotMatrix"
    description: "Gibt die finale Pivot-Matrix mit festen Kategorien und als 0.00 ausgegebenen Luecken zurueck."

dependencies:
  - "PIVOT"
  - "CTEs"
  - "temporary tables"
  - "THROW"
  - "COALESCE"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/14_Pivot_Unpivot/SQLScripts/PivotSparseCategoryDemo.md"
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
    description: "Erstversion einer didaktischen Sparse-Pivot-Demo mit Kategorienachse und Gap-Review."

notes:
  - "Die Erstversion arbeitet ausschliesslich mit temporaeren Demo-Tabellen."
  - "Fehlende Kategorien pro Team und Queue werden ueber eine explizite Kategorienachse als 0.00 sichtbar gemacht."
  - "Die finale Matrix kann optional auf Zeilen mit echten Kategorieluecken eingeschraenkt werden."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @SnapshotMonth TINYINT = 4;
DECLARE @OnlyRowsWithGaps BIT = 0;

DROP TABLE IF EXISTS #SparsePivotSource;
DROP TABLE IF EXISTS #CategoryCatalog;

CREATE TABLE #SparsePivotSource
(
    SnapshotDate    DATE            NOT NULL,
    OwnerTeam       VARCHAR(20)     NOT NULL,
    QueueName       VARCHAR(20)     NOT NULL,
    SeverityBand    VARCHAR(20)     NOT NULL,
    TicketCount     DECIMAL(10,2)   NOT NULL
);

CREATE TABLE #CategoryCatalog
(
    SeverityBand    VARCHAR(20)     NOT NULL PRIMARY KEY,
    DisplayOrder    TINYINT         NOT NULL,
    IsApproved      BIT             NOT NULL
);

INSERT INTO #SparsePivotSource
(
    SnapshotDate,
    OwnerTeam,
    QueueName,
    SeverityBand,
    TicketCount
)
VALUES
    ('2026-03-03', 'CentralOps', 'Billing',   'Critical', 2.00),
    ('2026-03-03', 'CentralOps', 'Billing',   'High',     5.00),
    ('2026-03-03', 'NorthOps',   'Returns',   'Medium',   7.00),
    ('2026-03-03', 'NorthOps',   'Returns',   'Low',      3.00),
    ('2026-03-03', 'WestOps',    'Wholesale', 'Critical', 1.00),
    ('2026-03-03', 'WestOps',    'Wholesale', 'Deferred', 6.00),
    ('2026-04-04', 'CentralOps', 'Billing',   'Critical', 3.00),
    ('2026-04-04', 'CentralOps', 'Billing',   'High',     8.00),
    ('2026-04-04', 'CentralOps', 'Billing',   'Medium',   4.00),
    ('2026-04-04', 'NorthOps',   'Returns',   'High',     6.00),
    ('2026-04-04', 'NorthOps',   'Returns',   'Low',      5.00),
    ('2026-04-04', 'SouthOps',   'Onboarding','Medium',   9.00),
    ('2026-04-04', 'SouthOps',   'Onboarding','Deferred', 2.00),
    ('2026-04-04', 'WestOps',    'Wholesale', 'Critical', 1.00),
    ('2026-04-04', 'WestOps',    'Wholesale', 'High',     2.00),
    ('2026-04-04', 'WestOps',    'Wholesale', 'Deferred', 7.00),
    ('2026-05-06', 'CentralOps', 'Billing',   'Critical', 4.00),
    ('2026-05-06', 'SouthOps',   'Onboarding','High',     3.00),
    ('2026-05-06', 'WestOps',    'Wholesale', 'Low',      2.00);

INSERT INTO #CategoryCatalog
(
    SeverityBand,
    DisplayOrder,
    IsApproved
)
VALUES
    ('Critical', 1, 1),
    ('High',     2, 1),
    ('Medium',   3, 1),
    ('Low',      4, 1),
    ('Deferred', 5, 1);

IF @SnapshotMonth NOT BETWEEN 1 AND 12
BEGIN
    THROW 50091, 'PivotSparseCategoryDemo expects @SnapshotMonth between 1 and 12.', 1;
END;

IF @OnlyRowsWithGaps NOT IN (0, 1)
BEGIN
    THROW 50092, 'PivotSparseCategoryDemo expects @OnlyRowsWithGaps as 0 or 1.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM #SparsePivotSource AS src
    WHERE MONTH(src.SnapshotDate) = @SnapshotMonth
)
BEGIN
    THROW 50093, 'PivotSparseCategoryDemo found no source rows for the selected @SnapshotMonth.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM #CategoryCatalog AS cat
    WHERE cat.IsApproved = 1
)
BEGIN
    THROW 50094, 'PivotSparseCategoryDemo found no approved severity categories.', 1;
END;

SELECT
    src.SnapshotDate,
    src.OwnerTeam,
    src.QueueName,
    src.SeverityBand,
    src.TicketCount
FROM #SparsePivotSource AS src
WHERE MONTH(src.SnapshotDate) = @SnapshotMonth
ORDER BY
    src.OwnerTeam,
    src.QueueName,
    CASE src.SeverityBand
        WHEN 'Critical' THEN 1
        WHEN 'High' THEN 2
        WHEN 'Medium' THEN 3
        WHEN 'Low' THEN 4
        WHEN 'Deferred' THEN 5
        ELSE 99
    END;

SELECT
    cat.DisplayOrder,
    cat.SeverityBand,
    cat.IsApproved
FROM #CategoryCatalog AS cat
WHERE cat.IsApproved = 1
ORDER BY
    cat.DisplayOrder;

;WITH FilteredSource AS
(
    SELECT
        src.OwnerTeam,
        src.QueueName,
        src.SeverityBand,
        src.TicketCount
    FROM #SparsePivotSource AS src
    WHERE MONTH(src.SnapshotDate) = @SnapshotMonth
),
RowAxis AS
(
    SELECT DISTINCT
        src.OwnerTeam,
        src.QueueName
    FROM FilteredSource AS src
),
ApprovedCategories AS
(
    SELECT
        cat.SeverityBand,
        cat.DisplayOrder
    FROM #CategoryCatalog AS cat
    WHERE cat.IsApproved = 1
),
DenseCoverage AS
(
    SELECT
        ra.OwnerTeam,
        ra.QueueName,
        ac.SeverityBand,
        COALESCE(SUM(fs.TicketCount), 0.00) AS TicketCount
    FROM RowAxis AS ra
    CROSS JOIN ApprovedCategories AS ac
    LEFT JOIN FilteredSource AS fs
        ON fs.OwnerTeam = ra.OwnerTeam
       AND fs.QueueName = ra.QueueName
       AND fs.SeverityBand = ac.SeverityBand
    GROUP BY
        ra.OwnerTeam,
        ra.QueueName,
        ac.SeverityBand
)
SELECT
    dc.OwnerTeam,
    dc.QueueName,
    SUM(CASE WHEN dc.TicketCount = 0.00 THEN 1 ELSE 0 END) AS MissingCategoryCount,
    SUM(CASE WHEN dc.TicketCount > 0.00 THEN 1 ELSE 0 END) AS PresentCategoryCount,
    CAST(SUM(dc.TicketCount) AS DECIMAL(10,2)) AS TotalTicketsInMonth
FROM DenseCoverage AS dc
GROUP BY
    dc.OwnerTeam,
    dc.QueueName
ORDER BY
    dc.OwnerTeam,
    dc.QueueName;

;WITH FilteredSource AS
(
    SELECT
        src.OwnerTeam,
        src.QueueName,
        src.SeverityBand,
        src.TicketCount
    FROM #SparsePivotSource AS src
    WHERE MONTH(src.SnapshotDate) = @SnapshotMonth
),
RowAxis AS
(
    SELECT DISTINCT
        src.OwnerTeam,
        src.QueueName
    FROM FilteredSource AS src
),
ApprovedCategories AS
(
    SELECT
        cat.SeverityBand,
        cat.DisplayOrder
    FROM #CategoryCatalog AS cat
    WHERE cat.IsApproved = 1
),
DenseSource AS
(
    SELECT
        ra.OwnerTeam,
        ra.QueueName,
        ac.SeverityBand,
        COALESCE(SUM(fs.TicketCount), 0.00) AS TicketCount
    FROM RowAxis AS ra
    CROSS JOIN ApprovedCategories AS ac
    LEFT JOIN FilteredSource AS fs
        ON fs.OwnerTeam = ra.OwnerTeam
       AND fs.QueueName = ra.QueueName
       AND fs.SeverityBand = ac.SeverityBand
    GROUP BY
        ra.OwnerTeam,
        ra.QueueName,
        ac.SeverityBand
),
CoverageReview AS
(
    SELECT
        ds.OwnerTeam,
        ds.QueueName,
        SUM(CASE WHEN ds.TicketCount = 0.00 THEN 1 ELSE 0 END) AS MissingCategoryCount
    FROM DenseSource AS ds
    GROUP BY
        ds.OwnerTeam,
        ds.QueueName
),
EligibleRows AS
(
    SELECT
        cr.OwnerTeam,
        cr.QueueName,
        cr.MissingCategoryCount
    FROM CoverageReview AS cr
    WHERE @OnlyRowsWithGaps = 0
       OR cr.MissingCategoryCount > 0
)
SELECT
    p.OwnerTeam,
    p.QueueName,
    CAST(COALESCE(p.[Critical], 0.00) AS DECIMAL(10,2)) AS Critical,
    CAST(COALESCE(p.[High], 0.00) AS DECIMAL(10,2)) AS High,
    CAST(COALESCE(p.[Medium], 0.00) AS DECIMAL(10,2)) AS Medium,
    CAST(COALESCE(p.[Low], 0.00) AS DECIMAL(10,2)) AS Low,
    CAST(COALESCE(p.[Deferred], 0.00) AS DECIMAL(10,2)) AS Deferred,
    er.MissingCategoryCount
FROM
(
    SELECT
        ds.OwnerTeam,
        ds.QueueName,
        ds.SeverityBand,
        ds.TicketCount
    FROM DenseSource AS ds
    INNER JOIN EligibleRows AS er
        ON er.OwnerTeam = ds.OwnerTeam
       AND er.QueueName = ds.QueueName
) AS src
PIVOT
(
    SUM(src.TicketCount)
    FOR src.SeverityBand IN ([Critical], [High], [Medium], [Low], [Deferred])
) AS p
INNER JOIN EligibleRows AS er
    ON er.OwnerTeam = p.OwnerTeam
   AND er.QueueName = p.QueueName
ORDER BY
    p.OwnerTeam,
    p.QueueName;
