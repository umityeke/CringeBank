namespace CringeBank.Application.Admin;

public sealed record AssignUserRoleResult(
    bool Success,
    string? FailureCode,
    AdminUserListItem? User)
{
    public static AssignUserRoleResult Ok(AdminUserListItem user) => new(true, null, user);

    public static AssignUserRoleResult Fail(string failureCode) => new(false, failureCode, null);
}
