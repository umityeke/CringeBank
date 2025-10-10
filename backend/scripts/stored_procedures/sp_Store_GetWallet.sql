/*
  Procedure: dbo.sp_Store_GetWallet
  Purpose : Returns wallet balances for a given auth uid, creating a zero-balance wallet when not found if allowed.
*/

IF DB_ID() IS NULL
BEGIN
    RAISERROR('Database context is not set. Use the appropriate database before running this script.', 16, 1);
    RETURN;
END
GO

IF OBJECT_ID('dbo.sp_Store_GetWallet', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.sp_Store_GetWallet;
END
GO

CREATE PROCEDURE dbo.sp_Store_GetWallet
    @AuthUid NVARCHAR(64),
    @CreateIfMissing BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @WalletId INT;

    IF @AuthUid IS NULL OR LTRIM(RTRIM(@AuthUid)) = N''
    BEGIN
        RAISERROR('AuthUid is required.', 16, 1);
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT TOP (1)
            @WalletId = WalletId
        FROM dbo.StoreWallets WITH (UPDLOCK, HOLDLOCK)
        WHERE AuthUid = @AuthUid;

        IF @WalletId IS NULL AND @CreateIfMissing = 1
        BEGIN
            INSERT INTO dbo.StoreWallets (AuthUid, GoldBalance, PendingGold, CreatedAt, UpdatedAt)
            VALUES (@AuthUid, 0, 0, SYSUTCDATETIME(), SYSUTCDATETIME());

            SET @WalletId = SCOPE_IDENTITY();
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

        RAISERROR('sp_Store_GetWallet failed (%d): %s', @ErrorSeverity, 1, @ErrorNumber, @ErrorMessage) WITH NOWAIT;
        RETURN;
    END CATCH

    SELECT TOP (1)
        WalletId,
        AuthUid,
        GoldBalance,
        PendingGold,
        LastLedgerEntryId,
        CreatedAt,
        UpdatedAt
    FROM dbo.StoreWallets WITH (NOLOCK)
    WHERE AuthUid = @AuthUid;

    IF OBJECT_ID('dbo.StoreWalletLedger', 'U') IS NOT NULL
    BEGIN
        SELECT TOP (50)
            l.LedgerId,
            l.WalletId,
            l.TargetAuthUid,
            l.ActorAuthUid,
            l.AmountDelta,
            l.Reason,
            l.MetadataJson,
            l.CreatedAt
        FROM dbo.StoreWalletLedger l WITH (NOLOCK)
        WHERE l.TargetAuthUid = @AuthUid
        ORDER BY l.CreatedAt DESC;
    END
END
GO

PRINT 'Procedure dbo.sp_Store_GetWallet created.';
GO
