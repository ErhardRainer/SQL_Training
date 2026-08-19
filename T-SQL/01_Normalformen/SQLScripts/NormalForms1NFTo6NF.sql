/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "NormalForms1NFTo6NF.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "01_Normalformen"
purpose: >
  Fuehrt anhand von Demo-Daten von einer atomaren Bestell- und Kursanmeldungsrelation
  ueber 2NF, 3NF und BCNF bis zu Spezialbeispielen fuer 4NF, 5NF und 6NF.
parameters:
  - name: "@ShowIntermediateData"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = gibt nach jeder Stufe die erzeugten Demo-Relationen aus"
result_sets:
  - name: "NormalizationStages"
    description: "Zusammenfassung der Regeln, Probleme und Zerlegungen je Normalform"
  - name: "IntermediateRelations"
    description: "Optionale Datenvorschau der jeweiligen Stufe"
dependencies:
  - "SQL Server 2016 SP2 or later (DROP TABLE IF EXISTS)"
  - "tempdb temporary tables"
  - "PRIMARY KEY"
  - "FOREIGN KEY"
safety:
  level: "read-only-tempdb"
  writes_data: false
documentation:
  markdown_file: "T-SQL/01_Normalformen/SQLScripts/NormalForms1NFTo6NF.md"
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
    date: "2026-08-17"
    user: "ER"
    description: "Erstversion des durchgaengigen Normalformen-Labors"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @ShowIntermediateData BIT = 1;

IF @ShowIntermediateData NOT IN (0, 1)
    THROW 50000, '@ShowIntermediateData muss 0 oder 1 sein.', 1;

-- Alle Objekte sind lokale temporaere Tabellen; das Skript aendert keine Fachdaten.
DROP TABLE IF EXISTS #Enrollment1NF;
DROP TABLE IF EXISTS #Student2NF;
DROP TABLE IF EXISTS #Course2NF;
DROP TABLE IF EXISTS #Term2NF;
DROP TABLE IF EXISTS #Offering2NF;
DROP TABLE IF EXISTS #Enrollment2NF;
DROP TABLE IF EXISTS #Program3NF;
DROP TABLE IF EXISTS #Student3NF;
DROP TABLE IF EXISTS #Instructor3NF;
DROP TABLE IF EXISTS #Room3NF;
DROP TABLE IF EXISTS #Offering3NF;
DROP TABLE IF EXISTS #TeachingAssignment3NF;
DROP TABLE IF EXISTS #InstructorSlotBCNF;
DROP TABLE IF EXISTS #RoomSlotBCNF;
DROP TABLE IF EXISTS #StudentLanguageSkill4NF;
DROP TABLE IF EXISTS #StudentLanguage4NF;
DROP TABLE IF EXISTS #StudentSkill4NF;
DROP TABLE IF EXISTS #SupplierPartProject5NF;
DROP TABLE IF EXISTS #SupplierPart5NF;
DROP TABLE IF EXISTS #SupplierProject5NF;
DROP TABLE IF EXISTS #PartProject5NF;
DROP TABLE IF EXISTS #EmployeeAssignment5NF;
DROP TABLE IF EXISTS #EmployeeRole6NF;
DROP TABLE IF EXISTS #EmployeeCostCenter6NF;

-- 1NF: alle Werte sind atomar; die breite Relation enthaelt dennoch Redundanz.
CREATE TABLE #Enrollment1NF
(
    StudentID       int          NOT NULL,
    StudentName     varchar(80)  NOT NULL,
    ProgramCode     varchar(10)  NOT NULL,
    ProgramName     varchar(80)  NOT NULL,
    CourseCode      varchar(10)  NOT NULL,
    CourseTitle     varchar(100) NOT NULL,
    TermCode        char(6)      NOT NULL,
    TermName        varchar(40)  NOT NULL,
    InstructorID    int          NOT NULL,
    InstructorName  varchar(80)  NOT NULL,
    RoomCode        varchar(10)  NOT NULL,
    RoomBuilding    varchar(60)  NOT NULL,
    Grade           char(2)      NULL,
    CONSTRAINT PK_Enrollment1NF PRIMARY KEY (StudentID, CourseCode, TermCode)
);

INSERT INTO #Enrollment1NF
    (StudentID, StudentName, ProgramCode, ProgramName, CourseCode, CourseTitle,
     TermCode, TermName, InstructorID, InstructorName, RoomCode, RoomBuilding, Grade)
VALUES
    (101, 'Anna Berger', 'CS', 'Computer Science', 'DB101', 'Database Design', '2026S1', 'Sommer 2026', 10, 'Mira Hoffmann', 'B-101', 'Berlin Mitte', 'A'),
    (101, 'Anna Berger', 'CS', 'Computer Science', 'PR201', 'Python Basics',   '2026S1', 'Sommer 2026', 11, 'Jonas Weber',   'B-102', 'Berlin Mitte', 'B'),
    (102, 'Boris Klein', 'CS', 'Computer Science', 'DB101', 'Database Design', '2026S1', 'Sommer 2026', 10, 'Mira Hoffmann', 'B-101', 'Berlin Mitte', 'B'),
    (103, 'Clara Roth',  'BA', 'Business Analytics','DB101','Database Design', '2026S1', 'Sommer 2026', 10, 'Mira Hoffmann', 'B-101', 'Berlin Mitte', 'A');

-- 2NF: Teilabhaengigkeiten vom zusammengesetzten Schluessel werden ausgelagert.
CREATE TABLE #Student2NF
(
    StudentID int NOT NULL PRIMARY KEY,
    StudentName varchar(80) NOT NULL,
    ProgramCode varchar(10) NOT NULL,
    ProgramName varchar(80) NOT NULL -- bleibt absichtlich fuer das 3NF-Beispiel
);
CREATE TABLE #Course2NF
(
    CourseCode varchar(10) NOT NULL PRIMARY KEY,
    CourseTitle varchar(100) NOT NULL
);
CREATE TABLE #Term2NF
(
    TermCode char(6) NOT NULL PRIMARY KEY,
    TermName varchar(40) NOT NULL
);
CREATE TABLE #Offering2NF
(
    CourseCode varchar(10) NOT NULL,
    TermCode char(6) NOT NULL,
    InstructorID int NOT NULL,
    InstructorName varchar(80) NOT NULL, -- transitiv fuer 3NF
    RoomCode varchar(10) NOT NULL,
    RoomBuilding varchar(60) NOT NULL, -- transitiv fuer 3NF
    CONSTRAINT PK_Offering2NF PRIMARY KEY (CourseCode, TermCode)
);
CREATE TABLE #Enrollment2NF
(
    StudentID int NOT NULL,
    CourseCode varchar(10) NOT NULL,
    TermCode char(6) NOT NULL,
    Grade char(2) NULL,
    CONSTRAINT PK_Enrollment2NF PRIMARY KEY (StudentID, CourseCode, TermCode)
);

INSERT INTO #Student2NF SELECT DISTINCT StudentID, StudentName, ProgramCode, ProgramName FROM #Enrollment1NF;
INSERT INTO #Course2NF SELECT DISTINCT CourseCode, CourseTitle FROM #Enrollment1NF;
INSERT INTO #Term2NF SELECT DISTINCT TermCode, TermName FROM #Enrollment1NF;
INSERT INTO #Offering2NF SELECT DISTINCT CourseCode, TermCode, InstructorID, InstructorName, RoomCode, RoomBuilding FROM #Enrollment1NF;
INSERT INTO #Enrollment2NF SELECT StudentID, CourseCode, TermCode, Grade FROM #Enrollment1NF;

-- 3NF: transitive Abhaengigkeiten ProgramCode -> ProgramName, InstructorID -> Name
-- und RoomCode -> RoomBuilding werden in Stammdatenrelationen verschoben.
CREATE TABLE #Program3NF (ProgramCode varchar(10) NOT NULL PRIMARY KEY, ProgramName varchar(80) NOT NULL);
CREATE TABLE #Student3NF
(
    StudentID int NOT NULL PRIMARY KEY,
    StudentName varchar(80) NOT NULL,
    ProgramCode varchar(10) NOT NULL
);
CREATE TABLE #Instructor3NF (InstructorID int NOT NULL PRIMARY KEY, InstructorName varchar(80) NOT NULL);
CREATE TABLE #Room3NF (RoomCode varchar(10) NOT NULL PRIMARY KEY, RoomBuilding varchar(60) NOT NULL);
CREATE TABLE #Offering3NF
(
    CourseCode varchar(10) NOT NULL,
    TermCode char(6) NOT NULL,
    InstructorID int NOT NULL,
    RoomCode varchar(10) NOT NULL,
    CONSTRAINT PK_Offering3NF PRIMARY KEY (CourseCode, TermCode)
);

INSERT INTO #Program3NF SELECT DISTINCT ProgramCode, ProgramName FROM #Student2NF;
INSERT INTO #Student3NF SELECT StudentID, StudentName, ProgramCode FROM #Student2NF;
INSERT INTO #Instructor3NF SELECT DISTINCT InstructorID, InstructorName FROM #Offering2NF;
INSERT INTO #Room3NF SELECT DISTINCT RoomCode, RoomBuilding FROM #Offering2NF;
INSERT INTO #Offering3NF SELECT CourseCode, TermCode, InstructorID, RoomCode FROM #Offering2NF;

-- BCNF: (StudentID, CourseCode) und (StudentID, InstructorID) sind Kandidatenschluessel.
-- Die Fachregel InstructorID -> CourseCode verletzt BCNF, denn InstructorID ist kein
-- Superschluessel. 3NF bleibt erfuellt, weil CourseCode ein Schluesselattribut ist.
CREATE TABLE #TeachingAssignment3NF
(
    StudentID int NOT NULL,
    InstructorID int NOT NULL,
    CourseCode varchar(10) NOT NULL,
    CONSTRAINT PK_TeachingAssignment3NF PRIMARY KEY (StudentID, CourseCode),
    CONSTRAINT UQ_TeachingAssignment3NF_StudentInstructor UNIQUE (StudentID, InstructorID)
);
INSERT INTO #TeachingAssignment3NF VALUES
    (101, 10, 'DB101'), (102, 10, 'DB101'), (103, 11, 'PR201');

CREATE TABLE #InstructorSlotBCNF
(
    InstructorID int NOT NULL,
    CourseCode varchar(10) NOT NULL,
    CONSTRAINT PK_InstructorSlotBCNF PRIMARY KEY (InstructorID)
);
CREATE TABLE #RoomSlotBCNF
(
    StudentID int NOT NULL,
    InstructorID int NOT NULL,
    CONSTRAINT PK_RoomSlotBCNF PRIMARY KEY (StudentID, InstructorID)
);
INSERT INTO #InstructorSlotBCNF SELECT DISTINCT InstructorID, CourseCode FROM #TeachingAssignment3NF;
INSERT INTO #RoomSlotBCNF SELECT StudentID, InstructorID FROM #TeachingAssignment3NF;

-- 4NF: Sprache und Kompetenz sind zwei unabhaengige Mengen je Student.
CREATE TABLE #StudentLanguageSkill4NF
(
    StudentID int NOT NULL,
    LanguageCode char(2) NOT NULL,
    SkillCode varchar(30) NOT NULL,
    CONSTRAINT PK_StudentLanguageSkill4NF PRIMARY KEY (StudentID, LanguageCode, SkillCode)
);
INSERT INTO #StudentLanguageSkill4NF VALUES
    (101, 'DE', 'SQL'), (101, 'DE', 'Python'), (101, 'EN', 'SQL'), (101, 'EN', 'Python');

CREATE TABLE #StudentLanguage4NF (StudentID int NOT NULL, LanguageCode char(2) NOT NULL, CONSTRAINT PK_StudentLanguage4NF PRIMARY KEY (StudentID, LanguageCode));
CREATE TABLE #StudentSkill4NF (StudentID int NOT NULL, SkillCode varchar(30) NOT NULL, CONSTRAINT PK_StudentSkill4NF PRIMARY KEY (StudentID, SkillCode));
INSERT INTO #StudentLanguage4NF SELECT DISTINCT StudentID, LanguageCode FROM #StudentLanguageSkill4NF;
INSERT INTO #StudentSkill4NF SELECT DISTINCT StudentID, SkillCode FROM #StudentLanguageSkill4NF;

-- 5NF: Dreifachvertraege werden nur dann in Paarrelationen zerlegt, wenn die
-- Fachregel garantiert: Ein Tripel ist gueltig genau dann, wenn alle drei Paare gueltig sind.
CREATE TABLE #SupplierPartProject5NF
(
    SupplierCode varchar(10) NOT NULL,
    PartCode varchar(10) NOT NULL,
    ProjectCode varchar(10) NOT NULL,
    CONSTRAINT PK_SupplierPartProject5NF PRIMARY KEY (SupplierCode, PartCode, ProjectCode)
);
INSERT INTO #SupplierPartProject5NF VALUES ('SUP1', 'P1', 'PRJ1'), ('SUP1', 'P2', 'PRJ1');
CREATE TABLE #SupplierPart5NF (SupplierCode varchar(10) NOT NULL, PartCode varchar(10) NOT NULL, CONSTRAINT PK_SupplierPart5NF PRIMARY KEY (SupplierCode, PartCode));
CREATE TABLE #SupplierProject5NF (SupplierCode varchar(10) NOT NULL, ProjectCode varchar(10) NOT NULL, CONSTRAINT PK_SupplierProject5NF PRIMARY KEY (SupplierCode, ProjectCode));
CREATE TABLE #PartProject5NF (PartCode varchar(10) NOT NULL, ProjectCode varchar(10) NOT NULL, CONSTRAINT PK_PartProject5NF PRIMARY KEY (PartCode, ProjectCode));
INSERT INTO #SupplierPart5NF SELECT DISTINCT SupplierCode, PartCode FROM #SupplierPartProject5NF;
INSERT INTO #SupplierProject5NF SELECT DISTINCT SupplierCode, ProjectCode FROM #SupplierPartProject5NF;
INSERT INTO #PartProject5NF SELECT DISTINCT PartCode, ProjectCode FROM #SupplierPartProject5NF;

-- 6NF: zeitlich unabhaengig aenderbare Fakten erhalten jeweils eine eigene Relation.
CREATE TABLE #EmployeeAssignment5NF
(
    EmployeeID int NOT NULL,
    ValidFrom date NOT NULL,
    ValidTo date NOT NULL,
    RoleName varchar(50) NOT NULL,
    CostCenter varchar(20) NOT NULL,
    CONSTRAINT PK_EmployeeAssignment5NF PRIMARY KEY (EmployeeID, ValidFrom)
);
INSERT INTO #EmployeeAssignment5NF VALUES (900, '2026-01-01', '2026-06-30', 'Analyst', 'CC-10');
CREATE TABLE #EmployeeRole6NF (EmployeeID int NOT NULL, ValidFrom date NOT NULL, ValidTo date NOT NULL, RoleName varchar(50) NOT NULL, CONSTRAINT PK_EmployeeRole6NF PRIMARY KEY (EmployeeID, ValidFrom));
CREATE TABLE #EmployeeCostCenter6NF (EmployeeID int NOT NULL, ValidFrom date NOT NULL, ValidTo date NOT NULL, CostCenter varchar(20) NOT NULL, CONSTRAINT PK_EmployeeCostCenter6NF PRIMARY KEY (EmployeeID, ValidFrom));
INSERT INTO #EmployeeRole6NF SELECT EmployeeID, ValidFrom, ValidTo, RoleName FROM #EmployeeAssignment5NF;
INSERT INTO #EmployeeCostCenter6NF SELECT EmployeeID, ValidFrom, ValidTo, CostCenter FROM #EmployeeAssignment5NF;

SELECT *
FROM (VALUES
    ('1NF',  'Atomare Werte und keine Wiederholungsgruppen', 'Breite Relation ist atomar, wiederholt aber Stammdaten.', 'Ausgangsrelation #Enrollment1NF'),
    ('2NF',  'Keine Teilabhaengigkeit von Teil eines zusammengesetzten Schluessels', 'Student, Kurs, Termin und Angebot haengen nicht von der ganzen Anmeldung ab.', 'Stammdaten und #Enrollment2NF trennen'),
    ('3NF',  'Keine transitive Abhaengigkeit von Nichtschluesselattributen', 'ProgramName, InstructorName und RoomBuilding haengen von Codes/IDs ab.', 'Program, Instructor und Room auslagern'),
    ('BCNF', 'Jede Determinante ist ein Kandidatenschluessel', 'InstructorID bestimmt CourseCode, ist aber kein Superschluessel.', 'Student-Dozent und Dozent-Kurs trennen'),
    ('4NF',  'Keine unabhaengigen Mehrwertabhaengigkeiten', 'Sprachen und Kompetenzen erzeugen ein kartesisches Produkt.', 'StudentLanguage und StudentSkill trennen'),
    ('5NF',  'Keine weiter zerlegbare Join-Abhaengigkeit', 'Lieferant-Teil-Projekt kann unter strenger Fachregel paarweise zerlegt werden.', 'Drei Paarrelationen verwenden'),
    ('6NF',  'Jede Relation beschreibt einen irreduziblen, oft zeitlichen Fakt', 'Rolle und Kostenstelle koennen zu unterschiedlichen Zeitpunkten wechseln.', 'Zeitliche Fakten separat fuehren')
) AS s(Normalform, Regel, Beobachtung, Zerlegung)
ORDER BY CASE Normalform WHEN '1NF' THEN 1 WHEN '2NF' THEN 2 WHEN '3NF' THEN 3 WHEN 'BCNF' THEN 4 WHEN '4NF' THEN 5 WHEN '5NF' THEN 6 ELSE 7 END;

IF @ShowIntermediateData = 1
BEGIN
    SELECT '1NF: atomare Ausgangsrelation' AS Stage, * FROM #Enrollment1NF ORDER BY StudentID, CourseCode;
    SELECT '2NF: Anmeldungen' AS Stage, * FROM #Enrollment2NF ORDER BY StudentID, CourseCode;
    SELECT '3NF: Kursangebote' AS Stage, * FROM #Offering3NF ORDER BY CourseCode, TermCode;
    SELECT 'BCNF: Student-Dozent-Zuordnung' AS Stage, * FROM #RoomSlotBCNF ORDER BY StudentID, InstructorID;
    SELECT '4NF: unabhaengige Sprachen' AS Stage, * FROM #StudentLanguage4NF ORDER BY StudentID, LanguageCode;
    SELECT '4NF: unabhaengige Kompetenzen' AS Stage, * FROM #StudentSkill4NF ORDER BY StudentID, SkillCode;
    SELECT '5NF: Lieferant-Teil' AS Stage, * FROM #SupplierPart5NF ORDER BY SupplierCode, PartCode;
    SELECT '6NF: Rollenverlauf' AS Stage, * FROM #EmployeeRole6NF ORDER BY EmployeeID, ValidFrom;
    SELECT '6NF: Kostenstellenverlauf' AS Stage, * FROM #EmployeeCostCenter6NF ORDER BY EmployeeID, ValidFrom;
END;
