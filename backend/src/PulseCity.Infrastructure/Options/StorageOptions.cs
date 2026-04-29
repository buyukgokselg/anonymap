namespace PulseCity.Infrastructure.Options;

public sealed class StorageOptions
{
    public const string SectionName = "PulseCity:Storage";

    public string UploadRootPath { get; set; } = "storage\\public";
    public string ExportRootPath { get; set; } = "storage\\private\\exports";
    public string OutboundMailRootPath { get; set; } = "storage\\private\\mail";
    public string LegacyUploadRootPath { get; set; } = "Uploads";
    public string PublicBasePath { get; set; } = "/uploads";
    public int MaxUploadSizeMb { get; set; } = 30;
    public List<string> AllowedContentTypes { get; set; } =
    [
        "image/jpeg",
        "image/png",
        "image/webp",
        "image/heic",
        "image/heif",
        "image/gif",
        "video/mp4",
        "video/quicktime",
        "video/webm",
    ];
    public List<string> AllowedExtensions { get; set; } =
    [
        ".jpg",
        ".jpeg",
        ".png",
        ".webp",
        ".heic",
        ".heif",
        ".gif",
        ".mp4",
        ".mov",
        ".webm",
    ];
}
