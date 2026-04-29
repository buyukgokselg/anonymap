using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;
using PulseCity.Application.Auth;
using PulseCity.Application.DTOs;
using PulseCity.Application.Interfaces;
using PulseCity.Domain.Entities;
using PulseCity.Domain.Enums;
using PulseCity.Infrastructure.Data;
using PulseCity.Infrastructure.Internal;
using PulseCity.Infrastructure.Options;
using System.Security.Cryptography;
using System.Text.Json;

namespace PulseCity.Infrastructure.Services;

public sealed class UsersService(
    PulseCityDbContext dbContext,
    IHostEnvironment hostEnvironment,
    IOptions<StorageOptions> storageOptions,
    IOptions<PrivacyOptions> privacyOptions,
    IOptions<JwtOptions> jwtOptions,
    IRealtimeNotifier realtimeNotifier,
    INotificationsService notificationsService,
    IBadgesService badgesService
) : IUsersService
{
    private static readonly TimeSpan ExportDownloadTokenLifetime = TimeSpan.FromMinutes(15);

    public async Task<UserProfileDto> GetOrCreateCurrentUserAsync(
        AuthenticatedUser authenticatedUser,
        CancellationToken cancellationToken = default
    )
    {
        var user = await dbContext.Users.FirstOrDefaultAsync(
            entry => entry.Id == authenticatedUser.UserId,
            cancellationToken
        );

        if (user is null)
        {
            user = new UserProfile
            {
                Id = authenticatedUser.UserId,
                Email = authenticatedUser.Email,
                UserName = TextNormalizer.BuildUserName(authenticatedUser.Email, authenticatedUser.UserId),
                DisplayName =
                    string.IsNullOrWhiteSpace(authenticatedUser.DisplayName)
                        ? TextNormalizer.BuildUserName(authenticatedUser.Email, authenticatedUser.UserId)
                        : authenticatedUser.DisplayName.Trim(),
                ProfilePhotoUrl = authenticatedUser.PhotoUrl ?? string.Empty,
                PreferredLanguage = "tr",
                LocationGranularity = "nearby",
                EnableDifferentialPrivacy = true,
                KAnonymityLevel = Math.Max(privacyOptions.Value.DefaultKAnonymityLevel, 3),
                AllowAnalytics = true,
                MatchPreference = "everyone",
                CreatedAt = DateTimeOffset.UtcNow,
                UpdatedAt = DateTimeOffset.UtcNow,
                LastSeenAt = DateTimeOffset.UtcNow,
                IsOnline = true,
            };

            user.NormalizedUserName = TextNormalizer.Normalize(user.UserName);
            user.NormalizedDisplayName = TextNormalizer.Normalize(user.DisplayName);
            user.NormalizedCity = TextNormalizer.Normalize(user.City);

            dbContext.Users.Add(user);
            await dbContext.SaveChangesAsync(cancellationToken);

            // İlk N kullanıcıya Pioneer rozeti — kayıt anında hesaplanır.
            await badgesService.RecomputeAsync(user.Id, cancellationToken);
        }
        else
        {
            user.Email = string.IsNullOrWhiteSpace(user.Email) ? authenticatedUser.Email : user.Email;
            if (
                string.IsNullOrWhiteSpace(user.DisplayName)
                && !string.IsNullOrWhiteSpace(authenticatedUser.DisplayName)
            )
            {
                user.DisplayName = authenticatedUser.DisplayName.Trim();
                user.NormalizedDisplayName = TextNormalizer.Normalize(user.DisplayName);
            }

            if (
                string.IsNullOrWhiteSpace(user.ProfilePhotoUrl)
                && !string.IsNullOrWhiteSpace(authenticatedUser.PhotoUrl)
            )
            {
                user.ProfilePhotoUrl = authenticatedUser.PhotoUrl.Trim();
            }

            user.IsOnline = true;
            user.LastSeenAt = DateTimeOffset.UtcNow;
            user.UpdatedAt = DateTimeOffset.UtcNow;

            await dbContext.SaveChangesAsync(cancellationToken);
        }

        return user.ToProfileDto();
    }

    public async Task<UserProfileDto> UpdateCurrentUserAsync(
        string userId,
        UpdateUserProfileRequest request,
        CancellationToken cancellationToken = default
    )
    {
        var user = await dbContext.Users.FirstOrDefaultAsync(entry => entry.Id == userId, cancellationToken)
            ?? throw new KeyNotFoundException("User was not found.");

        var requestedUserName = string.IsNullOrWhiteSpace(request.UserName)
            ? user.UserName
            : request.UserName;
        var sanitizedUserName = TextNormalizer.SanitizeUserName(requestedUserName, user.Id);
        if (sanitizedUserName.Length < 3)
        {
            throw new InvalidOperationException("Username must be at least 3 characters.");
        }

        var normalizedUserName = TextNormalizer.Normalize(sanitizedUserName);
        var userNameChanged = !string.Equals(
            user.NormalizedUserName,
            normalizedUserName,
            StringComparison.Ordinal
        );
        if (userNameChanged)
        {
            var userNameInUse = await dbContext.Users.AnyAsync(
                entry => entry.Id != userId && entry.NormalizedUserName == normalizedUserName,
                cancellationToken
            );
            if (userNameInUse)
            {
                throw new InvalidOperationException("This username is already in use.");
            }
        }

        user.UserName = sanitizedUserName;
        user.NormalizedUserName = normalizedUserName;
        user.FirstName = request.FirstName.Trim();
        user.LastName = request.LastName.Trim();
        user.DisplayName = request.DisplayName.Trim();
        user.Bio = request.Bio.Trim();
        user.City = request.City.Trim();
        user.Website = request.Website.Trim();
        user.Gender = NormalizeGender(request.Gender);
        user.BirthDate = request.BirthDate?.Date;
        user.Age = request.BirthDate.HasValue
            ? CalculateAge(request.BirthDate.Value.Date)
            : request.Age;
        user.Purpose = request.Purpose.Trim();
        user.MatchPreference = NormalizeMatchPreference(request.MatchPreference, user.Gender);
        user.Mode = NormalizeMode(request.Mode);
        user.PrivacyLevel = request.PrivacyLevel.Trim();
        user.PreferredLanguage = NormalizeLanguage(request.PreferredLanguage);
        user.LocationGranularity = NormalizeGranularity(request.LocationGranularity);
        user.EnableDifferentialPrivacy = request.EnableDifferentialPrivacy;
        user.KAnonymityLevel = Math.Clamp(
            request.KAnonymityLevel,
            2,
            10
        );
        user.AllowAnalytics = request.AllowAnalytics;
        user.IsVisible = request.IsVisible;
        user.ProfilePhotoUrl = request.ProfilePhotoUrl.Trim();
        user.PhotoUrls = request.PhotoUrls.Where(item => !string.IsNullOrWhiteSpace(item)).Distinct().Take(8).ToList();
        user.Interests = request.Interests.Where(item => !string.IsNullOrWhiteSpace(item)).Distinct().Take(24).ToList();
        user.Latitude = request.Latitude;
        user.Longitude = request.Longitude;
        user.LastSeenAt = DateTimeOffset.UtcNow;
        user.UpdatedAt = DateTimeOffset.UtcNow;
        user.NormalizedDisplayName = TextNormalizer.Normalize(user.DisplayName);
        user.NormalizedCity = TextNormalizer.Normalize(user.City);

        // ── Dating-context fields ──
        user.Orientation = NormalizeOrientation(request.Orientation);
        user.RelationshipIntent = NormalizeIntent(request.RelationshipIntent);
        user.HeightCm = request.HeightCm;
        user.DrinkingStatus = NormalizeFrequency(request.DrinkingStatus);
        user.SmokingStatus = NormalizeFrequency(request.SmokingStatus);
        user.DatingPrompts = request.DatingPrompts
            .Where(pair => !string.IsNullOrWhiteSpace(pair.Key) && !string.IsNullOrWhiteSpace(pair.Value))
            .Take(8)
            .ToDictionary(
                pair => pair.Key.Trim(),
                pair => pair.Value.Trim().Length > 240 ? pair.Value.Trim()[..240] : pair.Value.Trim()
            );
        user.LookingForModes = request.LookingForModes
            .Select(NormalizeMode)
            .Where(item => !string.IsNullOrWhiteSpace(item))
            .Distinct()
            .Take(4)
            .ToList();
        user.Dealbreakers = request.Dealbreakers
            .Where(item => !string.IsNullOrWhiteSpace(item))
            .Select(item => item.Trim().ToLowerInvariant())
            .Distinct()
            .Take(12)
            .ToList();

        await dbContext.SaveChangesAsync(cancellationToken);
        await realtimeNotifier.NotifyProfileChangedAsync(userId, cancellationToken);
        return user.ToProfileDto();
    }

    public async Task<PublicUserProfileDto?> GetUserByIdAsync(
        string userId,
        string? requesterUserId,
        CancellationToken cancellationToken = default
    )
    {
        if (!string.IsNullOrWhiteSpace(requesterUserId)
            && await AreUsersBlockedAsync(requesterUserId, userId, cancellationToken))
        {
            return null;
        }

        var user = await dbContext.Users.AsNoTracking()
            .FirstOrDefaultAsync(entry => entry.Id == userId, cancellationToken);
        if (user is null)
        {
            return null;
        }

        if (!user.IsVisible && !string.Equals(requesterUserId, userId, StringComparison.Ordinal))
        {
            return null;
        }

        return user.ToPublicProfileDto();
    }

    public async Task<IReadOnlyList<UserSummaryDto>> GetFollowersAsync(
        string userId,
        string? requesterUserId,
        CancellationToken cancellationToken = default
    )
    {
        var ids = await dbContext.Follows.AsNoTracking()
            .Where(entry => entry.FollowingUserId == userId)
            .OrderByDescending(entry => entry.CreatedAt)
            .Select(entry => entry.FollowerUserId)
            .ToListAsync(cancellationToken);

        return await BuildOrderedSummariesAsync(ids, requesterUserId, cancellationToken);
    }

    public async Task<IReadOnlyList<UserSummaryDto>> GetFollowingAsync(
        string userId,
        string? requesterUserId,
        CancellationToken cancellationToken = default
    )
    {
        var ids = await dbContext.Follows.AsNoTracking()
            .Where(entry => entry.FollowerUserId == userId)
            .OrderByDescending(entry => entry.CreatedAt)
            .Select(entry => entry.FollowingUserId)
            .ToListAsync(cancellationToken);

        return await BuildOrderedSummariesAsync(ids, requesterUserId, cancellationToken);
    }

    public async Task<IReadOnlyList<UserSummaryDto>> GetFriendsAsync(
        string userId,
        string? requesterUserId,
        CancellationToken cancellationToken = default
    )
    {
        var ids = await dbContext.Friendships.AsNoTracking()
            .Where(entry => entry.UserAId == userId || entry.UserBId == userId)
            .OrderByDescending(entry => entry.CreatedAt)
            .Select(entry => entry.UserAId == userId ? entry.UserBId : entry.UserAId)
            .ToListAsync(cancellationToken);

        return await BuildOrderedSummariesAsync(ids, requesterUserId, cancellationToken);
    }

    public async Task<IReadOnlyList<UserSummaryDto>> SearchUsersAsync(
        string query,
        string? excludeUserId,
        CancellationToken cancellationToken = default
    )
    {
        var normalized = TextNormalizer.Normalize(query);
        if (string.IsNullOrWhiteSpace(normalized))
        {
            return [];
        }

        var blockedUserIds = await GetBlockedUserIdsAsync(excludeUserId, cancellationToken);
        var prefixPattern = $"{normalized}%";
        var containsPattern = $"%{normalized}%";

        return await dbContext.Users.AsNoTracking()
            .Where(entry =>
                entry.Id != excludeUserId
                && entry.IsVisible
                && !blockedUserIds.Contains(entry.Id)
                && (
                    EF.Functions.Like(entry.NormalizedUserName, prefixPattern)
                    || EF.Functions.Like(entry.NormalizedDisplayName, prefixPattern)
                    || EF.Functions.Like(entry.NormalizedCity, prefixPattern)
                    || EF.Functions.Like(entry.NormalizedUserName, containsPattern)
                    || EF.Functions.Like(entry.NormalizedDisplayName, containsPattern)
                    || EF.Functions.Like(entry.NormalizedCity, containsPattern)
                )
            )
            .OrderBy(entry =>
                EF.Functions.Like(entry.NormalizedUserName, prefixPattern) ? 0 :
                EF.Functions.Like(entry.NormalizedDisplayName, prefixPattern) ? 1 :
                EF.Functions.Like(entry.NormalizedCity, prefixPattern) ? 2 :
                EF.Functions.Like(entry.NormalizedUserName, containsPattern) ? 3 :
                EF.Functions.Like(entry.NormalizedDisplayName, containsPattern) ? 4 : 5)
            .ThenBy(entry => entry.UserName)
            .Take(20)
            .Select(entry => entry.ToSummaryDto())
            .ToListAsync(cancellationToken);
    }

    public async Task<UserDataExportDto> CreateDataExportAsync(
        string userId,
        string publicBaseUrl,
        CancellationToken cancellationToken = default
    )
    {
        var user = await dbContext.Users.AsNoTracking()
            .FirstOrDefaultAsync(entry => entry.Id == userId, cancellationToken)
            ?? throw new KeyNotFoundException("User was not found.");

        var follows = await dbContext.Follows.AsNoTracking()
            .Where(entry => entry.FollowerUserId == userId || entry.FollowingUserId == userId)
            .ToListAsync(cancellationToken);
        var friendships = await dbContext.Friendships.AsNoTracking()
            .Where(entry => entry.UserAId == userId || entry.UserBId == userId)
            .ToListAsync(cancellationToken);
        var requests = await dbContext.FriendRequests.AsNoTracking()
            .Where(entry => entry.FromUserId == userId || entry.ToUserId == userId)
            .ToListAsync(cancellationToken);
        var presence = await dbContext.Presences.AsNoTracking()
            .FirstOrDefaultAsync(entry => entry.UserId == userId, cancellationToken);
        var posts = await dbContext.Posts.AsNoTracking()
            .Where(entry => entry.UserId == userId)
            .OrderByDescending(entry => entry.CreatedAt)
            .ToListAsync(cancellationToken);
        var postIds = posts.Select(entry => entry.Id).ToList();
        var comments = postIds.Count == 0
            ? []
            : await dbContext.PostComments.AsNoTracking()
                .Where(entry => postIds.Contains(entry.PostId))
                .ToListAsync(cancellationToken);
        var likes = postIds.Count == 0
            ? []
            : await dbContext.PostLikes.AsNoTracking()
                .Where(entry => postIds.Contains(entry.PostId))
                .ToListAsync(cancellationToken);
        var chats = await dbContext.ChatParticipants.AsNoTracking()
            .Where(entry => entry.UserId == userId)
            .Select(entry => entry.ChatId)
            .Distinct()
            .ToListAsync(cancellationToken);
        var messages = chats.Count == 0
            ? []
            : await dbContext.ChatMessages.AsNoTracking()
                .Where(entry => chats.Contains(entry.ChatId))
                .OrderByDescending(entry => entry.CreatedAt)
                .Take(2000)
                .ToListAsync(cancellationToken);
        var savedPosts = await dbContext.SavedPosts.AsNoTracking()
            .Where(entry => entry.UserId == userId)
            .ToListAsync(cancellationToken);
        var savedPlaces = await dbContext.SavedPlaces.AsNoTracking()
            .Where(entry => entry.UserId == userId)
            .ToListAsync(cancellationToken);
        var highlights = await dbContext.Highlights.AsNoTracking()
            .Where(entry => entry.UserId == userId)
            .ToListAsync(cancellationToken);
        var storyViews = await dbContext.StoryViews.AsNoTracking()
            .Where(entry => entry.ViewerUserId == userId)
            .OrderByDescending(entry => entry.ViewedAt)
            .ToListAsync(cancellationToken);
        var hiddenChatMessages = await dbContext.ChatMessageHiddenStates.AsNoTracking()
            .Where(entry => entry.UserId == userId)
            .OrderByDescending(entry => entry.HiddenAt)
            .ToListAsync(cancellationToken);

        var payload = new
        {
            exportedAt = DateTimeOffset.UtcNow,
            retentionHours = privacyOptions.Value.ExportRetentionHours,
            profile = user.ToProfileDto(),
            presence,
            follows,
            friendships,
            friendRequests = requests,
            posts,
            postLikes = likes,
            postComments = comments,
            savedPosts,
            savedPlaces,
            highlights,
            storyViews,
            hiddenChatMessages,
            chatIds = chats,
            messages,
        };

        var exportRoot = GetPrivateExportsRoot();
        var exportDirectory = Path.Combine(exportRoot, userId);
        Directory.CreateDirectory(exportDirectory);

        var exportId = Guid.NewGuid();
        var fileName = $"pulsecity-export-{DateTimeOffset.UtcNow:yyyyMMddHHmmss}.json";
        var fullPath = Path.Combine(exportDirectory, fileName);
        var json = JsonSerializer.Serialize(payload, new JsonSerializerOptions(JsonSerializerDefaults.Web)
        {
            WriteIndented = true,
        });
        await File.WriteAllTextAsync(fullPath, json, cancellationToken);
        var fileInfo = new FileInfo(fullPath);

        var relativePath = Path.Combine(userId, fileName).Replace("\\", "/");
        var export = new UserDataExport
        {
            Id = exportId,
            UserId = userId,
            FileName = fileName,
            RelativePath = relativePath,
            Status = "ready",
            FileSizeBytes = fileInfo.Length,
            CreatedAt = DateTimeOffset.UtcNow,
            ExpiresAt = DateTimeOffset.UtcNow.AddHours(
                Math.Max(1, privacyOptions.Value.ExportRetentionHours)
            ),
        };

        dbContext.UserDataExports.Add(export);
        await dbContext.SaveChangesAsync(cancellationToken);
        var token = BuildExportDownloadToken(export);

        return new UserDataExportDto(
            export.Id,
            export.Status,
            export.FileName,
            $"{publicBaseUrl.TrimEnd('/')}/api/users/me/export/{export.Id}/download?token={Uri.EscapeDataString(token)}",
            export.FileSizeBytes,
            export.CreatedAt,
            export.ExpiresAt
        );
    }

    public async Task<UserDataExportDownloadResult?> GetDataExportDownloadAsync(
        string userId,
        Guid exportId,
        string token,
        CancellationToken cancellationToken = default
    )
    {
        if (string.IsNullOrWhiteSpace(token))
        {
            return null;
        }

        var export = await dbContext.UserDataExports.AsNoTracking()
            .FirstOrDefaultAsync(
                entry =>
                    entry.Id == exportId
                    && entry.UserId == userId
                    && entry.Status == "ready"
                    && entry.ExpiresAt > DateTimeOffset.UtcNow,
                cancellationToken
            );

        if (export is null || !ValidateExportDownloadToken(export, token))
        {
            return null;
        }

        var path = ResolveExportPath(export);
        if (!File.Exists(path))
        {
            return null;
        }

        var stream = new FileStream(
            path,
            FileMode.Open,
            FileAccess.Read,
            FileShare.Read,
            64 * 1024,
            FileOptions.Asynchronous | FileOptions.SequentialScan
        );

        return new UserDataExportDownloadResult(
            export.FileName,
            "application/json",
            stream
        );
    }

    private async Task<IReadOnlyList<UserSummaryDto>> BuildOrderedSummariesAsync(
        IReadOnlyList<string> ids,
        string? requesterUserId,
        CancellationToken cancellationToken
    )
    {
        if (ids.Count == 0)
        {
            return [];
        }

        var blockedUserIds = await GetBlockedUserIdsAsync(requesterUserId, cancellationToken);
        var filteredIds = ids
            .Where(id => !blockedUserIds.Contains(id))
            .Distinct()
            .ToList();

        if (filteredIds.Count == 0)
        {
            return [];
        }

        var users = await dbContext.Users.AsNoTracking()
            .Where(entry => filteredIds.Contains(entry.Id) && entry.IsVisible)
            .ToDictionaryAsync(entry => entry.Id, cancellationToken);

        return filteredIds
            .Where(users.ContainsKey)
            .Select(id => users[id].ToSummaryDto())
            .ToList();
    }

    public async Task<UserProfileDto> UpdatePinnedMomentAsync(
        string userId,
        Guid? postId,
        CancellationToken cancellationToken = default
    )
    {
        var user = await dbContext.Users.FirstOrDefaultAsync(
            entry => entry.Id == userId,
            cancellationToken
        ) ?? throw new KeyNotFoundException("User was not found.");

        if (postId is null || postId == Guid.Empty)
        {
            user.PinnedPostId = null;
            user.PinnedAt = null;
        }
        else
        {
            // Sadece kendi post'u sabitlenebilir.
            var exists = await dbContext.Posts.AsNoTracking().AnyAsync(
                entry => entry.Id == postId && entry.UserId == userId,
                cancellationToken
            );
            if (!exists)
            {
                throw new KeyNotFoundException("Post was not found.");
            }
            user.PinnedPostId = postId;
            user.PinnedAt = DateTimeOffset.UtcNow;
        }

        user.UpdatedAt = DateTimeOffset.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);
        await realtimeNotifier.NotifyProfileChangedAsync(userId, cancellationToken);
        return user.ToProfileDto();
    }

    public async Task<IReadOnlyList<UserPlaceVisitDto>> GetPlacesVisitedAsync(
        string userId,
        string? requesterUserId,
        CancellationToken cancellationToken = default
    )
    {
        // Bloklanmışsa boş dön.
        if (!string.IsNullOrWhiteSpace(requesterUserId)
            && !string.Equals(requesterUserId, userId, StringComparison.Ordinal)
            && await AreUsersBlockedAsync(requesterUserId, userId, cancellationToken))
        {
            return [];
        }

        // Kullanıcının PlaceId'si dolu olan post'larını topla ve grupla.
        var visits = await dbContext.Posts.AsNoTracking()
            .Where(entry => entry.UserId == userId && entry.PlaceId != string.Empty)
            .GroupBy(entry => entry.PlaceId)
            .Select(group => new
            {
                PlaceId = group.Key,
                VisitCount = group.Count(),
                LastVisitedAt = group.Max(entry => entry.CreatedAt),
                CoverPhotoUrl = group
                    .OrderByDescending(entry => entry.CreatedAt)
                    .Select(entry =>
                        entry.PhotoUrls.Count > 0 ? entry.PhotoUrls[0] : string.Empty
                    )
                    .FirstOrDefault() ?? string.Empty,
                FallbackLocationName = group
                    .OrderByDescending(entry => entry.CreatedAt)
                    .Select(entry => entry.LocationName)
                    .FirstOrDefault() ?? string.Empty,
                FallbackLatitude = group
                    .OrderByDescending(entry => entry.CreatedAt)
                    .Select(entry => entry.Latitude)
                    .FirstOrDefault(),
                FallbackLongitude = group
                    .OrderByDescending(entry => entry.CreatedAt)
                    .Select(entry => entry.Longitude)
                    .FirstOrDefault(),
            })
            .OrderByDescending(entry => entry.LastVisitedAt)
            .Take(60)
            .ToListAsync(cancellationToken);

        if (visits.Count == 0)
        {
            return [];
        }

        // PlaceSnapshot tablosundan isim/konum bilgilerini zenginleştir.
        var placeIds = visits.Select(v => v.PlaceId).ToList();
        var snapshots = await dbContext.PlaceSnapshots.AsNoTracking()
            .Where(entry => placeIds.Contains(entry.PlaceId))
            .ToDictionaryAsync(entry => entry.PlaceId, cancellationToken);

        return visits.Select(v =>
        {
            snapshots.TryGetValue(v.PlaceId, out var snap);
            return new UserPlaceVisitDto(
                PlaceId: v.PlaceId,
                Name: snap?.Name ?? (string.IsNullOrWhiteSpace(v.FallbackLocationName)
                    ? v.PlaceId
                    : v.FallbackLocationName),
                Vicinity: snap?.Vicinity ?? string.Empty,
                Latitude: snap?.Latitude ?? v.FallbackLatitude,
                Longitude: snap?.Longitude ?? v.FallbackLongitude,
                VisitCount: v.VisitCount,
                LastVisitedAt: v.LastVisitedAt,
                CoverPhotoUrl: v.CoverPhotoUrl
            );
        }).ToList();
    }

    public async Task<SignalCrossingSummaryDto> GetSignalCrossingsAsync(
        string targetUserId,
        string requesterUserId,
        CancellationToken cancellationToken = default
    )
    {
        if (string.IsNullOrWhiteSpace(targetUserId)
            || string.IsNullOrWhiteSpace(requesterUserId)
            || string.Equals(targetUserId, requesterUserId, StringComparison.Ordinal))
        {
            return new SignalCrossingSummaryDto(0, null, []);
        }

        if (await AreUsersBlockedAsync(requesterUserId, targetUserId, cancellationToken))
        {
            return new SignalCrossingSummaryDto(0, null, []);
        }

        // İki ID'nin hangi sırada (A,B) olarak saklandığı deterministic
        // olsun diye string karşılaştırması ile normalize et.
        var (a, b) = string.Compare(requesterUserId, targetUserId, StringComparison.Ordinal) < 0
            ? (requesterUserId, targetUserId)
            : (targetUserId, requesterUserId);

        var query = dbContext.SignalCrossings.AsNoTracking()
            .Where(entry => entry.UserAId == a && entry.UserBId == b);

        var totalCount = await query.CountAsync(cancellationToken);
        if (totalCount == 0)
        {
            return new SignalCrossingSummaryDto(0, null, []);
        }

        var recent = await query
            .OrderByDescending(entry => entry.CrossedAt)
            .Take(10)
            .Select(entry => new SignalCrossingDto(
                entry.Id,
                entry.CrossedAt,
                entry.PlaceId,
                entry.LocationLabel,
                entry.ApproxLatitude,
                entry.ApproxLongitude
            ))
            .ToListAsync(cancellationToken);

        return new SignalCrossingSummaryDto(
            TotalCount: totalCount,
            LastCrossedAt: recent[0].CrossedAt,
            Recent: recent
        );
    }

    public async Task<DiscoverPeopleResponseDto> GetDiscoverPeopleAsync(
        string requesterUserId,
        DiscoverPeopleQuery query,
        CancellationToken cancellationToken = default
    )
    {
        var requester = await dbContext.Users.AsNoTracking()
            .FirstOrDefaultAsync(entry => entry.Id == requesterUserId, cancellationToken)
            ?? throw new KeyNotFoundException("User was not found.");

        var modeFilter = string.IsNullOrWhiteSpace(query.Mode) ? null : NormalizeMode(query.Mode);

        var minAge = query.MinAge;
        var maxAge = query.MaxAge;
        if (minAge.HasValue && maxAge.HasValue && minAge.Value > maxAge.Value)
        {
            (minAge, maxAge) = (maxAge, minAge);
        }

        var verifiedOnly = query.VerifiedOnly == true;

        // Exclusion subqueries — EF Core translates these into NOT EXISTS joins
        // so the three lookups collapse into a single SQL round-trip instead of
        // materializing HashSets into memory first.
        var blockedSubquery = dbContext.BlockedUsers.AsNoTracking()
            .Where(entry =>
                entry.UserId == requesterUserId || entry.BlockedUserId == requesterUserId)
            .Select(entry =>
                entry.UserId == requesterUserId ? entry.BlockedUserId : entry.UserId);

        var passedSubquery = dbContext.DiscoverPasses.AsNoTracking()
            .Where(entry => entry.UserId == requesterUserId)
            .Select(entry => entry.TargetUserId);

        // Anyone we already have a match record with (pending or accepted) should
        // also drop out of the discover stack so we do not repeat the same card.
        var matchedSubquery = dbContext.Matches.AsNoTracking()
            .Where(entry =>
                (entry.UserId1 == requesterUserId || entry.UserId2 == requesterUserId)
                && (entry.Status == MatchStatus.Pending || entry.Status == MatchStatus.Accepted))
            .Select(entry =>
                entry.UserId1 == requesterUserId ? entry.UserId2 : entry.UserId1);

        // Coarse SQL pre-filter; scoring happens in memory because DatingPrompts /
        // Interests / EnabledFeatures are JSON-serialized columns.
        var rawCandidates = await dbContext.Users.AsNoTracking()
            .Where(entry =>
                entry.Id != requesterUserId
                && entry.IsVisible
                && !blockedSubquery.Contains(entry.Id)
                && !passedSubquery.Contains(entry.Id)
                && !matchedSubquery.Contains(entry.Id)
                && (modeFilter == null || entry.Mode == modeFilter)
                && (!minAge.HasValue || entry.Age >= minAge.Value)
                && (!maxAge.HasValue || entry.Age <= maxAge.Value)
                && (!verifiedOnly || entry.IsPhotoVerified)
            )
            .Take(500)
            .ToListAsync(cancellationToken);

        var requesterInterests = new HashSet<string>(
            requester.Interests.Select(item => item.Trim().ToLowerInvariant()),
            StringComparer.Ordinal
        );
        var requesterDealbreakers = new HashSet<string>(
            requester.Dealbreakers.Select(item => item.Trim().ToLowerInvariant()),
            StringComparer.Ordinal
        );
        var requesterLookingForModes = new HashSet<string>(
            requester.LookingForModes.Select(NormalizeMode),
            StringComparer.Ordinal
        );

        var scored = new List<(UserProfile User, int Score, string Tier, double DistanceKm, IReadOnlyList<string> Shared)>();
        foreach (var candidate in rawCandidates)
        {
            // lookingForModes filter
            if (requesterLookingForModes.Count > 0
                && !requesterLookingForModes.Contains(NormalizeMode(candidate.Mode)))
            {
                continue;
            }

            // gender / match preference filter (best-effort, "everyone" passes through)
            if (!IsGenderCompatible(requester, candidate))
            {
                continue;
            }

            // dealbreaker filter
            if (HasDealbreaker(requesterDealbreakers, candidate))
            {
                continue;
            }

            var distanceKm = ComputeDistanceKm(
                requester.Latitude,
                requester.Longitude,
                candidate.Latitude,
                candidate.Longitude
            );

            // Distance filter — if both have coords, enforce radius
            if (distanceKm.HasValue && distanceKm.Value > query.RadiusKm)
            {
                continue;
            }

            var (score, shared) = ComputeChemistry(
                requester,
                candidate,
                requesterInterests,
                distanceKm,
                query.RadiusKm
            );
            scored.Add((candidate, score, ChemistryTier(score), distanceKm ?? -1, shared));
        }

        var ordered = scored
            .OrderByDescending(item => item.Score)
            .ThenByDescending(item => item.User.LastSeenAt)
            .ToList();

        var pageItems = ordered.Skip(query.Skip).Take(query.Take).ToList();
        var pageIds = pageItems.Select(x => x.User.Id).ToList();
        var nowUtc = DateTimeOffset.UtcNow;
        var hostingCounts = pageIds.Count == 0
            ? new Dictionary<string, int>()
            : await dbContext.Activities.AsNoTracking()
                .Where(a => a.Status == ActivityStatus.Published
                    && a.StartsAt >= nowUtc
                    && pageIds.Contains(a.HostUserId))
                .GroupBy(a => a.HostUserId)
                .Select(g => new { HostId = g.Key, Count = g.Count() })
                .ToDictionaryAsync(g => g.HostId, g => g.Count, cancellationToken);

        var page = pageItems
            .Select(item => new DiscoverPersonDto(
                Id: item.User.Id,
                DisplayName: string.IsNullOrWhiteSpace(item.User.DisplayName)
                    ? item.User.UserName
                    : item.User.DisplayName,
                UserName: item.User.UserName,
                Bio: item.User.Bio,
                City: item.User.City,
                Gender: item.User.Gender,
                Age: item.User.Age,
                Mode: NormalizeMode(item.User.Mode),
                ProfilePhotoUrl: item.User.ProfilePhotoUrl,
                PhotoUrls: item.User.PhotoUrls,
                Interests: item.User.Interests,
                Orientation: item.User.Orientation,
                RelationshipIntent: item.User.RelationshipIntent,
                HeightCm: item.User.HeightCm,
                DrinkingStatus: item.User.DrinkingStatus,
                SmokingStatus: item.User.SmokingStatus,
                IsPhotoVerified: item.User.IsPhotoVerified,
                DatingPrompts: item.User.DatingPrompts,
                DistanceKm: item.DistanceKm < 0 ? 0 : Math.Round(item.DistanceKm, 1),
                ChemistryScore: item.Score,
                ChemistryTier: item.Tier,
                SharedInterests: item.Shared,
                HostingActivityCount: hostingCounts.TryGetValue(item.User.Id, out var hc) ? hc : 0
            ))
            .ToList();

        var nextSkip = query.Skip + page.Count;
        var cursor = nextSkip < ordered.Count ? nextSkip.ToString() : string.Empty;

        return new DiscoverPeopleResponseDto(
            Items: page,
            TotalCandidates: ordered.Count,
            Cursor: cursor
        );
    }

    public async Task RecordDiscoverPassAsync(
        string userId,
        RecordDiscoverPassRequest request,
        CancellationToken cancellationToken = default
    )
    {
        var targetUserId = request.TargetUserId?.Trim() ?? string.Empty;
        if (string.IsNullOrWhiteSpace(targetUserId) || targetUserId == userId)
        {
            throw new InvalidOperationException("Invalid pass target.");
        }

        var exists = await dbContext.DiscoverPasses.AsNoTracking().AnyAsync(
            entry => entry.UserId == userId && entry.TargetUserId == targetUserId,
            cancellationToken
        );
        if (exists)
        {
            return;
        }

        dbContext.DiscoverPasses.Add(new DiscoverPass
        {
            UserId = userId,
            TargetUserId = targetUserId,
            CreatedAt = DateTimeOffset.UtcNow,
        });
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    public async Task<bool> UndoDiscoverPassAsync(
        string userId,
        string targetUserId,
        CancellationToken cancellationToken = default
    )
    {
        targetUserId = targetUserId?.Trim() ?? string.Empty;
        if (string.IsNullOrWhiteSpace(targetUserId))
        {
            return false;
        }

        var row = await dbContext.DiscoverPasses.FirstOrDefaultAsync(
            entry => entry.UserId == userId && entry.TargetUserId == targetUserId,
            cancellationToken
        );
        if (row == null)
        {
            return false;
        }

        dbContext.DiscoverPasses.Remove(row);
        await dbContext.SaveChangesAsync(cancellationToken);
        return true;
    }

    private static (int Score, IReadOnlyList<string> Shared) ComputeChemistry(
        UserProfile requester,
        UserProfile candidate,
        HashSet<string> requesterInterests,
        double? distanceKm,
        double radiusKm
    )
    {
        // Mode match (40 pts)
        var requesterMode = NormalizeMode(requester.Mode);
        var candidateMode = NormalizeMode(candidate.Mode);
        var modeScore = ScoreModeMatch(requesterMode, candidateMode);

        // Shared interests (25 pts)
        var sharedList = candidate.Interests
            .Where(item => requesterInterests.Contains(item.Trim().ToLowerInvariant()))
            .Take(8)
            .ToList();
        var totalInterests = Math.Max(1, Math.Min(requesterInterests.Count, 8));
        var interestScore = (int)Math.Round(25.0 * sharedList.Count / totalInterests);
        interestScore = Math.Min(25, interestScore);

        // Distance proximity (15 pts) — closer is better; null distance gives partial credit
        int distanceScore;
        if (!distanceKm.HasValue)
        {
            distanceScore = 6;
        }
        else if (distanceKm.Value <= 0.5)
        {
            distanceScore = 15;
        }
        else
        {
            var ratio = Math.Clamp(1.0 - (distanceKm.Value / Math.Max(1.0, radiusKm)), 0, 1);
            distanceScore = (int)Math.Round(15 * ratio);
        }

        // Verification (10 pts)
        var verificationScore = candidate.IsPhotoVerified ? 10 : 0;

        // Activity / online (10 pts)
        int activityScore;
        if (candidate.IsOnline)
        {
            activityScore = 10;
        }
        else if (candidate.LastSeenAt.HasValue)
        {
            var hoursSince = (DateTimeOffset.UtcNow - candidate.LastSeenAt.Value).TotalHours;
            activityScore = hoursSince switch
            {
                <= 1 => 9,
                <= 24 => 7,
                <= 168 => 4,
                _ => 1,
            };
        }
        else
        {
            activityScore = 0;
        }

        var total = Math.Clamp(
            modeScore + interestScore + distanceScore + verificationScore + activityScore,
            0,
            100
        );
        return (total, sharedList);
    }

    private static int ScoreModeMatch(string requesterMode, string candidateMode)
    {
        if (requesterMode == candidateMode)
        {
            return 40;
        }

        // chill is the universal connector — matches anything
        if (requesterMode == "chill" || candidateMode == "chill")
        {
            return 25;
        }

        return 10;
    }

    private static string ChemistryTier(int score) => score switch
    {
        >= 80 => "spark",
        >= 60 => "vibe",
        >= 40 => "match",
        >= 20 => "casual",
        _ => "low",
    };

    private static bool IsGenderCompatible(UserProfile requester, UserProfile candidate)
    {
        var requesterPref = requester.MatchPreference;
        var candidatePref = candidate.MatchPreference;

        bool requesterAccepts = requesterPref switch
        {
            "men" => candidate.Gender == "male",
            "women" => candidate.Gender == "female",
            _ => true,
        };
        bool candidateAccepts = candidatePref switch
        {
            "men" => requester.Gender == "male",
            "women" => requester.Gender == "female",
            _ => true,
        };
        return requesterAccepts && candidateAccepts;
    }

    private static bool HasDealbreaker(HashSet<string> dealbreakers, UserProfile candidate)
    {
        if (dealbreakers.Count == 0)
        {
            return false;
        }

        if (dealbreakers.Contains("smoker")
            && (candidate.SmokingStatus == "regularly" || candidate.SmokingStatus == "socially"))
        {
            return true;
        }
        if (dealbreakers.Contains("drinks_heavily") && candidate.DrinkingStatus == "regularly")
        {
            return true;
        }
        if (dealbreakers.Contains("no_photo")
            && string.IsNullOrWhiteSpace(candidate.ProfilePhotoUrl)
            && candidate.PhotoUrls.Count == 0)
        {
            return true;
        }
        if (dealbreakers.Contains("unverified") && !candidate.IsPhotoVerified)
        {
            return true;
        }
        if (dealbreakers.Contains("no_bio") && string.IsNullOrWhiteSpace(candidate.Bio))
        {
            return true;
        }
        return false;
    }

    private static double? ComputeDistanceKm(double? lat1, double? lng1, double? lat2, double? lng2)
    {
        if (!lat1.HasValue || !lng1.HasValue || !lat2.HasValue || !lng2.HasValue)
        {
            return null;
        }

        const double earthRadiusKm = 6371.0;
        var dLat = ToRadians(lat2.Value - lat1.Value);
        var dLng = ToRadians(lng2.Value - lng1.Value);
        var a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2)
            + Math.Cos(ToRadians(lat1.Value)) * Math.Cos(ToRadians(lat2.Value))
            * Math.Sin(dLng / 2) * Math.Sin(dLng / 2);
        var c = 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
        return earthRadiusKm * c;
    }

    private static double ToRadians(double degrees) => degrees * Math.PI / 180.0;

    private Task<HashSet<string>> GetBlockedUserIdsAsync(
        string? requesterUserId,
        CancellationToken cancellationToken
    ) => BlockedUsersHelper.GetBlockedUserIdsAsync(dbContext, requesterUserId, cancellationToken);

    private Task<bool> AreUsersBlockedAsync(
        string requesterUserId,
        string targetUserId,
        CancellationToken cancellationToken
    )
    {
        if (string.IsNullOrWhiteSpace(requesterUserId) || string.IsNullOrWhiteSpace(targetUserId))
        {
            return Task.FromResult(false);
        }

        return dbContext.BlockedUsers.AsNoTracking().AnyAsync(
            entry =>
                (entry.UserId == requesterUserId && entry.BlockedUserId == targetUserId)
                || (entry.UserId == targetUserId && entry.BlockedUserId == requesterUserId),
            cancellationToken
        );
    }

    private string GetPrivateExportsRoot() =>
        StoragePathResolver.ResolveExportRoot(hostEnvironment, storageOptions.Value);

    private string ResolveExportPath(UserDataExport export)
    {
        var privateRoot = GetPrivateExportsRoot();
        var normalized = export.RelativePath.TrimStart('/').Replace('/', Path.DirectorySeparatorChar);
        var privatePath = Path.Combine(privateRoot, normalized);
        if (File.Exists(privatePath))
        {
            return privatePath;
        }

        var uploadRoot = StoragePathResolver.ResolveLegacyPublicRoot(
            hostEnvironment,
            storageOptions.Value
        );
        return Path.Combine(
            uploadRoot,
            normalized.Replace(
                $"uploads{Path.DirectorySeparatorChar}",
                string.Empty,
                StringComparison.OrdinalIgnoreCase
            )
        );
    }

    private string BuildExportDownloadToken(UserDataExport export)
    {
        var expiry = DateTimeOffset.UtcNow.Add(ExportDownloadTokenLifetime);
        if (expiry > export.ExpiresAt)
        {
            expiry = export.ExpiresAt;
        }

        var expirySeconds = expiry.ToUnixTimeSeconds();
        var payload = $"{export.Id:N}:{export.UserId}:{expirySeconds}:{export.FileName}";
        var signature = ComputeSignature(payload);
        return $"{expirySeconds}.{Base64UrlEncode(signature)}";
    }

    private bool ValidateExportDownloadToken(UserDataExport export, string token)
    {
        var parts = token.Split('.', 2, StringSplitOptions.RemoveEmptyEntries);
        if (parts.Length != 2 || !long.TryParse(parts[0], out var expirySeconds))
        {
            return false;
        }

        var expiry = DateTimeOffset.FromUnixTimeSeconds(expirySeconds);
        if (expiry <= DateTimeOffset.UtcNow || expiry > export.ExpiresAt)
        {
            return false;
        }

        var payload = $"{export.Id:N}:{export.UserId}:{expirySeconds}:{export.FileName}";
        var expected = Base64UrlEncode(ComputeSignature(payload));
        var expectedBytes = System.Text.Encoding.UTF8.GetBytes(expected);
        var actualBytes = System.Text.Encoding.UTF8.GetBytes(parts[1]);
        return expectedBytes.Length == actualBytes.Length
            && CryptographicOperations.FixedTimeEquals(expectedBytes, actualBytes);
    }

    private byte[] ComputeSignature(string payload)
    {
        var signingKey = jwtOptions.Value.SigningKey.Trim();
        if (string.IsNullOrWhiteSpace(signingKey))
        {
            throw new InvalidOperationException("PulseCity:Jwt:SigningKey is required.");
        }

        using var hmac = new HMACSHA256(System.Text.Encoding.UTF8.GetBytes(signingKey));
        return hmac.ComputeHash(System.Text.Encoding.UTF8.GetBytes(payload));
    }

    private static string Base64UrlEncode(byte[] bytes)
    {
        return Convert.ToBase64String(bytes)
            .TrimEnd('=')
            .Replace('+', '-')
            .Replace('/', '_');
    }

    private static string NormalizeLanguage(string value)
    {
        var normalized = value.Trim().ToLowerInvariant();
        return normalized switch
        {
            "tr" or "de" or "en" => normalized,
            _ => "tr",
        };
    }

    private static string NormalizeGranularity(string value)
    {
        var normalized = value.Trim().ToLowerInvariant();
        return normalized switch
        {
            "exact" or "nearby" or "district" or "city" => normalized,
            _ => "nearby",
        };
    }

    private static string NormalizeGender(string? value) =>
        SharedHelpers.NormalizeGender(value);

    private static string NormalizeMatchPreference(string? value, string gender) =>
        SharedHelpers.NormalizeMatchPreference(value, gender);

    private static readonly Dictionary<string, string> LegacyModeAliases = new(StringComparer.OrdinalIgnoreCase)
    {
        { "kesif", "chill" },
        { "sakinlik", "chill" },
        { "sosyal", "friends" },
        { "uretkenlik", "chill" },
        { "eglence", "fun" },
        { "acik_alan", "chill" },
        { "topluluk", "friends" },
        { "aile", "chill" },
        { "alisveris", "chill" },
        { "ozel_cevre", "chill" },
    };

    private static string NormalizeMode(string? value)
    {
        var raw = value?.Trim().ToLowerInvariant() ?? string.Empty;
        if (string.IsNullOrEmpty(raw))
        {
            return "chill";
        }
        if (LegacyModeAliases.TryGetValue(raw, out var mapped))
        {
            return mapped;
        }
        return raw switch
        {
            "flirt" or "friends" or "fun" or "chill" => raw,
            _ => "chill",
        };
    }

    private static string NormalizeOrientation(string? value)
    {
        var raw = value?.Trim().ToLowerInvariant() ?? string.Empty;
        return raw switch
        {
            "straight" or "gay" or "lesbian" or "bi" or "pan" or "queer" or "asexual" or "none" => raw,
            _ => string.Empty,
        };
    }

    private static string NormalizeIntent(string? value)
    {
        var raw = value?.Trim().ToLowerInvariant() ?? string.Empty;
        return raw switch
        {
            "casual" or "relationship" or "friendship" or "unsure" or "open" => raw,
            _ => string.Empty,
        };
    }

    private static string NormalizeFrequency(string? value)
    {
        var raw = value?.Trim().ToLowerInvariant() ?? string.Empty;
        return raw switch
        {
            "never" or "rarely" or "socially" or "regularly" => raw,
            _ => string.Empty,
        };
    }

    private static int CalculateAge(DateTime birthDate)
    {
        var today = DateTime.UtcNow.Date;
        var age = today.Year - birthDate.Year;
        if (birthDate.Date > today.AddYears(-age))
        {
            age--;
        }
        return Math.Max(0, age);
    }

    public async Task<PhotoVerificationStatusDto> SubmitPhotoVerificationAsync(
        string userId,
        SubmitPhotoVerificationRequest request,
        CancellationToken cancellationToken = default
    )
    {
        var user = await dbContext.Users.FirstOrDefaultAsync(
            entry => entry.Id == userId,
            cancellationToken
        ) ?? throw new InvalidOperationException("User not found.");

        var selfieUrl = (request.SelfieUrl ?? string.Empty).Trim();
        if (string.IsNullOrWhiteSpace(selfieUrl))
        {
            throw new ArgumentException("Selfie URL is required.", nameof(request));
        }

        user.VerificationSelfieUrl = selfieUrl;
        user.VerificationSubmittedAt = DateTimeOffset.UtcNow;
        user.UpdatedAt = DateTimeOffset.UtcNow;

        // Geliştirme ortamında manuel moderasyon yok — selfie geldikten sonra
        // otomatik onay vererek UX akışı uçtan uca tamamlanabilsin.
        var autoApprove = hostEnvironment.IsDevelopment();
        if (autoApprove)
        {
            user.VerificationStatus = "approved";
            user.IsPhotoVerified = true;
        }
        else
        {
            user.VerificationStatus = "pending";
            user.IsPhotoVerified = false;
        }

        await dbContext.SaveChangesAsync(cancellationToken);

        if (user.IsPhotoVerified)
        {
            _ = notificationsService.CreateAsync(
                userId,
                NotificationType.VerificationApproved,
                "Profil doğrulaması tamamlandı",
                "Foto doğrulaman onaylandı, mavi rozet artık profilinde 🎉",
                deepLink: "/profile",
                relatedEntityType: "User",
                relatedEntityId: userId,
                cancellationToken: cancellationToken
            );

            // Verified rozetini hesapla — onay sonrası anında "Verified" rozetini kazansın.
            await badgesService.RecomputeAsync(userId, cancellationToken);
        }

        await realtimeNotifier.NotifyProfileChangedAsync(userId, cancellationToken);

        return new PhotoVerificationStatusDto(
            user.VerificationStatus,
            user.IsPhotoVerified,
            user.VerificationSubmittedAt
        );
    }

    public async Task<PhotoVerificationStatusDto> GetPhotoVerificationStatusAsync(
        string userId,
        CancellationToken cancellationToken = default
    )
    {
        var user = await dbContext.Users.AsNoTracking().FirstOrDefaultAsync(
            entry => entry.Id == userId,
            cancellationToken
        ) ?? throw new InvalidOperationException("User not found.");

        var status = string.IsNullOrWhiteSpace(user.VerificationStatus)
            ? (user.IsPhotoVerified ? "approved" : "none")
            : user.VerificationStatus;

        return new PhotoVerificationStatusDto(
            status,
            user.IsPhotoVerified,
            user.VerificationSubmittedAt
        );
    }
}
