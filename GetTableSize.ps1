$MyInstances = 'npguivpd02use1a'
$today = get-date -Format "dd MMM yyyy hh:mm"
$startDate = (get-date $today).AddDays(-1).ToString(“yyyy-MM-dd HH:mm”)
$endDate = (Get-Date $today).toString(“yyyy-MM-dd HH:mm”)

$MyInstances.ForEach{
 Get-DbaDbTable -SqlInstance  | Select @{n="CurrentDate";e={(Get-Date).ToString('MM-dd-yyyy hh:mm')}},SqlInstance,Database,Schema,Name,@{Name="DataSpaceUsed";Expression={[math]::round($_.DataSpaceUsed/1GB,2)}} | Sort-Object DataSpaceUsed -Descending | Select -First 10
}