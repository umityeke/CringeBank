namespace CringeBank.Api.Wallet;

public sealed record RefundEscrowRequest(bool IsSystemOverride, string? RefundReason);
