/*
  Procedure: dbo.sp_StoreMirror_UpsertDmMessage
  Purpose : Upserts a DM message row and refreshes conversation aggregates.
*/

IF DB_ID() IS NULL
BEGIN
    RAISERROR('Database context is not set. Use the appropriate database before running this script.', 16, 1);
    RETURN;
END
GO

IF OBJECT_ID('dbo.sp_StoreMirror_UpsertDmMessage', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.sp_StoreMirror_UpsertDmMessage;
END
GO

CREATE PROCEDURE dbo.sp_StoreMirror_UpsertDmMessage
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
    DECLARE @MessageFirestoreId NVARCHAR(128) = NULL;
    DECLARE @ConversationDbId BIGINT = NULL;
    DECLARE @ExistingMessageId BIGINT = NULL;
    DECLARE @SenderId NVARCHAR(64) = NULL;
    DECLARE @BodyText NVARCHAR(MAX) = NULL;
    DECLARE @MediaJson NVARCHAR(MAX) = NULL;
    DECLARE @MediaExternalJson NVARCHAR(MAX) = NULL;
    DECLARE @DeletedForJson NVARCHAR(MAX) = NULL;
    DECLARE @TombstoneJson NVARCHAR(MAX) = NULL;
    DECLARE @ClientMessageId NVARCHAR(128) = NULL;
    DECLARE @CreatedAt DATETIMEOFFSET(3) = NULL;
    DECLARE @UpdatedAt DATETIMEOFFSET(3) = NULL;
    DECLARE @EditedAt DATETIMEOFFSET(3) = NULL;
    DECLARE @EditedBy NVARCHAR(64) = NULL;
    DECLARE @DeletedAt DATETIMEOFFSET(3) = NULL;
    DECLARE @DeletedBy NVARCHAR(64) = NULL;
    DECLARE @SourceLabel NVARCHAR(64) = NULL;
    DECLARE @OperationNormalized NVARCHAR(32) = LOWER(LTRIM(RTRIM(@Operation)));

    SELECT
        @ConversationFirestoreId = JSON_VALUE(@MetadataJson, '$.conversationId'),
        @MessageFirestoreId = COALESCE(JSON_VALUE(@MetadataJson, '$.messageId'), JSON_VALUE(@MetadataJson, '$.clientMessageId')),
        @SourceLabel = JSON_VALUE(@MetadataJson, '$.source');

    IF (@ConversationFirestoreId IS NULL OR LTRIM(RTRIM(@ConversationFirestoreId)) = N'')
    BEGIN
        RAISERROR('Missing conversation id in metadata.', 16, 1);
        RETURN;
    END

    IF (@MessageFirestoreId IS NULL OR LTRIM(RTRIM(@MessageFirestoreId)) = N'')
    BEGIN
        RAISERROR('Missing message id in metadata.', 16, 1);
        RETURN;
    END

    IF (@DocumentJson IS NULL)
    BEGIN
        RETURN;
    END

    DECLARE @MessageDocument TABLE
    (
        SenderId NVARCHAR(64),
        BodyText NVARCHAR(MAX),
        ClientMessageId NVARCHAR(128),
        CreatedAt NVARCHAR(128),
        UpdatedAt NVARCHAR(128),
        EditedAt NVARCHAR(128),
        EditedBy NVARCHAR(64),
        Media NVARCHAR(MAX),
        MediaExternal NVARCHAR(MAX),
        DeletedFor NVARCHAR(MAX),
        Tombstone NVARCHAR(MAX)
    );

    INSERT INTO @MessageDocument
    SELECT
        SenderId = JSON_VALUE(@DocumentJson, '$.senderId'),
        BodyText = JSON_VALUE(@DocumentJson, '$.text'),
        ClientMessageId = JSON_VALUE(@DocumentJson, '$.clientMessageId'),
        CreatedAt = JSON_VALUE(@DocumentJson, '$.createdAt'),
        UpdatedAt = JSON_VALUE(@DocumentJson, '$.updatedAt'),
        EditedAt = JSON_VALUE(@DocumentJson, '$.edited.at'),
        EditedBy = JSON_VALUE(@DocumentJson, '$.edited.by'),
        Media = JSON_QUERY(@DocumentJson, '$.media'),
        MediaExternal = JSON_QUERY(@DocumentJson, '$.mediaExternal'),
        DeletedFor = JSON_QUERY(@DocumentJson, '$.deletedFor'),
        Tombstone = JSON_QUERY(@DocumentJson, '$.tombstone');

    SELECT TOP (1)
        @SenderId = NULLIF(LTRIM(RTRIM(SenderId)), N''),
        @BodyText = BodyText,
        @ClientMessageId = NULLIF(LTRIM(RTRIM(ClientMessageId)), N''),
        @CreatedAt = COALESCE(
            TRY_CONVERT(DATETIMEOFFSET(3), NULLIF(LTRIM(RTRIM(CreatedAt)), N''), 127),
            @CreatedAt
        ),
        @UpdatedAt = COALESCE(
            TRY_CONVERT(DATETIMEOFFSET(3), NULLIF(LTRIM(RTRIM(UpdatedAt)), N''), 127),
            @UpdatedAt
        ),
        @EditedAt = COALESCE(
            TRY_CONVERT(DATETIMEOFFSET(3), NULLIF(LTRIM(RTRIM(EditedAt)), N''), 127),
            @EditedAt
        ),
        @EditedBy = NULLIF(LTRIM(RTRIM(EditedBy)), N''),
        @MediaJson = Media,
        @MediaExternalJson = MediaExternal,
        @DeletedForJson = DeletedFor,
        @TombstoneJson = Tombstone
    FROM @MessageDocument;

    IF (@CreatedAt IS NULL)
    BEGIN
        SET @CreatedAt = @EventTimestamp;
    END
    IF (@UpdatedAt IS NULL)
    BEGIN
        SET @UpdatedAt = @EventTimestamp;
    END

    -- Determine tombstone deletion values if present
    IF (@TombstoneJson IS NOT NULL)
    BEGIN
        DECLARE @Tombstone TABLE (At NVARCHAR(128), ByUser NVARCHAR(64));
        INSERT INTO @Tombstone
        SELECT JSON_VALUE(@TombstoneJson, '$.at'), JSON_VALUE(@TombstoneJson, '$.by');
        SELECT TOP (1)
            @DeletedAt = COALESCE(
                TRY_CONVERT(DATETIMEOFFSET(3), NULLIF(LTRIM(RTRIM(At)), N''), 127),
                @DeletedAt
            ),
            @DeletedBy = NULLIF(LTRIM(RTRIM(ByUser)), N'')
        FROM @Tombstone;
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
            @ConversationFirestoreId,
            N'direct',
            0,
            NULL,
            NULL,
            @MetadataJson,
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            @EventTimestamp,
            @EventTimestamp,
            @EventId,
            @EventTimestamp
        );

        SET @ConversationDbId = SCOPE_IDENTITY();
    END

    SELECT @ExistingMessageId = MessageId
    FROM dbo.DmMessage WITH (UPDLOCK, HOLDLOCK)
    WHERE ConversationId = @ConversationDbId
      AND FirestoreId = @MessageFirestoreId;

    IF (@ExistingMessageId IS NULL)
    BEGIN
        INSERT INTO dbo.DmMessage
        (
            ConversationId,
            FirestoreId,
            ClientMessageId,
            AuthorUserId,
            BodyText,
            AttachmentJson,
            ExternalMediaJson,
            DeletedForJson,
            TombstoneJson,
            CreatedAt,
            UpdatedAt,
            EditedAt,
            EditedBy,
            DeletedAt,
            DeletedBy,
            Source,
            LastEventId,
            LastEventTimestamp
        )
        VALUES
        (
            @ConversationDbId,
            @MessageFirestoreId,
            @ClientMessageId,
            @SenderId,
            @BodyText,
            @MediaJson,
            @MediaExternalJson,
            @DeletedForJson,
            @TombstoneJson,
            @CreatedAt,
            @UpdatedAt,
            @EditedAt,
            @EditedBy,
            @DeletedAt,
            @DeletedBy,
            COALESCE(@SourceLabel, @Source),
            @EventId,
            @EventTimestamp
        );

        SET @ExistingMessageId = SCOPE_IDENTITY();
    END
    ELSE
    BEGIN
        UPDATE dbo.DmMessage
        SET
            ClientMessageId = COALESCE(@ClientMessageId, ClientMessageId),
            AuthorUserId = COALESCE(@SenderId, AuthorUserId),
            BodyText = @BodyText,
            AttachmentJson = @MediaJson,
            ExternalMediaJson = @MediaExternalJson,
            DeletedForJson = @DeletedForJson,
            TombstoneJson = @TombstoneJson,
            CreatedAt = COALESCE(@CreatedAt, CreatedAt),
            UpdatedAt = COALESCE(@UpdatedAt, @EventTimestamp, UpdatedAt),
            EditedAt = COALESCE(@EditedAt, EditedAt),
            EditedBy = COALESCE(@EditedBy, EditedBy),
            DeletedAt = COALESCE(@DeletedAt, DeletedAt),
            DeletedBy = COALESCE(@DeletedBy, DeletedBy),
            Source = COALESCE(@SourceLabel, @Source, Source),
            LastEventId = @EventId,
            LastEventTimestamp = @EventTimestamp
        WHERE MessageId = @ExistingMessageId;
    END

    IF (@OperationNormalized IN (N'create', N'update'))
    BEGIN
        INSERT INTO dbo.DmMessageAudit
        (
            ConversationId,
            MessageId,
            FirestoreId,
            Action,
            PerformedBy,
            PayloadJson,
            CreatedAt
        )
        VALUES
        (
            @ConversationDbId,
            @ExistingMessageId,
            @MessageFirestoreId,
            UPPER(@OperationNormalized),
            @EditedBy,
            @DocumentJson,
            @EventTimestamp
        );
    END

    -- refresh conversation summary if this is the latest message
    DECLARE @CandidateTimestamp DATETIMEOFFSET(3) = COALESCE(@UpdatedAt, @CreatedAt, @EventTimestamp);
    DECLARE @Preview NVARCHAR(400) = NULL;
    IF (@BodyText IS NOT NULL)
    BEGIN
        SET @Preview = CASE WHEN LEN(@BodyText) > 400 THEN LEFT(@BodyText, 400) ELSE @BodyText END;
    END

    UPDATE dbo.DmConversation
    SET
        LastMessageFirestoreId = @MessageFirestoreId,
        LastMessageSenderId = @SenderId,
        LastMessagePreview = COALESCE(@Preview, LastMessagePreview),
        LastMessageTimestamp = CASE
            WHEN LastMessageTimestamp IS NULL THEN @CandidateTimestamp
            WHEN @CandidateTimestamp >= LastMessageTimestamp THEN @CandidateTimestamp
            ELSE LastMessageTimestamp
        END,
        UpdatedAt = CASE
            WHEN @CandidateTimestamp >= UpdatedAt THEN @CandidateTimestamp
            ELSE UpdatedAt
        END,
        LastEventId = @EventId,
        LastEventTimestamp = @EventTimestamp
    WHERE ConversationId = @ConversationDbId;
END
GO

PRINT 'Procedure dbo.sp_StoreMirror_UpsertDmMessage created.';
GO
