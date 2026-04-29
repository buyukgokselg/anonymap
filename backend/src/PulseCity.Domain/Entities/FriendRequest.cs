using PulseCity.Domain.Enums;

namespace PulseCity.Domain.Entities;

public sealed class FriendRequest
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string FromUserId { get; set; } = string.Empty;
    public string ToUserId { get; set; } = string.Empty;
    public FriendRequestStatus Status { get; set; } = FriendRequestStatus.Pending;
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset? RespondedAt { get; set; }
}
