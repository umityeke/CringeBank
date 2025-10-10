/*
  Procedure: dbo.sp_Admin_AssignBadge
  Purpose : Assigns or reactivates a badge for a user and logs the action.
*/

IF DB_ID() IS NULL
BEGIN
    RAISERROR('Database context is not set. Use the appropriate database before running this script.', 16, 1);
    RETURN;
END
GO

IF OBJECT_ID('dbo.sp_Admin_AssignBadge', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.sp_Admin_AssignBadge;
END
GO

CREATE PROCEDURE dbo.sp_Admin_AssignBadge
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
    DECLARE @BadgeIsActive BIT;
    DECLARE @ExistingActiveId BIGINT;
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

        SELECT TOP (1)
            @BadgeSlug = Slug,
            @BadgeTitle = Title,
            @BadgeIsActive = IsActive
        FROM dbo.Badges WITH (UPDLOCK, HOLDLOCK)
        WHERE BadgeId = @BadgeId;

        IF @BadgeSlug IS NULL
        BEGIN
            RAISERROR('Badge not found.', 16, 1);
        END

        IF @BadgeIsActive = 0
        BEGIN
            RAISERROR('Badge is not active.', 16, 1);
        END

        SELECT TOP (1)
            @ExistingActiveId = UserBadgeId
        FROM dbo.UserBadges WITH (UPDLOCK, HOLDLOCK)
        WHERE AuthUid = @TargetAuthUid
          AND BadgeId = @BadgeId
          AND RevokedAt IS NULL;

        IF @ExistingActiveId IS NOT NULL
        BEGIN
            UPDATE dbo.UserBadges
            SET Reason = CASE WHEN @Reason IS NULL THEN Reason ELSE NULLIF(LTRIM(RTRIM(@Reason)), N'') END,
                MetadataJson = CASE WHEN @MetadataJson IS NULL THEN MetadataJson ELSE NULLIF(LTRIM(RTRIM(@MetadataJson)), N'') END,
                GrantedByAuthUid = @ActorAuthUid,
                GrantedAt = @now
            WHERE UserBadgeId = @ExistingActiveId;

            SET @UserBadgeId = @ExistingActiveId;
        END
        ELSE
        BEGIN
            UPDATE dbo.UserBadges
            SET RevokedAt = NULL,
                RevokedByAuthUid = NULL,
                Reason = CASE WHEN @Reason IS NULL THEN Reason ELSE NULLIF(LTRIM(RTRIM(@Reason)), N'') END,
                MetadataJson = CASE WHEN @MetadataJson IS NULL THEN MetadataJson ELSE NULLIF(LTRIM(RTRIM(@MetadataJson)), N'') END,
                GrantedAt = @now,
                GrantedByAuthUid = @ActorAuthUid
            WHERE AuthUid = @TargetAuthUid
              AND BadgeId = @BadgeId
              AND RevokedAt IS NOT NULL;

            IF @@ROWCOUNT > 0
            BEGIN
                SELECT TOP (1)
                    @UserBadgeId = UserBadgeId
                FROM dbo.UserBadges
                WHERE AuthUid = @TargetAuthUid
                  AND BadgeId = @BadgeId
                  AND RevokedAt IS NULL;
            END
        END

        IF @UserBadgeId IS NULL
        BEGIN
            INSERT INTO dbo.UserBadges
            (
                AuthUid,
                BadgeId,
                GrantedAt,
                GrantedByAuthUid,
                RevokedAt,
                RevokedByAuthUid,
                Reason,
                MetadataJson
            )
            VALUES
            (
                @TargetAuthUid,
                @BadgeId,
                @now,
                @ActorAuthUid,
                NULL,
                NULL,
                NULLIF(LTRIM(RTRIM(@Reason)), N''),
                CASE WHEN @MetadataJson IS NULL OR LTRIM(RTRIM(@MetadataJson)) = N'' THEN NULL ELSE @MetadataJson END
            );

            SET @UserBadgeId = SCOPE_IDENTITY();
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
            @Action = N'badge.assign',
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

        RAISERROR('sp_Admin_AssignBadge failed (%d): %s', @ErrorSeverity, 1, @ErrorNumber, @ErrorMessage) WITH NOWAIT;
        RETURN;
    END CATCH

    SELECT UserBadgeId = @UserBadgeId;
END
GO

PRINT 'Procedure dbo.sp_Admin_AssignBadge created.';
GO
