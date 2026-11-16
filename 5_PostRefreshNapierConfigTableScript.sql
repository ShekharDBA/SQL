USE IVPUatAudit
GO
IF(SELECT COUNT(*) FROM [master].[dbo].[WeekendDBRefreshList] where isRefreshActive=1 and DatabaseName='NapierApps')>0
BEGIN
Truncate Table NapierApps.[Common].[NapierConfig];

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
update_user  From IVPUatAudit.dbo.Backup_NapierConfig
SET IDENTITY_INSERT NapierApps.[Common].[NapierConfig] OFF;
Select * From NapierApps.[Common].[NapierConfig]
END
ELSE
BEGIN
Print('Napier Apps DB not enable to Weekend Refresh !!')
END