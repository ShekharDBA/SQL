SET NOCOUNT ON;

DECLARE @FileList TABLE (
    LogicalName NVARCHAR(200),
    PhysicalName NVARCHAR(MAX),
    Type NVARCHAR(5),
    FileGroupName NVARCHAR(200),
    Size NVARCHAR(200),
    MaxSize NVARCHAR(200),
    FileId NVARCHAR(200),
    CreateLSN NVARCHAR(200),
    DropLSN NVARCHAR(200),
    UniqueId UNIQUEIDENTIFIER,
    ReadOnlyLSN BIT,
    ReadWriteLSN BIT,
    BackupSizeInBytes NVARCHAR(200),
    SourceBlockSize NVARCHAR(200),
    FileGroupId NVARCHAR(200),
    LogGroupGUID NVARCHAR(200),
    DifferentialBaseLSN NVARCHAR(200),
    DifferentialBaseGUID UNIQUEIDENTIFIER,
    IsReadOnly BIT,
    IsPresent BIT,
    TDEThumbprint NVARCHAR(200),
    SnapshotUrl NVARCHAR(200)
);

DECLARE 
    @GroupId INT,
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
WHERE CAST(B.CollectionTime AS DATE) = CAST(GETDATE() AS DATE)
  AND B.[Status] = 'Success'
  AND A.RefreshStatus = 0
ORDER BY [Group] ASC;

OPEN RestoreCursor;
FETCH NEXT FROM RestoreCursor INTO @GroupId, @SourceDB, @TargetDB, @BackupFileName;

WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        SET @StartTime = GETDATE();
        SET @BackupFilePath = 'B:\WeekendRefresh\Prod_Backups\' + @BackupFileName;

        
        DELETE FROM @FileList;
        INSERT INTO @FileList
        EXEC('RESTORE FILELISTONLY FROM DISK = ''' + @BackupFilePath + '''');

        
        SELECT TOP 1 @DataFile = physical_name 
        FROM sys.master_files 
        WHERE database_id = DB_ID(@TargetDB) AND type_desc = 'ROWS';

        SELECT TOP 1 @LogFile = physical_name 
        FROM sys.master_files 
        WHERE database_id = DB_ID(@TargetDB) AND type_desc = 'LOG';

        DECLARE @DataDir NVARCHAR(500), @LogDir NVARCHAR(500);
        SET @DataDir = LEFT(@DataFile, LEN(@DataFile) - CHARINDEX('\', REVERSE(@DataFile)) + 1);
        SET @LogDir  = LEFT(@LogFile, LEN(@LogFile) - CHARINDEX('\', REVERSE(@LogFile)) + 1);

        
        DECLARE @MoveCmd VARCHAR(8000) = N'';
        SELECT @MoveCmd = @MoveCmd + 
            CASE 
                WHEN Type = 'L' THEN 
                    'MOVE N''' + LogicalName + ''' TO N''' + @LogDir + @TargetDB + '_' + LogicalName + '.ldf'' ' + CHAR(13)
                WHEN Type = 'D' THEN 
                    'MOVE N''' + LogicalName + ''' TO N''' + @DataDir + @TargetDB + '_' + LogicalName + '.mdf'', ' + CHAR(13)
                ELSE ''
            END
        FROM @FileList;

        IF RIGHT(RTRIM(@MoveCmd), 1) = ','
            SET @MoveCmd = LEFT(RTRIM(@MoveCmd), LEN(RTRIM(@MoveCmd)) - 1);

        
        DECLARE @RestoreCmd NVARCHAR(MAX);
        SET @RestoreCmd = 
            'ALTER DATABASE [' + @TargetDB + '] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;' + CHAR(13) + CHAR(10) +
            'RESTORE DATABASE [' + @TargetDB + '] FROM DISK = N''' + @BackupFilePath + '''' + CHAR(13) + CHAR(10) +
            'WITH ' + CHAR(13) + @MoveCmd + ',' + CHAR(13) +
            'REPLACE, RECOVERY, STATS = 5;' + CHAR(13) + CHAR(10) +
            'ALTER DATABASE [' + @TargetDB + '] SET MULTI_USER;';

        PRINT '--------------------------------------------';
        PRINT 'Restoring Database: ' + @TargetDB;
        PRINT 'Backup File: ' + @BackupFilePath;
        PRINT @RestoreCmd;
        PRINT '--------------------------------------------';

        
        --EXEC sp_executesql @RestoreCmd;

        SET @EndTime = GETDATE();
        SET @TotalTimeMin = DATEDIFF(SECOND, @StartTime, @EndTime) / 60.0;
        SET @ErrorMsg = NULL;

        
        /*
        INSERT INTO [master].[dbo].[RestoreDBLogs]
            ([DatabaseName], [StartTime], [EndTime], [TotalTimeMin], [BackupFileName], [Status], [ErrorMsg])
        VALUES
            (@TargetDB, @StartTime, @EndTime, @TotalTimeMin, @BackupFileName, 'Success', NULL);

        UPDATE A 
        SET A.RefreshStatus = 1
        FROM WeekendDBRefreshMapping A
        INNER JOIN [dbo].[S3DownloadLogs] B ON A.SourceDB = B.DatabaseName
        WHERE B.[Status] = 'Success'
          AND A.RefreshStatus = 0
          AND A.[Group] = @GroupId 
          AND A.SourceDB = @SourceDB 
          AND A.TargetDB = @TargetDB 
          AND B.BackupFileName = @BackupFileName;
        */

    END TRY
    BEGIN CATCH
        SET @EndTime = GETDATE();
        SET @TotalTimeMin = DATEDIFF(SECOND, @StartTime, @EndTime) / 60.0;
        SET @ErrorMsg = ERROR_MESSAGE();

        PRINT 'Restore failed for ' + @TargetDB + ': ' + @ErrorMsg;

        
        /*
        INSERT INTO [master].[dbo].[RestoreDBLogs]
            ([DatabaseName], [StartTime], [EndTime], [TotalTimeMin], [BackupFileName], [Status], [ErrorMsg])
        VALUES
            (@TargetDB, @StartTime, @EndTime, @TotalTimeMin, @BackupFileName, 'Failed', @ErrorMsg);
        */
    END CATCH;
    SET @TargetDB=''
    SET @SourceDB=''
    SET @BackupFileName=''
    SET @BackupFilePath=''
    SET @MoveCmd=''
    SET @LogFile=''
    FETCH NEXT FROM RestoreCursor INTO @GroupId, @SourceDB, @TargetDB, @BackupFileName;
END;

CLOSE RestoreCursor;
DEALLOCATE RestoreCursor;

PRINT 'Database restore process completed.';
