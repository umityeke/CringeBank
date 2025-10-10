/*
  Procedure: dbo.sp_Store_CreateOrderAndLockEscrow
  Purpose : Creates a store order, locks the escrow amount, debits buyer wallet, and reserves the product.
  Usage   :
    EXEC dbo.sp_Store_CreateOrderAndLockEscrow
        @BuyerAuthUid      = N'<buyer uid>',
        @ProductId         = N'<product id>',
        @RequestedBy       = N'<caller uid>', -- optional auditing
        @IsSystemOverride  = 0,
        @OrderPublicId     = @OrderPublicId OUTPUT;
*/

IF DB_ID() IS NULL
BEGIN
    RAISERROR('Database context is not set. Use the appropriate database before running this script.', 16, 1);
    RETURN;
END
GO

IF OBJECT_ID('dbo.sp_Store_CreateOrderAndLockEscrow', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.sp_Store_CreateOrderAndLockEscrow;
END
GO

CREATE PROCEDURE dbo.sp_Store_CreateOrderAndLockEscrow
    @BuyerAuthUid     NVARCHAR(64),
    @ProductId        NVARCHAR(64),
    @RequestedBy      NVARCHAR(64) = NULL,
    @IsSystemOverride BIT = 0,
    @CommissionRate   DECIMAL(5,4) = 0.05,
    @OrderPublicId    NVARCHAR(64) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @now DATETIME2(3) = SYSUTCDATETIME(),
        @ProductStatus NVARCHAR(32),
        @SellerAuthUid NVARCHAR(64),
        @SellerType NVARCHAR(16),
        @VendorId NVARCHAR(64),
        @PriceGold INT,
        @CommissionGold INT,
        @TotalGold INT,
        @WalletId INT,
        @CurrentBalance INT,
        @OrderId UNIQUEIDENTIFIER,
        @EscrowId UNIQUEIDENTIFIER,
        @ReservedBy NVARCHAR(64),
        @OrderStatus NVARCHAR(24) = N'PENDING';

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Load product with update lock to prevent race conditions
        SELECT TOP (1)
            @ProductStatus = Status,
            @SellerAuthUid = SellerAuthUid,
            @SellerType = SellerType,
            @VendorId = VendorId,
            @PriceGold = PriceGold,
            @ReservedBy = ReservedBy
        FROM dbo.StoreProducts WITH (UPDLOCK, HOLDLOCK)
        WHERE ProductId = @ProductId;

        IF @ProductStatus IS NULL
        BEGIN
            RAISERROR('Product not found.', 16, 1);
        END

        IF @ProductStatus <> N'ACTIVE' AND (@IsSystemOverride = 0 OR @ProductStatus IN (N'RESERVED', N'SOLD'))
        BEGIN
            RAISERROR('Product is not available for purchase. Status: %s', 16, 1, @ProductStatus);
        END

        IF @SellerAuthUid = @BuyerAuthUid AND @IsSystemOverride = 0
        BEGIN
            RAISERROR('Buyer cannot purchase own product.', 16, 1);
        END

        IF @SellerAuthUid IS NULL AND @VendorId IS NULL
        BEGIN
            RAISERROR('Product is missing seller information.', 16, 1);
        END

        IF @PriceGold IS NULL OR @PriceGold <= 0
        BEGIN
            RAISERROR('Product price is not valid.', 16, 1);
        END

        SET @CommissionGold = CAST(@PriceGold * @CommissionRate AS INT);
        SET @TotalGold = @PriceGold + @CommissionGold;

        -- Load buyer wallet
        SELECT TOP (1)
            @WalletId = WalletId,
            @CurrentBalance = GoldBalance
        FROM dbo.StoreWallets WITH (UPDLOCK, HOLDLOCK)
        WHERE AuthUid = @BuyerAuthUid;

        IF @WalletId IS NULL
        BEGIN
            RAISERROR('Wallet not found for buyer.', 16, 1);
        END

        IF @CurrentBalance IS NULL
        BEGIN
            SET @CurrentBalance = 0;
        END

        IF @CurrentBalance < @TotalGold AND @IsSystemOverride = 0
        BEGIN
            RAISERROR('Insufficient balance. Required: %d, Available: %d', 16, 1, @TotalGold, @CurrentBalance);
        END

        -- Generate identifiers
        SET @OrderId = NEWID();
        SET @EscrowId = @OrderId; -- keep same identifier linkage
        SET @OrderPublicId = REPLACE(CONVERT(NVARCHAR(36), @OrderId),'-','');

        -- Insert order row
        INSERT INTO dbo.StoreOrders
        (
            OrderId,
            OrderPublicId,
            ProductId,
            BuyerAuthUid,
            SellerAuthUid,
            VendorId,
            SellerType,
            ItemPriceGold,
            CommissionGold,
            TotalGold,
            Status,
            PaymentStatus,
            TimelineJson,
            CreatedAt,
            UpdatedAt
        )
        VALUES
        (
            @OrderId,
            @OrderPublicId,
            @ProductId,
            @BuyerAuthUid,
            @SellerAuthUid,
            @VendorId,
            @SellerType,
            @PriceGold,
            @CommissionGold,
            @TotalGold,
            @OrderStatus,
            N'AWAITING_ESCROW',
            NULL,
            @now,
            @now
        );

        -- Create escrow row
        INSERT INTO dbo.StoreEscrows
        (
            EscrowId,
            EscrowPublicId,
            OrderId,
            BuyerAuthUid,
            SellerAuthUid,
            VendorId,
            EscrowState,
            LockedAmountGold,
            ReleasedAmountGold,
            RefundedAmountGold,
            LockRequestedAt,
            LockedAt,
            CreatedAt,
            UpdatedAt
        )
        VALUES
        (
            @EscrowId,
            @OrderPublicId,
            @OrderId,
            @BuyerAuthUid,
            @SellerAuthUid,
            @VendorId,
            N'LOCKED',
            @TotalGold,
            0,
            0,
            @now,
            @now,
            @now,
            @now
        );

        -- Debit wallet balance
        UPDATE dbo.StoreWallets
        SET GoldBalance = GoldBalance - @TotalGold,
            PendingGold = PendingGold + @TotalGold,
            UpdatedAt = @now
        WHERE WalletId = @WalletId;

        IF @@ROWCOUNT <> 1
        BEGIN
            RAISERROR('Wallet update failed.', 16, 1);
        END

        -- Reserve product
        UPDATE dbo.StoreProducts
        SET Status = N'RESERVED',
            ReservedBy = @BuyerAuthUid,
            ReservedAt = @now,
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
        DECLARE @ErrorState INT = ERROR_STATE();

        RAISERROR('sp_Store_CreateOrderAndLockEscrow failed (%d): %s', @ErrorSeverity, 1, @ErrorNumber, @ErrorMessage) WITH NOWAIT;
        RETURN;
    END CATCH
END
GO

PRINT 'Procedure dbo.sp_Store_CreateOrderAndLockEscrow created.';
GO
