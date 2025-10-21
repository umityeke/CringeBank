using System;
using CringeBank.Domain.Abstractions;
using CringeBank.Domain.Enums;

namespace CringeBank.Domain.Entities;

public sealed class Wallet : AggregateRoot
{
    private Wallet()
    {
    }

    public Wallet(Guid id, string ownerKey, WalletOwnerType ownerType, decimal initialBalance = 0M)
        : base(id)
    {
        OwnerKey = ownerKey;
        OwnerType = ownerType;
        GoldBalance = initialBalance;
    }

    public string OwnerKey { get; private set; } = string.Empty;

    public WalletOwnerType OwnerType { get; private set; } = WalletOwnerType.Unknown;

    public decimal GoldBalance { get; private set; }

    public void Credit(decimal amount, DateTimeOffset? timestamp = null)
    {
        if (amount <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(amount), "Kredi tutarı pozitif olmalıdır.");
        }

        GoldBalance += amount;
        Touch(timestamp);
    }

    public void Debit(decimal amount, DateTimeOffset? timestamp = null)
    {
        if (amount <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(amount), "Borç tutarı pozitif olmalıdır.");
        }

        if (GoldBalance < amount)
        {
            throw new InvalidOperationException("Yetersiz bakiye.");
        }

        GoldBalance -= amount;
        Touch(timestamp);
    }

    public void SetOwner(string ownerKey, WalletOwnerType ownerType)
    {
        OwnerKey = ownerKey;
        OwnerType = ownerType;
        Touch();
    }
}
