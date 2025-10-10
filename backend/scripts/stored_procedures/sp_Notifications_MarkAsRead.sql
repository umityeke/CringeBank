-- =============================================
-- Stored Procedure: sp_Notifications_MarkAsRead
-- =============================================
-- Purpose: Mark notification(s) as read
-- =============================================

CREATE OR ALTER PROCEDURE sp_Notifications_MarkAsRead
    @RecipientAuthUid NVARCHAR(128),
    @NotificationPublicId NVARCHAR(50) = NULL -- If NULL, mark all as read
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Validation
    IF @RecipientAuthUid IS NULL OR LTRIM(RTRIM(@RecipientAuthUid)) = ''
    BEGIN
        RAISERROR('RecipientAuthUid is required', 16, 1);
        RETURN;
    END
    
    DECLARE @MarkedCount INT = 0;
    DECLARE @ReadAt DATETIME2 = GETUTCDATE();
    
    BEGIN TRY
        
        IF @NotificationPublicId IS NOT NULL AND LTRIM(RTRIM(@NotificationPublicId)) != ''
        BEGIN
            -- Mark specific notification as read
            UPDATE Notifications
            SET IsRead = 1,
                ReadAt = @ReadAt
            WHERE RecipientAuthUid = @RecipientAuthUid
                AND NotificationPublicId = @NotificationPublicId
                AND IsRead = 0;
            
            SET @MarkedCount = @@ROWCOUNT;
        END
        ELSE
        BEGIN
            -- Mark all unread notifications as read
            UPDATE Notifications
            SET IsRead = 1,
                ReadAt = @ReadAt
            WHERE RecipientAuthUid = @RecipientAuthUid
                AND IsRead = 0;
            
            SET @MarkedCount = @@ROWCOUNT;
        END
        
        SELECT @MarkedCount AS MarkedCount, 'Success' AS Message;
        
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END
GO

PRINT 'Stored Procedure sp_Notifications_MarkAsRead created successfully.';
GO
