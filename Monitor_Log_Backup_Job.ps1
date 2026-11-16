$To = "napiertechsupportoda@napierparkglobal.com"
$Cc = "deepak.jha@napierparkglobal.com"
$From = "aws-npg-sql-uat-ses-user@napierparkglobal.com"
$SMTPServer = "email-smtp.us-east-1.amazonaws.com"

$SThreshold = 120
$MThreshold = New-TimeSpan -Seconds $SThreshold
Get-DbaAgentJob -SqlInstance $env:computername | where-object {($_.Name -eq "OTL - SQL Log Backups") -and ($_.CurrentRunStatus -ne "Idle")}
Start-Sleep -s $SThreshold
$statuscheck= Get-DbaAgentJob -SqlInstance $env:computername | where-object {($_.Name -eq "OTL - SQL Log Backups") -and ($_.CurrentRunStatus -ne "Idle")}

if($statuscheck.CurrentRunStatus -eq "Executing")
{
  $body = "$($statuscheck.Name) has exceeded the threshold of $($MThreshold.TotalMinutes) minutes"
   $User = "AKIA2PHX6VSJIJ2EZ6ES"
    $PWord = ConvertTo-SecureString -String "BPLXU6gbV/iU+AJNfzRFWaSwI9lf7LFfnQbPZNCC9XB7" -AsPlainText -Force
    $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord
    Send-MailMessage -To $To -Subject "$($statuscheck.Name) Job on $env:computername Is Still Running" –From $From -SmtpServer $SMTPServer -Port 587 -Credential $Credential -UseSsl -Body $body
}