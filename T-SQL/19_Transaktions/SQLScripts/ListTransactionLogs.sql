IF OBJECT_ID('tempdb..#LogSpace') IS NOT NULL
    DROP TABLE #LogSpace;

CREATE TABLE #LogSpace
(
    [Database Name]      SYSNAME,
    [Log Size (MB)]      DECIMAL(18,2),
    [Log Space Used (%)] DECIMAL(18,2),
    [Status]             INT
);

INSERT INTO #LogSpace
EXEC ('DBCC SQLPERF(LOGSPACE)');

SELECT
    ls.[Database Name] AS DatabaseName,
    d.state_desc AS DatabaseState,
    d.recovery_model_desc AS RecoveryModel,
    CAST(ls.[Log Size (MB)] AS DECIMAL(18,2)) AS LogSizeMB,
    CAST(ls.[Log Space Used (%)] AS DECIMAL(18,2)) AS LogUsedPct,
    CAST(ls.[Log Size (MB)] * ls.[Log Space Used (%)] / 100.0 AS DECIMAL(18,2)) AS LogUsedMB,
    CAST(ls.[Log Size (MB)] * (100.0 - ls.[Log Space Used (%)]) / 100.0 AS DECIMAL(18,2)) AS LogFreeMB,
    d.log_reuse_wait_desc,
    CASE
        WHEN ls.[Log Space Used (%)] >= 95 THEN 'KRITISCH'
        WHEN ls.[Log Space Used (%)] >= 85 THEN 'HOCH'
        WHEN ls.[Log Space Used (%)] >= 70 THEN 'BEOBACHTEN'
        ELSE 'OK'
    END AS LogStatus
FROM #LogSpace AS ls
LEFT JOIN sys.databases AS d
    ON d.name = ls.[Database Name]
ORDER BY
    ls.[Log Space Used (%)] DESC,
    ls.[Log Size (MB)] DESC;