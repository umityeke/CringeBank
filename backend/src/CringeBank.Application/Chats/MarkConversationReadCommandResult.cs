namespace CringeBank.Application.Chats;

public sealed record MarkConversationReadCommandResult(
    bool Success,
    MarkConversationReadResult? Read,
    string? FailureCode)
{
    public static MarkConversationReadCommandResult Failure(string failureCode) => new(false, null, failureCode);

    public static MarkConversationReadCommandResult SuccessResult(MarkConversationReadResult read) => new(true, read, null);
}
