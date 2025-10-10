/*
  Procedure: dbo.sp_StoreMirror_GetFollowRelationship
  Purpose : Returns the mirrored follow edges between two users (viewer → target and target → viewer).
*/

IF DB_ID() IS NULL
BEGIN
    RAISERROR('Database context is not set. Use the appropriate database before running this script.', 16, 1);
    RETURN;
END
GO

IF OBJECT_ID('dbo.sp_StoreMirror_GetFollowRelationship', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.sp_StoreMirror_GetFollowRelationship;
END
GO

CREATE PROCEDURE dbo.sp_StoreMirror_GetFollowRelationship
    @ViewerUserId NVARCHAR(64),
    @TargetUserId NVARCHAR(64)
AS
BEGIN
    SET NOCOUNT ON;

    SET @ViewerUserId = NULLIF(LTRIM(RTRIM(@ViewerUserId)), N'');
    SET @TargetUserId = NULLIF(LTRIM(RTRIM(@TargetUserId)), N'');

    IF (@ViewerUserId IS NULL)
    BEGIN
        RAISERROR('SQL_GATEWAY_INVALID_VIEWER_ID', 16, 1);
        RETURN;
    END

    IF (@TargetUserId IS NULL)
    BEGIN
        RAISERROR('SQL_GATEWAY_INVALID_TARGET_ID', 16, 1);
        RETURN;
    END

    DECLARE @Edges TABLE
    (
        Direction NVARCHAR(16) NOT NULL,
        FollowerUserId NVARCHAR(64) NOT NULL,
        TargetUserId NVARCHAR(64) NOT NULL,
        State NVARCHAR(16) NULL,
        Source NVARCHAR(32) NULL,
        CreatedAt DATETIMEOFFSET(3) NULL,
        UpdatedAt DATETIMEOFFSET(3) NULL,
        LastEventId NVARCHAR(128) NULL,
        LastEventTimestamp DATETIMEOFFSET(3) NULL,
        MetadataJson NVARCHAR(MAX) NULL
    );

    DECLARE @Blocks TABLE
    (
        Direction NVARCHAR(16) NOT NULL,
        UserId NVARCHAR(64) NOT NULL,
        TargetUserId NVARCHAR(64) NOT NULL,
        CreatedAt DATETIMEOFFSET(3) NULL,
        RevokedAt DATETIMEOFFSET(3) NULL,
        Source NVARCHAR(64) NULL,
        MetadataJson NVARCHAR(MAX) NULL
    );

    INSERT INTO @Edges
    SELECT TOP (1)
        Direction = N'outgoing',
        FollowerUserId,
        TargetUserId,
        State,
        Source,
        CreatedAt,
        UpdatedAt,
        LastEventId,
        LastEventTimestamp,
        MetadataJson
    FROM dbo.FollowEdge
    WHERE FollowerUserId = @ViewerUserId
      AND TargetUserId = @TargetUserId;

    INSERT INTO @Edges
    SELECT TOP (1)
        Direction = N'incoming',
        FollowerUserId,
        TargetUserId,
        State,
        Source,
        CreatedAt,
        UpdatedAt,
        LastEventId,
        LastEventTimestamp,
        MetadataJson
    FROM dbo.FollowEdge
    WHERE FollowerUserId = @TargetUserId
      AND TargetUserId = @ViewerUserId;

    SELECT
        Direction,
        FollowerUserId,
        TargetUserId,
        State,
        Source,
        CreatedAt,
        UpdatedAt,
        LastEventId,
        LastEventTimestamp,
        MetadataJson
    FROM @Edges
    ORDER BY CASE Direction WHEN N'outgoing' THEN 0 ELSE 1 END;

    INSERT INTO @Blocks
    SELECT TOP (1)
        Direction = N'outgoing',
        UserId,
        TargetUserId,
        CreatedAt,
        RevokedAt,
        Source,
        MetadataJson
    FROM dbo.DmBlock
    WHERE UserId = @ViewerUserId
      AND TargetUserId = @TargetUserId
      AND (RevokedAt IS NULL OR RevokedAt > SYSUTCDATETIME())
    ORDER BY CreatedAt DESC;

    INSERT INTO @Blocks
    SELECT TOP (1)
        Direction = N'incoming',
        UserId,
        TargetUserId,
        CreatedAt,
        RevokedAt,
        Source,
        MetadataJson
    FROM dbo.DmBlock
    WHERE UserId = @TargetUserId
      AND TargetUserId = @ViewerUserId
      AND (RevokedAt IS NULL OR RevokedAt > SYSUTCDATETIME())
    ORDER BY CreatedAt DESC;

    SELECT
        Direction,
        UserId,
        TargetUserId,
        CreatedAt,
        RevokedAt,
        Source,
        MetadataJson
    FROM @Blocks
    ORDER BY CASE Direction WHEN N'outgoing' THEN 0 ELSE 1 END;
END
GO

PRINT 'Procedure dbo.sp_StoreMirror_GetFollowRelationship created.';
GO
