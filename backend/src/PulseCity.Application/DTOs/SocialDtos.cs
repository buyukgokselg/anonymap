using System.ComponentModel.DataAnnotations;

namespace PulseCity.Application.DTOs;

public sealed record FriendRequestDto(
    Guid Id,
    string Status,
    DateTimeOffset CreatedAt,
    UserSummaryDto FromUser,
    UserSummaryDto ToUser
);

public sealed class SendFriendRequestRequest
{
    [Required]
    [MaxLength(128)]
    public string TargetUserId { get; set; } = string.Empty;
}

public sealed class ToggleFollowRequest
{
    [Required]
    [MaxLength(128)]
    public string TargetUserId { get; set; } = string.Empty;
}

public sealed record FollowStateDto(
    string TargetUserId,
    bool IsFollowing,
    int FollowersCount,
    int FollowingCount
);

public sealed record RelationshipStateDto(
    string TargetUserId,
    bool IsFollowing,
    bool IsFriend,
    bool IsBlocked,
    bool IsBlockedByCurrentUser,
    bool HasBlockedCurrentUser,
    bool HasPendingIncomingFriendRequest,
    bool HasPendingOutgoingFriendRequest,
    Guid? IncomingFriendRequestId,
    Guid? OutgoingFriendRequestId
);

public sealed class BlockUserRequest
{
    [Required]
    [MaxLength(128)]
    public string TargetUserId { get; set; } = string.Empty;
}

public sealed record BlockedUserDto(
    string UserId,
    string DisplayName,
    string ProfilePhotoUrl,
    DateTimeOffset BlockedAt
);

public sealed class ReportUserRequest
{
    [Required]
    [MaxLength(128)]
    public string TargetUserId { get; set; } = string.Empty;

    [Required]
    [MaxLength(120)]
    public string Reason { get; set; } = string.Empty;

    [MaxLength(1000)]
    public string Details { get; set; } = string.Empty;
}
