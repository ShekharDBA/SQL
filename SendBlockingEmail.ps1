
$MyInstance = $env:COMPUTERNAME
$today = get-date -Format "dd MMM yyyy"


$To = "napiertechsupportoda@napierparkglobal.com"
#$To = "venkata.kiran@napierparkglobal.com"
$Cc = "chandra.shekhar@napierparkglobal.com"
$From = "aws-npg-sql-prod-ses-user@napierparkglobal.com"
$Subject = "Blocking Alerts on $MyInstance--$today"
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


#$body = "<h2 color:#ff4d4d>Invalid Objects Details</h2>"

#Invoke-Sqlcmd   -ServerInstance $MyInstance -Database  "IVPProdAudit" -Query "Select distinct * from IVPProdAudit.dbo.InvalidObjects Order by databaseName Asc" | Export-CSV $AttachmentPath -NoTypeInformation
#>
$style = @"
<style>
H3{color:#ff1a1a}
TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse}
TH{border-width: 1px;padding: 2px;border-style: solid;border-color: black;background-color:#ff1a1a;font-size:12;color:white}
TD{border-width: 1px;padding: 5px;border-style: solid;border-color: black;color:blue;font-size:14}
</style>
"@

$query =  "EXEC [IVPProdAudit].[dbo].[sp_sendblockmessage] 
	@nominutes=1,
	@opentranminutes=1"
$Report = Invoke-Sqlcmd -ServerInstance $MyInstance -Database "IVPProdAudit" -Query $query | convertTo-Html -Head $style -Property session_id,'Blocked From',blockedby,sql_text,database_name,waittype,loginname,logintime,hostname,programname,commndtype

$body = "<h3>Blocking Details:</h3>"
$body += $Report
Write-Host $Report.Count
if($Report.Count -gt 8){
$User = "AKIAVRUVUNTHEQ7TTVN3"
$PWord = ConvertTo-SecureString -String "BEjJLsP/iZTTO91cexHl/tjiPvry1aS9gEkY4CfrRrs1" -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord
Send-MailMessage -To $To -Cc $Cc -Subject $Subject –From $From -SmtpServer $SMTPServer -Port 587 -Credential $Credential -UseSsl -Body $body -BodyAsHtml
Write-Host "Email Sent"
}
Else{
Write-Host "No Blocking!!!"
}