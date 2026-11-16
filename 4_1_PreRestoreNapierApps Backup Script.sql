USE master
GO

Truncate Table master.dbo.BackupNapierConfig

Select * From master.dbo.BackupNapierConfig

SET IDENTITY_INSERT master.dbo.BackupNapierConfig ON;
Insert Into master.dbo.BackupNapierConfig(
ID,
ApplicationName,
Environment,
GroupName,
KeyName,
KeyValue,
Comments,
Is_Active,
create_dt,
update_dt,
create_user,
update_user
)
Select ID,
ApplicationName,
Environment,
GroupName,
KeyName,
KeyValue,
Comments,
Is_Active,
create_dt,
update_dt,
create_user,
update_user  From NapierApps.[Common].[NapierConfig]
SET IDENTITY_INSERT master.dbo.BackupNapierConfig OFF;
Select * From master.dbo.BackupNapierConfig

