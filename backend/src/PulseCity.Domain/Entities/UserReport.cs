namespace PulseCity.Domain.Entities;

public sealed class UserReport
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string ReporterUserId { get; set; } = string.Empty;
    public string TargetUserId { get; set; } = string.Empty;
    public string Reason { get; set; } = string.Empty;
    public string Details { get; set; } = string.Empty;
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}
