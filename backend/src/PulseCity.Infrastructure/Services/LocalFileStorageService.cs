using Microsoft.AspNetCore.StaticFiles;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;
using PulseCity.Application.Interfaces;
using PulseCity.Infrastructure.Internal;
using PulseCity.Infrastructure.Options;

namespace PulseCity.Infrastructure.Services;

public sealed class LocalFileStorageService(
    IHostEnvironment environment,
    IOptions<StorageOptions> options
) : IFileStorageService
{
    private readonly FileExtensionContentTypeProvider _contentTypeProvider = new();

    public async Task<string> SaveAsync(
        Stream stream,
        string fileName,
        string? contentType,
        CancellationToken cancellationToken = default
    )
    {
        var storageOptions = options.Value;
        var rootDirectory = StoragePathResolver.ResolvePublicRoot(environment, storageOptions);
        Directory.CreateDirectory(rootDirectory);

        var extension = Path.GetExtension(fileName);
        if (string.IsNullOrWhiteSpace(extension))
        {
            extension = GuessExtension(contentType);
        }
        extension = extension.Trim().ToLowerInvariant();

        var allowedExtensions = storageOptions.AllowedExtensions
            .Where(item => !string.IsNullOrWhiteSpace(item))
            .Select(item => item.Trim().ToLowerInvariant())
            .ToHashSet(StringComparer.Ordinal);
        if (allowedExtensions.Count == 0 || !allowedExtensions.Contains(extension))
        {
            throw new InvalidOperationException("Unsupported file extension.");
        }

        var relativeFolder = Path.Combine(
            DateTime.UtcNow.ToString("yyyy"),
            DateTime.UtcNow.ToString("MM")
        );
        var targetFolder = Path.Combine(rootDirectory, relativeFolder);
        Directory.CreateDirectory(targetFolder);

        var finalFileName = $"{Guid.NewGuid():N}{extension}";
        var targetPath = Path.Combine(targetFolder, finalFileName);

        await using var fileStream = File.Create(targetPath);
        await stream.CopyToAsync(fileStream, cancellationToken);

        var publicBasePath = storageOptions.PublicBasePath.TrimEnd('/');
        var relativePath = Path.Combine(relativeFolder, finalFileName).Replace("\\", "/");
        return $"{publicBasePath}/{relativePath}";
    }

    public Task DeleteAsync(
        string urlOrRelativePath,
        CancellationToken cancellationToken = default
    )
    {
        if (string.IsNullOrWhiteSpace(urlOrRelativePath))
        {
            return Task.CompletedTask;
        }

        var storageOptions = options.Value;
        var rootDirectory = Path.GetFullPath(
            StoragePathResolver.ResolvePublicRoot(environment, storageOptions)
        );
        Directory.CreateDirectory(rootDirectory);

        var candidate = urlOrRelativePath.Trim();
        if (Uri.TryCreate(candidate, UriKind.Absolute, out var absoluteUri))
        {
            candidate = absoluteUri.AbsolutePath;
        }

        var publicBasePath = storageOptions.PublicBasePath.Trim();
        if (!string.IsNullOrWhiteSpace(publicBasePath)
            && candidate.StartsWith(publicBasePath, StringComparison.OrdinalIgnoreCase))
        {
            candidate = candidate[publicBasePath.Length..];
        }

        candidate = candidate.TrimStart('/', '\\');
        if (string.IsNullOrWhiteSpace(candidate))
        {
            return Task.CompletedTask;
        }

        var targetPath = Path.GetFullPath(
            Path.Combine(
                rootDirectory,
                candidate.Replace('/', Path.DirectorySeparatorChar)
            )
        );

        if (!targetPath.StartsWith(rootDirectory, StringComparison.OrdinalIgnoreCase))
        {
            return Task.CompletedTask;
        }

        if (File.Exists(targetPath))
        {
            File.Delete(targetPath);
        }

        return Task.CompletedTask;
    }

    private string GuessExtension(string? contentType)
    {
        if (string.IsNullOrWhiteSpace(contentType))
        {
            return ".bin";
        }

        var match = _contentTypeProvider.Mappings.FirstOrDefault(
            entry => string.Equals(entry.Value, contentType, StringComparison.OrdinalIgnoreCase)
        );
        return string.IsNullOrWhiteSpace(match.Key) ? ".bin" : match.Key;
    }
}
