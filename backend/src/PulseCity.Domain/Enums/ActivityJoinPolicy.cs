namespace PulseCity.Domain.Enums;

public enum ActivityJoinPolicy
{
    /// <summary>Users join instantly without host approval.</summary>
    Open = 0,

    /// <summary>Host onaylar.</summary>
    ApprovalRequired = 1,
}
