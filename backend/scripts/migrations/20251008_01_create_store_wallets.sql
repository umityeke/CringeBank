/*
  Migration: Create dbo.StoreWallets table
  Usage:
    sqlcmd -S <server> -d <database> -U <user> -P <password> -b -i 20251008_01_create_store_wallets.sql
*/

IF DB_ID() IS NULL
BEGIN
    RAISERROR('Database context is not set. Use the appropriate database before running this script.', 16, 1);
    RETURN;
END
GO

IF OBJECT_ID('dbo.StoreWallets', 'U') IS NULL
BEGIN
    PRINT 'Creating table dbo.StoreWallets';
    CREATE TABLE dbo.StoreWallets
    (
        WalletId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_StoreWallets PRIMARY KEY,
        AuthUid NVARCHAR(64) NOT NULL,
        GoldBalance INT NOT NULL CONSTRAINT DF_StoreWallets_GoldBalance DEFAULT (0),
        PendingGold INT NOT NULL CONSTRAINT DF_StoreWallets_PendingGold DEFAULT (0),
        CreatedAt DATETIME2(3) NOT NULL CONSTRAINT DF_StoreWallets_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedAt DATETIME2(3) NOT NULL CONSTRAINT DF_StoreWallets_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        LastLedgerEntryId NVARCHAR(64) NULL,
        RowVersion ROWVERSION NOT NULL
    );
END
ELSE
BEGIN
    PRINT 'dbo.StoreWallets already exists. Validating required columns.';
END
GO

DECLARE @missingColumns TABLE (ColumnName NVARCHAR(128));

INSERT INTO @missingColumns (ColumnName)
SELECT c.RequiredColumn
FROM (VALUES
    ('WalletId'),
    ('AuthUid'),
    ('GoldBalance'),
    ('PendingGold'),
    ('CreatedAt'),
    ('UpdatedAt'),
    ('LastLedgerEntryId'),
    ('RowVersion')
) AS c(RequiredColumn)
WHERE COL_LENGTH('dbo.StoreWallets', c.RequiredColumn) IS NULL;

IF EXISTS (SELECT 1 FROM @missingColumns)
BEGIN
    DECLARE @columns NVARCHAR(MAX);
    SELECT @columns = STRING_AGG(ColumnName, ', ') FROM @missingColumns;
    RAISERROR('dbo.StoreWallets table is missing required columns: %s', 16, 1, @columns);
    RETURN;
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.StoreWallets')
      AND name = 'UX_StoreWallets_AuthUid'
)
BEGIN
    PRINT 'Creating unique index UX_StoreWallets_AuthUid';
    CREATE UNIQUE INDEX UX_StoreWallets_AuthUid ON dbo.StoreWallets (AuthUid);
END
ELSE
BEGIN
    PRINT 'Unique index UX_StoreWallets_AuthUid already exists.';
END
GO

PRINT 'dbo.StoreWallets migration completed successfully.';
GO
