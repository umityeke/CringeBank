using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Application.Users;
using CringeBank.Application.Users.Queries;
using CringeBank.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace CringeBank.Infrastructure.Users;

public sealed class UserReadRepository : IUserReadRepository
{
    private readonly CringeBankDbContext _dbContext;

    public UserReadRepository(CringeBankDbContext dbContext)
    {
        _dbContext = dbContext ?? throw new ArgumentNullException(nameof(dbContext));
    }

    public Task<UserProfileResult?> GetProfileByPublicIdAsync(Guid publicId, CancellationToken cancellationToken = default)
    {
        return _dbContext.AuthUsers
            .AsNoTracking()
            .Where(user => user.PublicId == publicId)
            .Select(user => new UserProfileResult(
                user.PublicId,
                user.Email,
                user.Username,
                user.Status,
                user.LastLoginAt,
                user.Profile != null && !string.IsNullOrWhiteSpace(user.Profile.DisplayName) ? user.Profile.DisplayName : null,
                user.Profile != null && !string.IsNullOrWhiteSpace(user.Profile.Bio) ? user.Profile.Bio : null,
                user.Profile != null && user.Profile.Verified,
                user.Profile != null && !string.IsNullOrWhiteSpace(user.Profile.AvatarUrl) ? user.Profile.AvatarUrl : null,
                user.Profile != null && !string.IsNullOrWhiteSpace(user.Profile.BannerUrl) ? user.Profile.BannerUrl : null,
                user.Profile != null && !string.IsNullOrWhiteSpace(user.Profile.Location) ? user.Profile.Location : null,
                user.Profile != null && !string.IsNullOrWhiteSpace(user.Profile.Website) ? user.Profile.Website : null,
                user.Profile != null ? user.Profile.CreatedAt : user.CreatedAt,
                user.Profile != null ? user.Profile.UpdatedAt : user.UpdatedAt))
            .SingleOrDefaultAsync(cancellationToken);
    }
}
