using System.ComponentModel.DataAnnotations;

namespace PulseCity.Application.DTOs;

/// <summary>Aktivite kart/detay görüntüleme DTO'su.</summary>
public sealed record ActivityDto(
    Guid Id,
    UserSummaryDto Host,
    string Title,
    string Description,
    string Category,
    string Mode,
    string? CoverImageUrl,
    string LocationName,
    string? LocationAddress,
    double Latitude,
    double Longitude,
    string City,
    string? PlaceId,
    DateTimeOffset StartsAt,
    DateTimeOffset? EndsAt,
    int? MaxParticipants,
    int CurrentParticipantCount,
    string Visibility,
    string JoinPolicy,
    bool RequiresVerification,
    IReadOnlyList<string> Interests,
    int? MinAge,
    int? MaxAge,
    string PreferredGender,
    string Status,
    string? CancellationReason,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt,
    /// <summary>Caller'ın bu aktivitedeki katılım durumu — null|requested|approved|declined|cancelled|host.</summary>
    string? ViewerParticipationStatus,
    /// <summary>Caller host mu?</summary>
    bool ViewerIsHost,
    /// <summary>Detayda gösterilen ilk N onaylı katılımcı (avatar stack için).</summary>
    IReadOnlyList<UserSummaryDto> SampleParticipants,
    /// <summary>"" = tek seferlik, "weekly" | "biweekly" | "monthly".</summary>
    string RecurrenceRule,
    DateTimeOffset? RecurrenceUntil
);

public sealed class CreateActivityRequest
{
    [Required, MaxLength(160)]
    public string Title { get; set; } = string.Empty;

    [MaxLength(2000)]
    public string Description { get; set; } = string.Empty;

    [Required, MaxLength(32)]
    public string Category { get; set; } = "Other";

    [MaxLength(32)]
    public string Mode { get; set; } = "chill";

    [MaxLength(512)]
    public string? CoverImageUrl { get; set; }

    [Required, MaxLength(200)]
    public string LocationName { get; set; } = string.Empty;

    [MaxLength(400)]
    public string? LocationAddress { get; set; }

    [Range(-90, 90)]
    public double Latitude { get; set; }

    [Range(-180, 180)]
    public double Longitude { get; set; }

    [Required, MaxLength(120)]
    public string City { get; set; } = string.Empty;

    /// <summary>Google Places ID — autocomplete'ten seçilen mekânın referansı. null = manuel giriş.</summary>
    [MaxLength(128)]
    public string? PlaceId { get; set; }

    [Required]
    public DateTimeOffset StartsAt { get; set; }

    public DateTimeOffset? EndsAt { get; set; }

    [Range(0, 1440)]
    public int ReminderMinutesBefore { get; set; } = 60;

    [Range(2, 200)]
    public int? MaxParticipants { get; set; }

    [MaxLength(32)]
    public string Visibility { get; set; } = "Public";

    [MaxLength(32)]
    public string JoinPolicy { get; set; } = "Open";

    public bool RequiresVerification { get; set; }

    public List<string> Interests { get; set; } = [];

    [Range(13, 120)]
    public int? MinAge { get; set; }

    [Range(13, 120)]
    public int? MaxAge { get; set; }

    [MaxLength(24)]
    public string PreferredGender { get; set; } = "any";

    /// <summary>"" = tek seferlik. "weekly" | "biweekly" | "monthly".</summary>
    [MaxLength(16)]
    public string RecurrenceRule { get; set; } = string.Empty;

    /// <summary>Tekrar bitiş tarihi — null = süresiz.</summary>
    public DateTimeOffset? RecurrenceUntil { get; set; }
}

public sealed class UpdateActivityRequest
{
    [MaxLength(160)]
    public string? Title { get; set; }

    [MaxLength(2000)]
    public string? Description { get; set; }

    [MaxLength(512)]
    public string? CoverImageUrl { get; set; }

    [MaxLength(200)]
    public string? LocationName { get; set; }

    [MaxLength(400)]
    public string? LocationAddress { get; set; }

    public double? Latitude { get; set; }
    public double? Longitude { get; set; }

    [MaxLength(120)]
    public string? City { get; set; }

    [MaxLength(128)]
    public string? PlaceId { get; set; }

    public DateTimeOffset? StartsAt { get; set; }
    public DateTimeOffset? EndsAt { get; set; }

    [Range(0, 1440)]
    public int? ReminderMinutesBefore { get; set; }

    [Range(2, 200)]
    public int? MaxParticipants { get; set; }

    [MaxLength(32)]
    public string? Visibility { get; set; }

    [MaxLength(32)]
    public string? JoinPolicy { get; set; }

    public bool? RequiresVerification { get; set; }

    public List<string>? Interests { get; set; }

    [Range(13, 120)]
    public int? MinAge { get; set; }

    [Range(13, 120)]
    public int? MaxAge { get; set; }

    [MaxLength(24)]
    public string? PreferredGender { get; set; }

    [MaxLength(16)]
    public string? RecurrenceRule { get; set; }

    public DateTimeOffset? RecurrenceUntil { get; set; }
}

public sealed class CancelActivityRequest
{
    [MaxLength(400)]
    public string? Reason { get; set; }
}

public sealed class ActivityListQuery
{
    /// <summary>Filter: kategori adı (Cesaret, Anlik, Sosyal, ...).</summary>
    [MaxLength(32)]
    public string? Category { get; set; }

    [MaxLength(32)]
    public string? Mode { get; set; }

    [MaxLength(120)]
    public string? City { get; set; }

    /// <summary>"today" | "tomorrow" | "this-week" | "weekend" | null.</summary>
    [MaxLength(24)]
    public string? When { get; set; }

    public double? CenterLatitude { get; set; }
    public double? CenterLongitude { get; set; }

    [Range(0.5, 200)]
    public double? RadiusKm { get; set; }

    [Range(1, 50)]
    public int Limit { get; set; } = 20;

    /// <summary>Cursor — daha eski (StartsAt &gt; cursor) sonuçları sayfa olarak verir.</summary>
    public DateTimeOffset? After { get; set; }

    /// <summary>Filter: yalnızca bu kullanıcının düzenlediği etkinlikler.</summary>
    public Guid? HostUserId { get; set; }
}

public sealed record ActivityListResponseDto(
    IReadOnlyList<ActivityDto> Items,
    bool HasMore
);

public sealed class JoinActivityRequest
{
    [MaxLength(400)]
    public string? Message { get; set; }
}

public sealed class RespondJoinRequest
{
    /// <summary>"approve" | "decline".</summary>
    [Required, MaxLength(16)]
    public string Decision { get; set; } = "approve";

    [MaxLength(400)]
    public string? ResponseNote { get; set; }
}

public sealed record ActivityParticipationDto(
    Guid Id,
    Guid ActivityId,
    UserSummaryDto User,
    string Status,
    string? JoinMessage,
    string? ResponseNote,
    DateTimeOffset RequestedAt,
    DateTimeOffset? RespondedAt
);

public sealed record ActivityParticipationListDto(
    IReadOnlyList<ActivityParticipationDto> Items
);

/// <summary>Aktivite sonrası verilen 1..5 yıldız puanı.</summary>
public sealed record ActivityRatingDto(
    Guid Id,
    Guid ActivityId,
    UserSummaryDto Rater,
    UserSummaryDto Rated,
    int Score,
    string? Comment,
    DateTimeOffset CreatedAt
);

public sealed record ActivityRatingListDto(
    IReadOnlyList<ActivityRatingDto> Items,
    double Average,
    int Count
);

public sealed class CreateActivityRatingRequest
{
    [Required, MaxLength(128)]
    public string RatedUserId { get; set; } = string.Empty;

    [Range(1, 5)]
    public int Score { get; set; } = 5;

    [MaxLength(800)]
    public string? Comment { get; set; }
}

/// <summary>
/// Bir kullanıcının henüz puanlamadığı geçmiş etkinlik + kalan kişiler.
/// </summary>
public sealed record PendingRatingDto(
    ActivityDto Activity,
    IReadOnlyList<UserSummaryDto> RateableUsers
);

public sealed record PendingRatingListDto(
    IReadOnlyList<PendingRatingDto> Items
);
