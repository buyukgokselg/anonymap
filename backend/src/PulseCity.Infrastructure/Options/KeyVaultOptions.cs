namespace PulseCity.Infrastructure.Options;

/// <summary>
/// Azure Key Vault configuration source. When <see cref="Uri"/> is set, the API
/// will overlay every secret from the vault on top of the JSON/env-var config.
///
/// Key Vault secret naming: the <c>:</c> separator in configuration keys is
/// replaced with <c>--</c> in Key Vault. For example, the Firebase service
/// account JSON lives in <c>PulseCity--Fcm--ServiceAccountJson</c>.
///
/// Authentication uses <c>DefaultAzureCredential</c>, which works with:
/// <list type="bullet">
///   <item>Azure App Service / Functions managed identity (production)</item>
///   <item>Visual Studio, Azure CLI, or VS Code sign-in (local dev)</item>
///   <item><c>AZURE_CLIENT_ID</c>/<c>AZURE_CLIENT_SECRET</c>/<c>AZURE_TENANT_ID</c> env vars (CI)</item>
/// </list>
/// </summary>
public sealed class KeyVaultOptions
{
    public const string SectionName = "PulseCity:KeyVault";

    /// <summary>
    /// Vault endpoint, e.g. <c>https://pulsecity-prod-kv.vault.azure.net/</c>.
    /// Leave empty to disable the Key Vault configuration source.
    /// </summary>
    public string Uri { get; set; } = string.Empty;

    /// <summary>
    /// How often to refresh cached secrets. Defaults to 10 minutes which is a
    /// sensible balance between rotation latency and KV request pressure.
    /// </summary>
    public int ReloadIntervalMinutes { get; set; } = 10;
}
