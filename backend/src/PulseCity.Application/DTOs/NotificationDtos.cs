using System.ComponentModel.DataAnnotations;

namespace PulseCity.Application.DTOs;

public sealed record NotificationDto(
    Guid Id,
    string Type,
    string Title,
    string Body,
    string? DeepLink,
    string? RelatedEntityType,
    string? RelatedEntityId,
    UserSummaryDto? Actor,
    bool IsRead,
    DateTimeOffset? ReadAt,
    DateTimeOffset CreatedAt
);

public sealed class NotificationListQuery
{
    [Range(1, 100)]
    public int Limit { get; set; } = 30;

    /// <summary>Optional cursor — return notifications strictly older than this timestamp.</summary>
    public DateTimeOffset? Before { get; set; }

    /// <summary>If true, return only unread notifications.</summary>
    public bool UnreadOnly { get; set; }
}

public sealed record NotificationListResponseDto(
    IReadOnlyList<NotificationDto> Items,
    int UnreadCount,
    bool HasMore
);

public sealed record UnreadCountDto(int UnreadCount);
