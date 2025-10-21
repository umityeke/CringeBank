namespace CringeBank.Application.Chats;

public sealed record SendMessageResult(
    bool Success,
    MessageResult? Message,
    string? FailureCode)
{
    public static SendMessageResult Failure(string failureCode) => new(false, null, failureCode);

    public static SendMessageResult SuccessResult(MessageResult message) => new(true, message, null);
}
