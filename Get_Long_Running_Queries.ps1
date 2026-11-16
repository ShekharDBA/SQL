###Created on 2023-07-04 by User djha_npg###
$MyInstance = $env:COMPUTERNAME
$today = get-date -Format "dd MMM yyyy"

#$To = 'napiertechsupportoda@napierparkglobal.com','Chandra.Chandraker@napierparkglobal.com','Dinesh.Loganathan@napierparkglobal.com','Arun.Bhuvanendran@napierparkglobal.com','anand.singit@napierparkglobal.com','Rahul.Rastogi@napierparkglobal.com'
#$MailServer = 'extrlus.options-it.com'
$To = "napiertechsupportoda@napierparkglobal.com","Chandra.Chandraker@napierparkglobal.com","anand.singit@napierparkglobal.com","Rahul.Rastogi@napierparkglobal.com","Dave.Sunny@napierparkglobal.com"

$MailServer = 'extrlus.options-it.com'
$To = "napiertechsupportoda@napierparkglobal.com", "ivprearchsupport@ivp.in","Chandra.Chandraker@napierparkglobal.com","anand.singit@napierparkglobal.com","Rahul.Rastogi@napierparkglobal.com","Dave.Sunny@napierparkglobal.com"
napiertechsupportoda@napierparkglobal.com

ivprearchsupport@ivp.in

Chandra.Chandraker@napierparkglobal.com

anand.singit@napierparkglobal.com

Rahul.Rastogi@napierparkglobal.com

Dave.Sunny@napierparkglobal.com

#$To = "Venkata.Kiran@napierparkglobal.com"
$Cc = "Chandra.shekhar@napierparkglobal.com"
$From = "aws-npg-sql-prod-ses-user@napierparkglobal.com"
$SMTPServer = "email-smtp.us-east-1.amazonaws.com"
<#
#$SMTPServer = "extrlus.options-it.com"
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
#$topCPUQueries = Get-DbaTopResourceUsage -SqlInstance $MyInstance -Type CPU  | convertTo-Html -Head $style -Property SqlInstance,Database,CpuTime,AvgerageCpuMS,ExecutionCount,ObjectName,QueryText,QueryTotalCpu
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
Select ServerName,[dd hh:mm:ss.mss]as [Duration (dd hh:mm:ss.mss)],ac.session_id,convert(nvarchar(max),ac.sql_text)as Sql_text,login_name,CPU,tempdb_allocations,tempdb_current,reads,writes,status,host_name,database_name,program_name,collection_time
from IVPProdAudit.dbo.ActiveQueries ac
INNER JOIN (Select MAX(AWSSessionID)as AWSID,convert(nvarchar(max),sql_text)as sql_txt,session_id
from IVPProdAudit.dbo.ActiveQueries WHere collection_time>=getdate()-1 and status='runnable'  and convert(nvarchar(max),sql_text) not like '%Alter index%'
and convert(nvarchar(max),sql_text) not like '%UPDATE STATISTICS%'
Group by convert(nvarchar(max),sql_text),session_id
)a ON ac.AWSSessionID=a.AWSID and convert(nvarchar(max),ac.sql_text)=a.sql_txt and ac.session_id=a.session_id
and [dd hh:mm:ss.mss]>'00 00:05:00.000'
order by ac.[dd hh:mm:ss.mss] DESC
"

$LongQueries = Invoke-Sqlcmd -ServerInstance $MyInstance -Database "IVPProdAudit" -Query $query -Querytimeout 0 | convertTo-Html -Head $style -Property ServerName,'Duration (dd hh:mm:ss.mss)',session_id,Sql_text,login_name,CPU,tempdb_allocations,tempdb_current,reads,writes,status,host_name,database_name,program_name,collection_time 
Write-Host $LongQueries.Count
if($LongQueries.Count -gt 8){
$body = "<h2>Long Running Queries:</h2>"
##$colorTagTable.Keys | foreach { $LastBackups = $LastBackups -replace ">$_<",($colorTagTable.$_) }
$body += $LongQueries
$User = "AKIAVRUVUNTHEQ7TTVN3"
$PWord = ConvertTo-SecureString -String "BEjJLsP/iZTTO91cexHl/tjiPvry1aS9gEkY4CfrRrs1" -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord
Send-MailMessage -To $To -Cc $Cc -Subject "Long Running Queries in last 24 hours on $MyInstance on $today" –From $From -SmtpServer $SMTPServer -Port 587 -Credential $Credential -UseSsl -Body $body -BodyAsHtml
#Send-MailMessage -To $To -Subject "Top CPU Queries in last 24 hours on $MyInstance on $today" –From "supportdba@options-it.com" -SmtpServer $MailServer -Body $body -BodyAsHtml
}
else{
Write-Host "No data found"
}