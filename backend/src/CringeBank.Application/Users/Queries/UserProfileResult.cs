using System;
using CringeBank.Domain.Auth.Enums;

namespace CringeBank.Application.Users.Queries;

public sealed record UserProfileResult(
    Guid PublicId,
    string Email,
    string Username,
    AuthUserStatus Status,
    DateTime? LastLoginAt,
    string? DisplayName,
    string? Bio,
    bool Verified,
    string? AvatarUrl,
    string? BannerUrl,
    string? Location,
    string? Website,
    DateTime CreatedAt,
    DateTime UpdatedAt);
