/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "SchemaOwnershipDriftAudit.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "22_Views_Schemata"

purpose: >
  Audit ueber Drift in der Eigentuemerschaft von Schemas.
  Das Skript vergleicht Schema-Owner mit expliziten Objekt-Ownern,
  markiert fehlende oder ungewoehnliche Verantwortlichkeiten und
  verdichtet die Ergebnisse zu einer handhabbaren Review-Sicht je Schema.

parameters:
  - name: "@SchemaNameLike"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Optionales LIKE-Muster fuer Schemanamen"
  - name: "@OnlyOwnershipDrift"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = nur Schemas und Objekte mit erkannter Ownership-Drift ausgeben"
  - name: "@IncludeRecommendations"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = zusaetzliches Resultset mit Review-Empfehlungen je Schema ausgeben"

result_sets:
  - name: "SchemaOwnershipFindings"
    description: "Detailbefunde zu Schema-Ownern und expliziten Objekt-Ownern"
  - name: "SchemaOwnershipSummary"
    description: "Verdichtete Sicht je Schema mit Drift-Score und Review-Status"
  - name: "SchemaOwnershipRecommendations"
    description: "Optionale Review-Hinweise fuer Schemas mit Ownership-Drift"

dependencies:
  - "sys.schemas"
  - "sys.objects"
  - "sys.database_principals"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/22_Views_Schemata/SQLScripts/SchemaOwnershipDriftAudit.md"
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
    description: "Erstversion fuer das Audit ueber Ownership-Drift auf Schemaebene"

notes:
  - "Explizite Objekt-Owner werden als Drift-Signal zum Schema-Owner bewertet und nicht pauschal als Fehler."
  - "Das Skript bleibt rein lesend und fuehrt keine ALTER AUTHORIZATION-Befehle aus."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @SchemaNameLike SYSNAME = NULL;
DECLARE @OnlyOwnershipDrift BIT = 0;
DECLARE @IncludeRecommendations BIT = 1;

IF @OnlyOwnershipDrift NOT IN (0, 1)
BEGIN
    THROW 50030, '@OnlyOwnershipDrift muss 0 oder 1 sein.', 1;
END;

IF @IncludeRecommendations NOT IN (0, 1)
BEGIN
    THROW 50031, '@IncludeRecommendations muss 0 oder 1 sein.', 1;
END;

IF @SchemaNameLike IS NOT NULL AND LTRIM(RTRIM(@SchemaNameLike)) = ''
BEGIN
    SET @SchemaNameLike = NULL;
END;

DROP TABLE IF EXISTS #SchemaInventory;
DROP TABLE IF EXISTS #SchemaObjects;
DROP TABLE IF EXISTS #SchemaOwnershipFindings;
DROP TABLE IF EXISTS #SchemaOwnershipSummary;
DROP TABLE IF EXISTS #SchemaOwnershipRecommendations;

CREATE TABLE #SchemaInventory
(
    schema_id                INT             NOT NULL PRIMARY KEY,
    schema_name              SYSNAME         NOT NULL,
    schema_owner_name        SYSNAME         NOT NULL,
    schema_owner_type_desc   NVARCHAR(60)    NOT NULL,
    schema_owner_sid         VARBINARY(85)   NULL
);

INSERT INTO #SchemaInventory
(
    schema_id,
    schema_name,
    schema_owner_name,
    schema_owner_type_desc,
    schema_owner_sid
)
SELECT
    s.schema_id,
    s.name AS schema_name,
    owner_principal.name AS schema_owner_name,
    owner_principal.type_desc AS schema_owner_type_desc,
    owner_principal.sid AS schema_owner_sid
FROM sys.schemas AS s
INNER JOIN sys.database_principals AS owner_principal
    ON owner_principal.principal_id = s.principal_id
WHERE @SchemaNameLike IS NULL
   OR s.name LIKE @SchemaNameLike;

CREATE TABLE #SchemaObjects
(
    schema_id                INT             NOT NULL,
    schema_name              SYSNAME         NOT NULL,
    schema_owner_name        SYSNAME         NOT NULL,
    object_id                INT             NULL,
    object_name              SYSNAME         NULL,
    full_object_name         NVARCHAR(517)   NULL,
    object_type_desc         NVARCHAR(60)    NULL,
    object_owner_name        SYSNAME         NULL,
    object_owner_type_desc   NVARCHAR(60)    NULL,
    object_owner_is_explicit BIT             NOT NULL,
    ownership_signal         NVARCHAR(80)    NOT NULL,
    signal_score             INT             NOT NULL,
    signal_note              NVARCHAR(260)   NOT NULL
);

INSERT INTO #SchemaObjects
(
    schema_id,
    schema_name,
    schema_owner_name,
    object_id,
    object_name,
    full_object_name,
    object_type_desc,
    object_owner_name,
    object_owner_type_desc,
    object_owner_is_explicit,
    ownership_signal,
    signal_score,
    signal_note
)
SELECT
    si.schema_id,
    si.schema_name,
    si.schema_owner_name,
    o.object_id,
    o.name AS object_name,
    QUOTENAME(si.schema_name) + N'.' + QUOTENAME(o.name) AS full_object_name,
    o.type_desc,
    explicit_owner.name AS object_owner_name,
    explicit_owner.type_desc AS object_owner_type_desc,
    CONVERT(BIT, CASE WHEN o.principal_id IS NULL THEN 0 ELSE 1 END) AS object_owner_is_explicit,
    CASE
        WHEN o.principal_id IS NULL THEN 'inherits-schema-owner'
        WHEN explicit_owner.principal_id IS NULL THEN 'explicit-owner-missing'
        WHEN explicit_owner.name <> si.schema_owner_name THEN 'owner-mismatch'
        ELSE 'explicit-owner-match'
    END AS ownership_signal,
    CASE
        WHEN o.principal_id IS NULL THEN 0
        WHEN explicit_owner.principal_id IS NULL THEN 95
        WHEN explicit_owner.name <> si.schema_owner_name THEN 75
        ELSE 15
    END AS signal_score,
    CASE
        WHEN o.principal_id IS NULL THEN N'Objekt erbt den Owner des Schemas und zeigt keine eigene Ownership-Abweichung.'
        WHEN explicit_owner.principal_id IS NULL THEN N'Das Objekt verweist auf einen expliziten Owner, der in sys.database_principals nicht aufloesbar ist.'
        WHEN explicit_owner.name <> si.schema_owner_name THEN N'Das Objekt besitzt einen expliziten Owner, der vom Schema-Owner abweicht.'
        ELSE N'Das Objekt besitzt einen expliziten Owner, der dem Schema-Owner entspricht.'
    END AS signal_note
FROM #SchemaInventory AS si
LEFT JOIN sys.objects AS o
    ON o.schema_id = si.schema_id
   AND o.parent_object_id = 0
   AND o.is_ms_shipped = 0
LEFT JOIN sys.database_principals AS explicit_owner
    ON explicit_owner.principal_id = o.principal_id;

CREATE TABLE #SchemaOwnershipFindings
(
    schema_name              SYSNAME         NOT NULL,
    schema_owner_name        SYSNAME         NOT NULL,
    finding_scope            NVARCHAR(30)    NOT NULL,
    object_name              SYSNAME         NULL,
    full_object_name         NVARCHAR(517)   NULL,
    object_type_desc         NVARCHAR(60)    NULL,
    finding_category         NVARCHAR(80)    NOT NULL,
    risk_level               VARCHAR(10)     NOT NULL,
    risk_score               INT             NOT NULL,
    finding                  NVARCHAR(260)   NOT NULL,
    recommended_action       NVARCHAR(260)   NOT NULL
);

INSERT INTO #SchemaOwnershipFindings
(
    schema_name,
    schema_owner_name,
    finding_scope,
    object_name,
    full_object_name,
    object_type_desc,
    finding_category,
    risk_level,
    risk_score,
    finding,
    recommended_action
)
SELECT
    si.schema_name,
    si.schema_owner_name,
    'schema',
    NULL,
    NULL,
    NULL,
    'schema-owner-not-dbo',
    'Low',
    25,
    'Das Schema wird nicht durch dbo, sondern durch einen anderen Datenbank-Principal verantwortet.',
    'Ownership bewusst dokumentieren und bei Berechtigungs- oder Deployment-Aenderungen erneut pruefen.'
FROM #SchemaInventory AS si
WHERE si.schema_owner_name <> 'dbo';

INSERT INTO #SchemaOwnershipFindings
(
    schema_name,
    schema_owner_name,
    finding_scope,
    object_name,
    full_object_name,
    object_type_desc,
    finding_category,
    risk_level,
    risk_score,
    finding,
    recommended_action
)
SELECT
    so.schema_name,
    so.schema_owner_name,
    'object',
    so.object_name,
    so.full_object_name,
    so.object_type_desc,
    'explicit-owner-missing',
    'High',
    95,
    'Ein Objekt besitzt einen expliziten Owner, der in den Datenbank-Principals nicht aufloesbar ist.',
    'Expliziten Object Owner pruefen und falls noetig Ownership gezielt auf einen gueltigen Principal oder das Schema zurueckfuehren.'
FROM #SchemaObjects AS so
WHERE so.object_id IS NOT NULL
  AND so.ownership_signal = 'explicit-owner-missing';

INSERT INTO #SchemaOwnershipFindings
(
    schema_name,
    schema_owner_name,
    finding_scope,
    object_name,
    full_object_name,
    object_type_desc,
    finding_category,
    risk_level,
    risk_score,
    finding,
    recommended_action
)
SELECT
    so.schema_name,
    so.schema_owner_name,
    'object',
    so.object_name,
    so.full_object_name,
    so.object_type_desc,
    'owner-mismatch',
    'Medium',
    75,
    'Ein Objekt verwendet einen expliziten Owner, der vom Owner des Schemas abweicht.',
    'Abweichende Ownership begruenden oder Object Ownership wieder auf das Schema angleichen.'
FROM #SchemaObjects AS so
WHERE so.object_id IS NOT NULL
  AND so.ownership_signal = 'owner-mismatch';

INSERT INTO #SchemaOwnershipFindings
(
    schema_name,
    schema_owner_name,
    finding_scope,
    object_name,
    full_object_name,
    object_type_desc,
    finding_category,
    risk_level,
    risk_score,
    finding,
    recommended_action
)
SELECT
    si.schema_name,
    si.schema_owner_name,
    'schema',
    NULL,
    NULL,
    NULL,
    'empty-schema',
    'Info',
    5,
    'Im betrachteten Schema wurden keine benutzerdefinierten schemaeigenen Objekte gefunden.',
    'Schema nur dann behalten, wenn es fuer kuenftige Objekte, Rechte oder logische Trennung benoetigt wird.'
FROM #SchemaInventory AS si
WHERE NOT EXISTS
(
    SELECT 1
    FROM #SchemaObjects AS so
    WHERE so.schema_id = si.schema_id
      AND so.object_id IS NOT NULL
);

INSERT INTO #SchemaOwnershipFindings
(
    schema_name,
    schema_owner_name,
    finding_scope,
    object_name,
    full_object_name,
    object_type_desc,
    finding_category,
    risk_level,
    risk_score,
    finding,
    recommended_action
)
SELECT
    si.schema_name,
    si.schema_owner_name,
    'schema',
    NULL,
    NULL,
    NULL,
    'mixed-object-ownership',
    'Medium',
    70,
    'Ein Schema enthaelt mehrere Objekte mit expliziter, vom Schema-Owner abweichender Ownership.',
    'Schema gesammelt reviewen, damit Ownership-Regeln fuer alle betroffenen Objekte konsistent bleiben.'
FROM #SchemaInventory AS si
WHERE
(
    SELECT COUNT(*)
    FROM #SchemaObjects AS so
    WHERE so.schema_id = si.schema_id
      AND so.ownership_signal = 'owner-mismatch'
) >= 2;

CREATE TABLE #SchemaOwnershipSummary
(
    schema_name                    SYSNAME         NOT NULL,
    schema_owner_name              SYSNAME         NOT NULL,
    object_count                   INT             NOT NULL,
    explicit_owner_count           INT             NOT NULL,
    owner_mismatch_count           INT             NOT NULL,
    missing_owner_count            INT             NOT NULL,
    highest_risk_score             INT             NOT NULL,
    drift_status                   VARCHAR(12)     NOT NULL,
    primary_recommendation         NVARCHAR(260)   NOT NULL
);

INSERT INTO #SchemaOwnershipSummary
(
    schema_name,
    schema_owner_name,
    object_count,
    explicit_owner_count,
    owner_mismatch_count,
    missing_owner_count,
    highest_risk_score,
    drift_status,
    primary_recommendation
)
SELECT
    si.schema_name,
    si.schema_owner_name,
    COUNT(so.object_id) AS object_count,
    SUM(CASE WHEN so.object_owner_is_explicit = 1 THEN 1 ELSE 0 END) AS explicit_owner_count,
    SUM(CASE WHEN so.ownership_signal = 'owner-mismatch' THEN 1 ELSE 0 END) AS owner_mismatch_count,
    SUM(CASE WHEN so.ownership_signal = 'explicit-owner-missing' THEN 1 ELSE 0 END) AS missing_owner_count,
    COALESCE(MAX(sof.risk_score), 0) AS highest_risk_score,
    CASE
        WHEN COALESCE(MAX(sof.risk_score), 0) >= 90 THEN 'High'
        WHEN COALESCE(MAX(sof.risk_score), 0) >= 50 THEN 'Medium'
        WHEN COALESCE(MAX(sof.risk_score), 0) > 0 THEN 'Low'
        ELSE 'Info'
    END AS drift_status,
    CASE
        WHEN COALESCE(MAX(sof.risk_score), 0) >= 90 THEN 'Explizite oder nicht mehr aufloesbare Object Ownership zuerst bereinigen.'
        WHEN COALESCE(MAX(sof.risk_score), 0) >= 50 THEN 'Abweichende Object Ownership gegen das gewuenschte Ownership-Modell pruefen.'
        WHEN COALESCE(MAX(sof.risk_score), 0) > 0 THEN 'Schema-Owner dokumentieren und bei kuenftigen Rechteschnitten erneut betrachten.'
        ELSE 'Keine auffaellige Ownership-Drift in den betrachteten Schemas erkannt.'
    END AS primary_recommendation
FROM #SchemaInventory AS si
LEFT JOIN #SchemaObjects AS so
    ON so.schema_id = si.schema_id
LEFT JOIN #SchemaOwnershipFindings AS sof
    ON sof.schema_name = si.schema_name
GROUP BY
    si.schema_name,
    si.schema_owner_name;

CREATE TABLE #SchemaOwnershipRecommendations
(
    schema_name                  SYSNAME         NOT NULL,
    drift_status                 VARCHAR(12)     NOT NULL,
    recommendation_type          NVARCHAR(60)    NOT NULL,
    recommended_review_step      NVARCHAR(260)   NOT NULL
);

INSERT INTO #SchemaOwnershipRecommendations
(
    schema_name,
    drift_status,
    recommendation_type,
    recommended_review_step
)
SELECT
    sos.schema_name,
    sos.drift_status,
    'ownership-review',
    CASE
        WHEN sos.drift_status = 'High' THEN N'ALTER AUTHORIZATION nur nach Review der betroffenen Objekte und Principals vorbereiten.'
        WHEN sos.drift_status = 'Medium' THEN N'Explizite Object Ownership mit Deployments, Rollenmodell und Ownership Chaining abgleichen.'
        ELSE N'Ownership-Regeln des Schemas dokumentieren und nur bei kuenftigen Aenderungen erneut pruefen.'
    END AS recommended_review_step
FROM #SchemaOwnershipSummary AS sos
WHERE sos.drift_status IN ('High', 'Medium', 'Low');

SELECT
    sof.schema_name,
    sof.schema_owner_name,
    sof.finding_scope,
    sof.object_name,
    sof.full_object_name,
    sof.object_type_desc,
    sof.finding_category,
    sof.risk_level,
    sof.risk_score,
    sof.finding,
    sof.recommended_action
FROM #SchemaOwnershipFindings AS sof
WHERE @OnlyOwnershipDrift = 0
   OR sof.risk_score >= 50
ORDER BY
    sof.schema_name,
    sof.risk_score DESC,
    sof.finding_category,
    sof.full_object_name;

SELECT
    sos.schema_name,
    sos.schema_owner_name,
    sos.object_count,
    sos.explicit_owner_count,
    sos.owner_mismatch_count,
    sos.missing_owner_count,
    sos.highest_risk_score,
    sos.drift_status,
    sos.primary_recommendation
FROM #SchemaOwnershipSummary AS sos
WHERE @OnlyOwnershipDrift = 0
   OR sos.drift_status IN ('High', 'Medium')
ORDER BY
    CASE sos.drift_status
        WHEN 'High' THEN 1
        WHEN 'Medium' THEN 2
        WHEN 'Low' THEN 3
        ELSE 4
    END,
    sos.highest_risk_score DESC,
    sos.schema_name;

IF @IncludeRecommendations = 1
BEGIN
    SELECT
        sor.schema_name,
        sor.drift_status,
        sor.recommendation_type,
        sor.recommended_review_step
    FROM #SchemaOwnershipRecommendations AS sor
    WHERE @OnlyOwnershipDrift = 0
       OR sor.drift_status IN ('High', 'Medium')
    ORDER BY
        CASE sor.drift_status
            WHEN 'High' THEN 1
            WHEN 'Medium' THEN 2
            WHEN 'Low' THEN 3
            ELSE 4
        END,
        sor.schema_name,
        sor.recommendation_type;
END;
