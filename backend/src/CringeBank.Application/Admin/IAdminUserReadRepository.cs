using System;
using System.Threading;
using System.Threading.Tasks;

namespace CringeBank.Application.Admin;

public interface IAdminUserReadRepository
{
    Task<AdminUserPageResult> SearchAsync(GetAdminUsersQuery query, CancellationToken cancellationToken = default);

    Task<AdminUserListItem?> GetByPublicIdAsync(Guid publicId, CancellationToken cancellationToken = default);
}
