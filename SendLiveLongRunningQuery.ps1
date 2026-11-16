
$MyInstance = $env:COMPUTERNAME
$today = get-date -Format "dd MMM yyyy"
#$MyInstance
#$To = "deepak.jha@napierparkglobal.com"
#$To = "napiertechsupportoda@napierparkglobal.com"

$To ="napiertechsupportoda@napierparkglobal.com", "Chandra.Chandraker@napierparkglobal.com","anand.singit@napierparkglobal.com", "Rahul.Rastogi@napierparkglobal.com","Dave.Sunny@napierparkglobal.com"

$Cc = "chandra.shekhar@napierparkglobal.com, Amit.Khanna@napierparkglobal.com"
$From = "aws-npg-sql-prod-ses-user@napierparkglobal.com"
$Subject = "Long Running Queries >15 Mins on NPGUAT-IVPSDB03"
$SMTPServer = "email-smtp.us-east-1.amazonaws.com"
#$SMTPServer = "extrlus.options-it.com"

$style = @"
<style>
H2{color:blue}
TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse}
TH{border-width: 1px;padding: 2px;border-style: solid;border-color: black;background-color:seagreen;font-size:12;color:white}
TD{border-width: 1px;padding: 5px;border-style: solid;border-color: black;color:blue;font-size:14}
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
$query =  "Exec dbo.sp_LongRunningQuery"
$Report = Invoke-Sqlcmd -ServerInstance "NPGUAT-IVPSDB03" -Database "IVPProdAudit" -Query $query | convertTo-Html -Head $style -Property 'Duration (dd hh:mm:ss.mss)',S_ID,SQL_Text,Login_Name,Status,HostName,DatabaseName,ProgramName,StartTime,CollectionTime


$body = "<h2>Long Running Queries>15 mins:</h2>"
##$colorTagTable.Keys | foreach { $LastBackups = $LastBackups -replace ">$_<",($colorTagTable.$_) }


$Report.Count
if ($Report.Count -gt 8){
    $body += $Report
    $User = "AKIAVRUVUNTHEQ7TTVN3"
    $PWord = ConvertTo-SecureString -String "BEjJLsP/iZTTO91cexHl/tjiPvry1aS9gEkY4CfrRrs1" -AsPlainText -Force
    $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord
    Send-MailMessage -To $To -Cc $Cc -Subject $Subject –From $From -SmtpServer $SMTPServer -Port 587 -Credential $Credential -UseSsl -Body $body -BodyAsHtml
    #Send-MailMessage -To $To -Cc $Cc -Subject $Subject –From $From -SmtpServer $SMTPServer -Body $body -BodyAsHtml

} 
else{
 Write-Host "No data found !"
}

