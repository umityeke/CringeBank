using System.Threading;
using System.Threading.Tasks;

namespace CringeBank.Application.Feeds;

public interface IFeedReadRepository
{
    Task<FeedCursorPage<FeedItemResult>> GetTimelineAsync(FeedTimelineQuery query, CancellationToken cancellationToken = default);

    Task<FeedCursorPage<FeedItemResult>> GetUserFeedAsync(FeedUserQuery query, CancellationToken cancellationToken = default);

    Task<FeedCursorPage<FeedItemResult>> SearchAsync(FeedSearchQuery query, CancellationToken cancellationToken = default);
}
