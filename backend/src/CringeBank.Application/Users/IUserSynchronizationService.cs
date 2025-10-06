using System.Threading;
using System.Threading.Tasks;

namespace CringeBank.Application.Users;

public interface IUserSynchronizationService
{
    Task<UserSynchronizationResult> SynchronizeAsync(FirebaseUserProfile profile, CancellationToken cancellationToken = default);
}
