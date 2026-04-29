namespace PulseCity.Domain.Entities;

public sealed class DeviceToken
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string UserId { get; set; } = string.Empty;
    public string Token { get; set; } = string.Empty;
    public string Platform { get; set; } = "android"; // android | ios
    public DateTimeOffset RegisteredAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;
}
