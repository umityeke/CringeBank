using System.Threading;
using System.Threading.Tasks;

namespace CringeBank.Infrastructure.Persistence.Seeding;

public interface IDataSeeder
{
    Task SeedAsync(CancellationToken cancellationToken = default);
}
