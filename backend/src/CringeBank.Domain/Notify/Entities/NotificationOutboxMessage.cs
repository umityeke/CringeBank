using System;
using CringeBank.Domain.Notify.Enums;

namespace CringeBank.Domain.Notify.Entities;

public sealed partial class NotificationOutboxMessage
{
    public long Id { get; private set; }

    public long NotificationId { get; private set; }

    public NotificationDeliveryChannel Channel { get; private set; }

    public string Topic { get; private set; } = string.Empty;

    public string PayloadJson { get; private set; } = "{}";

    public NotificationOutboxStatus Status { get; private set; }

    public int RetryCount { get; private set; }

    public DateTime CreatedAtUtc { get; private set; }

    public DateTime? ProcessedAtUtc { get; private set; }

    public Notification Notification { get; private set; } = null!;

    private NotificationOutboxMessage()
    {
        Status = NotificationOutboxStatus.Pending;
        CreatedAtUtc = DateTime.UtcNow;
    }

    public void MarkProcessed(DateTime? processedAtUtc = null)
    {
        Status = NotificationOutboxStatus.Sent;
        ProcessedAtUtc = (processedAtUtc ?? DateTime.UtcNow).ToUniversalTime();
    }

    public void MarkFailed(DateTime? processedAtUtc = null)
    {
        Status = NotificationOutboxStatus.Failed;
        RetryCount++;
        ProcessedAtUtc = processedAtUtc?.ToUniversalTime();
    }
}
