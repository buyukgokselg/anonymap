using PulseCity.Domain.Enums;

namespace PulseCity.Domain.Entities;

/// <summary>
/// Etkinlik — host tarafından oluşturulan, başkalarının katıldığı zamanlanmış buluşma.
/// </summary>
public sealed class Activity
{
    public Guid Id { get; set; } = Guid.NewGuid();

    /// <summary>Activity'i oluşturan kullanıcı.</summary>
    public string HostUserId { get; set; } = string.Empty;

    public string Title { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;

    public ActivityCategory Category { get; set; } = ActivityCategory.Other;

    /// <summary>flirt/friends/fun/chill gibi PulseCity mode etiketi.</summary>
    public string Mode { get; set; } = "chill";

    /// <summary>Cover görseli (opsiyonel).</summary>
    public string? CoverImageUrl { get; set; }

    // ── Place ──
    public string LocationName { get; set; } = string.Empty;
    public string? LocationAddress { get; set; }
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public string City { get; set; } = string.Empty;
    public string NormalizedCity { get; set; } = string.Empty;

    /// <summary>Google Places ID — autocomplete'ten seçilen mekânın referansı. null = manuel giriş.</summary>
    public string? PlaceId { get; set; }

    // ── Time ──
    public DateTimeOffset StartsAt { get; set; }
    public DateTimeOffset? EndsAt { get; set; }

    /// <summary>Aktiviteden önce hatırlatma push'u atılan dakika (default 60).</summary>
    public int ReminderMinutesBefore { get; set; } = 60;

    /// <summary>Hatırlatma push'unun gönderilip gönderilmediği — idempotent trigger için.</summary>
    public bool ReminderSent { get; set; }

    // ── Capacity ──

    /// <summary>Maksimum katılımcı sayısı (host hariç). null = sınırsız.</summary>
    public int? MaxParticipants { get; set; }

    /// <summary>Şu an Approved durumunda kaç katılımcı var (host hariç). Cached counter.</summary>
    public int CurrentParticipantCount { get; set; }

    // ── Audience ──
    public ActivityVisibility Visibility { get; set; } = ActivityVisibility.Public;
    public ActivityJoinPolicy JoinPolicy { get; set; } = ActivityJoinPolicy.Open;

    /// <summary>Cesaret kategorisi gibi durumlarda doğrulanmış üye şartı.</summary>
    public bool RequiresVerification { get; set; }

    /// <summary>İlgi etiketleri — match/discovery için kullanılır.</summary>
    public List<string> Interests { get; set; } = [];

    public int? MinAge { get; set; }
    public int? MaxAge { get; set; }

    /// <summary>any|female|male|nonbinary — aktivite kimleri tercih ettiğinin sinyali.</summary>
    public string PreferredGender { get; set; } = "any";

    // ── State ──
    public ActivityStatus Status { get; set; } = ActivityStatus.Published;
    public string? CancellationReason { get; set; }
    public DateTimeOffset? CancelledAt { get; set; }
    public DateTimeOffset? CompletedAt { get; set; }

    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;

    // ── Recurrence ──

    /// <summary>
    /// Tekrar kuralı. Boş = tek seferlik. "weekly" = her hafta aynı gün/saat,
    /// "biweekly" = iki haftada bir, "monthly" = her ay aynı gün.
    /// </summary>
    public string RecurrenceRule { get; set; } = string.Empty;

    /// <summary>Tekrar bitiş tarihi — null = süresiz.</summary>
    public DateTimeOffset? RecurrenceUntil { get; set; }

    /// <summary>Bu activity başka bir tekrarın türettiği örnek mi? Null = ana etkinlik.</summary>
    public Guid? RecurrenceParentId { get; set; }
}
