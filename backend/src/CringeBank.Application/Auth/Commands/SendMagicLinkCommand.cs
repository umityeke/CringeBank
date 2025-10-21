using CringeBank.Application.Abstractions.Commands;

namespace CringeBank.Application.Auth.Commands;

public sealed record SendMagicLinkCommand(string Email) : ICommand<SendMagicLinkResult>;
