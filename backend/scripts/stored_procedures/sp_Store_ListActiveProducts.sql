/*
  Procedure: dbo.sp_Store_ListActiveProducts
  Purpose : Returns the latest active or reserved store products with optional filtering.
*/

IF DB_ID() IS NULL
BEGIN
    RAISERROR('Database context is not set. Use the appropriate database before running this script.', 16, 1);
    RETURN;
END
GO

IF OBJECT_ID('dbo.sp_Store_ListActiveProducts', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.sp_Store_ListActiveProducts;
END
GO

CREATE PROCEDURE dbo.sp_Store_ListActiveProducts
    @SellerType NVARCHAR(16) = NULL,
    @Category NVARCHAR(64) = NULL,
    @Status NVARCHAR(32) = NULL,
    @Limit INT = 100
AS
BEGIN
    SET NOCOUNT ON;

    IF @Limit IS NULL OR @Limit <= 0 OR @Limit > 500
    BEGIN
        SET @Limit = 100;
    END

    SELECT TOP (@Limit)
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
    WHERE ((@Status IS NULL AND p.Status IN (N'ACTIVE', N'RESERVED')) OR (@Status IS NOT NULL AND p.Status = @Status))
      AND (@SellerType IS NULL OR p.SellerType = @SellerType)
      AND (@Category IS NULL OR p.Category = @Category)
    ORDER BY p.CreatedAt DESC;
END
GO

PRINT 'Procedure dbo.sp_Store_ListActiveProducts created.';
GO
