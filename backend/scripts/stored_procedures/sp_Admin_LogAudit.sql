/*
  Procedure: dbo.sp_Admin_LogAudit
  Purpose : Inserts an immutable admin audit log entry.
*/

IF DB_ID() IS NULL
BEGIN
    RAISERROR('Database context is not set. Use the appropriate database before running this script.', 16, 1);
    RETURN;
END
GO

IF OBJECT_ID('dbo.sp_Admin_LogAudit', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.sp_Admin_LogAudit;
END
GO

CREATE PROCEDURE dbo.sp_Admin_LogAudit
    @ActorAuthUid      NVARCHAR(64),
    @ActorRoleKey      NVARCHAR(64) = NULL,
    @TargetAuthUid     NVARCHAR(64) = NULL,
    @Action            NVARCHAR(64),
    @EntityType        NVARCHAR(64),
    @EntityId          NVARCHAR(128) = NULL,
    @PayloadJson       NVARCHAR(MAX) = NULL,
    @IpAddress         NVARCHAR(64) = NULL,
    @UserAgent         NVARCHAR(256) = NULL,
    @MetadataJson      NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @ActorAuthUid IS NULL OR LTRIM(RTRIM(@ActorAuthUid)) = N''
    BEGIN
        RAISERROR('Actor auth uid is required.', 16, 1);
        RETURN;
    END

    IF @Action IS NULL OR LTRIM(RTRIM(@Action)) = N''
    BEGIN
        RAISERROR('Action is required.', 16, 1);
        RETURN;
    END

    IF @EntityType IS NULL OR LTRIM(RTRIM(@EntityType)) = N''
    BEGIN
        RAISERROR('Entity type is required.', 16, 1);
        RETURN;
    END

    INSERT INTO dbo.AdminAuditLog
    (
        OccurredAt,
        ActorAuthUid,
        ActorRoleKey,
        TargetAuthUid,
        Action,
        EntityType,
        EntityId,
        PayloadJson,
        IpAddress,
        UserAgent,
        MetadataJson
    )
    VALUES
    (
        SYSUTCDATETIME(),
        @ActorAuthUid,
        NULLIF(LTRIM(RTRIM(@ActorRoleKey)), N''),
        NULLIF(LTRIM(RTRIM(@TargetAuthUid)), N''),
        LTRIM(RTRIM(@Action)),
        LTRIM(RTRIM(@EntityType)),
        CASE WHEN @EntityId IS NULL OR LTRIM(RTRIM(@EntityId)) = N'' THEN NULL ELSE LEFT(@EntityId, 128) END,
        CASE WHEN @PayloadJson IS NULL OR LTRIM(RTRIM(@PayloadJson)) = N'' THEN NULL ELSE @PayloadJson END,
        CASE WHEN @IpAddress IS NULL OR LTRIM(RTRIM(@IpAddress)) = N'' THEN NULL ELSE @IpAddress END,
        CASE WHEN @UserAgent IS NULL OR LTRIM(RTRIM(@UserAgent)) = N'' THEN NULL ELSE LEFT(@UserAgent, 256) END,
        CASE WHEN @MetadataJson IS NULL OR LTRIM(RTRIM(@MetadataJson)) = N'' THEN NULL ELSE @MetadataJson END
    );

    SELECT AuditId = SCOPE_IDENTITY();
END
GO

PRINT 'Procedure dbo.sp_Admin_LogAudit created.';
GO
