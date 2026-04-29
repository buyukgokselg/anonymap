namespace PulseCity.Domain.Enums;

public enum ActivityParticipationStatus
{
    /// <summary>Approval-required akışında host yanıt bekliyor.</summary>
    Requested = 0,

    /// <summary>Host accepted (approval-required) ya da open-policy auto-join.</summary>
    Approved = 1,

    Declined = 2,

    /// <summary>Kullanıcı vazgeçti veya host çıkardı.</summary>
    Cancelled = 3,
}
