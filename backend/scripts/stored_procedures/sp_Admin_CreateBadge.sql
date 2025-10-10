/*
  Procedure: dbo.sp_Admin_CreateBadge
  Purpose : Creates a new badge definition and logs the action.
*/

IF DB_ID() IS NULL
BEGIN
    RAISERROR('Database context is not set. Use the appropriate database before running this script.', 16, 1);
    RETURN;
END
GO

IF OBJECT_ID('dbo.sp_Admin_CreateBadge', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.sp_Admin_CreateBadge;
END
GO

CREATE PROCEDURE dbo.sp_Admin_CreateBadge
    @ActorAuthUid      NVARCHAR(64),
    @ActorRoleKey      NVARCHAR(64),
    @Slug              NVARCHAR(64),
    @Title             NVARCHAR(120),
    @Description       NVARCHAR(400) = NULL,
    @IconUrl           NVARCHAR(512) = NULL,
    @Category          NVARCHAR(64) = NULL,
    @DisplayOrder      INT = NULL,
    @MetadataJson      NVARCHAR(MAX) = NULL,
    @IpAddress         NVARCHAR(64) = NULL,
    @UserAgent         NVARCHAR(256) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @now DATETIMEOFFSET(3) = SYSUTCDATETIME();
    DECLARE @BadgeId BIGINT;
    DECLARE @AuditPayload NVARCHAR(MAX);
    DECLARE @EntityId NVARCHAR(128);

    IF @ActorAuthUid IS NULL OR LTRIM(RTRIM(@ActorAuthUid)) = N''
    BEGIN
        RAISERROR('Actor auth uid is required.', 16, 1);
        RETURN;
    END

    IF @Slug IS NULL OR LTRIM(RTRIM(@Slug)) = N''
    BEGIN
        RAISERROR('Badge slug is required.', 16, 1);
        RETURN;
    END

    IF @Title IS NULL OR LTRIM(RTRIM(@Title)) = N''
    BEGIN
        RAISERROR('Badge title is required.', 16, 1);
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        IF EXISTS (
            SELECT 1
            FROM dbo.Badges WITH (UPDLOCK, HOLDLOCK)
            WHERE Slug = @Slug
        )
        BEGIN
            RAISERROR('Badge slug already exists.', 16, 1);
        END

        INSERT INTO dbo.Badges
        (
            Slug,
            Title,
            Description,
            IconUrl,
            Category,
            IsActive,
            DisplayOrder,
            CreatedAt,
            UpdatedAt,
            CreatedByAuthUid,
            UpdatedByAuthUid,
            MetadataJson
        )
        VALUES
        (
            LTRIM(RTRIM(@Slug)),
            LTRIM(RTRIM(@Title)),
            NULLIF(LTRIM(RTRIM(@Description)), N''),
            NULLIF(LTRIM(RTRIM(@IconUrl)), N''),
            NULLIF(LTRIM(RTRIM(@Category)), N''),
            1,
            @DisplayOrder,
            @now,
            @now,
            @ActorAuthUid,
            @ActorAuthUid,
            CASE WHEN @MetadataJson IS NULL OR LTRIM(RTRIM(@MetadataJson)) = N'' THEN NULL ELSE @MetadataJson END
        );

        SET @BadgeId = SCOPE_IDENTITY();

        SELECT @AuditPayload = (SELECT @Slug AS slug, @Title AS title FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

        SET @EntityId = CAST(@BadgeId AS NVARCHAR(128));

        EXEC dbo.sp_Admin_LogAudit
            @ActorAuthUid = @ActorAuthUid,
            @ActorRoleKey = @ActorRoleKey,
            @TargetAuthUid = NULL,
            @Action = N'badge.create',
            @EntityType = N'badge',
            @EntityId = @EntityId,
            @PayloadJson = @AuditPayload,
            @IpAddress = @IpAddress,
            @UserAgent = @UserAgent,
            @MetadataJson = NULL;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
        BEGIN
            ROLLBACK TRANSACTION;
        END

        DECLARE @ErrorNumber INT = ERROR_NUMBER();
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();

        RAISERROR('sp_Admin_CreateBadge failed (%d): %s', @ErrorSeverity, 1, @ErrorNumber, @ErrorMessage) WITH NOWAIT;
        RETURN;
    END CATCH

    SELECT BadgeId = @BadgeId;
END
GO

PRINT 'Procedure dbo.sp_Admin_CreateBadge created.';
GO
