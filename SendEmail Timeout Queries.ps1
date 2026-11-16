Import-Module dbatools
$MyInstance = $env:COMPUTERNAME
$today = get-date -Format "dd MMM yyyy"

#napiertechsupportoda@napierparkglobal.com
$To = "napiertechsupportoda@napierparkglobal.com"
$Cc = "deepak.jha@napierparkglobal.com"
$From = "aws-npg-sql-uat-ses-user@napierparkglobal.com"
$Subject = "Timeout Queries--NPGUIVPD02USE1A--{$today}"
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

$query =  "Exec dbo.sp_Sendtimeouterror_Email"
$Report = Invoke-Sqlcmd -ServerInstance "NPGUAT-IVPREARC" -Database "IVPUatAudit" -Query $query | convertTo-Html -Head $style -Property msg,errordate,details

$body = "<h2>Timeout Queries:</h2>"
##$colorTagTable.Keys | foreach { $LastBackups = $LastBackups -replace ">$_<",($colorTagTable.$_) }
$body += $Report

$User = "AKIAVRUVUNTHAMQGXJUS"
$PWord = ConvertTo-SecureString -String "BMhK2Nhq/9/vfiNiru1426fyxUdgLH5bSkr0V8NPDyW" -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord
Send-MailMessage -To $To -Cc $Cc -Subject $Subject –From $From -SmtpServer $SMTPServer -Port 587 -Credential $Credential -UseSsl -Body $body -BodyAsHtml
