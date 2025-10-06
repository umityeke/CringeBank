using System;
using CringeBank.Domain.Enums;

namespace CringeBank.Application.Users;

public sealed record UserSynchronizationResult(
    Guid UserId,
    string FirebaseUid,
    string Email,
    bool EmailVerified,
    int ClaimsVersion,
    UserStatus Status,
    string? DisplayName,
    string? ProfileImageUrl,
    string? PhoneNumber,
    DateTimeOffset? LastLoginAtUtc,
    DateTimeOffset? LastSyncedAtUtc,
    string? LastSeenAppVersion);
