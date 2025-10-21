using System;
using CringeBank.Domain.Wallet.Enums;

namespace CringeBank.Domain.Wallet.Entities;

public sealed class WalletTransferAudit
{
    public long Id { get; private set; }

    public long? FromAccountId { get; private set; }

    public long? ToAccountId { get; private set; }

    public decimal Amount { get; private set; }

    public WalletTransferStatus Status { get; private set; }

    public DateTime CreatedAt { get; private set; }

    public WalletAccount? FromAccount { get; private set; }

    public WalletAccount? ToAccount { get; private set; }
}
