USE master
GO

Truncate Table NapierApps.[Common].[NapierConfig];
GO
Select * From NapierApps.[Common].[NapierConfig];

SET IDENTITY_INSERT NapierApps.[Common].[NapierConfig] ON;
Insert Into NapierApps.[Common].[NapierConfig](
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
update_user  From master.dbo.BackupNapierConfig
SET IDENTITY_INSERT NapierApps.[Common].[NapierConfig] OFF;
Select * From NapierApps.[Common].[NapierConfig]
