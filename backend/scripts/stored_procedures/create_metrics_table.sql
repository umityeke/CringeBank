-- MetricsLog Table Creation Script
-- 
-- Günlük ve saatlik metrikleri saklamak için tablo
-- Grafana dashboards ve historical analysis için kullanılır

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'MetricsLog')
BEGIN
    CREATE TABLE MetricsLog (
        Id INT IDENTITY(1,1) PRIMARY KEY,
        CollectedAt DATETIME NOT NULL,
        
        -- Wallet metrics
        TotalWallets INT NOT NULL DEFAULT 0,
        TotalGoldBalance BIGINT NOT NULL DEFAULT 0,
        TotalPendingGold BIGINT NOT NULL DEFAULT 0,
        NegativeBalances INT NOT NULL DEFAULT 0,
        
        -- Order metrics
        OrdersToday INT NOT NULL DEFAULT 0,
        CompletedOrders INT NOT NULL DEFAULT 0,
        CancelledOrders INT NOT NULL DEFAULT 0,
        PendingOrders INT NOT NULL DEFAULT 0,
        
        -- Escrow metrics
        LockedEscrows INT NOT NULL DEFAULT 0,
        ReleasedEscrows INT NOT NULL DEFAULT 0,
        RefundedEscrows INT NOT NULL DEFAULT 0,
        
        -- Product metrics
        ActiveProducts INT NOT NULL DEFAULT 0,
        ReservedProducts INT NOT NULL DEFAULT 0,
        
        -- Performance metrics (optional)
        AvgOrderCompletionTimeSec INT NULL,
        MaxQueryDurationMs INT NULL,
        
        CONSTRAINT UQ_MetricsLog_CollectedAt UNIQUE (CollectedAt)
    );
    
    CREATE INDEX IX_MetricsLog_CollectedAt ON MetricsLog(CollectedAt DESC);
    
    PRINT 'MetricsLog table created successfully';
END
ELSE
BEGIN
    PRINT 'MetricsLog table already exists';
END
GO

-- Sample validation query
SELECT TOP 10
    CollectedAt,
    TotalGoldBalance,
    NegativeBalances,
    OrdersToday,
    LockedEscrows
FROM MetricsLog
ORDER BY CollectedAt DESC;
GO
