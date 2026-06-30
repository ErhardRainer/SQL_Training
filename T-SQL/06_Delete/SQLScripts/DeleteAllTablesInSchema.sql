/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "DeleteAllTablesInSchema.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "06_Delete"

purpose: >
  Leert alle Benutzertabellen einer Datenbank (oder eines bestimmten Schemas)
  mit DELETE FROM. Im Gegensatz zu TRUNCATE funktioniert DELETE auch bei
  aktivierten Foreign Keys (Reihenfolge: Kind- vor Elterntabelle), loest
  Trigger aus und kann in einer Transaktion rueckgaengig gemacht werden.
  IDENTITY-Zaehler bleiben erhalten. Ein Preview-Modus zeigt die Zieltabellen,
  ohne Daten zu veraendern.

parameters:
  - name: "@SchemaFilter"
    sql_type: "NVARCHAR(128)"
    direction: "IN"
    required: false
    description: "Nur Tabellen dieses Schemas werden beruecksichtigt. NULL = alle Schemas."
  - name: "@TableList"
    sql_type: "NVARCHAR(MAX)"
    direction: "IN"
    required: false
    description: "Kommagetrennte Liste von Tabellennamen (ohne Schema). NULL = alle Tabellen."
  - name: "@PreviewOnly"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 zeigt nur die Kandidaten (Default), 0 fuehrt DELETE aus."
  - name: "@ApprovalToken"
    sql_type: "NVARCHAR(50)"
    direction: "IN"
    required: false
    description: "Muss 'DELETE-ALL-CONFIRMED' lauten, um den Ausfuehrungsmodus freizuschalten."
  - name: "@UseTransaction"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = alle DELETEs in einer Transaktion (Rollback moeglich). 0 = einzeln."

result_sets:
  - name: "DeleteTargets"
    description: "Liste aller Tabellen in der geplanten Loeschreihenfolge."
  - name: "DeleteAudit"
    description: "Protokoll der geloeschten Zeilen je Tabelle."
  - name: "ExecutionSummary"
    description: "Zusammenfassung: Modus, Tabellenzahl, Gesamtzeilen, Dauer."

dependencies:
  - "sys.tables"
  - "sys.schemas"
  - "sys.foreign_keys"
  - "sys.foreign_key_columns"
  - "DELETE FROM"
  - "Dynamic SQL (sp_executesql)"
  - "TRY/CATCH"
  - "Transactions"
  - "CURSOR"
  - "Topologische Sortierung via FK-Graph"

safety:
  level: "destructive-write-real-tables"
  writes_data: true

documentation:
  markdown_file: "T-SQL/06_Delete/SQLScripts/DeleteAllTablesInSchema.md"
  sync_blocks:
    - "SUMMARY_TABLE"
    - "PARAMETERS_TABLE"
    - "DEPENDENCIES_LIST"
    - "VERSION_HISTORY_TABLE"
    - "SQL_CODE"

main_responsible:
  name: "Erhard Rainer"
  initials: "ER"

version_history:
  - version: "1.0"
    date: "2026-06-30"
    user: "ER"
    description: "Erstversion: DELETE aller Benutzertabellen mit FK-Reihenfolge und Preview-Modus"

notes:
  - "DELETE loest DML-Trigger aus; TRUNCATE nicht."
  - "IDENTITY-Zaehler werden durch DELETE nicht zurueckgesetzt (im Gegensatz zu TRUNCATE)."
  - "Die Loeschreihenfolge wird aus dem FK-Graphen abgeleitet (Kind vor Elternteil)."
  - "Zirkulaere FK-Abhaengigkeiten koennen die Reihenfolge unloesbar machen."
  - "Der Default-Modus ist Preview (@PreviewOnly = 1)."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

-- ============================================================
-- Parameter
-- ============================================================
DECLARE @SchemaFilter   NVARCHAR(128)  = NULL;       -- z.B. N'dbo' oder N'sales'
DECLARE @TableList      NVARCHAR(MAX)  = NULL;       -- z.B. N'Orders,OrderItems,Products'
DECLARE @PreviewOnly    BIT            = 1;          -- Sicherheitsstandard: nur anzeigen
DECLARE @ApprovalToken  NVARCHAR(50)   = N'';        -- 'DELETE-ALL-CONFIRMED' zum Ausfuehren
DECLARE @UseTransaction BIT            = 1;          -- Alles in einer Transaktion

-- ============================================================
-- Validierung
-- ============================================================
IF @PreviewOnly = 0 AND @ApprovalToken <> N'DELETE-ALL-CONFIRMED'
BEGIN
    THROW 50710,
        'Ausfuehrungsmodus verweigert: @ApprovalToken muss ''DELETE-ALL-CONFIRMED'' lauten.',
        1;
END;

-- ============================================================
-- Arbeitstabellen
-- ============================================================
DROP TABLE IF EXISTS #AllTables;
DROP TABLE IF EXISTS #DeleteOrder;
DROP TABLE IF EXISTS #DeleteAudit;

-- Alle Benutzertabellen sammeln
CREATE TABLE #AllTables (
    TableObjectId   INT             NOT NULL PRIMARY KEY,
    SchemaName      NVARCHAR(128)   NOT NULL,
    TableName       NVARCHAR(128)   NOT NULL,
    FullName        NVARCHAR(260)   NOT NULL
);

INSERT INTO #AllTables (TableObjectId, SchemaName, TableName, FullName)
SELECT
    t.object_id,
    s.name,
    t.name,
    QUOTENAME(s.name) + N'.' + QUOTENAME(t.name)
FROM sys.tables AS t
INNER JOIN sys.schemas AS s ON t.schema_id = s.schema_id
WHERE t.is_ms_shipped = 0
  AND t.temporal_type <> 1                              -- keine Temporal-History-Tabellen
  AND (@SchemaFilter IS NULL OR s.name = @SchemaFilter)
  AND (
        @TableList IS NULL
        OR t.name IN (
            SELECT LTRIM(RTRIM(value))
            FROM STRING_SPLIT(@TableList, ',')
           )
      );

IF NOT EXISTS (SELECT 1 FROM #AllTables)
BEGIN
    SELECT 'Keine Zieltabellen gefunden. Bitte Parameter pruefen.' AS Hinweis;
    RETURN;
END;

-- Ziel-Tabellen in topologischer Reihenfolge (Kind vor Elternteil)
-- Ansatz: Iterative Tiefenzuweisung via FK-Graph
CREATE TABLE #DeleteOrder (
    SortOrder       INT             NOT NULL,
    TableObjectId   INT             NOT NULL,
    SchemaName      NVARCHAR(128)   NOT NULL,
    TableName       NVARCHAR(128)   NOT NULL,
    FullName        NVARCHAR(260)   NOT NULL,
    RowCountBefore  BIGINT          NULL,
    DeletedRows     BIGINT          NULL,
    WasDeleted      BIT             NOT NULL DEFAULT 0
);

CREATE TABLE #DeleteAudit (
    AuditId         INT             IDENTITY(1,1) NOT NULL,
    FullName        NVARCHAR(260)   NOT NULL,
    DeletedRows     BIGINT          NOT NULL,
    DurationMs      INT             NOT NULL
);

-- Topologische Sortierung: Tabellen ohne ausgehende FKs (oder mit niedrigerem Level) zuerst
-- Wir berechnen die "Tiefe" jeder Tabelle im FK-Baum
DECLARE @Level INT = 0;
DECLARE @Inserted INT = 1;

CREATE TABLE #Levels (
    TableObjectId   INT NOT NULL PRIMARY KEY,
    Depth           INT NOT NULL DEFAULT 0
);

-- Startpunkt: alle Tabellen ohne FK-Abhaengigkeiten (referenzieren keine andere Tabelle)
INSERT INTO #Levels (TableObjectId, Depth)
SELECT a.TableObjectId, 0
FROM #AllTables AS a
WHERE NOT EXISTS (
    SELECT 1
    FROM sys.foreign_keys AS fk
    WHERE fk.parent_object_id = a.TableObjectId
      AND fk.referenced_object_id <> fk.parent_object_id  -- keine Self-Referenzen
);

-- Iterativ: Tabellen, deren Eltern bereits einen Level haben, bekommen Elternlevel + 1
WHILE @Inserted > 0
BEGIN
    SET @Level += 1;

    INSERT INTO #Levels (TableObjectId, Depth)
    SELECT DISTINCT a.TableObjectId, @Level
    FROM #AllTables AS a
    INNER JOIN sys.foreign_keys AS fk
        ON fk.parent_object_id = a.TableObjectId
       AND fk.referenced_object_id <> fk.parent_object_id
    INNER JOIN #Levels AS lp
        ON lp.TableObjectId = fk.referenced_object_id
    WHERE NOT EXISTS (SELECT 1 FROM #Levels AS l WHERE l.TableObjectId = a.TableObjectId);

    SET @Inserted = @@ROWCOUNT;
END;

-- Tabellen, die nach der Iteration noch keinen Level haben (zirkulaere FKs), ans Ende stellen
INSERT INTO #Levels (TableObjectId, Depth)
SELECT a.TableObjectId, @Level + 1
FROM #AllTables AS a
WHERE NOT EXISTS (SELECT 1 FROM #Levels AS l WHERE l.TableObjectId = a.TableObjectId);

-- Loeschreihenfolge aufbauen: hoechste Tiefe (Kindtabellen) zuerst
INSERT INTO #DeleteOrder (SortOrder, TableObjectId, SchemaName, TableName, FullName)
SELECT
    ROW_NUMBER() OVER (ORDER BY lv.Depth DESC, a.SchemaName, a.TableName) AS SortOrder,
    a.TableObjectId,
    a.SchemaName,
    a.TableName,
    a.FullName
FROM #AllTables AS a
INNER JOIN #Levels AS lv ON a.TableObjectId = lv.TableObjectId;

DROP TABLE IF EXISTS #Levels;

-- ============================================================
-- Preview-Ausgabe (immer)
-- ============================================================
SELECT
    SortOrder,
    SchemaName,
    TableName,
    FullName,
    CASE @PreviewOnly
        WHEN 1 THEN 'Nur Vorschau - keine Aktion'
        ELSE        'Wird geleert (DELETE FROM)'
    END AS PlannedAction
FROM #DeleteOrder
ORDER BY SortOrder;

IF @PreviewOnly = 1
BEGIN
    SELECT
        'PREVIEW'                               AS Modus,
        COUNT(*)                                AS AnzahlTabellen,
        'Kein DELETE ausgefuehrt'               AS Status
    FROM #DeleteOrder;
    RETURN;
END;

-- ============================================================
-- Ausfuehrung: DELETE
-- ============================================================
DECLARE @StartTime  DATETIME2 = SYSDATETIME();
DECLARE @Sql        NVARCHAR(500);
DECLARE @FullName   NVARCHAR(260);
DECLARE @ObjId      INT;
DECLARE @RowsBefore BIGINT;
DECLARE @RowsAfter  BIGINT;
DECLARE @StepStart  DATETIME2;

BEGIN TRY

    IF @UseTransaction = 1
        BEGIN TRANSACTION;

    DECLARE cur_delete CURSOR LOCAL FAST_FORWARD FOR
        SELECT TableObjectId, FullName FROM #DeleteOrder ORDER BY SortOrder;

    OPEN cur_delete;
    FETCH NEXT FROM cur_delete INTO @ObjId, @FullName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @StepStart = SYSDATETIME();

        -- Zeilen vor DELETE
        SET @Sql = N'SELECT @n = COUNT_BIG(*) FROM ' + @FullName;
        EXEC sp_executesql @Sql, N'@n BIGINT OUTPUT', @n = @RowsBefore OUTPUT;

        UPDATE #DeleteOrder SET RowCountBefore = @RowsBefore WHERE TableObjectId = @ObjId;

        -- DELETE
        SET @Sql = N'DELETE FROM ' + @FullName;
        EXEC sp_executesql @Sql;

        SET @RowsAfter = @@ROWCOUNT;

        UPDATE #DeleteOrder
        SET DeletedRows = @RowsAfter,
            WasDeleted  = 1
        WHERE TableObjectId = @ObjId;

        INSERT INTO #DeleteAudit (FullName, DeletedRows, DurationMs)
        VALUES (
            @FullName,
            @RowsAfter,
            DATEDIFF(MILLISECOND, @StepStart, SYSDATETIME())
        );

        FETCH NEXT FROM cur_delete INTO @ObjId, @FullName;
    END;

    CLOSE cur_delete;
    DEALLOCATE cur_delete;

    IF @UseTransaction = 1
        COMMIT TRANSACTION;

END TRY
BEGIN CATCH
    IF CURSOR_STATUS('local', 'cur_delete') >= 0
    BEGIN
        CLOSE cur_delete;
        DEALLOCATE cur_delete;
    END;

    IF @UseTransaction = 1 AND @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    DECLARE @ErrMsg  NVARCHAR(2048) = ERROR_MESSAGE();
    DECLARE @ErrLine INT            = ERROR_LINE();
    RAISERROR('Fehler in DeleteAllTablesInSchema (Zeile %d): %s', 16, 1, @ErrLine, @ErrMsg);
    RETURN;
END CATCH;

-- ============================================================
-- Ergebnis-Ausgabe
-- ============================================================
SELECT
    d.SortOrder,
    d.SchemaName,
    d.TableName,
    d.RowCountBefore,
    d.DeletedRows,
    CASE d.WasDeleted WHEN 1 THEN 'Geleert' ELSE 'Uebersprungen' END AS Status
FROM #DeleteOrder AS d
ORDER BY d.SortOrder;

SELECT FullName, DeletedRows, DurationMs AS DauerMs
FROM #DeleteAudit
ORDER BY AuditId;

SELECT
    CASE @UseTransaction WHEN 1 THEN 'TRANSAKTION' ELSE 'EINZELN' END AS TransaktionsModus,
    COUNT(*)                                                AS AnzahlTabellen,
    SUM(CASE WasDeleted WHEN 1 THEN 1 ELSE 0 END)          AS GeleertTabellen,
    SUM(ISNULL(DeletedRows, 0))                             AS GeloeschteZeilenGesamt,
    CAST(
        DATEDIFF(MILLISECOND, @StartTime, SYSDATETIME())
        AS NVARCHAR(20)
    ) + N' ms'                                              AS GesamtDauer
FROM #DeleteOrder;

-- ============================================================
-- Aufraumen
-- ============================================================
DROP TABLE IF EXISTS #AllTables;
DROP TABLE IF EXISTS #DeleteOrder;
DROP TABLE IF EXISTS #DeleteAudit;
