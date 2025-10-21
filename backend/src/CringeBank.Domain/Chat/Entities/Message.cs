using System;
using System.Collections.Generic;
using CringeBank.Domain.Auth.Entities;

namespace CringeBank.Domain.Chat.Entities;

public sealed partial class Message
{
    private readonly List<MessageMedia> _media = new();
    private readonly List<MessageReceipt> _receipts = new();

    public long Id { get; private set; }

    public long ConversationId { get; private set; }

    public long SenderUserId { get; private set; }

    public string? Body { get; private set; }

    public bool DeletedForAll { get; private set; }

    public DateTime CreatedAt { get; private set; }

    public DateTime? EditedAt { get; private set; }

    public Conversation Conversation { get; private set; } = null!;

    public AuthUser Sender { get; private set; } = null!;

    public IReadOnlyCollection<MessageMedia> Media => _media;

    public IReadOnlyCollection<MessageReceipt> Receipts => _receipts;
}
