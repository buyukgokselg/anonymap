namespace PulseCity.Infrastructure.Options;

public sealed class RedisOptions
{
    public const string SectionName = "PulseCity:Redis";

    public string ConnectionString { get; set; } = string.Empty;
    public string InstanceName { get; set; } = "pulsecity:";
}
