Import-Module dbatools
$MyInstance = $env:COMPUTERNAME
$today = get-date -Format "dd MMM yyyy"

$To = "napiertechsupportoda@napierparkglobal.com"
$Cc = "deepak.jha@napierparkglobal.com"
$From = "aws-npg-sql-uat-ses-user@napierparkglobal.com"
$Subject = "Top 20 Queries--NPGUAT-IVPREARC--{$today}"
$SMTPServer = "email-smtp.us-east-1.amazonaws.com"

#$style = @"
#<style>
#H2{color:#ff4d4d}
#TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse}
#TH{border-width: 1px;padding: 2px;border-style: solid;border-color: black;background-color:seagreen;font-size:16;color:white}
#TD{border-width: 1px;padding: 5px;border-style: solid;border-color: black;color:blue;font-size:14}
#</style>
#"@

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

$query =  "Exec dbo.sp_Email_Top20Query"
$Report = Invoke-Sqlcmd -ServerInstance "NPGUAT-IVPREARC" -Database "IVPUatAudit" -Query $query | convertTo-Html -Head $style -Property 'dd hh:mm:ss.mss',session_id,sql_text,login_name,blocking_session,host_name,database_name,program_name,job_name,starttime,colection_time


$body = "<h2>Top 20 Queries:</h2>"
##$colorTagTable.Keys | foreach { $LastBackups = $LastBackups -replace ">$_<",($colorTagTable.$_) }
$body += $Report

$User = "AKIAVRUVUNTHAMQGXJUS"
$PWord = ConvertTo-SecureString -String "BMhK2Nhq/9/vfiNiru1426fyxUdgLH5bSkr0V8NPDyWz" -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord
Send-MailMessage -To $To -Cc $Cc -Subject $Subject –From $From -SmtpServer $SMTPServer -Port 587 -Credential $Credential -UseSsl -Body $body -BodyAsHtml
