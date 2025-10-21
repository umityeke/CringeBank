using CringeBank.Application.Abstractions.Commands;

namespace CringeBank.Application.Auth.Commands;

public sealed record RedeemMagicLinkCommand(string Token) : ICommand<RedeemMagicLinkResult>;
