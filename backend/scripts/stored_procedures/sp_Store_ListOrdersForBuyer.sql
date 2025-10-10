/*
  Procedure: dbo.sp_Store_ListOrdersForBuyer
  Purpose : Returns the latest orders for a buyer including escrow state summary.
*/

IF DB_ID() IS NULL
BEGIN
    RAISERROR('Database context is not set. Use the appropriate database before running this script.', 16, 1);
    RETURN;
END
GO

IF OBJECT_ID('dbo.sp_Store_ListOrdersForBuyer', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.sp_Store_ListOrdersForBuyer;
END
GO

CREATE PROCEDURE dbo.sp_Store_ListOrdersForBuyer
    @BuyerAuthUid NVARCHAR(64),
    @Limit INT = 50
AS
BEGIN
    SET NOCOUNT ON;

    IF @BuyerAuthUid IS NULL OR LTRIM(RTRIM(@BuyerAuthUid)) = N''
    BEGIN
        RAISERROR('BuyerAuthUid is required.', 16, 1);
        RETURN;
    END

    IF @Limit IS NULL OR @Limit <= 0 OR @Limit > 200
    BEGIN
        SET @Limit = 50;
    END

    SELECT TOP (@Limit)
        o.OrderPublicId,
        o.ProductId,
        o.BuyerAuthUid,
        o.SellerAuthUid,
        o.VendorId,
        o.SellerType,
        o.ItemPriceGold,
        o.CommissionGold,
        o.TotalGold,
        o.Status,
        o.PaymentStatus,
        o.CreatedAt,
        o.UpdatedAt,
        o.DeliveredAt,
        o.ReleasedAt,
        o.RefundedAt,
        o.DisputedAt,
        o.CompletedAt,
        o.CanceledAt,
        e.EscrowState,
        e.LockedAmountGold,
        e.ReleasedAmountGold,
        e.RefundedAmountGold,
        e.LockedAt,
        e.ReleasedAt,
        e.RefundedAt
    FROM dbo.StoreOrders o WITH (NOLOCK)
    LEFT JOIN dbo.StoreEscrows e WITH (NOLOCK) ON e.OrderId = o.OrderId
    WHERE o.BuyerAuthUid = @BuyerAuthUid
    ORDER BY o.CreatedAt DESC;
END
GO

PRINT 'Procedure dbo.sp_Store_ListOrdersForBuyer created.';
GO
