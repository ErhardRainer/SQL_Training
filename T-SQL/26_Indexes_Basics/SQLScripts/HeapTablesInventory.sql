/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "HeapTablesInventory.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "26_Indexes_Basics"
purpose: >
  Inventarisiert Heap-Tabellen der aktuellen Datenbank und markiert
  konservative Review-Kandidaten fuer Clustering-, Primary-Key- oder
  Weiterleitungs-Analysen.
parameters:
  - name: "@SchemaName"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Optionaler Filter auf ein Schema"
  - name: "@TableName"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Optionaler Filter auf einen Tabellennamen"
  - name: "@OnlyCandidates"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = nur Heaps mit erkennbarem Review-Signal zeigen, 0 = alle Heaps inventarisieren"
  - name: "@MinRowCount"
    sql_type: "BIGINT"
    direction: "IN"
    required: false
    description: "Mindestanzahl geschaetzter Zeilen fuer groessere Heap-Kandidaten"
result_sets:
  - name: "HeapTableInventory"
    description: "Detailinventur aller gefilterten Heaps mit Nutzung, physischer Groesse und Review-Klassifikation"
  - name: "HeapCandidateSummary"
    description: "Verdichtete Sicht auf erkannte Heap-Kandidatenklassen mit Anzahl, Zeilen und Seiten"
dependencies:
  - "sys.tables"
  - "sys.schemas"
  - "sys.indexes"
  - "sys.dm_db_partition_stats"
  - "sys.dm_db_index_usage_stats"
  - "sys.dm_db_index_physical_stats"
  - "CTE"
safety:
  level: "read-only"
  writes_data: false
documentation:
  markdown_file: "T-SQL/26_Indexes_Basics/SQLScripts/HeapTablesInventory.md"
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
    description: "Erstversion fuer die Inventur und Review-Priorisierung von Heap-Tabellen"
notes:
  - "Die Diagnose liest nur Kataloge und DMVs der aktuellen Datenbank."
  - "Ein Review-Signal fuer Heaps ist keine automatische Empfehlung, sofort einen Clustered Index anzulegen."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @SchemaName SYSNAME = NULL;
DECLARE @TableName SYSNAME = NULL;
DECLARE @OnlyCandidates BIT = 1;
DECLARE @MinRowCount BIGINT = 10000;

IF @OnlyCandidates NOT IN (0, 1)
BEGIN
    THROW 50000, '@OnlyCandidates muss 0 oder 1 sein.', 1;
END;

IF @MinRowCount < 0
BEGIN
    THROW 50000, '@MinRowCount darf nicht negativ sein.', 1;
END;

;WITH HeapBase AS
(
    SELECT
        s.name AS SchemaName,
        t.name AS TableName,
        t.object_id,
        i.index_id,
        i.name AS HeapName,
        SUM(ps.row_count) AS EstimatedRowCount,
        SUM(ps.used_page_count) AS UsedPageCount,
        SUM(ps.reserved_page_count) AS ReservedPageCount
    FROM sys.tables AS t
    INNER JOIN sys.schemas AS s
        ON s.schema_id = t.schema_id
    INNER JOIN sys.indexes AS i
        ON i.object_id = t.object_id
       AND i.index_id = 0
       AND i.type = 0
    INNER JOIN sys.dm_db_partition_stats AS ps
        ON ps.object_id = t.object_id
       AND ps.index_id = i.index_id
    WHERE t.is_ms_shipped = 0
      AND (@SchemaName IS NULL OR s.name = @SchemaName)
      AND (@TableName IS NULL OR t.name = @TableName)
    GROUP BY
        s.name,
        t.name,
        t.object_id,
        i.index_id,
        i.name
),
HeapPhysicalStats AS
(
    SELECT
        ips.object_id,
        ips.index_id,
        SUM(ips.forwarded_record_count) AS ForwardedRecordCount,
        MAX(ips.avg_fragmentation_in_percent) AS AvgFragmentationPercent,
        MAX(ips.avg_page_space_used_in_percent) AS AvgPageSpaceUsedPercent,
        SUM(ips.page_count) AS PhysicalPageCount
    FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') AS ips
    WHERE ips.index_id = 0
    GROUP BY
        ips.object_id,
        ips.index_id
),
NonclusteredIndexSummary AS
(
    SELECT
        i.object_id,
        COUNT(*) AS NonclusteredIndexCount
    FROM sys.indexes AS i
    WHERE i.type = 2
      AND i.is_hypothetical = 0
      AND i.is_disabled = 0
    GROUP BY
        i.object_id
),
KeyConstraintSummary AS
(
    SELECT
        i.object_id,
        MAX(CASE WHEN i.is_primary_key = 1 THEN 1 ELSE 0 END) AS HasPrimaryKey,
        MAX(CASE WHEN i.is_unique_constraint = 1 THEN 1 ELSE 0 END) AS HasUniqueConstraint
    FROM sys.indexes AS i
    WHERE i.is_hypothetical = 0
    GROUP BY
        i.object_id
),
UsageSummary AS
(
    SELECT
        us.object_id,
        us.index_id,
        SUM(us.user_seeks) AS UserSeeks,
        SUM(us.user_scans) AS UserScans,
        SUM(us.user_lookups) AS UserLookups,
        SUM(us.user_updates) AS UserUpdates
    FROM sys.dm_db_index_usage_stats AS us
    WHERE us.database_id = DB_ID()
      AND us.index_id = 0
    GROUP BY
        us.object_id,
        us.index_id
),
HeapAssessment AS
(
    SELECT
        DB_NAME() AS DatabaseName,
        hb.SchemaName,
        hb.TableName,
        hb.HeapName,
        hb.EstimatedRowCount,
        hb.UsedPageCount,
        hb.ReservedPageCount,
        COALESCE(hps.PhysicalPageCount, hb.UsedPageCount) AS PhysicalPageCount,
        COALESCE(hps.ForwardedRecordCount, 0) AS ForwardedRecordCount,
        CAST(COALESCE(hps.AvgFragmentationPercent, 0.0) AS DECIMAL(6,2)) AS AvgFragmentationPercent,
        CAST(COALESCE(hps.AvgPageSpaceUsedPercent, 0.0) AS DECIMAL(6,2)) AS AvgPageSpaceUsedPercent,
        COALESCE(us.UserSeeks, 0) AS UserSeeks,
        COALESCE(us.UserScans, 0) AS UserScans,
        COALESCE(us.UserLookups, 0) AS UserLookups,
        COALESCE(us.UserUpdates, 0) AS UserUpdates,
        COALESCE(nc.NonclusteredIndexCount, 0) AS NonclusteredIndexCount,
        CAST(COALESCE(kc.HasPrimaryKey, 0) AS BIT) AS HasPrimaryKey,
        CAST(COALESCE(kc.HasUniqueConstraint, 0) AS BIT) AS HasUniqueConstraint,
        CAST(CASE WHEN COALESCE(hps.ForwardedRecordCount, 0) > 0 THEN 1 ELSE 0 END AS BIT) AS HasForwardedRecords,
        CAST(
            CASE
                WHEN COALESCE(hps.ForwardedRecordCount, 0) > 1000 THEN 1
                ELSE 0
            END AS BIT
        ) AS HasHeavyForwarding,
        CASE
            WHEN COALESCE(hps.ForwardedRecordCount, 0) > 1000 THEN 'forwarded-record-hotspot'
            WHEN hb.EstimatedRowCount >= @MinRowCount
             AND COALESCE(us.UserScans, 0) >= COALESCE(us.UserSeeks, 0)
             AND COALESCE(kc.HasPrimaryKey, 0) = 0
                THEN 'large-scan-oriented-heap'
            WHEN hb.EstimatedRowCount >= @MinRowCount
             AND COALESCE(nc.NonclusteredIndexCount, 0) = 0
                THEN 'large-heap-without-nci'
            WHEN COALESCE(kc.HasPrimaryKey, 0) = 0
             AND COALESCE(kc.HasUniqueConstraint, 0) = 0
                THEN 'heap-without-key-constraint'
            ELSE 'inventory-only'
        END AS ReviewClass,
        CASE
            WHEN COALESCE(hps.ForwardedRecordCount, 0) > 1000
                THEN 'Viele Forwarded Records deuten auf teure Bookmark- und Scan-Pfade im Heap hin.'
            WHEN hb.EstimatedRowCount >= @MinRowCount
             AND COALESCE(us.UserScans, 0) >= COALESCE(us.UserSeeks, 0)
             AND COALESCE(kc.HasPrimaryKey, 0) = 0
                THEN 'Groesserer Heap mit scan-lastiger Nutzung und ohne Primary Key; Clustering-Frage lohnt sich fuer ein Review.'
            WHEN hb.EstimatedRowCount >= @MinRowCount
             AND COALESCE(nc.NonclusteredIndexCount, 0) = 0
                THEN 'Groesserer Heap ohne aktive Nonclustered-Indizes; Zugriffswege und Tabellenrolle sollten geprueft werden.'
            WHEN COALESCE(kc.HasPrimaryKey, 0) = 0
             AND COALESCE(kc.HasUniqueConstraint, 0) = 0
                THEN 'Heap besitzt keine sichtbare Key-Constraint und sollte fachlich auf stabile Zeilenidentifikation geprueft werden.'
            ELSE 'Heap wird nur inventarisiert; kein starkes Review-Signal erkannt.'
        END AS ReviewReason,
        CASE
            WHEN COALESCE(hps.ForwardedRecordCount, 0) > 1000
                THEN 'Forwarded Records, Update-Muster und moegliche Clustered-Key-Optionen analysieren.'
            WHEN hb.EstimatedRowCount >= @MinRowCount
             AND COALESCE(us.UserScans, 0) >= COALESCE(us.UserSeeks, 0)
             AND COALESCE(kc.HasPrimaryKey, 0) = 0
                THEN 'Tabellenzugriffe, Sortierbedarf und moegliche Clustered-Index-Spalten gemeinsam pruefen.'
            WHEN hb.EstimatedRowCount >= @MinRowCount
             AND COALESCE(nc.NonclusteredIndexCount, 0) = 0
                THEN 'Workload pruefen und bewerten, ob Heap bewusst minimal gehalten wird oder Indexierung fehlt.'
            WHEN COALESCE(kc.HasPrimaryKey, 0) = 0
             AND COALESCE(kc.HasUniqueConstraint, 0) = 0
                THEN 'Fachschluessel und Datenpflegeprozess pruefen; Heap muss nicht falsch sein, aber eine eindeutige Identifikation sollte klar sein.'
            ELSE 'Keine unmittelbare Aktion.'
        END AS SuggestedAction
    FROM HeapBase AS hb
    LEFT JOIN HeapPhysicalStats AS hps
        ON hps.object_id = hb.object_id
       AND hps.index_id = hb.index_id
    LEFT JOIN UsageSummary AS us
        ON us.object_id = hb.object_id
       AND us.index_id = hb.index_id
    LEFT JOIN NonclusteredIndexSummary AS nc
        ON nc.object_id = hb.object_id
    LEFT JOIN KeyConstraintSummary AS kc
        ON kc.object_id = hb.object_id
)
SELECT
    ha.DatabaseName,
    ha.SchemaName,
    ha.TableName,
    COALESCE(ha.HeapName, '(heap)') AS HeapName,
    ha.EstimatedRowCount,
    ha.UsedPageCount,
    ha.ReservedPageCount,
    ha.PhysicalPageCount,
    ha.ForwardedRecordCount,
    ha.AvgFragmentationPercent,
    ha.AvgPageSpaceUsedPercent,
    ha.UserSeeks,
    ha.UserScans,
    ha.UserLookups,
    ha.UserUpdates,
    ha.NonclusteredIndexCount,
    ha.HasPrimaryKey,
    ha.HasUniqueConstraint,
    ha.HasForwardedRecords,
    ha.HasHeavyForwarding,
    ha.ReviewClass,
    ha.ReviewReason,
    ha.SuggestedAction
FROM HeapAssessment AS ha
WHERE @OnlyCandidates = 0
   OR ha.ReviewClass <> 'inventory-only'
ORDER BY
    CASE ha.ReviewClass
        WHEN 'forwarded-record-hotspot' THEN 1
        WHEN 'large-scan-oriented-heap' THEN 2
        WHEN 'large-heap-without-nci' THEN 3
        WHEN 'heap-without-key-constraint' THEN 4
        ELSE 5
    END,
    ha.ForwardedRecordCount DESC,
    ha.EstimatedRowCount DESC,
    ha.SchemaName,
    ha.TableName;

SELECT
    ha.DatabaseName,
    ha.ReviewClass,
    COUNT(*) AS HeapCount,
    SUM(ha.EstimatedRowCount) AS TotalEstimatedRows,
    SUM(ha.PhysicalPageCount) AS TotalPhysicalPages,
    SUM(ha.ForwardedRecordCount) AS TotalForwardedRecords,
    SUM(ha.NonclusteredIndexCount) AS TotalNonclusteredIndexes
FROM HeapAssessment AS ha
WHERE ha.ReviewClass <> 'inventory-only'
GROUP BY
    ha.DatabaseName,
    ha.ReviewClass
ORDER BY
    HeapCount DESC,
    TotalEstimatedRows DESC,
    ha.ReviewClass;
