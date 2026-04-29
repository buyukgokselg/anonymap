namespace PulseCity.Domain.Entities;

public sealed class ChatThread
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string CreatedByUserId { get; set; } = string.Empty;
    public string LastMessage { get; set; } = string.Empty;
    public string? LastSenderId { get; set; }
    public DateTimeOffset LastMessageTime { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset? ExpiresAt { get; set; }
    public bool IsTemporary { get; set; } = true;
    public bool IsFriendChat { get; set; }
    public string? DirectMessageKey { get; set; }
    /// <summary>UserId of the person who sent a "make permanent" request inside the chat. Null = no pending request.</summary>
    public string? PendingFriendRequestFromUserId { get; set; }

    /// <summary>"direct" = 1:1 chat, "activity" = activity group chat. Default direct.</summary>
    public string Kind { get; set; } = "direct";

    /// <summary>For activity group chats only — the activity this thread belongs to.</summary>
    public Guid? ActivityId { get; set; }

    /// <summary>Optional display title — used for activity group chats (mirrors activity title at create time).</summary>
    public string Title { get; set; } = string.Empty;
}
