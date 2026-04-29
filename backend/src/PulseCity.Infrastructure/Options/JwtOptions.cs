namespace PulseCity.Infrastructure.Options;

public sealed class JwtOptions
{
    public const string SectionName = "PulseCity:Jwt";

    public string Issuer { get; set; } = "PulseCity.Api";
    public string Audience { get; set; } = "PulseCity.Mobile";
    public string SigningKey { get; set; } = string.Empty;
    public int AccessTokenMinutes { get; set; } = 60 * 24 * 14;
}
