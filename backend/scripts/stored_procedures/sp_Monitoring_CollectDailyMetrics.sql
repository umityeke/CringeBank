-- Daily Metrics Collection Stored Procedure
--
-- Günlük olarak çalıştırılarak MetricsLog tablosuna kayıt atar
-- Cron job veya manuel olarak çağrılabilir

CREATE OR ALTER PROCEDURE sp_Monitoring_CollectDailyMetrics
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @CollectedAt DATETIME = GETUTCDATE();
    DECLARE @DateToday DATE = CAST(@CollectedAt AS DATE);
    
    -- Check if already collected today
    IF EXISTS (SELECT 1 FROM MetricsLog WHERE CAST(CollectedAt AS DATE) = @DateToday)
    BEGIN
        RAISERROR('Metrics already collected for today', 16, 1);
        RETURN;
    END
    
    -- Collect all metrics in one transaction
    BEGIN TRANSACTION;
    
    BEGIN TRY
        INSERT INTO MetricsLog (
            CollectedAt,
            TotalWallets,
            TotalGoldBalance,
            TotalPendingGold,
            NegativeBalances,
            OrdersToday,
            CompletedOrders,
            CancelledOrders,
            PendingOrders,
            LockedEscrows,
            ReleasedEscrows,
            RefundedEscrows,
            ActiveProducts,
            ReservedProducts,
            AvgOrderCompletionTimeSec
        )
        SELECT 
            @CollectedAt AS CollectedAt,
            
            -- Wallet metrics
            (SELECT COUNT(*) FROM StoreWallets) AS TotalWallets,
            (SELECT ISNULL(SUM(GoldBalance), 0) FROM StoreWallets) AS TotalGoldBalance,
            (SELECT ISNULL(SUM(PendingGold), 0) FROM StoreWallets) AS TotalPendingGold,
            (SELECT COUNT(*) FROM StoreWallets WHERE GoldBalance < 0) AS NegativeBalances,
            
            -- Order metrics
            (SELECT COUNT(*) FROM StoreOrders WHERE CAST(CreatedAt AS DATE) = @DateToday) AS OrdersToday,
            (SELECT COUNT(*) FROM StoreOrders WHERE OrderStatus = 'COMPLETED') AS CompletedOrders,
            (SELECT COUNT(*) FROM StoreOrders WHERE OrderStatus = 'CANCELLED') AS CancelledOrders,
            (SELECT COUNT(*) FROM StoreOrders WHERE OrderStatus = 'PENDING') AS PendingOrders,
            
            -- Escrow metrics
            (SELECT COUNT(*) FROM StoreEscrows WHERE EscrowState = 'LOCKED') AS LockedEscrows,
            (SELECT COUNT(*) FROM StoreEscrows WHERE EscrowState = 'RELEASED') AS ReleasedEscrows,
            (SELECT COUNT(*) FROM StoreEscrows WHERE EscrowState = 'REFUNDED') AS RefundedEscrows,
            
            -- Product metrics
            (SELECT COUNT(*) FROM StoreProducts WHERE IsActive = 1) AS ActiveProducts,
            (SELECT COUNT(*) FROM StoreProducts WHERE ReservedBy IS NOT NULL) AS ReservedProducts,
            
            -- Performance metric
            (SELECT AVG(DATEDIFF(SECOND, CreatedAt, UpdatedAt))
             FROM StoreOrders
             WHERE OrderStatus = 'COMPLETED'
             AND CAST(CreatedAt AS DATE) = @DateToday) AS AvgOrderCompletionTimeSec;
        
        COMMIT TRANSACTION;
        
        PRINT 'Metrics collected successfully for ' + CAST(@DateToday AS VARCHAR(10));
        
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END
GO
