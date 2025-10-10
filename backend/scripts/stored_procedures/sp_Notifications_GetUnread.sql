-- =============================================
-- Stored Procedure: sp_Notifications_GetUnread
-- =============================================
-- Purpose: Get user's unread notifications with pagination
-- =============================================

CREATE OR ALTER PROCEDURE sp_Notifications_GetUnread
    @RecipientAuthUid NVARCHAR(128),
    @Limit INT = 50,
    @BeforeNotificationId BIGINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Validation
    IF @RecipientAuthUid IS NULL OR LTRIM(RTRIM(@RecipientAuthUid)) = ''
    BEGIN
        RAISERROR('RecipientAuthUid is required', 16, 1);
        RETURN;
    END
    
    IF @Limit > 100
    BEGIN
        RAISERROR('Limit cannot exceed 100 notifications', 16, 1);
        RETURN;
    END
    
    -- Get unread notifications
    SELECT TOP (@Limit)
        NotificationId,
        NotificationPublicId,
        RecipientAuthUid,
        SenderAuthUid,
        NotificationType,
        Title,
        Body,
        ActionUrl,
        ImageUrl,
        MetadataJson,
        IsRead,
        IsPushed,
        CreatedAt,
        ReadAt,
        PushedAt
    FROM Notifications
    WHERE RecipientAuthUid = @RecipientAuthUid
        AND IsRead = 0
        AND (@BeforeNotificationId IS NULL OR NotificationId < @BeforeNotificationId)
    ORDER BY NotificationId DESC;
    
END
GO

PRINT 'Stored Procedure sp_Notifications_GetUnread created successfully.';
GO
