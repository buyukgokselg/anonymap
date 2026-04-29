using PulseCity.Application.DTOs;

namespace PulseCity.Application.Interfaces;

public interface ISocialService
{
    Task<IReadOnlyList<FriendRequestDto>> GetIncomingFriendRequestsAsync(
        string userId,
        CancellationToken cancellationToken = default
    );

    Task<FriendRequestDto?> SendFriendRequestAsync(
        string fromUserId,
        string toUserId,
        CancellationToken cancellationToken = default
    );

    Task<RelationshipStateDto> GetRelationshipStateAsync(
        string userId,
        string targetUserId,
        CancellationToken cancellationToken = default
    );

    Task<bool> RespondToFriendRequestAsync(
        Guid requestId,
        string userId,
        bool accept,
        CancellationToken cancellationToken = default
    );

    Task<bool> CancelOutgoingFriendRequestAsync(
        Guid requestId,
        string userId,
        CancellationToken cancellationToken = default
    );

    Task<bool> RemoveFriendAsync(
        string userId,
        string targetUserId,
        CancellationToken cancellationToken = default
    );

    Task<FollowStateDto> ToggleFollowAsync(
        string userId,
        string targetUserId,
        CancellationToken cancellationToken = default
    );

    Task BlockUserAsync(
        string userId,
        string targetUserId,
        CancellationToken cancellationToken = default
    );

    Task ReportUserAsync(
        string userId,
        ReportUserRequest request,
        CancellationToken cancellationToken = default
    );

    Task<bool> UnblockUserAsync(
        string userId,
        string targetUserId,
        CancellationToken cancellationToken = default
    );

    Task<IReadOnlyList<BlockedUserDto>> GetBlockedUsersAsync(
        string userId,
        CancellationToken cancellationToken = default
    );
}
