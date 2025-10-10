/*
  Migration: Create dbo.StoreWalletLedger table for wallet adjustments.
*/

IF DB_ID() IS NULL
BEGIN
    RAISERROR('Database context is not set. Use the appropriate database before running this script.', 16, 1);
    RETURN;
END
GO

IF OBJECT_ID('dbo.StoreWalletLedger', 'U') IS NULL
BEGIN
    PRINT 'Creating table dbo.StoreWalletLedger';
    CREATE TABLE dbo.StoreWalletLedger
    (
        LedgerId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_StoreWalletLedger PRIMARY KEY,
        WalletId INT NOT NULL,
        TargetAuthUid NVARCHAR(64) NOT NULL,
        ActorAuthUid NVARCHAR(64) NOT NULL,
        AmountDelta INT NOT NULL,
        Reason NVARCHAR(256) NULL,
        MetadataJson NVARCHAR(1024) NULL,
        CreatedAt DATETIME2(3) NOT NULL CONSTRAINT DF_StoreWalletLedger_CreatedAt DEFAULT (SYSUTCDATETIME())
    );
END
ELSE
BEGIN
    PRINT 'dbo.StoreWalletLedger already exists. Validating required columns.';
END
GO

DECLARE @missingColumns TABLE (ColumnName NVARCHAR(128));

INSERT INTO @missingColumns (ColumnName)
SELECT c.RequiredColumn
FROM (VALUES
    ('LedgerId'),
    ('WalletId'),
    ('TargetAuthUid'),
    ('ActorAuthUid'),
    ('AmountDelta'),
    ('Reason'),
    ('MetadataJson'),
    ('CreatedAt')
) AS c(RequiredColumn)
WHERE COL_LENGTH('dbo.StoreWalletLedger', c.RequiredColumn) IS NULL;

IF EXISTS (SELECT 1 FROM @missingColumns)
BEGIN
    DECLARE @columns NVARCHAR(MAX);
    SELECT @columns = STRING_AGG(ColumnName, ', ') FROM @missingColumns;
    RAISERROR('dbo.StoreWalletLedger table is missing required columns: %s', 16, 1, @columns);
    RETURN;
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.foreign_keys
    WHERE parent_object_id = OBJECT_ID('dbo.StoreWalletLedger')
      AND name = 'FK_StoreWalletLedger_Wallets'
)
BEGIN
    PRINT 'Creating foreign key FK_StoreWalletLedger_Wallets';
    ALTER TABLE dbo.StoreWalletLedger
        ADD CONSTRAINT FK_StoreWalletLedger_Wallets
            FOREIGN KEY (WalletId)
            REFERENCES dbo.StoreWallets (WalletId)
            ON DELETE CASCADE;
END
ELSE
BEGIN
    PRINT 'Foreign key FK_StoreWalletLedger_Wallets already exists.';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.StoreWalletLedger')
      AND name = 'IX_StoreWalletLedger_TargetAuthUid_CreatedAt'
)
BEGIN
    PRINT 'Creating index IX_StoreWalletLedger_TargetAuthUid_CreatedAt';
    CREATE INDEX IX_StoreWalletLedger_TargetAuthUid_CreatedAt
        ON dbo.StoreWalletLedger (TargetAuthUid, CreatedAt DESC);
END
ELSE
BEGIN
    PRINT 'Index IX_StoreWalletLedger_TargetAuthUid_CreatedAt already exists.';
END
GO

PRINT 'dbo.StoreWalletLedger migration completed successfully.';
GO
