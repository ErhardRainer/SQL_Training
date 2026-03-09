DECLARE @DBName SYSNAME = N'BI_DWH';
DECLARE @SQL NVARCHAR(MAX);

SELECT
    d.name,
    d.recovery_model_desc,
    d.log_reuse_wait_desc
FROM sys.databases AS d
WHERE d.name = @DBName;

SET @SQL = N'USE ' + QUOTENAME(@DBName) + N';
DBCC OPENTRAN WITH TABLERESULTS, NO_INFOMSGS;';

EXEC (@SQL);