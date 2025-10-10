-- =============================================
-- Stored Procedure: sp_Timeline_FollowUser
-- =============================================
-- Purpose: Create or update follow relationship
-- =============================================

USE CringeBankDb;
GO

IF OBJECT_ID('sp_Timeline_FollowUser', 'P') IS NOT NULL
    DROP PROCEDURE sp_Timeline_FollowUser;
GO

CREATE PROCEDURE sp_Timeline_FollowUser
    @FollowerAuthUid NVARCHAR(128),
    @FollowedAuthUid NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;

    -- Validation
    IF @FollowerAuthUid IS NULL OR LEN(@FollowerAuthUid) = 0
    BEGIN
        RAISERROR('FollowerAuthUid is required', 16, 1);
        RETURN;
    END

    IF @FollowedAuthUid IS NULL OR LEN(@FollowedAuthUid) = 0
    BEGIN
        RAISERROR('FollowedAuthUid is required', 16, 1);
        RETURN;
    END

    IF @FollowerAuthUid = @FollowedAuthUid
    BEGIN
        RAISERROR('Cannot follow yourself', 16, 1);
        RETURN;
    END

    DECLARE @CreatedAt DATETIME2 = GETUTCDATE();
    DECLARE @IsNew BIT = 0;

    BEGIN TRANSACTION;

    BEGIN TRY
        -- Check if follow relationship already exists
        IF EXISTS (
            SELECT 1 FROM UserFollows
            WHERE FollowerAuthUid = @FollowerAuthUid
              AND FollowedAuthUid = @FollowedAuthUid
        )
        BEGIN
            -- Reactivate if unfollowed before
            UPDATE UserFollows
            SET IsActive = 1,
                UnfollowedAt = NULL
            WHERE FollowerAuthUid = @FollowerAuthUid
              AND FollowedAuthUid = @FollowedAuthUid
              AND IsActive = 0;
        END
        ELSE
        BEGIN
            -- Create new follow relationship
            INSERT INTO UserFollows (
                FollowerAuthUid,
                FollowedAuthUid,
                CreatedAt,
                IsActive,
                UnfollowedAt
            )
            VALUES (
                @FollowerAuthUid,
                @FollowedAuthUid,
                @CreatedAt,
                1,
                NULL
            );

            SET @IsNew = 1;
        END

        COMMIT TRANSACTION;

        -- Return success
        SELECT 
            @IsNew AS IsNew,
            @CreatedAt AS CreatedAt,
            'Follow relationship created' AS Message;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();

        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END
GO

PRINT 'Stored procedure sp_Timeline_FollowUser created successfully';
GO
