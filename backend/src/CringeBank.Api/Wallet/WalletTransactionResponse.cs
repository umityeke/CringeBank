using System;

namespace CringeBank.Api.Wallet;

public sealed record WalletTransactionResponse(
    long Id,
    string Type,
    decimal Amount,
    decimal BalanceAfter,
    string? Reference,
    string? Metadata,
    DateTime CreatedAtUtc);
