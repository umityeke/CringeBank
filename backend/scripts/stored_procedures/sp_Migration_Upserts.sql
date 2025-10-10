-- =====================================================
-- Migration Stored Procedures
-- =====================================================
-- These procedures are used by migrate_firestore_to_sql.js
-- to safely migrate data from Firestore to SQL Server
-- with idempotent MERGE operations.
-- =====================================================

-- =====================================================
-- sp_Migration_UpsertProduct
-- =====================================================
-- Migrates a single product from Firestore
-- Uses MERGE for idempotent execution
-- =====================================================

IF OBJECT_ID('dbo.sp_Migration_UpsertProduct', 'P') IS NOT NULL
  DROP PROCEDURE dbo.sp_Migration_UpsertProduct;
GO

CREATE PROCEDURE dbo.sp_Migration_UpsertProduct
  @ProductId NVARCHAR(64),
  @Title NVARCHAR(255),
  @Description NVARCHAR(MAX) = NULL,
  @PriceGold INT,
  @ImagesJson NVARCHAR(MAX) = NULL,
  @Category NVARCHAR(64) = NULL,
  @Condition NVARCHAR(32) = NULL,
  @Status NVARCHAR(32) = 'ACTIVE',
  @SellerAuthUid NVARCHAR(64),
  @VendorId NVARCHAR(64) = NULL,
  @SellerType NVARCHAR(32) = 'P2P',
  @QrUid NVARCHAR(64) = NULL,
  @QrBound BIT = 0,
  @ReservedBy NVARCHAR(64) = NULL,
  @ReservedAt DATETIME2 = NULL,
  @SharedEntryId NVARCHAR(64) = NULL,
  @SharedByAuthUid NVARCHAR(64) = NULL,
  @SharedAt DATETIME2 = NULL,
  @CreatedAt DATETIME2 = NULL,
  @UpdatedAt DATETIME2 = NULL
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;

  DECLARE @Now DATETIME2 = SYSUTCDATETIME();

  MERGE INTO StoreProducts AS target
  USING (
    SELECT 
      @ProductId AS ProductId,
      @Title AS Title,
      @Description AS Description,
      @PriceGold AS PriceGold,
      @ImagesJson AS ImagesJson,
      @Category AS Category,
      @Condition AS Condition,
      @Status AS Status,
      @SellerAuthUid AS SellerAuthUid,
      @VendorId AS VendorId,
      @SellerType AS SellerType,
      @QrUid AS QrUid,
      @QrBound AS QrBound,
      @ReservedBy AS ReservedBy,
      @ReservedAt AS ReservedAt,
      @SharedEntryId AS SharedEntryId,
      @SharedByAuthUid AS SharedByAuthUid,
      @SharedAt AS SharedAt,
      ISNULL(@CreatedAt, @Now) AS CreatedAt,
      ISNULL(@UpdatedAt, @Now) AS UpdatedAt
  ) AS source
  ON target.ProductId = source.ProductId
  WHEN MATCHED THEN
    UPDATE SET
      Title = source.Title,
      Description = source.Description,
      PriceGold = source.PriceGold,
      ImagesJson = source.ImagesJson,
      Category = source.Category,
      Condition = source.Condition,
      Status = source.Status,
      SellerAuthUid = source.SellerAuthUid,
      VendorId = source.VendorId,
      SellerType = source.SellerType,
      QrUid = source.QrUid,
      QrBound = source.QrBound,
      ReservedBy = source.ReservedBy,
      ReservedAt = source.ReservedAt,
      SharedEntryId = source.SharedEntryId,
      SharedByAuthUid = source.SharedByAuthUid,
      SharedAt = source.SharedAt,
      UpdatedAt = source.UpdatedAt
  WHEN NOT MATCHED THEN
    INSERT (
      ProductId, Title, Description, PriceGold, ImagesJson,
      Category, Condition, Status, SellerAuthUid, VendorId,
      SellerType, QrUid, QrBound, ReservedBy, ReservedAt,
      SharedEntryId, SharedByAuthUid, SharedAt, CreatedAt, UpdatedAt
    )
    VALUES (
      source.ProductId, source.Title, source.Description, source.PriceGold, source.ImagesJson,
      source.Category, source.Condition, source.Status, source.SellerAuthUid, source.VendorId,
      source.SellerType, source.QrUid, source.QrBound, source.ReservedBy, source.ReservedAt,
      source.SharedEntryId, source.SharedByAuthUid, source.SharedAt, source.CreatedAt, source.UpdatedAt
    );

  RETURN 0;
END;
GO

-- =====================================================
-- sp_Migration_UpsertOrder
-- =====================================================

IF OBJECT_ID('dbo.sp_Migration_UpsertOrder', 'P') IS NOT NULL
  DROP PROCEDURE dbo.sp_Migration_UpsertOrder;
GO

CREATE PROCEDURE dbo.sp_Migration_UpsertOrder
  @OrderPublicId NVARCHAR(64),
  @ProductId NVARCHAR(64),
  @BuyerAuthUid NVARCHAR(64),
  @SellerAuthUid NVARCHAR(64) = NULL,
  @VendorId NVARCHAR(64) = NULL,
  @SellerType NVARCHAR(32) = NULL,
  @ItemPriceGold INT,
  @CommissionGold INT,
  @TotalGold INT,
  @Status NVARCHAR(32) = 'PENDING',
  @PaymentStatus NVARCHAR(32) = NULL,
  @TimelineJson NVARCHAR(MAX) = NULL,
  @CreatedAt DATETIME2 = NULL,
  @UpdatedAt DATETIME2 = NULL,
  @DeliveredAt DATETIME2 = NULL,
  @ReleasedAt DATETIME2 = NULL,
  @RefundedAt DATETIME2 = NULL,
  @DisputedAt DATETIME2 = NULL,
  @CompletedAt DATETIME2 = NULL,
  @CanceledAt DATETIME2 = NULL
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;

  DECLARE @Now DATETIME2 = SYSUTCDATETIME();

  MERGE INTO StoreOrders AS target
  USING (
    SELECT 
      @OrderPublicId AS OrderPublicId,
      @ProductId AS ProductId,
      @BuyerAuthUid AS BuyerAuthUid,
      @SellerAuthUid AS SellerAuthUid,
      @VendorId AS VendorId,
      @SellerType AS SellerType,
      @ItemPriceGold AS ItemPriceGold,
      @CommissionGold AS CommissionGold,
      @TotalGold AS TotalGold,
      @Status AS Status,
      @PaymentStatus AS PaymentStatus,
      @TimelineJson AS TimelineJson,
      ISNULL(@CreatedAt, @Now) AS CreatedAt,
      ISNULL(@UpdatedAt, @Now) AS UpdatedAt,
      @DeliveredAt AS DeliveredAt,
      @ReleasedAt AS ReleasedAt,
      @RefundedAt AS RefundedAt,
      @DisputedAt AS DisputedAt,
      @CompletedAt AS CompletedAt,
      @CanceledAt AS CanceledAt
  ) AS source
  ON target.OrderPublicId = source.OrderPublicId
  WHEN MATCHED THEN
    UPDATE SET
      ProductId = source.ProductId,
      BuyerAuthUid = source.BuyerAuthUid,
      SellerAuthUid = source.SellerAuthUid,
      VendorId = source.VendorId,
      SellerType = source.SellerType,
      ItemPriceGold = source.ItemPriceGold,
      CommissionGold = source.CommissionGold,
      TotalGold = source.TotalGold,
      Status = source.Status,
      PaymentStatus = source.PaymentStatus,
      TimelineJson = source.TimelineJson,
      UpdatedAt = source.UpdatedAt,
      DeliveredAt = source.DeliveredAt,
      ReleasedAt = source.ReleasedAt,
      RefundedAt = source.RefundedAt,
      DisputedAt = source.DisputedAt,
      CompletedAt = source.CompletedAt,
      CanceledAt = source.CanceledAt
  WHEN NOT MATCHED THEN
    INSERT (
      OrderPublicId, ProductId, BuyerAuthUid, SellerAuthUid, VendorId,
      SellerType, ItemPriceGold, CommissionGold, TotalGold, Status,
      PaymentStatus, TimelineJson, CreatedAt, UpdatedAt, DeliveredAt,
      ReleasedAt, RefundedAt, DisputedAt, CompletedAt, CanceledAt
    )
    VALUES (
      source.OrderPublicId, source.ProductId, source.BuyerAuthUid, source.SellerAuthUid, source.VendorId,
      source.SellerType, source.ItemPriceGold, source.CommissionGold, source.TotalGold, source.Status,
      source.PaymentStatus, source.TimelineJson, source.CreatedAt, source.UpdatedAt, source.DeliveredAt,
      source.ReleasedAt, source.RefundedAt, source.DisputedAt, source.CompletedAt, source.CanceledAt
    );

  RETURN 0;
END;
GO

-- =====================================================
-- sp_Migration_UpsertEscrow
-- =====================================================

IF OBJECT_ID('dbo.sp_Migration_UpsertEscrow', 'P') IS NOT NULL
  DROP PROCEDURE dbo.sp_Migration_UpsertEscrow;
GO

CREATE PROCEDURE dbo.sp_Migration_UpsertEscrow
  @EscrowPublicId NVARCHAR(64),
  @OrderPublicId NVARCHAR(64),
  @BuyerAuthUid NVARCHAR(64),
  @SellerAuthUid NVARCHAR(64) = NULL,
  @State NVARCHAR(32) = 'LOCKED',
  @LockedAmountGold INT,
  @ReleasedAmountGold INT = 0,
  @RefundedAmountGold INT = 0,
  @LockedAt DATETIME2 = NULL,
  @ReleasedAt DATETIME2 = NULL,
  @RefundedAt DATETIME2 = NULL
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;

  DECLARE @Now DATETIME2 = SYSUTCDATETIME();

  MERGE INTO StoreEscrows AS target
  USING (
    SELECT 
      @EscrowPublicId AS EscrowPublicId,
      @OrderPublicId AS OrderPublicId,
      @BuyerAuthUid AS BuyerAuthUid,
      @SellerAuthUid AS SellerAuthUid,
      @State AS State,
      @LockedAmountGold AS LockedAmountGold,
      @ReleasedAmountGold AS ReleasedAmountGold,
      @RefundedAmountGold AS RefundedAmountGold,
      ISNULL(@LockedAt, @Now) AS LockedAt,
      @ReleasedAt AS ReleasedAt,
      @RefundedAt AS RefundedAt
  ) AS source
  ON target.EscrowPublicId = source.EscrowPublicId
  WHEN MATCHED THEN
    UPDATE SET
      OrderPublicId = source.OrderPublicId,
      BuyerAuthUid = source.BuyerAuthUid,
      SellerAuthUid = source.SellerAuthUid,
      State = source.State,
      LockedAmountGold = source.LockedAmountGold,
      ReleasedAmountGold = source.ReleasedAmountGold,
      RefundedAmountGold = source.RefundedAmountGold,
      LockedAt = source.LockedAt,
      ReleasedAt = source.ReleasedAt,
      RefundedAt = source.RefundedAt
  WHEN NOT MATCHED THEN
    INSERT (
      EscrowPublicId, OrderPublicId, BuyerAuthUid, SellerAuthUid,
      State, LockedAmountGold, ReleasedAmountGold, RefundedAmountGold,
      LockedAt, ReleasedAt, RefundedAt
    )
    VALUES (
      source.EscrowPublicId, source.OrderPublicId, source.BuyerAuthUid, source.SellerAuthUid,
      source.State, source.LockedAmountGold, source.ReleasedAmountGold, source.RefundedAmountGold,
      source.LockedAt, source.ReleasedAt, source.RefundedAt
    );

  RETURN 0;
END;
GO

-- =====================================================
-- sp_Migration_UpsertWallet
-- =====================================================

IF OBJECT_ID('dbo.sp_Migration_UpsertWallet', 'P') IS NOT NULL
  DROP PROCEDURE dbo.sp_Migration_UpsertWallet;
GO

CREATE PROCEDURE dbo.sp_Migration_UpsertWallet
  @AuthUid NVARCHAR(64),
  @GoldBalance INT = 0,
  @PendingGold INT = 0
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;

  DECLARE @Now DATETIME2 = SYSUTCDATETIME();

  MERGE INTO StoreWallets AS target
  USING (
    SELECT 
      @AuthUid AS AuthUid,
      @GoldBalance AS GoldBalance,
      @PendingGold AS PendingGold,
      @Now AS CreatedAt,
      @Now AS UpdatedAt
  ) AS source
  ON target.AuthUid = source.AuthUid
  WHEN MATCHED THEN
    UPDATE SET
      GoldBalance = source.GoldBalance,
      PendingGold = source.PendingGold,
      UpdatedAt = source.UpdatedAt
  WHEN NOT MATCHED THEN
    INSERT (AuthUid, GoldBalance, PendingGold, CreatedAt, UpdatedAt)
    VALUES (source.AuthUid, source.GoldBalance, source.PendingGold, source.CreatedAt, source.UpdatedAt);

  RETURN 0;
END;
GO

-- =====================================================
-- Grant execute permissions to appropriate roles
-- =====================================================

-- Migration procedures should only be executed by superadmin
-- Uncomment and customize based on your RBAC setup:
-- GRANT EXECUTE ON dbo.sp_Migration_UpsertProduct TO superadmin;
-- GRANT EXECUTE ON dbo.sp_Migration_UpsertOrder TO superadmin;
-- GRANT EXECUTE ON dbo.sp_Migration_UpsertEscrow TO superadmin;
-- GRANT EXECUTE ON dbo.sp_Migration_UpsertWallet TO superadmin;
