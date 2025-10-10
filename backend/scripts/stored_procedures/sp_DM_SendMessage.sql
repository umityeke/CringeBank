-- =============================================
-- Stored Procedure: sp_DM_SendMessage
-- Created: 2025-10-09
-- Purpose: Send a message and update conversation metadata
-- =============================================

CREATE OR ALTER PROCEDURE sp_DM_SendMessage
    @MessagePublicId NVARCHAR(50),
    @SenderAuthUid NVARCHAR(128),
    @RecipientAuthUid NVARCHAR(128),
    @MessageText NVARCHAR(MAX) = NULL,
    @MessageType NVARCHAR(20) = 'TEXT',
    @ImageUrl NVARCHAR(500) = NULL,
    @VoiceUrl NVARCHAR(500) = NULL,
    @VoiceDurationSec INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Validation
    IF @SenderAuthUid = @RecipientAuthUid
    BEGIN
        RAISERROR('Cannot send message to yourself', 16, 1);
        RETURN;
    END
    
    IF @MessageText IS NULL AND @ImageUrl IS NULL AND @VoiceUrl IS NULL
    BEGIN
        RAISERROR('Message must have text, image, or voice content', 16, 1);
        RETURN;
    END
    
    DECLARE @ConversationId NVARCHAR(100);
    DECLARE @PreviewText NVARCHAR(500);
    
    -- Generate conversation ID (sorted alphabetically for consistency)
    IF @SenderAuthUid < @RecipientAuthUid
        SET @ConversationId = @SenderAuthUid + '_' + @RecipientAuthUid;
    ELSE
        SET @ConversationId = @RecipientAuthUid + '_' + @SenderAuthUid;
    
    -- Generate preview text
    IF @MessageType = 'TEXT'
        SET @PreviewText = LEFT(@MessageText, 500);
    ELSE IF @MessageType = 'IMAGE'
        SET @PreviewText = '📷 Image';
    ELSE IF @MessageType = 'VOICE'
        SET @PreviewText = '🎤 Voice message';
    ELSE
        SET @PreviewText = 'Message';
    
    BEGIN TRANSACTION;
    
    BEGIN TRY
        -- 1. Insert message
        INSERT INTO Messages (
            MessagePublicId, ConversationId, SenderAuthUid, RecipientAuthUid,
            MessageText, MessageType, ImageUrl, VoiceUrl, VoiceDurationSec
        )
        VALUES (
            @MessagePublicId, @ConversationId, @SenderAuthUid, @RecipientAuthUid,
            @MessageText, @MessageType, @ImageUrl, @VoiceUrl, @VoiceDurationSec
        );
        
        -- 2. Update or create conversation
        MERGE Conversations AS target
        USING (SELECT @ConversationId AS ConversationId) AS source
        ON target.ConversationId = source.ConversationId
        WHEN MATCHED THEN
            UPDATE SET
                LastMessageText = @PreviewText,
                LastMessageAt = GETUTCDATE(),
                LastMessageType = @MessageType,
                -- Increment recipient's unread count
                UnreadCountP1 = CASE 
                    WHEN Participant1AuthUid = @RecipientAuthUid THEN UnreadCountP1 + 1 
                    ELSE UnreadCountP1 
                END,
                UnreadCountP2 = CASE 
                    WHEN Participant2AuthUid = @RecipientAuthUid THEN UnreadCountP2 + 1 
                    ELSE UnreadCountP2 
                END,
                UpdatedAt = GETUTCDATE()
        WHEN NOT MATCHED THEN
            INSERT (
                ConversationId, Participant1AuthUid, Participant2AuthUid, 
                LastMessageText, LastMessageAt, LastMessageType,
                UnreadCountP1, UnreadCountP2
            )
            VALUES (
                @ConversationId, 
                -- Ensure consistent ordering
                CASE WHEN @SenderAuthUid < @RecipientAuthUid THEN @SenderAuthUid ELSE @RecipientAuthUid END,
                CASE WHEN @SenderAuthUid < @RecipientAuthUid THEN @RecipientAuthUid ELSE @SenderAuthUid END,
                @PreviewText, 
                GETUTCDATE(), 
                @MessageType,
                -- Set initial unread count
                CASE WHEN @SenderAuthUid < @RecipientAuthUid THEN 1 ELSE 0 END,
                CASE WHEN @SenderAuthUid < @RecipientAuthUid THEN 0 ELSE 1 END
            );
        
        COMMIT TRANSACTION;
        
        -- Return result
        SELECT 
            @MessagePublicId AS MessagePublicId, 
            @ConversationId AS ConversationId,
            'Message sent successfully' AS Status;
        
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
