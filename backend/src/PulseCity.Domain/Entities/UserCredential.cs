namespace PulseCity.Domain.Entities;

public sealed class UserCredential
{
    public string UserId { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string PasswordHash { get; set; } = string.Empty;
    public string? GoogleSubject { get; set; }
    public bool HasPassword { get; set; }
    public int FailedLoginAttempts { get; set; }
    public DateTimeOffset? LockoutEnd { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;
}
