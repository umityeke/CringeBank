namespace CringeBank.Tests.Integration.Infrastructure;

using System.Threading;
using System.Threading.Tasks;
using CringeBank.Infrastructure.Persistence.Seeding;

public sealed class NoOpDatabaseInitializer : IDatabaseInitializer
{
    public Task InitializeAsync(CancellationToken cancellationToken = default)
    {
        return Task.CompletedTask;
    }
}
