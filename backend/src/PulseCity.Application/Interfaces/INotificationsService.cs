using PulseCity.Application.DTOs;
using PulseCity.Domain.Enums;

namespace PulseCity.Application.Interfaces;

public interface INotificationsService
{
    /// <summary>
    /// Create + persist + push (FCM) + realtime broadcast (SignalR) a notification for a single recipient.
    /// Returns the persisted DTO so callers can echo it where useful.
    /// </summary>
    Task<NotificationDto> CreateAsync(
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
    );

    Task<NotificationListResponseDto> ListAsync(
        string userId,
        NotificationListQuery query,
        CancellationToken cancellationToken = default
    );

    Task<UnreadCountDto> GetUnreadCountAsync(
        string userId,
        CancellationToken cancellationToken = default
    );

    Task<bool> MarkReadAsync(
        Guid notificationId,
        string userId,
        CancellationToken cancellationToken = default
    );

    Task<int> MarkAllReadAsync(
        string userId,
        CancellationToken cancellationToken = default
    );

    Task<bool> DeleteAsync(
        Guid notificationId,
        string userId,
        CancellationToken cancellationToken = default
    );
}
