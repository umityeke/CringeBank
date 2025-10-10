/*
  Procedure: dbo.sp_Store_GetProduct
  Purpose : Returns a single store product by product id.
*/

IF DB_ID() IS NULL
BEGIN
    RAISERROR('Database context is not set. Use the appropriate database before running this script.', 16, 1);
    RETURN;
END
GO

IF OBJECT_ID('dbo.sp_Store_GetProduct', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.sp_Store_GetProduct;
END
GO

CREATE PROCEDURE dbo.sp_Store_GetProduct
    @ProductId NVARCHAR(64)
AS
BEGIN
    SET NOCOUNT ON;

    IF @ProductId IS NULL OR LTRIM(RTRIM(@ProductId)) = N''
    BEGIN
        RAISERROR('ProductId is required.', 16, 1);
        RETURN;
    END

    SELECT TOP (1)
        p.ProductId,
        p.Title,
        p.Description,
        p.PriceGold,
        p.Category,
        p.Condition,
        p.Status,
        p.SellerAuthUid,
        p.VendorId,
        p.SellerType,
        p.ImagesJson,
        p.QrUid,
        p.QrBound,
    p.ReservedBy,
    p.ReservedAt,
    p.SharedEntryId,
    p.SharedByAuthUid,
    p.SharedAt,
    p.CreatedAt,
    p.UpdatedAt
    FROM dbo.StoreProducts p WITH (NOLOCK)
    WHERE p.ProductId = @ProductId;
END
GO

PRINT 'Procedure dbo.sp_Store_GetProduct created.';
GO
