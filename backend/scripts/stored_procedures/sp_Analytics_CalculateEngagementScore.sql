-- =============================================================================
-- Stored Procedure: sp_Analytics_CalculateEngagementScore
-- =============================================================================
-- Purpose: Calculate comprehensive user engagement score with component breakdown
-- Author: CringeBank Analytics Team
-- Date: 2025-10-09
-- =============================================================================

CREATE OR ALTER PROCEDURE sp_Analytics_CalculateEngagementScore
    @AuthUid NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        -- Validate input
        IF @AuthUid IS NULL OR LEN(LTRIM(RTRIM(@AuthUid))) = 0
        BEGIN
            RAISERROR('AuthUid is required', 16, 1);
            RETURN;
        END
        
        -- Time windows
        DECLARE @Last30Days DATE = CAST(DATEADD(DAY, -30, GETUTCDATE()) AS DATE);
        DECLARE @Last60Days DATE = CAST(DATEADD(DAY, -60, GETUTCDATE()) AS DATE);
        
        -- Score components (0-100 each)
        DECLARE @ContentCreationScore DECIMAL(10,2) = 0.0;
        DECLARE @InteractionScore DECIMAL(10,2) = 0.0;
        DECLARE @SocialGraphScore DECIMAL(10,2) = 0.0;
        DECLARE @ConsistencyScore DECIMAL(10,2) = 0.0;
        DECLARE @QualityScore DECIMAL(10,2) = 0.0;
        
        -- Historical metrics
        DECLARE @AvgDailyPosts DECIMAL(10,2) = 0.0;
        DECLARE @AvgDailyLikes DECIMAL(10,2) = 0.0;
        DECLARE @AvgDailyComments DECIMAL(10,2) = 0.0;
        DECLARE @TotalFollowers INT = 0;
        DECLARE @TotalFollowing INT = 0;
        DECLARE @FollowerGrowthRate DECIMAL(5,2) = 0.0;
        
        -- Activity patterns
        DECLARE @DaysActiveLast30 INT = 0;
        DECLARE @ConsecutiveActiveDays INT = 0;
        DECLARE @LongestStreak INT = 0;
        DECLARE @LastActiveDate DATE;
        
        -- Content quality
        DECLARE @AvgLikesPerPost DECIMAL(10,2) = 0.0;
        DECLARE @AvgCommentsPerPost DECIMAL(10,2) = 0.0;
        DECLARE @TrendingPostsCount INT = 0;
        
        -- ========================================================================
        -- 1. CONTENT CREATION SCORE (30% weight)
        -- ========================================================================
        -- Posts, timeline events, messages sent
        SELECT 
            @AvgDailyPosts = AVG(CAST(TimelineEventsCreated AS DECIMAL(10,2)))
        FROM UserDailyStats
        WHERE AuthUid = @AuthUid
            AND StatDate >= @Last30Days
            AND IsActive = 1;
        
        -- Normalize to 0-100 scale (1 post/day = 10 points, max 10 posts/day = 100)
        SET @ContentCreationScore = CASE 
            WHEN @AvgDailyPosts >= 10 THEN 100
            WHEN @AvgDailyPosts > 0 THEN @AvgDailyPosts * 10
            ELSE 0
        END;
        
        -- ========================================================================
        -- 2. INTERACTION SCORE (25% weight)
        -- ========================================================================
        -- Likes given, comments given, messages sent
        SELECT 
            @AvgDailyLikes = AVG(CAST(LikesGiven AS DECIMAL(10,2))),
            @AvgDailyComments = AVG(CAST(CommentsGiven AS DECIMAL(10,2)))
        FROM UserDailyStats
        WHERE AuthUid = @AuthUid
            AND StatDate >= @Last30Days
            AND IsActive = 1;
        
        -- Normalize (5 interactions/day = 50 points, 10+ = 100)
        DECLARE @AvgDailyInteractions DECIMAL(10,2) = @AvgDailyLikes + (@AvgDailyComments * 2);
        SET @InteractionScore = CASE 
            WHEN @AvgDailyInteractions >= 10 THEN 100
            WHEN @AvgDailyInteractions > 0 THEN @AvgDailyInteractions * 10
            ELSE 0
        END;
        
        -- ========================================================================
        -- 3. SOCIAL GRAPH SCORE (20% weight)
        -- ========================================================================
        -- Followers, following, follower growth
        -- Note: This would need Follows table - using placeholder for now
        SET @TotalFollowers = 0; -- TODO: Query from Follows table when available
        SET @TotalFollowing = 0;
        
        -- Normalize (100 followers = 50 points, 500+ = 100)
        SET @SocialGraphScore = CASE 
            WHEN @TotalFollowers >= 500 THEN 100
            WHEN @TotalFollowers > 0 THEN (@TotalFollowers / 5.0)
            ELSE 0
        END;
        
        -- ========================================================================
        -- 4. CONSISTENCY SCORE (15% weight)
        -- ========================================================================
        -- Days active, consecutive days, longest streak
        SELECT 
            @DaysActiveLast30 = COUNT(*),
            @LastActiveDate = MAX(StatDate)
        FROM UserDailyStats
        WHERE AuthUid = @AuthUid
            AND StatDate >= @Last30Days
            AND IsActive = 1;
        
        -- Calculate consecutive active days
        WITH DailyActivity AS (
            SELECT 
                StatDate,
                DATEADD(DAY, -ROW_NUMBER() OVER (ORDER BY StatDate), StatDate) AS Grp
            FROM UserDailyStats
            WHERE AuthUid = @AuthUid
                AND StatDate >= @Last60Days
                AND IsActive = 1
        ),
        Streaks AS (
            SELECT 
                Grp,
                COUNT(*) AS StreakLength
            FROM DailyActivity
            GROUP BY Grp
        )
        SELECT 
            @LongestStreak = MAX(StreakLength),
            @ConsecutiveActiveDays = ISNULL((
                SELECT TOP 1 StreakLength 
                FROM Streaks 
                ORDER BY Grp DESC
            ), 0)
        FROM Streaks;
        
        -- Normalize (15 days active = 50 points, 25+ = 100)
        SET @ConsistencyScore = CASE 
            WHEN @DaysActiveLast30 >= 25 THEN 100
            WHEN @DaysActiveLast30 > 0 THEN (@DaysActiveLast30 * 4.0)
            ELSE 0
        END;
        
        -- ========================================================================
        -- 5. QUALITY SCORE (10% weight)
        -- ========================================================================
        -- Avg likes per post, trending content count
        SELECT @TrendingPostsCount = COUNT(DISTINCT ContentPublicId)
        FROM ContentDailyStats
        WHERE AuthorAuthUid = @AuthUid
            AND StatDate >= @Last30Days
            AND IsTrending = 1;
        
        -- Calculate avg engagement per content
        SELECT 
            @AvgLikesPerPost = AVG(CAST(LikeCount AS DECIMAL(10,2))),
            @AvgCommentsPerPost = AVG(CAST(CommentCount AS DECIMAL(10,2)))
        FROM ContentDailyStats
        WHERE AuthorAuthUid = @AuthUid
            AND StatDate >= @Last30Days;
        
        -- Normalize (5 likes/post = 50 points, 20+ = 100)
        DECLARE @AvgEngagementPerPost DECIMAL(10,2) = 
            ISNULL(@AvgLikesPerPost, 0) + (ISNULL(@AvgCommentsPerPost, 0) * 2);
        
        SET @QualityScore = CASE 
            WHEN @AvgEngagementPerPost >= 20 THEN 100
            WHEN @AvgEngagementPerPost > 0 THEN @AvgEngagementPerPost * 5
            ELSE 0
        END;
        
        -- Add bonus for trending posts
        SET @QualityScore = @QualityScore + (@TrendingPostsCount * 10);
        IF @QualityScore > 100 SET @QualityScore = 100;
        
        -- ========================================================================
        -- CALCULATE TOTAL WEIGHTED SCORE
        -- ========================================================================
        DECLARE @TotalEngagementScore DECIMAL(10,2) = 
            (@ContentCreationScore * 0.30) +
            (@InteractionScore * 0.25) +
            (@SocialGraphScore * 0.20) +
            (@ConsistencyScore * 0.15) +
            (@QualityScore * 0.10);
        
        -- Determine score tier
        DECLARE @ScoreTier NVARCHAR(20) = CASE 
            WHEN @TotalEngagementScore >= 80 THEN 'ELITE'
            WHEN @TotalEngagementScore >= 60 THEN 'HIGH'
            WHEN @TotalEngagementScore >= 30 THEN 'MEDIUM'
            WHEN @TotalEngagementScore >= 10 THEN 'LOW'
            ELSE 'INACTIVE'
        END;
        
        -- Get previous score for trend calculation
        DECLARE @PreviousScore DECIMAL(10,2);
        SELECT @PreviousScore = TotalEngagementScore
        FROM UserEngagementScore
        WHERE AuthUid = @AuthUid;
        
        DECLARE @ScoreChange DECIMAL(10,2) = @TotalEngagementScore - ISNULL(@PreviousScore, 0);
        
        -- ========================================================================
        -- UPSERT INTO UserEngagementScore
        -- ========================================================================
        MERGE INTO UserEngagementScore AS target
        USING (SELECT @AuthUid AS AuthUid) AS source
        ON target.AuthUid = source.AuthUid
        WHEN MATCHED THEN
            UPDATE SET
                ContentCreationScore = @ContentCreationScore,
                InteractionScore = @InteractionScore,
                SocialGraphScore = @SocialGraphScore,
                ConsistencyScore = @ConsistencyScore,
                QualityScore = @QualityScore,
                TotalEngagementScore = @TotalEngagementScore,
                ScoreTier = @ScoreTier,
                AvgDailyPosts = @AvgDailyPosts,
                AvgDailyLikes = @AvgDailyLikes,
                AvgDailyComments = @AvgDailyComments,
                TotalFollowers = @TotalFollowers,
                TotalFollowing = @TotalFollowing,
                DaysActiveLast30 = @DaysActiveLast30,
                ConsecutiveActiveDays = @ConsecutiveActiveDays,
                LongestStreak = @LongestStreak,
                LastActiveDate = @LastActiveDate,
                AvgLikesPerPost = @AvgLikesPerPost,
                AvgCommentsPerPost = @AvgCommentsPerPost,
                TrendingPostsCount = @TrendingPostsCount,
                CalculatedAt = GETUTCDATE(),
                PreviousScore = @PreviousScore,
                ScoreChange = @ScoreChange,
                UpdatedAt = GETUTCDATE()
        WHEN NOT MATCHED THEN
            INSERT (
                AuthUid, ContentCreationScore, InteractionScore, SocialGraphScore,
                ConsistencyScore, QualityScore, TotalEngagementScore, ScoreTier,
                AvgDailyPosts, AvgDailyLikes, AvgDailyComments,
                TotalFollowers, TotalFollowing,
                DaysActiveLast30, ConsecutiveActiveDays, LongestStreak, LastActiveDate,
                AvgLikesPerPost, AvgCommentsPerPost, TrendingPostsCount,
                CalculatedAt, PreviousScore, ScoreChange
            )
            VALUES (
                @AuthUid, @ContentCreationScore, @InteractionScore, @SocialGraphScore,
                @ConsistencyScore, @QualityScore, @TotalEngagementScore, @ScoreTier,
                @AvgDailyPosts, @AvgDailyLikes, @AvgDailyComments,
                @TotalFollowers, @TotalFollowing,
                @DaysActiveLast30, @ConsecutiveActiveDays, @LongestStreak, @LastActiveDate,
                @AvgLikesPerPost, @AvgCommentsPerPost, @TrendingPostsCount,
                GETUTCDATE(), NULL, 0
            );
        
        -- Return results
        SELECT 
            @AuthUid AS AuthUid,
            @TotalEngagementScore AS TotalEngagementScore,
            @ScoreTier AS ScoreTier,
            @ContentCreationScore AS ContentCreationScore,
            @InteractionScore AS InteractionScore,
            @SocialGraphScore AS SocialGraphScore,
            @ConsistencyScore AS ConsistencyScore,
            @QualityScore AS QualityScore,
            @ScoreChange AS ScoreChange,
            @DaysActiveLast30 AS DaysActiveLast30,
            @ConsecutiveActiveDays AS ConsecutiveActiveDays,
            'Engagement score calculated successfully' AS Message;
        
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END
GO
