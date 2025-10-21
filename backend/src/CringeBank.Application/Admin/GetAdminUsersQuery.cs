using System;
using CringeBank.Application.Abstractions.Queries;
using CringeBank.Domain.Auth.Enums;

namespace CringeBank.Application.Admin;

public sealed record GetAdminUsersQuery(
    Guid ActorPublicId,
    string? Term,
    AuthUserStatus? Status,
    string? Role,
    int PageSize,
    string? Cursor) : IQuery<AdminUserPageResult>;
