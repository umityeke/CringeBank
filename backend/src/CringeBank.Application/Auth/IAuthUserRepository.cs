using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Domain.Auth.Entities;

namespace CringeBank.Application.Auth;

public interface IAuthUserRepository
{
    Task<AuthUser?> GetByEmailAsync(string email, CancellationToken cancellationToken = default);

    Task<AuthUser?> GetByUsernameAsync(string username, CancellationToken cancellationToken = default);

    Task<AuthUser?> GetByPublicIdAsync(Guid publicId, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<AuthUser>> GetByPublicIdsAsync(IEnumerable<Guid> publicIds, CancellationToken cancellationToken = default);

    Task<AuthRole?> GetRoleByNameAsync(string roleName, CancellationToken cancellationToken = default);

    Task SaveChangesAsync(CancellationToken cancellationToken = default);
}
