namespace PulseCity.Application.DTOs;

/// <summary>
/// Bir kullanıcının ziyaret ettiği mekanın özetlenmiş kaydı.
/// Post'lar ile PlaceSnapshot birleştirilerek üretilir — ayrı "visits" tablosu
/// tutulmaz. Sıralama için en son ziyaret tarihi kullanılır.
/// </summary>
public sealed record UserPlaceVisitDto(
    string PlaceId,
    string Name,
    string Vicinity,
    double? Latitude,
    double? Longitude,
    int VisitCount,
    DateTimeOffset LastVisitedAt,
    string CoverPhotoUrl
);

/// <summary>
/// Profil hero'sundaki "son sinyal N önce" indikatörü + altındaki özet kart
/// için gereken verinin tamamı.
/// </summary>
public sealed record SignalCrossingSummaryDto(
    int TotalCount,
    DateTimeOffset? LastCrossedAt,
    IReadOnlyList<SignalCrossingDto> Recent
);

public sealed record SignalCrossingDto(
    Guid Id,
    DateTimeOffset CrossedAt,
    string PlaceId,
    string LocationLabel,
    double? ApproxLatitude,
    double? ApproxLongitude
);

/// <summary>
/// Pinned moment set/clear request body. Null veya boş Guid → kaldır.
/// </summary>
public sealed class UpdatePinnedMomentRequest
{
    public Guid? PostId { get; set; }
}

/// <summary>
/// Profildeki sabitlenmiş an. Gösterim için post'un kendisi değil,
/// ilgili referans döner — client tarafı PostModel'i ayrıca yükleyebilir.
/// </summary>
public sealed record PinnedMomentDto(
    Guid PostId,
    DateTimeOffset PinnedAt
);
