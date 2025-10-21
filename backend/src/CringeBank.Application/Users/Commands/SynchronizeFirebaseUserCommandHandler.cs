using System;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Application.Abstractions.Commands;

namespace CringeBank.Application.Users.Commands;

public sealed class SynchronizeFirebaseUserCommandHandler : ICommandHandler<SynchronizeFirebaseUserCommand, UserSynchronizationResult>
{
    private readonly IUserSynchronizationService _userSynchronizationService;

    public SynchronizeFirebaseUserCommandHandler(IUserSynchronizationService userSynchronizationService)
    {
        _userSynchronizationService = userSynchronizationService ?? throw new ArgumentNullException(nameof(userSynchronizationService));
    }

    public Task<UserSynchronizationResult> HandleAsync(SynchronizeFirebaseUserCommand command, CancellationToken cancellationToken)
    {
        if (command is null)
        {
            throw new ArgumentNullException(nameof(command));
        }

        return _userSynchronizationService.SynchronizeAsync(command.Profile, cancellationToken);
    }
}
