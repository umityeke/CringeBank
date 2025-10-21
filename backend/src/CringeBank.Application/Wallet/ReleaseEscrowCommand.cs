using System;
using CringeBank.Application.Abstractions.Commands;

namespace CringeBank.Application.Wallet;

public sealed record ReleaseEscrowCommand(
    Guid OrderPublicId,
    Guid ActorPublicId,
    bool IsSystemOverride) : ICommand<ReleaseEscrowResult>;
