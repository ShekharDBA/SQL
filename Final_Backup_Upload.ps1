#Install-Module -Name ThreadJob -Force
#Import-Module SqlServer
cls;

$SqlInstance = "NPGUAT-IVPREARC"
$restoreTable = "DBReStoreList"
$logTable = "DBBackupLog"
$controlDB = "master"
$backupFolder = "B:\OnDemand_DB_Restore\Backups"
$s3BucketPath = "s3://npgl-backups/ivp/uat/db"
$maxParallel = 5
$maxTransferSize = 4194304    
$bufferCount = 100            

$ProcessStart = Get-Date
Write-Host $ProcessStart -ForegroundColor Red

Remove-Item -Path "$backupFolder\*.bak" -Force -ErrorAction SilentlyContinue

if (!(Test-Path $backupFolder)) {
    New-Item -Path $backupFolder -ItemType Directory | Out-Null
}

$query = "SELECT DatabaseName FROM $restoreTable WHERE isBackupActive = 1"
$databases = Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $controlDB -Query $query | Select-Object -ExpandProperty DatabaseName

if ($databases.Count -eq 0) {
    Write-Host "No databases with isBackupActive = 1 found. Exiting."
    exit
}

$jobs = @()

foreach ($db in $databases) {
    Write-Host "Queueing: $db" -ForegroundColor Yellow
    $jobs = $jobs | Where-Object { $_.State -eq 'Running' }
    while ($jobs.Count -ge $maxParallel) {
            Write-Host "Waiting... Active job count: $($jobs.Count)" -ForegroundColor Cyan
            $jobs | Format-Table Id, Name, State
            Start-Sleep -Seconds 5
            $jobs = $jobs | Where-Object { $_.State -eq 'Running' }
        
    }

    $job = Start-ThreadJob -ArgumentList $db, $backupFolder, $s3BucketPath, $SqlInstance, $logTable, $controlDB, $maxTransferSize, $bufferCount -ScriptBlock {
        param($dbName, $folder, $s3Path, $server, $logTbl, $logDB, $maxSize, $bufCount)

        $timestamp = Get-Date -Format "yyyyMMddHHmmss"
        $fileName = "${dbName}_URA_$timestamp.bak"
        $fullPath = Join-Path $folder $fileName
        $backupStart = Get-Date

        try {
            Write-Host "###############################"
            Write-Host "[$dbName] Backup started..."

            Backup-SqlDatabase -ServerInstance $server -Database $dbName -BackupFile $fullPath `
                -CompressionOption On -Initialize `
                -MaxTransferSize $maxSize -BufferCount $bufCount -ErrorAction Stop

            $backupEnd = Get-Date
            $backupDuration = ($backupEnd - $backupStart).TotalMinutes
            Write-Host "[$dbName] Backup finished in $backupDuration minutes. Starting S3 upload..."

            $s3Start = Get-Date
            aws s3 cp $fullPath "$s3Path/" --sse AES256 --only-show-errors
            $s3End = Get-Date
            $s3Duration = ($s3End - $s3Start).TotalMinutes
            Write-Host "[$dbName] S3 upload completed in $s3Duration minutes."

            $insert = @"
INSERT INTO $logTbl (DatabaseName, StartTime, EndTime, TotalTimeMinute, S3UploadTime, BackupFileName)
VALUES (N'$dbName', '$($backupStart.ToString("yyyy-MM-dd HH:mm:ss"))', '$($backupEnd.ToString("yyyy-MM-dd HH:mm:ss"))', $backupDuration, $s3Duration, N'$fileName')
"@

            Invoke-Sqlcmd -ServerInstance $server -Database $logDB -Query $insert
            Write-Host "[$dbName] Log inserted successfully."
            Write-Host "###############################"
        } catch {
            Write-Host "[$dbName] Error during backup or upload: $_" -ForegroundColor Red
        }
    }

    $jobs += $job
}

# Wait for all jobs
$jobs | ForEach-Object {
    $_ | Wait-Job
    Receive-Job -Job $_
    Remove-Job $_
}

$ProcessEnd = Get-Date
$TotalProcessTime = ($ProcessEnd - $ProcessStart).TotalMinutes

Write-Host "##################################################"
Write-Host "StartTime : $ProcessStart" -ForegroundColor Red
Write-Host "EndTime   : $ProcessEnd" -ForegroundColor Red
Write-Host "Total Duration (minutes): $TotalProcessTime" -ForegroundColor Red
Write-Host "##################################################"
