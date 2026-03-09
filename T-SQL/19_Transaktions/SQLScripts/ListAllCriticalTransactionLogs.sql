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
    d.recovery_model_desc AS RecoveryModel,
    CAST(ls.[Log Size (MB)] AS DECIMAL(18,2)) AS LogSizeMB,
    CAST(ls.[Log Space Used (%)] AS DECIMAL(18,2)) AS LogUsedPct,
    d.log_reuse_wait_desc
FROM #LogSpace AS ls
INNER JOIN sys.databases AS d
    ON d.name = ls.[Database Name]
WHERE ls.[Log Space Used (%)] >= 85
ORDER BY ls.[Log Space Used (%)] DESC;