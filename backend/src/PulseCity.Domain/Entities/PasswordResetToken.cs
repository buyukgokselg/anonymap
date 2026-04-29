namespace PulseCity.Domain.Entities;

public sealed class PasswordResetToken
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string UserId { get; set; } = string.Empty;
    public string TokenHash { get; set; } = string.Empty;
    public DateTimeOffset ExpiresAt { get; set; } = DateTimeOffset.UtcNow.AddMinutes(30);
    public DateTimeOffset? UsedAt { get; set; }
    public string RequestedIp { get; set; } = string.Empty;
    public string UserAgent { get; set; } = string.Empty;
    public int Attempts { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}
