-- =============================================================================
-- Stored Procedure: sp_Analytics_UpdateContentStats
-- =============================================================================
-- Purpose: Update trending scores and content metrics
-- Author: CringeBank Analytics Team
-- Date: 2025-10-09
-- =============================================================================

CREATE OR ALTER PROCEDURE sp_Analytics_UpdateContentStats
    @ContentType NVARCHAR(50),
    @ContentPublicId NVARCHAR(50),
    @AuthorAuthUid NVARCHAR(128),
    @TargetDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        -- Validate input
        IF @ContentType IS NULL OR @ContentPublicId IS NULL
        BEGIN
            RAISERROR('ContentType and ContentPublicId are required', 16, 1);
            RETURN;
        END
        
        IF @TargetDate IS NULL
        BEGIN
            SET @TargetDate = CAST(GETUTCDATE() AS DATE);
        END
        
        DECLARE @StartDate DATETIME2 = CAST(@TargetDate AS DATETIME2);
        DECLARE @EndDate DATETIME2 = DATEADD(DAY, 1, @StartDate);
        DECLARE @Last24h DATETIME2 = DATEADD(HOUR, -24, GETUTCDATE());
        
        -- Initialize metrics
        DECLARE @ViewCount INT = 0;
        DECLARE @UniqueViewers INT = 0;
        DECLARE @LikeCount INT = 0;
        DECLARE @CommentCount INT = 0;
        DECLARE @ShareCount INT = 0;
        DECLARE @LikesLast24h INT = 0;
        DECLARE @CommentsLast24h INT = 0;
        DECLARE @SharesLast24h INT = 0;
        DECLARE @EngagementVelocity DECIMAL(10,2) = 0.0;
        DECLARE @TrendingScore DECIMAL(10,2) = 0.0;
        DECLARE @IsTrending BIT = 0;
        
        -- For TIMELINE_EVENT content type
        IF @ContentType = 'TIMELINE_EVENT'
        BEGIN
            -- Count timeline event metrics from UserTimeline
            SELECT 
                @ViewCount = COUNT(*),
                @UniqueViewers = COUNT(DISTINCT ViewerAuthUid)
            FROM UserTimeline
            WHERE EventPublicId = @ContentPublicId
                AND CreatedAt >= @StartDate 
                AND CreatedAt < @EndDate;
            
            -- Count recent engagement (last 24h)
            SELECT @LikesLast24h = COUNT(*)
            FROM UserTimeline
            WHERE EventPublicId = @ContentPublicId
                AND CreatedAt >= @Last24h;
        END
        
        -- Calculate engagement velocity (engagements per hour in last 24h)
        DECLARE @HoursSinceCreation DECIMAL(10,2);
        SELECT @HoursSinceCreation = DATEDIFF(HOUR, MIN(CreatedAt), GETUTCDATE())
        FROM TimelineEvents
        WHERE EventPublicId = @ContentPublicId;
        
        IF @HoursSinceCreation > 0
        BEGIN
            SET @EngagementVelocity = (@LikesLast24h + @CommentsLast24h + @SharesLast24h) / 
                CASE WHEN @HoursSinceCreation > 24 THEN 24.0 ELSE @HoursSinceCreation END;
        END
        
        -- Calculate trending score
        -- Formula: (Likes * 1.0 + Comments * 2.0 + Shares * 3.0) * Velocity Weight
        DECLARE @BaseEngagement DECIMAL(10,2) = 
            (@LikeCount * 1.0) + (@CommentCount * 2.0) + (@ShareCount * 3.0);
        
        DECLARE @VelocityWeight DECIMAL(10,2) = 
            CASE 
                WHEN @EngagementVelocity > 100 THEN 3.0
                WHEN @EngagementVelocity > 50 THEN 2.0
                WHEN @EngagementVelocity > 10 THEN 1.5
                ELSE 1.0
            END;
        
        SET @TrendingScore = @BaseEngagement * @VelocityWeight;
        
        -- Mark as trending if score > threshold
        IF @TrendingScore > 100 AND @EngagementVelocity > 5
        BEGIN
            SET @IsTrending = 1;
        END
        
        -- Upsert into ContentDailyStats
        MERGE INTO ContentDailyStats AS target
        USING (
            SELECT 
                @ContentType AS ContentType,
                @ContentPublicId AS ContentPublicId,
                @AuthorAuthUid AS AuthorAuthUid,
                @TargetDate AS StatDate
        ) AS source
        ON target.ContentType = source.ContentType 
            AND target.ContentPublicId = source.ContentPublicId 
            AND target.StatDate = source.StatDate
        WHEN MATCHED THEN
            UPDATE SET
                ViewCount = @ViewCount,
                UniqueViewers = @UniqueViewers,
                LikeCount = @LikeCount,
                CommentCount = @CommentCount,
                ShareCount = @ShareCount,
                LikesLast24h = @LikesLast24h,
                CommentsLast24h = @CommentsLast24h,
                SharesLast24h = @SharesLast24h,
                EngagementVelocity = @EngagementVelocity,
                TrendingScore = @TrendingScore,
                IsTrending = @IsTrending,
                UpdatedAt = GETUTCDATE()
        WHEN NOT MATCHED THEN
            INSERT (
                ContentType, ContentPublicId, AuthorAuthUid, StatDate,
                ViewCount, UniqueViewers, LikeCount, CommentCount, ShareCount,
                LikesLast24h, CommentsLast24h, SharesLast24h,
                EngagementVelocity, TrendingScore, IsTrending
            )
            VALUES (
                @ContentType, @ContentPublicId, @AuthorAuthUid, @TargetDate,
                @ViewCount, @UniqueViewers, @LikeCount, @CommentCount, @ShareCount,
                @LikesLast24h, @CommentsLast24h, @SharesLast24h,
                @EngagementVelocity, @TrendingScore, @IsTrending
            );
        
        -- Return results
        SELECT 
            @ContentPublicId AS ContentPublicId,
            @TrendingScore AS TrendingScore,
            @EngagementVelocity AS EngagementVelocity,
            @IsTrending AS IsTrending,
            @ViewCount AS ViewCount,
            'Content stats updated successfully' AS Message;
        
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END
GO
