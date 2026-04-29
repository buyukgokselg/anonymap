namespace PulseCity.Infrastructure.Options;

public sealed class DatabaseOptions
{
    public const string SectionName = "PulseCity:Database";

    public bool ApplyMigrationsOnStartup { get; set; }
}
