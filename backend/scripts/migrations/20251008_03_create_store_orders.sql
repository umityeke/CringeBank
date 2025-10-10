/*
  Migration: Create dbo.StoreOrders table
  Usage:
    sqlcmd -S <server> -d <database> -U <user> -P <password> -b -i 20251008_03_create_store_orders.sql
*/

IF DB_ID() IS NULL
BEGIN
    RAISERROR('Database context is not set. Use the appropriate database before running this script.', 16, 1);
    RETURN;
END
GO

IF OBJECT_ID('dbo.StoreOrders', 'U') IS NULL
BEGIN
    PRINT 'Creating table dbo.StoreOrders';
    CREATE TABLE dbo.StoreOrders
    (
        OrderId UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_StoreOrders PRIMARY KEY DEFAULT (NEWID()),
        OrderPublicId NVARCHAR(64) NOT NULL,
        ProductId NVARCHAR(64) NOT NULL,
        BuyerAuthUid NVARCHAR(64) NOT NULL,
        SellerAuthUid NVARCHAR(64) NULL,
        VendorId NVARCHAR(64) NULL,
        SellerType NVARCHAR(16) NOT NULL,
        ItemPriceGold INT NOT NULL,
        CommissionGold INT NOT NULL,
        TotalGold INT NOT NULL,
    Status NVARCHAR(24) NOT NULL CONSTRAINT DF_StoreOrders_Status DEFAULT ('PENDING'),
    PaymentStatus NVARCHAR(24) NOT NULL CONSTRAINT DF_StoreOrders_PaymentStatus DEFAULT ('AWAITING_ESCROW'),
        TimelineJson NVARCHAR(MAX) NULL,
        CreatedAt DATETIME2(3) NOT NULL CONSTRAINT DF_StoreOrders_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedAt DATETIME2(3) NOT NULL CONSTRAINT DF_StoreOrders_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        DeliveredAt DATETIME2(3) NULL,
        ReleasedAt DATETIME2(3) NULL,
        RefundedAt DATETIME2(3) NULL,
        DisputedAt DATETIME2(3) NULL,
        CompletedAt DATETIME2(3) NULL,
        CanceledAt DATETIME2(3) NULL,
        RowVersion ROWVERSION NOT NULL
    );
END
ELSE
BEGIN
    PRINT 'dbo.StoreOrders already exists. Validating required columns.';
END
GO

DECLARE @missingOrderColumns TABLE (ColumnName NVARCHAR(128));

INSERT INTO @missingOrderColumns (ColumnName)
SELECT c.RequiredColumn
FROM (VALUES
    ('OrderId'),
    ('OrderPublicId'),
    ('ProductId'),
    ('BuyerAuthUid'),
    ('SellerAuthUid'),
    ('VendorId'),
    ('SellerType'),
    ('ItemPriceGold'),
    ('CommissionGold'),
    ('TotalGold'),
    ('Status'),
    ('PaymentStatus'),
    ('TimelineJson'),
    ('CreatedAt'),
    ('UpdatedAt'),
    ('DeliveredAt'),
    ('ReleasedAt'),
    ('RefundedAt'),
    ('DisputedAt'),
    ('CompletedAt'),
    ('CanceledAt'),
    ('RowVersion')
) AS c(RequiredColumn)
WHERE COL_LENGTH('dbo.StoreOrders', c.RequiredColumn) IS NULL;

IF EXISTS (SELECT 1 FROM @missingOrderColumns)
BEGIN
    DECLARE @orderColumns NVARCHAR(MAX);
    SELECT @orderColumns = STRING_AGG(ColumnName, ', ') FROM @missingOrderColumns;
    RAISERROR('dbo.StoreOrders table is missing required columns: %s', 16, 1, @orderColumns);
    RETURN;
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.StoreOrders')
      AND name = 'UX_StoreOrders_OrderPublicId'
)
BEGIN
    PRINT 'Creating unique index UX_StoreOrders_OrderPublicId';
    CREATE UNIQUE INDEX UX_StoreOrders_OrderPublicId ON dbo.StoreOrders (OrderPublicId);
END
ELSE
BEGIN
    PRINT 'Unique index UX_StoreOrders_OrderPublicId already exists.';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.StoreOrders')
      AND name = 'IX_StoreOrders_Buyer'
)
BEGIN
    PRINT 'Creating nonclustered index IX_StoreOrders_Buyer';
    CREATE NONCLUSTERED INDEX IX_StoreOrders_Buyer ON dbo.StoreOrders (BuyerAuthUid, Status)
        INCLUDE (CreatedAt, TotalGold, PaymentStatus);
END
ELSE
BEGIN
    PRINT 'Index IX_StoreOrders_Buyer already exists.';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.StoreOrders')
      AND name = 'IX_StoreOrders_Seller'
)
BEGIN
    PRINT 'Creating nonclustered index IX_StoreOrders_Seller';
    CREATE NONCLUSTERED INDEX IX_StoreOrders_Seller ON dbo.StoreOrders (SellerAuthUid, Status)
        INCLUDE (CreatedAt, TotalGold, PaymentStatus);
END
ELSE
BEGIN
    PRINT 'Index IX_StoreOrders_Seller already exists.';
END
GO

PRINT 'dbo.StoreOrders migration completed successfully.';
GO
