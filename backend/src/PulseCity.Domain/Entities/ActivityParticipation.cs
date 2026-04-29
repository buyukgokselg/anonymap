using PulseCity.Domain.Enums;

namespace PulseCity.Domain.Entities;

/// <summary>
/// Bir kullanıcının bir Activity'e katılım kaydı (request veya direct join).
/// Host kendi Activity'sinde participation kaydı tutmaz — host alanı Activity üzerinde.
/// </summary>
public sealed class ActivityParticipation
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public Guid ActivityId { get; set; }

    public string UserId { get; set; } = string.Empty;

    public ActivityParticipationStatus Status { get; set; } = ActivityParticipationStatus.Requested;

    /// <summary>Approval-required akışında kullanıcının host'a yazdığı kısa mesaj.</summary>
    public string? JoinMessage { get; set; }

    /// <summary>Host'un cevabı (decline reason vb).</summary>
    public string? ResponseNote { get; set; }

    public DateTimeOffset RequestedAt { get; set; } = DateTimeOffset.UtcNow;

    public DateTimeOffset? RespondedAt { get; set; }

    public DateTimeOffset? CancelledAt { get; set; }
}
