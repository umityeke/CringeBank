namespace CringeBank.Application.Wallet;

public sealed record ReleaseEscrowResult(
    bool Success,
    string? FailureCode,
    string? ErrorMessage)
{
    public static ReleaseEscrowResult Failure(string failureCode, string? errorMessage = null) => new(false, failureCode, errorMessage);

    public static ReleaseEscrowResult SuccessResult() => new(true, null, null);
}
