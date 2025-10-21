using System;
using System.Collections.Generic;

namespace CringeBank.Api.Admin;

public sealed record AdminUserResponse(
    Guid PublicId,
    string Email,
    string Username,
    string Status,
    DateTime CreatedAt,
    DateTime UpdatedAt,
    DateTime? LastLoginAt,
    string? DisplayName,
    IReadOnlyCollection<string> Roles);
