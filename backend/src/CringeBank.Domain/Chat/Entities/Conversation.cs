using System;
using System.Collections.Generic;
using CringeBank.Domain.Auth.Entities;

namespace CringeBank.Domain.Chat.Entities;

public sealed partial class Conversation
{
    private readonly List<ConversationMember> _members = new();
    private readonly List<Message> _messages = new();

    public long Id { get; private set; }

    public Guid PublicId { get; private set; }

    public bool IsGroup { get; private set; }

    public string? Title { get; private set; }

    public long CreatedByUserId { get; private set; }

    public DateTime CreatedAt { get; private set; }

    public DateTime UpdatedAt { get; private set; }

    public AuthUser CreatedByUser { get; private set; } = null!;

    public IReadOnlyCollection<ConversationMember> Members => _members;

    public IReadOnlyCollection<Message> Messages => _messages;
}
