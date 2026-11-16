
$ProcessStart=Get-Date
$SqlInstance = "NPGUAT-IVPREARC"
$Database = "master"
$BackupFolder = "B:\OnDemand_DB_Restore\Backups\Downloaded"
$RestoredFolder = "B:\OnDemand_DB_Restore\Backups\Downloaded\Restored"
$DatabaseListTable = "Backup_Restore_DBList"
$LogTable = "DBRestoreLogs"
$ParallelRestore = 3
$MaxTransferSize = 4194304     # 4 MB
$BufferCount = 100
$RetryIntervalSec = 120        # 2 minutes

# Import required modules
#Import-Module SqlServer
#Import-Module ThreadJob

function Get-DatabaseList {
    $query = @"
    SELECT DatabaseName
    FROM [$Database].[dbo].[$DatabaseListTable]
    WHERE isRestoreActive = 1
    ORDER BY ProcessOrder ASC
"@
    Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $Database -Query $query
}

function Log-Status {
    param (
        [string]$DatabaseName,
        [datetime]$StartTime,
        [datetime]$EndTime,
        [string]$BackupFile,
        [string]$Status,
        [string]$ErrorMsg
    )

    $TotalTime = [math]::Round(($EndTime - $StartTime).TotalMinutes, 2)
    $insertQuery = @"
    INSERT INTO [$Database].[dbo].[$LogTable]
    (DatabaseName, StartTime, EndTime, TotalTime, BackupFileName, [Status], ErrorMsg)
    VALUES (N'$DatabaseName', '$StartTime', '$EndTime', $TotalTime, N'$BackupFile', N'$Status', N'$ErrorMsg')
"@
    Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $Database -Query $insertQuery
}

function Restore-Database {
    param ($DatabaseName)

    $BackupFilePattern = "$DatabaseName*_*.bak"

    while ($true) {
        $file = Get-ChildItem -Path $BackupFolder -Filter $BackupFilePattern -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($file) {
            $BackupFilePath = $file.FullName
            $BackupFileName = $file.Name
            $StartTime = Get-Date

            try {
                # Get Logical file names from backup
                $fileList = Invoke-Sqlcmd -ServerInstance $SqlInstance -Query "RESTORE FILELISTONLY FROM DISK = N'$BackupFilePath'" -ErrorAction Stop
                $mdfLogical = $fileList | Where-Object {$_.Type -eq 'D'} | Select-Object -ExpandProperty LogicalName
                $ldfLogical = $fileList | Where-Object {$_.Type -eq 'L'} | Select-Object -ExpandProperty LogicalName

                # Determine target paths based on database name
                if ($DatabaseName -ieq "IVPPolaris") {
                    $mdfPhysical = "E:\SQL Data\$DatabaseName.mdf"
                    $ldfPhysical = "F:\Log\$DatabaseName_log.ldf"
                } else {
                    $mdfPhysical = "D:\SQL Data\$DatabaseName.mdf"
                    $ldfPhysical = "L:\Log\$DatabaseName_log.ldf"
                }

                # Build and run restore command
                $restoreQuery = @"
RESTORE DATABASE [$DatabaseName]
FROM DISK = N'$BackupFilePath'
WITH MOVE N'$mdfLogical' TO N'$mdfPhysical',
     MOVE N'$ldfLogical' TO N'$ldfPhysical',
     REPLACE,
     STATS = 5,
     BUFFERCOUNT = $BufferCount,
     MAXTRANSFERSIZE = $MaxTransferSize
"@
                Invoke-Sqlcmd -ServerInstance $SqlInstance -Query $restoreQuery -ErrorAction Stop
                $EndTime = Get-Date

                # Log Success
                Log-Status -DatabaseName $DatabaseName -StartTime $StartTime -EndTime $EndTime -BackupFile $BackupFileName -Status "Success" -ErrorMsg ""

                # Move the backup file to archive
                Move-Item -Path $BackupFilePath -Destination $RestoredFolder -Force
                break
            }
            catch {
                $EndTime = Get-Date
                $errorMsg = $_.Exception.Message.Replace("'", "''")
                Log-Status -DatabaseName $DatabaseName -StartTime $StartTime -EndTime $EndTime -BackupFile $BackupFileName -Status "Failed" -ErrorMsg $errorMsg
                break
            }
        } else {
            Start-Sleep -Seconds $RetryIntervalSec
        }
    }
}

# Main Execution
$AllDatabases = Get-DatabaseList
$queue = [System.Collections.Queue]::new()
$AllDatabases | ForEach-Object { $queue.Enqueue($_.DatabaseName) }

$jobs = @()
while ($queue.Count -gt 0 -or ($jobs | Where-Object { $_.State -eq 'Running' }).Count -gt 0) {
    # Remove finished jobs
    $jobs = $jobs | Where-Object { $_.State -eq 'Running' }

    # Launch new jobs if below max parallelism
    while ($queue.Count -gt 0 -and $jobs.Count -lt $ParallelRestore) {
        $dbName = $queue.Dequeue()
        $job = Start-ThreadJob -ScriptBlock ${function:Restore-Database} -ArgumentList $dbName
        $jobs += ,$job
    }

    Start-Sleep -Seconds 10
}

# Wait for remaining jobs to finish
$jobs | Wait-Job | Out-Null

$ProcessEnd=Get-Date
$TotalTime=($ProcessEnd-$ProcessStart).TotalMinutes
Write-Host "##############################################"
Write-Host "ProcessStartTime : $ProcessStart"
Write-Host "ProcessEndTime : $ProcessEnd"
Write-Host "TotalTime : $TotalTime"
Write-Host "##############################################"



