cls;
#Import-Module SqlServer
$Files=aws s3 ls s3://npgl-backups/ivp/uat/db/ | Select-String -Pattern 'URA.*\.bak'
$TotalFiles=0
ForEach($File in $Files){
    $filename = ($File -split '\s+')[-1]
    #Write-Host $filename  -ForegroundColor Yellow
    IF(Test-Path -Path "B:\OnDemand_DB_Restore\Backups\$filename" -PathType leaf){
        $TotalFiles+=1
        Write-Host "$TotalFiles : $File" -ForegroundColor Green
        
    }
}
