using System;

namespace CringeBank.Api.Profiles;

public sealed record SelfProfileResponse(
    Guid PublicId,
    string Email,
    string Username,
    string Status,
    string? DisplayName,
    string? Bio,
    bool Verified,
    string? AvatarUrl,
    string? BannerUrl,
    string? Location,
    string? Website,
    DateTime CreatedAt,
    DateTime UpdatedAt,
    DateTime? LastLoginAtUtc);
