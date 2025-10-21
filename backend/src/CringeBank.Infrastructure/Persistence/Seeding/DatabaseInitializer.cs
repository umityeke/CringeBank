using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace CringeBank.Infrastructure.Persistence.Seeding;

public sealed class DatabaseInitializer : IDatabaseInitializer
{
    private static readonly Action<ILogger, Exception?> LogApplyingMigrations = LoggerMessage.Define(
        LogLevel.Information,
        new EventId(3000, nameof(LogApplyingMigrations)),
        "Applying database migrations...");

    private static readonly Action<ILogger, Exception?> LogMigrationsApplied = LoggerMessage.Define(
        LogLevel.Information,
        new EventId(3001, nameof(LogMigrationsApplied)),
        "Database migrations applied successfully.");

    private static readonly Action<ILogger, string, Exception?> LogRunningSeeder = LoggerMessage.Define<string>(
        LogLevel.Information,
        new EventId(3002, nameof(LogRunningSeeder)),
        "Running data seeder: {SeederType}");

    private readonly CringeBankDbContext _dbContext;
    private readonly IEnumerable<IDataSeeder> _seeders;
    private readonly ILogger<DatabaseInitializer> _logger;

    public DatabaseInitializer(
        CringeBankDbContext dbContext,
        IEnumerable<IDataSeeder> seeders,
        ILogger<DatabaseInitializer> logger)
    {
        _dbContext = dbContext ?? throw new ArgumentNullException(nameof(dbContext));
        _seeders = seeders ?? throw new ArgumentNullException(nameof(seeders));
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
    }

    public async Task InitializeAsync(CancellationToken cancellationToken = default)
    {
        LogApplyingMigrations(_logger, null);
        await _dbContext.Database.MigrateAsync(cancellationToken);
        LogMigrationsApplied(_logger, null);

        foreach (var seeder in _seeders)
        {
            LogRunningSeeder(_logger, seeder.GetType().Name, null);
            await seeder.SeedAsync(cancellationToken);
        }
    }
}
