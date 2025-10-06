using System;
using CringeBank.Domain.Enums;

namespace CringeBank.Application.Users;

public sealed record FirebaseUserProfile(
    string FirebaseUid,
    string Email,
    bool EmailVerified,
    int ClaimsVersion,
    string? DisplayName,
    string? ProfileImageUrl,
    string? PhoneNumber,
    DateTimeOffset? LastLoginAtUtc,
    string? LastSeenAppVersion,
    bool IsDisabled,
    DateTimeOffset? DisabledAtUtc,
    DateTimeOffset? DeletedAtUtc,
    UserStatus Status);
