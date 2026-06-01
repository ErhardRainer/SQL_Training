/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "DefaultSchemaAssignmentReport.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "22_Views_Schemata"

purpose: >
  Zeigt Default-Schemas von Datenbank-Principals, prueft typische
  Abweichungen zwischen Namensschema, besessenen Schemata und tatsaechlicher
  Default-Schema-Zuordnung und verdichtet die Beobachtungen zu kompakten
  Review-Signalen.

parameters:
  - name: "@PrincipalNameLike"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Optionales LIKE-Muster fuer Datenbank-Principals"
  - name: "@DefaultSchemaLike"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Optionales LIKE-Muster fuer Default-Schemanamen"
  - name: "@IncludeRoles"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = auch Rollen in die Grundmenge aufnehmen"
  - name: "@OnlyDeviationSignals"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = nur Principals mit moeglichen Abweichungen oder fehlender Zuordnung zeigen"

result_sets:
  - name: "PrincipalDefaultSchemaReview"
    description: "Detailsicht pro Principal mit Default-Schema, Namensschema, Besitzverhaeltnissen und Review-Signal"
  - name: "DefaultSchemaSummary"
    description: "Verdichtete Sicht pro Default-Schema mit Anzahl Principals und Abweichungssignalen"
  - name: "OwnedSchemaDetail"
    description: "Detailsicht der von Principals besessenen Schemata fuer Rueckfragen zur beabsichtigten Nutzung"

dependencies:
  - "sys.database_principals"
  - "sys.schemas"
  - "sys.objects"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/22_Views_Schemata/SQLScripts/DefaultSchemaAssignmentReport.md"
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
    description: "Erstversion des Reports fuer Default-Schema-Zuordnungen"

notes:
  - "Das Skript bewertet Abweichungen als Review-Signal und nicht automatisch als Fehlkonfiguration."
  - "Ein Principalname muss nicht dem beabsichtigten Schemanamen entsprechen; die Namenspruefung dient nur als didaktische Heuristik."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @PrincipalNameLike SYSNAME = NULL;
DECLARE @DefaultSchemaLike SYSNAME = NULL;
DECLARE @IncludeRoles BIT = 0;
DECLARE @OnlyDeviationSignals BIT = 0;

IF @IncludeRoles NOT IN (0, 1)
BEGIN
    THROW 50060, '@IncludeRoles muss 0 oder 1 sein.', 1;
END;

IF @OnlyDeviationSignals NOT IN (0, 1)
BEGIN
    THROW 50061, '@OnlyDeviationSignals muss 0 oder 1 sein.', 1;
END;

IF @PrincipalNameLike IS NOT NULL AND LTRIM(RTRIM(@PrincipalNameLike)) = ''
BEGIN
    SET @PrincipalNameLike = NULL;
END;

IF @DefaultSchemaLike IS NOT NULL AND LTRIM(RTRIM(@DefaultSchemaLike)) = ''
BEGIN
    SET @DefaultSchemaLike = NULL;
END;

DROP TABLE IF EXISTS #PrincipalBase;
DROP TABLE IF EXISTS #OwnedSchemas;
DROP TABLE IF EXISTS #SchemaObjectCounts;
DROP TABLE IF EXISTS #PrincipalDefaultSchemaReview;
DROP TABLE IF EXISTS #DefaultSchemaSummary;

CREATE TABLE #PrincipalBase
(
    principal_id INT NOT NULL PRIMARY KEY,
    principal_name SYSNAME NOT NULL,
    principal_type CHAR(1) NOT NULL,
    principal_type_desc NVARCHAR(60) NOT NULL,
    authentication_type_desc NVARCHAR(60) NULL,
    default_schema_name SYSNAME NULL,
    default_schema_exists BIT NOT NULL,
    named_schema_exists BIT NOT NULL,
    named_schema_matches_default BIT NOT NULL
);

INSERT INTO #PrincipalBase
(
    principal_id,
    principal_name,
    principal_type,
    principal_type_desc,
    authentication_type_desc,
    default_schema_name,
    default_schema_exists,
    named_schema_exists,
    named_schema_matches_default
)
SELECT
    dp.principal_id,
    dp.name AS principal_name,
    dp.type AS principal_type,
    dp.type_desc AS principal_type_desc,
    dp.authentication_type_desc,
    dp.default_schema_name,
    CONVERT(BIT, CASE WHEN default_schema.schema_id IS NULL THEN 0 ELSE 1 END) AS default_schema_exists,
    CONVERT(BIT, CASE WHEN same_name_schema.schema_id IS NULL THEN 0 ELSE 1 END) AS named_schema_exists,
    CONVERT(BIT, CASE WHEN dp.default_schema_name IS NOT NULL AND dp.default_schema_name = dp.name THEN 1 ELSE 0 END) AS named_schema_matches_default
FROM sys.database_principals AS dp
LEFT JOIN sys.schemas AS default_schema
    ON default_schema.name = dp.default_schema_name
LEFT JOIN sys.schemas AS same_name_schema
    ON same_name_schema.name = dp.name
WHERE dp.principal_id > 4
  AND dp.is_fixed_role = 0
  AND (
        @IncludeRoles = 1
        OR dp.type <> 'R'
      )
  AND dp.type IN ('S', 'U', 'G', 'A', 'E', 'X', 'R')
  AND (@PrincipalNameLike IS NULL OR dp.name LIKE @PrincipalNameLike)
  AND (@DefaultSchemaLike IS NULL OR ISNULL(dp.default_schema_name, N'(none)') LIKE @DefaultSchemaLike);

CREATE TABLE #OwnedSchemas
(
    principal_id INT NOT NULL,
    schema_name SYSNAME NOT NULL,
    object_count INT NOT NULL
);

INSERT INTO #OwnedSchemas
(
    principal_id,
    schema_name,
    object_count
)
SELECT
    pb.principal_id,
    s.name AS schema_name,
    COUNT(o.object_id) AS object_count
FROM #PrincipalBase AS pb
INNER JOIN sys.schemas AS s
    ON s.principal_id = pb.principal_id
LEFT JOIN sys.objects AS o
    ON o.schema_id = s.schema_id
   AND o.is_ms_shipped = 0
GROUP BY
    pb.principal_id,
    s.name;

CREATE TABLE #SchemaObjectCounts
(
    schema_name SYSNAME NOT NULL PRIMARY KEY,
    object_count INT NOT NULL
);

INSERT INTO #SchemaObjectCounts
(
    schema_name,
    object_count
)
SELECT
    s.name AS schema_name,
    COUNT(o.object_id) AS object_count
FROM sys.schemas AS s
LEFT JOIN sys.objects AS o
    ON o.schema_id = s.schema_id
   AND o.is_ms_shipped = 0
GROUP BY
    s.name;

CREATE TABLE #PrincipalDefaultSchemaReview
(
    principal_name SYSNAME NOT NULL,
    principal_type_desc NVARCHAR(60) NOT NULL,
    authentication_type_desc NVARCHAR(60) NULL,
    default_schema_name SYSNAME NULL,
    default_schema_exists BIT NOT NULL,
    default_schema_object_count INT NOT NULL,
    named_schema_exists BIT NOT NULL,
    named_schema_matches_default BIT NOT NULL,
    owned_schema_count INT NOT NULL,
    owned_schema_list NVARCHAR(4000) NULL,
    review_signal VARCHAR(40) NOT NULL,
    review_note NVARCHAR(260) NOT NULL
);

INSERT INTO #PrincipalDefaultSchemaReview
(
    principal_name,
    principal_type_desc,
    authentication_type_desc,
    default_schema_name,
    default_schema_exists,
    default_schema_object_count,
    named_schema_exists,
    named_schema_matches_default,
    owned_schema_count,
    owned_schema_list,
    review_signal,
    review_note
)
SELECT
    pb.principal_name,
    pb.principal_type_desc,
    pb.authentication_type_desc,
    pb.default_schema_name,
    pb.default_schema_exists,
    ISNULL(soc.object_count, 0) AS default_schema_object_count,
    pb.named_schema_exists,
    pb.named_schema_matches_default,
    ISNULL(owned.owned_schema_count, 0) AS owned_schema_count,
    owned.owned_schema_list,
    CASE
        WHEN pb.default_schema_name IS NULL THEN 'no_default_schema'
        WHEN pb.default_schema_exists = 0 THEN 'default_schema_missing'
        WHEN ISNULL(owned.owned_schema_count, 0) > 0
             AND ISNULL(owned.owns_default_schema, 0) = 0 THEN 'owns_other_schema'
        WHEN pb.named_schema_exists = 1
             AND pb.named_schema_matches_default = 0 THEN 'named_schema_differs'
        WHEN pb.default_schema_name = N'dbo'
             AND pb.named_schema_exists = 1 THEN 'shared_default_schema'
        ELSE 'aligned'
    END AS review_signal,
    CASE
        WHEN pb.default_schema_name IS NULL THEN N'Kein Default-Schema hinterlegt; Namensauflosung sollte fuer diesen Principal bewusst geprueft werden.'
        WHEN pb.default_schema_exists = 0 THEN N'Das eingetragene Default-Schema existiert in sys.schemas nicht und sollte korrigiert oder neu angelegt werden.'
        WHEN ISNULL(owned.owned_schema_count, 0) > 0
             AND ISNULL(owned.owns_default_schema, 0) = 0 THEN N'Der Principal besitzt mindestens ein anderes Schema als sein aktuelles Default-Schema; beabsichtigte Nutzung gezielt pruefen.'
        WHEN pb.named_schema_exists = 1
             AND pb.named_schema_matches_default = 0 THEN N'Ein gleichnamiges Schema existiert, wird aber nicht als Default verwendet; dies kann bewusst sein, verdient aber Review.'
        WHEN pb.default_schema_name = N'dbo'
             AND pb.named_schema_exists = 1 THEN N'Der Principal hat ein gleichnamiges Schema, arbeitet standardmaessig jedoch im gemeinsamen Schema dbo.'
        ELSE N'Default-Schema, Namensschema und Besitzverhaeltnisse liefern kein auffaelliges Abweichungssignal.'
    END AS review_note
FROM #PrincipalBase AS pb
LEFT JOIN #SchemaObjectCounts AS soc
    ON soc.schema_name = pb.default_schema_name
OUTER APPLY
(
    SELECT
        COUNT(*) AS owned_schema_count,
        STRING_AGG(os.schema_name + N' (' + CONVERT(NVARCHAR(20), os.object_count) + N' Objekte)', N', ') AS owned_schema_list,
        MAX(CASE WHEN os.schema_name = pb.default_schema_name THEN 1 ELSE 0 END) AS owns_default_schema
    FROM #OwnedSchemas AS os
    WHERE os.principal_id = pb.principal_id
) AS owned;

CREATE TABLE #DefaultSchemaSummary
(
    default_schema_name SYSNAME NULL,
    principal_count INT NOT NULL,
    missing_schema_reference_count INT NOT NULL,
    owns_other_schema_count INT NOT NULL,
    named_schema_differs_count INT NOT NULL,
    shared_default_schema_count INT NOT NULL,
    total_objects_in_schema INT NOT NULL
);

INSERT INTO #DefaultSchemaSummary
(
    default_schema_name,
    principal_count,
    missing_schema_reference_count,
    owns_other_schema_count,
    named_schema_differs_count,
    shared_default_schema_count,
    total_objects_in_schema
)
SELECT
    pdsr.default_schema_name,
    COUNT(*) AS principal_count,
    SUM(CASE WHEN pdsr.review_signal = 'default_schema_missing' THEN 1 ELSE 0 END) AS missing_schema_reference_count,
    SUM(CASE WHEN pdsr.review_signal = 'owns_other_schema' THEN 1 ELSE 0 END) AS owns_other_schema_count,
    SUM(CASE WHEN pdsr.review_signal = 'named_schema_differs' THEN 1 ELSE 0 END) AS named_schema_differs_count,
    SUM(CASE WHEN pdsr.review_signal = 'shared_default_schema' THEN 1 ELSE 0 END) AS shared_default_schema_count,
    MAX(pdsr.default_schema_object_count) AS total_objects_in_schema
FROM #PrincipalDefaultSchemaReview AS pdsr
GROUP BY
    pdsr.default_schema_name;

SELECT
    pdsr.principal_name,
    pdsr.principal_type_desc,
    pdsr.authentication_type_desc,
    pdsr.default_schema_name,
    pdsr.default_schema_exists,
    pdsr.default_schema_object_count,
    pdsr.named_schema_exists,
    pdsr.named_schema_matches_default,
    pdsr.owned_schema_count,
    pdsr.owned_schema_list,
    pdsr.review_signal,
    pdsr.review_note
FROM #PrincipalDefaultSchemaReview AS pdsr
WHERE @OnlyDeviationSignals = 0
   OR pdsr.review_signal <> 'aligned'
ORDER BY
    CASE pdsr.review_signal
        WHEN 'default_schema_missing' THEN 1
        WHEN 'no_default_schema' THEN 2
        WHEN 'owns_other_schema' THEN 3
        WHEN 'named_schema_differs' THEN 4
        WHEN 'shared_default_schema' THEN 5
        ELSE 6
    END,
    pdsr.principal_name;

SELECT
    dss.default_schema_name,
    dss.principal_count,
    dss.missing_schema_reference_count,
    dss.owns_other_schema_count,
    dss.named_schema_differs_count,
    dss.shared_default_schema_count,
    dss.total_objects_in_schema,
    CASE
        WHEN dss.default_schema_name IS NULL THEN 'no-default'
        WHEN dss.missing_schema_reference_count > 0 THEN 'missing-schema'
        WHEN dss.owns_other_schema_count > 0 OR dss.named_schema_differs_count > 0 THEN 'review'
        WHEN dss.shared_default_schema_count > 0 THEN 'shared'
        ELSE 'aligned'
    END AS schema_signal
FROM #DefaultSchemaSummary AS dss
WHERE @OnlyDeviationSignals = 0
   OR dss.missing_schema_reference_count > 0
   OR dss.owns_other_schema_count > 0
   OR dss.named_schema_differs_count > 0
   OR dss.default_schema_name IS NULL
ORDER BY
    dss.principal_count DESC,
    dss.default_schema_name;

SELECT
    pb.principal_name,
    pb.principal_type_desc,
    os.schema_name,
    os.object_count,
    CASE
        WHEN os.schema_name = pb.default_schema_name THEN 'default-and-owned'
        ELSE 'owned-only'
    END AS ownership_relation
FROM #PrincipalBase AS pb
INNER JOIN #OwnedSchemas AS os
    ON os.principal_id = pb.principal_id
WHERE @OnlyDeviationSignals = 0
   OR os.schema_name <> ISNULL(pb.default_schema_name, N'')
ORDER BY
    pb.principal_name,
    os.schema_name;
