Cls;
$backupFolder = "B:\WeekendRefresh\Prod_Backups"
$s3Bucket = "s3://npgl-backups/ivp/prod/db"
$sqlServer = "NPGPRD-IVPSDB03"  
$sqlDatabase = "IVPPolaris"
$mappingTable = "dbo.[WeekendDBRefreshMapping]"
$logTable = "dbo.[S3DownloadLogs]"
$dateSuffix = Get-Date -Format "20260824"
$x="19"
$dateSuffix="$dateSuffix$x"
Write-Host $dateSuffix
#Import-Module SqlServer -ErrorAction Stop

# Set your AWS credentials
$env:AWS_ACCESS_KEY_ID = "ASIAVRUVUNTHJD5H53ZY"
$env:AWS_SECRET_ACCESS_KEY = "8PCs7TttblKhBviqsmUZmjZkwxfxZzC8"
$env:AWS_DEFAULT_REGION = "us-east-1"
$env:AWS_SESSION_TOKEN = "IQoJb3JpZ2luX2VjECIaCXVzLWVhc3QtMSJHMEUCIB6L2GIiVy1ku/TK1BIgkQt40ajYJ5MwLYimrlJL10VcAiEApVEe4ZNysgJxoiKjUeYS71VfXk8QhexUlY7JoTpbgDAqjgQI6///////////ARAAGgwzODE0OTIxNjE3NDIiDF7MxBF1yNAI4kk6YyriA9GFNFswgOD+9x90Bg/htKYswtunlWHTjH38e2llqApQ9ab/X7Go0mtYvry+OU/vJr1AdvXhpWlgrm7OxSyidjYmY7Ps8ZcSi5xtt0NxXIDAMWkVBIlWAInxbFaTsw0xIYaow+T6TDykkubrvzx3iNJVK4qiEhnX28dRbdQt40lLmRiLx3Fvm5VbK3eAl/hfU4c3M51fvfxSvym2lEW5W9MCLUuZgFLLatufSPdNQh8Xc5frhCkUr++u2iF/GADIckIive7ZOtdEq4qeR0y1iEzPv2vKUtp5MvPsBnHaT//NNmPjqozw4GpLa1bBgpgGQdLCNek/ucY3NldIT9SEui9SJRJlDCu65RziYr1ZehEzdB9DWCRQnN6kNeX9Hogeh+80pJqni65Xgz+nz4g2WKqZ+fRNnDE842IUwYXz2dKLy2+FXAfX0qmrl26apLRe89D/MLrlY7mwktF/2GlTWtlp8vDxaDg7hKitFEBgZPOeKjUD89VJMacZYi3VJWigl5/g2ObEigHviLb1bcp9xq6dOPswfg1Z6Cbu6Za25XdiKvL7HEeznCm3IdYxUZISVXB5AUUDHGVvxPfRirhi6IWA1k8wiCnsXmVG+hddT31Ojoj4MGv2aYoMQ+06dTRUklQdMMStsNQGOqgBIj6USek6kPTUZIj8gbOohkPkNZ2aq+fV0qUkN7UBIoM9ZdmwsIWc245sNaDF/Zn56OAsgb3zYmboxmxdqtkri2dZmWSenQKR0pXwzTAMr5VwyA21gV/KOdwHAiGar4TT1l+LanFuzeI/t/lu54wg/Y6Hyj8RZteLa5EXFfnDa0oQjJFBnEnKKy3RkfN1EhfMlr06RZ/xZOROIabbGNe+wbLhBjXn4wJR"

$query = @"
SELECT [SourceDB]
FROM [$sqlDatabase].$mappingTable Where RefreshStatus=0
ORDER BY [Group] ASC
"@
$databases = Invoke-Sqlcmd -ServerInstance $sqlServer -Database $sqlDatabase -Query $query

foreach ($db in $databases) {
    $sourceDB = $db.SourceDB
    $regex = "$sourceDB" + "_" + "$dateSuffix" + ".*\.bak"
    $startTime = Get-Date
    $status = "Success"
    $errorMsg = ""
    $filesFound = @()
    Write-Host "Downloading Backup : $regex Please wait..." -ForegroundColor Yellow

    try {

        $listOutput = aws s3 ls $s3Bucket/ --recursive | Where-Object { $_ -match $regex }
        if (-not $listOutput) {
            throw "No matching backup file found."
        }

        foreach ($line in $listOutput) {
            $parts = $line -split "\s+"
            $filePath = $parts[-1]
            $filesFound += $filePath
        }
        foreach ($file in $filesFound) {
        $fname=(Split-Path $file -Leaf)
        
            $destinationFile = Join-Path $backupFolder (Split-Path $file -Leaf)
            if(Test-Path -Path "$backupFolder\$fname" -PathType Leaf){
                Write-Host "$fname already downloaded ! skipping download" -ForegroundColor Green
                $filesFound = @()
                
            }
            else{
            aws s3 cp "s3://npgl-backups/$file" $destinationFile #--no-progress
            }
            if (-not (Test-Path $destinationFile)) {
                throw "File $file failed to download."
            }
        }
    }
    catch {
        $status = "Failed"
        $errorMsg = $_.Exception.Message
    }
    $endTime = Get-Date
    $totalTime = ($endTime - $startTime).TotalMinutes
    $collectionTime = Get-Date
    
    if ($filesFound.Count -gt 0) {
        foreach ($file in $filesFound) {
            $backupFileName = Split-Path $file -Leaf
            $logQuery = @"
INSERT INTO [$sqlDatabase].$logTable 
    (DatabaseName, StartTime, EndTime, TotalTime, BackupFileName, Status, ErrorMsg, CollectionTime)
VALUES 
    ('$sourceDB', '$startTime', '$endTime', $totalTime, '$backupFileName', '$status', '$errorMsg', '$collectionTime')
"@
    
            try {
                Invoke-Sqlcmd -ServerInstance $sqlServer -Database $sqlDatabase -Query $logQuery
            }
            catch {
                Write-Warning "Failed to insert log for $sourceDB file $backupFileName : $_"
            }
        }
    }
    else {
    if($filesFound.Length -gt 5){

        $logQuery = @"
INSERT INTO [$sqlDatabase].$logTable
    (DatabaseName, StartTime, EndTime, TotalTime, BackupFileName, Status, ErrorMsg, CollectionTime)
VALUES 
    ('$sourceDB', '$startTime', '$endTime', $totalTime, '', '$status', '$errorMsg', '$collectionTime')
"@
        try {
            Invoke-Sqlcmd -ServerInstance $sqlServer -Database $sqlDatabase -Query $logQuery
        }
        catch {
            Write-Warning "Failed to insert log for $sourceDB with no file: $_"
        }
    }
    }
}

Sleep -Seconds 3
Invoke-Sqlcmd -ServerInstance $sqlServer -Database $sqlDatabase -Query "Exec sp_sends3DownloadEmail"