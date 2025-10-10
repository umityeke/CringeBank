/*
  Migration: Create dbo.Users table
  Usage:
    sqlcmd -S <server> -d <database> -U <user> -P <password> -b -i 20251007_01_create_users_table.sql
*/

IF DB_ID() IS NULL
BEGIN
    RAISERROR('Database context is not set. Use the appropriate database before running this script.', 16, 1);
    RETURN;
END
GO

IF OBJECT_ID('dbo.Users', 'U') IS NULL
BEGIN
    PRINT 'Creating table dbo.Users';
    CREATE TABLE dbo.Users
    (
        Id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Users PRIMARY KEY,
        AuthUid NVARCHAR(64) NOT NULL,
        Email NVARCHAR(256) NULL,
        Username NVARCHAR(64) NOT NULL,
        DisplayName NVARCHAR(128) NULL,
        CreatedAt DATETIME2(3) NOT NULL CONSTRAINT DF_Users_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedAt DATETIME2(3) NOT NULL CONSTRAINT DF_Users_UpdatedAt DEFAULT (SYSUTCDATETIME())
    );
END
ELSE
BEGIN
    PRINT 'dbo.Users table already exists. Validating required columns.';
END
GO

DECLARE @missingColumns TABLE (ColumnName NVARCHAR(128));

INSERT INTO @missingColumns (ColumnName)
SELECT c.RequiredColumn
FROM (VALUES
    ('Id'),
    ('AuthUid'),
    ('Email'),
    ('Username'),
    ('DisplayName'),
    ('CreatedAt'),
    ('UpdatedAt')
) AS c(RequiredColumn)
WHERE COL_LENGTH('dbo.Users', c.RequiredColumn) IS NULL;

IF EXISTS (SELECT 1 FROM @missingColumns)
BEGIN
    DECLARE @columns NVARCHAR(MAX);
    SELECT @columns = STRING_AGG(ColumnName, ', ') FROM @missingColumns;
    RAISERROR('dbo.Users table is missing required columns: %s', 16, 1, @columns);
    RETURN;
END
GO

PRINT 'dbo.Users table migration completed successfully.';
GO
