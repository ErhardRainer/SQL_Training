/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "FunctionalDependencyWorksheet.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "01_Normalformen"

purpose: >
  Liefert ein didaktisches Arbeitsblatt fuer funktionale Abhaengigkeiten,
  indem vorbereitete Determinanten und abhaengige Attribute auf stabil wirkende
  Zuordnungen in einer breiten Einschreibungsrelation geprueft werden.

parameters:
  - name: "@ShowSourceData"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = Vorschau der didaktischen Ausgangsdaten ausgeben"
  - name: "@OnlyStableDependencies"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = nur stabil wirkende Abhaengigkeiten im Arbeitsblatt anzeigen"

result_sets:
  - name: "SourceDataPreview"
    description: "Optionale Vorschau der breiten Demo-Einschreibungsrelation"
  - name: "DependencyWorksheet"
    description: "Arbeitsblatt mit Kennzahlen, Signalen und Reflexionsfragen zu vorbereiteten Abhaengigkeiten"
  - name: "ModelingPrompts"
    description: "Didaktische Impulse fuer moegliche Zerlegungen und Rueckfragen zur Normalisierung"

dependencies:
  - "tempdb temporary tables"
  - "CROSS APPLY"
  - "COUNT(DISTINCT ...)"
  - "GROUP BY"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/01_Normalformen/SQLScripts/FunctionalDependencyWorksheet.md"
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
    date: "2026-04-16"
    user: "ER"
    description: "Erstversion des didaktischen Arbeitsblatts fuer funktionale Abhaengigkeiten"

notes:
  - "Die Demo-Daten modellieren absichtlich eine breite Einschreibungsrelation statt produktiver Tabellen"
  - "CourseCode -> InstructorCode ist bewusst nicht stabil, damit die Rolle zusammengesetzter Determinanten sichtbar wird"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @ShowSourceData BIT = 1;
DECLARE @OnlyStableDependencies BIT = 0;

IF @ShowSourceData NOT IN (0, 1)
BEGIN
    THROW 50000, '@ShowSourceData muss 0 oder 1 sein.', 1;
END;

IF @OnlyStableDependencies NOT IN (0, 1)
BEGIN
    THROW 50001, '@OnlyStableDependencies muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #EnrollmentWorksheet;
DROP TABLE IF EXISTS #DependencyCandidates;
DROP TABLE IF EXISTS #DependencyObservations;
DROP TABLE IF EXISTS #DependencyWorksheet;
DROP TABLE IF EXISTS #ModelingPrompts;

CREATE TABLE #EnrollmentWorksheet
(
    EnrollmentID    INT          NOT NULL,
    StudentNo       VARCHAR(20)  NOT NULL,
    StudentName     VARCHAR(80)  NOT NULL,
    ProgramCode     VARCHAR(20)  NOT NULL,
    ProgramName     VARCHAR(80)  NOT NULL,
    AdvisorCode     VARCHAR(20)  NOT NULL,
    AdvisorName     VARCHAR(80)  NOT NULL,
    CampusCode      VARCHAR(20)  NOT NULL,
    CampusName      VARCHAR(80)  NOT NULL,
    CourseCode      VARCHAR(20)  NOT NULL,
    CourseTitle     VARCHAR(80)  NOT NULL,
    TermCode        VARCHAR(20)  NOT NULL,
    InstructorCode  VARCHAR(20)  NOT NULL,
    InstructorName  VARCHAR(80)  NOT NULL,
    DeliveryMode    VARCHAR(20)  NOT NULL
);

INSERT INTO #EnrollmentWorksheet
(
    EnrollmentID,
    StudentNo,
    StudentName,
    ProgramCode,
    ProgramName,
    AdvisorCode,
    AdvisorName,
    CampusCode,
    CampusName,
    CourseCode,
    CourseTitle,
    TermCode,
    InstructorCode,
    InstructorName,
    DeliveryMode
)
VALUES
    (1001, 'S-1001', 'Anna Berger',   'CS-BSC', 'Computer Science BSc',      'ADV-CS1',  'Dr. Koch',     'BER', 'Berlin Campus',  'DB100', 'Relationale Grundlagen',   '2026S', 'INS-DB1', 'Prof. Winter',  'Onsite'),
    (1002, 'S-1002', 'Boris Klein',   'CS-BSC', 'Computer Science BSc',      'ADV-CS1',  'Dr. Koch',     'BER', 'Berlin Campus',  'DB100', 'Relationale Grundlagen',   '2026S', 'INS-DB1', 'Prof. Winter',  'Onsite'),
    (1003, 'S-1003', 'Cem Yilmaz',    'CS-BSC', 'Computer Science BSc',      'ADV-CS2',  'Dr. Lorenz',   'HAM', 'Hamburg Campus', 'DB100', 'Relationale Grundlagen',   '2026W', 'INS-DB3', 'Prof. Malik',   'Hybrid'),
    (1004, 'S-1004', 'Dina Maurer',   'QA-BSC', 'Quality Engineering BSc',   'ADV-QA1',  'Dr. Weiss',    'MUC', 'Munich Campus',  'QA210', 'Testing Foundations',      '2026S', 'INS-QA1', 'Prof. Hartmann','Onsite'),
    (1005, 'S-1005', 'Eva Schmitt',   'QA-BSC', 'Quality Engineering BSc',   'ADV-QA1',  'Dr. Weiss',    'MUC', 'Munich Campus',  'QA210', 'Testing Foundations',      '2026S', 'INS-QA1', 'Prof. Hartmann','Onsite'),
    (1006, 'S-1006', 'Farid Osman',   'BUS-MSC','Business Analytics MSc',    'ADV-BI1',  'Prof. Stein',  'BER', 'Berlin Campus',  'BI300', 'Analytics Sprint',         '2026S', 'INS-BI2', 'Prof. Seidel',  'Remote'),
    (1007, 'S-1007', 'Greta Nowak',   'BUS-MSC','Business Analytics MSc',    'ADV-BI1',  'Prof. Stein',  'BER', 'Berlin Campus',  'BI300', 'Analytics Sprint',         '2026S', 'INS-BI2', 'Prof. Seidel',  'Remote'),
    (1008, 'S-1008', 'Hasan Demir',   'CS-MSC', 'Data Engineering MSc',      'ADV-CS3',  'Prof. Adler',  'HAM', 'Hamburg Campus', 'DB220', 'Data Modeling Studio',    '2026W', 'INS-DB4', 'Prof. Kraus',   'Hybrid');

IF @ShowSourceData = 1
BEGIN
    SELECT
        ew.EnrollmentID,
        ew.StudentNo,
        ew.StudentName,
        ew.ProgramCode,
        ew.ProgramName,
        ew.AdvisorCode,
        ew.AdvisorName,
        ew.CampusCode,
        ew.CampusName,
        ew.CourseCode,
        ew.CourseTitle,
        ew.TermCode,
        ew.InstructorCode,
        ew.InstructorName,
        ew.DeliveryMode
    FROM #EnrollmentWorksheet AS ew
    ORDER BY
        ew.EnrollmentID;
END;

CREATE TABLE #DependencyCandidates
(
    DeterminantLabel  VARCHAR(80)   NOT NULL,
    DependentLabel    VARCHAR(80)   NOT NULL,
    WorksheetFocus    VARCHAR(220)  NOT NULL
);

INSERT INTO #DependencyCandidates
(
    DeterminantLabel,
    DependentLabel,
    WorksheetFocus
)
VALUES
    ('StudentNo', 'StudentName', 'Prueft, ob Studierendenstammdaten direkt vom Lernenden-Identifier abhaengen.'),
    ('StudentNo', 'ProgramCode', 'Prueft, ob das Studienprogramm pro Lernenden stabil hinterlegt ist.'),
    ('ProgramCode', 'ProgramName', 'Prueft Stammdatenkonsistenz fuer Studienprogramme.'),
    ('AdvisorCode', 'AdvisorName', 'Prueft Stammdatenkonsistenz fuer Betreuende.'),
    ('CampusCode', 'CampusName', 'Prueft Stammdatenkonsistenz fuer Standorte.'),
    ('CourseCode', 'CourseTitle', 'Prueft, ob die Kursbezeichnung stabil aus dem Kurscode folgt.'),
    ('InstructorCode', 'InstructorName', 'Prueft Stammdatenkonsistenz fuer Lehrende.'),
    ('CourseCode', 'InstructorCode', 'Zeigt, dass ein Kurscode allein je nach Termin verschiedene Lehrende haben kann.'),
    ('CourseCode + TermCode', 'InstructorCode', 'Prueft, ob ein konkretes Kursangebot je Termin genau eine Lehrperson hat.'),
    ('CourseCode + TermCode', 'DeliveryMode', 'Prueft, ob das Angebotsformat am kombinierten Kurs- und Terminschluessel haengt.');

CREATE TABLE #DependencyObservations
(
    DeterminantLabel   VARCHAR(80)   NOT NULL,
    DependentLabel     VARCHAR(80)   NOT NULL,
    WorksheetFocus     VARCHAR(220)  NOT NULL,
    DeterminantValue   VARCHAR(160)  NOT NULL,
    DependentValue     VARCHAR(160)  NOT NULL
);

INSERT INTO #DependencyObservations
(
    DeterminantLabel,
    DependentLabel,
    WorksheetFocus,
    DeterminantValue,
    DependentValue
)
SELECT
    dc.DeterminantLabel,
    dc.DependentLabel,
    dc.WorksheetFocus,
    mapping.DeterminantValue,
    mapping.DependentValue
FROM #EnrollmentWorksheet AS ew
INNER JOIN #DependencyCandidates AS dc
    ON 1 = 1
CROSS APPLY
(
    SELECT
        DeterminantValue =
            CASE dc.DeterminantLabel
                WHEN 'StudentNo' THEN ew.StudentNo
                WHEN 'ProgramCode' THEN ew.ProgramCode
                WHEN 'AdvisorCode' THEN ew.AdvisorCode
                WHEN 'CampusCode' THEN ew.CampusCode
                WHEN 'CourseCode' THEN ew.CourseCode
                WHEN 'InstructorCode' THEN ew.InstructorCode
                WHEN 'CourseCode + TermCode' THEN CONCAT(ew.CourseCode, '|', ew.TermCode)
            END,
        DependentValue =
            CASE dc.DependentLabel
                WHEN 'StudentName' THEN ew.StudentName
                WHEN 'ProgramCode' THEN ew.ProgramCode
                WHEN 'ProgramName' THEN ew.ProgramName
                WHEN 'AdvisorName' THEN ew.AdvisorName
                WHEN 'CampusName' THEN ew.CampusName
                WHEN 'CourseTitle' THEN ew.CourseTitle
                WHEN 'InstructorCode' THEN ew.InstructorCode
                WHEN 'InstructorName' THEN ew.InstructorName
                WHEN 'DeliveryMode' THEN ew.DeliveryMode
            END
) AS mapping;

CREATE TABLE #DependencyWorksheet
(
    DeterminantLabel          VARCHAR(80)   NOT NULL,
    DependentLabel            VARCHAR(80)   NOT NULL,
    DeterminantCardinality    INT           NOT NULL,
    StableDeterminantValues   INT           NOT NULL,
    AmbiguousDeterminants     INT           NOT NULL,
    MaxDependentValues        INT           NOT NULL,
    DependencySignal          VARCHAR(40)   NOT NULL,
    SampleDeterminantValue    VARCHAR(160)  NOT NULL,
    SampleDependentValue      VARCHAR(160)  NOT NULL,
    Interpretation            VARCHAR(260)  NOT NULL,
    WorksheetPrompt           VARCHAR(260)  NOT NULL
);

INSERT INTO #DependencyWorksheet
(
    DeterminantLabel,
    DependentLabel,
    DeterminantCardinality,
    StableDeterminantValues,
    AmbiguousDeterminants,
    MaxDependentValues,
    DependencySignal,
    SampleDeterminantValue,
    SampleDependentValue,
    Interpretation,
    WorksheetPrompt
)
SELECT
    stats.DeterminantLabel,
    stats.DependentLabel,
    COUNT(*) AS DeterminantCardinality,
    SUM(CASE WHEN stats.DependentValuesPerDeterminant = 1 THEN 1 ELSE 0 END) AS StableDeterminantValues,
    SUM(CASE WHEN stats.DependentValuesPerDeterminant > 1 THEN 1 ELSE 0 END) AS AmbiguousDeterminants,
    MAX(stats.DependentValuesPerDeterminant) AS MaxDependentValues,
    CASE
        WHEN MAX(stats.DependentValuesPerDeterminant) = 1 THEN 'supports_fd'
        ELSE 'needs_composite_key'
    END AS DependencySignal,
    MIN(stats.DeterminantValue) AS SampleDeterminantValue,
    MIN(stats.ExampleDependentValue) AS SampleDependentValue,
    CASE
        WHEN MAX(stats.DependentValuesPerDeterminant) = 1 THEN 'In den Demo-Daten verweist jeder beobachtete Determinantenwert auf genau einen abhaengigen Wert; die Abhaengigkeit eignet sich als Arbeitsannahme fuer eine funktionale Abhaengigkeit.'
        ELSE 'Mindestens ein Determinantenwert fuehrt auf mehrere abhaengige Werte; fuer diese Beobachtung sollte ein groesserer oder zusammengesetzter Schluessel diskutiert werden.'
    END AS Interpretation,
    MIN(stats.WorksheetFocus) AS WorksheetPrompt
FROM
(
    SELECT
        do.DeterminantLabel,
        do.DependentLabel,
        do.WorksheetFocus,
        do.DeterminantValue,
        COUNT(DISTINCT do.DependentValue) AS DependentValuesPerDeterminant,
        MIN(do.DependentValue) AS ExampleDependentValue
    FROM #DependencyObservations AS do
    GROUP BY
        do.DeterminantLabel,
        do.DependentLabel,
        do.WorksheetFocus,
        do.DeterminantValue
) AS stats
GROUP BY
    stats.DeterminantLabel,
    stats.DependentLabel;

SELECT
    dw.DeterminantLabel,
    dw.DependentLabel,
    dw.DeterminantCardinality,
    dw.StableDeterminantValues,
    dw.AmbiguousDeterminants,
    dw.MaxDependentValues,
    dw.DependencySignal,
    dw.SampleDeterminantValue,
    dw.SampleDependentValue,
    dw.Interpretation,
    dw.WorksheetPrompt
FROM #DependencyWorksheet AS dw
WHERE @OnlyStableDependencies = 0
   OR dw.DependencySignal = 'supports_fd'
ORDER BY
    CASE dw.DependencySignal
        WHEN 'supports_fd' THEN 1
        ELSE 2
    END,
    dw.DeterminantLabel,
    dw.DependentLabel;

CREATE TABLE #ModelingPrompts
(
    StepNumber         INT           NOT NULL,
    FocusArea          VARCHAR(80)   NOT NULL,
    PromptText         VARCHAR(260)  NOT NULL,
    SuggestedRelation  VARCHAR(120)  NOT NULL
);

INSERT INTO #ModelingPrompts
(
    StepNumber,
    FocusArea,
    PromptText,
    SuggestedRelation
)
VALUES
    (1, 'Student master data', 'Welche Attribute haengen stabil von StudentNo ab und sollten in einer eigenen Student-Relation landen?', 'Student(StudentNo, StudentName, ProgramCode, AdvisorCode, CampusCode)'),
    (2, 'Program master data', 'Wenn ProgramCode den ProgramName stabil bestimmt, wie wuerde eine kleine Program-Stammdatentabelle aussehen?', 'Program(ProgramCode, ProgramName)'),
    (3, 'Course offering', 'Warum reicht CourseCode allein nicht fuer InstructorCode, waehrend CourseCode + TermCode stabil wirkt?', 'CourseOffering(CourseCode, TermCode, InstructorCode, DeliveryMode)'),
    (4, 'Reference data', 'Welche weiteren Stammdaten lassen sich ueber AdvisorCode, CampusCode oder InstructorCode auslagern?', 'Advisor(...), Campus(...), Instructor(...)');

SELECT
    mp.StepNumber,
    mp.FocusArea,
    mp.PromptText,
    mp.SuggestedRelation
FROM #ModelingPrompts AS mp
ORDER BY
    mp.StepNumber;
