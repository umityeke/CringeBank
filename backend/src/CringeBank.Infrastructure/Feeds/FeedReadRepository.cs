using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Application.Feeds;
using CringeBank.Domain.Auth.Enums;
using CringeBank.Domain.Social.Enums;
using CringeBank.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace CringeBank.Infrastructure.Feeds;

public sealed class FeedReadRepository : IFeedReadRepository
{
    private const int CursorParts = 2;

    private readonly CringeBankDbContext _dbContext;

    public FeedReadRepository(CringeBankDbContext dbContext)
    {
        _dbContext = dbContext ?? throw new ArgumentNullException(nameof(dbContext));
    }

    public async Task<FeedCursorPage<FeedItemResult>> GetTimelineAsync(FeedTimelineQuery query, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(query);

        var viewerContext = await LoadViewerContextAsync(query.ViewerPublicId, cancellationToken).ConfigureAwait(false);

        if (viewerContext is null)
        {
            return EmptyPage();
        }

        var baseQuery = BuildBasePostQuery(viewerContext);

        var filtered = baseQuery
            .Where(post => post.UserId == viewerContext.UserId
                || post.Visibility == SocialPostVisibility.Public
                || (post.Visibility == SocialPostVisibility.Followers && viewerContext.FollowingUserIds.Contains(post.UserId)));

        return await ExecuteQueryAsync(filtered, query.PageSize, query.Cursor, cancellationToken).ConfigureAwait(false);
    }

    public async Task<FeedCursorPage<FeedItemResult>> GetUserFeedAsync(FeedUserQuery query, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(query);

        var viewerContext = await LoadViewerContextAsync(query.ViewerPublicId, cancellationToken).ConfigureAwait(false);

        if (viewerContext is null)
        {
            return EmptyPage();
        }

        var target = await _dbContext.AuthUsers
            .AsNoTracking()
            .Where(user => user.PublicId == query.TargetPublicId)
            .Select(user => new { user.Id, user.Status })
            .SingleOrDefaultAsync(cancellationToken)
            .ConfigureAwait(false);

        if (target is null || target.Status != AuthUserStatus.Active)
        {
            return EmptyPage();
        }

        if (viewerContext.BlockedUserIds.Contains(target.Id))
        {
            return EmptyPage();
        }

        var canViewFollowersPosts = viewerContext.UserId == target.Id || viewerContext.FollowingUserIds.Contains(target.Id);

        var baseQuery = BuildBasePostQuery(viewerContext)
            .Where(post => post.UserId == target.Id);

        var filtered = baseQuery.Where(post => post.Visibility == SocialPostVisibility.Public
            || (post.Visibility == SocialPostVisibility.Followers && canViewFollowersPosts)
            || (post.Visibility == SocialPostVisibility.Private && viewerContext.UserId == target.Id));

        return await ExecuteQueryAsync(filtered, query.PageSize, query.Cursor, cancellationToken).ConfigureAwait(false);
    }

    public async Task<FeedCursorPage<FeedItemResult>> SearchAsync(FeedSearchQuery query, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(query);

        var viewerContext = await LoadViewerContextAsync(query.ViewerPublicId, cancellationToken).ConfigureAwait(false);

        if (viewerContext is null)
        {
            return EmptyPage();
        }

        var term = query.Term?.Trim();
        if (string.IsNullOrWhiteSpace(term))
        {
            return EmptyPage();
        }

        var baseQuery = BuildBasePostQuery(viewerContext)
            .Where(post => post.Text != null && EF.Functions.Like(post.Text, BuildContainsPattern(term)));

        var filtered = baseQuery.Where(post => post.UserId == viewerContext.UserId
                || post.Visibility == SocialPostVisibility.Public
                || (post.Visibility == SocialPostVisibility.Followers && viewerContext.FollowingUserIds.Contains(post.UserId)));

        return await ExecuteQueryAsync(filtered, query.PageSize, query.Cursor, cancellationToken).ConfigureAwait(false);
    }

    private IQueryable<Domain.Social.Entities.SocialPost> BuildBasePostQuery(ViewerContext context)
    {
        var query = _dbContext.SocialPosts
            .AsNoTracking()
            .Where(post => post.DeletedAt == null)
            .Where(post => post.Author.Status == AuthUserStatus.Active);

        if (context.BlockedUserIds.Length > 0)
        {
            query = query.Where(post => !context.BlockedUserIds.Contains(post.UserId));
        }

        return query;
    }

    private static async Task<FeedCursorPage<FeedItemResult>> ExecuteQueryAsync(
        IQueryable<Domain.Social.Entities.SocialPost> query,
        int pageSize,
        string? cursor,
        CancellationToken cancellationToken)
    {
        var effectiveSize = Math.Clamp(pageSize <= 0 ? 20 : pageSize, 1, 100);
        var hasCursor = TryParseCursor(cursor, out var cursorCreatedAt, out var cursorId);

        if (hasCursor)
        {
            query = query.Where(post => post.CreatedAt < cursorCreatedAt
                || (post.CreatedAt == cursorCreatedAt && post.Id < cursorId));
        }

        var pageSizeWithBuffer = effectiveSize + 1;

        var items = await query
            .OrderByDescending(post => post.CreatedAt)
            .ThenByDescending(post => post.Id)
            .Select(post => new
            {
                post.Id,
                post.PublicId,
                AuthorPublicId = post.Author.PublicId,
                post.Author.Username,
                DisplayName = post.Author.Profile != null && post.Author.Profile.DisplayName != null && post.Author.Profile.DisplayName != string.Empty ? post.Author.Profile.DisplayName : null,
                AvatarUrl = post.Author.Profile != null && post.Author.Profile.AvatarUrl != null && post.Author.Profile.AvatarUrl != string.Empty ? post.Author.Profile.AvatarUrl : null,
                post.Text,
                Visibility = post.Visibility,
                post.LikesCount,
                post.CommentsCount,
                post.SavesCount,
                post.CreatedAt,
                post.UpdatedAt,
                Media = post.Media
                    .OrderBy(media => media.OrderIndex)
                    .Select(media => new FeedMediaItem(media.Url, media.Mime, media.Width, media.Height, media.OrderIndex))
                    .ToList()
            })
            .Take(pageSizeWithBuffer)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        var hasMore = items.Count > effectiveSize;

        if (hasMore)
        {
            items.RemoveAt(items.Count - 1);
        }

        if (items.Count == 0)
        {
            return new FeedCursorPage<FeedItemResult>(Array.Empty<FeedItemResult>(), null, false);
        }

        var rows = items
            .Select(item => new
            {
                item.Id,
                Result = new FeedItemResult(
                    item.PublicId,
                    item.AuthorPublicId,
                    item.Username,
                    item.DisplayName,
                    item.AvatarUrl,
                    item.Text,
                    item.Visibility.ToString(),
                    item.LikesCount,
                    item.CommentsCount,
                    item.SavesCount,
                    item.CreatedAt,
                    item.UpdatedAt,
                    item.Media)
            })
            .ToList();

        var results = rows.Select(row => row.Result).ToList();
        var lastRow = rows[^1];
        var nextCursor = hasMore ? EncodeCursor(lastRow.Result.CreatedAt, lastRow.Id) : null;

        return new FeedCursorPage<FeedItemResult>(results, nextCursor, hasMore);
    }

    private static string EncodeCursor(DateTime createdAt, long id)
    {
        var ticks = createdAt.ToUniversalTime().Ticks;
        var payload = string.Create(CultureInfo.InvariantCulture, $"{ticks}:{id}");
        return Convert.ToBase64String(Encoding.UTF8.GetBytes(payload));
    }

    private static bool TryParseCursor(string? cursor, out DateTime createdAtUtc, out long id)
    {
        createdAtUtc = default;
        id = default;

        if (string.IsNullOrWhiteSpace(cursor))
        {
            return false;
        }

        try
        {
            var decoded = Encoding.UTF8.GetString(Convert.FromBase64String(cursor.Trim()));
            var parts = decoded.Split(':');
            if (parts.Length != CursorParts)
            {
                return false;
            }

            if (!long.TryParse(parts[0], NumberStyles.Integer, CultureInfo.InvariantCulture, out var ticks))
            {
                return false;
            }

            if (!long.TryParse(parts[1], NumberStyles.Integer, CultureInfo.InvariantCulture, out id))
            {
                return false;
            }

            createdAtUtc = new DateTime(ticks, DateTimeKind.Utc);
            return true;
        }
        catch
        {
            return false;
        }
    }

    private static FeedCursorPage<FeedItemResult> EmptyPage()
    {
        return new FeedCursorPage<FeedItemResult>(Array.Empty<FeedItemResult>(), null, false);
    }

    private async Task<ViewerContext?> LoadViewerContextAsync(Guid viewerPublicId, CancellationToken cancellationToken)
    {
        var viewer = await _dbContext.AuthUsers
            .AsNoTracking()
            .Where(user => user.PublicId == viewerPublicId)
            .Select(user => new { user.Id, user.Status })
            .SingleOrDefaultAsync(cancellationToken)
            .ConfigureAwait(false);

        if (viewer is null || viewer.Status != AuthUserStatus.Active)
        {
            return null;
        }

        var following = await _dbContext.AuthFollows
            .AsNoTracking()
            .Where(follow => follow.FollowerUserId == viewer.Id)
            .Select(follow => follow.FolloweeUserId)
            .ToArrayAsync(cancellationToken)
            .ConfigureAwait(false);

        var blocked = await _dbContext.AuthUserBlocks
            .AsNoTracking()
            .Where(block => block.BlockerUserId == viewer.Id || block.BlockedUserId == viewer.Id)
            .Select(block => block.BlockerUserId == viewer.Id ? block.BlockedUserId : block.BlockerUserId)
            .Distinct()
            .ToArrayAsync(cancellationToken)
            .ConfigureAwait(false);

        return new ViewerContext(viewer.Id, following, blocked);
    }

    private static string BuildContainsPattern(string term)
    {
        var escaped = term.Replace("[", "[[", StringComparison.Ordinal)
            .Replace("%", "[%]", StringComparison.Ordinal)
            .Replace("_", "[_]", StringComparison.Ordinal);
        return string.Create(CultureInfo.InvariantCulture, $"%{escaped}%");
    }

    private sealed record ViewerContext(long UserId, long[] FollowingUserIds, long[] BlockedUserIds);
}
