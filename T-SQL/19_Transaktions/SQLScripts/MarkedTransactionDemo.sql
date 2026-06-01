/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "MarkedTransactionDemo.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "19_Transaktions"

purpose: >
  Demonstriert mit einem modellierten Ablauf, wie markierte Transaktionen
  fuer koordinierte Restore-Szenarien genutzt werden koennen. Das Skript
  zeigt Marken, moegliche Restore-Ziele und eine vorsichtige
  Kommando-Vorschau, ohne Backup- oder Restore-Befehle auszufuehren.

parameters:
  - name: "@ScenarioFocus"
    sql_type: "VARCHAR(30)"
    direction: "IN"
    required: false
    description: "Optionaler Fokus auf eine Szenariogruppe: ALL, CROSS_DB, RELEASE oder BATCH"
  - name: "@IncludeRestoreGuide"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zusaetzlich eine kompakte Restore-Entscheidungshilfe ausgeben"
  - name: "@IncludeCommandPreview"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = nur als Text generierte Beispielkommandos fuer WITH MARK und RESTORE LOG anzeigen"

result_sets:
  - name: "MarkedTransactionInventory"
    description: "Beschreibt modellierte Marken, betroffene Datenbanken und den didaktischen Restore-Zweck"
  - name: "RestoreDecisionGuide"
    description: "Leitet je Szenario das geeignete Restore-Ziel und den Fokus fuer die Abstimmung ab"
  - name: "CommandPreview"
    description: "Zeigt nicht ausgefuehrte Beispielkommandos fuer markierte Transaktionen und STOPATMARK"

dependencies:
  - "tempdb temporary tables"
  - "CASE"
  - "CONCAT"
  - "CROSS APPLY"
  - "ORDER BY"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/19_Transaktions/SQLScripts/MarkedTransactionDemo.md"
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
    date: "2026-04-22"
    user: "ER"
    description: "Erstversion des didaktischen Labs fuer markierte Transaktionen und Restore-Marken"

notes:
  - "Das Skript modelliert Backup- und Restore-Situationen in tempdb und fuehrt keine produktiven Transaktions- oder Restore-Kommandos aus"
  - "Die Kommando-Vorschau dient nur als Diskussionsgrundlage fuer Syntax, Reihenfolge und Guardrails"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

-- 1. Parameter vorbereiten
DECLARE @ScenarioFocus VARCHAR(30) = 'ALL';
DECLARE @IncludeRestoreGuide BIT = 1;
DECLARE @IncludeCommandPreview BIT = 1;

SET @ScenarioFocus = UPPER(LTRIM(RTRIM(@ScenarioFocus)));

IF @ScenarioFocus NOT IN ('ALL', 'CROSS_DB', 'RELEASE', 'BATCH')
BEGIN
    THROW 50000, '@ScenarioFocus muss ALL, CROSS_DB, RELEASE oder BATCH sein.', 1;
END;

IF @IncludeRestoreGuide NOT IN (0, 1)
BEGIN
    THROW 50001, '@IncludeRestoreGuide muss 0 oder 1 sein.', 1;
END;

IF @IncludeCommandPreview NOT IN (0, 1)
BEGIN
    THROW 50002, '@IncludeCommandPreview muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #MarkedTransactionInventory;
DROP TABLE IF EXISTS #RestoreDecisionGuide;
DROP TABLE IF EXISTS #CommandPreview;

-- 2. Modellierte Marken und Backup-Kontexte aufbauen
CREATE TABLE #MarkedTransactionInventory
(
    ScenarioID               INT            NOT NULL,
    ScenarioGroup            VARCHAR(30)    NOT NULL,
    MarkName                 VARCHAR(60)    NOT NULL,
    BusinessEvent            VARCHAR(120)   NOT NULL,
    DatabaseScope            VARCHAR(120)   NOT NULL,
    BackupChainStep          VARCHAR(90)    NOT NULL,
    RestoreTarget            VARCHAR(30)    NOT NULL,
    WhyRelevant              VARCHAR(220)   NOT NULL,
    CoordinationHint         VARCHAR(220)   NOT NULL
);

INSERT INTO #MarkedTransactionInventory
(
    ScenarioID,
    ScenarioGroup,
    MarkName,
    BusinessEvent,
    DatabaseScope,
    BackupChainStep,
    RestoreTarget,
    WhyRelevant,
    CoordinationHint
)
VALUES
    (
        1,
        'CROSS_DB',
        'QuarterClose_2026Q2',
        'Quartalsabschluss in Finance und Reporting fachlich synchron markieren',
        'FinanceLab + ReportingLab',
        'Log-Backups nach Full Backup',
        'STOPATMARK',
        'Eine gemeinsame Marke hilft, mehrere Datenbanken auf denselben fachlichen Zeitpunkt zurueckzufuehren.',
        'Nur sinnvoll, wenn alle betroffenen Datenbanken die Marke im jeweiligen Log-Backup enthalten.'
    ),
    (
        2,
        'RELEASE',
        'Release_2026_04_22',
        'Deployment-Fenster mit klar benannter Ruecksprungmarke absichern',
        'SalesLab',
        'Vor und nach dem Release eng getaktete Log-Backups',
        'STOPBEFOREMARK',
        'Vor einer problematischen Aenderung kann gezielt bis kurz vor die Marke restauriert werden.',
        'Die Marke sollte fachlich benannt sein und mit Change-, Deployment- und Backup-Zeitplan zusammenpassen.'
    ),
    (
        3,
        'BATCH',
        'InvoiceBatch_117',
        'Abgrenzung eines grossen Batch-Laufs fuer spaetere Analyse oder Restore-Diskussion',
        'BillingLab',
        'Mehrere Log-Backups waehrend des Batch-Fensters',
        'STOPATMARK',
        'Bei langen Batch-Laeufen wird sichtbar, welches Wiederanlauf- oder Restore-Ziel fachlich gemeint ist.',
        'Die Marke ersetzt keine Idempotenz, kann aber fuer Recovery- und Incident-Gespraeche Orientierung geben.'
    ),
    (
        4,
        'CROSS_DB',
        'WarehouseCutover_A',
        'Cutover zwischen Lagerverwaltung und Versand konsistent markieren',
        'WarehouseLab + ShippingLab',
        'Abgestimmte Log-Backups aus beiden Systemen',
        'STOPATMARK',
        'Koordinierte Marken reduzieren Missverstaendnisse bei abhaengigen Systemgrenzen.',
        'Der Restore-Plan muss pruefen, ob alle Ketten vollstaendig und alle Marken gleich benannt sind.'
    );

-- 3. Restore-Ziel, Risiko und Gespraechsfokus ableiten
CREATE TABLE #RestoreDecisionGuide
(
    ScenarioID               INT            NOT NULL,
    MarkName                 VARCHAR(60)    NOT NULL,
    RestoreTarget            VARCHAR(30)    NOT NULL,
    RestoreSyntaxHint        VARCHAR(120)   NOT NULL,
    CoordinationFocus        VARCHAR(180)   NOT NULL,
    PrimaryRisk              VARCHAR(180)   NOT NULL,
    ReviewQuestion           VARCHAR(220)   NOT NULL
);

INSERT INTO #RestoreDecisionGuide
(
    ScenarioID,
    MarkName,
    RestoreTarget,
    RestoreSyntaxHint,
    CoordinationFocus,
    PrimaryRisk,
    ReviewQuestion
)
SELECT
    mti.ScenarioID,
    mti.MarkName,
    mti.RestoreTarget,
    CASE mti.RestoreTarget
        WHEN 'STOPATMARK' THEN 'RESTORE LOG ... WITH STOPATMARK = ''mark_name'''
        ELSE 'RESTORE LOG ... WITH STOPBEFOREMARK = ''mark_name'''
    END AS RestoreSyntaxHint,
    CASE mti.ScenarioGroup
        WHEN 'CROSS_DB' THEN 'Backup-Ketten und Markenvorkommen ueber alle beteiligten Datenbanken abstimmen'
        WHEN 'RELEASE' THEN 'Release-Zeitpunkt, Ruecksprungziel und Kommunikationsfenster gemeinsam definieren'
        ELSE 'Batch-Grenzen, Wiederanlaufstrategie und fachliche Folgen eines Teil-Restores klaeren'
    END AS CoordinationFocus,
    CASE
        WHEN mti.ScenarioGroup = 'CROSS_DB' THEN 'Eine Datenbank hat die Marke nicht in derselben Backup-Kette.'
        WHEN mti.RestoreTarget = 'STOPBEFOREMARK' THEN 'Die gewuenschte Rueckkehr liegt logisch vor der markierten Aenderung, nicht auf ihr.'
        ELSE 'Die Marke ist vorhanden, aber Batch- oder Folgeprozesse sind fachlich nicht ausreichend abgegrenzt.'
    END AS PrimaryRisk,
    CONCAT(
        'Ist fuer ', mti.MarkName,
        ' klar dokumentiert, welche Datenbanken, Backups und Fachschritte gemeinsam betrachtet werden muessen?'
    ) AS ReviewQuestion
FROM #MarkedTransactionInventory AS mti;

-- 4. Nicht ausgefuehrte Beispielkommandos erzeugen
CREATE TABLE #CommandPreview
(
    ScenarioID               INT            NOT NULL,
    CommandType              VARCHAR(30)    NOT NULL,
    PreviewOrder             TINYINT        NOT NULL,
    CommandText              VARCHAR(400)   NOT NULL,
    WhyRelevant              VARCHAR(220)   NOT NULL
);

INSERT INTO #CommandPreview
(
    ScenarioID,
    CommandType,
    PreviewOrder,
    CommandText,
    WhyRelevant
)
SELECT
    mti.ScenarioID,
    cp.CommandType,
    cp.PreviewOrder,
    cp.CommandText,
    cp.WhyRelevant
FROM #MarkedTransactionInventory AS mti
CROSS APPLY
(
    VALUES
    (
        'mark',
        CAST(1 AS TINYINT),
        CONCAT(
            'BEGIN TRAN ', mti.MarkName,
            ' WITH MARK ''', mti.BusinessEvent, ''';'
        ),
        'Zeigt die Syntax fuer eine markierte Transaktion als fachlich benannte Grenze.'
    ),
    (
        'mark',
        CAST(2 AS TINYINT),
        'COMMIT TRAN;',
        'Die Marke wird erst mit der umschliessenden Transaktion sinnvoll abgeschlossen.'
    ),
    (
        'restore',
        CAST(3 AS TINYINT),
        CONCAT(
            'RESTORE LOG [',
            CASE
                WHEN CHARINDEX(' + ', mti.DatabaseScope) > 0
                    THEN LEFT(mti.DatabaseScope, CHARINDEX(' + ', mti.DatabaseScope) - 1)
                ELSE mti.DatabaseScope
            END,
            '] WITH ',
            CASE mti.RestoreTarget
                WHEN 'STOPATMARK' THEN 'STOPATMARK'
                ELSE 'STOPBEFOREMARK'
            END,
            ' = ''', mti.MarkName, ''';'
        ),
        'Zeigt die didaktische Restore-Zielsyntax zur ausgewaehlten Marke.'
    )
) AS cp(CommandType, PreviewOrder, CommandText, WhyRelevant);

-- 5. Ergebnis-Sets ausgeben
SELECT
    mti.ScenarioID,
    mti.ScenarioGroup,
    mti.MarkName,
    mti.BusinessEvent,
    mti.DatabaseScope,
    mti.BackupChainStep,
    mti.RestoreTarget,
    mti.WhyRelevant,
    mti.CoordinationHint
FROM #MarkedTransactionInventory AS mti
WHERE @ScenarioFocus = 'ALL'
   OR mti.ScenarioGroup = @ScenarioFocus
ORDER BY
    mti.ScenarioID;

SELECT
    rdg.ScenarioID,
    rdg.MarkName,
    rdg.RestoreTarget,
    rdg.RestoreSyntaxHint,
    rdg.CoordinationFocus,
    rdg.PrimaryRisk,
    rdg.ReviewQuestion
FROM #RestoreDecisionGuide AS rdg
INNER JOIN #MarkedTransactionInventory AS mti
    ON mti.ScenarioID = rdg.ScenarioID
WHERE @IncludeRestoreGuide = 1
  AND (@ScenarioFocus = 'ALL' OR mti.ScenarioGroup = @ScenarioFocus)
ORDER BY
    rdg.ScenarioID;

SELECT
    cp.ScenarioID,
    mti.MarkName,
    cp.CommandType,
    cp.PreviewOrder,
    cp.CommandText,
    cp.WhyRelevant
FROM #CommandPreview AS cp
INNER JOIN #MarkedTransactionInventory AS mti
    ON mti.ScenarioID = cp.ScenarioID
WHERE @IncludeCommandPreview = 1
  AND (@ScenarioFocus = 'ALL' OR mti.ScenarioGroup = @ScenarioFocus)
ORDER BY
    cp.ScenarioID,
    cp.PreviewOrder;
