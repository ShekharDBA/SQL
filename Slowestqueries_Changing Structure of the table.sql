

use IVPProdAudit
GO
SELECT  
    t.NAME AS [Table Name],
    s.Name AS [Schema Name],
    p.rows AS [Row Count],
    CAST((SUM(a.total_pages) * 8) / 1024.0 / 1024.0 AS DECIMAL(18,3)) AS [Size (GB)]
FROM sys.tables t
INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
INNER JOIN sys.indexes i ON t.object_id = i.object_id
INNER JOIN sys.partitions p ON i.object_id = p.object_id AND i.index_id = p.index_id
INNER JOIN sys.allocation_units a ON p.partition_id = a.container_id
WHERE t.name = 'Slowestqueries'
GROUP BY t.Name, s.Name, p.rows;

--Table Name	Schema Name	Row Count	Size (GB)
--SlowestQueries	dbo	253151	19.100

GO

SELECT
    MAX(LEN(ComputerName))     AS MaxComputerName,
    MAX(LEN(InstanceName))     AS MaxInstanceName,
    MAX(LEN(SqlInstance))      AS MaxSqlInstance,
    MAX(LEN([Database]))       AS MaxDatabase,
    MAX(LEN(ProcName))         AS MaxProcName,
    MAX(LEN(TypeDesc))         AS MaxTypeDesc
FROM dbo.SlowestQueries;
GO
--MaxComputerName	MaxInstanceName	MaxSqlInstance	MaxDatabase	MaxProcName	MaxTypeDesc
--15	NULL	15	28	88	6

SELECT
    MAX(Executions)       AS MaxExecutions,
    MAX(AvgExecMs)        AS MaxAvgExecMs,
    MAX(MaxExecMs)        AS MaxMaxExecMs,
    MAX(TotalWorkerTimeMs) AS MaxWorker,
    MAX(TotalElapsedTimeMs) AS MaxElapsed
FROM dbo.SlowestQueries;
GO

ALTER TABLE dbo.SlowestQueries ALTER COLUMN ComputerName nvarchar(128) NULL;
ALTER TABLE dbo.SlowestQueries ALTER COLUMN InstanceName nvarchar(128) NULL;
ALTER TABLE dbo.SlowestQueries ALTER COLUMN SqlInstance nvarchar(128) NULL;
ALTER TABLE dbo.SlowestQueries ALTER COLUMN [Database] nvarchar(128) NULL;
ALTER TABLE dbo.SlowestQueries ALTER COLUMN ProcName nvarchar(500) NULL;
ALTER TABLE dbo.SlowestQueries ALTER COLUMN TypeDesc nvarchar(60) NULL;
GO
ALTER TABLE dbo.SlowestQueries ALTER COLUMN Executions BIGINT NULL;
ALTER TABLE dbo.SlowestQueries ALTER COLUMN AvgExecMs BIGINT NULL;
ALTER TABLE dbo.SlowestQueries ALTER COLUMN MaxExecMs BIGINT NULL;
ALTER TABLE dbo.SlowestQueries ALTER COLUMN TotalWorkerTimeMs BIGINT NULL;
ALTER TABLE dbo.SlowestQueries ALTER COLUMN TotalElapsedTimeMs BIGINT NULL;
GO


ALTER INDEX ALL ON dbo.SlowestQueries REBUILD;

GO

SELECT  
    t.NAME AS [Table Name],
    s.Name AS [Schema Name],
    p.rows AS [Row Count],
    CAST((SUM(a.total_pages) * 8) / 1024.0 / 1024.0 AS DECIMAL(18,3)) AS [Size (GB)]
FROM sys.tables t
INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
INNER JOIN sys.indexes i ON t.object_id = i.object_id
INNER JOIN sys.partitions p ON i.object_id = p.object_id AND i.index_id = p.index_id
INNER JOIN sys.allocation_units a ON p.partition_id = a.container_id
WHERE t.name = 'Slowestqueries'
GROUP BY t.Name, s.Name, p.rows;
GO

USE [IVPProdAudit]
GO
DBCC SHRINKFILE (N'IVPProdAudit_log' , 0, TRUNCATEONLY)
GO
USE [IVPProdAudit]
GO
DBCC SHRINKFILE (N'IVPProdAudit' , 0, TRUNCATEONLY)
GO


DBCC UPDATEUSAGE(0, 'dbo.SlowestQueries') WITH COUNT_ROWS;
EXEC sp_spaceused 'dbo.SlowestQueries';


DBCC SHRINKFILE (N'IVPProdAudit', 0);

-- Next steps
ALTER INDEX ALL ON Slowestqueries REORGANIZE;
DBCC SHRINKFILE (N'IVPProdAudit', 0, NOTRUNCATE);
DBCC SHRINKFILE (N'IVPProdAudit', 0, TRUNCATEONLY);





