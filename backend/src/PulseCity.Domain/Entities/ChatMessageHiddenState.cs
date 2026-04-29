namespace PulseCity.Domain.Entities;

public sealed class ChatMessageHiddenState
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid MessageId { get; set; }
    public string UserId { get; set; } = string.Empty;
    public DateTimeOffset HiddenAt { get; set; } = DateTimeOffset.UtcNow;
}
