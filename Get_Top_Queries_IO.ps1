Import-Module dbatools

$MyInstance = $env:COMPUTERNAME
$today = get-date -Format "dd MMM yyyy"

#$To = 'napiertechsupportoda@napierparkglobal.com','Chandra.Chandraker@napierparkglobal.com','Dinesh.Loganathan@napierparkglobal.com','Arun.Bhuvanendran@napierparkglobal.com','anand.singit@napierparkglobal.com','Rahul.Rastogi@napierparkglobal.com'
#$MailServer = 'extrlus.options-it.com'

$To = 'napiertechsupportoda@napierparkglobal.com','Chandra.Chandraker@napierparkglobal.com','Dinesh.Loganathan@napierparkglobal.com','Arun.Bhuvanendran@napierparkglobal.com','anand.singit@napierparkglobal.com','Rahul.Rastogi@napierparkglobal.com'
#$To = "deepak.jha@napierparkglobal.com"
$Cc = "deepak.jha@napierparkglobal.com"
$From = "aws-npg-sql-prod-ses-user@napierparkglobal.com"
$SMTPServer = "email-smtp.us-east-1.amazonaws.com"
#$SMTPServer = "extrlus.options-it.com"

$style = @"
<style>
H2{color:blue}
TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse}
TH{border-width: 1px;padding: 2px;border-style: solid;border-color: black;background-color:seagreen;font-size:16;color:white}
TD{border-width: 1px;padding: 5px;border-style: solid;border-color: black;color:blue;font-size:14}
</style>
"@

#$topIOQueries = Get-DbaTopResourceUsage -SqlInstance $MyInstance -Type IO  | convertTo-Html -Head $style -Property SqlInstance,Database,AverageIO,ExecutionCount,ObjectName,QueryText,QueryTotalIO,TotalIO
$query =  "EXEC IVPProdAudit.dbo.sp_TOPIOQueries"
$topIOQueries = Invoke-Sqlcmd -ServerInstance $MyInstance -Database "IVPProdAudit" -Query $query -Querytimeout 0| convertTo-Html -Head $style -Property SqlInstance,Database,ExecutionCount,ObjectName,QueryText,QueryTotalIO,TotalIO


$body = "<h2>Top IO Queries:</h2>"
##$colorTagTable.Keys | foreach { $LastBackups = $LastBackups -replace ">$_<",($colorTagTable.$_) }
$body += $topIOQueries
$User = "AKIAVRUVUNTHEQ7TTVN3"
$PWord = ConvertTo-SecureString -String "BEjJLsP/iZTTO91cexHl/tjiPvry1aS9gEkY4CfrRrs1" -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord
Send-MailMessage -To $To -Cc $Cc -Subject "Top IO Queries Running on $MyInstance on $today" –From $From -SmtpServer $SMTPServer -Port 587 -Credential $Credential -UseSsl -Body $body -BodyAsHtml
#Send-MailMessage -To $To -Cc $Cc -Subject "Top IO Queries Running on $MyInstance on $today" –From $From -SmtpServer $SMTPServer -Body $body -BodyAsHtml
