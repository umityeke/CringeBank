using System;
using CringeBank.Domain.Auth.Entities;
using CringeBank.Domain.Chat.Enums;

namespace CringeBank.Domain.Chat.Entities;

public sealed partial class MessageReceipt
{
    public long Id { get; private set; }

    public long MessageId { get; private set; }

    public long UserId { get; private set; }

    public MessageReceiptType ReceiptType { get; private set; } = MessageReceiptType.Delivered;

    public DateTime CreatedAt { get; private set; }

    public Message Message { get; private set; } = null!;

    public AuthUser User { get; private set; } = null!;
}
