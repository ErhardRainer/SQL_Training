/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "SetUnionOrderReview.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "09_Set_Operations"

purpose: >
  Macht in einer didaktischen UNION-Szenerie sichtbar, wie lokale
  Branch-Sortierungen, finale ORDER-BY-Strategien und DISTINCT-Semantik
  die wahrgenommene Reihenfolge eines kombinierten Resultsets
  beeinflussen.

parameters:
  - name: "@PreferredOutputOrder"
    sql_type: "NVARCHAR(30)"
    direction: "IN"
    required: false
    description: "BUSINESS = sortiert nach Fachschluessel, SOURCE_THEN_LOCAL = behaelt Branch und lokale Reihenfolge sichtbar"
  - name: "@IncludeDistinctProjection"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zeigt zusaetzlich die distincte UNION-Projektion ohne Branch-Metadaten"
  - name: "@ShowRawBranches"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = gibt die vorbereiteten Branch-Zeilen mit lokaler Sortierung zusaetzlich aus"

result_sets:
  - name: "OrderReviewSummary"
    description: "Fasst Branch-Zeilen, distincte Business-Zeilen und die gewaehlte finale Sortierstrategie zusammen"
  - name: "OrderSensitivityReview"
    description: "Vergleicht lokale Branch-Reihenfolge mit der gewaehlten finalen Anzeige-Reihenfolge"
  - name: "DistinctUnionProjection"
    description: "Optionale distincte UNION-Projektion ohne Branch-Metadaten als Vergleich zur UNION-ALL-Sicht"
  - name: "RawBranchRows"
    description: "Optionale Ausgangszeilen der linken und rechten Branches inklusive lokaler Sortierinformation"

dependencies:
  - "tempdb"
  - "UNION"
  - "UNION ALL"
  - "ROW_NUMBER()"
  - "CASE"
  - "DROP TABLE IF EXISTS"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/09_Set_Operations/SQLScripts/SetUnionOrderReview.md"
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
    description: "Erstversion fuer Sortierungs- und Reihenfolgereviews bei UNION-Szenarien"

notes:
  - "Die Erstversion verwendet Demo-Daten in einer lokalen Temp-Tabelle"
  - "Distincte UNION-Projektionen werden bewusst ohne Branch-Metadaten gezeigt, damit Sortierwirkungen sichtbar bleiben"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @PreferredOutputOrder NVARCHAR(30) = N'BUSINESS';
DECLARE @IncludeDistinctProjection BIT = 1;
DECLARE @ShowRawBranches BIT = 1;

IF UPPER(@PreferredOutputOrder) NOT IN (N'BUSINESS', N'SOURCE_THEN_LOCAL')
BEGIN
    THROW 50000, '@PreferredOutputOrder muss BUSINESS oder SOURCE_THEN_LOCAL sein.', 1;
END;

IF @IncludeDistinctProjection NOT IN (0, 1)
BEGIN
    THROW 50001, '@IncludeDistinctProjection muss 0 oder 1 sein.', 1;
END;

IF @ShowRawBranches NOT IN (0, 1)
BEGIN
    THROW 50002, '@ShowRawBranches muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #OrderReviewInput;

CREATE TABLE #OrderReviewInput
(
    SourceBranch         NVARCHAR(10)    NOT NULL,
    StageName            NVARCHAR(20)    NOT NULL,
    LocalSortWeight      INT             NOT NULL,
    TicketID             INT             NOT NULL,
    BusinessPriority     INT             NOT NULL,
    EventLabel           NVARCHAR(40)    NOT NULL
);

INSERT INTO #OrderReviewInput
(
    SourceBranch,
    StageName,
    LocalSortWeight,
    TicketID,
    BusinessPriority,
    EventLabel
)
VALUES
    (N'LEFT',  N'capture', 10, 101, 2, N'Intake approved'),
    (N'LEFT',  N'capture', 20, 102, 1, N'Invoice staged'),
    (N'LEFT',  N'capture', 30, 103, 3, N'Customer matched'),
    (N'RIGHT', N'replay',  10, 102, 1, N'Invoice staged'),
    (N'RIGHT', N'replay',  20, 104, 2, N'Refund queued'),
    (N'RIGHT', N'replay',  30, 105, 1, N'Risk note added');

;WITH BranchRows AS
(
    SELECT
        input.SourceBranch,
        input.StageName,
        ROW_NUMBER() OVER
        (
            PARTITION BY input.SourceBranch
            ORDER BY
                input.LocalSortWeight,
                input.TicketID
        ) AS LocalBranchOrder,
        input.LocalSortWeight,
        input.TicketID,
        input.BusinessPriority,
        input.EventLabel
    FROM #OrderReviewInput AS input
),
UnionAllRows AS
(
    SELECT
        branch.SourceBranch,
        branch.StageName,
        branch.LocalBranchOrder,
        branch.LocalSortWeight,
        branch.TicketID,
        branch.BusinessPriority,
        branch.EventLabel,
        ROW_NUMBER() OVER
        (
            ORDER BY
                CASE branch.SourceBranch
                    WHEN N'LEFT' THEN 1
                    ELSE 2
                END,
                branch.LocalBranchOrder
        ) AS BranchSequenceOrder
    FROM BranchRows AS branch
),
FinalOrderedRows AS
(
    SELECT
        union_all.SourceBranch,
        union_all.StageName,
        union_all.LocalBranchOrder,
        union_all.LocalSortWeight,
        union_all.TicketID,
        union_all.BusinessPriority,
        union_all.EventLabel,
        union_all.BranchSequenceOrder,
        ROW_NUMBER() OVER
        (
            ORDER BY
                CASE
                    WHEN UPPER(@PreferredOutputOrder) = N'SOURCE_THEN_LOCAL' AND union_all.SourceBranch = N'LEFT' THEN 1
                    WHEN UPPER(@PreferredOutputOrder) = N'SOURCE_THEN_LOCAL' AND union_all.SourceBranch = N'RIGHT' THEN 2
                    ELSE 0
                END,
                CASE
                    WHEN UPPER(@PreferredOutputOrder) = N'SOURCE_THEN_LOCAL' THEN union_all.LocalBranchOrder
                    ELSE union_all.BusinessPriority
                END,
                CASE
                    WHEN UPPER(@PreferredOutputOrder) = N'SOURCE_THEN_LOCAL' THEN union_all.TicketID
                    ELSE union_all.TicketID
                END,
                union_all.SourceBranch
        ) AS FinalDisplayOrder
    FROM UnionAllRows AS union_all
),
DistinctUnionRows AS
(
    SELECT
        left_branch.TicketID,
        left_branch.BusinessPriority,
        left_branch.EventLabel
    FROM BranchRows AS left_branch
    WHERE left_branch.SourceBranch = N'LEFT'

    UNION

    SELECT
        right_branch.TicketID,
        right_branch.BusinessPriority,
        right_branch.EventLabel
    FROM BranchRows AS right_branch
    WHERE right_branch.SourceBranch = N'RIGHT'
)
SELECT
    @PreferredOutputOrder AS preferred_output_order,
    (SELECT COUNT(*) FROM BranchRows) AS branch_row_count,
    (SELECT COUNT(*) FROM FinalOrderedRows) AS union_all_row_count,
    (SELECT COUNT(*) FROM DistinctUnionRows) AS union_distinct_row_count,
    (SELECT COUNT(*) FROM BranchRows WHERE SourceBranch = N'LEFT') AS left_branch_rows,
    (SELECT COUNT(*) FROM BranchRows WHERE SourceBranch = N'RIGHT') AS right_branch_rows,
    CASE
        WHEN EXISTS
        (
            SELECT 1
            FROM FinalOrderedRows AS review
            WHERE review.BranchSequenceOrder <> review.FinalDisplayOrder
        )
            THEN N'Final ORDER BY changes the visible sequence compared with branch-local order.'
        ELSE N'Current final ORDER BY preserves the visible branch sequence.'
    END AS ordering_highlight,
    N'ORDER BY wirkt erst auf das kombinierte Resultset; lokale Branch-Reihenfolgen bleiben nur erhalten, wenn sie explizit in die finale Sortierung einfliessen.' AS takeaway
;

SELECT
    review.SourceBranch,
    review.StageName,
    review.BranchSequenceOrder,
    review.LocalBranchOrder,
    review.FinalDisplayOrder,
    review.TicketID,
    review.BusinessPriority,
    review.EventLabel,
    CASE
        WHEN review.BranchSequenceOrder = review.FinalDisplayOrder
            THEN N'stable'
        ELSE N'reordered'
    END AS order_effect,
    CASE
        WHEN UPPER(@PreferredOutputOrder) = N'BUSINESS'
            THEN N'Finales ORDER BY priorisiert BusinessPriority und TicketID.'
        ELSE N'Finales ORDER BY priorisiert SourceBranch und lokale Branch-Reihenfolge.'
    END AS interpretation
FROM FinalOrderedRows AS review
ORDER BY
    review.FinalDisplayOrder;

IF @IncludeDistinctProjection = 1
BEGIN
    SELECT
        distinct_rows.TicketID,
        distinct_rows.BusinessPriority,
        distinct_rows.EventLabel
    FROM DistinctUnionRows AS distinct_rows
    ORDER BY
        distinct_rows.BusinessPriority,
        distinct_rows.TicketID;
END;

IF @ShowRawBranches = 1
BEGIN
    SELECT
        branch.SourceBranch,
        branch.StageName,
        branch.LocalBranchOrder,
        branch.LocalSortWeight,
        branch.TicketID,
        branch.BusinessPriority,
        branch.EventLabel
    FROM BranchRows AS branch
    ORDER BY
        CASE branch.SourceBranch
            WHEN N'LEFT' THEN 1
            ELSE 2
        END,
        branch.LocalBranchOrder;
END;
