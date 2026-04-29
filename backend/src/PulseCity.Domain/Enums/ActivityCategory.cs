namespace PulseCity.Domain.Enums;

/// <summary>
/// Top-level theme of an activity. Drives card visual + filtering.
/// </summary>
public enum ActivityCategory
{
    /// <summary>Generic / kategorisiz.</summary>
    Other = 0,

    /// <summary>Vulnerability-driven meet-ups (paragliding alone-but-not-alone, ilk kez yoga vb.).</summary>
    Cesaret = 10,

    /// <summary>&lt;2 saat horizonu — anlık kahve, kısa yürüyüş.</summary>
    Anlik = 20,

    Sosyal = 30,
    Spor = 40,
    Sanat = 50,
    Egitim = 60,
    Doga = 70,
    Yemek = 80,
    Gece = 90,
    Seyahat = 100,
}
