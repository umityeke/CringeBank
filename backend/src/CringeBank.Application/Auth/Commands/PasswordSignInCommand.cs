using CringeBank.Application.Abstractions.Commands;

namespace CringeBank.Application.Auth.Commands;

public sealed record PasswordSignInCommand(string Identifier, string Password, string? DeviceIdHash, string? IpHash) : ICommand<PasswordSignInResult>;
