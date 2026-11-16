cls;
Remove-Item -Path "B:\Prod_Backup\*.bak*" -Force
$excel = Import-Excel -Path "B:\OnDemand_DB_Restore\DatabaseList.xlsx"
Invoke-Sqlcmd -Query "Truncate Table ServerMapping" -ServerInstance "10.42.11.10" -Database "master"
Sleep -Seconds 2
foreach ($row in $excel) {
    $query = @"
    INSERT INTO ServerMapping (SourceHost, SourceIP, SourceDatabase, TargetHost, TargetIP, TargetDatabase)
    VALUES ('$($row.SourceHost)', '$($row.SourceIP)', '$($row.SourceDatabase)', 
            '$($row.TargetHost)', '$($row.TargetIP)', '$($row.TargetDatabase)')
"@
    Invoke-Sqlcmd -Query $query -ServerInstance "10.42.11.10" -Database "master"
}

#############################################
Sleep -Seconds 2


$Server="10.42.11.10"
$database="master"
$dt=((Get-Date).AddDays(-0)).ToString("yyyyMMdd")

$Connection = New-Object System.Data.SQLClient.SQLConnection
#"Data Source=$SqlServer;Initial Catalog=$Database; Integrated Security=True;"
$Connection.ConnectionString = "Server = $Server; Database = $Database; Integrated Security = True;"
$Connection.Open()
$Command = New-Object System.Data.SQLClient.SQLCommand
$Command.Connection = $Connection
$Command.CommandText ="Select Distinct [SourceDatabase] From ServerMapping "
#$Command.BeginExecuteNonQuery()
#$Connection.Close() 
$sqlAdapter = new-object System.Data.SqlClient.SqlDataAdapter 
$sqlAdapter.SelectCommand = $Command
$dataSet = new-object System.Data.Dataset
$recordCount = $sqlAdapter.Fill($dataSet) 

#Close SQL Connection
$Connection.Close();

#Get single table from dataset
$data = $dataSet.Tables[0]


foreach($row in $data)

{ 
    $fileName=$row.SourceDatabase+"_"+$dt+"*.bak"
    Write-Host "Download Backup For "$fileName
    aws s3 cp s3://npgl-backups/ivp/prod/db B:\Prod_Backup --recursive --exclude "*" --include "$fileName" 
    $FullFileName=Get-ChildItem -Path "B:\Prod_Backup\$fileName" 
    $SourceDB=$row.SourceDatabase
    Invoke-Sqlcmd -Query "Update [master].[dbo].[ServerMapping] SET BackupPath='$FullFileName' Where SourceDatabase='$SourceDB'" -ServerInstance "10.42.11.10" -Database "master"
    #Write-Host $FullFileName
    #break;
    
}
#Restore database proc
#sp_RestoreOndemand
