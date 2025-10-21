using System;

namespace CringeBank.Api.Profiles;

public sealed record PublicProfileResponse(
    Guid PublicId,
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
