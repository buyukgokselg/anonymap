namespace PulseCity.Infrastructure.Options;

public sealed class PushNotificationOptions
{
    public const string SectionName = "PulseCity:Fcm";

    /// <summary>
    /// Inline service account JSON. Prefer supplying this via Azure Key Vault
    /// (secret name <c>PulseCity--Fcm--ServiceAccountJson</c>) or the
    /// <c>PulseCity__Fcm__ServiceAccountJson</c> environment variable — never
    /// commit the value to <c>appsettings.json</c>.
    /// </summary>
    public string ServiceAccountJson { get; set; } = string.Empty;

    /// <summary>
    /// Absolute path to a file containing the service account JSON. Useful on
    /// Azure App Service when a Key Vault reference is mounted as a file.
    /// Evaluated only when <see cref="ServiceAccountJson"/> is empty.
    /// </summary>
    public string ServiceAccountJsonFile { get; set; } = string.Empty;

    public string ProjectId { get; set; } = string.Empty;
}
