using System;
using System.Collections.Generic;
using CringeBank.Domain.Auth.Entities;

namespace CringeBank.Domain.Wallet.Entities;

public sealed partial class WalletAccount
{
    private readonly List<WalletTransaction> _transactions = new();
    private readonly List<WalletTransferAudit> _outgoingTransfers = new();
    private readonly List<WalletTransferAudit> _incomingTransfers = new();
    private readonly List<WalletInAppPurchase> _inAppPurchases = new();

    public long Id { get; private set; }

    public long UserId { get; private set; }

    public decimal Balance { get; private set; }

    public string Currency { get; private set; } = string.Empty;

    public DateTime UpdatedAt { get; private set; }

    public AuthUser User { get; private set; } = null!;

    public IReadOnlyCollection<WalletTransaction> Transactions => _transactions;

    public IReadOnlyCollection<WalletTransferAudit> OutgoingTransfers => _outgoingTransfers;

    public IReadOnlyCollection<WalletTransferAudit> IncomingTransfers => _incomingTransfers;

    public IReadOnlyCollection<WalletInAppPurchase> InAppPurchases => _inAppPurchases;
}
