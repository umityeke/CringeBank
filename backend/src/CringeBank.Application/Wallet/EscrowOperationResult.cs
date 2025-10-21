namespace CringeBank.Application.Wallet;

public sealed record EscrowOperationResult(
    bool Success,
    string? FailureCode,
    string? ErrorMessage)
{
    public static EscrowOperationResult Ok() => new(true, null, null);

    public static EscrowOperationResult Fail(string failureCode, string? errorMessage = null) => new(false, failureCode, errorMessage);
}
