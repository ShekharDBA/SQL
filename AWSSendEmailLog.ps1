 $yesterday = Get-Date (get-date).AddDays(-1) -format "MM-dd-yyyy"
$ydate = Get-Date (get-date).AddDays(-1) -format "MMddyyyy"
$environment = "uat"
$DirPath = "D:\Scripts\logs"
$logBackupFile = "ivp${environment}_log_backups_$ydate.txt"
$logBackupPath = "${DirPath}\${logBackupFile}"
$Threshold = "-2"
$MatchFileName = "ivp${environment}_log_backups"
$RemoveFiles = (Get-Date).AddDays($Threshold) 


#$To = 'napiertechsupportoda@napierparkglobal.com'
#$MailServer = 'extrlus.options-it.com'

$To = "napiertechsupportoda@napierparkglobal.com"
$Cc = "deepak.jha@napierparkglobal.com"
$From = "aws-npg-sql-uat-ses-user@napierparkglobal.com"
$SMTPServer = "email-smtp.us-east-1.amazonaws.com"

if (Test-Path -Path $logBackupPath)
{
   $output = get-content $logBackupPath | Select-String upload
   #Send-MailMessage -To $To -Subject "SQL Log Backups Copy on $env:computername from $yesterday" -From "supportdba@options-it.com" -SmtpServer $MailServer -Body ($output | Out-String)
   $User = "AKIA2PHX6VSJIJ2EZ6ES"
   $PWord = ConvertTo-SecureString -String "BPLXU6gbV/iU+AJNfzRFWaSwI9lf7LFfnQbPZNCC9XB7" -AsPlainText -Force
   $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord
   Send-MailMessage -To $To -Subject "SQL Log Backups Copy on $env:computername from $yesterday" –From $From -SmtpServer $SMTPServer -Port 587 -Credential $Credential -UseSsl -Body ($output | Out-String)
    
   Get-ChildItem $DirPath | Where-Object {$_.Name -match $MatchFileName -and $_.LastWriteTime -lt $RemoveFiles} | Remove-Item 
}
else
{
   Write-Host "$logBackupPath does not exist"
} 