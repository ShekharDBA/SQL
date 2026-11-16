cls;
$serverName = "NPGPRD-IVPSDB03"
$backupPath = "B:\MSSQL\LogBackups"
$logDB = "master"

Write-Host "Cleaning up old log backup files in $backupPath ..." -ForegroundColor Yellow
if (Test-Path $backupPath) {
    #Get-ChildItem -Path $backupPath -Filter "*.trn" -File | Remove-Item -Force -ErrorAction SilentlyContinue
    $cutoffTime = (Get-Date).AddHours(-24)
    $oldFiles = Get-ChildItem -Path $backupPath -Filter "*.trn" -File | Where-Object { $_.LastWriteTime -lt $cutoffTime }
if ($oldFiles.Count -gt 0) {
    Write-Host "Total files found : " $oldFiles.Count
        $oldFiles | ForEach-Object {
            try {
                Remove-Item $_.FullName -Force -ErrorAction Stop
                Write-Host "Deleted old file: $($_.Name)" -ForegroundColor DarkYellow
            } catch {
                Write-Host "Failed to delete file $($_.Name): $_" -ForegroundColor Red
            }
        }
        Write-Host "Old log backup files removed." -ForegroundColor Yellow
    }
    else {
        Write-Host "No old log backup files found." -ForegroundColor Gray
    }
} else {
    Write-Host "Backup path not found: $backupPath" -ForegroundColor Red
    exit
}

# --- Create table for log backup logs ---
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

# --- Get eligible databases (FULL/BULK_LOGGED only) ---
$dbList = Invoke-Sqlcmd -ServerInstance $serverName -Database $logDB -Query "
SELECT name 
FROM sys.databases 
WHERE state_desc = 'ONLINE'
  AND recovery_model_desc IN ('FULL', 'BULK_LOGGED')
  AND name NOT IN ('tempdb', 'model')"

foreach ($row in $dbList) {
    $dbName = $row.name
    try {
        $startTime = Get-Date
        $dateStamp = $startTime.ToString("yyyyMMdd_HHmm")
        $backupFile = Join-Path $backupPath "$dbName`_Log_$dateStamp.trn"

        Write-Host "Starting log backup of $dbName to $backupFile ..." -ForegroundColor Cyan

        
        $checkpointSql = "USE [$dbName]; CHECKPOINT;"
        Invoke-Sqlcmd -ServerInstance $serverName -Database $dbName -Query $checkpointSql

        $backupSql = @"
BACKUP LOG [$dbName]
TO DISK = N'$backupFile'
WITH STATS=5, COMPRESSION,
     BLOCKSIZE = 65536,
     BUFFERCOUNT = 64,
     MAXTRANSFERSIZE = 4194304;
"@

        Invoke-Sqlcmd -ServerInstance $serverName -Database $logDB -Query $backupSql -QueryTimeout 0

        $endTime = Get-Date
        $totalMins = [math]::Round(($endTime - $startTime).TotalMinutes, 2)
         # --- Shrink Log File ---
        Write-Host "Shrinking log file for $dbName ..." -ForegroundColor DarkCyan

        $getLogFileSql = "SELECT name FROM sys.database_files WHERE type_desc = 'LOG';"
        $logFileName = (Invoke-Sqlcmd -ServerInstance $serverName -Database $dbName -Query $getLogFileSql).name

        if ($logFileName) {
            #$shrinkSql = "DBCC SHRINKFILE([$logFileName], 1);"
            $shrinkSql = "DBCC SHRINKFILE ([$logFileName], 0, TRUNCATEONLY);"
            Invoke-Sqlcmd -ServerInstance $serverName -Database $dbName -Query $shrinkSql -ErrorAction Stop
            $shrinkStatus = "Shrink completed for log file: $logFileName"
            Write-Host $shrinkStatus -ForegroundColor Green
        }
        else {
            $shrinkStatus = "No log file found"
            Write-Host "No log file found for $dbName" -ForegroundColor Yellow
        }

        # Insert log entry
        $insertSql = @"
INSERT INTO dbo.BackupLogs(DatabaseName, BackupFileName, StartTime, EndTime, TotalTimeMins, RunDate)
VALUES ('$dbName', '$backupFile', '$startTime', '$endTime', $totalMins, CAST(GETDATE() AS DATE))
"@

        Invoke-Sqlcmd -ServerInstance $serverName -Database $logDB -Query $insertSql

        Write-Host "Log backup of $dbName completed in $totalMins minutes." -ForegroundColor Green
    }
    catch {
        Write-Host "Log backup failed for $dbName. Error: $_" -ForegroundColor Red
    }
}
