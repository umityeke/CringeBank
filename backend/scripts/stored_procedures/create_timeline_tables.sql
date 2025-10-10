-- =============================================
-- Timeline SQL Tables
-- =============================================
-- Purpose: Store timeline/feed events with fan-out on write pattern
-- Strategy: Dual-write (Firestore critical path, SQL analytics)
-- Created: 2025-10-09
-- =============================================

USE CringeBankDb;
GO

-- =============================================
-- Table: TimelineEvents
-- Description: Master table of all timeline events
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'TimelineEvents')
BEGIN
    CREATE TABLE TimelineEvents (
        EventId BIGINT IDENTITY(1,1) PRIMARY KEY,
        EventPublicId NVARCHAR(50) NOT NULL UNIQUE,
        ActorAuthUid NVARCHAR(128) NOT NULL,
        EventType NVARCHAR(50) NOT NULL, -- 'POST_CREATED', 'USER_FOLLOWED', 'COMMENT_ADDED', etc.
        EntityType NVARCHAR(50) NOT NULL, -- 'post', 'user', 'comment', etc.
        EntityId NVARCHAR(128) NOT NULL,
        MetadataJson NVARCHAR(MAX) NULL, -- Additional event data (post preview, user info, etc.)
        CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        IsDeleted BIT NOT NULL DEFAULT 0,
        DeletedAt DATETIME2 NULL
    );

    CREATE INDEX IX_TimelineEvents_Actor ON TimelineEvents(ActorAuthUid, CreatedAt DESC);
    CREATE INDEX IX_TimelineEvents_Entity ON TimelineEvents(EntityType, EntityId, CreatedAt DESC);
    CREATE INDEX IX_TimelineEvents_Type ON TimelineEvents(EventType, CreatedAt DESC);
    CREATE INDEX IX_TimelineEvents_PublicId ON TimelineEvents(EventPublicId);

    EXEC sys.sp_addextendedproperty 
        @name = N'MS_Description',
        @value = N'Master timeline events table. Stores all events before fan-out to user timelines.',
        @level0type = N'SCHEMA', @level0name = N'dbo',
        @level1type = N'TABLE', @level1name = N'TimelineEvents';

    PRINT 'Table TimelineEvents created successfully';
END
ELSE
BEGIN
    PRINT 'Table TimelineEvents already exists';
END
GO

-- =============================================
-- Table: UserTimeline
-- Description: Fan-out table - each user's personalized timeline
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'UserTimeline')
BEGIN
    CREATE TABLE UserTimeline (
        TimelineId BIGINT IDENTITY(1,1) PRIMARY KEY,
        ViewerAuthUid NVARCHAR(128) NOT NULL, -- User who sees this event in their feed
        EventId BIGINT NOT NULL,
        EventPublicId NVARCHAR(50) NOT NULL,
        ActorAuthUid NVARCHAR(128) NOT NULL,
        EventType NVARCHAR(50) NOT NULL,
        EntityType NVARCHAR(50) NOT NULL,
        EntityId NVARCHAR(128) NOT NULL,
        IsRead BIT NOT NULL DEFAULT 0,
        IsHidden BIT NOT NULL DEFAULT 0, -- User can hide events from their feed
        CreatedAt DATETIME2 NOT NULL,
        ReadAt DATETIME2 NULL,
        
        FOREIGN KEY (EventId) REFERENCES TimelineEvents(EventId)
    );

    CREATE INDEX IX_UserTimeline_Viewer ON UserTimeline(ViewerAuthUid, CreatedAt DESC);
    CREATE INDEX IX_UserTimeline_ViewerUnread ON UserTimeline(ViewerAuthUid, IsRead, CreatedAt DESC);
    CREATE INDEX IX_UserTimeline_Event ON UserTimeline(EventId, ViewerAuthUid);
    CREATE INDEX IX_UserTimeline_PublicId ON UserTimeline(EventPublicId, ViewerAuthUid);

    EXEC sys.sp_addextendedproperty 
        @name = N'MS_Description',
        @value = N'User-specific timeline entries. Fan-out pattern: one event creates multiple rows (one per follower).',
        @level0type = N'SCHEMA', @level0name = N'dbo',
        @level1type = N'TABLE', @level1name = N'UserTimeline';

    PRINT 'Table UserTimeline created successfully';
END
ELSE
BEGIN
    PRINT 'Table UserTimeline already exists';
END
GO

-- =============================================
-- Table: UserFollows
-- Description: User follow relationships for timeline fan-out
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'UserFollows')
BEGIN
    CREATE TABLE UserFollows (
        FollowId BIGINT IDENTITY(1,1) PRIMARY KEY,
        FollowerAuthUid NVARCHAR(128) NOT NULL, -- User who follows
        FollowedAuthUid NVARCHAR(128) NOT NULL, -- User being followed
        CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        IsActive BIT NOT NULL DEFAULT 1,
        UnfollowedAt DATETIME2 NULL,
        
        UNIQUE (FollowerAuthUid, FollowedAuthUid)
    );

    CREATE INDEX IX_UserFollows_Follower ON UserFollows(FollowerAuthUid, IsActive, CreatedAt DESC);
    CREATE INDEX IX_UserFollows_Followed ON UserFollows(FollowedAuthUid, IsActive, CreatedAt DESC);
    CREATE INDEX IX_UserFollows_Active ON UserFollows(IsActive, FollowerAuthUid, FollowedAuthUid);

    EXEC sys.sp_addextendedproperty 
        @name = N'MS_Description',
        @value = N'User follow relationships. Used for timeline fan-out: when user posts, fans out to all followers.',
        @level0type = N'SCHEMA', @level0name = N'dbo',
        @level1type = N'TABLE', @level1name = N'UserFollows';

    PRINT 'Table UserFollows created successfully';
END
ELSE
BEGIN
    PRINT 'Table UserFollows already exists';
END
GO

-- =============================================
-- Sample Data Verification
-- =============================================
PRINT '';
PRINT '==============================================';
PRINT 'Timeline Tables Created Successfully';
PRINT '==============================================';
PRINT 'Tables:';
PRINT '  - TimelineEvents: Master events table';
PRINT '  - UserTimeline: Fan-out timeline entries';
PRINT '  - UserFollows: Follow relationships';
PRINT '';
PRINT 'Next Steps:';
PRINT '  1. Create stored procedures (sp_Timeline_CreateEvent, sp_Timeline_GetUserFeed)';
PRINT '  2. Update Firestore triggers for dual-write';
PRINT '  3. Run migration script to backfill existing events';
PRINT '==============================================';
GO
