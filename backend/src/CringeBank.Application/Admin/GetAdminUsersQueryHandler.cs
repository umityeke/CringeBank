using System;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Application.Abstractions.Queries;
using CringeBank.Application.Auth;
using CringeBank.Domain.Auth.Enums;

namespace CringeBank.Application.Admin;

public sealed class GetAdminUsersQueryHandler : IQueryHandler<GetAdminUsersQuery, AdminUserPageResult>
{
    private readonly IAuthUserRepository _authUserRepository;
    private readonly IAdminUserReadRepository _adminUserReadRepository;

    public GetAdminUsersQueryHandler(
        IAuthUserRepository authUserRepository,
        IAdminUserReadRepository adminUserReadRepository)
    {
        _authUserRepository = authUserRepository ?? throw new ArgumentNullException(nameof(authUserRepository));
        _adminUserReadRepository = adminUserReadRepository ?? throw new ArgumentNullException(nameof(adminUserReadRepository));
    }

    public async Task<AdminUserPageResult> HandleAsync(GetAdminUsersQuery query, CancellationToken cancellationToken)
    {
        if (query is null)
        {
            throw new ArgumentNullException(nameof(query));
        }

        var actor = await _authUserRepository.GetByPublicIdAsync(query.ActorPublicId, cancellationToken).ConfigureAwait(false);

        if (actor is null)
        {
            throw new InvalidOperationException("Actor not found.");
        }

        if (actor.Status is not AuthUserStatus.Active)
        {
            throw new InvalidOperationException("Actor not active.");
        }

        return await _adminUserReadRepository.SearchAsync(query, cancellationToken).ConfigureAwait(false);
    }
}
