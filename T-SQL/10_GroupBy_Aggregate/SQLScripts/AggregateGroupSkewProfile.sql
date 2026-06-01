/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "AggregateGroupSkewProfile.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "10_GroupBy_Aggregate"

purpose: >
  Profiliert ungleich verteilte Untergruppen innerhalb groesserer
  Aggregate, berechnet Beitragsanteile je Segment und leitet daraus
  Dominanz- und Schiefe-Signale pro Hauptgruppe ab.

parameters:
  - name: "@DominantShareThreshold"
    sql_type: "DECIMAL(5,4)"
    direction: "IN"
    required: true
    description: "Schwellenwert, ab dem der groesste Segmentanteil als dominant gilt"
  - name: "@MinimumGroupVolume"
    sql_type: "INT"
    direction: "IN"
    required: true
    description: "Mindestanzahl an Auftragszeilen, damit eine Gruppe als belastbar bewertet wird"
  - name: "@ShowOrderPreview"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zeigt die Demo-Auftragszeilen vor der Verdichtung an"

result_sets:
  - name: "OrderPreview"
    description: "Optionale Vorschau der Demo-Auftragszeilen mit Region und Segment"
  - name: "SegmentContributionProfile"
    description: "Beitragsanteile und Summen je Kombination aus Region und CustomerSegment"
  - name: "GroupSkewProfile"
    description: "Verdichtete Schiefe-Kennzahlen je Region mit dominantem Segment"
  - name: "SkewClassSummary"
    description: "Zaehlt, wie viele Regionen je Schiefe-Klasse auftreten"

dependencies:
  - "tempdb"
  - "GROUP BY"
  - "SUM()"
  - "COUNT()"
  - "MIN()"
  - "MAX()"
  - "CAST()"
  - "CASE"
  - "NULLIF()"
  - "DROP TABLE IF EXISTS"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/10_GroupBy_Aggregate/SQLScripts/AggregateGroupSkewProfile.md"
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
    description: "Erstversion eines didaktischen Labs fuer Schiefe-Profile aggregierter Gruppen"

notes:
  - "Die Erstversion nutzt lokale Temp-Daten statt produktiver Faktentabellen"
  - "Schiefe wird ueber den Anteil des groessten Segments innerhalb einer Region bewertet"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @DominantShareThreshold DECIMAL(5,4) = 0.6500;
DECLARE @MinimumGroupVolume INT = 4;
DECLARE @ShowOrderPreview BIT = 1;

IF @DominantShareThreshold IS NULL OR @DominantShareThreshold <= 0 OR @DominantShareThreshold > 1
BEGIN
    THROW 50000, '@DominantShareThreshold muss zwischen 0 und 1 liegen.', 1;
END;

IF @MinimumGroupVolume IS NULL OR @MinimumGroupVolume <= 0
BEGIN
    THROW 50001, '@MinimumGroupVolume muss groesser als 0 sein.', 1;
END;

IF @ShowOrderPreview NOT IN (0, 1)
BEGIN
    THROW 50002, '@ShowOrderPreview muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #SalesOrders;

CREATE TABLE #SalesOrders
(
    OrderID         INT             NOT NULL,
    OrderDate       DATE            NOT NULL,
    SalesRegion     VARCHAR(20)     NOT NULL,
    CustomerSegment VARCHAR(20)     NOT NULL,
    SalesChannel    VARCHAR(20)     NOT NULL,
    OrderAmount     DECIMAL(12,2)   NOT NULL
);

INSERT INTO #SalesOrders
(
    OrderID,
    OrderDate,
    SalesRegion,
    CustomerSegment,
    SalesChannel,
    OrderAmount
)
VALUES
    (4001, '2026-01-03', 'North', 'Enterprise', 'Online',  820.00),
    (4002, '2026-01-05', 'North', 'Enterprise', 'Online',  790.00),
    (4003, '2026-01-08', 'North', 'Enterprise', 'Retail',  610.00),
    (4004, '2026-01-11', 'North', 'Enterprise', 'Retail',  655.00),
    (4005, '2026-01-15', 'North', 'SMB',        'Online',  210.00),
    (4006, '2026-01-18', 'North', 'Public',     'Retail',  185.00),
    (4007, '2026-02-02', 'South', 'SMB',        'Online',  330.00),
    (4008, '2026-02-04', 'South', 'SMB',        'Retail',  310.00),
    (4009, '2026-02-06', 'South', 'Enterprise', 'Online',  450.00),
    (4010, '2026-02-09', 'South', 'Enterprise', 'Retail',  430.00),
    (4011, '2026-02-12', 'South', 'Public',     'Online',  290.00),
    (4012, '2026-02-16', 'South', 'Public',     'Retail',  305.00),
    (4013, '2026-03-01', 'West',  'SMB',        'Online',  240.00),
    (4014, '2026-03-03', 'West',  'SMB',        'Online',  255.00),
    (4015, '2026-03-06', 'West',  'SMB',        'Retail',  260.00),
    (4016, '2026-03-09', 'West',  'SMB',        'Retail',  245.00),
    (4017, '2026-03-12', 'West',  'SMB',        'Online',  270.00),
    (4018, '2026-03-14', 'West',  'Enterprise', 'Online',  520.00),
    (4019, '2026-03-18', 'East',  'Enterprise', 'Online',  510.00),
    (4020, '2026-03-20', 'East',  'SMB',        'Retail',  295.00),
    (4021, '2026-03-22', 'East',  'Public',     'Online',  305.00),
    (4022, '2026-03-24', 'East',  'Enterprise', 'Retail',  495.00),
    (4023, '2026-03-26', 'East',  'SMB',        'Online',  285.00),
    (4024, '2026-03-28', 'East',  'Public',     'Retail',  315.00);

IF @ShowOrderPreview = 1
BEGIN
    SELECT
        so.OrderID,
        so.OrderDate,
        so.SalesRegion,
        so.CustomerSegment,
        so.SalesChannel,
        so.OrderAmount
    FROM #SalesOrders AS so
    ORDER BY
        so.SalesRegion,
        so.CustomerSegment,
        so.OrderDate,
        so.OrderID;
END;

;WITH RegionTotals AS
(
    SELECT
        so.SalesRegion,
        COUNT(*) AS RegionOrderCount,
        SUM(so.OrderAmount) AS RegionRevenue
    FROM #SalesOrders AS so
    GROUP BY
        so.SalesRegion
),
SegmentMetrics AS
(
    SELECT
        so.SalesRegion,
        so.CustomerSegment,
        COUNT(*) AS SegmentOrderCount,
        SUM(so.OrderAmount) AS SegmentRevenue
    FROM #SalesOrders AS so
    GROUP BY
        so.SalesRegion,
        so.CustomerSegment
),
ContributionProfile AS
(
    SELECT
        sm.SalesRegion,
        sm.CustomerSegment,
        sm.SegmentOrderCount,
        sm.SegmentRevenue,
        rt.RegionOrderCount,
        rt.RegionRevenue,
        CAST(sm.SegmentOrderCount * 1.0 / NULLIF(rt.RegionOrderCount, 0) AS DECIMAL(5,4)) AS OrderShare,
        CAST(sm.SegmentRevenue * 1.0 / NULLIF(rt.RegionRevenue, 0) AS DECIMAL(5,4)) AS RevenueShare
    FROM SegmentMetrics AS sm
    INNER JOIN RegionTotals AS rt
        ON rt.SalesRegion = sm.SalesRegion
),
DominantSegments AS
(
    SELECT
        cp.SalesRegion,
        MAX(cp.OrderShare) AS MaxOrderShare
    FROM ContributionProfile AS cp
    GROUP BY
        cp.SalesRegion
)
SELECT
    cp.SalesRegion,
    cp.CustomerSegment,
    cp.SegmentOrderCount,
    cp.RegionOrderCount,
    cp.OrderShare,
    cp.SegmentRevenue,
    cp.RegionRevenue,
    cp.RevenueShare
FROM ContributionProfile AS cp
ORDER BY
    cp.SalesRegion,
    cp.OrderShare DESC,
    cp.CustomerSegment;

;WITH RegionTotals AS
(
    SELECT
        so.SalesRegion,
        COUNT(*) AS RegionOrderCount,
        SUM(so.OrderAmount) AS RegionRevenue
    FROM #SalesOrders AS so
    GROUP BY
        so.SalesRegion
),
SegmentMetrics AS
(
    SELECT
        so.SalesRegion,
        so.CustomerSegment,
        COUNT(*) AS SegmentOrderCount,
        SUM(so.OrderAmount) AS SegmentRevenue
    FROM #SalesOrders AS so
    GROUP BY
        so.SalesRegion,
        so.CustomerSegment
),
ContributionProfile AS
(
    SELECT
        sm.SalesRegion,
        sm.CustomerSegment,
        sm.SegmentOrderCount,
        sm.SegmentRevenue,
        rt.RegionOrderCount,
        rt.RegionRevenue,
        CAST(sm.SegmentOrderCount * 1.0 / NULLIF(rt.RegionOrderCount, 0) AS DECIMAL(5,4)) AS OrderShare,
        CAST(sm.SegmentRevenue * 1.0 / NULLIF(rt.RegionRevenue, 0) AS DECIMAL(5,4)) AS RevenueShare
    FROM SegmentMetrics AS sm
    INNER JOIN RegionTotals AS rt
        ON rt.SalesRegion = sm.SalesRegion
),
DominantSegments AS
(
    SELECT
        cp.SalesRegion,
        MAX(cp.OrderShare) AS MaxOrderShare
    FROM ContributionProfile AS cp
    GROUP BY
        cp.SalesRegion
)
SELECT
    cp.SalesRegion,
    MAX(CASE WHEN cp.OrderShare = ds.MaxOrderShare THEN cp.CustomerSegment END) AS DominantCustomerSegment,
    MAX(cp.RegionOrderCount) AS RegionOrderCount,
    COUNT(*) AS SegmentCount,
    ds.MaxOrderShare AS DominantOrderShare,
    MIN(cp.OrderShare) AS SmallestOrderShare,
    CAST(ds.MaxOrderShare - MIN(cp.OrderShare) AS DECIMAL(5,4)) AS ShareSpread,
    CAST(MAX(cp.RevenueShare) AS DECIMAL(5,4)) AS DominantRevenueShare,
    CASE
        WHEN MAX(cp.RegionOrderCount) < @MinimumGroupVolume THEN 'low_volume'
        WHEN ds.MaxOrderShare >= @DominantShareThreshold THEN 'dominant_segment'
        WHEN ds.MaxOrderShare >= 0.5000 THEN 'moderate_skew'
        ELSE 'balanced'
    END AS SkewClass
FROM ContributionProfile AS cp
INNER JOIN DominantSegments AS ds
    ON ds.SalesRegion = cp.SalesRegion
GROUP BY
    cp.SalesRegion,
    ds.MaxOrderShare
ORDER BY
    ds.MaxOrderShare DESC,
    cp.SalesRegion;

;WITH RegionTotals AS
(
    SELECT
        so.SalesRegion,
        COUNT(*) AS RegionOrderCount
    FROM #SalesOrders AS so
    GROUP BY
        so.SalesRegion
),
SegmentMetrics AS
(
    SELECT
        so.SalesRegion,
        so.CustomerSegment,
        COUNT(*) AS SegmentOrderCount
    FROM #SalesOrders AS so
    GROUP BY
        so.SalesRegion,
        so.CustomerSegment
),
ContributionProfile AS
(
    SELECT
        sm.SalesRegion,
        sm.CustomerSegment,
        rt.RegionOrderCount,
        CAST(sm.SegmentOrderCount * 1.0 / NULLIF(rt.RegionOrderCount, 0) AS DECIMAL(5,4)) AS OrderShare
    FROM SegmentMetrics AS sm
    INNER JOIN RegionTotals AS rt
        ON rt.SalesRegion = sm.SalesRegion
),
RegionSkewClass AS
(
    SELECT
        cp.SalesRegion,
        CASE
            WHEN MAX(cp.RegionOrderCount) < @MinimumGroupVolume THEN 'low_volume'
            WHEN MAX(cp.OrderShare) >= @DominantShareThreshold THEN 'dominant_segment'
            WHEN MAX(cp.OrderShare) >= 0.5000 THEN 'moderate_skew'
            ELSE 'balanced'
        END AS SkewClass
    FROM ContributionProfile AS cp
    GROUP BY
        cp.SalesRegion
)
SELECT
    rsc.SkewClass,
    COUNT(*) AS RegionCount
FROM RegionSkewClass AS rsc
GROUP BY
    rsc.SkewClass
ORDER BY
    RegionCount DESC,
    rsc.SkewClass;
