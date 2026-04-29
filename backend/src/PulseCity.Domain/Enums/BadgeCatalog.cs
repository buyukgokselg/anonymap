namespace PulseCity.Domain.Enums;

/// <summary>
/// Rozet kataloğu — backend ve frontend için tek doğruluk kaynağı. UI rozet
/// görselini <see cref="BadgeDefinition.IconKey"/>'e göre çizer.
/// </summary>
public sealed record BadgeDefinition(
    string Code,
    string Title,
    string Description,
    string IconKey,
    string Color,
    IReadOnlyList<int> TierThresholds
);

public static class BadgeCatalog
{
    /// <summary>İlk etkinliği düzenleme + tekrarlayan host olma rozetleri.</summary>
    public const string Host = "host";

    /// <summary>Aktivitelere katılım sıklığı.</summary>
    public const string Social = "social";

    /// <summary>Yüksek puan ortalaması (4.5+).</summary>
    public const string Rated = "rated";

    /// <summary>Foto doğrulamadan geçen kullanıcılar.</summary>
    public const string Verified = "verified";

    /// <summary>İlk 1000 kullanıcı (createdAt sırası).</summary>
    public const string Pioneer = "pioneer";

    /// <summary>10+ arkadaş.</summary>
    public const string Connector = "connector";

    public static IReadOnlyList<BadgeDefinition> All { get; } = new[]
    {
        new BadgeDefinition(
            Host,
            "Ev Sahibi",
            "Düzenlediğin etkinlikler insanları gerçek hayatta buluşturuyor.",
            "celebration",
            "#E94560",
            new[] { 1, 5, 25, 100 }),

        new BadgeDefinition(
            Social,
            "Sosyal Kelebek",
            "Katıldığın etkinliklerde yeni insanlarla tanışıyorsun.",
            "groups",
            "#FF6B81",
            new[] { 1, 10, 50, 200 }),

        new BadgeDefinition(
            Rated,
            "Yıldız Profil",
            "Aktivite katılımcıların seni yüksek puanladı.",
            "star",
            "#F39C12",
            new[] { 1, 25, 100 }),

        new BadgeDefinition(
            Verified,
            "Onaylı Profil",
            "Foto doğrulamandan geçtin — kimliğin güvende.",
            "verified",
            "#2ECC71",
            new[] { 1 }),

        new BadgeDefinition(
            Connector,
            "Köprü",
            "Geniş bir arkadaş ağı kurdun.",
            "hub",
            "#7C4DFF",
            new[] { 10, 50, 250 }),

        new BadgeDefinition(
            Pioneer,
            "Öncü",
            "PulseCity'nin ilk dalgasındasın.",
            "rocket",
            "#00D9FF",
            new[] { 1 }),
    };

    public static BadgeDefinition? Find(string code) =>
        All.FirstOrDefault(b => b.Code == code);
}
