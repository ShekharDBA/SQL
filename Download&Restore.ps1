cls;
#Import-Module SqlServer
#Import-Module ThreadJob
$ProcessStart=Get-Date
Write-Host $ProcessStart -ForegroundColor Red

$SqlInstance = "NPGPRD-IVPREARCDB"                  
$restoreTable = "DBReStoreList"              
$logTable = "DBRestoreLog"                   
$controlDB = "master"                        
$restoreFolder = "B:\OnDemand DB Refresh\BackupFiles"
$ArchivePath="B:\OnDemand DB Refresh\BackupFiles\Archive"
$s3Path = "s3://npgl-backups/ivp/prod/db"
$maxParallel = 5
$pollIntervalSeconds = 30
$maxWaitMinutes = 120


if (!(Test-Path $restoreFolder)) {
    New-Item -Path $restoreFolder -ItemType Directory | Out-Null
}


$query = "SELECT DatabaseName FROM $restoreTable WHERE isRestoreActive = 1"
$databases = Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $controlDB -Query $query | Select-Object -ExpandProperty DatabaseName

if ($databases.Count -eq 0) {
    Write-Host "No databases are active to restore."
    exit
}


$jobs = @()

foreach ($db in $databases) {
    while ($jobs.Count -ge $maxParallel) {
        $jobs = $jobs | Where-Object { $_.State -eq 'Running' }
        Start-Sleep -Seconds 10
    }

    $job = Start-ThreadJob -ArgumentList $db, $restoreFolder, $s3Path, $SqlInstance, $pollIntervalSeconds, $maxWaitMinutes, $logTable, $controlDB -ScriptBlock {
        param($dbName, $restoreDir, $s3bucket, $server, $pollSeconds, $maxWait, $logTbl, $logDB)

        $startTime = Get-Date
        $restoreStatus = 'Failed'
        $fileName = ''
        $localPath = ''
        $downloadDuration = 0

        try {
            
            $found = $false
            $SearchFile=$dbName+"_PRA"
            while ((-not $found) -and ((Get-Date) - $startTime).TotalMinutes -lt $maxWait) {
                $listing = aws s3 ls "$s3bucket/" | Select-String "$SearchFile" | Sort-Object -Descending
                if ($listing) {
                    $fileName = ($listing -split '\s+')[-1]
                    $localPath = Join-Path $restoreDir $fileName
                    $found = $true
                } else {
                    Write-Host "[$dbName] Waiting for .bak file in S3..."
                    Start-Sleep -Seconds $pollSeconds
                }
            }

            if (-not $found) {
                Write-Warning "[$dbName] Timed out waiting for backup in S3."
                return
            }

            
            $dlStart = Get-Date
            if (!(Test-Path $localPath)) {
                Write-Host "[$dbName] Downloading $fileName..."
                aws s3 cp "$s3bucket/$fileName" $localPath --only-show-errors
                Write-Host "[$dbName] Download complete."
            }
            $dlEnd = Get-Date
            $downloadDuration = ($dlEnd - $dlStart).TotalMinutes

            
            Write-Host "[$dbName] Starting restore..."
            Restore-SqlDatabase -ServerInstance $server -Database $dbName -BackupFile $localPath -ReplaceDatabase -ErrorAction Stop
            $restoreStatus = 'Success'
            Write-Host "[$dbName] Restore completed."

            
            Move-Item -Path $localPath -Destination $ArchivePath -Force
            Write-Host "[$dbName] .bak file Moved after restore." 
        }
        catch {
            Write-Error "[$dbName] Error during restore: $_"
        }
        finally {
            $endTime = Get-Date
            $totalMinutes = ($endTime - $startTime).TotalMinutes

            
            $insert = @"
INSERT INTO $logTbl (DatabaseName, StartTime, EndTime, TotalTimeMinute, BackupFileName, BackupFileDownloadTime, RestoreStatus)
VALUES (
    N'$dbName',
    '$($startTime.ToString("yyyy-MM-dd HH:mm:ss"))',
    '$($endTime.ToString("yyyy-MM-dd HH:mm:ss"))',
    $totalMinutes,
    N'$fileName',
    $downloadDuration,
    N'$restoreStatus'
)
"@

            try {
                Invoke-Sqlcmd -ServerInstance $server -Database $logDB -Query $insert -ErrorAction Stop
                Write-Host "[$dbName] Restore log inserted."
            } catch {
                Write-Error "[$dbName] Failed to log restore: $_"
            }
        }
    }

    $jobs = @($jobs) + $job
}


$jobs | ForEach-Object {
    $_ | Wait-Job
    Receive-Job -Job $_
    Remove-Job $_
}

Write-Host "All restores and logs complete."
$ProcessEnd=Get-Date
$TotalProcessTime=($ProcessEnd-$ProcessStart).TotalMinutes
Write-Host "##################################################"
Write-Host "StartTime : $ProcessStart"-ForegroundColor Red
Write-Host "StartTime : $ProcessEnd"-ForegroundColor Red
Write-Host $TotalProcessTime -ForegroundColor Red
Write-Host "##################################################"
