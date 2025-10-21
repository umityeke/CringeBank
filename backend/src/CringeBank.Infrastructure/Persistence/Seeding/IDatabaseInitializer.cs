using System.Threading;
using System.Threading.Tasks;

namespace CringeBank.Infrastructure.Persistence.Seeding;

public interface IDatabaseInitializer
{
    Task InitializeAsync(CancellationToken cancellationToken = default);
}
