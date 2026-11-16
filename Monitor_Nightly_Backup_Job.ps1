#$To = 'napiertechsupportoda@napierparkglobal.com'
#$MailServer = 'extrlus.options-it.com' 

$To = "napiertechsupportoda@napierparkglobal.com"
        
$Cc = "chandra.shekhar@napierparkglobal.com"
$From = "aws-npg-sql-prod-ses-user@napierparkglobal.com"
$SMTPServer = "email-smtp.us-east-1.amazonaws.com"
#$SMTPServer = "extrlus.options-it.com"

$SThreshold = 7200
New-TimeSpan -Seconds $SThreshold
$MThreshold = New-TimeSpan -Seconds $SThreshold
Get-DbaAgentJob -SqlInstance $env:computername | where-object {($_.Name -eq "OTL - Nightly SQL Backups") -and ($_.CurrentRunStatus -ne "Idle")}
Start-Sleep -s $SThreshold
$statuscheck= Get-DbaAgentJob -SqlInstance $env:computername | where-object {($_.Name -eq "OTL - Nightly SQL Backups") -and ($_.CurrentRunStatus -ne "Idle")}

if($statuscheck.CurrentRunStatus -eq "Executing")
{
     $body = "$($statuscheck.Name) has exceeded the threshold limit of $($MThreshold.TotalHours) hours"
     $User = "AKIAVRUVUNTHEQ7TTVN3"
     $PWord = ConvertTo-SecureString -String "BEjJLsP/iZTTO91cexHl/tjiPvry1aS9gEkY4CfrRrs1" -AsPlainText -Force
     $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord
     Send-MailMessage -To $To -Cc $Cc -Subject "$($statuscheck.Name) Job on $env:computername Is Still Running" –From $From -SmtpServer $SMTPServer -Port 587 -Credential $Credential -UseSsl -Body $body -BodyAsHtml
     #Send-MailMessage -To $To -Cc $Cc -Subject "$($statuscheck.Name) Job on $env:computername Is Still Running" –From $From -SmtpServer $SMTPServer -Body $body

}