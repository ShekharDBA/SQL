SET NOCOUNT ON;
DECLARE @FileList TABLE (
LogicalName NVARCHAR(200),
PhysicalName NVARCHAR(MAX),
Type  NVARCHAR(5),
FileGroupName  NVARCHAR(200),
Size  NVARCHAR(200),
MaxSize  NVARCHAR(200),
FileId  NVARCHAR(200),
CreateLSN  NVARCHAR(200),
DropLSN  NVARCHAR(200),
UniqueId uniqueidentifier,
ReadOnlyLSN bit,
ReadWriteLSN bit,
BackupSizeInBytes  NVARCHAR(200),
SourceBlockSize NVARCHAR(200),
FileGroupId  NVARCHAR(200),
LogGroupGUID  NVARCHAR(200),
DifferentialBaseLSN  NVARCHAR(200),
DifferentialBaseGUID uniqueidentifier,
IsReadOnly bit,
IsPresent bit,
TDEThumbprint  NVARCHAR(200),
SnapshotUrl  NVARCHAR(200)
)
DECLARE @TargetDB_mdf NVARCHAR(200)
DECLARE @TargetDB_ldf NVARCHAR(200)

DECLARE @GroupId INT,
        @SourceDB SYSNAME,
        @TargetDB SYSNAME,
        @BackupFileName NVARCHAR(500),
        @BackupFilePath NVARCHAR(500),
        @DataFile NVARCHAR(500),
        @LogFile NVARCHAR(500),
        @StartTime DATETIME,
        @EndTime DATETIME,
        @TotalTimeMin FLOAT,
        @ErrorMsg NVARCHAR(4000);


DECLARE RestoreCursor CURSOR FOR
SELECT A.[Group], A.[SourceDB], A.[TargetDB], B.BackupFileName
FROM WeekendDBRefreshMapping A
INNER JOIN [dbo].[S3DownloadLogs] B
    ON A.SourceDB = B.DatabaseName
WHERE CAST(B.CollectionTime AS date) = CAST(GETDATE() AS date)
  AND B.[Status] = 'Success'
  AND A.RefreshStatus = 0
  ORDER BY [GROUP] ASC;

OPEN RestoreCursor;
FETCH NEXT FROM RestoreCursor INTO @GroupId, @SourceDB, @TargetDB, @BackupFileName;

WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        SET @StartTime = GETDATE();

        
        SELECT @DataFile = physical_name 
        FROM sys.master_files 
        WHERE database_id = DB_ID(@TargetDB) AND type_desc = 'ROWS';

        SELECT @LogFile = physical_name 
        FROM sys.master_files 
        WHERE database_id = DB_ID(@TargetDB) AND type_desc = 'LOG';
      
        SET @BackupFilePath = 'H:\WeekendRefresh\Prod_Backups\' + @BackupFileName;
		
		INSERT INTO @FileList
		EXEC('RESTORE FILELISTONLY FROM DISK = ''' + @BackupFilePath + '''');
		SELECT @TargetDB_mdf=REPLACE(RIGHT(PhysicalName, CHARINDEX('\', REVERSE(PhysicalName)) - 1),'.mdf','') FROM @FileList WHERE Type = 'D';
		SELECT @TargetDB_ldf=REPLACE(RIGHT(PhysicalName, CHARINDEX('\', REVERSE(PhysicalName)) - 1),'.ldf','') FROM @FileList WHERE Type = 'L';


       
        DECLARE @RestoreCmd NVARCHAR(MAX);

        SET @RestoreCmd = N'ALTER DATABASE ['+@TargetDB+'] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;' +
						  N'RESTORE DATABASE [' + @TargetDB + N'] FROM DISK = N''' + @BackupFilePath + N''' ' +
                          N'WITH MOVE ''' + @TargetDB_mdf + ''' TO ''' + @DataFile + N''', ' +
                          N'MOVE ''' + @TargetDB_ldf + ''' TO ''' + @LogFile + N''', ' +
                          N'REPLACE, RECOVERY,STATS=5 ;' +
						  N'ALTER DATABASE ['+@TargetDB+'] SET MULTI_USER;';

        PRINT @RestoreCmd;
        EXEC sp_executesql @RestoreCmd;

        SET @EndTime = GETDATE();
        SET @TotalTimeMin = DATEDIFF(SECOND, @StartTime, @EndTime) / 60.0;
        SET @ErrorMsg = NULL;

        
        INSERT INTO [master].[dbo].[RestoreDBLogs]
            ([DatabaseName], [StartTime], [EndTime], [TotalTimeMin], [BackupFileName], [Status], [ErrorMsg])
        VALUES
            (@TargetDB, @StartTime, @EndTime, @TotalTimeMin, @BackupFileName, 'Success', @ErrorMsg);
			--Updating Mapping table
		UPDATE A SET A.RefreshStatus=1 FROM WeekendDBRefreshMapping A
		INNER JOIN [dbo].[S3DownloadLogs] B	ON A.SourceDB = B.DatabaseName
		WHERE B.[Status] = 'Success'
			  AND A.RefreshStatus = 0
			  AND A.[Group]=@GroupId 
			  AND A.SourceDB=@SourceDB 
			  AND A.TargetDB=@TargetDB 
			  AND B.BackupFileName=@BackupFileName;
			 

    END TRY
    BEGIN CATCH
        SET @EndTime = GETDATE();
        SET @TotalTimeMin = DATEDIFF(SECOND, @StartTime, @EndTime) / 60.0;
        SET @ErrorMsg = ERROR_MESSAGE();

        
        INSERT INTO [master].[dbo].[RestoreDBLogs]
            ([DatabaseName], [StartTime], [EndTime], [TotalTimeMin], [BackupFileName], [Status], [ErrorMsg])
        VALUES
            (@TargetDB, @StartTime, @EndTime, @TotalTimeMin, @BackupFileName, 'Failed', @ErrorMsg);
    END CATCH

    FETCH NEXT FROM RestoreCursor INTO @GroupId, @SourceDB, @TargetDB, @BackupFileName;
END

CLOSE RestoreCursor;
DEALLOCATE RestoreCursor;

PRINT 'Database restore process completed.';

