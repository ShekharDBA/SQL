$serverName = "NPGUAT-IVPSDB03"
$backupPath = "H:\MSSQL\Nightly_Backups"
$logDB = "master"


Write-Host "Cleaning up old backup files in $backupPath ..." -ForegroundColor Yellow
if (Test-Path $backupPath) {
    Get-ChildItem -Path $backupPath -Filter "*.bak" -File | Remove-Item -Force -ErrorAction SilentlyContinue
    Write-Host "All old .bak files removed." -ForegroundColor Yellow
} else {
    Write-Host "Backup path not found: $backupPath" -ForegroundColor Red
    exit
}


$createTableCmd = @"
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name='BackupLogs' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE dbo.BackupLogs
    (
        Id INT IDENTITY(1,1) PRIMARY KEY,
        DatabaseName SYSNAME,
        BackupFileName NVARCHAR(500),
        StartTime DATETIME,
        EndTime DATETIME,
        TotalTimeMins DECIMAL(10,2),
        RunDate DATE
    )
END
"@

Invoke-Sqlcmd -ServerInstance $serverName -Database $logDB -Query $createTableCmd

# --- Get databases to backup ---
$dbList = Invoke-Sqlcmd -ServerInstance $serverName -Database $logDB -Query "Select [name] from sys.databases Where state_desc='ONLINE' and name not in('tempdb')"

foreach ($row in $dbList) {
    $dbName = $row.name
    try {
        $startTime = Get-Date
        $dateStamp = $startTime.ToString("yyyyMMdd")
        $backupFile = Join-Path $backupPath "$dbName`_URA_$dateStamp.bak"

        Write-Host "Starting backup of $dbName to $backupFile ..." -ForegroundColor Cyan

        
        $backupSql = @"
BACKUP DATABASE [$dbName]
TO DISK = N'$backupFile'
WITH STATS=5,COMPRESSION, 
     BLOCKSIZE = 65536,
     BUFFERCOUNT = 64,
     MAXTRANSFERSIZE = 4194304;

"@

        Invoke-Sqlcmd -ServerInstance $serverName -Database $logDB -Query $backupSql -QueryTimeout 0

        $endTime = Get-Date
        $totalMins = [math]::Round(($endTime - $startTime).TotalMinutes, 2)

        # Insert log entry
        $insertSql = @"
INSERT INTO dbo.BackupLogs(DatabaseName, BackupFileName, StartTime, EndTime, TotalTimeMins, RunDate)
VALUES ('$dbName', '$backupFile', '$startTime', '$endTime', $totalMins, CAST(GETDATE() AS DATE))
"@

        Invoke-Sqlcmd -ServerInstance $serverName -Database $logDB -Query $insertSql

        Write-Host "Backup of $dbName completed in $totalMins minutes." -ForegroundColor Green
    }
    catch {
        Write-Host "Backup failed for $dbName. Error: $_" -ForegroundColor Red
    }
}
