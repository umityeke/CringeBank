using System;
using System.Text.Json;
using CringeBank.Domain.Notify.Enums;

namespace CringeBank.Domain.Notify.Entities;

public sealed partial class Notification
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    public static Notification Create(
        long recipientUserId,
        NotificationType type,
        string title,
        string? body,
        string? actionUrl,
        string? imageUrl,
        object? payload,
        long? senderUserId = null,
        DateTime? utcNow = null)
    {
        if (recipientUserId <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(recipientUserId));
        }

        if (string.IsNullOrWhiteSpace(title))
        {
            throw new ArgumentException("Başlık boş olamaz.", nameof(title));
        }

        var timestamp = (utcNow ?? DateTime.UtcNow).ToUniversalTime();

        return new Notification
        {
            PublicId = Guid.NewGuid(),
            RecipientUserId = recipientUserId,
            SenderUserId = senderUserId,
            Type = type,
            Title = Truncate(title.Trim(), 200),
            Body = string.IsNullOrWhiteSpace(body) ? null : Truncate(body.Trim(), 512),
            ActionUrl = string.IsNullOrWhiteSpace(actionUrl) ? null : Truncate(actionUrl.Trim(), 512),
            ImageUrl = string.IsNullOrWhiteSpace(imageUrl) ? null : Truncate(imageUrl.Trim(), 512),
            PayloadJson = SerializePayload(payload),
            IsRead = false,
            CreatedAtUtc = timestamp,
            ReadAtUtc = null
        };
    }

    private static string SerializePayload(object? payload)
    {
        return payload is null
            ? "{}"
            : JsonSerializer.Serialize(payload, JsonOptions);
    }

    private static string Truncate(string value, int maxLength)
    {
        return value.Length <= maxLength ? value : value[..maxLength];
    }
}
