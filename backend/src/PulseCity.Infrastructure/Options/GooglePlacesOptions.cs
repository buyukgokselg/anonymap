namespace PulseCity.Infrastructure.Options;

public sealed class GooglePlacesOptions
{
    public const string SectionName = "PulseCity:GooglePlaces";

    public string ApiKey { get; set; } = string.Empty;
    public int NearbyCacheMinutes { get; set; } = 5;
    public int DetailCacheMinutes { get; set; } = 30;
}
