/*
  Migration: Create dbo.StoreEscrows table
  Usage:
    sqlcmd -S <server> -d <database> -U <user> -P <password> -b -i 20251008_04_create_store_escrows.sql
*/

IF DB_ID() IS NULL
BEGIN
    RAISERROR('Database context is not set. Use the appropriate database before running this script.', 16, 1);
    RETURN;
END
GO

IF OBJECT_ID('dbo.StoreEscrows', 'U') IS NULL
BEGIN
    PRINT 'Creating table dbo.StoreEscrows';
    CREATE TABLE dbo.StoreEscrows
    (
        EscrowId UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_StoreEscrows PRIMARY KEY DEFAULT (NEWID()),
        EscrowPublicId NVARCHAR(64) NOT NULL,
        OrderId UNIQUEIDENTIFIER NOT NULL,
        BuyerAuthUid NVARCHAR(64) NOT NULL,
        SellerAuthUid NVARCHAR(64) NULL,
        VendorId NVARCHAR(64) NULL,
    EscrowState NVARCHAR(24) NOT NULL CONSTRAINT DF_StoreEscrows_State DEFAULT ('LOCKED'),
        LockedAmountGold INT NOT NULL,
        ReleasedAmountGold INT NOT NULL DEFAULT (0),
        RefundedAmountGold INT NOT NULL DEFAULT (0),
        LockRequestedAt DATETIME2(3) NULL,
        LockedAt DATETIME2(3) NULL,
        ReleasedAt DATETIME2(3) NULL,
        RefundedAt DATETIME2(3) NULL,
        DisputedAt DATETIME2(3) NULL,
        ResolvedAt DATETIME2(3) NULL,
        NotesJson NVARCHAR(MAX) NULL,
        CreatedAt DATETIME2(3) NOT NULL CONSTRAINT DF_StoreEscrows_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedAt DATETIME2(3) NOT NULL CONSTRAINT DF_StoreEscrows_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        RowVersion ROWVERSION NOT NULL
    );
END
ELSE
BEGIN
    PRINT 'dbo.StoreEscrows already exists. Validating required columns.';
END
GO

DECLARE @missingEscrowColumns TABLE (ColumnName NVARCHAR(128));

INSERT INTO @missingEscrowColumns (ColumnName)
SELECT c.RequiredColumn
FROM (VALUES
    ('EscrowId'),
    ('EscrowPublicId'),
    ('OrderId'),
    ('BuyerAuthUid'),
    ('SellerAuthUid'),
    ('VendorId'),
    ('EscrowState'),
    ('LockedAmountGold'),
    ('ReleasedAmountGold'),
    ('RefundedAmountGold'),
    ('LockRequestedAt'),
    ('LockedAt'),
    ('ReleasedAt'),
    ('RefundedAt'),
    ('DisputedAt'),
    ('ResolvedAt'),
    ('NotesJson'),
    ('CreatedAt'),
    ('UpdatedAt'),
    ('RowVersion')
) AS c(RequiredColumn)
WHERE COL_LENGTH('dbo.StoreEscrows', c.RequiredColumn) IS NULL;

IF EXISTS (SELECT 1 FROM @missingEscrowColumns)
BEGIN
    DECLARE @escrowColumns NVARCHAR(MAX);
    SELECT @escrowColumns = STRING_AGG(ColumnName, ', ') FROM @missingEscrowColumns;
    RAISERROR('dbo.StoreEscrows table is missing required columns: %s', 16, 1, @escrowColumns);
    RETURN;
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.StoreEscrows')
      AND name = 'UX_StoreEscrows_EscrowPublicId'
)
BEGIN
    PRINT 'Creating unique index UX_StoreEscrows_EscrowPublicId';
    CREATE UNIQUE INDEX UX_StoreEscrows_EscrowPublicId ON dbo.StoreEscrows (EscrowPublicId);
END
ELSE
BEGIN
    PRINT 'Unique index UX_StoreEscrows_EscrowPublicId already exists.';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.StoreEscrows')
      AND name = 'IX_StoreEscrows_Order'
)
BEGIN
    PRINT 'Creating nonclustered index IX_StoreEscrows_Order';
    CREATE NONCLUSTERED INDEX IX_StoreEscrows_Order ON dbo.StoreEscrows (OrderId)
        INCLUDE (EscrowState, LockedAmountGold, ReleasedAmountGold, RefundedAmountGold, UpdatedAt);
END
ELSE
BEGIN
    PRINT 'Index IX_StoreEscrows_Order already exists.';
END
GO

PRINT 'dbo.StoreEscrows migration completed successfully.';
GO
