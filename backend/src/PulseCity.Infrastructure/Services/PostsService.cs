using Microsoft.EntityFrameworkCore;
using PulseCity.Application.DTOs;
using PulseCity.Application.Interfaces;
using PulseCity.Domain.Entities;
using PulseCity.Domain.Enums;
using PulseCity.Infrastructure.Data;
using PulseCity.Infrastructure.Internal;
using System.Globalization;
using System.Text.Json;

namespace PulseCity.Infrastructure.Services;

public sealed class PostsService(
    PulseCityDbContext dbContext,
    IRealtimeNotifier realtimeNotifier,
    IFileStorageService fileStorageService,
    IPushNotificationService pushNotificationService
) : IPostsService
{
    public async Task<IReadOnlyList<PostFeedItemDto>> GetFeedAsync(
        string? currentUserId,
        int take,
        string? vibeTag = null,
        string? type = null,
        CancellationToken cancellationToken = default
    )
    {
        var safeTake = Math.Clamp(take, 1, 60);
        IReadOnlyList<PostFeedSqlRow> rows = await QueryPostFeedRowsAsync(
            top: safeTake,
            userId: null,
            vibeTag: vibeTag,
            type: type,
            cancellationToken: cancellationToken
        );

        rows = await FilterBlockedRowsAsync(rows, currentUserId, cancellationToken);
        return await BuildFeedItemsFromRowsAsync(rows, currentUserId, cancellationToken);
    }

    public async Task<IReadOnlyList<PostFeedItemDto>> GetShortsFeedAsync(
        string? currentUserId,
        int take,
        string scope,
        double? latitude = null,
        double? longitude = null,
        double? radiusKm = null,
        CancellationToken cancellationToken = default
    )
    {
        var safeTake = Math.Clamp(take, 1, 40);
        var normalizedScope = string.Equals(scope, "personal", StringComparison.OrdinalIgnoreCase)
            ? "personal"
            : "global";
        var effectiveRadiusKm = Math.Clamp(radiusKm ?? 4.5, 1.0, 50.0);
        var viewerMode = normalizedScope == "personal"
            ? await ResolvePreferredShortsModeAsync(currentUserId, cancellationToken)
            : null;

        IReadOnlyList<ShortFeedSqlRow> rows = await QueryShortFeedRowsAsync(
            top: normalizedScope == "personal" ? 180 : 140,
            cancellationToken: cancellationToken
        );

        rows = await FilterBlockedShortRowsAsync(rows, currentUserId, cancellationToken);

        var now = DateTimeOffset.UtcNow;
        var rankedRows = normalizedScope == "personal"
            ? OrderPersonalShortRows(rows, viewerMode, latitude, longitude, effectiveRadiusKm, safeTake, now)
            : OrderGlobalShortRows(rows, latitude, longitude, safeTake, now);

        return await BuildShortFeedItemsFromRowsAsync(rankedRows, currentUserId, cancellationToken);
    }

    public async Task<PostFeedItemDto> CreatePostAsync(
        string userId,
        CreatePostRequest request,
        CancellationToken cancellationToken = default
    )
    {
        var hasMedia = request.PhotoUrls.Any(item => !string.IsNullOrWhiteSpace(item))
            || !string.IsNullOrWhiteSpace(request.VideoUrl);
        if (string.IsNullOrWhiteSpace(request.Text) && !hasMedia)
        {
            throw new InvalidOperationException("A post must contain text or media.");
        }

        var userExists = await dbContext.Users.AsNoTracking().AnyAsync(entry => entry.Id == userId, cancellationToken);
        if (!userExists)
        {
            throw new KeyNotFoundException("User was not found.");
        }

        var type = request.Type.Trim().Equals("short", StringComparison.OrdinalIgnoreCase)
            ? PostType.Short
            : PostType.Post;

        var post = new Post
        {
            UserId = userId,
            Text = request.Text.Trim(),
            LocationName = request.Location.Trim(),
            PlaceId = request.PlaceId.Trim(),
            Latitude = request.Latitude,
            Longitude = request.Longitude,
            PhotoUrls = request.PhotoUrls.Where(item => !string.IsNullOrWhiteSpace(item)).Distinct().Take(10).ToList(),
            VideoUrl = string.IsNullOrWhiteSpace(request.VideoUrl) ? null : request.VideoUrl.Trim(),
            Rating = request.Rating,
            VibeTag = request.VibeTag.Trim(),
            Type = type,
            CreatedAt = DateTimeOffset.UtcNow,
            UpdatedAt = DateTimeOffset.UtcNow,
        };

        dbContext.Posts.Add(post);
        await dbContext.SaveChangesAsync(cancellationToken);
        await realtimeNotifier.NotifyFeedChangedAsync(
            post.Id,
            userId,
            string.IsNullOrWhiteSpace(post.PlaceId) ? null : post.PlaceId,
            cancellationToken
        );

        var rows = await QueryPostFeedRowsAsync(
            top: 1,
            postId: post.Id,
            cancellationToken: cancellationToken
        );

        return rows.Count > 0
            ? (await BuildFeedItemsFromRowsAsync(rows, userId, cancellationToken)).Single()
            : (await BuildFeedItemsAsync([post], userId, cancellationToken)).Single();
    }

    public async Task<PostFeedItemDto?> UpdatePostAsync(
        Guid postId,
        string userId,
        UpdatePostRequest request,
        CancellationToken cancellationToken = default
    )
    {
        var post = await dbContext.Posts
            .FirstOrDefaultAsync(entry => entry.Id == postId && entry.UserId == userId, cancellationToken);

        if (post is null)
        {
            return null;
        }

        var normalizedText = request.Text.Trim();
        var normalizedLocation = request.Location.Trim();
        var normalizedPlaceId = request.PlaceId.Trim();
        var normalizedPhotoUrls = request.PhotoUrls
            .Where(item => !string.IsNullOrWhiteSpace(item))
            .Select(item => item.Trim())
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .Take(10)
            .ToList();
        var normalizedVideoUrl = string.IsNullOrWhiteSpace(request.VideoUrl)
            ? null
            : request.VideoUrl.Trim();
        var previousMedia = post.PhotoUrls
            .Where(item => !string.IsNullOrWhiteSpace(item))
            .Append(post.VideoUrl)
            .Where(item => !string.IsNullOrWhiteSpace(item))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList()!;

        var effectivePhotoUrls = normalizedPhotoUrls.Count > 0
            ? normalizedPhotoUrls
            : post.PhotoUrls;
        var effectiveVideoUrl = normalizedVideoUrl ?? post.VideoUrl;
        var hasMedia = effectivePhotoUrls.Count > 0 || !string.IsNullOrWhiteSpace(effectiveVideoUrl);
        if (string.IsNullOrWhiteSpace(normalizedText) && !hasMedia)
        {
            throw new InvalidOperationException("A post must contain text or media.");
        }

        post.Text = normalizedText;
        post.LocationName = normalizedLocation;
        post.PlaceId = normalizedPlaceId;
        post.Latitude = request.Latitude;
        post.Longitude = request.Longitude;
        post.PhotoUrls = effectivePhotoUrls;
        post.VideoUrl = effectiveVideoUrl;
        post.Rating = request.Rating;
        post.VibeTag = request.VibeTag.Trim();
        post.UpdatedAt = DateTimeOffset.UtcNow;

        await dbContext.SaveChangesAsync(cancellationToken);
        var currentMedia = post.PhotoUrls
            .Where(item => !string.IsNullOrWhiteSpace(item))
            .Append(post.VideoUrl)
            .Where(item => !string.IsNullOrWhiteSpace(item))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList()!;
        await DeleteMediaAsync(
            previousMedia.Except(currentMedia, StringComparer.OrdinalIgnoreCase),
            cancellationToken
        );
        await realtimeNotifier.NotifyFeedChangedAsync(postId, userId, post.PlaceId, cancellationToken);

        return (await BuildFeedItemsAsync([post], userId, cancellationToken)).Single();
    }

    public async Task<IReadOnlyList<PostFeedItemDto>> GetUserPostsAsync(
        string userId,
        string? currentUserId,
        string? type = null,
        CancellationToken cancellationToken = default
    )
    {
        IReadOnlyList<PostFeedSqlRow> rows = await QueryPostFeedRowsAsync(
            top: 120,
            userId: userId,
            type: type,
            cancellationToken: cancellationToken
        );

        rows = await FilterBlockedRowsAsync(rows, currentUserId, cancellationToken);
        return await BuildFeedItemsFromRowsAsync(rows, currentUserId, cancellationToken);
    }

    public async Task<IReadOnlyList<PostFeedItemDto>> GetSavedPostsAsync(
        string userId,
        CancellationToken cancellationToken = default
    )
    {
        IReadOnlyList<PostFeedSqlRow> rows = await dbContext.Database.SqlQueryRaw<PostFeedSqlRow>(
            "EXEC dbo.usp_GetSavedPostsByUser @UserId={0}",
            userId
        ).ToListAsync(cancellationToken);

        rows = await FilterBlockedRowsAsync(rows, userId, cancellationToken);
        return await BuildFeedItemsFromRowsAsync(rows, userId, cancellationToken);
    }

    public async Task<PostInteractionDto> ToggleLikeAsync(
        Guid postId,
        string userId,
        CancellationToken cancellationToken = default
    )
    {
        var postExists = await dbContext.Posts.AsNoTracking().AnyAsync(entry => entry.Id == postId, cancellationToken);
        if (!postExists)
        {
            throw new KeyNotFoundException("Post was not found.");
        }

        await EnsureNotBlockedForPostAsync(postId, userId, cancellationToken);

        var like = await dbContext.PostLikes
            .FirstOrDefaultAsync(entry => entry.PostId == postId && entry.UserId == userId, cancellationToken);

        var likedByCurrentUser = like is null;
        await using var transaction = await BeginOptionalTransactionAsync(cancellationToken);
        if (like is null)
        {
            dbContext.PostLikes.Add(
                new PostLike
                {
                    PostId = postId,
                    UserId = userId,
                    CreatedAt = DateTimeOffset.UtcNow,
                }
            );
        }
        else
        {
            dbContext.PostLikes.Remove(like);
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        if (transaction is not null)
        {
            await transaction.CommitAsync(cancellationToken);
        }
        await realtimeNotifier.NotifyFeedChangedAsync(postId, null, null, cancellationToken);
        if (likedByCurrentUser)
        {
            var post2 = await dbContext.Posts.AsNoTracking().FirstOrDefaultAsync(e => e.Id == postId, cancellationToken);
            if (post2 != null && post2.UserId != userId)
            {
                var liker = await dbContext.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == userId, cancellationToken);
                var likerName = liker?.DisplayName ?? "Birisi";
                _ = pushNotificationService.SendToUserAsync(
                    post2.UserId,
                    likerName,
                    "gönderini beğendi.",
                    new Dictionary<string, string> { ["type"] = "post_like", ["postId"] = postId.ToString() },
                    cancellationToken
                );
            }
        }
        var likesCount = await dbContext.PostLikes.CountAsync(entry => entry.PostId == postId, cancellationToken);
        return new PostInteractionDto(postId, likesCount, likedByCurrentUser);
    }

    public async Task<PostCommentDto> AddCommentAsync(
        Guid postId,
        string userId,
        AddPostCommentRequest request,
        CancellationToken cancellationToken = default
    )
    {
        var post = await dbContext.Posts.FirstOrDefaultAsync(entry => entry.Id == postId, cancellationToken)
            ?? throw new KeyNotFoundException("Post was not found.");
        var user = await dbContext.Users.AsNoTracking().FirstOrDefaultAsync(entry => entry.Id == userId, cancellationToken)
            ?? throw new KeyNotFoundException("User was not found.");

        await EnsureNotBlockedBetweenUsersAsync(userId, post.UserId, cancellationToken);

        var comment = new PostComment
        {
            PostId = postId,
            UserId = userId,
            Text = request.Text.Trim(),
            CreatedAt = DateTimeOffset.UtcNow,
        };

        dbContext.PostComments.Add(comment);
        post.CommentsCount += 1;
        post.UpdatedAt = DateTimeOffset.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);
        await realtimeNotifier.NotifyFeedChangedAsync(postId, post.UserId, post.PlaceId, cancellationToken);
        if (post.UserId != userId)
        {
            _ = pushNotificationService.SendToUserAsync(
                post.UserId,
                user.DisplayName,
                $"yorum yaptı: {comment.Text[..Math.Min(comment.Text.Length, 60)]}",
                new Dictionary<string, string> { ["type"] = "post_comment", ["postId"] = postId.ToString() },
                cancellationToken
            );
        }

        return new PostCommentDto(
            comment.Id,
            postId,
            userId,
            user.DisplayName,
            user.ProfilePhotoUrl,
            comment.Text,
            comment.CreatedAt
        );
    }

    public async Task<IReadOnlyList<PostCommentDto>> GetCommentsAsync(
        Guid postId,
        string? currentUserId,
        int skip = 0,
        int take = 50,
        CancellationToken cancellationToken = default
    )
    {
        var safeSkip = Math.Max(0, skip);
        var safeTake = Math.Clamp(take, 1, 100);
        var comments = await dbContext.PostComments.AsNoTracking()
            .Where(entry => entry.PostId == postId)
            .OrderBy(entry => entry.CreatedAt)
            .Skip(safeSkip)
            .Take(safeTake)
            .ToListAsync(cancellationToken);

        if (comments.Count == 0)
        {
            return [];
        }

        var userIds = comments.Select(entry => entry.UserId).Distinct().ToList();
        var blockedUserIds = await GetBlockedUserIdsAsync(currentUserId, cancellationToken);
        var users = await dbContext.Users.AsNoTracking()
            .Where(entry => userIds.Contains(entry.Id) && !blockedUserIds.Contains(entry.Id))
            .ToDictionaryAsync(entry => entry.Id, cancellationToken);

        return comments
            .Where(entry => users.ContainsKey(entry.UserId))
            .Select(entry => new PostCommentDto(
                entry.Id,
                entry.PostId,
                entry.UserId,
                users[entry.UserId].DisplayName,
                users[entry.UserId].ProfilePhotoUrl,
                entry.Text,
                entry.CreatedAt
            ))
            .ToList();
    }

    public async Task<PostCommentDto?> UpdateCommentAsync(
        Guid postId,
        Guid commentId,
        string userId,
        UpdatePostCommentRequest request,
        CancellationToken cancellationToken = default
    )
    {
        var comment = await dbContext.PostComments
            .FirstOrDefaultAsync(
                entry => entry.Id == commentId && entry.PostId == postId && entry.UserId == userId,
                cancellationToken
            );
        if (comment is null)
        {
            return null;
        }

        var user = await dbContext.Users.AsNoTracking()
            .FirstOrDefaultAsync(entry => entry.Id == userId, cancellationToken)
            ?? throw new KeyNotFoundException("User was not found.");

        comment.Text = request.Text.Trim();
        await dbContext.SaveChangesAsync(cancellationToken);

        var post = await dbContext.Posts.AsNoTracking()
            .FirstOrDefaultAsync(entry => entry.Id == postId, cancellationToken);
        await realtimeNotifier.NotifyFeedChangedAsync(postId, post?.UserId, post?.PlaceId, cancellationToken);

        return new PostCommentDto(
            comment.Id,
            comment.PostId,
            comment.UserId,
            user.DisplayName,
            user.ProfilePhotoUrl,
            comment.Text,
            comment.CreatedAt
        );
    }

    public async Task<bool> DeleteCommentAsync(
        Guid postId,
        Guid commentId,
        string userId,
        CancellationToken cancellationToken = default
    )
    {
        var comment = await dbContext.PostComments
            .FirstOrDefaultAsync(
                entry => entry.Id == commentId && entry.PostId == postId && entry.UserId == userId,
                cancellationToken
            );
        if (comment is null)
        {
            return false;
        }

        var post = await dbContext.Posts.FirstOrDefaultAsync(entry => entry.Id == postId, cancellationToken);
        if (post is null)
        {
            return false;
        }

        dbContext.PostComments.Remove(comment);
        post.CommentsCount = Math.Max(0, post.CommentsCount - 1);
        post.UpdatedAt = DateTimeOffset.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);
        await realtimeNotifier.NotifyFeedChangedAsync(postId, post.UserId, post.PlaceId, cancellationToken);
        return true;
    }

    public async Task<PostSaveDto> ToggleSaveAsync(
        Guid postId,
        string userId,
        CancellationToken cancellationToken = default
    )
    {
        var postExists = await dbContext.Posts.AsNoTracking().AnyAsync(entry => entry.Id == postId, cancellationToken);
        if (!postExists)
        {
            throw new KeyNotFoundException("Post was not found.");
        }

        await EnsureNotBlockedForPostAsync(postId, userId, cancellationToken);

        var savedPost = await dbContext.SavedPosts
            .FirstOrDefaultAsync(entry => entry.PostId == postId && entry.UserId == userId, cancellationToken);

        var savedByCurrentUser = savedPost is null;
        await using var transaction = await BeginOptionalTransactionAsync(cancellationToken);
        if (savedPost is null)
        {
            dbContext.SavedPosts.Add(
                new SavedPost
                {
                    PostId = postId,
                    UserId = userId,
                    CreatedAt = DateTimeOffset.UtcNow,
                }
            );
        }
        else
        {
            dbContext.SavedPosts.Remove(savedPost);
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        if (transaction is not null)
        {
            await transaction.CommitAsync(cancellationToken);
        }
        var authorUserId = await dbContext.Posts.AsNoTracking()
            .Where(entry => entry.Id == postId)
            .Select(entry => entry.UserId)
            .FirstOrDefaultAsync(cancellationToken);
        await realtimeNotifier.NotifyFeedChangedAsync(postId, authorUserId, null, cancellationToken);
        return new PostSaveDto(postId, savedByCurrentUser);
    }

    public async Task<bool> DeletePostAsync(
        Guid postId,
        string userId,
        CancellationToken cancellationToken = default
    )
    {
        var post = await dbContext.Posts
            .FirstOrDefaultAsync(entry => entry.Id == postId && entry.UserId == userId, cancellationToken);

        if (post is null)
        {
            return false;
        }

        var comments = await dbContext.PostComments.Where(e => e.PostId == postId).ToListAsync(cancellationToken);
        var likes = await dbContext.PostLikes.Where(e => e.PostId == postId).ToListAsync(cancellationToken);
        var saves = await dbContext.SavedPosts.Where(e => e.PostId == postId).ToListAsync(cancellationToken);

        dbContext.PostComments.RemoveRange(comments);
        dbContext.PostLikes.RemoveRange(likes);
        dbContext.SavedPosts.RemoveRange(saves);
        dbContext.Posts.Remove(post);

        await dbContext.SaveChangesAsync(cancellationToken);
        await DeleteMediaAsync(
            post.PhotoUrls
                .Where(item => !string.IsNullOrWhiteSpace(item))
                .Append(post.VideoUrl)
                .Where(item => !string.IsNullOrWhiteSpace(item)),
            cancellationToken
        );
        await realtimeNotifier.NotifyFeedChangedAsync(postId, userId, null, cancellationToken);
        return true;
    }

    private async Task DeleteMediaAsync(
        IEnumerable<string> mediaUrls,
        CancellationToken cancellationToken
    )
    {
        foreach (var mediaUrl in mediaUrls
            .Where(item => !string.IsNullOrWhiteSpace(item))
            .Distinct(StringComparer.OrdinalIgnoreCase))
        {
            try
            {
                await fileStorageService.DeleteAsync(mediaUrl, cancellationToken);
            }
            catch
            {
                // Intentionally ignore storage cleanup failures so content deletion is not blocked.
            }
        }
    }

    private async Task<IReadOnlyList<PostFeedItemDto>> BuildFeedItemsAsync(
        IReadOnlyList<Post> posts,
        string? currentUserId,
        CancellationToken cancellationToken
    )
    {
        if (posts.Count == 0)
        {
            return [];
        }

        var postIds = posts.Select(entry => entry.Id).ToList();
        var userIds = posts.Select(entry => entry.UserId).Distinct().ToList();

        var users = await dbContext.Users.AsNoTracking()
            .Where(entry => userIds.Contains(entry.Id))
            .ToDictionaryAsync(entry => entry.Id, cancellationToken);

        var likes = await dbContext.PostLikes.AsNoTracking()
            .Where(entry => postIds.Contains(entry.PostId))
            .ToListAsync(cancellationToken);

        var savedPostIds = string.IsNullOrWhiteSpace(currentUserId)
            ? []
            : await dbContext.SavedPosts.AsNoTracking()
                .Where(entry => entry.UserId == currentUserId && postIds.Contains(entry.PostId))
                .Select(entry => entry.PostId)
                .ToListAsync(cancellationToken);

        return posts
            .Where(entry => users.ContainsKey(entry.UserId))
            .Select(entry =>
            {
                var user = users[entry.UserId];
                var likesForPost = likes.Where(like => like.PostId == entry.Id).ToList();
                return new PostFeedItemDto(
                    entry.Id,
                    entry.UserId,
                    user.DisplayName,
                    user.ProfilePhotoUrl,
                    entry.Text,
                    entry.LocationName,
                    entry.PlaceId,
                    entry.Latitude,
                    entry.Longitude,
                    entry.PhotoUrls,
                    entry.VideoUrl,
                    entry.Rating,
                    entry.VibeTag,
                    entry.Type == PostType.Short ? "short" : "post",
                    likesForPost.Count,
                    !string.IsNullOrWhiteSpace(currentUserId) && likesForPost.Any(like => like.UserId == currentUserId),
                    savedPostIds.Contains(entry.Id),
                    entry.CommentsCount,
                    entry.CreatedAt,
                    entry.UpdatedAt,
                    null,
                    null
                );
            })
            .ToList();
    }

    private async Task<IReadOnlyList<PostFeedItemDto>> BuildFeedItemsFromRowsAsync(
        IReadOnlyList<PostFeedSqlRow> rows,
        string? currentUserId,
        CancellationToken cancellationToken
    )
    {
        if (rows.Count == 0)
        {
            return [];
        }

        var postIds = rows.Select(entry => entry.Id).ToList();
        var likedPostIds = string.IsNullOrWhiteSpace(currentUserId)
            ? []
            : await dbContext.PostLikes.AsNoTracking()
                .Where(entry => entry.UserId == currentUserId && postIds.Contains(entry.PostId))
                .Select(entry => entry.PostId)
                .ToListAsync(cancellationToken);

        var savedPostIds = string.IsNullOrWhiteSpace(currentUserId)
            ? []
            : await dbContext.SavedPosts.AsNoTracking()
                .Where(entry => entry.UserId == currentUserId && postIds.Contains(entry.PostId))
                .Select(entry => entry.PostId)
                .ToListAsync(cancellationToken);

        return rows.Select(entry => new PostFeedItemDto(
            entry.Id,
            entry.UserId,
            entry.UserDisplayName,
            entry.UserProfilePhotoUrl,
            entry.Text,
            entry.Location,
            entry.PlaceId,
            entry.Latitude,
            entry.Longitude,
            DeserializeList(entry.PhotoUrls),
            entry.VideoUrl,
            entry.Rating,
            entry.VibeTag,
            entry.Type,
            entry.LikesCount,
            likedPostIds.Contains(entry.Id),
            savedPostIds.Contains(entry.Id),
            entry.CommentsCount,
            entry.CreatedAt,
            entry.CreatedAt,
            null,
            null
        )).ToList();
    }

    private async Task<IReadOnlyList<PostFeedItemDto>> BuildShortFeedItemsFromRowsAsync(
        IReadOnlyList<ShortFeedSqlRow> rows,
        string? currentUserId,
        CancellationToken cancellationToken
    )
    {
        if (rows.Count == 0)
        {
            return [];
        }

        var postIds = rows.Select(entry => entry.Id).ToList();
        var likedPostIds = string.IsNullOrWhiteSpace(currentUserId)
            ? []
            : await dbContext.PostLikes.AsNoTracking()
                .Where(entry => entry.UserId == currentUserId && postIds.Contains(entry.PostId))
                .Select(entry => entry.PostId)
                .ToListAsync(cancellationToken);

        var savedPostIds = string.IsNullOrWhiteSpace(currentUserId)
            ? []
            : await dbContext.SavedPosts.AsNoTracking()
                .Where(entry => entry.UserId == currentUserId && postIds.Contains(entry.PostId))
                .Select(entry => entry.PostId)
                .ToListAsync(cancellationToken);

        return rows.Select(entry => new PostFeedItemDto(
            entry.Id,
            entry.UserId,
            entry.UserDisplayName,
            entry.UserProfilePhotoUrl,
            entry.Text,
            entry.Location,
            entry.PlaceId,
            entry.Latitude,
            entry.Longitude,
            DeserializeList(entry.PhotoUrls),
            entry.VideoUrl,
            entry.Rating,
            entry.VibeTag,
            entry.Type,
            entry.LikesCount,
            likedPostIds.Contains(entry.Id),
            savedPostIds.Contains(entry.Id),
            entry.CommentsCount,
            entry.CreatedAt,
            entry.CreatedAt,
            entry.UserMode,
            entry.DistanceMeters
        )).ToList();
    }

    private async Task<IReadOnlyList<PostFeedSqlRow>> QueryPostFeedRowsAsync(
        int top,
        string? userId = null,
        string? vibeTag = null,
        string? type = null,
        Guid? postId = null,
        CancellationToken cancellationToken = default
    )
    {
        var sql = new System.Text.StringBuilder(
            $"SELECT TOP ({Math.Clamp(top, 1, 240)}) * FROM dbo.vw_PostFeedSummary WHERE 1 = 1"
        );
        var parameters = new List<object>();

        if (postId.HasValue)
        {
            sql.Append($" AND Id = {{{parameters.Count}}}");
            parameters.Add(postId.Value);
        }

        if (!string.IsNullOrWhiteSpace(userId))
        {
            sql.Append($" AND UserId = {{{parameters.Count}}}");
            parameters.Add(userId.Trim());
        }

        if (!string.IsNullOrWhiteSpace(vibeTag))
        {
            sql.Append($" AND VibeTag = {{{parameters.Count}}}");
            parameters.Add(vibeTag.Trim());
        }

        if (!string.IsNullOrWhiteSpace(type))
        {
            sql.Append($" AND Type = {{{parameters.Count}}}");
            parameters.Add(type.Trim().ToLowerInvariant());
        }

        sql.Append(" ORDER BY CreatedAt DESC");

        return await dbContext.Database.SqlQueryRaw<PostFeedSqlRow>(
            sql.ToString(),
            parameters.ToArray()
        ).ToListAsync(cancellationToken);
    }

    private async Task<IReadOnlyList<ShortFeedSqlRow>> QueryShortFeedRowsAsync(
        int top,
        CancellationToken cancellationToken = default
    )
    {
        var safeTop = Math.Clamp(top, 1, 240);
        var sql =
            """
            SELECT TOP (
            """
            + safeTop.ToString(CultureInfo.InvariantCulture)
            + """
            )
                p.Id,
                p.UserId,
                u.DisplayName AS UserDisplayName,
                u.ProfilePhotoUrl AS UserProfilePhotoUrl,
                p.Text,
                p.LocationName AS Location,
                p.PlaceId,
                p.Latitude,
                p.Longitude,
                p.PhotoUrls,
                p.VideoUrl,
                p.Rating,
                p.VibeTag,
                N'short' AS Type,
                ISNULL(lk.LikesCount, 0) AS LikesCount,
                p.CommentsCount,
                p.CreatedAt,
                u.Mode AS UserMode,
                CAST(NULL AS float) AS DistanceMeters
            FROM Posts AS p
            INNER JOIN Users AS u ON u.Id = p.UserId
            LEFT JOIN
            (
                SELECT PostId, COUNT(*) AS LikesCount
                FROM PostLikes
                GROUP BY PostId
            ) AS lk ON lk.PostId = p.Id
            WHERE p.Type = 1
            ORDER BY p.CreatedAt DESC
            """;

        return await dbContext.Database.SqlQueryRaw<ShortFeedSqlRow>(
            sql
        ).ToListAsync(cancellationToken);
    }

    private static IReadOnlyList<string> DeserializeList(string? json)
    {
        if (string.IsNullOrWhiteSpace(json))
        {
            return [];
        }

        try
        {
            return JsonSerializer.Deserialize<List<string>>(json) ?? [];
        }
        catch
        {
            return [];
        }
    }

    private async Task<IReadOnlyList<PostFeedSqlRow>> FilterBlockedRowsAsync(
        IReadOnlyList<PostFeedSqlRow> rows,
        string? currentUserId,
        CancellationToken cancellationToken
    )
    {
        if (rows.Count == 0 || string.IsNullOrWhiteSpace(currentUserId))
        {
            return rows;
        }

        var blockedUserIds = await GetBlockedUserIdsAsync(currentUserId, cancellationToken);
        if (blockedUserIds.Count == 0)
        {
            return rows;
        }

        return rows.Where(entry => !blockedUserIds.Contains(entry.UserId)).ToList();
    }

    private async Task<IReadOnlyList<ShortFeedSqlRow>> FilterBlockedShortRowsAsync(
        IReadOnlyList<ShortFeedSqlRow> rows,
        string? currentUserId,
        CancellationToken cancellationToken
    )
    {
        if (rows.Count == 0 || string.IsNullOrWhiteSpace(currentUserId))
        {
            return rows;
        }

        var blockedUserIds = await GetBlockedUserIdsAsync(currentUserId, cancellationToken);
        if (blockedUserIds.Count == 0)
        {
            return rows;
        }

        return rows.Where(entry => !blockedUserIds.Contains(entry.UserId)).ToList();
    }

    private async Task<string?> ResolvePreferredShortsModeAsync(
        string? currentUserId,
        CancellationToken cancellationToken
    )
    {
        if (string.IsNullOrWhiteSpace(currentUserId))
        {
            return null;
        }

        return await dbContext.Users.AsNoTracking()
            .Where(entry => entry.Id == currentUserId)
            .Select(entry => entry.Mode)
            .FirstOrDefaultAsync(cancellationToken);
    }

    private static IReadOnlyList<ShortFeedSqlRow> OrderPersonalShortRows(
        IReadOnlyList<ShortFeedSqlRow> rows,
        string? viewerMode,
        double? latitude,
        double? longitude,
        double radiusKm,
        int take,
        DateTimeOffset now
    )
    {
        var prepared = rows
            .Select(entry =>
            {
                entry.DistanceMeters = CalculateDistanceMeters(latitude, longitude, entry.Latitude, entry.Longitude);
                return entry;
            })
            .ToList();

        var sameModeRows = string.IsNullOrWhiteSpace(viewerMode)
            ? prepared
            : prepared.Where(entry => string.Equals(entry.UserMode, viewerMode, StringComparison.OrdinalIgnoreCase)).ToList();

        var radiusMeters = radiusKm * 1000;
        var ordered = new List<ShortFeedSqlRow>();
        var usedIds = new HashSet<Guid>();

        void AppendRows(IEnumerable<ShortFeedSqlRow> candidates)
        {
            foreach (var candidate in candidates)
            {
                if (usedIds.Add(candidate.Id))
                {
                    ordered.Add(candidate);
                    if (ordered.Count >= take)
                    {
                        break;
                    }
                }
            }
        }

        AppendRows(
            sameModeRows
                .Where(entry => GetAgeHours(entry.CreatedAt, now) <= 72
                    && (!entry.DistanceMeters.HasValue || entry.DistanceMeters.Value <= radiusMeters))
                .OrderByDescending(entry => CalculatePersonalScore(entry, radiusMeters, now, true))
                .ThenByDescending(entry => entry.CreatedAt)
        );

        if (ordered.Count < take)
        {
            AppendRows(
                sameModeRows
                    .Where(entry => GetAgeHours(entry.CreatedAt, now) <= 168
                        && (!entry.DistanceMeters.HasValue || entry.DistanceMeters.Value <= radiusMeters * 3))
                    .OrderByDescending(entry => CalculatePersonalScore(entry, radiusMeters * 2, now, false))
                    .ThenByDescending(entry => entry.CreatedAt)
            );
        }

        if (ordered.Count < take)
        {
            AppendRows(
                sameModeRows
                    .OrderByDescending(entry => CalculatePersonalScore(entry, radiusMeters * 4, now, false))
                    .ThenByDescending(entry => entry.CreatedAt)
            );
        }

        if (ordered.Count < take)
        {
            AppendRows(
                prepared
                    .Where(entry => GetAgeHours(entry.CreatedAt, now) <= 120)
                    .OrderByDescending(entry => CalculateFallbackScore(entry, now))
                    .ThenByDescending(entry => entry.CreatedAt)
            );
        }

        return ordered.Take(take).ToList();
    }

    private static IReadOnlyList<ShortFeedSqlRow> OrderGlobalShortRows(
        IReadOnlyList<ShortFeedSqlRow> rows,
        double? latitude,
        double? longitude,
        int take,
        DateTimeOffset now
    )
    {
        return rows
            .Select(entry =>
            {
                entry.DistanceMeters = CalculateDistanceMeters(latitude, longitude, entry.Latitude, entry.Longitude);
                return entry;
            })
            .OrderByDescending(entry => CalculateGlobalScore(entry, now))
            .ThenByDescending(entry => entry.CreatedAt)
            .Take(take)
            .ToList();
    }

    private static double CalculatePersonalScore(
        ShortFeedSqlRow row,
        double radiusMeters,
        DateTimeOffset now,
        bool strictNearby
    )
    {
        var ageHours = GetAgeHours(row.CreatedAt, now);
        var freshnessScore = Math.Max(0, 96 - ageHours) * 6;
        var engagementScore = (row.LikesCount * 4) + (row.CommentsCount * 7);
        var distanceScore = row.DistanceMeters.HasValue
            ? Math.Max(0, radiusMeters - Math.Min(row.DistanceMeters.Value, radiusMeters)) / 35
            : (strictNearby ? 0 : 10);
        var modeScore = string.IsNullOrWhiteSpace(row.UserMode) ? 0 : 80;
        return modeScore + freshnessScore + engagementScore + distanceScore;
    }

    private static double CalculateFallbackScore(ShortFeedSqlRow row, DateTimeOffset now)
    {
        var ageHours = GetAgeHours(row.CreatedAt, now);
        var freshnessScore = Math.Max(0, 72 - ageHours) * 4;
        var engagementScore = (row.LikesCount * 3) + (row.CommentsCount * 5);
        var distanceScore = row.DistanceMeters.HasValue
            ? Math.Max(0, 5000 - Math.Min(row.DistanceMeters.Value, 5000)) / 120
            : 0;
        return freshnessScore + engagementScore + distanceScore;
    }

    private static double CalculateGlobalScore(ShortFeedSqlRow row, DateTimeOffset now)
    {
        var ageHours = GetAgeHours(row.CreatedAt, now);
        // 336 saat = 14 gün — daha uzun pencere, eski içeriklerin de sıralanabilmesi için
        var freshnessScore = Math.Max(0, 336 - ageHours) * 2;
        var engagementScore = (row.LikesCount * 5) + (row.CommentsCount * 9);
        var distanceScore = row.DistanceMeters.HasValue
            ? Math.Max(0, 6000 - Math.Min(row.DistanceMeters.Value, 6000)) / 180
            : 0;
        return freshnessScore + engagementScore + distanceScore;
    }

    private static double GetAgeHours(DateTimeOffset createdAt, DateTimeOffset now)
    {
        return Math.Max(0, (now - createdAt).TotalHours);
    }

    private static double? CalculateDistanceMeters(
        double? viewerLatitude,
        double? viewerLongitude,
        double? postLatitude,
        double? postLongitude
    )
    {
        if (!viewerLatitude.HasValue || !viewerLongitude.HasValue || !postLatitude.HasValue || !postLongitude.HasValue)
        {
            return null;
        }

        const double earthRadius = 6371000;
        var dLat = DegreesToRadians(postLatitude.Value - viewerLatitude.Value);
        var dLng = DegreesToRadians(postLongitude.Value - viewerLongitude.Value);
        var startLat = DegreesToRadians(viewerLatitude.Value);
        var endLat = DegreesToRadians(postLatitude.Value);

        var a = Math.Pow(Math.Sin(dLat / 2), 2)
            + Math.Cos(startLat) * Math.Cos(endLat) * Math.Pow(Math.Sin(dLng / 2), 2);
        var c = 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
        return earthRadius * c;
    }

    private static double DegreesToRadians(double value) => value * (Math.PI / 180);

    private Task<HashSet<string>> GetBlockedUserIdsAsync(
        string? currentUserId,
        CancellationToken cancellationToken
    ) => BlockedUsersHelper.GetBlockedUserIdsAsync(dbContext, currentUserId, cancellationToken);

    private async Task EnsureNotBlockedForPostAsync(
        Guid postId,
        string currentUserId,
        CancellationToken cancellationToken
    )
    {
        var authorUserId = await dbContext.Posts.AsNoTracking()
            .Where(entry => entry.Id == postId)
            .Select(entry => entry.UserId)
            .FirstOrDefaultAsync(cancellationToken);

        if (!string.IsNullOrWhiteSpace(authorUserId))
        {
            await EnsureNotBlockedBetweenUsersAsync(currentUserId, authorUserId, cancellationToken);
        }
    }

    private async Task EnsureNotBlockedBetweenUsersAsync(
        string currentUserId,
        string otherUserId,
        CancellationToken cancellationToken
    )
    {
        if (string.IsNullOrWhiteSpace(currentUserId)
            || string.IsNullOrWhiteSpace(otherUserId)
            || string.Equals(currentUserId, otherUserId, StringComparison.Ordinal))
        {
            return;
        }

        var isBlocked = await dbContext.BlockedUsers.AsNoTracking().AnyAsync(
            entry =>
                (entry.UserId == currentUserId && entry.BlockedUserId == otherUserId)
                || (entry.UserId == otherUserId && entry.BlockedUserId == currentUserId),
            cancellationToken
        );

        if (isBlocked)
        {
            throw new InvalidOperationException("The requested post action is blocked.");
        }
    }

    private async Task<Microsoft.EntityFrameworkCore.Storage.IDbContextTransaction?> BeginOptionalTransactionAsync(
        CancellationToken cancellationToken
    )
    {
        if (!dbContext.Database.IsRelational())
        {
            return null;
        }

        return await dbContext.Database.BeginTransactionAsync(cancellationToken);
    }

    private sealed class PostFeedSqlRow
    {
        public Guid Id { get; init; }
        public string UserId { get; init; } = string.Empty;
        public string UserDisplayName { get; init; } = string.Empty;
        public string UserProfilePhotoUrl { get; init; } = string.Empty;
        public string Text { get; init; } = string.Empty;
        public string Location { get; init; } = string.Empty;
        public string PlaceId { get; init; } = string.Empty;
        public double? Latitude { get; init; }
        public double? Longitude { get; init; }
        public string PhotoUrls { get; init; } = "[]";
        public string? VideoUrl { get; init; }
        public double Rating { get; init; }
        public string VibeTag { get; init; } = string.Empty;
        public string Type { get; init; } = string.Empty;
        public int LikesCount { get; init; }
        public int CommentsCount { get; init; }
        public DateTimeOffset CreatedAt { get; init; }
    }

    private sealed class ShortFeedSqlRow
    {
        public Guid Id { get; init; }
        public string UserId { get; init; } = string.Empty;
        public string UserDisplayName { get; init; } = string.Empty;
        public string UserProfilePhotoUrl { get; init; } = string.Empty;
        public string Text { get; init; } = string.Empty;
        public string Location { get; init; } = string.Empty;
        public string PlaceId { get; init; } = string.Empty;
        public double? Latitude { get; init; }
        public double? Longitude { get; init; }
        public string? PhotoUrls { get; init; }
        public string? VideoUrl { get; init; }
        public double Rating { get; init; }
        public string VibeTag { get; init; } = string.Empty;
        public string Type { get; init; } = "short";
        public int LikesCount { get; init; }
        public int CommentsCount { get; init; }
        public DateTimeOffset CreatedAt { get; init; }
        public string UserMode { get; init; } = string.Empty;
        public double? DistanceMeters { get; set; }
    }
}
