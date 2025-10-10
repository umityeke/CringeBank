/*
  Procedure: dbo.sp_StoreMirror_UpsertDmConversation
  Purpose : Upserts a DM conversation record based on Firestore mirror events.
*/

IF DB_ID() IS NULL
BEGIN
    RAISERROR('Database context is not set. Use the appropriate database before running this script.', 16, 1);
    RETURN;
END
GO

IF OBJECT_ID('dbo.sp_StoreMirror_UpsertDmConversation', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.sp_StoreMirror_UpsertDmConversation;
END
GO

CREATE PROCEDURE dbo.sp_StoreMirror_UpsertDmConversation
    @EventType NVARCHAR(64),
    @Operation NVARCHAR(32),
    @Source NVARCHAR(256),
    @EventId NVARCHAR(128),
    @EventTimestamp DATETIMEOFFSET(3),
    @DocumentJson NVARCHAR(MAX),
    @PreviousDocumentJson NVARCHAR(MAX),
    @MetadataJson NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ConversationFirestoreId NVARCHAR(128) = NULL;
    DECLARE @ConversationKey NVARCHAR(128) = NULL;
    DECLARE @IsGroup BIT = 0;
    DECLARE @Type NVARCHAR(32) = NULL;
    DECLARE @MemberCount INT = NULL;
    DECLARE @ParticipantHash VARBINARY(64) = NULL;
    DECLARE @Metadata NVARCHAR(MAX) = @MetadataJson;
    DECLARE @ParticipantMetaJson NVARCHAR(MAX) = NULL;
    DECLARE @ReadPointersJson NVARCHAR(MAX) = NULL;
    DECLARE @MembersJson NVARCHAR(MAX) = NULL;
    DECLARE @LastMessageId NVARCHAR(128) = NULL;
    DECLARE @LastMessageSenderId NVARCHAR(64) = NULL;
    DECLARE @LastMessagePreview NVARCHAR(400) = NULL;
    DECLARE @LastMessageTimestamp DATETIMEOFFSET(3) = NULL;
    DECLARE @CreatedAt DATETIMEOFFSET(3) = NULL;
    DECLARE @UpdatedAt DATETIMEOFFSET(3) = NULL;
    DECLARE @ConversationDbId BIGINT = NULL;

    SELECT
        @ConversationFirestoreId = JSON_VALUE(@MetadataJson, '$.conversationId'),
        @ConversationKey = JSON_VALUE(@MetadataJson, '$.conversationId');

    IF (@ConversationFirestoreId IS NULL OR LTRIM(RTRIM(@ConversationFirestoreId)) = N'')
    BEGIN
        RAISERROR('Conversation id missing in metadata.', 16, 1);
        RETURN;
    END

    IF (@DocumentJson IS NULL)
    BEGIN
        -- No document payload supplied. Skip without failing to allow idempotent delete events.
        RETURN;
    END

    DECLARE @ConversationDocument TABLE
    (
        Type NVARCHAR(32),
        IsGroup BIT,
        MemberCount INT,
        LastMessageId NVARCHAR(128),
        LastMessageSenderId NVARCHAR(64),
        LastMessagePreview NVARCHAR(4000),
        LastMessageAt NVARCHAR(128),
        CreatedAt NVARCHAR(128),
        UpdatedAt NVARCHAR(128)
    );

    INSERT INTO @ConversationDocument
    SELECT
        Type = JSON_VALUE(@DocumentJson, '$.type'),
        IsGroup = CASE WHEN JSON_VALUE(@DocumentJson, '$.isGroup') IN (N'true', N'TRUE', N'1') THEN 1 ELSE 0 END,
        MemberCount = TRY_CAST(JSON_VALUE(@DocumentJson, '$.memberCount') AS INT),
        LastMessageId = JSON_VALUE(@DocumentJson, '$.lastMessageId'),
        LastMessageSenderId = JSON_VALUE(@DocumentJson, '$.lastSenderId'),
        LastMessagePreview = JSON_VALUE(@DocumentJson, '$.lastMessageText'),
        LastMessageAt = JSON_VALUE(@DocumentJson, '$.lastMessageAt'),
        CreatedAt = JSON_VALUE(@DocumentJson, '$.createdAt'),
        UpdatedAt = JSON_VALUE(@DocumentJson, '$.updatedAt');

    SELECT TOP (1)
        @Type = NULLIF(LTRIM(RTRIM(Type)), N''),
        @IsGroup = IsGroup,
        @MemberCount = MemberCount,
        @LastMessageId = NULLIF(LTRIM(RTRIM(LastMessageId)), N''),
        @LastMessageSenderId = NULLIF(LTRIM(RTRIM(LastMessageSenderId)), N''),
        @LastMessagePreview = CASE
                                  WHEN LastMessagePreview IS NULL THEN NULL
                                  WHEN LEN(LastMessagePreview) > 400 THEN LEFT(LastMessagePreview, 400)
                                  ELSE LastMessagePreview
                              END,
        @LastMessageTimestamp = COALESCE(
            TRY_CONVERT(DATETIMEOFFSET(3), NULLIF(LTRIM(RTRIM(LastMessageAt)), N''), 127),
            @LastMessageTimestamp
        ),
        @CreatedAt = COALESCE(
            TRY_CONVERT(DATETIMEOFFSET(3), NULLIF(LTRIM(RTRIM(CreatedAt)), N''), 127),
            @CreatedAt
        ),
        @UpdatedAt = COALESCE(
            TRY_CONVERT(DATETIMEOFFSET(3), NULLIF(LTRIM(RTRIM(UpdatedAt)), N''), 127),
            @UpdatedAt
        )
    FROM @ConversationDocument;

    SET @ParticipantMetaJson = JSON_QUERY(@DocumentJson, '$.participantMeta');
    SET @ReadPointersJson = JSON_QUERY(@DocumentJson, '$.readPointers');
    SET @MembersJson = JSON_QUERY(@DocumentJson, '$.members');

    IF (@Type IS NULL)
    BEGIN
        SET @Type = CASE WHEN @IsGroup = 1 THEN N'group' ELSE N'direct' END;
    END

    DECLARE @Members TABLE (UserId NVARCHAR(128) NOT NULL);
    IF (@MembersJson IS NOT NULL)
    BEGIN
        INSERT INTO @Members (UserId)
        SELECT DISTINCT LTRIM(RTRIM(value))
        FROM OPENJSON(@MembersJson)
        WHERE LTRIM(RTRIM(value)) <> N'';
    END

    IF (@MemberCount IS NULL)
    BEGIN
        SELECT @MemberCount = COUNT(1) FROM @Members;
    END

    DECLARE @MemberConcat NVARCHAR(MAX) = NULL;
    SELECT @MemberConcat = STRING_AGG(UserId, ',') WITHIN GROUP (ORDER BY UserId)
    FROM @Members;

    IF (@MemberConcat IS NOT NULL)
    BEGIN
        SET @ParticipantHash = HASHBYTES('SHA2_256', @MemberConcat);
    END

    SELECT @ConversationDbId = ConversationId
    FROM dbo.DmConversation WITH (UPDLOCK, HOLDLOCK)
    WHERE FirestoreId = @ConversationFirestoreId;

    IF (@ConversationDbId IS NULL)
    BEGIN
        INSERT INTO dbo.DmConversation
        (
            FirestoreId,
            ConversationKey,
            Type,
            IsGroup,
            ParticipantHash,
            MemberCount,
            MetadataJson,
            ParticipantMetaJson,
            ReadPointersJson,
            LastMessageFirestoreId,
            LastMessageSenderId,
            LastMessagePreview,
            LastMessageTimestamp,
            CreatedAt,
            UpdatedAt,
            LastEventId,
            LastEventTimestamp
        )
        VALUES
        (
            @ConversationFirestoreId,
            COALESCE(@ConversationKey, @ConversationFirestoreId),
            @Type,
            @IsGroup,
            @ParticipantHash,
            @MemberCount,
            @Metadata,
            @ParticipantMetaJson,
            @ReadPointersJson,
            @LastMessageId,
            @LastMessageSenderId,
            @LastMessagePreview,
            COALESCE(@LastMessageTimestamp, @EventTimestamp),
            COALESCE(@CreatedAt, @EventTimestamp),
            COALESCE(@UpdatedAt, @EventTimestamp),
            @EventId,
            @EventTimestamp
        );

        SET @ConversationDbId = SCOPE_IDENTITY();
    END
    ELSE
    BEGIN
        UPDATE dbo.DmConversation
        SET
            ConversationKey = COALESCE(@ConversationKey, ConversationKey),
            Type = @Type,
            IsGroup = @IsGroup,
            ParticipantHash = @ParticipantHash,
            MemberCount = @MemberCount,
            MetadataJson = @Metadata,
            ParticipantMetaJson = @ParticipantMetaJson,
            ReadPointersJson = @ReadPointersJson,
            LastMessageFirestoreId = COALESCE(@LastMessageId, LastMessageFirestoreId),
            LastMessageSenderId = COALESCE(@LastMessageSenderId, LastMessageSenderId),
            LastMessagePreview = COALESCE(@LastMessagePreview, LastMessagePreview),
            LastMessageTimestamp = COALESCE(@LastMessageTimestamp, LastMessageTimestamp),
            CreatedAt = COALESCE(@CreatedAt, CreatedAt),
            UpdatedAt = COALESCE(@UpdatedAt, @EventTimestamp, UpdatedAt),
            LastEventId = @EventId,
            LastEventTimestamp = @EventTimestamp
        WHERE ConversationId = @ConversationDbId;
    END

    IF EXISTS (SELECT 1 FROM @Members)
    BEGIN
        DECLARE @ParticipantMeta TABLE
        (
            UserId NVARCHAR(128) NOT NULL,
            MetaJson NVARCHAR(MAX) NULL
        );

        IF (@ParticipantMetaJson IS NOT NULL)
        BEGIN
            INSERT INTO @ParticipantMeta (UserId, MetaJson)
            SELECT [key], value
            FROM OPENJSON(@ParticipantMetaJson);
        END

        DECLARE @ReadPointers TABLE
        (
            UserId NVARCHAR(128) NOT NULL,
            MessageId NVARCHAR(128) NULL
        );

        IF (@ReadPointersJson IS NOT NULL)
        BEGIN
            INSERT INTO @ReadPointers (UserId, MessageId)
            SELECT [key], NULLIF(LTRIM(RTRIM(value)), N'')
            FROM OPENJSON(@ReadPointersJson);
        END

        MERGE dbo.DmParticipant AS target
        USING (
            SELECT
                m.UserId,
                meta.MetaJson,
                rp.MessageId
            FROM @Members AS m
            LEFT JOIN @ParticipantMeta AS meta ON meta.UserId = m.UserId
            LEFT JOIN @ReadPointers AS rp ON rp.UserId = m.UserId
        ) AS source (UserId, MetaJson, MessageId)
        ON target.ConversationId = @ConversationDbId AND target.UserId = source.UserId
        WHEN MATCHED THEN
            UPDATE SET
                target.MetadataJson = source.MetaJson,
                target.ReadPointerMessageId = source.MessageId,
                target.ReadPointerTimestamp = CASE
                    WHEN source.MessageId IS NOT NULL THEN SYSUTCDATETIME()
                    ELSE target.ReadPointerTimestamp
                END,
                target.UpdatedAt = SYSUTCDATETIME()
        WHEN NOT MATCHED THEN
            INSERT (ConversationId, UserId, Role, JoinedAt, MuteState, ReadPointerMessageId, ReadPointerTimestamp, MetadataJson)
            VALUES (@ConversationDbId, source.UserId, NULL, SYSUTCDATETIME(), NULL, source.MessageId, SYSUTCDATETIME(), source.MetaJson)
        WHEN NOT MATCHED BY SOURCE AND @Operation IN (N'update', N'delete') THEN
            DELETE;
    END

    -- touch conversation updated timestamp to reflect processing time when not provided
    UPDATE dbo.DmConversation
    SET UpdatedAt = COALESCE(@UpdatedAt, @EventTimestamp, UpdatedAt)
    WHERE ConversationId = @ConversationDbId;
END
GO

PRINT 'Procedure dbo.sp_StoreMirror_UpsertDmConversation created.';
GO
