/*
  Migration: Create dbo.StoreProducts table
  Usage:
    sqlcmd -S <server> -d <database> -U <user> -P <password> -b -i 20251008_02_create_store_products.sql
*/

IF DB_ID() IS NULL
BEGIN
    RAISERROR('Database context is not set. Use the appropriate database before running this script.', 16, 1);
    RETURN;
END
GO

IF OBJECT_ID('dbo.StoreProducts', 'U') IS NULL
BEGIN
    PRINT 'Creating table dbo.StoreProducts';
    CREATE TABLE dbo.StoreProducts
    (
        ProductId NVARCHAR(64) NOT NULL CONSTRAINT PK_StoreProducts PRIMARY KEY,
        Title NVARCHAR(200) NOT NULL,
        Description NVARCHAR(MAX) NULL,
        PriceGold INT NOT NULL,
        Category NVARCHAR(64) NULL,
        Condition NVARCHAR(32) NULL,
        Status NVARCHAR(32) NOT NULL CONSTRAINT DF_StoreProducts_Status DEFAULT ('ACTIVE'),
        SellerAuthUid NVARCHAR(64) NULL,
        VendorId NVARCHAR(64) NULL,
        SellerType NVARCHAR(16) NOT NULL CONSTRAINT DF_StoreProducts_SellerType DEFAULT ('P2P'),
        ImagesJson NVARCHAR(MAX) NULL,
        QrUid NVARCHAR(64) NULL,
        QrBound BIT NOT NULL CONSTRAINT DF_StoreProducts_QrBound DEFAULT (0),
        ReservedBy NVARCHAR(64) NULL,
        ReservedAt DATETIME2(3) NULL,
        CreatedAt DATETIME2(3) NOT NULL CONSTRAINT DF_StoreProducts_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedAt DATETIME2(3) NOT NULL CONSTRAINT DF_StoreProducts_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        RowVersion ROWVERSION NOT NULL
    );
END
ELSE
BEGIN
    PRINT 'dbo.StoreProducts already exists. Validating required columns.';
END
GO

DECLARE @missingProductColumns TABLE (ColumnName NVARCHAR(128));

INSERT INTO @missingProductColumns (ColumnName)
SELECT c.RequiredColumn
FROM (VALUES
    ('ProductId'),
    ('Title'),
    ('Description'),
    ('PriceGold'),
    ('Category'),
    ('Condition'),
    ('Status'),
    ('SellerAuthUid'),
    ('VendorId'),
    ('SellerType'),
    ('ImagesJson'),
    ('QrUid'),
    ('QrBound'),
    ('ReservedBy'),
    ('ReservedAt'),
    ('CreatedAt'),
    ('UpdatedAt'),
    ('RowVersion')
) AS c(RequiredColumn)
WHERE COL_LENGTH('dbo.StoreProducts', c.RequiredColumn) IS NULL;

IF EXISTS (SELECT 1 FROM @missingProductColumns)
BEGIN
    DECLARE @productColumns NVARCHAR(MAX);
    SELECT @productColumns = STRING_AGG(ColumnName, ', ') FROM @missingProductColumns;
    RAISERROR('dbo.StoreProducts table is missing required columns: %s', 16, 1, @productColumns);
    RETURN;
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.StoreProducts')
      AND name = 'IX_StoreProducts_StatusSellerType'
)
BEGIN
    PRINT 'Creating nonclustered index IX_StoreProducts_StatusSellerType';
    CREATE NONCLUSTERED INDEX IX_StoreProducts_StatusSellerType
        ON dbo.StoreProducts (Status, SellerType)
        INCLUDE (Category, PriceGold, UpdatedAt);
END
ELSE
BEGIN
    PRINT 'Index IX_StoreProducts_StatusSellerType already exists.';
END
GO

PRINT 'dbo.StoreProducts migration completed successfully.';
GO
