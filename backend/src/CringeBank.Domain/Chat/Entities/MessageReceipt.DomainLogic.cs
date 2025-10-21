using System;
using CringeBank.Domain.Chat.Enums;

namespace CringeBank.Domain.Chat.Entities;

public sealed partial class MessageReceipt
{
    public static MessageReceipt Create(long messageId, long userId, MessageReceiptType receiptType, DateTime? timestampUtc = null)
    {
        if (messageId <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(messageId));
        }

        if (userId <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(userId));
        }

        var createdAt = (timestampUtc ?? DateTime.UtcNow).ToUniversalTime();

        return new MessageReceipt
        {
            MessageId = messageId,
            UserId = userId,
            ReceiptType = receiptType,
            CreatedAt = createdAt
        };
    }
}
