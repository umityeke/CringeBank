using System.Threading;
using System.Threading.Tasks;

namespace CringeBank.Application.Chats;

public interface IChatEventPublisher
{
    Task PublishConversationCreatedAsync(ConversationResult conversation, CancellationToken cancellationToken = default);

    Task PublishMessageSentAsync(MessageResult message, CancellationToken cancellationToken = default);

    Task PublishConversationReadAsync(MarkConversationReadResult result, CancellationToken cancellationToken = default);
}
