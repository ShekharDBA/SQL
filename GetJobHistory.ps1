$MyInstances = 'npguivpd02use1a','npgdivpd02use1a','npgpivpd02use1a'
$today = get-date -Format "dd MMM yyyy hh:mm"
$beginDate = (get-date $today).AddDays(-1).ToString(“yyyy-MM-dd HH:mm”)
$finishDate = (Get-Date $today).toString(“yyyy-MM-dd HH:mm”)

Get-DbaAgentJobHistory -SqlInstance $myInstances | Select SqlInstance,Job,StepName,RunDate,StartDate,EndDate,Duration,Status,Message