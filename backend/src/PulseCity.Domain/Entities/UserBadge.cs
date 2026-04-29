namespace PulseCity.Domain.Entities;

/// <summary>
/// Bir kullanıcının kazandığı rozet kaydı. Rozet kataloğu (BadgeCode + tier)
/// kod tarafında <c>BadgeCatalog</c> olarak sabittir; bu tablo yalnızca
/// "kim, ne zaman, hangi seviyeyi" hak ettiğini izler.
/// </summary>
public sealed class UserBadge
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public string UserId { get; set; } = string.Empty;

    /// <summary>Rozet katalog kodu (ör. "host", "social", "rated").</summary>
    public string BadgeCode { get; set; } = string.Empty;

    /// <summary>Tier 1..N — rozetin hangi seviyesini kazandı.</summary>
    public int Tier { get; set; } = 1;

    /// <summary>Rozet ilk kazanıldığı an. Tier yükseldiğinde güncellenir.</summary>
    public DateTimeOffset EarnedAt { get; set; } = DateTimeOffset.UtcNow;

    /// <summary>İlerleme metriği (ör. düzenlenen aktivite sayısı). Sadece UI içindir.</summary>
    public int Progress { get; set; }
}
