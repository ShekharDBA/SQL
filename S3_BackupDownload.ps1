    $dbname= @("IVPPOLARISH")
   
    $dt="20260223"
    
    forEach($db in $dbname){
    $fileName=$db+"_PRA_"+$dt+"*.bak"
        Write-Host $fileName
        aws s3 cp "s3://npgl-backups/ivp/prod/db" "B:\Prod_Backup" --recursive --exclude "*" --include "$fileName" --profile backup  # For ProdBackups
        #aws s3 cp "s3://npgl-backups/ivp/uat/db" "B:\Prod_Backup" --recursive --exclude "*" --include "$fileName" --profile backup # For UATBackups
        #aws s3 cp "s3://npgl-backups/ivp/dev/db" "B:\Prod_Backup" --recursive --exclude "*" --include "$fileName" --profile backup # For DevBackups
      }