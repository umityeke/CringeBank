using CringeBank.Domain.Auth.Enums;

namespace CringeBank.Application.Admin;

public sealed record UpdateUserStatusResult(
    bool Success,
    string? FailureCode,
    AuthUserStatus? Status,
    AdminUserListItem? User)
{
    public static UpdateUserStatusResult Ok(AuthUserStatus status, AdminUserListItem user) => new(true, null, status, user);

    public static UpdateUserStatusResult Fail(string failureCode) => new(false, failureCode, null, null);
}
