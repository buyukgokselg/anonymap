using System.ComponentModel.DataAnnotations;
using System.IO;

namespace PulseCity.Application.DTOs;

public sealed record UserSummaryDto(
    string Id,
    string UserName,
    string DisplayName,
    string Bio,
    string City,
    string Gender,
    string Mode,
    string PrivacyLevel,
    bool IsVisible,
    bool IsOnline,
    string ProfilePhotoUrl,
    IReadOnlyList<string> Interests,
    int FollowersCount,
    int FollowingCount,
    int FriendsCount,
    int PulseScore,
    /// <summary>Aldığı aktivite puanlarının ortalaması (0..5). 0 = henüz puanlanmamış.</summary>
    double ActivityRatingAverage = 0,
    int ActivityRatingCount = 0
);

public sealed record PublicUserProfileDto(
    string Id,
    string UserName,
    string DisplayName,
    string Bio,
    string City,
    string Gender,
    string Mode,
    string MatchPreference,
    string PrivacyLevel,
    bool IsVisible,
    bool IsOnline,
    string ProfilePhotoUrl,
    IReadOnlyList<string> Interests,
    DateTimeOffset? LastSeenAt,
    DateTimeOffset CreatedAt,
    int FollowersCount,
    int FollowingCount,
    int FriendsCount,
    int PulseScore,
    int PlacesVisited,
    int VibeTagsCreated,
    Guid? PinnedPostId,
    DateTimeOffset? PinnedAt
);

public sealed record UserProfileDto(
    string Id,
    string Email,
    string UserName,
    string DisplayName,
    string Bio,
    string City,
    string Website,
    string FirstName,
    string LastName,
    string Gender,
    DateTime? BirthDate,
    int Age,
    string Purpose,
    string MatchPreference,
    string Mode,
    string PrivacyLevel,
    string PreferredLanguage,
    string LocationGranularity,
    bool EnableDifferentialPrivacy,
    int KAnonymityLevel,
    bool AllowAnalytics,
    bool IsVisible,
    bool IsOnline,
    string ProfilePhotoUrl,
    IReadOnlyList<string> PhotoUrls,
    IReadOnlyList<string> Interests,
    double? Latitude,
    double? Longitude,
    DateTimeOffset? LastSeenAt,
    DateTimeOffset CreatedAt,
    int FollowersCount,
    int FollowingCount,
    int FriendsCount,
    int PulseScore,
    int PlacesVisited,
    int VibeTagsCreated,
    Guid? PinnedPostId,
    DateTimeOffset? PinnedAt,
    string Orientation,
    string RelationshipIntent,
    int? HeightCm,
    string DrinkingStatus,
    string SmokingStatus,
    bool IsPhotoVerified,
    string VerificationStatus,
    DateTimeOffset? VerificationSubmittedAt,
    IReadOnlyDictionary<string, string> DatingPrompts,
    IReadOnlyList<string> LookingForModes,
    IReadOnlyList<string> Dealbreakers,
    IReadOnlyDictionary<string, bool> EnabledFeatures
);

public sealed record NearbyUserDto(
    string Id,
    string UserName,
    string DisplayName,
    string Bio,
    string City,
    string Gender,
    string Mode,
    string MatchPreference,
    string PrivacyLevel,
    string LocationGranularity,
    bool IsVisible,
    bool IsOnline,
    string ProfilePhotoUrl,
    IReadOnlyList<string> Interests,
    double? Latitude,
    double? Longitude,
    DateTimeOffset? LastSeenAt,
    int FollowersCount,
    int FollowingCount,
    int FriendsCount,
    int PulseScore,
    int PlacesVisited,
    int VibeTagsCreated,
    double DistanceMeters,
    bool ShareProfile,
    bool IsSignalActive
);

public sealed class UpdateUserProfileRequest
{
    [MaxLength(64)]
    public string UserName { get; set; } = string.Empty;

    [MaxLength(64)]
    public string DisplayName { get; set; } = string.Empty;

    [MaxLength(160)]
    public string Bio { get; set; } = string.Empty;

    [MaxLength(120)]
    public string City { get; set; } = string.Empty;

    [MaxLength(256)]
    public string Website { get; set; } = string.Empty;

    [MaxLength(64)]
    public string FirstName { get; set; } = string.Empty;

    [MaxLength(64)]
    public string LastName { get; set; } = string.Empty;

    [MaxLength(32)]
    public string Gender { get; set; } = string.Empty;

    public DateTime? BirthDate { get; set; }

    [Range(0, 120)]
    public int Age { get; set; }

    [MaxLength(64)]
    public string Purpose { get; set; } = string.Empty;

    [MaxLength(16)]
    public string MatchPreference { get; set; } = "auto";

    [MaxLength(32)]
    public string Mode { get; set; } = "chill";

    [MaxLength(32)]
    public string PrivacyLevel { get; set; } = "full";

    [MaxLength(8)]
    public string PreferredLanguage { get; set; } = "tr";

    [MaxLength(24)]
    public string LocationGranularity { get; set; } = "nearby";

    public bool EnableDifferentialPrivacy { get; set; } = true;

    [Range(2, 10)]
    public int KAnonymityLevel { get; set; } = 3;

    public bool AllowAnalytics { get; set; } = true;

    public bool IsVisible { get; set; } = true;

    [MaxLength(512)]
    public string ProfilePhotoUrl { get; set; } = string.Empty;

    public List<string> PhotoUrls { get; set; } = [];
    public List<string> Interests { get; set; } = [];
    public double? Latitude { get; set; }
    public double? Longitude { get; set; }

    // ── Dating fields ──
    [MaxLength(24)]
    public string Orientation { get; set; } = string.Empty;

    [MaxLength(24)]
    public string RelationshipIntent { get; set; } = string.Empty;

    [Range(120, 230)]
    public int? HeightCm { get; set; }

    [MaxLength(24)]
    public string DrinkingStatus { get; set; } = string.Empty;

    [MaxLength(24)]
    public string SmokingStatus { get; set; } = string.Empty;

    public Dictionary<string, string> DatingPrompts { get; set; } = new();
    public List<string> LookingForModes { get; set; } = [];
    public List<string> Dealbreakers { get; set; } = [];
}

public sealed class UpdatePresenceRequest
{
    [Range(-90, 90)]
    public double Latitude { get; set; }

    [Range(-180, 180)]
    public double Longitude { get; set; }

    [MaxLength(120)]
    public string City { get; set; } = string.Empty;

    [MaxLength(32)]
    public string Mode { get; set; } = "chill";

    public bool ShareProfile { get; set; } = true;
    public bool IsSignalActive { get; set; }
    public bool IsOnline { get; set; } = true;
}

public sealed class UpdateOnlineStatusRequest
{
    public bool IsOnline { get; set; }
}

public sealed class NearbyUsersRequest
{
    [Range(-90, 90)]
    public double Latitude { get; set; }

    [Range(-180, 180)]
    public double Longitude { get; set; }

    [Range(0.1, 50)]
    public double RadiusKm { get; set; } = 1;

    public bool SignalOnly { get; set; }
}

public sealed record DiscoverPersonDto(
    string Id,
    string DisplayName,
    string UserName,
    string Bio,
    string City,
    string Gender,
    int Age,
    string Mode,
    string ProfilePhotoUrl,
    IReadOnlyList<string> PhotoUrls,
    IReadOnlyList<string> Interests,
    string Orientation,
    string RelationshipIntent,
    int? HeightCm,
    string DrinkingStatus,
    string SmokingStatus,
    bool IsPhotoVerified,
    IReadOnlyDictionary<string, string> DatingPrompts,
    double DistanceKm,
    int ChemistryScore,
    string ChemistryTier,
    IReadOnlyList<string> SharedInterests,
    /// <summary>Şu an yayınlanmış (gelecek tarihli) aktivite sayısı — discover badge için.</summary>
    int HostingActivityCount
);

public sealed record DiscoverPeopleResponseDto(
    IReadOnlyList<DiscoverPersonDto> Items,
    int TotalCandidates,
    string Cursor
);

public sealed class DiscoverPeopleQuery
{
    [Range(-90, 90)]
    public double? Latitude { get; set; }

    [Range(-180, 180)]
    public double? Longitude { get; set; }

    [Range(1, 200)]
    public double RadiusKm { get; set; } = 25;

    [Range(1, 50)]
    public int Take { get; set; } = 10;

    [Range(0, 1000)]
    public int Skip { get; set; }

    [MaxLength(32)]
    public string? Mode { get; set; }

    [Range(18, 99)]
    public int? MinAge { get; set; }

    [Range(18, 99)]
    public int? MaxAge { get; set; }

    public bool? VerifiedOnly { get; set; }
}

public sealed class RecordDiscoverPassRequest
{
    [Required]
    [MaxLength(128)]
    public string TargetUserId { get; set; } = string.Empty;
}

public sealed record UserDataExportDto(
    Guid Id,
    string Status,
    string FileName,
    string DownloadUrl,
    long FileSizeBytes,
    DateTimeOffset CreatedAt,
    DateTimeOffset ExpiresAt
);

public sealed record UserDataExportDownloadResult(
    string FileName,
    string ContentType,
    Stream Content
);

/// <summary>
/// Foto doğrulama başvurusu — kullanıcı bir selfie yükler ve gestür belirtir.
/// SelfieUrl uploads endpoint'inden alınmış olmalı.
/// </summary>
public sealed class SubmitPhotoVerificationRequest
{
    [Required]
    [MaxLength(512)]
    public string SelfieUrl { get; set; } = string.Empty;

    /// <summary>
    /// İstenen doz/jest — "smile" | "peace" | "thumbs_up" | "wave" | "wink".
    /// Sunucu sadece bilgi amaçlı tutar (ML moderasyonu için ipucu).
    /// </summary>
    [MaxLength(32)]
    public string Gesture { get; set; } = string.Empty;
}

/// <summary>
/// Foto doğrulama özeti — UI hangi durum kartını göstereceğini belirler.
/// </summary>
public sealed record PhotoVerificationStatusDto(
    /// <summary>"none" | "pending" | "approved" | "rejected"</summary>
    string Status,
    bool IsPhotoVerified,
    DateTimeOffset? SubmittedAt
);
