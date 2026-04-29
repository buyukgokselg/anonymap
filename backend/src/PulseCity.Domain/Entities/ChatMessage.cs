using PulseCity.Domain.Enums;

namespace PulseCity.Domain.Entities;

public sealed class ChatMessage
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid ChatId { get; set; }
    public string SenderId { get; set; } = string.Empty;
    public string Text { get; set; } = string.Empty;
    public ChatMessageType Type { get; set; } = ChatMessageType.Text;
    public ChatMessageStatus Status { get; set; } = ChatMessageStatus.Sent;
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset? UpdatedAt { get; set; }
    public DateTimeOffset? DeletedAt { get; set; }
    public string? DeletedByUserId { get; set; }
    public string? PhotoUrl { get; set; }
    public string? VideoUrl { get; set; }
    public double? Latitude { get; set; }
    public double? Longitude { get; set; }
    public bool? PhotoApproved { get; set; }
    public string? Reaction { get; set; }
    public int? DisappearSeconds { get; set; }
    public Guid? SharedPostId { get; set; }
    public string? SharedPostAuthor { get; set; }
    public string? SharedPostLocation { get; set; }
    public string? SharedPostVibe { get; set; }
    public string? SharedPostMediaUrl { get; set; }
}
