using System;
using CringeBank.Domain.Auth.Entities;
using CringeBank.Domain.ValueObjects;

namespace CringeBank.Domain.Chat.Entities;

public sealed partial class Message
{
    public static Message Create(Conversation conversation, AuthUser sender, MessageBody body, DateTime? utcNow = null)
    {
        ArgumentNullException.ThrowIfNull(conversation);
        ArgumentNullException.ThrowIfNull(sender);
        ArgumentNullException.ThrowIfNull(body);

        if (sender.Id <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(sender));
        }

        var timestamp = (utcNow ?? DateTime.UtcNow).ToUniversalTime();

        return new Message
        {
            Conversation = conversation,
            ConversationId = conversation.Id,
            Sender = sender,
            SenderUserId = sender.Id,
            Body = body.Value,
            DeletedForAll = false,
            CreatedAt = timestamp,
            EditedAt = null
        };
    }
}
