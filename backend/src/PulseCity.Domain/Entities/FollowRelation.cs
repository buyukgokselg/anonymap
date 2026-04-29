namespace PulseCity.Domain.Entities;

public sealed class FollowRelation
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string FollowerUserId { get; set; } = string.Empty;
    public string FollowingUserId { get; set; } = string.Empty;
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}
