using System;

namespace CringeBank.Application.Wallet;

public sealed record WalletTransactionResult(
    long Id,
    string Type,
    decimal Amount,
    decimal BalanceAfter,
    string? Reference,
    string? Metadata,
    DateTime CreatedAtUtc);
