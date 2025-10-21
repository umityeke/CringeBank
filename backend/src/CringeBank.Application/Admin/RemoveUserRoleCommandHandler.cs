using System;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Application.Abstractions.Commands;
using CringeBank.Application.Auth;
using CringeBank.Domain.Auth.Enums;

namespace CringeBank.Application.Admin;

public sealed class RemoveUserRoleCommandHandler : ICommandHandler<RemoveUserRoleCommand, RemoveUserRoleResult>
{
    private readonly IAuthUserRepository _authUserRepository;
    private readonly IAdminUserReadRepository _adminUserReadRepository;

    public RemoveUserRoleCommandHandler(
        IAuthUserRepository authUserRepository,
        IAdminUserReadRepository adminUserReadRepository)
    {
        _authUserRepository = authUserRepository ?? throw new ArgumentNullException(nameof(authUserRepository));
        _adminUserReadRepository = adminUserReadRepository ?? throw new ArgumentNullException(nameof(adminUserReadRepository));
    }

    public async Task<RemoveUserRoleResult> HandleAsync(RemoveUserRoleCommand command, CancellationToken cancellationToken)
    {
        if (command is null)
        {
            throw new ArgumentNullException(nameof(command));
        }

        var actor = await _authUserRepository.GetByPublicIdAsync(command.ActorPublicId, cancellationToken).ConfigureAwait(false);

        if (actor is null)
        {
            return RemoveUserRoleResult.Fail("actor_not_found");
        }

        if (actor.Status is not AuthUserStatus.Active)
        {
            return RemoveUserRoleResult.Fail("actor_not_active");
        }

        var target = await _authUserRepository.GetByPublicIdAsync(command.TargetPublicId, cancellationToken).ConfigureAwait(false);

        if (target is null)
        {
            return RemoveUserRoleResult.Fail("user_not_found");
        }

        var role = await _authUserRepository.GetRoleByNameAsync(command.RoleName, cancellationToken).ConfigureAwait(false);

        if (role is null)
        {
            return RemoveUserRoleResult.Fail("role_not_found");
        }

        var removed = target.RemoveRole(role);

        if (!removed)
        {
            return RemoveUserRoleResult.Fail("role_not_assigned");
        }

        await _authUserRepository.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        var userSummary = await _adminUserReadRepository.GetByPublicIdAsync(target.PublicId, cancellationToken).ConfigureAwait(false);

        if (userSummary is null)
        {
            return RemoveUserRoleResult.Fail("user_summary_unavailable");
        }

        return RemoveUserRoleResult.Ok(userSummary);
    }
}
