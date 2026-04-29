using Microsoft.Extensions.Hosting;
using PulseCity.Infrastructure.Options;

namespace PulseCity.Infrastructure.Internal;

public static class StoragePathResolver
{
    public static string ResolvePublicRoot(IHostEnvironment environment, StorageOptions options) =>
        ResolveStoragePath(options.UploadRootPath, "storage\\public");

    public static string ResolveLegacyPublicRoot(IHostEnvironment environment, StorageOptions options) =>
        Path.GetFullPath(
            Path.Combine(
                environment.ContentRootPath,
                string.IsNullOrWhiteSpace(options.LegacyUploadRootPath)
                    ? "Uploads"
                    : options.LegacyUploadRootPath
            )
        );

    public static string ResolveExportRoot(IHostEnvironment environment, StorageOptions options) =>
        ResolveStoragePath(options.ExportRootPath, "storage\\private\\exports");

    public static string ResolveMailDropRoot(IHostEnvironment environment, StorageOptions options) =>
        ResolveStoragePath(options.OutboundMailRootPath, "storage\\private\\mail");

    private static string ResolveStoragePath(string configuredPath, string fallbackRelativePath)
    {
        var expanded = ExpandConfiguredPath((configuredPath ?? string.Empty).Trim());
        if (string.IsNullOrWhiteSpace(expanded))
        {
            expanded = fallbackRelativePath;
        }

        if (Path.IsPathRooted(expanded))
        {
            return Path.GetFullPath(expanded);
        }

        var root = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "PulseCity"
        );
        return Path.GetFullPath(Path.Combine(root, expanded));
    }

    private static string ExpandConfiguredPath(string configuredPath)
    {
        if (string.IsNullOrWhiteSpace(configuredPath))
        {
            return string.Empty;
        }

        var expanded = Environment.ExpandEnvironmentVariables(configuredPath);
        var localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        if (!string.IsNullOrWhiteSpace(localAppData))
        {
            expanded = expanded.Replace("%LOCALAPPDATA%", localAppData, StringComparison.OrdinalIgnoreCase);
            expanded = expanded.Replace("$LOCALAPPDATA", localAppData, StringComparison.OrdinalIgnoreCase);
        }

        if (!OperatingSystem.IsWindows())
        {
            expanded = expanded.Replace('\\', Path.DirectorySeparatorChar);
        }

        return expanded;
    }
}
