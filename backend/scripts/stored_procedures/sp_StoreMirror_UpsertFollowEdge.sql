/*
  Procedure: dbo.sp_StoreMirror_UpsertFollowEdge
  Purpose : Upserts a follow edge mirror record and logs the event.
*/

IF DB_ID() IS NULL
BEGIN
    RAISERROR('Database context is not set. Use the appropriate database before running this script.', 16, 1);
    RETURN;
END
GO

IF OBJECT_ID('dbo.sp_StoreMirror_UpsertFollowEdge', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.sp_StoreMirror_UpsertFollowEdge;
END
GO

CREATE PROCEDURE dbo.sp_StoreMirror_UpsertFollowEdge
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
    DECLARE @State NVARCHAR(16) = NULL;
    DECLARE @SourceLabel NVARCHAR(32) = NULL;
    DECLARE @CreatedAt DATETIMEOFFSET(3) = NULL;
    DECLARE @UpdatedAt DATETIMEOFFSET(3) = NULL;
    DECLARE @Metadata NVARCHAR(MAX) = COALESCE(@DocumentJson, @MetadataJson);

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

    IF (@DocumentJson IS NULL)
    BEGIN
        RETURN;
    END

    DECLARE @Document TABLE
    (
        Status NVARCHAR(32),
        Source NVARCHAR(32),
        CreatedAt NVARCHAR(128),
        UpdatedAt NVARCHAR(128)
    );

    INSERT INTO @Document
    SELECT
        Status = JSON_VALUE(@DocumentJson, '$.status'),
        Source = JSON_VALUE(@DocumentJson, '$.source'),
        CreatedAt = JSON_VALUE(@DocumentJson, '$.createdAt'),
        UpdatedAt = JSON_VALUE(@DocumentJson, '$.updatedAt');

    SELECT TOP (1)
        @State = UPPER(NULLIF(LTRIM(RTRIM(Status)), N'')),
        @SourceLabel = NULLIF(LTRIM(RTRIM(Source)), N''),
        @CreatedAt = COALESCE(
            TRY_CONVERT(DATETIMEOFFSET(3), NULLIF(LTRIM(RTRIM(CreatedAt)), N''), 127),
            @CreatedAt
        ),
        @UpdatedAt = COALESCE(
            TRY_CONVERT(DATETIMEOFFSET(3), NULLIF(LTRIM(RTRIM(UpdatedAt)), N''), 127),
            @UpdatedAt
        )
    FROM @Document;

    IF (@State IS NULL)
    BEGIN
        SET @State = CASE LOWER(LTRIM(RTRIM(@Operation)))
            WHEN 'create' THEN N'ACTIVE'
            WHEN 'update' THEN N'ACTIVE'
            ELSE N'ACTIVE'
        END;
    END

    IF (@CreatedAt IS NULL)
    BEGIN
        SET @CreatedAt = @EventTimestamp;
    END
    IF (@UpdatedAt IS NULL)
    BEGIN
        SET @UpdatedAt = @EventTimestamp;
    END

    MERGE dbo.FollowEdge AS target
    USING (SELECT @Follower AS FollowerUserId, @Target AS TargetUserId) AS source
        (FollowerUserId, TargetUserId)
    ON target.FollowerUserId = source.FollowerUserId
       AND target.TargetUserId = source.TargetUserId
    WHEN MATCHED THEN
        UPDATE SET
            State = @State,
            Source = COALESCE(@SourceLabel, @Source, Source),
            CreatedAt = COALESCE(target.CreatedAt, @CreatedAt),
            UpdatedAt = @UpdatedAt,
            MetadataJson = COALESCE(@DocumentJson, target.MetadataJson),
            LastEventId = @EventId,
            LastEventTimestamp = @EventTimestamp
    WHEN NOT MATCHED THEN
        INSERT (FollowerUserId, TargetUserId, State, Source, CreatedAt, UpdatedAt, MetadataJson, LastEventId, LastEventTimestamp)
        VALUES (@Follower, @Target, @State, COALESCE(@SourceLabel, @Source), @CreatedAt, @UpdatedAt, @DocumentJson, @EventId, @EventTimestamp);

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
        COALESCE(@DocumentJson, @MetadataJson)
    );
END
GO

PRINT 'Procedure dbo.sp_StoreMirror_UpsertFollowEdge created.';
GO
