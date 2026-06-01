/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "FunctionConditionalLabeling.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "05_Funktionen"

purpose: >
  Kombiniert CASE mit String-, Datums- und Nullbehandlungsfunktionen,
  um aus kompakten Demo-Signalen fachlich lesbare Labels fuer Umsatz,
  Servicezustand und Risiko abzuleiten.

parameters:
  - name: "@LabelMode"
    sql_type: "VARCHAR(20)"
    direction: "IN"
    required: false
    description: "Filtert all, revenue, service oder risk"
  - name: "@ReferenceDate"
    sql_type: "DATE"
    direction: "IN"
    required: false
    description: "Referenzdatum fuer Kontaktalter und Faelligkeitslabels"
  - name: "@ShowOnlyEscalated"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 zeigt nur eskalationsrelevante Zeilen, 0 zeigt alle Demo-Faelle"

result_sets:
  - name: "ConditionalLabelRows"
    description: "Zeigt pro Demo-Konto abgeleitete Umsatz-, Service- und Risikolabels"
  - name: "LabelSummary"
    description: "Aggregiert die Demo-Konten nach aktivem Label-Fokus"
  - name: "EscalationPreview"
    description: "Listet eskalationsrelevante Konten mit begruendetem Queue-Label"

dependencies:
  - "tempdb temporary tables"
  - "CASE"
  - "COALESCE"
  - "CONCAT"
  - "DATEDIFF"
  - "ROW_NUMBER"
  - "STRING_AGG"
  - "UPPER"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/05_Funktionen/SQLScripts/FunctionConditionalLabeling.md"
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
    description: "Erstversion fuer didaktische Labels aus CASE und Funktionen"

notes:
  - "Das Skript arbeitet nur mit temporaeren Demo-Daten und erzeugt keine persistenten Aenderungen."
  - "Die Labels sind Lehrmuster fuer SQL-Ausdruecke und keine verbindliche Fachklassifikation."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @LabelMode VARCHAR(20) = 'all';
DECLARE @ReferenceDate DATE = '2026-04-17';
DECLARE @ShowOnlyEscalated BIT = 0;

IF @LabelMode NOT IN ('all', 'revenue', 'service', 'risk')
BEGIN
    THROW 50610, '@LabelMode muss all, revenue, service oder risk sein.', 1;
END;

IF @ShowOnlyEscalated NOT IN (0, 1)
BEGIN
    THROW 50611, '@ShowOnlyEscalated muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #AccountSignals;

CREATE TABLE #AccountSignals
(
    AccountId INT NOT NULL PRIMARY KEY,
    AccountName NVARCHAR(80) NOT NULL,
    RegionCode CHAR(2) NOT NULL,
    AnnualRevenue DECIMAL(12, 2) NOT NULL,
    OpenIssueCount INT NOT NULL,
    DaysPastDue INT NOT NULL,
    LastContactDate DATE NULL,
    PreferredChannel VARCHAR(20) NULL,
    AccountOwner NVARCHAR(80) NULL
);

INSERT INTO #AccountSignals
(
    AccountId,
    AccountName,
    RegionCode,
    AnnualRevenue,
    OpenIssueCount,
    DaysPastDue,
    LastContactDate,
    PreferredChannel,
    AccountOwner
)
VALUES
    (4101, N'Alpen Machines GmbH', 'DE', 185000.00, 0, 0, DATEADD(DAY, -6, @ReferenceDate), 'direct', N'R. Winter'),
    (4102, N'Baltic Retail AG', 'CH', 128000.00, 2, 11, DATEADD(DAY, -18, @ReferenceDate), 'partner', N'S. Keller'),
    (4103, N'City Health Lab', 'DE', 64200.00, 4, 3, DATEADD(DAY, -29, @ReferenceDate), 'online', N'M. Braun'),
    (4104, N'Donau Services KG', 'AT', 27800.00, 1, 0, DATEADD(DAY, -47, @ReferenceDate), NULL, N'T. Mayer'),
    (4105, N'Elbe Mobility SE', 'DE', 93400.00, 3, 26, NULL, 'direct', NULL),
    (4106, N'Fjord Foods SA', 'CH', 22100.00, 5, 39, DATEADD(DAY, -63, @ReferenceDate), 'partner', N'L. Huber');

;WITH PreparedSignals AS
(
    SELECT
        src.AccountId,
        UPPER(src.AccountName) AS NormalizedAccountName,
        src.RegionCode,
        src.AnnualRevenue,
        src.OpenIssueCount,
        src.DaysPastDue,
        src.LastContactDate,
        COALESCE(src.PreferredChannel, 'unspecified') AS PreferredChannel,
        COALESCE(src.AccountOwner, N'Unassigned') AS AccountOwner,
        CASE
            WHEN src.AnnualRevenue >= 150000.00 THEN 'strategic'
            WHEN src.AnnualRevenue >= 80000.00 THEN 'growth'
            WHEN src.AnnualRevenue >= 40000.00 THEN 'core'
            ELSE 'develop'
        END AS RevenueLabel,
        CASE
            WHEN src.OpenIssueCount >= 4 THEN 'service-hot'
            WHEN src.OpenIssueCount >= 2 THEN 'service-watch'
            WHEN src.OpenIssueCount = 1 THEN 'service-light'
            ELSE 'service-stable'
        END AS ServiceLabel,
        CASE
            WHEN src.DaysPastDue >= 30 THEN 'risk-critical'
            WHEN src.DaysPastDue >= 10 OR src.LastContactDate IS NULL THEN 'risk-watch'
            ELSE 'risk-low'
        END AS RiskLabel,
        DATEDIFF(DAY, COALESCE(src.LastContactDate, DATEADD(DAY, -90, @ReferenceDate)), @ReferenceDate) AS DaysSinceContact,
        CONCAT(
            CASE
                WHEN src.DaysPastDue >= 30 THEN 'collections'
                WHEN src.OpenIssueCount >= 3 THEN 'service-desk'
                ELSE 'account-owner'
            END,
            ':',
            UPPER(src.RegionCode)
        ) AS EscalationQueue
    FROM #AccountSignals AS src
),
FilteredSignals AS
(
    SELECT
        ps.AccountId,
        ps.NormalizedAccountName,
        ps.RegionCode,
        ps.AnnualRevenue,
        ps.OpenIssueCount,
        ps.DaysPastDue,
        ps.LastContactDate,
        ps.PreferredChannel,
        ps.AccountOwner,
        ps.RevenueLabel,
        ps.ServiceLabel,
        ps.RiskLabel,
        ps.DaysSinceContact,
        ps.EscalationQueue,
        CASE
            WHEN ps.DaysPastDue >= 30 OR ps.OpenIssueCount >= 4 OR ps.DaysSinceContact >= 45 THEN 1
            ELSE 0
        END AS IsEscalated,
        CASE @LabelMode
            WHEN 'revenue' THEN ps.RevenueLabel
            WHEN 'service' THEN ps.ServiceLabel
            WHEN 'risk' THEN ps.RiskLabel
            ELSE CONCAT(ps.RevenueLabel, ' | ', ps.ServiceLabel, ' | ', ps.RiskLabel)
        END AS ActiveLabel,
        CASE
            WHEN ps.LastContactDate IS NULL THEN 'missing-contact-date'
            WHEN ps.DaysSinceContact >= 45 THEN 'stale-contact'
            WHEN ps.DaysPastDue >= 10 THEN 'payment-follow-up'
            ELSE 'healthy-touchpoint'
        END AS ContactLabel
    FROM PreparedSignals AS ps
    WHERE (@ShowOnlyEscalated = 0 OR ps.DaysPastDue >= 30 OR ps.OpenIssueCount >= 4 OR ps.DaysSinceContact >= 45)
),
RankedSignals AS
(
    SELECT
        ROW_NUMBER() OVER (
            ORDER BY
                fs.IsEscalated DESC,
                fs.DaysPastDue DESC,
                fs.OpenIssueCount DESC,
                fs.AnnualRevenue DESC,
                fs.NormalizedAccountName
        ) AS DisplayOrder,
        fs.AccountId,
        fs.NormalizedAccountName,
        fs.RegionCode,
        fs.AnnualRevenue,
        fs.OpenIssueCount,
        fs.DaysPastDue,
        fs.LastContactDate,
        fs.PreferredChannel,
        fs.AccountOwner,
        fs.RevenueLabel,
        fs.ServiceLabel,
        fs.RiskLabel,
        fs.ActiveLabel,
        fs.ContactLabel,
        fs.DaysSinceContact,
        fs.IsEscalated,
        fs.EscalationQueue
    FROM FilteredSignals AS fs
)
SELECT
    rs.DisplayOrder,
    rs.AccountId,
    rs.NormalizedAccountName,
    rs.RegionCode,
    rs.AnnualRevenue,
    rs.OpenIssueCount,
    rs.DaysPastDue,
    rs.LastContactDate,
    rs.PreferredChannel,
    rs.AccountOwner,
    rs.RevenueLabel,
    rs.ServiceLabel,
    rs.RiskLabel,
    rs.ActiveLabel,
    rs.ContactLabel,
    rs.DaysSinceContact,
    rs.IsEscalated,
    rs.EscalationQueue
FROM RankedSignals AS rs
ORDER BY
    rs.DisplayOrder;

SELECT
    fs.ActiveLabel,
    COUNT(*) AS AccountCount,
    SUM(fs.AnnualRevenue) AS RevenueTotal,
    SUM(CASE WHEN fs.IsEscalated = 1 THEN 1 ELSE 0 END) AS EscalatedCount,
    MAX(fs.DaysPastDue) AS MaxDaysPastDue,
    STRING_AGG(CONVERT(VARCHAR(20), fs.AccountId), ', ') WITHIN GROUP (ORDER BY fs.AccountId) AS SampleAccountIds
FROM FilteredSignals AS fs
GROUP BY
    fs.ActiveLabel
ORDER BY
    RevenueTotal DESC,
    fs.ActiveLabel;

SELECT
    rs.AccountId,
    rs.NormalizedAccountName,
    rs.ActiveLabel,
    rs.ContactLabel,
    rs.EscalationQueue,
    CONCAT(
        'issues=',
        rs.OpenIssueCount,
        '; overdue=',
        rs.DaysPastDue,
        '; days_since_contact=',
        rs.DaysSinceContact
    ) AS EscalationReason
FROM RankedSignals AS rs
WHERE rs.IsEscalated = 1
ORDER BY
    rs.DaysPastDue DESC,
    rs.OpenIssueCount DESC,
    rs.AccountId;
