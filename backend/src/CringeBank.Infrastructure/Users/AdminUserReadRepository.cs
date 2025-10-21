using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Application.Admin;
using CringeBank.Domain.Auth.Enums;
using CringeBank.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace CringeBank.Infrastructure.Users;

public sealed class AdminUserReadRepository : IAdminUserReadRepository
{
    private const int CursorParts = 2;
    private const int DefaultPageSize = 25;
    private const int MaxPageSize = 100;

    private readonly CringeBankDbContext _dbContext;

    public AdminUserReadRepository(CringeBankDbContext dbContext)
    {
        _dbContext = dbContext ?? throw new ArgumentNullException(nameof(dbContext));
    }

    public async Task<AdminUserPageResult> SearchAsync(GetAdminUsersQuery query, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(query);

        var pageSize = NormalizePageSize(query.PageSize);

        var users = _dbContext.AuthUsers
            .AsNoTracking()
            .Include(user => user.Profile)
            .Include(user => user.UserRoles)
                .ThenInclude(userRole => userRole.Role)
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(query.Term))
        {
            var term = query.Term.Trim();
            users = users.Where(user =>
                EF.Functions.Like(user.Email, $"%{term}%") ||
                EF.Functions.Like(user.Username, $"%{term}%") ||
                (user.Profile != null && EF.Functions.Like(user.Profile.DisplayName ?? string.Empty, $"%{term}%")));
        }

        if (query.Status.HasValue)
        {
            var statusValue = query.Status.Value;
            users = users.Where(user => user.Status == statusValue);
        }

        if (!string.IsNullOrWhiteSpace(query.Role))
        {
            var roleTerm = query.Role.Trim();
            users = users.Where(user => user.UserRoles.Any(userRole =>
                userRole.Role != null && userRole.Role.Name != null &&
                EF.Functions.Like(userRole.Role.Name, roleTerm)));
        }

        if (!string.IsNullOrWhiteSpace(query.Cursor) &&
            TryDecodeCursor(query.Cursor, out var createdAtTicks, out var lastUserId))
        {
            var createdAt = new DateTime(createdAtTicks, DateTimeKind.Utc);
            users = users.Where(user => user.CreatedAt < createdAt ||
                (user.CreatedAt == createdAt && user.Id < lastUserId));
        }

        var ordered = users
            .OrderByDescending(user => user.CreatedAt)
            .ThenByDescending(user => user.Id);

        var entities = await ordered
            .Take(pageSize + 1)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        var hasMore = entities.Count > pageSize;

        if (hasMore)
        {
            entities.RemoveAt(entities.Count - 1);
        }

        var nextCursor = hasMore && entities.Count > 0
            ? EncodeCursor(entities[^1])
            : null;

        var items = entities
            .Select(Map)
            .ToArray();

        return new AdminUserPageResult(items, nextCursor, hasMore);
    }

    public async Task<AdminUserListItem?> GetByPublicIdAsync(Guid publicId, CancellationToken cancellationToken = default)
    {
        if (publicId == Guid.Empty)
        {
            return null;
        }

        var user = await _dbContext.AuthUsers
            .AsNoTracking()
            .Include(entity => entity.Profile)
            .Include(entity => entity.UserRoles)
                .ThenInclude(userRole => userRole.Role)
            .SingleOrDefaultAsync(entity => entity.PublicId == publicId, cancellationToken)
            .ConfigureAwait(false);

        return user is null ? null : Map(user);
    }

    private static AdminUserListItem Map(Domain.Auth.Entities.AuthUser user)
    {
        var roles = user.UserRoles
            .Where(userRole => userRole.Role is not null && !string.IsNullOrWhiteSpace(userRole.Role.Name))
            .Select(userRole => userRole.Role!.Name)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .OrderBy(name => name, StringComparer.OrdinalIgnoreCase)
            .ToArray();

        return new AdminUserListItem(
            user.PublicId,
            user.Email,
            user.Username,
            user.Status,
            user.CreatedAt,
            user.UpdatedAt,
            user.LastLoginAt,
            user.Profile?.DisplayName,
            roles);
    }

    private static int NormalizePageSize(int requested)
    {
        if (requested <= 0)
        {
            return DefaultPageSize;
        }

        return requested > MaxPageSize ? MaxPageSize : requested;
    }

    private static string EncodeCursor(Domain.Auth.Entities.AuthUser user)
    {
        var payload = string.Create(CultureInfo.InvariantCulture, $"{user.CreatedAt.Ticks}:{user.Id}");
        return Convert.ToBase64String(Encoding.UTF8.GetBytes(payload));
    }

    private static bool TryDecodeCursor(string cursor, out long createdAtTicks, out long userId)
    {
        createdAtTicks = 0;
        userId = 0;

        if (string.IsNullOrWhiteSpace(cursor))
        {
            return false;
        }

        try
        {
            var decoded = Encoding.UTF8.GetString(Convert.FromBase64String(cursor));
            var segments = decoded.Split(':');

            if (segments.Length != CursorParts)
            {
                return false;
            }

            if (!long.TryParse(segments[0], NumberStyles.Integer, CultureInfo.InvariantCulture, out createdAtTicks))
            {
                return false;
            }

            if (!long.TryParse(segments[1], NumberStyles.Integer, CultureInfo.InvariantCulture, out userId))
            {
                createdAtTicks = 0;
                return false;
            }

            return true;
        }
        catch
        {
            createdAtTicks = 0;
            userId = 0;
            return false;
        }
    }
}
