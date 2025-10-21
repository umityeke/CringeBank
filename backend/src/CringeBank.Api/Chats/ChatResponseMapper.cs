using System;
using System.Globalization;
using System.Linq;
using CringeBank.Application.Chats;

namespace CringeBank.Api.Chats;

public static class ChatResponseMapper
{
    public static ConversationResponse Map(ConversationResult result)
    {
        ArgumentNullException.ThrowIfNull(result);

        var members = result.Members
            .Select(Map)
            .ToArray();

        return new ConversationResponse(
            result.PublicId,
            result.IsGroup,
            result.Title,
            result.CreatedAt,
            result.UpdatedAt,
            members);
    }

    public static MessageResponse Map(MessageResult result)
    {
        ArgumentNullException.ThrowIfNull(result);

        return new MessageResponse(
            result.Id,
            result.ConversationPublicId,
            result.SenderPublicId,
            result.Body,
            result.DeletedForAll,
            result.CreatedAt,
            result.EditedAt,
            result.ParticipantPublicIds);
    }

    public static ConversationReadResponse Map(MarkConversationReadResult result)
    {
        ArgumentNullException.ThrowIfNull(result);

        return new ConversationReadResponse(
            result.ConversationPublicId,
            result.UserPublicId,
            result.LastReadMessageId,
            result.LastReadAt,
            result.ParticipantPublicIds);
    }

    private static ConversationMemberResponse Map(ConversationMemberResult result)
    {
        var role = result.Role.ToString();
        return new ConversationMemberResponse(
            result.UserPublicId,
            role,
            result.JoinedAt,
            result.LastReadMessageId,
            result.LastReadAt);
    }
}
