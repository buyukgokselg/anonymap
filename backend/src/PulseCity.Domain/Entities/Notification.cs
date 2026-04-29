using PulseCity.Domain.Enums;

namespace PulseCity.Domain.Entities;

public sealed class Notification
{
    public Guid Id { get; set; } = Guid.NewGuid();

    /// <summary>The user who receives this notification.</summary>
    public string RecipientUserId { get; set; } = string.Empty;

    /// <summary>The user who triggered the notification (nullable for system notifications).</summary>
    public string? ActorUserId { get; set; }

    public NotificationType Type { get; set; } = NotificationType.System;

    public string Title { get; set; } = string.Empty;

    public string Body { get; set; } = string.Empty;

    /// <summary>Deep link or app route to open when the notification is tapped.</summary>
    public string? DeepLink { get; set; }

    /// <summary>Logical entity type the notification refers to (e.g. "Activity", "Match").</summary>
    public string? RelatedEntityType { get; set; }

    /// <summary>Identifier of the related entity (Guid or string id).</summary>
    public string? RelatedEntityId { get; set; }

    public bool IsRead { get; set; }

    public DateTimeOffset? ReadAt { get; set; }

    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}
