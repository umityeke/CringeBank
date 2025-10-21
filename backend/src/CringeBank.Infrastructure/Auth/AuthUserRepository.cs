using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Application.Auth;
using CringeBank.Domain.Auth.Entities;
using CringeBank.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace CringeBank.Infrastructure.Auth;

public sealed class AuthUserRepository : IAuthUserRepository
{
    private readonly CringeBankDbContext _dbContext;

    public AuthUserRepository(CringeBankDbContext dbContext)
    {
        _dbContext = dbContext ?? throw new ArgumentNullException(nameof(dbContext));
    }

    public Task<AuthUser?> GetByEmailAsync(string email, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(email))
        {
            return Task.FromResult<AuthUser?>(null);
        }

        var normalized = email.Trim().ToUpperInvariant();

        return _dbContext.AuthUsers
            .Include(user => user.Security)
            .Include(user => user.UserRoles)
                .ThenInclude(userRole => userRole.Role)
            .SingleOrDefaultAsync(user => user.EmailNormalized == normalized, cancellationToken);
    }

    public Task<AuthUser?> GetByUsernameAsync(string username, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(username))
        {
            return Task.FromResult<AuthUser?>(null);
        }

        var normalized = username.Trim().ToLowerInvariant();

        return _dbContext.AuthUsers
            .Include(user => user.Security)
            .Include(user => user.UserRoles)
                .ThenInclude(userRole => userRole.Role)
            .SingleOrDefaultAsync(user => user.UsernameNormalized == normalized, cancellationToken);
    }

    public Task<AuthUser?> GetByPublicIdAsync(Guid publicId, CancellationToken cancellationToken = default)
    {
        return _dbContext.AuthUsers
            .Include(user => user.Security)
            .Include(user => user.Profile)
            .Include(user => user.UserRoles)
                .ThenInclude(userRole => userRole.Role)
            .SingleOrDefaultAsync(user => user.PublicId == publicId, cancellationToken);
    }

    public async Task<IReadOnlyList<AuthUser>> GetByPublicIdsAsync(IEnumerable<Guid> publicIds, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(publicIds);

        var identifiers = publicIds.Distinct().Where(id => id != Guid.Empty).ToArray();

        if (identifiers.Length == 0)
        {
            return Array.Empty<AuthUser>();
        }

        var users = await _dbContext.AuthUsers
            .Include(user => user.Security)
            .Include(user => user.Profile)
            .Include(user => user.UserRoles)
                .ThenInclude(userRole => userRole.Role)
            .Where(user => identifiers.Contains(user.PublicId))
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        return users;
    }

    public Task<AuthRole?> GetRoleByNameAsync(string roleName, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(roleName))
        {
            return Task.FromResult<AuthRole?>(null);
        }

        var trimmed = roleName.Trim();
        var lowered = trimmed.ToLowerInvariant();

        return _dbContext.AuthRoles
            .SingleOrDefaultAsync(role => role.Name == trimmed || role.Name == lowered, cancellationToken);
    }

    public Task SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        return _dbContext.SaveChangesAsync(cancellationToken);
    }
}
