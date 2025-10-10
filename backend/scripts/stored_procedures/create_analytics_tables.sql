-- =============================================================================
-- Faz 3: Advanced Analytics - SQL Tables
-- =============================================================================
-- Purpose: Create analytics tables for real-time aggregations and metrics
-- Author: CringeBank Analytics Team
-- Date: 2025-10-09
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Table: UserDailyStats
-- Purpose: Daily user activity metrics for engagement tracking
-- -----------------------------------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'UserDailyStats')
BEGIN
    CREATE TABLE UserDailyStats (
        StatId BIGINT IDENTITY(1,1) PRIMARY KEY,
        AuthUid NVARCHAR(128) NOT NULL,
        StatDate DATE NOT NULL,
        
        -- Post Activity
        PostsCreated INT NOT NULL DEFAULT 0,
        PostLikesReceived INT NOT NULL DEFAULT 0,
        PostCommentsReceived INT NOT NULL DEFAULT 0,
        PostSharesReceived INT NOT NULL DEFAULT 0,
        
        -- Engagement Activity
        LikesGiven INT NOT NULL DEFAULT 0,
        CommentsGiven INT NOT NULL DEFAULT 0,
        SharesGiven INT NOT NULL DEFAULT 0,
        
        -- DM Activity
        MessagesReceived INT NOT NULL DEFAULT 0,
        MessagesSent INT NOT NULL DEFAULT 0,
        ConversationsStarted INT NOT NULL DEFAULT 0,
        
        -- Timeline Activity
        TimelineEventsCreated INT NOT NULL DEFAULT 0,
        TimelineEventsViewed INT NOT NULL DEFAULT 0,
        
        -- Notifications
        NotificationsReceived INT NOT NULL DEFAULT 0,
        NotificationsRead INT NOT NULL DEFAULT 0,
        
        -- Social Graph
        NewFollowers INT NOT NULL DEFAULT 0,
        NewFollowing INT NOT NULL DEFAULT 0,
        UnfollowedBy INT NOT NULL DEFAULT 0,
        Unfollowed INT NOT NULL DEFAULT 0,
        
        -- Session Metrics
        SessionCount INT NOT NULL DEFAULT 0,
        TotalSessionMinutes INT NOT NULL DEFAULT 0,
        
        -- Computed Fields
        EngagementScore DECIMAL(10,2) DEFAULT 0.0,
        IsActive BIT DEFAULT 0, -- Active if any activity that day
        
        CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        UpdatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        
        CONSTRAINT UQ_UserDailyStats_User_Date UNIQUE (AuthUid, StatDate)
    );
    
    -- Indexes
    CREATE NONCLUSTERED INDEX IX_UserDailyStats_Date 
        ON UserDailyStats(StatDate DESC, IsActive);
    
    CREATE NONCLUSTERED INDEX IX_UserDailyStats_User 
        ON UserDailyStats(AuthUid, StatDate DESC)
        INCLUDE (EngagementScore, IsActive);
    
    CREATE NONCLUSTERED INDEX IX_UserDailyStats_EngagementScore 
        ON UserDailyStats(EngagementScore DESC, StatDate DESC)
        WHERE IsActive = 1;
    
    -- Extended Properties
    EXEC sys.sp_addextendedproperty 
        @name=N'MS_Description', 
        @value=N'Daily aggregated user activity metrics for engagement tracking and analytics' , 
        @level0type=N'SCHEMA', @level0name=N'dbo', 
        @level1type=N'TABLE', @level1name=N'UserDailyStats';
    
    PRINT 'Table UserDailyStats created successfully';
END
ELSE
BEGIN
    PRINT 'Table UserDailyStats already exists';
END
GO

-- -----------------------------------------------------------------------------
-- Table: ContentDailyStats
-- Purpose: Daily content metrics for trending and discovery
-- -----------------------------------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'ContentDailyStats')
BEGIN
    CREATE TABLE ContentDailyStats (
        StatId BIGINT IDENTITY(1,1) PRIMARY KEY,
        ContentType NVARCHAR(50) NOT NULL, -- POST, COMMENT, MESSAGE
        ContentPublicId NVARCHAR(50) NOT NULL,
        AuthorAuthUid NVARCHAR(128) NOT NULL,
        StatDate DATE NOT NULL,
        
        -- Engagement Metrics
        ViewCount INT NOT NULL DEFAULT 0,
        UniqueViewers INT NOT NULL DEFAULT 0,
        LikeCount INT NOT NULL DEFAULT 0,
        CommentCount INT NOT NULL DEFAULT 0,
        ShareCount INT NOT NULL DEFAULT 0,
        
        -- Growth Metrics
        LikesLast24h INT NOT NULL DEFAULT 0,
        CommentsLast24h INT NOT NULL DEFAULT 0,
        SharesLast24h INT NOT NULL DEFAULT 0,
        
        -- Velocity Metrics (for trending)
        EngagementVelocity DECIMAL(10,2) DEFAULT 0.0, -- Engagement per hour
        ViewVelocity DECIMAL(10,2) DEFAULT 0.0, -- Views per hour
        
        -- Quality Metrics
        AvgEngagementTime INT DEFAULT 0, -- Seconds
        BounceRate DECIMAL(5,2) DEFAULT 0.0, -- Percentage
        
        -- Computed Fields
        TrendingScore DECIMAL(10,2) DEFAULT 0.0,
        QualityScore DECIMAL(10,2) DEFAULT 0.0,
        IsTrending BIT DEFAULT 0,
        
        CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        UpdatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        
        CONSTRAINT UQ_ContentDailyStats_Content_Date UNIQUE (ContentType, ContentPublicId, StatDate),
        CONSTRAINT CK_ContentDailyStats_Type CHECK (ContentType IN ('POST', 'COMMENT', 'MESSAGE', 'TIMELINE_EVENT'))
    );
    
    -- Indexes
    CREATE NONCLUSTERED INDEX IX_ContentDailyStats_Date 
        ON ContentDailyStats(StatDate DESC, IsTrending);
    
    CREATE NONCLUSTERED INDEX IX_ContentDailyStats_Trending 
        ON ContentDailyStats(TrendingScore DESC, StatDate DESC)
        WHERE IsTrending = 1;
    
    CREATE NONCLUSTERED INDEX IX_ContentDailyStats_Author 
        ON ContentDailyStats(AuthorAuthUid, StatDate DESC)
        INCLUDE (TrendingScore, EngagementVelocity);
    
    CREATE NONCLUSTERED INDEX IX_ContentDailyStats_Content 
        ON ContentDailyStats(ContentPublicId, ContentType, StatDate DESC);
    
    -- Extended Properties
    EXEC sys.sp_addextendedproperty 
        @name=N'MS_Description', 
        @value=N'Daily aggregated content metrics for trending detection and content discovery' , 
        @level0type=N'SCHEMA', @level0name=N'dbo', 
        @level1type=N'TABLE', @level1name=N'ContentDailyStats';
    
    PRINT 'Table ContentDailyStats created successfully';
END
ELSE
BEGIN
    PRINT 'Table ContentDailyStats already exists';
END
GO

-- -----------------------------------------------------------------------------
-- Table: SystemMetrics
-- Purpose: System-wide metrics and health indicators
-- -----------------------------------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'SystemMetrics')
BEGIN
    CREATE TABLE SystemMetrics (
        MetricId BIGINT IDENTITY(1,1) PRIMARY KEY,
        MetricType NVARCHAR(100) NOT NULL,
        MetricDate DATETIME2 NOT NULL,
        IntervalType NVARCHAR(20) NOT NULL, -- HOURLY, DAILY, WEEKLY
        
        -- User Metrics
        TotalUsers BIGINT DEFAULT 0,
        ActiveUsers BIGINT DEFAULT 0,
        NewUsers BIGINT DEFAULT 0,
        DAU BIGINT DEFAULT 0, -- Daily Active Users
        MAU BIGINT DEFAULT 0, -- Monthly Active Users
        
        -- Content Metrics
        TotalPosts BIGINT DEFAULT 0,
        NewPosts BIGINT DEFAULT 0,
        TotalComments BIGINT DEFAULT 0,
        NewComments BIGINT DEFAULT 0,
        
        -- DM Metrics
        TotalMessages BIGINT DEFAULT 0,
        NewMessages BIGINT DEFAULT 0,
        TotalConversations BIGINT DEFAULT 0,
        ActiveConversations BIGINT DEFAULT 0,
        
        -- Timeline Metrics
        TotalTimelineEvents BIGINT DEFAULT 0,
        NewTimelineEvents BIGINT DEFAULT 0,
        AvgFeedLoadTime INT DEFAULT 0, -- Milliseconds
        
        -- Notification Metrics
        TotalNotifications BIGINT DEFAULT 0,
        NewNotifications BIGINT DEFAULT 0,
        PushSuccessRate DECIMAL(5,2) DEFAULT 0.0,
        AvgReadTime INT DEFAULT 0, -- Minutes
        
        -- Engagement Metrics
        TotalLikes BIGINT DEFAULT 0,
        TotalShares BIGINT DEFAULT 0,
        AvgEngagementRate DECIMAL(5,2) DEFAULT 0.0,
        
        -- Performance Metrics
        AvgResponseTime INT DEFAULT 0, -- Milliseconds
        ErrorRate DECIMAL(5,2) DEFAULT 0.0,
        SqlWriteSuccessRate DECIMAL(5,2) DEFAULT 0.0,
        
        -- Growth Metrics
        UserGrowthRate DECIMAL(5,2) DEFAULT 0.0, -- Percentage
        ContentGrowthRate DECIMAL(5,2) DEFAULT 0.0,
        EngagementGrowthRate DECIMAL(5,2) DEFAULT 0.0,
        
        MetadataJson NVARCHAR(MAX), -- Additional custom metrics
        
        CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        
        CONSTRAINT UQ_SystemMetrics_Type_Date UNIQUE (MetricType, MetricDate, IntervalType),
        CONSTRAINT CK_SystemMetrics_Interval CHECK (IntervalType IN ('HOURLY', 'DAILY', 'WEEKLY', 'MONTHLY'))
    );
    
    -- Indexes
    CREATE NONCLUSTERED INDEX IX_SystemMetrics_Date 
        ON SystemMetrics(MetricDate DESC, IntervalType);
    
    CREATE NONCLUSTERED INDEX IX_SystemMetrics_Type 
        ON SystemMetrics(MetricType, MetricDate DESC)
        INCLUDE (DAU, MAU, AvgEngagementRate);
    
    CREATE NONCLUSTERED INDEX IX_SystemMetrics_DAU 
        ON SystemMetrics(DAU DESC, MetricDate DESC)
        WHERE IntervalType = 'DAILY';
    
    -- Extended Properties
    EXEC sys.sp_addextendedproperty 
        @name=N'MS_Description', 
        @value=N'System-wide metrics and health indicators for monitoring and analytics' , 
        @level0type=N'SCHEMA', @level0name=N'dbo', 
        @level1type=N'TABLE', @level1name=N'SystemMetrics';
    
    PRINT 'Table SystemMetrics created successfully';
END
ELSE
BEGIN
    PRINT 'Table SystemMetrics already exists';
END
GO

-- -----------------------------------------------------------------------------
-- Table: UserEngagementScore
-- Purpose: Current user engagement scores with historical tracking
-- -----------------------------------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'UserEngagementScore')
BEGIN
    CREATE TABLE UserEngagementScore (
        ScoreId BIGINT IDENTITY(1,1) PRIMARY KEY,
        AuthUid NVARCHAR(128) NOT NULL,
        
        -- Current Score Components
        ContentCreationScore DECIMAL(10,2) DEFAULT 0.0, -- Weight: 30%
        InteractionScore DECIMAL(10,2) DEFAULT 0.0,     -- Weight: 25%
        SocialGraphScore DECIMAL(10,2) DEFAULT 0.0,     -- Weight: 20%
        ConsistencyScore DECIMAL(10,2) DEFAULT 0.0,     -- Weight: 15%
        QualityScore DECIMAL(10,2) DEFAULT 0.0,         -- Weight: 10%
        
        -- Aggregate Score
        TotalEngagementScore DECIMAL(10,2) DEFAULT 0.0, -- Weighted sum
        ScoreTier NVARCHAR(20), -- ELITE, HIGH, MEDIUM, LOW, INACTIVE
        
        -- Historical Metrics (30 days)
        AvgDailyPosts DECIMAL(10,2) DEFAULT 0.0,
        AvgDailyLikes DECIMAL(10,2) DEFAULT 0.0,
        AvgDailyComments DECIMAL(10,2) DEFAULT 0.0,
        TotalFollowers INT DEFAULT 0,
        TotalFollowing INT DEFAULT 0,
        FollowerGrowthRate DECIMAL(5,2) DEFAULT 0.0,
        
        -- Activity Patterns
        DaysActiveLast30 INT DEFAULT 0,
        ConsecutiveActiveDays INT DEFAULT 0,
        LongestStreak INT DEFAULT 0,
        LastActiveDate DATE,
        
        -- Content Quality
        AvgLikesPerPost DECIMAL(10,2) DEFAULT 0.0,
        AvgCommentsPerPost DECIMAL(10,2) DEFAULT 0.0,
        TrendingPostsCount INT DEFAULT 0,
        
        -- Ranking
        GlobalRank INT,
        CategoryRank INT,
        
        CalculatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        PreviousScore DECIMAL(10,2), -- For trend analysis
        ScoreChange DECIMAL(10,2) DEFAULT 0.0,
        
        CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        UpdatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        
        CONSTRAINT UQ_UserEngagementScore_User UNIQUE (AuthUid)
    );
    
    -- Indexes
    CREATE NONCLUSTERED INDEX IX_UserEngagementScore_Score 
        ON UserEngagementScore(TotalEngagementScore DESC, ScoreTier)
        INCLUDE (AuthUid, CalculatedAt);
    
    CREATE NONCLUSTERED INDEX IX_UserEngagementScore_Tier 
        ON UserEngagementScore(ScoreTier, TotalEngagementScore DESC);
    
    CREATE NONCLUSTERED INDEX IX_UserEngagementScore_Rank 
        ON UserEngagementScore(GlobalRank)
        WHERE GlobalRank IS NOT NULL;
    
    CREATE NONCLUSTERED INDEX IX_UserEngagementScore_Active 
        ON UserEngagementScore(LastActiveDate DESC, TotalEngagementScore DESC);
    
    -- Extended Properties
    EXEC sys.sp_addextendedproperty 
        @name=N'MS_Description', 
        @value=N'User engagement scores with component breakdown and historical tracking' , 
        @level0type=N'SCHEMA', @level0name=N'dbo', 
        @level1type=N'TABLE', @level1name=N'UserEngagementScore';
    
    PRINT 'Table UserEngagementScore created successfully';
END
ELSE
BEGIN
    PRINT 'Table UserEngagementScore already exists';
END
GO

-- -----------------------------------------------------------------------------
-- Table: RecommendationCache
-- Purpose: Cached recommendations for fast retrieval
-- -----------------------------------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'RecommendationCache')
BEGIN
    CREATE TABLE RecommendationCache (
        CacheId BIGINT IDENTITY(1,1) PRIMARY KEY,
        AuthUid NVARCHAR(128) NOT NULL,
        RecommendationType NVARCHAR(50) NOT NULL, -- FOLLOW_SUGGESTIONS, TRENDING_POSTS, SIMILAR_USERS
        
        -- Recommendation Data
        RecommendationData NVARCHAR(MAX) NOT NULL, -- JSON array of recommendations
        RecommendationCount INT NOT NULL,
        
        -- Scoring
        ConfidenceScore DECIMAL(5,2) DEFAULT 0.0, -- 0-100
        AlgorithmVersion NVARCHAR(20),
        
        -- Cache Management
        ExpiresAt DATETIME2 NOT NULL,
        IsStale BIT DEFAULT 0,
        
        CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        UpdatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        
        CONSTRAINT UQ_RecommendationCache_User_Type UNIQUE (AuthUid, RecommendationType),
        CONSTRAINT CK_RecommendationCache_Type CHECK (RecommendationType IN ('FOLLOW_SUGGESTIONS', 'TRENDING_POSTS', 'SIMILAR_USERS', 'CONTENT_DISCOVERY', 'HASHTAG_SUGGESTIONS'))
    );
    
    -- Indexes
    CREATE NONCLUSTERED INDEX IX_RecommendationCache_User 
        ON RecommendationCache(AuthUid, RecommendationType)
        WHERE IsStale = 0;
    
    CREATE NONCLUSTERED INDEX IX_RecommendationCache_Expiry 
        ON RecommendationCache(ExpiresAt)
        WHERE IsStale = 0;
    
    -- Extended Properties
    EXEC sys.sp_addextendedproperty 
        @name=N'MS_Description', 
        @value=N'Cached recommendations for fast retrieval and reduced computation' , 
        @level0type=N'SCHEMA', @level0name=N'dbo', 
        @level1type=N'TABLE', @level1name=N'RecommendationCache';
    
    PRINT 'Table RecommendationCache created successfully';
END
ELSE
BEGIN
    PRINT 'Table RecommendationCache already exists';
END
GO

PRINT '';
PRINT '=============================================================================';
PRINT 'Faz 3 Analytics Tables Created Successfully';
PRINT '=============================================================================';
PRINT 'Tables:';
PRINT '  - UserDailyStats (Daily user activity metrics)';
PRINT '  - ContentDailyStats (Content trending and discovery)';
PRINT '  - SystemMetrics (System-wide health indicators)';
PRINT '  - UserEngagementScore (Engagement scoring with tiers)';
PRINT '  - RecommendationCache (Fast recommendation retrieval)';
PRINT '=============================================================================';
