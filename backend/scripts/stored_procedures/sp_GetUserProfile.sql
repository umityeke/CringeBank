/*
  Stored Procedure: dbo.sp_GetUserProfile
  Purpose: Fetch a single dbo.Users row by AuthUid and expose read metadata.
  Usage:
    sqlcmd -S <server> -d <database> -U <user> -P <password> -b -i stored_procedures/sp_GetUserProfile.sql
*/

IF DB_ID() IS NULL
BEGIN
    RAISERROR('Database context is not set. Use the appropriate database before running this script.', 16, 1);
    RETURN;
END
GO

IF OBJECT_ID('dbo.Users', 'U') IS NULL
BEGIN
    RAISERROR('dbo.Users table is missing. Run the necessary migrations before creating dbo.sp_GetUserProfile.', 16, 1);
    RETURN;
END
GO

PRINT 'Creating or altering dbo.sp_GetUserProfile';
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetUserProfile
    @AuthUid NVARCHAR(64)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @authUidTrimmed NVARCHAR(64) = NULLIF(LTRIM(RTRIM(@AuthUid)), '');
    IF @authUidTrimmed IS NULL
    BEGIN
        RAISERROR('AuthUid is required.', 16, 1);
        RETURN;
    END

    SELECT TOP (1)
        Id AS UserId,
        AuthUid,
        Email,
        Username,
        DisplayName,
        CreatedAt,
        UpdatedAt
    FROM dbo.Users
    WHERE AuthUid = @authUidTrimmed;

    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR('USER_NOT_FOUND', 16, 1);
    END
END
GO

PRINT 'dbo.sp_GetUserProfile deployed successfully.';
GO
