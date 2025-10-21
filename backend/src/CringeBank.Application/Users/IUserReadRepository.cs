using System;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Application.Users.Queries;

namespace CringeBank.Application.Users;

public interface IUserReadRepository
{
    Task<UserProfileResult?> GetProfileByPublicIdAsync(Guid publicId, CancellationToken cancellationToken = default);
}
