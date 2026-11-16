$AttachmentPath = "D:\Monitoring\DBA\UnusedTable_Prod.csv"
if (Test-Path $AttachmentPath) {
   Remove-Item $AttachmentPath -verbose
}

$MyInstance = $env:COMPUTERNAME
$today = get-date -Format "dd MMM yyyy"

#napiertechsupportoda@napierparkglobal.com
$To = "napiertechsupportoda@napierparkglobal.com"
#$To="venkata.kiran@napierparkglobal.com"
$Cc = "chandra.shekhar@napierparkglobal.com"
$From = "aws-npg-sql-uat-ses-user@napierparkglobal.com"
$Subject = "Unused Tables Report $MyInstance--$today"
$SMTPServer = "email-smtp.us-east-1.amazonaws.com"



Invoke-Sqlcmd   -ServerInstance $MyInstance -Database  "IVPProdAudit" -Query "Select * FROM [IVPProdAudit].[dbo].[Unused_Tbl]" | Export-CSV $AttachmentPath -NoTypeInformation

$User = "AKIAVRUVUNTHEQ7TTVN3"
$PWord = ConvertTo-SecureString -String "BEjJLsP/iZTTO91cexHl/tjiPvry1aS9gEkY4CfrRrs1" -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord
Send-MailMessage -To $To -Cc $Cc -Subject $Subject –From $From -SmtpServer $SMTPServer -Port 587 -Credential $Credential -UseSsl -Attachments $AttachmentPath -Body "Please find the attached file. !" -BodyAsHtml