using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using PulseCity.Application.DTOs;
using PulseCity.Application.Interfaces;
using PulseCity.Domain.Entities;
using PulseCity.Domain.Enums;
using PulseCity.Infrastructure.Data;
using PulseCity.Infrastructure.Internal;

namespace PulseCity.Infrastructure.Services;

public sealed class NotificationsService(
    PulseCityDbContext dbContext,
    IRealtimeNotifier realtimeNotifier,
    IPushNotificationService pushNotificationService,
    ILogger<NotificationsService> logger
) : INotificationsService
{
    public async Task<NotificationDto> CreateAsync(
        string recipientUserId,
        NotificationType type,
        string title,
        string body,
        string? actorUserId = null,
        string? deepLink = null,
        string? relatedEntityType = null,
        string? relatedEntityId = null,
        Dictionary<string, string>? pushData = null,
        bool sendPush = true,
        CancellationToken cancellationToken = default
    )
    {
        if (string.IsNullOrWhiteSpace(recipientUserId))
        {
            throw new ArgumentException("Recipient user id is required.", nameof(recipientUserId));
        }

        var entity = new Notification
        {
            RecipientUserId = recipientUserId,
            ActorUserId = string.IsNullOrWhiteSpace(actorUserId) ? null : actorUserId,
            Type = type,
            Title = title.Trim(),
            Body = body.Trim(),
            DeepLink = string.IsNullOrWhiteSpace(deepLink) ? null : deepLink.Trim(),
            RelatedEntityType = relatedEntityType,
            RelatedEntityId = relatedEntityId,
            CreatedAt = DateTimeOffset.UtcNow,
        };

        dbContext.Notifications.Add(entity);
        await dbContext.SaveChangesAsync(cancellationToken);

        UserSummaryDto? actor = null;
        if (!string.IsNullOrWhiteSpace(entity.ActorUserId))
        {
            var actorEntity = await dbContext.Users.AsNoTracking()
                .FirstOrDefaultAsync(u => u.Id == entity.ActorUserId, cancellationToken);
            if (actorEntity is not null)
            {
                actor = actorEntity.ToSummaryDto();
            }
        }

        var dto = MapToDto(entity, actor);

        var unreadCount = await dbContext.Notifications.AsNoTracking()
            .CountAsync(n => n.RecipientUserId == recipientUserId && !n.IsRead, cancellationToken);

        try
        {
            await realtimeNotifier.NotifyNotificationCreatedAsync(
                recipientUserId,
                dto,
                unreadCount,
                cancellationToken
            );
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Realtime notification dispatch failed for user {UserId}", recipientUserId);
        }

        if (sendPush)
        {
            try
            {
                var data = pushData ?? new Dictionary<string, string>();
                data["notificationId"] = entity.Id.ToString();
                data["type"] = entity.Type.ToString();
                if (!string.IsNullOrWhiteSpace(entity.DeepLink))
                {
                    data["deepLink"] = entity.DeepLink;
                }
                if (!string.IsNullOrWhiteSpace(entity.RelatedEntityType))
                {
                    data["relatedEntityType"] = entity.RelatedEntityType;
                }
                if (!string.IsNullOrWhiteSpace(entity.RelatedEntityId))
                {
                    data["relatedEntityId"] = entity.RelatedEntityId;
                }

                await pushNotificationService.SendToUserAsync(
                    recipientUserId,
                    entity.Title,
                    entity.Body,
                    data,
                    cancellationToken
                );
            }
            catch (Exception ex)
            {
                logger.LogWarning(ex, "Push notification dispatch failed for user {UserId}", recipientUserId);
            }
        }

        return dto;
    }

    public async Task<NotificationListResponseDto> ListAsync(
        string userId,
        NotificationListQuery query,
        CancellationToken cancellationToken = default
    )
    {
        var limit = Math.Clamp(query.Limit <= 0 ? 30 : query.Limit, 1, 100);

        var baseQuery = dbContext.Notifications.AsNoTracking()
            .Where(n => n.RecipientUserId == userId);

        if (query.UnreadOnly)
        {
            baseQuery = baseQuery.Where(n => !n.IsRead);
        }
        if (query.Before is { } before)
        {
            baseQuery = baseQuery.Where(n => n.CreatedAt < before);
        }

        var rows = await baseQuery
            .OrderByDescending(n => n.CreatedAt)
            .Take(limit + 1)
            .ToListAsync(cancellationToken);

        var hasMore = rows.Count > limit;
        if (hasMore)
        {
            rows.RemoveAt(rows.Count - 1);
        }

        var actorIds = rows
            .Select(r => r.ActorUserId)
            .Where(id => !string.IsNullOrWhiteSpace(id))
            .Cast<string>()
            .Distinct()
            .ToList();

        var actors = actorIds.Count == 0
            ? new Dictionary<string, UserSummaryDto>()
            : (await dbContext.Users.AsNoTracking()
                    .Where(u => actorIds.Contains(u.Id))
                    .ToListAsync(cancellationToken))
                .ToDictionary(u => u.Id, u => u.ToSummaryDto());

        var items = rows
            .Select(r =>
            {
                UserSummaryDto? actor = null;
                if (!string.IsNullOrWhiteSpace(r.ActorUserId)
                    && actors.TryGetValue(r.ActorUserId!, out var found))
                {
                    actor = found;
                }
                return MapToDto(r, actor);
            })
            .ToList();

        var unreadCount = await dbContext.Notifications.AsNoTracking()
            .CountAsync(n => n.RecipientUserId == userId && !n.IsRead, cancellationToken);

        return new NotificationListResponseDto(items, unreadCount, hasMore);
    }

    public async Task<UnreadCountDto> GetUnreadCountAsync(
        string userId,
        CancellationToken cancellationToken = default
    )
    {
        var count = await dbContext.Notifications.AsNoTracking()
            .CountAsync(n => n.RecipientUserId == userId && !n.IsRead, cancellationToken);
        return new UnreadCountDto(count);
    }

    public async Task<bool> MarkReadAsync(
        Guid notificationId,
        string userId,
        CancellationToken cancellationToken = default
    )
    {
        var entity = await dbContext.Notifications
            .FirstOrDefaultAsync(n => n.Id == notificationId && n.RecipientUserId == userId, cancellationToken);
        if (entity is null)
        {
            return false;
        }

        if (!entity.IsRead)
        {
            entity.IsRead = true;
            entity.ReadAt = DateTimeOffset.UtcNow;
            await dbContext.SaveChangesAsync(cancellationToken);
        }

        await BroadcastChangedAsync(userId, cancellationToken);
        return true;
    }

    public async Task<int> MarkAllReadAsync(
        string userId,
        CancellationToken cancellationToken = default
    )
    {
        var now = DateTimeOffset.UtcNow;
        var affected = await dbContext.Notifications
            .Where(n => n.RecipientUserId == userId && !n.IsRead)
            .ExecuteUpdateAsync(
                setters => setters
                    .SetProperty(n => n.IsRead, true)
                    .SetProperty(n => n.ReadAt, now),
                cancellationToken
            );

        if (affected > 0)
        {
            await BroadcastChangedAsync(userId, cancellationToken);
        }
        return affected;
    }

    public async Task<bool> DeleteAsync(
        Guid notificationId,
        string userId,
        CancellationToken cancellationToken = default
    )
    {
        var entity = await dbContext.Notifications
            .FirstOrDefaultAsync(n => n.Id == notificationId && n.RecipientUserId == userId, cancellationToken);
        if (entity is null)
        {
            return false;
        }

        dbContext.Notifications.Remove(entity);
        await dbContext.SaveChangesAsync(cancellationToken);
        await BroadcastChangedAsync(userId, cancellationToken);
        return true;
    }

    private async Task BroadcastChangedAsync(string userId, CancellationToken cancellationToken)
    {
        try
        {
            var unreadCount = await dbContext.Notifications.AsNoTracking()
                .CountAsync(n => n.RecipientUserId == userId && !n.IsRead, cancellationToken);
            await realtimeNotifier.NotifyNotificationsChangedAsync(userId, unreadCount, cancellationToken);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Notification realtime broadcast failed for user {UserId}", userId);
        }
    }

    private static NotificationDto MapToDto(Notification entity, UserSummaryDto? actor) =>
        new(
            entity.Id,
            entity.Type.ToString(),
            entity.Title,
            entity.Body,
            entity.DeepLink,
            entity.RelatedEntityType,
            entity.RelatedEntityId,
            actor,
            entity.IsRead,
            entity.ReadAt,
            entity.CreatedAt
        );
}
