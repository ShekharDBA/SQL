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

$topIOQueries = Get-DbaTopResourceUsage -SqlInstance $MyInstance -Type IO  | convertTo-Html -Head $style -Property SqlInstance,Database,AverageIO,ExecutionCount,ObjectName,QueryText,QueryTotalIO,TotalIO

$body = "<h2>Top IO Queries:</h2>"
##$colorTagTable.Keys | foreach { $LastBackups = $LastBackups -replace ">$_<",($colorTagTable.$_) }
$body += $topIOQueries

#Send-MailMessage -To $To -Subject "Top IO Queries Running on $MyInstance on $today" –From "supportdba@options-it.com" -SmtpServer $MailServer -Body $body -BodyAsHtml
$User = "AKIAVRUVUNTHAMQGXJUS"
$PWord = ConvertTo-SecureString -String "BMhK2Nhq/9/vfiNiru1426fyxUdgLH5bSkr0V8NPDyWz" -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord
Send-MailMessage -To $To -Subject "Top IO Queries Running on $MyInstance on $today" –From $From -SmtpServer $SMTPServer -Port 587 -Credential $Credential -UseSsl -Body $body -BodyAsHtml
