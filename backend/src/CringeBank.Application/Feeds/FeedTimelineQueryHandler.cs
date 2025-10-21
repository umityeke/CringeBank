using System;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Application.Abstractions.Queries;

namespace CringeBank.Application.Feeds;

public sealed class FeedTimelineQueryHandler : IQueryHandler<FeedTimelineQuery, FeedCursorPage<FeedItemResult>>
{
    private readonly IFeedReadRepository _repository;

    public FeedTimelineQueryHandler(IFeedReadRepository repository)
    {
        _repository = repository ?? throw new ArgumentNullException(nameof(repository));
    }

    public Task<FeedCursorPage<FeedItemResult>> HandleAsync(FeedTimelineQuery query, CancellationToken cancellationToken)
    {
        if (query is null)
        {
            throw new ArgumentNullException(nameof(query));
        }

        return _repository.GetTimelineAsync(query, cancellationToken);
    }
}
