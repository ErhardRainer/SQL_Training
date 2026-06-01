/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "QuotedIdentifierLegacyBatchScan.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "21_QUOTED_IDENTIFIER"

purpose: >
  Sucht nach aelteren Moduldefinitionen und Batch-Mustern, die im Umfeld von
  QUOTED_IDENTIFIER haeufig Review-Bedarf ausloesen. Das Skript kombiniert
  Katalogmetadaten mit einfachen Text-Heuristiken fuer Session-Header,
  doppelte Anfuehrungszeichen und legacy-nahe Syntaxmarker.

parameters:
  - name: "@LegacyCutoffDate"
    sql_type: "DATE"
    direction: "IN"
    required: false
    description: "Module mit create_date oder modify_date vor diesem Datum gelten als legacy-nah"
  - name: "@SchemaName"
    sql_type: "SYSNAME"
    direction: "IN"
    required: false
    description: "Optionaler Schemaname fuer die Eingrenzung des Scans"
  - name: "@OnlyFlaggedBatches"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = nur Module mit mindestens einem Legacy- oder QUOTED_IDENTIFIER-Flag ausgeben"
  - name: "@PreviewLength"
    sql_type: "INT"
    direction: "IN"
    required: false
    description: "Maximale Zeichenanzahl fuer den Definitionsauszug im Detailreport"

result_sets:
  - name: "QuotedIdentifierLegacyBatchScan"
    description: "Detailsicht auf Module mit Legacy-Indikatoren, Batch-Heuristiken und Review-Prioritaet"
  - name: "FlagSummary"
    description: "Verdichtete Uebersicht ueber die erkannten Flag-Typen"
  - name: "RemediationQueue"
    description: "Kompakte Review- und Remediation-Warteschlange fuer gefundene Kandidaten"

dependencies:
  - "sys.sql_modules"
  - "sys.objects"
  - "sys.schemas"
  - "OBJECTPROPERTYEX"
  - "SET QUOTED_IDENTIFIER"
  - "SET ANSI_NULLS"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/21_QUOTED_IDENTIFIER/SQLScripts/QuotedIdentifierLegacyBatchScan.md"
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
    description: "Erstversion des Legacy-Batch-Scans fuer QUOTED_IDENTIFIER"

notes:
  - "Der Scan arbeitet heuristisch auf Basis von Moduldefinitionen und ersetzt keine vollstaendige Parser-Analyse."
  - "Doppelte Anfuehrungszeichen werden bewusst als Review-Signal und nicht als automatischer Fehler bewertet."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @LegacyCutoffDate DATE = '2016-01-01';
DECLARE @SchemaName SYSNAME = NULL;
DECLARE @OnlyFlaggedBatches BIT = 1;
DECLARE @PreviewLength INT = 180;

IF @LegacyCutoffDate IS NULL
BEGIN
    THROW 50000, '@LegacyCutoffDate darf nicht NULL sein.', 1;
END;

IF @OnlyFlaggedBatches NOT IN (0, 1)
BEGIN
    THROW 50001, '@OnlyFlaggedBatches muss 0 oder 1 sein.', 1;
END;

IF @PreviewLength < 60 OR @PreviewLength > 400
BEGIN
    THROW 50002, '@PreviewLength muss zwischen 60 und 400 liegen.', 1;
END;

DROP TABLE IF EXISTS #ModuleInventory;
DROP TABLE IF EXISTS #LegacyBatchAssessment;
DROP TABLE IF EXISTS #FlagSummary;
DROP TABLE IF EXISTS #RemediationQueue;

CREATE TABLE #ModuleInventory
(
    object_id                    INT            NOT NULL,
    schema_name                  SYSNAME        NOT NULL,
    module_name                  SYSNAME        NOT NULL,
    module_type                  NVARCHAR(60)   NOT NULL,
    create_date                  DATETIME       NOT NULL,
    modify_date                  DATETIME       NOT NULL,
    uses_quoted_identifier       BIT            NOT NULL,
    uses_ansi_nulls              BIT            NOT NULL,
    is_schema_bound              BIT            NOT NULL,
    is_encrypted                 BIT            NOT NULL,
    normalized_definition        NVARCHAR(MAX)  NULL,
    definition_preview           NVARCHAR(400)  NULL
);

INSERT INTO #ModuleInventory
(
    object_id,
    schema_name,
    module_name,
    module_type,
    create_date,
    modify_date,
    uses_quoted_identifier,
    uses_ansi_nulls,
    is_schema_bound,
    is_encrypted,
    normalized_definition,
    definition_preview
)
SELECT
    o.object_id,
    s.name AS schema_name,
    o.name AS module_name,
    o.type_desc AS module_type,
    o.create_date,
    o.modify_date,
    sm.uses_quoted_identifier,
    sm.uses_ansi_nulls,
    CONVERT(BIT, OBJECTPROPERTYEX(o.object_id, 'IsSchemaBound')) AS is_schema_bound,
    sm.is_encrypted,
    CASE
        WHEN sm.is_encrypted = 1 THEN NULL
        ELSE UPPER(REPLACE(REPLACE(sm.definition, CHAR(13), ' '), CHAR(10), ' '))
    END AS normalized_definition,
    CASE
        WHEN sm.is_encrypted = 1 THEN NULL
        ELSE LEFT(REPLACE(REPLACE(sm.definition, CHAR(13), ' '), CHAR(10), ' '), @PreviewLength)
    END AS definition_preview
FROM sys.sql_modules AS sm
INNER JOIN sys.objects AS o
    ON sm.object_id = o.object_id
INNER JOIN sys.schemas AS s
    ON o.schema_id = s.schema_id
WHERE o.type IN ('P', 'V', 'FN', 'IF', 'TF', 'TR')
  AND (@SchemaName IS NULL OR s.name = @SchemaName);

CREATE TABLE #LegacyBatchAssessment
(
    object_id                          INT            NOT NULL,
    module_qualified_name              NVARCHAR(517)  NOT NULL,
    module_type                        NVARCHAR(60)   NOT NULL,
    create_date                        DATETIME       NOT NULL,
    modify_date                        DATETIME       NOT NULL,
    quoted_identifier_capture          VARCHAR(3)     NOT NULL,
    ansi_nulls_capture                 VARCHAR(3)     NOT NULL,
    is_schema_bound                    VARCHAR(3)     NOT NULL,
    is_encrypted                       VARCHAR(3)     NOT NULL,
    is_legacy_module                   BIT            NOT NULL,
    has_set_qi_off_statement           BIT            NOT NULL,
    has_set_ansi_nulls_off_statement   BIT            NOT NULL,
    has_double_quote_tokens            BIT            NOT NULL,
    has_quoted_identifier_dml_hint     BIT            NOT NULL,
    flag_count                         INT            NOT NULL,
    risk_level                         VARCHAR(10)    NOT NULL,
    review_focus                       NVARCHAR(260)  NOT NULL,
    remediation_hint                   NVARCHAR(260)  NOT NULL,
    definition_preview                 NVARCHAR(400)  NULL
);

INSERT INTO #LegacyBatchAssessment
(
    object_id,
    module_qualified_name,
    module_type,
    create_date,
    modify_date,
    quoted_identifier_capture,
    ansi_nulls_capture,
    is_schema_bound,
    is_encrypted,
    is_legacy_module,
    has_set_qi_off_statement,
    has_set_ansi_nulls_off_statement,
    has_double_quote_tokens,
    has_quoted_identifier_dml_hint,
    flag_count,
    risk_level,
    review_focus,
    remediation_hint,
    definition_preview
)
SELECT
    mi.object_id,
    QUOTENAME(mi.schema_name) + N'.' + QUOTENAME(mi.module_name) AS module_qualified_name,
    mi.module_type,
    mi.create_date,
    mi.modify_date,
    CASE mi.uses_quoted_identifier
        WHEN 1 THEN 'ON'
        ELSE 'OFF'
    END AS quoted_identifier_capture,
    CASE mi.uses_ansi_nulls
        WHEN 1 THEN 'ON'
        ELSE 'OFF'
    END AS ansi_nulls_capture,
    CASE mi.is_schema_bound
        WHEN 1 THEN 'Yes'
        ELSE 'No'
    END AS is_schema_bound,
    CASE mi.is_encrypted
        WHEN 1 THEN 'Yes'
        ELSE 'No'
    END AS is_encrypted,
    CASE
        WHEN mi.create_date < @LegacyCutoffDate OR mi.modify_date < @LegacyCutoffDate THEN 1
        ELSE 0
    END AS is_legacy_module,
    CASE
        WHEN mi.normalized_definition LIKE '%SET QUOTED_IDENTIFIER OFF%' THEN 1
        ELSE 0
    END AS has_set_qi_off_statement,
    CASE
        WHEN mi.normalized_definition LIKE '%SET ANSI_NULLS OFF%' THEN 1
        ELSE 0
    END AS has_set_ansi_nulls_off_statement,
    CASE
        WHEN mi.normalized_definition LIKE '%"%' THEN 1
        ELSE 0
    END AS has_double_quote_tokens,
    CASE
        WHEN mi.normalized_definition LIKE '%" %'
          OR mi.normalized_definition LIKE '%"=%'
          OR mi.normalized_definition LIKE '% LIKE "%'
          OR mi.normalized_definition LIKE '% IN ("%'
          OR mi.normalized_definition LIKE '%SELECT "%'
          OR mi.normalized_definition LIKE '%WHERE "%'
          OR mi.normalized_definition LIKE '%VALUES ("%' THEN 1
        ELSE 0
    END AS has_quoted_identifier_dml_hint,
    (CASE WHEN mi.create_date < @LegacyCutoffDate OR mi.modify_date < @LegacyCutoffDate THEN 1 ELSE 0 END)
    + (CASE WHEN mi.uses_quoted_identifier = 0 THEN 1 ELSE 0 END)
    + (CASE WHEN mi.normalized_definition LIKE '%SET QUOTED_IDENTIFIER OFF%' THEN 1 ELSE 0 END)
    + (CASE WHEN mi.normalized_definition LIKE '%SET ANSI_NULLS OFF%' THEN 1 ELSE 0 END)
    + (CASE WHEN mi.normalized_definition LIKE '%"%' THEN 1 ELSE 0 END)
    + (CASE WHEN mi.normalized_definition LIKE '%" %'
          OR mi.normalized_definition LIKE '%"=%'
          OR mi.normalized_definition LIKE '% LIKE "%'
          OR mi.normalized_definition LIKE '% IN ("%'
          OR mi.normalized_definition LIKE '%SELECT "%'
          OR mi.normalized_definition LIKE '%WHERE "%'
          OR mi.normalized_definition LIKE '%VALUES ("%' THEN 1 ELSE 0 END) AS flag_count,
    CASE
        WHEN mi.is_encrypted = 1 AND mi.uses_quoted_identifier = 0 THEN 'High'
        WHEN mi.uses_quoted_identifier = 0 THEN 'High'
        WHEN mi.normalized_definition LIKE '%SET QUOTED_IDENTIFIER OFF%' THEN 'High'
        WHEN (mi.create_date < @LegacyCutoffDate OR mi.modify_date < @LegacyCutoffDate)
         AND (mi.normalized_definition LIKE '%"%' OR mi.normalized_definition LIKE '%SET ANSI_NULLS OFF%') THEN 'Medium'
        WHEN mi.create_date < @LegacyCutoffDate OR mi.modify_date < @LegacyCutoffDate THEN 'Medium'
        WHEN mi.normalized_definition LIKE '%"%' THEN 'Review'
        ELSE 'Info'
    END AS risk_level,
    CASE
        WHEN mi.is_encrypted = 1 AND mi.uses_quoted_identifier = 0 THEN 'Encrypted module with QUOTED_IDENTIFIER OFF capture'
        WHEN mi.uses_quoted_identifier = 0 THEN 'Captured with QUOTED_IDENTIFIER OFF'
        WHEN mi.normalized_definition LIKE '%SET QUOTED_IDENTIFIER OFF%' THEN 'Definition contains explicit SET QUOTED_IDENTIFIER OFF'
        WHEN mi.normalized_definition LIKE '%" %'
          OR mi.normalized_definition LIKE '%"=%'
          OR mi.normalized_definition LIKE '% LIKE "%'
          OR mi.normalized_definition LIKE '% IN ("%'
          OR mi.normalized_definition LIKE '%SELECT "%'
          OR mi.normalized_definition LIKE '%WHERE "%'
          OR mi.normalized_definition LIKE '%VALUES ("%' THEN 'Definition includes double-quote patterns worth manual review'
        WHEN mi.create_date < @LegacyCutoffDate OR mi.modify_date < @LegacyCutoffDate THEN 'Legacy-age module with session-setting review recommended'
        ELSE 'No immediate QUOTED_IDENTIFIER review trigger'
    END AS review_focus,
    CASE
        WHEN mi.uses_quoted_identifier = 0 OR mi.normalized_definition LIKE '%SET QUOTED_IDENTIFIER OFF%'
            THEN 'Module source sichern und in einer Session mit SET ANSI_NULLS ON plus SET QUOTED_IDENTIFIER ON neu pruefen.'
        WHEN mi.normalized_definition LIKE '%"%' OR mi.normalized_definition LIKE '%SET ANSI_NULLS OFF%'
            THEN 'Doppelte Anfuehrungszeichen und Session-Header manuell gegen die Zielkonvention pruefen.'
        WHEN mi.create_date < @LegacyCutoffDate OR mi.modify_date < @LegacyCutoffDate
            THEN 'Legacy-Modul in die naechste Header- und Deployment-Review aufnehmen.'
        ELSE 'Keine unmittelbare Aktion erforderlich.'
    END AS remediation_hint,
    mi.definition_preview
FROM #ModuleInventory AS mi;

SELECT
    lba.module_qualified_name,
    lba.module_type,
    lba.create_date,
    lba.modify_date,
    lba.quoted_identifier_capture,
    lba.ansi_nulls_capture,
    lba.is_schema_bound,
    lba.is_encrypted,
    lba.is_legacy_module,
    lba.has_set_qi_off_statement,
    lba.has_set_ansi_nulls_off_statement,
    lba.has_double_quote_tokens,
    lba.has_quoted_identifier_dml_hint,
    lba.flag_count,
    lba.risk_level,
    lba.review_focus,
    lba.remediation_hint,
    lba.definition_preview
FROM #LegacyBatchAssessment AS lba
WHERE @OnlyFlaggedBatches = 0
   OR lba.flag_count > 0
ORDER BY
    CASE lba.risk_level
        WHEN 'High' THEN 1
        WHEN 'Medium' THEN 2
        WHEN 'Review' THEN 3
        ELSE 4
    END,
    lba.flag_count DESC,
    lba.modify_date,
    lba.module_qualified_name;

CREATE TABLE #FlagSummary
(
    flag_name       VARCHAR(40)    NOT NULL,
    module_count    INT            NOT NULL,
    highest_risk    VARCHAR(10)    NOT NULL,
    summary_note    NVARCHAR(260)  NOT NULL
);

INSERT INTO #FlagSummary
(
    flag_name,
    module_count,
    highest_risk,
    summary_note
)
SELECT
    src.flag_name,
    COUNT(*) AS module_count,
    CASE MIN(src.risk_rank)
        WHEN 1 THEN 'High'
        WHEN 2 THEN 'Medium'
        WHEN 3 THEN 'Review'
        ELSE 'Info'
    END AS highest_risk,
    CASE src.flag_name
        WHEN 'LegacyAge' THEN 'Objekte vor dem Stichtag sollten auf Session-Header und Deployments geprueft werden.'
        WHEN 'QuotedIdentifierOff' THEN 'Capture oder Header deuten auf QUOTED_IDENTIFIER OFF und damit auf priorisierten Review-Bedarf.'
        WHEN 'AnsiNullsOff' THEN 'ANSI_NULLS OFF tritt haeufig gemeinsam mit aelteren Header-Konventionen auf.'
        WHEN 'DoubleQuotes' THEN 'Doppelte Anfuehrungszeichen koennen unter abweichenden Session-Settings anders wirken.'
        ELSE 'Heuristischer Review-Hinweis aus dem Legacy-Batch-Scan.'
    END AS summary_note
FROM
(
    SELECT
        'LegacyAge' AS flag_name,
        CASE lba.risk_level
            WHEN 'High' THEN 1
            WHEN 'Medium' THEN 2
            WHEN 'Review' THEN 3
            ELSE 4
        END AS risk_rank
    FROM #LegacyBatchAssessment AS lba
    WHERE lba.is_legacy_module = 1

    UNION ALL

    SELECT
        'QuotedIdentifierOff',
        CASE lba.risk_level
            WHEN 'High' THEN 1
            WHEN 'Medium' THEN 2
            WHEN 'Review' THEN 3
            ELSE 4
        END
    FROM #LegacyBatchAssessment AS lba
    WHERE lba.quoted_identifier_capture = 'OFF'
       OR lba.has_set_qi_off_statement = 1

    UNION ALL

    SELECT
        'AnsiNullsOff',
        CASE lba.risk_level
            WHEN 'High' THEN 1
            WHEN 'Medium' THEN 2
            WHEN 'Review' THEN 3
            ELSE 4
        END
    FROM #LegacyBatchAssessment AS lba
    WHERE lba.has_set_ansi_nulls_off_statement = 1

    UNION ALL

    SELECT
        'DoubleQuotes',
        CASE lba.risk_level
            WHEN 'High' THEN 1
            WHEN 'Medium' THEN 2
            WHEN 'Review' THEN 3
            ELSE 4
        END
    FROM #LegacyBatchAssessment AS lba
    WHERE lba.has_double_quote_tokens = 1
) AS src
GROUP BY
    src.flag_name;

SELECT
    fs.flag_name,
    fs.module_count,
    fs.highest_risk,
    fs.summary_note
FROM #FlagSummary AS fs
ORDER BY
    CASE fs.highest_risk
        WHEN 'High' THEN 1
        WHEN 'Medium' THEN 2
        WHEN 'Review' THEN 3
        ELSE 4
    END,
    fs.flag_name;

CREATE TABLE #RemediationQueue
(
    queue_rank            INT            NOT NULL,
    module_qualified_name NVARCHAR(517)  NOT NULL,
    risk_level            VARCHAR(10)    NOT NULL,
    review_focus          NVARCHAR(260)  NOT NULL,
    remediation_hint      NVARCHAR(260)  NOT NULL,
    suggested_header      NVARCHAR(80)   NOT NULL
);

INSERT INTO #RemediationQueue
(
    queue_rank,
    module_qualified_name,
    risk_level,
    review_focus,
    remediation_hint,
    suggested_header
)
SELECT
    ROW_NUMBER() OVER
    (
        ORDER BY
            CASE lba.risk_level
                WHEN 'High' THEN 1
                WHEN 'Medium' THEN 2
                WHEN 'Review' THEN 3
                ELSE 4
            END,
            lba.flag_count DESC,
            lba.modify_date,
            lba.module_qualified_name
    ) AS queue_rank,
    lba.module_qualified_name,
    lba.risk_level,
    lba.review_focus,
    lba.remediation_hint,
    'SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;' AS suggested_header
FROM #LegacyBatchAssessment AS lba
WHERE lba.flag_count > 0;

SELECT
    rq.queue_rank,
    rq.module_qualified_name,
    rq.risk_level,
    rq.review_focus,
    rq.remediation_hint,
    rq.suggested_header
FROM #RemediationQueue AS rq
ORDER BY
    rq.queue_rank;
