using PulseCity.Application.DTOs;

namespace PulseCity.Infrastructure.Internal;

internal static class PlacesScoring
{
    public static readonly Dictionary<string, string[]> ModeTypes = new(StringComparer.OrdinalIgnoreCase)
    {
        ["kesif"] = ["restaurant", "cafe", "museum", "art_gallery", "tourist_attraction"],
        ["sakinlik"] = ["park", "library", "spa", "church"],
        ["sosyal"] = ["bar", "cafe", "night_club", "restaurant"],
        ["uretkenlik"] = ["cafe", "library"],
        ["eglence"] = ["night_club", "bar", "movie_theater", "bowling_alley", "amusement_park"],
        ["acik_alan"] = ["park", "campground", "stadium"],
        ["topluluk"] = ["community_center", "cafe", "art_gallery"],
        ["aile"] = ["park", "zoo", "aquarium", "museum", "amusement_park"],
    };

    private static readonly Dictionary<string, int[]> ModePeakHours = new(StringComparer.OrdinalIgnoreCase)
    {
        ["kesif"] = [10, 11, 12, 13, 14, 15, 16, 17],
        ["sakinlik"] = [7, 8, 9, 10, 11, 15, 16, 17],
        ["sosyal"] = [17, 18, 19, 20, 21, 22],
        ["uretkenlik"] = [8, 9, 10, 11, 12, 13, 14, 15],
        ["eglence"] = [20, 21, 22, 23, 0, 1, 2],
        ["acik_alan"] = [9, 10, 11, 12, 13, 14, 15, 16],
        ["topluluk"] = [16, 17, 18, 19, 20],
        ["aile"] = [10, 11, 12, 13, 14, 15, 16],
    };

    private static readonly string[] PositiveReviewWords =
    [
        "harika", "mukemmel", "guzel", "keyifli", "hizli", "temiz", "samimi", "lezzetli",
        "rahat", "oneririm", "great", "amazing", "excellent", "friendly", "clean", "cozy", "perfect",
    ];

    private static readonly string[] NegativeReviewWords =
    [
        "kotu", "berbat", "yavas", "kirli", "pahali", "kalabalik", "gurultulu", "soguk",
        "disappoint", "bad", "slow", "dirty", "expensive", "crowded", "noisy", "rude",
    ];

    public static PlaceSummaryDto BuildPlaceSummary(
        RawPlace place,
        NearbyPlacesRequest request,
        CommunitySignals communitySignals,
        string languageCode = "tr"
    )
    {
        var googlePulseScore = CalculateGooglePulseScore(place);
        var densityScore = CalculateDensityScore(place);
        var trendScore = CalculateTrendScore(place);
        var communityScore = CalculateCommunityScore(communitySignals);
        var liveSignalScore = CalculateLiveSignalScore(communitySignals);
        var ambassadorScore = CalculateAmbassadorScore(communitySignals);
        var syntheticDemandScore = Math.Clamp(communitySignals.SyntheticDemand, 0, 100);
        var seedConfidence = CalculateSeedConfidence(place, communitySignals);
        var pulseScore = CalculateBlendedPulseScore(
            googlePulseScore,
            densityScore,
            trendScore,
            communityScore,
            liveSignalScore,
            ambassadorScore,
            syntheticDemandScore
        );
        var distanceMeters = CalculateDistanceMeters(request.Latitude, request.Longitude, place.Latitude, place.Longitude);
        var momentScore = CalculateMomentScore(
            pulseScore,
            trendScore,
            densityScore,
            distanceMeters,
            place.OpenNow,
            place.Types,
            request.ModeId,
            DateTimeOffset.UtcNow
        );
        var pulseDriverTags = BuildPulseDriverTags(
            place.OpenNow,
            trendScore,
            place.Rating,
            place.UserRatingsTotal,
            distanceMeters,
            communityScore,
            liveSignalScore,
            ambassadorScore,
            syntheticDemandScore,
            languageCode
        );
        var sourceBreakdown = communitySignals.SourceBreakdown ?? new Dictionary<string, int>();

        return new PlaceSummaryDto(
            place.PlaceId,
            place.Name,
            place.Vicinity,
            place.Latitude,
            place.Longitude,
            place.Rating,
            place.UserRatingsTotal,
            place.OpenNow,
            place.PriceLevel,
            place.Types,
            place.PhotoReferences.FirstOrDefault(),
            googlePulseScore,
            densityScore,
            trendScore,
            pulseScore,
            communityScore,
            liveSignalScore,
            ambassadorScore,
            syntheticDemandScore,
            seedConfidence,
            momentScore,
            DensityLabelFromScore(densityScore, languageCode),
            TrendLabelFromScore(trendScore, languageCode),
            FormatDistance(distanceMeters, languageCode),
            distanceMeters,
            pulseDriverTags,
            sourceBreakdown,
            ExplainPulseDrivers(place.Name, pulseDriverTags, request.ModeId, languageCode)
        );
    }

    public static int CalculateMomentScore(PlaceSummaryDto place, string modeId, DateTimeOffset at) =>
        CalculateMomentScore(place.PulseScore, place.TrendScore, place.DensityScore, place.DistanceMeters, place.OpenNow, place.Types, modeId, at);

    public static int CalculateForecastConfidence(PlaceSummaryDto place, int offsetHours)
    {
        var reviewStrength = Math.Log(place.UserRatingsTotal + 1, 5000) * 100;
        var dataStrength = (place.PulseScore * 0.35) + (place.GooglePulseScore * 0.25) + (reviewStrength * 0.20) + (place.CommunityScore * 0.20);
        return (int)Math.Clamp(Math.Round(dataStrength - (offsetHours * 4)), 48, 96);
    }

    public static double CalculateDistanceMeters(double startLatitude, double startLongitude, double endLatitude, double endLongitude)
    {
        const double earthRadius = 6371000;
        var dLat = ToRadians(endLatitude - startLatitude);
        var dLng = ToRadians(endLongitude - startLongitude);
        var a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2)
            + Math.Cos(ToRadians(startLatitude)) * Math.Cos(ToRadians(endLatitude))
            * Math.Sin(dLng / 2) * Math.Sin(dLng / 2);
        var c = 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
        return earthRadius * c;
    }

    public static int CalculateMomentScore(int pulseScore, int trendScore, int densityScore, double distanceMeters, bool openNow, IReadOnlyList<string> types, string modeId, DateTimeOffset at)
    {
        var distanceScore = Math.Clamp(100 - (distanceMeters / 18), 0, 100);
        var modeFit = CalculateModeFit(modeId, types);
        var timeFit = CalculateTimeFit(modeId, types, at);
        var score = (pulseScore * 0.50) + (trendScore * 0.12) + (densityScore * 0.08) + (distanceScore * 0.14) + (modeFit * 0.08) + (timeFit * 0.08) + (openNow ? 16 : 0);
        return ClampScore(score);
    }

    private static int CalculateGooglePulseScore(RawPlace place)
    {
        var ratingComponent = (place.Rating / 5.0) * 42;
        var volumeComponent = Math.Log(place.UserRatingsTotal + 1, 5000) * 28;
        var availabilityComponent = place.OpenNow ? 10.0 : 3.0;
        var priceComponent = place.PriceLevel switch { 0 => 5.0, 1 => 7.0, 2 => 9.0, 3 => 6.0, _ => 4.0 };
        return ClampScore(ratingComponent + volumeComponent + availabilityComponent + priceComponent);
    }

    private static int CalculateDensityScore(RawPlace place) =>
        ClampScore((Math.Log(place.UserRatingsTotal + 1, 5000) * 70) + ((place.Rating / 5.0) * 30));

    private static int CalculateTrendScore(RawPlace place)
    {
        var baseScore = Math.Log(place.UserRatingsTotal + 1, 5000) * 48;
        return ClampScore(baseScore + CalculateReviewRecencyScore(place.Reviews) + (place.OpenNow ? 18 : 0) + (CalculateReviewSentimentScore(place.Reviews) * 0.12));
    }

    private static int CalculateReviewSentimentScore(IReadOnlyList<RawReview> reviews)
    {
        if (reviews.Count == 0) return 50;
        var positive = 0;
        var negative = 0;
        foreach (var review in reviews)
        {
            var text = review.Text.ToLowerInvariant();
            positive += PositiveReviewWords.Count(text.Contains);
            negative += NegativeReviewWords.Count(text.Contains);
        }
        var total = positive + negative;
        if (total == 0) return 55;
        return ClampScore((((double)(positive - negative) / total) + 1) * 50);
    }

    private static int CalculateReviewRecencyScore(IReadOnlyList<RawReview> reviews)
    {
        var score = 0;
        foreach (var review in reviews)
        {
            var relativeTime = review.RelativeTime.ToLowerInvariant();
            if (relativeTime.Contains("saat") || relativeTime.Contains("hour")) score += 18;
            else if (relativeTime.Contains("gun") || relativeTime.Contains("day")) score += 14;
            else if (relativeTime.Contains("hafta") || relativeTime.Contains("week")) score += 10;
            else if (relativeTime.Contains("ay") || relativeTime.Contains("month")) score += 6;
        }
        return Math.Clamp(score, 0, 25);
    }

    private static int CalculateCommunityScore(CommunitySignals communitySignals) =>
        ClampScore(
            (communitySignals.Posts * 8)
            + (communitySignals.Shorts * 10)
            + (communitySignals.Likes * 1.4)
            + (communitySignals.Comments * 2.5)
            + (communitySignals.Creators * 6)
            + (communitySignals.Saves * 4)
        );

    private static int CalculateLiveSignalScore(CommunitySignals communitySignals) =>
        ClampScore((communitySignals.LiveVisitors * 13) + (communitySignals.Saves * 3));

    private static int CalculateAmbassadorScore(CommunitySignals communitySignals) =>
        ClampScore((communitySignals.Ambassadors * 18) + (communitySignals.Creators * 4));

    private static int CalculateSeedConfidence(RawPlace place, CommunitySignals communitySignals) =>
        ClampScore(
            30
            + (Math.Log(place.UserRatingsTotal + 1, 5000) * 20)
            + (communitySignals.Posts * 6)
            + (communitySignals.Shorts * 7)
            + (communitySignals.LiveVisitors * 8)
            + (communitySignals.Ambassadors * 10)
        );

    private static int CalculateBlendedPulseScore(
        int googlePulseScore,
        int densityScore,
        int trendScore,
        int communityScore,
        int liveSignalScore,
        int ambassadorScore,
        int syntheticDemandScore
    ) => ClampScore(
        (googlePulseScore * 0.34)
        + (densityScore * 0.15)
        + (trendScore * 0.15)
        + (communityScore * 0.14)
        + (liveSignalScore * 0.08)
        + (ambassadorScore * 0.08)
        + (syntheticDemandScore * 0.06)
    );

    private static double CalculateModeFit(string modeId, IReadOnlyList<string> types)
    {
        if (types.Count == 0 || !ModeTypes.TryGetValue(modeId, out var desiredTypes)) return 45;
        return Math.Clamp((types.Count(desiredTypes.Contains) * 22) + 35, 0, 100);
    }

    private static double CalculateTimeFit(string modeId, IReadOnlyList<string> types, DateTimeOffset at)
    {
        var peakHours = ModePeakHours.GetValueOrDefault(modeId) ?? [];
        var hour = at.Hour;
        var score = peakHours.Contains(hour) ? 82.0 : 52.0;
        var nightlife = types.Contains("bar") || types.Contains("night_club");
        var cafeLike = types.Contains("cafe") || types.Contains("library");
        var parkLike = types.Contains("park") || types.Contains("campground");
        if (nightlife && (hour >= 20 || hour <= 2)) score += 16;
        if (nightlife && hour < 17) score -= 24;
        if (cafeLike && hour >= 8 && hour <= 17) score += 14;
        if (cafeLike && hour >= 22) score -= 20;
        if (parkLike && hour >= 9 && hour <= 18) score += 12;
        if (parkLike && (hour <= 6 || hour >= 22)) score -= 22;
        return Math.Clamp(score, 0, 100);
    }

    private static List<string> BuildPulseDriverTags(
        bool openNow,
        int trendScore,
        double rating,
        int userRatingsTotal,
        double distanceMeters,
        int communityScore,
        int liveSignalScore,
        int ambassadorScore,
        int syntheticDemandScore,
        string languageCode
    )
    {
        var tags = new List<string>();
        if (openNow) tags.Add(Localize(languageCode, "Şu an açık", "Open now", "Jetzt geöffnet"));
        if (trendScore >= 65) tags.Add(Localize(languageCode, "İvme kazanıyor", "Gaining momentum", "Gewinnt an Dynamik"));
        if (communityScore >= 35) tags.Add(Localize(languageCode, "Topluluktan sinyal alıyor", "Community is signaling", "Community sendet Signale"));
        if (liveSignalScore >= 35) tags.Add(Localize(languageCode, "Canlı sinyal güçlü", "Live signal is strong", "Live-Signal ist stark"));
        if (ambassadorScore >= 35) tags.Add(Localize(languageCode, "Yerel ambassador desteği var", "Backed by local ambassadors", "Wird von lokalen Ambassadors getragen"));
        if (syntheticDemandScore >= 40) tags.Add(Localize(languageCode, "Sentetik talep yükseliyor", "Synthetic demand is rising", "Synthetische Nachfrage steigt"));
        if (distanceMeters <= 350) tags.Add(Localize(languageCode, "Yürüyerek yakın", "Walkable", "Zu Fuß erreichbar"));
        if (rating >= 4.4) tags.Add(Localize(languageCode, "Puan ortalaması güçlü", "Strong rating", "Starke Bewertung"));
        if (userRatingsTotal >= 150) tags.Add(Localize(languageCode, "Yorum hacmi yüksek", "High review volume", "Hohe Kommentarzahl"));
        if (tags.Count == 0) tags.Add(Localize(languageCode, "Veri dengesi güçlü", "Strong data balance", "Stabile Datenlage"));
        return tags.Take(3).ToList();
    }

    private static string ExplainPulseDrivers(string placeName, IReadOnlyList<string> tags, string modeId, string languageCode)
    {
        if (languageCode == "en")
        {
            var context = string.IsNullOrWhiteSpace(modeId) ? string.Empty : $" for {modeId} mode";
            return tags.Count switch
            {
                1 => $"{placeName}{context} stands out because it is {tags[0].ToLowerInvariant()}.",
                2 => $"{placeName}{context} is climbing thanks to {tags[0].ToLowerInvariant()} and {tags[1].ToLowerInvariant()}.",
                _ => $"{placeName}{context} is rising thanks to {tags[0].ToLowerInvariant()}, {tags[1].ToLowerInvariant()} and {tags[2].ToLowerInvariant()}.",
            };
        }

        if (languageCode == "de")
        {
            var context = string.IsNullOrWhiteSpace(modeId) ? string.Empty : $" für den Modus {modeId}";
            return tags.Count switch
            {
                1 => $"{placeName}{context} fällt auf, weil es {tags[0].ToLowerInvariant()} ist.",
                2 => $"{placeName}{context} steigt dank {tags[0].ToLowerInvariant()} und {tags[1].ToLowerInvariant()}.",
                _ => $"{placeName}{context} steigt dank {tags[0].ToLowerInvariant()}, {tags[1].ToLowerInvariant()} und {tags[2].ToLowerInvariant()}.",
            };
        }

        var turkishContext = string.IsNullOrWhiteSpace(modeId) ? string.Empty : $" {modeId} modu için";
        return tags.Count switch
        {
            1 => $"{placeName}{turkishContext} {tags[0].ToLowerInvariant()} olduğu için öne çıkıyor.",
            2 => $"{placeName}{turkishContext} {tags[0].ToLowerInvariant()} ve {tags[1].ToLowerInvariant()} sayesinde yükseliyor.",
            _ => $"{placeName}{turkishContext} {tags[0].ToLowerInvariant()}, {tags[1].ToLowerInvariant()} ve {tags[2].ToLowerInvariant()} sayesinde yükseliyor.",
        };
    }

    private static string DensityLabelFromScore(int score, string languageCode) => score switch
    {
        >= 82 => Localize(languageCode, "Çok yoğun", "Very busy", "Sehr belebt"),
        >= 64 => Localize(languageCode, "Yoğun", "Busy", "Belebt"),
        >= 42 => Localize(languageCode, "Orta", "Moderate", "Mittel"),
        >= 20 => Localize(languageCode, "Düşük", "Low", "Niedrig"),
        _ => Localize(languageCode, "Çok düşük", "Very low", "Sehr niedrig"),
    };

    private static string TrendLabelFromScore(int score, string languageCode) => score switch
    {
        >= 78 => Localize(languageCode, "Patlıyor", "Spiking", "Explodiert"),
        >= 58 => Localize(languageCode, "Yükseliyor", "Rising", "Steigend"),
        >= 38 => Localize(languageCode, "Sabit", "Stable", "Stabil"),
        _ => Localize(languageCode, "Sakin", "Calm", "Ruhig"),
    };

    private static string FormatDistance(double meters, string languageCode) => meters < 1000
        ? $"{Math.Round(meters)}m"
        : $"{meters / 1000:0.0}km";

    public static string FormatForecastLabel(int offsetHours, string languageCode)
    {
        if (offsetHours == 0)
        {
            return Localize(languageCode, "Şimdi", "Now", "Jetzt");
        }

        return languageCode switch
        {
            "en" => $"+{offsetHours}h",
            "de" => $"+{offsetHours} Std.",
            _ => $"+{offsetHours}s",
        };
    }

    private static string Localize(string languageCode, string tr, string en, string de)
    {
        return languageCode switch
        {
            "en" => en,
            "de" => de,
            _ => tr,
        };
    }
    private static double ToRadians(double degrees) => degrees * (Math.PI / 180);
    private static int ClampScore(double value) => (int)Math.Clamp(Math.Round(value), 0, 100);
}
