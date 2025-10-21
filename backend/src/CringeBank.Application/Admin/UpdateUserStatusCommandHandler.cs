using System;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Application.Abstractions.Commands;
using CringeBank.Application.Auth;
using CringeBank.Domain.Auth.Enums;

namespace CringeBank.Application.Admin;

public sealed class UpdateUserStatusCommandHandler : ICommandHandler<UpdateUserStatusCommand, UpdateUserStatusResult>
{
    private readonly IAuthUserRepository _authUserRepository;
    private readonly IAdminUserReadRepository _adminUserReadRepository;

    public UpdateUserStatusCommandHandler(
        IAuthUserRepository authUserRepository,
        IAdminUserReadRepository adminUserReadRepository)
    {
        _authUserRepository = authUserRepository ?? throw new ArgumentNullException(nameof(authUserRepository));
        _adminUserReadRepository = adminUserReadRepository ?? throw new ArgumentNullException(nameof(adminUserReadRepository));
    }

    public async Task<UpdateUserStatusResult> HandleAsync(UpdateUserStatusCommand command, CancellationToken cancellationToken)
    {
        if (command is null)
        {
            throw new ArgumentNullException(nameof(command));
        }

        var actor = await _authUserRepository.GetByPublicIdAsync(command.ActorPublicId, cancellationToken).ConfigureAwait(false);

        if (actor is null)
        {
            return UpdateUserStatusResult.Fail("actor_not_found");
        }

        if (actor.Status is not AuthUserStatus.Active)
        {
            return UpdateUserStatusResult.Fail("actor_not_active");
        }

        var target = await _authUserRepository.GetByPublicIdAsync(command.TargetPublicId, cancellationToken).ConfigureAwait(false);

        if (target is null)
        {
            return UpdateUserStatusResult.Fail("user_not_found");
        }

        var changed = target.SetStatus(command.Status);

        if (!changed)
        {
            return UpdateUserStatusResult.Fail("status_unchanged");
        }

        await _authUserRepository.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        var userSummary = await _adminUserReadRepository.GetByPublicIdAsync(target.PublicId, cancellationToken).ConfigureAwait(false);

        if (userSummary is null)
        {
            return UpdateUserStatusResult.Fail("user_summary_unavailable");
        }

        return UpdateUserStatusResult.Ok(command.Status, userSummary);
    }
}
