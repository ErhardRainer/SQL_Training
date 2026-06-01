/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "CrossSchemaGrantReview.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "22_Views_Schemata"

purpose: >
  Review ueber explizite Objektberechtigungen auf Views, Prozeduren und
  Funktionen, die schemauebergreifend auf andere Objekte verweisen.
  Das Skript kombiniert Metadaten aus sys.sql_expression_dependencies mit
  sys.database_permissions, um Kopplung zwischen Schemagrenzen und
  Freigaben an Principals sichtbar zu machen.

parameters:
  - name: "@PrincipalNameLike"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Optionales LIKE-Muster fuer Datenbank-Principals"
  - name: "@SourceSchemaLike"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Optionales LIKE-Muster fuer das Schema des freigegebenen Objekts"
  - name: "@TargetSchemaLike"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Optionales LIKE-Muster fuer referenzierte Zielschemata"
  - name: "@OnlyWithExplicitGrant"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = nur Objekte mit expliziter Objektberechtigung ausgeben"

result_sets:
  - name: "CrossSchemaGrantReview"
    description: "Detailsicht je schemauebergreifendem Objekt und expliziter Objektberechtigung"
  - name: "CrossSchemaGrantSummary"
    description: "Verdichtete Sicht pro Objekt mit Zielschemata, Anzahl Grants und Risikohinweis"
  - name: "CrossSchemaDependencyDetail"
    description: "Detailansicht der erkannten schemauebergreifenden Abhaengigkeiten"

dependencies:
  - "sys.objects"
  - "sys.schemas"
  - "sys.sql_expression_dependencies"
  - "sys.database_permissions"
  - "sys.database_principals"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/22_Views_Schemata/SQLScripts/CrossSchemaGrantReview.md"
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
    description: "Erstversion fuer das Review schemauebergreifender Objektberechtigungen"

notes:
  - "Das Skript bewertet explizite Objektberechtigungen als Review-Signal und nicht automatisch als Sicherheitsfehler."
  - "Ohne explizite Objektberechtigungen kann Zugriff dennoch ueber Rollen, Ownership Chaining oder Schema-Rechte moeglich sein."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @PrincipalNameLike SYSNAME = NULL;
DECLARE @SourceSchemaLike SYSNAME = NULL;
DECLARE @TargetSchemaLike SYSNAME = NULL;
DECLARE @OnlyWithExplicitGrant BIT = 0;

IF @OnlyWithExplicitGrant NOT IN (0, 1)
BEGIN
    THROW 50030, '@OnlyWithExplicitGrant muss 0 oder 1 sein.', 1;
END;

IF @PrincipalNameLike IS NOT NULL AND LTRIM(RTRIM(@PrincipalNameLike)) = ''
BEGIN
    SET @PrincipalNameLike = NULL;
END;

IF @SourceSchemaLike IS NOT NULL AND LTRIM(RTRIM(@SourceSchemaLike)) = ''
BEGIN
    SET @SourceSchemaLike = NULL;
END;

IF @TargetSchemaLike IS NOT NULL AND LTRIM(RTRIM(@TargetSchemaLike)) = ''
BEGIN
    SET @TargetSchemaLike = NULL;
END;

DROP TABLE IF EXISTS #CrossSchemaDependencies;
DROP TABLE IF EXISTS #CrossSchemaObjects;
DROP TABLE IF EXISTS #ObjectPermissions;
DROP TABLE IF EXISTS #CrossSchemaGrantReview;
DROP TABLE IF EXISTS #CrossSchemaGrantSummary;

CREATE TABLE #CrossSchemaDependencies
(
    object_id                    INT             NOT NULL,
    source_schema_name           SYSNAME         NOT NULL,
    object_name                  SYSNAME         NOT NULL,
    full_object_name             NVARCHAR(517)   NOT NULL,
    object_type_desc             NVARCHAR(60)    NOT NULL,
    target_schema_name           SYSNAME         NOT NULL,
    target_entity_name           SYSNAME         NULL,
    dependency_scope             NVARCHAR(40)    NOT NULL,
    is_schema_bound_reference    BIT             NOT NULL,
    is_caller_dependent          BIT             NOT NULL,
    dependency_risk              VARCHAR(10)     NOT NULL,
    dependency_note              NVARCHAR(260)   NOT NULL
);

INSERT INTO #CrossSchemaDependencies
(
    object_id,
    source_schema_name,
    object_name,
    full_object_name,
    object_type_desc,
    target_schema_name,
    target_entity_name,
    dependency_scope,
    is_schema_bound_reference,
    is_caller_dependent,
    dependency_risk,
    dependency_note
)
SELECT DISTINCT
    o.object_id,
    source_schema.name AS source_schema_name,
    o.name AS object_name,
    QUOTENAME(source_schema.name) + N'.' + QUOTENAME(o.name) AS full_object_name,
    o.type_desc,
    COALESCE(target_schema.name, sed.referenced_schema_name) AS target_schema_name,
    COALESCE(target_object.name, sed.referenced_entity_name) AS target_entity_name,
    CASE
        WHEN sed.referenced_id IS NOT NULL THEN 'resolved'
        ELSE 'metadata-only'
    END AS dependency_scope,
    CONVERT(BIT, ISNULL(sed.is_schema_bound_reference, 0)) AS is_schema_bound_reference,
    CONVERT(BIT, ISNULL(sed.is_caller_dependent, 0)) AS is_caller_dependent,
    CASE
        WHEN sed.referenced_id IS NULL THEN 'Medium'
        WHEN ISNULL(sed.is_caller_dependent, 0) = 1 THEN 'Medium'
        ELSE 'Low'
    END AS dependency_risk,
    CASE
        WHEN sed.referenced_id IS NULL THEN N'Schemauebergreifende Referenz ist nur ueber Metadatenname sichtbar.'
        WHEN ISNULL(sed.is_caller_dependent, 0) = 1 THEN N'Aufloesung haengt vom Aufruferkontext ab und sollte gezielt geprueft werden.'
        ELSE N'Schemauebergreifende Referenz ist ueber Metadaten aufloesbar.'
    END AS dependency_note
FROM sys.objects AS o
INNER JOIN sys.schemas AS source_schema
    ON source_schema.schema_id = o.schema_id
INNER JOIN sys.sql_expression_dependencies AS sed
    ON sed.referencing_id = o.object_id
LEFT JOIN sys.objects AS target_object
    ON target_object.object_id = sed.referenced_id
LEFT JOIN sys.schemas AS target_schema
    ON target_schema.schema_id = target_object.schema_id
WHERE o.is_ms_shipped = 0
  AND o.type IN ('V', 'P', 'FN', 'IF', 'TF')
  AND COALESCE(target_schema.name, sed.referenced_schema_name) IS NOT NULL
  AND COALESCE(target_schema.name, sed.referenced_schema_name) <> source_schema.name
  AND (@SourceSchemaLike IS NULL OR source_schema.name LIKE @SourceSchemaLike)
  AND (@TargetSchemaLike IS NULL OR COALESCE(target_schema.name, sed.referenced_schema_name) LIKE @TargetSchemaLike);

CREATE TABLE #CrossSchemaObjects
(
    object_id                    INT             NOT NULL PRIMARY KEY,
    full_object_name             NVARCHAR(517)   NOT NULL,
    source_schema_name           SYSNAME         NOT NULL,
    object_name                  SYSNAME         NOT NULL,
    object_type_desc             NVARCHAR(60)    NOT NULL,
    target_schema_count          INT             NOT NULL,
    cross_schema_reference_count INT             NOT NULL,
    highest_dependency_risk      VARCHAR(10)     NOT NULL
);

INSERT INTO #CrossSchemaObjects
(
    object_id,
    full_object_name,
    source_schema_name,
    object_name,
    object_type_desc,
    target_schema_count,
    cross_schema_reference_count,
    highest_dependency_risk
)
SELECT
    d.object_id,
    MAX(d.full_object_name) AS full_object_name,
    MAX(d.source_schema_name) AS source_schema_name,
    MAX(d.object_name) AS object_name,
    MAX(d.object_type_desc) AS object_type_desc,
    COUNT(DISTINCT d.target_schema_name) AS target_schema_count,
    COUNT(*) AS cross_schema_reference_count,
    CASE
        WHEN MAX(CASE d.dependency_risk WHEN 'Medium' THEN 2 ELSE 1 END) = 2 THEN 'Medium'
        ELSE 'Low'
    END AS highest_dependency_risk
FROM #CrossSchemaDependencies AS d
GROUP BY
    d.object_id;

CREATE TABLE #ObjectPermissions
(
    object_id                 INT             NOT NULL,
    principal_name            SYSNAME         NOT NULL,
    principal_type_desc       NVARCHAR(60)    NOT NULL,
    permission_name           NVARCHAR(128)   NOT NULL,
    state_desc                NVARCHAR(60)    NOT NULL,
    has_grant_option          BIT             NOT NULL
);

INSERT INTO #ObjectPermissions
(
    object_id,
    principal_name,
    principal_type_desc,
    permission_name,
    state_desc,
    has_grant_option
)
SELECT
    dp.major_id AS object_id,
    grantee.name AS principal_name,
    grantee.type_desc AS principal_type_desc,
    dp.permission_name,
    dp.state_desc,
    CONVERT(BIT, CASE WHEN dp.state = 'W' THEN 1 ELSE 0 END) AS has_grant_option
FROM sys.database_permissions AS dp
INNER JOIN sys.database_principals AS grantee
    ON grantee.principal_id = dp.grantee_principal_id
WHERE dp.class = 1
  AND dp.major_id IN (SELECT object_id FROM #CrossSchemaObjects)
  AND (@PrincipalNameLike IS NULL OR grantee.name LIKE @PrincipalNameLike);

CREATE TABLE #CrossSchemaGrantReview
(
    full_object_name             NVARCHAR(517)   NOT NULL,
    object_type_desc             NVARCHAR(60)    NOT NULL,
    target_schema_count          INT             NOT NULL,
    cross_schema_reference_count INT             NOT NULL,
    principal_name               SYSNAME         NOT NULL,
    principal_type_desc          NVARCHAR(60)    NOT NULL,
    permission_name              NVARCHAR(128)   NOT NULL,
    state_desc                   NVARCHAR(60)    NOT NULL,
    has_grant_option             BIT             NOT NULL,
    review_risk                  VARCHAR(10)     NOT NULL,
    review_note                  NVARCHAR(260)   NOT NULL
);

INSERT INTO #CrossSchemaGrantReview
(
    full_object_name,
    object_type_desc,
    target_schema_count,
    cross_schema_reference_count,
    principal_name,
    principal_type_desc,
    permission_name,
    state_desc,
    has_grant_option,
    review_risk,
    review_note
)
SELECT
    o.full_object_name,
    o.object_type_desc,
    o.target_schema_count,
    o.cross_schema_reference_count,
    COALESCE(p.principal_name, N'(no explicit object grant)') AS principal_name,
    COALESCE(p.principal_type_desc, N'NONE') AS principal_type_desc,
    COALESCE(p.permission_name, N'(none)') AS permission_name,
    COALESCE(p.state_desc, N'NONE') AS state_desc,
    COALESCE(p.has_grant_option, 0) AS has_grant_option,
    CASE
        WHEN p.principal_name IN ('public', 'guest') THEN 'High'
        WHEN p.has_grant_option = 1 THEN 'High'
        WHEN p.principal_name IS NOT NULL THEN 'Medium'
        WHEN o.highest_dependency_risk = 'Medium' THEN 'Medium'
        ELSE 'Info'
    END AS review_risk,
    CASE
        WHEN p.principal_name IN ('public', 'guest') THEN N'Breite Freigabe auf ein schemauebergreifendes Objekt sollte gezielt begruendet werden.'
        WHEN p.has_grant_option = 1 THEN N'GRANT WITH GRANT OPTION erlaubt die Weitergabe der Berechtigung ueber Schemagrenzen hinweg.'
        WHEN p.principal_name IS NOT NULL THEN N'Explizite Objektberechtigung mit schemauebergreifender Abhaengigkeit fuer Rollenkonzept pruefen.'
        WHEN o.highest_dependency_risk = 'Medium' THEN N'Keine explizite Objektberechtigung gefunden, aber die Abhaengigkeit selbst braucht Kontextpruefung.'
        ELSE N'Keine explizite Objektberechtigung auf Objektebene gefunden.'
    END AS review_note
FROM #CrossSchemaObjects AS o
LEFT JOIN #ObjectPermissions AS p
    ON p.object_id = o.object_id
WHERE @OnlyWithExplicitGrant = 0
   OR p.principal_name IS NOT NULL;

CREATE TABLE #CrossSchemaGrantSummary
(
    full_object_name             NVARCHAR(517)   NOT NULL,
    object_type_desc             NVARCHAR(60)    NOT NULL,
    target_schema_count          INT             NOT NULL,
    cross_schema_reference_count INT             NOT NULL,
    explicit_grant_count         INT             NOT NULL,
    principal_count              INT             NOT NULL,
    highest_review_risk          VARCHAR(10)     NOT NULL,
    recommendation               NVARCHAR(260)   NOT NULL
);

INSERT INTO #CrossSchemaGrantSummary
(
    full_object_name,
    object_type_desc,
    target_schema_count,
    cross_schema_reference_count,
    explicit_grant_count,
    principal_count,
    highest_review_risk,
    recommendation
)
SELECT
    r.full_object_name,
    MAX(r.object_type_desc) AS object_type_desc,
    MAX(r.target_schema_count) AS target_schema_count,
    MAX(r.cross_schema_reference_count) AS cross_schema_reference_count,
    SUM(CASE WHEN r.principal_name = N'(no explicit object grant)' THEN 0 ELSE 1 END) AS explicit_grant_count,
    COUNT(DISTINCT CASE WHEN r.principal_name = N'(no explicit object grant)' THEN NULL ELSE r.principal_name END) AS principal_count,
    CASE
        WHEN MAX(CASE r.review_risk WHEN 'High' THEN 3 WHEN 'Medium' THEN 2 WHEN 'Info' THEN 1 ELSE 0 END) = 3 THEN 'High'
        WHEN MAX(CASE r.review_risk WHEN 'High' THEN 3 WHEN 'Medium' THEN 2 WHEN 'Info' THEN 1 ELSE 0 END) = 2 THEN 'Medium'
        ELSE 'Info'
    END AS highest_review_risk,
    CASE
        WHEN MAX(CASE r.review_risk WHEN 'High' THEN 3 WHEN 'Medium' THEN 2 WHEN 'Info' THEN 1 ELSE 0 END) = 3
            THEN N'Breite oder delegierbare Grants auf schemauebergreifende Objekte zuerst gegen Rollenmodell und Least Privilege pruefen.'
        WHEN MAX(CASE r.review_risk WHEN 'High' THEN 3 WHEN 'Medium' THEN 2 WHEN 'Info' THEN 1 ELSE 0 END) = 2
            THEN N'Objektgrants, Ownership Chaining und Schema-Rechte gemeinsam als Freigabepfad dokumentieren.'
        ELSE N'Nur die schemauebergreifende Abhaengigkeit dokumentieren und bei Rechteschnitt neu pruefen.'
    END AS recommendation
FROM #CrossSchemaGrantReview AS r
GROUP BY
    r.full_object_name;

SELECT
    r.full_object_name,
    r.object_type_desc,
    r.target_schema_count,
    r.cross_schema_reference_count,
    r.principal_name,
    r.principal_type_desc,
    r.permission_name,
    r.state_desc,
    r.has_grant_option,
    r.review_risk,
    r.review_note
FROM #CrossSchemaGrantReview AS r
ORDER BY
    CASE r.review_risk WHEN 'High' THEN 1 WHEN 'Medium' THEN 2 ELSE 3 END,
    r.full_object_name,
    r.principal_name,
    r.permission_name;

SELECT
    s.full_object_name,
    s.object_type_desc,
    s.target_schema_count,
    s.cross_schema_reference_count,
    s.explicit_grant_count,
    s.principal_count,
    s.highest_review_risk,
    s.recommendation
FROM #CrossSchemaGrantSummary AS s
ORDER BY
    CASE s.highest_review_risk WHEN 'High' THEN 1 WHEN 'Medium' THEN 2 ELSE 3 END,
    s.explicit_grant_count DESC,
    s.full_object_name;

SELECT
    d.full_object_name,
    d.object_type_desc,
    d.target_schema_name,
    d.target_entity_name,
    d.dependency_scope,
    d.is_schema_bound_reference,
    d.is_caller_dependent,
    d.dependency_risk,
    d.dependency_note
FROM #CrossSchemaDependencies AS d
ORDER BY
    d.full_object_name,
    d.target_schema_name,
    d.target_entity_name;
