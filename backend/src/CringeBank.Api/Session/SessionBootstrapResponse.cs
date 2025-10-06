using System;

namespace CringeBank.Api.Session;

public sealed record SessionBootstrapResponse(
    Guid UserId,
    string FirebaseUid,
    string Email,
    bool EmailVerified,
    int ClaimsVersion,
    string Status,
    string? DisplayName,
    string? ProfileImageUrl,
    string? PhoneNumber,
    DateTimeOffset? LastLoginAtUtc,
    DateTimeOffset? LastSyncedAtUtc,
    string? LastSeenAppVersion);
