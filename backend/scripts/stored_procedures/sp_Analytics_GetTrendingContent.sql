-- =============================================================================
-- Stored Procedure: sp_Analytics_GetTrendingContent
-- =============================================================================
-- Purpose: Get trending content based on engagement velocity and scores
-- Author: CringeBank Analytics Team
-- Date: 2025-10-09
-- =============================================================================

CREATE OR ALTER PROCEDURE sp_Analytics_GetTrendingContent
    @ContentType NVARCHAR(50) = NULL, -- Filter by type, NULL for all
    @Limit INT = 20,
    @MinTrendingScore DECIMAL(10,2) = 50.0,
    @TimeWindowHours INT = 24 -- Look at content from last N hours
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        -- Validate limit
        IF @Limit IS NULL OR @Limit < 1
        BEGIN
            SET @Limit = 20;
        END
        
        IF @Limit > 100
        BEGIN
            SET @Limit = 100;
        END
        
        DECLARE @CutoffDate DATETIME2 = DATEADD(HOUR, -@TimeWindowHours, GETUTCDATE());
        
        -- Get trending content
        SELECT TOP (@Limit)
            c.ContentType,
            c.ContentPublicId,
            c.AuthorAuthUid,
            c.StatDate,
            c.ViewCount,
            c.UniqueViewers,
            c.LikeCount,
            c.CommentCount,
            c.ShareCount,
            c.EngagementVelocity,
            c.TrendingScore,
            c.IsTrending,
            c.UpdatedAt
        FROM ContentDailyStats c
        WHERE c.IsTrending = 1
            AND c.TrendingScore >= @MinTrendingScore
            AND c.UpdatedAt >= @CutoffDate
            AND (@ContentType IS NULL OR c.ContentType = @ContentType)
        ORDER BY 
            c.TrendingScore DESC,
            c.EngagementVelocity DESC;
        
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END
GO
