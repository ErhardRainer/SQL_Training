/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "DetectPartialDependencies.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "01_Normalformen"

purpose: >
  Prueft eine didaktische Einschreibungsrelation mit zusammengesetztem
  Schluessel auf Merkmale partieller Abhaengigkeiten. Das Skript macht
  sichtbar, welche Attribute bereits durch einen Teil des Schluessels
  bestimmt werden und damit als Einstieg fuer 2NF-Verletzungen dienen.

parameters:
  - name: "@ShowSourceData"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = Vorschau der didaktischen Ausgangsdaten ausgeben"
  - name: "@OnlyViolations"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = nur erkannte partielle Abhaengigkeiten ausgeben"

result_sets:
  - name: "SourceDataPreview"
    description: "Optionale Vorschau der denormalisierten Einschreibungsdaten"
  - name: "PartialDependencyAudit"
    description: "Bewertet ausgewaehlte Determinanten gegen den zusammengesetzten Schluessel"
  - name: "SecondNormalFormRefactorHints"
    description: "Zeigt didaktische Zerlegungsideen fuer eine 2NF-naehere Struktur"

dependencies:
  - "tempdb temporary tables"
  - "GROUP BY"
  - "COUNT(DISTINCT ...)"
  - "UNION ALL"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/01_Normalformen/SQLScripts/DetectPartialDependencies.md"
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
    description: "Erstversion des didaktischen Partial-Dependency-Checks"

notes:
  - "Der didaktische Schluessel ist StudentNo + CourseCode + TermCode"
  - "Partielle Abhaengigkeiten werden auf vorbereiteten Demo-Daten illustriert und nicht allgemeingueltig bewiesen"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @ShowSourceData BIT = 1;
DECLARE @OnlyViolations BIT = 0;

IF @ShowSourceData NOT IN (0, 1)
BEGIN
    THROW 50000, '@ShowSourceData muss 0 oder 1 sein.', 1;
END;

IF @OnlyViolations NOT IN (0, 1)
BEGIN
    THROW 50001, '@OnlyViolations muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #EnrollmentWide;
DROP TABLE IF EXISTS #PartialDependencyAudit;
DROP TABLE IF EXISTS #RefactorHints;

CREATE TABLE #EnrollmentWide
(
    StudentNo           VARCHAR(20)  NOT NULL,
    StudentName         VARCHAR(50)  NOT NULL,
    HomeDepartmentCode  VARCHAR(20)  NOT NULL,
    HomeDepartmentName  VARCHAR(100) NOT NULL,
    CourseCode          VARCHAR(20)  NOT NULL,
    CourseTitle         VARCHAR(100) NOT NULL,
    Credits             TINYINT      NOT NULL,
    LecturerID          INT          NOT NULL,
    LecturerName        VARCHAR(50)  NOT NULL,
    TermCode            VARCHAR(10)  NOT NULL,
    TermLabel           VARCHAR(30)  NOT NULL,
    EnrollmentStatus    VARCHAR(20)  NOT NULL
);

INSERT INTO #EnrollmentWide
(
    StudentNo,
    StudentName,
    HomeDepartmentCode,
    HomeDepartmentName,
    CourseCode,
    CourseTitle,
    Credits,
    LecturerID,
    LecturerName,
    TermCode,
    TermLabel,
    EnrollmentStatus
)
VALUES
    ('S-1001', 'Alice Berger', 'CS',   'Computer Science', 'DB100', 'Relational Basics',      5, 10, 'Dr. Koch',   '2026S', 'Sommer 2026', 'active'),
    ('S-1001', 'Alice Berger', 'CS',   'Computer Science', 'DB220', 'Normalization Workshop', 4, 14, 'Prof. Hahn', '2026S', 'Sommer 2026', 'active'),
    ('S-1002', 'Boris Klein',  'CS',   'Computer Science', 'DB100', 'Relational Basics',      5, 10, 'Dr. Koch',   '2026S', 'Sommer 2026', 'active'),
    ('S-1002', 'Boris Klein',  'CS',   'Computer Science', 'QA300', 'Data Quality Clinic',    3, 18, 'Dr. Wolf',   '2026W', 'Winter 2026', 'active'),
    ('S-1003', 'Cem Yilmaz',   'DATA', 'Data Engineering', 'DB100', 'Relational Basics',      5, 10, 'Dr. Koch',   '2026W', 'Winter 2026', 'active'),
    ('S-1003', 'Cem Yilmaz',   'DATA', 'Data Engineering', 'DB220', 'Normalization Workshop', 4, 14, 'Prof. Hahn', '2026S', 'Sommer 2026', 'active'),
    ('S-1004', 'Dina Maurer',  'QA',   'Quality Assurance','QA300', 'Data Quality Clinic',    3, 18, 'Dr. Wolf',   '2026W', 'Winter 2026', 'waitlist'),
    ('S-1005', 'Eva Schmitt',  'ARCH', 'Architecture',     'MOD410','Model Review Lab',       2, 21, 'Dr. Stern',  '2026S', 'Sommer 2026', 'active');

IF @ShowSourceData = 1
BEGIN
    SELECT
        ew.StudentNo,
        ew.StudentName,
        ew.HomeDepartmentCode,
        ew.HomeDepartmentName,
        ew.CourseCode,
        ew.CourseTitle,
        ew.Credits,
        ew.LecturerID,
        ew.LecturerName,
        ew.TermCode,
        ew.TermLabel,
        ew.EnrollmentStatus
    FROM #EnrollmentWide AS ew
    ORDER BY
        ew.StudentNo,
        ew.CourseCode,
        ew.TermCode;
END;

CREATE TABLE #PartialDependencyAudit
(
    DeterminantColumns               VARCHAR(100) NOT NULL,
    DependentColumns                 VARCHAR(150) NOT NULL,
    DeterminantIsProperKeySubset     BIT          NOT NULL,
    DistinctDeterminants             INT          NOT NULL,
    MaxDependentVariantsPerSubset    INT          NOT NULL,
    DependencyStatus                 VARCHAR(40)  NOT NULL,
    Interpretation                   VARCHAR(200) NOT NULL
);

INSERT INTO #PartialDependencyAudit
(
    DeterminantColumns,
    DependentColumns,
    DeterminantIsProperKeySubset,
    DistinctDeterminants,
    MaxDependentVariantsPerSubset,
    DependencyStatus,
    Interpretation
)
SELECT
    'StudentNo',
    'StudentName, HomeDepartmentCode, HomeDepartmentName',
    CAST(1 AS BIT),
    COUNT(*) AS DistinctDeterminants,
    MAX(VariantCount) AS MaxDependentVariantsPerSubset,
    CASE
        WHEN MAX(VariantCount) = 1 THEN 'partial_dependency'
        ELSE 'not_stable'
    END,
    'Stammdaten des Lernenden haengen nur von StudentNo ab und nicht vom vollen Einschreibeschluessel.'
FROM
(
    SELECT
        ew.StudentNo,
        COUNT(DISTINCT CONCAT(ew.StudentName, '|', ew.HomeDepartmentCode, '|', ew.HomeDepartmentName)) AS VariantCount
    FROM #EnrollmentWide AS ew
    GROUP BY
        ew.StudentNo
) AS student_check

UNION ALL

SELECT
    'CourseCode',
    'CourseTitle, Credits, LecturerID, LecturerName',
    CAST(1 AS BIT),
    COUNT(*),
    MAX(VariantCount),
    CASE
        WHEN MAX(VariantCount) = 1 THEN 'partial_dependency'
        ELSE 'not_stable'
    END,
    'Kursattribute werden bereits durch CourseCode bestimmt und nicht erst durch StudentNo + CourseCode + TermCode.'
FROM
(
    SELECT
        ew.CourseCode,
        COUNT(DISTINCT CONCAT(ew.CourseTitle, '|', ew.Credits, '|', ew.LecturerID, '|', ew.LecturerName)) AS VariantCount
    FROM #EnrollmentWide AS ew
    GROUP BY
        ew.CourseCode
) AS course_check

UNION ALL

SELECT
    'TermCode',
    'TermLabel',
    CAST(1 AS BIT),
    COUNT(*),
    MAX(VariantCount),
    CASE
        WHEN MAX(VariantCount) = 1 THEN 'partial_dependency'
        ELSE 'not_stable'
    END,
    'Die sprechende Terminbezeichnung haengt nur vom Termin-Code ab.'
FROM
(
    SELECT
        ew.TermCode,
        COUNT(DISTINCT ew.TermLabel) AS VariantCount
    FROM #EnrollmentWide AS ew
    GROUP BY
        ew.TermCode
) AS term_check

UNION ALL

SELECT
    'StudentNo, CourseCode, TermCode',
    'EnrollmentStatus',
    CAST(0 AS BIT),
    COUNT(*),
    MAX(VariantCount),
    CASE
        WHEN MAX(VariantCount) = 1 THEN 'full_key_dependency'
        ELSE 'not_stable'
    END,
    'Der Einschreibestatus wird didaktisch als Merkmal der gesamten Belegung behandelt.'
FROM
(
    SELECT
        ew.StudentNo,
        ew.CourseCode,
        ew.TermCode,
        COUNT(DISTINCT ew.EnrollmentStatus) AS VariantCount
    FROM #EnrollmentWide AS ew
    GROUP BY
        ew.StudentNo,
        ew.CourseCode,
        ew.TermCode
) AS key_check;

SELECT
    pda.DeterminantColumns,
    pda.DependentColumns,
    pda.DeterminantIsProperKeySubset,
    pda.DistinctDeterminants,
    pda.MaxDependentVariantsPerSubset,
    pda.DependencyStatus,
    pda.Interpretation
FROM #PartialDependencyAudit AS pda
WHERE @OnlyViolations = 0
   OR pda.DependencyStatus = 'partial_dependency'
ORDER BY
    CASE pda.DependencyStatus
        WHEN 'partial_dependency' THEN 1
        WHEN 'full_key_dependency' THEN 2
        ELSE 3
    END,
    pda.DeterminantColumns;

CREATE TABLE #RefactorHints
(
    StepNumber      INT          NOT NULL,
    TargetRelation  VARCHAR(60)  NOT NULL,
    SuggestedKey    VARCHAR(100) NOT NULL,
    ColumnsToKeep   VARCHAR(200) NOT NULL,
    Reasoning       VARCHAR(250) NOT NULL
);

INSERT INTO #RefactorHints
(
    StepNumber,
    TargetRelation,
    SuggestedKey,
    ColumnsToKeep,
    Reasoning
)
VALUES
    (1, 'StudentDimension',    'StudentNo',                     'StudentNo, StudentName, HomeDepartmentCode, HomeDepartmentName', 'Lagert Lernenden-Stammdaten aus, damit sie nicht pro Kursbelegung wiederholt werden.'),
    (2, 'CourseDimension',     'CourseCode',                    'CourseCode, CourseTitle, Credits, LecturerID, LecturerName',     'Separiert kursbezogene Attribute, die nur von CourseCode abhaengen.'),
    (3, 'TermDimension',       'TermCode',                      'TermCode, TermLabel',                                             'Holt Terminbezeichnungen aus der Einschreibung heraus.'),
    (4, 'StudentEnrollment',   'StudentNo, CourseCode, TermCode','StudentNo, CourseCode, TermCode, EnrollmentStatus',               'Behaelt nur Attribute, die von der gesamten Schluesselkombination abhaengen.');

SELECT
    rh.StepNumber,
    rh.TargetRelation,
    rh.SuggestedKey,
    rh.ColumnsToKeep,
    rh.Reasoning
FROM #RefactorHints AS rh
ORDER BY
    rh.StepNumber;
