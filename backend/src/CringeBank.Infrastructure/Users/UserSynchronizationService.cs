using System;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Application.Abstractions.Mapping;
using CringeBank.Application.Users;
using CringeBank.Domain.Entities;
using CringeBank.Domain.Enums;
using CringeBank.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace CringeBank.Infrastructure.Users;

public sealed class UserSynchronizationService : IUserSynchronizationService
{
    private readonly CringeBankDbContext _dbContext;
    private readonly ILogger<UserSynchronizationService> _logger;
    private readonly IObjectMapper _mapper;

    private static readonly Action<ILogger, string, Exception?> LogUserCreated = LoggerMessage.Define<string>(
        LogLevel.Information,
        new EventId(2000, nameof(LogUserCreated)),
        "Yeni kullanıcı senkronize edildi: {FirebaseUid}.");

    public UserSynchronizationService(CringeBankDbContext dbContext, ILogger<UserSynchronizationService> logger, IObjectMapper mapper)
    {
        _dbContext = dbContext ?? throw new ArgumentNullException(nameof(dbContext));
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        _mapper = mapper ?? throw new ArgumentNullException(nameof(mapper));
    }

    public async Task<UserSynchronizationResult> SynchronizeAsync(FirebaseUserProfile profile, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(profile);

        var utcNow = DateTimeOffset.UtcNow;

        var user = await _dbContext.Users.SingleOrDefaultAsync(x => x.FirebaseUid == profile.FirebaseUid, cancellationToken);

        if (user is null)
        {
            user = new User(Guid.NewGuid(), profile.FirebaseUid, profile.Email, profile.EmailVerified, profile.ClaimsVersion, profile.Status);
            _dbContext.Users.Add(user);
            LogUserCreated(_logger, profile.FirebaseUid, null);
        }

        user.UpdateCoreProfile(
            profile.Email,
            profile.PhoneNumber,
            profile.DisplayName,
            profile.ProfileImageUrl,
            profile.EmailVerified,
            profile.ClaimsVersion,
            profile.LastLoginAtUtc,
            profile.LastSeenAppVersion);

        user.SetStatus(profile.Status);
        user.SetDisabled(profile.IsDisabled, profile.DisabledAtUtc);

        if (profile.DeletedAtUtc.HasValue)
        {
            user.SetDeleted(profile.DeletedAtUtc);
        }

        user.MarkSynced(utcNow);

        await _dbContext.SaveChangesAsync(cancellationToken);

        return _mapper.Map<UserSynchronizationResult>(user);
    }
}
