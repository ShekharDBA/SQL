#Import-Module SqlServer
#Import-Module ThreadJob
cls;
$ProcessStart=Get-Date
$SqlInstance = "NPGUAT-IVPREARC"
$ControlDB = "master"
$S3BucketRoot = "s3://npgl-backups/ivp/prod/db/"
$BackupDownloadStagingPath = "B:\OnDemand_DB_Restore\Backups\Staging"
$BackupDownloadFinalPath = "B:\OnDemand_DB_Restore\Backups\Downloaded"
$DateStamp = "20250719"

$MaxParallelDownloads = 3
$RetryAttempts = 2

$env:AWS_ACCESS_KEY_ID = "ASIAVRUVUNTHLCXADTR7"
$env:AWS_SECRET_ACCESS_KEY = "AyKSRQKYrnDh/VTBCFXvk4FL+9YoeU2q2apeqrPm"
$env:AWS_DEFAULT_REGION = "us-east-1"
$env:AWS_SESSION_TOKEN = "IQoJb3JpZ2luX2VjEIX//////////wEaCXVzLWVhc3QtMSJIMEYCIQCwjbIMP1GL937x7yjgVOhEoCAGvsO4ta4tPc5/6303WAIhAOtj6ZeO7phgx43rFK1jzwsgqjRgR5CGUV9Y94n9Aka2KqYDCJ3//////////wEQABoMMzgxNDkyMTYxNzQyIgzbTNNrVcq5avURcEMq+gKHe1I3iGHjXGKzw2QRvlAmDGX9V+Z1KYLfcneaFYf3254S1CEORBZMpOBoFH7WkI4340GbktTy+BZChQgeOM1UsnCj+6dhDy44Z7vCDf6WhEuZ6TWORV/vb09E4O6KzCpo+zQx8Dtw88XHKpQoUFpRYqX3pF1ezpN2Qf35THoVf4wX5CgaLuW8vNYw4lgsV2z9UqntJU2QX9a3jOaiSu5SWUlQpGXl0BvID/YwD5c5TgbijyPMUM88D/rJKTBRNAJ8ljst2S/j05udItL7+FOPTRlSDF8VCKEYmXOnB17yBpoKMPQ305zk5fX9zGMzepRusHI/X21nilhQVq6Y/mnnyNOwR56G/wRK5VRkJygcn39jA3qBFdCYaKlNZ2SbgrPetYJzURqMNOCo364Ws4i/gK2PjCR2VaxbgDbhjXZrbIG7dRDELmLxzz+KYYxS8EvFNilWuFvGEmxWk7Emm4x1RkLF54ct9xR6+nhg8FRabF7PYuMVLrsY2z8wlbTswwY6pQGBAlSBxCEY83BIY7i5JZHs46jySIJ7l7UCnvuuu15rPgAgkJnBttiBe1G+ihhLiOoTp9rJTM0WOI5cGuSUFYUZUYD7s4f9v2CpRExB47MxWfR7N3Ch8e2y4NYfL2muC9QsCXK9IayCochPMW7+UA/uQ9IyYGunLiQOv2049go7AueimEdhq4aiZyjmQpA/Dc6zHMhq81Xp+hCdqvBOoqSf8zsM0rU="


New-Item -Path $BackupDownloadStagingPath -ItemType Directory -Force | Out-Null
New-Item -Path $BackupDownloadFinalPath -ItemType Directory -Force | Out-Null

$query = @"
SELECT DatabaseName
FROM Backup_Restore_DBList
WHERE isBackupActive = 1
ORDER BY ProcessOrder ASC
"@
$databases = Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $ControlDB -Query $query
$s3ListRaw = aws s3 ls $S3BucketRoot | Select-String -Pattern "IVPP_$DateStamp.*\.bak"
$s3Files = $s3ListRaw -replace '^\s*\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\s+\d+\s+', ''

$jobQueue = @()

foreach ($db in $databases) {
    $dbName = $db.DatabaseName
    #$matchingFile = $s3Files | Where-Object { $_ -like "$dbName_$DateStamp*.bak" }
    $matchingFile = $s3Files | Where-Object { $_ -match "^$dbName.*$DateStamp.*\.bak$" } | Select-Object -First 1

    if ($matchingFile) {
        $s3FilePath = "$S3BucketRoot$matchingFile"
        $localFileStaging = "$BackupDownloadStagingPath\$matchingFile"
        $localFileFinal = "$BackupDownloadFinalPath\$matchingFile"
        #Write-Host "$s3FilePath"
        #Write-Host "$matchingFile"
        #Write-Host "$localFileStaging"
        #Write-Host "$localFileFinal"
        #Break;

        while (@(Get-Job -State "Running").Count -ge $MaxParallelDownloads) {
            Start-Sleep -Seconds 5
        }

        $jobQueue += Start-ThreadJob -Name $dbName -ScriptBlock {
            param($dbName, $s3FilePath, $localFileStaging, $localFileFinal, $SqlInstance, $ControlDB, $matchingFile, $RetryAttempts)

            $attempt = 0
            $success = $false
            $fullError = ""
            $start = Get-Date

            while (-not $success -and $attempt -lt $RetryAttempts) {
                try {
                    $attempt++
                    aws s3 cp $s3FilePath $localFileStaging --no-progress

                    if (Test-Path $localFileStaging) {
                        Move-Item -Path $localFileStaging -Destination $localFileFinal -Force
                        $success = $true
                    } else {
                        throw "File not found after download: $localFileStaging"
                    }
                }
                catch {
                    $fullError += "Attempt $attempt failed: $($_.Exception.Message)`n"
                    Start-Sleep -Seconds 5
                }
            }

            $end = Get-Date
            $duration = [math]::Round(($end - $start).TotalMinutes, 2)
            if ($success) {$status = "Success"} else {$status = "Failed"}

            $logQuery = @"
INSERT INTO S3DownloadLogs 
(DatabaseName, StartTime, EndTime, TotalTime, BackupFileName, Status, ErrorMsg)
VALUES ('$dbName', '$start', '$end', $duration, '$matchingFile', '$status', '$fullError')
"@
            Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $ControlDB -Query $logQuery

        } -ArgumentList $dbName, $s3FilePath, $localFileStaging, $localFileFinal, $SqlInstance, $ControlDB, $matchingFile, $RetryAttempts
    }
    else {
        $msg= "No matching file found in S3 for $dbName on $DateStamp"
        Write-Host $msg 
        $sd=Get-Date
        $ed=Get-Date
        $tt=($ed-$sd).TotalMinutes
$logQuery = @"
INSERT INTO S3DownloadLogs 
(DatabaseName, StartTime, EndTime, TotalTime, BackupFileName, Status, ErrorMsg)
VALUES ('$dbName', '$sd', '$ed', $tt, '$matchingFile', 'Failed', '$msg')
"@
 Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $ControlDB -Query $logQuery
    }
}

Write-Host "Waiting for all downloads to complete..."
Get-Job | Wait-Job | Receive-Job
Write-Host "All done."
$ProcessEnd=Get-Date
$TotalTime=($ProcessEnd-$ProcessStart).TotalMinutes
Write-Host "##############################################"
Write-Host "ProcessStartTime : $ProcessStart"
Write-Host "ProcessEndTime : $ProcessEnd"
Write-Host "TotalTime : $TotalTime"
Write-Host "##############################################"

