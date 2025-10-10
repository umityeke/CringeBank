/*
  Procedure: dbo.sp_StoreMirror_ListDmConversations
  Purpose : Lists DM conversations mirrored in SQL for a given participant with pagination support.
*/

IF DB_ID() IS NULL
BEGIN
    RAISERROR('Database context is not set. Use the appropriate database before running this script.', 16, 1);
    RETURN;
END
GO

IF OBJECT_ID('dbo.sp_StoreMirror_ListDmConversations', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.sp_StoreMirror_ListDmConversations;
END
GO

CREATE PROCEDURE dbo.sp_StoreMirror_ListDmConversations
    @AuthUid NVARCHAR(64),
    @Limit INT = 20,
    @UpdatedBefore DATETIMEOFFSET(3) = NULL,
    @BeforeConversationFirestoreId NVARCHAR(128) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @NormalizedAuthUid NVARCHAR(64) = LTRIM(RTRIM(@AuthUid));

    IF (@NormalizedAuthUid IS NULL OR @NormalizedAuthUid = N'')
    BEGIN
        RAISERROR('Auth uid is required.', 16, 1);
        RETURN;
    END

    IF (@Limit IS NULL OR @Limit < 1)
    BEGIN
        SET @Limit = 20;
    END

    IF (@Limit > 100)
    BEGIN
        SET @Limit = 100;
    END

    DECLARE @BeforeConversationDbId BIGINT = NULL;

    IF (@BeforeConversationFirestoreId IS NOT NULL AND LTRIM(RTRIM(@BeforeConversationFirestoreId)) <> N'')
    BEGIN
        SELECT TOP (1)
            @BeforeConversationDbId = ConversationId
        FROM dbo.DmConversation WITH (NOLOCK)
        WHERE FirestoreId = LTRIM(RTRIM(@BeforeConversationFirestoreId));
    END

    SELECT TOP (@Limit)
        ConversationId = c.ConversationId,
        ConversationFirestoreId = c.FirestoreId,
        ConversationKey = c.ConversationKey,
        ConversationType = c.Type,
        IsGroup = c.IsGroup,
        MemberCount = c.MemberCount,
        MetadataJson = c.MetadataJson,
        ParticipantMetaJson = c.ParticipantMetaJson,
        ReadPointersJson = c.ReadPointersJson,
        LastMessageFirestoreId = c.LastMessageFirestoreId,
        LastMessageSenderId = c.LastMessageSenderId,
        LastMessagePreview = c.LastMessagePreview,
        LastMessageTimestamp = c.LastMessageTimestamp,
        CreatedAt = c.CreatedAt,
        UpdatedAt = c.UpdatedAt,
        LastEventId = c.LastEventId,
        LastEventTimestamp = c.LastEventTimestamp,
        UserReadPointerMessageId = p.ReadPointerMessageId,
        UserReadPointerTimestamp = p.ReadPointerTimestamp,
        UserMetadataJson = p.MetadataJson,
        ParticipantsJson = COALESCE(
            (
                SELECT
                    dp.UserId,
                    dp.Role,
                    dp.JoinedAt,
                    dp.MuteState,
                    dp.ReadPointerMessageId,
                    dp.ReadPointerTimestamp,
                    dp.MetadataJson
                FROM dbo.DmParticipant AS dp WITH (NOLOCK)
                WHERE dp.ConversationId = c.ConversationId
                ORDER BY dp.UserId
                FOR JSON PATH
            ),
            N'[]'
        )
    FROM dbo.DmConversation AS c WITH (NOLOCK)
    INNER JOIN dbo.DmParticipant AS p WITH (NOLOCK)
        ON p.ConversationId = c.ConversationId
       AND p.UserId = @NormalizedAuthUid
    WHERE
        (
            @UpdatedBefore IS NULL
            OR c.UpdatedAt < @UpdatedBefore
            OR (
                c.UpdatedAt = @UpdatedBefore
                AND @BeforeConversationDbId IS NOT NULL
                AND c.ConversationId < @BeforeConversationDbId
            )
        )
    ORDER BY c.UpdatedAt DESC, c.ConversationId DESC;
END
GO

PRINT 'Procedure dbo.sp_StoreMirror_ListDmConversations created.';
GO
