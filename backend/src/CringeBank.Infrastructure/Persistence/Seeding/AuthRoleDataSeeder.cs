using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Domain.Auth.Entities;
using CringeBank.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace CringeBank.Infrastructure.Persistence.Seeding;

public sealed class AuthRoleDataSeeder : IDataSeeder
{
    private static readonly Action<ILogger, Exception?> LogRolesAlreadySeeded = LoggerMessage.Define(
        LogLevel.Information,
        new EventId(3100, nameof(LogRolesAlreadySeeded)),
        "Auth roles already seeded.");

    private static readonly Action<ILogger, string, Exception?> LogSeedingRole = LoggerMessage.Define<string>(
        LogLevel.Information,
        new EventId(3101, nameof(LogSeedingRole)),
        "Seeding auth role '{RoleName}'.");

    private static readonly IReadOnlyList<(string Name, string Description)> Roles = new List<(string, string)>
    {
        ("user", "Default application user with standard permissions."),
        ("system_writer", "Service-to-service role with elevated write permissions."),
        ("admin", "Delegated operational administrator."),
        ("category_admin", "Scoped moderator limited to assigned categories."),
        ("superadmin", "Full-system administrator with unrestricted access.")
    };

    private readonly CringeBankDbContext _dbContext;
    private readonly ILogger<AuthRoleDataSeeder> _logger;

    public AuthRoleDataSeeder(CringeBankDbContext dbContext, ILogger<AuthRoleDataSeeder> logger)
    {
        _dbContext = dbContext ?? throw new ArgumentNullException(nameof(dbContext));
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
    }

    public async Task SeedAsync(CancellationToken cancellationToken = default)
    {
        var existingRoleNames = await _dbContext.AuthRoles
            .Select(role => role.Name)
            .ToListAsync(cancellationToken);

        var missingRoles = Roles
            .Where(role => !existingRoleNames.Any(existing => string.Equals(existing, role.Name, StringComparison.OrdinalIgnoreCase)))
            .ToList();

        if (missingRoles.Count == 0)
        {
            LogRolesAlreadySeeded(_logger, null);
            return;
        }

        foreach (var (name, description) in missingRoles)
        {
            LogSeedingRole(_logger, name, null);
            _dbContext.AuthRoles.Add(new AuthRole(name, description));
        }

        await _dbContext.SaveChangesAsync(cancellationToken);
    }
}
