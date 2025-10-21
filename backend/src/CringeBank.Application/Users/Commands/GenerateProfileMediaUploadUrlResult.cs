namespace CringeBank.Application.Users.Commands;

public sealed record GenerateProfileMediaUploadUrlResult(
    bool Success,
    ProfileMediaUploadToken? Token,
    string? FailureCode)
{
    public static GenerateProfileMediaUploadUrlResult Failure(string failureCode) => new(false, null, failureCode);

    public static GenerateProfileMediaUploadUrlResult SuccessResult(ProfileMediaUploadToken token) => new(true, token, null);
}
