namespace CringeBank.Application.Auth.Commands;

public sealed record SendMagicLinkResult(bool Sent, string? TokenForDebug);
