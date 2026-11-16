###Created on 2023-07-04 by User djha_npg###

$MyInstance = $env:COMPUTERNAME
$today = get-date -Format "dd MMM yyyy"
$To = "napiertechsupportoda@napierparkglobal.com" #,"technology@napierparkglobal.com"
#$To = "deepak.jha@napierparkglobal.com"
$Cc = "deepak.jha@napierparkglobal.com"
$From = "aws-npg-sql-uat-ses-user@napierparkglobal.com"
$SMTPServer = "email-smtp.us-east-1.amazonaws.com"

<#
$style = @"
<style>            
table {            
  width:100%;            
}            
table, th, td {            
  border: 1px solid black;            
  border-collapse: collapse;            
}            
th, td {            
  padding: 10px;            
  text-align: left;     
  width:100%; 
  
}            
table tr:nth-child(even) {            
  background-color: #eee;            
}            
table tr:nth-child(odd) {            
 background-color: #fff;            
}            
table th {            
  background-color: #ff3333;            
  color: #000000;            
  } 
  h2{
  color:#ff4d4d
  }           
</style>
"@
#>
$style = @"
<style>
H2{color:blue}
TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse}
TH{border-width: 1px;padding: 2px;border-style: solid;border-color: black;background-color:seagreen;font-size:16;color:white}
TD{border-width: 1px;padding: 5px;border-style: solid;border-color: black;color:blue;font-size:14}
</style>
"@
$query =  "
Select TOP 50 ServerName,[dd hh:mm:ss.mss]as [Duration(dd hh:mm:ss.mss)],session_id,ac.sql_text,login_name,CPU,host_name,database_name,program_name,collection_time
from [IVPUatAudit].[dbo].[AWS_sessions_collection] ac
INNER JOIN (Select MAX(AWSSessionID)as AWSID,Convert(nvarchar(max),sql_text)As sql_text
from [IVPUatAudit].[dbo].[AWS_sessions_collection] WHere collection_time>=getdate()-1
Group by Convert(nvarchar(max),sql_text)
)a ON ac.AWSSessionID=a.AWSID 
order by CPU DESC"

$topCPUQueries = Invoke-Sqlcmd -ServerInstance $MyInstance -Database "IVPUatAudit" -Query $query -Querytimeout 0 | convertTo-Html -Head $style -Property ServerName,'Duration(dd hh:mm:ss.mss)',session_id,sql_text,login_name,CPU,host_name,database_name,program_name,collection_time 


$body = "<h2>Top CPU Queries:</h2>"
##$colorTagTable.Keys | foreach { $LastBackups = $LastBackups -replace ">$_<",($colorTagTable.$_) }
$body += $topCPUQueries
$User = "AKIAVRUVUNTHAMQGXJUS"
$PWord = ConvertTo-SecureString -String "BMhK2Nhq/9/vfiNiru1426fyxUdgLH5bSkr0V8NPDyWz" -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord
Send-MailMessage -To $To -Cc $Cc -Subject "Top CPU Queries in last 24 hours on $MyInstance on $today" –From $From -SmtpServer $SMTPServer -Port 587 -Credential $Credential -UseSsl -Body $body -BodyAsHtml
#Send-MailMessage -To $To -Subject "Top CPU Queries Running on $MyInstance on $today" –From "supportdba@options-it.com" -SmtpServer $MailServer -Body $body -BodyAsHtml
