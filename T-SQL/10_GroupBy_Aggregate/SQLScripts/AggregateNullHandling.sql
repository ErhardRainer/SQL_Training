/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "AggregateNullHandling.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "10_GroupBy_Aggregate"

purpose: >
  Demonstriert das Verhalten von COUNT, SUM, AVG, MIN und MAX bei NULL-Werten
  sowie bei Gruppen ohne passende Detailzeilen.

parameters:
  - name: "@IncludeDetailPreview"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zeigt die Demo-Daten mit markierten NULL-Werten vor der Aggregation"
  - name: "@HighlightInactiveGroups"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = markiert Gruppen ohne aktive Umsatzzeilen explizit im Ergebnis"

result_sets:
  - name: "SalesDetailPreview"
    description: "Optionale Vorschau der Demo-Daten mit NULL-Werten und Teamzuordnung"
  - name: "NullHandlingByTeam"
    description: "Zeigt je Team den Unterschied zwischen COUNT(*), COUNT(Spalte) und Aggregaten ueber NULL-Werte"
  - name: "AggregateBehaviorReference"
    description: "Kompakte Referenz zu den beobachteten Regeln fuer NULL und leere Gruppen"

dependencies:
  - "tempdb"
  - "LEFT JOIN"
  - "GROUP BY"
  - "COUNT()"
  - "SUM()"
  - "AVG()"
  - "MIN()"
  - "MAX()"
  - "CASE"
  - "COALESCE()"
  - "DROP TABLE IF EXISTS"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/10_GroupBy_Aggregate/SQLScripts/AggregateNullHandling.md"
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
    description: "Erstversion eines didaktischen Labs fuer NULL-Verhalten in Aggregaten und leeren Gruppen"

notes:
  - "Die Erstversion verwendet lokale Temp-Tabellen fuer Teams und Umsatzzeilen"
  - "Leere Gruppen werden ueber LEFT JOIN von #SalesTeams zu #SalesFacts sichtbar gemacht"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @IncludeDetailPreview BIT = 1;
DECLARE @HighlightInactiveGroups BIT = 1;

IF @IncludeDetailPreview NOT IN (0, 1)
BEGIN
    THROW 50000, '@IncludeDetailPreview muss 0 oder 1 sein.', 1;
END;

IF @HighlightInactiveGroups NOT IN (0, 1)
BEGIN
    THROW 50001, '@HighlightInactiveGroups muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #SalesTeams;
DROP TABLE IF EXISTS #SalesFacts;

CREATE TABLE #SalesTeams
(
    TeamID       INT          NOT NULL,
    TeamName     VARCHAR(30)  NOT NULL,
    RegionName   VARCHAR(20)  NOT NULL
);

CREATE TABLE #SalesFacts
(
    TeamID         INT             NOT NULL,
    OrderMonth     DATE            NOT NULL,
    OrderCount     INT             NULL,
    RevenueAmount  DECIMAL(12,2)   NULL,
    DiscountAmount DECIMAL(12,2)   NULL
);

INSERT INTO #SalesTeams
(
    TeamID,
    TeamName,
    RegionName
)
VALUES
    (1, 'North Alpha', 'North'),
    (2, 'North Beta',  'North'),
    (3, 'South Gamma', 'South'),
    (4, 'West Delta',  'West'),
    (5, 'East Epsilon', 'East');

INSERT INTO #SalesFacts
(
    TeamID,
    OrderMonth,
    OrderCount,
    RevenueAmount,
    DiscountAmount
)
VALUES
    (1, '2026-01-01', 12, 2400.00, 120.00),
    (1, '2026-02-01', 10, NULL,    90.00),
    (1, '2026-03-01', 14, 3150.00, NULL),
    (2, '2026-01-01',  8, 1650.00, 70.00),
    (2, '2026-02-01',  0, NULL,    NULL),
    (2, '2026-03-01',  7, 1490.00, 55.00),
    (3, '2026-01-01', 11, 2100.00, 110.00),
    (3, '2026-02-01',  9, 1980.00, NULL),
    (3, '2026-03-01', 13, NULL,    65.00),
    (5, '2026-01-01',  6, NULL,    40.00),
    (5, '2026-02-01',  5, NULL,    NULL);

IF @IncludeDetailPreview = 1
BEGIN
    SELECT
        st.TeamName,
        st.RegionName,
        sf.OrderMonth,
        sf.OrderCount,
        sf.RevenueAmount,
        sf.DiscountAmount,
        CASE
            WHEN sf.RevenueAmount IS NULL THEN 'RevenueIsNull'
            ELSE 'RevenuePresent'
        END AS RevenueState,
        CASE
            WHEN sf.DiscountAmount IS NULL THEN 'DiscountIsNull'
            ELSE 'DiscountPresent'
        END AS DiscountState
    FROM #SalesTeams AS st
    LEFT JOIN #SalesFacts AS sf
        ON sf.TeamID = st.TeamID
    ORDER BY
        st.TeamID,
        sf.OrderMonth;
END;

SELECT
    st.TeamName,
    st.RegionName,
    COUNT(*) AS JoinedRows,
    COUNT(sf.OrderMonth) AS FactRows,
    COUNT(sf.RevenueAmount) AS RevenueValueCount,
    COUNT(sf.DiscountAmount) AS DiscountValueCount,
    SUM(sf.RevenueAmount) AS RevenueSumIgnoringNulls,
    AVG(sf.RevenueAmount) AS RevenueAverageIgnoringNulls,
    MIN(sf.RevenueAmount) AS RevenueMinimumIgnoringNulls,
    MAX(sf.RevenueAmount) AS RevenueMaximumIgnoringNulls,
    SUM(sf.DiscountAmount) AS DiscountSumIgnoringNulls,
    AVG(sf.DiscountAmount) AS DiscountAverageIgnoringNulls,
    COALESCE(SUM(sf.RevenueAmount), 0.00) AS RevenueSumWithFallback,
    CASE
        WHEN COUNT(sf.OrderMonth) = 0 THEN 'no_fact_rows'
        WHEN COUNT(sf.RevenueAmount) = 0 THEN 'fact_rows_but_all_revenue_null'
        ELSE 'revenue_values_present'
    END AS RevenueObservation,
    CASE
        WHEN @HighlightInactiveGroups = 1 AND COUNT(sf.OrderMonth) = 0 THEN 'empty_group_visible_via_left_join'
        WHEN @HighlightInactiveGroups = 1 AND COUNT(sf.OrderMonth) > 0 THEN 'group_has_fact_rows'
        ELSE 'highlight_disabled'
    END AS GroupStatus
FROM #SalesTeams AS st
LEFT JOIN #SalesFacts AS sf
    ON sf.TeamID = st.TeamID
GROUP BY
    st.TeamName,
    st.RegionName
ORDER BY
    st.RegionName,
    st.TeamName;

SELECT
    RuleLabel,
    ObservedBehavior,
    ConsequenceForReports
FROM
(
    VALUES
        (
            'COUNT(*)',
            'Zaehlt nach dem LEFT JOIN auch die Platzhalterzeile einer leeren Gruppe.',
            'Fuer echte Faktzeilen besser COUNT(sf.OrderMonth) oder COUNT(PrimaryKey) verwenden.'
        ),
        (
            'COUNT(column)',
            'Zaehlt nur nicht-NULL Werte der angegebenen Spalte.',
            'Geeignet, um belegte Werte getrennt von vorhandenen Zeilen zu betrachten.'
        ),
        (
            'SUM/AVG/MIN/MAX',
            'Ignorieren NULL-Eintraege, liefern aber bei ausschliesslich NULL oder ohne Faktzeile selbst NULL.',
            'Oft ist COALESCE fuer Berichtsspalten oder Kennzahlenvergleich sinnvoll.'
        ),
        (
            'LEFT JOIN mit Dimension',
            'Macht Teams ohne Detaildaten als leere Gruppe sichtbar.',
            'Hilfreich fuer Vollstaendigkeitspruefungen und Zero-Activity-Reports.'
        )
) AS reference_data
(
    RuleLabel,
    ObservedBehavior,
    ConsequenceForReports
)
ORDER BY
    RuleLabel;
