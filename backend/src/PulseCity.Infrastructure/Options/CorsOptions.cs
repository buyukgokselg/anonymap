namespace PulseCity.Infrastructure.Options;

public sealed class CorsOptions
{
    public const string SectionName = "PulseCity:Cors";

    public List<string> AllowedOrigins { get; set; } = [];
}
