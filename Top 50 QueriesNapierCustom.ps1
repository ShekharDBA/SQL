Import-Module dbatools
$MyInstance = $env:COMPUTERNAME
$today = get-date -Format "dd MMM yyyy"
$MyInstance
#$To = "venkata.kiran@napierparkglobal.com"
$To = "napiertechsupportoda@napierparkglobal.com","technology@napierparkglobal.com"
$Cc = "chandra.shekhar@napierparkglobal.com"
$From = "aws-npg-sql-prod-ses-user@napierparkglobal.com"
$Subject = "Top 50 Slowest Queries(NapierCustom) in last 24 hours on $MyInstance on $today"
$SMTPServer = "email-smtp.us-east-1.amazonaws.com"
#$SMTPServer = "extrlus.options-it.com"

$style = @"
<style>
H3{color:seagreen}
TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse}
TH{border-width: 1px;padding: 2px;border-style: solid;border-color: black;background-color:seagreen;font-size:12;color:white}
TD{border-width: 1px;padding: 5px;border-style: solid;border-color: black;color:blue;font-size:12}
</style>
"@
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
$query =  "
Select TOP 50 ServerName,[dd hh:mm:ss.mss]as [Duration(dd hh:mm:ss.mss)],session_id,ac.sql_text,login_name,status,CPU,host_name,database_name,program_name,collection_time
from IVPProdAudit.dbo.ActiveQueries ac
INNER JOIN (Select MAX(AWSSessionID)as AWSID,Convert(nvarchar(max),sql_text)As sql_text
from IVPProdAudit.dbo.ActiveQueries WHere collection_time>=getdate()-1
Group by Convert(nvarchar(max),sql_text)
)a ON ac.AWSSessionID=a.AWSID 
Where ac.database_name='NapierCustom' and Convert(nvarchar(max),ac.sql_text) not like '%backup%' and status='runnable'
order by [Duration(dd hh:mm:ss.mss)] DESC
"
$Report = Invoke-Sqlcmd -ServerInstance $MyInstance -Database "IVPProdAudit" -Query $query -Querytimeout 0 | convertTo-Html -Head $style -Property ServerName,'Duration(dd hh:mm:ss.mss)',session_id,sql_text,login_name,status,CPU,host_name,database_name,program_name,collection_time


$body = "<h3>Top 50 Queries NapierCustom database:</h3>"
##$colorTagTable.Keys | foreach { $LastBackups = $LastBackups -replace ">$_<",($colorTagTable.$_) }
$body += $Report
if($Report.Count -gt 8){
$User = "AKIAVRUVUNTHEQ7TTVN3"
$PWord = ConvertTo-SecureString -String "BEjJLsP/iZTTO91cexHl/tjiPvry1aS9gEkY4CfrRrs1" -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord
Send-MailMessage -To $To -Cc $Cc -Subject $Subject –From $From -SmtpServer $SMTPServer -Port 587 -Credential $Credential -UseSsl -Body $body -BodyAsHtml
#Send-MailMessage -To $To -Cc $Cc -Subject $Subject –From $From -SmtpServer $SMTPServer -Body $body -BodyAsHtml
}
Else{
Write-Host "No data. !"
}