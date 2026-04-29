namespace PulseCity.Infrastructure.Internal;

internal sealed class RawPlace
{
    public string PlaceId { get; init; } = string.Empty;
    public string Name { get; init; } = string.Empty;
    public string Vicinity { get; init; } = string.Empty;
    public string Address { get; init; } = string.Empty;
    public string Phone { get; init; } = string.Empty;
    public string Website { get; init; } = string.Empty;
    public double Latitude { get; init; }
    public double Longitude { get; init; }
    public double Rating { get; init; }
    public int UserRatingsTotal { get; init; }
    public bool OpenNow { get; init; }
    public int PriceLevel { get; init; }
    public List<string> Types { get; init; } = [];
    public List<string> PhotoReferences { get; init; } = [];
    public List<string> WeekdayText { get; init; } = [];
    public List<RawReview> Reviews { get; init; } = [];
}

internal readonly record struct RawReview(
    string Author,
    int Rating,
    string Text,
    string RelativeTime
);

internal readonly record struct CommunitySignals(
    int Posts,
    int Shorts,
    int Likes,
    int Comments,
    int Creators,
    int Saves = 0,
    int LiveVisitors = 0,
    int Ambassadors = 0,
    int SyntheticDemand = 0,
    IReadOnlyDictionary<string, int>? SourceBreakdown = null
);
