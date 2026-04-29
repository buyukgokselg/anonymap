using System.ComponentModel.DataAnnotations;

namespace PulseCity.Application.DTOs;

public sealed record PlaceSummaryDto(
    string PlaceId,
    string Name,
    string Vicinity,
    double Latitude,
    double Longitude,
    double Rating,
    int UserRatingsTotal,
    bool OpenNow,
    int PriceLevel,
    IReadOnlyList<string> Types,
    string? PhotoReference,
    int GooglePulseScore,
    int DensityScore,
    int TrendScore,
    int PulseScore,
    int CommunityScore,
    int LiveSignalScore,
    int AmbassadorScore,
    int SyntheticDemandScore,
    int SeedConfidence,
    int MomentScore,
    string DensityLabel,
    string TrendLabel,
    string DistanceLabel,
    double DistanceMeters,
    IReadOnlyList<string> PulseDriverTags,
    IReadOnlyDictionary<string, int> SeedSourceBreakdown,
    string PulseReason
);

public sealed record PlaceReviewDto(
    string Author,
    int Rating,
    string Text,
    string RelativeTime
);

public sealed record PlaceDetailDto(
    string PlaceId,
    string Name,
    string Address,
    string Phone,
    string Website,
    double Latitude,
    double Longitude,
    double Rating,
    int TotalRatings,
    bool IsOpen,
    int PriceLevel,
    IReadOnlyList<string> WeekdayText,
    IReadOnlyList<string> PhotoReferences,
    IReadOnlyList<PlaceReviewDto> Reviews,
    int GooglePulseScore,
    int DensityScore,
    int TrendScore,
    int PulseScore,
    int CommunityScore,
    int LiveSignalScore,
    int AmbassadorScore,
    int SyntheticDemandScore,
    int SeedConfidence,
    IReadOnlyList<string> PulseDriverTags,
    IReadOnlyDictionary<string, int> SeedSourceBreakdown,
    string PulseReason
);

public sealed class NearbyPlacesRequest
{
    [Range(-90, 90)]
    public double Latitude { get; set; }

    [Range(-180, 180)]
    public double Longitude { get; set; }

    [MaxLength(32)]
    public string ModeId { get; set; } = "kesif";

    [MaxLength(8)]
    public string LanguageCode { get; set; } = "tr";

    [Range(100, 50000)]
    public int Radius { get; set; } = 1500;

    public bool RequireOpenNow { get; set; }

    [MaxLength(16)]
    public string SortBy { get; set; } = "moment";
}

public sealed class PlaceDetailRequest
{
    [Range(-90, 90)]
    public double? Latitude { get; set; }

    [Range(-180, 180)]
    public double? Longitude { get; set; }

    [MaxLength(32)]
    public string ModeId { get; set; } = "kesif";

    [MaxLength(8)]
    public string LanguageCode { get; set; } = "tr";
}

public sealed record ForecastSlotDto(
    int OffsetHours,
    DateTimeOffset Time,
    string Label,
    int Score,
    int Confidence,
    PlaceSummaryDto TopPlace
);

public sealed class SavePlaceRequest
{
    [Required]
    [MaxLength(160)]
    public string PlaceId { get; set; } = string.Empty;

    [Required]
    [MaxLength(160)]
    public string PlaceName { get; set; } = string.Empty;

    [MaxLength(300)]
    public string Vicinity { get; set; } = string.Empty;

    public double? Latitude { get; set; }
    public double? Longitude { get; set; }
}

public sealed record SavedPlaceStateDto(string PlaceId, bool Saved);
