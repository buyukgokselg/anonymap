namespace PulseCity.Domain.Entities;

/// <summary>
/// İki kullanıcının anonimleştirilmiş konum sinyallerinin kesiştiği an.
/// Eşleşme akışı yerine profil ekranında "son sinyal 2s önce" gibi
/// indirgenmiş bilgiyi beslemek için kullanılır. Ad-hoc oluşturulur;
/// tetikleme logic'i presence tarafında çalışır (Phase 3 şemasında
/// yalnızca depolama kurulur).
/// </summary>
public sealed class SignalCrossing
{
    public Guid Id { get; set; } = Guid.NewGuid();

    /// <summary>Çiftin küçük sıralı taraf ID'si (deterministic index).</summary>
    public string UserAId { get; set; } = string.Empty;

    /// <summary>Çiftin büyük sıralı taraf ID'si.</summary>
    public string UserBId { get; set; } = string.Empty;

    public DateTimeOffset CrossedAt { get; set; } = DateTimeOffset.UtcNow;

    public string PlaceId { get; set; } = string.Empty;
    public string LocationLabel { get; set; } = string.Empty;

    /// <summary>K-anonim düzeyine göre bulanıklaştırılmış enlem.</summary>
    public double? ApproxLatitude { get; set; }
    public double? ApproxLongitude { get; set; }
}
