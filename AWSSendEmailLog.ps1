$yesterday = Get-Date (get-date).AddDays(-1) -format "MM-dd-yyyy"
$ydate = Get-Date (get-date).AddDays(-1) -format "MMddyyyy"
$environment = "prod"
$DirPath = "D:\Scripts\logs"
$logBackupFile = "ivp${environment}_log_backups_$ydate.txt"
$logBackupPath = "${DirPath}\${logBackupFile}"
$Threshold = "-2"
$MatchFileName = "ivp${environment}_log_backups"
$RemoveFiles = (Get-Date).AddDays($Threshold) 

#$To ='napiertechsupportoda@napierparkglobal.com'
#$MailServer = 'extrlus.options-it.com'

$To = 'napiertechsupportoda@napierparkglobal.com'
$Cc = "chandra.shekhar@napierparkglobal.com"
$From = "aws-npg-sql-prod-ses-user@napierparkglobal.com"
$SMTPServer = "email-smtp.us-east-1.amazonaws.com"
#$SMTPServer = "extrlus.options-it.com"

if (Test-Path -Path $logBackupPath)
{
   $output = get-content $logBackupPath | Select-String upload
   
#$User = "AKIA2PHX6VSJL2ZNDCRJ"
#$PWord = ConvertTo-SecureString -String "BCxzAbiAA/g0sngS6qTGTwJZPxtFUE+oM4zwlaWmNQ1b" -AsPlainText -Force
#$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord
#Send-MailMessage -To $To -Subject "Top IO Queries Running on $MyInstance on $today" –From "supportdba@options-it.com" -SmtpServer $MailServer -Body $body -BodyAsHtml
#Send-MailMessage -To $To -Cc $Cc -Subject "SQL Log Backups Copy on $env:computername from $yesterday" –From $From -SmtpServer $SMTPServer -Body ($output | Out-String)
Send-MailMessage -To $To -Cc $Cc -Subject "SQL Log Backups Copy on $env:computername from $yesterday" –From $From -SmtpServer $SMTPServer -Port 587 -Credential $Credential -UseSsl -Body ($output | Out-String)
Get-ChildItem $DirPath | Where-Object {$_.Name -match $MatchFileName -and $_.LastWriteTime -lt $RemoveFiles} | Remove-Item 
}
else
{
   Write-Host "$logBackupPath does not exist"
}