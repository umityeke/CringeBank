/*
  Procedure: dbo.sp_StoreMirror_DeleteDmMessage
  Purpose : Marks a DM message as deleted based on mirror events.
*/

IF DB_ID() IS NULL
BEGIN
    RAISERROR('Database context is not set. Use the appropriate database before running this script.', 16, 1);
    RETURN;
END
GO

IF OBJECT_ID('dbo.sp_StoreMirror_DeleteDmMessage', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.sp_StoreMirror_DeleteDmMessage;
END
GO

CREATE PROCEDURE dbo.sp_StoreMirror_DeleteDmMessage
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
    DECLARE @DeletedAt DATETIMEOFFSET(3) = @EventTimestamp;
    DECLARE @DeletedBy NVARCHAR(64) = NULL;
    DECLARE @TombstoneJson NVARCHAR(MAX) = NULL;
    DECLARE @DeletedForJson NVARCHAR(MAX) = NULL;

    SELECT
        @ConversationFirestoreId = JSON_VALUE(@MetadataJson, '$.conversationId'),
        @MessageFirestoreId = COALESCE(JSON_VALUE(@MetadataJson, '$.messageId'), JSON_VALUE(@MetadataJson, '$.clientMessageId'));

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

    IF (@PreviousDocumentJson IS NOT NULL)
    BEGIN
        SET @TombstoneJson = JSON_QUERY(@PreviousDocumentJson, '$.tombstone');
        SET @DeletedForJson = JSON_QUERY(@PreviousDocumentJson, '$.deletedFor');

        DECLARE @PrevTombstone TABLE (At NVARCHAR(128), ByUser NVARCHAR(64));
        INSERT INTO @PrevTombstone
        SELECT
            JSON_VALUE(@PreviousDocumentJson, '$.tombstone.at'),
            JSON_VALUE(@PreviousDocumentJson, '$.tombstone.by');

        SELECT TOP (1)
            @DeletedAt = COALESCE(
                TRY_CONVERT(DATETIMEOFFSET(3), NULLIF(LTRIM(RTRIM(At)), N''), 127),
                @DeletedAt
            ),
            @DeletedBy = NULLIF(LTRIM(RTRIM(ByUser)), N'')
        FROM @PrevTombstone;
    END

    SELECT @ConversationDbId = ConversationId
    FROM dbo.DmConversation WITH (UPDLOCK, HOLDLOCK)
    WHERE FirestoreId = @ConversationFirestoreId;

    IF (@ConversationDbId IS NULL)
    BEGIN
        RETURN;
    END

    SELECT @ExistingMessageId = MessageId
    FROM dbo.DmMessage WITH (UPDLOCK, HOLDLOCK)
    WHERE ConversationId = @ConversationDbId
      AND FirestoreId = @MessageFirestoreId;

    IF (@ExistingMessageId IS NULL)
    BEGIN
        RETURN;
    END

    UPDATE dbo.DmMessage
    SET
        DeletedAt = COALESCE(@DeletedAt, @EventTimestamp),
        DeletedBy = COALESCE(@DeletedBy, DeletedBy),
        TombstoneJson = COALESCE(@TombstoneJson, TombstoneJson),
        DeletedForJson = COALESCE(@DeletedForJson, DeletedForJson),
        LastEventId = @EventId,
        LastEventTimestamp = @EventTimestamp
    WHERE MessageId = @ExistingMessageId;

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
        N'DELETE',
        @DeletedBy,
        COALESCE(@PreviousDocumentJson, @DocumentJson),
        @EventTimestamp
    );

    UPDATE dbo.DmConversation
    SET
        UpdatedAt = CASE
            WHEN @EventTimestamp >= UpdatedAt THEN @EventTimestamp
            ELSE UpdatedAt
        END,
        LastEventId = @EventId,
        LastEventTimestamp = @EventTimestamp
    WHERE ConversationId = @ConversationDbId;
END
GO

PRINT 'Procedure dbo.sp_StoreMirror_DeleteDmMessage created.';
GO
