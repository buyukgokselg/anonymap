namespace PulseCity.Domain.Entities;

public sealed class ChatParticipant
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid ChatId { get; set; }
    public string UserId { get; set; } = string.Empty;
    public DateTimeOffset JoinedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset? LastReadAt { get; set; }
    public int UnreadCount { get; set; }
    public bool IsTyping { get; set; }
    public bool IsArchived { get; set; }
    public DateTimeOffset? ArchivedAt { get; set; }
    public DateTimeOffset? DeletedAt { get; set; }
}
