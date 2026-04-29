namespace PulseCity.Domain.Entities;

public sealed class SavedPlace
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string UserId { get; set; } = string.Empty;
    public string PlaceId { get; set; } = string.Empty;
    public string PlaceName { get; set; } = string.Empty;
    public string Vicinity { get; set; } = string.Empty;
    public double? Latitude { get; set; }
    public double? Longitude { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}
