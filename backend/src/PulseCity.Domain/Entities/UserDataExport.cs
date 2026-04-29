namespace PulseCity.Domain.Entities;

public sealed class UserDataExport
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string UserId { get; set; } = string.Empty;
    public string FileName { get; set; } = string.Empty;
    public string RelativePath { get; set; } = string.Empty;
    public string Status { get; set; } = "ready";
    public long FileSizeBytes { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset ExpiresAt { get; set; } = DateTimeOffset.UtcNow.AddHours(72);
}
