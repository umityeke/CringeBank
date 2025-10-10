-- =============================================
-- Stored Procedure: sp_Notifications_Create
-- =============================================
-- Purpose: Create new notification
-- =============================================

CREATE OR ALTER PROCEDURE sp_Notifications_Create
    @NotificationPublicId NVARCHAR(50),
    @RecipientAuthUid NVARCHAR(128),
    @SenderAuthUid NVARCHAR(128) = NULL,
    @NotificationType NVARCHAR(50),
    @Title NVARCHAR(200),
    @Body NVARCHAR(1000),
    @ActionUrl NVARCHAR(500) = NULL,
    @ImageUrl NVARCHAR(500) = NULL,
    @MetadataJson NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Validation
    IF @NotificationPublicId IS NULL OR LTRIM(RTRIM(@NotificationPublicId)) = ''
    BEGIN
        RAISERROR('NotificationPublicId is required', 16, 1);
        RETURN;
    END
    
    IF @RecipientAuthUid IS NULL OR LTRIM(RTRIM(@RecipientAuthUid)) = ''
    BEGIN
        RAISERROR('RecipientAuthUid is required', 16, 1);
        RETURN;
    END
    
    IF @NotificationType IS NULL OR LTRIM(RTRIM(@NotificationType)) = ''
    BEGIN
        RAISERROR('NotificationType is required', 16, 1);
        RETURN;
    END
    
    IF @Title IS NULL OR LTRIM(RTRIM(@Title)) = ''
    BEGIN
        RAISERROR('Title is required', 16, 1);
        RETURN;
    END
    
    IF @Body IS NULL OR LTRIM(RTRIM(@Body)) = ''
    BEGIN
        RAISERROR('Body is required', 16, 1);
        RETURN;
    END
    
    DECLARE @NotificationId BIGINT;
    DECLARE @CreatedAt DATETIME2 = GETUTCDATE();
    
    BEGIN TRY
        
        INSERT INTO Notifications (
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
            CreatedAt
        )
        VALUES (
            @NotificationPublicId,
            @RecipientAuthUid,
            @SenderAuthUid,
            @NotificationType,
            @Title,
            @Body,
            @ActionUrl,
            @ImageUrl,
            @MetadataJson,
            0,
            0,
            @CreatedAt
        );
        
        SET @NotificationId = SCOPE_IDENTITY();
        
        -- Return created notification
        SELECT 
            @NotificationId AS NotificationId,
            @NotificationPublicId AS NotificationPublicId,
            @CreatedAt AS CreatedAt,
            'Notification created successfully' AS Message;
        
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END
GO

PRINT 'Stored Procedure sp_Notifications_Create created successfully.';
GO
