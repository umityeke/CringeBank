-- =============================================
-- Notifications Tables - SQL Schema
-- =============================================
-- Purpose: Store push notifications history and read status
-- Strategy: Dual-write with Firestore, SQL for analytics and history
-- Author: Cringe Bank SQL Migration Team
-- Date: 2025-10-09
-- =============================================

USE CringeBankDB;
GO

-- =============================================
-- Table: Notifications
-- =============================================
-- Stores all push notifications sent to users
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Notifications')
BEGIN
    CREATE TABLE Notifications (
        NotificationId BIGINT IDENTITY(1,1) PRIMARY KEY,
        NotificationPublicId NVARCHAR(50) NOT NULL UNIQUE,
        RecipientAuthUid NVARCHAR(128) NOT NULL,
        SenderAuthUid NVARCHAR(128) NULL, -- NULL for system notifications
        NotificationType NVARCHAR(50) NOT NULL, -- 'POST_LIKE', 'NEW_FOLLOWER', 'COMMENT', 'DM', 'SYSTEM', etc.
        Title NVARCHAR(200) NOT NULL,
        Body NVARCHAR(1000) NOT NULL,
        ActionUrl NVARCHAR(500) NULL, -- Deep link URL (e.g., /post/{postId})
        ImageUrl NVARCHAR(500) NULL, -- Notification image (e.g., sender's avatar)
        MetadataJson NVARCHAR(MAX) NULL, -- Additional data (postId, commentId, etc.)
        IsRead BIT NOT NULL DEFAULT 0,
        IsPushed BIT NOT NULL DEFAULT 0, -- Whether FCM push was sent
        CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        ReadAt DATETIME2 NULL,
        PushedAt DATETIME2 NULL,
        
        CONSTRAINT CK_Notifications_NotificationType CHECK (
            NotificationType IN (
                'POST_LIKE', 'POST_COMMENT', 'COMMENT_REPLY',
                'NEW_FOLLOWER', 'FOLLOW_REQUEST_ACCEPTED',
                'MENTION', 'DM_NEW_MESSAGE',
                'SYSTEM_ANNOUNCEMENT', 'SYSTEM_UPDATE', 'SYSTEM_WARNING'
            )
        )
    );

    -- Add extended properties for documentation
    EXEC sys.sp_addextendedproperty 
        @name=N'MS_Description', 
        @value=N'Push notifications table - stores all notifications sent to users' , 
        @level0type=N'SCHEMA',@level0name=N'dbo', 
        @level1type=N'TABLE',@level1name=N'Notifications';

    PRINT 'Table Notifications created successfully.';
END
ELSE
BEGIN
    PRINT 'Table Notifications already exists.';
END
GO

-- =============================================
-- Indexes for Notifications
-- =============================================

-- Index for notification lookup by public ID
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Notifications_PublicId' AND object_id = OBJECT_ID('Notifications'))
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX IX_Notifications_PublicId
    ON Notifications(NotificationPublicId);
    PRINT 'Index IX_Notifications_PublicId created.';
END

-- Index for user's notifications (most important query)
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Notifications_Recipient' AND object_id = OBJECT_ID('Notifications'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Notifications_Recipient
    ON Notifications(RecipientAuthUid, CreatedAt DESC)
    INCLUDE (NotificationPublicId, SenderAuthUid, NotificationType, Title, Body, IsRead);
    PRINT 'Index IX_Notifications_Recipient created.';
END

-- Index for unread count queries (badge count)
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Notifications_Unread' AND object_id = OBJECT_ID('Notifications'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Notifications_Unread
    ON Notifications(RecipientAuthUid, IsRead, CreatedAt DESC);
    PRINT 'Index IX_Notifications_Unread created.';
END

-- Index for push status tracking (retry failed pushes)
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Notifications_PushStatus' AND object_id = OBJECT_ID('Notifications'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Notifications_PushStatus
    ON Notifications(IsPushed, CreatedAt DESC)
    WHERE IsPushed = 0; -- Filtered index for unpushed notifications
    PRINT 'Index IX_Notifications_PushStatus created.';
END

-- Index for sender's sent notifications (analytics)
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Notifications_Sender' AND object_id = OBJECT_ID('Notifications'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Notifications_Sender
    ON Notifications(SenderAuthUid, CreatedAt DESC)
    WHERE SenderAuthUid IS NOT NULL; -- Filtered index (excludes system notifications)
    PRINT 'Index IX_Notifications_Sender created.';
END

-- Index for notification type analytics
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Notifications_Type' AND object_id = OBJECT_ID('Notifications'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Notifications_Type
    ON Notifications(NotificationType, CreatedAt DESC);
    PRINT 'Index IX_Notifications_Type created.';
END

GO

PRINT '========================================';
PRINT 'Notifications table and indexes created successfully!';
PRINT 'Tables: Notifications';
PRINT 'Total Indexes: 6';
PRINT '========================================';
GO
