/*
  Procedure: dbo.sp_Admin_UpdateBadge
  Purpose : Updates badge metadata and logs the change.
*/

IF DB_ID() IS NULL
BEGIN
    RAISERROR('Database context is not set. Use the appropriate database before running this script.', 16, 1);
    RETURN;
END
GO

IF OBJECT_ID('dbo.sp_Admin_UpdateBadge', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.sp_Admin_UpdateBadge;
END
GO

CREATE PROCEDURE dbo.sp_Admin_UpdateBadge
    @ActorAuthUid      NVARCHAR(64),
    @ActorRoleKey      NVARCHAR(64),
    @BadgeId           BIGINT,
    @Slug              NVARCHAR(64) = NULL,
    @Title             NVARCHAR(120) = NULL,
    @Description       NVARCHAR(400) = NULL,
    @IconUrl           NVARCHAR(512) = NULL,
    @Category          NVARCHAR(64) = NULL,
    @IsActive          BIT = NULL,
    @DisplayOrder      INT = NULL,
    @MetadataJson      NVARCHAR(MAX) = NULL,
    @IpAddress         NVARCHAR(64) = NULL,
    @UserAgent         NVARCHAR(256) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @now DATETIMEOFFSET(3) = SYSUTCDATETIME();
    DECLARE @CurrentSlug NVARCHAR(64);
    DECLARE @CurrentTitle NVARCHAR(120);
    DECLARE @CurrentDescription NVARCHAR(400);
    DECLARE @CurrentIconUrl NVARCHAR(512);
    DECLARE @CurrentCategory NVARCHAR(64);
    DECLARE @CurrentIsActive BIT;
    DECLARE @CurrentDisplayOrder INT;
    DECLARE @CurrentMetadata NVARCHAR(MAX);
    DECLARE @AuditPayload NVARCHAR(MAX);
    DECLARE @EntityId NVARCHAR(128);

    IF @ActorAuthUid IS NULL OR LTRIM(RTRIM(@ActorAuthUid)) = N''
    BEGIN
        RAISERROR('Actor auth uid is required.', 16, 1);
        RETURN;
    END

    IF @BadgeId IS NULL OR @BadgeId <= 0
    BEGIN
        RAISERROR('BadgeId is required.', 16, 1);
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT
            @CurrentSlug = Slug,
            @CurrentTitle = Title,
            @CurrentDescription = Description,
            @CurrentIconUrl = IconUrl,
            @CurrentCategory = Category,
            @CurrentIsActive = IsActive,
            @CurrentDisplayOrder = DisplayOrder,
            @CurrentMetadata = MetadataJson
        FROM dbo.Badges WITH (UPDLOCK, HOLDLOCK)
        WHERE BadgeId = @BadgeId;

        IF @@ROWCOUNT = 0
        BEGIN
            RAISERROR('Badge not found.', 16, 1);
        END

        IF @Slug IS NOT NULL AND LTRIM(RTRIM(@Slug)) <> LTRIM(RTRIM(@CurrentSlug))
        BEGIN
            IF EXISTS (
                SELECT 1
                FROM dbo.Badges WITH (UPDLOCK, HOLDLOCK)
                WHERE Slug = @Slug
                  AND BadgeId <> @BadgeId
            )
            BEGIN
                RAISERROR('Badge slug already exists.', 16, 1);
            END
        END

        UPDATE dbo.Badges
        SET Slug = COALESCE(NULLIF(LTRIM(RTRIM(@Slug)), N''), Slug),
            Title = COALESCE(NULLIF(LTRIM(RTRIM(@Title)), N''), Title),
            Description = CASE WHEN @Description IS NULL THEN Description ELSE NULLIF(LTRIM(RTRIM(@Description)), N'') END,
            IconUrl = CASE WHEN @IconUrl IS NULL THEN IconUrl ELSE NULLIF(LTRIM(RTRIM(@IconUrl)), N'') END,
            Category = CASE WHEN @Category IS NULL THEN Category ELSE NULLIF(LTRIM(RTRIM(@Category)), N'') END,
            IsActive = COALESCE(@IsActive, IsActive),
            DisplayOrder = COALESCE(@DisplayOrder, DisplayOrder),
            UpdatedAt = @now,
            UpdatedByAuthUid = @ActorAuthUid,
            MetadataJson = CASE WHEN @MetadataJson IS NULL THEN MetadataJson ELSE NULLIF(LTRIM(RTRIM(@MetadataJson)), N'') END
        WHERE BadgeId = @BadgeId;

        IF @@ROWCOUNT = 0
        BEGIN
            RAISERROR('Badge update failed.', 16, 1);
        END

        SELECT @AuditPayload = (
            SELECT
                Old = (
                    SELECT
                        @CurrentSlug AS slug,
                        @CurrentTitle AS title,
                        @CurrentDescription AS description,
                        @CurrentIconUrl AS iconUrl,
                        @CurrentCategory AS category,
                        @CurrentIsActive AS isActive,
                        @CurrentDisplayOrder AS displayOrder
                    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                ),
                New = (
                    SELECT
                        Slug AS slug,
                        Title AS title,
                        Description AS description,
                        IconUrl AS iconUrl,
                        Category AS category,
                        IsActive AS isActive,
                        DisplayOrder AS displayOrder
                    FROM dbo.Badges
                    WHERE BadgeId = @BadgeId
                    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                )
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );

        SET @EntityId = CAST(@BadgeId AS NVARCHAR(128));

        EXEC dbo.sp_Admin_LogAudit
            @ActorAuthUid = @ActorAuthUid,
            @ActorRoleKey = @ActorRoleKey,
            @TargetAuthUid = NULL,
            @Action = N'badge.update',
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

        RAISERROR('sp_Admin_UpdateBadge failed (%d): %s', @ErrorSeverity, 1, @ErrorNumber, @ErrorMessage) WITH NOWAIT;
        RETURN;
    END CATCH

    SELECT BadgeId = @BadgeId;
END
GO

PRINT 'Procedure dbo.sp_Admin_UpdateBadge created.';
GO
