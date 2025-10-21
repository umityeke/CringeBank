using System;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Application.Abstractions.Commands;
using CringeBank.Application.Auth;

namespace CringeBank.Application.Auth.Commands;

public sealed class SendMagicLinkCommandHandler : ICommandHandler<SendMagicLinkCommand, SendMagicLinkResult>
{
    private readonly IAuthUserRepository _repository;

    public SendMagicLinkCommandHandler(IAuthUserRepository repository)
    {
        _repository = repository ?? throw new ArgumentNullException(nameof(repository));
    }

    public async Task<SendMagicLinkResult> HandleAsync(SendMagicLinkCommand command, CancellationToken cancellationToken)
    {
        if (command is null)
        {
            throw new ArgumentNullException(nameof(command));
        }

        if (string.IsNullOrWhiteSpace(command.Email))
        {
            return new SendMagicLinkResult(true, null);
        }

        var normalizedEmail = command.Email.Trim();
        var user = await _repository.GetByEmailAsync(normalizedEmail, cancellationToken);

        if (user is null || user.Security is null)
        {
            return new SendMagicLinkResult(true, null);
        }

        var utcNow = DateTime.UtcNow;
        var token = TokenUtility.GenerateChallengeToken(user.PublicId);
        user.Security.SetMagicCode(TokenUtility.ComputeSha256(token.CodePart), utcNow.AddMinutes(15));

        await _repository.SaveChangesAsync(cancellationToken);

        return new SendMagicLinkResult(true, token.Token);
    }
}
