using System.ComponentModel.DataAnnotations;

namespace PulseCity.Application.DTOs;

public sealed record ChatParticipantDto(
    string UserId,
    string UserName,
    string DisplayName,
    string ProfilePhotoUrl,
    string Mode,
    string PrivacyLevel,
    bool IsVisible,
    bool IsOnline,
    int UnreadCount,
    bool IsTyping,
    DateTimeOffset JoinedAt,
    DateTimeOffset? LastReadAt
);

public sealed record ChatThreadDto(
    Guid Id,
    string CreatedByUserId,
    string? DirectMessageKey,
    bool CurrentUserIsArchived,
    string? LastSenderId,
    string LastMessage,
    DateTimeOffset LastMessageTime,
    DateTimeOffset CreatedAt,
    DateTimeOffset? ExpiresAt,
    bool IsTemporary,
    bool IsFriendChat,
    IReadOnlyList<ChatParticipantDto> Participants,
    string? PendingFriendRequestFromUserId,
    /// <summary>"direct" | "activity".</summary>
    string Kind,
    /// <summary>Activity grup sohbeti için aktivite id.</summary>
    Guid? ActivityId,
    /// <summary>Activity grup sohbeti için başlık (yoksa boş).</summary>
    string Title
);

public sealed record ChatMessageDto(
    Guid Id,
    Guid ChatId,
    string SenderId,
    string SenderDisplayName,
    string SenderProfilePhotoUrl,
    string Text,
    string Type,
    string Status,
    DateTimeOffset CreatedAt,
    DateTimeOffset? UpdatedAt,
    DateTimeOffset? DeletedAt,
    bool DeletedForEveryone,
    string? PhotoUrl,
    string? VideoUrl,
    double? Latitude,
    double? Longitude,
    bool? PhotoApproved,
    string? Reaction,
    int? DisappearSeconds,
    Guid? SharedPostId,
    string? SharedPostAuthor,
    string? SharedPostLocation,
    string? SharedPostVibe,
    string? SharedPostMediaUrl
);

public sealed class DeleteChatMessageRequest
{
    [Required]
    [MaxLength(16)]
    public string Scope { get; set; } = "everyone";
}

public sealed class CreateDirectChatRequest
{
    [Required]
    [MaxLength(128)]
    public string OtherUserId { get; set; } = string.Empty;

    public bool IsTemporary { get; set; }
}

public sealed class SendChatMessageRequest
{
    [MaxLength(4000)]
    public string Text { get; set; } = string.Empty;

    [MaxLength(24)]
    public string Type { get; set; } = "text";

    [MaxLength(512)]
    public string? PhotoUrl { get; set; }

    [MaxLength(512)]
    public string? VideoUrl { get; set; }

    public double? Latitude { get; set; }
    public double? Longitude { get; set; }
    public bool? PhotoApproved { get; set; }

    [MaxLength(64)]
    public string? Reaction { get; set; }

    public int? DisappearSeconds { get; set; }
    public Guid? SharedPostId { get; set; }

    [MaxLength(128)]
    public string? SharedPostAuthor { get; set; }

    [MaxLength(160)]
    public string? SharedPostLocation { get; set; }

    [MaxLength(64)]
    public string? SharedPostVibe { get; set; }

    [MaxLength(512)]
    public string? SharedPostMediaUrl { get; set; }
}

public sealed class UpdateChatMessageStatusRequest
{
    [Required]
    [MaxLength(16)]
    public string Status { get; set; } = "sent";
}

public sealed class UpdateChatReactionRequest
{
    [MaxLength(64)]
    public string? Reaction { get; set; }
}

public sealed class SetTypingRequest
{
    public bool IsTyping { get; set; }
}
