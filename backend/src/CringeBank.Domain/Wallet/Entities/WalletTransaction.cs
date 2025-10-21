using System;
using CringeBank.Domain.Wallet.Enums;

namespace CringeBank.Domain.Wallet.Entities;

public sealed class WalletTransaction
{
    public long Id { get; private set; }

    public long AccountId { get; private set; }

    public Guid ExternalId { get; private set; }

    public WalletTransactionType Type { get; private set; }

    public decimal Amount { get; private set; }

    public decimal BalanceAfter { get; private set; }

    public string? Reference { get; private set; }

    public string? Metadata { get; private set; }

    public DateTime CreatedAt { get; private set; }

    public WalletAccount Account { get; private set; } = null!;
}
