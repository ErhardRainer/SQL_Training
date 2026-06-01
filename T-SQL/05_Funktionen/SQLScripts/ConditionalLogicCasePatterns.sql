/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "ConditionalLogicCasePatterns.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "05_Funktionen"

purpose: >
  Buendelt typische CASE-Muster fuer Segmentklassifikation,
  Umsatz-Bucketing, Statuskennzeichen und umschaltbare
  Sortierschluessel auf einer gemeinsamen Demo-Datenbasis.

parameters:
  - name: "@SegmentFocus"
    sql_type: "VARCHAR(20)"
    direction: "IN"
    required: false
    description: "Filtert all, core, growth oder watch"
  - name: "@SortMode"
    sql_type: "VARCHAR(20)"
    direction: "IN"
    required: false
    description: "Steuert den Sortierschluessel ueber priority, revenue oder overdue"
  - name: "@IncludeInactive"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 zeigt auch inaktive Kunden, 0 blendet sie aus"

result_sets:
  - name: "CasePatternRows"
    description: "Zeigt pro Demo-Kunde abgeleitete CASE-Spalten fuer Segment, Buckets und Sortierung"
  - name: "BucketSummary"
    description: "Aggregiert Zeilen je Segment und Umsatz-Bucket"
  - name: "SortModeSummary"
    description: "Erlaeutert den aktiven Sortiermodus und die dadurch priorisierten Zeilen"

dependencies:
  - "tempdb temporary tables"
  - "CASE"
  - "CTE"
  - "ROW_NUMBER"
  - "STRING_AGG"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/05_Funktionen/SQLScripts/ConditionalLogicCasePatterns.md"
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
    date: "2026-04-17"
    user: "ER"
    description: "Erstversion fuer didaktische CASE-Muster in Funktionen"

notes:
  - "Das Skript nutzt nur tempdb-nahe Demo-Daten und keine produktiven Tabellen."
  - "CASE wird bewusst fuer Lesbarkeit und Lehrzwecke gebuendelt statt in UDFs ausgelagert."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @SegmentFocus VARCHAR(20) = 'all';
DECLARE @SortMode VARCHAR(20) = 'priority';
DECLARE @IncludeInactive BIT = 1;

IF @SegmentFocus NOT IN ('all', 'core', 'growth', 'watch')
BEGIN
    THROW 50510, '@SegmentFocus muss all, core, growth oder watch sein.', 1;
END;

IF @SortMode NOT IN ('priority', 'revenue', 'overdue')
BEGIN
    THROW 50511, '@SortMode muss priority, revenue oder overdue sein.', 1;
END;

IF @IncludeInactive NOT IN (0, 1)
BEGIN
    THROW 50512, '@IncludeInactive muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #CustomerSignals;

CREATE TABLE #CustomerSignals
(
    CustomerID INT NOT NULL PRIMARY KEY,
    CustomerName NVARCHAR(80) NOT NULL,
    RegionCode CHAR(2) NOT NULL,
    ChannelCode VARCHAR(20) NOT NULL,
    IsActive BIT NOT NULL,
    RevenueAmount DECIMAL(10, 2) NOT NULL,
    DiscountPct DECIMAL(5, 2) NOT NULL,
    OpenTicketCount INT NOT NULL,
    DaysPastDue INT NOT NULL
);

INSERT INTO #CustomerSignals
(
    CustomerID,
    CustomerName,
    RegionCode,
    ChannelCode,
    IsActive,
    RevenueAmount,
    DiscountPct,
    OpenTicketCount,
    DaysPastDue
)
VALUES
    (3101, N'Alpen Handel GmbH', 'DE', 'direct', 1, 182000.00, 3.50, 0, 0),
    (3102, N'Bodensee Retail AG', 'CH', 'partner', 1, 94500.00, 6.00, 1, 4),
    (3103, N'City Data KG', 'DE', 'online', 1, 48600.00, 10.00, 3, 19),
    (3104, N'Donau Services GmbH', 'AT', 'direct', 0, 15300.00, 12.50, 2, 0),
    (3105, N'Elbphilharmonie Tech AG', 'DE', 'partner', 1, 127500.00, 4.00, 0, 8),
    (3106, N'Fjord Analytics SA', 'CH', 'online', 1, 35200.00, 8.50, 4, 27),
    (3107, N'Gletscher Logistik GmbH', 'AT', 'direct', 1, 70200.00, 5.00, 1, 0),
    (3108, N'Havel Office KG', 'DE', 'online', 0, 11800.00, 15.00, 5, 41);

;WITH PreparedSignals AS
(
    SELECT
        cs.CustomerID,
        cs.CustomerName,
        cs.RegionCode,
        cs.ChannelCode,
        cs.IsActive,
        cs.RevenueAmount,
        cs.DiscountPct,
        cs.OpenTicketCount,
        cs.DaysPastDue,
        CASE
            WHEN cs.RevenueAmount >= 120000.00 AND cs.OpenTicketCount <= 1 AND cs.IsActive = 1 THEN 'core'
            WHEN cs.RevenueAmount >= 40000.00 AND cs.IsActive = 1 THEN 'growth'
            ELSE 'watch'
        END AS SegmentLabel,
        CASE
            WHEN cs.RevenueAmount >= 150000.00 THEN 'enterprise'
            WHEN cs.RevenueAmount >= 80000.00 THEN 'upper-mid'
            WHEN cs.RevenueAmount >= 30000.00 THEN 'mid'
            ELSE 'entry'
        END AS RevenueBucket,
        CASE
            WHEN cs.DaysPastDue >= 30 THEN 'critical'
            WHEN cs.DaysPastDue >= 7 THEN 'monitor'
            WHEN cs.DaysPastDue > 0 THEN 'slight'
            ELSE 'current'
        END AS ReceivableState,
        CASE
            WHEN cs.IsActive = 0 THEN 'inactive'
            WHEN cs.OpenTicketCount >= 3 THEN 'support-heavy'
            WHEN cs.DiscountPct >= 10.00 THEN 'discount-sensitive'
            ELSE 'stable'
        END AS RelationshipFlag,
        CASE
            WHEN @SortMode = 'priority' AND cs.IsActive = 1 AND cs.DaysPastDue >= 7 THEN 1
            WHEN @SortMode = 'priority' AND cs.IsActive = 1 AND cs.OpenTicketCount >= 2 THEN 2
            WHEN @SortMode = 'priority' THEN 3
            WHEN @SortMode = 'revenue' AND cs.RevenueAmount >= 120000.00 THEN 1
            WHEN @SortMode = 'revenue' AND cs.RevenueAmount >= 60000.00 THEN 2
            WHEN @SortMode = 'revenue' THEN 3
            WHEN @SortMode = 'overdue' AND cs.DaysPastDue >= 30 THEN 1
            WHEN @SortMode = 'overdue' AND cs.DaysPastDue >= 7 THEN 2
            ELSE 3
        END AS SortTier,
        CASE
            WHEN @SortMode = 'priority' THEN
                CASE
                    WHEN cs.IsActive = 0 THEN 'inactive-last'
                    WHEN cs.DaysPastDue >= 7 THEN 'collection-first'
                    WHEN cs.OpenTicketCount >= 2 THEN 'service-review'
                    ELSE 'steady-book'
                END
            WHEN @SortMode = 'revenue' THEN
                CASE
                    WHEN cs.RevenueAmount >= 120000.00 THEN 'top-revenue'
                    WHEN cs.RevenueAmount >= 60000.00 THEN 'mid-revenue'
                    ELSE 'lower-revenue'
                END
            ELSE
                CASE
                    WHEN cs.DaysPastDue >= 30 THEN 'critical-overdue'
                    WHEN cs.DaysPastDue >= 7 THEN 'watch-overdue'
                    ELSE 'current-first'
                END
        END AS SortLabel
    FROM #CustomerSignals AS cs
    WHERE (@IncludeInactive = 1 OR cs.IsActive = 1)
),
FilteredSignals AS
(
    SELECT
        ps.CustomerID,
        ps.CustomerName,
        ps.RegionCode,
        ps.ChannelCode,
        ps.IsActive,
        ps.RevenueAmount,
        ps.DiscountPct,
        ps.OpenTicketCount,
        ps.DaysPastDue,
        ps.SegmentLabel,
        ps.RevenueBucket,
        ps.ReceivableState,
        ps.RelationshipFlag,
        ps.SortTier,
        ps.SortLabel
    FROM PreparedSignals AS ps
    WHERE (@SegmentFocus = 'all' OR ps.SegmentLabel = @SegmentFocus)
),
RankedSignals AS
(
    SELECT
        ROW_NUMBER() OVER (
            ORDER BY
                fs.SortTier,
                CASE WHEN @SortMode = 'revenue' THEN fs.RevenueAmount END DESC,
                CASE WHEN @SortMode = 'overdue' THEN fs.DaysPastDue END DESC,
                fs.CustomerName
        ) AS DisplayOrder,
        fs.CustomerID,
        fs.CustomerName,
        fs.RegionCode,
        fs.ChannelCode,
        fs.IsActive,
        fs.RevenueAmount,
        fs.DiscountPct,
        fs.OpenTicketCount,
        fs.DaysPastDue,
        fs.SegmentLabel,
        fs.RevenueBucket,
        fs.ReceivableState,
        fs.RelationshipFlag,
        fs.SortTier,
        fs.SortLabel
    FROM FilteredSignals AS fs
)
SELECT
    rs.DisplayOrder,
    rs.CustomerID,
    rs.CustomerName,
    rs.RegionCode,
    rs.ChannelCode,
    rs.IsActive,
    rs.RevenueAmount,
    rs.DiscountPct,
    rs.OpenTicketCount,
    rs.DaysPastDue,
    rs.SegmentLabel,
    rs.RevenueBucket,
    rs.ReceivableState,
    rs.RelationshipFlag,
    rs.SortTier,
    rs.SortLabel
FROM RankedSignals AS rs
ORDER BY
    rs.DisplayOrder;

SELECT
    fs.SegmentLabel,
    fs.RevenueBucket,
    COUNT(*) AS CustomerCount,
    SUM(fs.RevenueAmount) AS RevenueTotal,
    AVG(fs.DiscountPct) AS AvgDiscountPct,
    STRING_AGG(fs.CustomerName, ', ') WITHIN GROUP (ORDER BY fs.CustomerName) AS SampleCustomers
FROM FilteredSignals AS fs
GROUP BY
    fs.SegmentLabel,
    fs.RevenueBucket
ORDER BY
    CASE fs.SegmentLabel
        WHEN 'core' THEN 1
        WHEN 'growth' THEN 2
        ELSE 3
    END,
    CASE fs.RevenueBucket
        WHEN 'enterprise' THEN 1
        WHEN 'upper-mid' THEN 2
        WHEN 'mid' THEN 3
        ELSE 4
    END;

;WITH SortModeSummary AS
(
    SELECT
        @SortMode AS SortMode,
        MIN(fs.SortTier) AS HighestPriorityTier,
        COUNT(*) AS VisibleCustomers,
        SUM(CASE WHEN fs.ReceivableState IN ('critical', 'monitor') THEN 1 ELSE 0 END) AS EscalationCandidates,
        SUM(CASE WHEN fs.SegmentLabel = 'core' THEN 1 ELSE 0 END) AS CoreCustomers,
        MIN(fs.SortLabel) AS LeadingSortLabel
    FROM FilteredSignals AS fs
)
SELECT
    sms.SortMode,
    sms.HighestPriorityTier,
    sms.VisibleCustomers,
    sms.EscalationCandidates,
    sms.CoreCustomers,
    sms.LeadingSortLabel,
    CASE sms.SortMode
        WHEN 'priority' THEN 'Priorisiert ueberfaellige oder serviceintensive Kunden zuerst.'
        WHEN 'revenue' THEN 'Priorisiert hohe Umsatzbeitraege fuer Account-Review oder Kampagnen.'
        ELSE 'Priorisiert Forderungsalter fuer Mahn- und Eskalationslisten.'
    END AS TeachingNote
FROM SortModeSummary AS sms;
