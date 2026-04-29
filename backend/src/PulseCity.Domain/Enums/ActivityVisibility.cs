namespace PulseCity.Domain.Enums;

public enum ActivityVisibility
{
    /// <summary>Discoverable by everyone.</summary>
    Public = 0,

    /// <summary>Sadece arkadaşlara görünür.</summary>
    Friends = 1,

    /// <summary>Sadece karşılıklı eşleşmelere.</summary>
    MutualMatches = 2,

    /// <summary>Sadece doğrudan davet edilenler.</summary>
    InviteOnly = 3,
}
