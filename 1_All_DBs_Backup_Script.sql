

DECLARE @BackupPath NVARCHAR(255) = 'B:\Backups\UAT_Backups\';
DECLARE @DBName NVARCHAR(255);
DECLARE @SQL NVARCHAR(MAX);
DECLARE @DateTime NVARCHAR(20);

-- Generate timestamp: yyyyMMdd_HHmmss (no hyphens)
SET @DateTime = REPLACE(CONVERT(VARCHAR(19), GETDATE(), 120), '-', '');
SET @DateTime = REPLACE(@DateTime, ':', '');
SET @DateTime = REPLACE(@DateTime, ' ', '_');

DECLARE DBList CURSOR FOR
SELECT TargetDB
FROM WeekendDBRefreshMapping
WHERE IsDownloadRequired = 1;

OPEN DBList;
FETCH NEXT FROM DBList INTO @DBName;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @SQL = '
        BACKUP DATABASE [' + @DBName + ']
        TO DISK = ''' + @BackupPath + @DBName + '_UAT_' + @DateTime + '.bak''
        WITH INIT, FORMAT, COMPRESSION, STATS = 10;
    ';

    PRINT 'Backing up: ' + @DBName + ' ...';
    EXEC(@SQL);

    FETCH NEXT FROM DBList INTO @DBName;
END

CLOSE DBList;
DEALLOCATE DBList;