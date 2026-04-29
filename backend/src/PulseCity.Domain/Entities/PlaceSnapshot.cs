namespace PulseCity.Domain.Entities;

public sealed class PlaceSnapshot
{
    public string PlaceId { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string Vicinity { get; set; } = string.Empty;
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public double Rating { get; set; }
    public int UserRatingsTotal { get; set; }
    public int PriceLevel { get; set; }
    public bool IsOpenNow { get; set; }
    public int GooglePulseScore { get; set; }
    public int DensityScore { get; set; }
    public int TrendScore { get; set; }
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;
}
