namespace PulseCity.Domain.Entities;

public sealed class Highlight
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string UserId { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string CoverUrl { get; set; } = string.Empty;
    public List<string> MediaUrls { get; set; } = [];
    public string Type { get; set; } = "image";
    public string TextColorHex { get; set; } = "#FFFFFF";
    public double TextOffsetX { get; set; }
    public double TextOffsetY { get; set; }
    public string? ModeTag { get; set; }
    public string? LocationLabel { get; set; }
    public string? PlaceId { get; set; }
    public bool ShowModeOverlay { get; set; }
    public bool ShowLocationOverlay { get; set; }
    public string EntryKind { get; set; } = "highlight";
    public DateTimeOffset? ExpiresAt { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}
