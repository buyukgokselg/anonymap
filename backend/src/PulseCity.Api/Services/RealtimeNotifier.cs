using Microsoft.AspNetCore.SignalR;
using PulseCity.Api.Hubs;
using PulseCity.Application.DTOs;
using PulseCity.Application.Interfaces;
using PulseCity.Application.Realtime;

namespace PulseCity.Api.Services;

public sealed class RealtimeNotifier(
    IHubContext<PulseRealtimeHub> hubContext
) : IRealtimeNotifier
{
    public Task NotifyPresenceChangedAsync(
        string city,
        string userId,
        CancellationToken cancellationToken = default
    )
    {
        if (string.IsNullOrWhiteSpace(city))
        {
            return Task.CompletedTask;
        }

        return hubContext.Clients.Group(RealtimeGroups.Presence(city)).SendAsync(
            "presenceChanged",
            new
            {
                city = city.Trim(),
                userId,
                occurredAt = DateTimeOffset.UtcNow,
            },
            cancellationToken
        );
    }

    public Task NotifyProfileChangedAsync(
        string userId,
        CancellationToken cancellationToken = default
    ) => hubContext.Clients.Group(RealtimeGroups.User(userId)).SendAsync(
        "profileChanged",
        new
        {
            userId,
            occurredAt = DateTimeOffset.UtcNow,
        },
        cancellationToken
    );

    public Task NotifyFriendRequestsChangedAsync(
        IReadOnlyCollection<string> userIds,
        CancellationToken cancellationToken = default
    ) => NotifyUserGroupsAsync(
        userIds,
        "friendRequestsChanged",
        new
        {
            occurredAt = DateTimeOffset.UtcNow,
        },
        cancellationToken
    );

    public Task NotifyRelationshipChangedAsync(
        IReadOnlyCollection<string> userIds,
        CancellationToken cancellationToken = default
    ) => NotifyUserGroupsAsync(
        userIds,
        "relationshipChanged",
        new
        {
            occurredAt = DateTimeOffset.UtcNow,
        },
        cancellationToken
    );

    public Task NotifyMatchesChangedAsync(
        IReadOnlyCollection<string> userIds,
        CancellationToken cancellationToken = default
    ) => NotifyUserGroupsAsync(
        userIds,
        "matchesChanged",
        new
        {
            occurredAt = DateTimeOffset.UtcNow,
        },
        cancellationToken
    );

    public async Task NotifyTypingChangedAsync(
        Guid chatId,
        IReadOnlyCollection<string> participantIds,
        string userId,
        bool isTyping,
        CancellationToken cancellationToken = default
    )
    {
        await hubContext.Clients.Group(RealtimeGroups.Chat(chatId)).SendAsync(
            "typingChanged",
            new
            {
                chatId,
                userId,
                isTyping,
                occurredAt = DateTimeOffset.UtcNow,
            },
            cancellationToken
        );

        await NotifyUserGroupsAsync(
            participantIds,
            "chatListChanged",
            new
            {
                chatId,
                userId,
                isTyping,
                occurredAt = DateTimeOffset.UtcNow,
            },
            cancellationToken
        );
    }

    public async Task NotifyChatUpdatedAsync(
        Guid chatId,
        IReadOnlyCollection<string> participantIds,
        ChatMessageDto? message = null,
        CancellationToken cancellationToken = default
    )
    {
        await hubContext.Clients.Group(RealtimeGroups.Chat(chatId)).SendAsync(
            "chatChanged",
            new
            {
                chatId,
                occurredAt = DateTimeOffset.UtcNow,
            },
            cancellationToken
        );

        if (message is not null)
        {
            await hubContext.Clients.Group(RealtimeGroups.Chat(chatId)).SendAsync(
                "messageCreated",
                message,
                cancellationToken
            );
        }

        await NotifyUserGroupsAsync(
            participantIds,
            "chatListChanged",
            new
            {
                chatId,
                occurredAt = DateTimeOffset.UtcNow,
            },
            cancellationToken
        );
    }

    public async Task NotifyFeedChangedAsync(
        Guid? postId,
        string? authorUserId,
        string? placeId,
        CancellationToken cancellationToken = default
    )
    {
        await hubContext.Clients.Group("feed").SendAsync(
            "feedChanged",
            new
            {
                postId,
                authorUserId,
                placeId,
                occurredAt = DateTimeOffset.UtcNow,
            },
            cancellationToken
        );

        if (!string.IsNullOrWhiteSpace(authorUserId))
        {
            await hubContext.Clients.Group(RealtimeGroups.User(authorUserId)).SendAsync(
                "userPostsChanged",
                new
                {
                    userId = authorUserId,
                    postId,
                    occurredAt = DateTimeOffset.UtcNow,
                },
                cancellationToken
            );
        }
    }

    public Task NotifyNotificationCreatedAsync(
        string recipientUserId,
        NotificationDto notification,
        int unreadCount,
        CancellationToken cancellationToken = default
    ) => hubContext.Clients.Group(RealtimeGroups.User(recipientUserId)).SendAsync(
        "notificationCreated",
        new
        {
            notification,
            unreadCount,
            occurredAt = DateTimeOffset.UtcNow,
        },
        cancellationToken
    );

    public Task NotifyNotificationsChangedAsync(
        string recipientUserId,
        int unreadCount,
        CancellationToken cancellationToken = default
    ) => hubContext.Clients.Group(RealtimeGroups.User(recipientUserId)).SendAsync(
        "notificationsChanged",
        new
        {
            unreadCount,
            occurredAt = DateTimeOffset.UtcNow,
        },
        cancellationToken
    );

    public Task NotifyActivityChangedAsync(
        Guid activityId,
        IReadOnlyCollection<string> recipientUserIds,
        string changeType,
        CancellationToken cancellationToken = default
    ) => NotifyUserGroupsAsync(
        recipientUserIds,
        "activityChanged",
        new
        {
            activityId,
            changeType,
            occurredAt = DateTimeOffset.UtcNow,
        },
        cancellationToken
    );

    private async Task NotifyUserGroupsAsync(
        IReadOnlyCollection<string> userIds,
        string eventName,
        object payload,
        CancellationToken cancellationToken
    )
    {
        foreach (var userId in userIds.Where(id => !string.IsNullOrWhiteSpace(id)).Distinct())
        {
            await hubContext.Clients.Group(RealtimeGroups.User(userId)).SendAsync(
                eventName,
                payload,
                cancellationToken
            );
        }
    }
}
