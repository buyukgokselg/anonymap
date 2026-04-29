using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using PulseCity.Application.Interfaces;
using PulseCity.Infrastructure.Options;
using System.Globalization;
using System.Text;

namespace PulseCity.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public sealed class UploadsController(
    IFileStorageService fileStorageService,
    IOptions<StorageOptions> storageOptions
) : ControllerBase
{
    [HttpPost("media")]
    [RequestSizeLimit(30_000_000)]
    public async Task<IActionResult> UploadMedia(
        IFormFile file,
        CancellationToken cancellationToken
    )
    {
        var storage = storageOptions.Value;
        if (file.Length <= 0)
        {
            return BadRequest(new { message = "File is empty." });
        }

        var maxBytes = Math.Max(1, storage.MaxUploadSizeMb) * 1024L * 1024L;
        if (file.Length > maxBytes)
        {
            return BadRequest(new { message = "File is too large." });
        }

        if (!IsAllowedFile(file, storage))
        {
            return BadRequest(new { message = "Unsupported file type." });
        }

        if (!await HasAllowedMagicBytesAsync(file, cancellationToken))
        {
            return BadRequest(new { message = "File content does not match the declared file type." });
        }

        await using var stream = file.OpenReadStream();
        var relativeUrl = await fileStorageService.SaveAsync(
            stream,
            file.FileName,
            file.ContentType,
            cancellationToken
        );

        var baseUri = $"{Request.Scheme}://{Request.Host}";
        return Ok(
            new
            {
                url = $"{baseUri}{relativeUrl}",
                relativeUrl,
                fileName = file.FileName,
                size = file.Length,
                contentType = file.ContentType,
            }
        );
    }

    private static bool IsAllowedFile(IFormFile file, StorageOptions storage)
    {
        var extension = Path.GetExtension(file.FileName)?.Trim().ToLowerInvariant() ?? string.Empty;
        var contentType = file.ContentType?.Trim().ToLowerInvariant() ?? string.Empty;

        var allowedExtensions = storage.AllowedExtensions
            .Where(item => !string.IsNullOrWhiteSpace(item))
            .Select(item => item.Trim().ToLowerInvariant())
            .ToHashSet(StringComparer.Ordinal);

        var allowedContentTypes = storage.AllowedContentTypes
            .Where(item => !string.IsNullOrWhiteSpace(item))
            .Select(item => item.Trim().ToLowerInvariant())
            .ToHashSet(StringComparer.Ordinal);

        var extensionAllowed = extension.Length > 0 && allowedExtensions.Contains(extension);
        var contentTypeAllowed = contentType.Length > 0 && allowedContentTypes.Contains(contentType);

        if (!extensionAllowed && !contentTypeAllowed)
        {
            return false;
        }

        var fileName = Path.GetFileName(file.FileName);
        return extension.Length == 0
            ? contentTypeAllowed
            : fileName.EndsWith(extension, true, CultureInfo.InvariantCulture);
    }

    private static async Task<bool> HasAllowedMagicBytesAsync(
        IFormFile file,
        CancellationToken cancellationToken
    )
    {
        var extension = Path.GetExtension(file.FileName)?.Trim().ToLowerInvariant() ?? string.Empty;
        await using var stream = file.OpenReadStream();
        var header = new byte[16];
        var read = await stream.ReadAsync(header.AsMemory(0, header.Length), cancellationToken);
        if (read <= 0)
        {
            return false;
        }

        return extension switch
        {
            ".jpg" or ".jpeg" => StartsWith(header, read, 0xFF, 0xD8, 0xFF),
            ".png" => StartsWith(header, read, 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A),
            ".gif" => StartsWithAscii(header, read, "GIF87a") || StartsWithAscii(header, read, "GIF89a"),
            ".webp" => StartsWithAscii(header, read, "RIFF") && ContainsAscii(header, read, 8, "WEBP"),
            ".webm" => StartsWith(header, read, 0x1A, 0x45, 0xDF, 0xA3),
            ".mp4" => HasFtypBrand(header, read, ["isom", "iso2", "mp41", "mp42", "avc1"]),
            ".mov" => HasFtypBrand(header, read, ["qt  "]),
            ".heic" or ".heif" => HasFtypBrand(header, read, ["heic", "heix", "hevc", "hevx", "mif1", "msf1"]),
            _ => false,
        };
    }

    private static bool HasFtypBrand(byte[] bytes, int length, IReadOnlyList<string> brands)
    {
        if (length < 12 || !ContainsAscii(bytes, length, 4, "ftyp"))
        {
            return false;
        }

        var brand = Encoding.ASCII.GetString(bytes, 8, Math.Min(4, length - 8));
        return brands.Contains(brand, StringComparer.OrdinalIgnoreCase);
    }

    private static bool StartsWith(byte[] bytes, int length, params byte[] prefix)
    {
        if (length < prefix.Length)
        {
            return false;
        }

        for (var index = 0; index < prefix.Length; index++)
        {
            if (bytes[index] != prefix[index])
            {
                return false;
            }
        }

        return true;
    }

    private static bool StartsWithAscii(byte[] bytes, int length, string value) =>
        ContainsAscii(bytes, length, 0, value);

    private static bool ContainsAscii(byte[] bytes, int length, int offset, string value)
    {
        if (length < offset + value.Length)
        {
            return false;
        }

        var actual = Encoding.ASCII.GetString(bytes, offset, value.Length);
        return string.Equals(actual, value, StringComparison.Ordinal);
    }
}
