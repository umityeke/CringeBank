/*
  Stored Procedure: dbo.sp_Store_RefundOrder
  Purpose: Refunds an order by unlocking escrow and returning funds to buyer wallet
  
  Usage:
    DECLARE @RefundPublicId NVARCHAR(64);
    EXEC dbo.sp_Store_RefundOrder
      @OrderPublicId = 'order_abc123',
      @ActorAuthUid = 'seller_uid',
      @RefundReason = 'Product unavailable',
      @IsSystemOverride = 0,
      @RefundPublicId = @RefundPublicId OUTPUT;
    
    SELECT @RefundPublicId AS RefundId;
*/

IF DB_ID() IS NULL
BEGIN
    RAISERROR('Database context is not set. Use the appropriate database before running this script.', 16, 1);
    RETURN;
END
GO

IF OBJECT_ID('dbo.sp_Store_RefundOrder', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.sp_Store_RefundOrder;
END
GO

CREATE PROCEDURE dbo.sp_Store_RefundOrder
    @OrderId          UNIQUEIDENTIFIER = NULL,
    @OrderPublicId    NVARCHAR(64) = NULL,
    @ActorAuthUid     NVARCHAR(64),
    @RefundReason     NVARCHAR(512) = NULL,
    @IsSystemOverride BIT = 0,
    @RefundPublicId   NVARCHAR(64) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @now DATETIME2(3) = SYSUTCDATETIME(),
        @ResolvedOrderId UNIQUEIDENTIFIER,
        @BuyerAuthUid NVARCHAR(64),
        @SellerAuthUid NVARCHAR(64),
        @OrderStatus NVARCHAR(24),
        @PaymentStatus NVARCHAR(24),
        @OrderTotal INT,
        @EscrowState NVARCHAR(24),
        @BuyerWalletId INT,
        @BuyerPending INT,
        @ProductId NVARCHAR(64);

    IF @OrderId IS NULL AND @OrderPublicId IS NULL
    BEGIN
        RAISERROR('Either @OrderId or @OrderPublicId must be provided.', 16, 1);
        RETURN;
    END

    IF @ActorAuthUid IS NULL OR LTRIM(RTRIM(@ActorAuthUid)) = N''
    BEGIN
        RAISERROR('Actor auth UID is required.', 16, 1);
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Load order with lock
        SELECT TOP (1)
            @ResolvedOrderId = OrderId,
            @BuyerAuthUid = BuyerAuthUid,
            @SellerAuthUid = SellerAuthUid,
            @OrderStatus = Status,
            @PaymentStatus = PaymentStatus,
            @OrderTotal = TotalGold,
            @ProductId = ProductId
        FROM dbo.StoreOrders WITH (UPDLOCK, HOLDLOCK)
        WHERE (OrderId = ISNULL(@OrderId, OrderId) AND @OrderPublicId IS NULL)
           OR (OrderPublicId = @OrderPublicId);

        IF @ResolvedOrderId IS NULL
        BEGIN
            RAISERROR('Order not found.', 16, 1);
        END

        -- Only seller or system can refund
        IF @ActorAuthUid <> @SellerAuthUid AND @IsSystemOverride = 0
        BEGIN
            RAISERROR('Only seller or system can initiate refund.', 16, 1);
        END

        -- Check order status
        IF @OrderStatus NOT IN (N'PENDING', N'AWAITING_SHIPMENT') AND @IsSystemOverride = 0
        BEGIN
            RAISERROR('Order cannot be refunded. Current status: %s', 16, 1, @OrderStatus);
        END

        IF @PaymentStatus <> N'ESCROW_LOCKED' AND @IsSystemOverride = 0
        BEGIN
            RAISERROR('Payment status does not allow refund. Current status: %s', 16, 1, @PaymentStatus);
        END

        -- Check escrow state
        SELECT TOP (1)
            @EscrowState = EscrowState
        FROM dbo.StoreEscrows WITH (UPDLOCK, HOLDLOCK)
        WHERE OrderId = @ResolvedOrderId;

        IF @EscrowState IS NULL
        BEGIN
            RAISERROR('Escrow record not found.', 16, 1);
        END

        IF @EscrowState <> N'LOCKED' AND @IsSystemOverride = 0
        BEGIN
            RAISERROR('Escrow is not locked. Current state: %s', 16, 1, @EscrowState);
        END

        -- Update escrow to REFUNDED
        UPDATE dbo.StoreEscrows
        SET EscrowState = N'REFUNDED',
            ReleasedAt = @now,
            UpdatedAt = @now
        WHERE OrderId = @ResolvedOrderId;

        -- Return funds to buyer: pending → balance
        SELECT TOP (1)
            @BuyerWalletId = WalletId,
            @BuyerPending = PendingGold
        FROM dbo.StoreWallets WITH (UPDLOCK, HOLDLOCK)
        WHERE AuthUid = @BuyerAuthUid;

        IF @BuyerWalletId IS NULL
        BEGIN
            RAISERROR('Buyer wallet not found.', 16, 1);
        END

        IF ISNULL(@BuyerPending, 0) < @OrderTotal AND @IsSystemOverride = 0
        BEGIN
            RAISERROR('Buyer pending balance insufficient for refund.', 16, 1);
        END

        UPDATE dbo.StoreWallets
        SET GoldBalance = GoldBalance + @OrderTotal,
            PendingGold = CASE WHEN PendingGold >= @OrderTotal THEN PendingGold - @OrderTotal ELSE 0 END,
            UpdatedAt = @now
        WHERE WalletId = @BuyerWalletId;

        -- Update order status
        UPDATE dbo.StoreOrders
        SET Status = N'CANCELLED',
            PaymentStatus = N'REFUNDED',
            UpdatedAt = @now
        WHERE OrderId = @ResolvedOrderId;

        -- Release product reservation
        IF @ProductId IS NOT NULL
        BEGIN
            UPDATE dbo.StoreProducts
            SET Status = N'ACTIVE',
                ReservedBy = NULL,
                UpdatedAt = @now
            WHERE ProductId = @ProductId AND Status = N'RESERVED';
        END

        -- Generate refund ID
        SET @RefundPublicId = N'refund_' + LOWER(REPLACE(CAST(NEWID() AS NVARCHAR(36)), '-', ''));

        -- Log ledger entry if table exists
        IF OBJECT_ID('dbo.StoreWalletLedger', 'U') IS NOT NULL
        BEGIN
            INSERT INTO dbo.StoreWalletLedger
            (
                WalletId,
                AmountDelta,
                Reason,
                ActorAuthUid,
                MetadataJson,
                CreatedAt
            )
            VALUES
            (
                @BuyerWalletId,
                @OrderTotal,
                N'ORDER_REFUND',
                @ActorAuthUid,
                JSON_QUERY(
                    '{"orderId":"' + CAST(@ResolvedOrderId AS NVARCHAR(36)) + '"' +
                    ',"refundId":"' + @RefundPublicId + '"' +
                    ISNULL(',"reason":"' + REPLACE(@RefundReason, '"', '\"') + '"', '') +
                    '}'
                ),
                @now
            );
        END

        COMMIT TRANSACTION;

        SELECT
            @RefundPublicId AS RefundPublicId,
            @ResolvedOrderId AS OrderId,
            @OrderTotal AS RefundedAmount,
            @now AS RefundedAt;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrorMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMsg, 16, 1);
        RETURN;
    END CATCH
END
GO

PRINT 'sp_Store_RefundOrder created successfully.';
GO
