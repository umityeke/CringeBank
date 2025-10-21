using System;
using System.Collections.Generic;
using System.Linq;
using CringeBank.Application.Feeds;

namespace CringeBank.Api.Feeds;

internal static class FeedResponseMapper
{
    public static FeedPageResponse<FeedItemResponse> Map(FeedCursorPage<FeedItemResult> page)
    {
        ArgumentNullException.ThrowIfNull(page);

        var items = page.Items.Select(MapItem).ToList();
        return new FeedPageResponse<FeedItemResponse>(items, page.NextCursor, page.HasMore);
    }

    private static FeedItemResponse MapItem(FeedItemResult item)
    {
        ArgumentNullException.ThrowIfNull(item);

        var media = item.Media
            .Select(mediaItem => new FeedMediaItemResponse(
                mediaItem.Url,
                mediaItem.Mime,
                mediaItem.Width,
                mediaItem.Height,
                mediaItem.OrderIndex))
            .ToList();

        IReadOnlyList<FeedMediaItemResponse> mediaList = media;

        return new FeedItemResponse(
            item.PublicId,
            item.AuthorPublicId,
            item.AuthorUsername,
            item.AuthorDisplayName,
            item.AuthorAvatarUrl,
            item.Text,
            item.Visibility,
            item.LikesCount,
            item.CommentsCount,
            item.SavesCount,
            item.CreatedAt,
            item.UpdatedAt,
            mediaList);
    }
}
