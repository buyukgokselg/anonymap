using PulseCity.Domain.Enums;

namespace PulseCity.Domain.Entities;

public sealed class Post
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string UserId { get; set; } = string.Empty;
    public string Text { get; set; } = string.Empty;
    public string LocationName { get; set; } = string.Empty;
    public string PlaceId { get; set; } = string.Empty;
    public double? Latitude { get; set; }
    public double? Longitude { get; set; }
    public List<string> PhotoUrls { get; set; } = [];
    public string? VideoUrl { get; set; }
    public double Rating { get; set; }
    public string VibeTag { get; set; } = string.Empty;
    public int CommentsCount { get; set; }
    public PostType Type { get; set; } = PostType.Post;
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;
}
