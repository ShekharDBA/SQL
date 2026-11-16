#Remove-Item -Path B:\Prod_Backup\*.bak
################################
#Enter the database name and date to download the backup

$Databasename=@("IVPCorpAction","IVPPolaris")  #put the database name with comma seperate
$dt="20250413"  #put the date in yyyyMMdd format

#############################################

ForEach($dbname in $Databasename){

$Server="10.42.11.10"
$database="master"
#$dt=Get-Date -Format("yyyyMMdd")

$Connection = New-Object System.Data.SQLClient.SQLConnection
#"Data Source=$SqlServer;Initial Catalog=$Database; Integrated Security=True;"
$Connection.ConnectionString = "Server = $Server; Database = $Database; Integrated Security = True;"
$Connection.Open()
$Command = New-Object System.Data.SQLClient.SQLCommand
$Command.Connection = $Connection
$Command.CommandText ="SELECT [DatabaseName] FROM [master].[dbo].[WeekendDBRefreshList] where DatabaseName='$dbname'"
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
    $fileName=$row.DatabaseName+"_"+$dt+"*.bak"
    Write-Host "Download Backup For "$fileName
    aws s3 cp s3://npgl-backups/ivp/prod/db B:\Prod_Backup --recursive --exclude "*" --include "$fileName" 
    
}
}
exit