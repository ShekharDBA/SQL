$AttachmentPath = "D:\Monitoring\DBA\UnusedTable_UAT.csv"
if (Test-Path $AttachmentPath) {
   Remove-Item $AttachmentPath -verbose
}

$MyInstance = $env:COMPUTERNAME
$today = get-date -Format "dd MMM yyyy"

#napiertechsupportoda@napierparkglobal.com
$To = "napiertechsupportoda@napierparkglobal.com"
#$To="deepak.jha@napierparkglobal.com"
$Cc = "deepak.jha@napierparkglobal.com"
$From = "aws-npg-sql-uat-ses-user@napierparkglobal.com"
$Subject = "Unused Tables Report $MyInstance--$today"
$SMTPServer = "email-smtp.us-east-1.amazonaws.com"



Invoke-Sqlcmd   -ServerInstance $MyInstance -Database  "IVPUatAudit" -Query "Select * FROM [IVPUatAudit].[dbo].[Unused_Tbl]" | Export-CSV $AttachmentPath -NoTypeInformation

$User = "AKIAVRUVUNTHAMQGXJUS"
$PWord = ConvertTo-SecureString -String "BMhK2Nhq/9/vfiNiru1426fyxUdgLH5bSkr0V8NPDyWz" -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord
Send-MailMessage -To $To -Cc $Cc -Subject $Subject –From $From -SmtpServer $SMTPServer -Port 587 -Credential $Credential -UseSsl -Attachments $AttachmentPath -Body "Please find the attached file. !" -BodyAsHtml