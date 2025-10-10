-- =============================================
-- Stored Procedure: sp_Notifications_MarkAsPushed
-- =============================================
-- Purpose: Mark notification as pushed (FCM sent successfully)
-- =============================================

CREATE OR ALTER PROCEDURE sp_Notifications_MarkAsPushed
    @NotificationPublicId NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Validation
    IF @NotificationPublicId IS NULL OR LTRIM(RTRIM(@NotificationPublicId)) = ''
    BEGIN
        RAISERROR('NotificationPublicId is required', 16, 1);
        RETURN;
    END
    
    DECLARE @PushedAt DATETIME2 = GETUTCDATE();
    
    BEGIN TRY
        
        UPDATE Notifications
        SET IsPushed = 1,
            PushedAt = @PushedAt
        WHERE NotificationPublicId = @NotificationPublicId
            AND IsPushed = 0;
        
        DECLARE @UpdatedCount INT = @@ROWCOUNT;
        
        SELECT @UpdatedCount AS UpdatedCount, 'Success' AS Message;
        
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END
GO

PRINT 'Stored Procedure sp_Notifications_MarkAsPushed created successfully.';
GO
