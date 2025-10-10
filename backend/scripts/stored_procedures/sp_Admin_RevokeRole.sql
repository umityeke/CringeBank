/*
  Procedure: dbo.sp_Admin_RevokeRole
  Purpose : Revokes an admin role assignment and logs the action.
*/

IF DB_ID() IS NULL
BEGIN
    RAISERROR('Database context is not set. Use the appropriate database before running this script.', 16, 1);
    RETURN;
END
GO

IF OBJECT_ID('dbo.sp_Admin_RevokeRole', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.sp_Admin_RevokeRole;
END
GO

CREATE PROCEDURE dbo.sp_Admin_RevokeRole
    @ActorAuthUid      NVARCHAR(64),
    @ActorRoleKey      NVARCHAR(64),
    @TargetAuthUid     NVARCHAR(64),
    @RoleKey           NVARCHAR(64),
    @Reason            NVARCHAR(400) = NULL,
    @MetadataJson      NVARCHAR(MAX) = NULL,
    @IpAddress         NVARCHAR(64) = NULL,
    @UserAgent         NVARCHAR(256) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @now DATETIMEOFFSET(3) = SYSUTCDATETIME();
    DECLARE @AdminRoleId BIGINT;
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

    IF @RoleKey IS NULL OR LTRIM(RTRIM(@RoleKey)) = N''
    BEGIN
        RAISERROR('Role key is required.', 16, 1);
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT TOP (1)
            @AdminRoleId = AdminRoleId
        FROM dbo.AdminRoles WITH (UPDLOCK, HOLDLOCK)
        WHERE AuthUid = @TargetAuthUid
          AND RoleKey = @RoleKey
          AND RevokedAt IS NULL;

        IF @AdminRoleId IS NULL
        BEGIN
            RAISERROR('Active admin role not found.', 16, 1);
        END

        UPDATE dbo.AdminRoles
        SET RevokedAt = @now,
            RevokedByAuthUid = @ActorAuthUid,
            Status = 'revoked',
            MetadataJson = CASE WHEN @MetadataJson IS NULL THEN MetadataJson ELSE NULLIF(LTRIM(RTRIM(@MetadataJson)), N'') END
        WHERE AdminRoleId = @AdminRoleId;

        IF @@ROWCOUNT = 0
        BEGIN
            RAISERROR('Role revoke failed.', 16, 1);
        END

        SELECT @AuditPayload = (
            SELECT
                adminRoleId = @AdminRoleId,
                targetAuthUid = @TargetAuthUid,
                roleKey = @RoleKey,
                reason = @Reason
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );

        SET @EntityId = CAST(@AdminRoleId AS NVARCHAR(128));

        EXEC dbo.sp_Admin_LogAudit
            @ActorAuthUid = @ActorAuthUid,
            @ActorRoleKey = @ActorRoleKey,
            @TargetAuthUid = @TargetAuthUid,
            @Action = N'role.revoke',
            @EntityType = N'admin_role',
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

        RAISERROR('sp_Admin_RevokeRole failed (%d): %s', @ErrorSeverity, 1, @ErrorNumber, @ErrorMessage) WITH NOWAIT;
        RETURN;
    END CATCH

    SELECT AdminRoleId = @AdminRoleId;
END
GO

PRINT 'Procedure dbo.sp_Admin_RevokeRole created.';
GO
