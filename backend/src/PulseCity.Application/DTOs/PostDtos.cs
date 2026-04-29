using System.ComponentModel.DataAnnotations;

namespace PulseCity.Application.DTOs;

public sealed record PostFeedItemDto(
    Guid Id,
    string UserId,
    string UserDisplayName,
    string UserProfilePhotoUrl,
    string Text,
    string Location,
    string PlaceId,
    double? Latitude,
    double? Longitude,
    IReadOnlyList<string> PhotoUrls,
    string? VideoUrl,
    double Rating,
    string VibeTag,
    string Type,
    int LikesCount,
    bool LikedByCurrentUser,
    bool SavedByCurrentUser,
    int CommentsCount,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt,
    string? UserMode = null,
    double? DistanceMeters = null
);

public sealed class CreatePostRequest
{
    [MaxLength(2000)]
    public string Text { get; set; } = string.Empty;

    [MaxLength(120)]
    public string Location { get; set; } = string.Empty;

    [MaxLength(160)]
    public string PlaceId { get; set; } = string.Empty;

    public double? Latitude { get; set; }
    public double? Longitude { get; set; }
    public List<string> PhotoUrls { get; set; } = [];
    public string? VideoUrl { get; set; }

    [Range(0, 5)]
    public double Rating { get; set; }

    [MaxLength(64)]
    public string VibeTag { get; set; } = string.Empty;

    [MaxLength(16)]
    public string Type { get; set; } = "post";
}

public sealed class AddPostCommentRequest
{
    [Required]
    [MaxLength(1000)]
    public string Text { get; set; } = string.Empty;
}

public sealed class UpdatePostRequest
{
    [MaxLength(2000)]
    public string Text { get; set; } = string.Empty;

    [MaxLength(120)]
    public string Location { get; set; } = string.Empty;

    [MaxLength(160)]
    public string PlaceId { get; set; } = string.Empty;

    public double? Latitude { get; set; }
    public double? Longitude { get; set; }
    public List<string> PhotoUrls { get; set; } = [];
    public string? VideoUrl { get; set; }

    [Range(0, 5)]
    public double Rating { get; set; }

    [MaxLength(64)]
    public string VibeTag { get; set; } = string.Empty;
}

public sealed class UpdatePostCommentRequest
{
    [Required]
    [MaxLength(1000)]
    public string Text { get; set; } = string.Empty;
}

public sealed record PostInteractionDto(Guid PostId, int LikesCount, bool LikedByCurrentUser);
public sealed record PostSaveDto(Guid PostId, bool SavedByCurrentUser);

public sealed record PostCommentDto(
    Guid Id,
    Guid PostId,
    string UserId,
    string UserDisplayName,
    string UserProfilePhotoUrl,
    string Text,
    DateTimeOffset CreatedAt
);

public sealed record PlaceCommunitySignalLookupDto(
    string PlaceId,
    string Name,
    string Vicinity
);

public sealed class PlaceCommunitySignalsRequest
{
    public List<PlaceCommunitySignalLookupDto> Places { get; set; } = [];
}

public sealed record PlaceCommunitySignalDto(
    string PlaceId,
    int Posts,
    int Shorts,
    int Likes,
    int Comments,
    int Creators
);
