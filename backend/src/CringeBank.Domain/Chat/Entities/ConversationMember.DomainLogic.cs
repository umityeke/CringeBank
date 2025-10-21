using System;
using CringeBank.Domain.Auth.Entities;
using CringeBank.Domain.Chat.Enums;

namespace CringeBank.Domain.Chat.Entities;

public sealed partial class ConversationMember
{
    public static ConversationMember Create(Conversation conversation, AuthUser user, ConversationMemberRole role, DateTime? joinedAtUtc = null)
    {
        ArgumentNullException.ThrowIfNull(conversation);
        ArgumentNullException.ThrowIfNull(user);

        if (user.Id <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(user));
        }

        var utcNow = (joinedAtUtc ?? DateTime.UtcNow).ToUniversalTime();

        return new ConversationMember
        {
            Conversation = conversation,
            ConversationId = conversation.Id,
            User = user,
            UserId = user.Id,
            Role = role,
            JoinedAt = utcNow,
            LastReadMessageId = null,
            LastReadAt = null
        };
    }

    public void UpdateLastRead(long messageId, DateTime? readAtUtc = null)
    {
        if (messageId <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(messageId));
        }

        if (LastReadMessageId.HasValue && LastReadMessageId.Value >= messageId)
        {
            return;
        }

        LastReadMessageId = messageId;
        LastReadAt = (readAtUtc ?? DateTime.UtcNow).ToUniversalTime();
    }
}
