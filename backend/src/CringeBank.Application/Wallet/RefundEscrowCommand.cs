using System;
using CringeBank.Application.Abstractions.Commands;

namespace CringeBank.Application.Wallet;

public sealed record RefundEscrowCommand(
    Guid OrderPublicId,
    Guid ActorPublicId,
    bool IsSystemOverride,
    string? RefundReason) : ICommand<RefundEscrowResult>;
