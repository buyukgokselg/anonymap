using PulseCity.Domain.Enums;

namespace PulseCity.Domain.Entities;

public sealed class UserMatch
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string UserId1 { get; set; } = string.Empty;
    public string UserId2 { get; set; } = string.Empty;
    public int Compatibility { get; set; }
    public List<string> CommonInterests { get; set; } = [];
    public MatchStatus Status { get; set; } = MatchStatus.Pending;
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset? RespondedAt { get; set; }
    public Guid? ChatId { get; set; }
    /// <summary>Whether UserId1 (initiator) wants to be anonymous in the match chat.</summary>
    public bool Initiator1AnonymousInChat { get; set; }
    /// <summary>Whether UserId2 (responder) wants to be anonymous in the match chat.</summary>
    public bool Responder2AnonymousInChat { get; set; }
}
