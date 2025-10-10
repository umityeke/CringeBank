/*
  Procedure: dbo.sp_StoreMirror_DeleteFollowEdge
  Purpose : Marks a follow edge as removed and records deletion event.
*/

IF DB_ID() IS NULL
BEGIN
    RAISERROR('Database context is not set. Use the appropriate database before running this script.', 16, 1);
    RETURN;
END
GO

IF OBJECT_ID('dbo.sp_StoreMirror_DeleteFollowEdge', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.sp_StoreMirror_DeleteFollowEdge;
END
GO

CREATE PROCEDURE dbo.sp_StoreMirror_DeleteFollowEdge
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

    DECLARE @Follower NVARCHAR(64) = NULL;
    DECLARE @Target NVARCHAR(64) = NULL;
    DECLARE @Metadata NVARCHAR(MAX) = COALESCE(@PreviousDocumentJson, @DocumentJson, @MetadataJson);

    SELECT
        @Follower = JSON_VALUE(@MetadataJson, '$.userId'),
        @Target = JSON_VALUE(@MetadataJson, '$.targetId');

    IF (@Follower IS NULL OR LTRIM(RTRIM(@Follower)) = N'')
    BEGIN
        RAISERROR('Missing follower user id in metadata.', 16, 1);
        RETURN;
    END

    IF (@Target IS NULL OR LTRIM(RTRIM(@Target)) = N'')
    BEGIN
        RAISERROR('Missing target user id in metadata.', 16, 1);
        RETURN;
    END

    UPDATE dbo.FollowEdge
    SET
        State = N'REMOVED',
        UpdatedAt = @EventTimestamp,
        MetadataJson = COALESCE(@PreviousDocumentJson, MetadataJson),
        LastEventId = @EventId,
        LastEventTimestamp = @EventTimestamp
    WHERE FollowerUserId = @Follower
      AND TargetUserId = @Target;

    INSERT INTO dbo.FollowEvent
    (
        FollowerUserId,
        TargetUserId,
        EventType,
        CreatedAt,
        CorrelationId,
        MetadataJson
    )
    VALUES
    (
        @Follower,
        @Target,
        UPPER(@EventType),
        @EventTimestamp,
        @EventId,
        @Metadata
    );
END
GO

PRINT 'Procedure dbo.sp_StoreMirror_DeleteFollowEdge created.';
GO
