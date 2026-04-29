namespace PulseCity.Domain.Entities;

public sealed class UserPresence
{
    public string UserId { get; set; } = string.Empty;
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public string City { get; set; } = string.Empty;
    public string Mode { get; set; } = "kesif";
    public bool ShareProfile { get; set; } = true;
    public bool IsSignalActive { get; set; }
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;
}
