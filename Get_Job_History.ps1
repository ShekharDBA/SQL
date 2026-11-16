Import-Module dbatools

$MyInstance = $env:COMPUTERNAME
$today = get-date -Format "dd MMM yyyy"

#$To ='deepak.jha@napierparkglobal.com'
#$MailServer = 'extrlus.options-it.com'

$To = 'napiertechsupportoda@napierparkglobal.com'
$Cc = "deepak.jha@napierparkglobal.com"
$From = "aws-npg-sql-prod-ses-user@napierparkglobal.com"
$SMTPServer = "email-smtp.us-east-1.amazonaws.com"
#$SMTPServer = "extrlus.options-it.com"


$style = @"
<style>
H3{color:blue}
TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse}
TH{border-width: 1px;padding: 2px;border-style: solid;border-color: black;background-color:seagreen;font-size:12;color:white}
TD{border-width: 1px;padding: 5px;border-style: solid;border-color: black;color:blue;font-size:14}
</style>
"@

$MyInstance = $env:COMPUTERNAME
$todaysDate = (Get-Date).ToString("MM/dd/yyyy")
$yesterdaysDate = (Get-Date).Adddays(-1).ToString("MM/dd/yyyy")
$JobDetails = Get-DbaAgentJobHistory -SqlInstance $MyInstance -ExcludeJobSteps | Where-Object {($_.RunDate -like "$yesterdaysDate*") -or ($_.RunDate -like "$todaysDate*")} | convertTo-Html -Head $style -Property SqlInstance,Job,StepName,RunDate,StartDate,EndDate,Duration,Status,Message 

$body = "<h3>Job History Overview:</h3>"
##$colorTagTable.Keys | foreach { $LastBackups = $LastBackups -replace ">$_<",($colorTagTable.$_) }
$body += $JobDetails
$User = "AKIAVRUVUNTHEQ7TTVN3"
$PWord = ConvertTo-SecureString -String "BEjJLsP/iZTTO91cexHl/tjiPvry1aS9gEkY4CfrRrs1" -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord
Send-MailMessage -To $To -Cc $Cc -Subject "Job History Details of last 24 hours on $MyInstance" –From $From -SmtpServer $SMTPServer -Port 587 -Credential $Credential -UseSsl -Body $body -BodyAsHtml 
#Send-MailMessage -To $To -Cc $Cc -Subject "Job History Details on $MyInstance from $today" –From $From -SmtpServer $SMTPServer -Body $body -BodyAsHtml
