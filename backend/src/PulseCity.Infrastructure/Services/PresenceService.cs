using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using PulseCity.Application.DTOs;
using PulseCity.Application.Interfaces;
using PulseCity.Infrastructure.Data;
using PulseCity.Infrastructure.Options;
using System.Security.Cryptography;
using System.Text;

namespace PulseCity.Infrastructure.Services;

public sealed class PresenceService(
    PulseCityDbContext dbContext,
    IOptions<PrivacyOptions> privacyOptions,
    IRealtimeNotifier realtimeNotifier
) : IPresenceService
{
    public async Task<LobbySnapshotDto> GetLobbySnapshotAsync(
        CancellationToken cancellationToken = default
    )
    {
        var now = DateTimeOffset.UtcNow;
        var activeSince = now.AddMinutes(-12);
        var risingSince = now.AddHours(-3);
        var livePlaceSince = now.AddHours(-2);

        var activeUsers = await dbContext.Users
            .AsNoTracking()
            .Where(entry => entry.IsOnline && entry.LastSeenAt != null && entry.LastSeenAt >= activeSince)
            .CountAsync(cancellationToken);

        var recentPresenceModes = await (
            from user in dbContext.Users.AsNoTracking()
            join presence in dbContext.Presences.AsNoTracking()
                on user.Id equals presence.UserId into presenceJoin
            from presence in presenceJoin.DefaultIfEmpty()
            where user.IsOnline
                && user.LastSeenAt != null
                && user.LastSeenAt >= activeSince
            select new
            {
                UserId = user.Id,
                Mode = presence != null && !string.IsNullOrWhiteSpace(presence.Mode) ? presence.Mode : user.Mode,
            }
        )
            .ToListAsync(cancellationToken);

        var modeActivity = recentPresenceModes
            .GroupBy(entry => string.IsNullOrWhiteSpace(entry.Mode) ? "kesif" : entry.Mode)
            .Select(group => new LobbyModeActivityDto(
                group.Key,
                group.Select(entry => entry.UserId).Distinct(StringComparer.Ordinal).Count()
            ))
            .OrderByDescending(entry => entry.Count)
            .Take(6)
            .ToList();

        var livePlaces = await dbContext.PlaceSnapshots
            .AsNoTracking()
            .Where(entry => entry.UpdatedAt >= livePlaceSince && entry.IsOpenNow)
            .CountAsync(cancellationToken);

        var recentPostCoordinates = await dbContext.Posts
            .AsNoTracking()
            .Where(entry =>
                entry.CreatedAt >= risingSince &&
                entry.Latitude.HasValue &&
                entry.Longitude.HasValue
            )
            .Select(entry => new
            {
                Latitude = entry.Latitude!.Value,
                Longitude = entry.Longitude!.Value,
            })
            .ToListAsync(cancellationToken);

        var risingZones = recentPostCoordinates
            .Select(entry => $"{Math.Round(entry.Latitude, 2):0.00}:{Math.Round(entry.Longitude, 2):0.00}")
            .Distinct(StringComparer.Ordinal)
            .Count();

        return new LobbySnapshotDto(
            ActiveUsers: activeUsers,
            LivePlaces: livePlaces,
            RisingZones: risingZones,
            ModeActivity: modeActivity
        );
    }

    public async Task UpdatePresenceAsync(
        string userId,
        UpdatePresenceRequest request,
        CancellationToken cancellationToken = default
    )
    {
        var now = DateTimeOffset.UtcNow;
        var trimmedCity = request.City.Trim();
        var normalizedMode = string.IsNullOrWhiteSpace(request.Mode)
            ? "kesif"
            : request.Mode.Trim().ToLowerInvariant();

        var user = await dbContext.Users.FirstOrDefaultAsync(
            entry => entry.Id == userId,
            cancellationToken
        );
        if (user is not null)
        {
            user.Latitude = request.Latitude;
            user.Longitude = request.Longitude;
            if (!string.IsNullOrWhiteSpace(trimmedCity))
            {
                user.City = trimmedCity;
                user.NormalizedCity = trimmedCity.ToLowerInvariant();
            }
            user.IsOnline = request.IsOnline;
            user.LastSeenAt = now;
            user.UpdatedAt = now;
        }

        var presence = await dbContext.Presences.FirstOrDefaultAsync(
            entry => entry.UserId == userId,
            cancellationToken
        );

        if (presence is null)
        {
            dbContext.Presences.Add(
                new PulseCity.Domain.Entities.UserPresence
                {
                    UserId = userId,
                    Latitude = request.Latitude,
                    Longitude = request.Longitude,
                    City = trimmedCity,
                    Mode = normalizedMode,
                    ShareProfile = request.ShareProfile,
                    IsSignalActive = request.IsOnline && request.IsSignalActive,
                    UpdatedAt = now,
                }
            );
        }
        else
        {
            presence.Latitude = request.Latitude;
            presence.Longitude = request.Longitude;
            presence.City = trimmedCity;
            presence.Mode = normalizedMode;
            presence.ShareProfile = request.ShareProfile;
            presence.IsSignalActive = request.IsOnline && request.IsSignalActive;
            presence.UpdatedAt = now;
        }

        await dbContext.SaveChangesAsync(cancellationToken);

        await realtimeNotifier.NotifyPresenceChangedAsync(
            trimmedCity,
            userId,
            cancellationToken
        );
        await realtimeNotifier.NotifyProfileChangedAsync(userId, cancellationToken);
    }

    public async Task UpdateOnlineStatusAsync(
        string userId,
        UpdateOnlineStatusRequest request,
        CancellationToken cancellationToken = default
    )
    {
        string cityForBroadcast = string.Empty;
        var user = await dbContext.Users.FirstOrDefaultAsync(entry => entry.Id == userId, cancellationToken);
        if (user is not null)
        {
            user.IsOnline = request.IsOnline;
            user.LastSeenAt = DateTimeOffset.UtcNow;
            user.UpdatedAt = DateTimeOffset.UtcNow;
            cityForBroadcast = user.City;
        }

        var presence = await dbContext.Presences.FirstOrDefaultAsync(entry => entry.UserId == userId, cancellationToken);
        if (presence is not null)
        {
            if (!request.IsOnline)
            {
                presence.IsSignalActive = false;
            }
            presence.UpdatedAt = DateTimeOffset.UtcNow;
            if (!string.IsNullOrWhiteSpace(presence.City))
            {
                cityForBroadcast = presence.City;
            }
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        await realtimeNotifier.NotifyProfileChangedAsync(userId, cancellationToken);
        if (!string.IsNullOrWhiteSpace(cityForBroadcast))
        {
            await realtimeNotifier.NotifyPresenceChangedAsync(cityForBroadcast, userId, cancellationToken);
        }
    }

    public async Task<IReadOnlyList<NearbyUserDto>> GetNearbyUsersAsync(
        string currentUserId,
        NearbyUsersRequest request,
        CancellationToken cancellationToken = default
    )
    {
        var rows = await dbContext.Database.SqlQueryRaw<NearbyUserSqlRow>(
            """
            SELECT *
            FROM dbo.fn_GetNearbyVisibleUsers({0}, {1}, {2}, {3})
            ORDER BY DistanceMeters ASC
            """,
            currentUserId,
            request.Latitude,
            request.Longitude,
            request.RadiusKm
        ).ToListAsync(cancellationToken);

        var blockedUserIds = await dbContext.BlockedUsers.AsNoTracking()
            .Where(entry => entry.UserId == currentUserId || entry.BlockedUserId == currentUserId)
            .Select(entry => entry.UserId == currentUserId ? entry.BlockedUserId : entry.UserId)
            .ToListAsync(cancellationToken);

        var mapped = rows.Select(row => new NearbyUserCandidate(
            new NearbyUserDto(
                row.Id,
                row.UserName,
                row.DisplayName,
                row.Bio,
                row.City,
                row.Gender,
                row.Mode,
                row.MatchPreference,
                row.PrivacyLevel,
                row.LocationGranularity,
                row.IsVisible,
                row.IsOnline,
                row.ProfilePhotoUrl,
                ParseList(row.Interests),
                row.Latitude,
                row.Longitude,
                row.LastSeenAt,
                row.FollowersCount,
                row.FollowingCount,
                row.FriendsCount,
                row.PulseScore,
                row.PlacesVisited,
                row.VibeTagsCreated,
                row.DistanceMeters,
                row.ShareProfile,
                row.IsSignalActive
            ),
            row.KAnonymityLevel,
            row.EnableDifferentialPrivacy
        ))
        .Where(entry => !request.SignalOnly || entry.Dto.IsSignalActive)
        .Where(entry => !blockedUserIds.Contains(entry.Id))
        .ToList();

        return ProtectNearbyUsers(mapped);
    }

    private IReadOnlyList<NearbyUserDto> ProtectNearbyUsers(
        IReadOnlyList<NearbyUserCandidate> users
    )
    {
        var visibleCount = users.Count(entry => entry.Dto.IsVisible && entry.Dto.IsOnline);
        return users.Select(entry =>
        {
            var dto = entry.Dto;
            var effectiveK = Math.Max(
                entry.KAnonymityLevel,
                privacyOptions.Value.DefaultKAnonymityLevel
            );
            var granularity = NormalizeGranularity(dto.LocationGranularity);
            if (visibleCount < effectiveK)
            {
                granularity = PromoteGranularity(granularity);
            }

            var protectedDistance = ProtectDistance(dto.DistanceMeters, granularity);
            var (latitude, longitude) = ProtectCoordinates(
                dto.Id,
                dto.Latitude,
                dto.Longitude,
                granularity,
                entry.EnableDifferentialPrivacy
            );

            var shouldHideProfile = !dto.ShareProfile
                || dto.PrivacyLevel.Equals("ghost", StringComparison.OrdinalIgnoreCase);

            return dto with
            {
                DisplayName = shouldHideProfile ? string.Empty : dto.DisplayName,
                Bio = shouldHideProfile ? string.Empty : dto.Bio,
                UserName = shouldHideProfile ? string.Empty : dto.UserName,
                ProfilePhotoUrl = shouldHideProfile ? string.Empty : dto.ProfilePhotoUrl,
                Interests = shouldHideProfile ? [] : dto.Interests,
                PrivacyLevel = shouldHideProfile ? "ghost" : dto.PrivacyLevel,
                Latitude = latitude,
                Longitude = longitude,
                DistanceMeters = protectedDistance,
                LocationGranularity = granularity,
            };
        }).ToList();
    }

    private (double? Latitude, double? Longitude) ProtectCoordinates(
        string userId,
        double? latitude,
        double? longitude,
        string granularity,
        bool enableDifferentialPrivacy
    )
    {
        if (!latitude.HasValue || !longitude.HasValue)
        {
            return (latitude, longitude);
        }

        if (granularity == "city")
        {
            return (null, null);
        }

        var gridMeters = granularity switch
        {
            "district" => 600d,
            "nearby" => 120d,
            _ => 30d,
        };

        var protectedLat = RoundLatitude(latitude.Value, gridMeters);
        var protectedLng = RoundLongitude(latitude.Value, longitude.Value, gridMeters);

        if (!enableDifferentialPrivacy)
        {
            return (protectedLat, protectedLng);
        }

        var noiseRadiusMeters = Math.Max(
            10,
            granularity switch
            {
                "district" => privacyOptions.Value.DefaultNoiseMeters * 3,
                "nearby" => privacyOptions.Value.DefaultNoiseMeters,
                _ => privacyOptions.Value.DefaultNoiseMeters / 2,
            }
        );

        var seed = $"{userId}:{DateTimeOffset.UtcNow:yyyyMMddHH}";
        var hash = SHA256.HashData(Encoding.UTF8.GetBytes(seed));
        var angle = (BitConverter.ToUInt32(hash, 0) / (double)uint.MaxValue) * (Math.PI * 2);
        var radius = (BitConverter.ToUInt32(hash, 4) / (double)uint.MaxValue) * noiseRadiusMeters;
        var latitudeOffset = (radius * Math.Cos(angle)) / 111_320d;
        var longitudeOffset = (radius * Math.Sin(angle))
            / (111_320d * Math.Cos(protectedLat * Math.PI / 180d));

        return (protectedLat + latitudeOffset, protectedLng + longitudeOffset);
    }

    private static double ProtectDistance(double meters, string granularity)
    {
        var band = granularity switch
        {
            "city" => 1000d,
            "district" => 250d,
            "nearby" => 50d,
            _ => 15d,
        };

        return Math.Max(band, Math.Round(meters / band) * band);
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

    private static string PromoteGranularity(string value) => value switch
    {
        "exact" => "nearby",
        "nearby" => "district",
        _ => "city",
    };

    private static double RoundLatitude(double latitude, double meters)
    {
        var step = meters / 111_320d;
        return Math.Round(latitude / step) * step;
    }

    private static double RoundLongitude(double latitude, double longitude, double meters)
    {
        var step = meters / (111_320d * Math.Max(0.2, Math.Cos(latitude * Math.PI / 180d)));
        return Math.Round(longitude / step) * step;
    }

    private static IReadOnlyList<string> ParseList(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return [];
        }

        try
        {
            return System.Text.Json.JsonSerializer.Deserialize<List<string>>(value) ?? [];
        }
        catch
        {
            return [];
        }
    }

    private sealed class NearbyUserSqlRow
    {
        public string Id { get; init; } = string.Empty;
        public string UserName { get; init; } = string.Empty;
        public string DisplayName { get; init; } = string.Empty;
        public string Bio { get; init; } = string.Empty;
        public string City { get; init; } = string.Empty;
        public string Gender { get; init; } = string.Empty;
        public string Mode { get; init; } = string.Empty;
        public string MatchPreference { get; init; } = string.Empty;
        public string PrivacyLevel { get; init; } = string.Empty;
        public string LocationGranularity { get; init; } = "nearby";
        public bool IsVisible { get; init; }
        public bool IsOnline { get; init; }
        public string ProfilePhotoUrl { get; init; } = string.Empty;
        public string Interests { get; init; } = string.Empty;
        public double? Latitude { get; init; }
        public double? Longitude { get; init; }
        public DateTimeOffset? LastSeenAt { get; init; }
        public int FollowersCount { get; init; }
        public int FollowingCount { get; init; }
        public int FriendsCount { get; init; }
        public int PulseScore { get; init; }
        public int PlacesVisited { get; init; }
        public int VibeTagsCreated { get; init; }
        public double DistanceMeters { get; init; }
        public bool ShareProfile { get; init; }
        public bool IsSignalActive { get; init; }
        public bool EnableDifferentialPrivacy { get; init; }
        public int KAnonymityLevel { get; init; }
    }

    private sealed record NearbyUserCandidate(
        NearbyUserDto Dto,
        int KAnonymityLevel,
        bool EnableDifferentialPrivacy
    )
    {
        public string Id => Dto.Id;
    }
}
