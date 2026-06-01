/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "ExceptIntersectAudit.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "09_Set_Operations"

purpose: >
  Erstellt eine Audit-Sicht auf Gleichheiten und Unterschiede zweier
  Ergebnismengen und zeigt dabei EXCEPT, INTERSECT und die Wirkung von
  DISTINCT-basierten Set-Operatoren auf derselben Demo-Basis.

parameters:
  - name: "@OnlyShowDifferences"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = im Detail nur Unterschiede zwischen linker und rechter Menge ausgeben"
  - name: "@IncludeSharedRows"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zusaetzlich die mit INTERSECT gefundenen gemeinsamen Zeilen ausgeben"
  - name: "@IncludeDuplicateDiagnostics"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zusaetzliches Resultset zur Duplikatdichte je Seite ausgeben"

result_sets:
  - name: "SetDifferenceDetail"
    description: "Zeigt Zeilen, die nur links, nur rechts oder auf beiden Seiten vorkommen"
  - name: "SetAuditSummary"
    description: "Verdichtet die Anzahl gemeinsamer und unterschiedlicher Zeilen"
  - name: "DuplicateDiagnostics"
    description: "Optionaler Blick auf Dubletten pro Seite vor der DISTINCT-Wirkung der Set-Operatoren"

dependencies:
  - "tempdb"
  - "temp tables"
  - "EXCEPT"
  - "INTERSECT"
  - "UNION ALL"
  - "CASE"
  - "GROUP BY"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/09_Set_Operations/SQLScripts/ExceptIntersectAudit.md"
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
    description: "Erstversion fuer eine Audit-Sicht mit EXCEPT und INTERSECT auf zwei Demo-Mengen"

notes:
  - "Die Demo-Daten enthalten absichtlich Dubletten und NULL-Werte, damit Set-Semantik sichtbar wird."
  - "EXCEPT und INTERSECT arbeiten auf DISTINCT-Basis; die optionale Duplikatdiagnostik macht diesen Effekt explizit."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @OnlyShowDifferences BIT = 0;
DECLARE @IncludeSharedRows BIT = 1;
DECLARE @IncludeDuplicateDiagnostics BIT = 1;

IF @OnlyShowDifferences NOT IN (0, 1)
BEGIN
    THROW 50000, '@OnlyShowDifferences muss 0 oder 1 sein.', 1;
END;

IF @IncludeSharedRows NOT IN (0, 1)
BEGIN
    THROW 50001, '@IncludeSharedRows muss 0 oder 1 sein.', 1;
END;

IF @IncludeDuplicateDiagnostics NOT IN (0, 1)
BEGIN
    THROW 50002, '@IncludeDuplicateDiagnostics muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #LeftSet;
DROP TABLE IF EXISTS #RightSet;

CREATE TABLE #LeftSet
(
    RegionCode      NVARCHAR(10)    NULL,
    ProductLine     NVARCHAR(30)    NULL,
    SnapshotMonth   DATE            NOT NULL,
    TicketCount     INT             NOT NULL
);

CREATE TABLE #RightSet
(
    RegionCode      NVARCHAR(10)    NULL,
    ProductLine     NVARCHAR(30)    NULL,
    SnapshotMonth   DATE            NOT NULL,
    TicketCount     INT             NOT NULL
);

INSERT INTO #LeftSet
(
    RegionCode,
    ProductLine,
    SnapshotMonth,
    TicketCount
)
VALUES
    (N'DE-N', N'Analytics', '2026-01-01', 14),
    (N'DE-S', N'Analytics', '2026-01-01', 11),
    (N'AT-E', N'Platform', '2026-01-01', 9),
    (N'CH-ZH', N'Platform', '2026-01-01', 7),
    (N'DE-N', N'Analytics', '2026-01-01', 14),
    (NULL, N'Support', '2026-01-01', 4),
    (N'AT-E', N'Support', '2026-02-01', 6);

INSERT INTO #RightSet
(
    RegionCode,
    ProductLine,
    SnapshotMonth,
    TicketCount
)
VALUES
    (N'DE-N', N'Analytics', '2026-01-01', 14),
    (N'DE-W', N'Analytics', '2026-01-01', 8),
    (N'AT-E', N'Platform', '2026-01-01', 9),
    (N'CH-ZH', N'Platform', '2026-01-01', 8),
    (NULL, N'Support', '2026-01-01', 4),
    (NULL, N'Support', '2026-01-01', 4),
    (N'AT-E', N'Support', '2026-02-01', 6);

;WITH LeftDistinct AS
(
    SELECT DISTINCT
        ls.RegionCode,
        ls.ProductLine,
        ls.SnapshotMonth,
        ls.TicketCount
    FROM #LeftSet AS ls
),
RightDistinct AS
(
    SELECT DISTINCT
        rs.RegionCode,
        rs.ProductLine,
        rs.SnapshotMonth,
        rs.TicketCount
    FROM #RightSet AS rs
),
LeftOnly AS
(
    SELECT
        ld.RegionCode,
        ld.ProductLine,
        ld.SnapshotMonth,
        ld.TicketCount
    FROM LeftDistinct AS ld
    EXCEPT
    SELECT
        rd.RegionCode,
        rd.ProductLine,
        rd.SnapshotMonth,
        rd.TicketCount
    FROM RightDistinct AS rd
),
RightOnly AS
(
    SELECT
        rd.RegionCode,
        rd.ProductLine,
        rd.SnapshotMonth,
        rd.TicketCount
    FROM RightDistinct AS rd
    EXCEPT
    SELECT
        ld.RegionCode,
        ld.ProductLine,
        ld.SnapshotMonth,
        ld.TicketCount
    FROM LeftDistinct AS ld
),
SharedRows AS
(
    SELECT
        ld.RegionCode,
        ld.ProductLine,
        ld.SnapshotMonth,
        ld.TicketCount
    FROM LeftDistinct AS ld
    INTERSECT
    SELECT
        rd.RegionCode,
        rd.ProductLine,
        rd.SnapshotMonth,
        rd.TicketCount
    FROM RightDistinct AS rd
),
SetDifferenceDetail AS
(
    SELECT
        N'left_only' AS AuditCategory,
        lo.RegionCode,
        lo.ProductLine,
        lo.SnapshotMonth,
        lo.TicketCount
    FROM LeftOnly AS lo

    UNION ALL

    SELECT
        N'right_only' AS AuditCategory,
        ro.RegionCode,
        ro.ProductLine,
        ro.SnapshotMonth,
        ro.TicketCount
    FROM RightOnly AS ro

    UNION ALL

    SELECT
        N'in_both' AS AuditCategory,
        sr.RegionCode,
        sr.ProductLine,
        sr.SnapshotMonth,
        sr.TicketCount
    FROM SharedRows AS sr
),
SetAuditSummary AS
(
    SELECT
        detail.AuditCategory,
        COUNT(*) AS RowCount
    FROM SetDifferenceDetail AS detail
    GROUP BY
        detail.AuditCategory
),
DuplicateDiagnostics AS
(
    SELECT
        src.SourceName,
        src.RegionCode,
        src.ProductLine,
        src.SnapshotMonth,
        src.TicketCount,
        COUNT(*) AS DuplicateCount
    FROM
    (
        SELECT
            N'left' AS SourceName,
            ls.RegionCode,
            ls.ProductLine,
            ls.SnapshotMonth,
            ls.TicketCount
        FROM #LeftSet AS ls

        UNION ALL

        SELECT
            N'right' AS SourceName,
            rs.RegionCode,
            rs.ProductLine,
            rs.SnapshotMonth,
            rs.TicketCount
        FROM #RightSet AS rs
    ) AS src
    GROUP BY
        src.SourceName,
        src.RegionCode,
        src.ProductLine,
        src.SnapshotMonth,
        src.TicketCount
    HAVING COUNT(*) > 1
),
FilteredDetail AS
(
    SELECT
        detail.AuditCategory,
        detail.RegionCode,
        detail.ProductLine,
        detail.SnapshotMonth,
        detail.TicketCount
    FROM SetDifferenceDetail AS detail
    WHERE (@IncludeSharedRows = 1 OR detail.AuditCategory <> N'in_both')
      AND (@OnlyShowDifferences = 0 OR detail.AuditCategory <> N'in_both')
)
SELECT
    detail.AuditCategory,
    detail.RegionCode,
    detail.ProductLine,
    detail.SnapshotMonth,
    detail.TicketCount
FROM FilteredDetail AS detail
ORDER BY
    CASE detail.AuditCategory
        WHEN N'left_only' THEN 1
        WHEN N'right_only' THEN 2
        ELSE 3
    END,
    COALESCE(detail.RegionCode, N'<NULL>'),
    detail.ProductLine,
    detail.SnapshotMonth,
    detail.TicketCount;

SELECT
    summary.AuditCategory,
    summary.RowCount
FROM SetAuditSummary AS summary
WHERE @IncludeSharedRows = 1
   OR summary.AuditCategory <> N'in_both'
ORDER BY
    CASE summary.AuditCategory
        WHEN N'left_only' THEN 1
        WHEN N'right_only' THEN 2
        ELSE 3
    END;

IF @IncludeDuplicateDiagnostics = 1
BEGIN
    SELECT
        diagnostics.SourceName,
        diagnostics.RegionCode,
        diagnostics.ProductLine,
        diagnostics.SnapshotMonth,
        diagnostics.TicketCount,
        diagnostics.DuplicateCount
    FROM DuplicateDiagnostics AS diagnostics
    ORDER BY
        diagnostics.SourceName,
        COALESCE(diagnostics.RegionCode, N'<NULL>'),
        diagnostics.ProductLine,
        diagnostics.SnapshotMonth,
        diagnostics.TicketCount;
END;
