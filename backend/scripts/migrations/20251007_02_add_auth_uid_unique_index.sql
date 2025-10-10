/*
  Migration: Add unique index on dbo.Users.AuthUid
  Usage:
    sqlcmd -S <server> -d <database> -U <user> -P <password> -b -i 20251007_02_add_auth_uid_unique_index.sql
*/

IF DB_ID() IS NULL
BEGIN
    RAISERROR('Database context is not set. Use the appropriate database before running this script.', 16, 1);
    RETURN;
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.tables t
    WHERE t.name = 'Users'
      AND SCHEMA_NAME(t.schema_id) = 'dbo'
)
BEGIN
    RAISERROR('dbo.Users table does not exist. Create the Users table before applying this migration.', 16, 1);
    RETURN;
END
GO

IF COL_LENGTH('dbo.Users', 'AuthUid') IS NULL
BEGIN
    RAISERROR('dbo.Users.AuthUid column is missing. Add the column before applying this migration.', 16, 1);
    RETURN;
END
GO

DECLARE @existingIndex NVARCHAR(128);
SELECT @existingIndex = ind.name
FROM sys.indexes ind
JOIN sys.index_columns ic ON ind.object_id = ic.object_id AND ind.index_id = ic.index_id
JOIN sys.columns col ON ic.object_id = col.object_id AND ic.column_id = col.column_id
WHERE ind.object_id = OBJECT_ID('dbo.Users')
  AND col.name = 'AuthUid'
  AND ind.is_unique = 1;

IF @existingIndex IS NOT NULL
BEGIN
    PRINT 'Unique index on dbo.Users.AuthUid already exists: ' + @existingIndex;
END
ELSE
BEGIN
    PRINT 'Creating unique index IX_Users_AuthUid on dbo.Users(AuthUid)';
    CREATE UNIQUE INDEX IX_Users_AuthUid
        ON dbo.Users (AuthUid)
        WHERE AuthUid IS NOT NULL;
END;
GO

PRINT 'AuthUid unique index migration completed successfully.';
GO
