namespace PulseCity.Domain.Entities;

public sealed class StoryView
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid StoryId { get; set; }
    public string ViewerUserId { get; set; } = string.Empty;
    public DateTimeOffset ViewedAt { get; set; } = DateTimeOffset.UtcNow;
}
