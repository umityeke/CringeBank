using System;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Application.Abstractions.Commands;
using CringeBank.Application.Auth;
using CringeBank.Domain.Auth.Entities;
using CringeBank.Domain.Auth.Enums;

namespace CringeBank.Application.Auth.Commands;

public sealed class PasswordSignInCommandHandler : ICommandHandler<PasswordSignInCommand, PasswordSignInResult>
{
    private readonly IAuthUserRepository _repository;
    private readonly IPasswordHasher _passwordHasher;
    private readonly IAuthTokenService _tokenService;

    public PasswordSignInCommandHandler(
        IAuthUserRepository repository,
        IPasswordHasher passwordHasher,
        IAuthTokenService tokenService)
    {
        _repository = repository ?? throw new ArgumentNullException(nameof(repository));
        _passwordHasher = passwordHasher ?? throw new ArgumentNullException(nameof(passwordHasher));
        _tokenService = tokenService ?? throw new ArgumentNullException(nameof(tokenService));
    }

    public async Task<PasswordSignInResult> HandleAsync(PasswordSignInCommand command, CancellationToken cancellationToken)
    {
        if (command is null)
        {
            throw new ArgumentNullException(nameof(command));
        }

        var identifier = command.Identifier?.Trim();
        var password = command.Password ?? string.Empty;

        if (string.IsNullOrWhiteSpace(identifier) || string.IsNullOrWhiteSpace(password))
        {
            return PasswordSignInFailure("invalid_credentials");
        }

        AuthUser? user = await _repository.GetByEmailAsync(identifier, cancellationToken);

        if (user is null)
        {
            user = await _repository.GetByUsernameAsync(identifier, cancellationToken);
        }

        if (user is null)
        {
            return PasswordSignInFailure("invalid_credentials");
        }

        if (user.Status is AuthUserStatus.Suspended or AuthUserStatus.Banned)
        {
            return PasswordSignInFailure("account_locked");
        }

        if (user.PasswordHash is null || user.PasswordSalt is null)
        {
            return PasswordSignInFailure("password_not_set");
        }

        if (!_passwordHasher.VerifyPassword(password, user.PasswordSalt, user.PasswordHash))
        {
            return PasswordSignInFailure("invalid_credentials");
        }

        var utcNow = DateTime.UtcNow;
        var security = user.Security ?? throw new InvalidOperationException("User security kaydi bulunamadi.");

        if (security.OtpEnabled && security.OtpSecret is not null)
        {
            var mfaToken = TokenUtility.GenerateChallengeToken(user.PublicId);
            security.SetMagicCode(TokenUtility.ComputeSha256(mfaToken.CodePart), utcNow.AddMinutes(5));
            await _repository.SaveChangesAsync(cancellationToken);

            return new PasswordSignInResult(
                Success: true,
                AccessToken: null,
                RefreshToken: null,
                RefreshTokenExpiresAtUtc: null,
                RequiresMfa: true,
                MfaToken: mfaToken.Token,
                FailureCode: null);
        }

        user.MarkSignedIn(utcNow);
        var tokens = _tokenService.CreateTokens(user, utcNow);
    security.SetRefreshToken(tokens.RefreshToken.Hash, tokens.RefreshToken.ExpiresAtUtc);
    security.ClearMagicCode();
        await _repository.SaveChangesAsync(cancellationToken);

        return new PasswordSignInResult(
            Success: true,
            AccessToken: tokens.AccessToken,
            RefreshToken: tokens.RefreshToken.Token,
            RefreshTokenExpiresAtUtc: tokens.RefreshToken.ExpiresAtUtc,
            RequiresMfa: false,
            MfaToken: null,
            FailureCode: null);
    }

    private static PasswordSignInResult PasswordSignInFailure(string failureCode)
    {
        return new PasswordSignInResult(false, null, null, null, false, null, failureCode);
    }
}
