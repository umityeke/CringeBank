/*
  Procedure: dbo.sp_Store_AdjustWalletBalance
  Purpose : Adjusts a user wallet balance by a delta, optionally recording metadata, and enforces non-negative balances unless override is used.
*/

IF DB_ID() IS NULL
BEGIN
    RAISERROR('Database context is not set. Use the appropriate database before running this script.', 16, 1);
    RETURN;
END
GO

IF OBJECT_ID('dbo.sp_Store_AdjustWalletBalance', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.sp_Store_AdjustWalletBalance;
END
GO

CREATE PROCEDURE dbo.sp_Store_AdjustWalletBalance
    @TargetAuthUid   NVARCHAR(64),
    @ActorAuthUid    NVARCHAR(64),
    @AmountDelta     INT,
    @Reason          NVARCHAR(256) = NULL,
    @MetadataJson    NVARCHAR(1024) = NULL,
    @IsSystemOverride BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @now DATETIME2(3) = SYSUTCDATETIME(),
        @WalletId INT,
        @CurrentBalance INT,
        @NewBalance INT,
        @LedgerId BIGINT;

    IF @TargetAuthUid IS NULL OR LTRIM(RTRIM(@TargetAuthUid)) = N''
    BEGIN
        RAISERROR('Target auth uid is required.', 16, 1);
        RETURN;
    END

    IF @ActorAuthUid IS NULL OR LTRIM(RTRIM(@ActorAuthUid)) = N''
    BEGIN
        RAISERROR('Actor auth uid is required.', 16, 1);
        RETURN;
    END

    IF @AmountDelta IS NULL OR @AmountDelta = 0
    BEGIN
        RAISERROR('Amount delta must be non-zero.', 16, 1);
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT TOP (1)
            @WalletId = WalletId,
            @CurrentBalance = GoldBalance
        FROM dbo.StoreWallets WITH (UPDLOCK, HOLDLOCK)
        WHERE AuthUid = @TargetAuthUid;

        IF @WalletId IS NULL
        BEGIN
            IF @AmountDelta < 0 AND @IsSystemOverride = 0
            BEGIN
                RAISERROR('Wallet not found for debit.', 16, 1);
            END

            INSERT INTO dbo.StoreWallets (AuthUid, GoldBalance, PendingGold, CreatedAt, UpdatedAt)
            VALUES (@TargetAuthUid, 0, 0, @now, @now);

            SET @WalletId = SCOPE_IDENTITY();
            SET @CurrentBalance = 0;
        END

        SET @NewBalance = ISNULL(@CurrentBalance, 0) + @AmountDelta;

        IF @NewBalance < 0 AND @IsSystemOverride = 0
        BEGIN
            RAISERROR('Wallet balance cannot become negative.', 16, 1);
        END

        UPDATE dbo.StoreWallets
        SET GoldBalance = @NewBalance,
            UpdatedAt = @now
        WHERE WalletId = @WalletId;

        IF @@ROWCOUNT <> 1
        BEGIN
            RAISERROR('Wallet update failed.', 16, 1);
        END

        IF OBJECT_ID('dbo.StoreWalletLedger', 'U') IS NOT NULL
        BEGIN
            INSERT INTO dbo.StoreWalletLedger
            (
                WalletId,
                TargetAuthUid,
                ActorAuthUid,
                AmountDelta,
                Reason,
                MetadataJson,
                CreatedAt
            )
            VALUES
            (
                @WalletId,
                @TargetAuthUid,
                @ActorAuthUid,
                @AmountDelta,
                NULLIF(LTRIM(RTRIM(@Reason)), N''),
                CASE WHEN @MetadataJson IS NULL OR LTRIM(RTRIM(@MetadataJson)) = N'' THEN NULL ELSE @MetadataJson END,
                @now
            );

            SET @LedgerId = SCOPE_IDENTITY();

            UPDATE dbo.StoreWallets
            SET LastLedgerEntryId = CAST(@LedgerId AS NVARCHAR(64))
            WHERE WalletId = @WalletId;
        END

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

        RAISERROR('sp_Store_AdjustWalletBalance failed (%d): %s', @ErrorSeverity, 1, @ErrorNumber, @ErrorMessage) WITH NOWAIT;
        RETURN;
    END CATCH

    SELECT
        TargetAuthUid = @TargetAuthUid,
        AmountDelta = @AmountDelta,
        NewBalance = @NewBalance,
        LedgerEntryId = CASE WHEN @LedgerId IS NULL THEN NULL ELSE CAST(@LedgerId AS NVARCHAR(64)) END;
END
GO

PRINT 'Procedure dbo.sp_Store_AdjustWalletBalance created.';
GO
