using System;
using System.Collections.Generic;
using CringeBank.Domain.Auth.Enums;

namespace CringeBank.Application.Admin;

public sealed record AdminUserListItem(
    Guid PublicId,
    string Email,
    string Username,
    AuthUserStatus Status,
    DateTime CreatedAt,
    DateTime UpdatedAt,
    DateTime? LastLoginAt,
    string? DisplayName,
    IReadOnlyCollection<string> Roles);
