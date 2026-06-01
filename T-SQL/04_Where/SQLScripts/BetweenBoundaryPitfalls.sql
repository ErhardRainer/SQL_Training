/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "BetweenBoundaryPitfalls.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "04_Where"

purpose: >
  Macht inklusive Grenzen, Datumsenden und Off-by-one-Faelle bei
  BETWEEN sichtbar und kontrastiert sie mit expliziten sowie
  halb-offenen Bereichsmustern.

parameters:
  - name: "@ScoreLowerBound"
    sql_type: "INT"
    direction: "IN"
    required: true
    description: "Untere inklusive Grenze fuer die numerische Bereichsdemo"
  - name: "@ScoreUpperBound"
    sql_type: "INT"
    direction: "IN"
    required: true
    description: "Obere inklusive Grenze fuer die numerische Bereichsdemo"
  - name: "@WindowStartDate"
    sql_type: "DATE"
    direction: "IN"
    required: true
    description: "Fachlicher Starttag fuer die Datumsdemo"
  - name: "@WindowEndDate"
    sql_type: "DATE"
    direction: "IN"
    required: true
    description: "Fachlicher Endtag fuer die Datumsdemo"
  - name: "@ResultMode"
    sql_type: "VARCHAR(20)"
    direction: "IN"
    required: false
    description: "Filtert all, numeric, datetime oder notes"

result_sets:
  - name: "NumericBoundaryPitfalls"
    description: "Vergleicht BETWEEN mit expliziten Grenzvergleichen und zeigt Off-by-one-Faelle"
  - name: "DatetimeBoundaryPitfalls"
    description: "Kontrastiert BETWEEN auf DATE-Grenzen mit einem robusten halb-offenen Datumsfenster"
  - name: "BoundaryTeachingNotes"
    description: "Verdichtet die zentralen Lernpunkte zu inklusiven Grenzen und Datumsenden"

dependencies:
  - "tempdb temporary tables"
  - "BETWEEN"
  - "DATEADD"
  - "CAST"
  - "CASE"
  - "DATETIME2"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/04_Where/SQLScripts/BetweenBoundaryPitfalls.md"
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
    description: "Erstversion fuer BETWEEN-Grenzfaelle und Off-by-one-Pitfalls im WHERE-Kapitel"

notes:
  - "Das Skript arbeitet ausschliesslich mit tempdb-Objekten und Demo-Daten."
  - "Die Datumsdemo behandelt @WindowEndDate fachlich als ganzen Kalendertag und stellt dem naiven BETWEEN-Muster ein halb-offenes Fenster gegenueber."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @ScoreLowerBound INT = 10;
DECLARE @ScoreUpperBound INT = 12;
DECLARE @WindowStartDate DATE = '2026-05-01';
DECLARE @WindowEndDate DATE = '2026-05-03';
DECLARE @ResultMode VARCHAR(20) = 'all';

DECLARE @WindowStartDateTime DATETIME2(0) = CAST(@WindowStartDate AS DATETIME2(0));
DECLARE @WindowEndDateTime DATETIME2(0) = CAST(@WindowEndDate AS DATETIME2(0));
DECLARE @WindowEndExclusive DATETIME2(0) = DATEADD(DAY, 1, @WindowEndDateTime);

IF @ScoreLowerBound IS NULL OR @ScoreUpperBound IS NULL
BEGIN
    THROW 50520, '@ScoreLowerBound und @ScoreUpperBound muessen gesetzt sein.', 1;
END;

IF @ScoreLowerBound > @ScoreUpperBound
BEGIN
    THROW 50521, '@ScoreLowerBound darf nicht groesser als @ScoreUpperBound sein.', 1;
END;

IF @WindowStartDate IS NULL OR @WindowEndDate IS NULL
BEGIN
    THROW 50522, '@WindowStartDate und @WindowEndDate muessen gesetzt sein.', 1;
END;

IF @WindowEndDate < @WindowStartDate
BEGIN
    THROW 50523, '@WindowEndDate darf nicht vor @WindowStartDate liegen.', 1;
END;

IF @ResultMode NOT IN ('all', 'numeric', 'datetime', 'notes')
BEGIN
    THROW 50524, '@ResultMode muss all, numeric, datetime oder notes sein.', 1;
END;

DROP TABLE IF EXISTS #NumericSamples;
DROP TABLE IF EXISTS #DatetimeSamples;

CREATE TABLE #NumericSamples
(
    SampleID INT NOT NULL PRIMARY KEY,
    SampleLabel NVARCHAR(140) NOT NULL,
    ScoreValue INT NOT NULL
);

CREATE TABLE #DatetimeSamples
(
    EventID INT NOT NULL PRIMARY KEY,
    EventLabel NVARCHAR(140) NOT NULL,
    EventTime DATETIME2(0) NOT NULL
);

INSERT INTO #NumericSamples
(
    SampleID,
    SampleLabel,
    ScoreValue
)
VALUES
    (1, N'Knapp unter der unteren Grenze', 9),
    (2, N'Exakt auf der unteren Grenze', 10),
    (3, N'Zwischenwert im Bereich', 11),
    (4, N'Exakt auf der oberen Grenze', 12),
    (5, N'Knapp ueber der oberen Grenze', 13);

INSERT INTO #DatetimeSamples
(
    EventID,
    EventLabel,
    EventTime
)
VALUES
    (101, N'Kurz vor dem Fenster', '2026-04-30T23:59:59'),
    (102, N'Exakt zum Start', '2026-05-01T00:00:00'),
    (103, N'Vormittag im Zielbereich', '2026-05-01T09:30:00'),
    (104, N'Abend vor dem letzten Tag', '2026-05-02T20:15:00'),
    (105, N'Exakt Mitternacht am Enddatum', '2026-05-03T00:00:00'),
    (106, N'Mittag am Enddatum', '2026-05-03T12:00:00'),
    (107, N'Letzte Sekunde am Enddatum', '2026-05-03T23:59:59'),
    (108, N'Exakt zum exklusiven Ende', '2026-05-04T00:00:00');

SELECT
    @ScoreLowerBound AS ScoreLowerBound,
    @ScoreUpperBound AS ScoreUpperBound,
    @WindowStartDate AS WindowStartDate,
    @WindowEndDate AS WindowEndDate,
    @WindowStartDateTime AS WindowStartDateTime,
    @WindowEndDateTime AS BetweenEndAtMidnight,
    @WindowEndExclusive AS HalfOpenEndExclusive,
    'BETWEEN ist inklusiv; bei DATETIME deckt ein DATE-Endwert nur Mitternacht des Endtags ab.' AS TeachingNote;

;WITH NumericEvaluation AS
(
    SELECT
        ns.SampleID,
        ns.SampleLabel,
        ns.ScoreValue,
        IncludedByBetween =
            CASE
                WHEN ns.ScoreValue BETWEEN @ScoreLowerBound AND @ScoreUpperBound THEN 1
                ELSE 0
            END,
        IncludedByExplicitInclusive =
            CASE
                WHEN ns.ScoreValue >= @ScoreLowerBound
                 AND ns.ScoreValue <= @ScoreUpperBound THEN 1
                ELSE 0
            END,
        IncludedByExclusiveUpperBound =
            CASE
                WHEN ns.ScoreValue >= @ScoreLowerBound
                 AND ns.ScoreValue < @ScoreUpperBound THEN 1
                ELSE 0
            END,
        BoundaryRole =
            CASE
                WHEN ns.ScoreValue = @ScoreLowerBound THEN 'lower-boundary'
                WHEN ns.ScoreValue = @ScoreUpperBound THEN 'upper-boundary'
                WHEN ns.ScoreValue BETWEEN @ScoreLowerBound AND @ScoreUpperBound THEN 'inside-range'
                ELSE 'outside-range'
            END
    FROM #NumericSamples AS ns
)
SELECT
    ne.SampleID,
    ne.SampleLabel,
    ne.ScoreValue,
    InclusiveRangeText = CONCAT(@ScoreLowerBound, ' bis ', @ScoreUpperBound),
    ne.IncludedByBetween,
    ne.IncludedByExplicitInclusive,
    ne.IncludedByExclusiveUpperBound,
    ne.BoundaryRole,
    OffByOneDiagnosis =
        CASE
            WHEN ne.BoundaryRole = 'upper-boundary' AND ne.IncludedByExclusiveUpperBound = 0
                THEN 'Die obere Grenze faellt bei < Obergrenze heraus.'
            WHEN ne.BoundaryRole = 'lower-boundary'
                THEN 'Die untere Grenze bleibt bei BETWEEN und >= erhalten.'
            WHEN ne.BoundaryRole = 'inside-range'
                THEN 'Innenliegende Werte werden von allen passenden Bereichsmustern getroffen.'
            ELSE 'Werte ausserhalb des Bereichs bleiben draussen.'
        END
FROM NumericEvaluation AS ne
WHERE @ResultMode IN ('all', 'numeric')
ORDER BY
    ne.SampleID;

;WITH DatetimeEvaluation AS
(
    SELECT
        ds.EventID,
        ds.EventLabel,
        ds.EventTime,
        IncludedByBetweenDates =
            CASE
                WHEN ds.EventTime BETWEEN @WindowStartDateTime AND @WindowEndDateTime THEN 1
                ELSE 0
            END,
        IncludedByHalfOpenWindow =
            CASE
                WHEN ds.EventTime >= @WindowStartDateTime
                 AND ds.EventTime < @WindowEndExclusive THEN 1
                ELSE 0
            END,
        BoundaryRole =
            CASE
                WHEN ds.EventTime < @WindowStartDateTime THEN 'before-window'
                WHEN ds.EventTime = @WindowStartDateTime THEN 'start-boundary'
                WHEN ds.EventTime = @WindowEndDateTime THEN 'end-midnight'
                WHEN CAST(ds.EventTime AS DATE) = @WindowEndDate
                 AND ds.EventTime > @WindowEndDateTime
                 AND ds.EventTime < @WindowEndExclusive THEN 'same-day-after-midnight'
                WHEN ds.EventTime = @WindowEndExclusive THEN 'exclusive-end-boundary'
                ELSE 'inside-window'
            END
    FROM #DatetimeSamples AS ds
)
SELECT
    de.EventID,
    de.EventLabel,
    de.EventTime,
    BetweenWindow = CONCAT(CONVERT(VARCHAR(19), @WindowStartDateTime, 120), ' bis ', CONVERT(VARCHAR(19), @WindowEndDateTime, 120)),
    HalfOpenWindow = CONCAT(CONVERT(VARCHAR(19), @WindowStartDateTime, 120), ' bis < ', CONVERT(VARCHAR(19), @WindowEndExclusive, 120)),
    de.IncludedByBetweenDates,
    de.IncludedByHalfOpenWindow,
    de.BoundaryRole,
    PitfallDiagnosis =
        CASE
            WHEN de.BoundaryRole = 'end-midnight'
                THEN 'Mitternacht des Endtags ist noch enthalten.'
            WHEN de.BoundaryRole = 'same-day-after-midnight'
                THEN 'Spaetere Uhrzeiten am Endtag fehlen bei BETWEEN auf DATE-Grenzen.'
            WHEN de.BoundaryRole = 'exclusive-end-boundary'
                THEN 'Das exklusive Ende gehoert bewusst nicht mehr zum Halb-offen-Fenster.'
            WHEN de.BoundaryRole = 'start-boundary'
                THEN 'Der Startzeitpunkt bleibt in beiden Mustern enthalten.'
            WHEN de.BoundaryRole = 'before-window'
                THEN 'Vor dem Startdatum liegt kein Treffer vor.'
            ELSE 'Der Zeitpunkt liegt im fachlichen Fenster und wird vom robusten Muster erfasst.'
        END
FROM DatetimeEvaluation AS de
WHERE @ResultMode IN ('all', 'datetime')
ORDER BY
    de.EventID;

SELECT
    NoteOrder,
    NoteTitle,
    NoteText
FROM
(
    VALUES
        (1, N'BETWEEN ist beidseitig inklusiv', N'Die untere und die obere Grenze gehoeren zum Trefferraum von BETWEEN.'),
        (2, N'Off-by-one an der Obergrenze', N'Der Wechsel von <= Obergrenze zu < Obergrenze entfernt genau den Grenzwert und ist daher keine austauschbare Schreibweise.'),
        (3, N'DATE gegen DATETIME', N'Wird das Enddatum als 2026-05-03 00:00:00 interpretiert, fehlen spaetere Uhrzeiten am selben Kalendertag.'),
        (4, N'Robustes Tagesfenster', N'Fuer fachlich inklusive Tage ist >= Start und < naechster Tag meist das stabilere Muster.')
) AS notes(NoteOrder, NoteTitle, NoteText)
WHERE @ResultMode IN ('all', 'notes')
ORDER BY
    NoteOrder;
