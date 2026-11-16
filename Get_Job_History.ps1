Import-Module dbatools

$MyInstance = $env:COMPUTERNAME
$today = get-date -Format "dd MMM yyyy"

#$To = 'napiertechsupportoda@napierparkglobal.com'
#$MailServer = 'extrlus.options-it.com'

$To = "napiertechsupportoda@napierparkglobal.com"
$Cc = "deepak.jha@napierparkglobal.com"
$From = "aws-npg-sql-uat-ses-user@napierparkglobal.com"
$SMTPServer = "email-smtp.us-east-1.amazonaws.com"

$style = @"
<style>
H2{color:blue}
TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse}
TH{border-width: 1px;padding: 2px;border-style: solid;border-color: black;background-color:seagreen;font-size:16;color:white}
TD{border-width: 1px;padding: 5px;border-style: solid;border-color: black;color:blue;font-size:14}
</style>
"@

$MyInstance = $env:COMPUTERNAME
$todaysDate = (Get-Date).ToString("MM/dd/yyyy")
$yesterdaysDate = (Get-Date).Adddays(-1).ToString("MM/dd/yyyy")
$JobDetails = Get-DbaAgentJobHistory -SqlInstance $MyInstance -ExcludeJobSteps | Where-Object {($_.RunDate -like "$yesterdaysDate*") -or ($_.RunDate -like "$todaysDate*")} | convertTo-Html -Head $style -Property SqlInstance,Job,StepName,RunDate,StartDate,EndDate,Duration,Status,Message 

$body = "<h2>Job History Overview:</h2>"
##$colorTagTable.Keys | foreach { $LastBackups = $LastBackups -replace ">$_<",($colorTagTable.$_) }
$body += $JobDetails

#Send-MailMessage -To $To -Subject "Job History Details on $MyInstance from $today" –From "supportdba@options-it.com" -SmtpServer $MailServer -Body $body -BodyAsHtml
$User = "AKIAVRUVUNTHAMQGXJUS"
$PWord = ConvertTo-SecureString -String "BMhK2Nhq/9/vfiNiru1426fyxUdgLH5bSkr0V8NPDyWz" -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord
Send-MailMessage -To $To -Subject "Job History Details on $MyInstance from $today" –From $From -SmtpServer $SMTPServer -Port 587 -Credential $Credential -UseSsl -Body $body -BodyAsHtml
