using Microsoft.EntityFrameworkCore;
using PulseCity.Application.DTOs;
using PulseCity.Application.Interfaces;
using PulseCity.Domain.Entities;
using PulseCity.Domain.Enums;
using PulseCity.Infrastructure.Data;

namespace PulseCity.Infrastructure.Services;

public sealed class BadgesService(
    PulseCityDbContext dbContext,
    INotificationsService notificationsService
) : IBadgesService
{
    /// <summary>Pioneer rozeti için cutoff — ilk N kullanıcı.</summary>
    private const int PioneerCutoff = 1000;

    /// <summary>Yıldız Profil rozeti için ortalama eşiği (5 üzerinden).</summary>
    private const double RatedAverageThreshold = 4.5;

    public BadgeCatalogResponseDto GetCatalog() =>
        new(BadgeCatalog.All.Select(MapDefinition).ToArray());

    public async Task<UserBadgesResponseDto> GetForUserAsync(
        string userId,
        CancellationToken cancellationToken = default
    )
    {
        if (string.IsNullOrWhiteSpace(userId))
        {
            return new UserBadgesResponseDto(
                Array.Empty<UserBadgeDto>(),
                0,
                BadgeCatalog.All.Count
            );
        }

        var earned = await dbContext.UserBadges
            .Where(b => b.UserId == userId)
            .ToListAsync(cancellationToken);

        var earnedByCode = earned.ToDictionary(b => b.BadgeCode, b => b);
        var items = new List<UserBadgeDto>(BadgeCatalog.All.Count);
        foreach (var def in BadgeCatalog.All)
        {
            if (earnedByCode.TryGetValue(def.Code, out var ub))
            {
                items.Add(new UserBadgeDto(
                    def.Code,
                    Earned: true,
                    Tier: ub.Tier,
                    Progress: ub.Progress,
                    NextThreshold: ub.Tier < def.TierThresholds.Count
                        ? def.TierThresholds[ub.Tier]
                        : null,
                    EarnedAt: ub.EarnedAt
                ));
            }
            else
            {
                items.Add(new UserBadgeDto(
                    def.Code,
                    Earned: false,
                    Tier: 0,
                    Progress: 0,
                    NextThreshold: def.TierThresholds.FirstOrDefault(),
                    EarnedAt: null
                ));
            }
        }

        return new UserBadgesResponseDto(items, earned.Count, BadgeCatalog.All.Count);
    }

    public async Task<IReadOnlyList<string>> RecomputeAsync(
        string userId,
        CancellationToken cancellationToken = default
    )
    {
        if (string.IsNullOrWhiteSpace(userId)) return Array.Empty<string>();

        var user = await dbContext.Users
            .AsNoTracking()
            .FirstOrDefaultAsync(u => u.Id == userId, cancellationToken);
        if (user is null) return Array.Empty<string>();

        // Mevcut rozetleri yükle
        var existing = await dbContext.UserBadges
            .Where(b => b.UserId == userId)
            .ToListAsync(cancellationToken);
        var existingByCode = existing.ToDictionary(b => b.BadgeCode, b => b);

        // Metrikleri hesapla
        var hostCount = await dbContext.Activities
            .CountAsync(
                a => a.HostUserId == userId && a.Status != ActivityStatus.Cancelled,
                cancellationToken
            );
        var joinCount = await dbContext.ActivityParticipations
            .CountAsync(
                p => p.UserId == userId && p.Status == ActivityParticipationStatus.Approved,
                cancellationToken
            );
        var ratingCount = user.ActivityRatingCount;
        var ratingAvg = user.ActivityRatingAverage;
        var friendCount = user.FriendsCount;
        var isVerified = user.IsPhotoVerified;

        // Pioneer için sıra hesaplama (cutoff'tan önce mi)
        var pioneerEligible = await dbContext.Users
            .CountAsync(u => u.CreatedAt < user.CreatedAt, cancellationToken) < PioneerCutoff;

        var newlyAwarded = new List<string>();
        var dirty = false;

        UpsertTier(userId, BadgeCatalog.Host, hostCount, existingByCode, newlyAwarded, ref dirty);
        UpsertTier(userId, BadgeCatalog.Social, joinCount, existingByCode, newlyAwarded, ref dirty);

        // Rated: ortalama eşiği üstündeyse, ratingCount'u tier göstergesi yap
        if (ratingCount > 0 && ratingAvg >= RatedAverageThreshold)
        {
            UpsertTier(
                userId,
                BadgeCatalog.Rated,
                ratingCount,
                existingByCode,
                newlyAwarded,
                ref dirty
            );
        }

        UpsertTier(
            userId,
            BadgeCatalog.Connector,
            friendCount,
            existingByCode,
            newlyAwarded,
            ref dirty
        );

        if (isVerified)
        {
            UpsertTier(
                userId,
                BadgeCatalog.Verified,
                1,
                existingByCode,
                newlyAwarded,
                ref dirty
            );
        }

        if (pioneerEligible)
        {
            UpsertTier(
                userId,
                BadgeCatalog.Pioneer,
                1,
                existingByCode,
                newlyAwarded,
                ref dirty
            );
        }

        if (dirty)
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }

        if (newlyAwarded.Count > 0)
        {
            await NotifyAwardedAsync(userId, newlyAwarded, existingByCode, cancellationToken);
        }

        return newlyAwarded;
    }

    /// <summary>
    /// Yeni kazanılan her rozet için kullanıcıya BadgeEarned bildirimi gönderir.
    /// Bildirim hataları rozet hesaplama akışını kesmesin diye yutulur.
    /// </summary>
    private async Task NotifyAwardedAsync(
        string userId,
        IReadOnlyList<string> awardedCodes,
        IDictionary<string, UserBadge> earnedByCode,
        CancellationToken cancellationToken
    )
    {
        foreach (var code in awardedCodes)
        {
            var def = BadgeCatalog.Find(code);
            if (def is null) continue;
            var tier = earnedByCode.TryGetValue(code, out var ub) ? ub.Tier : 1;
            var tierLabel = TierLabel(tier);
            var title = string.IsNullOrEmpty(tierLabel)
                ? def.Title
                : $"{tierLabel} · {def.Title}";
            var body = $"Yeni rozet kazandın: {def.Title} 🎉";
            try
            {
                await notificationsService.CreateAsync(
                    userId,
                    NotificationType.BadgeEarned,
                    title,
                    body,
                    deepLink: "/profile/badges",
                    relatedEntityType: "Badge",
                    relatedEntityId: code,
                    cancellationToken: cancellationToken
                );
            }
            catch
            {
                // Bildirim altyapısı geçici olarak hata verirse rozet akışını kesmeyelim.
            }
        }
    }

    private static string TierLabel(int tier) => tier switch
    {
        1 => "Bronze",
        2 => "Silver",
        3 => "Gold",
        4 => "Platinum",
        _ => string.Empty,
    };

    /// <summary>
    /// Bir rozet için kullanıcının ulaştığı en yüksek tier'ı belirler; gerekirse
    /// kayıt ekler/günceller. Yeni kazanılan tier varsa <paramref name="newlyAwarded"/>
    /// listesine kodu ekler ve <paramref name="dirty"/>'yi true yapar.
    /// </summary>
    private void UpsertTier(
        string userId,
        string code,
        int progress,
        IDictionary<string, UserBadge> existing,
        List<string> newlyAwarded,
        ref bool dirty
    )
    {
        var def = BadgeCatalog.Find(code);
        if (def is null) return;

        var earnedTier = 0;
        for (var i = 0; i < def.TierThresholds.Count; i++)
        {
            if (progress >= def.TierThresholds[i]) earnedTier = i + 1;
        }
        if (earnedTier == 0) return;

        if (existing.TryGetValue(code, out var current))
        {
            if (earnedTier > current.Tier)
            {
                current.Tier = earnedTier;
                current.Progress = progress;
                current.EarnedAt = DateTimeOffset.UtcNow;
                dbContext.UserBadges.Update(current);
                newlyAwarded.Add(code);
                dirty = true;
            }
            else if (current.Progress != progress)
            {
                current.Progress = progress;
                dbContext.UserBadges.Update(current);
                dirty = true;
            }
        }
        else
        {
            var fresh = new UserBadge
            {
                UserId = userId,
                BadgeCode = code,
                Tier = earnedTier,
                Progress = progress,
                EarnedAt = DateTimeOffset.UtcNow,
            };
            existing[code] = fresh;
            dbContext.UserBadges.Add(fresh);
            newlyAwarded.Add(code);
            dirty = true;
        }
    }

    private static BadgeDefinitionDto MapDefinition(BadgeDefinition def) =>
        new(def.Code, def.Title, def.Description, def.IconKey, def.Color, def.TierThresholds);
}
