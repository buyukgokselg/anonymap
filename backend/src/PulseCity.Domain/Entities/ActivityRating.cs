namespace PulseCity.Domain.Entities;

/// <summary>
/// Bir aktivite sonrası bir katılımcının başka bir katılımcıya (veya host'a) verdiği puan.
/// (ActivityId, RaterUserId, RatedUserId) tekildir — aynı çift için tek puan.
/// </summary>
public sealed class ActivityRating
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public Guid ActivityId { get; set; }

    /// <summary>Puanı veren kullanıcı.</summary>
    public string RaterUserId { get; set; } = string.Empty;

    /// <summary>Puanı alan kullanıcı (host veya katılımcı).</summary>
    public string RatedUserId { get; set; } = string.Empty;

    /// <summary>1..5 yıldız.</summary>
    public int Score { get; set; }

    /// <summary>Opsiyonel kısa yorum.</summary>
    public string? Comment { get; set; }

    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}
