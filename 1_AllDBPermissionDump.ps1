$SqlInstance = "NPGUAT-IVPSDB03"
$DatabaseName="master"
$DT=(Get-Date).ToString("yyyyMMdd")
$OutPutFile="H:\WeekendRefresh\PostScripts\PermissionDump__${DT}.sql"

Sleep -Seconds 2

$ScriptsData=Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $DatabaseName -Query "Exec [dbo].[sp_createPermissionScript]"
forEach($row in $ScriptsData){
$row.Column1 | Add-Content -Path $OutPutFile

}
Write-Host "Script Comppleted !"