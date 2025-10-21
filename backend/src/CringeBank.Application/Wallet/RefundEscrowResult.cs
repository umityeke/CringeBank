namespace CringeBank.Application.Wallet;

public sealed record RefundEscrowResult(
    bool Success,
    string? FailureCode,
    string? ErrorMessage)
{
    public static RefundEscrowResult Failure(string failureCode, string? errorMessage = null) => new(false, failureCode, errorMessage);

    public static RefundEscrowResult SuccessResult() => new(true, null, null);
}
