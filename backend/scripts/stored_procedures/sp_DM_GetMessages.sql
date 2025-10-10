-- =============================================
-- Stored Procedure: sp_DM_GetMessages
-- Created: 2025-10-09
-- Purpose: Get messages for a conversation with pagination
-- =============================================

CREATE OR ALTER PROCEDURE sp_DM_GetMessages
    @ConversationId NVARCHAR(100),
    @RequestorAuthUid NVARCHAR(128),
    @Limit INT = 50,
    @BeforeMessageId BIGINT = NULL -- For pagination (load older messages)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Validation
    IF @Limit > 100
    BEGIN
        RAISERROR('Limit cannot exceed 100 messages', 16, 1);
        RETURN;
    END
    
    -- Verify requestor is a participant
    DECLARE @IsParticipant BIT = 0;
    
    SELECT @IsParticipant = 1
    FROM Conversations
    WHERE ConversationId = @ConversationId
      AND (Participant1AuthUid = @RequestorAuthUid OR Participant2AuthUid = @RequestorAuthUid);
    
    IF @IsParticipant = 0
    BEGIN
        RAISERROR('Unauthorized: Not a conversation participant', 16, 1);
        RETURN;
    END
    
    -- Get messages (newest first for pagination)
    SELECT TOP (@Limit)
        MessageId,
        MessagePublicId,
        SenderAuthUid,
        RecipientAuthUid,
        MessageText,
        MessageType,
        ImageUrl,
        VoiceUrl,
        VoiceDurationSec,
        IsRead,
        CreatedAt,
        ReadAt
    FROM Messages
    WHERE ConversationId = @ConversationId
      AND IsDeleted = 0
      AND (@BeforeMessageId IS NULL OR MessageId < @BeforeMessageId)
    ORDER BY MessageId DESC;
END
GO
