using System;
using System.Collections.Generic;
using CringeBank.Domain.Auth.Entities;
using CringeBank.Domain.Notify.Enums;

namespace CringeBank.Domain.Notify.Entities;

public sealed partial class Notification
{
    private readonly List<NotificationOutboxMessage> _outboxMessages = new();

    public long Id { get; private set; }

    public Guid PublicId { get; private set; }

    public long RecipientUserId { get; private set; }

    public long? SenderUserId { get; private set; }

    public NotificationType Type { get; private set; }

    public string Title { get; private set; } = string.Empty;

    public string? Body { get; private set; }

    public string? ActionUrl { get; private set; }

    public string? ImageUrl { get; private set; }

    public string PayloadJson { get; private set; } = "{}";

    public bool IsRead { get; private set; }

    public DateTime CreatedAtUtc { get; private set; }

    public DateTime? ReadAtUtc { get; private set; }

    public AuthUser? Sender { get; private set; }

    public AuthUser Recipient { get; private set; } = null!;

    public IReadOnlyCollection<NotificationOutboxMessage> OutboxMessages => _outboxMessages.AsReadOnly();

    private Notification()
    {
        PublicId = Guid.NewGuid();
        CreatedAtUtc = DateTime.UtcNow;
    }

    public void MarkAsRead(DateTime? readAtUtc = null)
    {
        if (IsRead)
        {
            return;
        }

        IsRead = true;
        ReadAtUtc = (readAtUtc ?? DateTime.UtcNow).ToUniversalTime();
    }

    public void AddOutboxMessage(NotificationOutboxMessage message)
    {
        ArgumentNullException.ThrowIfNull(message);

        if (!_outboxMessages.Contains(message))
        {
            _outboxMessages.Add(message);
        }
    }
}
