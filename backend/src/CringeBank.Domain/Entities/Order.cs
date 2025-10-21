using System;
using CringeBank.Domain.Abstractions;
using CringeBank.Domain.Enums;

namespace CringeBank.Domain.Entities;

public sealed partial class Order : AggregateRoot
{
    private Order()
    {
    }

    public Order(
        Guid id,
        Guid productId,
        Guid buyerId,
        Guid sellerId,
        SellerType sellerType,
        decimal priceGold,
        decimal commissionGold,
        decimal totalGold)
        : base(id)
    {
        ProductId = productId;
        BuyerId = buyerId;
        SellerId = sellerId;
        SellerType = sellerType;
        PriceGold = priceGold;
        CommissionGold = commissionGold;
        TotalGold = totalGold;
        Status = OrderStatus.Pending;
    }

    public Guid ProductId { get; private set; }

    public Guid BuyerId { get; private set; }

    public Guid SellerId { get; private set; }

    public SellerType SellerType { get; private set; }

    public decimal PriceGold { get; private set; }

    public decimal CommissionGold { get; private set; }

    public decimal TotalGold { get; private set; }

    public OrderStatus Status { get; private set; } = OrderStatus.Unknown;

    public DateTimeOffset? CompletedAtUtc { get; private set; }

    public DateTimeOffset? CanceledAtUtc { get; private set; }

    public Product? Product { get; private set; }

    public Escrow? Escrow { get; private set; }

    public void MarkCompleted(DateTimeOffset? timestamp = null)
    {
        Status = OrderStatus.Completed;
        CompletedAtUtc = timestamp ?? DateTimeOffset.UtcNow;
        Touch(CompletedAtUtc);
    }

    public void Cancel(DateTimeOffset? timestamp = null)
    {
        Status = OrderStatus.Canceled;
        CanceledAtUtc = timestamp ?? DateTimeOffset.UtcNow;
        Touch(CanceledAtUtc);
    }
}
