using System;
using CringeBank.Domain.Wallet.Enums;

namespace CringeBank.Domain.Wallet.Entities;

public sealed class WalletInAppPurchase
{
    public long Id { get; private set; }

    public long AccountId { get; private set; }

    public string Platform { get; private set; } = string.Empty;

    public string Receipt { get; private set; } = string.Empty;

    public WalletInAppPurchaseStatus Status { get; private set; }

    public DateTime CreatedAt { get; private set; }

    public DateTime? ValidatedAt { get; private set; }

    public WalletAccount Account { get; private set; } = null!;
}
