/*
  Procedure: dbo.sp_Admin_ListRoles
  Purpose : Lists admin role assignments with optional filtering by user or status.
*/

IF DB_ID() IS NULL
BEGIN
    RAISERROR('Database context is not set. Use the appropriate database before running this script.', 16, 1);
    RETURN;
END
GO

IF OBJECT_ID('dbo.sp_Admin_ListRoles', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.sp_Admin_ListRoles;
END
GO

CREATE PROCEDURE dbo.sp_Admin_ListRoles
    @AuthUid   NVARCHAR(64) = NULL,
    @Status    NVARCHAR(32) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        AdminRoleId,
        AuthUid,
        RoleKey,
        Status,
        ScopeJson,
        GrantedAt,
        GrantedByAuthUid,
        RevokedAt,
        RevokedByAuthUid,
        MetadataJson,
        RowVersion
    FROM dbo.AdminRoles
    WHERE (@AuthUid IS NULL OR AuthUid = @AuthUid)
      AND (@Status IS NULL OR Status = @Status)
    ORDER BY GrantedAt DESC;
END
GO

PRINT 'Procedure dbo.sp_Admin_ListRoles created.';
GO
