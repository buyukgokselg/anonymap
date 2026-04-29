namespace PulseCity.Infrastructure.Options;

public sealed class PrivacyOptions
{
    public const string SectionName = "PulseCity:Privacy";

    public int ExportRetentionHours { get; set; } = 72;
    public int DefaultKAnonymityLevel { get; set; } = 3;
    public int DefaultNoiseMeters { get; set; } = 85;
}
