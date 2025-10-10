/*
  Procedure: dbo.sp_Store_ReleaseEscrow
  Purpose : Releases escrow funds to the seller, moves commission to platform wallet, and completes the order.
*/

IF DB_ID() IS NULL
BEGIN
    RAISERROR('Database context is not set. Use the appropriate database before running this script.', 16, 1);
    RETURN;
END
GO

IF OBJECT_ID('dbo.sp_Store_ReleaseEscrow', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.sp_Store_ReleaseEscrow;
END
GO

CREATE PROCEDURE dbo.sp_Store_ReleaseEscrow
    @OrderId         UNIQUEIDENTIFIER = NULL,
    @OrderPublicId   NVARCHAR(64) = NULL,
    @ActorAuthUid    NVARCHAR(64),
    @IsSystemOverride BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @now DATETIME2(3) = SYSUTCDATETIME(),
        @ResolvedOrderId UNIQUEIDENTIFIER,
        @BuyerAuthUid NVARCHAR(64),
        @SellerAuthUid NVARCHAR(64),
        @VendorId NVARCHAR(64),
        @OrderStatus NVARCHAR(24),
        @PaymentStatus NVARCHAR(24),
        @OrderTotal INT,
        @OrderCommission INT,
        @OrderPrice INT,
        @EscrowState NVARCHAR(24),
        @BuyerWalletId INT,
        @SellerWalletId INT,
        @PlatformWalletId INT,
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
            @VendorId = VendorId,
            @OrderStatus = Status,
            @PaymentStatus = PaymentStatus,
            @OrderTotal = TotalGold,
            @OrderCommission = CommissionGold,
            @OrderPrice = ItemPriceGold,
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
            RAISERROR('Order status is not pending. Current status: %s', 16, 1, @OrderStatus);
        END

        IF @PaymentStatus NOT IN (N'AWAITING_ESCROW', N'ESCROW_LOCKED') AND @IsSystemOverride = 0
        BEGIN
            RAISERROR('Payment status does not allow release. Current status: %s', 16, 1, @PaymentStatus);
        END

        IF @ActorAuthUid IS NULL
        BEGIN
            RAISERROR('Actor information is required.', 16, 1);
        END

        IF @ActorAuthUid <> @BuyerAuthUid AND @IsSystemOverride = 0
        BEGIN
            RAISERROR('Only buyer or system override can release escrow.', 16, 1);
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

        IF @BuyerPending IS NULL SET @BuyerPending = 0;
        IF @BuyerPending < @OrderTotal AND @IsSystemOverride = 0
        BEGIN
            RAISERROR('Buyer pending balance insufficient to release escrow.', 16, 1);
        END

        UPDATE dbo.StoreWallets
        SET PendingGold = CASE WHEN PendingGold >= @OrderTotal THEN PendingGold - @OrderTotal ELSE 0 END,
            UpdatedAt = @now
        WHERE WalletId = @BuyerWalletId;

        -- Seller wallet credit
        SELECT TOP (1)
            @SellerWalletId = WalletId
        FROM dbo.StoreWallets WITH (UPDLOCK, HOLDLOCK)
        WHERE AuthUid = @SellerAuthUid;

        IF @SellerWalletId IS NULL
        BEGIN
            INSERT INTO dbo.StoreWallets (AuthUid, GoldBalance, PendingGold, CreatedAt, UpdatedAt)
            VALUES (@SellerAuthUid, 0, 0, @now, @now);
            SET @SellerWalletId = SCOPE_IDENTITY();
        END

        UPDATE dbo.StoreWallets
        SET GoldBalance = GoldBalance + @OrderPrice,
            UpdatedAt = @now
        WHERE WalletId = @SellerWalletId;

        -- Platform commission
        SELECT TOP (1)
            @PlatformWalletId = WalletId
        FROM dbo.StoreWallets WITH (UPDLOCK, HOLDLOCK)
        WHERE AuthUid = N'platform';

        IF @PlatformWalletId IS NULL
        BEGIN
            INSERT INTO dbo.StoreWallets (AuthUid, GoldBalance, PendingGold, CreatedAt, UpdatedAt)
            VALUES (N'platform', 0, 0, @now, @now);
            SET @PlatformWalletId = SCOPE_IDENTITY();
        END

        UPDATE dbo.StoreWallets
        SET GoldBalance = GoldBalance + @OrderCommission,
            UpdatedAt = @now
        WHERE WalletId = @PlatformWalletId;

        -- Update escrow record
        UPDATE dbo.StoreEscrows
        SET EscrowState = N'RELEASED',
            ReleasedAmountGold = @OrderTotal,
            ReleasedAt = @now,
            UpdatedAt = @now
        WHERE OrderId = @ResolvedOrderId;

        -- Update order record
        UPDATE dbo.StoreOrders
        SET Status = N'COMPLETED',
            PaymentStatus = N'RELEASED',
            CompletedAt = @now,
            ReleasedAt = @now,
            UpdatedAt = @now
        WHERE OrderId = @ResolvedOrderId;

        -- Update product record
        UPDATE dbo.StoreProducts
        SET Status = N'SOLD',
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

        RAISERROR('sp_Store_ReleaseEscrow failed (%d): %s', @ErrorSeverity, 1, @ErrorNumber, @ErrorMessage) WITH NOWAIT;
        RETURN;
    END CATCH
END
GO

PRINT 'Procedure dbo.sp_Store_ReleaseEscrow created.';
GO
