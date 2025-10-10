-- =============================================================================
-- Stored Procedure: sp_Analytics_GetFollowSuggestions
-- =============================================================================
-- Purpose: Generate personalized follow suggestions based on mutual connections
--          and similar interests
-- Author: CringeBank Analytics Team
-- Date: 2025-10-09
-- =============================================================================

CREATE OR ALTER PROCEDURE sp_Analytics_GetFollowSuggestions
    @AuthUid NVARCHAR(128),
    @Limit INT = 10
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
        
        IF @Limit IS NULL OR @Limit < 1
        BEGIN
            SET @Limit = 10;
        END
        
        IF @Limit > 50
        BEGIN
            SET @Limit = 50;
        END
        
        -- Temporary table for suggestions with scores
        CREATE TABLE #Suggestions (
            SuggestedAuthUid NVARCHAR(128),
            RecommendationScore DECIMAL(10,2),
            MutualConnectionCount INT,
            EngagementScore DECIMAL(10,2),
            ReasonCode NVARCHAR(50)
        );
        
        -- ========================================================================
        -- STRATEGY 1: Users with similar engagement patterns
        -- ========================================================================
        -- Get user's engagement tier
        DECLARE @UserTier NVARCHAR(20);
        SELECT @UserTier = ScoreTier
        FROM UserEngagementScore
        WHERE AuthUid = @AuthUid;
        
        -- Find users in same tier with high engagement scores
        INSERT INTO #Suggestions (SuggestedAuthUid, RecommendationScore, EngagementScore, ReasonCode)
        SELECT TOP 20
            ues.AuthUid,
            ues.TotalEngagementScore * 0.6 AS RecommendationScore, -- 60% weight
            ues.TotalEngagementScore,
            'SIMILAR_ENGAGEMENT'
        FROM UserEngagementScore ues
        WHERE ues.ScoreTier = @UserTier
            AND ues.AuthUid != @AuthUid
            AND ues.LastActiveDate >= CAST(DATEADD(DAY, -7, GETUTCDATE()) AS DATE) -- Active in last 7 days
            AND NOT EXISTS (
                SELECT 1 FROM #Suggestions s WHERE s.SuggestedAuthUid = ues.AuthUid
            )
        ORDER BY ues.TotalEngagementScore DESC;
        
        -- ========================================================================
        -- STRATEGY 2: Users who interact with similar content
        -- ========================================================================
        -- Find users who engaged with same timeline events
        INSERT INTO #Suggestions (SuggestedAuthUid, RecommendationScore, ReasonCode)
        SELECT TOP 15
            ut.ViewerAuthUid,
            COUNT(DISTINCT ut.EventPublicId) * 2.0 AS RecommendationScore, -- 2 points per shared interest
            'SIMILAR_INTERESTS'
        FROM UserTimeline ut
        WHERE ut.EventPublicId IN (
            -- Events the current user viewed
            SELECT EventPublicId 
            FROM UserTimeline 
            WHERE ViewerAuthUid = @AuthUid
                AND CreatedAt >= DATEADD(DAY, -30, GETUTCDATE())
        )
            AND ut.ViewerAuthUid != @AuthUid
            AND NOT EXISTS (
                SELECT 1 FROM #Suggestions s WHERE s.SuggestedAuthUid = ut.ViewerAuthUid
            )
        GROUP BY ut.ViewerAuthUid
        HAVING COUNT(DISTINCT ut.EventPublicId) >= 3 -- At least 3 common interests
        ORDER BY COUNT(DISTINCT ut.EventPublicId) DESC;
        
        -- ========================================================================
        -- STRATEGY 3: Active content creators in user's niche
        -- ========================================================================
        -- Find users who create trending content
        INSERT INTO #Suggestions (SuggestedAuthUid, RecommendationScore, ReasonCode)
        SELECT TOP 10
            c.AuthorAuthUid,
            SUM(c.TrendingScore) / 10.0 AS RecommendationScore, -- Normalize trending score
            'TRENDING_CREATOR'
        FROM ContentDailyStats c
        WHERE c.IsTrending = 1
            AND c.StatDate >= CAST(DATEADD(DAY, -7, GETUTCDATE()) AS DATE)
            AND c.AuthorAuthUid != @AuthUid
            AND NOT EXISTS (
                SELECT 1 FROM #Suggestions s WHERE s.SuggestedAuthUid = c.AuthorAuthUid
            )
        GROUP BY c.AuthorAuthUid
        HAVING COUNT(*) >= 2 -- At least 2 trending posts
        ORDER BY SUM(c.TrendingScore) DESC;
        
        -- ========================================================================
        -- STRATEGY 4: Users with consistent activity
        -- ========================================================================
        -- Find consistently active users
        INSERT INTO #Suggestions (SuggestedAuthUid, RecommendationScore, ReasonCode)
        SELECT TOP 10
            ues.AuthUid,
            (ues.ConsecutiveActiveDays * 2.0) + (ues.DaysActiveLast30 * 1.0) AS RecommendationScore,
            'CONSISTENT_CREATOR'
        FROM UserEngagementScore ues
        WHERE ues.ConsecutiveActiveDays >= 7
            AND ues.AuthUid != @AuthUid
            AND NOT EXISTS (
                SELECT 1 FROM #Suggestions s WHERE s.SuggestedAuthUid = ues.AuthUid
            )
        ORDER BY ues.ConsecutiveActiveDays DESC, ues.DaysActiveLast30 DESC;
        
        -- ========================================================================
        -- AGGREGATE AND RANK SUGGESTIONS
        -- ========================================================================
        -- Combine all strategies and calculate final scores
        SELECT TOP (@Limit)
            s.SuggestedAuthUid AS AuthUid,
            SUM(s.RecommendationScore) AS TotalScore,
            MAX(s.EngagementScore) AS EngagementScore,
            MAX(s.MutualConnectionCount) AS MutualConnections,
            STRING_AGG(s.ReasonCode, ', ') AS RecommendationReasons,
            COUNT(*) AS ReasonCount -- Number of different reasons
        FROM #Suggestions s
        GROUP BY s.SuggestedAuthUid
        ORDER BY 
            SUM(s.RecommendationScore) DESC,
            COUNT(*) DESC, -- Prefer users who match multiple criteria
            MAX(s.EngagementScore) DESC;
        
        -- Cleanup
        DROP TABLE #Suggestions;
        
    END TRY
    BEGIN CATCH
        -- Cleanup on error
        IF OBJECT_ID('tempdb..#Suggestions') IS NOT NULL
            DROP TABLE #Suggestions;
        
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END
GO
