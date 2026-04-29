namespace PulseCity.Application.DTOs;

/// <summary>Statik rozet kataloğu girdisi — UI'da görüntülenecek bilgi.</summary>
public sealed record BadgeDefinitionDto(
    string Code,
    string Title,
    string Description,
    /// <summary>Material icon adı (UI tarafında ikon haritalaması bu key üzerinden yapılır).</summary>
    string IconKey,
    /// <summary>Hex renk (#RRGGBB) — UI rozet aksanı için.</summary>
    string Color,
    /// <summary>Tier eşikleri (ör. [1, 5, 25] = bronze, silver, gold için gereken aksiyon sayısı).</summary>
    IReadOnlyList<int> TierThresholds
);

/// <summary>Bir kullanıcının kazandığı rozet — kazanılmamış rozetler için Earned=false.</summary>
public sealed record UserBadgeDto(
    string Code,
    bool Earned,
    /// <summary>Kazanılan tier (1..N). Earned=false ise 0.</summary>
    int Tier,
    /// <summary>Şu anki ilerleme metriği (ör. düzenlenen aktivite sayısı).</summary>
    int Progress,
    /// <summary>Bir sonraki tier eşiği — Tier maksimumdaysa null.</summary>
    int? NextThreshold,
    DateTimeOffset? EarnedAt
);

public sealed record UserBadgesResponseDto(
    IReadOnlyList<UserBadgeDto> Items,
    /// <summary>Kazanılmış rozet sayısı (UI badge sayacı için).</summary>
    int EarnedCount,
    /// <summary>Toplam katalog büyüklüğü.</summary>
    int TotalCount
);

public sealed record BadgeCatalogResponseDto(
    IReadOnlyList<BadgeDefinitionDto> Items
);
