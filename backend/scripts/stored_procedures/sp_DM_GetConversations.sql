-- =============================================
-- Stored Procedure: sp_DM_GetConversations
-- Created: 2025-10-09
-- Purpose: Get user's conversation list
-- =============================================

CREATE OR ALTER PROCEDURE sp_DM_GetConversations
    @UserAuthUid NVARCHAR(128),
    @IncludeArchived BIT = 0,
    @Limit INT = 50,
    @BeforeTimestamp DATETIME = NULL -- For pagination
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Validation
    IF @Limit > 100
    BEGIN
        RAISERROR('Limit cannot exceed 100 conversations', 16, 1);
        RETURN;
    END
    
    -- Get conversations where user is a participant
    SELECT TOP (@Limit)
        c.ConversationId,
        c.Participant1AuthUid,
        c.Participant2AuthUid,
        -- Other participant
        CASE 
            WHEN c.Participant1AuthUid = @UserAuthUid THEN c.Participant2AuthUid 
            ELSE c.Participant1AuthUid 
        END AS OtherParticipantAuthUid,
        c.LastMessageText,
        c.LastMessageAt,
        c.LastMessageType,
        -- User's unread count
        CASE 
            WHEN c.Participant1AuthUid = @UserAuthUid THEN c.UnreadCountP1 
            ELSE c.UnreadCountP2 
        END AS UnreadCount,
        -- User's archive status
        CASE 
            WHEN c.Participant1AuthUid = @UserAuthUid THEN c.IsArchivedP1 
            ELSE c.IsArchivedP2 
        END AS IsArchived,
        c.CreatedAt,
        c.UpdatedAt
    FROM Conversations c
    WHERE (c.Participant1AuthUid = @UserAuthUid OR c.Participant2AuthUid = @UserAuthUid)
      AND (@IncludeArchived = 1 OR 
           (@IncludeArchived = 0 AND 
            ((c.Participant1AuthUid = @UserAuthUid AND c.IsArchivedP1 = 0) OR 
             (c.Participant2AuthUid = @UserAuthUid AND c.IsArchivedP2 = 0))))
      AND (@BeforeTimestamp IS NULL OR c.UpdatedAt < @BeforeTimestamp)
    ORDER BY c.UpdatedAt DESC;
END
GO
