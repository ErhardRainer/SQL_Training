/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "ValidationErrorThrowTemplate.sql"
script_version: "1.0"
script_type: "didactic-lab"
chapter: "25_ErrorHandling_TryCatch"

purpose: >
  Zeigt ein didaktisches Muster fuer fachliche Validierungen mit sauberem
  THROW, indem ein Beispielauftrag vorbereitet, gegen einfache Fachregeln
  geprueft und Fehler optional im CATCH erneut geworfen werden.

parameters:
  - name: "@Scenario"
    sql_type: "VARCHAR(30)"
    direction: "IN"
    required: false
    description: "Steuert, welches Demo-Szenario vorbereitet wird"
  - name: "@RequestedAmount"
    sql_type: "DECIMAL(12,2)"
    direction: "IN"
    required: false
    description: "Ueberschreibt den Demo-Betrag; NULL behaelt den Szenariowert"
  - name: "@ReThrowInCatch"
    sql_type: "BIT"
    direction: "IN"
    required: false
    description: "1 = Fehler nach der Diagnose im CATCH erneut werfen"

result_sets:
  - name: "ScenarioInput"
    description: "Zeigt das vorbereitete Demo-Payload vor der Validierung"
  - name: "ApprovedPayload"
    description: "Wird nur bei erfolgreicher Validierung ausgegeben"
  - name: "CatchDiagnostics"
    description: "Fehlermetadaten und Handlungshinweise fuer den CATCH-Fall"

dependencies:
  - "tempdb temporary tables"
  - "TRY...CATCH"
  - "THROW"
  - "ERROR_* functions"

safety:
  level: "read-only-tempdb"
  writes_data: false

documentation:
  markdown_file: "T-SQL/25_ErrorHandling_TryCatch/SQLScripts/ValidationErrorThrowTemplate.md"
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
    date: "2026-04-17"
    user: "ER"
    description: "Erstversion fuer fachliche Validierungen mit sauberem THROW"

notes:
  - "Die Demo arbeitet nur mit tempdb-Objekten und simulierten Auftragsdaten."
  - "Fehlernummern ab 51000 sind als fachliche Validierungssignale fuer das Beispiel reserviert."
---
END:SQL-HEADER v1
*/

SET NOCOUNT ON;

DECLARE @Scenario VARCHAR(30) = 'valid';
DECLARE @RequestedAmount DECIMAL(12,2) = NULL;
DECLARE @ReThrowInCatch BIT = 0;

IF @ReThrowInCatch NOT IN (0, 1)
BEGIN
    THROW 51000, '@ReThrowInCatch muss 0 oder 1 sein.', 1;
END;

IF @Scenario NOT IN ('valid', 'missing-customer', 'inactive-customer', 'unsupported-currency', 'amount-too-high', 'blank-requestor')
BEGIN
    THROW 51001, '@Scenario ist ungueltig.', 1;
END;

DROP TABLE IF EXISTS #CustomerCatalog;
DROP TABLE IF EXISTS #CurrencyCatalog;
DROP TABLE IF EXISTS #OrderRequest;

CREATE TABLE #CustomerCatalog
(
    CustomerCode VARCHAR(20) NOT NULL PRIMARY KEY,
    CustomerName VARCHAR(100) NOT NULL,
    IsActive BIT NOT NULL,
    CreditLimit DECIMAL(12,2) NOT NULL
);

CREATE TABLE #CurrencyCatalog
(
    CurrencyCode CHAR(3) NOT NULL PRIMARY KEY
);

CREATE TABLE #OrderRequest
(
    CustomerCode VARCHAR(20) NULL,
    OrderAmount DECIMAL(12,2) NOT NULL,
    CurrencyCode CHAR(3) NOT NULL,
    RequestedBy SYSNAME NULL,
    BusinessArea VARCHAR(30) NOT NULL
);

INSERT INTO #CustomerCatalog
(
    CustomerCode,
    CustomerName,
    IsActive,
    CreditLimit
)
VALUES
    ('CUST-1001', 'Alpenmarkt GmbH', 1, 5000.00),
    ('CUST-1002', 'Nordhandel AG', 1, 2500.00),
    ('CUST-1999', 'Archivkunde Demo', 0, 1000.00);

INSERT INTO #CurrencyCatalog
(
    CurrencyCode
)
VALUES
    ('EUR'),
    ('CHF'),
    ('USD');

INSERT INTO #OrderRequest
(
    CustomerCode,
    OrderAmount,
    CurrencyCode,
    RequestedBy,
    BusinessArea
)
SELECT
    CASE @Scenario
        WHEN 'missing-customer' THEN NULL
        WHEN 'inactive-customer' THEN 'CUST-1999'
        ELSE 'CUST-1001'
    END AS CustomerCode,
    COALESCE(
        @RequestedAmount,
        CASE @Scenario
            WHEN 'amount-too-high' THEN 6200.00
            ELSE 1250.00
        END
    ) AS OrderAmount,
    CASE @Scenario
        WHEN 'unsupported-currency' THEN 'GBP'
        ELSE 'EUR'
    END AS CurrencyCode,
    CASE @Scenario
        WHEN 'blank-requestor' THEN '   '
        ELSE 'trainer.demo'
    END AS RequestedBy,
    'OrderApproval' AS BusinessArea;

SELECT
    @Scenario AS ScenarioName,
    orq.CustomerCode,
    orq.OrderAmount,
    orq.CurrencyCode,
    orq.RequestedBy,
    orq.BusinessArea
FROM #OrderRequest AS orq;

BEGIN TRY
    DECLARE
        @CustomerCode VARCHAR(20),
        @OrderAmountValue DECIMAL(12,2),
        @CurrencyCodeValue CHAR(3),
        @RequestedByValue SYSNAME,
        @BusinessAreaValue VARCHAR(30),
        @CreditLimit DECIMAL(12,2),
        @CustomerIsActive BIT;

    SELECT TOP (1)
        @CustomerCode = NULLIF(LTRIM(RTRIM(orq.CustomerCode)), ''),
        @OrderAmountValue = orq.OrderAmount,
        @CurrencyCodeValue = UPPER(orq.CurrencyCode),
        @RequestedByValue = NULLIF(LTRIM(RTRIM(orq.RequestedBy)), ''),
        @BusinessAreaValue = orq.BusinessArea
    FROM #OrderRequest AS orq;

    IF @CustomerCode IS NULL
    BEGIN
        THROW 51010, 'CustomerCode ist ein Pflichtfeld fuer die fachliche Freigabe.', 1;
    END;

    IF @RequestedByValue IS NULL
    BEGIN
        THROW 51011, 'RequestedBy darf fuer eine fachliche Freigabe nicht leer sein.', 1;
    END;

    IF @OrderAmountValue <= 0
    BEGIN
        THROW 51012, 'OrderAmount muss groesser als 0 sein.', 1;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM #CurrencyCatalog AS cc
        WHERE cc.CurrencyCode = @CurrencyCodeValue
    )
    BEGIN
        THROW 51013, 'CurrencyCode wird im Template nicht unterstuetzt.', 1;
    END;

    SELECT
        @CustomerIsActive = cc.IsActive,
        @CreditLimit = cc.CreditLimit
    FROM #CustomerCatalog AS cc
    WHERE cc.CustomerCode = @CustomerCode;

    IF @CustomerIsActive IS NULL
    BEGIN
        THROW 51014, 'CustomerCode ist im Demo-Katalog nicht bekannt.', 1;
    END;

    IF @CustomerIsActive = 0
    BEGIN
        THROW 51015, 'CustomerCode ist inaktiv und darf nicht mehr freigegeben werden.', 1;
    END;

    IF @OrderAmountValue > @CreditLimit
    BEGIN
        THROW 51016, 'OrderAmount ueberschreitet das im Template hinterlegte Kreditlimit.', 1;
    END;

    SELECT
        @CustomerCode AS CustomerCode,
        cc.CustomerName,
        @OrderAmountValue AS ApprovedAmount,
        @CurrencyCodeValue AS CurrencyCode,
        @RequestedByValue AS RequestedBy,
        @BusinessAreaValue AS BusinessArea,
        @CreditLimit AS CreditLimit,
        CAST('approved' AS VARCHAR(20)) AS ValidationStatus,
        CAST('Alle fachlichen Guard Clauses wurden ohne Fehler durchlaufen.' AS VARCHAR(120)) AS ValidationNote
    FROM #CustomerCatalog AS cc
    WHERE cc.CustomerCode = @CustomerCode;
END TRY
BEGIN CATCH
    SELECT
        @Scenario AS ScenarioName,
        ERROR_NUMBER() AS ErrorNumber,
        ERROR_SEVERITY() AS ErrorSeverity,
        ERROR_STATE() AS ErrorState,
        ERROR_LINE() AS ErrorLine,
        ERROR_PROCEDURE() AS ErrorProcedure,
        ERROR_MESSAGE() AS ErrorMessage,
        CASE
            WHEN ERROR_NUMBER() BETWEEN 51010 AND 51099 THEN 'business-validation'
            ELSE 'unexpected'
        END AS ErrorCategory,
        CASE
            WHEN ERROR_NUMBER() BETWEEN 51010 AND 51099 THEN 'Fachliche Meldung fuer API, UI oder Logging uebernehmen.'
            ELSE 'Unerwarteten Fehler separat untersuchen und nicht maskieren.'
        END AS RecommendedHandling,
        CASE
            WHEN @ReThrowInCatch = 1 THEN 'rethrow-enabled'
            ELSE 'diagnostics-only'
        END AS CatchMode;

    IF @ReThrowInCatch = 1
    BEGIN
        THROW;
    END;
END CATCH;
