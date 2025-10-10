-- =============================================
-- Stored Procedure: sp_Timeline_CreateEvent
-- =============================================
-- Purpose: Create timeline event and fan-out to followers
-- Strategy: Insert event + fan-out to UserTimeline for all followers
-- =============================================

USE CringeBankDb;
GO

IF OBJECT_ID('sp_Timeline_CreateEvent', 'P') IS NOT NULL
    DROP PROCEDURE sp_Timeline_CreateEvent;
GO

CREATE PROCEDURE sp_Timeline_CreateEvent
    @EventPublicId NVARCHAR(50),
    @ActorAuthUid NVARCHAR(128),
    @EventType NVARCHAR(50),
    @EntityType NVARCHAR(50),
    @EntityId NVARCHAR(128),
    @MetadataJson NVARCHAR(MAX) = NULL,
    @FanOutToFollowers BIT = 1 -- If true, fan-out to followers; if false, only create event
AS
BEGIN
    SET NOCOUNT ON;

    -- Validation
    IF @EventPublicId IS NULL OR LEN(@EventPublicId) = 0
    BEGIN
        RAISERROR('EventPublicId is required', 16, 1);
        RETURN;
    END

    IF @ActorAuthUid IS NULL OR LEN(@ActorAuthUid) = 0
    BEGIN
        RAISERROR('ActorAuthUid is required', 16, 1);
        RETURN;
    END

    IF @EventType IS NULL OR LEN(@EventType) = 0
    BEGIN
        RAISERROR('EventType is required', 16, 1);
        RETURN;
    END

    IF @EntityType IS NULL OR LEN(@EntityType) = 0
    BEGIN
        RAISERROR('EntityType is required', 16, 1);
        RETURN;
    END

    IF @EntityId IS NULL OR LEN(@EntityId) = 0
    BEGIN
        RAISERROR('EntityId is required', 16, 1);
        RETURN;
    END

    DECLARE @EventId BIGINT;
    DECLARE @CreatedAt DATETIME2 = GETUTCDATE();
    DECLARE @FannedOutCount INT = 0;

    BEGIN TRANSACTION;

    BEGIN TRY
        -- Insert event into TimelineEvents
        INSERT INTO TimelineEvents (
            EventPublicId,
            ActorAuthUid,
            EventType,
            EntityType,
            EntityId,
            MetadataJson,
            CreatedAt,
            IsDeleted,
            DeletedAt
        )
        VALUES (
            @EventPublicId,
            @ActorAuthUid,
            @EventType,
            @EntityType,
            @EntityId,
            @MetadataJson,
            @CreatedAt,
            0,
            NULL
        );

        SET @EventId = SCOPE_IDENTITY();

        -- Fan-out to followers if requested
        IF @FanOutToFollowers = 1
        BEGIN
            -- Insert into UserTimeline for all active followers
            INSERT INTO UserTimeline (
                ViewerAuthUid,
                EventId,
                EventPublicId,
                ActorAuthUid,
                EventType,
                EntityType,
                EntityId,
                IsRead,
                IsHidden,
                CreatedAt,
                ReadAt
            )
            SELECT
                FollowerAuthUid, -- Follower sees this event
                @EventId,
                @EventPublicId,
                @ActorAuthUid,
                @EventType,
                @EntityType,
                @EntityId,
                0, -- IsRead = false
                0, -- IsHidden = false
                @CreatedAt,
                NULL -- ReadAt = null
            FROM UserFollows
            WHERE FollowedAuthUid = @ActorAuthUid
              AND IsActive = 1;

            SET @FannedOutCount = @@ROWCOUNT;

            -- Also add to actor's own timeline (user sees their own posts)
            INSERT INTO UserTimeline (
                ViewerAuthUid,
                EventId,
                EventPublicId,
                ActorAuthUid,
                EventType,
                EntityType,
                EntityId,
                IsRead,
                IsHidden,
                CreatedAt,
                ReadAt
            )
            VALUES (
                @ActorAuthUid, -- Actor sees their own event
                @EventId,
                @EventPublicId,
                @ActorAuthUid,
                @EventType,
                @EntityType,
                @EntityId,
                1, -- Mark as read (actor already knows)
                0,
                @CreatedAt,
                @CreatedAt
            );

            SET @FannedOutCount = @FannedOutCount + 1;
        END

        COMMIT TRANSACTION;

        -- Return success
        SELECT 
            @EventId AS EventId,
            @EventPublicId AS EventPublicId,
            @FannedOutCount AS FannedOutCount,
            @CreatedAt AS CreatedAt,
            'Event created successfully' AS Message;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();

        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END
GO

PRINT 'Stored procedure sp_Timeline_CreateEvent created successfully';
GO
