namespace PulseCity.Domain.Entities;

public sealed class PostComment
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid PostId { get; set; }
    public string UserId { get; set; } = string.Empty;
    public string Text { get; set; } = string.Empty;
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}
