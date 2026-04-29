using PulseCity.Application.DTOs;

namespace PulseCity.Application.Interfaces;

/// <summary>
/// Rozet sistemi için sözleşme. Rozet kataloğu sabittir; bu servis kullanıcının
/// hangi rozetleri/tier'ları kazandığını hesaplar ve <see cref="RecomputeAsync"/>
/// üzerinden ilerlemeyi günceller.
/// </summary>
public interface IBadgesService
{
    /// <summary>Statik rozet kataloğu — UI ilk açılışta cacheler.</summary>
    BadgeCatalogResponseDto GetCatalog();

    /// <summary>Bir kullanıcının rozet durumu (kazanılmış + henüz kazanılmamış tüm rozetler).</summary>
    Task<UserBadgesResponseDto> GetForUserAsync(
        string userId,
        CancellationToken cancellationToken = default
    );

    /// <summary>
    /// Kullanıcının metriklerini yeniden hesaplar; yeni kazanılan rozet/tier varsa ekler.
    /// Her ilgili yazma operasyonundan (ör. aktivite oluşturma, puan alma) sonra çağrılır.
    /// Yeni kazanılan rozet kodları döner — caller bildirim için kullanabilir.
    /// </summary>
    Task<IReadOnlyList<string>> RecomputeAsync(
        string userId,
        CancellationToken cancellationToken = default
    );
}
