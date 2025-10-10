/*
  Stored Procedure: dbo.sp_EnsureUser
  Usage:
    sqlcmd -S <server> -d <database> -U <user> -P <password> -b -i stored_procedures/sp_EnsureUser.sql
*/

IF DB_ID() IS NULL
BEGIN
    RAISERROR('Database context is not set. Use the appropriate database before running this script.', 16, 1);
    RETURN;
END
GO

IF OBJECT_ID('dbo.Users', 'U') IS NULL
BEGIN
    RAISERROR('dbo.Users table is missing. Run the Users table migration before creating dbo.sp_EnsureUser.', 16, 1);
    RETURN;
END
GO

PRINT 'Creating or altering dbo.sp_EnsureUser';
GO

CREATE OR ALTER PROCEDURE dbo.sp_EnsureUser
    @AuthUid NVARCHAR(64),
    @Email NVARCHAR(256) = NULL,
    @Username NVARCHAR(64),
    @DisplayName NVARCHAR(128) = NULL,
    @UserId INT OUTPUT,
    @Created BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @authUidTrimmed NVARCHAR(64) = LTRIM(RTRIM(@AuthUid));
    IF @authUidTrimmed IS NULL OR @authUidTrimmed = ''
    BEGIN
        RAISERROR('AuthUid is required.', 16, 1);
        RETURN;
    END

    DECLARE @emailNormalized NVARCHAR(256) = NULLIF(LTRIM(RTRIM(@Email)), '');
    IF @emailNormalized IS NOT NULL
    BEGIN
        SET @emailNormalized = LOWER(@emailNormalized);
    END

    DECLARE @usernameNormalized NVARCHAR(64) = NULLIF(LTRIM(RTRIM(@Username)), '');
    IF @usernameNormalized IS NULL
    BEGIN
        SET @usernameNormalized = @authUidTrimmed;
    END

    DECLARE @displayNameNormalized NVARCHAR(128) = NULLIF(LTRIM(RTRIM(@DisplayName)), '');
    IF @displayNameNormalized IS NULL
    BEGIN
        SET @displayNameNormalized = @usernameNormalized;
    END

    DECLARE @now DATETIME2(3) = SYSUTCDATETIME();

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT TOP (1)
            @UserId = Id
        FROM dbo.Users WITH (UPDLOCK, HOLDLOCK)
        WHERE AuthUid = @authUidTrimmed;

        IF @UserId IS NOT NULL
        BEGIN
            UPDATE dbo.Users
            SET
                Email = CASE WHEN @emailNormalized IS NULL THEN Email ELSE @emailNormalized END,
                Username = @usernameNormalized,
                DisplayName = CASE WHEN @displayNameNormalized IS NULL THEN DisplayName ELSE @displayNameNormalized END,
                UpdatedAt = @now
            WHERE Id = @UserId;

            SET @Created = 0;
            COMMIT TRANSACTION;
            RETURN;
        END

        INSERT INTO dbo.Users (AuthUid, Email, Username, DisplayName, CreatedAt, UpdatedAt)
        VALUES (@authUidTrimmed, @emailNormalized, @usernameNormalized, @displayNameNormalized, @now, @now);

        SET @UserId = SCOPE_IDENTITY();
        SET @Created = 1;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
        BEGIN
            ROLLBACK TRANSACTION;
        END

        IF ERROR_NUMBER() IN (2601, 2627)
        BEGIN
            BEGIN TRY
                BEGIN TRANSACTION;

                SELECT TOP (1)
                    @UserId = Id
                FROM dbo.Users WITH (UPDLOCK, HOLDLOCK)
                WHERE AuthUid = @authUidTrimmed;

                IF @UserId IS NULL
                BEGIN
                    RAISERROR('Unique constraint violation occurred but no existing user was found for AuthUid %s.', 16, 1, @authUidTrimmed);
                    ROLLBACK TRANSACTION;
                    RETURN;
                END

                UPDATE dbo.Users
                SET
                    Email = CASE WHEN @emailNormalized IS NULL THEN Email ELSE @emailNormalized END,
                    Username = @usernameNormalized,
                    DisplayName = CASE WHEN @displayNameNormalized IS NULL THEN DisplayName ELSE @displayNameNormalized END,
                    UpdatedAt = @now
                WHERE Id = @UserId;

                SET @Created = 0;
                COMMIT TRANSACTION;
                RETURN;
            END TRY
            BEGIN CATCH
                IF XACT_STATE() <> 0
                BEGIN
                    ROLLBACK TRANSACTION;
                END

                DECLARE @errMsgDup NVARCHAR(4000) = ERROR_MESSAGE();
                DECLARE @errSeverityDup INT = ERROR_SEVERITY();
                DECLARE @errStateDup INT = ERROR_STATE();
                RAISERROR(@errMsgDup, @errSeverityDup, @errStateDup);
            END CATCH
        END

        DECLARE @errMsg NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @errSeverity INT = ERROR_SEVERITY();
        DECLARE @errState INT = ERROR_STATE();
        RAISERROR(@errMsg, @errSeverity, @errState);
    END CATCH
END
GO

PRINT 'dbo.sp_EnsureUser deployed successfully.';
GO
