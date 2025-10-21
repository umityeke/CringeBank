using System;
using CringeBank.Domain.Auth.Entities;
using CringeBank.Domain.Chat.Enums;

namespace CringeBank.Domain.Chat.Entities;

public sealed partial class ConversationMember
{
    public long Id { get; private set; }

    public long ConversationId { get; private set; }

    public long UserId { get; private set; }

    public ConversationMemberRole Role { get; private set; } = ConversationMemberRole.Participant;

    public DateTime JoinedAt { get; private set; }

    public long? LastReadMessageId { get; private set; }

    public DateTime? LastReadAt { get; private set; }

    public Conversation Conversation { get; private set; } = null!;

    public AuthUser User { get; private set; } = null!;
}
