-- =============================================================================
-- Stored Procedure: sp_Analytics_AggregateUserDaily
-- =============================================================================
-- Purpose: Aggregate user activity metrics for a specific date
-- Author: CringeBank Analytics Team
-- Date: 2025-10-09
-- =============================================================================

CREATE OR ALTER PROCEDURE sp_Analytics_AggregateUserDaily
    @AuthUid NVARCHAR(128),
    @TargetDate DATE
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
        
        IF @TargetDate IS NULL
        BEGIN
            SET @TargetDate = CAST(GETUTCDATE() AS DATE);
        END
        
        DECLARE @StartDate DATETIME2 = CAST(@TargetDate AS DATETIME2);
        DECLARE @EndDate DATETIME2 = DATEADD(DAY, 1, @StartDate);
        
        -- Temporary variables for metrics
        DECLARE @PostsCreated INT = 0;
        DECLARE @PostLikesReceived INT = 0;
        DECLARE @PostCommentsReceived INT = 0;
        DECLARE @PostSharesReceived INT = 0;
        DECLARE @LikesGiven INT = 0;
        DECLARE @CommentsGiven INT = 0;
        DECLARE @SharesGiven INT = 0;
        DECLARE @MessagesReceived INT = 0;
        DECLARE @MessagesSent INT = 0;
        DECLARE @ConversationsStarted INT = 0;
        DECLARE @TimelineEventsCreated INT = 0;
        DECLARE @TimelineEventsViewed INT = 0;
        DECLARE @NotificationsReceived INT = 0;
        DECLARE @NotificationsRead INT = 0;
        DECLARE @NewFollowers INT = 0;
        DECLARE @NewFollowing INT = 0;
        DECLARE @EngagementScore DECIMAL(10,2) = 0.0;
        DECLARE @IsActive BIT = 0;
        
        -- Count messages received
        SELECT @MessagesReceived = COUNT(*)
        FROM Messages
        WHERE RecipientAuthUid = @AuthUid
            AND CreatedAt >= @StartDate 
            AND CreatedAt < @EndDate;
        
        -- Count messages sent
        SELECT @MessagesSent = COUNT(*)
        FROM Messages
        WHERE SenderAuthUid = @AuthUid
            AND CreatedAt >= @StartDate 
            AND CreatedAt < @EndDate;
        
        -- Count conversations started (first message in conversation)
        SELECT @ConversationsStarted = COUNT(DISTINCT c.ConversationId)
        FROM Conversations c
        WHERE c.CreatedByAuthUid = @AuthUid
            AND c.CreatedAt >= @StartDate 
            AND c.CreatedAt < @EndDate;
        
        -- Count timeline events created
        SELECT @TimelineEventsCreated = COUNT(*)
        FROM TimelineEvents
        WHERE ActorAuthUid = @AuthUid
            AND CreatedAt >= @StartDate 
            AND CreatedAt < @EndDate;
        
        -- Count timeline events viewed (from UserTimeline)
        SELECT @TimelineEventsViewed = COUNT(*)
        FROM UserTimeline
        WHERE ViewerAuthUid = @AuthUid
            AND CreatedAt >= @StartDate 
            AND CreatedAt < @EndDate;
        
        -- Count notifications received
        SELECT @NotificationsReceived = COUNT(*)
        FROM Notifications
        WHERE RecipientAuthUid = @AuthUid
            AND CreatedAt >= @StartDate 
            AND CreatedAt < @EndDate;
        
        -- Count notifications read
        SELECT @NotificationsRead = COUNT(*)
        FROM Notifications
        WHERE RecipientAuthUid = @AuthUid
            AND ReadAt >= @StartDate 
            AND ReadAt < @EndDate
            AND IsRead = 1;
        
        -- Calculate engagement score (simple formula)
        -- Posts * 10 + Messages * 3 + Timeline * 2 + Notifications Read * 1
        SET @EngagementScore = 
            (@PostsCreated * 10.0) +
            (@MessagesSent * 3.0) +
            (@TimelineEventsCreated * 2.0) +
            (@NotificationsRead * 1.0) +
            (@LikesGiven * 0.5) +
            (@CommentsGiven * 1.5);
        
        -- Check if user was active (any activity)
        IF (@PostsCreated > 0 OR @MessagesSent > 0 OR @TimelineEventsCreated > 0 OR 
            @LikesGiven > 0 OR @CommentsGiven > 0 OR @NotificationsRead > 0)
        BEGIN
            SET @IsActive = 1;
        END
        
        -- Upsert into UserDailyStats
        MERGE INTO UserDailyStats AS target
        USING (SELECT @AuthUid AS AuthUid, @TargetDate AS StatDate) AS source
        ON target.AuthUid = source.AuthUid AND target.StatDate = source.StatDate
        WHEN MATCHED THEN
            UPDATE SET
                PostsCreated = @PostsCreated,
                PostLikesReceived = @PostLikesReceived,
                PostCommentsReceived = @PostCommentsReceived,
                PostSharesReceived = @PostSharesReceived,
                LikesGiven = @LikesGiven,
                CommentsGiven = @CommentsGiven,
                SharesGiven = @SharesGiven,
                MessagesReceived = @MessagesReceived,
                MessagesSent = @MessagesSent,
                ConversationsStarted = @ConversationsStarted,
                TimelineEventsCreated = @TimelineEventsCreated,
                TimelineEventsViewed = @TimelineEventsViewed,
                NotificationsReceived = @NotificationsReceived,
                NotificationsRead = @NotificationsRead,
                EngagementScore = @EngagementScore,
                IsActive = @IsActive,
                UpdatedAt = GETUTCDATE()
        WHEN NOT MATCHED THEN
            INSERT (
                AuthUid, StatDate, PostsCreated, PostLikesReceived, PostCommentsReceived,
                PostSharesReceived, LikesGiven, CommentsGiven, SharesGiven,
                MessagesReceived, MessagesSent, ConversationsStarted,
                TimelineEventsCreated, TimelineEventsViewed,
                NotificationsReceived, NotificationsRead,
                EngagementScore, IsActive
            )
            VALUES (
                @AuthUid, @TargetDate, @PostsCreated, @PostLikesReceived, @PostCommentsReceived,
                @PostSharesReceived, @LikesGiven, @CommentsGiven, @SharesGiven,
                @MessagesReceived, @MessagesSent, @ConversationsStarted,
                @TimelineEventsCreated, @TimelineEventsViewed,
                @NotificationsReceived, @NotificationsRead,
                @EngagementScore, @IsActive
            );
        
        -- Return results
        SELECT 
            @AuthUid AS AuthUid,
            @TargetDate AS StatDate,
            @EngagementScore AS EngagementScore,
            @IsActive AS IsActive,
            @MessagesReceived AS MessagesReceived,
            @MessagesSent AS MessagesSent,
            @TimelineEventsCreated AS TimelineEventsCreated,
            'User daily stats aggregated successfully' AS Message;
        
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END
GO
