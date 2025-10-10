/*
  Migration: Create SQL mirror tables for direct messages and follow edges
  Usage:
    sqlcmd -S <server> -d <database> -U <user> -P <password> -b -i 20251008_07_create_dm_follow_mirror_tables.sql
*/

IF DB_ID() IS NULL
BEGIN
    RAISERROR('Database context is not set. Use the appropriate database before running this script.', 16, 1);
    RETURN;
END
GO

IF OBJECT_ID('dbo.DmConversation', 'U') IS NULL
BEGIN
    PRINT 'Creating table dbo.DmConversation';
    CREATE TABLE dbo.DmConversation
    (
        ConversationId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DmConversation PRIMARY KEY,
        FirestoreId NVARCHAR(128) NOT NULL,
        ConversationKey NVARCHAR(128) NULL,
        Type NVARCHAR(32) NOT NULL CONSTRAINT DF_DmConversation_Type DEFAULT ('direct'),
        IsGroup BIT NOT NULL CONSTRAINT DF_DmConversation_IsGroup DEFAULT (0),
        ParticipantHash VARBINARY(64) NULL,
        MemberCount INT NULL,
        MetadataJson NVARCHAR(MAX) NULL,
        ParticipantMetaJson NVARCHAR(MAX) NULL,
        ReadPointersJson NVARCHAR(MAX) NULL,
        LastMessageFirestoreId NVARCHAR(128) NULL,
        LastMessageSenderId NVARCHAR(64) NULL,
        LastMessagePreview NVARCHAR(400) NULL,
        LastMessageTimestamp DATETIMEOFFSET(3) NULL,
        CreatedAt DATETIMEOFFSET(3) NOT NULL CONSTRAINT DF_DmConversation_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedAt DATETIMEOFFSET(3) NOT NULL CONSTRAINT DF_DmConversation_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        LastEventId NVARCHAR(128) NULL,
        LastEventTimestamp DATETIMEOFFSET(3) NULL
    );
END
ELSE
BEGIN
    PRINT 'dbo.DmConversation already exists.';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.DmConversation')
      AND name = 'UX_DmConversation_FirestoreId'
)
BEGIN
    CREATE UNIQUE INDEX UX_DmConversation_FirestoreId
        ON dbo.DmConversation (FirestoreId);
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.DmConversation')
      AND name = 'IX_DmConversation_UpdatedAt'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_DmConversation_UpdatedAt
        ON dbo.DmConversation (UpdatedAt DESC)
        INCLUDE (LastMessageTimestamp, MemberCount);
END
GO

IF OBJECT_ID('dbo.DmParticipant', 'U') IS NULL
BEGIN
    PRINT 'Creating table dbo.DmParticipant';
    CREATE TABLE dbo.DmParticipant
    (
        ConversationId BIGINT NOT NULL,
        UserId NVARCHAR(64) NOT NULL,
        Role NVARCHAR(32) NULL,
        JoinedAt DATETIMEOFFSET(3) NULL,
        MuteState NVARCHAR(32) NULL,
        ReadPointerMessageId NVARCHAR(128) NULL,
        ReadPointerTimestamp DATETIMEOFFSET(3) NULL,
        MetadataJson NVARCHAR(MAX) NULL,
        UpdatedAt DATETIMEOFFSET(3) NOT NULL CONSTRAINT DF_DmParticipant_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_DmParticipant PRIMARY KEY (ConversationId, UserId),
        CONSTRAINT FK_DmParticipant_Conversation FOREIGN KEY (ConversationId)
            REFERENCES dbo.DmConversation (ConversationId) ON DELETE CASCADE
    );
END
ELSE
BEGIN
    PRINT 'dbo.DmParticipant already exists.';
END
GO

IF OBJECT_ID('dbo.DmMessage', 'U') IS NULL
BEGIN
    PRINT 'Creating table dbo.DmMessage';
    CREATE TABLE dbo.DmMessage
    (
        MessageId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DmMessage PRIMARY KEY,
        ConversationId BIGINT NOT NULL,
        FirestoreId NVARCHAR(128) NOT NULL,
        ClientMessageId NVARCHAR(128) NULL,
        AuthorUserId NVARCHAR(64) NOT NULL,
        BodyText NVARCHAR(MAX) NULL,
        AttachmentJson NVARCHAR(MAX) NULL,
        ExternalMediaJson NVARCHAR(MAX) NULL,
        DeletedForJson NVARCHAR(MAX) NULL,
        TombstoneJson NVARCHAR(MAX) NULL,
        CreatedAt DATETIMEOFFSET(3) NOT NULL,
        UpdatedAt DATETIMEOFFSET(3) NOT NULL,
        EditedAt DATETIMEOFFSET(3) NULL,
        EditedBy NVARCHAR(64) NULL,
        DeletedAt DATETIMEOFFSET(3) NULL,
        DeletedBy NVARCHAR(64) NULL,
        Source NVARCHAR(64) NULL,
        LastEventId NVARCHAR(128) NULL,
        LastEventTimestamp DATETIMEOFFSET(3) NULL,
        CONSTRAINT FK_DmMessage_Conversation FOREIGN KEY (ConversationId)
            REFERENCES dbo.DmConversation (ConversationId) ON DELETE CASCADE
    );
END
ELSE
BEGIN
    PRINT 'dbo.DmMessage already exists.';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.DmMessage')
      AND name = 'UX_DmMessage_ConversationFirestore'
)
BEGIN
    CREATE UNIQUE INDEX UX_DmMessage_ConversationFirestore
        ON dbo.DmMessage (ConversationId, FirestoreId);
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.DmMessage')
      AND name = 'IX_DmMessage_ConversationCreatedAt'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_DmMessage_ConversationCreatedAt
        ON dbo.DmMessage (ConversationId, CreatedAt DESC, MessageId DESC);
END
GO

IF OBJECT_ID('dbo.DmMessageAudit', 'U') IS NULL
BEGIN
    PRINT 'Creating table dbo.DmMessageAudit';
    CREATE TABLE dbo.DmMessageAudit
    (
        AuditId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DmMessageAudit PRIMARY KEY,
        ConversationId BIGINT NOT NULL,
        MessageId BIGINT NULL,
        FirestoreId NVARCHAR(128) NULL,
        Action NVARCHAR(32) NOT NULL,
        PerformedBy NVARCHAR(64) NULL,
        PayloadJson NVARCHAR(MAX) NULL,
        CreatedAt DATETIMEOFFSET(3) NOT NULL CONSTRAINT DF_DmMessageAudit_CreatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT FK_DmMessageAudit_Conversation FOREIGN KEY (ConversationId)
            REFERENCES dbo.DmConversation (ConversationId) ON DELETE CASCADE,
        CONSTRAINT FK_DmMessageAudit_Message FOREIGN KEY (MessageId)
            REFERENCES dbo.DmMessage (MessageId) ON DELETE SET NULL
    );
END
ELSE
BEGIN
    PRINT 'dbo.DmMessageAudit already exists.';
END
GO

IF OBJECT_ID('dbo.DmBlock', 'U') IS NULL
BEGIN
    PRINT 'Creating table dbo.DmBlock';
    CREATE TABLE dbo.DmBlock
    (
        UserId NVARCHAR(64) NOT NULL,
        TargetUserId NVARCHAR(64) NOT NULL,
        CreatedAt DATETIMEOFFSET(3) NOT NULL,
        RevokedAt DATETIMEOFFSET(3) NULL,
        Source NVARCHAR(64) NULL,
        MetadataJson NVARCHAR(MAX) NULL,
        CONSTRAINT PK_DmBlock PRIMARY KEY (UserId, TargetUserId)
    );
END
ELSE
BEGIN
    PRINT 'dbo.DmBlock already exists.';
END
GO

IF OBJECT_ID('dbo.FollowEdge', 'U') IS NULL
BEGIN
    PRINT 'Creating table dbo.FollowEdge';
    CREATE TABLE dbo.FollowEdge
    (
        FollowerUserId NVARCHAR(64) NOT NULL,
        TargetUserId NVARCHAR(64) NOT NULL,
        State NVARCHAR(16) NOT NULL,
        Source NVARCHAR(32) NULL,
        CreatedAt DATETIMEOFFSET(3) NOT NULL,
        UpdatedAt DATETIMEOFFSET(3) NOT NULL,
        MetadataJson NVARCHAR(MAX) NULL,
        LastEventId NVARCHAR(128) NULL,
        LastEventTimestamp DATETIMEOFFSET(3) NULL,
        CONSTRAINT PK_FollowEdge PRIMARY KEY (FollowerUserId, TargetUserId)
    );
END
ELSE
BEGIN
    PRINT 'dbo.FollowEdge already exists.';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.FollowEdge')
      AND name = 'IX_FollowEdge_TargetState'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_FollowEdge_TargetState
        ON dbo.FollowEdge (TargetUserId, State, UpdatedAt DESC);
END
GO

IF OBJECT_ID('dbo.FollowEvent', 'U') IS NULL
BEGIN
    PRINT 'Creating table dbo.FollowEvent';
    CREATE TABLE dbo.FollowEvent
    (
        EventId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_FollowEvent PRIMARY KEY,
        FollowerUserId NVARCHAR(64) NOT NULL,
        TargetUserId NVARCHAR(64) NOT NULL,
        EventType NVARCHAR(32) NOT NULL,
        CreatedAt DATETIMEOFFSET(3) NOT NULL CONSTRAINT DF_FollowEvent_CreatedAt DEFAULT (SYSUTCDATETIME()),
        CorrelationId NVARCHAR(128) NULL,
        MetadataJson NVARCHAR(MAX) NULL
    );
END
ELSE
BEGIN
    PRINT 'dbo.FollowEvent already exists.';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.FollowEvent')
      AND name = 'IX_FollowEvent_CreatedAt'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_FollowEvent_CreatedAt
        ON dbo.FollowEvent (CreatedAt DESC)
        INCLUDE (FollowerUserId, TargetUserId, EventType);
END
GO

IF OBJECT_ID('dbo.RealtimeMirrorCheckpoint', 'U') IS NULL
BEGIN
    PRINT 'Creating table dbo.RealtimeMirrorCheckpoint';
    CREATE TABLE dbo.RealtimeMirrorCheckpoint
    (
        Module NVARCHAR(64) NOT NULL,
        Shard NVARCHAR(64) NOT NULL,
        LastProcessedAt DATETIMEOFFSET(3) NULL,
        CursorToken NVARCHAR(256) NULL,
        UpdatedAt DATETIMEOFFSET(3) NOT NULL CONSTRAINT DF_RealtimeMirrorCheckpoint_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        MetadataJson NVARCHAR(MAX) NULL,
        CONSTRAINT PK_RealtimeMirrorCheckpoint PRIMARY KEY (Module, Shard)
    );
END
ELSE
BEGIN
    PRINT 'dbo.RealtimeMirrorCheckpoint already exists.';
END
GO

IF OBJECT_ID('dbo.RealtimeMirrorDeadLetter', 'U') IS NULL
BEGIN
    PRINT 'Creating table dbo.RealtimeMirrorDeadLetter';
    CREATE TABLE dbo.RealtimeMirrorDeadLetter
    (
        DeadLetterId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_RealtimeMirrorDeadLetter PRIMARY KEY,
        OccurredAt DATETIMEOFFSET(3) NOT NULL CONSTRAINT DF_RealtimeMirrorDeadLetter_OccurredAt DEFAULT (SYSUTCDATETIME()),
        EventType NVARCHAR(64) NULL,
        MessageId NVARCHAR(128) NULL,
        Subscription NVARCHAR(64) NULL,
        RetryCount INT NULL,
        ErrorMessage NVARCHAR(MAX) NULL,
        Payload NVARCHAR(MAX) NULL
    );
END
ELSE
BEGIN
    PRINT 'dbo.RealtimeMirrorDeadLetter already exists.';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.RealtimeMirrorDeadLetter')
      AND name = 'IX_RealtimeMirrorDeadLetter_OccurredAt'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_RealtimeMirrorDeadLetter_OccurredAt
        ON dbo.RealtimeMirrorDeadLetter (OccurredAt DESC)
        INCLUDE (EventType, MessageId, RetryCount);
END
GO

IF OBJECT_ID('dbo.RealtimeMirrorMetrics', 'U') IS NULL
BEGIN
    PRINT 'Creating table dbo.RealtimeMirrorMetrics';
    CREATE TABLE dbo.RealtimeMirrorMetrics
    (
        MetricId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_RealtimeMirrorMetrics PRIMARY KEY,
        MetricType NVARCHAR(64) NOT NULL,
        WindowStart DATETIMEOFFSET(3) NOT NULL,
        WindowEnd DATETIMEOFFSET(3) NULL,
        Count INT NULL,
        DurationMs INT NULL,
        MetadataJson NVARCHAR(MAX) NULL,
        CreatedAt DATETIMEOFFSET(3) NOT NULL CONSTRAINT DF_RealtimeMirrorMetrics_CreatedAt DEFAULT (SYSUTCDATETIME())
    );
END
ELSE
BEGIN
    PRINT 'dbo.RealtimeMirrorMetrics already exists.';
END
GO

PRINT 'SQL mirror table migration completed successfully.';
GO
