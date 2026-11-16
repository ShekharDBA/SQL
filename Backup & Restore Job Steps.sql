--Step 1
Create Table DBReStoreList(
ID int identity(1,1) primary Key,
DatabaseName NVARCHAR(200),
isRestoreActive bit,
isBackupActive bit
)
Insert Into DBReStoreList(DatabaseName,isRestoreActive,isBackupActive)
Select name ,0,1 From sys.databases Where name not in ('tempdb')

--Step 2
Create Table DBBackupLog(
  ID INT IDENTITY(1,1) Primary Key,
  DatabaseName NVARCHAR(200),
  StartTime DATETIME,
  EndTime DATETIME,
  TotalTimeMinute DECIMAL(18,2),
  S3UploadTime DECIMAL(18,2),
  BackupFileName NVARCHAR(MAX)
)

--Step 3
CREATE TABLE DBRestoreLog (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    DatabaseName NVARCHAR(200),
    StartTime DATETIME,
    EndTime DATETIME,
    TotalTimeMinute FLOAT,
    BackupFileName NVARCHAR(255),
    BackupFileDownloadTime FLOAT,
    RestoreStatus NVARCHAR(50)
)