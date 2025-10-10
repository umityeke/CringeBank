/*
  Procedure: dbo.sp_StoreMirror_ListDmMessages
  Purpose : Lists DM messages mirrored in SQL for a conversation with pagination support.
*/

IF DB_ID() IS NULL
BEGIN
    RAISERROR('Database context is not set. Use the appropriate database before running this script.', 16, 1);
    RETURN;
END
GO

IF OBJECT_ID('dbo.sp_StoreMirror_ListDmMessages', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.sp_StoreMirror_ListDmMessages;
END
GO

CREATE PROCEDURE dbo.sp_StoreMirror_ListDmMessages
    @AuthUid NVARCHAR(64),
    @ConversationFirestoreId NVARCHAR(128),
    @Limit INT = 50,
    @BeforeTimestamp DATETIMEOFFSET(3) = NULL,
    @BeforeMessageFirestoreId NVARCHAR(128) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @NormalizedAuthUid NVARCHAR(64) = LTRIM(RTRIM(@AuthUid));
    DECLARE @NormalizedConversationFirestoreId NVARCHAR(128) = LTRIM(RTRIM(@ConversationFirestoreId));

    IF (@NormalizedAuthUid IS NULL OR @NormalizedAuthUid = N'')
    BEGIN
        RAISERROR('Auth uid is required.', 16, 1);
        RETURN;
    END

    IF (@NormalizedConversationFirestoreId IS NULL OR @NormalizedConversationFirestoreId = N'')
    BEGIN
        RAISERROR('Conversation id is required.', 16, 1);
        RETURN;
    END

    IF (@Limit IS NULL OR @Limit < 1)
    BEGIN
        SET @Limit = 50;
    END

    IF (@Limit > 200)
    BEGIN
        SET @Limit = 200;
    END

    DECLARE @ConversationDbId BIGINT = NULL;
    DECLARE @BeforeMessageDbId BIGINT = NULL;

    SELECT TOP (1)
        @ConversationDbId = ConversationId
    FROM dbo.DmConversation WITH (NOLOCK)
    WHERE FirestoreId = @NormalizedConversationFirestoreId;

    IF (@ConversationDbId IS NULL)
    BEGIN
        RETURN;
    END

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.DmParticipant WITH (NOLOCK)
        WHERE ConversationId = @ConversationDbId
          AND UserId = @NormalizedAuthUid
    )
    BEGIN
        RETURN;
    END

    IF (@BeforeMessageFirestoreId IS NOT NULL AND LTRIM(RTRIM(@BeforeMessageFirestoreId)) <> N'')
    BEGIN
        SELECT TOP (1)
            @BeforeMessageDbId = MessageId
        FROM dbo.DmMessage WITH (NOLOCK)
        WHERE ConversationId = @ConversationDbId
          AND FirestoreId = LTRIM(RTRIM(@BeforeMessageFirestoreId));
    END

    SELECT TOP (@Limit)
        MessageId = m.MessageId,
        MessageFirestoreId = m.FirestoreId,
        ClientMessageId = m.ClientMessageId,
        AuthorUserId = m.AuthorUserId,
        BodyText = m.BodyText,
        AttachmentJson = m.AttachmentJson,
        ExternalMediaJson = m.ExternalMediaJson,
        DeletedForJson = m.DeletedForJson,
        TombstoneJson = m.TombstoneJson,
        CreatedAt = m.CreatedAt,
        UpdatedAt = m.UpdatedAt,
        EditedAt = m.EditedAt,
        EditedBy = m.EditedBy,
        DeletedAt = m.DeletedAt,
        DeletedBy = m.DeletedBy,
        Source = m.Source,
        LastEventId = m.LastEventId,
        LastEventTimestamp = m.LastEventTimestamp
    FROM dbo.DmMessage AS m WITH (NOLOCK)
    WHERE
        m.ConversationId = @ConversationDbId
        AND (
            (@BeforeTimestamp IS NULL AND @BeforeMessageDbId IS NULL)
            OR (m.CreatedAt < @BeforeTimestamp)
            OR (
                @BeforeTimestamp IS NOT NULL
                AND m.CreatedAt = @BeforeTimestamp
                AND (
                    @BeforeMessageDbId IS NULL
                    OR m.MessageId < @BeforeMessageDbId
                )
            )
            OR (
                @BeforeTimestamp IS NULL
                AND @BeforeMessageDbId IS NOT NULL
                AND m.MessageId < @BeforeMessageDbId
            )
        )
    ORDER BY m.CreatedAt DESC, m.MessageId DESC;
END
GO

PRINT 'Procedure dbo.sp_StoreMirror_ListDmMessages created.';
GO
