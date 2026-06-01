/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "DetectRepeatingGroups.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "01_Normalformen"

purpose: >
  Analysiert eine didaktisch denormalisierte Demo-Tabelle auf moegliche
  Wiederholungsgruppen. Das Skript macht Spaltenfamilien wie Phone1..3,
  SkillTag1..3 und Session1..2 sichtbar und liefert einen Einstieg fuer
  die Diskussion ueber 1NF und spaetere Auslagerung in Kindtabellen.

parameters:
  - name: "@ShowSourceData"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = Vorschau der breiten Demo-Tabelle ausgeben"
  - name: "@IncludeNormalizedPreview"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zusaetzlich eine zeilenorientierte Normalisierungs-Vorschau ausgeben"

result_sets:
  - name: "SourceDataPreview"
    description: "Optionale Vorschau der denormalisierten Ausgangsdaten"
  - name: "RepeatingGroupAudit"
    description: "Bewertet erkannte Spaltenfamilien und deren Belegung als moegliche Wiederholungsgruppen"
  - name: "NormalizedPreview"
    description: "Optionale Vorschau einer zeilenorientierten 1NF-naeheren Darstellung"
  - name: "NormalizationHints"
    description: "Zeigt didaktische Zerlegungsideen fuer die Auslagerung der Wiederholungsgruppen"

dependencies:
  - "tempdb temporary tables"
  - "CROSS APPLY"
  - "GROUP BY"
  - "COUNT(DISTINCT ...)"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/01_Normalformen/SQLScripts/DetectRepeatingGroups.md"
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
    description: "Erstversion des didaktischen Repeating-Group-Audits"

notes:
  - "Die Demo-Relation verwendet absichtlich nummerierte Spaltenfamilien als 1NF-Gegenbeispiel"
  - "Die Normalisierungs-Vorschau zeigt eine didaktische Zielstruktur und keinen produktiven Migrationsplan"
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @ShowSourceData BIT = 1;
DECLARE @IncludeNormalizedPreview BIT = 1;

IF @ShowSourceData NOT IN (0, 1)
BEGIN
    THROW 50000, '@ShowSourceData muss 0 oder 1 sein.', 1;
END;

IF @IncludeNormalizedPreview NOT IN (0, 1)
BEGIN
    THROW 50001, '@IncludeNormalizedPreview muss 0 oder 1 sein.', 1;
END;

DROP TABLE IF EXISTS #WorkshopRegistrationWide;
DROP TABLE IF EXISTS #RepeatingValues;
DROP TABLE IF EXISTS #RepeatingGroupAudit;
DROP TABLE IF EXISTS #NormalizationHints;

CREATE TABLE #WorkshopRegistrationWide
(
    RegistrationID  INT           NOT NULL,
    AttendeeNo      VARCHAR(20)   NOT NULL,
    AttendeeName    VARCHAR(80)   NOT NULL,
    CohortCode      VARCHAR(20)   NOT NULL,
    Phone1          VARCHAR(30)   NULL,
    Phone2          VARCHAR(30)   NULL,
    Phone3          VARCHAR(30)   NULL,
    SkillTag1       VARCHAR(40)   NULL,
    SkillTag2       VARCHAR(40)   NULL,
    SkillTag3       VARCHAR(40)   NULL,
    Session1        VARCHAR(40)   NULL,
    Session2        VARCHAR(40)   NULL
);

INSERT INTO #WorkshopRegistrationWide
(
    RegistrationID,
    AttendeeNo,
    AttendeeName,
    CohortCode,
    Phone1,
    Phone2,
    Phone3,
    SkillTag1,
    SkillTag2,
    SkillTag3,
    Session1,
    Session2
)
VALUES
    (101, 'A-1001', 'Alice Berger', 'NF-01', '030-1000', '0176-44001', NULL,         'SQL',      'Normalization', 'ERD',       'Morning Lab', 'Review Clinic'),
    (102, 'A-1002', 'Boris Klein',  'NF-01', '030-2000', NULL,          NULL,         'SQL',      'Indexing',      NULL,        'Morning Lab', NULL),
    (103, 'A-1003', 'Cem Yilmaz',   'NF-02', '030-3000', '030-3001',    '030-3002',   'Modeling', 'Quality',       'SQL',       'Evening Lab', 'Review Clinic'),
    (104, 'A-1004', 'Dina Maurer',  'NF-02', NULL,       '0170-884400', NULL,         'Quality',  NULL,            NULL,        'Evening Lab', NULL),
    (105, 'A-1005', 'Eva Schmitt',  'NF-03', '089-7000', '089-7001',    NULL,         'SQL',      'Automation',    'Testing',   'Morning Lab', 'Case Study');

IF @ShowSourceData = 1
BEGIN
    SELECT
        wrw.RegistrationID,
        wrw.AttendeeNo,
        wrw.AttendeeName,
        wrw.CohortCode,
        wrw.Phone1,
        wrw.Phone2,
        wrw.Phone3,
        wrw.SkillTag1,
        wrw.SkillTag2,
        wrw.SkillTag3,
        wrw.Session1,
        wrw.Session2
    FROM #WorkshopRegistrationWide AS wrw
    ORDER BY
        wrw.RegistrationID;
END;

CREATE TABLE #RepeatingValues
(
    RegistrationID  INT          NOT NULL,
    AttendeeNo      VARCHAR(20)  NOT NULL,
    GroupName       VARCHAR(30)  NOT NULL,
    SlotName        VARCHAR(20)  NOT NULL,
    SlotOrdinal     TINYINT      NOT NULL,
    SlotValue       VARCHAR(80)  NOT NULL
);

INSERT INTO #RepeatingValues
(
    RegistrationID,
    AttendeeNo,
    GroupName,
    SlotName,
    SlotOrdinal,
    SlotValue
)
SELECT
    wrw.RegistrationID,
    wrw.AttendeeNo,
    v.GroupName,
    v.SlotName,
    v.SlotOrdinal,
    v.SlotValue
FROM #WorkshopRegistrationWide AS wrw
CROSS APPLY
(
    VALUES
        ('Phone',    'Phone1',    1, wrw.Phone1),
        ('Phone',    'Phone2',    2, wrw.Phone2),
        ('Phone',    'Phone3',    3, wrw.Phone3),
        ('SkillTag', 'SkillTag1', 1, wrw.SkillTag1),
        ('SkillTag', 'SkillTag2', 2, wrw.SkillTag2),
        ('SkillTag', 'SkillTag3', 3, wrw.SkillTag3),
        ('Session',  'Session1',  1, wrw.Session1),
        ('Session',  'Session2',  2, wrw.Session2)
) AS v(GroupName, SlotName, SlotOrdinal, SlotValue)
WHERE NULLIF(LTRIM(RTRIM(v.SlotValue)), '') IS NOT NULL;

CREATE TABLE #RepeatingGroupAudit
(
    GroupName                    VARCHAR(30)  NOT NULL,
    SlotColumns                  VARCHAR(80)  NOT NULL,
    RowsWithAtLeastOneValue      INT          NOT NULL,
    MaxFilledSlotsPerRow         INT          NOT NULL,
    RowsWithMultipleFilledSlots  INT          NOT NULL,
    DistinctValuesObserved       INT          NOT NULL,
    RepeatingGroupStatus         VARCHAR(40)  NOT NULL,
    Interpretation               VARCHAR(220) NOT NULL
);

INSERT INTO #RepeatingGroupAudit
(
    GroupName,
    SlotColumns,
    RowsWithAtLeastOneValue,
    MaxFilledSlotsPerRow,
    RowsWithMultipleFilledSlots,
    DistinctValuesObserved,
    RepeatingGroupStatus,
    Interpretation
)
SELECT
    grouped.GroupName,
    CASE grouped.GroupName
        WHEN 'Phone' THEN 'Phone1, Phone2, Phone3'
        WHEN 'SkillTag' THEN 'SkillTag1, SkillTag2, SkillTag3'
        WHEN 'Session' THEN 'Session1, Session2'
    END AS SlotColumns,
    grouped.RowsWithAtLeastOneValue,
    grouped.MaxFilledSlotsPerRow,
    grouped.RowsWithMultipleFilledSlots,
    grouped.DistinctValuesObserved,
    CASE
        WHEN grouped.MaxFilledSlotsPerRow > 1 THEN 'repeating_group_likely'
        ELSE 'single_value_per_row'
    END AS RepeatingGroupStatus,
    CASE
        WHEN grouped.MaxFilledSlotsPerRow > 1 THEN 'Mehrere belegte Slots derselben Spaltenfamilie pro Registrierung sprechen fuer eine Wiederholungsgruppe ausserhalb der 1NF.'
        ELSE 'In den Demo-Daten ist pro Registrierung nur ein Wert belegt; die nummerierte Spaltenfamilie bleibt dennoch ein Modellierungswarnsignal.'
    END AS Interpretation
FROM
(
    SELECT
        per_group.GroupName,
        COUNT(*) AS RowsWithAtLeastOneValue,
        MAX(per_group.FilledSlotsPerRow) AS MaxFilledSlotsPerRow,
        SUM(CASE WHEN per_group.FilledSlotsPerRow > 1 THEN 1 ELSE 0 END) AS RowsWithMultipleFilledSlots,
        value_count.DistinctValuesObserved
    FROM
    (
        SELECT
            rv.GroupName,
            rv.RegistrationID,
            COUNT(*) AS FilledSlotsPerRow
        FROM #RepeatingValues AS rv
        GROUP BY
            rv.GroupName,
            rv.RegistrationID
    ) AS per_group
    INNER JOIN
    (
        SELECT
            rv.GroupName,
            COUNT(DISTINCT rv.SlotValue) AS DistinctValuesObserved
        FROM #RepeatingValues AS rv
        GROUP BY
            rv.GroupName
    ) AS value_count
        ON value_count.GroupName = per_group.GroupName
    GROUP BY
        per_group.GroupName,
        value_count.DistinctValuesObserved
) AS grouped;

SELECT
    rga.GroupName,
    rga.SlotColumns,
    rga.RowsWithAtLeastOneValue,
    rga.MaxFilledSlotsPerRow,
    rga.RowsWithMultipleFilledSlots,
    rga.DistinctValuesObserved,
    rga.RepeatingGroupStatus,
    rga.Interpretation
FROM #RepeatingGroupAudit AS rga
ORDER BY
    CASE rga.RepeatingGroupStatus
        WHEN 'repeating_group_likely' THEN 1
        ELSE 2
    END,
    rga.GroupName;

IF @IncludeNormalizedPreview = 1
BEGIN
    SELECT
        rv.AttendeeNo,
        rv.GroupName,
        rv.SlotOrdinal,
        rv.SlotValue
    FROM #RepeatingValues AS rv
    ORDER BY
        rv.AttendeeNo,
        rv.GroupName,
        rv.SlotOrdinal;
END;

CREATE TABLE #NormalizationHints
(
    StepNumber           INT           NOT NULL,
    SuggestedRelation    VARCHAR(60)   NOT NULL,
    SuggestedKey         VARCHAR(120)  NOT NULL,
    ColumnsToKeep        VARCHAR(200)  NOT NULL,
    Reasoning            VARCHAR(260)  NOT NULL
);

INSERT INTO #NormalizationHints
(
    StepNumber,
    SuggestedRelation,
    SuggestedKey,
    ColumnsToKeep,
    Reasoning
)
VALUES
    (1, 'WorkshopRegistration', 'RegistrationID', 'RegistrationID, AttendeeNo, AttendeeName, CohortCode', 'Die Stammattribute der Registrierung bleiben in einer Basistabelle ohne nummerierte Mehrfachfelder.'),
    (2, 'RegistrationPhone',    'RegistrationID, PhoneOrdinal', 'RegistrationID, PhoneOrdinal, PhoneNumber', 'Telefonnummern werden als zeilenorientierte Kindtabelle statt Phone1..3 modelliert.'),
    (3, 'RegistrationSkill',    'RegistrationID, SkillOrdinal', 'RegistrationID, SkillOrdinal, SkillTag',     'Skill-Tags werden als wiederholbare Detailzeilen statt SkillTag1..3 gespeichert.'),
    (4, 'RegistrationSession',  'RegistrationID, SessionOrdinal', 'RegistrationID, SessionOrdinal, SessionName', 'Session-Zuordnungen werden separat gefuehrt und koennen spaeter auch auf echte Session-IDs zeigen.');

SELECT
    nh.StepNumber,
    nh.SuggestedRelation,
    nh.SuggestedKey,
    nh.ColumnsToKeep,
    nh.Reasoning
FROM #NormalizationHints AS nh
ORDER BY
    nh.StepNumber;
