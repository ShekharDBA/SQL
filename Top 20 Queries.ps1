Import-Module dbatools
$MyInstance = $env:COMPUTERNAME
$today = get-date -Format "dd MMM yyyy"
$MyInstance
#$To = "deepak.jha@napierparkglobal.com"
#$To = "napiertechsupportoda@napierparkglobal.com"
$To = "napiertechsupportoda@napierparkglobal.com", "ivprearchsupport@ivp.in","Chandra.Chandraker@napierparkglobal.com","anand.singit@napierparkglobal.com","Rahul.Rastogi@napierparkglobal.com","Dave.Sunny@napierparkglobal.com"
$Cc = "Amit.Khanna@napierparkglobal.com", "chandra.shekhar@napierparkglobal.com"
$From = "aws-npg-sql-prod-ses-user@napierparkglobal.com"
$Subject = "Top 20 Slowest Queries in last 24 hours on $MyInstance on $today"
$SMTPServer = "email-smtp.us-east-1.amazonaws.com"
#$SMTPServer = "extrlus.options-it.com"

$style = @"
<style>
H3{color:#ff4d4d}
TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;display: block;}
TH{border-width: 1px;padding: 2px;border-style: solid;border-color: black;background-color:seagreen;font-size:12;color:white;}
TD{border-width: 1px;padding: 5px;border-style: solid;border-color: black;color:blue;font-size:12;display: inline-block;}
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
$query =  "Select [Time taken by SQL (dd hh:mm:ss.mss)]as [duration(dd hh:mm:ss.mss)],session_id,sql_text,login_name,blocking_session,host_name,database_name,program_name,job_name,starttime,colection_time,status From [IVPProdAudit].[dbo].Top20Query Order by 1 desc"
$Report = Invoke-Sqlcmd -ServerInstance $MyInstance -Database "IVPProdAudit" -Query $query | convertTo-Html -Head $style -Property 'Duration(dd hh:mm:ss.mss)',session_id,sql_text,login_name,blocking_session,host_name,database_name,program_name,job_name,starttime,colection_time,status

$body = "<h3>Top 20 Queries:</h3>"
##$colorTagTable.Keys | foreach { $LastBackups = $LastBackups -replace ">$_<",($colorTagTable.$_) }
$body += $Report
$User = "AKIAVRUVUNTHEQ7TTVN3"
$PWord = ConvertTo-SecureString -String "BEjJLsP/iZTTO91cexHl/tjiPvry1aS9gEkY4CfrRrs1" -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord
Send-MailMessage -To $To -Cc $Cc -Subject $Subject –From $From -SmtpServer $SMTPServer -Port 587 -Credential $Credential -UseSsl -Body $body -BodyAsHtml
#Send-MailMessage -To $To -Cc $Cc -Subject $Subject –From $From -SmtpServer $SMTPServer -Body $body -BodyAsHtml
