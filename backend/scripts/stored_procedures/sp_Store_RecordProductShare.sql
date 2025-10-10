/*
  Procedure: dbo.sp_Store_RecordProductShare
  Purpose : Marks a sold product as shared and records share metadata.
*/

IF DB_ID() IS NULL
BEGIN
    RAISERROR('Database context is not set. Use the appropriate database before running this script.', 16, 1);
    RETURN;
END
GO

IF OBJECT_ID('dbo.sp_Store_RecordProductShare', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.sp_Store_RecordProductShare;
END
GO

CREATE PROCEDURE dbo.sp_Store_RecordProductShare
    @ProductId NVARCHAR(64),
    @EntryId NVARCHAR(128),
    @RequestedBy NVARCHAR(64)
AS
BEGIN
    SET NOCOUNT ON;

    IF @ProductId IS NULL OR LTRIM(RTRIM(@ProductId)) = N''
    BEGIN
        RAISERROR('SQL_GATEWAY_PRODUCT_ID_REQUIRED', 16, 1);
        RETURN;
    END

    IF @EntryId IS NULL OR LTRIM(RTRIM(@EntryId)) = N''
    BEGIN
        RAISERROR('SQL_GATEWAY_ENTRY_ID_REQUIRED', 16, 1);
        RETURN;
    END

    IF @RequestedBy IS NULL OR LTRIM(RTRIM(@RequestedBy)) = N''
    BEGIN
        RAISERROR('SQL_GATEWAY_AUTH_REQUIRED', 16, 1);
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @CurrentStatus NVARCHAR(32);
        DECLARE @SellerType NVARCHAR(16);
        DECLARE @SellerAuthUid NVARCHAR(64);
        DECLARE @ExistingEntryId NVARCHAR(128);

        SELECT
            @CurrentStatus = p.Status,
            @SellerType = p.SellerType,
            @SellerAuthUid = p.SellerAuthUid,
            @ExistingEntryId = p.SharedEntryId
        FROM dbo.StoreProducts AS p WITH (UPDLOCK, HOLDLOCK)
        WHERE p.ProductId = @ProductId;

        IF @@ROWCOUNT = 0
        BEGIN
            RAISERROR('SQL_GATEWAY_PRODUCT_NOT_FOUND', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @ExistingEntryId IS NOT NULL AND LTRIM(RTRIM(@ExistingEntryId)) <> N''
        BEGIN
            RAISERROR('SQL_GATEWAY_ALREADY_SHARED', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @CurrentStatus IS NULL OR UPPER(@CurrentStatus) <> 'SOLD'
        BEGIN
            RAISERROR('SQL_GATEWAY_SHARE_INVALID_STATUS', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @SellerType IS NOT NULL AND UPPER(@SellerType) <> 'P2P'
        BEGIN
            RAISERROR('SQL_GATEWAY_SHARE_ONLY_P2P', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @SellerAuthUid IS NOT NULL AND LTRIM(RTRIM(@SellerAuthUid)) NOT IN (LTRIM(RTRIM(@RequestedBy)))
        BEGIN
            RAISERROR('SQL_GATEWAY_SHARE_UNAUTHORIZED', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        UPDATE dbo.StoreProducts
        SET SharedEntryId = @EntryId,
            SharedByAuthUid = @RequestedBy,
            SharedAt = SYSUTCDATETIME(),
            UpdatedAt = SYSUTCDATETIME()
        WHERE ProductId = @ProductId;

        IF @@ROWCOUNT = 0
        BEGIN
            RAISERROR('SQL_GATEWAY_SHARE_UPDATE_FAILED', 16, 1);
            ROLLBACK TRANSACTION;
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
        FROM dbo.StoreProducts AS p WITH (NOLOCK)
        WHERE p.ProductId = @ProductId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION;
        END

        DECLARE @ErrorNumber INT = ERROR_NUMBER();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();

        RAISERROR('sp_Store_RecordProductShare failed (%d): %s', @ErrorSeverity, 1, @ErrorNumber, @ErrorMessage) WITH NOWAIT;
    END CATCH;
END
GO

PRINT 'Procedure dbo.sp_Store_RecordProductShare created.';
GO
