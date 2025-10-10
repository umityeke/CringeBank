/*
  Procedure: dbo.sp_Admin_RevokeBadge
  Purpose : Revokes a user's badge assignment and logs the action.
*/

IF DB_ID() IS NULL
BEGIN
    RAISERROR('Database context is not set. Use the appropriate database before running this script.', 16, 1);
    RETURN;
END
GO

IF OBJECT_ID('dbo.sp_Admin_RevokeBadge', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.sp_Admin_RevokeBadge;
END
GO

CREATE PROCEDURE dbo.sp_Admin_RevokeBadge
    @ActorAuthUid      NVARCHAR(64),
    @ActorRoleKey      NVARCHAR(64),
    @TargetAuthUid     NVARCHAR(64),
    @BadgeId           BIGINT,
    @Reason            NVARCHAR(400) = NULL,
    @MetadataJson      NVARCHAR(MAX) = NULL,
    @IpAddress         NVARCHAR(64) = NULL,
    @UserAgent         NVARCHAR(256) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @now DATETIMEOFFSET(3) = SYSUTCDATETIME();
    DECLARE @UserBadgeId BIGINT;
    DECLARE @BadgeSlug NVARCHAR(64);
    DECLARE @BadgeTitle NVARCHAR(120);
    DECLARE @AuditPayload NVARCHAR(MAX);
    DECLARE @EntityId NVARCHAR(128);

    IF @ActorAuthUid IS NULL OR LTRIM(RTRIM(@ActorAuthUid)) = N''
    BEGIN
        RAISERROR('Actor auth uid is required.', 16, 1);
        RETURN;
    END

    IF @TargetAuthUid IS NULL OR LTRIM(RTRIM(@TargetAuthUid)) = N''
    BEGIN
        RAISERROR('Target auth uid is required.', 16, 1);
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
            @BadgeSlug = Slug,
            @BadgeTitle = Title
        FROM dbo.Badges
        WHERE BadgeId = @BadgeId;

        IF @BadgeSlug IS NULL
        BEGIN
            RAISERROR('Badge not found.', 16, 1);
        END

        SELECT TOP (1)
            @UserBadgeId = UserBadgeId
        FROM dbo.UserBadges WITH (UPDLOCK, HOLDLOCK)
        WHERE AuthUid = @TargetAuthUid
          AND BadgeId = @BadgeId
          AND RevokedAt IS NULL;

        IF @UserBadgeId IS NULL
        BEGIN
            RAISERROR('Active user badge not found.', 16, 1);
        END

        UPDATE dbo.UserBadges
        SET RevokedAt = @now,
            RevokedByAuthUid = @ActorAuthUid,
            Reason = CASE WHEN @Reason IS NULL THEN Reason ELSE NULLIF(LTRIM(RTRIM(@Reason)), N'') END,
            MetadataJson = CASE WHEN @MetadataJson IS NULL THEN MetadataJson ELSE NULLIF(LTRIM(RTRIM(@MetadataJson)), N'') END
        WHERE UserBadgeId = @UserBadgeId;

        IF @@ROWCOUNT = 0
        BEGIN
            RAISERROR('Badge revoke failed.', 16, 1);
        END

        SELECT @AuditPayload = (
            SELECT
                badgeId = @BadgeId,
                badgeSlug = @BadgeSlug,
                badgeTitle = @BadgeTitle,
                targetAuthUid = @TargetAuthUid,
                reason = @Reason
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );

        SET @EntityId = CAST(@UserBadgeId AS NVARCHAR(128));

        EXEC dbo.sp_Admin_LogAudit
            @ActorAuthUid = @ActorAuthUid,
            @ActorRoleKey = @ActorRoleKey,
            @TargetAuthUid = @TargetAuthUid,
            @Action = N'badge.revoke',
            @EntityType = N'user_badge',
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

        RAISERROR('sp_Admin_RevokeBadge failed (%d): %s', @ErrorSeverity, 1, @ErrorNumber, @ErrorMessage) WITH NOWAIT;
        RETURN;
    END CATCH

    SELECT UserBadgeId = @UserBadgeId;
END
GO

PRINT 'Procedure dbo.sp_Admin_RevokeBadge created.';
GO
