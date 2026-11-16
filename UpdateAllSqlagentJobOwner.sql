USE msdb;
GO

DECLARE @NewOwner NVARCHAR(128) = N'NAPIER\svc_sqlagentprd_rear';

-- Loop through all jobs and change the owner
DECLARE @JobName NVARCHAR(128);

DECLARE JobCursor CURSOR FOR
SELECT name
FROM msdb.dbo.sysjobs;

OPEN JobCursor;
FETCH NEXT FROM JobCursor INTO @JobName;

WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC msdb.dbo.sp_update_job
        @job_name = @JobName,
        @owner_login_name = @NewOwner;

    FETCH NEXT FROM JobCursor INTO @JobName;
END

CLOSE JobCursor;
DEALLOCATE JobCursor;

PRINT 'All SQL Agent job owners updated to ' + @NewOwner;
