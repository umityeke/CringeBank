-- =============================================
-- Direct Messaging Tables
-- Created: 2025-10-09
-- Purpose: Store user-to-user messages with real-time sync
-- =============================================

-- Messages Table: Individual messages
CREATE TABLE Messages (
    MessageId BIGINT IDENTITY(1,1) PRIMARY KEY,
    MessagePublicId NVARCHAR(50) NOT NULL UNIQUE,
    ConversationId NVARCHAR(100) NOT NULL,
    SenderAuthUid NVARCHAR(128) NOT NULL,
    RecipientAuthUid NVARCHAR(128) NOT NULL,
    MessageText NVARCHAR(MAX) NULL,
    MessageType NVARCHAR(20) NOT NULL DEFAULT 'TEXT', -- TEXT, IMAGE, VOICE, SYSTEM
    ImageUrl NVARCHAR(500) NULL,
    VoiceUrl NVARCHAR(500) NULL,
    VoiceDurationSec INT NULL, -- Duration in seconds for VOICE type
    IsRead BIT NOT NULL DEFAULT 0,
    IsDeleted BIT NOT NULL DEFAULT 0,
    CreatedAt DATETIME NOT NULL DEFAULT GETUTCDATE(),
    ReadAt DATETIME NULL,
    DeletedAt DATETIME NULL,
    
    -- Indexes for performance
    INDEX IX_Messages_ConversationId (ConversationId, CreatedAt DESC),
    INDEX IX_Messages_SenderAuthUid (SenderAuthUid, CreatedAt DESC),
    INDEX IX_Messages_RecipientAuthUid (RecipientAuthUid, CreatedAt DESC),
    INDEX IX_Messages_Unread (RecipientAuthUid, IsRead, CreatedAt DESC)
);
GO

-- Conversations Table: Conversation metadata (denormalized for performance)
CREATE TABLE Conversations (
    ConversationId NVARCHAR(100) PRIMARY KEY,
    Participant1AuthUid NVARCHAR(128) NOT NULL,
    Participant2AuthUid NVARCHAR(128) NOT NULL,
    LastMessageText NVARCHAR(500) NULL,
    LastMessageAt DATETIME NULL,
    LastMessageType NVARCHAR(20) NULL, -- To show preview (e.g., "🎤 Voice message")
    UnreadCountP1 INT NOT NULL DEFAULT 0, -- Participant 1's unread count
    UnreadCountP2 INT NOT NULL DEFAULT 0, -- Participant 2's unread count
    IsArchivedP1 BIT NOT NULL DEFAULT 0, -- Participant 1 archived conversation
    IsArchivedP2 BIT NOT NULL DEFAULT 0, -- Participant 2 archived conversation
    CreatedAt DATETIME NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME NOT NULL DEFAULT GETUTCDATE(),
    
    -- Indexes for conversation list queries
    INDEX IX_Conversations_Participant1 (Participant1AuthUid, UpdatedAt DESC),
    INDEX IX_Conversations_Participant2 (Participant2AuthUid, UpdatedAt DESC),
    INDEX IX_Conversations_Unread_P1 (Participant1AuthUid, UnreadCountP1),
    INDEX IX_Conversations_Unread_P2 (Participant2AuthUid, UnreadCountP2)
);
GO

-- Add comments for documentation
EXEC sys.sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Stores individual messages between users. Synced with Firestore for real-time updates.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'TABLE',  @level1name = N'Messages';
GO

EXEC sys.sp_addextendedproperty 
    @name = N'MS_Description', 
    @value = N'Denormalized conversation metadata for fast conversation list queries.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'TABLE',  @level1name = N'Conversations';
GO

PRINT 'DM tables created successfully';
