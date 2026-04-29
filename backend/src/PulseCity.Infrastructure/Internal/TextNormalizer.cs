using System.Text;
using System.Text.RegularExpressions;

namespace PulseCity.Infrastructure.Internal;

internal static partial class TextNormalizer
{
    public static string Normalize(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return string.Empty;
        }

        var lowered = value.Trim().ToLowerInvariant();
        var cleaned = NonWordRegex().Replace(lowered, " ");
        return MultiSpaceRegex().Replace(cleaned, " ").Trim();
    }

    public static string BuildUserName(string email, string userId)
    {
        var source = email.Contains('@') ? email[..email.IndexOf('@')] : userId;
        return SanitizeUserName(source, fallbackUserId: userId);
    }

    public static string SanitizeUserName(string? value, string? fallbackUserId = null)
    {
        var source = (value ?? string.Empty).Trim();
        if (source.StartsWith('@'))
        {
            source = source[1..];
        }

        var builder = new StringBuilder();
        foreach (var character in source)
        {
            if (char.IsLetterOrDigit(character) || character is '_' or '.')
            {
                builder.Append(char.ToLowerInvariant(character));
            }
        }

        var candidate = builder.ToString();
        if (!string.IsNullOrWhiteSpace(candidate))
        {
            return candidate;
        }

        var resolvedUserId = string.IsNullOrWhiteSpace(fallbackUserId) ? "user" : fallbackUserId;
        return $"user_{resolvedUserId[..Math.Min(8, resolvedUserId.Length)]}";
    }

    [GeneratedRegex(@"[^\p{L}\p{N}\._]+", RegexOptions.Compiled)]
    private static partial Regex NonWordRegex();

    [GeneratedRegex(@"\s+", RegexOptions.Compiled)]
    private static partial Regex MultiSpaceRegex();
}
