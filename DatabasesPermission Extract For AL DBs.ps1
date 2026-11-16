$ServerName = "NPGDEV-IVPSDB03"
 
$TimeStamp = Get-Date -Format "yyyyMMddHHmmss"
$OutputFile = "B:\Databases Permissions Backup\All_Database_Permissions_$TimeStamp.sql"
 

# Remove existing file
if (Test-Path $OutputFile)
{
    Remove-Item $OutputFile -Force
}

# Get all online user databases
$Databases = Invoke-Sqlcmd `
    -ServerInstance $ServerName `
    -Database master `
    -Query "
        SELECT name
        FROM sys.databases
        WHERE database_id = 4
          AND state_desc = 'ONLINE'
        ORDER BY name;
    "

foreach ($DB in $Databases)
{
    $DBName = $DB.name

    Write-Host "Processing Database: $DBName"

    $Query = @"
SET NOCOUNT ON;

IF OBJECT_ID('tempdb..#PermissionScript') IS NOT NULL
    DROP TABLE #PermissionScript;

CREATE TABLE #PermissionScript
(
      ID INT IDENTITY(1,1)
    , ScriptLine NVARCHAR(MAX)
);

------------------------------------------------------------
-- DATABASE CONTEXT
------------------------------------------------------------

INSERT INTO #PermissionScript
VALUES ('USE [$DBName];');

INSERT INTO #PermissionScript
VALUES ('GO');

------------------------------------------------------------
-- DATABASE USERS
------------------------------------------------------------

INSERT INTO #PermissionScript
SELECT
'IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = '''
+ dp.name COLLATE DATABASE_DEFAULT
+ ''')
BEGIN
    CREATE USER '
+ QUOTENAME(dp.name) COLLATE DATABASE_DEFAULT
+ CASE
    WHEN dp.type IN ('S','U','G')
         AND dp.sid IS NOT NULL
    THEN ' FOR LOGIN ' + QUOTENAME(dp.name)
    ELSE ''
  END
+ ';
END;'
FROM sys.database_principals dp
WHERE dp.type IN ('S','U','G')
AND dp.name NOT IN ('dbo','guest','sys','INFORMATION_SCHEMA');

------------------------------------------------------------
-- DATABASE ROLES
------------------------------------------------------------

INSERT INTO #PermissionScript
SELECT
'IF DATABASE_PRINCIPAL_ID('''
+ name COLLATE DATABASE_DEFAULT
+ ''') IS NULL
CREATE ROLE '
+ QUOTENAME(name)
+ ';'
FROM sys.database_principals
WHERE type='R'
AND is_fixed_role=0
AND name <> 'public';

------------------------------------------------------------
-- ROLE MEMBERSHIP
------------------------------------------------------------

INSERT INTO #PermissionScript
SELECT
'EXEC sp_addrolemember @rolename = '
+ QUOTENAME(USER_NAME(rm.role_principal_id),'''')
+ ', @membername = '
+ QUOTENAME(USER_NAME(rm.member_principal_id),'''')
+ ';'
FROM sys.database_role_members rm
WHERE USER_NAME(rm.member_principal_id) IS NOT NULL;

------------------------------------------------------------
-- SCHEMA LEVEL PERMISSIONS
------------------------------------------------------------

INSERT INTO #PermissionScript
SELECT
CASE
    WHEN p.state <> 'W'
        THEN p.state_desc COLLATE DATABASE_DEFAULT
    ELSE 'GRANT'
END
+ ' '
+ p.permission_name COLLATE DATABASE_DEFAULT
+ ' ON SCHEMA::'
+ QUOTENAME(s.name)
+ ' TO '
+ QUOTENAME(dp.name)
+ CASE
    WHEN p.state = 'W'
        THEN ' WITH GRANT OPTION'
    ELSE ''
  END
+ ';'
FROM sys.database_permissions p
JOIN sys.schemas s
    ON p.major_id = s.schema_id
JOIN sys.database_principals dp
    ON p.grantee_principal_id = dp.principal_id
WHERE p.class = 3
AND dp.principal_id > 4;

------------------------------------------------------------
-- OBJECT LEVEL PERMISSIONS
------------------------------------------------------------

INSERT INTO #PermissionScript
SELECT
CASE
    WHEN p.state <> 'W'
        THEN p.state_desc COLLATE DATABASE_DEFAULT
    ELSE 'GRANT'
END
+ ' '
+ p.permission_name COLLATE DATABASE_DEFAULT
+ ' ON '
+ QUOTENAME(OBJECT_SCHEMA_NAME(p.major_id))
+ '.'
+ QUOTENAME(OBJECT_NAME(p.major_id))
+ ' TO '
+ QUOTENAME(dp.name)
+ CASE
    WHEN p.state = 'W'
        THEN ' WITH GRANT OPTION'
    ELSE ''
  END
+ ';'
FROM sys.database_permissions p
JOIN sys.database_principals dp
    ON p.grantee_principal_id = dp.principal_id
WHERE p.class = 1;

------------------------------------------------------------
-- DATABASE LEVEL PERMISSIONS
------------------------------------------------------------

INSERT INTO #PermissionScript
SELECT
CASE
    WHEN p.state <> 'W'
        THEN p.state_desc COLLATE DATABASE_DEFAULT
    ELSE 'GRANT'
END
+ ' '
+ p.permission_name COLLATE DATABASE_DEFAULT
+ ' TO '
+ QUOTENAME(dp.name)
+ CASE
    WHEN p.state = 'W'
        THEN ' WITH GRANT OPTION'
    ELSE ''
  END
+ ';'
FROM sys.database_permissions p
JOIN sys.database_principals dp
    ON p.grantee_principal_id = dp.principal_id
WHERE p.major_id = 0
AND dp.principal_id > 4;

SELECT ScriptLine
FROM #PermissionScript
ORDER BY ID;
"@

    Invoke-Sqlcmd `
        -ServerInstance $ServerName `
        -Database $DBName `
        -Query $Query |
    Select-Object -ExpandProperty ScriptLine |
    Out-File $OutputFile -Append -Encoding UTF8
}

Write-Host ""
Write-Host "Completed Successfully"
Write-Host "Output File: $OutputFile"

notepad.exe $OutputFile