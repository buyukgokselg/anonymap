using PulseCity.Application.DTOs;

namespace PulseCity.Application.Interfaces;

public interface IRealtimeNotifier
{
    Task NotifyPresenceChangedAsync(
        string city,
        string userId,
        CancellationToken cancellationToken = default
    );

    Task NotifyProfileChangedAsync(
        string userId,
        CancellationToken cancellationToken = default
    );

    Task NotifyFriendRequestsChangedAsync(
        IReadOnlyCollection<string> userIds,
        CancellationToken cancellationToken = default
    );

    Task NotifyRelationshipChangedAsync(
        IReadOnlyCollection<string> userIds,
        CancellationToken cancellationToken = default
    );

    Task NotifyMatchesChangedAsync(
        IReadOnlyCollection<string> userIds,
        CancellationToken cancellationToken = default
    );

    Task NotifyTypingChangedAsync(
        Guid chatId,
        IReadOnlyCollection<string> participantIds,
        string userId,
        bool isTyping,
        CancellationToken cancellationToken = default
    );

    Task NotifyChatUpdatedAsync(
        Guid chatId,
        IReadOnlyCollection<string> participantIds,
        ChatMessageDto? message = null,
        CancellationToken cancellationToken = default
    );

    Task NotifyFeedChangedAsync(
        Guid? postId,
        string? authorUserId,
        string? placeId,
        CancellationToken cancellationToken = default
    );

    /// <summary>Push a freshly-created notification to the recipient's user group + bump unread count.</summary>
    Task NotifyNotificationCreatedAsync(
        string recipientUserId,
        NotificationDto notification,
        int unreadCount,
        CancellationToken cancellationToken = default
    );

    /// <summary>Notify clients that the user's unread/read state changed (mark-read, mark-all-read, delete).</summary>
    Task NotifyNotificationsChangedAsync(
        string recipientUserId,
        int unreadCount,
        CancellationToken cancellationToken = default
    );

    /// <summary>Broadcast an activity change to interested users (host + participants).</summary>
    /// <param name="changeType">"created" | "updated" | "cancelled" | "participants"</param>
    Task NotifyActivityChangedAsync(
        Guid activityId,
        IReadOnlyCollection<string> recipientUserIds,
        string changeType,
        CancellationToken cancellationToken = default
    );
}
