#Add-Type -AssemblyName "Microsoft.SqlServer.Smo"
#Add-Type -AssemblyName "Microsoft.SqlServer.ConnectionInfo"
#Add-Type -AssemblyName "Microsoft.SqlServer.SmoExtended"
Import-Module SqlServer -DisableNameChecking

$serverName = "NPGPRD-IVPSDB03"
$backupPath = "B:\MSSQL\Nightly Backups"
$logDB = "master"

# --- Cleanup old backup files ---
Write-Host "Cleaning up old backup files in $backupPath ..." -ForegroundColor Yellow
if (Test-Path $backupPath) {
    Get-ChildItem -Path $backupPath -Filter "*.bak" -File | Remove-Item -Force -ErrorAction SilentlyContinue
    Write-Host "All old .bak files removed." -ForegroundColor Yellow
    
} else {
    Write-Host "Backup path not found: $backupPath" -ForegroundColor Red
    
}

$connectionString = "Server=$serverName;Database=$logDB;Integrated Security=True;"
$connection = New-Object System.Data.SqlClient.SqlConnection
$connection.ConnectionString = $connectionString
$connection.Open()

$createTableCmd = @"
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name='BackupLogs')
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
$command = $connection.CreateCommand()
$command.CommandText = $createTableCmd
$command.ExecuteNonQuery() | Out-Null

$getDBsCmd = "SELECT TargetDB FROM dbo.WeekendDBRefreshMapping"
$command.CommandText = $getDBsCmd
$reader = $command.ExecuteReader()

$databases = @()
while ($reader.Read()) {
    $databases += $reader["SourceDB"]
}
$reader.Close()

$server = New-Object Microsoft.SqlServer.Management.Smo.Server $serverName

foreach ($dbName in $databases) {
    try {
        $startTime = Get-Date
        $dateStamp = $startTime.ToString("yyyyMMdd")
        $backupFile = Join-Path $backupPath "$dbName`_PRA_$dateStamp.bak"

        Write-Host "Starting backup of $dbName to $backupFile ..." -ForegroundColor Cyan

        
        $backup = New-Object Microsoft.SqlServer.Management.Smo.Backup
        $backup.Action = "Database"
        $backup.Database = $dbName
        $backup.Devices.AddDevice($backupFile, "File")
        $backup.Initialize = $true
        $backup.Checksum = $true
        $backup.ContinueAfterError = $true
        $backup.CompressionOption = "On"

        
        $backup.MaxTransferSize = 4194304   
        $backup.BufferCount = 64            
        $backup.BlockSize = 65536           

        
        $backup.SqlBackup($server)

        $endTime = Get-Date
        $totalMins = [math]::Round(($endTime - $startTime).TotalMinutes, 2)

        
        $insertLog = @"
INSERT INTO dbo.BackupLogs(DatabaseName, BackupFileName, StartTime, EndTime, TotalTimeMins, RunDate)
VALUES ('$dbName', '$backupFile', '$startTime', '$endTime', $totalMins, CAST(GETDATE() AS DATE))
"@
        $command = $connection.CreateCommand()
        $command.CommandText = $insertLog
        $command.ExecuteNonQuery() | Out-Null

        Write-Host "Backup of $dbName completed in $totalMins minutes." -ForegroundColor Green
    }
    catch {
        Write-Host "Backup failed for $dbName. Error: $_" -ForegroundColor Red
    }
}

$connection.Close()
