namespace CringeBank.Application.Admin;

public sealed record RemoveUserRoleResult(
    bool Success,
    string? FailureCode,
    AdminUserListItem? User)
{
    public static RemoveUserRoleResult Ok(AdminUserListItem user) => new(true, null, user);

    public static RemoveUserRoleResult Fail(string failureCode) => new(false, failureCode, null);
}
