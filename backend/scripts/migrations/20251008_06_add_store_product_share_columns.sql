/*
  Migration: Add share metadata columns to dbo.StoreProducts
  Usage:
    sqlcmd -S <server> -d <database> -U <user> -P <password> -b -i 20251008_06_add_store_product_share_columns.sql
*/

IF DB_ID() IS NULL
BEGIN
    RAISERROR('Database context is not set. Use the appropriate database before running this script.', 16, 1);
    RETURN;
END
GO

IF OBJECT_ID('dbo.StoreProducts', 'U') IS NULL
BEGIN
    RAISERROR('dbo.StoreProducts table is missing. Run the create migration first.', 16, 1);
    RETURN;
END
GO

IF COL_LENGTH('dbo.StoreProducts', 'SharedEntryId') IS NULL
BEGIN
    PRINT 'Adding column SharedEntryId to dbo.StoreProducts';
    ALTER TABLE dbo.StoreProducts
        ADD SharedEntryId NVARCHAR(128) NULL;
END
ELSE
BEGIN
    PRINT 'Column SharedEntryId already exists on dbo.StoreProducts';
END
GO

IF COL_LENGTH('dbo.StoreProducts', 'SharedByAuthUid') IS NULL
BEGIN
    PRINT 'Adding column SharedByAuthUid to dbo.StoreProducts';
    ALTER TABLE dbo.StoreProducts
        ADD SharedByAuthUid NVARCHAR(64) NULL;
END
ELSE
BEGIN
    PRINT 'Column SharedByAuthUid already exists on dbo.StoreProducts';
END
GO

IF COL_LENGTH('dbo.StoreProducts', 'SharedAt') IS NULL
BEGIN
    PRINT 'Adding column SharedAt to dbo.StoreProducts';
    ALTER TABLE dbo.StoreProducts
        ADD SharedAt DATETIME2(3) NULL;
END
ELSE
BEGIN
    PRINT 'Column SharedAt already exists on dbo.StoreProducts';
END
GO

PRINT 'StoreProducts share metadata migration completed successfully.';
GO
