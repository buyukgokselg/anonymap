using Microsoft.EntityFrameworkCore;
using PulseCity.Application.DTOs;
using PulseCity.Application.Interfaces;
using PulseCity.Domain.Entities;
using PulseCity.Domain.Enums;
using PulseCity.Infrastructure.Data;
using PulseCity.Infrastructure.Internal;

namespace PulseCity.Infrastructure.Services;

public sealed class MatchesService(
    PulseCityDbContext dbContext,
    IRealtimeNotifier realtimeNotifier,
    IChatsService chatsService,
    INotificationsService notificationsService
) : IMatchesService
{
    private async Task<Guid> EnsureDirectChatAsync(
        string userId,
        string otherUserId,
        CancellationToken cancellationToken
    )
    {
        var chat = await chatsService.CreateOrGetDirectChatAsync(
            userId,
            new CreateDirectChatRequest { OtherUserId = otherUserId, IsTemporary = false },
            cancellationToken
        );
        return chat.Id;
    }

    public async Task<MatchDto> CreateAsync(
        string userId,
        CreateMatchRequest request,
        CancellationToken cancellationToken = default
    )
    {
        var otherUserId = request.OtherUserId.Trim();
        if (string.IsNullOrWhiteSpace(otherUserId) || otherUserId == userId)
        {
            throw new InvalidOperationException("Invalid match target.");
        }

        var users = await LoadUsersAsync(userId, otherUserId, cancellationToken);
        await EnsureUsersNotBlockedAsync(userId, otherUserId, cancellationToken);
        EnsureUsersCanMatch(users[userId], users[otherUserId]);

        // Server-authoritative compatibility & common-interest computation.
        // Client-sent values are ignored to prevent tampering and inconsistency.
        var serverCommonInterests = IntersectInterests(
            users[userId].Interests,
            users[otherUserId].Interests
        );
        var serverCompatibility = ComputeCompatibility(
            users[userId],
            users[otherUserId],
            serverCommonInterests
        );

        var existingAccepted = await dbContext.Matches.AsNoTracking()
            .Where(entry =>
                ((entry.UserId1 == userId && entry.UserId2 == otherUserId)
                || (entry.UserId1 == otherUserId && entry.UserId2 == userId))
                && entry.Status == MatchStatus.Accepted)
            .OrderByDescending(entry => entry.RespondedAt ?? entry.CreatedAt)
            .FirstOrDefaultAsync(cancellationToken);
        if (existingAccepted is not null)
        {
            return (await BuildMatchDtosAsync([existingAccepted], userId, cancellationToken)).Single();
        }

        var participantIds = new[] { userId, otherUserId };
        await using var transaction = await BeginOptionalTransactionAsync(cancellationToken);

        var inversePending = await dbContext.Matches
            .FirstOrDefaultAsync(
                entry =>
                    entry.UserId1 == otherUserId
                    && entry.UserId2 == userId
                    && entry.Status == MatchStatus.Pending,
                cancellationToken
            );
        if (inversePending is not null)
        {
            inversePending.Status = MatchStatus.Accepted;
            inversePending.RespondedAt = DateTimeOffset.UtcNow;
            inversePending.Compatibility = serverCompatibility;
            inversePending.CommonInterests = serverCommonInterests.ToList();
            await dbContext.SaveChangesAsync(cancellationToken);

            // Both users have now swiped right on each other — spin up (or reuse)
            // a direct chat thread so the pair can message immediately.
            var chatId = await EnsureDirectChatAsync(userId, otherUserId, cancellationToken);
            inversePending.ChatId = chatId;
            await dbContext.SaveChangesAsync(cancellationToken);

            if (transaction is not null)
            {
                await transaction.CommitAsync(cancellationToken);
            }
            await realtimeNotifier.NotifyMatchesChangedAsync(participantIds, cancellationToken);
            return (await BuildMatchDtosAsync([inversePending], userId, cancellationToken)).Single();
        }

        var existingPending = await dbContext.Matches.AsNoTracking()
            .Where(entry =>
                entry.UserId1 == userId
                && entry.UserId2 == otherUserId
                && entry.Status == MatchStatus.Pending)
            .OrderByDescending(entry => entry.CreatedAt)
            .FirstOrDefaultAsync(cancellationToken);
        if (existingPending is not null)
        {
            return (await BuildMatchDtosAsync([existingPending], userId, cancellationToken)).Single();
        }

        var match = new UserMatch
        {
            UserId1 = userId,
            UserId2 = otherUserId,
            Compatibility = serverCompatibility,
            CommonInterests = serverCommonInterests.ToList(),
            Status = MatchStatus.Pending,
            CreatedAt = DateTimeOffset.UtcNow,
            Initiator1AnonymousInChat = request.AnonymousInChat,
        };

        dbContext.Matches.Add(match);
        await dbContext.SaveChangesAsync(cancellationToken);
        if (transaction is not null)
        {
            await transaction.CommitAsync(cancellationToken);
        }
        await realtimeNotifier.NotifyMatchesChangedAsync(participantIds, cancellationToken);
        var requestingUser = await dbContext.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == userId, cancellationToken);
        var requesterName = requestingUser?.DisplayName ?? "Birisi";
        _ = notificationsService.CreateAsync(
            otherUserId,
            NotificationType.MatchCreated,
            requesterName,
            "seninle eşleşmek istiyor! 💫",
            actorUserId: userId,
            deepLink: "/matches/incoming",
            relatedEntityType: "Match",
            relatedEntityId: match.Id.ToString(),
            cancellationToken: cancellationToken
        );

        return (await BuildMatchDtosAsync([match], userId, cancellationToken)).Single();
    }

    public async Task<bool> RespondAsync(
        Guid matchId,
        string userId,
        RespondToMatchRequest request,
        CancellationToken cancellationToken = default
    )
    {
        var match = await dbContext.Matches
            .FirstOrDefaultAsync(
                entry =>
                    entry.Id == matchId
                    && entry.UserId2 == userId
                    && entry.Status == MatchStatus.Pending,
                cancellationToken
            );

        if (match is null)
        {
            return false;
        }

        var participantIds = new[] { match.UserId1, match.UserId2 };
        await using var transaction = await BeginOptionalTransactionAsync(cancellationToken);
        match.Status = ParseStatus(request.Status);
        match.RespondedAt = DateTimeOffset.UtcNow;
        match.Responder2AnonymousInChat = request.AnonymousInChat;

        if (match.Status == MatchStatus.Accepted)
        {
            // ChatId is server-authoritative; the client's requested ChatId is
            // ignored so match + chat stay in sync.
            await dbContext.SaveChangesAsync(cancellationToken);
            var chatId = await EnsureDirectChatAsync(userId, match.UserId1, cancellationToken);
            match.ChatId = chatId;
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        if (transaction is not null)
        {
            await transaction.CommitAsync(cancellationToken);
        }
        await realtimeNotifier.NotifyMatchesChangedAsync(participantIds, cancellationToken);
        if (match.Status == MatchStatus.Accepted)
        {
            var responder = await dbContext.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == userId, cancellationToken);
            var responderName = responder?.DisplayName ?? "Birisi";
            _ = notificationsService.CreateAsync(
                match.UserId1,
                NotificationType.MatchCreated,
                responderName,
                "eşleşmeyi kabul etti! 🎉",
                actorUserId: userId,
                deepLink: match.ChatId is { } cid ? $"/chats/{cid}" : "/matches",
                relatedEntityType: "Match",
                relatedEntityId: match.Id.ToString(),
                cancellationToken: cancellationToken
            );
        }
        return true;
    }

    public async Task<IReadOnlyList<MatchDto>> GetPendingIncomingAsync(
        string userId,
        CancellationToken cancellationToken = default
    )
    {
        var matches = await dbContext.Matches.AsNoTracking()
            .Where(entry => entry.UserId2 == userId && entry.Status == MatchStatus.Pending)
            .OrderByDescending(entry => entry.CreatedAt)
            .ToListAsync(cancellationToken);

        return await BuildMatchDtosAsync(matches, userId, cancellationToken);
    }

    public async Task<IReadOnlyList<MatchDto>> GetAllMatchesAsync(
        string userId,
        CancellationToken cancellationToken = default
    )
    {
        var matches = await dbContext.Matches.AsNoTracking()
            .Where(entry => entry.UserId1 == userId || entry.UserId2 == userId)
            .OrderByDescending(entry => entry.CreatedAt)
            .ToListAsync(cancellationToken);

        return await BuildMatchDtosAsync(matches, userId, cancellationToken);
    }

    public async Task<LikesMeResponseDto> GetLikesMeAsync(
        string userId,
        LikesMeQuery query,
        CancellationToken cancellationToken = default
    )
    {
        var limit = Math.Clamp(query.Limit, 1, 50);

        // Subquery — mutual-block filter translated to SQL NOT EXISTS by EF Core,
        // so we don't round-trip the block list.
        var blockedSubquery = dbContext.BlockedUsers.AsNoTracking()
            .Where(entry => entry.UserId == userId || entry.BlockedUserId == userId)
            .Select(entry => entry.UserId == userId ? entry.BlockedUserId : entry.UserId);

        var baseQuery = dbContext.Matches.AsNoTracking()
            .Where(entry =>
                entry.UserId2 == userId
                && entry.Status == MatchStatus.Pending
                && !blockedSubquery.Contains(entry.UserId1));

        // Single round-trip for the count + page. Using Take(limit + 1) lets us
        // know whether there are more rows without a second COUNT query being
        // the critical path for the HasMore flag (still keeping TotalCount for
        // the inbox badge).
        var totalCount = await baseQuery.CountAsync(cancellationToken);

        var pendingRows = await baseQuery
            .OrderByDescending(entry => entry.CreatedAt)
            .Take(limit)
            .Select(entry => new
            {
                entry.Id,
                entry.UserId1,
                entry.Compatibility,
                entry.CommonInterests,
                entry.CreatedAt,
                entry.Initiator1AnonymousInChat,
            })
            .ToListAsync(cancellationToken);

        if (pendingRows.Count == 0)
        {
            return new LikesMeResponseDto(totalCount, HasMore: false, Items: []);
        }

        var likerIds = pendingRows.Select(row => row.UserId1).Distinct().ToList();
        var likers = await dbContext.Users.AsNoTracking()
            .Where(entry => likerIds.Contains(entry.Id))
            .ToDictionaryAsync(entry => entry.Id, cancellationToken);

        var items = pendingRows
            .Where(row => likers.ContainsKey(row.UserId1))
            .Select(row => new LikesMeEntryDto(
                row.Id,
                likers[row.UserId1].ToSummaryDto(),
                row.Compatibility,
                row.CommonInterests,
                row.CreatedAt,
                row.Initiator1AnonymousInChat
            ))
            .ToList();

        return new LikesMeResponseDto(
            TotalCount: totalCount,
            HasMore: totalCount > items.Count,
            Items: items
        );
    }

    private async Task<Dictionary<string, UserProfile>> LoadUsersAsync(
        string userId,
        string otherUserId,
        CancellationToken cancellationToken
    )
    {
        var knownUsers = await dbContext.Users.AsNoTracking()
            .Where(entry => entry.Id == userId || entry.Id == otherUserId)
            .ToDictionaryAsync(entry => entry.Id, cancellationToken);

        if (!knownUsers.ContainsKey(userId) || !knownUsers.ContainsKey(otherUserId))
        {
            throw new KeyNotFoundException("One or more users were not found.");
        }

        return knownUsers;
    }

    private async Task<IReadOnlyList<MatchDto>> BuildMatchDtosAsync(
        IReadOnlyList<UserMatch> matches,
        string? requesterUserId,
        CancellationToken cancellationToken
    )
    {
        if (matches.Count == 0)
        {
            return [];
        }

        var blockedUserIds = await GetBlockedUserIdsAsync(requesterUserId, cancellationToken);
        var userIds = matches
            .SelectMany(entry => new[] { entry.UserId1, entry.UserId2 })
            .Distinct()
            .ToList();

        var users = await dbContext.Users.AsNoTracking()
            .Where(entry => userIds.Contains(entry.Id))
            .ToDictionaryAsync(entry => entry.Id, cancellationToken);

        return matches
            .Where(entry =>
                users.ContainsKey(entry.UserId1)
                && users.ContainsKey(entry.UserId2)
                && !blockedUserIds.Contains(entry.UserId1)
                && !blockedUserIds.Contains(entry.UserId2))
            .Select(entry => new MatchDto(
                entry.Id,
                entry.Status.ToString().ToLowerInvariant(),
                entry.Compatibility,
                entry.CommonInterests,
                entry.CreatedAt,
                entry.RespondedAt,
                entry.ChatId,
                users[entry.UserId1].ToSummaryDto(),
                users[entry.UserId2].ToSummaryDto(),
                entry.Initiator1AnonymousInChat,
                entry.Responder2AnonymousInChat
            ))
            .ToList();
    }

    private async Task EnsureUsersNotBlockedAsync(
        string userId,
        string otherUserId,
        CancellationToken cancellationToken
    )
    {
        var isBlocked = await dbContext.BlockedUsers.AsNoTracking().AnyAsync(
            entry =>
                (entry.UserId == userId && entry.BlockedUserId == otherUserId)
                || (entry.UserId == otherUserId && entry.BlockedUserId == userId),
            cancellationToken
        );

        if (isBlocked)
        {
            throw new InvalidOperationException("This match request is blocked.");
        }
    }

    private Task<HashSet<string>> GetBlockedUserIdsAsync(
        string? requesterUserId,
        CancellationToken cancellationToken
    ) => BlockedUsersHelper.GetBlockedUserIdsAsync(dbContext, requesterUserId, cancellationToken);

    private static MatchStatus ParseStatus(string? value) =>
        value?.Trim().ToLowerInvariant() switch
        {
            "accepted" => MatchStatus.Accepted,
            "declined" => MatchStatus.Declined,
            "expired" => MatchStatus.Expired,
            _ => MatchStatus.Pending,
        };

    private static void EnsureUsersCanMatch(UserProfile currentUser, UserProfile otherUser)
    {
        var currentGender = NormalizeGender(currentUser.Gender);
        var otherGender = NormalizeGender(otherUser.Gender);
        var currentPreference = NormalizeMatchPreference(currentUser.MatchPreference, currentGender);
        var otherPreference = NormalizeMatchPreference(otherUser.MatchPreference, otherGender);

        if (!AllowsGender(currentPreference, otherGender) || !AllowsGender(otherPreference, currentGender))
        {
            throw new InvalidOperationException("These users are not compatible for matching.");
        }
    }

    /// <summary>
    /// Deterministic, server-authoritative compatibility score in [1,99].
    /// Mirrors the client-side formula in signal_screen.dart::_calculateCompatibility
    /// so the number the user saw on-screen stays consistent after persistence.
    /// </summary>
    private static int ComputeCompatibility(
        UserProfile me,
        UserProfile other,
        IReadOnlyCollection<string> sharedInterests
    )
    {
        var score = 36 + (sharedInterests.Count * 13);

        if (!string.IsNullOrWhiteSpace(me.Mode)
            && string.Equals(me.Mode, other.Mode, StringComparison.OrdinalIgnoreCase))
        {
            score += 14;
        }

        if (!string.IsNullOrWhiteSpace(me.City)
            && string.Equals(me.City, other.City, StringComparison.OrdinalIgnoreCase))
        {
            score += 6;
        }

        if (!string.IsNullOrWhiteSpace(me.Purpose)
            && string.Equals(me.Purpose, other.Purpose, StringComparison.OrdinalIgnoreCase))
        {
            score += 8;
        }

        var pulseGap = Math.Abs(me.PulseScore - other.PulseScore);
        score += Math.Clamp(14 - (int)Math.Round(pulseGap / 10.0), 0, 14);

        var distanceMeters = ApproximateDistanceMeters(me, other);
        if (distanceMeters is double dist)
        {
            if (dist <= 150) score += 10;
            else if (dist <= 300) score += 7;
            else if (dist <= 500) score += 4;
        }

        return Math.Clamp(score, 1, 99);
    }

    private static IReadOnlyList<string> IntersectInterests(
        IEnumerable<string> a,
        IEnumerable<string> b
    ) => a
        .Where(entry => !string.IsNullOrWhiteSpace(entry))
        .Select(entry => entry.Trim())
        .Intersect(
            b.Where(entry => !string.IsNullOrWhiteSpace(entry)).Select(entry => entry.Trim()),
            StringComparer.OrdinalIgnoreCase
        )
        .Take(10)
        .ToList();

    private static double? ApproximateDistanceMeters(UserProfile a, UserProfile b)
    {
        if (a.Latitude is not double lat1 || a.Longitude is not double lon1
            || b.Latitude is not double lat2 || b.Longitude is not double lon2)
        {
            return null;
        }

        // Haversine
        const double earthRadiusMeters = 6371000.0;
        var dLat = (lat2 - lat1) * Math.PI / 180.0;
        var dLon = (lon2 - lon1) * Math.PI / 180.0;
        var lat1Rad = lat1 * Math.PI / 180.0;
        var lat2Rad = lat2 * Math.PI / 180.0;
        var h = Math.Sin(dLat / 2) * Math.Sin(dLat / 2)
              + Math.Cos(lat1Rad) * Math.Cos(lat2Rad)
              * Math.Sin(dLon / 2) * Math.Sin(dLon / 2);
        var c = 2 * Math.Atan2(Math.Sqrt(h), Math.Sqrt(1 - h));
        return earthRadiusMeters * c;
    }

    private static string NormalizeGender(string? value) =>
        SharedHelpers.NormalizeGender(value);

    private static string NormalizeMatchPreference(string? value, string gender) =>
        SharedHelpers.NormalizeMatchPreference(value, gender);

    private static bool AllowsGender(string preference, string targetGender)
    {
        if (string.IsNullOrWhiteSpace(targetGender))
        {
            return preference == "everyone";
        }

        return preference switch
        {
            "women" => targetGender == "female",
            "men" => targetGender == "male",
            _ => true,
        };
    }

    private async Task<Microsoft.EntityFrameworkCore.Storage.IDbContextTransaction?> BeginOptionalTransactionAsync(
        CancellationToken cancellationToken
    )
    {
        if (!dbContext.Database.IsRelational())
        {
            return null;
        }

        return await dbContext.Database.BeginTransactionAsync(cancellationToken);
    }
}
