using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Distributed;
using Microsoft.Extensions.Options;
using PulseCity.Application.DTOs;
using PulseCity.Application.Interfaces;
using PulseCity.Domain.Entities;
using PulseCity.Infrastructure.Data;
using PulseCity.Infrastructure.Internal;
using PulseCity.Infrastructure.Options;

namespace PulseCity.Infrastructure.Services;

public sealed class PlacesService(
    HttpClient httpClient,
    IDistributedCache cache,
    IOptions<GooglePlacesOptions> options,
    PulseCityDbContext dbContext
) : IPlacesService
{
    private const string BaseUrl = "https://maps.googleapis.com/maps/api/place";
    private static readonly JsonSerializerOptions SerializerOptions = new(JsonSerializerDefaults.Web);

    public async Task<IReadOnlyList<PlaceSummaryDto>> GetNearbyPlacesAsync(
        NearbyPlacesRequest request,
        CancellationToken cancellationToken = default
    )
    {
        var languageCode = NormalizeLanguageCode(request.LanguageCode);
        var sortBy = NormalizeSortBy(request.SortBy);
        var cacheKey =
            $"places:nearby:{request.ModeId}:{languageCode}:{request.RequireOpenNow}:{sortBy}:{Math.Round(request.Latitude, 4)}:{Math.Round(request.Longitude, 4)}:{request.Radius}";
        var cached = await cache.GetStringAsync(cacheKey, cancellationToken);
        if (!string.IsNullOrWhiteSpace(cached))
        {
            var cachedPlaces = JsonSerializer.Deserialize<List<PlaceSummaryDto>>(cached, SerializerOptions);
            if (cachedPlaces is { Count: > 0 })
            {
                return cachedPlaces;
            }
        }

        if (string.IsNullOrWhiteSpace(options.Value.ApiKey))
        {
            return [];
        }

        var types = PlacesScoring.ModeTypes.TryGetValue(request.ModeId, out var modeTypes)
            ? modeTypes
            : ["restaurant", "cafe"];

        var rawPlaces = new List<RawPlace>();
        foreach (var type in types.Take(3))
        {
            var url =
                $"{BaseUrl}/nearbysearch/json?location={request.Latitude},{request.Longitude}&radius={request.Radius}&type={Uri.EscapeDataString(type)}&key={options.Value.ApiKey}&language={NormalizeGoogleLanguage(languageCode)}";
            using var response = await httpClient.GetAsync(url, cancellationToken);
            if (!response.IsSuccessStatusCode)
            {
                continue;
            }

            using var document = JsonDocument.Parse(await response.Content.ReadAsStreamAsync(cancellationToken));
            if (!document.RootElement.TryGetProperty("results", out var results))
            {
                continue;
            }

            foreach (var result in results.EnumerateArray())
            {
                var mapped = PlacesJsonParser.MapNearbyResult(result);
                if (mapped is null || rawPlaces.Any(entry => entry.PlaceId == mapped.PlaceId))
                {
                    continue;
                }

                rawPlaces.Add(mapped);
            }
        }

        var communityByPlaceId = await BuildCommunitySignalsAsync(rawPlaces, cancellationToken);

        var ranked = rawPlaces
            .Select(place => PlacesScoring.BuildPlaceSummary(place, request, communityByPlaceId.GetValueOrDefault(place.PlaceId), languageCode))
            .Where(place => !request.RequireOpenNow || place.OpenNow)
            .ToList();

        var ordered = sortBy == "popular"
            ? ranked
                .OrderByDescending(CalculatePopularSortScore)
                .ThenByDescending(place => place.PulseScore)
            : ranked
                .OrderByDescending(place => place.MomentScore)
                .ThenByDescending(place => place.PulseScore);
        var finalPlaces = ordered
            .Take(sortBy == "popular" ? 30 : 20)
            .ToList();

        await UpsertPlaceSnapshotsAsync(finalPlaces, cancellationToken);
        await cache.SetStringAsync(
            cacheKey,
            JsonSerializer.Serialize(finalPlaces, SerializerOptions),
            new DistributedCacheEntryOptions
            {
                AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(Math.Max(1, options.Value.NearbyCacheMinutes)),
            },
            cancellationToken
        );

        return finalPlaces;
    }

    public async Task<PlaceDetailDto?> GetPlaceDetailAsync(
        string placeId,
        PlaceDetailRequest request,
        CancellationToken cancellationToken = default
    )
    {
        var languageCode = NormalizeLanguageCode(request.LanguageCode);
        if (string.IsNullOrWhiteSpace(placeId) || string.IsNullOrWhiteSpace(options.Value.ApiKey))
        {
            return null;
        }

        var cacheKey = $"places:detail:{placeId}:{request.ModeId}:{languageCode}:{request.Latitude}:{request.Longitude}";
        var cached = await cache.GetStringAsync(cacheKey, cancellationToken);
        if (!string.IsNullOrWhiteSpace(cached))
        {
            return JsonSerializer.Deserialize<PlaceDetailDto>(cached, SerializerOptions);
        }

        var url =
            $"{BaseUrl}/details/json?place_id={Uri.EscapeDataString(placeId)}&fields=name,formatted_address,formatted_phone_number,website,rating,reviews,opening_hours,photos,geometry,types,price_level,user_ratings_total,place_id&key={options.Value.ApiKey}&language={NormalizeGoogleLanguage(languageCode)}";
        using var response = await httpClient.GetAsync(url, cancellationToken);
        if (!response.IsSuccessStatusCode)
        {
            return null;
        }

        using var document = JsonDocument.Parse(await response.Content.ReadAsStreamAsync(cancellationToken));
        if (!document.RootElement.TryGetProperty("result", out var result))
        {
            return null;
        }

        var rawPlace = PlacesJsonParser.MapDetailResult(result);
        if (rawPlace is null)
        {
            return null;
        }

        var summary = PlacesScoring.BuildPlaceSummary(
            rawPlace,
            new NearbyPlacesRequest
            {
                Latitude = request.Latitude ?? rawPlace.Latitude,
                Longitude = request.Longitude ?? rawPlace.Longitude,
                ModeId = request.ModeId,
                LanguageCode = languageCode,
                Radius = 1500,
            },
            await BuildCommunitySignalsForPlaceAsync(rawPlace, cancellationToken),
            languageCode
        );

        var detail = new PlaceDetailDto(
            rawPlace.PlaceId,
            rawPlace.Name,
            rawPlace.Address,
            rawPlace.Phone,
            rawPlace.Website,
            rawPlace.Latitude,
            rawPlace.Longitude,
            rawPlace.Rating,
            rawPlace.UserRatingsTotal,
            rawPlace.OpenNow,
            rawPlace.PriceLevel,
            rawPlace.WeekdayText,
            rawPlace.PhotoReferences,
            rawPlace.Reviews.Select(review => new PlaceReviewDto(review.Author, review.Rating, review.Text, review.RelativeTime)).ToList(),
            summary.GooglePulseScore,
            summary.DensityScore,
            summary.TrendScore,
            summary.PulseScore,
            summary.CommunityScore,
            summary.LiveSignalScore,
            summary.AmbassadorScore,
            summary.SyntheticDemandScore,
            summary.SeedConfidence,
            summary.PulseDriverTags,
            summary.SeedSourceBreakdown,
            summary.PulseReason
        );

        await UpsertPlaceSnapshotsAsync([summary], cancellationToken);
        await cache.SetStringAsync(
            cacheKey,
            JsonSerializer.Serialize(detail, SerializerOptions),
            new DistributedCacheEntryOptions
            {
                AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(Math.Max(5, options.Value.DetailCacheMinutes)),
            },
            cancellationToken
        );

        return detail;
    }

    public async Task<IReadOnlyList<ForecastSlotDto>> GetForecastAsync(
        NearbyPlacesRequest request,
        CancellationToken cancellationToken = default
    )
    {
        var languageCode = NormalizeLanguageCode(request.LanguageCode);
        var nearbyPlaces = await GetNearbyPlacesAsync(
            new NearbyPlacesRequest
            {
                Latitude = request.Latitude,
                Longitude = request.Longitude,
                ModeId = request.ModeId,
                LanguageCode = languageCode,
                Radius = request.Radius,
                RequireOpenNow = false,
                SortBy = request.SortBy,
            },
            cancellationToken
        );

        if (nearbyPlaces.Count == 0)
        {
            return [];
        }

        var offsets = new[] { 0, 1, 2, 4, 6 };
        var baseTime = DateTimeOffset.UtcNow;
        return offsets.Select(offset =>
        {
            var slotTime = baseTime.AddHours(offset);
            var topPlace = nearbyPlaces
                .OrderByDescending(place => PlacesScoring.CalculateMomentScore(place, request.ModeId, slotTime))
                .ThenByDescending(place => place.PulseScore)
                .First();

            var score = PlacesScoring.CalculateMomentScore(topPlace, request.ModeId, slotTime);
            return new ForecastSlotDto(
                offset,
                slotTime,
                PlacesScoring.FormatForecastLabel(offset, languageCode),
                score,
                PlacesScoring.CalculateForecastConfidence(topPlace, offset),
                topPlace with { MomentScore = score }
            );
        }).ToList();
    }

    public async Task<SavedPlaceStateDto> ToggleSaveAsync(
        string userId,
        SavePlaceRequest request,
        CancellationToken cancellationToken = default
    )
    {
        var existing = await dbContext.SavedPlaces
            .FirstOrDefaultAsync(entry => entry.UserId == userId && entry.PlaceId == request.PlaceId, cancellationToken);

        var saved = existing is null;
        if (existing is null)
        {
            dbContext.SavedPlaces.Add(
                new SavedPlace
                {
                    UserId = userId,
                    PlaceId = request.PlaceId,
                    PlaceName = request.PlaceName.Trim(),
                    Vicinity = request.Vicinity.Trim(),
                    Latitude = request.Latitude,
                    Longitude = request.Longitude,
                    CreatedAt = DateTimeOffset.UtcNow,
                }
            );
        }
        else
        {
            dbContext.SavedPlaces.Remove(existing);
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        return new SavedPlaceStateDto(request.PlaceId, saved);
    }

    public async Task<IReadOnlyList<PlaceCommunitySignalDto>> GetCommunitySignalsAsync(
        PlaceCommunitySignalsRequest request,
        CancellationToken cancellationToken = default
    )
    {
        var lookups = request.Places
            .Where(entry => !string.IsNullOrWhiteSpace(entry.PlaceId) || !string.IsNullOrWhiteSpace(entry.Name))
            .ToList();
        if (lookups.Count == 0)
        {
            return [];
        }

        var placeIds = lookups
            .Select(entry => entry.PlaceId.Trim())
            .Where(entry => !string.IsNullOrWhiteSpace(entry))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();

        var directSignals = await BuildCommunitySignalsAsync(
            lookups
                .Select(entry => new RawPlace
                {
                    PlaceId = entry.PlaceId.Trim(),
                    Name = entry.Name.Trim(),
                    Vicinity = entry.Vicinity.Trim(),
                })
                .Where(entry => !string.IsNullOrWhiteSpace(entry.PlaceId))
                .ToList(),
            cancellationToken
        );
        var results = new List<PlaceCommunitySignalDto>(lookups.Count);

        var fallbackPosts = await dbContext.Posts.AsNoTracking()
            .OrderByDescending(entry => entry.CreatedAt)
            .Take(160)
            .ToListAsync(cancellationToken);
        var fallbackPostIds = fallbackPosts.Select(entry => entry.Id).ToList();
        var fallbackLikes = fallbackPostIds.Count == 0
            ? []
            : await dbContext.PostLikes.AsNoTracking()
                .Where(entry => fallbackPostIds.Contains(entry.PostId))
                .ToListAsync(cancellationToken);
        var fallbackComments = fallbackPostIds.Count == 0
            ? []
            : await dbContext.PostComments.AsNoTracking()
                .Where(entry => fallbackPostIds.Contains(entry.PostId))
                .ToListAsync(cancellationToken);

        foreach (var lookup in lookups)
        {
            var placeId = lookup.PlaceId.Trim();
            if (!string.IsNullOrWhiteSpace(placeId) && directSignals.TryGetValue(placeId, out var direct))
            {
                results.Add(new PlaceCommunitySignalDto(placeId, direct.Posts, direct.Shorts, direct.Likes, direct.Comments, direct.Creators));
                continue;
            }

            var normalizedName = lookup.Name.Trim().ToLowerInvariant();
            var normalizedVicinity = lookup.Vicinity.Trim().ToLowerInvariant();
            var matchedPosts = fallbackPosts.Where(post =>
            {
                var location = post.LocationName.ToLowerInvariant();
                var text = post.Text.ToLowerInvariant();
                var matchesName = !string.IsNullOrWhiteSpace(normalizedName)
                    && (location.Contains(normalizedName) || text.Contains(normalizedName));
                var matchesVicinity = !string.IsNullOrWhiteSpace(normalizedVicinity)
                    && (location.Contains(normalizedVicinity) || text.Contains(normalizedVicinity));
                return matchesName || matchesVicinity;
            }).ToList();

            var matchedIds = matchedPosts.Select(entry => entry.Id).ToHashSet();
            results.Add(new PlaceCommunitySignalDto(
                placeId,
                matchedPosts.Count(entry => entry.Type == Domain.Enums.PostType.Post),
                matchedPosts.Count(entry => entry.Type == Domain.Enums.PostType.Short),
                fallbackLikes.Count(entry => matchedIds.Contains(entry.PostId)),
                fallbackComments.Count(entry => matchedIds.Contains(entry.PostId)),
                matchedPosts.Select(entry => entry.UserId).Distinct().Count()
            ));
        }

        return results;
    }

    private async Task<Dictionary<string, CommunitySignals>> BuildCommunitySignalsAsync(
        IReadOnlyList<RawPlace> places,
        CancellationToken cancellationToken
    )
    {
        if (places.Count == 0)
        {
            return [];
        }

        var placeIds = places.Select(entry => entry.PlaceId).ToList();

        var posts = await dbContext.Posts.AsNoTracking()
            .Where(entry => placeIds.Contains(entry.PlaceId))
            .Select(entry => new { entry.Id, entry.PlaceId, entry.Type, entry.UserId })
            .ToListAsync(cancellationToken);
        var savedPlaces = await dbContext.SavedPlaces.AsNoTracking()
            .Where(entry => placeIds.Contains(entry.PlaceId))
            .Select(entry => new { entry.PlaceId, entry.UserId })
            .ToListAsync(cancellationToken);
        var postIds = posts.Select(entry => entry.Id).ToList();
        var likes = postIds.Count == 0
            ? []
            : await dbContext.PostLikes.AsNoTracking().Where(entry => postIds.Contains(entry.PostId)).ToListAsync(cancellationToken);
        var comments = postIds.Count == 0
            ? []
            : await dbContext.PostComments.AsNoTracking().Where(entry => postIds.Contains(entry.PostId)).ToListAsync(cancellationToken);

        var creatorIds = posts.Select(entry => entry.UserId).Distinct().ToList();
        var creators = creatorIds.Count == 0
            ? new Dictionary<string, (int Followers, int Friends, int PulseScore)>()
            : await dbContext.Users.AsNoTracking()
                .Where(entry => creatorIds.Contains(entry.Id))
                .ToDictionaryAsync(
                    entry => entry.Id,
                    entry => (
                        Followers: entry.FollowersCount,
                        Friends: entry.FriendsCount,
                        PulseScore: entry.PulseScore
                    ),
                    cancellationToken
                );

        var minLat = places.Min(entry => entry.Latitude) - 0.02;
        var maxLat = places.Max(entry => entry.Latitude) + 0.02;
        var minLng = places.Min(entry => entry.Longitude) - 0.02;
        var maxLng = places.Max(entry => entry.Longitude) + 0.02;
        var livePresences = await dbContext.Presences.AsNoTracking()
            .Where(entry =>
                entry.IsSignalActive
                && entry.UpdatedAt >= DateTimeOffset.UtcNow.AddMinutes(-30)
                && entry.Latitude >= minLat
                && entry.Latitude <= maxLat
                && entry.Longitude >= minLng
                && entry.Longitude <= maxLng
            )
            .ToListAsync(cancellationToken);

        return places.ToDictionary(
            place => place.PlaceId,
            place =>
            {
                var placePosts = posts.Where(entry => entry.PlaceId == place.PlaceId).ToList();
                var groupedPostIds = placePosts.Select(item => item.Id).ToHashSet();
                var savesCount = savedPlaces.Count(entry => entry.PlaceId == place.PlaceId);
                var liveVisitors = livePresences.Count(entry =>
                    PlacesScoring.CalculateDistanceMeters(
                        entry.Latitude,
                        entry.Longitude,
                        place.Latitude,
                        place.Longitude
                    ) <= 280
                );
                var ambassadorCount = placePosts
                    .Select(item => item.UserId)
                    .Distinct()
                    .Count(userId =>
                    {
                        if (!creators.TryGetValue(userId, out var creator))
                        {
                            return false;
                        }

                        return creator.PulseScore >= 60
                            || creator.Followers >= 10
                            || (creator.Followers + creator.Friends) >= 18;
                    });
                var syntheticDemand = (int)Math.Clamp(
                    (Math.Log(place.UserRatingsTotal + 1, 5000) * 28)
                    + (place.OpenNow ? 12 : 4)
                    + (liveVisitors * 10)
                    + (savesCount * 4)
                    - (placePosts.Count * 3),
                    0,
                    100
                );
                var sourceBreakdown = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase)
                {
                    ["google"] = Math.Clamp(place.UserRatingsTotal / 20, 0, 100),
                    ["posts"] = placePosts.Count(item => item.Type == Domain.Enums.PostType.Post),
                    ["shorts"] = placePosts.Count(item => item.Type == Domain.Enums.PostType.Short),
                    ["saves"] = savesCount,
                    ["live"] = liveVisitors,
                    ["ambassadors"] = ambassadorCount,
                    ["synthetic"] = syntheticDemand,
                };

                return new CommunitySignals(
                    placePosts.Count(item => item.Type == Domain.Enums.PostType.Post),
                    placePosts.Count(item => item.Type == Domain.Enums.PostType.Short),
                    likes.Count(item => groupedPostIds.Contains(item.PostId)),
                    comments.Count(item => groupedPostIds.Contains(item.PostId)),
                    placePosts.Select(item => item.UserId).Distinct().Count(),
                    savesCount,
                    liveVisitors,
                    ambassadorCount,
                    syntheticDemand,
                    sourceBreakdown
                );
            }
        );
    }

    private async Task<CommunitySignals> BuildCommunitySignalsForPlaceAsync(
        RawPlace place,
        CancellationToken cancellationToken
    )
    {
        var dictionary = await BuildCommunitySignalsAsync([place], cancellationToken);
        return dictionary.GetValueOrDefault(place.PlaceId);
    }

    private async Task UpsertPlaceSnapshotsAsync(
        IReadOnlyList<PlaceSummaryDto> places,
        CancellationToken cancellationToken
    )
    {
        if (places.Count == 0)
        {
            return;
        }

        var placeIds = places.Select(entry => entry.PlaceId).ToList();
        var existing = await dbContext.PlaceSnapshots
            .Where(entry => placeIds.Contains(entry.PlaceId))
            .ToDictionaryAsync(entry => entry.PlaceId, cancellationToken);

        foreach (var place in places)
        {
            if (!existing.TryGetValue(place.PlaceId, out var snapshot))
            {
                snapshot = new PlaceSnapshot { PlaceId = place.PlaceId };
                dbContext.PlaceSnapshots.Add(snapshot);
            }

            snapshot.Name = place.Name;
            snapshot.Vicinity = place.Vicinity;
            snapshot.Latitude = place.Latitude;
            snapshot.Longitude = place.Longitude;
            snapshot.Rating = place.Rating;
            snapshot.UserRatingsTotal = place.UserRatingsTotal;
            snapshot.PriceLevel = place.PriceLevel;
            snapshot.IsOpenNow = place.OpenNow;
            snapshot.GooglePulseScore = place.GooglePulseScore;
            snapshot.DensityScore = place.DensityScore;
            snapshot.TrendScore = place.TrendScore;
            snapshot.UpdatedAt = DateTimeOffset.UtcNow;
        }

        await dbContext.SaveChangesAsync(cancellationToken);
    }

    private static string NormalizeLanguageCode(string? languageCode)
    {
        return languageCode?.Trim().ToLowerInvariant() switch
        {
            "en" => "en",
            "de" => "de",
            _ => "tr",
        };
    }

    private static string NormalizeSortBy(string? sortBy)
    {
        var trimmed = (sortBy ?? string.Empty).Trim().ToLowerInvariant();
        return trimmed == "popular" ? "popular" : "moment";
    }

    private static string NormalizeGoogleLanguage(string languageCode)
    {
        return languageCode switch
        {
            "en" => "en",
            "de" => "de",
            _ => "tr",
        };
    }

    private static double CalculatePopularSortScore(PlaceSummaryDto place)
    {
        var reviewVolume = Math.Clamp(place.UserRatingsTotal / 20.0, 0, 100);
        var metroDistanceBias = Math.Clamp(100 - (place.DistanceMeters / 1200.0), 0, 100);
        var openBoost = place.OpenNow ? 12.0 : 0.0;

        return (place.PulseScore * 0.40)
            + (place.Rating * 10.0)
            + (reviewVolume * 0.20)
            + (place.CommunityScore * 0.16)
            + (place.TrendScore * 0.08)
            + (metroDistanceBias * 0.08)
            + openBoost;
    }
}
