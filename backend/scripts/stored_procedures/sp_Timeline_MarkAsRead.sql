-- =============================================
-- Stored Procedure: sp_Timeline_MarkAsRead
-- =============================================
-- Purpose: Mark timeline events as read for a user
-- =============================================

USE CringeBankDb;
GO

IF OBJECT_ID('sp_Timeline_MarkAsRead', 'P') IS NOT NULL
    DROP PROCEDURE sp_Timeline_MarkAsRead;
GO

CREATE PROCEDURE sp_Timeline_MarkAsRead
    @ViewerAuthUid NVARCHAR(128),
    @EventPublicIds NVARCHAR(MAX) = NULL, -- Comma-separated list of EventPublicIds (optional)
    @MarkAllAsRead BIT = 0 -- If true, mark all unread events as read
AS
BEGIN
    SET NOCOUNT ON;

    -- Validation
    IF @ViewerAuthUid IS NULL OR LEN(@ViewerAuthUid) = 0
    BEGIN
        RAISERROR('ViewerAuthUid is required', 16, 1);
        RETURN;
    END

    DECLARE @MarkedCount INT = 0;
    DECLARE @ReadAt DATETIME2 = GETUTCDATE();

    BEGIN TRANSACTION;

    BEGIN TRY
        IF @MarkAllAsRead = 1
        BEGIN
            -- Mark all unread events as read
            UPDATE UserTimeline
            SET IsRead = 1,
                ReadAt = @ReadAt
            WHERE ViewerAuthUid = @ViewerAuthUid
              AND IsRead = 0;

            SET @MarkedCount = @@ROWCOUNT;
        END
        ELSE IF @EventPublicIds IS NOT NULL AND LEN(@EventPublicIds) > 0
        BEGIN
            -- Mark specific events as read
            UPDATE UserTimeline
            SET IsRead = 1,
                ReadAt = @ReadAt
            WHERE ViewerAuthUid = @ViewerAuthUid
              AND EventPublicId IN (SELECT value FROM STRING_SPLIT(@EventPublicIds, ','))
              AND IsRead = 0;

            SET @MarkedCount = @@ROWCOUNT;
        END

        COMMIT TRANSACTION;

        -- Return result
        SELECT 
            @MarkedCount AS MarkedCount,
            @ReadAt AS ReadAt,
            'Events marked as read' AS Message;

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

PRINT 'Stored procedure sp_Timeline_MarkAsRead created successfully';
GO
