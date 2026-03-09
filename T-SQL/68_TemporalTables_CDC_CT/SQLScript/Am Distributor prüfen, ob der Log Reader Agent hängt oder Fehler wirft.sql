DECLARE @PublisherDB SYSNAME = N'BI_DWH';

SELECT
    a.publisher_db,
    a.name AS LogReaderAgent,
    h.[time],
    h.runstatus,
    h.error_id,
    h.comments
FROM distribution.dbo.MSlogreader_agents AS a
OUTER APPLY
(
    SELECT TOP (20)
        h.[time],
        h.runstatus,
        h.error_id,
        h.comments
    FROM distribution.dbo.MSlogreader_history AS h
    WHERE h.agent_id = a.id
    ORDER BY h.[time] DESC
) AS h
WHERE a.publisher_db = @PublisherDB
ORDER BY h.[time] DESC;