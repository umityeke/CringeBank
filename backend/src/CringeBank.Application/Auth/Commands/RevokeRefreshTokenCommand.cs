using CringeBank.Application.Abstractions.Commands;

namespace CringeBank.Application.Auth.Commands;

public sealed record RevokeRefreshTokenCommand(string RefreshToken) : ICommand<RevokeRefreshTokenResult>;

public sealed record RevokeRefreshTokenResult(bool Success, string? FailureCode);
