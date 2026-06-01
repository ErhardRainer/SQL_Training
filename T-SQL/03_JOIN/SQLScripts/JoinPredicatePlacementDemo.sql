/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "JoinPredicatePlacementDemo.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "03_JOIN"

purpose: >
  Vergleicht die Platzierung desselben Filters in ON und WHERE bei einem
  LEFT JOIN und macht sichtbar, wie sich dadurch erhaltene, verworfene und
  NULL-erweiterte Zeilen unterscheiden.

parameters:
  - name: "@TargetLeadStatus"
    sql_type: "NVARCHAR(20)"
    direction: "IN"
    required: false
    description: "Lead-Status auf der rechten Tabelle, der als Treffer gelten soll"
  - name: "@OnlyChangedCampaigns"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = nur Kampagnen zeigen, deren sichtbare Zeilenmenge je Filterplatzierung abweicht"
  - name: "@IncludeSourceData"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = Demo-Daten vor den JOIN-Auswertungen ausgeben"
  - name: "@IncludeInnerJoinReference"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zusaetzlich eine INNER-JOIN-Referenz mit demselben Statusfilter ausgeben"

result_sets:
  - name: "SourceDataPreview"
    description: "Optionale Vorschau der Demo-Kampagnen und Leads"
  - name: "FilterPlacedInOn"
    description: "LEFT JOIN mit Statusfilter direkt in der ON-Klausel"
  - name: "FilterPlacedInWhere"
    description: "LEFT JOIN mit demselben Statusfilter erst in der WHERE-Klausel"
  - name: "PredicatePlacementSummary"
    description: "Vergleicht pro Kampagne sichtbare Zeilen, NULL-Erhalt und Diagnosefaehigkeit"
  - name: "InnerJoinReference"
    description: "Optionale Referenz, wie nah die WHERE-Variante am INNER JOIN liegt"

dependencies:
  - "tempdb"
  - "temp tables"
  - "LEFT JOIN"
  - "INNER JOIN"
  - "CTE"
  - "CASE"
  - "COALESCE"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/03_JOIN/SQLScripts/JoinPredicatePlacementDemo.md"
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
    date: "2026-04-19"
    user: "ER"
    description: "Erstversion fuer die Demo zur Filterplatzierung in ON und WHERE bei LEFT JOINs"

notes:
  - "Die Demo verwendet ausschliesslich tempdb-Objekte und modelliert keine produktive Marketinglogik."
  - "Die WHERE-Variante zeigt bewusst, wie NULL-erhaltene LEFT-JOIN-Zeilen durch einen rechten Filter wieder verschwinden."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @TargetLeadStatus NVARCHAR(20) = N'qualified';
DECLARE @OnlyChangedCampaigns BIT = 1;
DECLARE @IncludeSourceData BIT = 1;
DECLARE @IncludeInnerJoinReference BIT = 1;

IF NULLIF(LTRIM(RTRIM(@TargetLeadStatus)), N'') IS NULL
BEGIN
    THROW 50030, '@TargetLeadStatus darf nicht leer sein.', 1;
END;

IF @OnlyChangedCampaigns NOT IN (0, 1)
BEGIN
    THROW 50031, '@OnlyChangedCampaigns muss 0 oder 1 sein.', 1;
END;

IF @IncludeSourceData NOT IN (0, 1)
BEGIN
    THROW 50032, '@IncludeSourceData muss 0 oder 1 sein.', 1;
END;

IF @IncludeInnerJoinReference NOT IN (0, 1)
BEGIN
    THROW 50033, '@IncludeInnerJoinReference muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #Campaigns;
DROP TABLE IF EXISTS #Leads;
DROP TABLE IF EXISTS #JoinFilterOn;
DROP TABLE IF EXISTS #JoinFilterWhere;

CREATE TABLE #Campaigns
(
    CampaignID INT NOT NULL PRIMARY KEY,
    CampaignCode NVARCHAR(20) NOT NULL,
    CampaignName NVARCHAR(100) NOT NULL,
    ChannelName NVARCHAR(30) NOT NULL,
    FocusRegion NVARCHAR(20) NOT NULL
);

CREATE TABLE #Leads
(
    LeadID INT NOT NULL PRIMARY KEY,
    CampaignID INT NOT NULL,
    LeadName NVARCHAR(100) NOT NULL,
    LeadStatus NVARCHAR(20) NOT NULL,
    EstimatedValue DECIMAL(10,2) NOT NULL,
    OwnerName NVARCHAR(100) NOT NULL
);

INSERT INTO #Campaigns (CampaignID, CampaignCode, CampaignName, ChannelName, FocusRegion)
VALUES
    (10, N'CAMP-ALPHA', N'ERP Renewal Wave', N'Email', N'DE-NORTH'),
    (20, N'CAMP-BETA', N'Service Upsell Sprint', N'Webinar', N'DE-SOUTH'),
    (30, N'CAMP-GAMMA', N'Cloud Launch Series', N'Partner', N'AT-WEST'),
    (40, N'CAMP-DELTA', N'Data Quality Checkup', N'Email', N'CH-CENTRAL'),
    (50, N'CAMP-EPSILON', N'Public Sector Outreach', N'Event', N'DE-NORTH');

INSERT INTO #Leads (LeadID, CampaignID, LeadName, LeadStatus, EstimatedValue, OwnerName)
VALUES
    (1001, 10, N'Alpen Handel', N'qualified', 18000.00, N'Anja Weiss'),
    (1002, 10, N'Berg Logistik', N'new', 12000.00, N'Ben Maurer'),
    (1003, 20, N'City Clinic', N'nurturing', 9000.00, N'Clara Stein'),
    (1004, 20, N'Delta School', N'qualified', 15000.00, N'Denis Wolf'),
    (1005, 20, N'Elbe Stores', N'qualified', 7000.00, N'Elif Kurz'),
    (1006, 30, N'Forum Group', N'new', 11000.00, N'Farid Meier'),
    (1007, 40, N'Global Foods', N'closed', 22000.00, N'Greta Blum');

IF @IncludeSourceData = 1
BEGIN
    SELECT
        c.CampaignID,
        c.CampaignCode,
        c.CampaignName,
        c.ChannelName,
        c.FocusRegion,
        l.LeadID,
        l.LeadName,
        l.LeadStatus,
        l.EstimatedValue,
        l.OwnerName
    FROM #Campaigns AS c
    LEFT JOIN #Leads AS l
        ON l.CampaignID = c.CampaignID
    ORDER BY
        c.CampaignID,
        l.LeadID;
END;

SELECT
    c.CampaignID,
    c.CampaignCode,
    c.CampaignName,
    c.ChannelName,
    c.FocusRegion,
    l.LeadID,
    l.LeadName,
    l.LeadStatus,
    l.EstimatedValue,
    l.OwnerName,
    CASE
        WHEN l.LeadID IS NULL THEN 'campaign preserved without matching target-status lead'
        ELSE 'campaign matched target-status lead in ON'
    END AS PlacementOutcome
INTO #JoinFilterOn
FROM #Campaigns AS c
LEFT JOIN #Leads AS l
    ON l.CampaignID = c.CampaignID
   AND l.LeadStatus = @TargetLeadStatus;

SELECT
    c.CampaignID,
    c.CampaignCode,
    c.CampaignName,
    c.ChannelName,
    c.FocusRegion,
    l.LeadID,
    l.LeadName,
    l.LeadStatus,
    l.EstimatedValue,
    l.OwnerName,
    CAST('campaign kept only when a target-status lead exists after WHERE filtering' AS NVARCHAR(120)) AS PlacementOutcome
INTO #JoinFilterWhere
FROM #Campaigns AS c
LEFT JOIN #Leads AS l
    ON l.CampaignID = c.CampaignID
WHERE l.LeadStatus = @TargetLeadStatus;

;WITH OnSummary AS
(
    SELECT
        jfo.CampaignID,
        COUNT(*) AS RowsWithFilterInOn,
        SUM(CASE WHEN jfo.LeadID IS NULL THEN 1 ELSE 0 END) AS NullExtendedRowsInOn
    FROM #JoinFilterOn AS jfo
    GROUP BY
        jfo.CampaignID
),
WhereSummary AS
(
    SELECT
        jfw.CampaignID,
        COUNT(*) AS RowsWithFilterInWhere
    FROM #JoinFilterWhere AS jfw
    GROUP BY
        jfw.CampaignID
)
SELECT
    jfo.CampaignCode,
    jfo.CampaignName,
    jfo.ChannelName,
    jfo.FocusRegion,
    jfo.LeadID,
    jfo.LeadName,
    jfo.LeadStatus,
    jfo.EstimatedValue,
    jfo.OwnerName,
    jfo.PlacementOutcome
FROM #JoinFilterOn AS jfo
LEFT JOIN OnSummary AS os
    ON os.CampaignID = jfo.CampaignID
LEFT JOIN WhereSummary AS ws
    ON ws.CampaignID = jfo.CampaignID
WHERE @OnlyChangedCampaigns = 0
   OR COALESCE(os.RowsWithFilterInOn, 0) <> COALESCE(ws.RowsWithFilterInWhere, 0)
ORDER BY
    jfo.CampaignCode,
    jfo.LeadID;

SELECT
    jfw.CampaignCode,
    jfw.CampaignName,
    jfw.ChannelName,
    jfw.FocusRegion,
    jfw.LeadID,
    jfw.LeadName,
    jfw.LeadStatus,
    jfw.EstimatedValue,
    jfw.OwnerName,
    jfw.PlacementOutcome
FROM #JoinFilterWhere AS jfw
LEFT JOIN OnSummary AS os
    ON os.CampaignID = jfw.CampaignID
LEFT JOIN WhereSummary AS ws
    ON ws.CampaignID = jfw.CampaignID
WHERE @OnlyChangedCampaigns = 0
   OR COALESCE(os.RowsWithFilterInOn, 0) <> COALESCE(ws.RowsWithFilterInWhere, 0)
ORDER BY
    jfw.CampaignCode,
    jfw.LeadID;

SELECT
    c.CampaignCode,
    c.CampaignName,
    c.ChannelName,
    c.FocusRegion,
    COALESCE(os.RowsWithFilterInOn, 0) AS RowsWithFilterInOn,
    COALESCE(os.NullExtendedRowsInOn, 0) AS NullExtendedRowsInOn,
    COALESCE(ws.RowsWithFilterInWhere, 0) AS RowsWithFilterInWhere,
    CASE
        WHEN COALESCE(os.RowsWithFilterInOn, 0) = COALESCE(ws.RowsWithFilterInWhere, 0) THEN 'same-visible-rows'
        WHEN COALESCE(ws.RowsWithFilterInWhere, 0) = 0 AND COALESCE(os.NullExtendedRowsInOn, 0) > 0 THEN 'campaign-lost-in-where'
        ELSE 'different-visible-rows'
    END AS ComparisonStatus,
    CASE
        WHEN COALESCE(ws.RowsWithFilterInWhere, 0) = 0 AND COALESCE(os.NullExtendedRowsInOn, 0) > 0
            THEN 'Die ON-Variante behaelt die Kampagne als NULL-erweiterte Zeile sichtbar.'
        WHEN COALESCE(os.RowsWithFilterInOn, 0) <> COALESCE(ws.RowsWithFilterInWhere, 0)
            THEN 'Die Filterplatzierung aendert die sichtbare Ergebnismenge fuer diese Kampagne.'
        ELSE 'Beide Varianten zeigen dieselbe Menge an sichtbaren Zeilen.'
    END AS TeachingNote
FROM #Campaigns AS c
LEFT JOIN OnSummary AS os
    ON os.CampaignID = c.CampaignID
LEFT JOIN WhereSummary AS ws
    ON ws.CampaignID = c.CampaignID
WHERE @OnlyChangedCampaigns = 0
   OR COALESCE(os.RowsWithFilterInOn, 0) <> COALESCE(ws.RowsWithFilterInWhere, 0)
ORDER BY
    c.CampaignCode;

IF @IncludeInnerJoinReference = 1
BEGIN
    SELECT
        c.CampaignCode,
        c.CampaignName,
        c.ChannelName,
        c.FocusRegion,
        l.LeadID,
        l.LeadName,
        l.LeadStatus,
        l.EstimatedValue,
        l.OwnerName,
        'INNER JOIN reference with identical target-status filter' AS PlacementOutcome
    FROM #Campaigns AS c
    INNER JOIN #Leads AS l
        ON l.CampaignID = c.CampaignID
       AND l.LeadStatus = @TargetLeadStatus
    ORDER BY
        c.CampaignCode,
        l.LeadID;
END;
