using System;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Application.Abstractions.Commands;
using CringeBank.Application.Auth;
using CringeBank.Domain.Auth.Entities;
using CringeBank.Domain.Auth.Enums;

namespace CringeBank.Application.Admin;

public sealed class AssignUserRoleCommandHandler : ICommandHandler<AssignUserRoleCommand, AssignUserRoleResult>
{
    private readonly IAuthUserRepository _authUserRepository;
    private readonly IAdminUserReadRepository _adminUserReadRepository;

    public AssignUserRoleCommandHandler(
        IAuthUserRepository authUserRepository,
        IAdminUserReadRepository adminUserReadRepository)
    {
        _authUserRepository = authUserRepository ?? throw new ArgumentNullException(nameof(authUserRepository));
        _adminUserReadRepository = adminUserReadRepository ?? throw new ArgumentNullException(nameof(adminUserReadRepository));
    }

    public async Task<AssignUserRoleResult> HandleAsync(AssignUserRoleCommand command, CancellationToken cancellationToken)
    {
        if (command is null)
        {
            throw new ArgumentNullException(nameof(command));
        }

        var actor = await _authUserRepository.GetByPublicIdAsync(command.ActorPublicId, cancellationToken).ConfigureAwait(false);

        if (actor is null)
        {
            return AssignUserRoleResult.Fail("actor_not_found");
        }

        if (actor.Status is not AuthUserStatus.Active)
        {
            return AssignUserRoleResult.Fail("actor_not_active");
        }

        var target = await _authUserRepository.GetByPublicIdAsync(command.TargetPublicId, cancellationToken).ConfigureAwait(false);

        if (target is null)
        {
            return AssignUserRoleResult.Fail("user_not_found");
        }

        var role = await GetRoleAsync(command.RoleName, cancellationToken).ConfigureAwait(false);

        if (role is null)
        {
            return AssignUserRoleResult.Fail("role_not_found");
        }

        var assigned = target.AssignRole(role);

        if (!assigned)
        {
            return AssignUserRoleResult.Fail("role_already_assigned");
        }

        await _authUserRepository.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        var userSummary = await _adminUserReadRepository.GetByPublicIdAsync(target.PublicId, cancellationToken).ConfigureAwait(false);

        if (userSummary is null)
        {
            return AssignUserRoleResult.Fail("user_summary_unavailable");
        }

        return AssignUserRoleResult.Ok(userSummary);
    }

    private Task<AuthRole?> GetRoleAsync(string roleName, CancellationToken cancellationToken)
    {
        return _authUserRepository.GetRoleByNameAsync(roleName, cancellationToken);
    }
}
