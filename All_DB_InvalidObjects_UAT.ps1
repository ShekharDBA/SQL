$AttachmentPath = "D:\Monitoring\DBA\InvalidObjects_UAT.csv"
if (Test-Path $AttachmentPath) {
   Remove-Item $AttachmentPath -verbose
}

$MyInstance = $env:COMPUTERNAME
$today = get-date -Format "dd MMM yyyy"

#napiertechsupportoda@napierparkglobal.com
$To = "napiertechsupportoda@napierparkglobal.com"
$Cc = "chandra.shekhar@napierparkglobal.com"
$From = "aws-npg-sql-uat-ses-user@napierparkglobal.com"
$Subject = "All databases Invalid Objects Report $MyInstance--$today"
$SMTPServer = "email-smtp.us-east-1.amazonaws.com"



Invoke-Sqlcmd   -ServerInstance $MyInstance -Database  "IVPUatAudit" -Query "Exec dbo.sp_get_all_invalidObjects" | Export-CSV $AttachmentPath -NoTypeInformation

$User = "AKIA2PHX6VSJIJ2EZ6ES"
$PWord = ConvertTo-SecureString -String "BPLXU6gbV/iU+AJNfzRFWaSwI9lf7LFfnQbPZNCC9XB7" -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord
Send-MailMessage -To $To -Cc $Cc -Subject $Subject –From $From -SmtpServer $SMTPServer -Port 587 -Credential $Credential -UseSsl -Attachments $AttachmentPath -Body "Please find the attached file. !" -BodyAsHtml