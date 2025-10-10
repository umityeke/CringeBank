-- =============================================
-- Stored Procedure: sp_DM_MarkAsRead
-- Created: 2025-10-09
-- Purpose: Mark all unread messages in conversation as read
-- =============================================

CREATE OR ALTER PROCEDURE sp_DM_MarkAsRead
    @ConversationId NVARCHAR(100),
    @ReaderAuthUid NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Verify reader is a participant
    DECLARE @IsParticipant BIT = 0;
    
    SELECT @IsParticipant = 1
    FROM Conversations
    WHERE ConversationId = @ConversationId
      AND (Participant1AuthUid = @ReaderAuthUid OR Participant2AuthUid = @ReaderAuthUid);
    
    IF @IsParticipant = 0
    BEGIN
        RAISERROR('Unauthorized: Not a conversation participant', 16, 1);
        RETURN;
    END
    
    BEGIN TRANSACTION;
    
    BEGIN TRY
        DECLARE @MarkedCount INT;
        
        -- Mark all unread messages as read
        UPDATE Messages
        SET IsRead = 1, ReadAt = GETUTCDATE()
        WHERE ConversationId = @ConversationId
          AND RecipientAuthUid = @ReaderAuthUid
          AND IsRead = 0;
        
        SET @MarkedCount = @@ROWCOUNT;
        
        -- Reset unread count in conversation
        UPDATE Conversations
        SET 
            UnreadCountP1 = CASE WHEN Participant1AuthUid = @ReaderAuthUid THEN 0 ELSE UnreadCountP1 END,
            UnreadCountP2 = CASE WHEN Participant2AuthUid = @ReaderAuthUid THEN 0 ELSE UnreadCountP2 END,
            UpdatedAt = GETUTCDATE()
        WHERE ConversationId = @ConversationId;
        
        COMMIT TRANSACTION;
        
        -- Return result
        SELECT @MarkedCount AS MessagesMarkedAsRead;
        
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH;
END
GO
