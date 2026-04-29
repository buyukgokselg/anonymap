using Microsoft.EntityFrameworkCore;
using PulseCity.Application.DTOs;
using PulseCity.Application.Interfaces;
using PulseCity.Domain.Entities;
using PulseCity.Infrastructure.Data;

namespace PulseCity.Infrastructure.Services;

public sealed class HighlightsService(
    PulseCityDbContext dbContext,
    IRealtimeNotifier realtimeNotifier,
    IFileStorageService fileStorageService
) : IHighlightsService
{
    public Task<HighlightDto> CreateHighlightAsync(
        string userId,
        CreateHighlightRequest request,
        CancellationToken cancellationToken = default
    ) => CreateAsync(
        userId,
        request,
        entryKind: "highlight",
        expiresAt: null,
        cancellationToken
    );

    public Task<HighlightDto> CreateStoryAsync(
        string userId,
        CreateHighlightRequest request,
        CancellationToken cancellationToken = default
    )
    {
        var durationHours = Math.Clamp(request.DurationHours ?? 24, 1, 168);
        return CreateAsync(
            userId,
            request,
            entryKind: "story",
            expiresAt: DateTimeOffset.UtcNow.AddHours(durationHours),
            cancellationToken
        );
    }

    public Task<IReadOnlyList<HighlightDto>> GetHighlightsByUserAsync(
        string userId,
        string? requesterUserId,
        CancellationToken cancellationToken = default
    ) => GetByUserAsync(
        userId,
        requesterUserId,
        entryKind: "highlight",
        requireActive: false,
        cancellationToken
    );

    public Task<IReadOnlyList<HighlightDto>> GetActiveStoriesByUserAsync(
        string userId,
        string? requesterUserId,
        CancellationToken cancellationToken = default
    ) => GetByUserAsync(
        userId,
        requesterUserId,
        entryKind: "story",
        requireActive: true,
        cancellationToken
    );

    public Task<bool> DeleteHighlightAsync(
        string userId,
        Guid highlightId,
        CancellationToken cancellationToken = default
    ) => DeleteAsync(userId, highlightId, entryKind: "highlight", cancellationToken);

    public Task<bool> DeleteStoryAsync(
        string userId,
        Guid storyId,
        CancellationToken cancellationToken = default
    ) => DeleteAsync(userId, storyId, entryKind: "story", cancellationToken);

    public async Task RecordStoryViewAsync(
        Guid storyId,
        string viewerUserId,
        CancellationToken cancellationToken = default
    )
    {
        var story = await dbContext.Highlights.AsNoTracking()
            .FirstOrDefaultAsync(
                entry =>
                    entry.Id == storyId
                    && entry.EntryKind == "story"
                    && (!entry.ExpiresAt.HasValue || entry.ExpiresAt > DateTimeOffset.UtcNow),
                cancellationToken
            );
        if (story is null || story.UserId == viewerUserId)
        {
            return;
        }

        var existing = await dbContext.StoryViews
            .FirstOrDefaultAsync(
                entry => entry.StoryId == storyId && entry.ViewerUserId == viewerUserId,
                cancellationToken
            );

        if (existing is null)
        {
            dbContext.StoryViews.Add(new StoryView
            {
                StoryId = storyId,
                ViewerUserId = viewerUserId,
                ViewedAt = DateTimeOffset.UtcNow,
            });
        }
        else
        {
            existing.ViewedAt = DateTimeOffset.UtcNow;
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        await realtimeNotifier.NotifyProfileChangedAsync(story.UserId, cancellationToken);
    }

    private async Task<bool> DeleteAsync(
        string userId,
        Guid highlightId,
        string entryKind,
        CancellationToken cancellationToken
    )
    {
        var highlight = await dbContext.Highlights
            .FirstOrDefaultAsync(
                entry =>
                    entry.Id == highlightId
                    && entry.UserId == userId
                    && entry.EntryKind == entryKind,
                cancellationToken
            );
        if (highlight is null)
        {
            return false;
        }

        var storyViews = await dbContext.StoryViews
            .Where(entry => entry.StoryId == highlightId)
            .ToListAsync(cancellationToken);
        if (storyViews.Count > 0)
        {
            dbContext.StoryViews.RemoveRange(storyViews);
        }

        dbContext.Highlights.Remove(highlight);
        await dbContext.SaveChangesAsync(cancellationToken);
        await DeleteMediaAsync(
            highlight.MediaUrls
                .Where(entry => !string.IsNullOrWhiteSpace(entry))
                .Append(highlight.CoverUrl)
                .Where(entry => !string.IsNullOrWhiteSpace(entry)),
            cancellationToken
        );
        await realtimeNotifier.NotifyProfileChangedAsync(userId, cancellationToken);
        return true;
    }

    private async Task<HighlightDto> CreateAsync(
        string userId,
        CreateHighlightRequest request,
        string entryKind,
        DateTimeOffset? expiresAt,
        CancellationToken cancellationToken
    )
    {
        var userExists = await dbContext.Users.AsNoTracking()
            .AnyAsync(entry => entry.Id == userId, cancellationToken);
        if (!userExists)
        {
            throw new KeyNotFoundException("User was not found.");
        }

        var highlight = new Highlight
        {
            UserId = userId,
            Title = request.Title.Trim(),
            CoverUrl = request.CoverUrl.Trim(),
            MediaUrls = request.MediaUrls
                .Where(entry => !string.IsNullOrWhiteSpace(entry))
                .Select(entry => entry.Trim())
                .Distinct()
                .ToList(),
            Type = string.IsNullOrWhiteSpace(request.Type)
                ? "image"
                : request.Type.Trim().ToLowerInvariant(),
            TextColorHex = string.IsNullOrWhiteSpace(request.TextColorHex)
                ? "#FFFFFF"
                : request.TextColorHex.Trim(),
            TextOffsetX = request.TextOffsetX,
            TextOffsetY = request.TextOffsetY,
            ModeTag = string.IsNullOrWhiteSpace(request.ModeTag) ? null : request.ModeTag.Trim(),
            LocationLabel = string.IsNullOrWhiteSpace(request.LocationLabel)
                ? null
                : request.LocationLabel.Trim(),
            PlaceId = string.IsNullOrWhiteSpace(request.PlaceId) ? null : request.PlaceId.Trim(),
            ShowModeOverlay = request.ShowModeOverlay,
            ShowLocationOverlay = request.ShowLocationOverlay,
            EntryKind = entryKind,
            ExpiresAt = expiresAt,
            CreatedAt = DateTimeOffset.UtcNow,
        };

        if (highlight.MediaUrls.Count == 0 && !string.IsNullOrWhiteSpace(highlight.CoverUrl))
        {
            highlight.MediaUrls = [highlight.CoverUrl];
        }

        dbContext.Highlights.Add(highlight);
        await dbContext.SaveChangesAsync(cancellationToken);
        await realtimeNotifier.NotifyProfileChangedAsync(userId, cancellationToken);

        return ToDto(
            highlight,
            requesterUserId: userId,
            requesterOwnsStories: true,
            storyViews: [],
            viewerProfiles: new Dictionary<string, UserProfile>(StringComparer.Ordinal)
        );
    }

    private async Task<IReadOnlyList<HighlightDto>> GetByUserAsync(
        string userId,
        string? requesterUserId,
        string entryKind,
        bool requireActive,
        CancellationToken cancellationToken
    )
    {
        var owner = await dbContext.Users.AsNoTracking()
            .FirstOrDefaultAsync(entry => entry.Id == userId, cancellationToken);
        if (owner is null)
        {
            return [];
        }

        if (!string.IsNullOrWhiteSpace(requesterUserId)
            && !string.Equals(requesterUserId, userId, StringComparison.Ordinal))
        {
            var blocked = await dbContext.BlockedUsers.AsNoTracking().AnyAsync(
                entry =>
                    (entry.UserId == requesterUserId && entry.BlockedUserId == userId)
                    || (entry.UserId == userId && entry.BlockedUserId == requesterUserId),
                cancellationToken
            );
            if (blocked)
            {
                return [];
            }
        }

        if (!owner.IsVisible
            && !string.Equals(requesterUserId, userId, StringComparison.Ordinal))
        {
            return [];
        }

        var query = dbContext.Highlights.AsNoTracking()
            .Where(entry => entry.UserId == userId && entry.EntryKind == entryKind);

        if (requireActive)
        {
            var now = DateTimeOffset.UtcNow;
            query = query.Where(entry => !entry.ExpiresAt.HasValue || entry.ExpiresAt > now);
        }

        var items = await query
            .OrderByDescending(entry => entry.CreatedAt)
            .ToListAsync(cancellationToken);

        if (items.Count == 0)
        {
            return [];
        }

        var storyIds = items
            .Where(entry => entry.EntryKind == "story")
            .Select(entry => entry.Id)
            .ToList();
        var storyViews = storyIds.Count == 0
            ? []
            : await dbContext.StoryViews.AsNoTracking()
                .Where(entry => storyIds.Contains(entry.StoryId))
                .OrderByDescending(entry => entry.ViewedAt)
                .ToListAsync(cancellationToken);

        var viewerIds = storyViews
            .Select(entry => entry.ViewerUserId)
            .Distinct(StringComparer.Ordinal)
            .ToList();
        var viewerProfiles = viewerIds.Count == 0
            ? new Dictionary<string, UserProfile>(StringComparer.Ordinal)
            : await dbContext.Users.AsNoTracking()
                .Where(entry => viewerIds.Contains(entry.Id))
                .ToDictionaryAsync(entry => entry.Id, cancellationToken);

        var requesterOwnsStories = string.Equals(requesterUserId, userId, StringComparison.Ordinal);
        return items.Select(entry => ToDto(
            entry,
            requesterUserId,
            requesterOwnsStories,
            storyViews,
            viewerProfiles
        )).ToList();
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
                // Keep content deletion successful even if storage cleanup fails.
            }
        }
    }

    private static HighlightDto ToDto(
        Highlight highlight,
        string? requesterUserId,
        bool requesterOwnsStories,
        IReadOnlyList<StoryView> storyViews,
        IReadOnlyDictionary<string, UserProfile> viewerProfiles
    ) =>
        new(
            highlight.Id,
            highlight.UserId,
            highlight.Title,
            highlight.CoverUrl,
            highlight.MediaUrls,
            highlight.Type,
            highlight.TextColorHex,
            highlight.TextOffsetX,
            highlight.TextOffsetY,
            highlight.ModeTag,
            highlight.LocationLabel,
            highlight.PlaceId,
            highlight.ShowModeOverlay,
            highlight.ShowLocationOverlay,
            highlight.EntryKind,
            highlight.ExpiresAt,
            highlight.CreatedAt,
            requesterUserId != null
                && storyViews.Any(entry =>
                    entry.StoryId == highlight.Id && entry.ViewerUserId == requesterUserId),
            storyViews.Count(entry => entry.StoryId == highlight.Id),
            requesterOwnsStories
                ? storyViews
                    .Where(entry => entry.StoryId == highlight.Id)
                    .Select(entry =>
                    {
                        viewerProfiles.TryGetValue(entry.ViewerUserId, out var viewer);
                        return new StoryViewerDto(
                            entry.ViewerUserId,
                            viewer?.UserName ?? string.Empty,
                            viewer?.DisplayName ?? string.Empty,
                            viewer?.ProfilePhotoUrl ?? string.Empty,
                            entry.ViewedAt
                        );
                    })
                    .ToList()
                : []
        );
}
