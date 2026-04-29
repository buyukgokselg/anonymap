namespace PulseCity.Domain.Entities;

public sealed class UserProfile
{
    public string Id { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string FirstName { get; set; } = string.Empty;
    public string LastName { get; set; } = string.Empty;
    public string UserName { get; set; } = string.Empty;
    public string NormalizedUserName { get; set; } = string.Empty;
    public string DisplayName { get; set; } = string.Empty;
    public string NormalizedDisplayName { get; set; } = string.Empty;
    public string Bio { get; set; } = string.Empty;
    public string City { get; set; } = string.Empty;
    public string NormalizedCity { get; set; } = string.Empty;
    public string Website { get; set; } = string.Empty;
    public string Gender { get; set; } = string.Empty;
    public DateTime? BirthDate { get; set; }
    public int Age { get; set; }
    public string Purpose { get; set; } = string.Empty;
    public string MatchPreference { get; set; } = "auto";
    public string Mode { get; set; } = "chill";
    public string PrivacyLevel { get; set; } = "full";
    public string PreferredLanguage { get; set; } = "tr";
    public string LocationGranularity { get; set; } = "nearby";
    public bool EnableDifferentialPrivacy { get; set; } = true;
    public int KAnonymityLevel { get; set; } = 3;
    public bool AllowAnalytics { get; set; } = true;
    public bool IsVisible { get; set; } = true;
    public bool IsOnline { get; set; }
    public string ProfilePhotoUrl { get; set; } = string.Empty;
    public List<string> PhotoUrls { get; set; } = [];
    public List<string> Interests { get; set; } = [];
    public double? Latitude { get; set; }
    public double? Longitude { get; set; }
    public DateTimeOffset? LastSeenAt { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;
    public int FollowersCount { get; set; }
    public int FollowingCount { get; set; }
    public int FriendsCount { get; set; }
    public int PulseScore { get; set; }
    public int PlacesVisited { get; set; }
    public int VibeTagsCreated { get; set; }

    /// <summary>Aktivite katılımcılarından alınan puanların ortalaması (0..5). Cached.</summary>
    public double ActivityRatingAverage { get; set; }

    /// <summary>Aldığı toplam puan sayısı. Cached.</summary>
    public int ActivityRatingCount { get; set; }

    /// <summary>
    /// Sabitlenen an — kullanıcının profilinde öne çıkardığı post'un ID'si.
    /// Null ise gösterilmez.
    /// </summary>
    public Guid? PinnedPostId { get; set; }

    public DateTimeOffset? PinnedAt { get; set; }

    // ── Dating-context fields (pivot Phase 2) ──

    /// <summary>none|straight|gay|lesbian|bi|pan|queer|asexual</summary>
    public string Orientation { get; set; } = string.Empty;

    /// <summary>casual|relationship|friendship|unsure|open</summary>
    public string RelationshipIntent { get; set; } = string.Empty;

    public int? HeightCm { get; set; }

    /// <summary>never|rarely|socially|regularly</summary>
    public string DrinkingStatus { get; set; } = string.Empty;

    /// <summary>never|rarely|socially|regularly</summary>
    public string SmokingStatus { get; set; } = string.Empty;

    public bool IsPhotoVerified { get; set; }

    /// <summary>
    /// Foto doğrulama durumu — boş = hiç başvurmamış, "pending" = inceleniyor,
    /// "approved" = onaylandı (IsPhotoVerified ile uyumlu), "rejected" = reddedildi.
    /// </summary>
    public string VerificationStatus { get; set; } = string.Empty;

    /// <summary>
    /// Doğrulama için kullanıcının yüklediği selfie URL'i (sadece moderasyon görür).
    /// </summary>
    public string VerificationSelfieUrl { get; set; } = string.Empty;

    public DateTimeOffset? VerificationSubmittedAt { get; set; }

    /// <summary>
    /// Profile prompts — key/value pairs chosen by user
    /// (e.g. "my-dream-trip" → "Patagonya'ya kaçmak").
    /// Serialized as JSON.
    /// </summary>
    public Dictionary<string, string> DatingPrompts { get; set; } = new();

    /// <summary>
    /// Array of mode ids user wants to see in matches (e.g. ["flirt","chill"]).
    /// Empty = see all.
    /// </summary>
    public List<string> LookingForModes { get; set; } = [];

    /// <summary>
    /// Array of dealbreaker tags ("smoker", "no_photo", "drinks_heavily")
    /// that filter matches out on the discover feed.
    /// </summary>
    public List<string> Dealbreakers { get; set; } = [];

    /// <summary>
    /// Runtime feature flag overrides per user. Key = AppFeatures flag name.
    /// Allows staged rollout of re-enabled legacy features without new builds.
    /// </summary>
    public Dictionary<string, bool> EnabledFeatures { get; set; } = new();
}
