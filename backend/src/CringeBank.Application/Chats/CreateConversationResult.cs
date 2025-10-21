namespace CringeBank.Application.Chats;

public sealed record CreateConversationResult(
    bool Success,
    ConversationResult? Conversation,
    string? FailureCode)
{
    public static CreateConversationResult Failure(string failureCode) => new(false, null, failureCode);

    public static CreateConversationResult SuccessResult(ConversationResult conversation) => new(true, conversation, null);
}
