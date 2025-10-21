namespace CringeBank.Api.Security;

public sealed record AppCheckVerificationResult(bool Success, string? FailureCode)
{
    public static readonly AppCheckVerificationResult SuccessResult = new(true, null);

    public static AppCheckVerificationResult MissingToken => new(false, "app_check_missing");
}
