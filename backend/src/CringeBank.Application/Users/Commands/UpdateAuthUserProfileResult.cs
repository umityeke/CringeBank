using CringeBank.Application.Users.Queries;

namespace CringeBank.Application.Users.Commands;

public sealed record UpdateAuthUserProfileResult(
    bool Success,
    UserProfileResult? Profile,
    string? FailureCode)
{
    public static UpdateAuthUserProfileResult Failure(string failureCode) => new(false, null, failureCode);

    public static UpdateAuthUserProfileResult SuccessResult(UserProfileResult profile) => new(true, profile, null);
}
