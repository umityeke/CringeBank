using System;
using System.Text.Json;
using CringeBank.Domain.Notify.Enums;

namespace CringeBank.Domain.Notify.Entities;

public sealed partial class NotificationOutboxMessage
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    public static NotificationOutboxMessage Create(
        Notification notification,
        NotificationDeliveryChannel channel,
        string topic,
        object payload,
        DateTime? utcNow = null)
    {
        ArgumentNullException.ThrowIfNull(notification);

        if (string.IsNullOrWhiteSpace(topic))
        {
            throw new ArgumentException("Topic boş olamaz.", nameof(topic));
        }

        if (payload is null)
        {
            throw new ArgumentNullException(nameof(payload));
        }

        var message = new NotificationOutboxMessage
        {
            Notification = notification,
            NotificationId = notification.Id,
            Channel = channel,
            Topic = topic.Trim(),
            PayloadJson = JsonSerializer.Serialize(payload, JsonOptions),
            Status = NotificationOutboxStatus.Pending,
            RetryCount = 0,
            CreatedAtUtc = (utcNow ?? DateTime.UtcNow).ToUniversalTime()
        };

        notification.AddOutboxMessage(message);
        return message;
    }
}
