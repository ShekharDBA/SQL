$MyInstances = 'NPGUAT-IVPREARC'
$today = get-date -Format "dd MMM yyyy hh:mm"
$beginDate = (get-date $today).AddDays(-1).ToString(“yyyy-MM-dd HH:mm”)
$finishDate = (Get-Date $today).toString(“yyyy-MM-dd HH:mm”)

$MyInstances.ForEach{
Get-DbaTopResourceUsage -SqlInstance $MyInstances -Type IO
}