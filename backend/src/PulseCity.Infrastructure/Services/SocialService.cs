using Microsoft.EntityFrameworkCore;
using PulseCity.Application.DTOs;
using PulseCity.Application.Interfaces;
using PulseCity.Domain.Entities;
using PulseCity.Domain.Enums;
using PulseCity.Infrastructure.Data;
using PulseCity.Infrastructure.Internal;

namespace PulseCity.Infrastructure.Services;

public sealed class SocialService(
    PulseCityDbContext dbContext,
    IRealtimeNotifier realtimeNotifier,
    INotificationsService notificationsService,
    IBadgesService badgesService
) : ISocialService
{
    public async Task<IReadOnlyList<FriendRequestDto>> GetIncomingFriendRequestsAsync(
        string userId,
        CancellationToken cancellationToken = default
    )
    {
        var blockedUserIds = await GetBlockedUserIdsAsync(userId, cancellationToken);
        var requests = await dbContext.FriendRequests.AsNoTracking()
            .Where(entry =>
                entry.ToUserId == userId
                && entry.Status == FriendRequestStatus.Pending
                && !blockedUserIds.Contains(entry.FromUserId))
            .OrderByDescending(entry => entry.CreatedAt)
            .Take(50)
            .ToListAsync(cancellationToken);

        if (requests.Count == 0)
        {
            return [];
        }

        return await BuildFriendRequestDtosAsync(requests, cancellationToken);
    }

    public async Task<FriendRequestDto?> SendFriendRequestAsync(
        string fromUserId,
        string toUserId,
        CancellationToken cancellationToken = default
    )
    {
        if (string.IsNullOrWhiteSpace(fromUserId) || string.IsNullOrWhiteSpace(toUserId) || fromUserId == toUserId)
        {
            return null;
        }

        await EnsureUsersExistAsync(fromUserId, toUserId, cancellationToken);
        await EnsureNotBlockedAsync(fromUserId, toUserId, cancellationToken);

        if (await AreFriendsAsync(fromUserId, toUserId, cancellationToken))
        {
            return null;
        }

        await using var transaction = await dbContext.Database.BeginTransactionAsync(cancellationToken);

        var inversePending = await dbContext.FriendRequests
            .FirstOrDefaultAsync(
                entry =>
                    entry.FromUserId == toUserId
                    && entry.ToUserId == fromUserId
                    && entry.Status == FriendRequestStatus.Pending,
                cancellationToken
            );

        if (inversePending is not null)
        {
            await AcceptFriendRequestInternalAsync(inversePending, fromUserId, cancellationToken);
            await transaction.CommitAsync(cancellationToken);
            await realtimeNotifier.NotifyFriendRequestsChangedAsync(
                [fromUserId, toUserId],
                cancellationToken
            );
            await realtimeNotifier.NotifyRelationshipChangedAsync(
                [fromUserId, toUserId],
                cancellationToken
            );
            await realtimeNotifier.NotifyProfileChangedAsync(fromUserId, cancellationToken);
            await realtimeNotifier.NotifyProfileChangedAsync(toUserId, cancellationToken);
            // İnverse-pending durumunda dolaylı kabul gerçekleşti — Connector'ı her iki tarafa hesapla.
            await badgesService.RecomputeAsync(fromUserId, cancellationToken);
            await badgesService.RecomputeAsync(toUserId, cancellationToken);
            return null;
        }

        var existing = await dbContext.FriendRequests
            .FirstOrDefaultAsync(
                entry =>
                    entry.FromUserId == fromUserId
                    && entry.ToUserId == toUserId
                    && entry.Status == FriendRequestStatus.Pending,
                cancellationToken
            );

        if (existing is null)
        {
            existing = new FriendRequest
            {
                FromUserId = fromUserId,
                ToUserId = toUserId,
                Status = FriendRequestStatus.Pending,
                CreatedAt = DateTimeOffset.UtcNow,
            };

            dbContext.FriendRequests.Add(existing);
            await dbContext.SaveChangesAsync(cancellationToken);
        }

        await transaction.CommitAsync(cancellationToken);
        await realtimeNotifier.NotifyFriendRequestsChangedAsync(
            [fromUserId, toUserId],
            cancellationToken
        );
        await realtimeNotifier.NotifyRelationshipChangedAsync(
            [fromUserId, toUserId],
            cancellationToken
        );
        await realtimeNotifier.NotifyProfileChangedAsync(fromUserId, cancellationToken);
        await realtimeNotifier.NotifyProfileChangedAsync(toUserId, cancellationToken);
        if (existing != null)
        {
            var fromUser = await dbContext.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == fromUserId, cancellationToken);
            var fromName = fromUser?.DisplayName ?? "Birisi";
            _ = notificationsService.CreateAsync(
                toUserId,
                NotificationType.FriendRequestReceived,
                fromName,
                "sana arkadaşlık isteği gönderdi.",
                actorUserId: fromUserId,
                deepLink: "/social/friend-requests",
                relatedEntityType: "FriendRequest",
                relatedEntityId: existing.Id.ToString(),
                cancellationToken: cancellationToken
            );
        }
        return (await BuildFriendRequestDtosAsync([existing], cancellationToken)).Single();
    }

    public async Task<RelationshipStateDto> GetRelationshipStateAsync(
        string userId,
        string targetUserId,
        CancellationToken cancellationToken = default
    )
    {
        if (string.IsNullOrWhiteSpace(userId) || string.IsNullOrWhiteSpace(targetUserId) || userId == targetUserId)
        {
            return new RelationshipStateDto(
                targetUserId,
                false,
                false,
                false,
                false,
                false,
                false,
                false,
                null,
                null
            );
        }

        var isFollowing = await dbContext.Follows.AsNoTracking().AnyAsync(
            entry => entry.FollowerUserId == userId && entry.FollowingUserId == targetUserId,
            cancellationToken
        );

        var (userAId, userBId) = OrderUsers(userId, targetUserId);
        var isFriend = await dbContext.Friendships.AsNoTracking().AnyAsync(
            entry => entry.UserAId == userAId && entry.UserBId == userBId,
            cancellationToken
        );

        var isBlockedByCurrentUser = await dbContext.BlockedUsers.AsNoTracking().AnyAsync(
            entry => entry.UserId == userId && entry.BlockedUserId == targetUserId,
            cancellationToken
        );
        var hasBlockedCurrentUser = await dbContext.BlockedUsers.AsNoTracking().AnyAsync(
            entry => entry.UserId == targetUserId && entry.BlockedUserId == userId,
            cancellationToken
        );
        var isBlocked = isBlockedByCurrentUser || hasBlockedCurrentUser;

        var incomingPending = await dbContext.FriendRequests.AsNoTracking()
            .Where(entry =>
                entry.FromUserId == targetUserId
                && entry.ToUserId == userId
                && entry.Status == FriendRequestStatus.Pending)
            .OrderByDescending(entry => entry.CreatedAt)
            .Select(entry => new { entry.Id })
            .FirstOrDefaultAsync(cancellationToken);

        var outgoingPending = await dbContext.FriendRequests.AsNoTracking()
            .Where(entry =>
                entry.FromUserId == userId
                && entry.ToUserId == targetUserId
                && entry.Status == FriendRequestStatus.Pending)
            .OrderByDescending(entry => entry.CreatedAt)
            .Select(entry => new { entry.Id })
            .FirstOrDefaultAsync(cancellationToken);

        return new RelationshipStateDto(
            targetUserId,
            isFollowing,
            isFriend,
            isBlocked,
            isBlockedByCurrentUser,
            hasBlockedCurrentUser,
            incomingPending is not null,
            outgoingPending is not null,
            incomingPending?.Id,
            outgoingPending?.Id
        );
    }

    public async Task<bool> RespondToFriendRequestAsync(
        Guid requestId,
        string userId,
        bool accept,
        CancellationToken cancellationToken = default
    )
    {
        var request = await dbContext.FriendRequests
            .FirstOrDefaultAsync(
                entry =>
                    entry.Id == requestId
                    && entry.ToUserId == userId
                    && entry.Status == FriendRequestStatus.Pending,
                cancellationToken
            );

        if (request is null)
        {
            return false;
        }

        await using var transaction = await dbContext.Database.BeginTransactionAsync(cancellationToken);
        if (accept)
        {
            await AcceptFriendRequestInternalAsync(request, userId, cancellationToken);
        }
        else
        {
            request.Status = FriendRequestStatus.Declined;
            request.RespondedAt = DateTimeOffset.UtcNow;
            await dbContext.SaveChangesAsync(cancellationToken);
        }

        await transaction.CommitAsync(cancellationToken);
        await realtimeNotifier.NotifyFriendRequestsChangedAsync(
            [request.FromUserId, request.ToUserId],
            cancellationToken
        );
        await realtimeNotifier.NotifyRelationshipChangedAsync(
            [request.FromUserId, request.ToUserId],
            cancellationToken
        );
        await realtimeNotifier.NotifyProfileChangedAsync(request.FromUserId, cancellationToken);
        await realtimeNotifier.NotifyProfileChangedAsync(request.ToUserId, cancellationToken);
        if (accept)
        {
            var accepter = await dbContext.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == userId, cancellationToken);
            var accepterName = accepter?.DisplayName ?? "Birisi";
            _ = notificationsService.CreateAsync(
                request.FromUserId,
                NotificationType.FriendRequestAccepted,
                accepterName,
                "arkadaşlık isteğini kabul etti.",
                actorUserId: userId,
                deepLink: $"/users/{userId}",
                relatedEntityType: "FriendRequest",
                relatedEntityId: request.Id.ToString(),
                cancellationToken: cancellationToken
            );

            // Connector rozetinin her iki taraf için ilerlemesini güncelle.
            await badgesService.RecomputeAsync(request.FromUserId, cancellationToken);
            await badgesService.RecomputeAsync(request.ToUserId, cancellationToken);
        }
        return true;
    }

    public async Task<bool> CancelOutgoingFriendRequestAsync(
        Guid requestId,
        string userId,
        CancellationToken cancellationToken = default
    )
    {
        var request = await dbContext.FriendRequests
            .FirstOrDefaultAsync(
                entry =>
                    entry.Id == requestId
                    && entry.FromUserId == userId
                    && entry.Status == FriendRequestStatus.Pending,
                cancellationToken
            );

        if (request is null)
        {
            return false;
        }

        request.Status = FriendRequestStatus.Cancelled;
        request.RespondedAt = DateTimeOffset.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);
        await realtimeNotifier.NotifyFriendRequestsChangedAsync(
            [request.FromUserId, request.ToUserId],
            cancellationToken
        );
        await realtimeNotifier.NotifyRelationshipChangedAsync(
            [request.FromUserId, request.ToUserId],
            cancellationToken
        );
        await realtimeNotifier.NotifyProfileChangedAsync(request.FromUserId, cancellationToken);
        await realtimeNotifier.NotifyProfileChangedAsync(request.ToUserId, cancellationToken);
        return true;
    }

    public async Task<bool> RemoveFriendAsync(
        string userId,
        string targetUserId,
        CancellationToken cancellationToken = default
    )
    {
        if (string.IsNullOrWhiteSpace(userId) || string.IsNullOrWhiteSpace(targetUserId) || userId == targetUserId)
        {
            return false;
        }

        var (userAId, userBId) = OrderUsers(userId, targetUserId);
        var friendship = await dbContext.Friendships
            .FirstOrDefaultAsync(
                entry => entry.UserAId == userAId && entry.UserBId == userBId,
                cancellationToken
            );

        if (friendship is null)
        {
            return false;
        }

        dbContext.Friendships.Remove(friendship);
        await dbContext.SaveChangesAsync(cancellationToken);
        await RefreshRelationshipCountersAsync([userId, targetUserId], cancellationToken);
        await realtimeNotifier.NotifyRelationshipChangedAsync(
            [userId, targetUserId],
            cancellationToken
        );
        await realtimeNotifier.NotifyProfileChangedAsync(userId, cancellationToken);
        await realtimeNotifier.NotifyProfileChangedAsync(targetUserId, cancellationToken);
        return true;
    }

    public async Task<FollowStateDto> ToggleFollowAsync(
        string userId,
        string targetUserId,
        CancellationToken cancellationToken = default
    )
    {
        if (string.IsNullOrWhiteSpace(userId) || string.IsNullOrWhiteSpace(targetUserId) || userId == targetUserId)
        {
            throw new InvalidOperationException("Invalid follow target.");
        }

        await EnsureUsersExistAsync(userId, targetUserId, cancellationToken);
        await EnsureNotBlockedAsync(userId, targetUserId, cancellationToken);

        var relation = await dbContext.Follows
            .FirstOrDefaultAsync(
                entry => entry.FollowerUserId == userId && entry.FollowingUserId == targetUserId,
                cancellationToken
            );

        var isFollowing = relation is null;
        if (relation is null)
        {
            dbContext.Follows.Add(
                new FollowRelation
                {
                    FollowerUserId = userId,
                    FollowingUserId = targetUserId,
                    CreatedAt = DateTimeOffset.UtcNow,
                }
            );
        }
        else
        {
            dbContext.Follows.Remove(relation);
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        await RefreshRelationshipCountersAsync([userId, targetUserId], cancellationToken);
        await realtimeNotifier.NotifyRelationshipChangedAsync(
            [userId, targetUserId],
            cancellationToken
        );
        await realtimeNotifier.NotifyProfileChangedAsync(userId, cancellationToken);
        await realtimeNotifier.NotifyProfileChangedAsync(targetUserId, cancellationToken);

        var target = await dbContext.Users.AsNoTracking().FirstAsync(entry => entry.Id == targetUserId, cancellationToken);
        var me = await dbContext.Users.AsNoTracking().FirstAsync(entry => entry.Id == userId, cancellationToken);

        if (isFollowing)
        {
            _ = notificationsService.CreateAsync(
                targetUserId,
                NotificationType.System,
                me.DisplayName,
                "seni takip etmeye başladı.",
                actorUserId: userId,
                deepLink: $"/users/{userId}",
                relatedEntityType: "Follow",
                relatedEntityId: userId,
                cancellationToken: cancellationToken
            );
        }

        return new FollowStateDto(targetUserId, isFollowing, target.FollowersCount, me.FollowingCount);
    }

    public async Task BlockUserAsync(
        string userId,
        string targetUserId,
        CancellationToken cancellationToken = default
    )
    {
        if (string.IsNullOrWhiteSpace(userId) || string.IsNullOrWhiteSpace(targetUserId) || userId == targetUserId)
        {
            return;
        }

        await EnsureUsersExistAsync(userId, targetUserId, cancellationToken);

        var existing = await dbContext.BlockedUsers
            .FirstOrDefaultAsync(
                entry => entry.UserId == userId && entry.BlockedUserId == targetUserId,
                cancellationToken
            );

        if (existing is null)
        {
            dbContext.BlockedUsers.Add(
                new BlockedUser
                {
                    UserId = userId,
                    BlockedUserId = targetUserId,
                    CreatedAt = DateTimeOffset.UtcNow,
                }
            );
        }

        var followRelations = await dbContext.Follows
            .Where(entry =>
                (entry.FollowerUserId == userId && entry.FollowingUserId == targetUserId)
                || (entry.FollowerUserId == targetUserId && entry.FollowingUserId == userId)
            )
            .ToListAsync(cancellationToken);

        var friendships = await dbContext.Friendships
            .Where(entry =>
                (entry.UserAId == userId && entry.UserBId == targetUserId)
                || (entry.UserAId == targetUserId && entry.UserBId == userId)
            )
            .ToListAsync(cancellationToken);

        var pendingRequests = await dbContext.FriendRequests
            .Where(entry =>
                (
                    entry.FromUserId == userId
                    && entry.ToUserId == targetUserId
                    && entry.Status == FriendRequestStatus.Pending
                )
                || (
                    entry.FromUserId == targetUserId
                    && entry.ToUserId == userId
                    && entry.Status == FriendRequestStatus.Pending
                )
            )
            .ToListAsync(cancellationToken);

        if (followRelations.Count > 0)
        {
            dbContext.Follows.RemoveRange(followRelations);
        }

        if (friendships.Count > 0)
        {
            dbContext.Friendships.RemoveRange(friendships);
        }

        foreach (var request in pendingRequests)
        {
            request.Status = FriendRequestStatus.Cancelled;
            request.RespondedAt = DateTimeOffset.UtcNow;
        }

        var sharedChatIds = await dbContext.ChatParticipants
            .Where(entry => entry.UserId == userId || entry.UserId == targetUserId)
            .GroupBy(entry => entry.ChatId)
            .Where(group =>
                group.Any(entry => entry.UserId == userId)
                && group.Any(entry => entry.UserId == targetUserId))
            .Select(group => group.Key)
            .ToListAsync(cancellationToken);

        if (sharedChatIds.Count > 0)
        {
            var chats = await dbContext.Chats.Where(entry => sharedChatIds.Contains(entry.Id)).ToListAsync(cancellationToken);
            dbContext.Chats.RemoveRange(chats);
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        await RefreshRelationshipCountersAsync([userId, targetUserId], cancellationToken);
        await realtimeNotifier.NotifyFriendRequestsChangedAsync(
            [userId, targetUserId],
            cancellationToken
        );
        await realtimeNotifier.NotifyRelationshipChangedAsync(
            [userId, targetUserId],
            cancellationToken
        );
        await realtimeNotifier.NotifyProfileChangedAsync(userId, cancellationToken);
        await realtimeNotifier.NotifyProfileChangedAsync(targetUserId, cancellationToken);
        foreach (var chatId in sharedChatIds)
        {
            await realtimeNotifier.NotifyChatUpdatedAsync(
                chatId,
                [userId, targetUserId],
                cancellationToken: cancellationToken
            );
        }
    }

    public async Task ReportUserAsync(
        string userId,
        ReportUserRequest request,
        CancellationToken cancellationToken = default
    )
    {
        if (string.IsNullOrWhiteSpace(request.TargetUserId) || request.TargetUserId == userId)
        {
            return;
        }

        await EnsureUsersExistAsync(userId, request.TargetUserId, cancellationToken);

        dbContext.UserReports.Add(
            new UserReport
            {
                ReporterUserId = userId,
                TargetUserId = request.TargetUserId,
                Reason = request.Reason.Trim(),
                Details = request.Details.Trim(),
                CreatedAt = DateTimeOffset.UtcNow,
            }
        );

        await dbContext.SaveChangesAsync(cancellationToken);
    }

    public async Task<bool> UnblockUserAsync(
        string userId,
        string targetUserId,
        CancellationToken cancellationToken = default
    )
    {
        var block = await dbContext.BlockedUsers
            .FirstOrDefaultAsync(
                entry => entry.UserId == userId && entry.BlockedUserId == targetUserId,
                cancellationToken
            );

        if (block is null)
        {
            return false;
        }

        dbContext.BlockedUsers.Remove(block);
        await dbContext.SaveChangesAsync(cancellationToken);
        await realtimeNotifier.NotifyRelationshipChangedAsync(
            [userId, targetUserId],
            cancellationToken
        );
        await realtimeNotifier.NotifyProfileChangedAsync(userId, cancellationToken);
        await realtimeNotifier.NotifyProfileChangedAsync(targetUserId, cancellationToken);
        return true;
    }

    public async Task<IReadOnlyList<BlockedUserDto>> GetBlockedUsersAsync(
        string userId,
        CancellationToken cancellationToken = default
    )
    {
        var blocks = await dbContext.BlockedUsers.AsNoTracking()
            .Where(entry => entry.UserId == userId)
            .OrderByDescending(entry => entry.CreatedAt)
            .ToListAsync(cancellationToken);

        if (blocks.Count == 0)
        {
            return [];
        }

        var blockedUserIds = blocks.Select(entry => entry.BlockedUserId).ToList();
        var users = await dbContext.Users.AsNoTracking()
            .Where(entry => blockedUserIds.Contains(entry.Id))
            .ToDictionaryAsync(entry => entry.Id, cancellationToken);

        return blocks
            .Where(entry => users.ContainsKey(entry.BlockedUserId))
            .Select(entry =>
            {
                var user = users[entry.BlockedUserId];
                return new BlockedUserDto(
                    user.Id,
                    user.DisplayName ?? user.UserName,
                    user.ProfilePhotoUrl ?? string.Empty,
                    entry.CreatedAt
                );
            })
            .ToList();
    }

    private async Task EnsureUsersExistAsync(
        string userId,
        string targetUserId,
        CancellationToken cancellationToken
    )
    {
        var knownUsers = await dbContext.Users.AsNoTracking()
            .Where(entry => entry.Id == userId || entry.Id == targetUserId)
            .Select(entry => entry.Id)
            .ToListAsync(cancellationToken);

        if (!knownUsers.Contains(userId) || !knownUsers.Contains(targetUserId))
        {
            throw new KeyNotFoundException("One or more users were not found.");
        }
    }

    private async Task EnsureNotBlockedAsync(
        string userId,
        string targetUserId,
        CancellationToken cancellationToken
    )
    {
        var isBlocked = await dbContext.BlockedUsers.AsNoTracking().AnyAsync(
            entry =>
                (entry.UserId == userId && entry.BlockedUserId == targetUserId)
                || (entry.UserId == targetUserId && entry.BlockedUserId == userId),
            cancellationToken
        );

        if (isBlocked)
        {
            throw new InvalidOperationException("The requested social action is blocked.");
        }
    }

    private Task<bool> AreFriendsAsync(
        string userId,
        string targetUserId,
        CancellationToken cancellationToken
    )
    {
        var (userAId, userBId) = OrderUsers(userId, targetUserId);
        return dbContext.Friendships.AsNoTracking().AnyAsync(
            entry => entry.UserAId == userAId && entry.UserBId == userBId,
            cancellationToken
        );
    }

    private async Task AcceptFriendRequestInternalAsync(
        FriendRequest request,
        string respondingUserId,
        CancellationToken cancellationToken
    )
    {
        if (request.ToUserId != respondingUserId)
        {
            throw new InvalidOperationException("Only the receiving user can accept a friend request.");
        }

        var (userAId, userBId) = OrderUsers(request.FromUserId, request.ToUserId);
        var existingFriendship = await dbContext.Friendships
            .FirstOrDefaultAsync(
                entry => entry.UserAId == userAId && entry.UserBId == userBId,
                cancellationToken
            );

        if (existingFriendship is null)
        {
            dbContext.Friendships.Add(
                new Friendship
                {
                    UserAId = userAId,
                    UserBId = userBId,
                    CreatedAt = DateTimeOffset.UtcNow,
                }
            );
        }

        request.Status = FriendRequestStatus.Accepted;
        request.RespondedAt = DateTimeOffset.UtcNow;

        await dbContext.SaveChangesAsync(cancellationToken);
        await RefreshRelationshipCountersAsync([request.FromUserId, request.ToUserId], cancellationToken);
    }

    private async Task RefreshRelationshipCountersAsync(
        IEnumerable<string> userIds,
        CancellationToken cancellationToken
    )
    {
        var distinctIds = userIds.Where(id => !string.IsNullOrWhiteSpace(id)).Distinct().ToList();
        if (distinctIds.Count == 0)
        {
            return;
        }

        var users = await dbContext.Users.Where(entry => distinctIds.Contains(entry.Id)).ToListAsync(cancellationToken);
        var followerCounts = await dbContext.Follows.AsNoTracking()
            .Where(entry => distinctIds.Contains(entry.FollowingUserId))
            .GroupBy(entry => entry.FollowingUserId)
            .Select(group => new { UserId = group.Key, Count = group.Count() })
            .ToDictionaryAsync(entry => entry.UserId, entry => entry.Count, cancellationToken);
        var followingCounts = await dbContext.Follows.AsNoTracking()
            .Where(entry => distinctIds.Contains(entry.FollowerUserId))
            .GroupBy(entry => entry.FollowerUserId)
            .Select(group => new { UserId = group.Key, Count = group.Count() })
            .ToDictionaryAsync(entry => entry.UserId, entry => entry.Count, cancellationToken);
        var friendCounts = await dbContext.Friendships.AsNoTracking()
            .Where(entry => distinctIds.Contains(entry.UserAId) || distinctIds.Contains(entry.UserBId))
            .SelectMany(entry => new[]
            {
                new { UserId = entry.UserAId },
                new { UserId = entry.UserBId },
            })
            .Where(entry => distinctIds.Contains(entry.UserId))
            .GroupBy(entry => entry.UserId)
            .Select(group => new { UserId = group.Key, Count = group.Count() })
            .ToDictionaryAsync(entry => entry.UserId, entry => entry.Count, cancellationToken);

        foreach (var user in users)
        {
            user.FollowersCount = followerCounts.GetValueOrDefault(user.Id);
            user.FollowingCount = followingCounts.GetValueOrDefault(user.Id);
            user.FriendsCount = friendCounts.GetValueOrDefault(user.Id);
            user.UpdatedAt = DateTimeOffset.UtcNow;
        }

        await dbContext.SaveChangesAsync(cancellationToken);
    }

    private async Task<IReadOnlyList<FriendRequestDto>> BuildFriendRequestDtosAsync(
        IReadOnlyList<FriendRequest> requests,
        CancellationToken cancellationToken
    )
    {
        var userIds = requests
            .SelectMany(entry => new[] { entry.FromUserId, entry.ToUserId })
            .Distinct()
            .ToList();

        var users = await dbContext.Users.AsNoTracking()
            .Where(entry => userIds.Contains(entry.Id))
            .ToDictionaryAsync(entry => entry.Id, cancellationToken);

        return requests
            .Where(entry => users.ContainsKey(entry.FromUserId) && users.ContainsKey(entry.ToUserId))
            .Select(entry => new FriendRequestDto(
                entry.Id,
                entry.Status.ToString().ToLowerInvariant(),
                entry.CreatedAt,
                users[entry.FromUserId].ToSummaryDto(),
                users[entry.ToUserId].ToSummaryDto()
            ))
            .ToList();
    }

    private Task<HashSet<string>> GetBlockedUserIdsAsync(
        string userId,
        CancellationToken cancellationToken
    ) => BlockedUsersHelper.GetBlockedUserIdsAsync(dbContext, userId, cancellationToken);

    private static (string UserAId, string UserBId) OrderUsers(string first, string second) =>
        string.CompareOrdinal(first, second) <= 0 ? (first, second) : (second, first);
}
