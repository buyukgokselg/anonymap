namespace PulseCity.Infrastructure.Internal;

internal static class SharedHelpers
{
    internal static string NormalizeGender(string? value)
    {
        var normalized = value?.Trim().ToLowerInvariant() ?? string.Empty;
        return normalized switch
        {
            "male" or "man" or "erkek" => "male",
            "female" or "woman" or "kadin" or "kadın" => "female",
            "nonbinary" or "non-binary" or "diger" or "diğer" => "nonbinary",
            _ => normalized,
        };
    }

    internal static string NormalizeMatchPreference(string? value, string gender)
    {
        var normalized = value?.Trim().ToLowerInvariant() ?? string.Empty;
        if (string.IsNullOrWhiteSpace(normalized) || normalized == "auto")
        {
            return gender switch
            {
                "male" => "women",
                "female" => "men",
                _ => "everyone",
            };
        }

        return normalized switch
        {
            "women" or "woman" or "kadinlar" or "kadınlar" => "women",
            "men" or "man" or "erkekler" => "men",
            "everyone" or "herkes" => "everyone",
            _ => "everyone",
        };
    }

    /// <summary>
    /// Tanışma niyeti modu — flirt/friends/fun/chill arasından döner.
    /// Eski legacy mod değerleri (kesif, sosyal vs.) frontend'in
    /// ModeConfig._legacyAliases haritasıyla uyumlu olarak çözümlenir.
    /// </summary>
    internal static string NormalizeMode(string? value)
    {
        var normalized = value?.Trim().ToLowerInvariant() ?? string.Empty;
        return normalized switch
        {
            "flirt" => "flirt",
            "friends" => "friends",
            "fun" => "fun",
            "chill" => "chill",
            // Legacy aliases — eski kullanıcılar / DB satırları için
            "kesif" or "sakinlik" or "uretkenlik" or "acik_alan" or "aile" or "alisveris" or "ozel_cevre" => "chill",
            "sosyal" or "topluluk" => "friends",
            "eglence" => "fun",
            _ => "chill",
        };
    }
}
