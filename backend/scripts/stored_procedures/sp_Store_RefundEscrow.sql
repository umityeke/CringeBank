/*
  Procedure: dbo.sp_Store_RefundEscrow
  Purpose : Refunds escrow amount back to buyer, cancels the order, and reactivates the product.
*/

IF DB_ID() IS NULL
BEGIN
    RAISERROR('Database context is not set. Use the appropriate database before running this script.', 16, 1);
    RETURN;
END
GO

IF OBJECT_ID('dbo.sp_Store_RefundEscrow', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.sp_Store_RefundEscrow;
END
GO

CREATE PROCEDURE dbo.sp_Store_RefundEscrow
    @OrderId         UNIQUEIDENTIFIER = NULL,
    @OrderPublicId   NVARCHAR(64) = NULL,
    @ActorAuthUid    NVARCHAR(64),
    @IsSystemOverride BIT = 0,
    @RefundReason    NVARCHAR(256) = NULL
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

    BEGIN TRY
        BEGIN TRANSACTION;

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

        IF @OrderStatus <> N'PENDING' AND @IsSystemOverride = 0
        BEGIN
            RAISERROR('Only pending orders can be refunded. Current status: %s', 16, 1, @OrderStatus);
        END

        IF @PaymentStatus NOT IN (N'AWAITING_ESCROW', N'ESCROW_LOCKED') AND @IsSystemOverride = 0
        BEGIN
            RAISERROR('Payment status does not allow refund. Current status: %s', 16, 1, @PaymentStatus);
        END

        IF @ActorAuthUid IS NULL
        BEGIN
            RAISERROR('Actor information is required.', 16, 1);
        END

        IF @ActorAuthUid NOT IN (@BuyerAuthUid, @SellerAuthUid) AND @IsSystemOverride = 0
        BEGIN
            RAISERROR('Only buyer, seller, or override can refund escrow.', 16, 1);
        END

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
            RAISERROR('Escrow is not in LOCKED state. Current state: %s', 16, 1, @EscrowState);
        END

        -- Buyer wallet adjustments
        SELECT TOP (1)
            @BuyerWalletId = WalletId,
            @BuyerPending = PendingGold
        FROM dbo.StoreWallets WITH (UPDLOCK, HOLDLOCK)
        WHERE AuthUid = @BuyerAuthUid;

        IF @BuyerWalletId IS NULL
        BEGIN
            RAISERROR('Buyer wallet not found.', 16, 1);
        END

        UPDATE dbo.StoreWallets
        SET GoldBalance = GoldBalance + @OrderTotal,
            PendingGold = CASE WHEN PendingGold >= @OrderTotal THEN PendingGold - @OrderTotal ELSE 0 END,
            UpdatedAt = @now
        WHERE WalletId = @BuyerWalletId;

        -- Update escrow record
        UPDATE dbo.StoreEscrows
        SET EscrowState = N'REFUNDED',
            RefundedAmountGold = @OrderTotal,
            RefundedAt = @now,
            UpdatedAt = @now,
            NotesJson = CASE
                WHEN @RefundReason IS NULL THEN NotesJson
                ELSE JSON_MODIFY(ISNULL(NotesJson, N'{}'), '$.refundReason', @RefundReason)
            END
        WHERE OrderId = @ResolvedOrderId;

        -- Update order record
        UPDATE dbo.StoreOrders
        SET Status = N'CANCELED',
            PaymentStatus = N'REFUNDED',
            CanceledAt = @now,
            RefundedAt = @now,
            UpdatedAt = @now
        WHERE OrderId = @ResolvedOrderId;

        -- Update product record
        UPDATE dbo.StoreProducts
        SET Status = N'ACTIVE',
            ReservedBy = NULL,
            ReservedAt = NULL,
            UpdatedAt = @now
        WHERE ProductId = @ProductId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
        BEGIN
            ROLLBACK TRANSACTION;
        END

        DECLARE @ErrorNumber INT = ERROR_NUMBER();
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();

        RAISERROR('sp_Store_RefundEscrow failed (%d): %s', @ErrorSeverity, 1, @ErrorNumber, @ErrorMessage) WITH NOWAIT;
        RETURN;
    END CATCH
END
GO

PRINT 'Procedure dbo.sp_Store_RefundEscrow created.';
GO
