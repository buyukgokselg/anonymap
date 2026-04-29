namespace PulseCity.Domain.Entities;

public sealed class Friendship
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string UserAId { get; set; } = string.Empty;
    public string UserBId { get; set; } = string.Empty;
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}
