using System;
using CringeBank.Domain.Abstractions;
using CringeBank.Domain.Enums;

namespace CringeBank.Domain.Entities;

public sealed class Escrow : AggregateRoot
{
    private Escrow()
    {
    }

    public Escrow(Guid id, Guid orderId, Guid buyerId, Guid sellerId, decimal amountGold)
        : base(id)
    {
        OrderId = orderId;
        BuyerId = buyerId;
        SellerId = sellerId;
        AmountGold = amountGold;
        Status = EscrowStatus.Locked;
    }

    public Guid OrderId { get; private set; }

    public Guid BuyerId { get; private set; }

    public Guid SellerId { get; private set; }

    public decimal AmountGold { get; private set; }

    public EscrowStatus Status { get; private set; } = EscrowStatus.Unknown;

    public DateTimeOffset? ReleasedAtUtc { get; private set; }

    public DateTimeOffset? RefundedAtUtc { get; private set; }

    public Order? Order { get; private set; }

    public void Release(DateTimeOffset? timestamp = null)
    {
        Status = EscrowStatus.Released;
        ReleasedAtUtc = timestamp ?? DateTimeOffset.UtcNow;
        Touch(ReleasedAtUtc);
    }

    public void Refund(DateTimeOffset? timestamp = null)
    {
        Status = EscrowStatus.Refunded;
        RefundedAtUtc = timestamp ?? DateTimeOffset.UtcNow;
        Touch(RefundedAtUtc);
    }
}
