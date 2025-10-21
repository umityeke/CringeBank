using System.Threading;
using System.Threading.Tasks;
using CringeBank.Application.Chats;

namespace CringeBank.Application.Notifications;

public interface IChatNotificationService
{
    Task QueueAsync(MessageResult message, CancellationToken cancellationToken = default);
}
