-- =============================================
-- Stored Procedure: sp_Timeline_GetUserFeed
-- =============================================
-- Purpose: Get user's timeline feed with pagination
-- Returns: Timeline events visible to the user
-- =============================================

USE CringeBankDb;
GO

IF OBJECT_ID('sp_Timeline_GetUserFeed', 'P') IS NOT NULL
    DROP PROCEDURE sp_Timeline_GetUserFeed;
GO

CREATE PROCEDURE sp_Timeline_GetUserFeed
    @ViewerAuthUid NVARCHAR(128),
    @Limit INT = 50,
    @BeforeTimelineId BIGINT = NULL, -- For pagination
    @IncludeRead BIT = 1, -- Include already-read events
    @IncludeHidden BIT = 0 -- Include hidden events
AS
BEGIN
    SET NOCOUNT ON;

    -- Validation
    IF @ViewerAuthUid IS NULL OR LEN(@ViewerAuthUid) = 0
    BEGIN
        RAISERROR('ViewerAuthUid is required', 16, 1);
        RETURN;
    END

    IF @Limit > 100
    BEGIN
        RAISERROR('Limit cannot exceed 100 events', 16, 1);
        RETURN;
    END

    -- Get user's timeline feed
    SELECT TOP(@Limit)
        ut.TimelineId,
        ut.ViewerAuthUid,
        ut.EventId,
        ut.EventPublicId,
        ut.ActorAuthUid,
        ut.EventType,
        ut.EntityType,
        ut.EntityId,
        ut.IsRead,
        ut.IsHidden,
        ut.CreatedAt,
        ut.ReadAt,
        te.MetadataJson,
        te.IsDeleted AS EventIsDeleted
    FROM UserTimeline ut
    INNER JOIN TimelineEvents te ON ut.EventId = te.EventId
    WHERE ut.ViewerAuthUid = @ViewerAuthUid
      AND (@BeforeTimelineId IS NULL OR ut.TimelineId < @BeforeTimelineId)
      AND (@IncludeRead = 1 OR ut.IsRead = 0)
      AND (@IncludeHidden = 1 OR ut.IsHidden = 0)
      AND te.IsDeleted = 0 -- Don't show deleted events
    ORDER BY ut.TimelineId DESC;

END
GO

PRINT 'Stored procedure sp_Timeline_GetUserFeed created successfully';
GO
