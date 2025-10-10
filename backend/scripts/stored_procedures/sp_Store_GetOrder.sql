/*
  Stored Procedure: dbo.sp_Store_GetOrder
  Purpose: Retrieves detailed order information including escrow and product data
  
  Usage:
    EXEC dbo.sp_Store_GetOrder
      @OrderPublicId = 'order_abc123',
      @RequestedBy = 'buyer_uid';
*/

IF DB_ID() IS NULL
BEGIN
    RAISERROR('Database context is not set. Use the appropriate database before running this script.', 16, 1);
    RETURN;
END
GO

IF OBJECT_ID('dbo.sp_Store_GetOrder', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.sp_Store_GetOrder;
END
GO

CREATE PROCEDURE dbo.sp_Store_GetOrder
    @OrderId       UNIQUEIDENTIFIER = NULL,
    @OrderPublicId NVARCHAR(64) = NULL,
    @RequestedBy   NVARCHAR(64) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ResolvedOrderId UNIQUEIDENTIFIER;

    IF @OrderId IS NULL AND @OrderPublicId IS NULL
    BEGIN
        RAISERROR('Either @OrderId or @OrderPublicId must be provided.', 16, 1);
        RETURN;
    END

    SELECT TOP (1)
        @ResolvedOrderId = OrderId
    FROM dbo.StoreOrders
    WHERE (OrderId = ISNULL(@OrderId, OrderId) AND @OrderPublicId IS NULL)
       OR (OrderPublicId = @OrderPublicId);

    IF @ResolvedOrderId IS NULL
    BEGIN
        RAISERROR('Order not found.', 16, 1);
        RETURN;
    END

    -- Return order with escrow and product details
    SELECT
        o.OrderId,
        o.OrderPublicId,
        o.BuyerAuthUid,
        o.SellerAuthUid,
        o.VendorId,
        o.ProductId,
        o.Status AS OrderStatus,
        o.PaymentStatus,
        o.ItemPriceGold,
        o.CommissionGold,
        o.TotalGold,
        o.CreatedAt AS OrderCreatedAt,
        o.UpdatedAt AS OrderUpdatedAt,
        e.EscrowId,
        e.EscrowState,
        e.LockedAt AS EscrowLockedAt,
        e.ReleasedAt AS EscrowReleasedAt,
        p.Title AS ProductTitle,
        p.Category AS ProductCategory,
        p.ImageUrls AS ProductImageUrls,
        p.SellerType AS ProductSellerType
    FROM dbo.StoreOrders o
    LEFT JOIN dbo.StoreEscrows e ON o.OrderId = e.OrderId
    LEFT JOIN dbo.StoreProducts p ON o.ProductId = p.ProductId
    WHERE o.OrderId = @ResolvedOrderId;

END
GO

PRINT 'sp_Store_GetOrder created successfully.';
GO
