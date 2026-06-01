/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "ThirdNormalFormViolationExamples.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "01_Normalformen"

purpose: >
  Zeigt mehrere realistisch wirkende Tabellenmodelle mit transitiven
  Abhaengigkeiten, bewertet deren 3NF-Risiko und leitet eine moegliche
  Zerlegung in Stammdaten-, Lookup- und Bewegungsrelationen ab.

parameters:
  - name: "@ShowSourceData"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = Ausgangsdaten der didaktischen Beispieltabelle ausgeben"
  - name: "@OnlyViolations"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = nur erkannte 3NF-Verletzungen im Analyse-Resultset zeigen"

result_sets:
  - name: "SourceExampleRows"
    description: "Optionale Vorschau der didaktischen Tabellenzeilen mit moeglichen Transitiven"
  - name: "ThirdNormalFormAssessment"
    description: "Bewertet vorbereitete Determinanten auf stabile transitive Abhaengigkeiten und 3NF-Risiko"
  - name: "NormalizationTargets"
    description: "Skizziert Zielrelationen fuer die Aufloesung der gefundenen 3NF-Verletzungen"

dependencies:
  - "tempdb temporary tables"
  - "CROSS APPLY"
  - "COUNT(DISTINCT ...)"
  - "CASE"
  - "GROUP BY"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/01_Normalformen/SQLScripts/ThirdNormalFormViolationExamples.md"
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
    description: "Erstversion der didaktischen Beispielsammlung fuer 3NF-Verletzungen"

notes:
  - "Die Szenarien nutzen Demo-Daten und repraesentieren bewusst typische transitive Abhaengigkeiten aus Stammdaten- und Lookupfeldern"
  - "Jede vorbereitete Determinante ist absichtlich kein Primaerschluessel der Quelltabelle, damit 3NF-Risiken sichtbar werden"
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

DROP TABLE IF EXISTS #ExampleRows;
DROP TABLE IF EXISTS #TransitiveCandidates;
DROP TABLE IF EXISTS #DependencyObservations;
DROP TABLE IF EXISTS #ThirdNormalFormAssessment;
DROP TABLE IF EXISTS #NormalizationTargets;

CREATE TABLE #ExampleRows
(
    ScenarioName         VARCHAR(80)   NOT NULL,
    TableName            VARCHAR(80)   NOT NULL,
    PrimaryKeyColumn     VARCHAR(80)   NOT NULL,
    PrimaryKeyValue      VARCHAR(80)   NOT NULL,
    NaturalKeyValue      VARCHAR(80)   NOT NULL,
    NonKeyAttribute      VARCHAR(80)   NOT NULL,
    NonKeyValue          VARCHAR(120)  NOT NULL,
    TransitivelyBy       VARCHAR(80)   NOT NULL,
    TransitivelyValue    VARCHAR(120)  NOT NULL,
    AdditionalAttribute  VARCHAR(120)  NOT NULL
);

INSERT INTO #ExampleRows
(
    ScenarioName,
    TableName,
    PrimaryKeyColumn,
    PrimaryKeyValue,
    NaturalKeyValue,
    NonKeyAttribute,
    NonKeyValue,
    TransitivelyBy,
    TransitivelyValue,
    AdditionalAttribute
)
VALUES
    ('Customer orders', 'SalesOrder', 'OrderID', 'SO-1001', 'C-100', 'PostalCode', '10115', 'CityName', 'Berlin', 'RegionCode=DE-BE'),
    ('Customer orders', 'SalesOrder', 'OrderID', 'SO-1002', 'C-101', 'PostalCode', '10115', 'CityName', 'Berlin', 'RegionCode=DE-BE'),
    ('Customer orders', 'SalesOrder', 'OrderID', 'SO-1003', 'C-102', 'PostalCode', '20095', 'CityName', 'Hamburg', 'RegionCode=DE-HH'),
    ('Customer orders', 'SalesOrder', 'OrderID', 'SO-1004', 'C-103', 'PostalCode', '80331', 'CityName', 'Munich', 'RegionCode=DE-BY'),
    ('Course enrollment', 'Enrollment', 'EnrollmentID', 'EN-2001', 'DB100|2026S', 'InstructorCode', 'INS-DB1', 'InstructorName', 'Prof. Winter', 'DepartmentCode=DEP-DB'),
    ('Course enrollment', 'Enrollment', 'EnrollmentID', 'EN-2002', 'DB100|2026S', 'InstructorCode', 'INS-DB1', 'InstructorName', 'Prof. Winter', 'DepartmentCode=DEP-DB'),
    ('Course enrollment', 'Enrollment', 'EnrollmentID', 'EN-2003', 'DB100|2026W', 'InstructorCode', 'INS-DB3', 'InstructorName', 'Prof. Malik', 'DepartmentCode=DEP-DB'),
    ('Course enrollment', 'Enrollment', 'EnrollmentID', 'EN-2004', 'QA210|2026S', 'InstructorCode', 'INS-QA1', 'InstructorName', 'Prof. Hartmann', 'DepartmentCode=DEP-QA'),
    ('Asset assignments', 'AssetAssignment', 'AssignmentID', 'AS-3001', 'LAP-01', 'LocationCode', 'BER-HQ', 'LocationName', 'Berlin Headquarters', 'CountryCode=DE'),
    ('Asset assignments', 'AssetAssignment', 'AssignmentID', 'AS-3002', 'LAP-01', 'LocationCode', 'BER-HQ', 'LocationName', 'Berlin Headquarters', 'CountryCode=DE'),
    ('Asset assignments', 'AssetAssignment', 'AssignmentID', 'AS-3003', 'LAP-02', 'LocationCode', 'HAM-DC', 'LocationName', 'Hamburg Data Center', 'CountryCode=DE'),
    ('Asset assignments', 'AssetAssignment', 'AssignmentID', 'AS-3004', 'LAP-03', 'LocationCode', 'MUC-LAB', 'LocationName', 'Munich Lab', 'CountryCode=DE');

IF @ShowSourceData = 1
BEGIN
    SELECT
        er.ScenarioName,
        er.TableName,
        er.PrimaryKeyColumn,
        er.PrimaryKeyValue,
        er.NaturalKeyValue,
        er.NonKeyAttribute,
        er.NonKeyValue,
        er.TransitivelyBy,
        er.TransitivelyValue,
        er.AdditionalAttribute
    FROM #ExampleRows AS er
    ORDER BY
        er.ScenarioName,
        er.PrimaryKeyValue;
END;

CREATE TABLE #TransitiveCandidates
(
    ScenarioName              VARCHAR(80)   NOT NULL,
    TableName                 VARCHAR(80)   NOT NULL,
    PrimaryKeyColumn          VARCHAR(80)   NOT NULL,
    PrimaryKeySemantic        VARCHAR(120)  NOT NULL,
    DeterminantLabel          VARCHAR(80)   NOT NULL,
    DeterminantRole           VARCHAR(180)  NOT NULL,
    DependentLabel            VARCHAR(80)   NOT NULL,
    ViolationExplanation      VARCHAR(260)  NOT NULL,
    SuggestedReferenceTable   VARCHAR(140)  NOT NULL
);

INSERT INTO #TransitiveCandidates
(
    ScenarioName,
    TableName,
    PrimaryKeyColumn,
    PrimaryKeySemantic,
    DeterminantLabel,
    DeterminantRole,
    DependentLabel,
    ViolationExplanation,
    SuggestedReferenceTable
)
VALUES
    ('Customer orders', 'SalesOrder', 'OrderID', 'Jede Zeile repraesentiert einen Auftrag.', 'PostalCode', 'Nichtschluesselattribut in einer Auftragszeile', 'CityName', 'PostalCode bestimmt CityName, obwohl die Tabelle ueber OrderID identifiziert wird.', 'PostalCodeLookup(PostalCode, CityName, RegionCode)'),
    ('Course enrollment', 'Enrollment', 'EnrollmentID', 'Jede Zeile repraesentiert eine einzelne Einschreibung.', 'InstructorCode', 'Nichtschluesselattribut des Kursangebots innerhalb der Einschreibung', 'InstructorName', 'InstructorCode bestimmt InstructorName, obwohl die Einschreibung ueber EnrollmentID identifiziert wird.', 'Instructor(InstructorCode, InstructorName, DepartmentCode)'),
    ('Asset assignments', 'AssetAssignment', 'AssignmentID', 'Jede Zeile repraesentiert eine Asset-Zuweisung.', 'LocationCode', 'Nichtschluesselattribut innerhalb der Zuweisung', 'LocationName', 'LocationCode bestimmt LocationName, obwohl die Tabelle ueber AssignmentID identifiziert wird.', 'Location(LocationCode, LocationName, CountryCode)');

CREATE TABLE #DependencyObservations
(
    ScenarioName        VARCHAR(80)   NOT NULL,
    TableName           VARCHAR(80)   NOT NULL,
    PrimaryKeyColumn    VARCHAR(80)   NOT NULL,
    DeterminantLabel    VARCHAR(80)   NOT NULL,
    DeterminantValue    VARCHAR(120)  NOT NULL,
    DependentLabel      VARCHAR(80)   NOT NULL,
    DependentValue      VARCHAR(120)  NOT NULL
);

INSERT INTO #DependencyObservations
(
    ScenarioName,
    TableName,
    PrimaryKeyColumn,
    DeterminantLabel,
    DeterminantValue,
    DependentLabel,
    DependentValue
)
SELECT
    tc.ScenarioName,
    tc.TableName,
    tc.PrimaryKeyColumn,
    tc.DeterminantLabel,
    mapping.DeterminantValue,
    tc.DependentLabel,
    mapping.DependentValue
FROM #ExampleRows AS er
INNER JOIN #TransitiveCandidates AS tc
    ON tc.ScenarioName = er.ScenarioName
   AND tc.TableName = er.TableName
CROSS APPLY
(
    SELECT
        DeterminantValue =
            CASE tc.DeterminantLabel
                WHEN 'PostalCode' THEN er.NonKeyValue
                WHEN 'InstructorCode' THEN er.NonKeyValue
                WHEN 'LocationCode' THEN er.NonKeyValue
            END,
        DependentValue =
            CASE tc.DependentLabel
                WHEN 'CityName' THEN er.TransitivelyValue
                WHEN 'InstructorName' THEN er.TransitivelyValue
                WHEN 'LocationName' THEN er.TransitivelyValue
            END
) AS mapping;

CREATE TABLE #ThirdNormalFormAssessment
(
    ScenarioName               VARCHAR(80)   NOT NULL,
    TableName                  VARCHAR(80)   NOT NULL,
    PrimaryKeyColumn           VARCHAR(80)   NOT NULL,
    DeterminantLabel           VARCHAR(80)   NOT NULL,
    DependentLabel             VARCHAR(80)   NOT NULL,
    DistinctDeterminants       INT           NOT NULL,
    StableDeterminants         INT           NOT NULL,
    MaxDependentVariants       INT           NOT NULL,
    ThreeNfRisk                VARCHAR(30)   NOT NULL,
    WhyItViolates3NF           VARCHAR(260)  NOT NULL,
    SuggestedReferenceTable    VARCHAR(140)  NOT NULL,
    NormalizationAction        VARCHAR(260)  NOT NULL
);

INSERT INTO #ThirdNormalFormAssessment
(
    ScenarioName,
    TableName,
    PrimaryKeyColumn,
    DeterminantLabel,
    DependentLabel,
    DistinctDeterminants,
    StableDeterminants,
    MaxDependentVariants,
    ThreeNfRisk,
    WhyItViolates3NF,
    SuggestedReferenceTable,
    NormalizationAction
)
SELECT
    tc.ScenarioName,
    tc.TableName,
    tc.PrimaryKeyColumn,
    tc.DeterminantLabel,
    tc.DependentLabel,
    COUNT(*) AS DistinctDeterminants,
    SUM(CASE WHEN stats.DependentVariants = 1 THEN 1 ELSE 0 END) AS StableDeterminants,
    MAX(stats.DependentVariants) AS MaxDependentVariants,
    CASE
        WHEN MAX(stats.DependentVariants) = 1 THEN 'transitive_violation'
        ELSE 'review_dependency'
    END AS ThreeNfRisk,
    tc.ViolationExplanation,
    tc.SuggestedReferenceTable,
    CASE tc.ScenarioName
        WHEN 'Customer orders' THEN 'Lagere Ortsinformationen in eine Lookup-Tabelle aus und speichere im Auftrag nur den referenzierten Postleitzahlwert.'
        WHEN 'Course enrollment' THEN 'Fuehre eine Instructor-Stammdatentabelle ein und verweise aus dem Kursangebot oder der Einschreibung nur auf InstructorCode.'
        WHEN 'Asset assignments' THEN 'Normalisiere Standortstammdaten in eine eigene Relation und halte in der Zuweisung nur LocationCode.'
    END AS NormalizationAction
FROM #TransitiveCandidates AS tc
INNER JOIN
(
    SELECT
        do.ScenarioName,
        do.TableName,
        do.PrimaryKeyColumn,
        do.DeterminantLabel,
        do.DependentLabel,
        do.DeterminantValue,
        COUNT(DISTINCT do.DependentValue) AS DependentVariants
    FROM #DependencyObservations AS do
    GROUP BY
        do.ScenarioName,
        do.TableName,
        do.PrimaryKeyColumn,
        do.DeterminantLabel,
        do.DependentLabel,
        do.DeterminantValue
) AS stats
    ON stats.ScenarioName = tc.ScenarioName
   AND stats.TableName = tc.TableName
   AND stats.PrimaryKeyColumn = tc.PrimaryKeyColumn
   AND stats.DeterminantLabel = tc.DeterminantLabel
   AND stats.DependentLabel = tc.DependentLabel
GROUP BY
    tc.ScenarioName,
    tc.TableName,
    tc.PrimaryKeyColumn,
    tc.DeterminantLabel,
    tc.DependentLabel,
    tc.ViolationExplanation,
    tc.SuggestedReferenceTable;

SELECT
    tfa.ScenarioName,
    tfa.TableName,
    tfa.PrimaryKeyColumn,
    tfa.DeterminantLabel,
    tfa.DependentLabel,
    tfa.DistinctDeterminants,
    tfa.StableDeterminants,
    tfa.MaxDependentVariants,
    tfa.ThreeNfRisk,
    tfa.WhyItViolates3NF,
    tfa.SuggestedReferenceTable,
    tfa.NormalizationAction
FROM #ThirdNormalFormAssessment AS tfa
WHERE @OnlyViolations = 0
   OR tfa.ThreeNfRisk = 'transitive_violation'
ORDER BY
    CASE tfa.ThreeNfRisk
        WHEN 'transitive_violation' THEN 1
        ELSE 2
    END,
    tfa.ScenarioName,
    tfa.DeterminantLabel;

CREATE TABLE #NormalizationTargets
(
    StepNumber          INT           NOT NULL,
    ScenarioName        VARCHAR(80)   NOT NULL,
    TargetRelation      VARCHAR(140)  NOT NULL,
    KeyColumns          VARCHAR(120)  NOT NULL,
    ColumnsToMove       VARCHAR(200)  NOT NULL,
    Benefit             VARCHAR(260)  NOT NULL
);

INSERT INTO #NormalizationTargets
(
    StepNumber,
    ScenarioName,
    TargetRelation,
    KeyColumns,
    ColumnsToMove,
    Benefit
)
VALUES
    (1, 'Customer orders', 'PostalCodeLookup', 'PostalCode', 'CityName, RegionCode', 'Entfernt transitive Ortsattribute aus jeder Auftragszeile.'),
    (2, 'Course enrollment', 'Instructor', 'InstructorCode', 'InstructorName, DepartmentCode', 'Zentralisiert Lehrendenstammdaten statt Wiederholung je Einschreibung oder Kursangebot.'),
    (3, 'Asset assignments', 'Location', 'LocationCode', 'LocationName, CountryCode', 'Lagert Standortstammdaten aus und reduziert Pflegeaufwand bei Umbenennungen.');

SELECT
    nt.StepNumber,
    nt.ScenarioName,
    nt.TargetRelation,
    nt.KeyColumns,
    nt.ColumnsToMove,
    nt.Benefit
FROM #NormalizationTargets AS nt
ORDER BY
    nt.StepNumber;
