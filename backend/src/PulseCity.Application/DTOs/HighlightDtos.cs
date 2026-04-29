using System.ComponentModel.DataAnnotations;

namespace PulseCity.Application.DTOs;

public sealed record HighlightDto(
    Guid Id,
    string UserId,
    string Title,
    string CoverUrl,
    IReadOnlyList<string> MediaUrls,
    string Type,
    string TextColorHex,
    double TextOffsetX,
    double TextOffsetY,
    string? ModeTag,
    string? LocationLabel,
    string? PlaceId,
    bool ShowModeOverlay,
    bool ShowLocationOverlay,
    string EntryKind,
    DateTimeOffset? ExpiresAt,
    DateTimeOffset CreatedAt,
    bool SeenByCurrentUser,
    int ViewCount,
    IReadOnlyList<StoryViewerDto> Viewers
);

public sealed record StoryViewerDto(
    string UserId,
    string UserName,
    string DisplayName,
    string ProfilePhotoUrl,
    DateTimeOffset ViewedAt
);

public sealed class CreateHighlightRequest
{
    [MaxLength(80)]
    public string Title { get; set; } = string.Empty;

    [Required]
    [MaxLength(512)]
    public string CoverUrl { get; set; } = string.Empty;

    public List<string> MediaUrls { get; set; } = [];

    [MaxLength(24)]
    public string Type { get; set; } = "image";

    [MaxLength(16)]
    public string TextColorHex { get; set; } = "#FFFFFF";

    [Range(-1, 1)]
    public double TextOffsetX { get; set; }

    [Range(-1, 1)]
    public double TextOffsetY { get; set; }

    [MaxLength(32)]
    public string? ModeTag { get; set; }

    [MaxLength(160)]
    public string? LocationLabel { get; set; }

    [MaxLength(160)]
    public string? PlaceId { get; set; }

    public bool ShowModeOverlay { get; set; }

    public bool ShowLocationOverlay { get; set; }

    [Range(1, 168)]
    public int? DurationHours { get; set; }
}
